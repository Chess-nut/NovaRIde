import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/guardian/domain/models/rider_location.dart';

void main() {
  test('location readings do not invent missing telemetry', () {
    const location = RiderLocation(
      riderId: 'R-001',
      latitude: 14.5995,
      longitude: 120.9842,
      speedKmh: null,
      heading: null,
      timestamp: null,
      status: 'RIDING',
      address: null,
    );

    expect(location.riderId, 'R-001');
    expect(location.latitude, 14.5995);
    expect(location.speedKmh, isNull);
    expect(location.timestamp, isNull);
    expect(location.address, isNull);
  });
}
