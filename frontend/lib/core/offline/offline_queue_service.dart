import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart' as logger;

part 'offline_queue_service.g.dart';

/// Queued request item for offline mode
class QueuedRequest {
  const QueuedRequest({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.timestamp,
    this.retryCount = 0,
    this.headers,
  });

  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, String>? headers;

  QueuedRequest copyWith({
    String? id,
    String? endpoint,
    String? method,
    Map<String, dynamic>? body,
    DateTime? timestamp,
    int? retryCount,
    Map<String, String>? headers,
  }) {
    return QueuedRequest(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      headers: headers ?? this.headers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
        'headers': headers,
      };

  static QueuedRequest fromJson(Map<String, dynamic> json) => QueuedRequest(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        body: json['body'] as Map<String, dynamic>?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        headers: json['headers'] as Map<String, String>?,
      );
}

/// Result of processing a queued request
class QueuedRequestResult {
  const QueuedRequestResult({
    required this.requestId,
    required this.success,
    this.error,
  });

  final String requestId;
  final bool success;
  final String? error;
}

/// Configuration for offline queue behavior
class OfflineQueueConfig {
  const OfflineQueueConfig({
    this.maxQueueSize = 100,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.persistQueue = true,
    this.queueStorageKey = 'offline_request_queue',
  });

  final int maxQueueSize;
  final int maxRetries;
  final Duration retryDelay;
  final bool persistQueue;
  final String queueStorageKey;
}

/// Service for managing offline request queue
@riverpod
OfflineQueueService offlineQueueService(Ref ref) {
  return OfflineQueueService(
    config: const OfflineQueueConfig(),
  );
}

class OfflineQueueService {
  OfflineQueueService({
    required this.config,
  });

  final OfflineQueueConfig config;
  final List<QueuedRequest> _queue = [];
  bool _isProcessing = false;
  final StreamController<QueuedRequestResult> _resultController =
      StreamController.broadcast();

  Stream<QueuedRequestResult> get resultStream => _resultController.stream;

  List<QueuedRequest> get queue => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  bool get isProcessing => _isProcessing;

  /// Add a request to the offline queue
  String addRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    if (_queue.length >= config.maxQueueSize) {
      logger.AppLogger.warning(
        'Offline queue full ($queueLength/${config.maxQueueSize}). '
        'Removing oldest request.',
      );
      _queue.removeAt(0);
    }

    final request = QueuedRequest(
      id: _generateId(),
      endpoint: endpoint,
      method: method,
      body: body,
      timestamp: DateTime.now(),
      headers: headers,
    );

    _queue.add(request);
    _persistQueue();

    logger.AppLogger.info(
      'Request queued: $method $endpoint (queue size: $queueLength)',
      tag: 'OfflineQueue',
    );

    return request.id;
  }

  /// Remove a request from the queue
  bool removeRequest(String requestId) {
    final initialLength = _queue.length;
    _queue.removeWhere((r) => r.id == requestId);
    if (_queue.length < initialLength) {
      _persistQueue();
      return true;
    }
    return false;
  }

  /// Clear all queued requests
  void clearQueue() {
    _queue.clear();
    _persistQueue();
    logger.AppLogger.info('Offline queue cleared', tag: 'OfflineQueue');
  }

  /// Process queued requests when online
  Future<List<QueuedRequestResult>> processQueue(
    Future<void> Function(QueuedRequest) requestExecutor,
  ) async {
    if (_isProcessing || _queue.isEmpty) {
      return [];
    }

    _isProcessing = true;
    final results = <QueuedRequestResult>[];

    try {
      // Process requests in order (FIFO)
      final toProcess = List<QueuedRequest>.from(_queue);
      _queue.clear();

      for (final request in toProcess) {
        final result = await _processRequest(request, requestExecutor);
        results.add(result);

        // Notify via stream
        if (!_resultController.isClosed) {
          _resultController.add(result);
        }

        // If failed and retries remain, re-queue
        if (!result.success && request.retryCount < config.maxRetries) {
          _queue.add(request.copyWith(
            retryCount: request.retryCount + 1,
          ));
          // Add delay before retry
          await Future.delayed(config.retryDelay);
        }
      }

      _persistQueue();
    } finally {
      _isProcessing = false;
    }

    return results;
  }

  Future<QueuedRequestResult> _processRequest(
    QueuedRequest request,
    Future<void> Function(QueuedRequest) executor,
  ) async {
    try {
      logger.AppLogger.info(
        'Processing queued request: ${request.method} ${request.endpoint} '
        '(attempt ${request.retryCount + 1})',
        tag: 'OfflineQueue',
      );

      await executor(request);

      return QueuedRequestResult(
        requestId: request.id,
        success: true,
      );
    } catch (error) {
      logger.AppLogger.error(
        'Failed to process queued request: ${request.method} ${request.endpoint}',
        error: error,
        stackTrace: StackTrace.current,
        tag: 'OfflineQueue',
      );

      return QueuedRequestResult(
        requestId: request.id,
        success: false,
        error: error.toString(),
      );
    }
  }

  /// Load persisted queue from storage
  Future<void> loadPersistedQueue() async {
    if (!config.persistQueue) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(config.queueStorageKey);

      if (queueJson != null) {
        final json = jsonDecode(queueJson) as List<dynamic>;
        _queue.clear();
        for (final item in json) {
          _queue.add(QueuedRequest.fromJson(item as Map<String, dynamic>));
        }
        logger.AppLogger.info(
          'Loaded $queueLength queued requests',
          tag: 'OfflineQueue',
        );
      }
    } catch (error) {
      logger.AppLogger.error(
        'Failed to load offline queue',
        error: error,
        tag: 'OfflineQueue',
      );
    }
  }

  /// Persist queue to storage
  void _persistQueue() {
    if (!config.persistQueue) return;

    SharedPreferences.getInstance().then((prefs) {
      final queueJson = jsonEncode(_queue.map((r) => r.toJson()).toList());
      prefs.setString(config.queueStorageKey, queueJson);
    }).catchError((error) {
      logger.AppLogger.error(
        'Failed to persist offline queue',
        error: error,
        tag: 'OfflineQueue',
      );
    });
  }

  /// Get request by ID
  QueuedRequest? getRequest(String requestId) {
    try {
      return _queue.firstWhere((r) => r.id == requestId);
    } catch (e) {
      logger.AppLogger.debug('[OfflineQueue] Request not found: $requestId, error: $e');
      return null;
    }
  }

  /// Get all requests for a specific endpoint
  List<QueuedRequest> getRequestsForEndpoint(String endpoint) {
    return _queue.where((r) => r.endpoint == endpoint).toList();
  }

  /// Count requests by method type
  Map<String, int> getRequestCountsByMethod() {
    final counts = <String, int>{};
    for (final request in _queue) {
      counts[request.method] = (counts[request.method] ?? 0) + 1;
    }
    return counts;
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_$queueLength';
  }

  /// Dispose resources
  void dispose() {
    _resultController.close();
  }
}
