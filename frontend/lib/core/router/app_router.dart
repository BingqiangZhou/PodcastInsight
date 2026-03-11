import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/auth_test_page.dart';
import '../../features/auth/presentation/pages/auth_verify_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/podcast/presentation/pages/podcast_list_page.dart';
import '../../features/podcast/presentation/pages/podcast_player_page.dart';
import '../../features/podcast/presentation/pages/podcast_episodes_page.dart';
import '../../features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import '../../features/podcast/presentation/pages/podcast_daily_report_page.dart';
import '../../features/podcast/presentation/navigation/podcast_navigation.dart';
import '../../features/profile/presentation/pages/profile_history_page.dart';
import '../../features/profile/presentation/pages/profile_cache_management_page.dart';
import '../../features/profile/presentation/pages/profile_subscriptions_page.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_shells.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash', // Will be redirected by redirect logic
    debugLogDiagnostics: kDebugMode,
    refreshListenable: AuthStateListenable(
      ref,
    ), // Trigger refresh on auth state change
    routes: [
      // Splash (minimal, will auto-redirect via redirect logic)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/auth-test',
        name: 'auth-test',
        builder: (context, state) => const AuthTestPage(),
      ),
      GoRoute(
        path: '/auth-verify',
        name: 'auth-verify',
        builder: (context, state) => const AuthVerifyPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordPage(token: token);
        },
      ),

      // Main app with bottom navigation
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // Daily report route (no bottom nav)
      GoRoute(
        path: '/reports/daily',
        name: 'dailyReport',
        builder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final parsedDate = _parseDateOnlyQuery(dateParam);
          return PodcastDailyReportPage(
            initialDate: parsedDate,
            source: state.uri.queryParameters['source'],
          );
        },
      ),

      // Podcast routes (no bottom nav)
      GoRoute(
        path: '/podcast',
        name: 'podcast',
        builder: (context, state) => const PodcastListPage(),
        routes: [
          // 1. 订阅的单集列表: /podcast/episodes/1
          GoRoute(
            path: 'episodes/:subscriptionId',
            name: 'podcastEpisodes',
            builder: (context, state) {
              final args = PodcastEpisodesPageArgs.extractFromState(state);
              if (args == null) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(child: Text(l10n.invalid_navigation_arguments)),
                );
              }
              return PodcastEpisodesPage(
                subscriptionId: args.subscriptionId,
                podcastTitle: args.podcastTitle,
                subscription: args.subscription,
              );
            },
          ),
          // 2. 单集详情: /podcast/episodes/1/2
          GoRoute(
            path: 'episodes/:subscriptionId/:episodeId',
            name: 'episodeDetail',
            builder: (context, state) {
              final args = PodcastEpisodeDetailPageArgs.extractFromState(state);
              if (args == null) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(child: Text(l10n.invalid_navigation_arguments)),
                );
              }
              return PodcastEpisodeDetailPage(episodeId: args.episodeId);
            },
          ),
          // Direct episode detail route (for backward compatibility)
          GoRoute(
            path: 'episode/detail/:episodeId',
            name: 'episodeDetailDirect',
            builder: (context, state) {
              final episodeId = int.tryParse(
                state.pathParameters['episodeId'] ?? '',
              );
              if (episodeId == null) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(child: Text(l10n.invalid_episode_id)),
                );
              }
              return PodcastEpisodeDetailPage(episodeId: episodeId);
            },
          ),
          // 4. 播放器: /podcast/player/1?subscriptionId=1
          GoRoute(
            path: 'player/:episodeId',
            name: 'episodePlayer',
            builder: (context, state) {
              final args = PodcastPlayerPageArgs.extractFromState(state);
              if (args == null) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(child: Text(l10n.invalid_navigation_arguments)),
                );
              }
              return PodcastPlayerPage(args: args);
            },
          ),
        ],
      ),

      // Profile routes
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const HomePage(initialTab: 2),
        routes: [
          GoRoute(
            path: 'cache',
            name: 'profile-cache',
            builder: (context, state) => const ProfileCacheManagementPage(),
          ),
          GoRoute(
            path: 'history',
            name: 'profile-history',
            builder: (context, state) => const ProfileHistoryPage(),
          ),
          GoRoute(
            path: 'subscriptions',
            name: 'profile-subscriptions',
            builder: (context, state) => const ProfileSubscriptionsPage(),
          ),
        ],
      ),
    ],

    // Redirect logic
    redirect: (context, state) {
      // Read latest auth state every time
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';
      final isAuthTest = state.matchedLocation.startsWith('/auth-test');
      final isForgotPassword = state.matchedLocation.startsWith(
        '/forgot-password',
      );
      final isResetPassword = state.matchedLocation.startsWith(
        '/reset-password',
      );

      // Allow Splash
      if (isSplash) return null;

      // Allow Auth Test page for debugging
      if (isAuthTest) return null;

      // Allow password reset pages
      if (isForgotPassword || isResetPassword) return null;

      if (!isAuthenticated) {
        // Not authenticated
        if (isLoggingIn || isRegistering) {
          // Allowed to be on login/register pages
          return null;
        }
        // Redirect to login
        return '/login';
      } else {
        // Authenticated
        if (isLoggingIn || isRegistering) {
          // If trying to login/register while authenticated, go home
          return '/home';
        }
        // Allowed to proceed
        return null;
      }
    },

    // Error handling
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );
});

// Helper for refreshListenable
class AuthStateListenable extends ChangeNotifier {
  final Ref ref;

  AuthStateListenable(this.ref) {
    ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}

class ErrorPage extends StatelessWidget {
  final Exception? error;

  const ErrorPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppPageBackdrop(),
          AppEmptyState(
            icon: Icons.error_outline,
            title: l10n.unknown_error,
            subtitle: error?.toString() ?? l10n.unknown_error,
            action: FilledButton(
              onPressed: () => context.go('/splash'),
              child: Text(l10n.home),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseDateOnlyQuery(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(local.year, local.month, local.day);
}
