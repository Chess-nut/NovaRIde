/// Reads the rider's linked roster entry and their alerts.
///
/// **Contract:** on failure, throw a `Failure` from
/// `core/errors/failure.dart` — never a `FirebaseException`.
library;

import '../entities/rider_alert.dart';

abstract interface class RiderAlertRepository {
  /// The roster entry a Super Admin has linked to account [uid], updating
  /// live. Emits null while there is none: a rider who signed up but has
  /// not been linked yet is a normal state.
  Stream<LinkedRider?> watchLinkedRider(String uid);

  /// The alerts filed under roster id [riderId], newest first, capped.
  Stream<List<RiderAlert>> watchAlerts(String riderId);
}
