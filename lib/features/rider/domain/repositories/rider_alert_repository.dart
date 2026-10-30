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

  /// Calls off a pending crash as a false positive. With [standDown], the
  /// same batch takes the rider out of `emergency` — pass it when the
  /// helmet's emergency write has already landed. The rules accept this
  /// only within the 15 s countdown; after it, it throws.
  Future<void> cancelPendingCrash({
    required String alertId,
    required String riderId,
    required bool standDown,
  });

  /// Takes the rider out of `emergency` after a cancel, for when the
  /// helmet's emergency write landed after it. Accepted for 90 s from the
  /// cancelled alert's arrival, naming that alert.
  Future<void> standDown({required String riderId, required String alertId});
}
