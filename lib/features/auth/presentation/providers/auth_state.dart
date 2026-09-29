/// The session, as the router sees it.
///
/// Phase 1 ships a placeholder: no Firebase, no persistence, nothing that
/// can actually sign anybody in. That is on purpose. The shape below is
/// what the router redirects on, so the splash → auth gate → role home
/// behaviour can be built and tested now and still be correct when Phase 3
/// puts a real [AuthRepository] behind it. Phase 3 replaces the body of
/// [AuthController] and nothing else in this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Placeholder implementation.
///
/// It resolves to signed-out and stays there. The mutators exist so a
/// widget test can drive the router through the states the real thing will
/// produce; no screen calls them, because no screen can sign in yet.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Phase 3: subscribe to AuthRepository.authStateChanges() here and let
    // the first event replace this. Resolving synchronously for now means
    // the splash screen is passed through in one frame rather than hung
    // on, which keeps the existing boot behaviour — straight to Welcome.
    return const AuthState.signedOut();
  }

  /// Puts the session back to "not known yet". What a cold start looks
  /// like before the stored session has been read.
  void markUnknown() => state = const AuthState.unknown();

  void signedIn(UserProfile profile) => state = AuthState.signedIn(profile);

  void awaitingVerification(UserProfile profile) =>
      state = AuthState.awaitingVerification(profile);

  void signedOut() => state = const AuthState.signedOut();
}
