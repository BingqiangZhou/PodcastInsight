import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/glass/glass_background.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';

/// Authentication Verification Page - Direct API Testing
/// This page bypasses complex build issues and tests backend connectivity directly
class AuthVerifyPage extends StatefulWidget {
  const AuthVerifyPage({super.key});

  @override
  State<AuthVerifyPage> createState() => _AuthVerifyPageState();
}

class _AuthVerifyPageState extends State<AuthVerifyPage> {
  String _status = 'Ready to test...';
  Color _statusColor = Colors.grey;

  late final Dio _dio;

  String get baseUrl => '${AppConfig.serverBaseUrl}/api/v1/auth';

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _testBackendHealth() async {
    setState(() {
      _status = 'Testing backend connectivity...';
      _statusColor = Colors.blue;
    });

    try {
      final response = await _dio
          .get('$baseUrl/health')
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _status = '✅ Backend is reachable and healthy!';
          _statusColor = AppColors.accentWarm;
        });
      } else {
        setState(() {
          _status = '❌ Backend responded with status: ${response.statusCode}';
          _statusColor = Colors.orange;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _status = '❌ Failed to connect: ${e.message ?? e.type.toString()}\n\nMake sure backend Docker is running on port 8000';
        _statusColor = Colors.red;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Failed to connect: $e\n\nMake sure backend Docker is running on port 8000';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _testRegister() async {
    setState(() {
      _status = 'Testing registration...';
      _statusColor = Colors.blue;
    });

    try {
      final response = await _dio.post(
        '$baseUrl/register',
        data: {
          'email': 'flutter_verify@example.com',
          'password': 'Verify1234',
          'username': 'flutter_verify',
          'full_name': 'Flutter Verify User',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final data = response.data;

      if (response.statusCode == 200) {
        setState(() {
          _status = '✅ Registration SUCCESS!\n\nUser: ${data['email']}\nID: ${data['id']}\n\nNow try login to get tokens.';
          _statusColor = AppColors.accentWarm;
        });
      } else if (response.statusCode == 409) {
        setState(() {
          _status = 'ℹ️ Email already exists (this is OK for repeat tests)';
          _statusColor = Colors.orange;
        });
      } else {
        setState(() {
          _status = '❌ Registration failed: ${data['detail'] ?? response.data}';
          _statusColor = Colors.red;
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        setState(() {
          _status = 'ℹ️ Email already exists (this is OK for repeat tests)';
          _statusColor = Colors.orange;
        });
      } else {
        final data = e.response?.data;
        setState(() {
          _status = '❌ Registration failed: ${data is Map ? (data['detail'] ?? data) : e.message}';
          _statusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _status = 'Testing login...';
      _statusColor = Colors.blue;
    });

    try {
      final response = await _dio.post(
        '$baseUrl/login',
        data: {
          'email_or_username': 'flutter_verify@example.com',
          'password': 'Verify1234',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        setState(() {
          _status = '✅ Login SUCCESS!\n\nAccess Token: ${accessToken.substring(0, 30)}...\nRefresh Token: ${refreshToken.substring(0, 30)}...\n\nTry "Get User Info" to verify token works!';
          _statusColor = AppColors.accentWarm;
        });
      } else {
        final data = response.data;
        setState(() {
          _status = '❌ Login failed: $data';
          _statusColor = Colors.red;
        });
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _status = '❌ Login failed: ${data is Map ? (data['detail'] ?? data) : e.message}';
        _statusColor = Colors.red;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _testGetUser() async {
    setState(() {
      _status = 'Getting user info (needs login first)...';
      _statusColor = Colors.blue;
    });

    // First get a token
    try {
      final loginResp = await _dio.post(
        '$baseUrl/login',
        data: {
          'email_or_username': 'flutter_verify@example.com',
          'password': 'Verify1234',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (loginResp.statusCode != 200) {
        setState(() {
          _status = '❌ Need to login first. Login failed.';
          _statusColor = Colors.red;
        });
        return;
      }

      final loginData = loginResp.data;
      final accessToken = loginData['access_token'];

      // Now get user info
      final userResp = await _dio.get(
        '$baseUrl/me',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (userResp.statusCode == 200) {
        final userData = userResp.data;
        setState(() {
          _status = '✅ User Info Retrieval SUCCESS!\n\n'
              'Email: ${userData['email']}\n'
              'Username: ${userData['username']}\n'
              'Full Name: ${userData['full_name']}\n'
              'User ID: ${userData['id']}';
          _statusColor = AppColors.accentWarm;
        });
      } else {
        setState(() {
          _status = '❌ Get user failed: ${userResp.statusCode}';
          _statusColor = Colors.red;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _status = '❌ Error: ${e.message ?? e.type.toString()}';
        _statusColor = Colors.red;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        theme: GlassBackgroundTheme.neutral,
        child: SafeArea(
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Display
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 12,
                      child: Text(
                        _status,
                        style: AppTheme.monoStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Test Buttons
                    _TestButton(
                      text: '🔧 1. Check Backend Health',
                      onPressed: _testBackendHealth,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '📝 2. Register New User',
                      onPressed: _testRegister,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '🔓 3. Login (Get Tokens)',
                      onPressed: _testLogin,
                    ),
                    const SizedBox(height: 8),

                    _TestButton(
                      text: '👤 4. Get User Info (with Token)',
                      onPressed: _testGetUser,
                    ),
                    const SizedBox(height: 20),

                    // Instructions
                    _buildInstructions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📋 Test Flow:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text('1. Must run Backend Docker first (port 8000)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('2. Click "Check Health" to verify connection', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('3. Click "Register" to create test user', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('4. Click "Login" to get access/refresh tokens', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('5. Click "Get User Info" to verify tokens work', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('6. If all pass → Backend ✅ Ready!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    return SurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
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
