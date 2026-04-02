import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';

void main() {
  // ── PodcastDiscoverPaginationState ──────────────────────────────

  group('PodcastDiscoverPaginationState', () {
    test('default values', () {
      const state = PodcastDiscoverPaginationState();
      expect(state.loadedCount, 0);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isFalse);
    });

    test('copyWith returns new instance with updated fields', () {
      const original = PodcastDiscoverPaginationState();
      final updated = original.copyWith(
        loadedCount: 25,
        isLoadingMore: true,
        hasMore: true,
      );

      expect(updated.loadedCount, 25);
      expect(updated.isLoadingMore, isTrue);
      expect(updated.hasMore, isTrue);

      // Original is unchanged
      expect(original.loadedCount, 0);
      expect(original.isLoadingMore, isFalse);
    });

    test('copyWith preserves fields when not specified', () {
      const state = PodcastDiscoverPaginationState(
        loadedCount: 50,
        isLoadingMore: true,
        hasMore: true,
      );
      final updated = state.copyWith(loadedCount: 75);

      expect(updated.loadedCount, 75);
      expect(updated.isLoadingMore, isTrue);
      expect(updated.hasMore, isTrue);
    });

    test('equality works for identical states', () {
      const a = PodcastDiscoverPaginationState(
        loadedCount: 10,
        isLoadingMore: true,
        hasMore: false,
      );
      const b = PodcastDiscoverPaginationState(
        loadedCount: 10,
        isLoadingMore: true,
        hasMore: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different fields', () {
      const a = PodcastDiscoverPaginationState(loadedCount: 10);
      const b = PodcastDiscoverPaginationState(loadedCount: 20);
      expect(a, isNot(equals(b)));
    });

    test('props contain all fields', () {
      const state = PodcastDiscoverPaginationState(
        loadedCount: 5,
        isLoadingMore: true,
        hasMore: true,
      );
      expect(state.props, [5, true, true]);
    });
  });

  // ── PodcastDiscoverState ────────────────────────────────────────

  group('PodcastDiscoverState', () {
    PodcastDiscoverState defaultState() {
      return const PodcastDiscoverState(country: PodcastCountry.usa);
    }

    // -- Default values --

    group('default values', () {
      test('has expected defaults', () {
        final state = defaultState();
        expect(state.country, PodcastCountry.usa);
        expect(state.isLoading, isFalse);
        expect(state.isRefreshing, isFalse);
        expect(state.error, isNull);
        expect(state.selectedTab, PodcastDiscoverTab.episodes);
        expect(state.selectedCategory, PodcastDiscoverState.allCategoryValue);
        expect(state.topShows, isEmpty);
        expect(state.topEpisodes, isEmpty);
        expect(state.showsPagination, const PodcastDiscoverPaginationState());
        expect(
          state.episodesPagination,
          const PodcastDiscoverPaginationState(),
        );
        expect(state.lastRefreshTime, isNull);
      });
    });

    // -- copyWith --

    group('copyWith', () {
      test('updates individual fields', () {
        final base = defaultState();
        final updated = base.copyWith(isLoading: true, error: 'oops');
        expect(updated.isLoading, isTrue);
        expect(updated.error, 'oops');
        expect(updated.country, PodcastCountry.usa);
      });

      test('preserves fields not specified', () {
        final base = defaultState().copyWith(isLoading: true, error: 'err');
        final updated = base.copyWith(isLoading: false, clearError: true);
        expect(updated.isLoading, isFalse);
        expect(updated.error, isNull);
      });

      test('clearError sets error to null', () {
        final withError = defaultState().copyWith(error: 'network failure');
        expect(withError.error, 'network failure');

        final cleared = withError.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });

      test('clearError with explicit error still clears', () {
        final state = defaultState().copyWith(
          error: 'original',
          clearError: true,
        );
        expect(state.error, isNull);
      });

      test('does not clear error when clearError is false', () {
        final state = defaultState().copyWith(error: 'kept');
        final updated = state.copyWith(isLoading: true);
        expect(updated.error, 'kept');
      });
    });

    // -- isDataFresh --

    group('isDataFresh', () {
      test('returns false when no lastRefreshTime', () {
        final state = defaultState();
        expect(state.isDataFresh(), isFalse);
      });

      test('returns true when within cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 3)),
        );
        expect(state.isDataFresh(), isTrue);
      });

      test('returns false when past cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 10)),
        );
        expect(state.isDataFresh(), isFalse);
      });

      test('respects custom cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 3)),
        );
        expect(
          state.isDataFresh(cacheDuration: const Duration(minutes: 2)),
          isFalse,
        );
        expect(
          state.isDataFresh(cacheDuration: const Duration(minutes: 5)),
          isTrue,
        );
      });
    });

    // -- activeItems --

    group('activeItems', () {
      final shows = [
        _makeItem(id: 's1', title: 'Show 1'),
        _makeItem(id: 's2', title: 'Show 2'),
      ];
      final episodes = [
        _makeItem(id: 'e1', title: 'Episode 1'),
        _makeItem(id: 'e2', title: 'Episode 2'),
        _makeItem(id: 'e3', title: 'Episode 3'),
      ];

      test('returns topShows when podcasts tab', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          topShows: shows,
          topEpisodes: episodes,
        );
        expect(state.activeItems, shows);
      });

      test('returns topEpisodes when episodes tab', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.episodes,
          topShows: shows,
          topEpisodes: episodes,
        );
        expect(state.activeItems, episodes);
      });
    });

    // -- currentPagination --

    group('currentPagination', () {
      test('delegates to showsPagination for podcasts tab', () {
        const showsPag = PodcastDiscoverPaginationState(loadedCount: 42);
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          showsPagination: showsPag,
        );
        expect(state.currentPagination, showsPag);
      });

      test('delegates to episodesPagination for episodes tab', () {
        const episodesPag = PodcastDiscoverPaginationState(loadedCount: 99);
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.episodes,
          episodesPagination: episodesPag,
        );
        expect(state.currentPagination, episodesPag);
      });
    });

    // -- isCurrentTabLoadingMore --

    group('isCurrentTabLoadingMore', () {
      test('returns true when current tab is loading more', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.episodes,
          episodesPagination: const PodcastDiscoverPaginationState(
            isLoadingMore: true,
          ),
        );
        expect(state.isCurrentTabLoadingMore, isTrue);
      });

      test('returns false when current tab is not loading more', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.episodes,
          episodesPagination: const PodcastDiscoverPaginationState(
            isLoadingMore: false,
          ),
        );
        expect(state.isCurrentTabLoadingMore, isFalse);
      });
    });

    // -- currentTabHasMore --

    group('currentTabHasMore', () {
      test('returns value from current tab pagination', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          showsPagination: const PodcastDiscoverPaginationState(hasMore: true),
        );
        expect(state.currentTabHasMore, isTrue);
      });

      test('returns false when hasMore is false', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          showsPagination: const PodcastDiscoverPaginationState(hasMore: false),
        );
        expect(state.currentTabHasMore, isFalse);
      });
    });

    // -- currentTabLoadedCount --

    group('currentTabLoadedCount', () {
      test('returns loadedCount from current tab pagination', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.episodes,
          episodesPagination: const PodcastDiscoverPaginationState(
            loadedCount: 75,
          ),
        );
        expect(state.currentTabLoadedCount, 75);
      });
    });

    // -- categories --

    group('categories', () {
      test('returns empty list when no active items', () {
        final state = defaultState();
        expect(state.categories, isEmpty);
      });

      test('extracts genres and sorts by count descending', () {
        final items = [
          _makeItem(id: '1', genres: ['Technology', 'News']),
          _makeItem(id: '2', genres: ['News']),
          _makeItem(id: '3', genres: ['Technology']),
          _makeItem(id: '4', genres: ['Technology', 'Comedy']),
        ];
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          topShows: items,
        );

        final cats = state.categories;
        // Technology: 3, News: 2, Comedy: 1
        expect(cats, ['Technology', 'News', 'Comedy']);
      });

      test('breaks ties alphabetically (case-insensitive)', () {
        final items = [
          _makeItem(id: '1', genres: ['banana']),
          _makeItem(id: '2', genres: ['Apple']),
        ];
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          topShows: items,
        );

        final cats = state.categories;
        // Both have count 1. Tie broken alphabetically case-insensitive.
        // "Apple" (a) < "banana" (b).
        expect(cats, ['Apple', 'banana']);
      });

      test('trims genre names and skips empty ones', () {
        final items = [
          _makeItem(id: '1', genres: ['  Tech  ', '  ', '']),
          _makeItem(id: '2', genres: ['Tech']),
        ];
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          topShows: items,
        );

        final cats = state.categories;
        expect(cats, ['Tech']);
      });
    });

    // -- filteredActiveItems --

    group('filteredActiveItems', () {
      final items = [
        _makeItem(id: '1', genres: ['Technology']),
        _makeItem(id: '2', genres: ['News']),
        _makeItem(id: '3', genres: ['Technology', 'Comedy']),
      ];

      test('returns all items when selectedCategory is allCategoryValue', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: PodcastDiscoverState.allCategoryValue,
          topShows: items,
        );
        expect(state.filteredActiveItems, hasLength(3));
      });

      test('filters by selectedCategory', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: 'Technology',
          topShows: items,
        );
        final filtered = state.filteredActiveItems;
        expect(filtered, hasLength(2));
        expect(filtered.every((item) => item.hasGenre('Technology')), isTrue);
      });

      test('returns empty when no items match category', () {
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: 'Sports',
          topShows: items,
        );
        expect(state.filteredActiveItems, isEmpty);
      });
    });

    // -- visibleItems --

    group('visibleItems', () {
      test('delegates to filteredActiveItems', () {
        final items = [
          _makeItem(id: '1', genres: ['Tech']),
          _makeItem(id: '2', genres: ['News']),
        ];
        final state = defaultState().copyWith(
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: 'Tech',
          topShows: items,
        );
        expect(state.visibleItems, state.filteredActiveItems);
      });
    });

    // -- Equality --

    group('equality', () {
      test('equal when all fields match', () {
        final now = DateTime(2026, 1, 15, 10, 30);
        final a = PodcastDiscoverState(
          country: PodcastCountry.usa,
          isLoading: true,
          isRefreshing: false,
          error: 'err',
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: 'Tech',
          topShows: [_makeItem(id: '1')],
          topEpisodes: [_makeItem(id: '2')],
          showsPagination: const PodcastDiscoverPaginationState(
            loadedCount: 5,
          ),
          episodesPagination: const PodcastDiscoverPaginationState(
            loadedCount: 10,
          ),
          lastRefreshTime: now,
        );
        final b = PodcastDiscoverState(
          country: PodcastCountry.usa,
          isLoading: true,
          isRefreshing: false,
          error: 'err',
          selectedTab: PodcastDiscoverTab.podcasts,
          selectedCategory: 'Tech',
          topShows: [_makeItem(id: '1')],
          topEpisodes: [_makeItem(id: '2')],
          showsPagination: const PodcastDiscoverPaginationState(
            loadedCount: 5,
          ),
          episodesPagination: const PodcastDiscoverPaginationState(
            loadedCount: 10,
          ),
          lastRefreshTime: now,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when any field differs', () {
        final a = defaultState();
        final b = a.copyWith(isLoading: true);
        expect(a, isNot(equals(b)));
      });
    });

    // -- allCategoryValue constant --

    group('allCategoryValue', () {
      test('is a sentinel value distinct from real categories', () {
        expect(PodcastDiscoverState.allCategoryValue, '__all__');
      });
    });
  });
}

/// Helper to create a [PodcastDiscoverItem] for tests.
PodcastDiscoverItem _makeItem({
  String id = '0',
  String title = 'Test Item',
  List<String> genres = const [],
}) {
  return PodcastDiscoverItem(
    itemId: id,
    itunesId: int.tryParse(id),
    title: title,
    artist: 'Artist',
    artworkUrl: 'https://example.com/artwork.png',
    url: 'https://example.com/item/$id',
    genres: genres,
    kind: PodcastDiscoverKind.podcasts,
  );
}
