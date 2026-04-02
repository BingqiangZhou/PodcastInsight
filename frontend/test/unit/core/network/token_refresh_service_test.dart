import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_ai_assistant/core/network/token_refresh_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockAdapter implements HttpClientAdapter {
  ({int statusCode, dynamic body, Map<String, List<String>> headers})
      response = (
    statusCode: 200,
    body: <String, dynamic>{},
    headers: {},
  );
  DioException? error;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (error != null) throw error!;
    final bodyBytes = response.body != null
        ? Uint8List.fromList(utf8.encode(jsonEncode(response.body)))
        : Uint8List(0);
    final headers = Map<String, List<String>>.from(response.headers);
    if (!headers.containsKey('content-type') && response.body != null) {
      headers['content-type'] = ['application/json; charset=utf-8'];
    }
    return ResponseBody.fromBytes(bodyBytes, response.statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

({int statusCode, dynamic body, Map<String, List<String>> headers}) _resp({
  required int statusCode,
  dynamic body,
}) =>
    (statusCode: statusCode, body: body, headers: <String, List<String>>{});

void main() {
  late TokenRefreshService service;
  late Dio dio;
  late _MockAdapter adapter;
  late _MockSecureStorage storage;

  setUp(() {
    adapter = _MockAdapter();
    storage = _MockSecureStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = adapter;

    // Default stubs: read returns null, write/delete are no-ops
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    service = TokenRefreshService(dio: dio, secureStorage: storage);
  });

  void stubRefreshToken([String value = 'valid_refresh']) {
    when(() => storage.read(key: 'refresh_token'))
        .thenAnswer((_) async => value);
  }

  group('refreshToken', () {
    test('returns invalidSession when no refresh token stored', () async {
      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.invalidSession);
    });

    test('returns invalidSession when refresh token is empty', () async {
      stubRefreshToken('');
      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.invalidSession);
    });

    test('returns success and stores tokens on valid response', () async {
      stubRefreshToken();
      adapter.response = _resp(
        statusCode: 200,
        body: {
          'access_token': 'new_access_token_123',
          'refresh_token': 'new_refresh_token_456',
          'expires_in': 3600,
        },
      );

      final result = await service.refreshToken();

      expect(result.success, isTrue);
      expect(result.accessToken, 'new_access_token_123');
      expect(result.expiresInSeconds, 3600);
      verify(() => storage.write(key: 'access_token', value: 'new_access_token_123')).called(1);
      verify(() => storage.write(key: 'refresh_token', value: 'new_refresh_token_456')).called(1);
    });

    test('returns unknownFailure when response is missing access_token', () async {
      stubRefreshToken();
      adapter.response = _resp(statusCode: 200, body: {'refresh_token': 'new_refresh'});

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.unknownFailure);
    });

    test('returns unknownFailure when response body is not a Map', () async {
      stubRefreshToken();
      adapter.response = _resp(statusCode: 200, body: 'not a map');

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.unknownFailure);
    });

    test('returns invalidSession on 401 response', () async {
      stubRefreshToken();
      adapter.error = DioException(
        response: Response(statusCode: 401, requestOptions: RequestOptions(path: '')),
        requestOptions: RequestOptions(path: ''),
      );

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.invalidSession);
    });

    test('returns transientFailure on connection timeout', () async {
      stubRefreshToken();
      adapter.error = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: ''),
      );

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.transientFailure);
    });

    test('returns transientFailure on connection error', () async {
      stubRefreshToken();
      adapter.error = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: ''),
      );

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.transientFailure);
    });

    test('returns transientFailure on 5xx response', () async {
      stubRefreshToken();
      adapter.error = DioException(
        response: Response(statusCode: 503, requestOptions: RequestOptions(path: '')),
        requestOptions: RequestOptions(path: ''),
      );

      final result = await service.refreshToken();
      expect(result.success, isFalse);
      expect(result.reason, TokenRefreshFailureReason.transientFailure);
    });
  });

  group('clearTokens', () {
    test('deletes all token keys from secure storage', () async {
      await service.clearTokens();
      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
      verify(() => storage.delete(key: 'token_expiry')).called(1);
      verify(() => storage.delete(key: 'user_profile')).called(1);
    });
  });

  group('getAccessToken', () {
    test('returns stored access token', () async {
      when(() => storage.read(key: 'access_token')).thenAnswer((_) async => 'my_token');
      expect(await service.getAccessToken(), 'my_token');
    });

    test('returns null when no token stored', () async {
      expect(await service.getAccessToken(), isNull);
    });
  });

  group('classifyRefreshFailure', () {
    test('classifies 401 as invalidSession', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 401, requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.invalidSession,
      );
    });

    test('classifies 404 with invalid-session body as invalidSession', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 404, data: {'detail': 'Invalid session'}, requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.invalidSession,
      );
    });

    test('classifies 422 with refresh token message as invalidSession', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 422, data: {'message': 'refresh token expired'}, requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.invalidSession,
      );
    });

    test('classifies 404 without session keywords as unknownFailure', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 404, data: {'detail': 'Not here'}, requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.unknownFailure,
      );
    });

    test('classifies connection timeout as transientFailure', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.transientFailure,
      );
    });

    test('classifies 500 as transientFailure', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 500, requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.transientFailure,
      );
    });

    test('classifies string response body containing session keywords', () {
      expect(
        TokenRefreshService.classifyRefreshFailure(DioException(
          response: Response(statusCode: 400, data: 'Session has expired', requestOptions: RequestOptions(path: '')),
          requestOptions: RequestOptions(path: ''),
        )),
        TokenRefreshFailureReason.invalidSession,
      );
    });
  });

  group('shouldClearTokensForRefreshFailure', () {
    test('returns true for invalidSession', () {
      expect(TokenRefreshService.shouldClearTokensForRefreshFailure(TokenRefreshFailureReason.invalidSession), isTrue);
    });

    test('returns false for transientFailure', () {
      expect(TokenRefreshService.shouldClearTokensForRefreshFailure(TokenRefreshFailureReason.transientFailure), isFalse);
    });

    test('returns false for unknownFailure', () {
      expect(TokenRefreshService.shouldClearTokensForRefreshFailure(TokenRefreshFailureReason.unknownFailure), isFalse);
    });
  });
}
