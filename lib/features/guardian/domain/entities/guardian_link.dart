/// The rider–guardian link and the invite code that creates it.
///
/// A rider shows a short code; a guardian types it in; a link exists.
/// Each guardian follows one rider (the link's document id is the
/// guardian's uid, so a second one cannot be written), and a rider can
/// have any number of guardians.
library;

/// How long an invite code works after the rider makes it. The rules
/// enforce the same number against the server clock.
const Duration kInviteLifetime = Duration(minutes: 15);

/// Characters an invite code is made of: capitals and digits, without the
/// ones that are easy to misread aloud or on a small screen (0/O, 1/I/L).
const String kInviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Length of an invite code.
const int kInviteLength = 6;

/// Upper-cases, strips spaces and dashes, so "k7p 2qm" and "K7P-2QM" are
/// the same code as "K7P2QM".
String normaliseInviteCode(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// True when [code] (already normalised) could be an invite code.
bool isWellFormedInviteCode(String code) =>
    code.length == kInviteLength &&
    code.split('').every(kInviteAlphabet.contains);

/// "K7P2QM" → "K7P 2QM", for reading aloud.
String formatInviteCode(String code) => code.length == kInviteLength
    ? '${code.substring(0, 3)} ${code.substring(3)}'
    : code;

/// `guardianInvites/{code}`. Lives until the rider cancels it; works for
/// [kInviteLifetime] after [createdAt].
class GuardianInvite {
  const GuardianInvite({
    required this.code,
    required this.riderUid,
    required this.riderName,
    this.createdAt,
  });

  final String code;
  final String riderUid;

  /// Shown to the guardian before they connect, so they know whose code
  /// they typed.
  final String riderName;

  /// Server time. Null only for an instant after the rider's own write,
  /// before the server stamps it.
  final DateTime? createdAt;

  DateTime? get expiresAt => createdAt?.add(kInviteLifetime);

  /// Time left at [now]; zero once expired. A code whose [createdAt] has
  /// not arrived yet has its whole lifetime left.
  Duration remaining(DateTime now) {
    final end = expiresAt;
    if (end == null) return kInviteLifetime;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isExpired(DateTime now) => remaining(now) == Duration.zero;

  factory GuardianInvite.fromMap(String code, Map<String, dynamic> map) {
    return GuardianInvite(
      code: code,
      riderUid: map['riderUid'] as String? ?? '',
      riderName: map['riderName'] as String? ?? '',
      createdAt: dateFrom(map['createdAt']),
    );
  }
}

/// `guardianLinks/{guardianUid}`.
class GuardianLink {
  const GuardianLink({
    required this.guardianUid,
    required this.riderUid,
    required this.guardianName,
    required this.relationship,
    this.createdAt,
  });

  final String guardianUid;
  final String riderUid;
  final String guardianName;

  /// What the guardian is to the rider: "Parent", "Sibling"…
  final String relationship;
  final DateTime? createdAt;

  factory GuardianLink.fromMap(String guardianUid, Map<String, dynamic> map) {
    return GuardianLink(
      guardianUid: guardianUid,
      riderUid: map['riderUid'] as String? ?? '',
      guardianName: map['guardianName'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      createdAt: dateFrom(map['createdAt']),
    );
  }
}

/// What a guardian may read about the rider they follow, from
/// `users/{riderUid}`.
class FollowedRiderAccount {
  const FollowedRiderAccount({
    required this.uid,
    required this.fullName,
    required this.username,
    this.phoneNumber,
  });

  final String uid;
  final String fullName;
  final String username;
  final String? phoneNumber;

  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : username;

  /// The first word of [displayName], for "Call Chester".
  String get firstName {
    final parts = displayName.split(RegExp(r'\s+'));
    return parts.isEmpty ? displayName : parts.first;
  }

  factory FollowedRiderAccount.fromMap(String uid, Map<String, dynamic> map) {
    final phone = (map['phoneNumber'] as String?)?.trim();
    return FollowedRiderAccount(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      phoneNumber: (phone == null || phone.isEmpty) ? null : phone,
    );
  }
}

/// The relationships a guardian picks from when connecting.
const List<String> kGuardianRelationships = [
  'Parent',
  'Sibling',
  'Spouse',
  'Child',
  'Friend',
  'Other',
];

/// Anything with a `toDate()` — a Firestore `Timestamp` — without this
/// file importing one.
DateTime? dateFrom(Object? value) {
  if (value is DateTime) return value;
  try {
    final converted = (value as dynamic)?.toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}
