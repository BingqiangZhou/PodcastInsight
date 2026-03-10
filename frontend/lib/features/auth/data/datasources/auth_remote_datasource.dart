import '../../../../core/utils/app_logger.dart' as logger;
import '../../domain/models/auth_request.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/user.dart';
import '../../../../core/network/dio_client.dart';

abstract class AuthRemoteDatasource {
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<RefreshTokenResponse> refreshToken(String refreshToken);
  Future<void> logout(String? refreshToken);
  Future<User> getCurrentUser();
  Future<void> forgotPassword(ForgotPasswordRequest request);
  Future<void> resetPassword(ResetPasswordRequest request);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final DioClient _apiClient;

  AuthRemoteDatasourceImpl(this._apiClient);

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    logger.AppLogger.debug('=== AuthRemoteDatasource register ===');
    logger.AppLogger.debug('Request data: ${request.toJson()}');

    final response = await _apiClient.post(
      '/auth/register',
      data: request.toJson(),
    );

    logger.AppLogger.debug('Response status: ${response.statusCode}');
    logger.AppLogger.debug('Response data type: ${response.data.runtimeType}');
    logger.AppLogger.debug('Response data keys: ${(response.data as Map<String, dynamic>).keys.toList()}');

    // Check if response contains user object instead of token
    final responseData = response.data as Map<String, dynamic>;

    // If response contains user fields (id, email, username), it's a User object
    // In that case, we need to call login to get the tokens
    if (responseData.containsKey('id') &&
        responseData.containsKey('email') &&
        !responseData.containsKey('access_token')) {
      logger.AppLogger.debug('!!! Received User object instead of Token, attempting login...');

      // Try to login with the newly created user credentials
      return await login(LoginRequest(
        username: request.email,
        password: request.password,
      ));
    }

    // Otherwise, parse as AuthResponse
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return RefreshTokenResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String? refreshToken) async {
    if (refreshToken != null) {
      await _apiClient.post(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } else {
      await _apiClient.post('/auth/logout');
    }
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await _apiClient.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    await _apiClient.post(
      '/auth/forgot-password',
      data: request.toJson(),
    );
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    await _apiClient.post(
      '/auth/reset-password',
      data: request.toJson(),
    );
  }
}
