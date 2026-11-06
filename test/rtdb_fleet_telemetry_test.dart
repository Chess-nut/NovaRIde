// The console reads helmets on the Realtime Database firmware (camelCase
// nodes, merged by lib/admin/data/rtdb_fleet_merge.dart) into the same
// HelmetTelemetry the fleet table renders. Two things must hold: a reading
// the helmet did not send is a dash, never 0; and a helmet with no rider
// assigned is shown as an unassigned row, not hidden.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/admin/data/firestore_fleet_repository.dart';
import 'package:novaride/admin/data/rtdb_fleet_merge.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/widgets/fleet_table.dart';
import 'package:novaride/shared/models/models.dart';

final _now = DateTime(2026, 10, 30, 14);
final _nowMs = _now.millisecondsSinceEpoch;

/// deviceStatus/tracker-001 as the firmware writes it today.
Map<String, dynamic> _status() => {
  'deviceId': 'tracker-001',
  'online': true,
  'accelerometerReady': true,
  'accelMagnitudeG': 1.012,
  'mq3Raw': 734,
  'mq3Voltage': 0.592,
  'alcoholRelativeIndex': 734.0,
  'alcoholAlert': true,
  'sw420Active': false,
  'tiltDegrees': 3.1,
  'orientation': 'upright',
  'cellularDataReady': true,
  'lastSeen': _nowMs - 20000,
};

/// devices/tracker-001/latest.
Map<String, dynamic> _fix({int ageMs = 60000}) => {
  'lat': 14.6091,
  'lng': 121.0223,
  'speedKmph': 23.4,
  'satellites': 7,
  'gpsAgeMs': 900,
  'serverTime': _nowMs - ageMs,
};

HelmetTelemetry _map({
  String? riderId,
  Map<String, dynamic>? status,
  Map<String, dynamic>? fix,
}) => mergeFleetNodes(
  deviceId: 'tracker-001',
  riderId: riderId,
  status: status ?? _status(),
  device: {'latest': fix ?? _fix()},
  now: _now,
)!;

void main() {
  test('uses the explicit asia-southeast1 database URL', () {
    expect(
      FirestoreFleetRepository.helmetDatabaseUrl,
      'https://novaride-7a68c-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  });

  group('RTDB mapping', () {
    test('maps the camelCase fields onto the console model', () {
      final t = _map();
      expect(t.deviceId, 'tracker-001');
      expect(t.riderId, isNull);
      expect(t.accelMagnitudeG, closeTo(1.012, 1e-9));
      expect(t.alcoholRawIndex, 734);
      expect(t.mq3Raw, 734);
      expect(t.mq3Voltage, closeTo(0.592, 1e-9));
      expect(t.alcoholDetected, isTrue, reason: "the firmware's own verdict");
      expect(t.sw420Active, isFalse);
      expect(t.tiltDegrees, closeTo(3.1, 1e-9));
      expect(t.orientation, 'upright');
      expect(t.cellularDataReady, isTrue);
      expect(t.online, isTrue);
      expect(t.speedKmh, closeTo(23.4, 1e-9));
      expect(t.lat, closeTo(14.6091, 1e-9));
      expect(t.lng, closeTo(121.0223, 1e-9));
      expect(t.satellites, 7);
      expect(t.positionSource, PositionSource.latest);
      expect(t.gpsFix, isTrue);
      expect(
        t.lastUpdate!.isAtSameMomentAs(
          DateTime.fromMillisecondsSinceEpoch(_nowMs - 20000),
        ),
        isTrue,
      );
    });

    test('battery is not sent by this firmware, so it is null — not 0', () {
      expect(_map().batteryPct, isNull);
      expect(_map().batteryLabel, '—');
    });

    test('the alcohol index is labelled raw, never as a concentration', () {
      for (final label in [_map().alcoholRawLabel, _map().alcoholThresholdLabel]) {
        expect(label, contains('aw'));
        expect(label, isNot(contains('mg')));
        expect(label, isNot(contains('%')));
        expect(label, isNot(contains('BAC')));
      }
    });

    test('no fix node: no position, no speed, no fix', () {
      final t = mergeFleetNodes(
        deviceId: 'tracker-001',
        status: _status(),
        now: _now,
      )!;
      expect(t.lat, isNull);
      expect(t.lng, isNull);
      expect(t.speedKmh, isNull);
      expect(t.gpsFix, isFalse);
      expect(t.speedLabel, '—');
      expect(t.coordinatesLabel, 'No position');
    });

    test('a stale fix keeps its position but drops speed', () {
      final t = _map(
        fix: _fix(ageMs: const Duration(minutes: 20).inMilliseconds),
      );
      expect(t.lat, isNotNull);
      expect(t.gpsFix, isFalse);
      expect(t.speedKmh, isNull);
    });

    test('a 0,0 position before the first fix is not a position at all', () {
      final t = _map(fix: {..._fix(), 'lat': 0, 'lng': 0});
      expect(t.lat, isNull, reason: 'never a marker in the Atlantic');
      expect(t.gpsFix, isFalse);
      expect(t.speedKmh, isNull);
    });

    test('accelerometer down: the 0.000 it sends is not a reading', () {
      final t = _map(
        status: {
          ..._status(),
          'accelerometerReady': false,
          'accelMagnitudeG': 0.0,
        },
      );
      expect(t.accelMagnitudeG, isNull);
    });

    test('missing sensors stay missing', () {
      final t = mergeFleetNodes(
        deviceId: 'tracker-001',
        status: const <String, dynamic>{},
        now: _now,
      )!;
      expect(t.alcoholDetected, isNull);
      expect(t.alcoholRawIndex, isNull);
      expect(t.lastUpdate, isNull);
      expect(t.alcoholLabel, 'Not measured');
      expect(t.alcoholThresholdLabel, '—');
      expect(t.vibrationLabel, '—');
      expect(t.tiltLabel, '—');
      expect(t.safetyEventLabel, '—');
    });

    test('a rider found by the join is carried through', () {
      expect(_map(riderId: 'R-001').riderId, 'R-001');
    });
  });

  testWidgets('the table shows dashes for missing readings, never 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rider = MockData.riders.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetTable(
            riders: [rider],
            telemetry: [
              HelmetTelemetry(
                riderId: rider.id,
                speedKmh: null,
                batteryPct: null,
                gpsFix: false,
                lat: null,
                lng: null,
                lastUpdate: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('0.0 km/h'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Not measured'), findsOneWidget);
  });

  testWidgets('a rider with no telemetry at all shows dashes, not 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetTable(
            riders: [MockData.riders.first],
            telemetry: const [],
          ),
        ),
      ),
    );

    expect(find.text('0.0 km/h'), findsNothing);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('an unassigned helmet is a row of its own, selectable by id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? selected;
    final t = _map();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetTable(
            riders: const [],
            telemetry: [t],
            unassigned: [t],
            onSelect: (id) => selected = id,
          ),
        ),
      ),
    );

    expect(find.text('Unassigned device'), findsOneWidget);
    expect(find.text('tracker-001'), findsOneWidget);
    expect(find.text('NO RIDER'), findsOneWidget);
    expect(find.text('23.4 km/h'), findsOneWidget);
    expect(find.text('Detected'), findsOneWidget);

    await tester.tap(find.text('tracker-001'));
    expect(selected, 'tracker-001');
  });
}
