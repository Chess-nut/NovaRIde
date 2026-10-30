/// Route names and paths for the mobile router, in one place.
///
/// `go_router` matches on paths but navigates most safely by name: a name is
/// checked against the route table at call time, so a renamed path does not
/// become a silent dead link. Both live here so the two can never drift.
library;

abstract final class AppRoutes {
  /// Decides where to send the viewer once the session is known. Never a
  /// destination anyone navigates to on purpose.
  static const splash = 'splash';
  static const splashPath = '/';

  /// The brand screen with GET STARTED and Log In. The first thing a signed
  /// -out visitor sees.
  static const onboarding = 'onboarding';
  static const onboardingPath = '/onboarding';

  static const selectUserType = 'selectUserType';
  static const selectUserTypePath = '/select-user-type';

  static const login = 'login';
  static const loginPath = '/login';

  static const signup = 'signup';
  static const signupPath = '/signup';

  static const forgotPassword = 'forgotPassword';
  static const forgotPasswordPath = '/forgot-password';

  /// Where a signed-in but unverified account is held. Phase 3 gives it a
  /// real "resend" action against Firebase Auth.
  static const verifyEmail = 'verifyEmail';
  static const verifyEmailPath = '/verify-email';

  static const riderHome = 'riderHome';
  static const riderHomePath = '/rider';

  static const guardianHome = 'guardianHome';
  static const guardianHomePath = '/guardian';

  /// The guardian tabs the existing bottom bar switches between. They hang
  /// off [guardianHomePath] so the section is one subtree.
  static const guardianMap = 'guardianMap';
  static const guardianMapPath = '/guardian/map';

  static const guardianAlerts = 'guardianAlerts';
  static const guardianAlertsPath = '/guardian/alerts';

  static const guardianHistory = 'guardianHistory';
  static const guardianHistoryPath = '/guardian/history';

  static const guardianProfile = 'guardianProfile';
  static const guardianProfilePath = '/guardian/profile';

  static const guardianConnect = 'guardianConnect';
  static const guardianConnectPath = '/guardian/connect';

  /// Reachable from the old route table but linked from nowhere in the UI.
  /// Carried over so the move to go_router drops no destination; Phase 7
  /// decides whether the screen survives.
  static const guardianMonitoring = 'guardianMonitoring';
  static const guardianMonitoringPath = '/guardian/monitoring';

  /// Paths a signed-out visitor is allowed to be on. Everything else
  /// redirects to [onboardingPath].
  static const publicPaths = <String>{
    splashPath,
    onboardingPath,
    selectUserTypePath,
    loginPath,
    signupPath,
    forgotPasswordPath,
  };
}
