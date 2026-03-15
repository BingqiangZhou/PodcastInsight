import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_request.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../../../core/auth/auth_event.dart';
import '../../../../core/network/token_refresh_service.dart';
import '../../../../core/network/exceptions/network_exceptions.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/app_logger.dart' as logger;

// Token refresh constants
const int _tokenRefreshBufferMinutes = 5; // Refresh 5 minutes before expiry
const int _tokenCheckIntervalSeconds = 60; // Check every minute
const String _lastPlaybackSnapshotStorageKeyPrefix =
    'podcast_last_playback_snapshot_v1';

@visibleForTesting
List<String> playbackSnapshotKeysToClearOnLogout(String? userId) {
  final keys = <String>[_lastPlaybackSnapshotStorageKeyPrefix];
  if (userId != null && userId.isNotEmpty) {
    keys.add('${_lastPlaybackSnapshotStorageKeyPrefix}_$userId');
  }
  return keys;
}

// Storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageServiceImpl(const FlutterSecureStorage());
});

// Remote datasource provider - use shared DioClient
final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDatasourceImpl(dioClient);
});

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDatasource = ref.watch(authRemoteDatasourceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(remoteDatasource, secureStorage);
});

// Auth state notifier provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthState {
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
  late final AuthRepository _authRepository;
  late final SecureStorageService _secureStorage;
  Timer? _tokenRefreshTimer;
  StreamSubscription<AuthEvent>? _authEventSubscription;
  AppLifecycleListener? _lifecycleListener;

  @override
  AuthState build() {
    _authRepository = ref.read(authRepositoryProvider);
    _secureStorage = ref.read(secureStorageProvider);

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

        final result = await _authRepository.getCurrentUser();
        result.fold(
          (error) {
            if (error is AuthenticationException) {
              // For authentication errors, clear state and let router handle redirect
              // Don't show error message, just navigate to login
              _handleAuthError();
              state = state.copyWith(
                isLoading: false,
                error: null, // Don't show error message
                currentOperation: null,
              );
            } else {
              // For other errors, show error message
              String userMessage = _getErrorMessage(error);
              state = state.copyWith(
                isLoading: false,
                error: userMessage,
                currentOperation: null,
              );
            }
          },
          (user) => state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
            error: null,
            currentOperation: null,
          ),
        );
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

    final result = await _authRepository.login(request);
    result.fold(
      (error) {
        String userMessage = _getErrorMessage(error);
        Map<String, String>? fieldErrors = _getFieldErrors(error);

        state = state.copyWith(
          isLoading: false,
          error: userMessage,
          fieldErrors: fieldErrors,
          currentOperation: null,
        );
      },
      (authResponse) async {
        // Save token expiry - prioritize server's UTC expires_at, fall back to expiresIn
        if (authResponse.expiresAt != null) {
          // Use server's UTC expiration time
          await _secureStorage.saveTokenExpiry(authResponse.expiresAt!);
          logger.AppLogger.debug('✅ [Auth] Saved server UTC expiry: ${authResponse.expiresAt}');
        } else if (authResponse.expiresIn > 0) {
          // Fall back to relative expiresIn, convert to UTC
          final expiryUtc = DateTime.now().toUtc().add(
            Duration(seconds: authResponse.expiresIn),
          );
          await _secureStorage.saveTokenExpiry(expiryUtc);
          logger.AppLogger.debug('✅ [Auth] Saved local UTC expiry: $expiryUtc');
        }

        // Fetch user info after successful login
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (error) {
            // Even if user fetch fails, login was successful
            state = state.copyWith(
              isAuthenticated: true,
              isLoading: false,
              error: null,
              currentOperation: null,
            );
            // Enable auto-refresh
            _enableAutoRefresh();
          },
          (user) {
            state = state.copyWith(
              user: user,
              isAuthenticated: true,
              isLoading: false,
              error: null,
              currentOperation: null,
            );
            // Enable auto-refresh
            _enableAutoRefresh();
          },
        );
      },
    );
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

    final result = await _authRepository.register(request);
    result.fold(
      (error) {
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
      },
      (authResponse) async {
        // Save token expiry - prioritize server's UTC expires_at, fall back to expiresIn
        if (authResponse.expiresAt != null) {
          // Use server's UTC expiration time
          await _secureStorage.saveTokenExpiry(authResponse.expiresAt!);
          logger.AppLogger.debug('✅ [Auth] Saved server UTC expiry: ${authResponse.expiresAt}');
        } else if (authResponse.expiresIn > 0) {
          // Fall back to relative expiresIn, convert to UTC
          final expiryUtc = DateTime.now().toUtc().add(
            Duration(seconds: authResponse.expiresIn),
          );
          await _secureStorage.saveTokenExpiry(expiryUtc);
          logger.AppLogger.debug('✅ [Auth] Saved local UTC expiry: $expiryUtc');
        }

        // Fetch user info after successful registration
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (error) {
            // Even if user fetch fails, registration was successful
            state = state.copyWith(
              isAuthenticated: true,
              isLoading: false,
              error: null,
              currentOperation: null,
            );
            // Enable auto-refresh
            _enableAutoRefresh();
          },
          (user) {
            state = state.copyWith(
              user: user,
              isAuthenticated: true,
              isLoading: false,
              error: null,
              currentOperation: null,
            );
            // Enable auto-refresh
            _enableAutoRefresh();
          },
        );
      },
    );
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
    final result = await _authRepository.logout(refreshToken);
    await result.fold(
      (error) async {
        // Even if logout API fails, clear local state
        await _clearAuthState();
        await _clearPlaybackSnapshot(currentUserId);
        ref.read(dioClientProvider).clearETagCache();
        state = state.copyWith(isLoading: false, currentOperation: null);
      },
      (_) async {
        await _clearAuthState();
        await _clearPlaybackSnapshot(currentUserId);
        ref.read(dioClientProvider).clearETagCache();
        state = const AuthState(isAuthenticated: false, isLoading: false);
      },
    );
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
      if (error.fieldErrors != null && error.fieldErrors!.isNotEmpty) {
        return Map<String, String>.from(error.fieldErrors!);
      }

      // Fall back to details (for backward compatibility)
      if (error.details != null && error.details!.isNotEmpty) {
        return Map<String, String>.from(error.details!);
      }
    }
    return null;
  }

  Future<void> _handleAuthError() async {
    await _clearAuthState();
    state = state.copyWith(isAuthenticated: false, user: null);
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

    final result = await _authRepository.forgotPassword(request);
    result.fold(
      (error) {
        String userMessage = _getErrorMessage(error);
        state = state.copyWith(
          isLoading: false,
          error: userMessage,
          currentOperation: null,
        );
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      },
    );
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

    final result = await _authRepository.resetPassword(request);
    result.fold(
      (error) {
        String userMessage = _getErrorMessage(error);
        Map<String, String>? fieldErrors = _getFieldErrors(error);

        state = state.copyWith(
          isLoading: false,
          error: userMessage,
          fieldErrors: fieldErrors,
          currentOperation: null,
        );
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          error: null,
          currentOperation: null,
        );
      },
    );
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
