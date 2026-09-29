/// Everything the app can ask of the identity provider.
///
/// Interface only — Phase 1 ships no implementation. Phase 3 adds the
/// Firebase one behind it. The point of writing it now is that the router,
/// the providers and the screens can all be built and tested against this
/// shape, and the day Firebase arrives nothing above this line changes.
///
/// **Contract for every method:** on failure, throw a
/// `Failure` from `core/errors/failure.dart` — never a `FirebaseException`,
/// never a bare `Exception`. Implementations catch at this boundary and map
/// with `failureFrom`. Callers may assume the `message` on what they catch
/// is fit to show.
library;

import '../entities/user_profile.dart';
import '../entities/user_role.dart';

abstract interface class AuthRepository {
  /// The current account, or null when signed out.
  ///
  /// Emits on sign-in, on sign-out — including a sign-out the SDK performs
  /// itself when a refresh token is revoked — and on session restore at
  /// launch. It does **not** emit on a routine hourly token refresh.
  ///
  /// The first event may take a moment at launch while the stored session
  /// is read; until it arrives the app is on the splash screen.
  Stream<UserProfile?> authStateChanges();

  /// The account right now, without waiting for the stream. Null when
  /// signed out or when the session has not been restored yet.
  UserProfile? get currentUser;

  /// Email and password. [email] is trimmed by the implementation.
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });

  /// Username and password. Resolves the username to an email through
  /// `usernames/{usernameLower}` first, then signs in. A username that does
  /// not exist and a wrong password must fail identically — see the
  /// enumeration note in `core/errors/firebase_failure_mapper.dart`.
  Future<UserProfile> signInWithUsername({
    required String username,
    required String password,
  });

  /// Creates the account, claims the username and writes the profile
  /// documents. All of it or none of it: a uid with no `users/` document,
  /// or a username claimed for an account that was never created, is worse
  /// than a failed sign-up.
  ///
  /// The new account is signed in and unverified; the caller is expected to
  /// land on the verify-email screen.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
  });

  /// True when nothing holds [username] yet. Case-insensitive. For the
  /// live check on the sign-up form; [signUp] re-checks inside its
  /// transaction, because anything checked before a write can be taken
  /// between the two.
  Future<bool> isUsernameAvailable(String username);

  /// Sends the verification email to the signed-in account. Throws if
  /// nobody is signed in.
  Future<void> sendEmailVerification();

  /// Re-reads the account from the provider so a verification completed in
  /// a browser is noticed. Returns the refreshed profile.
  Future<UserProfile> reloadUser();

  /// Sends a password-reset email. Completes normally for an address that
  /// has no account: telling the caller which is which would make this an
  /// account-enumeration oracle.
  Future<void> sendPasswordResetEmail(String email);

  /// Edits the displayable fields of `users/{uid}`.
  ///
  /// Deliberately cannot touch `email`, `username` or `role`. The
  /// rules refuse all three — an email change belongs to Firebase Auth,
  /// a username is claimed under `usernames/` and nothing there can be
  /// transferred, and a role decides what the account may reach. A form
  /// offering those fields would fail on save, so it must not offer
  /// them.
  ///
  /// Passing null leaves a field alone; passing an empty string clears
  /// it. Returns the profile as it now stands.
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
  });

  Future<void> signOut();
}
