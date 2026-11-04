/// [EmergencyContactRepository] on Firestore:
/// `riderProfiles/{uid}/emergencyContacts/{id}` with `name`,
/// `relationship`, `phone`, `createdAt`, `updatedAt`. The rider owns the
/// subcollection; operators may read it.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/emergency_contact.dart';
import '../domain/repositories/emergency_contact_repository.dart';

class FirestoreEmergencyContactRepository implements EmergencyContactRepository {
  FirestoreEmergencyContactRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _contacts(String riderUid) =>
      _firestore
          .collection(FirestoreCollections.riderProfiles)
          .doc(riderUid)
          .collection(FirestoreCollections.emergencyContacts);

  @override
  Stream<List<EmergencyContact>> watch(String riderUid) {
    return _contacts(riderUid)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                EmergencyContact.fromMap(doc.id, doc.data()),
            ])
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  @override
  Future<void> add(String riderUid, EmergencyContact contact) async {
    try {
      await _contacts(riderUid).add({
        'name': contact.name,
        'relationship': contact.relationship,
        'phone': contact.phone,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Future<void> update(String riderUid, EmergencyContact contact) async {
    try {
      await _contacts(riderUid).doc(contact.id).update({
        'name': contact.name,
        'relationship': contact.relationship,
        'phone': contact.phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Future<void> delete(String riderUid, String contactId) async {
    try {
      await _contacts(riderUid).doc(contactId).delete();
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }
}
