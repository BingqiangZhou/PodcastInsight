import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/offline/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OfflineQueueService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = OfflineQueueService(
      config: const OfflineQueueConfig(
        maxQueueSize: 5,
        maxRetries: 2,
        retryDelay: Duration(milliseconds: 10),
        persistQueue: false,
      ),
    );
  });

  group('addRequest', () {
    test('adds request and returns id', () async {
      final id = await service.addRequest(
        endpoint: '/api/test',
        method: 'POST',
        body: {'key': 'value'},
      );

      expect(id, isNotEmpty);
      expect(service.queueLength, 1);
      expect(service.queue.first.endpoint, '/api/test');
      expect(service.queue.first.method, 'POST');
      expect(service.queue.first.body, {'key': 'value'});
    });

    test('generates unique ids', () async {
      final id1 = await service.addRequest(endpoint: '/a', method: 'GET');
      final id2 = await service.addRequest(endpoint: '/b', method: 'GET');

      expect(id1, isNot(equals(id2)));
    });

    test('evicts oldest request when queue is full', () async {
      for (var i = 0; i < 5; i++) {
        await service.addRequest(endpoint: '/$i', method: 'GET');
      }
      expect(service.queueLength, 5);

      // Adding one more should evict the oldest
      await service.addRequest(endpoint: '/overflow', method: 'GET');
      expect(service.queueLength, 5);
      expect(service.queue.first.endpoint, '/1'); // /0 was evicted
      expect(service.queue.last.endpoint, '/overflow');
    });

    test('stores headers', () async {
      await service.addRequest(
        endpoint: '/api/test',
        method: 'POST',
        headers: {'Authorization': 'Bearer token'},
      );

      expect(service.queue.first.headers, {'Authorization': 'Bearer token'});
    });

    test('increments queue length', () async {
      expect(service.queueLength, 0);
      await service.addRequest(endpoint: '/a', method: 'GET');
      expect(service.queueLength, 1);
      await service.addRequest(endpoint: '/b', method: 'GET');
      expect(service.queueLength, 2);
    });
  });

  group('removeRequest', () {
    test('removes existing request and returns true', () async {
      final id = await service.addRequest(endpoint: '/test', method: 'GET');
      expect(service.queueLength, 1);

      final removed = service.removeRequest(id);
      expect(removed, isTrue);
      expect(service.queueLength, 0);
    });

    test('returns false for non-existent request', () async {
      final removed = service.removeRequest('nonexistent');
      expect(removed, isFalse);
    });
  });

  group('clearQueue', () {
    test('clears all requests', () async {
      await service.addRequest(endpoint: '/a', method: 'GET');
      await service.addRequest(endpoint: '/b', method: 'GET');
      expect(service.queueLength, 2);

      service.clearQueue();
      expect(service.queueLength, 0);
    });
  });

  group('getRequest', () {
    test('returns request by id', () async {
      final id = await service.addRequest(
        endpoint: '/test',
        method: 'POST',
        body: {'x': 1},
      );

      final request = service.getRequest(id);
      expect(request, isNotNull);
      expect(request!.endpoint, '/test');
      expect(request.method, 'POST');
      expect(request.body, {'x': 1});
    });

    test('returns null for non-existent id', () {
      expect(service.getRequest('nonexistent'), isNull);
    });
  });

  group('getRequestsForEndpoint', () {
    test('filters requests by endpoint', () async {
      await service.addRequest(endpoint: '/api/a', method: 'GET');
      await service.addRequest(endpoint: '/api/b', method: 'GET');
      await service.addRequest(endpoint: '/api/a', method: 'POST');

      final results = service.getRequestsForEndpoint('/api/a');
      expect(results.length, 2);
      expect(results.every((r) => r.endpoint == '/api/a'), isTrue);
    });

    test('returns empty list for no matches', () {
      final results = service.getRequestsForEndpoint('/nonexistent');
      expect(results, isEmpty);
    });
  });

  group('getRequestCountsByMethod', () {
    test('counts requests by method type', () async {
      await service.addRequest(endpoint: '/a', method: 'GET');
      await service.addRequest(endpoint: '/b', method: 'GET');
      await service.addRequest(endpoint: '/c', method: 'POST');

      final counts = service.getRequestCountsByMethod();
      expect(counts['GET'], 2);
      expect(counts['POST'], 1);
    });
  });

  group('processQueue', () {
    test('returns empty list when queue is empty', () async {
      final results = await service.processQueue((_) async {});
      expect(results, isEmpty);
    });

    test('processes all requests in FIFO order', () async {
      await service.addRequest(endpoint: '/first', method: 'GET');
      await service.addRequest(endpoint: '/second', method: 'GET');

      final processed = <String>[];
      final results = await service.processQueue((request) async {
        processed.add(request.endpoint);
      });

      expect(results.length, 2);
      expect(results.every((r) => r.success), isTrue);
      expect(processed, ['/first', '/second']);
      // Successful requests are not re-queued
      expect(service.queueLength, 0);
    });

    test('re-queues failed request up to max retries', () async {
      await service.addRequest(endpoint: '/fail', method: 'GET');
      // retryCount starts at 0, maxRetries is 2
      // After failure with retryCount=0, it re-queues with retryCount=1

      final results = await service.processQueue((_) async {
        throw Exception('Network error');
      });

      expect(results.length, 1);
      expect(results.first.success, isFalse);
      expect(results.first.error, isNotNull);
      // Re-queued with incremented retryCount
      expect(service.queueLength, 1);
      expect(service.queue.first.retryCount, 1);
    });

    test('drops request when max retries exceeded', () async {
      await service.addRequest(endpoint: '/fail', method: 'GET');

      // First process: fails, re-queues with retryCount=1
      await service.processQueue((_) async {
        throw Exception('Network error');
      });
      expect(service.queueLength, 1);
      expect(service.queue.first.retryCount, 1);

      // Second process: fails, re-queues with retryCount=2
      await service.processQueue((_) async {
        throw Exception('Network error');
      });
      expect(service.queueLength, 1);
      expect(service.queue.first.retryCount, 2);

      // Third process: fails, retryCount=2 >= maxRetries=2, NOT re-queued
      await service.processQueue((_) async {
        throw Exception('Network error');
      });
      expect(service.queueLength, 0);
    });

    test('handles partial success', () async {
      await service.addRequest(endpoint: '/ok', method: 'GET');
      await service.addRequest(endpoint: '/fail', method: 'GET');
      await service.addRequest(endpoint: '/ok2', method: 'GET');

      final results = await service.processQueue((request) async {
        if (request.endpoint == '/fail') {
          throw Exception('fail');
        }
      });

      expect(results.length, 3);
      expect(results[0].success, isTrue);
      expect(results[1].success, isFalse);
      expect(results[2].success, isTrue);
      // Only the failed one is re-queued
      expect(service.queueLength, 1);
    });

    test('sets isProcessing during execution', () async {
      await service.addRequest(endpoint: '/test', method: 'GET');
      expect(service.isProcessing, isFalse);

      // Use a completer to check isProcessing mid-flight
      final completer = Completer<void>();
      late bool processingDuringExecution;

      final processFuture = service.processQueue((_) async {
        processingDuringExecution = service.isProcessing;
        completer.complete();
      });

      await completer.future;
      expect(processingDuringExecution, isTrue);

      await processFuture;
      expect(service.isProcessing, isFalse);
    });

    test('concurrent process calls return empty', () async {
      await service.addRequest(endpoint: '/test', method: 'GET');

      // Start first process with a delay
      final slow = service.processQueue((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      // Second call should return empty since first is running
      final concurrent = await service.processQueue((_) async {});
      expect(concurrent, isEmpty);

      await slow;
    });
  });

  group('resultStream', () {
    test('emits results as they are processed', () async {
      await service.addRequest(endpoint: '/a', method: 'GET');
      await service.addRequest(endpoint: '/b', method: 'GET');

      final results = <QueuedRequestResult>[];
      final sub = service.resultStream.listen(results.add);

      await service.processQueue((_) async {});

      // Allow stream to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      expect(results.length, 2);
      expect(results.every((r) => r.success), isTrue);

      await sub.cancel();
    });
  });

  group('persistence', () {
    test('round-trips queue to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final persistService = OfflineQueueService(
        config: const OfflineQueueConfig(
          maxQueueSize: 100,
          maxRetries: 3,
          persistQueue: true,
          queueStorageKey: 'test_queue',
        ),
      );

      await persistService.addRequest(
        endpoint: '/api/test',
        method: 'POST',
        body: {'key': 'value'},
        headers: {'Auth': 'token'},
      );

      // Create new service and load
      final loadedService = OfflineQueueService(
        config: const OfflineQueueConfig(
          maxQueueSize: 100,
          maxRetries: 3,
          persistQueue: true,
          queueStorageKey: 'test_queue',
        ),
      );
      await loadedService.loadPersistedQueue();

      expect(loadedService.queueLength, 1);
      expect(loadedService.queue.first.endpoint, '/api/test');
      expect(loadedService.queue.first.method, 'POST');
      expect(loadedService.queue.first.body, {'key': 'value'});
      expect(loadedService.queue.first.headers, {'Auth': 'token'});
    });

    test('loads empty queue gracefully', () async {
      SharedPreferences.setMockInitialValues({});

      final s = OfflineQueueService(
        config: const OfflineQueueConfig(
          persistQueue: true,
          queueStorageKey: 'empty_queue',
        ),
      );
      await s.loadPersistedQueue();
      expect(s.queueLength, 0);
    });
  });

  group('dispose', () {
    test('closes result stream', () async {
      service.dispose();
      // Stream should be closed — adding listeners won't receive events
      await service.addRequest(endpoint: '/a', method: 'GET');
      await service.processQueue((_) async {});
      // No crash means dispose handled stream closure properly
    });
  });
}
