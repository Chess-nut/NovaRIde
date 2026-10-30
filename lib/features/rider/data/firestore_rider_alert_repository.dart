import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/rider_alert.dart';
import '../domain/repositories/rider_alert_repository.dart';

/// [RiderAlertRepository] against Cloud Firestore.
///
/// Both reads are exactly the queries rules_test/rider_link.test.js proves
/// the rules admit. Changing either filter means changing that test first:
/// a query the rules cannot prove from its filters is refused whole.
class FirestoreRiderAlertRepository implements RiderAlertRepository {
  FirestoreRiderAlertRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Enough for the countdown and a short recent history; the console keeps
  /// the full record.
  static const _alertLimit = 20;

  @override
  Stream<LinkedRider?> watchLinkedRider(String uid) {
    return _firestore
        .collection(FirestoreCollections.riders)
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty
            ? null
            : LinkedRider.fromMap(snapshot.docs.first.id, snapshot.docs.first.data()))
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  @override
  Stream<List<RiderAlert>> watchAlerts(String riderId) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where('riderId', isEqualTo: riderId)
        .orderBy('timestamp', descending: true)
        .limit(_alertLimit)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs) RiderAlert.fromMap(doc.id, doc.data()),
            ])
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  @override
  Future<void> cancelPendingCrash({
    required String alertId,
    required String riderId,
    required bool standDown,
  }) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection(FirestoreCollections.alerts).doc(alertId), {
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    if (standDown) {
      batch.update(
        _firestore.collection(FirestoreCollections.riders).doc(riderId),
        _standDownFields(alertId),
      );
    }
    try {
      await batch.commit();
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Future<void> standDown({required String riderId, required String alertId}) async {
    try {
      await _firestore
          .collection(FirestoreCollections.riders)
          .doc(riderId)
          .update(_standDownFields(alertId));
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  /// Exactly what isRiderStandDown in firestore.rules admits.
  static Map<String, Object> _standDownFields(String alertId) =>
      {'status': 'riding', 'statusClearedBy': alertId};
}
