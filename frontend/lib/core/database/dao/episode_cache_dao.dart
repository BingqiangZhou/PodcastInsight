import 'package:drift/drift.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';

part 'episode_cache_dao.g.dart';

@DriftAccessor(tables: [EpisodesCache])
class EpisodeCacheDao extends DatabaseAccessor<AppDatabase>
    with _$EpisodeCacheDaoMixin {
  EpisodeCacheDao(super.db);

  /// Upsert a single episode into the cache.
  Future<void> upsertEpisode(EpisodesCacheCompanion episode) {
    return into(episodesCache).insertOnConflictUpdate(episode);
  }

  /// Bulk upsert episodes.
  Future<void> upsertAll(List<EpisodesCacheCompanion> episodes) {
    return batch((b) {
      b.insertAllOnConflictUpdate(episodesCache, episodes);
    });
  }

  /// Get a cached episode by ID.
  Future<EpisodesCacheData?> getById(int id) {
    return (select(episodesCache)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all cached episodes for a subscription.
  Future<List<EpisodesCacheData>> getBySubscriptionId(int subscriptionId) {
    return (select(episodesCache)
          ..where((t) => t.subscriptionId.equals(subscriptionId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.publishedAt),
          ]))
        .get();
  }

  /// Watch all cached episodes.
  Stream<List<EpisodesCacheData>> watchAll() {
    return (select(episodesCache)
          ..orderBy([
            (t) => OrderingTerm.desc(t.publishedAt),
          ]))
        .watch();
  }

  /// Delete a cached episode by ID.
  Future<void> deleteById(int id) {
    return (delete(episodesCache)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all cached episodes for a subscription.
  Future<void> deleteBySubscriptionId(int subscriptionId) {
    return (delete(episodesCache)
          ..where((t) => t.subscriptionId.equals(subscriptionId)))
        .go();
  }
}
