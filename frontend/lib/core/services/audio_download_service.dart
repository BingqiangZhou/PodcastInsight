import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/download_dao.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Manages audio file downloads for offline playback.
///
/// Downloads audio files from CDN URLs to local storage and tracks
/// progress in the [DownloadTasks] table via [DownloadDao].
class AudioDownloadService {
  final AppDatabase _db;
  final HttpClient _httpClient = HttpClient();

  /// Active download sinks keyed by episode ID for cancellation.
  final Map<int, IOSink> _activeSinks = {};

  /// Aborted flags keyed by episode ID.
  final Map<int, bool> _aborted = {};

  /// Maximum concurrent downloads.
  static const int _maxConcurrent = 2;

  /// Current download count.
  int get _activeCount => _activeSinks.length;

  AudioDownloadService(this._db);

  DownloadDao get _dao => _db.downloadDao;

  /// Start downloading an episode's audio file.
  ///
  /// If a download already exists for this episode, its status is checked:
  /// - completed: returns immediately
  /// - pending/downloading/failed: retries the download
  Future<void> download({
    required int episodeId,
    required String audioUrl,
    String? title,
    String? subscriptionTitle,
    String? imageUrl,
    String? subscriptionImageUrl,
    int? subscriptionId,
    int? audioDuration,
    DateTime? publishedAt,
  }) async {
    // Cache episode metadata for the downloads page
    if (title != null) {
      await _db.episodeCacheDao.upsertEpisode(
        EpisodesCacheCompanion.insert(
          id: episodeId,
          subscriptionId: subscriptionId ?? 0,
          title: title,
          audioUrl: audioUrl,
          imageUrl: Value(imageUrl),
          audioDuration: Value(audioDuration),
          subscriptionTitle: Value(subscriptionTitle),
          subscriptionImageUrl: Value(subscriptionImageUrl),
          publishedAt: publishedAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    // Check existing task
    final existing = await _dao.getByEpisodeId(episodeId);
    if (existing != null && existing.status == 'completed') {
      logger.AppLogger.debug(
        '[Download] Episode $episodeId already downloaded: ${existing.localPath}',
      );
      return;
    }

    // Insert or reset task
    if (existing != null) {
      await _dao.markPending(existing.id);
    } else {
      await _dao.insertTask(
        DownloadTasksCompanion.insert(
          episodeId: episodeId,
          audioUrl: audioUrl,
        ),
      );
    }

    _startDownload(episodeId, audioUrl);
  }

  /// Internal method to perform the actual download.
  Future<void> _startDownload(int episodeId, String audioUrl) async {
    final task = await _dao.getByEpisodeId(episodeId);
    if (task == null) return;

    _aborted[episodeId] = false;

    try {
      // Mark as downloading
      await _dao.updateProgress(task.id, 0.0);

      final uri = Uri.parse(audioUrl);
      final request = await _httpClient.getUrl(uri);

      final response = await request.close();
      final contentLength = response.contentLength;

      // Prepare local file
      final dir = await _getDownloadsDirectory();
      final fileName = _generateFileName(episodeId, audioUrl);
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);

      // Ensure parent directory exists
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final sink = file.openWrite();
      _activeSinks[episodeId] = sink;
      int receivedBytes = 0;

      await for (final chunk in response) {
        // Check if aborted
        if (_aborted[episodeId] == true) {
          await sink.close();
          if (await file.exists()) {
            await file.delete();
          }
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          await _dao.updateProgress(task.id, progress.clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();

      // Verify file was written
      if (await file.exists() && await file.length() > 0) {
        await _dao.markCompleted(task.id, filePath);
        logger.AppLogger.info(
          '[Download] Completed episode $episodeId: $filePath (${_formatBytes(receivedBytes)})',
        );
      } else {
        await file.delete().catchError((_) => File(''));
        await _dao.markFailed(task.id);
        logger.AppLogger.warning('[Download] Empty file for episode $episodeId');
      }
    } catch (e) {
      // Clean up partial file
      final dir = await _getDownloadsDirectory();
      final fileName = _generateFileName(episodeId, audioUrl);
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete().catchError((_) => File(''));
      }

      await _dao.markFailed(task.id);
      logger.AppLogger.error('[Download] Failed episode $episodeId: $e');
    } finally {
      _activeSinks.remove(episodeId);
      _aborted.remove(episodeId);
    }
  }

  /// Cancel an active download.
  Future<void> cancel(int episodeId) async {
    _aborted[episodeId] = true;

    final sink = _activeSinks.remove(episodeId);
    if (sink != null) {
      await sink.close().catchError((_) {});
      logger.AppLogger.debug('[Download] Cancelled episode $episodeId');
    }

    final task = await _dao.getByEpisodeId(episodeId);
    if (task != null) {
      await _dao.markFailed(task.id);
    }
  }

  /// Delete a downloaded file and its task record.
  Future<void> delete(int episodeId) async {
    // Cancel if actively downloading
    await cancel(episodeId);

    final task = await _dao.getByEpisodeId(episodeId);
    if (task != null) {
      // Delete local file
      if (task.localPath != null) {
        final file = File(task.localPath!);
        if (await file.exists()) {
          await file.delete();
          logger.AppLogger.debug(
            '[Download] Deleted file for episode $episodeId: ${task.localPath}',
          );
        }
      }
      await _dao.deleteByEpisodeId(episodeId);
    }
  }

  /// Get the local file path for a downloaded episode, or null if not available.
  Future<String?> getLocalPath(int episodeId) async {
    final task = await _dao.getByEpisodeId(episodeId);
    if (task != null && task.status == 'completed' && task.localPath != null) {
      final file = File(task.localPath!);
      if (await file.exists()) {
        return task.localPath;
      }
      // File was deleted externally — clean up
      await _dao.deleteByEpisodeId(episodeId);
    }
    return null;
  }

  /// Watch all download tasks.
  Stream<List<DownloadTask>> watchAll() => _dao.watchAll();

  /// Watch a specific episode's download status.
  Stream<DownloadTask?> watchByEpisodeId(int episodeId) =>
      _dao.watchByEpisodeId(episodeId);

  /// Get all completed downloads.
  Future<List<DownloadTask>> getAllCompleted() => _dao.getAllCompleted();

  /// Clean up resources.
  void dispose() {
    for (final sink in _activeSinks.values) {
      sink.close().catchError((_) {});
    }
    _activeSinks.clear();
    _aborted.clear();
    _httpClient.close();
  }

  // --- Helpers ---

  Future<Directory> _getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'downloads'));
  }

  String _generateFileName(int episodeId, String audioUrl) {
    final hash = audioUrl.hashCode.toRadixString(36).replaceAll('-', 'n');
    // Try to preserve extension from URL
    final ext = _getExtensionFromUrl(audioUrl);
    return 'episode_${episodeId}_$hash$ext';
  }

  String _getExtensionFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot > 0 && lastDot > path.length - 6) {
        return path.substring(lastDot);
      }
    } catch (_) {
      // ignore
    }
    return '.mp3';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
