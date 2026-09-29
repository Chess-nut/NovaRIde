// Sign-up, against a repository rather than a network.
//
// The screen's job after Phase 3 is narrow: validate, call signUp, and
// let the router's gate decide where that lands. It never navigates
// itself, which is what these assert.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/pages/signup_page.dart';
import 'package:novaride/features/auth/presentation/pages/verify_email_page.dart';

import 'support/fake_auth_repository.dart';
import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  Future<FakeAuthRepository> openSignup(
    WidgetTester tester, {
    Map<String, String> taken = const {},
    Failure? failWith,
  }) async {
    final repository = FakeAuthRepository(usernames: taken, failWith: failWith);
    addTearDown(repository.dispose);
    await pumpMobileApp(tester, repository: repository);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motorcycle Rider'));
    await tester.pumpAndSettle();
    // The link sits below the fold on a test-sized screen.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupPage), findsOneWidget);
    return repository;
  }

  Future<void> fillValid(WidgetTester tester, {String username = 'riderone'}) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Rider One');
    await tester.enterText(fields.at(1), username);
    await tester.enterText(fields.at(2), 'rider@example.test');
    await tester.enterText(fields.at(3), '09171234567');
    await tester.enterText(fields.at(4), 'rider123');
    await tester.enterText(fields.at(5), 'rider123');
    await tester.pump();
  }

  /// The tick sits near the bottom of a long form, so it has to be
  /// scrolled to before it is hit-testable.
  Future<void> tickConsent(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('refuses to submit without the consent tick', (tester) async {
    final repository = await openSignup(tester);
    await fillValid(tester);
    await submit(tester);

    expect(
      find.textContaining('accept the terms'),
      findsOneWidget,
    );
    expect(repository.calls.where((c) => c.startsWith('signUp')), isEmpty);
  });

  // The role comes from Select User Type and is carried through, not
  // asked for again on this screen.
  testWidgets('creates the account and lands on verify email', (tester) async {
    final repository = await openSignup(tester);
    await fillValid(tester);
    await tickConsent(tester);
    await submit(tester);

    expect(
      repository.calls,
      contains('signUp:rider@example.test:riderone:${UserRole.rider.wireName}'),
    );
    // A new account is unverified, so the gate holds it here rather than
    // letting it into the app.
    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.byType(SignupPage), findsNothing);
  });

  // A taken username belongs on the field, not in the banner — the thing
  // to fix is where the eye already is.
  testWidgets('puts a taken username on the field', (tester) async {
    await openSignup(tester, taken: const {'riderone': 'someone@example.test'});
    await fillValid(tester);
    await tickConsent(tester);
    await submit(tester);

    expect(find.text('That username is taken. Try another.'), findsOneWidget);
    expect(find.byType(SignupPage), findsOneWidget);
  });

  testWidgets('clears the taken-username error once the text changes',
      (tester) async {
    await openSignup(tester, taken: const {'riderone': 'someone@example.test'});
    await fillValid(tester);
    await tickConsent(tester);
    await submit(tester);
    expect(find.text('That username is taken. Try another.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'ridertwo');
    await tester.pumpAndSettle();

    expect(find.text('That username is taken. Try another.'), findsNothing);
  });

  testWidgets('shows a network failure in the banner', (tester) async {
    await openSignup(
      tester,
      failWith: const NetworkFailure(
        'No connection to NovaRide. Check your internet and try again.',
      ),
    );
    await fillValid(tester);
    await tickConsent(tester);
    await submit(tester);

    expect(
      find.text('No connection to NovaRide. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(find.byType(SignupPage), findsOneWidget);
  });

  testWidgets('enforces the password rule before calling the repository',
      (tester) async {
    final repository = await openSignup(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Rider One');
    await tester.enterText(fields.at(1), 'riderone');
    await tester.enterText(fields.at(2), 'rider@example.test');
    await tester.enterText(fields.at(4), 'password');
    await tester.enterText(fields.at(5), 'password');
    await tickConsent(tester);
    await submit(tester);

    expect(
      find.text('Use at least 8 characters, with a letter and a number.'),
      findsWidgets,
    );
    expect(repository.calls.where((c) => c.startsWith('signUp')), isEmpty);
  });
}
