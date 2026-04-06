import 'package:drift/drift.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';

part 'download_dao.g.dart';

@DriftAccessor(tables: [DownloadTasks])
class DownloadDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadDaoMixin {
  DownloadDao(super.db);

  /// Insert a new download task.
  Future<int> insertTask(DownloadTasksCompanion task) {
    return into(downloadTasks).insert(task);
  }

  /// Watch all download tasks, ordered by creation time descending.
  Stream<List<DownloadTask>> watchAll() {
    return (select(downloadTasks)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Watch download task for a specific episode.
  Stream<DownloadTask?> watchByEpisodeId(int episodeId) {
    return (select(downloadTasks)
          ..where((t) => t.episodeId.equals(episodeId)))
        .watchSingleOrNull();
  }

  /// Get a download task by episode ID.
  Future<DownloadTask?> getByEpisodeId(int episodeId) {
    return (select(downloadTasks)
          ..where((t) => t.episodeId.equals(episodeId)))
        .getSingleOrNull();
  }

  /// Get all completed downloads.
  Future<List<DownloadTask>> getAllCompleted() {
    return (select(downloadTasks)
          ..where((t) => t.status.equals('completed')))
        .get();
  }

  /// Update download progress.
  Future<void> updateProgress(int id, double progress) {
    return (update(downloadTasks)
          ..where((t) => t.id.equals(id)))
        .write(DownloadTasksCompanion(progress: Value(progress)));
  }

  /// Mark a download as completed with the local file path.
  Future<void> markCompleted(int id, String localPath) {
    return (update(downloadTasks)
          ..where((t) => t.id.equals(id)))
        .write(
      DownloadTasksCompanion(
        status: const Value('completed'),
        localPath: Value(localPath),
        progress: const Value(1),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark a download as failed.
  Future<void> markFailed(int id) {
    return (update(downloadTasks)
          ..where((t) => t.id.equals(id)))
        .write(const DownloadTasksCompanion(status: Value('failed')));
  }

  /// Mark a download as pending (for retry).
  Future<void> markPending(int id) {
    return (update(downloadTasks)
          ..where((t) => t.id.equals(id)))
        .write(
      const DownloadTasksCompanion(
        status: Value('pending'),
        progress: Value(0),
      ),
    );
  }

  /// Delete a download task by episode ID.
  Future<void> deleteByEpisodeId(int episodeId) {
    return (delete(downloadTasks)
          ..where((t) => t.episodeId.equals(episodeId)))
        .go();
  }

  /// Delete a download task by ID.
  Future<void> deleteById(int id) {
    return (delete(downloadTasks)..where((t) => t.id.equals(id))).go();
  }

  /// Get the local file path for a completed download by episode ID.
  Future<String?> getLocalPathByEpisodeId(int episodeId) async {
    final task = await getByEpisodeId(episodeId);
    if (task != null && task.status == 'completed') {
      return task.localPath;
    }
    return null;
  }
}
