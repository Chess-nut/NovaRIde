// The mobile auth gate.
//
// Phase 1 builds the splash -> gate -> role home shape on a placeholder
// session provider, so it can be pinned down before real auth arrives.
// These tests are what makes that worth doing: Phase 3 swaps the provider's
// implementation, and if the routing changes, this file says so.
//
// The first group calls the redirect directly — it is a pure function of
// (session, location), so it needs no widget tree. The second pumps the app
// to prove the wiring actually reaches it.

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/app/router.dart';
import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/pages/verify_email_page.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/guardian/presentation/pages/family_dashboard_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/splash_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:novaride/features/rider/presentation/pages/home_page.dart';

import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  final rider = profileFor(UserRole.rider);
  final guardian = profileFor(UserRole.guardian);

  group('redirect — session not resolved', () {
    const auth = AuthState.unknown();

    test('holds on the splash', () {
      expect(redirectFor(auth, AppRoutes.splashPath), isNull);
    });

    // Without this a cold start flashes the login screen before the stored
    // session has been read.
    test('pulls every other location back to the splash', () {
      for (final path in [
        AppRoutes.onboardingPath,
        AppRoutes.loginPath,
        AppRoutes.riderHomePath,
        AppRoutes.guardianHomePath,
      ]) {
        expect(redirectFor(auth, path), AppRoutes.splashPath, reason: path);
      }
    });
  });

  group('redirect — signed out', () {
    const auth = AuthState.signedOut();

    test('leaves the splash for onboarding once the session is known', () {
      expect(redirectFor(auth, AppRoutes.splashPath), AppRoutes.onboardingPath);
    });

    test('allows every public screen', () {
      for (final path in [
        AppRoutes.onboardingPath,
        AppRoutes.selectUserTypePath,
        AppRoutes.loginPath,
        AppRoutes.signupPath,
        AppRoutes.forgotPasswordPath,
      ]) {
        expect(redirectFor(auth, path), isNull, reason: path);
      }
    });

    test('refuses the role homes and the verify screen', () {
      for (final path in [
        AppRoutes.riderHomePath,
        AppRoutes.guardianHomePath,
        AppRoutes.guardianMapPath,
        AppRoutes.verifyEmailPath,
      ]) {
        expect(redirectFor(auth, path), AppRoutes.onboardingPath, reason: path);
      }
    });
  });

  group('redirect — signed in, email not confirmed', () {
    final auth = AuthState.awaitingVerification(rider);

    test('allows the verify screen', () {
      expect(redirectFor(auth, AppRoutes.verifyEmailPath), isNull);
    });

    // The screen is a hold, not a suggestion: an unverified account must
    // not be able to navigate around it.
    test('pulls everything else onto it, including the rider home', () {
      for (final path in [
        AppRoutes.splashPath,
        AppRoutes.onboardingPath,
        AppRoutes.loginPath,
        AppRoutes.riderHomePath,
        AppRoutes.guardianHomePath,
      ]) {
        expect(redirectFor(auth, path), AppRoutes.verifyEmailPath, reason: path);
      }
    });
  });

  group('redirect — signed in and confirmed', () {
    test('sends a rider to the rider home from every signed-out screen', () {
      final auth = AuthState.signedIn(rider);
      for (final path in [
        AppRoutes.splashPath,
        AppRoutes.onboardingPath,
        AppRoutes.loginPath,
        AppRoutes.signupPath,
        AppRoutes.verifyEmailPath,
      ]) {
        expect(redirectFor(auth, path), AppRoutes.riderHomePath, reason: path);
      }
    });

    test('sends a guardian to the guardian home', () {
      final auth = AuthState.signedIn(guardian);
      expect(redirectFor(auth, AppRoutes.loginPath), AppRoutes.guardianHomePath);
      expect(redirectFor(auth, AppRoutes.splashPath), AppRoutes.guardianHomePath);
    });

    test('allows any in-app screen to stay put', () {
      final auth = AuthState.signedIn(guardian);
      for (final path in [
        AppRoutes.guardianHomePath,
        AppRoutes.guardianMapPath,
        AppRoutes.guardianAlertsPath,
        AppRoutes.riderHomePath,
      ]) {
        expect(redirectFor(auth, path), isNull, reason: path);
      }
    });
  });

  group('homePathFor', () {
    test('maps each role to its home', () {
      expect(homePathFor(UserRole.rider), AppRoutes.riderHomePath);
      expect(homePathFor(UserRole.guardian), AppRoutes.guardianHomePath);
    });

    // Should be unreachable; routing is the wrong place to throw.
    test('falls back to the rider home when the role is missing', () {
      expect(homePathFor(null), AppRoutes.riderHomePath);
    });
  });

  group('the gate, through the app', () {
    testWidgets('an unresolved session stays on the splash', (tester) async {
      await pumpMobileApp(tester, auth: const AuthState.unknown(), settle: false);
      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('a signed-out session lands on welcome', (tester) async {
      await pumpMobileApp(tester, auth: const AuthState.signedOut());
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
    });

    testWidgets('a signed-in rider lands on the rider home', (tester) async {
      await pumpMobileApp(tester, auth: AuthState.signedIn(rider));
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('a signed-in guardian lands on the family dashboard',
        (tester) async {
      await pumpMobileApp(tester, auth: AuthState.signedIn(guardian));
      expect(find.byType(FamilyDashboardPage), findsOneWidget);
    });

    testWidgets('an unconfirmed account is held on verify email',
        (tester) async {
      await pumpMobileApp(tester, auth: AuthState.awaitingVerification(rider));
      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.text('Confirm your email'), findsOneWidget);
    });
  });
}
