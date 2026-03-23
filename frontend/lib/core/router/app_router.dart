import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/auth_verify_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/podcast/presentation/pages/podcast_list_page.dart';
import '../../features/podcast/presentation/pages/podcast_episodes_page.dart';
import '../../features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import '../../features/podcast/presentation/pages/podcast_daily_report_page.dart';
import '../../features/podcast/presentation/pages/podcast_highlights_page.dart';
import '../../features/podcast/presentation/navigation/podcast_navigation.dart';
import '../../features/profile/presentation/pages/profile_history_page.dart';
import '../../features/profile/presentation/pages/profile_cache_management_page.dart';
import '../../features/profile/presentation/pages/profile_subscriptions_page.dart';
import '../../features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import '../../core/localization/app_localizations_extension.dart';
import '../../core/widgets/app_shells.dart';
import '../../core/widgets/page_transitions.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Helper to create a custom transition page with fade-slide animation.
CustomTransitionPage<T> _buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
  ArcticPageTransitionType transitionType = ArcticPageTransitionType.fadeSlide,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeOutCubic);
      final curvedAnimation = animation.drive(curve);

      switch (transitionType) {
        case ArcticPageTransitionType.fade:
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );

        case ArcticPageTransitionType.fadeSlide:
          return SlideTransition(
            position: curvedAnimation.drive(
              Tween<Offset>(
                begin: const Offset(0.02, 0.0),
                end: Offset.zero,
              ),
            ),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );

        case ArcticPageTransitionType.slideUp:
          return SlideTransition(
            position: curvedAnimation.drive(
              Tween<Offset>(
                begin: const Offset(0.0, 0.03),
                end: Offset.zero,
              ),
            ),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );

        case ArcticPageTransitionType.scale:
          return ScaleTransition(
            scale: curvedAnimation.drive(
              Tween<double>(begin: 0.97, end: 1.0),
            ),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );

        default:
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
      }
    },
  );
}

/// Helper for modal-style transitions (bottom sheets, dialogs).
CustomTransitionPage<T> _buildModalPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeOutCubic);
      final curvedAnimation = animation.drive(curve);

      return SlideTransition(
        position: curvedAnimation.drive(
          Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ),
        ),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash', // Will be redirected by redirect logic
    debugLogDiagnostics: kDebugMode,
    observers: [appRouteObserver],
    refreshListenable: AuthStateListenable(
      ref,
    ), // Trigger refresh on auth state change
    routes: [
      // Splash (minimal, will auto-redirect via redirect logic)
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const SplashPage(),
          transitionType: ArcticPageTransitionType.fade,
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

      // Main app with bottom navigation
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const HomePage(),
        ),
      ),

      // Daily report route (no bottom nav)
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

      // Highlights route (no bottom nav)
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

      // Podcast routes (no bottom nav)
      GoRoute(
        path: '/podcast',
        name: 'podcast',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const _PlayerAwareRouteFrame(child: PodcastListPage()),
        ),
        routes: [
          // 1. 订阅的单集列表: /podcast/episodes/1
          GoRoute(
            path: 'episodes/:subscriptionId',
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
          // 2. 单集详情: /podcast/episodes/1/2
          GoRoute(
            path: 'episodes/:subscriptionId/:episodeId',
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
          // Direct episode detail route (for backward compatibility)
          GoRoute(
            path: 'episode/detail/:episodeId',
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
      ),

      // Profile routes
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const HomePage(initialTab: 2),
        ),
        routes: [
          GoRoute(
            path: 'cache',
            name: 'profile-cache',
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
            pageBuilder: (context, state) => _buildModalPage(
              state: state,
              child: const _PlayerAwareRouteFrame(child: ProfileHistoryPage()),
            ),
          ),
          GoRoute(
            path: 'subscriptions',
            name: 'profile-subscriptions',
            pageBuilder: (context, state) => _buildModalPage(
              state: state,
              child: const _PlayerAwareRouteFrame(child: ProfileSubscriptionsPage()),
            ),
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
      final isForgotPassword = state.matchedLocation.startsWith(
        '/forgot-password',
      );
      final isResetPassword = state.matchedLocation.startsWith(
        '/reset-password',
      );

      // Allow Splash
      if (isSplash) return null;

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
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
                          const SizedBox(),
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

class _PlayerAwareRouteFrame extends StatelessWidget {
  const _PlayerAwareRouteFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PodcastPlayerLayoutFrame(child: child);
  }
}
