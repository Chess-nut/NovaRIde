import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/domain/models/rider_location.dart';

class FakeFamilyRepository implements FamilyRepository {
  FakeFamilyRepository({
    this.rider = const FamilyConnectedRider(
      id: 'R-001',
      name: 'Test Rider',
      relationship: 'Rider',
      avatarLetters: 'TR',
      status: FamilyRiderStatus.idle,
    ),
  });

  final FamilyConnectedRider? rider;

  @override
  Stream<FamilyConnectedRider?> watchRiderStatus() => Stream.value(rider);

  @override
  Stream<RiderLocation?> watchRiderLocation() => Stream.value(null);

  @override
  Stream<List<FamilyIncident>> watchIncidentHistory() =>
      Stream.value(const []);

  @override
  Stream<FamilyIncident?> watchActiveEmergency() => Stream.value(null);

  @override
  Stream<FamilyUserProfile> watchUserProfile() => Stream.value(
    const FamilyUserProfile(
      uid: 'uid-test',
      name: 'Test User',
      relationship: 'Family member',
      phoneNumber: '',
      email: 'test@example.test',
      connectedRider: '',
      familyId: 'R-001',
    ),
  );

  @override
  Stream<List<FamilyMember>> watchFamilyMembers() => Stream.value(
    const [
      FamilyMember(
        uid: 'uid-test',
        displayName: 'Test User',
        role: 'guardian',
        status: 'active',
        permissions: {
          'liveLocation': true,
          'emergencyAlerts': true,
          'tripStatus': true,
          'helmetStatus': true,
          'incidentHistory': true,
        },
      ),
    ],
  );

  @override
  Stream<List<FamilyPermission>> watchMyPermissions() => Stream.value(
    const [
      FamilyPermission(
        type: FamilyPermissionType.liveLocation,
        label: 'Live Location',
        enabled: true,
      ),
      FamilyPermission(
        type: FamilyPermissionType.emergencyAlerts,
        label: 'Emergency Alerts',
        enabled: true,
      ),
      FamilyPermission(
        type: FamilyPermissionType.tripStatus,
        label: 'Trip Status',
        enabled: true,
      ),
      FamilyPermission(
        type: FamilyPermissionType.helmetStatus,
        label: 'Helmet Status',
        enabled: true,
      ),
      FamilyPermission(
        type: FamilyPermissionType.incidentHistory,
        label: 'Incident History',
        enabled: true,
      ),
    ],
  );

  @override
  Future<String> createInvite({String? invitedEmail}) async => 'TEST-CODE';

  @override
  Future<void> acceptInvite(String code) async {}

  @override
  Future<void> setMemberPermission(
    String memberUid,
    FamilyPermissionType permission,
    bool enabled,
  ) async {}

  @override
  Future<void> setNotificationSetting(String setting, bool enabled) async {}

  @override
  Future<void> revokeMember(String memberUid) async {}

  @override
  Future<void> leaveFamily() async {}

  @override
  Future<void> signOut() async {}
}
