// A helmet that sends no alcohol verdict is "Not measured". It used to read
// as 0.00, which a dispatcher takes for sober: the absence of a reading
// presented as a reading.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/widgets/fleet_table.dart';
import 'package:novaride/shared/models/models.dart';

HelmetTelemetry _telemetry(String riderId, bool? detected) => HelmetTelemetry(
      riderId: riderId,
      speedKmh: 0,
      alcoholDetected: detected,
      batteryPct: 80,
      gpsFix: true,
      lat: 14.6,
      lng: 121.0,
      lastUpdate: DateTime(2026, 10, 16),
    );

void main() {
  test('the readout has a state of its own for "not measured"', () {
    expect(_telemetry('R-001', null).alcoholLabel, 'Not measured');
    expect(_telemetry('R-001', false).alcoholLabel, 'Not detected');
    expect(_telemetry('R-001', true).alcoholLabel, 'Detected');
  });

  testWidgets('the fleet table never shows a missing reading as a number',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final riders = MockData.riders.take(3).toList();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FleetTable(
          riders: riders,
          telemetry: [
            _telemetry(riders[0].id, null),
            _telemetry(riders[1].id, false),
            _telemetry(riders[2].id, true),
          ],
        ),
      ),
    ));

    expect(find.text('Not measured'), findsOneWidget);
    expect(find.text('Not detected'), findsOneWidget);
    expect(find.text('Detected'), findsOneWidget);
    expect(find.text('0.00'), findsNothing);
  });
}
