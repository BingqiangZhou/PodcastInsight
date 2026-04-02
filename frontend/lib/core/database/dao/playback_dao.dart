import 'package:drift/drift.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';

part 'playback_dao.g.dart';

@DriftAccessor(tables: [PlaybackStates])
class PlaybackDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackDaoMixin {
  PlaybackDao(super.db);

  /// Upsert a playback state for an episode.
  Future<void> upsertPlaybackState(PlaybackStatesCompanion state) {
    return into(playbackStates).insertOnConflictUpdate(state);
  }

  /// Update position for an episode.
  Future<void> updatePosition(int episodeId, int positionSeconds) {
    return (update(playbackStates)
          ..where((t) => t.episodeId.equals(episodeId)))
        .write(
      PlaybackStatesCompanion(
        positionSeconds: Value(positionSeconds),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get playback state for a specific episode.
  Future<PlaybackState?> getByEpisodeId(int episodeId) {
    return (select(playbackStates)
          ..where((t) => t.episodeId.equals(episodeId)))
        .getSingleOrNull();
  }

  /// Watch all playback states.
  Stream<List<PlaybackState>> watchAll() {
    return (select(playbackStates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.lastUpdatedAt),
          ]))
        .watch();
  }

  /// Delete playback state by episode ID.
  Future<void> deleteByEpisodeId(int episodeId) {
    return (delete(playbackStates)
          ..where((t) => t.episodeId.equals(episodeId)))
        .go();
  }
}
