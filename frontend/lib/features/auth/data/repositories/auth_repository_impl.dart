import 'package:dio/dio.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/storage/secure_storage_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/auth_request.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/auth_response.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {

  AuthRepositoryImpl(
    this._remoteDatasource,
    this._secureStorage,
  );
  final AuthRemoteDatasource _remoteDatasource;
  final SecureStorageService _secureStorage;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final authResponse = await _remoteDatasource.login(request);

      // Save tokens to secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final authResponse = await _remoteDatasource.register(request);

      // Save tokens to secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException catch (e) {
      logger.AppLogger.debug('=== Repository Accepts AppException ===');
      logger.AppLogger.debug('Exception type: ${e.runtimeType}');
      logger.AppLogger.debug('Exception message: ${e.message}');
      rethrow;
    } catch (e) {
      logger.AppLogger.debug('=== Repository Falls to UnknownException ===');
      logger.AppLogger.debug('Error type: ${e.runtimeType}');
      logger.AppLogger.debug('Error: $e');
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    try {
      final authResponse = await _remoteDatasource.refreshToken(refreshToken);

      // Update tokens in secure storage
      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return RefreshTokenResponse(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        tokenType: authResponse.tokenType,
        expiresIn: authResponse.expiresIn,
        expiresAt: authResponse.expiresAt,
        serverTime: authResponse.serverTime,
      );
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      // Use provided token or get from storage
      final token = refreshToken ?? await _secureStorage.getRefreshToken();

      // Call logout endpoint with refresh token if available
      if (token != null && token.isNotEmpty) {
        await _remoteDatasource.logout(token);
      }

      // Clear tokens from secure storage
      await _secureStorage.clearTokens();
    } on DioException catch (e) {
      await _secureStorage.clearTokens();
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      // Even if logout fails, clear local tokens
      await _secureStorage.clearTokens();
      rethrow;
    } catch (e) {
      // Even if logout fails, clear local tokens
      await _secureStorage.clearTokens();
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final user = await _remoteDatasource.getCurrentUser();
      return user;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _remoteDatasource.forgotPassword(request);
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    try {
      await _remoteDatasource.resetPassword(request);
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }
}
