/// [GuardianLinkRepository] on Firestore.
///
/// Two collections, both guarded by `firestore.rules`:
///
/// * `guardianInvites/{code}` — `riderUid`, `riderName`, `createdAt`.
///   The rider writes and deletes their own; any signed-in account may
///   `get` one by its code (that is how a guardian finds it); only the
///   rider may list theirs.
/// * `guardianLinks/{guardianUid}` — `riderUid`, `inviteCode`,
///   `guardianName`, `relationship`, `createdAt`. Written once by the
///   guardian, and only while the code they name is under 15 minutes old
///   and belongs to that rider. Never updated; either side may delete it.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/guardian_link.dart';
import '../domain/repositories/guardian_link_repository.dart';

class FirestoreGuardianLinkRepository implements GuardianLinkRepository {
  FirestoreGuardianLinkRepository({FirebaseFirestore? firestore, Random? random})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final Random _random;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection(FirestoreCollections.guardianInvites);

  CollectionReference<Map<String, dynamic>> get _links =>
      _firestore.collection(FirestoreCollections.guardianLinks);

  String _newCode() => List.generate(
        kInviteLength,
        (_) => kInviteAlphabet[_random.nextInt(kInviteAlphabet.length)],
      ).join();

  // ------------------------------------------------------------ rider side

  @override
  Future<GuardianInvite> createInvite({
    required String riderUid,
    required String riderName,
  }) async {
    try {
      // 31^6 is ~887 million codes, so a collision is rare; three tries
      // is plenty. Writing over someone else's code is refused by the
      // rules anyway (invites are never updated), so the check here only
      // turns that refusal into a quiet retry.
      for (var attempt = 0; attempt < 3; attempt++) {
        final code = _newCode();
        final ref = _invites.doc(code);
        if ((await ref.get()).exists) continue;
        await ref.set({
          'riderUid': riderUid,
          'riderName': riderName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return GuardianInvite(
          code: code,
          riderUid: riderUid,
          riderName: riderName,
          createdAt: DateTime.now(),
        );
      }
      throw const UnexpectedFailure(
        'Couldn\'t make a code just now. Please try again.',
      );
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Future<void> cancelInvite(String code) async {
    try {
      await _invites.doc(code).delete();
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Stream<List<GuardianInvite>> watchInvitesOf(String riderUid) {
    return _invites
        .where('riderUid', isEqualTo: riderUid)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                GuardianInvite.fromMap(doc.id, doc.data()),
            ])
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  @override
  Stream<List<GuardianLink>> watchGuardiansOf(String riderUid) {
    return _links
        .where('riderUid', isEqualTo: riderUid)
        .snapshots()
        .map((snapshot) {
          final links = [
            for (final doc in snapshot.docs)
              GuardianLink.fromMap(doc.id, doc.data()),
          ];
          // Oldest first: the order people were added in.
          links.sort((a, b) => (a.createdAt ?? DateTime(9999))
              .compareTo(b.createdAt ?? DateTime(9999)));
          return links;
        })
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  // --------------------------------------------------------- guardian side

  @override
  Future<GuardianInvite> lookUpInvite(String code) async {
    final normalised = normaliseInviteCode(code);
    if (!isWellFormedInviteCode(normalised)) {
      throw const ValidationFailure(
        'A code is 6 letters and numbers, like K7P 2QM.',
        field: 'code',
      );
    }
    try {
      final snapshot = await _invites.doc(normalised).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const NotFoundFailure(
          'That code doesn\'t exist. Check it with the rider.',
        );
      }
      return GuardianInvite.fromMap(normalised, data);
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Future<GuardianLink> redeem({
    required String code,
    required String guardianUid,
    required String guardianName,
    required String relationship,
  }) async {
    final invite = await lookUpInvite(code);
    if (invite.isExpired(DateTime.now())) {
      throw const ValidationFailure(
        'That code has expired. Ask the rider for a new one.',
        field: 'code',
      );
    }
    try {
      final ref = _links.doc(guardianUid);
      if ((await ref.get()).exists) {
        throw const ValidationFailure(
          'You already follow a rider. Unlink in Profile first.',
        );
      }
      await ref.set({
        'riderUid': invite.riderUid,
        'inviteCode': invite.code,
        'guardianName': guardianName,
        'relationship': relationship,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return GuardianLink(
        guardianUid: guardianUid,
        riderUid: invite.riderUid,
        guardianName: guardianName,
        relationship: relationship,
        createdAt: DateTime.now(),
      );
    } on FirebaseException catch (error, stack) {
      // The rules refuse a link when the code is past its 15 minutes by
      // the server's clock, which can disagree with the phone's by a few
      // seconds. Say that, rather than the generic permission sentence.
      if (error.code == 'permission-denied') {
        throw ValidationFailure(
          'That code has expired. Ask the rider for a new one.',
          field: 'code',
          cause: error,
          stackTrace: stack,
        );
      }
      throw failureFrom(error, stack);
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }

  @override
  Stream<GuardianLink?> watchLinkOf(String guardianUid) {
    return _links
        .doc(guardianUid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return snapshot.exists && data != null
              ? GuardianLink.fromMap(guardianUid, data)
              : null;
        })
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  @override
  Stream<FollowedRiderAccount?> watchRiderAccount(String riderUid) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(riderUid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return snapshot.exists && data != null
              ? FollowedRiderAccount.fromMap(riderUid, data)
              : null;
        })
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }

  // ------------------------------------------------------------- either

  @override
  Future<void> unlink(String guardianUid) async {
    try {
      await _links.doc(guardianUid).delete();
    } catch (error, stack) {
      throw failureFrom(error, stack);
    }
  }
}
