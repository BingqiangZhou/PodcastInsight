import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';

void main() {
  group('ApplePodcastRssService', () {
    test('parses top shows json response', () async {
      final adapter = _FakeHttpClientAdapter(
        responder: (_) => ResponseBody.fromString(
          jsonEncode(_sampleResponse('Top Shows', 'podcasts')),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ApplePodcastRssService(dio: dio);

      final result = await service.fetchTopShows(
        country: PodcastCountry.usa,
        limit: 10,
      );

      expect(result.feed.title, 'Top Shows');
      expect(result.feed.results.length, 2);
      expect(result.feed.results.first.name, 'Show One');
      expect(result.feed.results.first.kind, 'podcasts');
    });

    test('uses cache for repeated request key', () async {
      final adapter = _FakeHttpClientAdapter(
        responder: (_) => ResponseBody.fromString(
          jsonEncode(_sampleResponse('Top Episodes', 'podcast-episodes')),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ApplePodcastRssService(dio: dio);

      await service.fetchTopEpisodes(country: PodcastCountry.usa, limit: 10);
      await service.fetchTopEpisodes(country: PodcastCountry.usa, limit: 10);

      expect(adapter.requestCount, 1);
    });

    test('throws when response body is invalid json for json format', () async {
      final adapter = _FakeHttpClientAdapter(
        responder: (_) => ResponseBody.fromString(
          '<xml></xml>',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ApplePodcastRssService(dio: dio);

      expect(
        () => service.fetchTopShows(
          country: PodcastCountry.usa,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('normalizes limit above 100 to 100', () async {
      final adapter = _FakeHttpClientAdapter(
        responder: (_) => ResponseBody.fromString(
          jsonEncode(_sampleResponse('Top Shows', 'podcasts')),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ApplePodcastRssService(dio: dio);

      await service.fetchTopShows(country: PodcastCountry.usa, limit: 999);

      expect(adapter.lastRequestOptions, isNotNull);
      expect(
        adapter.lastRequestOptions!.uri.toString(),
        contains('/top/100/podcasts.json'),
      );
    });
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responder});

  final ResponseBody Function(RequestOptions options) responder;
  int requestCount = 0;
  RequestOptions? lastRequestOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    lastRequestOptions = options;
    return responder(options);
  }
}

Map<String, dynamic> _sampleResponse(String title, String kind) {
  return {
    'feed': {
      'title': title,
      'country': 'us',
      'updated': '2026-02-14T00:00:00Z',
      'results': [
        {
          'artistName': 'Author A',
          'id': '1001',
          'name': 'Show One',
          'kind': kind,
          'artworkUrl100': 'https://example.com/1.png',
          'genres': [
            {'name': 'Technology'},
          ],
          'url': 'https://podcasts.apple.com/us/podcast/id1001',
        },
        {
          'artistName': 'Author B',
          'id': '1002',
          'name': 'Show Two',
          'kind': kind,
          'artworkUrl100': 'https://example.com/2.png',
          'genres': [
            {'name': 'News'},
          ],
          'url': 'https://podcasts.apple.com/us/podcast/id1002',
        },
      ],
    },
  };
}
