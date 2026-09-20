import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/emergency_contact/data/emergency_contact_repository.dart';
import 'package:novaride/emergency_contact/models/rider_location.dart';

void main() {
  test('parses Firebase-style rider location data', () {
    final location = RiderLocation.fromMap('rider-001', {
      'latitude': 14.5995,
      'longitude': 120.9842,
      'speed': 42,
      'heading': 90,
      'timestamp': '2026-09-14T10:00:00Z',
      'status': 'RIDING',
      'address': 'EDSA, Quezon City',
    });

    expect(location.riderId, 'rider-001');
    expect(location.latitude, 14.5995);
    expect(location.speedKmh, 42);
    expect(location.heading, 90);
    expect(location.status, 'RIDING');
  });

  test('repository exposes only a permission-gated location stream', () async {
    final repository = EmergencyContactRepository();
    expect(repository.canMonitorLocation, isTrue);
    expect(await repository.watchRiderLocation().first, isA<RiderLocation>());
  });
}
