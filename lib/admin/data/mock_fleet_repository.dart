import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:novaride/admin/data/fleet_geography.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/shared/models/models.dart';

/// In-process stand-in for the cloud store: one mutable copy of the seed
/// data plus the timers that keep it moving.
///
/// Plays the part of the helmets and the backend at once — it jitters
/// telemetry, raises alerts on an irregular beat and flips riders to
/// emergency the way the firmware and a cloud function eventually will.
/// Writes from the controller land here and are echoed straight back out
/// through the same streams, so the console never has to special-case
/// "did my write take".
///
/// Streams deliver synchronously. That keeps the controller's state
/// consistent in the same call that mutated it, which is what the widget
/// and controller tests rely on — and it costs nothing here, since there is
/// no I/O to wait on.
class MockFleetRepository implements FleetRepository {
  MockFleetRepository({bool simulate = true}) {
    _riders = List.of(MockData.riders);
    _telemetry = List.of(MockData.telemetry);
    _alerts = List.of(MockData.alerts);
    if (simulate) {
      _jitterTimer = Timer.periodic(_jitterInterval, (_) => _stepTelemetry());
      _scheduleNextAlert();
    }
  }

  static const _jitterInterval = Duration(seconds: 3);

  /// Deltas per jitter tick — small enough to read as drift, not teleporting.
  static const _latJitter = 0.0035;
  static const _lngJitter = 0.0035;
  static const _speedJitter = 3.0;

  /// Cap so the feed never grows unbounded over a long demo session.
  static const maxAlerts = 40;

  final Random _rng = Random();

  late List<Rider> _riders;
  late List<HelmetTelemetry> _telemetry;
  late List<AlertEvent> _alerts;

  final _ridersCtrl = StreamController<List<Rider>>.broadcast(sync: true);
  final _telemetryCtrl =
      StreamController<List<HelmetTelemetry>>.broadcast(sync: true);
  final _alertsCtrl = StreamController<List<AlertEvent>>.broadcast(sync: true);

  Timer? _jitterTimer;
  Timer? _alertTimer;
  int _nextAlertId = 102;

  @override
  FleetSource get source => FleetSource.simulation;

  // --------------------------------------------------------------- streams

  @override
  Stream<List<Rider>> watchRiders() =>
      _replaying(() => List.unmodifiable(_riders), _ridersCtrl.stream);

  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() =>
      _replaying(() => List.unmodifiable(_telemetry), _telemetryCtrl.stream);

  @override
  Stream<List<AlertEvent>> watchAlerts() =>
      _replaying(() => List.unmodifiable(_alerts), _alertsCtrl.stream);

  /// The simulation has nothing to lose a connection to.
  @override
  Stream<FleetConnection> watchConnection() =>
      Stream.value(FleetConnection.connected);

  /// Hands a new listener the current value during `listen()`, then forwards
  /// every later emission. Both synchronous, see the class comment.
  Stream<T> _replaying<T>(T Function() current, Stream<T> updates) =>
      _ReplayStream(current, updates);

  void _publishRiders() => _ridersCtrl.add(List.unmodifiable(_riders));
  void _publishTelemetry() => _telemetryCtrl.add(List.unmodifiable(_telemetry));
  void _publishAlerts() => _alertsCtrl.add(List.unmodifiable(_alerts));

  // ---------------------------------------------------------------- writes

  /// Drops the new rider near a random district so the dot is not stacked
  /// on an existing one, and gives them a fix so they are plottable at once.
  @override
  Future<void> addRider(Rider rider) async {
    _riders.add(rider);

    final district = kFleetDistricts[_rng.nextInt(kFleetDistricts.length)];
    _telemetry.add(
      HelmetTelemetry(
        riderId: rider.id,
        speedKmh: rider.status == RiderStatus.riding
            ? 24 + _rng.nextDouble() * 20
            : 0,
        alcoholLevel: 0,
        batteryPct: 80 + _rng.nextInt(20),
        gpsFix: true,
        lat: district.lat + _signed(0.006),
        lng: district.lng + _signed(0.006),
        lastUpdate: DateTime.now(),
      ),
    );

    _publishRiders();
    _publishTelemetry();
  }

  @override
  Future<void> updateRider(Rider rider) async {
    final index = _riders.indexWhere((r) => r.id == rider.id);
    if (index == -1) return;
    _riders[index] = rider;
    _publishRiders();
  }

  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async {
    _setStatus(riderId, status);
    _publishRiders();
  }

  @override
  Future<void> transitionAlert(String alertId, AlertAction action) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return;
    final alert = _alerts[index];
    _alerts[index] = alert.copyWith(
      status: action.toStatus,
      history: [...alert.history, action],
    );
    _publishAlerts();
  }

  // ------------------------------------------------------------ simulation

  /// Nudges every riding helmet a little so the map reads as live.
  void _stepTelemetry() {
    final now = DateTime.now();

    for (var i = 0; i < _telemetry.length; i++) {
      final t = _telemetry[i];
      if (_riderFor(t.riderId)?.status != RiderStatus.riding) continue;

      _telemetry[i] = t.copyWith(
        lat: (t.lat + _signed(_latJitter))
            .clamp(kFleetLatMin, kFleetLatMax)
            .toDouble(),
        lng: (t.lng + _signed(_lngJitter))
            .clamp(kFleetLngMin, kFleetLngMax)
            .toDouble(),
        speedKmh:
            (t.speedKmh + _signed(_speedJitter)).clamp(8.0, 78.0).toDouble(),
        lastUpdate: now,
      );
    }

    _publishTelemetry();
  }

  /// Alerts arrive on an irregular 10–14s cadence — a fixed beat reads as fake.
  void _scheduleNextAlert() {
    final delay = Duration(milliseconds: 10000 + _rng.nextInt(4001));
    _alertTimer = Timer(delay, _spawnAlert);
  }

  void _spawnAlert() {
    _emitAlert();
    _scheduleNextAlert();
  }

  /// Spawns one alert without touching the timer.
  ///
  /// Separated from [_spawnAlert] so tests can drive the simulation a step at
  /// a time — calling the timer path directly would reschedule and orphan the
  /// pending timer.
  @visibleForTesting
  void debugEmitAlert() => _emitAlert();

  void _emitAlert() {
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
      if (_alerts.length > maxAlerts) _alerts.removeLast();

      // A crash or SOS flips the rider red — that one write is what makes the
      // donut, the map dot and the priority chart all react together.
      if (type.isCritical) _setStatus(rider.id, RiderStatus.emergency);
    }

    _standDownOldestEmergency();
    _publishAlerts();
    _publishRiders();
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
  /// the [maxAlerts] cap ages them off the board entirely.
  ///
  /// Consequence worth knowing during a demo: if the operator never resolves
  /// anything, emergencies persist rather than self-clearing. Clearing them
  /// is the operator's job as of the response workflow.
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

  Rider? _riderFor(String riderId) {
    for (final r in _riders) {
      if (r.id == riderId) return r;
    }
    return null;
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
    _ridersCtrl.close();
    _telemetryCtrl.close();
    _alertsCtrl.close();
  }
}

/// A broadcast stream that delivers [current] to each new listener inside
/// `listen()` itself, before forwarding [updates].
///
/// `Stream.multi` cannot do this: its `onListen` runs inside a guarded
/// callback, so even `addSync` is queued until the next microtask, and the
/// controller would start empty for one turn of the event loop.
class _ReplayStream<T> extends Stream<T> {
  final T Function() _current;
  final Stream<T> _updates;

  _ReplayStream(this._current, this._updates);

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _updates.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    onData?.call(_current());
    return subscription;
  }
}
