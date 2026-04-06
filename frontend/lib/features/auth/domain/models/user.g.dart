// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: User._idFromJson(json['id']),
  email: json['email'] as String,
  isVerified: json['is_verified'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? false,
  username: json['username'] as String?,
  fullName: json['full_name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  isSuperuser: json['is_superuser'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'username': instance.username,
  'full_name': instance.fullName,
  'avatar_url': instance.avatarUrl,
  'is_verified': instance.isVerified,
  'is_active': instance.isActive,
  'is_superuser': instance.isSuperuser,
  'created_at': instance.createdAt?.toIso8601String(),
};
