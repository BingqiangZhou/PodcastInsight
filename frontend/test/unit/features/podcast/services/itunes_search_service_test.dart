import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';

void main() {
  group('ITunesSearchService', () {
    test('extracts show and episode ids from Apple podcast URL', () {
      final service = ITunesSearchService(dio: Dio());
      const url =
          'https://podcasts.apple.com/us/podcast/the-daily/id1200361736?i=1000749579753';

      expect(service.extractShowIdFromApplePodcastUrl(url), 1200361736);
      expect(service.extractEpisodeIdFromApplePodcastUrl(url), 1000749579753);
      expect(
        service.extractShowIdFromApplePodcastUrl('https://example.com'),
        isNull,
      );
    });

    test(
      'lookupPodcastEpisodes parses mixed lookup payload and caches response',
      () async {
        final adapter = _FakeHttpClientAdapter(
          responder: (_) => ResponseBody.fromString(
            jsonEncode(_lookupResponse()),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = ITunesSearchService(dio: dio);

        final lookupA = await service.lookupPodcastEpisodes(
          showId: 333,
          country: PodcastCountry.usa,
        );
        final lookupB = await service.lookupPodcastEpisodes(
          showId: 333,
          country: PodcastCountry.usa,
        );

        expect(adapter.requestCount, 1);
        expect(lookupA.showId, 333);
        expect(lookupA.collectionName, 'Top Episode Show');
        expect(lookupA.episodes.length, 2);
        expect(lookupA.episodes.first.trackId, 222);
        expect(
          lookupA.episodes.first.resolvedAudioUrl,
          'https://example.com/ep-222.mp3',
        );
        expect(lookupB.episodes.length, 2);
      },
    );

    test(
      'findEpisodeInLookup returns the requested episode by track id',
      () async {
        final adapter = _FakeHttpClientAdapter(
          responder: (_) => ResponseBody.fromString(
            jsonEncode(_lookupResponse()),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = ITunesSearchService(dio: dio);

        final episode = await service.findEpisodeInLookup(
          showId: 333,
          episodeTrackId: 33301,
          country: PodcastCountry.usa,
        );

        expect(episode, isNotNull);
        expect(episode!.trackName, 'Episode Two');
        expect(episode.resolvedAudioUrl, 'https://example.com/ep-33301.mp3');
      },
    );
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responder});

  final ResponseBody Function(RequestOptions options) responder;
  int requestCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    return responder(options);
  }
}

Map<String, dynamic> _lookupResponse() {
  return {
    'resultCount': 3,
    'results': [
      {
        'wrapperType': 'track',
        'kind': 'podcast',
        'trackId': 333,
        'collectionId': 333,
        'collectionName': 'Top Episode Show',
        'artistName': 'Episode Artist',
        'feedUrl': 'https://example.com/feed.xml',
      },
      {
        'wrapperType': 'podcastEpisode',
        'kind': 'podcast-episode',
        'trackId': 222,
        'collectionId': 333,
        'trackName': 'Episode One',
        'collectionName': 'Top Episode Show',
        'episodeUrl': 'https://example.com/ep-222.mp3',
        'trackTimeMillis': 180000,
      },
      {
        'wrapperType': 'podcastEpisode',
        'kind': 'podcast-episode',
        'trackId': 33301,
        'collectionId': 333,
        'trackName': 'Episode Two',
        'collectionName': 'Top Episode Show',
        'previewUrl': 'https://example.com/ep-33301.mp3',
        'trackTimeMillis': 90000,
      },
    ],
  };
}
