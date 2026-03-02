part of 'podcast_playback_providers.dart';

final podcastQueueControllerProvider =
    AsyncNotifierProvider<PodcastQueueController, PodcastQueueModel>(
      PodcastQueueController.new,
    );

class PodcastQueueController extends AsyncNotifier<PodcastQueueModel> {
  late PodcastRepository _repository;
  Future<PodcastQueueModel>? _inFlightQueueLoad;
  final Map<int, Future<PodcastQueueModel>> _inFlightAddToQueueByEpisodeId =
      <int, Future<PodcastQueueModel>>{};
  DateTime? _lastQueueRefreshAt;
  int _latestAppliedQueueRevision = -1;
  int _queueSyncInFlight = 0;
  static const Duration _queueRefreshThrottle = Duration(seconds: 20);

  @override
  FutureOr<PodcastQueueModel> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    try {
      return await _loadQueueInternal(
        forceRefresh: false,
        trackSyncing: false,
        setErrorStateOnFailure: false,
      );
    } catch (_) {
      return PodcastQueueModel.empty();
    }
  }

  bool _hasFreshQueueState() {
    if (_lastQueueRefreshAt == null) {
      return false;
    }
    return DateTime.now().difference(_lastQueueRefreshAt!) <
        _queueRefreshThrottle;
  }

  void _beginQueueSync() {
    _queueSyncInFlight += 1;
    if (_queueSyncInFlight == 1) {
      ref.read(audioPlayerProvider.notifier).setQueueSyncing(true);
    }
  }

  void _endQueueSync() {
    if (_queueSyncInFlight <= 0) {
      return;
    }
    _queueSyncInFlight -= 1;
    if (_queueSyncInFlight == 0) {
      ref.read(audioPlayerProvider.notifier).setQueueSyncing(false);
    }
  }

  PodcastQueueModel _applyQueue(PodcastQueueModel queue) {
    if (queue.revision < _latestAppliedQueueRevision) {
      logger.AppLogger.debug(
        '[Queue] Ignore stale queue snapshot: incoming_revision=${queue.revision}, latest_revision=$_latestAppliedQueueRevision',
      );
      return state.value ?? queue;
    }

    state = AsyncValue.data(queue);
    _lastQueueRefreshAt = DateTime.now();
    if (queue.revision > _latestAppliedQueueRevision) {
      _latestAppliedQueueRevision = queue.revision;
    }
    ref.read(audioPlayerProvider.notifier).syncQueueState(queue);
    return queue;
  }

  Future<PodcastQueueModel> _loadQueueInternal({
    required bool forceRefresh,
    bool trackSyncing = true,
    bool setErrorStateOnFailure = true,
  }) {
    final inFlight = _inFlightQueueLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final cachedQueue = state.value;
    if (!forceRefresh && cachedQueue != null && _hasFreshQueueState()) {
      return Future.value(cachedQueue);
    }

    if (trackSyncing) {
      _beginQueueSync();
    }

    final loadFuture = () async {
      try {
        final queue = await _repository.getQueue();
        return _applyQueue(queue);
      } catch (error, stackTrace) {
        if (setErrorStateOnFailure || state.value == null) {
          state = AsyncValue.error(error, stackTrace);
        }
        rethrow;
      } finally {
        _inFlightQueueLoad = null;
        if (trackSyncing) {
          _endQueueSync();
        }
      }
    }();

    _inFlightQueueLoad = loadFuture;
    return loadFuture;
  }

  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    return _loadQueueInternal(
      forceRefresh: forceRefresh,
      trackSyncing: true,
      setErrorStateOnFailure: true,
    );
  }

  Future<void> refreshQueueInBackground() async {
    try {
      await _loadQueueInternal(
        forceRefresh: false,
        trackSyncing: false,
        setErrorStateOnFailure: false,
      );
    } catch (_) {
      // Keep existing queue UI state when background refresh fails.
    }
  }

  Future<PodcastQueueModel> addToQueue(int episodeId) async {
    final inFlight = _inFlightAddToQueueByEpisodeId[episodeId];
    if (inFlight != null) {
      return inFlight;
    }

    _beginQueueSync();
    final addFuture = () async {
      try {
        final playerSnapshot = ref.read(audioPlayerProvider);

        var queue = await _repository.addQueueItem(episodeId);
        queue = _applyQueue(queue);

        final currentOrder = queue.items.map((item) => item.episodeId).toList();
        final desiredOrder = buildQueueOrderAfterAdd(
          queue: queue,
          episodeId: episodeId,
          isPlaying: playerSnapshot.isPlaying,
          playingEpisodeId: playerSnapshot.currentEpisode?.id,
        );

        if (!isSameEpisodeOrder(currentOrder, desiredOrder)) {
          try {
            final reorderedQueue = await _repository.reorderQueueItems(
              desiredOrder,
            );
            queue = _applyQueue(reorderedQueue);
          } catch (error) {
            logger.AppLogger.debug(
              '[Queue] Reorder after add failed; keeping add result. error=$error',
            );
            unawaited(
              _loadQueueInternal(
                forceRefresh: true,
                trackSyncing: false,
                setErrorStateOnFailure: false,
              ),
            );
          }
        }

        return queue;
      } catch (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
        rethrow;
      } finally {
        _endQueueSync();
      }
    }();

    _inFlightAddToQueueByEpisodeId[episodeId] = addFuture;
    try {
      return await addFuture;
    } finally {
      if (identical(_inFlightAddToQueueByEpisodeId[episodeId], addFuture)) {
        _inFlightAddToQueueByEpisodeId.remove(episodeId);
      }
    }
  }

  Future<PodcastQueueModel> removeFromQueue(int episodeId) async {
    // --- Optimistic UI update: remove item instantly ---
    // Use addPostFrameCallback to defer the state mutation so it does not
    // trigger a rebuild while RenderSliverList is still performing layout.
    final previousQueue = state.value;
    if (previousQueue != null) {
      final updatedItems = previousQueue.items
          .where((i) => i.episodeId != episodeId)
          .toList();
      int? updatedCurrentEpisodeId = previousQueue.currentEpisodeId;
      if (updatedCurrentEpisodeId == episodeId) {
        final oldIndex = previousQueue.items.indexWhere(
          (i) => i.episodeId == episodeId,
        );
        if (oldIndex >= 0 && oldIndex + 1 < previousQueue.items.length) {
          updatedCurrentEpisodeId = previousQueue.items[oldIndex + 1].episodeId;
        } else if (updatedItems.isNotEmpty) {
          updatedCurrentEpisodeId = updatedItems.first.episodeId;
        } else {
          updatedCurrentEpisodeId = null;
        }
      }
      final optimistic = PodcastQueueModel(
        items: updatedItems,
        currentEpisodeId: updatedCurrentEpisodeId,
        revision: previousQueue.revision + 1,
        updatedAt: DateTime.now(),
      );
      // Defer state update until after the current frame completes layout/paint.
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      state = AsyncValue.data(optimistic);
      _latestAppliedQueueRevision = optimistic.revision;
      ref.read(audioPlayerProvider.notifier).syncQueueState(optimistic);
    }

    // --- Background API call (no rollback) ---
    _beginQueueSync();
    try {
      final queue = await _repository.removeQueueItem(episodeId);
      return _applyQueue(queue);
    } catch (error) {
      // Server likely already completed the delete.
      // Refresh in background to reconcile state rather than rolling back.
      unawaited(
        _loadQueueInternal(
          forceRefresh: true,
          trackSyncing: false,
          setErrorStateOnFailure: false,
        ),
      );
      return state.value ?? PodcastQueueModel.empty();
    } finally {
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> reorderQueue(List<int> episodeIds) async {
    _beginQueueSync();
    try {
      final queue = await _repository.reorderQueueItems(episodeIds);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> setCurrentEpisode(int episodeId) async {
    _beginQueueSync();
    try {
      final queue = await _repository.setQueueCurrent(episodeId);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    _beginQueueSync();
    try {
      final queue = await _repository.activateQueueEpisode(episodeId);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> playFromQueue(int episodeId) async {
    try {
      final queue = await activateEpisode(episodeId);

      final current = queue.currentItem;
      if (current != null) {
        await ref
            .read(audioPlayerProvider.notifier)
            .playEpisode(
              current.toEpisodeModel(),
              source: PlaySource.queue,
              queueEpisodeId: current.episodeId,
            );
      }
      return queue;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<PodcastQueueModel> onQueueTrackCompleted() async {
    try {
      final queue = await _repository.completeQueueCurrent();
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
