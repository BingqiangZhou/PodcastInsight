import '../models/auth_request.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<RefreshTokenResponse> refreshToken(String refreshToken);
  Future<void> logout(String? refreshToken);
  Future<User> getCurrentUser();
  Future<void> forgotPassword(ForgotPasswordRequest request);
  Future<void> resetPassword(ResetPasswordRequest request);
}
