import 'user_role.dart';

/// A signed-in NovaRide account, as the app thinks about it.
///
/// This is the domain shape, not the document shape: it holds no
/// `Timestamp`, no `DocumentSnapshot`, and nothing from `firebase_auth`. The
/// data layer Phase 3 adds is what reads `users/{uid}` and its
/// role-specific profile and assembles one of these; everything above that
/// boundary can be built and tested without Firebase running.
///
/// It is deliberately the union of what both roles need. Fields that only
/// one role has — a rider's helmet id, a guardian's linked riders — belong
/// on `riderProfiles/` and `guardianProfiles/` and get their own entities
/// when a screen actually needs them.
///
/// Written out by hand rather than generated. It is a value class with
/// nine fields; the generator's output was longer than this file and
/// needed a prerelease toolchain to produce it.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    this.emailVerified = false,
    this.phoneNumber,
    this.photoUrl,
    this.createdAt,
  });

  /// The Firebase Auth uid. The same value keys `users/`, `riderProfiles/`
  /// and `guardianProfiles/`.
  final String uid;
  final String email;

  /// The chosen username, in the case the person typed it. The lowercased
  /// form is the document id under `usernames/`; this is what gets shown.
  final String username;
  final String fullName;
  final UserRole role;

  /// Mirrors `FirebaseAuth.currentUser.emailVerified`, not a Firestore
  /// field. The router holds an unverified account on the verify-email
  /// screen.
  final bool emailVerified;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime? createdAt;

  /// What to greet someone with when the full name is missing or blank.
  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : username;

  bool get isRider => role == UserRole.rider;
  bool get isGuardian => role == UserRole.guardian;

  /// Every field is optional so a caller changes one without restating the
  /// rest. Nullable fields cannot be cleared this way — nothing needs to,
  /// and a sentinel to allow it would cost more than it is worth.
  UserProfile copyWith({
    String? uid,
    String? email,
    String? username,
    String? fullName,
    UserRole? role,
    bool? emailVerified,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Reads the `users/{uid}` shape. A missing or unrecognised `role` throws
  /// rather than defaulting: guessing would hand someone the wrong home
  /// screen, and the data layer can turn this into a `Failure`.
  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final role = UserRole.fromWireName(map['role'] as String?);
    if (role == null) {
      throw FormatException(
        'users/$uid has no usable role (found ${map['role']}).',
      );
    }
    return UserProfile(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      fullName: (map['fullName'] as String?) ?? '',
      role: role,
      emailVerified: (map['emailVerified'] as bool?) ?? false,
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: _dateFrom(map['createdAt']),
    );
  }

  /// The document body, without the uid — that is the document id.
  ///
  /// `createdAt` is left out on purpose: it is written once, at sign-up,
  /// with a server timestamp, and a client clock has no business setting
  /// it. `emailVerified` is also absent, because Firebase Auth owns it.
  Map<String, dynamic> toMap() => {
        'email': email,
        'username': username,
        'fullName': fullName,
        'role': role.wireName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  /// Accepts an ISO-8601 string or anything with a `toDate()` — which is
  /// what a Firestore `Timestamp` has, without this file importing one.
  static DateTime? _dateFrom(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final converted = (value as dynamic).toDate();
      return converted is DateTime ? converted : null;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.uid == uid &&
          other.email == email &&
          other.username == username &&
          other.fullName == fullName &&
          other.role == role &&
          other.emailVerified == emailVerified &&
          other.phoneNumber == phoneNumber &&
          other.photoUrl == photoUrl &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(uid, email, username, fullName, role,
      emailVerified, phoneNumber, photoUrl, createdAt);

  @override
  String toString() => 'UserProfile($uid, $username, ${role.wireName})';
}
