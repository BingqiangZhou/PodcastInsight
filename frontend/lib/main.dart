import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:personal_ai_assistant/core/app/app.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/presentation/providers/onboarding_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_handler.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kDebugMode) {
        logger.AppLogger.configure(const logger.AppLoggerConfig.debug());
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logger.AppLogger.error(
          '[FlutterError] ${details.exceptionAsString()}',
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logger.AppLogger.error(
          '[PlatformError] $error',
          error: error,
          stackTrace: stack,
        );
        return true;
      };

      final isMobile = Platform.isAndroid || Platform.isIOS;

      // On mobile platforms, AudioService.init() wraps the handler in a
      // foreground service that provides lock-screen controls and a
      // persistent notification. On desktop, we use a plain handler.
      // The resulting handler is fed into Riverpod via a provider override
      // so that the entire app accesses a single instance through
      // [audioHandlerProvider].
      final PodcastAudioHandler platformAudioHandler;
      if (isMobile) {
        platformAudioHandler = await AudioService.init(
          builder: PodcastAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.personal_ai_assistant.audio',
            androidNotificationChannelName: 'Podcast Playback',
            androidNotificationChannelDescription:
                'Podcast audio playback controls',
            androidShowNotificationBadge: true,
            androidStopForegroundOnPause: false,
          ),
        );
        logger.AppLogger.info('AudioService initialized (mobile platform)');
      } else {
        platformAudioHandler = PodcastAudioHandler();
        logger.AppLogger.info(
          'PodcastAudioHandler initialized (desktop platform)',
        );
      }

      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          await Permission.notification.request();
        }
      }

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );

      // Desktop platforms allow all orientations (landscape is natural for desktop).
      // Mobile platforms lock to portrait for consistent mobile UX.
      final isDesktop =
          Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      if (isDesktop) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        // edgeToEdge system UI mode is only relevant for mobile.
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      final prefs = await SharedPreferences.getInstance();
      final storageService = LocalStorageServiceImpl(prefs);

      final initialThemeModeCode =
          await storageService.getString(
            AppConstants.themeKey,
          ) ??
          kThemeModeSystem;

      final customServerUrl = await storageService.getServerBaseUrl();
      if (customServerUrl != null && customServerUrl.isNotEmpty) {
        AppConfig.setServerBaseUrl(customServerUrl);
        logger.AppLogger.info('[AppInit] Loaded server URL: $customServerUrl');
      }

      final oldApiBaseUrl = await storageService.getApiBaseUrl();
      if (oldApiBaseUrl != null && oldApiBaseUrl.isNotEmpty) {
        await storageService.saveServerBaseUrl(oldApiBaseUrl);
        AppConfig.setServerBaseUrl(oldApiBaseUrl);
        logger.AppLogger.info(
          '[AppInit] Migrated old API URL to server URL: $oldApiBaseUrl',
        );
      }

      final hasCompletedOnboarding =
          await storageService.getBool(
            AppConstants.hasCompletedOnboardingKey,
          ) ??
          false;

      runApp(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storageService),
            audioHandlerProvider.overrideWithValue(platformAudioHandler),
            initialThemeModeCodeProvider.overrideWithValue(
              initialThemeModeCode,
            ),
            initialOnboardingCompletedProvider.overrideWithValue(
              hasCompletedOnboarding,
            ),
          ],
          child: const _AppWithSplashScreen(),
        ),
      );
    },
    (error, stackTrace) {
      logger.AppLogger.error(
        '[ZoneError] $error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class _AppWithSplashScreen extends StatelessWidget {
  const _AppWithSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const PersonalAIAssistantApp();
  }
}
