import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

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
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    /// The Firebase Auth uid. The same value keys `users/`,
    /// `riderProfiles/` and `guardianProfiles/`.
    required String uid,
    required String email,

    /// The chosen username, in the case the person typed it. The lowercased
    /// form is the document id under `usernames/`; this is what gets shown.
    required String username,
    required String fullName,
    required UserRole role,

    /// Mirrors `FirebaseAuth.currentUser.emailVerified`, not a Firestore
    /// field. The router holds an unverified account on the verify-email
    /// screen.
    @Default(false) bool emailVerified,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  /// What to greet someone with when the full name is missing or blank.
  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : username;

  bool get isRider => role == UserRole.rider;
  bool get isGuardian => role == UserRole.guardian;
}
