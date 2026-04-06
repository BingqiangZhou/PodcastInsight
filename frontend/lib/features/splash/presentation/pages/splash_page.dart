import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/glass/glass_background.dart';

/// Minimal splash page that immediately redirects
/// The native splash screen (with app icon) is shown during Flutter initialization
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Navigate immediately without delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() async {
    if (!mounted) return;

    // Request notification permission for media controls (Android 13+ / iOS)
    unawaited(_requestNotificationPermission());

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      context.go('/feed');
    } else {
      context.go('/login');
    }
  }

  /// Request notification permission for audio playback media controls
  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;

      // Request permission if not granted
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      // Don't block app startup if permission request fails
      logger.AppLogger.debug('⚠️ Failed to request notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        theme: GlassBackgroundTheme.neutral,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
