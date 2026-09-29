/// Which of the two mobile audiences an account belongs to.
///
/// The app has exactly two. The operator console's roles (superAdmin,
/// dispatcher, viewer) are a different axis entirely and live on
/// `admins/{uid}`; an operator never signs into this app and a rider never
/// signs into the console.
///
/// The wire spellings are fixed. [rider] and [guardian] are what the
/// `users/{uid}.role` field holds and what `riderProfiles/` and
/// `guardianProfiles/` are named after, so changing one of these strings is
/// a data migration, not a rename.
///
/// The UI says "Family / Emergency Contact" for [guardian]. That is a
/// label, not the identifier — [label] is the only place the two meet.
library;

import 'package:json_annotation/json_annotation.dart';

enum UserRole {
  @JsonValue('rider')
  rider,

  @JsonValue('guardian')
  guardian;

  /// The string stored in Firestore.
  String get wireName => switch (this) {
        UserRole.rider => 'rider',
        UserRole.guardian => 'guardian',
      };

  /// What a person is called on screen.
  String get label => switch (this) {
        UserRole.rider => 'Motorcycle Rider',
        UserRole.guardian => 'Family / Emergency Contact',
      };

  /// Parses a stored value. Returns null rather than guessing: an account
  /// whose role does not parse is a data problem, and defaulting it to
  /// [rider] would hand someone the wrong home screen.
  static UserRole? fromWireName(String? raw) => switch (raw?.trim()) {
        'rider' => UserRole.rider,
        'guardian' => UserRole.guardian,
        // The spelling the app used before the collections were settled.
        // Read-tolerated so an account created during development still
        // resolves; never written.
        'emergencyContact' => UserRole.guardian,
        _ => null,
      };
}
