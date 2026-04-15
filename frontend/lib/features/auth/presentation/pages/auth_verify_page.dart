import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

class _VerifyStatus {
  const _VerifyStatus({required this.message, required this.color});

  final String message;
  final Color color;

  static const initial = _VerifyStatus(
    message: 'Ready to test...',
    color: Colors.grey,
  );

  _VerifyStatus copyWith({String? message, Color? color}) =>
      _VerifyStatus(message: message ?? this.message, color: color ?? this.color);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthVerifyNotifier extends Notifier<_VerifyStatus> {
  late final Dio _dio;

  String get _baseUrl => '${AppConfig.serverBaseUrl}/api/v1/auth';

  @override
  _VerifyStatus build() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
    ref.onDispose(() => _dio.close());
    return _VerifyStatus.initial;
  }

  Future<void> testBackendHealth() async {
    state = const _VerifyStatus(
      message: 'Testing backend connectivity...',
      color: Colors.blue,
    );

    try {
      final response = await _dio
          .get('$_baseUrl/health')
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        state = _VerifyStatus(
          message: 'Backend is reachable and healthy!',
          color: AppColors.accentWarm,
        );
      } else {
        state = _VerifyStatus(
          message: 'Backend responded with status: ${response.statusCode}',
          color: Colors.orange,
        );
      }
    } on DioException catch (e) {
      state = _VerifyStatus(
        message:
            'Failed to connect: ${e.message ?? e.type.toString()}\n\nMake sure backend Docker is running on port 8000',
        color: Colors.red,
      );
    } catch (e) {
      state = _VerifyStatus(
        message:
            'Failed to connect: $e\n\nMake sure backend Docker is running on port 8000',
        color: Colors.red,
      );
    }
  }

  Future<void> testRegister() async {
    state = const _VerifyStatus(
      message: 'Testing registration...',
      color: Colors.blue,
    );

    try {
      final response = await _dio.post(
        '$_baseUrl/register',
        data: {
          'email': 'flutter_verify@example.com',
          'password': 'Verify1234',
          'username': 'flutter_verify',
          'full_name': 'Flutter Verify User',
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = response.data;

      if (response.statusCode == 200) {
        state = _VerifyStatus(
          message:
              'Registration SUCCESS!\n\nUser: ${data['email']}\nID: ${data['id']}\n\nNow try login to get tokens.',
          color: AppColors.accentWarm,
        );
      } else if (response.statusCode == 409) {
        state = const _VerifyStatus(
          message: 'Email already exists (this is OK for repeat tests)',
          color: Colors.orange,
        );
      } else {
        state = _VerifyStatus(
          message: 'Registration failed: ${data['detail'] ?? response.data}',
          color: Colors.red,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        state = const _VerifyStatus(
          message: 'Email already exists (this is OK for repeat tests)',
          color: Colors.orange,
        );
      } else {
        final data = e.response?.data;
        state = _VerifyStatus(
          message:
              'Registration failed: ${data is Map ? (data['detail'] ?? data) : e.message}',
          color: Colors.red,
        );
      }
    } catch (e) {
      state = _VerifyStatus(message: 'Error: $e', color: Colors.red);
    }
  }

  Future<void> testLogin() async {
    state = const _VerifyStatus(
      message: 'Testing login...',
      color: Colors.blue,
    );

    try {
      final response = await _dio.post(
        '$_baseUrl/login',
        data: {
          'email_or_username': 'flutter_verify@example.com',
          'password': 'Verify1234',
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        state = _VerifyStatus(
          message:
              'Login SUCCESS!\n\nAccess Token: ${accessToken.substring(0, 30)}...\nRefresh Token: ${refreshToken.substring(0, 30)}...\n\nTry "Get User Info" to verify token works!',
          color: AppColors.accentWarm,
        );
      } else {
        final data = response.data;
        state = _VerifyStatus(
          message: 'Login failed: $data',
          color: Colors.red,
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      state = _VerifyStatus(
        message:
            'Login failed: ${data is Map ? (data['detail'] ?? data) : e.message}',
        color: Colors.red,
      );
    } catch (e) {
      state = _VerifyStatus(message: 'Error: $e', color: Colors.red);
    }
  }

  Future<void> testGetUser() async {
    state = const _VerifyStatus(
      message: 'Getting user info (needs login first)...',
      color: Colors.blue,
    );

    try {
      final loginResp = await _dio.post(
        '$_baseUrl/login',
        data: {
          'email_or_username': 'flutter_verify@example.com',
          'password': 'Verify1234',
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (loginResp.statusCode != 200) {
        state = const _VerifyStatus(
          message: 'Need to login first. Login failed.',
          color: Colors.red,
        );
        return;
      }

      final loginData = loginResp.data;
      final accessToken = loginData['access_token'];

      final userResp = await _dio.get(
        '$_baseUrl/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (userResp.statusCode == 200) {
        final userData = userResp.data;
        state = _VerifyStatus(
          message:
              'User Info Retrieval SUCCESS!\n\n'
              'Email: ${userData['email']}\n'
              'Username: ${userData['username']}\n'
              'Full Name: ${userData['full_name']}\n'
              'User ID: ${userData['id']}',
          color: AppColors.accentWarm,
        );
      } else {
        state = _VerifyStatus(
          message: 'Get user failed: ${userResp.statusCode}',
          color: Colors.red,
        );
      }
    } on DioException catch (e) {
      state = _VerifyStatus(
        message: 'Error: ${e.message ?? e.type.toString()}',
        color: Colors.red,
      );
    } catch (e) {
      state = _VerifyStatus(message: 'Error: $e', color: Colors.red);
    }
  }
}

final authVerifyProvider =
    NotifierProvider<AuthVerifyNotifier, _VerifyStatus>(
  AuthVerifyNotifier.new,
);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Authentication Verification Page - Direct API Testing
/// This page bypasses complex build issues and tests backend connectivity directly
class AuthVerifyPage extends ConsumerWidget {
  const AuthVerifyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(authVerifyProvider);
    final notifier = ref.read(authVerifyProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SurfacePanel(
                showBorder: false,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.auth_verification_title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 16),

                    // Status Display
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        status.message,
                        style: AppTheme.monoStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: status.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Test Buttons
                    _TestButton(
                      text: '1. Check Backend Health',
                      onPressed: notifier.testBackendHealth,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '2. Register New User',
                      onPressed: notifier.testRegister,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '3. Login (Get Tokens)',
                      onPressed: notifier.testLogin,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '4. Get User Info (with Token)',
                      onPressed: notifier.testGetUser,
                    ),
                    const SizedBox(height: 20),

                    // Instructions
                    _buildInstructions(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Flow:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '1. Must run Backend Docker first (port 8000)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          '2. Click "Check Health" to verify connection',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          '3. Click "Register" to create test user',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          '4. Click "Login" to get access/refresh tokens',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          '5. Click "Get User Info" to verify tokens work',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          '6. If all pass - Backend is Ready!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.text,
    required this.onPressed,
  });
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.mdLgRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Text(
              text,
              style: AppTheme.monoStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
