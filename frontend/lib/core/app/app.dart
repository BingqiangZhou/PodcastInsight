import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../localization/locale_provider.dart';
import '../providers/route_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_shells.dart';
import '../utils/app_logger.dart' as logger;
import '../../shared/widgets/loading_widget.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/settings/presentation/providers/app_update_provider.dart';
import '../../features/settings/presentation/widgets/update_dialog.dart';

import '../../main.dart' as main_app;

/// Splash screen widget that matches the Mindriver brand style
class _SplashScreenWidget extends StatelessWidget {
  const _SplashScreenWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppPageBackdrop(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Image.asset(
                      'assets/icons/Logo3.png',
                      key: const Key('app_init_logo'),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n?.appTitle ?? 'Stella',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.appSlogan ?? 'Dawn\'s near. Let\'s begin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const LoadingWidget(
                    key: Key('app_init_loading_indicator'),
                    size: 30,
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _wrapAppChild(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final navigationBarColor = Color.alphaBlend(
    theme.colorScheme.surface.withValues(alpha: isDark ? 0.16 : 0.24),
    theme.scaffoldBackgroundColor,
  );

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
    child: MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.8,
      maxScaleFactor: 1.2,
      child: child,
    ),
  );
}

class PersonalAIAssistantApp extends ConsumerStatefulWidget {
  const PersonalAIAssistantApp({super.key});

  @override
  ConsumerState<PersonalAIAssistantApp> createState() =>
      _PersonalAIAssistantAppState();
}

class _PersonalAIAssistantAppState
    extends ConsumerState<PersonalAIAssistantApp> {
  bool _isInitialized = false;
  GoRouter? _routeSyncRouter;
  VoidCallback? _routeSyncListener;
  bool _routeSyncScheduled = false;
  String? _pendingRoute;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupRouteListener();
  }

  @override
  void dispose() {
    if (_routeSyncRouter != null && _routeSyncListener != null) {
      _routeSyncRouter!.routerDelegate.removeListener(_routeSyncListener!);
    }
    // CRITICAL: Release audio resources when app is disposed
    // This ensures the audio player and (on mobile) the AudioService foreground service are properly cleaned up
    _cleanupAudioService();
    super.dispose();
  }

  /// Cleanup audio service resources
  /// Works on both mobile (with AudioService) and desktop (without AudioService)
  Future<void> _cleanupAudioService() async {
    try {
      // stopService() will:
      // - On mobile: Stop AudioService, stop playback, dispose player
      // - On desktop: Stop playback, dispose player
      await main_app.audioHandler.stopService();

      logger.AppLogger.debug('[AppInit] Audio handler stopped and cleaned up');
    } catch (e) {
      logger.AppLogger.debug('[AppInit] Error cleaning up audio handler: $e');
    }
  }

  Future<void> _initializeApp() async {
    final startedAt = DateTime.now();
    // Wrap auth check in timeout to prevent infinite loading
    try {
      // Load saved locale from storage
      await ref.read(localeProvider.notifier).loadSavedLocale();

      // Load saved theme mode from storage
      await ref.read(themeModeProvider.notifier).loadSavedThemeMode();

      // Check authentication status with timeout to prevent infinite loading
      // If backend is down, we still want the app to load
      await ref
          .read(authProvider.notifier)
          .checkAuthStatus()
          .timeout(
            const Duration(seconds: 15), // Extended from 5 to 15 seconds
            onTimeout: () {
              logger.AppLogger.debug(
                '[AppInit] Auth check timed out after 15 seconds',
              );
              // Mark as incomplete - the background task will complete eventually
              // but we won't wait for it
              throw TimeoutException('Auth check timed out');
            },
          );
    } on TimeoutException catch (_) {
      logger.AppLogger.debug(
        '[AppInit] Auth check timed out - continuing anyway',
      );
      // CRITICAL: Reset loading state to prevent infinite loading
      // The timeout happens externally, so auth provider's state doesn't get updated
      ref.read(authProvider.notifier).resetLoadingState();

      // Retry auth check in background after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(authProvider.notifier).checkAuthStatus().catchError((e) {
            logger.AppLogger.debug(
              '[AppInit] Background auth retry failed: $e',
            );
          });
        }
      });
      // The router will redirect to login since isAuthenticated defaults to false
      // Background auth check may complete later but won't affect UI
    } catch (e) {
      logger.AppLogger.debug(
        '[AppInit] Auth check failed: $e, continuing initialization',
      );
      // CRITICAL: Reset loading state on error
      ref.read(authProvider.notifier).resetLoadingState();
      // Don't block app initialization on auth errors
      // The router will handle redirecting to login if needed
    }

    const minSplash = Duration(milliseconds: 120);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    // Auto-check for updates after app is fully initialized
    if (mounted) {
      _autoCheckForUpdates();
    }
  }

  /// Automatically check for updates in background
  /// Shows notification if update is available
  Future<void> _autoCheckForUpdates() async {
    // Wait a bit longer to ensure app is fully loaded
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Get update state (will use cache if available)
      final updateState = await ref.read(autoUpdateCheckProvider.future);

      if (!mounted) return;

      // Show update dialog if update is available
      if (updateState.hasUpdate && updateState.latestRelease != null) {
        // Use the GoRouter's navigator context which is inside MaterialApp
        // (the state's own context is above MaterialApp, so AppLocalizations
        // and ScaffoldMessenger would not be found from it).
        final router = ref.read(appRouterProvider);
        final navContext = appNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          AppUpdateDialog.show(
            context: navContext,
            release: updateState.latestRelease!,
            currentVersion: updateState.currentVersion,
          );
        }
      }
    } catch (e) {
      // Silently fail on auto-check errors
      logger.AppLogger.debug('Auto-check for updates failed: $e');
    }
  }

  void _setupRouteListener() {
    final router = ref.read(appRouterProvider);

    void queueCurrentRouteUpdate(String route) {
      _pendingRoute = route;
      if (_routeSyncScheduled) {
        return;
      }
      _routeSyncScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeSyncScheduled = false;
        if (!mounted) {
          return;
        }

        final routeToApply = _pendingRoute;
        _pendingRoute = null;
        if (routeToApply == null) {
          return;
        }

        final notifier = ref.read(currentRouteProvider.notifier);
        final currentRoute = ref.read(currentRouteProvider);
        if (currentRoute != routeToApply) {
          notifier.setRoute(routeToApply);
        }
      });
    }

    void syncCurrentRoute() {
      if (!mounted) {
        return;
      }

      try {
        final RouteMatchList matchList =
            router.routerDelegate.currentConfiguration;
        queueCurrentRouteUpdate(matchList.uri.toString());
      } catch (_) {
        queueCurrentRouteUpdate('/');
      }
    }

    _routeSyncRouter = router;
    _routeSyncListener = syncCurrentRoute;
    router.routerDelegate.addListener(syncCurrentRoute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncCurrentRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while initializing
    if (!_isInitialized) {
      return MaterialApp(
        key: const ValueKey('app_splash_shell'),
        title: 'Stella',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ref.watch(themeModeProvider),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        builder: (context, child) =>
            _wrapAppChild(context, child ?? const SizedBox.shrink()),
        home: const _SplashScreenWidget(),
      );
    }

    // Show main app after initialization
    return MaterialApp.router(
      key: const ValueKey('app_router_shell'),
      title: 'Stella',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),

      // Router configuration
      routerConfig: ref.watch(appRouterProvider),

      // Localization
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh')],

      builder: (context, child) =>
          _wrapAppChild(context, child ?? const SizedBox.shrink()),
    );
  }
}
