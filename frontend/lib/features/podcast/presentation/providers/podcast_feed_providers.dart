import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';

final podcastFeedProvider =
    NotifierProvider<PodcastFeedNotifier, PodcastFeedState>(
      PodcastFeedNotifier.new,
    );

class PodcastFeedNotifier extends Notifier<PodcastFeedState> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  Future<void>? _inFlightRequest;

  @override
  PodcastFeedState build() {
    return const PodcastFeedState();
  }

  /// Runs [action] with deduplication.
  ///
  /// If a previous call is still in-flight, this returns immediately
  /// without running [action] again. Once [action] completes, the
  /// in-flight reference is cleared.
  Future<void> deduplicate(Future<void> Function() action) async {
    final existing = _inFlightRequest;
    if (existing != null) return existing;

    final future = action();
    _inFlightRequest = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightRequest, future)) {
        _inFlightRequest = null;
      }
    }
  }

  /// Resets the in-flight dedup state.
  void resetDedup() {
    _inFlightRequest = null;
  }

  String _extractReadableErrorMessage(Object error) {
    if (error is AppException) {
      return error.userMessage;
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

    await deduplicate(() async {
      if (shouldShowInitialLoader) {
        state = currentState.copyWith(isLoading: true, clearError: true);
      }

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

        if (error is AuthException) {
          logger.AppLogger.debug(
            'Authentication failed while loading feed, checking auth status.',
          );
          ref.read(authProvider.notifier).checkAuthStatus();
        }

        state = state.copyWith(
          isLoading: false,
          error: _extractReadableErrorMessage(error),
        );
      }
    });
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

      if (error is AuthException) {
        logger.AppLogger.debug(
          'Authentication failed while loading more feed, checking auth status.',
        );
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
