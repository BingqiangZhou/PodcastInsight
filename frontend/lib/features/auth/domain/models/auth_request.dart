import 'package:json_annotation/json_annotation.dart';

part 'auth_request.g.dart';

@JsonSerializable()
class LoginRequest {

  const LoginRequest({
    required this.username,
    required this.password,
    this.rememberMe = false,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  // Backend expects "email_or_username" as parameter name
  @JsonKey(name: 'email_or_username')
  final String username; // Can be email or username

  final String password;

  @JsonKey(name: 'remember_me')
  final bool rememberMe;
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RegisterRequest {

  const RegisterRequest({
    required this.email,
    required this.password,
    this.username,
    this.rememberMe = false,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
  final String email;
  final String password;
  final String? username;

  @JsonKey(name: 'remember_me')
  final bool rememberMe;
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class RefreshTokenRequest {

  const RefreshTokenRequest({
    required this.refreshToken,
  });

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) => _$RefreshTokenRequestFromJson(json);
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

@JsonSerializable()
class ForgotPasswordRequest {

  const ForgotPasswordRequest({
    required this.email,
  });

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) => _$ForgotPasswordRequestFromJson(json);
  final String email;
  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}

@JsonSerializable()
class ResetPasswordRequest {

  const ResetPasswordRequest({
    required this.token,
    required this.newPassword,
  });

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) => _$ResetPasswordRequestFromJson(json);
  final String token;

  @JsonKey(name: 'new_password')
  final String newPassword;
  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}