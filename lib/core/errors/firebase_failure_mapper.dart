/// Turns a `firebase_auth` or `cloud_firestore` error into a [Failure] whose
/// message can go straight on screen.
///
/// Seeded from the admin console's `messageForFirebaseCode`, but the wording
/// is this app's: the console talks to three named operators who can ask a
/// Super Admin for help, and a rider or a guardian has nobody to ask. Every
/// sentence here either tells the person what to do next or admits the
/// problem is not theirs.
///
/// Two rules the mapper keeps:
///
/// 1. **Never return the code.** `[firebase_auth/invalid-credential]` on a
///    login screen is noise to everyone who is not us. The code belongs in
///    the log, which is why every [Failure] carries its `cause`.
/// 2. **Never let the message distinguish a wrong password from an unknown
///    email.** With email-enumeration protection on — the default for new
///    projects, and on for novaride-7a68c — Firebase reports both as
///    `invalid-credential` anyway; the older distinct codes are folded into
///    the same sentence so a project with it off does not quietly become an
///    account-enumeration oracle.
library;

import 'package:firebase_auth/firebase_auth.dart';

import 'failure.dart';

const String _fallbackMessage =
    'Something went wrong. Try again, and if it keeps happening, check your '
    'connection first.';

/// Maps any thrown object to a [Failure]. Anything that is already a
/// [Failure] passes through, so a mapper at an outer layer is harmless.
Failure failureFrom(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;
  if (error is FirebaseException) {
    return failureForCode(error.code, cause: error, stackTrace: stackTrace);
  }
  return UnexpectedFailure(
    _fallbackMessage,
    cause: error,
    stackTrace: stackTrace,
  );
}

/// The mapping itself, exposed by code so it can be tested without
/// constructing a [FirebaseException].
Failure failureForCode(String code, {Object? cause, StackTrace? stackTrace}) {
  return switch (code) {
    // ---- credentials, sign-in -------------------------------------------
    // One sentence for a wrong password and an unknown email, on purpose.
    'wrong-password' ||
    'user-not-found' ||
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'INVALID_LOGIN_CREDENTIALS' => AuthFailure(
      'Incorrect email or password.',
      cause: cause,
      stackTrace: stackTrace,
    ),
    'invalid-email' => const ValidationFailure(
      'That is not a valid email address.',
      field: 'email',
    ),
    'missing-password' => const ValidationFailure(
      'Enter your password.',
      field: 'password',
    ),
    'user-disabled' => AuthFailure(
      'This account has been turned off. Contact NovaRide support to get '
      'it back.',
      cause: cause,
      stackTrace: stackTrace,
    ),
    'too-many-requests' => AuthFailure(
      'Too many attempts. Wait a few minutes before trying again.',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // ---- credentials, sign-up -------------------------------------------
    'email-already-in-use' => const ValidationFailure(
      'An account already uses that email address. Log in instead, or '
      'reset the password.',
      field: 'email',
    ),
    'weak-password' => const ValidationFailure(
      'That password is too easy to guess. Use at least 8 characters with '
      'a letter and a number.',
      field: 'password',
    ),

    // ---- action links: verification and password reset ------------------
    'expired-action-code' => AuthFailure(
      'That link has expired. Ask for a new one.',
      cause: cause,
      stackTrace: stackTrace,
    ),
    'invalid-action-code' => AuthFailure(
      'That link is not valid any more — it may already have been used. '
      'Ask for a new one.',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // ---- session --------------------------------------------------------
    'user-token-expired' ||
    'user-token-revoked' ||
    'requires-recent-login' ||
    'unauthenticated' => AuthFailure(
      'You have been signed out. Log in again to continue.',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // ---- connectivity (firebase_auth and cloud_firestore) ---------------
    'network-request-failed' ||
    'unavailable' ||
    'deadline-exceeded' => NetworkFailure(
      'No connection to NovaRide. Check your internet and try again.',
      cause: cause,
      stackTrace: stackTrace,
    ),

    // ---- Firestore ------------------------------------------------------
    // Not the person's fault and not something they can fix, so the sentence
    // does not ask them to do anything except report it.
    'permission-denied' => PermissionFailure(
      'This account is not allowed to see that yet. Nothing is wrong on '
      'your side — please report it.',
      cause: cause,
      stackTrace: stackTrace,
    ),
    'not-found' => NotFoundFailure(
      'That record no longer exists.',
      cause: cause,
      stackTrace: stackTrace,
    ),
    'already-exists' => const ValidationFailure('That record already exists.'),

    // ---- project configuration ------------------------------------------
    // Only reachable on a misconfigured project. Says so plainly rather than
    // blaming the person's credentials.
    'operation-not-allowed' => AuthFailure(
      'This sign-in method is switched off for NovaRide. Please report it.',
      cause: cause,
      stackTrace: stackTrace,
    ),

    _ => UnexpectedFailure(
      _fallbackMessage,
      cause: cause,
      stackTrace: stackTrace,
    ),
  };
}

/// Google OAuth uses provider-specific error codes that should not be shown
/// as email/password failures.
Failure failureFromGoogleSignIn(Object error, [StackTrace? stackTrace]) {
  if (error is! FirebaseAuthException) {
    return failureFrom(error, stackTrace);
  }

  final message = switch (error.code) {
    'popup-blocked' =>
      'Your browser blocked the sign-in popup. Allow pop-ups for this site '
          'and try again.',
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-cancelled' ||
    'canceled' => 'Google sign-in was cancelled. No changes were made.',
    'web-storage-unsupported' =>
      'Your browser blocked sign-in storage. Allow site data and try again.',
    'account-exists-with-different-credential' =>
      'An account already uses this email with another sign-in method. '
          'Use that method to log in.',
    'invalid-credential' || 'invalid-login-credentials' =>
      'Google could not verify this sign-in. Choose your account again.',
    _ => null,
  };
  if (message == null) return failureFromAuth(error, stackTrace);
  return AuthFailure(message, cause: error, stackTrace: stackTrace);
}

/// Convenience for the common `catch (e, s)` at a data-source boundary when
/// only the sentence is wanted.
String messageFor(Object error) => failureFrom(error).message;

/// Kept so a caller that already holds a [FirebaseAuthException] does not
/// have to reach for `.code` itself.
Failure failureFromAuth(
  FirebaseAuthException error, [
  StackTrace? stackTrace,
]) => failureForCode(error.code, cause: error, stackTrace: stackTrace);
