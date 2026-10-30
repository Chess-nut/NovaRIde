/// Every Cloud Firestore collection the mobile app names, in one place.
///
/// No feature code spells a collection out as a string literal. A typo in a
/// path is not a compile error and not a runtime error either — it is a
/// silent read of an empty collection, or a write into one the security
/// rules deny, and both are slow to diagnose. Naming them here also keeps
/// the app's vocabulary and `firestore.rules` visibly in step: every
/// constant below has a matching `match` block in that file, or is
/// deliberately noted as not yet open.
///
/// The names are the schema's, unchanged — see docs/FIRESTORE_SCHEMA.md.
library;

abstract final class FirestoreCollections {
  /// `users/{uid}` — the account record every signed-in principal has,
  /// whatever their role. Written at sign-up. **Not yet open in
  /// firestore.rules**; Phase 4 adds the rule and rules_test/closed.test.js
  /// is what has to change when it does.
  static const users = 'users';

  /// `riderProfiles/{uid}` — rider-specific fields, separate from `users`
  /// so a guardian's document and a rider's never share a shape.
  /// **Not yet open.**
  static const riderProfiles = 'riderProfiles';

  /// `guardianProfiles/{uid}` — the family/emergency-contact counterpart.
  /// **Not yet open.**
  static const guardianProfiles = 'guardianProfiles';

  /// `usernames/{usernameLower}` — the uniqueness index that makes username
  /// login possible. The document id is the lowercased username; the body
  /// points back at a uid. Claimed in the same transaction as sign-up.
  /// **Not yet open.**
  static const usernames = 'usernames';

  /// `riders/{R-001}` — the operator console's roster. The mobile app does
  /// not own these and must never create one; the link from an account to a
  /// roster entry is `riders/{id}.authUid`, written console-side.
  static const riders = 'riders';

  /// `devices/{NR-H1-001}` — helmet telemetry, firmware-owned and
  /// snake_case. Read-only as far as this app is concerned.
  static const devices = 'devices';

  /// `alerts/{alertId}` — the response workflow. Created by the helmet
  /// service, worked by the console. The mobile app reads its own rider's.
  static const alerts = 'alerts';

  /// `alerts/{alertId}/history/{entryId}` — the append-only audit trail.
  /// Also read as a collection group, which is why it is a bare name.
  static const alertHistory = 'history';

  /// `admins/{uid}` — operator provisioning. Present for completeness: the
  /// mobile app has no reason to touch it, and the rules refuse it.
  static const admins = 'admins';

  /// `emergencyContacts/{id}` — reserved in the schema, unused, unopened.
  static const emergencyContacts = 'emergencyContacts';
}
