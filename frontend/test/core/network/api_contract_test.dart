import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/auth_request.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';

void main() {
  group('Frontend API contract', () {
    test('auth login posts to /auth/login with expected body', () async {
      final client = _RecordingDioClient();
      final datasource = AuthRemoteDatasourceImpl(client);

      await datasource.login(
        const LoginRequest(
          username: 'demo@example.com',
          password: 'Password123',
          rememberMe: true,
        ),
      );

      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/auth/login');
      expect(
        client.lastData,
        {
          'email_or_username': 'demo@example.com',
          'password': 'Password123',
          'remember_me': true,
        },
      );
    });

    test('subscription list uses /podcasts/subscriptions query contract', () async {
      final adapter = _RecordingHttpClientAdapter(
        responder: (options) => _responseBody(
          options,
          {
            'subscriptions': <Map<String, dynamic>>[],
            'total': 0,
            'page': 2,
            'size': 20,
            'pages': 0,
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;
      final service = PodcastApiService(dio);

      await service.listSubscriptions(2, 20, null, 'active');

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.uri.path, '/api/v1/podcasts/subscriptions');
      expect(adapter.lastRequest!.uri.queryParameters, {
        'page': '2',
        'size': '20',
        'status': 'active',
      });
    });

    test('feed endpoint uses /podcasts/episodes/feed query contract', () async {
      final adapter = _RecordingHttpClientAdapter(
        responder: (options) => _responseBody(
          options,
          {
            'items': <Map<String, dynamic>>[],
            'has_more': false,
            'next_page': null,
            'next_cursor': null,
            'total': 0,
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;
      final service = PodcastApiService(dio);

      await service.getPodcastFeed(1, 20, 'cursor-token');

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.uri.path, '/api/v1/podcasts/episodes/feed');
      expect(adapter.lastRequest!.uri.queryParameters, {
        'page': '1',
        'page_size': '20',
        'cursor': 'cursor-token',
      });
    });

    test('queue endpoint uses /podcasts/queue', () async {
      final adapter = _RecordingHttpClientAdapter(
        responder: (options) => _responseBody(
          options,
          const PodcastQueueModel().toJson(),
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;
      final service = PodcastApiService(dio);

      await service.getQueue();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.uri.path, '/api/v1/podcasts/queue');
    });

    test('transcription start uses /podcasts/episodes/{id}/transcribe body contract', () async {
      final adapter = _RecordingHttpClientAdapter(
        responder: (options) => _responseBody(
          options,
          {
            'id': 9,
            'episode_id': 42,
            'status': 'pending',
            'created_at': DateTime.utc(2026, 3, 10).toIso8601String(),
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;
      final service = PodcastApiService(dio);

      await service.startTranscription(
        42,
        const PodcastTranscriptionRequest(forceRegenerate: true),
      );

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.uri.path,
        '/api/v1/podcasts/episodes/42/transcribe',
      );
      expect(
        jsonDecode(adapter.lastRequestBody! as String),
        {
          'forceRegenerate': true,
          'chunkSizeMb': null,
          'transcriptionModel': null,
        },
      );
    });
  });
}

({int statusCode, Uint8List bodyBytes, Headers headers}) _responseBody(
  RequestOptions options,
  Map<String, dynamic> body,
) {
  return (
    statusCode: 200,
    bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    headers: Headers.fromMap({
      Headers.contentTypeHeader: [Headers.jsonContentType],
    }),
  );
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({required this.responder});

  final ({int statusCode, Uint8List bodyBytes, Headers headers}) Function(
    RequestOptions options,
  ) responder;

  RequestOptions? lastRequest;
  Object? lastRequestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      lastRequestBody = utf8.decode(bytes);
    }

    final response = responder(options);
    return ResponseBody.fromBytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers.map,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingDioClient extends DioClient {
  String? lastMethod;
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    bool invalidateCache = false,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: path, method: 'POST'),
      statusCode: 200,
      data: {
        'access_token': 'token',
        'refresh_token': 'refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
      },
    );
  }
}
