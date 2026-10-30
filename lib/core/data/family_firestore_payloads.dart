abstract final class FamilyFirestorePayloads {
  static const defaultPermissions = <String, bool>{
    'liveLocation': true,
    'emergencyAlerts': true,
    'tripStatus': true,
    'helmetStatus': true,
    'incidentHistory': true,
  };

  static Map<String, Object?> family({
    required String ownerUid,
    required Object serverTimestamp,
  }) => {
    'ownerUid': ownerUid,
    'createdAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> member({
    required String uid,
    required String role,
    required String displayName,
    required Object serverTimestamp,
    Map<String, bool>? permissions,
  }) => {
    'uid': uid,
    'role': role,
    'status': 'active',
    'displayName': displayName,
    'permissions': permissions ?? defaultPermissions,
    'createdAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };
}
