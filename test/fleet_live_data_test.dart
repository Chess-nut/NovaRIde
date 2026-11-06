// What the controller makes of live helmet data: the status a rider shows
// (worked out from the helmet, never written back), where an alert with no
// position of its own is said to be, trails seeded from the helmet's
// history, and the helmet-reported events an operator can open as alerts.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/shared/models/models.dart';

/// A repository whose every stream the test drives by hand, synchronously.
class _ScriptedRepository implements FleetRepository, HelmetFeed {
  final riders = StreamController<List<Rider>>.broadcast(sync: true);
  final telemetry = StreamController<List<HelmetTelemetry>>.broadcast(
    sync: true,
  );
  final alerts = StreamController<List<AlertEvent>>.broadcast(sync: true);
  final history = StreamController<Map<String, List<HelmetFix>>>.broadcast(
    sync: true,
  );
  final events = StreamController<List<HelmetEvent>>.broadcast(sync: true);
  final rtdb = StreamController<RtdbLink>.broadcast(sync: true);

  final writes = <String>[];
  final opened = <String>[];

  @override
  FleetSource get source => FleetSource.firestore;
  @override
  Stream<List<Rider>> watchRiders() => riders.stream;
  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() => telemetry.stream;
  @override
  Stream<List<AlertEvent>> watchAlerts() => alerts.stream;
  @override
  Stream<FleetConnection> watchConnection() =>
      Stream.value(FleetConnection.connected);
  @override
  Stream<RtdbLink> watchRtdbLink() => rtdb.stream;
  @override
  Stream<Map<String, List<HelmetFix>>> watchFixHistory() => history.stream;
  @override
  Stream<List<HelmetEvent>> watchHelmetEvents() => events.stream;

  @override
  Future<String> openHelmetEventAsAlert(
    HelmetEvent event, {
    required String actorName,
  }) async {
    opened.add('${event.id} by $actorName');
    return event.id;
  }

  @override
  Future<Rider> addRider(Rider rider) async => rider;
  @override
  Future<void> updateRider(Rider rider) async => writes.add('update');
  @override
  Future<void> setRiderActive(String riderId, bool active) async =>
      writes.add('active');
  @override
  Future<String> linkAppAccount(String riderId, String username) async => '';
  @override
  Future<void> unlinkAppAccount(String riderId) async {}
  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async =>
      writes.add('status $riderId ${status.name}');
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) async =>
      writes.add('transition');
  @override
  void dispose() {
    riders.close();
    telemetry.close();
    alerts.close();
    history.close();
    events.close();
    rtdb.close();
  }
}

Rider _rider(
  String id, {
  String helmetId = 'tracker-001',
  RiderStatus stored = RiderStatus.idle,
  bool active = true,
}) => Rider(
  id: id,
  fullName: 'Rider $id',
  helmetId: helmetId,
  phone: '0917',
  status: stored,
  isActive: active,
);

HelmetTelemetry _helmet({
  String riderId = 'R-001',
  String deviceId = 'tracker-001',
  Duration heardAgo = const Duration(seconds: 10),
  double? speed,
  bool fix = true,
  bool? online = true,
  String? safetyEvent = 'Monitoring',
}) {
  final now = DateTime.now();
  final heard = now.subtract(heardAgo);
  return HelmetTelemetry(
    riderId: riderId,
    deviceId: deviceId,
    speedKmh: speed,
    batteryPct: null,
    gpsFix: fix,
    lat: fix ? 14.6091 : null,
    lng: fix ? 121.0223 : null,
    fixAt: fix ? heard : null,
    lastUpdate: heard,
    online: online,
    safetyEvent: safetyEvent,
  );
}

AlertEvent _alert({
  String id = 'A-1',
  String riderId = 'R-001',
  AlertType type = AlertType.crash,
  AlertStatus status = AlertStatus.open,
  double? lat,
  double? lng,
  required DateTime at,
  String? deviceId,
}) => AlertEvent(
  id: id,
  riderId: riderId,
  riderName: 'Rider $riderId',
  type: type,
  lat: lat,
  lng: lng,
  address: '',
  timestamp: at,
  status: status,
  deviceId: deviceId,
);

late _ScriptedRepository _repo;

FleetController _fleet({
  List<Rider>? riders,
  List<HelmetTelemetry> telemetry = const [],
  List<AlertEvent> alerts = const [],
}) {
  _repo = _ScriptedRepository();
  final fleet = FleetController(_repo);
  addTearDown(fleet.dispose);
  _repo.riders.add(riders ?? [_rider('R-001')]);
  _repo.telemetry.add(telemetry);
  _repo.alerts.add(alerts);
  return fleet;
}

void main() {
  group('effective status', () {
    test('a helmet heard just now, standing still, is idle', () {
      final fleet = _fleet(telemetry: [_helmet(speed: 0)]);
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.idle);
    });

    test('a current fix at walking pace or more is riding', () {
      final fleet = _fleet(telemetry: [_helmet(speed: 24)]);
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.riding);
      final slow = _fleet(telemetry: [_helmet(speed: 3)]);
      expect(slow.effectiveStatusFor('R-001'), RiderStatus.idle);
    });

    test('silent past two minutes is offline, whatever the roster says', () {
      final fleet = _fleet(
        riders: [_rider('R-001', stored: RiderStatus.idle)],
        telemetry: [_helmet(heardAgo: const Duration(hours: 3), speed: 30)],
      );
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.offline);
      expect(
        fleet.statusCounts[RiderStatus.offline],
        1,
        reason: 'the donut counts what the helmet says',
      );
      expect(_repo.writes, isEmpty, reason: 'never written back');
    });

    test('online == false, or no helmet at all, is offline', () {
      expect(
        _fleet(telemetry: [_helmet(online: false)]).effectiveStatusFor('R-001'),
        RiderStatus.offline,
      );
      expect(_fleet().effectiveStatusFor('R-001'), RiderStatus.offline);
      expect(
        _fleet(
          riders: [_rider('R-001', helmetId: '')],
        ).effectiveStatusFor('R-001'),
        RiderStatus.offline,
      );
    });

    test('an active crash or SOS alert is emergency', () {
      final fleet = _fleet(
        telemetry: [_helmet(speed: 0)],
        alerts: [_alert(type: AlertType.sos, at: DateTime.now())],
      );
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.emergency);

      final resolved = _fleet(
        telemetry: [_helmet(speed: 0)],
        alerts: [
          _alert(status: AlertStatus.resolved, at: DateTime.now()),
        ],
      );
      expect(resolved.effectiveStatusFor('R-001'), RiderStatus.idle);
    });

    test("the helmet's own crash state is emergency, even gone quiet", () {
      final fleet = _fleet(
        telemetry: [
          _helmet(
            heardAgo: const Duration(hours: 1),
            safetyEvent: 'Crash alert: abnormal posture persisted 12 minutes',
          ),
        ],
      );
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.emergency);
    });

    test('a deactivated rider stays offline', () {
      final fleet = _fleet(
        riders: [_rider('R-001', active: false)],
        telemetry: [_helmet(speed: 30)],
        alerts: [_alert(at: DateTime.now())],
      );
      expect(fleet.effectiveStatusFor('R-001'), RiderStatus.offline);
    });
  });

  group('where an alert is', () {
    final alertAt = DateTime.utc(2026, 10, 30, 6);

    test('no position and no history: Location unavailable, never Sampaloc', () {
      final fleet = _fleet(alerts: [_alert(at: alertAt)]);
      final a = fleet.alerts.single;
      expect(a.lat, isNull);
      expect(a.address, 'Location unavailable');
      expect(a.address, isNot(contains('Sampaloc')));
      expect(a.address, isNot(contains('España')));
      expect(fleet.alertsByArea[kOutsideCoverage], 1);
      expect(fleet.alertsByArea['Sampaloc'], 0);
    });

    test('no position: the last fix at or before the alert, labelled so', () {
      final fleet = _fleet(alerts: [_alert(at: alertAt)]);
      _repo.history.add({
        'TRACKER-001': [
          HelmetFix(
            lat: 14.304193,
            lng: 121.123406,
            at: alertAt.subtract(const Duration(minutes: 9)),
            source: PositionSource.trackingLogs,
          ),
          HelmetFix(
            lat: 14.304159,
            lng: 121.123368,
            at: alertAt.subtract(const Duration(minutes: 4)),
            source: PositionSource.trackingLogs,
          ),
          // After the alert: not where the helmet was when it fired.
          HelmetFix(
            lat: 14.5,
            lng: 121.0,
            at: alertAt.add(const Duration(minutes: 1)),
            source: PositionSource.trackingLogs,
          ),
        ],
      });
      final a = fleet.alerts.single;
      expect(a.lat, isNull, reason: 'the alert itself still has no position');
      expect(a.lastKnownFix!.lat, 14.304159);
      expect(a.address, 'Last known position · 4 min before the alert');
      // Where the helmet was is not where the alert happened.
      expect(fleet.alertsByArea[kOutsideCoverage], 1);
    });

    test('its own position inside a district: "Near …", counted there', () {
      final fleet = _fleet(
        alerts: [_alert(lat: 14.6100, lng: 120.9950, at: alertAt)],
      );
      expect(fleet.alerts.single.address, 'Near Sampaloc');
      expect(fleet.alertsByArea['Sampaloc'], 1);
    });

    test('its own position outside every district: coordinates, Outside', () {
      final fleet = _fleet(
        alerts: [_alert(lat: 14.304159, lng: 121.123368, at: alertAt)],
      );
      expect(
        fleet.alerts.single.address,
        '14.30416, 121.12337 · Outside coverage',
      );
      expect(fleet.alertsByArea[kOutsideCoverage], 1);
    });
  });

  test('the trail is seeded from history, in time order, without repeats', () {
    final t0 = DateTime.utc(2026, 10, 30, 6);
    final fleet = _fleet(telemetry: [_helmet()]);
    _repo.history.add({
      'tracker-001': [
        HelmetFix(lat: 14.60, lng: 121.00, at: t0, source: PositionSource.trackingLogs),
        HelmetFix(
          lat: 14.60,
          lng: 121.00,
          at: t0.add(const Duration(minutes: 5)),
          source: PositionSource.tracking,
        ),
        HelmetFix(
          lat: 14.61,
          lng: 121.01,
          at: t0.add(const Duration(minutes: 10)),
          source: PositionSource.gpsLogs,
        ),
      ],
    });
    final trail = fleet.trailFor('R-001');
    expect(trail.map((p) => p.lat), [14.60, 14.61, 14.6091]);
    expect(trail.first.at, t0);
  });

  group('helmet events', () {
    HelmetEvent event({String? riderId = 'R-001', DateTime? at}) => HelmetEvent(
      id: 'tracker-001_1793352323540',
      deviceId: 'tracker-001',
      kind: HelmetEventKind.crash,
      at: at ?? DateTime.now(),
      detail: 'Crash alert: abnormal posture persisted 12 minutes',
      riderId: riderId,
    );

    test('are shown until an alert covers them', () {
      final fleet = _fleet();
      _repo.events.add([event()]);
      expect(fleet.helmetEvents.single.riderName, 'Rider R-001');

      // Opened: an alert with the event's own id.
      _repo.alerts.add([
        _alert(id: 'tracker-001_1793352323540', at: DateTime.now()),
      ]);
      expect(fleet.helmetEvents, isEmpty);
    });

    test('a Firestore alert of the same type within 5 minutes covers it', () {
      final now = DateTime.now();
      final fleet = _fleet();
      _repo.events.add([event(at: now)]);
      _repo.alerts.add([
        _alert(id: 'k3F9q', at: now.add(const Duration(minutes: 2))),
      ]);
      expect(fleet.helmetEvents, isEmpty);

      _repo.alerts.add([
        _alert(id: 'k3F9q', at: now.add(const Duration(minutes: 20))),
      ]);
      expect(fleet.helmetEvents, hasLength(1));
    });

    test('open as alert goes through the feed; no rider is refused', () async {
      final fleet = _fleet();
      final id = await fleet.openHelmetEventAsAlert(event(), actor: 'Ops');
      expect(id, 'tracker-001_1793352323540');
      expect(_repo.opened, ['tracker-001_1793352323540 by Ops']);
      expect(
        () => fleet.openHelmetEventAsAlert(event(riderId: null), actor: 'Ops'),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('the RTDB link is passed through for the top bar', () {
    final fleet = _fleet();
    expect(fleet.rtdbLink.state, RtdbLinkState.notConfigured);
    _repo.rtdb.add(
      const RtdbLink(RtdbLinkState.denied, 'permission_denied at /deviceStatus'),
    );
    expect(fleet.rtdbLink.state, RtdbLinkState.denied);
    expect(fleet.rtdbLink.message, contains('permission_denied'));
  });
}
