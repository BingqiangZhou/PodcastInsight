import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/database_provider.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';

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
final episodeDownloadStatusProvider =
    StreamProvider.family<DownloadTask?, int>((ref, episodeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.downloadDao.watchByEpisodeId(episodeId);
});
