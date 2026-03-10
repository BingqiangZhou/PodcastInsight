import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../domain/models/auth_request.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/network/exceptions/network_exceptions.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/app_logger.dart' as logger;

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl(
    this._remoteDatasource,
    this._secureStorage,
  );

  @override
  Future<Either<AppException, AuthResponse>> login(LoginRequest request) async {
    try {
      final authResponse = await _remoteDatasource.login(request);

      // Save tokens to secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return Right(authResponse);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, AuthResponse>> register(RegisterRequest request) async {
    try {
      final authResponse = await _remoteDatasource.register(request);

      // Save tokens to secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return Right(authResponse);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      logger.AppLogger.debug('=== Repository Accepts AppException ===');
      logger.AppLogger.debug('Exception type: ${e.runtimeType}');
      logger.AppLogger.debug('Exception message: ${e.message}');
      return Left(e);
    } catch (e) {
      logger.AppLogger.debug('=== Repository Falls to UnknownException ===');
      logger.AppLogger.debug('Error type: ${e.runtimeType}');
      logger.AppLogger.debug('Error: $e');
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, RefreshTokenResponse>> refreshToken(String refreshToken) async {
    try {
      final authResponse = await _remoteDatasource.refreshToken(refreshToken);

      // Update tokens in secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      final refreshResponse = RefreshTokenResponse(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        tokenType: authResponse.tokenType,
        expiresIn: authResponse.expiresIn,
        expiresAt: authResponse.expiresAt,
        serverTime: authResponse.serverTime,
      );

      return Right(refreshResponse);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, void>> logout(String? refreshToken) async {
    try {
      // Use provided token or get from storage
      final token = refreshToken ?? await _secureStorage.getRefreshToken();

      // Call logout endpoint with refresh token if available
      if (token != null && token.isNotEmpty) {
        await _remoteDatasource.logout(token);
      }

      // Clear tokens from secure storage
      await _secureStorage.clearTokens();

      return const Right(null);
    } on DioException catch (e) {
      await _secureStorage.clearTokens();
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      // Even if logout fails, clear local tokens
      await _secureStorage.clearTokens();
      return Left(e);
    } catch (e) {
      // Even if logout fails, clear local tokens
      await _secureStorage.clearTokens();
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, User>> getCurrentUser() async {
    try {
      final user = await _remoteDatasource.getCurrentUser();
      return Right(user);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, void>> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _remoteDatasource.forgotPassword(request);
      return const Right(null);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnknownException(e.toString()));
    }
  }

  @override
  Future<Either<AppException, void>> resetPassword(ResetPasswordRequest request) async {
    try {
      await _remoteDatasource.resetPassword(request);
      return const Right(null);
    } on DioException catch (e) {
      if (e.error is AppException) {
        return Left(e.error as AppException);
      }
      return Left(UnknownException(e.message ?? 'Unknown Dio error'));
    } on AppException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnknownException(e.toString()));
    }
  }
}
