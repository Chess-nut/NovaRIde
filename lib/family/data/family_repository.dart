import 'dart:async';

import 'package:novaride/family/models/family_models.dart';

/// Firebase-backed repository seam for the Family Module.
///
/// The current project does not yet include Firebase packages or Firestore
/// collections, so this service exposes the exact contract the UI expects while
/// returning realistic mock data. Replace the mock methods with Firestore
/// snapshots and stream subscriptions when the real backend is connected.
class FamilyRepository {
  FamilyRepository._();

  static final FamilyRepository _instance = FamilyRepository._();

  factory FamilyRepository() => _instance;

  final StreamController<FamilyConnectedRider> _riderStreamController =
      StreamController<FamilyConnectedRider>.broadcast();

  final List<FamilyIncident> _incidentHistory = [
    FamilyIncident(
      id: 'inc-001',
      title: 'Minor Impact',
      location: 'EDSA, Quezon City',
      timestamp: DateTime(2026, 5, 24, 15, 45),
      status: 'Resolved',
      severity: 'Low',
      riderStatus: 'Safe',
      incidentType: 'Impact',
      gpsInfo: '14.5995° N / 120.9842° E',
      sosTriggered: false,
      riderCancelledAlert: true,
      durationLabel: '00:03:12',
    ),
    FamilyIncident(
      id: 'inc-002',
      title: 'GPS Signal Lost',
      location: 'Metro Manila',
      timestamp: DateTime(2026, 5, 15, 18, 30),
      status: 'Resolved',
      severity: 'Medium',
      riderStatus: 'Safe',
      incidentType: 'Location',
      gpsInfo: '14.6091° N / 120.9829° E',
      sosTriggered: false,
      riderCancelledAlert: false,
      durationLabel: '00:12:40',
    ),
    FamilyIncident(
      id: 'inc-003',
      title: 'Alcohol Warning',
      location: 'Caloocan',
      timestamp: DateTime(2026, 5, 10, 2, 20),
      status: 'Warning',
      severity: 'High',
      riderStatus: 'Warning',
      incidentType: 'Alcohol',
      gpsInfo: '14.7705° N / 120.9717° E',
      sosTriggered: false,
      riderCancelledAlert: false,
      durationLabel: '00:02:09',
    ),
  ];

  final List<FamilyPermission> _riderPermissions = [
    const FamilyPermission(type: FamilyPermissionType.liveLocation, label: 'Live Location', enabled: true),
    const FamilyPermission(type: FamilyPermissionType.emergencyAlerts, label: 'Emergency Alerts', enabled: true),
    const FamilyPermission(type: FamilyPermissionType.tripStatus, label: 'Trip Status', enabled: true),
    const FamilyPermission(type: FamilyPermissionType.helmetStatus, label: 'Helmet Status', enabled: true),
    const FamilyPermission(type: FamilyPermissionType.incidentHistory, label: 'Incident History', enabled: true),
  ];

  FamilyConnectedRider _connectedRider = FamilyConnectedRider(
    id: 'rider-001',
    name: 'Juan dela Cruz',
    relationship: 'Rider',
    avatarLetters: 'JD',
    status: FamilyRiderStatus.riding,
    speedKmh: 42,
    tripDurationMinutes: 23,
    destination: 'Quezon City',
    address: 'EDSA, Quezon City',
    batteryPct: 87,
    helmetConnected: true,
    gpsActive: true,
    internetConnected: true,
    impactNormal: true,
    alcoholSafe: true,
    gpsLocked: true,
    isCurrentlyRiding: true,
    lastUpdatedSeconds: 2,
    latitude: 14.5995,
    longitude: 120.9842,
    heading: 'NNE',
    lastUpdated: DateTime(2026, 9, 8, 10, 56, 30),
    activeEmergency: false,
  );

  FamilyConnectedRider get connectedRider => _connectedRider;

  List<FamilyIncident> get incidentHistory => List.unmodifiable(_incidentHistory);

  List<FamilyPermission> get riderPermissions => List.unmodifiable(_riderPermissions);

  bool get hasActiveEmergency =>
      _connectedRider.status == FamilyRiderStatus.accidentDetected ||
      _connectedRider.status == FamilyRiderStatus.sosActive;

  Stream<FamilyConnectedRider> watchRiderStatus() {
    _riderStreamController.add(_connectedRider);
    return _riderStreamController.stream;
  }

  void updateRiderStatus(FamilyRiderStatus status) {
    _connectedRider = _connectedRider.copyWith(
      status: status,
      activeEmergency: status == FamilyRiderStatus.accidentDetected || status == FamilyRiderStatus.sosActive,
      lastUpdatedSeconds: 2,
      lastUpdated: DateTime.now(),
    );
    _riderStreamController.add(_connectedRider);
  }

  void simulateEmergency() {
    updateRiderStatus(FamilyRiderStatus.accidentDetected);
  }

  void resolveEmergency() {
    updateRiderStatus(FamilyRiderStatus.resolved);
  }

  void dispose() {
    _riderStreamController.close();
  }
}
