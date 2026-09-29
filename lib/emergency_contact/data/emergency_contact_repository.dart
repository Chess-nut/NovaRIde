import 'dart:async';
import 'package:novaride/emergency_contact/models/emergency_contact_models.dart';
import 'package:novaride/emergency_contact/models/rider_location.dart';

class EmergencyContactRepository {
  EmergencyContactRepository._();
  static final EmergencyContactRepository _instance = EmergencyContactRepository._();
  factory EmergencyContactRepository() => _instance;

  final _riderController = StreamController<ConnectedRider>.broadcast();
  final _incidents = <Incident>[
    Incident(id: 'inc-001', title: 'Minor Impact', location: 'EDSA, Quezon City', timestamp: DateTime(2026, 5, 24, 15, 45), status: 'Resolved', severity: 'Low', riderStatus: 'Safe', incidentType: 'Impact', gpsInfo: '14.5995° N / 120.9842° E', sosTriggered: false, riderCancelledAlert: true, durationLabel: '00:03:12'),
    Incident(id: 'inc-002', title: 'GPS Signal Lost', location: 'Metro Manila', timestamp: DateTime(2026, 5, 15, 18, 30), status: 'Resolved', severity: 'Medium', riderStatus: 'Safe', incidentType: 'Location', gpsInfo: '14.6091° N / 120.9829° E', sosTriggered: false, riderCancelledAlert: false, durationLabel: '00:12:40'),
    Incident(id: 'inc-003', title: 'Alcohol Warning', location: 'Caloocan', timestamp: DateTime(2026, 5, 10, 2, 20), status: 'Warning', severity: 'High', riderStatus: 'Warning', incidentType: 'Alcohol', gpsInfo: '14.7705° N / 120.9717° E', sosTriggered: false, riderCancelledAlert: false, durationLabel: '00:02:09'),
  ];
  final _permissions = <Permission>[
    const Permission(type: PermissionType.liveLocation, label: 'Live Location', enabled: true),
    const Permission(type: PermissionType.emergencyAlerts, label: 'Emergency Alerts', enabled: true),
    const Permission(type: PermissionType.tripStatus, label: 'Trip Status', enabled: true),
    const Permission(type: PermissionType.helmetStatus, label: 'Helmet Status', enabled: true),
    const Permission(type: PermissionType.incidentHistory, label: 'Incident History', enabled: true),
  ];

  ConnectedRider _rider = ConnectedRider(
    id: 'rider-001', name: 'Juan dela Cruz', relationship: 'Rider', avatarLetters: 'JD',
    status: RiderStatus.riding, speedKmh: 42, tripDurationMinutes: 23, destination: 'Quezon City',
    address: 'EDSA, Quezon City', batteryPct: 87, helmetConnected: true, gpsActive: true,
    internetConnected: true, impactNormal: true, alcoholSafe: true, gpsLocked: true,
    isCurrentlyRiding: true, lastUpdatedSeconds: 2, latitude: 14.5995, longitude: 120.9842,
    heading: 'NNE', lastUpdated: DateTime(2026, 9, 8, 10, 56, 30), activeEmergency: false,
  );

  ConnectedRider get connectedRider => _rider;
  List<Incident> get incidentHistory => List.unmodifiable(_incidents);
  List<Permission> get riderPermissions => List.unmodifiable(_permissions);
  bool get canMonitorLocation => _permissions.any((p) => p.type == PermissionType.liveLocation && p.enabled);
  bool get hasActiveEmergency => _rider.status == RiderStatus.accidentDetected || _rider.status == RiderStatus.sosActive;

  Stream<ConnectedRider> watchRiderStatus() {
    _riderController.add(_rider);
    return _riderController.stream;
  }

  Stream<RiderLocation> watchRiderLocation() async* {
    yield _locationFor(_rider);
    await for (final rider in _riderController.stream) {
      if (canMonitorLocation) yield _locationFor(rider);
    }
  }

  RiderLocation _locationFor(ConnectedRider rider) => RiderLocation(
    riderId: rider.id, latitude: rider.latitude, longitude: rider.longitude,
    speedKmh: rider.speedKmh, heading: _headingDegrees(rider.heading), timestamp: rider.lastUpdated,
    status: rider.status.label, address: rider.address,
  );

  double? _headingDegrees(String heading) => const <String, double>{'N': 0, 'NE': 45, 'E': 90, 'SE': 135, 'S': 180, 'SW': 225, 'W': 270, 'NW': 315}[heading.toUpperCase()];

  void updateRiderStatus(RiderStatus status) {
    _rider = _rider.copyWith(status: status, activeEmergency: status == RiderStatus.accidentDetected || status == RiderStatus.sosActive, lastUpdatedSeconds: 2, lastUpdated: DateTime.now());
    _riderController.add(_rider);
  }

  void simulateEmergency() => updateRiderStatus(RiderStatus.accidentDetected);
  void resolveEmergency() => updateRiderStatus(RiderStatus.resolved);
}
