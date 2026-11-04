// A GuardianLinkRepository that never touches Firestore, driven by the
// test. Every guardian screen and the rider's Emergency contacts read it,
// so the harness always overrides it.

import 'dart:async';

import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/guardian/domain/entities/guardian_link.dart';
import 'package:novaride/features/guardian/domain/repositories/guardian_link_repository.dart';

class FakeGuardianLinkRepository implements GuardianLinkRepository {
  FakeGuardianLinkRepository({
    GuardianLink? link,
    this.riderAccount,
    List<GuardianLink> guardians = const [],
    this.inviteCode = 'K7P2QM',
  })  : _link = link,
        _guardians = guardians;

  GuardianLink? _link;
  List<GuardianLink> _guardians;
  final FollowedRiderAccount? riderAccount;
  final String inviteCode;
  final List<GuardianInvite> _invites = [];

  final _linkCtrl = StreamController<GuardianLink?>.broadcast();
  final _guardiansCtrl = StreamController<List<GuardianLink>>.broadcast();
  final _invitesCtrl = StreamController<List<GuardianInvite>>.broadcast();

  /// What the screens asked for, in order.
  final List<String> calls = [];

  /// Thrown by the next [redeem], when set.
  Failure? failRedeemWith;

  @override
  Future<GuardianInvite> createInvite({
    required String riderUid,
    required String riderName,
  }) async {
    calls.add('createInvite:$riderUid|$riderName');
    final invite = GuardianInvite(
      code: inviteCode,
      riderUid: riderUid,
      riderName: riderName,
      createdAt: DateTime.now(),
    );
    _invites.add(invite);
    _invitesCtrl.add(List.of(_invites));
    return invite;
  }

  @override
  Future<void> cancelInvite(String code) async {
    calls.add('cancelInvite:$code');
    _invites.removeWhere((i) => i.code == code);
    _invitesCtrl.add(List.of(_invites));
  }

  @override
  Stream<List<GuardianInvite>> watchInvitesOf(String riderUid) async* {
    yield List.of(_invites);
    yield* _invitesCtrl.stream;
  }

  @override
  Stream<List<GuardianLink>> watchGuardiansOf(String riderUid) async* {
    yield _guardians;
    yield* _guardiansCtrl.stream;
  }

  @override
  Future<GuardianInvite> lookUpInvite(String code) async {
    calls.add('lookUpInvite:${normaliseInviteCode(code)}');
    return GuardianInvite(
      code: normaliseInviteCode(code),
      riderUid: 'uid-rider',
      riderName: 'Juan Dela Cruz',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<GuardianLink> redeem({
    required String code,
    required String guardianUid,
    required String guardianName,
    required String relationship,
  }) async {
    calls.add('redeem:${normaliseInviteCode(code)}|$guardianUid|$guardianName|$relationship');
    final failure = failRedeemWith;
    if (failure != null) throw failure;
    final link = GuardianLink(
      guardianUid: guardianUid,
      riderUid: 'uid-rider',
      guardianName: guardianName,
      relationship: relationship,
      createdAt: DateTime.now(),
    );
    _linkCtrl.add(_link = link);
    return link;
  }

  @override
  Stream<GuardianLink?> watchLinkOf(String guardianUid) async* {
    yield _link;
    yield* _linkCtrl.stream;
  }

  @override
  Stream<FollowedRiderAccount?> watchRiderAccount(String riderUid) =>
      Stream.value(riderAccount);

  @override
  Future<void> unlink(String guardianUid) async {
    calls.add('unlink:$guardianUid');
    if (_link?.guardianUid == guardianUid) _linkCtrl.add(_link = null);
    _guardians = [
      for (final g in _guardians)
        if (g.guardianUid != guardianUid) g,
    ];
    _guardiansCtrl.add(_guardians);
  }
}
