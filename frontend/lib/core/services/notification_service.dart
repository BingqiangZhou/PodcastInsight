import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Notification service for managing local notifications.
///
/// Supports:
/// - iOS: APNs-style local notifications
/// - Android: Notification channels
/// - Permission requests
/// - Scheduled notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service.
  ///
  /// Must be called during app startup.
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    if (_initialized) return true;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS/macOS initialization settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: macOSSettings,
    );

    final result = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final success = result ?? false;
    if (success) {
      _initialized = true;
      logger.AppLogger.debug('[NotificationService] Initialized successfully');

      // Create notification channels for Android
      if (!kIsWeb && Platform.isAndroid) {
        await _createChannels();
      }
    } else {
      // Not all platforms support local notifications (e.g. macOS)
      _initialized = true;
      logger.AppLogger.debug('[NotificationService] Platform returned false, continuing');
    }

    return success;
  }

  /// Create notification channels for Android (Oreo and above).
  Future<void> _createChannels() async {
    const newEpisodeChannel = AndroidNotificationChannel(
      'new_episodes',
      'New Episodes',
      description: 'Notifications for new podcast episodes',
      importance: Importance.high,
    );

    const playbackChannel = AndroidNotificationChannel(
      'playback',
      'Playback',
      description: 'Playback status notifications',
      importance: Importance.low,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(newEpisodeChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(playbackChannel);

    logger.AppLogger.debug('[NotificationService] Notification channels created');
  }

  /// Request notification permissions from the user.
  ///
  /// Returns true if permissions are granted.
  Future<bool> requestPermissions() async {
    if (!kIsWeb && Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    }

    return true;
  }

  /// Check if notification permissions are granted.
  Future<bool> arePermissionsGranted() async {
    if (!kIsWeb && Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }

    return true;
  }

  /// Show a new episode notification.
  Future<void> showNewEpisodeNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'new_episodes',
      'New Episodes',
      channelDescription: 'Notifications for new podcast episodes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show a playback status notification (low priority).
  Future<void> showPlaybackNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'playback',
      'Playback',
      channelDescription: 'Playback status notifications',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      details,
    );
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification by ID.
  Future<void> cancelById(int id) async {
    await _notifications.cancel(id);
  }

  /// Handle notification tap events.
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    logger.AppLogger.debug(
      '[NotificationService] Notification tapped: $payload',
    );
  }
}
