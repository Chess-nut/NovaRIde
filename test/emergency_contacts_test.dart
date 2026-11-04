// The rider's Emergency contacts: guardians in the app, invite codes, and
// saved phone contacts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/guardian/domain/entities/guardian_link.dart';
import 'package:novaride/features/rider/domain/entities/emergency_contact.dart';

import 'support/fake_emergency_contact_repository.dart';
import 'support/fake_guardian_link_repository.dart';
import 'support/mobile_app.dart';

final _rider = AuthState.signedIn(profileFor(UserRole.rider, uid: 'uid-rider'));

Future<void> _open(
  WidgetTester tester, {
  FakeGuardianLinkRepository? links,
  FakeEmergencyContactRepository? contacts,
}) async {
  await pumpMobileApp(
    tester,
    auth: _rider,
    guardianLinks: links,
    emergencyContacts: contacts,
  );
  await tester.tap(find.byIcon(Icons.person_outline).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Emergency contacts'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  silenceAppLogger();

  testWidgets('starts empty and says what each section is for',
      (tester) async {
    await _open(tester);

    expect(find.text('Guardians in the app'), findsOneWidget);
    expect(find.text('No guardians yet'), findsOneWidget);
    await tester.ensureVisible(find.text('No phone contacts'));
    expect(find.text('No phone contacts'), findsOneWidget);
    // The old page opened with the four developers as "Sibling".
    expect(find.textContaining('Legarde'), findsNothing);
  });

  testWidgets('lists the guardians who follow this rider', (tester) async {
    await _open(
      tester,
      links: FakeGuardianLinkRepository(guardians: const [
        GuardianLink(
          guardianUid: 'uid-g1',
          riderUid: 'uid-rider',
          guardianName: 'Maria Santos',
          relationship: 'Parent',
        ),
      ]),
    );

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Parent · sees your alerts and location'), findsOneWidget);
  });

  testWidgets('removes a guardian after a confirmation', (tester) async {
    final links = FakeGuardianLinkRepository(guardians: const [
      GuardianLink(
        guardianUid: 'uid-g1',
        riderUid: 'uid-rider',
        guardianName: 'Maria Santos',
        relationship: 'Parent',
      ),
    ]);
    await _open(tester, links: links);

    await _tap(tester, find.byTooltip('Remove Maria Santos'));
    expect(find.text('Remove Maria Santos?'), findsOneWidget);
    await _tap(tester, find.text('Remove'));

    expect(links.calls, contains('unlink:uid-g1'));
    expect(find.text('Maria Santos'), findsNothing);
  });

  testWidgets('makes an invite code and shows it with a countdown',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final links = FakeGuardianLinkRepository();
    await _open(tester, links: links);

    await _tap(tester, find.text('Invite a guardian'));

    expect(links.calls, contains('createInvite:uid-rider|Test Person'));
    expect(find.bySemanticsLabel('Invite code K 7 P 2 Q M'), findsOneWidget);
    expect(find.textContaining('Expires in'), findsWidgets);
    expect(find.text('Copy code'), findsOneWidget);

    await _tap(tester, find.text('Cancel this code'));
    expect(links.calls, contains('cancelInvite:K7P2QM'));
    semantics.dispose();
  });

  testWidgets('saves a phone contact', (tester) async {
    final contacts = FakeEmergencyContactRepository();
    await _open(tester, contacts: contacts);

    await _tap(tester, find.text('Add phone contact'));
    // The sheet's three fields, in order: name, relationship, phone.
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Lola Remedios');
    await tester.enterText(fields.at(1), 'Grandparent');
    await tester.enterText(fields.at(2), '09171234567');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Add contact'));

    expect(contacts.calls, contains('add:Lola Remedios|Grandparent|09171234567'));
    expect(find.text('Lola Remedios'), findsOneWidget);
  });

  testWidgets('lists saved phone contacts', (tester) async {
    await _open(
      tester,
      contacts: FakeEmergencyContactRepository(contacts: const [
        EmergencyContact(
          id: 'c1',
          name: 'Lola Remedios',
          relationship: 'Grandparent',
          phone: '09171234567',
        ),
      ]),
    );
    await tester.ensureVisible(find.text('Lola Remedios'));
    expect(find.text('Grandparent · 09171234567'), findsOneWidget);
  });
}
