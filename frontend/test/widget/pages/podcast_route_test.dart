import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Podcast Route Tests', () {
    testWidgets('should navigate to podcast episodes page with correct route', (tester) async {
      // Build the app with router
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/podcast',
              routes: [
                GoRoute(
                  path: '/podcast',
                  name: 'podcast',
                  builder: (context, state) => const Scaffold(body: Text('Podcast List')),
                  routes: [
                    GoRoute(
                      path: 'episodes/:subscriptionId',
                      name: 'podcastEpisodes',
                      builder: (context, state) => Scaffold(
                        body: Text('Episodes for ${state.pathParameters['subscriptionId']}'),
                      ),
                    ),
                    GoRoute(
                      path: 'episodes/:subscriptionId/:episodeId',
                      name: 'episodeDetail',
                      builder: (context, state) => Scaffold(
                        body: Text('Episode ${state.pathParameters['episodeId']}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial page
      expect(find.text('Podcast List'), findsOneWidget);

      // Test navigation to episodes list (subscription ID = 1)
      final context = tester.element(find.text('Podcast List'));
      final router = GoRouter.of(context);

      // This should work: /podcast/episodes/1
      router.go('/podcast/episodes/1');
      await tester.pumpAndSettle();

      expect(find.text('Episodes for 1'), findsOneWidget);

      // Test navigation to episode detail (subscription ID = 1, episode ID = 2)
      router.go('/podcast/episodes/1/2');
      await tester.pumpAndSettle();

      expect(find.text('Episode 2'), findsOneWidget);
    });

    testWidgets('should reject invalid route /podcasts/episodes/1', (tester) async {
      // Build the app with router
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/podcast',
              routes: [
                GoRoute(
                  path: '/podcast',
                  name: 'podcast',
                  builder: (context, state) => const Scaffold(body: Text('Podcast List')),
                  routes: [
                    GoRoute(
                      path: 'episodes/:subscriptionId',
                      name: 'podcastEpisodes',
                      builder: (context, state) => Scaffold(
                        body: Text('Episodes for ${state.pathParameters['subscriptionId']}'),
                      ),
                    ),
                  ],
                ),
              ],
              errorBuilder: (context, state) => Scaffold(
                body: Text('Route Error: ${state.error}'),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('Podcast List'));
      final router = GoRouter.of(context);

      // This should fail: /podcasts/episodes/1 (wrong plural form)
      router.go('/podcasts/episodes/1');
      await tester.pumpAndSettle();

      // Should show error page
      expect(find.textContaining('Route Error'), findsOneWidget);
    });
  });
}