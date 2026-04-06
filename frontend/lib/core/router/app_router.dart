import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/auth_verify_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/onboarding_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/register_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/reset_password_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/onboarding_provider.dart';
import 'package:personal_ai_assistant/features/home/presentation/pages/home_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_daily_report_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_downloads_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episodes_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_highlights_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_history_page.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_subscriptions_page.dart';
import 'package:personal_ai_assistant/features/settings/presentation/pages/appearance_page.dart';
import 'package:personal_ai_assistant/features/splash/presentation/pages/splash_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Helper to create a custom transition page with fade animation.
CustomTransitionPage<T> _buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

/// Helper for modal-style transitions (same as standard for simplicity).
CustomTransitionPage<T> _buildModalPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    observers: [appRouteObserver],
    refreshListenable: AuthStateListenable(ref),
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const SplashPage(),
        ),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/auth-verify',
        name: 'auth-verify',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const AuthVerifyPage(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return _buildPageWithTransition(
            state: state,
            child: ResetPasswordPage(token: token),
          );
        },
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const OnboardingPage(),
        ),
      ),

      // Main app shell with persistent tab navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellWidget(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Discover (Podcast list)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: 'discover',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const PodcastListPage(),
                ),
              ),
            ],
          ),
          // Branch 1: Feed (default)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                name: 'feed',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const PodcastFeedPage(),
                ),
              ),
            ],
          ),
          // Branch 2: Profile (previously Branch 3)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const ProfilePage(),
                ),
                routes: [
                  // Profile sub-routes push over the shell
                  GoRoute(
                    path: 'cache',
                    name: 'profile-cache',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileCacheManagementPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'history',
                    name: 'profile-history',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileHistoryPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'subscriptions',
                    name: 'profile-subscriptions',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileSubscriptionsPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'downloads',
                    name: 'profile-downloads',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: PodcastDownloadsPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Pushed routes (cover the shell, no bottom nav)

      GoRoute(
        path: '/settings/appearance',
        name: 'appearance',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const AppearancePage(),
        ),
      ),

      // Daily report
      GoRoute(
        path: '/reports/daily',
        name: 'dailyReport',
        pageBuilder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final parsedDate = _parseDateOnlyQuery(dateParam);
          return _buildModalPage(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastDailyReportPage(
                initialDate: parsedDate,
                source: state.uri.queryParameters['source'],
              ),
            ),
          );
        },
      ),

      // Highlights
      GoRoute(
        path: '/highlights',
        name: 'highlights',
        pageBuilder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final parsedDate = _parseDateOnlyQuery(dateParam);
          return _buildModalPage(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastHighlightsPage(
                initialDate: parsedDate,
                source: state.uri.queryParameters['source'],
              ),
            ),
          );
        },
      ),

      // Podcast routes (cover the shell)
      GoRoute(
        path: '/podcast',
        name: 'podcast',
        redirect: (context, state) => '/discover',
      ),
      GoRoute(
        path: '/podcast/episodes/:subscriptionId',
        name: 'podcastEpisodes',
        pageBuilder: (context, state) {
          final args = PodcastEpisodesPageArgs.extractFromState(state);
          if (args == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_navigation_arguments)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastEpisodesPage(
                subscriptionId: args.subscriptionId,
                podcastTitle: args.podcastTitle,
                subscription: args.subscription,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/podcast/episodes/:subscriptionId/:episodeId',
        name: 'episodeDetail',
        pageBuilder: (context, state) {
          final args = PodcastEpisodeDetailPageArgs.extractFromState(state);
          if (args == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_navigation_arguments)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastEpisodeDetailPage(episodeId: args.episodeId),
            ),
          );
        },
      ),
      GoRoute(
        path: '/podcast/episode/detail/:episodeId',
        name: 'episodeDetailDirect',
        pageBuilder: (context, state) {
          final episodeId = int.tryParse(
            state.pathParameters['episodeId'] ?? '',
          );
          if (episodeId == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_episode_id)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastEpisodeDetailPage(episodeId: episodeId),
            ),
          );
        },
      ),
    ],

    // Redirect logic
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isForgotPassword = state.matchedLocation.startsWith(
        '/forgot-password',
      );
      final isResetPassword = state.matchedLocation.startsWith(
        '/reset-password',
      );

      // Redirect legacy /home to /feed
      if (state.matchedLocation == '/home') {
        return '/feed';
      }

      // Allow Splash
      if (isSplash) return null;

      // Allow password reset pages
      if (isForgotPassword || isResetPassword) {
        return null;
      }

      if (!isAuthenticated) {
        if (isLoggingIn || isRegistering) {
          return null;
        }
        return '/login';
      } else {
        // Authenticated user checks
        if (isLoggingIn || isRegistering) {
          return '/feed';
        }

        // Onboarding check: if not completed, redirect to onboarding
        final hasCompletedOnboarding = ref.read(onboardingCompletedProvider);
        if (!hasCompletedOnboarding && !isOnboarding) {
          return '/onboarding';
        }
        // Don't let authenticated users go back to onboarding if completed
        if (hasCompletedOnboarding && isOnboarding) {
          return '/feed';
        }

        return null;
      }
    },

    // Error handling
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );
});

// Helper for refreshListenable - notifies on auth status or onboarding changes
class AuthStateListenable extends ChangeNotifier {

  AuthStateListenable(this.ref) {
    ref.listen(authProvider.select((s) => s.isAuthenticated), (previous, next) {
      notifyListeners();
    });
    ref.listen(onboardingCompletedProvider, (previous, next) {
      notifyListeners();
    });
  }
  final Ref ref;
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: AppEmptyState(
            icon: Icons.error_outline,
            title: l10n.unknown_error,
            subtitle: error?.toString() ?? l10n.unknown_error,
            action: FilledButton(
              onPressed: () => context.go('/feed'),
              child: Text(l10n.home),
            ),
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

class _PlayerAwareRouteFrame extends StatelessWidget {
  const _PlayerAwareRouteFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PodcastPlayerLayoutFrame(child: child);
  }
}
