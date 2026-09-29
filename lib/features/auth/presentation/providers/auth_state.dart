/// The session, as the router sees it.
///
/// Phase 3 put a real [AuthRepository] behind this. The shape below did
/// not change when it did — which was the point of building the router's
/// gate against it first: swapping the placeholder for Firebase was a
/// change to [AuthController.build] and nothing else.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';

/// Where the session is, as far as routing is concerned.
enum AuthStatus {
  /// The stored session has not been read yet. Distinct from
  /// [unauthenticated] because they route differently: this one waits on
  /// the splash screen, that one goes to onboarding. Collapsing the two is
  /// what makes an app flash its login screen on every cold start.
  unknown,

  unauthenticated,

  /// Signed in, but the email address has not been confirmed. Held on the
  /// verify-email screen rather than let into the app.
  awaitingEmailVerification,

  authenticated,
}

/// An immutable snapshot of the session.
class AuthState {
  const AuthState._(this.status, this.profile);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.signedOut() : this._(AuthStatus.unauthenticated, null);

  /// Signed in and verified.
  const AuthState.signedIn(UserProfile profile)
      : this._(AuthStatus.authenticated, profile);

  /// Signed in, waiting on the verification email.
  const AuthState.awaitingVerification(UserProfile profile)
      : this._(AuthStatus.awaitingEmailVerification, profile);

  /// Picks the right state for a profile, from whether Firebase Auth says
  /// the address is confirmed. One place, so the router and the screens
  /// cannot disagree about what "signed in" means.
  factory AuthState.forProfile(UserProfile? profile) {
    if (profile == null) return const AuthState.signedOut();
    return profile.emailVerified
        ? AuthState.signedIn(profile)
        : AuthState.awaitingVerification(profile);
  }

  final AuthStatus status;

  /// Null in [AuthStatus.unknown] and [AuthStatus.unauthenticated].
  final UserProfile? profile;

  bool get isResolved => status != AuthStatus.unknown;
  bool get isSignedIn =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.awaitingEmailVerification;

  /// Null until someone is signed in.
  UserRole? get role => profile?.role;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status && other.profile == profile;

  @override
  int get hashCode => Object.hash(status, profile);

  @override
  String toString() => 'AuthState(${status.name}, ${profile?.uid})';
}

/// The session the router reads.
///
/// Override it in a test to put the app in a given state:
///
/// ```dart
/// ProviderScope(
///   overrides: [authStateProvider.overrideWith(() => FakeAuth(state))],
///   child: const NovaRideApp(),
/// )
/// ```
final authStateProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Follows `AuthRepository.authStateChanges()`.
///
/// It starts [AuthStatus.unknown] and stays there until the first event
/// arrives, which is what holds the app on the splash screen while a
/// stored session is read instead of flashing the login screen at someone
/// who is already signed in.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);

    final subscription = repository.authStateChanges().listen(
      (profile) => state = AuthState.forProfile(profile),
      onError: (Object error, StackTrace stack) {
        // The stream failing is not the same as being signed out, but
        // there is nothing else the app can do with it, and leaving the
        // session `unknown` would hold everyone on the splash screen
        // forever.
        AppLogger.e('Auth stream failed', error: error, stackTrace: stack);
        state = const AuthState.signedOut();
      },
    );
    ref.onDispose(subscription.cancel);

    // Firebase answers immediately when it already knows, so this is the
    // cold-start case only.
    return const AuthState.unknown();
  }
}
