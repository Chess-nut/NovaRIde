/// Everything the app can ask of the identity provider.
///
/// The Firebase implementation lives in the data layer; the interface keeps
/// screens and tests independent of Firebase.
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
  /// [role] is used only if this Auth account has no Firestore user profile;
  /// an existing profile's stored role is authoritative.
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
    required UserRole role,
  });

  /// Google OAuth. A new account is created with [role]; existing accounts
  /// keep the role already stored in their profile.
  Future<UserProfile> signInWithGoogle({required UserRole role});

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
