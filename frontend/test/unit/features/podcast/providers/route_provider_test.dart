import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';

void main() {
  group('RouteProvider Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('currentRouteProvider', () {
      test('should have default route value of "/"', () {
        // Act
        final route = container.read(currentRouteProvider);

        // Assert
        expect(route, '/');
      });

      test('should update route when setRoute is called', () {
        // Arrange
        const newRoute = '/podcast/episodes/1/42';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(newRoute);

        // Assert
        expect(container.read(currentRouteProvider), newRoute);
      });

      test('should handle multiple route updates', () {
        // Act & Assert - First update
        container.read(currentRouteProvider.notifier).setRoute('/feed');
        expect(container.read(currentRouteProvider), '/feed');

        // Act & Assert - Second update
        container.read(currentRouteProvider.notifier).setRoute('/discover');
        expect(container.read(currentRouteProvider), '/discover');

        // Act & Assert - Third update
        container.read(currentRouteProvider.notifier).setRoute('/profile');
        expect(container.read(currentRouteProvider), '/profile');
      });

      test('should handle routes with query parameters', () {
        // Arrange
        const routeWithQuery = '/feed?page=2&sort=newest';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(routeWithQuery);

        // Assert
        expect(container.read(currentRouteProvider), routeWithQuery);
      });

      test('should handle deep link routes', () {
        // Arrange
        const deepLinkRoute = '/podcast/episodes/123/456?position=120';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(deepLinkRoute);

        // Assert
        expect(container.read(currentRouteProvider), deepLinkRoute);
      });
    });

    group('isOnEpisodeDetailPageProvider', () {
      test('should return false when on root route', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, false);
      });

      test('should return true when on podcast episode detail page', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/podcast/episodes/1/42');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, true);
      });

      test('should return true for direct episode detail route', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/podcast/episode/detail/42');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, true);
      });

      test('should return false when on feed page', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/feed');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, false);
      });

      test('should return false when on discover page', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/discover');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, false);
      });

      test('should return false when on profile page', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/profile');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, false);
      });

      test('should return true for episode detail with query params', () {
        // Arrange
        container.read(currentRouteProvider.notifier).setRoute('/podcast/episodes/5/10?autoplay=true');

        // Act
        final isOnDetail = container.read(isOnEpisodeDetailPageProvider);

        // Assert
        expect(isOnDetail, true);
      });

      test('should reactively update when route changes', () {
        // Start on home page
        container.read(currentRouteProvider.notifier).setRoute('/');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // Navigate to episode detail
        container.read(currentRouteProvider.notifier).setRoute('/podcast/episodes/42/100');
        expect(container.read(isOnEpisodeDetailPageProvider), true);

        // Navigate back to feed
        container.read(currentRouteProvider.notifier).setRoute('/feed');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // Navigate to direct detail route
        container.read(currentRouteProvider.notifier).setRoute('/podcast/episode/detail/100');
        expect(container.read(isOnEpisodeDetailPageProvider), true);
      });

      test('should handle edge case routes correctly', () {
        // Edge case: route contains 'episodes' but not in path context
        container.read(currentRouteProvider.notifier).setRoute('/episodes/podcast');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // Edge case: empty route
        container.read(currentRouteProvider.notifier).setRoute('');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // Edge case: just /podcast prefix
        container.read(currentRouteProvider.notifier).setRoute('/podcast');
        expect(container.read(isOnEpisodeDetailPageProvider), false);
      });
    });

    group('RouteProvider integration tests', () {
      test('should maintain state consistency between providers', () {
        // Simulate navigation flow
        final notifier = container.read(currentRouteProvider.notifier);

        // 1. Start at root
        notifier.setRoute('/');
        expect(container.read(currentRouteProvider), '/');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // 2. Navigate to feed
        notifier.setRoute('/feed');
        expect(container.read(currentRouteProvider), '/feed');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // 3. Navigate to episode detail
        notifier.setRoute('/podcast/episodes/10/20');
        expect(container.read(currentRouteProvider), '/podcast/episodes/10/20');
        expect(container.read(isOnEpisodeDetailPageProvider), true);

        // 4. Navigate to discover
        notifier.setRoute('/discover');
        expect(container.read(currentRouteProvider), '/discover');
        expect(container.read(isOnEpisodeDetailPageProvider), false);

        // 5. Navigate to direct episode detail
        notifier.setRoute('/podcast/episode/detail/20');
        expect(container.read(currentRouteProvider), '/podcast/episode/detail/20');
        expect(container.read(isOnEpisodeDetailPageProvider), true);
      });

      test('should handle rapid route changes', () {
        final notifier = container.read(currentRouteProvider.notifier);

        // Simulate rapid navigation
        for (var i = 0; i < 10; i++) {
          notifier.setRoute('/route/$i');
          expect(container.read(currentRouteProvider), '/route/$i');
        }

        // Final state should be the last route set
        expect(container.read(currentRouteProvider), '/route/9');
      });
    });
  });
}
