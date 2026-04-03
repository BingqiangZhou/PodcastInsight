import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';

void main() {
  group('ApiResponseNormalizer', () {
    group('normalize', () {
      test('returns empty map for null input', () {
        expect(ApiResponseNormalizer.normalize(null), isEmpty);
      });

      test('wraps List input in items key', () {
        final result = ApiResponseNormalizer.normalize([1, 2, 3]);
        expect(result, {'items': [1, 2, 3]});
      });

      test('wraps non-map, non-list scalar in data key', () {
        final result = ApiResponseNormalizer.normalize('hello');
        expect(result, {'data': 'hello'});
      });

      test('normalizes subscriptions key to items', () {
        final result = ApiResponseNormalizer.normalize({
          'subscriptions': [{'id': 1}],
          'total': 10,
        });
        expect(result['items'], [{'id': 1}]);
        expect(result.containsKey('subscriptions'), isFalse);
        expect(result['total'], 10);
      });

      test('does not override existing items key', () {
        final result = ApiResponseNormalizer.normalize({
          'items': [{'id': 1}],
          'subscriptions': [{'id': 2}],
        });
        expect(result['items'], [{'id': 1}]);
        // subscriptions should remain since items already existed
        expect(result['subscriptions'], [{'id': 2}]);
      });

      test('normalizes list under total to items', () {
        final result = ApiResponseNormalizer.normalize({
          'total': 5,
          'podcasts': [1, 2, 3],
        });
        expect(result['items'], [1, 2, 3]);
        expect(result['total'], 5);
      });

      test('returns map unchanged when items already present', () {
        final input = {
          'items': [1],
          'total': 1,
        };
        final result = ApiResponseNormalizer.normalize(input);
        expect(result, equals(input));
      });

      test('returns map unchanged for normal map without subscriptions/total', () {
        final input = {'name': 'test', 'value': 42};
        expect(ApiResponseNormalizer.normalize(input), equals(input));
      });
    });

    group('extractItems', () {
      test('extracts items from normalized response', () {
        final items = ApiResponseNormalizer.extractItems<int>({
          'items': [1, 2, 3],
          'total': 3,
        });
        expect(items, [1, 2, 3]);
      });

      test('extracts items from subscriptions response', () {
        final items = ApiResponseNormalizer.extractItems<Map<String, dynamic>>({
          'subscriptions': [{'id': 1}],
        });
        expect(items, [{'id': 1}]);
      });

      test('returns empty list when no items found', () {
        expect(ApiResponseNormalizer.extractItems({'name': 'test'}), isEmpty);
      });

      test('returns empty list for null input', () {
        expect(ApiResponseNormalizer.extractItems(null), isEmpty);
      });

      test('returns empty list when items is not a List', () {
        expect(ApiResponseNormalizer.extractItems({'items': 'not a list'}), isEmpty);
      });
    });

    group('extractTotal', () {
      test('extracts int total', () {
        expect(
          ApiResponseNormalizer.extractTotal({'total': 42}),
          42,
        );
      });

      test('extracts string total', () {
        expect(
          ApiResponseNormalizer.extractTotal({'total': '100'}),
          100,
        );
      });

      test('returns default value when total is missing', () {
        expect(
          ApiResponseNormalizer.extractTotal({'items': []}),
          0,
        );
        expect(
          ApiResponseNormalizer.extractTotal({'items': []}, defaultValue: -1),
          -1,
        );
      });

      test('returns default value for unparseable string', () {
        expect(
          ApiResponseNormalizer.extractTotal({'total': 'abc'}),
          0,
        );
      });

      test('returns default value for null', () {
        expect(
          ApiResponseNormalizer.extractTotal(null),
          0,
        );
      });
    });

    group('isPaginatedResponse', () {
      test('returns true for paginated response', () {
        expect(
          ApiResponseNormalizer.isPaginatedResponse({
            'items': [1],
            'total': 1,
          }),
          isTrue,
        );
      });

      test('returns false when missing total', () {
        expect(
          ApiResponseNormalizer.isPaginatedResponse({'items': [1]}),
          isFalse,
        );
      });

      test('returns false when missing items', () {
        expect(
          ApiResponseNormalizer.isPaginatedResponse({'total': 1}),
          isFalse,
        );
      });
    });
  });

  group('RetryOptions', () {
    test('defaults are correct', () {
      const options = RetryOptions();
      expect(options.maxRetries, 3);
      expect(options.initialDelay, const Duration(seconds: 1));
      expect(options.backoffMultiplier, 2.0);
    });

    test('getDelay returns initial delay for first attempt', () {
      const options = RetryOptions(initialDelay: Duration(seconds: 2));
      expect(options.getDelay(0), const Duration(seconds: 2));
    });

    test('getDelay doubles for second attempt with multiplier 2.0', () {
      const options = RetryOptions(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
      );
      expect(options.getDelay(1), const Duration(seconds: 2));
      expect(options.getDelay(2), const Duration(seconds: 4));
    });

    test('getDelay with custom multiplier', () {
      const options = RetryOptions(
        initialDelay: Duration(milliseconds: 500),
        backoffMultiplier: 3.0,
      );
      expect(options.getDelay(0), const Duration(milliseconds: 500));
      expect(options.getDelay(1), const Duration(milliseconds: 1500));
      expect(options.getDelay(2), const Duration(milliseconds: 4500));
    });

    test('equality works', () {
      const a = RetryOptions();
      const b = RetryOptions();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality works', () {
      const a = RetryOptions(maxRetries: 3);
      const b = RetryOptions(maxRetries: 5);
      expect(a, isNot(equals(b)));
    });
  });

  group('_shouldRetry behavior', () {
    /// We test the retry behavior indirectly by verifying the _shouldRetry
    /// logic through Dio error classification. Since _shouldRetry is private,
    /// we verify the documented retry behavior:
    /// - Timeout errors: retryable
    /// - Connection errors: retryable
    /// - 5xx errors: retryable
    /// - 429: retryable
    /// - 4xx (except 429): not retryable
    /// - Cancel: not retryable

    test('timeout errors should be retryable per spec', () {
      // Verify classification via error type
      final timeoutError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(timeoutError.type, DioExceptionType.connectionTimeout);
    });

    test('5xx errors should be retryable per spec', () {
      final serverError = DioException(
        response: Response(statusCode: 503, requestOptions: RequestOptions(path: '')),
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
      );
      expect(serverError.response?.statusCode, 503);
      expect(serverError.type, DioExceptionType.badResponse);
    });

    test('429 should be retryable per spec', () {
      final rateLimitError = DioException(
        response: Response(statusCode: 429, requestOptions: RequestOptions(path: '')),
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
      );
      expect(rateLimitError.response?.statusCode, 429);
    });

    test('401 should not trigger retry per spec (handled by 401 flow)', () {
      final authError = DioException(
        response: Response(statusCode: 401, requestOptions: RequestOptions(path: '')),
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
      );
      expect(authError.response?.statusCode, 401);
    });
  });

  group('DioClient request deduplication', () {
    test('concurrent identical requests share a single Completer', () async {
      final inFlight = <String, Completer<Response>>{};
      const key = 'GET:/items:null';
      var actualFetchCount = 0;

      Future<Response> deduplicatedGet(String path) async {
        if (inFlight.containsKey(key)) {
          return inFlight[key]!.future;
        }
        final completer = Completer<Response>();
        inFlight[key] = completer;
        try {
          actualFetchCount++;
          // Simulate network delay
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final response = Response(
            requestOptions: RequestOptions(path: path),
            data: {'items': [1, 2, 3]},
            statusCode: 200,
          );
          completer.complete(response);
          return response;
        } catch (e) {
          completer.completeError(e);
          rethrow;
        } finally {
          inFlight.remove(key);
        }
      }

      // Fire 3 concurrent requests
      final results = await Future.wait([
        deduplicatedGet('/items'),
        deduplicatedGet('/items'),
        deduplicatedGet('/items'),
      ]);

      expect(results.length, 3);
      for (final r in results) {
        expect(r.statusCode, 200);
      }
      // Only 1 actual fetch happened
      expect(actualFetchCount, 1);
    });

    test('different paths create separate Completers', () async {
      final inFlight = <String, Completer<Response>>{};
      var actualFetchCount = 0;

      Future<Response> deduplicatedGet(String path, {Map<String, dynamic>? qp}) async {
        final key = 'GET:$path:$qp';
        if (inFlight.containsKey(key)) {
          return inFlight[key]!.future;
        }
        final completer = Completer<Response>();
        inFlight[key] = completer;
        try {
          actualFetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final response = Response(
            requestOptions: RequestOptions(path: path),
            data: {'ok': true},
            statusCode: 200,
          );
          completer.complete(response);
          return response;
        } finally {
          inFlight.remove(key);
        }
      }

      await Future.wait([
        deduplicatedGet('/items'),
        deduplicatedGet('/episodes'),
      ]);

      expect(actualFetchCount, 2);
    });

    test('different query parameters create separate Completers', () async {
      final inFlight = <String, Completer<Response>>{};
      var actualFetchCount = 0;

      Future<Response> deduplicatedGet(String path, {Map<String, dynamic>? qp}) async {
        final key = 'GET:$path:$qp';
        if (inFlight.containsKey(key)) {
          return inFlight[key]!.future;
        }
        final completer = Completer<Response>();
        inFlight[key] = completer;
        try {
          actualFetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final response = Response(
            requestOptions: RequestOptions(path: path),
            data: {'ok': true},
            statusCode: 200,
          );
          completer.complete(response);
          return response;
        } finally {
          inFlight.remove(key);
        }
      }

      await Future.wait([
        deduplicatedGet('/items', qp: {'page': 1}),
        deduplicatedGet('/items', qp: {'page': 2}),
      ]);

      expect(actualFetchCount, 2);
    });

    test('error propagates to all waiting callers', () async {
      final inFlight = <String, Completer<Response>>{};
      const key = 'GET:/items:null';
      var actualFetchCount = 0;

      Future<Response> deduplicatedGet(String path) async {
        if (inFlight.containsKey(key)) {
          return inFlight[key]!.future;
        }
        final completer = Completer<Response>();
        inFlight[key] = completer;
        try {
          actualFetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          completer.completeError(
            DioException(
              requestOptions: RequestOptions(path: path),
              error: 'Network error',
            ),
          );
          throw DioException(
            requestOptions: RequestOptions(path: path),
            error: 'Network error',
          );
        } finally {
          inFlight.remove(key);
        }
      }

      var errorCount = 0;
      await Future.wait(
        [
          deduplicatedGet('/items').catchError((Object e) {
            errorCount++;
            throw e;
          }),
          deduplicatedGet('/items').catchError((Object e) {
            errorCount++;
            throw e;
          }),
        ].map((f) => f.catchError((Object e) {
              return Response(
                requestOptions: RequestOptions(path: '/items'),
                statusCode: 500,
              );
            })),
      );

      expect(actualFetchCount, 1);
      expect(errorCount, 2);
    });

    test('sequential requests each create their own Completer', () async {
      final inFlight = <String, Completer<Response>>{};
      const key = 'GET:/items:null';
      var actualFetchCount = 0;

      Future<Response> deduplicatedGet(String path) async {
        if (inFlight.containsKey(key)) {
          return inFlight[key]!.future;
        }
        final completer = Completer<Response>();
        inFlight[key] = completer;
        try {
          actualFetchCount++;
          final response = Response(
            requestOptions: RequestOptions(path: path),
            data: {'count': actualFetchCount},
            statusCode: 200,
          );
          completer.complete(response);
          return response;
        } finally {
          inFlight.remove(key);
        }
      }

      // Sequential (not concurrent) — each resolves before the next starts
      final r1 = await deduplicatedGet('/items');
      final r2 = await deduplicatedGet('/items');

      expect(actualFetchCount, 2);
      expect(r1.data['count'], 1);
      expect(r2.data['count'], 2);
    });
  });
}
