import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/shared/models/paginated_state.dart';

const Object _stateNoChange = Object();

class PodcastFeedState extends PaginatedState<PodcastEpisodeModel> {
  final String? nextCursor;

  const PodcastFeedState({
    List<PodcastEpisodeModel> episodes = const [],
    bool hasMore = true,
    int? nextPage,
    this.nextCursor,
    int total = 0,
    bool isLoading = false,
    bool isLoadingMore = false,
    String? error,
    DateTime? lastRefreshTime,
  }) : super(
          items: episodes,
          hasMore: hasMore,
          nextPage: nextPage,
          total: total,
          isLoading: isLoading,
          isLoadingMore: isLoadingMore,
          error: error,
          lastRefreshTime: lastRefreshTime,
        );

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
      episodes: episodes ?? items.cast<PodcastEpisodeModel>(),
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
  final int? cachedSubscriptionId;
  final String? cachedStatus;
  final bool? cachedHasSummary;

  const PodcastEpisodesState({
    List<PodcastEpisodeModel> episodes = const [],
    bool hasMore = true,
    int? nextPage,
    int currentPage = 1,
    int total = 0,
    bool isLoading = false,
    bool isLoadingMore = false,
    String? error,
    this.cachedSubscriptionId,
    this.cachedStatus,
    this.cachedHasSummary,
    DateTime? lastRefreshTime,
  }) : super(
          items: episodes,
          hasMore: hasMore,
          nextPage: nextPage,
          currentPage: currentPage,
          total: total,
          isLoading: isLoading,
          isLoadingMore: isLoadingMore,
          error: error,
          lastRefreshTime: lastRefreshTime,
        );

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
      episodes: episodes ?? items.cast<PodcastEpisodeModel>(),
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
  /// Set of Feed URLs currently being subscribed
  final Set<String> subscribingFeedUrls;

  const PodcastSubscriptionState({
    List<PodcastSubscriptionModel> subscriptions = const [],
    bool hasMore = true,
    int? nextPage,
    int currentPage = 1,
    int total = 0,
    bool isLoading = false,
    bool isLoadingMore = false,
    String? error,
    this.subscribingFeedUrls = const {},
    DateTime? lastRefreshTime,
  }) : super(
          items: subscriptions,
          hasMore: hasMore,
          nextPage: nextPage,
          currentPage: currentPage,
          total: total,
          isLoading: isLoading,
          isLoadingMore: isLoadingMore,
          error: error,
          lastRefreshTime: lastRefreshTime,
        );

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
      subscriptions:
          subscriptions ?? items.cast<PodcastSubscriptionModel>(),
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
