import 'package:home_widget/home_widget.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Home screen widget service for managing app widgets.
///
/// Supports:
/// - iOS: WidgetKit widgets
/// - Android: Glance widgets
/// - Updating widget data from Flutter
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const String _nowPlayingWidgetId = 'now_playing_widget';
  static const String _recentUpdatesWidgetId = 'recent_updates_widget';

  /// Initialize the home widget service.
  Future<void> initialize() async {
    logger.AppLogger.debug('[HomeWidgetService] Initialized');
  }

  /// Update the "Now Playing" widget with current episode info.
  Future<void> updateNowPlayingWidget({
    required String title,
    required String podcastName,
    String? imageUrl,
    bool isPlaying = false,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'now_playing_title',
        title,
      );
      await HomeWidget.saveWidgetData<String>(
        'now_playing_podcast',
        podcastName,
      );
      await HomeWidget.saveWidgetData<String>(
        'now_playing_image',
        imageUrl ?? '',
      );
      await HomeWidget.saveWidgetData<bool>(
        'now_playing_is_playing',
        isPlaying,
      );
      await HomeWidget.updateWidget(
        name: _nowPlayingWidgetId,
        androidName: 'NowPlayingWidget',
      );
      logger.AppLogger.debug(
        '[HomeWidgetService] Updated now playing widget: $title',
      );
    } catch (e) {
      logger.AppLogger.error(
        '[HomeWidgetService] Failed to update now playing widget: $e',
      );
    }
  }

  /// Update the "Recent Updates" widget with new episodes.
  Future<void> updateRecentUpdatesWidget({
    required List<Map<String, dynamic>> episodes,
  }) async {
    final recentEpisodes = episodes.take(3).toList();

    try {
      await HomeWidget.saveWidgetData<int>(
        'recent_count',
        recentEpisodes.length,
      );
      for (var i = 0; i < recentEpisodes.length; i++) {
        final ep = recentEpisodes[i];
        await HomeWidget.saveWidgetData<String>(
          'recent_${i}_title',
          (ep['title'] ?? '') as String,
        );
        await HomeWidget.saveWidgetData<String>(
          'recent_${i}_podcast',
          (ep['podcastName'] ?? '') as String,
        );
      }
      await HomeWidget.updateWidget(
        name: _recentUpdatesWidgetId,
        androidName: 'RecentUpdatesWidget',
      );
      logger.AppLogger.debug(
        '[HomeWidgetService] Updated recent updates widget: ${recentEpisodes.length} episodes',
      );
    } catch (e) {
      logger.AppLogger.error(
        '[HomeWidgetService] Failed to update recent updates widget: $e',
      );
    }
  }

  /// Clear all widget data.
  Future<void> clearAll() async {
    try {
      // home_widget doesn't have a delete method, just overwrite with empty
      await HomeWidget.saveWidgetData<String>('now_playing_title', '');
      await HomeWidget.saveWidgetData<String>('now_playing_podcast', '');
      await HomeWidget.saveWidgetData<String>('now_playing_image', '');
      await HomeWidget.saveWidgetData<bool>('now_playing_is_playing', false);
      await HomeWidget.saveWidgetData<int>('recent_count', 0);
      await HomeWidget.updateWidget(name: _nowPlayingWidgetId);
      await HomeWidget.updateWidget(name: _recentUpdatesWidgetId);
      logger.AppLogger.debug('[HomeWidgetService] Cleared all widgets');
    } catch (e) {
      logger.AppLogger.error(
        '[HomeWidgetService] Failed to clear widgets: $e',
      );
    }
  }
}
