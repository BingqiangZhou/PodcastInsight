import 'package:dartz/dartz.dart';

import '../models/auth_request.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../../../../core/network/exceptions/network_exceptions.dart';

abstract class AuthRepository {
  Future<Either<AppException, AuthResponse>> login(LoginRequest request);
  Future<Either<AppException, AuthResponse>> register(RegisterRequest request);
  Future<Either<AppException, RefreshTokenResponse>> refreshToken(String refreshToken);
  Future<Either<AppException, void>> logout(String? refreshToken);
  Future<Either<AppException, User>> getCurrentUser();
  Future<Either<AppException, void>> forgotPassword(ForgotPasswordRequest request);
  Future<Either<AppException, void>> resetPassword(ResetPasswordRequest request);
}
