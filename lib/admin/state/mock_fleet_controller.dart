import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/shared/models/models.dart';

/// Geographic window the stylized basemap paints. Fixed rather than derived
/// from the riders so the live jitter never re-frames the map under the dots.
const double kFleetLatMin = 14.53;
const double kFleetLatMax = 14.75;
const double kFleetLngMin = 120.95;
const double kFleetLngMax = 121.12;

/// Coverage area. One district drives three things at once: a bar in the
/// "alerts by area" chart, a label on the map, and the street shown in the feed.
class FleetDistrict {
  final String name;

  /// Trimmed for the 9px bar-chart axis, which has ~40px per slot.
  final String shortLabel;

  /// Uppercase form scattered across the mock basemap.
  final String mapLabel;
  final String address;
  final double lat;
  final double lng;

  const FleetDistrict({
    required this.name,
    required this.shortLabel,
    required this.mapLabel,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

const List<FleetDistrict> kFleetDistricts = [
  FleetDistrict(
    name: 'Diliman',
    shortLabel: 'Diliman',
    mapLabel: 'QC-DILIMAN',
    address: 'Katipunan Ave, QC',
    lat: 14.6537,
    lng: 121.0687,
  ),
  FleetDistrict(
    name: 'Cubao',
    shortLabel: 'Cubao',
    mapLabel: 'CUBAO',
    address: 'Aurora Blvd, Cubao',
    lat: 14.6199,
    lng: 121.0530,
  ),
  FleetDistrict(
    name: 'Novaliches',
    shortLabel: 'Novali.',
    mapLabel: 'NOVALICHES',
    address: 'Mindanao Ave, Novaliches',
    lat: 14.7180,
    lng: 121.0333,
  ),
  FleetDistrict(
    name: 'Fairview',
    shortLabel: 'Fairvw',
    mapLabel: 'FAIRVIEW',
    address: 'Regalado Ave, Fairview',
    lat: 14.7297,
    lng: 121.0644,
  ),
  FleetDistrict(
    name: 'Commonwealth',
    shortLabel: 'Comm.',
    mapLabel: 'COMMONWEALTH',
    address: 'Commonwealth Ave, QC',
    lat: 14.6906,
    lng: 121.0801,
  ),
  FleetDistrict(
    name: 'Sampaloc',
    shortLabel: 'Sampa.',
    mapLabel: 'SAMPALOC',
    address: 'España Blvd, Sampaloc',
    lat: 14.6100,
    lng: 120.9950,
  ),
  FleetDistrict(
    name: 'Sta. Mesa',
    shortLabel: 'StaMesa',
    mapLabel: 'STA. MESA',
    address: 'E. Rodriguez Sr. Ave',
    lat: 14.5980,
    lng: 121.0150,
  ),
  FleetDistrict(
    name: 'Makati',
    shortLabel: 'Makati',
    mapLabel: 'MAKATI',
    address: 'EDSA, Makati',
    lat: 14.5547,
    lng: 121.0244,
  ),
];

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

/// Live mock fleet: one mutable copy of the seed data plus the timers that
/// keep it moving. Every dashboard panel reads from this single instance, so
/// a spawned crash lands in the feed, the donut, the map and the priority
/// chart in the same frame.
///
/// Phase 4 seam: swap the two timers below for Firestore snapshot
/// subscriptions — the panels only ever see the getters, so nothing else moves.
/// The workflow mutations become Firestore writes on the same seam: a
/// transition becomes an `alerts/{id}` update plus an `alerts/{id}/history`
/// sub-collection append, and the local mutation disappears in favour of the
/// snapshot echoing the write back. Injection happens once, in `FleetHost`.
class MockFleetController extends ChangeNotifier {
  MockFleetController() {
    _riders = List.of(MockData.riders);
    _telemetry = List.of(MockData.telemetry);
    _alerts = List.of(MockData.alerts);
    // Seed each trail with the rider's starting fix so the first jitter tick
    // already has something to draw a segment from.
    for (final t in _telemetry) {
      _trails[t.riderId] = [TrailPoint(t.lat, t.lng)];
    }
    _jitterTimer = Timer.periodic(_jitterInterval, (_) => _stepTelemetry());
    _scheduleNextAlert();
  }

  static const _jitterInterval = Duration(seconds: 3);

  /// Deltas per jitter tick — small enough to read as drift, not teleporting.
  static const _latJitter = 0.0035;
  static const _lngJitter = 0.0035;
  static const _speedJitter = 3.0;

  /// Cap so the feed never grows unbounded over a long demo session.
  static const _maxAlerts = 40;

  /// Breadcrumb depth per rider. Twenty fixes at the 3s jitter interval is
  /// about a minute of history — long enough to read as a path, short enough
  /// that the map does not turn into spaghetti.
  static const _maxTrailPoints = 20;

  final Random _rng = Random();

  late final List<Rider> _riders;
  late final List<HelmetTelemetry> _telemetry;
  late final List<AlertEvent> _alerts;

  final Map<String, List<TrailPoint>> _trails = {};

  Timer? _jitterTimer;
  Timer? _alertTimer;

  DateTime _lastSync = DateTime.now();
  int _nextAlertId = 102;
  String? _selectedRiderId;

  UnmodifiableListView<Rider> get riders => UnmodifiableListView(_riders);
  UnmodifiableListView<HelmetTelemetry> get telemetry =>
      UnmodifiableListView(_telemetry);
  UnmodifiableListView<AlertEvent> get alerts => UnmodifiableListView(_alerts);

  /// Timestamp of the most recent simulated telemetry push.
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

  /// Life-critical first, then severity by type. Anything already resolved
  /// stops competing for dispatch attention and drops to "none".
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

  static AlertPriority priorityOf(AlertEvent alert) {
    if (alert.status == AlertStatus.resolved) return AlertPriority.none;
    return switch (alert.type) {
      AlertType.crash => AlertPriority.critical,
      AlertType.sos => AlertPriority.high,
      AlertType.alcoholWarning => AlertPriority.medium,
      AlertType.lowBattery => AlertPriority.low,
    };
  }

  static FleetDistrict nearestDistrict(double lat, double lng) {
    var best = kFleetDistricts.first;
    var bestDistance = double.infinity;
    for (final d in kFleetDistricts) {
      // Squared planar distance — the coverage area is small enough that
      // proper great-circle maths would not change the winner.
      final dLat = d.lat - lat;
      final dLng = d.lng - lng;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = d;
      }
    }
    return best;
  }

  // -------------------------------------------------------------- workflow

  /// Operator takes ownership of an open alert.
  ///
  /// Throws [StateError] if the alert is unknown or the move is illegal —
  /// callers surface [StateError.message] in a SnackBar rather than letting a
  /// rejected action look like a successful one.
  void acknowledgeAlert(String alertId, {required String actor}) {
    _transition(alertId, AlertStatus.acknowledged, actor: actor);
  }

  /// Sends a responder. Requires the alert to already be acknowledged.
  void dispatchAlert(
    String alertId, {
    required String actor,
    required ResponderType responder,
    String? note,
  }) {
    _transition(
      alertId,
      AlertStatus.dispatched,
      actor: actor,
      responder: responder,
      note: note,
    );
  }

  /// Closes the incident and, where nothing else is outstanding, puts the
  /// rider back on the road.
  void resolveAlert(String alertId, {required String actor, String? note}) {
    _transition(alertId, AlertStatus.resolved, actor: actor, note: note);
  }

  /// The one place an alert's status changes. Enforces the linear lifecycle
  /// declared on [AlertStatusLabel.nextStatus] and appends the audit entry.
  void _transition(
    String alertId,
    AlertStatus target, {
    required String actor,
    ResponderType? responder,
    String? note,
  }) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) {
      throw StateError('Alert $alertId is no longer on the board.');
    }

    final alert = _alerts[index];
    if (!alert.status.canTransitionTo(target)) {
      throw StateError(
        'Cannot mark ${alert.id} as ${target.label.toLowerCase()} while it is '
        '${alert.status.label.toLowerCase()} — an alert must go '
        'open → acknowledged → dispatched → resolved.',
      );
    }

    _alerts[index] = alert.copyWith(
      status: target,
      history: [
        ...alert.history,
        AlertAction(
          toStatus: target,
          actorName: actor,
          note: note,
          responder: responder,
          at: DateTime.now(),
        ),
      ],
    );

    if (target == AlertStatus.resolved) {
      _clearRiderIfSettled(alert.riderId);
    }

    notifyListeners();
  }

  /// A rider comes off emergency once none of their critical alerts are
  /// still active. Anything less would clear the dot while responders are
  /// still en route to a second incident.
  void _clearRiderIfSettled(String riderId) {
    final rider = riderFor(riderId);
    if (rider == null || rider.status != RiderStatus.emergency) return;

    final stillActive = _alerts.any(
      (a) => a.riderId == riderId && a.type.isCritical && a.status.isActive,
    );
    if (stillActive) return;

    _setStatus(riderId, RiderStatus.idle);
  }

  // ------------------------------------------------------------- simulation

  /// Nudges every riding helmet a little so the map reads as live.
  void _stepTelemetry() {
    final now = DateTime.now();

    for (var i = 0; i < _telemetry.length; i++) {
      final t = _telemetry[i];
      if (riderFor(t.riderId)?.status != RiderStatus.riding) continue;

      final moved = t.copyWith(
        lat: (t.lat + _signed(_latJitter)).clamp(kFleetLatMin, kFleetLatMax).toDouble(),
        lng: (t.lng + _signed(_lngJitter)).clamp(kFleetLngMin, kFleetLngMax).toDouble(),
        speedKmh: (t.speedKmh + _signed(_speedJitter)).clamp(8.0, 78.0).toDouble(),
        lastUpdate: now,
      );
      _telemetry[i] = moved;
      _recordTrailPoint(moved);
    }

    _lastSync = now;
    notifyListeners();
  }

  /// Appends a fix to the rider's breadcrumb, dropping the oldest once the
  /// cap is reached so a long demo session cannot grow the trail unbounded.
  void _recordTrailPoint(HelmetTelemetry telemetry) {
    final trail = _trails.putIfAbsent(telemetry.riderId, () => <TrailPoint>[]);
    trail.add(TrailPoint(telemetry.lat, telemetry.lng));
    if (trail.length > _maxTrailPoints) {
      trail.removeRange(0, trail.length - _maxTrailPoints);
    }
  }

  /// Alerts arrive on an irregular 10–14s cadence — a fixed beat reads as fake.
  void _scheduleNextAlert() {
    final delay = Duration(milliseconds: 10000 + _rng.nextInt(4001));
    _alertTimer = Timer(delay, _spawnAlert);
  }

  void _spawnAlert() {
    final district = kFleetDistricts[_rng.nextInt(kFleetDistricts.length)];
    final type = _randomType();
    final rider = _alertCandidate();

    if (rider != null) {
      _alerts.insert(
        0,
        AlertEvent(
          id: 'A-${_nextAlertId++}',
          riderId: rider.id,
          riderName: rider.fullName,
          type: type,
          lat: district.lat + _signed(0.006),
          lng: district.lng + _signed(0.006),
          address: district.address,
          timestamp: DateTime.now(),
          status: AlertStatus.open,
        ),
      );
      if (_alerts.length > _maxAlerts) _alerts.removeLast();

      // A crash or SOS flips the rider red — that one write is what makes the
      // donut, the map dot and the priority chart all react together.
      if (type.isCritical) _setStatus(rider.id, RiderStatus.emergency);
    }

    _standDownOldestEmergency();
    _lastSync = DateTime.now();
    notifyListeners();
    _scheduleNextAlert();
  }

  /// Anyone but an offline helmet can raise an alert; riding riders are the
  /// likeliest so the map usually has a dot to turn red.
  Rider? _alertCandidate() {
    final riding =
        _riders.where((r) => r.status == RiderStatus.riding).toList();
    if (riding.isNotEmpty && _rng.nextDouble() < 0.7) {
      return riding[_rng.nextInt(riding.length)];
    }
    final available =
        _riders.where((r) => r.status != RiderStatus.offline).toList();
    if (available.isEmpty) return null;
    return available[_rng.nextInt(available.length)];
  }

  /// Weighted so criticals stay the exception, not the norm.
  AlertType _randomType() {
    final roll = _rng.nextDouble();
    if (roll < 0.18) return AlertType.crash;
    if (roll < 0.34) return AlertType.sos;
    if (roll < 0.64) return AlertType.alcoholWarning;
    return AlertType.lowBattery;
  }

  /// Emergencies would otherwise pile up until the whole fleet is red; once
  /// three are open, the first one in fleet order goes back on the road.
  ///
  /// Only riders with no active critical alert are eligible — an alert the
  /// operator is working through owns its rider's status until it is
  /// resolved, so a demo acknowledge/dispatch can never be silently undone by
  /// this timer. Riders qualify again once their alerts are resolved, or once
  /// the [_maxAlerts] cap ages them off the board entirely.
  ///
  /// Consequence worth knowing during a demo: if the operator never resolves
  /// anything, emergencies now persist rather than self-clearing. Clearing
  /// them is the operator's job as of the response workflow.
  void _standDownOldestEmergency() {
    final emergencies =
        _riders.where((r) => r.status == RiderStatus.emergency).toList();
    if (emergencies.length < 3) return;

    for (final rider in emergencies) {
      final hasActiveAlert = _alerts.any(
        (a) => a.riderId == rider.id && a.type.isCritical && a.status.isActive,
      );
      if (!hasActiveAlert) {
        _setStatus(rider.id, RiderStatus.riding);
        return;
      }
    }
  }

  void _setStatus(String riderId, RiderStatus status) {
    final index = _riders.indexWhere((r) => r.id == riderId);
    if (index == -1) return;
    _riders[index] = _riders[index].copyWith(status: status);
  }

  double _signed(double magnitude) => (_rng.nextDouble() * 2 - 1) * magnitude;

  @override
  void dispose() {
    _jitterTimer?.cancel();
    _alertTimer?.cancel();
    _jitterTimer = null;
    _alertTimer = null;
    super.dispose();
  }
}
