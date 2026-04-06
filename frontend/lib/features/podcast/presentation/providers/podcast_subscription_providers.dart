import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';

final podcastSubscriptionProvider =
    NotifierProvider<PodcastSubscriptionNotifier, PodcastSubscriptionState>(
      PodcastSubscriptionNotifier.new,
    );

class PodcastSubscriptionNotifier extends Notifier<PodcastSubscriptionState> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  bool _isLoadingSubscriptions = false;
  bool _isLoadingMoreSubscriptions = false;

  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState();
  }

  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {
    // Guard against concurrent invocation
    if (_isLoadingSubscriptions) return;
    _isLoadingSubscriptions = true;

    try {
      // Check if data is fresh and skip refresh if not forced
      if (!forceRefresh && page == 1 && state.isDataFresh()) {
        logger.AppLogger.debug(
          '[Playback] Using cached subscription data (fresh within 5 min)',
        );
        return;
      }

      state = state.copyWith(isLoading: true, clearError: true);

      final response = await _repository.listSubscriptions(
        page: page,
        size: size,
        categoryId: categoryId,
        status: status,
      );

      state = state.copyWith(
        subscriptions: response.subscriptions,
        hasMore: page < response.pages,
        nextPage: page < response.pages ? page + 1 : null,
        currentPage: page,
        total: response.total,
        isLoading: false,
        clearError: true,
        lastRefreshTime: DateTime.now(), // Record refresh time
      );
      logger.AppLogger.debug(
        '[OK] Subscription data loaded at ${DateTime.now()} (total=${response.total}, count=${response.subscriptions.length})',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      rethrow;
    } finally {
      _isLoadingSubscriptions = false;
    }
  }

  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {
    if (state.isLoadingMore || !state.hasMore) return;

    // Guard against concurrent invocation
    if (_isLoadingMoreSubscriptions) return;
    _isLoadingMoreSubscriptions = true;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.listSubscriptions(
        page: state.nextPage ?? 1,
        size: 10,
        categoryId: categoryId,
        status: status,
      );

      state = state.copyWith(
        subscriptions: [...state.subscriptions, ...response.subscriptions],
        hasMore: (state.nextPage ?? 1) < response.pages,
        nextPage: (state.nextPage ?? 1) < response.pages
            ? (state.nextPage ?? 1) + 1
            : null,
        currentPage: state.nextPage ?? 1,
        total: response.total,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error.toString());
    } finally {
      _isLoadingMoreSubscriptions = false;
    }
  }

  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {
    state = const PodcastSubscriptionState();
    await loadSubscriptions(
      categoryId: categoryId,
      status: status,
    );
  }

  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) async {
    // Mark as subscribing
    state = state.copyWith(
      subscribingFeedUrls: {...state.subscribingFeedUrls, feedUrl},
    );

    try {
      final subscription = await _repository.addSubscription(
        feedUrl: feedUrl,
        categoryIds: categoryIds,
      );

      // Optimistic update: add new subscription to local list
      state = state.copyWith(
        subscriptions: [subscription, ...state.subscriptions],
        total: state.total + 1,
        subscribingFeedUrls: state.subscribingFeedUrls
            .where((url) => url != feedUrl)
            .toSet(),
      );

      return subscription;
    } catch (error) {
      // Remove from subscribing set
      state = state.copyWith(
        subscribingFeedUrls: state.subscribingFeedUrls
            .where((url) => url != feedUrl)
            .toSet(),
      );
      rethrow;
    }
  }

  Future<void> deleteSubscription(int subscriptionId) async {
    // Optimistic update: remove from local list immediately
    final updatedSubscriptions = state.subscriptions
        .where((s) => s.id != subscriptionId)
        .toList();

    try {
      await _repository.deleteSubscription(subscriptionId);

      state = state.copyWith(
        subscriptions: updatedSubscriptions,
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } catch (error) {
      // Revert: reload from server on failure
      await refreshSubscriptions();
      rethrow;
    }
  }

  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions({
    required List<int> subscriptionIds,
  }) async {
    // Optimistic update: remove from local list immediately
    final idSet = subscriptionIds.toSet();
    final updatedSubscriptions = state.subscriptions
        .where((s) => !idSet.contains(s.id))
        .toList();

    try {
      logger.AppLogger.debug(
        '[Playback] Bulk delete request: subscriptionIds=$subscriptionIds',
      );

      final response = await _repository.bulkDeleteSubscriptions(
        subscriptionIds: subscriptionIds,
      );

      logger.AppLogger.debug(
        '[OK] Bulk delete success: ${response.successCount} deleted, ${response.failedCount} failed',
      );

      state = state.copyWith(
        subscriptions: updatedSubscriptions,
        total: state.total > response.successCount
            ? state.total - response.successCount
            : 0,
      );

      return response;
    } catch (error) {
      logger.AppLogger.debug('[Error] Bulk delete failed: $error');
      // Revert: reload from server on failure
      await refreshSubscriptions();
      rethrow;
    }
  }

  Future<void> refreshSubscription(int subscriptionId) async {
    try {
      await _repository.refreshSubscription(subscriptionId);

      // Refresh the list
      await refreshSubscriptions();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> reparseSubscription(int subscriptionId, bool forceAll) async {
    try {
      await _repository.reparseSubscription(subscriptionId, forceAll);

      // Refresh the list
      await refreshSubscriptions();
    } catch (error) {
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Derived selectors (moved from podcast_subscription_selectors.dart)
// ---------------------------------------------------------------------------

final subscribedNormalizedFeedUrlsProvider = Provider<Set<String>>((ref) {
  final subscriptions = ref.watch(
    podcastSubscriptionProvider.select((state) => state.subscriptions),
  );
  return UnmodifiableSetView(
    subscriptions
        .map((sub) => PodcastUrlUtils.normalizeFeedUrl(sub.sourceUrl))
        .toSet(),
  );
});

final subscribingNormalizedFeedUrlsProvider = Provider<Set<String>>((ref) {
  final subscribingFeedUrls = ref.watch(
    podcastSubscriptionProvider.select((state) => state.subscribingFeedUrls),
  );
  return UnmodifiableSetView(
    subscribingFeedUrls.map(PodcastUrlUtils.normalizeFeedUrl).toSet(),
  );
});
