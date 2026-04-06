import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/database_provider.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:riverpod/src/providers/stream_provider.dart';

/// Provides the [AudioDownloadService] singleton.
final downloadManagerProvider = Provider<AudioDownloadService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = AudioDownloadService(db);

  ref.onDispose(service.dispose);

  return service;
});

/// Watches all download tasks, ordered by creation time descending.
final downloadsListProvider =
    StreamProvider<List<DownloadTask>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.downloadDao.watchAll();
});

/// Watches the download status for a specific episode.
///
/// Returns null if no download task exists for this episode.
final StreamProviderFamily<DownloadTask?, int> episodeDownloadStatusProvider =
    StreamProvider.family<DownloadTask?, int>((ref, episodeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.downloadDao.watchByEpisodeId(episodeId);
});

/// Fetches cached episode metadata for a given episode ID.
///
/// Returns null if the episode is not in the local cache.
final FutureProviderFamily<EpisodesCacheData?, int> episodeCacheMetaProvider =
    FutureProvider.family<EpisodesCacheData?, int>((ref, episodeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.episodeCacheDao.getById(episodeId);
});

/// Groups download tasks by status: [active, failed, completed].
///
/// Used by the downloads page to render sections without filtering in build().
typedef GroupedDownloads = ({
  List<DownloadTask> active,
  List<DownloadTask> failed,
  List<DownloadTask> completed,
});

final groupedDownloadsProvider = Provider<GroupedDownloads>((ref) {
  final asyncValue = ref.watch(downloadsListProvider);
  final tasks = asyncValue.whenOrNull(
        data: (data) => data,
      ) ??
      [];
  return (
    active: tasks
        .where((t) => t.status == 'pending' || t.status == 'downloading')
        .toList(),
    failed: tasks.where((t) => t.status == 'failed').toList(),
    completed: tasks.where((t) => t.status == 'completed').toList(),
  );
});
