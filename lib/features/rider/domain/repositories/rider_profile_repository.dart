/// Reads `riderProfiles/{uid}`.
///
/// Separate from `AuthRepository`, which owns `users/{uid}`: that one is
/// the account every role has, this one is the rider's half. A guardian
/// never calls this.
///
/// **Contract:** on failure, throw a `Failure` from
/// `core/errors/failure.dart` — never a `FirebaseException`. Callers may
/// assume the `message` on what they catch is fit to show.
library;

import '../entities/rider_profile.dart';

abstract interface class RiderProfileRepository {
  /// The rider's profile, updating as the document changes.
  ///
  /// Emits null when there is no document — which happens for a
  /// guardian, and for the moment between an account being created and
  /// `ensureProfile` committing.
  Stream<RiderProfile?> watch(String uid);
}
