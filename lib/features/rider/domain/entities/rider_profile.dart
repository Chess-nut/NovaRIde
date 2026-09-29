/// The `riderProfiles/{uid}` document.
///
/// Today it holds only its timestamps. That is not an oversight — the
/// fields a rider screen wants (helmet pairing, trip totals, safety
/// score) have no source yet:
///
/// - **Pairing** lives console-side, on `riders/{R-xxx}.helmetId` and
///   `devices/{id}.assigned_rider_id`. A mobile account cannot read
///   either, and nothing writes `riders/{id}.authUid` to link the two.
/// - **Telemetry** lives on `devices/{id}`, which the rules refuse to a
///   mobile account for the same reason.
/// - **Trip totals and safety score** are not computed anywhere, by
///   anything, yet.
///
/// So this entity is deliberately almost empty, and the screens show
/// placeholders rather than numbers. Phase 7 adds fields here as their
/// sources arrive; until then an empty entity is the honest shape.
library;

class RiderProfile {
  const RiderProfile({
    required this.uid,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True once a helmet is linked to this account.
  ///
  /// Always false today, and the screens rely on that being honest
  /// rather than on a hardcoded "Connected". When the link lands it
  /// becomes a real check and nothing above has to change.
  bool get hasPairedHelmet => false;

  factory RiderProfile.fromMap(String uid, Map<String, dynamic>? map) {
    return RiderProfile(
      uid: uid,
      createdAt: _dateFrom(map?['createdAt']),
      updatedAt: _dateFrom(map?['updatedAt']),
    );
  }

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
      other is RiderProfile &&
          other.uid == uid &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(uid, createdAt, updatedAt);
}
