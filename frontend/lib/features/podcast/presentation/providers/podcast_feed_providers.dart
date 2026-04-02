import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/exceptions/network_exceptions.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/podcast_state_models.dart';
import '../../data/repositories/podcast_repository.dart';
import 'podcast_core_providers.dart';

final podcastFeedProvider =
    NotifierProvider<PodcastFeedNotifier, PodcastFeedState>(
      PodcastFeedNotifier.new,
    );

class PodcastFeedNotifier extends Notifier<PodcastFeedState> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  Future<void>? _inFlightInitialLoad;

  @override
  PodcastFeedState build() {
    return const PodcastFeedState();
  }

  String _extractReadableErrorMessage(Object error) {
    if (error is AppException) {
      final message = error.message.trim();
      return message.isNotEmpty ? message : 'Network error occurred';
    }

    final message = error.toString().trim();
    return message.isNotEmpty ? message : 'Network error occurred';
  }

  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    final currentState = state;
    final hasData = currentState.episodes.isNotEmpty;
    final shouldShowInitialLoader = !background && !hasData;

    if (!forceRefresh && hasData && currentState.isDataFresh()) {
      return;
    }

    final existingLoad = _inFlightInitialLoad;
    if (existingLoad != null) {
      return existingLoad;
    }

    if (shouldShowInitialLoader) {
      state = currentState.copyWith(isLoading: true, clearError: true);
    }

    final loadFuture = () async {
      try {
        final response = await _repository.getPodcastFeed(
          page: 1,
          pageSize: 20,
        );

        state = state.copyWith(
          episodes: response.items,
          hasMore: response.hasMore,
          nextPage: response.nextPage,
          nextCursor: response.nextCursor,
          total: response.total,
          isLoading: false,
          clearError: true,
          lastRefreshTime: DateTime.now(),
        );
      } catch (error) {
        logger.AppLogger.debug('[Error] Failed to load feed: $error');

        // Check if this is an authentication error
        if (error is AuthenticationException) {
          logger.AppLogger.debug(
            'Authentication failed while loading feed, checking auth status.',
          );
          // Trigger auth status check to update state and redirect to login
          ref.read(authProvider.notifier).checkAuthStatus();
        }

        state = state.copyWith(
          isLoading: false,
          error: _extractReadableErrorMessage(error),
        );
      }
    }();

    _inFlightInitialLoad = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_inFlightInitialLoad, loadFuture)) {
        _inFlightInitialLoad = null;
      }
    }
  }

  Future<void> loadMoreFeed() async {
    final currentState = state;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getPodcastFeed(
        page: currentState.nextPage ?? 1,
        pageSize: 20,
        cursor: currentState.nextCursor,
      );

      state = state.copyWith(
        episodes: [...state.episodes, ...response.items],
        hasMore: response.hasMore,
        nextPage: response.nextPage,
        nextCursor: response.nextCursor,
        total: response.total,
        isLoadingMore: false,
        lastRefreshTime: DateTime.now(),
      );
    } catch (error) {
      logger.AppLogger.debug('[Error] Failed to load more feed: $error');

      // Check if this is an authentication error
      if (error is AuthenticationException) {
        logger.AppLogger.debug(
          'Authentication failed while loading more feed, checking auth status.',
        );
        // Trigger auth status check to update state and redirect to login
        ref.read(authProvider.notifier).checkAuthStatus();
      }

      state = state.copyWith(
        isLoadingMore: false,
        error: _extractReadableErrorMessage(error),
      );
    }
  }

  Future<void> refreshFeed({bool fastReturn = false}) async {
    final hasExistingFeed = state.episodes.isNotEmpty;
    if (fastReturn && hasExistingFeed) {
      unawaited(loadInitialFeed(forceRefresh: true, background: true));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return;
    }

    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated) {
      await loadInitialFeed(
        forceRefresh: true,
        background: state.episodes.isNotEmpty,
      );
      return;
    }

    await loadInitialFeed(
      forceRefresh: true,
      background: state.episodes.isNotEmpty,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
