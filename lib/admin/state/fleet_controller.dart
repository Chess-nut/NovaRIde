import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:novaride/admin/data/fleet_geography.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/shared/models/models.dart';

export 'package:novaride/admin/data/fleet_geography.dart';
export 'package:novaride/admin/data/fleet_repository.dart'
    show FleetSource, FleetSourceLabel, FleetConnection, FleetConnectionState;

/// One historical GPS fix in a rider's breadcrumb trail.
///
/// Deliberately not a full [HelmetTelemetry] — the trail only needs geometry,
/// and keeping twenty full telemetry records per rider would be wasteful.
class TrailPoint {
  final double lat;
  final double lng;

  const TrailPoint(this.lat, this.lng);
}

/// Dispatch priority buckets for the "alert priority" chart.
enum AlertPriority { critical, high, medium, low, none }

extension AlertPriorityLabel on AlertPriority {
  String get label => switch (this) {
        AlertPriority.critical => 'Critical',
        AlertPriority.high => 'High',
        AlertPriority.medium => 'Medium',
        AlertPriority.low => 'Low',
        AlertPriority.none => 'None',
      };
}

/// Live fleet state for the whole console, fed by one [FleetRepository].
///
/// Every dashboard panel reads from this single instance, so a crash that
/// arrives from the store lands in the feed, the donut, the map and the
/// priority chart in the same frame. The controller holds the workflow rules
/// — legal alert transitions, roster uniqueness, when a rider comes off
/// emergency — and validates every mutation against its local copy before
/// asking the repository to persist. The repository's streams are the source
/// of truth: a write is only "done" once it echoes back through them.
///
/// Mutations throw [StateError] synchronously when the rule check fails and
/// return the persistence future otherwise, so a page can catch a rejected
/// action in the same call and still learn if the store refused the write.
///
/// Roster writes are optimistic: the rider appears (or changes) the moment
/// the operator saves, ahead of the store's answer, and is withdrawn if the
/// store refuses or does not answer within [writeTimeout]. The pending copy
/// is an overlay on the store's list, never a mutation of it, so the
/// stream stays the source of truth and a rejected write leaves no trace.
class FleetController extends ChangeNotifier {
  FleetController(this._repository) {
    _ridersSub = _repository.watchRiders().listen(
          _onRiders,
          onError: (Object e) => debugPrint('FleetController riders: $e'),
        );
    _telemetrySub = _repository.watchTelemetry().listen(
          _onTelemetry,
          onError: (Object e) => debugPrint('FleetController telemetry: $e'),
        );
    _alertsSub = _repository.watchAlerts().listen(
          _onAlerts,
          onError: (Object e) => debugPrint('FleetController alerts: $e'),
        );
    _connectionSub = _repository.watchConnection().listen(_onConnection);
  }

  /// Breadcrumb depth per rider. Twenty fixes at the simulation's 3s cadence
  /// is about a minute of history — long enough to read as a path, short
  /// enough that the map does not turn into spaghetti.
  static const _maxTrailPoints = 20;

  final FleetRepository _repository;

  StreamSubscription<List<Rider>>? _ridersSub;
  StreamSubscription<List<HelmetTelemetry>>? _telemetrySub;
  StreamSubscription<List<AlertEvent>>? _alertsSub;
  StreamSubscription<FleetConnection>? _connectionSub;

  /// How long a roster write may go unanswered before it is treated as
  /// failed and rolled back. Firestore transactions fail within seconds when
  /// the client is offline; this catches the connection that hangs instead.
  static const writeTimeout = Duration(seconds: 20);

  /// The roster as the store last delivered it.
  List<Rider> _storeRiders = const [];

  /// [_storeRiders] with the pending writes laid over it — what pages read.
  List<Rider> _riders = const [];

  /// Writes shown ahead of the store's confirmation, by rider id. An entry
  /// is added when the write is issued, marked confirmed when the store
  /// accepts it, and dropped once the store's stream reflects it — or at
  /// once if the write fails.
  final Map<String, _PendingWrite> _pending = {};
  int _nextWriteToken = 0;

  List<HelmetTelemetry> _telemetry = const [];
  List<AlertEvent> _alerts = const [];
  final Map<String, List<TrailPoint>> _trails = {};

  bool _ridersLoaded = false;
  bool _telemetryLoaded = false;
  bool _alertsLoaded = false;

  FleetConnection _connection = FleetConnection.connecting;
  DateTime _lastSync = DateTime.now();
  String? _selectedRiderId;

  FleetSource get source => _repository.source;

  FleetConnection get connection => _connection;

  /// True once every stream has delivered at least once. The simulation is
  /// loaded before the constructor returns; a cloud source takes a moment.
  bool get isLoaded => _ridersLoaded && _telemetryLoaded && _alertsLoaded;

  UnmodifiableListView<Rider> get riders => UnmodifiableListView(_riders);
  UnmodifiableListView<HelmetTelemetry> get telemetry =>
      UnmodifiableListView(_telemetry);
  UnmodifiableListView<AlertEvent> get alerts => UnmodifiableListView(_alerts);

  /// Timestamp of the most recent telemetry or alert push from the source.
  DateTime get lastSync => _lastSync;

  /// Rider the operator is drilled into, shared between the roster table and
  /// the map so clicking either keeps both in agreement. Null means no
  /// selection.
  String? get selectedRiderId => _selectedRiderId;

  void selectRider(String? riderId) {
    if (_selectedRiderId == riderId) return;
    _selectedRiderId = riderId;
    notifyListeners();
  }

  /// Recent GPS fixes for one rider, oldest first.
  UnmodifiableListView<TrailPoint> trailFor(String riderId) =>
      UnmodifiableListView(_trails[riderId] ?? const <TrailPoint>[]);

  HelmetTelemetry? telemetryFor(String riderId) {
    for (final t in _telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }

  Rider? riderFor(String riderId) {
    for (final r in _riders) {
      if (r.id == riderId) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------- inbound

  void _onRiders(List<Rider> riders) {
    _storeRiders = riders;
    _ridersLoaded = true;
    // A snapshot delivered after the store accepted a write reflects it, so
    // the overlay for that write has done its job. Unconfirmed ones stay:
    // this snapshot may predate their commit.
    _pending.removeWhere((_, write) => write.confirmed);
    _composeRiders();
    notifyListeners();
  }

  /// Rebuilds [_riders]: the store's order, each rider replaced by its
  /// pending edit if one exists, then pending additions appended.
  void _composeRiders() {
    final storeIds = {for (final r in _storeRiders) r.id};
    _riders = [
      for (final r in _storeRiders) _pending[r.id]?.rider ?? r,
      for (final write in _pending.values)
        if (!storeIds.contains(write.rider.id)) write.rider,
    ];
  }

  /// Every telemetry push extends the breadcrumb of any helmet that moved.
  /// Comparing against the trail's last fix rather than trusting the source
  /// to tell us means a Firestore echo of an unchanged document adds nothing.
  void _onTelemetry(List<HelmetTelemetry> telemetry) {
    _telemetry = telemetry;
    _telemetryLoaded = true;
    _lastSync = DateTime.now();
    for (final t in telemetry) {
      _recordTrailPoint(t);
    }
    notifyListeners();
  }

  void _onAlerts(List<AlertEvent> alerts) {
    _alerts = alerts;
    _alertsLoaded = true;
    _lastSync = DateTime.now();
    notifyListeners();
  }

  void _onConnection(FleetConnection connection) {
    _connection = connection;
    notifyListeners();
  }

  /// Appends a fix to the rider's breadcrumb when it differs from the last
  /// one, dropping the oldest once the cap is reached so a long session
  /// cannot grow the trail unbounded.
  void _recordTrailPoint(HelmetTelemetry telemetry) {
    final trail = _trails.putIfAbsent(telemetry.riderId, () => <TrailPoint>[]);
    if (trail.isNotEmpty) {
      final last = trail.last;
      if (last.lat == telemetry.lat && last.lng == telemetry.lng) return;
    }
    trail.add(TrailPoint(telemetry.lat, telemetry.lng));
    if (trail.length > _maxTrailPoints) {
      trail.removeRange(0, trail.length - _maxTrailPoints);
    }
  }

  // ---------------------------------------------------------------- derived

  /// Rider headcount per status, every bucket present so the donut and its
  /// legend keep a stable order even at zero.
  Map<RiderStatus, int> get statusCounts {
    final counts = {for (final s in RiderStatus.values) s: 0};
    for (final r in _riders) {
      counts[r.status] = counts[r.status]! + 1;
    }
    return counts;
  }

  /// Alerts bucketed by the district whose centre they sit closest to.
  Map<String, int> get alertsByArea {
    final counts = {for (final d in kFleetDistricts) d.name: 0};
    for (final a in _alerts) {
      final district = nearestDistrict(a.lat, a.lng);
      counts[district.name] = counts[district.name]! + 1;
    }
    return counts;
  }

  Map<AlertPriority, int> get alertsByPriority {
    final counts = {for (final p in AlertPriority.values) p: 0};
    for (final a in _alerts) {
      final p = priorityOf(a);
      counts[p] = counts[p]! + 1;
    }
    return counts;
  }

  Map<AlertType, int> get alertsByType {
    final counts = {for (final t in AlertType.values) t: 0};
    for (final a in _alerts) {
      counts[a.type] = counts[a.type]! + 1;
    }
    return counts;
  }

  /// Life-critical alerts still on the board. Drives the "open critical"
  /// KPI and the resolve-clears-the-rider rule.
  int get openCriticalCount =>
      _alerts.where((a) => a.type.isCritical && a.status.isActive).length;

  /// Mean time from an alert firing to an operator acknowledging it — the
  /// headline "Golden Hour" number the console exists to shrink.
  /// Null until at least one alert has been acknowledged.
  Duration? get averageAcknowledgeTime =>
      _meanTimeTo(AlertStatus.acknowledged);

  Duration? get averageResolveTime => _meanTimeTo(AlertStatus.resolved);

  Duration? _meanTimeTo(AlertStatus status) {
    var totalMicros = 0;
    var count = 0;
    for (final alert in _alerts) {
      final at = alert.reachedAt(status);
      if (at == null) continue;
      totalMicros += at.difference(alert.timestamp).inMicroseconds;
      count++;
    }
    if (count == 0) return null;
    return Duration(microseconds: totalMicros ~/ count);
  }

  /// Life-critical first, then severity by type. Anything already resolved
  /// stops competing for dispatch attention and drops to "none".
  static AlertPriority priorityOf(AlertEvent alert) {
    if (alert.status == AlertStatus.resolved) return AlertPriority.none;
    return switch (alert.type) {
      AlertType.crash => AlertPriority.critical,
      AlertType.sos => AlertPriority.high,
      AlertType.alcoholWarning => AlertPriority.medium,
      AlertType.lowBattery => AlertPriority.low,
    };
  }

  static FleetDistrict nearestDistrict(double lat, double lng) =>
      nearestFleetDistrict(lat, lng);

  // ------------------------------------------------------------- roster CRUD

  /// Registers a new rider and resolves to the record as the store saved it
  /// — the id may have moved forward if another operator claimed the
  /// suggested one first.
  ///
  /// Throws [StateError] synchronously if the id or helmet serial is already
  /// taken on this console's copy of the roster — uniqueness is enforced
  /// here as well as in the form, so a caller cannot bypass it — and a
  /// [FleetWriteException] later if the store refuses or does not answer.
  /// The rider is on the roster from the moment this is called and gone
  /// again the moment it fails.
  Future<Rider> addRider(Rider rider) {
    if (_riders.any((r) => r.id == rider.id)) {
      throw StateError('Rider ${rider.id} already exists.');
    }
    if (_riders.any(
      (r) => r.helmetId.toUpperCase() == rider.helmetId.toUpperCase(),
    )) {
      throw StateError('Helmet ${rider.helmetId} is already assigned.');
    }
    return _writeOptimistically(rider, () => _repository.addRider(rider));
  }

  /// Replaces a rider's editable fields. Throws if the id is unknown or the
  /// new helmet serial belongs to somebody else.
  Future<void> updateRider(Rider rider) {
    if (riderFor(rider.id) == null) {
      throw StateError('Rider ${rider.id} is not on the roster.');
    }
    if (_riders.any(
      (r) =>
          r.id != rider.id &&
          r.helmetId.toUpperCase() == rider.helmetId.toUpperCase(),
    )) {
      throw StateError('Helmet ${rider.helmetId} is already assigned.');
    }
    return _writeOptimistically(
      rider,
      () => _repository.updateRider(rider).then((_) => rider),
    );
  }

  /// Takes a rider off active duty without deleting them. Their alerts keep
  /// resolving against a real rider record, and reactivating puts them back
  /// as idle rather than guessing at their previous status. A narrow write:
  /// only `isActive` and `status` travel, so nothing stale rides along.
  Future<void> setRiderActive(String riderId, bool active) {
    final rider = riderFor(riderId);
    if (rider == null) {
      throw StateError('Rider $riderId is not on the roster.');
    }
    final expected = rider.copyWith(
      isActive: active,
      status: active ? RiderStatus.idle : RiderStatus.offline,
    );
    return _writeOptimistically(
      expected,
      () => _repository.setRiderActive(riderId, active).then((_) => expected),
    );
  }

  /// Shows [expected] on the roster now, runs [write], and reconciles:
  ///
  /// - the store accepts → the entry is marked confirmed and dropped as
  ///   soon as the stream shows the saved record (immediately, if it
  ///   already does — the simulation echoes synchronously);
  /// - the store refuses, or [writeTimeout] passes → the entry is withdrawn
  ///   and the error rethrown as a [FleetWriteException] for the page.
  ///
  /// [write] resolves to the record as saved, which may carry a different
  /// id than [expected] (an add whose suggested id was taken); the overlay
  /// follows the saved id so the roster never shows both.
  Future<Rider> _writeOptimistically(
    Rider expected,
    Future<Rider> Function() write,
  ) async {
    final token = _nextWriteToken++;
    _stage(expected, token);

    final Rider saved;
    try {
      saved = await write().timeout(writeTimeout);
    } on TimeoutException {
      _withdraw(expected.id, token);
      throw const FleetWriteException(
        'No answer from the store in 20 seconds. The change may not have '
        'been saved — check the connection, then check the roster before '
        'trying again.',
      );
    } catch (_) {
      _withdraw(expected.id, token);
      rethrow;
    }

    if (saved.id != expected.id) {
      _withdraw(expected.id, token);
      _stage(saved, token);
    }
    final entry = _pending[saved.id];
    if (entry != null && entry.token == token) {
      if (_storeRiders.any((r) => _sameRecord(r, saved))) {
        _pending.remove(saved.id);
      } else {
        entry.confirmed = true;
      }
      _composeRiders();
      notifyListeners();
    }
    return saved;
  }

  void _stage(Rider rider, int token) {
    _pending[rider.id] = _PendingWrite(rider, token);
    _composeRiders();
    notifyListeners();
  }

  /// Drops the overlay entry for [id] if it still belongs to this write —
  /// a newer write to the same rider owns the entry otherwise.
  void _withdraw(String id, int token) {
    if (_pending[id]?.token != token) return;
    _pending.remove(id);
    _composeRiders();
    notifyListeners();
  }

  static bool _sameRecord(Rider a, Rider b) =>
      a.id == b.id &&
      a.fullName == b.fullName &&
      a.helmetId == b.helmetId &&
      a.phone == b.phone &&
      a.status == b.status &&
      a.isActive == b.isActive;

  // -------------------------------------------------------------- workflow

  /// Operator takes ownership of an open alert.
  ///
  /// Throws [StateError] if the alert is unknown or the move is illegal —
  /// callers surface [StateError.message] in a SnackBar rather than letting a
  /// rejected action look like a successful one.
  Future<void> acknowledgeAlert(String alertId, {required String actor}) {
    return _transition(alertId, AlertStatus.acknowledged, actor: actor);
  }

  /// Sends a responder. Requires the alert to already be acknowledged.
  Future<void> dispatchAlert(
    String alertId, {
    required String actor,
    required ResponderType responder,
    String? note,
  }) {
    return _transition(
      alertId,
      AlertStatus.dispatched,
      actor: actor,
      responder: responder,
      note: note,
    );
  }

  /// Closes the incident and, where nothing else is outstanding, puts the
  /// rider back on the road.
  Future<void> resolveAlert(
    String alertId, {
    required String actor,
    String? note,
  }) {
    return _transition(alertId, AlertStatus.resolved, actor: actor, note: note);
  }

  /// The one place an alert's status changes. Enforces the linear lifecycle
  /// declared on [AlertStatusLabel.nextStatus] and appends the audit entry.
  Future<void> _transition(
    String alertId,
    AlertStatus target, {
    required String actor,
    ResponderType? responder,
    String? note,
  }) {
    AlertEvent? alert;
    for (final a in _alerts) {
      if (a.id == alertId) {
        alert = a;
        break;
      }
    }
    if (alert == null) {
      throw StateError('Alert $alertId is no longer on the board.');
    }
    if (!alert.status.canTransitionTo(target)) {
      throw StateError(
        'Cannot mark ${alert.id} as ${target.label.toLowerCase()} while it is '
        '${alert.status.label.toLowerCase()} — an alert must go '
        'open → acknowledged → dispatched → resolved.',
      );
    }

    final action = AlertAction(
      toStatus: target,
      actorName: actor,
      note: note,
      responder: responder,
      at: DateTime.now(),
    );

    // Both writes are issued in this call rather than chained, so a source
    // that echoes synchronously has the rider released by the time we return.
    final writes = <Future<void>>[_repository.transitionAlert(alertId, action)];
    if (target == AlertStatus.resolved && _settlesRider(alert)) {
      writes.add(_repository.setRiderStatus(alert.riderId, RiderStatus.idle));
    }
    return Future.wait(writes).then((_) {});
  }

  /// A rider comes off emergency once none of their critical alerts are
  /// still active. Anything less would clear the dot while responders are
  /// still en route to a second incident.
  ///
  /// The alert being resolved is excluded explicitly: with a cloud source the
  /// local copy has not seen the write yet, so it would still count itself.
  bool _settlesRider(AlertEvent resolving) {
    final rider = riderFor(resolving.riderId);
    if (rider == null || rider.status != RiderStatus.emergency) return false;

    return !_alerts.any(
      (a) =>
          a.id != resolving.id &&
          a.riderId == resolving.riderId &&
          a.type.isCritical &&
          a.status.isActive,
    );
  }

  /// Tears down the subscriptions and the repository behind them. The
  /// controller owns its repository — `FleetHost` builds them as a pair.
  @override
  void dispose() {
    _ridersSub?.cancel();
    _telemetrySub?.cancel();
    _alertsSub?.cancel();
    _connectionSub?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// One roster write shown ahead of the store. See
/// `FleetController._writeOptimistically`.
class _PendingWrite {
  final Rider rider;

  /// Identifies the write, so a failure cannot withdraw a newer write to the
  /// same rider that has since replaced this entry.
  final int token;

  /// Set once the store accepted the write; the entry then goes with the
  /// next snapshot, which reflects it.
  bool confirmed = false;

  _PendingWrite(this.rider, this.token);
}
