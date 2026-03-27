/// Shared helpers for episode-scoped provider cache maps.
///
/// These helpers keep provider map access consistent across summary,
/// transcription, and conversation providers without changing lifecycle
/// behavior for any notifier implementation.
T getOrCreateEpisodeScopedProvider<T>(
  Map<int, T> cache,
  int episodeId,
  T Function() create,
) {
  return cache.putIfAbsent(episodeId, create);
}

void releaseEpisodeScopedProvider<T>(Map<int, T> cache, int episodeId) {
  cache.remove(episodeId);
}
