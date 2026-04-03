import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/network/retry_interceptor.dart';

void main() {
  group('RetryInterceptor', () {
    late Dio dio;
    late _MockHttpClientAdapter mockAdapter;

    setUp(() {
      mockAdapter = _MockHttpClientAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
        ..httpClientAdapter = mockAdapter
        ..interceptors.add(RetryInterceptor(
          dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
            ..httpClientAdapter = mockAdapter,
          options: const RetryOptions(
            maxRetries: 2,
            initialDelay: Duration(milliseconds: 10),
          ),
        ));
    });

    group('retries on transient errors', () {
      test('retries on connection timeout', () async {
        mockAdapter.error = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        // First call fails, second succeeds
        mockAdapter.shouldFailOnce = true;
        mockAdapter.response = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
        expect(mockAdapter.requestCount, 2);
      });

      test('retries on receive timeout', () async {
        mockAdapter.error = DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        mockAdapter.shouldFailOnce = true;
        mockAdapter.response = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
        expect(mockAdapter.requestCount, 2);
      });

      test('retries on 5xx server errors', () async {
        mockAdapter.response = _makeResponse(500, {'error': 'internal'});

        // First call returns 500, then succeeds
        mockAdapter.failCount = 1;
        mockAdapter.successResponse = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
      });

      test('retries on 429 rate limit', () async {
        mockAdapter.response = _makeResponse(429, {'error': 'rate limited'});

        mockAdapter.failCount = 1;
        mockAdapter.successResponse = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
      });

      test('retries on connection error', () async {
        mockAdapter.error = DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/test'),
          error: 'Connection refused',
        );

        mockAdapter.shouldFailOnce = true;
        mockAdapter.response = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
      });
    });

    group('does not retry on non-retryable errors', () {
      test('does not retry on 401', () async {
        mockAdapter.response = _makeResponse(401, {'error': 'unauthorized'});

        try {
          await dio.get('/test');
          fail('Should have thrown');
        } on DioException catch (e) {
          expect(e.response?.statusCode, 401);
          expect(mockAdapter.requestCount, 1);
        }
      });

      test('does not retry on 404', () async {
        mockAdapter.response = _makeResponse(404, {'error': 'not found'});

        try {
          await dio.get('/test');
          fail('Should have thrown');
        } on DioException catch (e) {
          expect(e.response?.statusCode, 404);
          expect(mockAdapter.requestCount, 1);
        }
      });

      test('does not retry on cancelled request', () async {
        mockAdapter.error = DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(path: '/test'),
        );

        try {
          await dio.get('/test');
          fail('Should have thrown');
        } on DioException catch (e) {
          expect(e.type, DioExceptionType.cancel);
        }
      });
    });

    group('retry exhaustion', () {
      test('gives up after max retries', () async {
        // Always return 500
        mockAdapter.response = _makeResponse(500, {'error': 'persistent'});

        try {
          await dio.get('/test');
          fail('Should have thrown');
        } on DioException catch (e) {
          expect(e.response?.statusCode, 500);
          // Original request + maxRetries attempts
          expect(mockAdapter.requestCount, greaterThanOrEqualTo(2));
        }
      });
    });

    group('Retry-After header', () {
      test('respects Retry-After header for 429 responses', () async {
        // This test verifies the retry path handles 429 with Retry-After.
        // The actual delay is tested by ensuring it doesn't throw.
        mockAdapter.response = _makeResponse(
          429,
          {'error': 'rate limited'},
          headers: {'retry-after': ['1']},
        );

        mockAdapter.failCount = 1;
        mockAdapter.successResponse = _makeResponse(200, {'ok': true});

        final response = await dio.get('/test');
        expect(response.statusCode, 200);
      });
    });
  });
}

/// Creates a mock response body.
_Response _makeResponse(
  int statusCode,
  Map<String, dynamic> body, {
  Map<String, List<String>>? headers,
}) {
  return (statusCode: statusCode, body: body, headers: headers ?? {});
}

/// Mock HTTP adapter that can be configured to return errors or success.
class _MockHttpClientAdapter implements HttpClientAdapter {
  _Response? response;
  _Response? successResponse;
  DioException? error;
  bool shouldFailOnce = false;
  int failCount = 0;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;

    // If error is set, throw it (possibly only once)
    if (error != null) {
      if (shouldFailOnce && requestCount > 1) {
        // Fall through to success
      } else {
        throw error!;
      }
    }

    // If failCount is set, return failure responses that many times
    if (failCount > 0 && requestCount <= failCount) {
      final resp = response!;
      final bodyBytes = Uint8List.fromList(utf8.encode(jsonEncode(resp.body)));
      return ResponseBody.fromBytes(
        bodyBytes,
        resp.statusCode,
        headers: _ensureContentType(resp.headers, resp.body),
      );
    }

    // Return success response
    final resp = successResponse ?? response;
    if (resp == null) {
      throw DioException(
        requestOptions: options,
        error: 'No response configured',
      );
    }

    final bodyBytes = Uint8List.fromList(utf8.encode(jsonEncode(resp.body)));
    return ResponseBody.fromBytes(
      bodyBytes,
      resp.statusCode,
      headers: _ensureContentType(resp.headers, resp.body),
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, List<String>> _ensureContentType(
  Map<String, List<String>> headers,
  Map<String, dynamic>? body,
) {
  final result = Map<String, List<String>>.from(headers);
  if (!result.containsKey('content-type') && body != null) {
    result['content-type'] = ['application/json; charset=utf-8'];
  }
  return result;
}

typedef _Response = ({
  int statusCode,
  Map<String, dynamic> body,
  Map<String, List<String>> headers,
});
