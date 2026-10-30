// The auth screens against a repository.
//
// Phase 2 tested these forms against a hardcoded credential. Phase 3 put
// a real AuthRepository behind them, so they are driven through
// FakeAuthRepository instead — the same interface the Firebase one
// implements, with none of the network.
//
// Three of these still pin down things that were wrong or missing before
// Phase 2: an errorStyle that could collapse and hide the message,
// validation that only ran on submit, and fields a password manager could
// not fill.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/pages/login_page.dart';
import 'package:novaride/features/auth/presentation/pages/verify_email_page.dart';
import 'package:novaride/features/guardian/presentation/pages/family_dashboard_page.dart';
import 'package:novaride/features/rider/presentation/pages/home_page.dart';

import 'support/fake_auth_repository.dart';
import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  final rider = UserProfile(
    uid: 'uid-rider',
    email: 'rider@example.test',
    username: 'riderone',
    fullName: 'Rider One',
    role: UserRole.rider,
    emailVerified: true,
  );
  final guardian = rider.copyWith(
    uid: 'uid-guardian',
    email: 'guardian@example.test',
    username: 'guardianone',
    role: UserRole.guardian,
  );

  FakeAuthRepository repositoryWith({Failure? failWith}) => FakeAuthRepository(
    accounts: {
      'rider@example.test': ('rider123', rider),
      'guardian@example.test': ('guard123', guardian),
    },
    usernames: const {
      'riderone': 'rider@example.test',
      'guardianone': 'guardian@example.test',
    },
    failWith: failWith,
  );

  Future<FakeAuthRepository> openLogin(
    WidgetTester tester, {
    Failure? failWith,
  }) async {
    final repository = repositoryWith(failWith: failWith);
    addTearDown(repository.dispose);
    await pumpMobileApp(tester, repository: repository);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    return repository;
  }

  group('login form — validation', () {
    testWidgets('does not complain before anything is typed', (tester) async {
      await openLogin(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Enter your password.'), findsNothing);
      expect(find.text('Enter your email address.'), findsNothing);
    });

    // autovalidateMode: onUserInteraction. The message has to appear once
    // a field has been touched, not only once the button is pressed.
    testWidgets('complains once a field has been touched and emptied', (
      tester,
    ) async {
      await openLogin(tester);

      final identifier = find.byType(TextFormField).first;
      await tester.enterText(identifier, 'a');
      await tester.pump();
      await tester.enterText(identifier, '');
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
    });

    // The message must be laid out, not clipped to nothing by an
    // errorStyle with no height — which is what the default was doing.
    testWidgets('renders the error message with a real size', (tester) async {
      await openLogin(tester);

      final identifier = find.byType(TextFormField).first;
      await tester.enterText(identifier, 'a');
      await tester.pump();
      await tester.enterText(identifier, '');
      await tester.pumpAndSettle();

      final size = tester.getSize(find.text('Enter your email address.'));
      expect(size.height, greaterThan(8));
      expect(size.width, greaterThan(40));
    });

    testWidgets('offers the fields to a password manager', (tester) async {
      await openLogin(tester);

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.length, 2);
      expect(fields[0].autofillHints, contains(AutofillHints.email));
      expect(fields[1].autofillHints, contains(AutofillHints.password));
      expect(fields[0].textInputAction, TextInputAction.next);
      expect(fields[1].textInputAction, TextInputAction.done);
      expect(fields[1].obscureText, isTrue);
    });

    testWidgets('reveals and re-hides the password', (tester) async {
      await openLogin(tester);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isFalse,
      );

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isTrue,
      );
    });
  });

  group('login form — signing in', () {
    Future<void> submit(WidgetTester tester, String id, String password) async {
      await tester.enterText(find.byType(TextFormField).first, id);
      await tester.enterText(find.byType(TextFormField).last, password);
      await tester.tap(find.text('Log in').last);
      await tester.pumpAndSettle();
    }

    testWidgets('does not perform username login during the privacy rollout', (
      tester,
    ) async {
      final repository = await openLogin(tester);
      await submit(tester, 'riderone', 'rider123');

      expect(
        repository.calls,
        isNot(contains('signInWithEmail:riderone:rider')),
      );
      expect(
        find.text('That does not look like an email address.'),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('signs in by email', (tester) async {
      final repository = await openLogin(tester);
      await submit(tester, 'rider@example.test', 'rider123');

      expect(
        repository.calls,
        contains('signInWithEmail:rider@example.test:rider'),
      );
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Google sign-in uses the selected role for a new account', (
      tester,
    ) async {
      final repository = await openLogin(tester);
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      final googleButton = find.text('Continue with Google');
      await tester.ensureVisible(googleButton);
      await tester.pumpAndSettle();
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('signInWithGoogle:guardian'));
      expect(find.byType(FamilyDashboardPage), findsOneWidget);
    });

    // The role comes from the account, not from the toggle on the form.
    testWidgets('a guardian lands on the family dashboard', (tester) async {
      await openLogin(tester);
      await submit(tester, 'guardian@example.test', 'guard123');

      expect(find.byType(FamilyDashboardPage), findsOneWidget);
    });

    testWidgets('passes selected role for missing-profile recovery', (
      tester,
    ) async {
      final repository = await openLogin(tester);
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await submit(tester, 'guardian@example.test', 'guard123');

      expect(
        repository.calls,
        contains('signInWithEmail:guardian@example.test:guardian'),
      );
      expect(find.byType(FamilyDashboardPage), findsOneWidget);
    });

    testWidgets('a wrong password stays put and says so', (tester) async {
      await openLogin(tester);
      await submit(tester, 'rider@example.test', 'wrongpass1');

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('an unknown email gets the standard credential message', (
      tester,
    ) async {
      await openLogin(tester);
      await submit(tester, 'nobody@example.test', 'rider123');

      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('a network failure says so instead', (tester) async {
      await openLogin(
        tester,
        failWith: const NetworkFailure(
          'No connection to NovaRide. Check your internet and try again.',
        ),
      );
      await submit(tester, 'rider@example.test', 'rider123');

      expect(
        find.text(
          'No connection to NovaRide. Check your internet and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsOneWidget);
    });

    // An unverified account is held on verify-email by the router's gate,
    // not by anything the login screen does.
    testWidgets('an unverified account lands on verify email', (tester) async {
      final unverified = rider.copyWith(emailVerified: false);
      final repository = FakeAuthRepository(
        accounts: {'rider@example.test': ('rider123', unverified)},
        usernames: const {'riderone': 'rider@example.test'},
      );
      addTearDown(repository.dispose);

      await pumpMobileApp(tester, repository: repository);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await submit(tester, 'rider@example.test', 'rider123');

      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });

  group('verify email', () {
    Future<FakeAuthRepository> openVerify(WidgetTester tester) async {
      final unverified = rider.copyWith(emailVerified: false);
      final repository = FakeAuthRepository(
        accounts: {'rider@example.test': ('rider123', unverified)},
        usernames: const {'riderone': 'rider@example.test'},
      );
      addTearDown(repository.dispose);
      await pumpMobileApp(tester, repository: repository);
      repository.emit(unverified);
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('names the address the link went to', (tester) async {
      await openVerify(tester);
      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.textContaining('rider@example.test'), findsOneWidget);
    });

    testWidgets('re-sends the link', (tester) async {
      final repository = await openVerify(tester);

      await tester.tap(find.text('Send the link again'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('sendEmailVerification'));
      expect(find.textContaining('Check your inbox'), findsOneWidget);
    });

    testWidgets('says so when the address is still unconfirmed', (
      tester,
    ) async {
      final repository = await openVerify(tester);

      await tester.tap(find.text('I have confirmed it'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('reloadUser'));
      expect(find.textContaining('Not confirmed yet'), findsOneWidget);
      expect(find.byType(VerifyEmailPage), findsOneWidget);
    });

    // Otherwise the screen is a trap for anyone who mistyped their
    // address at sign-up.
    testWidgets('signing out is possible from here', (tester) async {
      final repository = await openVerify(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('signOut'));
      expect(find.byType(VerifyEmailPage), findsNothing);
    });
  });
}
