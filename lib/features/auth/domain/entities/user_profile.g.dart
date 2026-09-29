// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  uid: json['uid'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  fullName: json['fullName'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  emailVerified: json['emailVerified'] as bool? ?? false,
  phoneNumber: json['phoneNumber'] as String?,
  photoUrl: json['photoUrl'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'email': instance.email,
      'username': instance.username,
      'fullName': instance.fullName,
      'role': _$UserRoleEnumMap[instance.role]!,
      'emailVerified': instance.emailVerified,
      'phoneNumber': instance.phoneNumber,
      'photoUrl': instance.photoUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.rider: 'rider',
  UserRole.guardian: 'guardian',
};
