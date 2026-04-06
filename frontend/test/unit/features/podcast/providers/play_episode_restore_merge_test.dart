import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('mergeEpisodeForPlayback', () {
    test('uses backend playback fields as source of truth', () {
      final incoming = _buildIncomingEpisode(
        playbackPosition: 12,
        audioDuration: 1200,
        audioUrl: 'https://example.com/local.mp3',
        lastPlayedAt: DateTime(2026, 2, 10),
      );
      final latest = _buildDetailResponse(
        playbackPosition: 456,
        audioDuration: 3600,
        audioUrl: 'https://example.com/server.mp3',
        playbackRate: 1.5,
        isPlayed: true,
        lastPlayedAt: DateTime(2026, 2, 13),
        subscription: {'title': 'Server Show'},
      );

      final merged = mergeEpisodeForPlayback(incoming, latest);

      expect(merged.playbackPosition, 456);
      expect(merged.audioDuration, 3600);
      expect(merged.audioUrl, 'https://example.com/server.mp3');
      expect(merged.playbackRate, 1.5);
      expect(merged.isPlayed, isTrue);
      expect(merged.lastPlayedAt, DateTime(2026, 2, 13));
      expect(merged.subscriptionTitle, 'Server Show');
    });

    test('keeps local fallback fields when backend does not provide them', () {
      final incoming = _buildIncomingEpisode(
        playbackPosition: 99,
        audioDuration: 1800,
        subscriptionTitle: 'Local Subscription Title',
      );
      final latest = _buildDetailResponse(
        playbackPosition: null,
        audioDuration: null,
        subscription: null,
      );

      final merged = mergeEpisodeForPlayback(incoming, latest);

      expect(merged.playbackPosition, 99);
      expect(merged.audioDuration, 1800);
      expect(merged.subscriptionTitle, 'Local Subscription Title');
    });
  });

  group('resolveEpisodeForPlayback', () {
    test('falls back to original episode when fetch fails', () async {
      final incoming = _buildIncomingEpisode();

      final resolved = await resolveEpisodeForPlayback(incoming, () async {
        throw Exception('network failure');
      });

      expect(identical(resolved, incoming), isTrue);
    });

    test('returns merged episode when fetch succeeds', () async {
      final incoming = _buildIncomingEpisode(playbackPosition: 12);
      final detail = _buildDetailResponse(playbackPosition: 345);

      final resolved = await resolveEpisodeForPlayback(incoming, () async {
        return detail;
      });

      expect(resolved.playbackPosition, 345);
    });
  });
}

PodcastEpisodeModel _buildIncomingEpisode({
  int? playbackPosition,
  int? audioDuration,
  String audioUrl = 'https://example.com/default.mp3',
  double playbackRate = 1.0,
  bool isPlayed = false,
  DateTime? lastPlayedAt,
  String? subscriptionTitle = 'Incoming Show',
}) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 101,
    subscriptionTitle: subscriptionTitle,
    title: 'Incoming Episode',
    description: 'Incoming description',
    audioUrl: audioUrl,
    audioDuration: audioDuration,
    publishedAt: DateTime(2026, 2),
    playbackPosition: playbackPosition,
    playbackRate: playbackRate,
    isPlayed: isPlayed,
    lastPlayedAt: lastPlayedAt,
    createdAt: DateTime(2026, 2),
  );
}

PodcastEpisodeModel _buildDetailResponse({
  int? playbackPosition = 120,
  int? audioDuration = 2400,
  String audioUrl = 'https://example.com/detail.mp3',
  double playbackRate = 1.25,
  bool isPlayed = false,
  DateTime? lastPlayedAt,
  Map<String, dynamic>? subscription = const {'title': 'Detail Show'},
}) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 101,
    title: 'Detail Episode',
    audioUrl: audioUrl,
    audioDuration: audioDuration,
    publishedAt: DateTime(2026, 2, 2),
    playbackPosition: playbackPosition,
    playbackRate: playbackRate,
    isPlayed: isPlayed,
    lastPlayedAt: lastPlayedAt,
    createdAt: DateTime(2026, 2, 2),
    subscription: subscription,
  );
}
