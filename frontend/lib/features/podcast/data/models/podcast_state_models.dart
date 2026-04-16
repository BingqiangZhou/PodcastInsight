import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/shared/models/paginated_state.dart';

const Object _stateNoChange = Object();

class PodcastFeedState extends PaginatedState<PodcastEpisodeModel> {

  const PodcastFeedState({
    List<PodcastEpisodeModel> episodes = const [],
    super.hasMore,
    super.nextPage,
    this.nextCursor,
    super.total,
    super.isLoading,
    super.isLoadingMore,
    super.error,
    super.lastRefreshTime,
  }) : super(
          items: episodes,
        );
  final String? nextCursor;

  List<PodcastEpisodeModel> get episodes => items;

  PodcastFeedState copyWith({
    List<PodcastEpisodeModel>? episodes,
    bool? hasMore,
    Object? nextPage = _stateNoChange,
    Object? nextCursor = _stateNoChange,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    DateTime? lastRefreshTime,
  }) {
    return PodcastFeedState(
      episodes: episodes ?? items,
      hasMore: hasMore ?? this.hasMore,
      nextPage: identical(nextPage, _stateNoChange)
          ? this.nextPage
          : nextPage as int?,
      nextCursor: identical(nextCursor, _stateNoChange)
          ? this.nextCursor
          : nextCursor as String?,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  @override
  bool isDataFresh({
    Duration cacheDuration = CacheConstants.feedCacheDuration,
  }) {
    return super.isDataFresh(cacheDuration: cacheDuration);
  }

  @override
  List<Object?> get props => [
        ...super.props,
        nextCursor,
      ];
}

class PodcastEpisodesState extends PaginatedState<PodcastEpisodeModel> {

  const PodcastEpisodesState({
    List<PodcastEpisodeModel> episodes = const [],
    super.hasMore,
    super.nextPage,
    super.currentPage,
    super.total,
    super.isLoading,
    super.isLoadingMore,
    super.error,
    this.cachedSubscriptionId,
    this.cachedStatus,
    this.cachedHasSummary,
    super.lastRefreshTime,
  }) : super(
          items: episodes,
        );
  final int? cachedSubscriptionId;
  final String? cachedStatus;
  final bool? cachedHasSummary;

  List<PodcastEpisodeModel> get episodes => items;

  PodcastEpisodesState copyWith({
    List<PodcastEpisodeModel>? episodes,
    bool? hasMore,
    int? nextPage,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? cachedSubscriptionId,
    String? cachedStatus,
    bool? cachedHasSummary,
    DateTime? lastRefreshTime,
  }) {
    return PodcastEpisodesState(
      episodes: episodes ?? items,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      cachedSubscriptionId:
          cachedSubscriptionId ?? this.cachedSubscriptionId,
      cachedStatus: cachedStatus ?? this.cachedStatus,
      cachedHasSummary: cachedHasSummary ?? this.cachedHasSummary,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        cachedSubscriptionId,
        cachedStatus,
        cachedHasSummary,
      ];
}

class PodcastSubscriptionState
    extends PaginatedState<PodcastSubscriptionModel> {

  const PodcastSubscriptionState({
    List<PodcastSubscriptionModel> subscriptions = const [],
    super.hasMore,
    super.nextPage,
    super.currentPage,
    super.total,
    super.isLoading,
    super.isLoadingMore,
    super.error,
    this.subscribingFeedUrls = const {},
    super.lastRefreshTime,
  }) : super(
          items: subscriptions,
        );
  /// Set of Feed URLs currently being subscribed
  final Set<String> subscribingFeedUrls;

  List<PodcastSubscriptionModel> get subscriptions => items;

  PodcastSubscriptionState copyWith({
    List<PodcastSubscriptionModel>? subscriptions,
    bool? hasMore,
    int? nextPage,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    Set<String>? subscribingFeedUrls,
    DateTime? lastRefreshTime,
  }) {
    return PodcastSubscriptionState(
      subscriptions: subscriptions ?? items,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      subscribingFeedUrls: subscribingFeedUrls ?? this.subscribingFeedUrls,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        subscribingFeedUrls,
      ];
}
