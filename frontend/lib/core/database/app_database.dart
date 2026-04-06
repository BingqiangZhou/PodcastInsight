import 'package:drift/drift.dart';
import 'package:personal_ai_assistant/core/database/dao/download_dao.dart';
import 'package:personal_ai_assistant/core/database/dao/episode_cache_dao.dart';
import 'package:personal_ai_assistant/core/database/dao/playback_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [DownloadTasks, PlaybackStates, EpisodesCache],
  daos: [DownloadDao, PlaybackDao, EpisodeCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Recreate episodes_cache with primary key on id
        await migrator.deleteTable('episodes_cache');
        await migrator.createTable(episodesCache);
      }
    },
  );
}

// === Download Tasks Table ===

class DownloadTasks extends Table {
  @override
  String get tableName => 'download_tasks';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get episodeId => integer()();
  TextColumn get audioUrl => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// === Playback States Table ===

class PlaybackStates extends Table {
  @override
  String get tableName => 'playback_states';

  IntColumn get episodeId => integer()();
  IntColumn get positionSeconds =>
      integer().withDefault(const Constant(0))();
  RealColumn get playbackRate =>
      real().withDefault(const Constant(1))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {episodeId};
}

// === Episodes Cache Table ===

class EpisodesCache extends Table {
  @override
  String get tableName => 'episodes_cache';

  IntColumn get id => integer()();
  IntColumn get subscriptionId => integer()();
  TextColumn get title => text()();
  TextColumn get audioUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get audioDuration => integer().nullable()();
  TextColumn get subscriptionTitle => text().nullable()();
  TextColumn get subscriptionImageUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
