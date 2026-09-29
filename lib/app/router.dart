/// The mobile app's routing table and its one auth gate.
///
/// Shape: **splash → auth gate → role home.** The splash is where the app
/// sits while the session is still unknown; the gate decides, once it is
/// known, whether the viewer belongs in the signed-out screens or in their
/// role's home. Both halves are driven by [authStateProvider], which is a
/// placeholder in Phase 1 — which is the point: the redirect is finished
/// and testable before real auth exists, so Phase 3 is a change of one
/// provider rather than a change of navigation.
///
/// The moved screens still navigate imperatively
/// (`Navigator.push(MaterialPageRoute(...))`). That keeps working: those
/// pushes go onto the root navigator this router owns. Only the guardian
/// bottom bar had to change, because it used named routes, which need a
/// table `MaterialApp.router` does not have.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../core/utils/app_logger.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/guardian/presentation/pages/family_dashboard_page.dart';
import '../features/guardian/presentation/pages/family_emergency_alert_page.dart';
import '../features/guardian/presentation/pages/family_incident_history_page.dart';
import '../features/guardian/presentation/pages/family_live_location_page.dart';
import '../features/guardian/presentation/pages/family_monitoring_page.dart';
import '../features/guardian/presentation/pages/family_profile_page.dart';
import '../features/onboarding/presentation/pages/role_selection_page.dart';
import '../features/onboarding/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/welcome_page.dart';
import '../features/rider/presentation/pages/home_page.dart';

/// The app's [GoRouter].
///
/// Built once per [ProviderScope]. It re-runs its redirect whenever
/// [authStateProvider] changes, through a [ValueNotifier] bridge —
/// `go_router` wants a [Listenable] and Riverpod does not hand one out.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthState>(ref.read(authStateProvider));
  ref.onDispose(refresh.dispose);
  ref.listen<AuthState>(authStateProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: AppRoutes.splashPath,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref.read(authStateProvider), state),
    routes: _routes,
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

/// The auth gate.
///
/// Returns null to allow the requested location, or a path to send the
/// viewer somewhere else instead. Kept as a free function so a test can
/// call it with a state and a location and read the answer, without
/// pumping a widget.
@visibleForTesting
String? redirectFor(AuthState auth, String location) {
  // 1. Session not resolved yet — nowhere but the splash is meaningful.
  if (!auth.isResolved) {
    return location == AppRoutes.splashPath ? null : AppRoutes.splashPath;
  }

  // 2. Signed out — only the public screens. Anything else, including
  //    sitting on the splash after it resolves, goes to onboarding.
  if (!auth.isSignedIn) {
    if (location == AppRoutes.splashPath) return AppRoutes.onboardingPath;
    return AppRoutes.publicPaths.contains(location)
        ? null
        : AppRoutes.onboardingPath;
  }

  // 3. Signed in but unverified — held on verify-email, and nothing else
  //    is reachable. Without this an unverified account could simply
  //    navigate past the screen.
  if (auth.status == AuthStatus.awaitingEmailVerification) {
    return location == AppRoutes.verifyEmailPath
        ? null
        : AppRoutes.verifyEmailPath;
  }

  // 4. Signed in and verified. The signed-out screens and the splash are
  //    no longer somewhere to be; everything else is the role's own.
  final home = homePathFor(auth.role);
  if (location == AppRoutes.splashPath ||
      location == AppRoutes.verifyEmailPath ||
      AppRoutes.publicPaths.contains(location)) {
    return home;
  }
  return null;
}

/// Where a signed-in account belongs.
///
/// A null role should not happen — a resolved, signed-in [AuthState] always
/// carries a profile — but routing is the wrong place to throw, so it falls
/// back to the rider home and leaves a line in the log.
@visibleForTesting
String homePathFor(UserRole? role) {
  switch (role) {
    case UserRole.rider:
      return AppRoutes.riderHomePath;
    case UserRole.guardian:
      return AppRoutes.guardianHomePath;
    case null:
      AppLogger.w('Router: signed in with no role; defaulting to rider home.');
      return AppRoutes.riderHomePath;
  }
}

String? _redirect(AuthState auth, GoRouterState state) {
  final to = redirectFor(auth, state.uri.path);
  if (to != null) {
    AppLogger.d('Router: ${state.uri.path} -> $to (${auth.status.name})');
  }
  return to;
}

final List<RouteBase> _routes = [
  GoRoute(
    path: AppRoutes.splashPath,
    name: AppRoutes.splash,
    builder: (context, state) => const SplashPage(),
  ),
  GoRoute(
    path: AppRoutes.onboardingPath,
    name: AppRoutes.onboarding,
    builder: (context, state) => const WelcomePage(),
  ),
  GoRoute(
    path: AppRoutes.selectUserTypePath,
    name: AppRoutes.selectUserType,
    builder: (context, state) => const RoleSelectionPage(),
  ),
  GoRoute(
    path: AppRoutes.loginPath,
    name: AppRoutes.login,
    // `?role=guardian` so a deep link can land on the right copy. Anything
    // unrecognised falls back to rider, which is the screen's own default.
    builder: (context, state) => LoginPage(
      role: UserRole.fromWireName(state.uri.queryParameters['role']) ??
          UserRole.rider,
    ),
  ),
  GoRoute(
    path: AppRoutes.signupPath,
    name: AppRoutes.signup,
    builder: (context, state) => SignupPage(
      role: UserRole.fromWireName(state.uri.queryParameters['role']) ??
          UserRole.rider,
    ),
  ),
  GoRoute(
    path: AppRoutes.forgotPasswordPath,
    name: AppRoutes.forgotPassword,
    builder: (context, state) => const ForgotPasswordPage(),
  ),
  GoRoute(
    path: AppRoutes.verifyEmailPath,
    name: AppRoutes.verifyEmail,
    builder: (context, state) =>
        VerifyEmailPage(email: state.uri.queryParameters['email']),
  ),
  GoRoute(
    path: AppRoutes.riderHomePath,
    name: AppRoutes.riderHome,
    builder: (context, state) => const HomePage(),
  ),
  // The guardian section. The tabs are siblings rather than children
  // because the existing bottom bar replaces the whole screen on a tap
  // instead of nesting; a ShellRoute would change that behaviour, and
  // Phase 7 is where the family dashboards get reworked.
  GoRoute(
    path: AppRoutes.guardianHomePath,
    name: AppRoutes.guardianHome,
    builder: (context, state) => const FamilyDashboardPage(),
  ),
  GoRoute(
    path: AppRoutes.guardianMapPath,
    name: AppRoutes.guardianMap,
    builder: (context, state) => const FamilyLiveLocationPage(),
  ),
  GoRoute(
    path: AppRoutes.guardianAlertsPath,
    name: AppRoutes.guardianAlerts,
    builder: (context, state) => const FamilyEmergencyAlertPage(),
  ),
  GoRoute(
    path: AppRoutes.guardianHistoryPath,
    name: AppRoutes.guardianHistory,
    builder: (context, state) => const FamilyIncidentHistoryPage(),
  ),
  GoRoute(
    path: AppRoutes.guardianProfilePath,
    name: AppRoutes.guardianProfile,
    builder: (context, state) => const FamilyProfilePage(),
  ),
  GoRoute(
    path: AppRoutes.guardianMonitoringPath,
    name: AppRoutes.guardianMonitoring,
    builder: (context, state) => const FamilyMonitoringPage(),
  ),
];

/// Only reachable through a bad deep link — every in-app navigation goes
/// through [AppRoutes]. Says where it was asked to go, because a blank
/// screen here is the hardest kind of bug to report.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('That screen does not exist.'),
              const SizedBox(height: 8),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go(AppRoutes.splashPath),
                child: const Text('Start over'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
