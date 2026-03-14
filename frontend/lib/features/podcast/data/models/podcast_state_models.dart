import 'package:equatable/equatable.dart';

import '../../../../core/constants/cache_constants.dart';
import 'podcast_episode_model.dart';
import 'podcast_subscription_model.dart';

const Object _stateNoChange = Object();

class PodcastFeedState extends Equatable {
  final List<PodcastEpisodeModel> episodes;
  final bool hasMore;
  final int? nextPage;
  final String? nextCursor;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  /// Last refresh timestamp for cache validation
  final DateTime? lastRefreshTime;

  const PodcastFeedState({
    this.episodes = const [],
    this.hasMore = true,
    this.nextPage,
    this.nextCursor,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastRefreshTime,
  });

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
      episodes: episodes ?? this.episodes,
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

  /// Check if data is fresh (within cache duration)
  bool isDataFresh({
    Duration cacheDuration = CacheConstants.feedCacheDuration,
  }) {
    if (lastRefreshTime == null) return false;
    return DateTime.now().difference(lastRefreshTime!) < cacheDuration;
  }

  @override
  List<Object?> get props => [
    episodes,
    hasMore,
    nextPage,
    nextCursor,
    total,
    isLoading,
    isLoadingMore,
    error,
    lastRefreshTime,
  ];
}

class PodcastEpisodesState extends Equatable {
  final List<PodcastEpisodeModel> episodes;
  final bool hasMore;
  final int? nextPage;
  final int currentPage;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int? cachedSubscriptionId;
  final String? cachedStatus;
  final bool? cachedHasSummary;

  /// Last refresh timestamp for cache validation
  final DateTime? lastRefreshTime;

  const PodcastEpisodesState({
    this.episodes = const [],
    this.hasMore = true,
    this.nextPage,
    this.currentPage = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.cachedSubscriptionId,
    this.cachedStatus,
    this.cachedHasSummary,
    this.lastRefreshTime,
  });

  PodcastEpisodesState copyWith({
    List<PodcastEpisodeModel>? episodes,
    bool? hasMore,
    int? nextPage,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? cachedSubscriptionId,
    String? cachedStatus,
    bool? cachedHasSummary,
    DateTime? lastRefreshTime,
  }) {
    return PodcastEpisodesState(
      episodes: episodes ?? this.episodes,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      cachedSubscriptionId: cachedSubscriptionId ?? this.cachedSubscriptionId,
      cachedStatus: cachedStatus ?? this.cachedStatus,
      cachedHasSummary: cachedHasSummary ?? this.cachedHasSummary,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  /// Check if data is fresh (within cache duration)
  bool isDataFresh({
    Duration cacheDuration = CacheConstants.defaultListCacheDuration,
  }) {
    if (lastRefreshTime == null) return false;
    return DateTime.now().difference(lastRefreshTime!) < cacheDuration;
  }

  @override
  List<Object?> get props => [
    episodes,
    hasMore,
    nextPage,
    currentPage,
    total,
    isLoading,
    isLoadingMore,
    error,
    cachedSubscriptionId,
    cachedStatus,
    cachedHasSummary,
    lastRefreshTime,
  ];
}

class PodcastSubscriptionState extends Equatable {
  final List<PodcastSubscriptionModel> subscriptions;
  final bool hasMore;
  final int? nextPage;
  final int currentPage;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  /// 正在订阅的 Feed URLs 集合 / Set of Feed URLs currently being subscribed
  final Set<String> subscribingFeedUrls;

  /// Last refresh timestamp for cache validation
  final DateTime? lastRefreshTime;

  const PodcastSubscriptionState({
    this.subscriptions = const [],
    this.hasMore = true,
    this.nextPage,
    this.currentPage = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.subscribingFeedUrls = const {},
    this.lastRefreshTime,
  });

  PodcastSubscriptionState copyWith({
    List<PodcastSubscriptionModel>? subscriptions,
    bool? hasMore,
    int? nextPage,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Set<String>? subscribingFeedUrls,
    DateTime? lastRefreshTime,
  }) {
    return PodcastSubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      subscribingFeedUrls: subscribingFeedUrls ?? this.subscribingFeedUrls,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  /// Check if data is fresh (within cache duration)
  bool isDataFresh({
    Duration cacheDuration = CacheConstants.defaultListCacheDuration,
  }) {
    if (lastRefreshTime == null) return false;
    return DateTime.now().difference(lastRefreshTime!) < cacheDuration;
  }

  @override
  List<Object?> get props => [
    subscriptions,
    hasMore,
    nextPage,
    currentPage,
    total,
    isLoading,
    isLoadingMore,
    error,
    subscribingFeedUrls,
    lastRefreshTime,
  ];
}
