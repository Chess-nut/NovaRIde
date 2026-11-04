/// Invites, links, and what a linked guardian may read about the rider.
///
/// Every method throws a `Failure` (never a raw Firebase exception), and
/// every stream reports one as its error.
library;

import '../entities/guardian_link.dart';

abstract interface class GuardianLinkRepository {
  // ------------------------------------------------------------ rider side

  /// Makes a new code for [riderUid]. Retries on the rare collision with
  /// an existing code.
  Future<GuardianInvite> createInvite({
    required String riderUid,
    required String riderName,
  });

  /// Deletes the code so nobody else can use it.
  Future<void> cancelInvite(String code);

  /// The rider's own codes, expired ones included (the caller filters).
  Stream<List<GuardianInvite>> watchInvitesOf(String riderUid);

  /// Everyone following [riderUid].
  Stream<List<GuardianLink>> watchGuardiansOf(String riderUid);

  // --------------------------------------------------------- guardian side

  /// The code's invite, or a `NotFoundFailure` when there is no such code.
  /// Used to show "Connect to Chester?" before linking.
  Future<GuardianInvite> lookUpInvite(String code);

  /// Links [guardianUid] to the rider behind [code]. Fails with a
  /// `ValidationFailure` when the code has expired or the guardian already
  /// follows someone.
  Future<GuardianLink> redeem({
    required String code,
    required String guardianUid,
    required String guardianName,
    required String relationship,
  });

  /// The rider this guardian follows, or null.
  Stream<GuardianLink?> watchLinkOf(String guardianUid);

  /// The followed rider's name and phone number.
  Stream<FollowedRiderAccount?> watchRiderAccount(String riderUid);

  // ------------------------------------------------------------- either

  /// Ends the link. The guardian may end their own; the rider may end any
  /// of theirs.
  Future<void> unlink(String guardianUid);
}
