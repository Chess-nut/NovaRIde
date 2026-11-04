/// A rider's phone-only emergency contacts. Methods throw a `Failure`;
/// the stream reports one as its error.
library;

import '../entities/emergency_contact.dart';

abstract interface class EmergencyContactRepository {
  /// [riderUid]'s contacts, in the order they were added.
  Stream<List<EmergencyContact>> watch(String riderUid);

  /// Saves a new contact ([contact]'s id is ignored).
  Future<void> add(String riderUid, EmergencyContact contact);

  /// Overwrites the name, relationship and phone of [contact].
  Future<void> update(String riderUid, EmergencyContact contact);

  Future<void> delete(String riderUid, String contactId);
}
