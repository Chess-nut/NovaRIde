/// What the app passes around when something did not work.
///
/// Every failure carries a [message] that is already fit to put in front of
/// the person using the app: a sentence, no error code, no exception
/// `toString()`. Codes and stack traces go to [AppLogger], not the screen.
/// Feature code catches a platform exception once, at the data-source
/// boundary, turns it into one of these, and from there inward the UI only
/// ever handles a [Failure].
///
/// The subtypes exist because the *caller* reacts differently to each, not
/// because the wording differs: a [NetworkFailure] is worth a Retry button,
/// an [AuthFailure] usually means "fix the form and try again", and an
/// [UnexpectedFailure] means the app is in a state nobody planned for.
library;

sealed class Failure implements Exception {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// A complete sentence for the person at the screen.
  final String message;

  /// The original exception, kept for logging. Never shown.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sign-in, sign-up, verification, password reset — anything the identity
/// provider refused.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause, super.stackTrace});
}

/// The request never reached Firebase, or did not come back in time. The
/// distinguishing feature is that trying again later may simply work.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

/// Authenticated, but not allowed — the security rules said no. On this
/// project that usually means a rule has not been written for the path yet
/// rather than that the person did something wrong.
final class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.cause, super.stackTrace});
}

/// A read that found nothing where something was required — a profile
/// document missing for a uid that authenticated, say.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// The input was refused before it ever left the app, or refused by a
/// uniqueness check. [field] names the form field to attach it to, when one
/// applies.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.field, super.cause, super.stackTrace});

  final String? field;
}

/// Nothing above fits. Always worth logging with its [cause].
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
