import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';

void main() {
  testWidgets(
    'discover, library, and profile use the same compact header height',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<double> pumpAndMeasure(
        Widget home, {
        required List<dynamic> overrides,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: overrides.cast(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(CompactHeaderPanel)).height;
      }

      final discoverHeight = await pumpAndMeasure(
        const PodcastListPage(),
        overrides: [
          countrySelectorProvider.overrideWith(
            () => _FixedCountrySelectorNotifier(
              const CountrySelectorState(selectedCountry: PodcastCountry.china),
            ),
          ),
          podcastDiscoverProvider.overrideWith(
            () => _FixedPodcastDiscoverNotifier(
              const PodcastDiscoverState(country: PodcastCountry.china),
            ),
          ),
          search.podcastSearchProvider.overrideWith(
            () =>
                _FixedPodcastSearchNotifier(const search.PodcastSearchState()),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => _FixedPodcastSubscriptionNotifier(
              const PodcastSubscriptionState(
                hasMore: false,
              ),
            ),
          ),
        ],
      );

      final libraryHeight = await pumpAndMeasure(
        const PodcastFeedPage(),
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _FixedPodcastFeedNotifier(
              const PodcastFeedState(
                hasMore: false,
              ),
            ),
          ),
        ],
      );

      final profileHeight = await pumpAndMeasure(
        const Scaffold(body: ProfilePage()),
        overrides: [
          authProvider.overrideWith(_FixedAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_profileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => _FixedPodcastSubscriptionNotifier(
              const PodcastSubscriptionState(
                hasMore: false,
              ),
            ),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(_emptyDailyReportDates),
          ),
        ],
      );

      expect(discoverHeight, libraryHeight);
      expect(profileHeight, libraryHeight);
    },
  );
}

const _profileStats = ProfileStatsModel(
  totalSubscriptions: 4,
  totalEpisodes: 12,
  summariesGenerated: 8,
  pendingSummaries: 1,
  playedEpisodes: 5,
  latestDailyReportDate: '2026-03-05',
);

const _emptyDailyReportDates = PodcastDailyReportDatesResponse(
  dates: [],
  total: 0,
  page: 1,
  size: 100,
  pages: 0,
);

class _FixedCountrySelectorNotifier extends CountrySelectorNotifier {
  _FixedCountrySelectorNotifier(this._state);

  final CountrySelectorState _state;

  @override
  CountrySelectorState build() => _state;

  @override
  Future<void> selectCountry(PodcastCountry country) async {}
}

class _FixedPodcastDiscoverNotifier extends PodcastDiscoverNotifier {
  _FixedPodcastDiscoverNotifier(this._state);

  final PodcastDiscoverState _state;

  @override
  PodcastDiscoverState build() => _state;

  @override
  Future<void> loadInitialData() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> onCountryChanged(PodcastCountry country) async {}

  @override
  void setTab(PodcastDiscoverTab tab) {}

  @override
  void selectCategory(String category) {}

  @override
  Future<void> loadMoreCurrentTab() async {}
}

class _FixedPodcastSearchNotifier extends search.PodcastSearchNotifier {
  _FixedPodcastSearchNotifier(this._state);

  final search.PodcastSearchState _state;

  @override
  search.PodcastSearchState build() => _state;

  @override
  void searchPodcasts(String query) {}

  @override
  void searchEpisodes(String query) {}

  @override
  void setSearchMode(search.PodcastSearchMode mode) {
    state = state.copyWith(searchMode: mode);
  }

  @override
  void clearSearch() {}

  @override
  Future<void> retrySearch() async {}
}

class _FixedPodcastFeedNotifier extends PodcastFeedNotifier {
  _FixedPodcastFeedNotifier(this._state);

  final PodcastFeedState _state;

  @override
  PodcastFeedState build() => _state;

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {}

  @override
  Future<void> loadMoreFeed() async {}

  @override
  Future<void> refreshFeed({bool fastReturn = false}) async {}
}

class _FixedPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  _FixedPodcastSubscriptionNotifier(this._state);

  final PodcastSubscriptionState _state;

  @override
  PodcastSubscriptionState build() => _state;

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

class _FixedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState();
  }
}

class _FixedProfileStatsNotifier extends ProfileStatsNotifier {
  _FixedProfileStatsNotifier(this._stats);

  final ProfileStatsModel _stats;

  @override
  Future<ProfileStatsModel?> build() async => _stats;

  @override
  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async => _stats;
}

class _FixedDailyReportDatesNotifier extends DailyReportDatesNotifier {
  _FixedDailyReportDatesNotifier(this._value);

  final PodcastDailyReportDatesResponse _value;

  @override
  Future<PodcastDailyReportDatesResponse?> build() async => _value;

  @override
  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = 100,
    bool forceRefresh = false,
  }) async {
    return _value;
  }

  @override
  Future<PodcastDailyReportDatesResponse?> ensureMonthCoverage(
    DateTime focusedMonth,
  ) async {
    return _value;
  }
}
