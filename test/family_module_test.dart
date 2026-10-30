import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/domain/models/rider_location.dart';
import 'package:novaride/features/guardian/presentation/pages/family_dashboard_page.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';

void main() {
  testWidgets('Family dashboard renders core safety content', (tester) async {
    final repository = _FakeFamilyRepository(
      rider: const FamilyConnectedRider(
        id: 'R-001',
        name: 'Rider One',
        relationship: 'Rider',
        avatarLetters: 'RO',
        status: FamilyRiderStatus.riding,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FamilyDashboardPage(repository: repository)),
    );
    await tester.pump();

    expect(find.text('Family Safety'), findsOneWidget);
    expect(find.text('RIDER STATUS'), findsOneWidget);
    expect(find.text('CURRENT TRIP'), findsOneWidget);
    expect(find.text('LIVE LOCATION'), findsOneWidget);
    expect(find.text('Rider One'), findsOneWidget);
    expect(find.text('42 km/h'), findsNothing);
  });

  testWidgets('Family dashboard shows an honest empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDashboardPage(repository: _FakeFamilyRepository()),
      ),
    );

    await tester.pump();
    expect(find.text('No rider connected'), findsOneWidget);
    expect(find.text('Juan dela Cruz'), findsNothing);
  });

  testWidgets('Family bottom nav includes the required sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FamilyBottomNavBar(selectedIndex: 0),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

class _FakeFamilyRepository implements FamilyRepository {
  _FakeFamilyRepository({this.rider});

  final FamilyConnectedRider? rider;

  @override
  Stream<FamilyConnectedRider?> watchRiderStatus() => Stream.value(rider);

  @override
  Stream<RiderLocation?> watchRiderLocation() => Stream.value(null);

  @override
  Stream<List<FamilyIncident>> watchIncidentHistory() => Stream.value(const []);

  @override
  Stream<FamilyIncident?> watchActiveEmergency() => Stream.value(null);

  @override
  Stream<FamilyUserProfile> watchUserProfile() => Stream.value(
    const FamilyUserProfile(
      uid: 'uid',
      name: 'User',
      relationship: 'Guardian',
      phoneNumber: '',
      email: 'user@example.test',
      connectedRider: '',
    ),
  );

  @override
  Stream<List<FamilyMember>> watchFamilyMembers() => Stream.value(const []);

  @override
  Stream<List<FamilyPermission>> watchMyPermissions() => Stream.value(const []);

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
