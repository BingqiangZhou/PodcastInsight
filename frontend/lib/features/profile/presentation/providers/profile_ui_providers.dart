import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Manages the notification toggle preference stored in local storage.
class NotificationPreferenceNotifier extends Notifier<bool> {
  static const String _storageKey = 'profile_notifications_enabled';
  bool _isInitialized = false;

  @override
  bool build() {
    _loadFromStorage();
    return false;
  }

  Future<void> _loadFromStorage() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final saved = await storage.getBool(_storageKey);
      if (saved != null) {
        state = saved;
      }
    } catch (e) {
      logger.AppLogger.warning('Error loading notification preference: $e');
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    if (!_isInitialized) return;
    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.saveBool(_storageKey, value);
    } catch (e) {
      logger.AppLogger.warning('Error saving notification preference: $e');
    }
  }
}

/// Provider for notification preference state.
final notificationPreferenceProvider =
    NotifierProvider<NotificationPreferenceNotifier, bool>(
  NotificationPreferenceNotifier.new,
);

/// Manages the app version string loaded from PackageInfo.
class AppVersionNotifier extends Notifier<String> {
  @override
  String build() {
    // Load version asynchronously on first access
    _loadVersion();
    return '';
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      state = 'v${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      logger.AppLogger.debug('Error loading version: $e');
      state = '\u2014';
    }
  }
}

/// Provider for app version display string.
final appVersionProvider = NotifierProvider<AppVersionNotifier, String>(
  AppVersionNotifier.new,
);
