import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {

  const User({
    required this.id,
    required this.email,
    required this.isVerified, required this.isActive, this.username,
    this.fullName,
    this.avatarUrl,
    this.isSuperuser = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String email;

  static String _idFromJson(dynamic id) {
    return id.toString();
  }
  final String? username;

  @JsonKey(name: 'full_name')
  final String? fullName;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @JsonKey(name: 'is_verified', defaultValue: false)
  final bool isVerified;

  @JsonKey(name: 'is_active', defaultValue: false)
  final bool isActive;

  @JsonKey(name: 'is_superuser')
  final bool isSuperuser;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? avatarUrl,
    bool? isVerified,
    bool? isActive,
    bool? isSuperuser,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName {
    return fullName ?? username ?? email.split('@')[0];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User(id: $id, email: $email, username: $username, fullName: $fullName)';
  }
}