import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:personal_ai_assistant/features/auth/domain/models/auth_request.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_ai_assistant/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:personal_ai_assistant/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:personal_ai_assistant/features/auth/data/events/auth_event.dart';
import 'package:personal_ai_assistant/core/network/token_refresh_service.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/storage/secure_storage_service.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/shared/constants/storage_keys.dart';

// Token refresh constants
const int _tokenRefreshBufferMinutes = 5; // Refresh 5 minutes before expiry
const int _tokenCheckIntervalSeconds = 180; // Check every 3 minutes

@visibleForTesting
List<String> playbackSnapshotKeysToClearOnLogout(String? userId) {
  final keys = <String>[kLastPlaybackSnapshotStorageKeyPrefix];
  if (userId != null && userId.isNotEmpty) {
    keys.add('${kLastPlaybackSnapshotStorageKeyPrefix}_$userId');
  }
  return keys;
}

// Storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageServiceImpl(const FlutterSecureStorage());
});

// Remote datasource provider - use shared DioClient
final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return AuthRemoteDatasourceImpl(dioClient);
});

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDatasource = ref.read(authRemoteDatasourceProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthRepositoryImpl(remoteDatasource, secureStorage);
});

// Auth state notifier provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthState extends Equatable {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final bool isRefreshingToken;
  final AuthOperation? currentOperation;
  final Map<String, String>? fieldErrors; // For validation errors

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.isRefreshingToken = false,
    this.currentOperation,
    this.fieldErrors,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool? isRefreshingToken,
    AuthOperation? currentOperation,
    Map<String, String>? fieldErrors,
    bool clearError = false,
    bool clearFieldErrors = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
      isRefreshingToken: isRefreshingToken ?? this.isRefreshingToken,
      currentOperation: currentOperation ?? this.currentOperation,
      fieldErrors: clearFieldErrors ? null : (fieldErrors ?? this.fieldErrors),
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        isAuthenticated,
        error,
        isRefreshingToken,
        currentOperation,
        fieldErrors,
      ];
}

enum AuthOperation {
  login,
  register,
  logout,
  refreshToken,
  checkAuth,
  forgotPassword,
  resetPassword,
  verifyEmail,
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  SecureStorageService get _secureStorage => ref.read(secureStorageProvider);
  Timer? _tokenRefreshTimer;
  StreamSubscription<AuthEvent>? _authEventSubscription;
  AppLifecycleListener? _lifecycleListener;

  @override
  AuthState build() {

    // Listen to auth events from DioClient
    _authEventSubscription = AuthEventNotifier.instance.authEventStream.listen((
      event,
    ) {
      if (event.type == AuthEventType.tokenCleared) {
        // Sync auth state when tokens are cleared by DioClient
        if (state.isAuthenticated) {
          logger.AppLogger.debug(
            '🔔 [AuthProvider] Received tokenCleared event, clearing auth state',
          );
          state = state.copyWith(isAuthenticated: false, user: null);
        }
        ref.read(dioClientProvider).clearETagCache();
      }
    });

    // Listen to app lifecycle state changes
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChanged,
    );

    // Don't check auth status here to avoid circular dependency
    // Let the UI call checkAuthStatus when needed
    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _stopTokenRefreshTimer();
      _authEventSubscription?.cancel();
    });
    return const AuthState();
  }

  void _onAppLifecycleStateChanged(AppLifecycleState state) {
    // Only handle lifecycle events if user is authenticated
    if (!this.state.isAuthenticated) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground - check token immediately and restart timer
        logger.AppLogger.debug('📱 [Auth] App resumed, checking token...');
        _checkAndRefreshToken();
        _startTokenRefreshTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - stop timer to save resources
        logger.AppLogger.debug('📱 [Auth] App paused, stopping token refresh timer');
        _stopTokenRefreshTimer();
        break;
    }
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: AuthOperation.checkAuth,
    );

    try {
      final token = await _secureStorage.getAccessToken();
      if (token != null) {
        // Check if token is expired (if we have expiry info)
        final tokenExpiry = await _secureStorage.getTokenExpiry();
        // Use UTC time for comparison to avoid timezone issues
        if (tokenExpiry != null && DateTime.now().toUtc().isAfter(tokenExpiry.toUtc())) {
          // Token expired, try refresh
          final refreshResult = await _attemptTokenRefresh();
          if (!refreshResult.success && refreshResult.isInvalidSessionFailure) {
            await _clearAuthState();
            state = state.copyWith(
              isLoading: false,
              isAuthenticated: false,
              error: 'Session expired. Please login again.',
            );
            return;
          }
          if (!refreshResult.success) {
            state = state.copyWith(isLoading: false, currentOperation: null);
            return;
          }
        }

        try {
          final user = await _authRepository.getCurrentUser();
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
            error: null,
            currentOperation: null,
          );
        } on AuthenticationException {
          // For authentication errors, clear state and let router handle redirect
          // Don't show error message, just navigate to login
          _handleAuthError();
          state = state.copyWith(
            isLoading: false,
            error: null, // Don't show error message
            currentOperation: null,
          );
        } on AppException catch (error) {
          // For other errors, show error message
          String userMessage = _getErrorMessage(error);
          state = state.copyWith(
            isLoading: false,
            error: userMessage,
            currentOperation: null,
          );
        }
        // Enable auto-refresh on successful auth check
        _enableAutoRefresh();
      } else {
        state = state.copyWith(isLoading: false, currentOperation: null);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Authentication check failed: ${e.toString()}',
        currentOperation: null,
      );
    }
  }

  Future<void> login({
    required String email, // Can be email or username
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFieldErrors: true,
      currentOperation: AuthOperation.login,
    );

    final request = LoginRequest(
      username: email, // Backend expects username field
      password: password,
      rememberMe: rememberMe,
    );

    try {
      final authResponse = await _authRepository.login(request);

      await _saveTokenExpiry(
        expiresAt: authResponse.expiresAt,
        expiresIn: authResponse.expiresIn,
      );

      // Fetch user info after successful login
      try {
        final user = await _authRepository.getCurrentUser();
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      } catch (_) {
        // Even if user fetch fails, login was successful
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      }
      // Enable auto-refresh
      _enableAutoRefresh();
    } on AppException catch (error) {
      String userMessage = _getErrorMessage(error);
      Map<String, String>? fieldErrors = _getFieldErrors(error);

      state = state.copyWith(
        isLoading: false,
        error: userMessage,
        fieldErrors: fieldErrors,
        currentOperation: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentOperation: null,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? username,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFieldErrors: true,
      currentOperation: AuthOperation.register,
    );

    final request = RegisterRequest(
      email: email,
      password: password,
      username: username,
      rememberMe: rememberMe,
    );

    try {
      final authResponse = await _authRepository.register(request);

      await _saveTokenExpiry(
        expiresAt: authResponse.expiresAt,
        expiresIn: authResponse.expiresIn,
      );

      // Fetch user info after successful registration
      try {
        final user = await _authRepository.getCurrentUser();
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      } catch (_) {
        // Even if user fetch fails, registration was successful
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      }
      // Enable auto-refresh
      _enableAutoRefresh();
    } on AppException catch (error) {
      // Debug logging
      logger.AppLogger.debug('=== Register Error Debug ===');
      logger.AppLogger.debug('Error type: ${error.runtimeType}');
      logger.AppLogger.debug('Error message: ${error.message}');
      logger.AppLogger.debug('Error statusCode: ${error.statusCode}');

      if (error is ValidationException) {
        logger.AppLogger.debug('Field errors: ${error.fieldErrors}');
        logger.AppLogger.debug('Error details: ${error.details}');
      }

      String userMessage = _getErrorMessage(error);
      Map<String, String>? fieldErrors = _getFieldErrors(error);

      logger.AppLogger.debug('User message: $userMessage');
      logger.AppLogger.debug('Field errors: $fieldErrors');
      logger.AppLogger.debug('========================');

      state = state.copyWith(
        isLoading: false,
        error: userMessage,
        fieldErrors: fieldErrors,
        currentOperation: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentOperation: null,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: AuthOperation.logout,
    );

    // Stop auto-refresh timer
    _disableAutoRefresh();

    final currentUserId = state.user?.id;
    final refreshToken = await _secureStorage.getRefreshToken();
    try {
      await _authRepository.logout(refreshToken);
    } catch (_) {
      // Even if logout API fails, clear local state
    }
    await _clearAuthState();
    await _clearPlaybackSnapshot(currentUserId);
    ref.read(dioClientProvider).clearETagCache();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  Future<void> refreshToken() async {
    if (state.isRefreshingToken) return;

    state = state.copyWith(
      isRefreshingToken: true,
      currentOperation: AuthOperation.refreshToken,
    );

    final refreshResult = await ref
        .read(dioClientProvider)
        .refreshSessionToken();
    if (!refreshResult.success) {
      if (refreshResult.isInvalidSessionFailure) {
        // Clear auth state and let router handle redirect automatically
        await _handleAuthError();
      }

      state = state.copyWith(
        isRefreshingToken: false,
        error: null,
        currentOperation: null,
      );
      return;
    }

    state = state.copyWith(
      isRefreshingToken: false,
      error: null,
      currentOperation: null,
    );
  }

  // Helper methods
  String _getErrorMessage(AppException error) {
    logger.AppLogger.debug('=== _getErrorMessage Debug ===');
    logger.AppLogger.debug('Error runtimeType: ${error.runtimeType}');
    logger.AppLogger.debug('Error message: ${error.message}');
    logger.AppLogger.debug('Error type check: ${error is ConflictException}');
    logger.AppLogger.debug('ConflictException type: $ConflictException');

    String result;
    switch (error) {
      case NetworkException():
        result = 'Network error. Please check your connection and try again.';
        break;
      case AuthenticationException():
        // Use the already user-friendly message from AuthenticationException
        result = error.message;
        break;
      case ValidationException():
        result = error.message;
        logger.AppLogger.debug('ValidationException message: $result');
        break;
      case ServerException():
        result = 'Server error. Please try again later.';
        break;
      case AuthorizationException():
        result = 'You do not have permission to perform this action.';
        break;
      case NotFoundException():
        result = 'The requested resource was not found.';
        break;
      case ConflictException():
        result = error.message;
        logger.AppLogger.debug('ConflictException message: $result');
        break;
      default:
        result = 'An unexpected error occurred. Please try again.';
        logger.AppLogger.debug('Default error case triggered');
    }

    logger.AppLogger.debug('Result message: $result');
    logger.AppLogger.debug('==========================');
    return result;
  }

  Map<String, String>? _getFieldErrors(AppException error) {
    if (error is ValidationException) {
      logger.AppLogger.debug('=== _getFieldErrors Debug ===');
      logger.AppLogger.debug('error.fieldErrors: ${error.fieldErrors}');
      logger.AppLogger.debug('error.details: ${error.details}');
      logger.AppLogger.debug('=============================');

      // Try fieldErrors first (from our updated code)
      final fieldErrors = error.fieldErrors;
      if (fieldErrors != null && fieldErrors.isNotEmpty) {
        return Map<String, String>.from(fieldErrors);
      }

      // Fall back to details (for backward compatibility)
      final details = error.details;
      if (details != null && details.isNotEmpty) {
        return Map<String, String>.from(details);
      }
    }
    return null;
  }

  Future<void> _handleAuthError() async {
    await _clearAuthState();
    state = state.copyWith(isAuthenticated: false, user: null);
  }

  /// Saves token expiry from auth response.
  /// Prioritizes server's UTC expires_at, falls back to relative expiresIn.
  Future<void> _saveTokenExpiry({
    DateTime? expiresAt,
    required int expiresIn,
  }) async {
    if (expiresAt != null) {
      await _secureStorage.saveTokenExpiry(expiresAt);
      logger.AppLogger.debug('✅ [Auth] Saved server UTC expiry: $expiresAt');
    } else if (expiresIn > 0) {
      final expiryUtc = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
      await _secureStorage.saveTokenExpiry(expiryUtc);
      logger.AppLogger.debug('✅ [Auth] Saved local UTC expiry: $expiryUtc');
    }
  }

  Future<void> _clearAuthState() async {
    await _secureStorage.clearTokens();
    await _secureStorage.clearTokenExpiry();
  }

  Future<void> _clearPlaybackSnapshot(String? userId) async {
    final storage = ref.read(localStorageServiceProvider);
    final keys = playbackSnapshotKeysToClearOnLogout(userId);
    for (final key in keys) {
      await storage.remove(key);
    }
  }

  Future<TokenRefreshResult> _attemptTokenRefresh() async {
    return ref.read(dioClientProvider).refreshSessionToken();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearFieldErrors() {
    state = state.copyWith(clearFieldErrors: true);
  }

  /// Reset loading state (called when auth check times out or is cancelled)
  void resetLoadingState() {
    if (state.isLoading) {
      state = state.copyWith(isLoading: false, currentOperation: null);
    }
  }

  /// Clear local auth state without calling logout API
  /// Used when switching servers to reset auth state cleanly
  Future<void> clearLocalAuthState() async {
    _disableAutoRefresh();
    final currentUserId = state.user?.id;
    await _clearAuthState();
    await _clearPlaybackSnapshot(currentUserId);
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  Future<void> checkAuthStatus() async {
    await _checkAuthStatus();
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFieldErrors: true,
      currentOperation: AuthOperation.forgotPassword,
    );

    final request = ForgotPasswordRequest(email: email);

    try {
      await _authRepository.forgotPassword(request);
      state = state.copyWith(
        isLoading: false,
        error: null,
        currentOperation: null,
      );
    } on AppException catch (error) {
      String userMessage = _getErrorMessage(error);
      state = state.copyWith(
        isLoading: false,
        error: userMessage,
        currentOperation: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentOperation: null,
      );
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFieldErrors: true,
      currentOperation: AuthOperation.resetPassword,
    );

    final request = ResetPasswordRequest(
      token: token,
      newPassword: newPassword,
    );

    try {
      await _authRepository.resetPassword(request);
      state = state.copyWith(
        isLoading: false,
        error: null,
        currentOperation: null,
      );
    } on AppException catch (error) {
      String userMessage = _getErrorMessage(error);
      Map<String, String>? fieldErrors = _getFieldErrors(error);

      state = state.copyWith(
        isLoading: false,
        error: userMessage,
        fieldErrors: fieldErrors,
        currentOperation: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentOperation: null,
      );
    }
  }

  // === Auto Token Refresh Methods ===

  /// Start automatic token refresh timer
  /// Checks token expiry every minute and refreshes 5 minutes before expiry
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer(); // Clear any existing timer

    _tokenRefreshTimer = Timer.periodic(
      const Duration(seconds: _tokenCheckIntervalSeconds),
      (_) => _checkAndRefreshToken(),
    );

    logger.AppLogger.debug('✅ [Auth] Token refresh timer started');
  }

  /// Stop automatic token refresh timer
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    logger.AppLogger.debug('⏹️ [Auth] Token refresh timer stopped');
  }

  /// Check if token needs refresh and refresh if necessary
  Future<void> _checkAndRefreshToken() async {
    // Only proceed if authenticated and not already refreshing
    if (!state.isAuthenticated || state.isRefreshingToken) {
      return;
    }

    try {
      final tokenExpiry = await _secureStorage.getTokenExpiry();
      if (tokenExpiry == null) {
        return; // No expiry info, skip
      }

      final now = DateTime.now().toUtc();
      final tokenExpiryUtc = tokenExpiry.toUtc();
      final timeUntilExpiry = tokenExpiryUtc.difference(now);

      // Add 2 minute safety margin to prevent clock skew issues
      const safetyMargin = Duration(minutes: 2);
      final effectiveBuffer = Duration(minutes: _tokenRefreshBufferMinutes) + safetyMargin;

      // Refresh if token expires in less than buffer time + safety margin
      if (timeUntilExpiry <= effectiveBuffer) {
        logger.AppLogger.debug(
          '🔄 [Auth] Token expiring in ${timeUntilExpiry.inMinutes}m ${timeUntilExpiry.inSeconds}s, auto-refreshing...',
        );
        await refreshToken();
      }
    } catch (e) {
      logger.AppLogger.debug('⚠️ [Auth] Error checking token expiry: $e');
    }
  }

  /// Start auto-refresh for authenticated user
  /// Call this after successful login or authentication check
  void _enableAutoRefresh() {
    _startTokenRefreshTimer();
  }

  /// Stop auto-refresh for logout
  /// Call this after logout
  void _disableAutoRefresh() {
    _stopTokenRefreshTimer();
  }
}
