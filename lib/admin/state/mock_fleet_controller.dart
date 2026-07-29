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
class MockFleetController extends ChangeNotifier {
  MockFleetController() {
    _riders = List.of(MockData.riders);
    _telemetry = List.of(MockData.telemetry);
    _alerts = List.of(MockData.alerts);
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

  final Random _rng = Random();

  late final List<Rider> _riders;
  late final List<HelmetTelemetry> _telemetry;
  late final List<AlertEvent> _alerts;

  Timer? _jitterTimer;
  Timer? _alertTimer;

  DateTime _lastSync = DateTime.now();
  int _nextAlertId = 102;

  UnmodifiableListView<Rider> get riders => UnmodifiableListView(_riders);
  UnmodifiableListView<HelmetTelemetry> get telemetry =>
      UnmodifiableListView(_telemetry);
  UnmodifiableListView<AlertEvent> get alerts => UnmodifiableListView(_alerts);

  /// Timestamp of the most recent simulated telemetry push.
  DateTime get lastSync => _lastSync;

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

  // ------------------------------------------------------------- simulation

  /// Nudges every riding helmet a little so the map reads as live.
  void _stepTelemetry() {
    final now = DateTime.now();

    for (var i = 0; i < _telemetry.length; i++) {
      final t = _telemetry[i];
      if (riderFor(t.riderId)?.status != RiderStatus.riding) continue;

      _telemetry[i] = t.copyWith(
        lat: (t.lat + _signed(_latJitter)).clamp(kFleetLatMin, kFleetLatMax).toDouble(),
        lng: (t.lng + _signed(_lngJitter)).clamp(kFleetLngMin, kFleetLngMax).toDouble(),
        speedKmh: (t.speedKmh + _signed(_speedJitter)).clamp(8.0, 78.0).toDouble(),
        lastUpdate: now,
      );
    }

    _lastSync = now;
    notifyListeners();
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
  void _standDownOldestEmergency() {
    final emergencies =
        _riders.where((r) => r.status == RiderStatus.emergency).toList();
    if (emergencies.length < 3) return;
    _setStatus(emergencies.first.id, RiderStatus.riding);
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
