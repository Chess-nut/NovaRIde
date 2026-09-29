import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/rider_profile.dart';
import '../domain/repositories/rider_profile_repository.dart';

/// [RiderProfileRepository] against Cloud Firestore.
///
/// A live snapshot rather than a one-shot read, so a profile written by
/// `ensureProfile` a moment after the account appears reaches the screen
/// without anything having to refresh.
class FirestoreRiderProfileRepository implements RiderProfileRepository {
  FirestoreRiderProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<RiderProfile?> watch(String uid) {
    return _firestore
        .collection(FirestoreCollections.riderProfiles)
        .doc(uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? RiderProfile.fromMap(uid, snapshot.data()) : null)
        // The interface's error contract: a Failure with a sentence on
        // it, never a raw FirebaseException reaching a widget.
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }
}
