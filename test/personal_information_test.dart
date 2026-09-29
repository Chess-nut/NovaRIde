// Personal Information reads and writes the real account record.
//
// It used to be pre-filled with the demo persona and its Save button
// waited 600ms and showed a snackbar. Now it fills from `users/{uid}`
// and saves back to it.
//
// The read-only fields are the interesting part. The rules make `email`
// and `username` immutable, so a form that let someone type into them
// would fail on save with a permission error and no way to understand
// why. The screen says so on the field instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/rider/presentation/pages/profile/personal_information.dart';

import 'support/fake_auth_repository.dart';
import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  const rider = UserProfile(
    uid: 'uid-rider',
    email: 'juan@example.test',
    username: 'juandc',
    fullName: 'Juan Dela Cruz',
    role: UserRole.rider,
    emailVerified: true,
    phoneNumber: '09171234567',
    address: 'Makati City',
  );

  Future<FakeAuthRepository> open(
    WidgetTester tester, {
    Failure? failWith,
    UserProfile profile = rider,
  }) async {
    final repository = FakeAuthRepository(
      accounts: {profile.email: ('rider123', profile)},
      failWith: failWith,
    );
    addTearDown(repository.dispose);
    await pumpMobileApp(tester, repository: repository);
    repository.emit(profile);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalInformationPage), findsOneWidget);
    return repository;
  }

  testWidgets('fills from the signed-in account', (tester) async {
    await open(tester);

    expect(find.text('Juan Dela Cruz'), findsWidgets);
    expect(find.text('09171234567'), findsOneWidget);
    expect(find.text('Makati City'), findsOneWidget);
    // Shown, but not in a field anyone can type into.
    expect(find.text('juandc'), findsOneWidget);
    expect(find.text('juan@example.test'), findsOneWidget);
    // None of the demo persona survives.
    expect(find.text('Deor the great'), findsNothing);
    expect(find.text('admin'), findsNothing);
    expect(find.text('deor.thegreat@email.com'), findsNothing);
  });

  // Three editable fields, not five. The rules refuse a change to email
  // or username, so offering them would be offering a failure.
  testWidgets('offers exactly the fields the rules let it change',
      (tester) async {
    await open(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Usernames cannot be changed.'), findsOneWidget);
    expect(find.text('Changing your email is not supported yet.'),
        findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
  });

  testWidgets('saves the three editable fields and leaves', (tester) async {
    final repository = await open(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Juana Dela Cruz');
    await tester.enterText(find.byType(TextFormField).at(1), '09181234567');
    await tester.enterText(find.byType(TextFormField).at(2), 'Taguig City');
    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(
      repository.calls,
      contains('updateProfile:Juana Dela Cruz|09181234567|Taguig City'),
    );
    expect(find.byType(PersonalInformationPage), findsNothing);
  });

  // Sign-up never asks for an address, so demanding one on a first edit
  // would block a save that changes something else entirely.
  testWidgets('accepts a blank address', (tester) async {
    final repository = await open(
      tester,
      profile: rider.copyWith(address: ''),
    );

    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(repository.calls.any((c) => c.startsWith('updateProfile')), isTrue);
  });

  testWidgets('refuses an invalid phone number before saving', (tester) async {
    final repository = await open(tester);

    await tester.enterText(find.byType(TextFormField).at(1), '12345');
    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mobile number like'), findsOneWidget);
    expect(repository.calls.any((c) => c.startsWith('updateProfile')), isFalse);
    expect(find.byType(PersonalInformationPage), findsOneWidget);
  });

  // A refused write stays on the form with the edit intact, rather than
  // popping and losing it.
  testWidgets('shows a failed save and stays put', (tester) async {
    await open(
      tester,
      failWith: const NetworkFailure(
        'No connection to NovaRide. Check your internet and try again.',
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Juana Dela Cruz');
    await tester.ensureVisible(find.text('SAVE CHANGES'));
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(
      find.text('No connection to NovaRide. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(find.byType(PersonalInformationPage), findsOneWidget);
  });
}
