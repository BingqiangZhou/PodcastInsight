import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Memory management utility for monitoring and responding to memory pressure.
///
/// This utility helps manage memory in Flutter apps by:
/// - Monitoring memory usage patterns
/// - Providing callbacks for memory pressure events
/// - Coordinating cleanup across multiple caches
/// - Offering diagnostic information
///
/// Usage:
/// ```dart
/// // Initialize at app startup
/// await MemoryManager.instance.initialize();
///
/// // Register a cleanup callback
/// MemoryManager.instance.registerCleanupCallback('myCache', () {
///   myCache.clear();
/// });
///
/// // Manually trigger cleanup if needed
/// MemoryManager.instance.performCleanup();
/// ```
class MemoryManager {
  MemoryManager._();

  static final MemoryManager instance = MemoryManager._();

  /// Registered cleanup callbacks keyed by owner name
  final Map<String, VoidCallback> _cleanupCallbacks = {};

  /// Memory pressure state
  MemoryPressure _currentPressure = MemoryPressure.normal;

  /// Timestamp of last cleanup
  DateTime? _lastCleanupTime;

  /// Minimum interval between cleanups to avoid excessive GC
  static const Duration _minCleanupInterval = Duration(seconds: 30);

  /// Whether the manager has been initialized
  bool _initialized = false;

  /// Initialize the memory manager.
  ///
  /// Should be called once at app startup.
  /// Sets up platform-specific memory monitoring.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    logger.AppLogger.debug('[MemoryManager] Initializing...');

    // Register default cleanup handlers
    _registerDefaultHandlers();

    // On web, we can use the Performance API for memory monitoring
    if (kIsWeb) {
      _setupWebMemoryMonitoring();
    }

    // On mobile platforms, memory pressure is handled automatically by Flutter
    // but we can add additional monitoring
    logger.AppLogger.debug('[MemoryManager] Initialized');
  }

  void _registerDefaultHandlers() {
    // Register text processing cache cleanup
    registerCleanupCallback('textProcessingCache', () {
      // Import would be circular, so this is a placeholder
      // TextProcessingCache.performCleanup();
    });

    // Register image cache cleanup
    registerCleanupCallback('imageCache', () {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();
    });
  }

  void _setupWebMemoryMonitoring() {
    // Web-specific memory monitoring using Performance API
    // This is a simplified implementation
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (kIsWeb) {
        _checkWebMemoryPressure();
      }
    });
  }

  void _checkWebMemoryPressure() {
    // On web, we can use performance.memory if available
    // This is Chrome-specific and may not work in all browsers
    try {
      // Note: This requires specific browser support
      // In production, you'd want more robust detection
    } catch (_) {
      // Silently ignore if not supported
    }
  }

  /// Register a cleanup callback for a specific resource.
  ///
  /// The [owner] should be a unique identifier for the resource
  /// (e.g., 'imageCache', 'audioCache', 'textProcessingCache').
  ///
  /// The [callback] will be invoked when memory pressure is detected
  /// or when performCleanup is manually called.
  void registerCleanupCallback(String owner, VoidCallback callback) {
    _cleanupCallbacks[owner] = callback;
    logger.AppLogger.debug('[MemoryManager] Registered cleanup callback: $owner');
  }

  /// Unregister a cleanup callback.
  void unregisterCleanupCallback(String owner) {
    _cleanupCallbacks.remove(owner);
    logger.AppLogger.debug('[MemoryManager] Unregistered cleanup callback: $owner');
  }

  /// Perform cleanup of all registered resources.
  ///
  /// This method is rate-limited to avoid excessive garbage collection.
  /// Returns true if cleanup was performed, false if skipped due to rate limiting.
  bool performCleanup({bool force = false}) {
    final now = DateTime.now();

    // Check rate limiting unless forced
    if (!force &&
        _lastCleanupTime != null &&
        now.difference(_lastCleanupTime!) < _minCleanupInterval) {
      logger.AppLogger.debug('[MemoryManager] Cleanup skipped (rate limited)');
      return false;
    }

    logger.AppLogger.debug('[MemoryManager] Performing cleanup...');
    logger.AppLogger.debug('[MemoryManager] Registered callbacks: ${_cleanupCallbacks.length}');

    int cleaned = 0;
    for (final entry in _cleanupCallbacks.entries) {
      try {
        entry.value();
        cleaned++;
      } catch (e, st) {
        logger.AppLogger.debug('[MemoryManager] Cleanup failed for ${entry.key}: $e');
        logger.AppLogger.debug('[MemoryManager] Stack trace: $st');
      }
    }

    _lastCleanupTime = now;
    logger.AppLogger.debug('[MemoryManager] Cleanup completed: $cleaned/${_cleanupCallbacks.length} handlers');

    return true;
  }

  /// Get current memory pressure state.
  MemoryPressure get currentPressure => _currentPressure;

  /// Update memory pressure state.
  ///
  /// This can be called in response to platform memory pressure events.
  void updatePressure(MemoryPressure pressure) {
    if (_currentPressure == pressure) return;

    logger.AppLogger.debug('[MemoryManager] Memory pressure changed: $_currentPressure -> $pressure');
    _currentPressure = pressure;

    // Perform cleanup when under pressure
    if (pressure != MemoryPressure.normal) {
      performCleanup(force: true);
    }
  }

  /// Get memory statistics for monitoring.
  ///
  /// Returns a map with diagnostic information about memory state.
  Map<String, dynamic> getStats() {
    final imageCache = PaintingBinding.instance.imageCache;

    return {
      'pressure': _currentPressure.toString(),
      'lastCleanup': _lastCleanupTime?.toIso8601String(),
      'registeredCallbacks': _cleanupCallbacks.length,
      'callbackOwners': _cleanupCallbacks.keys.toList(),
      'imageCache': {
        'currentSize': imageCache.currentSize,
        'currentSizeBytes': imageCache.currentSizeBytes,
        'maximumSize': imageCache.maximumSize,
        'maximumSizeBytes': imageCache.maximumSizeBytes,
        'liveImageCount': imageCache.liveImageCount,
        'usagePercentage': imageCache.maximumSizeBytes > 0
            ? (imageCache.currentSizeBytes / imageCache.maximumSizeBytes * 100).toStringAsFixed(1)
            : '0',
      },
    };
  }

  /// Clears all registered cleanup callbacks.
  ///
  /// Useful for testing or when shutting down the app.
  void clearCallbacks() {
    _cleanupCallbacks.clear();
    logger.AppLogger.debug('[MemoryManager] All callbacks cleared');
  }
}

/// Memory pressure levels.
enum MemoryPressure {
  /// Normal memory usage, no action needed.
  normal,

  /// Moderate memory pressure, consider optional cleanup.
  moderate,

  /// High memory pressure, aggressive cleanup recommended.
  critical,
}
