part of 'podcast_playback_providers.dart';

enum QueueOperationKind {
  idle,
  initialLoading,
  refreshing,
  reordering,
  removing,
  activating,
}

class QueueOperationState {
  const QueueOperationState._(this.kind, {this.episodeId});

  const QueueOperationState.idle() : this._(QueueOperationKind.idle);

  const QueueOperationState.initialLoading()
    : this._(QueueOperationKind.initialLoading);

  const QueueOperationState.refreshing()
    : this._(QueueOperationKind.refreshing);

  const QueueOperationState.reordering()
    : this._(QueueOperationKind.reordering);

  const QueueOperationState.removing({int? episodeId})
    : this._(QueueOperationKind.removing, episodeId: episodeId);

  const QueueOperationState.activating({int? episodeId})
    : this._(QueueOperationKind.activating, episodeId: episodeId);

  final QueueOperationKind kind;
  final int? episodeId;

  bool get isBusy => kind != QueueOperationKind.idle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is QueueOperationState &&
        other.kind == kind &&
        other.episodeId == episodeId;
  }

  @override
  int get hashCode => Object.hash(kind, episodeId);
}

final podcastQueueControllerProvider =
    AsyncNotifierProvider<PodcastQueueController, PodcastQueueModel>(
      PodcastQueueController.new,
    );

final podcastQueueOperationProvider =
    NotifierProvider<QueueOperationNotifier, QueueOperationState>(
      QueueOperationNotifier.new,
    );

class QueueOperationNotifier extends Notifier<QueueOperationState> {
  @override
  QueueOperationState build() {
    return const QueueOperationState.idle();
  }

  void setState(QueueOperationState operation) {
    state = operation;
  }
}

class PodcastQueueController extends AsyncNotifier<PodcastQueueModel> {
  late PodcastRepository _repository;
  Future<PodcastQueueModel>? _inFlightQueueLoad;
  final Map<int, Future<PodcastQueueModel>> _inFlightAddToQueueByEpisodeId =
      <int, Future<PodcastQueueModel>>{};
  DateTime? _lastQueueRefreshAt;
  int _latestAppliedQueueRevision = -1;
  int _queueSyncInFlight = 0;
  static const Duration _queueRefreshThrottle = Duration(seconds: 20);

  @visibleForTesting
  Duration get queueLoadTimeout => const Duration(seconds: 12);

  @override
  FutureOr<PodcastQueueModel> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    try {
      return await _loadQueueInternal(
        forceRefresh: false,
        trackSyncing: false,
        setErrorStateOnFailure: false,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  bool _hasFreshQueueState() {
    final lastRefresh = _lastQueueRefreshAt;
    if (lastRefresh == null) {
      return false;
    }
    return DateTime.now().difference(lastRefresh) <
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

  void _setQueueOperation(QueueOperationState operation) {
    ref.read(podcastQueueOperationProvider.notifier).setState(operation);
  }

  void _clearQueueOperation() {
    ref
        .read(podcastQueueOperationProvider.notifier)
        .setState(const QueueOperationState.idle());
  }

  void _setErrorStateIfNeeded(Object error, StackTrace stackTrace) {
    if (state.value == null) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  PodcastQueueItemModel _copyQueueItemWithPosition(
    PodcastQueueItemModel item,
    int position,
  ) {
    return PodcastQueueItemModel(
      episodeId: item.episodeId,
      position: position,
      playbackPosition: item.playbackPosition,
      title: item.title,
      podcastId: item.podcastId,
      audioUrl: item.audioUrl,
      duration: item.duration,
      publishedAt: item.publishedAt,
      imageUrl: item.imageUrl,
      subscriptionTitle: item.subscriptionTitle,
      subscriptionImageUrl: item.subscriptionImageUrl,
    );
  }

  List<PodcastQueueItemModel> _reindexItems(List<PodcastQueueItemModel> items) {
    return items
        .asMap()
        .entries
        .map((entry) => _copyQueueItemWithPosition(entry.value, entry.key))
        .toList();
  }

  int? _resolveCurrentEpisodeIdAfterRemoval(
    PodcastQueueModel queue,
    int removedEpisodeId,
    List<PodcastQueueItemModel> updatedItems,
  ) {
    final currentEpisodeId = queue.currentEpisodeId;
    if (currentEpisodeId != removedEpisodeId) {
      return currentEpisodeId;
    }

    final oldIndex = queue.items.indexWhere(
      (item) => item.episodeId == removedEpisodeId,
    );
    if (oldIndex >= 0 && oldIndex + 1 < queue.items.length) {
      return queue.items[oldIndex + 1].episodeId;
    }
    if (updatedItems.isNotEmpty) {
      return updatedItems.first.episodeId;
    }
    return null;
  }

  PodcastQueueModel _buildOptimisticRemovedQueue(
    PodcastQueueModel queue,
    int episodeId,
  ) {
    final updatedItems = _reindexItems(
      queue.items.where((item) => item.episodeId != episodeId).toList(),
    );
    return PodcastQueueModel(
      items: updatedItems,
      currentEpisodeId: _resolveCurrentEpisodeIdAfterRemoval(
        queue,
        episodeId,
        updatedItems,
      ),
      revision: queue.revision + 1,
      updatedAt: DateTime.now(),
    );
  }

  PodcastQueueModel _buildOptimisticReorderedQueue(
    PodcastQueueModel queue,
    List<int> episodeIds,
  ) {
    final itemById = <int, PodcastQueueItemModel>{
      for (final item in queue.items) item.episodeId: item,
    };
    final orderedItems = <PodcastQueueItemModel>[];
    for (final episodeId in episodeIds) {
      final item = itemById.remove(episodeId);
      if (item != null) {
        orderedItems.add(item);
      }
    }
    orderedItems.addAll(itemById.values);

    return PodcastQueueModel(
      currentEpisodeId: queue.currentEpisodeId,
      revision: queue.revision + 1,
      updatedAt: DateTime.now(),
      items: _reindexItems(orderedItems),
    );
  }

  PodcastQueueModel _commitQueueState(
    PodcastQueueModel queue, {
    required bool updateLastRefreshAt,
    bool enforceRevisionGuard = true,
  }) {
    if (enforceRevisionGuard && queue.revision < _latestAppliedQueueRevision) {
      logger.AppLogger.debug(
        '[Queue] Ignore stale queue snapshot: incoming_revision=${queue.revision}, latest_revision=$_latestAppliedQueueRevision',
      );
      return state.value ?? queue;
    }

    state = AsyncValue.data(queue);
    if (updateLastRefreshAt) {
      _lastQueueRefreshAt = DateTime.now();
    }
    _latestAppliedQueueRevision = queue.revision;
    ref.read(audioPlayerProvider.notifier).syncQueueState(queue);
    return queue;
  }

  PodcastQueueModel _applyQueue(PodcastQueueModel queue) {
    return _commitQueueState(queue, updateLastRefreshAt: true);
  }

  PodcastQueueModel _applyOptimisticQueue(PodcastQueueModel queue) {
    return _commitQueueState(
      queue,
      updateLastRefreshAt: false,
      enforceRevisionGuard: false,
    );
  }

  PodcastQueueModel _restoreQueueSnapshot(PodcastQueueModel queue) {
    return _commitQueueState(
      queue,
      updateLastRefreshAt: false,
      enforceRevisionGuard: false,
    );
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
        final queue = await _repository.getQueue().timeout(queueLoadTimeout);
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
    _setQueueOperation(
      state.value == null
          ? const QueueOperationState.initialLoading()
          : const QueueOperationState.refreshing(),
    );
    try {
      return await _loadQueueInternal(
        forceRefresh: forceRefresh,
        trackSyncing: true,
        setErrorStateOnFailure: true,
      );
    } finally {
      _clearQueueOperation();
    }
  }

  Future<void> refreshQueueInBackground() async {
    _setQueueOperation(const QueueOperationState.refreshing());
    try {
      await _loadQueueInternal(
        forceRefresh: false,
        trackSyncing: false,
        setErrorStateOnFailure: false,
      );
    } catch (e) {
      // Keep existing queue UI state when background refresh fails.
      logger.AppLogger.debug('[PlaybackQueue] Background queue refresh failed: $e');
    } finally {
      _clearQueueOperation();
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

        // Auto-download the added episode
        final addedItem = queue.items.cast<PodcastQueueItemModel?>().firstWhere(
              (item) => item?.episodeId == episodeId,
              orElse: () => null,
            );
        if (addedItem != null && addedItem.audioUrl.isNotEmpty) {
          try {
            ref.read(downloadManagerProvider).download(
                  episodeId: addedItem.episodeId,
                  audioUrl: addedItem.audioUrl,
                );
          } catch (e) {
            logger.AppLogger.debug(
              '[Queue] Auto-download failed for episode $episodeId: $e',
            );
          }
        }

        return queue;
      } catch (error, stackTrace) {
        _setErrorStateIfNeeded(error, stackTrace);
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
    // Auto-cleanup: delete the download for the removed episode
    try {
      ref.read(downloadManagerProvider).delete(episodeId);
    } catch (e) {
      logger.AppLogger.debug(
        '[Queue] Auto-cleanup download failed for episode $episodeId: $e',
      );
    }

    final previousQueue = state.value;
    if (previousQueue != null) {
      final optimistic = _buildOptimisticRemovedQueue(previousQueue, episodeId);
      _applyOptimisticQueue(optimistic);
    }

    _beginQueueSync();
    _setQueueOperation(QueueOperationState.removing(episodeId: episodeId));
    try {
      final queue = await _repository.removeQueueItem(episodeId);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      if (previousQueue != null) {
        _restoreQueueSnapshot(previousQueue);
      } else {
        _setErrorStateIfNeeded(error, stackTrace);
      }
      rethrow;
    } finally {
      _clearQueueOperation();
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> removeFromQueueAndResolvePlayback(
    int episodeId,
  ) async {
    final playerSnapshot = ref.read(audioPlayerProvider);
    final isRemovingCurrentQueueEpisode =
        playerSnapshot.playSource == PlaySource.queue &&
        playerSnapshot.currentEpisode?.id == episodeId;

    final queue = await removeFromQueue(episodeId);
    if (!isRemovingCurrentQueueEpisode) {
      return queue;
    }

    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final next = queue.currentItem;
    if (next == null) {
      await playerNotifier.stop();
      return queue;
    }

    if (!playerSnapshot.isPlaying) {
      await playerNotifier.stop();
      return queue;
    }

    await playerNotifier.playEpisode(
      next.toEpisodeModel(),
      source: PlaySource.queue,
      queueEpisodeId: next.episodeId,
    );
    return queue;
  }

  Future<PodcastQueueModel> reorderQueue(List<int> episodeIds) async {
    final previousQueue = state.value;
    if (previousQueue != null) {
      _applyOptimisticQueue(
        _buildOptimisticReorderedQueue(previousQueue, episodeIds),
      );
    }

    _beginQueueSync();
    _setQueueOperation(const QueueOperationState.reordering());
    try {
      final queue = await _repository.reorderQueueItems(episodeIds);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      if (previousQueue != null) {
        _restoreQueueSnapshot(previousQueue);
      } else {
        _setErrorStateIfNeeded(error, stackTrace);
      }
      rethrow;
    } finally {
      _clearQueueOperation();
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> setCurrentEpisode(int episodeId) async {
    _beginQueueSync();
    _setQueueOperation(QueueOperationState.activating(episodeId: episodeId));
    try {
      final queue = await _repository.setQueueCurrent(episodeId);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      _setErrorStateIfNeeded(error, stackTrace);
      rethrow;
    } finally {
      _clearQueueOperation();
      _endQueueSync();
    }
  }

  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    _beginQueueSync();
    _setQueueOperation(QueueOperationState.activating(episodeId: episodeId));
    try {
      final queue = await _repository.activateQueueEpisode(episodeId);
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      _setErrorStateIfNeeded(error, stackTrace);
      rethrow;
    } finally {
      _clearQueueOperation();
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
      _setErrorStateIfNeeded(error, stackTrace);
      rethrow;
    }
  }

  Future<PodcastQueueModel> onQueueTrackCompleted() async {
    try {
      final queue = await _repository.completeQueueCurrent();
      return _applyQueue(queue);
    } catch (error, stackTrace) {
      _setErrorStateIfNeeded(error, stackTrace);
      rethrow;
    }
  }
}
