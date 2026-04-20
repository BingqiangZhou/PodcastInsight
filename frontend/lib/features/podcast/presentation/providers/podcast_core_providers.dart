import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_handler.dart';

final podcastApiServiceProvider = Provider<PodcastApiService>((ref) {
  final dio = ref.read(dioClientProvider).dio;
  return PodcastApiService(dio);
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  final apiService = ref.read(podcastApiServiceProvider);
  return PodcastRepository(apiService);
});

/// Provides the singleton [PodcastAudioHandler] managed by Riverpod.
///
/// The handler is created once and shared across all features that need
/// audio playback. It is disposed when the provider scope is disposed.
final audioHandlerProvider = Provider<PodcastAudioHandler>((ref) {
  final handler = PodcastAudioHandler();
  ref.onDispose(handler.stopService);
  return handler;
});
