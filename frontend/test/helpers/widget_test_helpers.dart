import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/category_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';

/// Wraps a widget in MaterialApp and ProviderScope for testing
Widget createTestWidget({
  required Widget child,
  ProviderContainer? container,
  ThemeData? theme,
  Map<String, Widget Function(BuildContext)> routes = const {},
  GoRouter? router,
}) {
  return UncontrolledProviderScope(
    container: container ?? ProviderContainer(),
    child: MaterialApp.router(
      theme: theme,
      routerConfig: router ?? GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => child,
          ),
        ],
      ),
    ),
  );
}

/// Helper to wait for async operations to complete
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// Helper to verify a toast/snackbar is shown
void expectSnackbar(String message) {
  expect(find.byKey(Key('snackbar_$message')), findsOneWidget);
}

/// Helper to create mock data for testing
T createMockData<T>(T Function(int) creator, int count) {
  throw UnimplementedError('Create mock data implementation needed');
}

/// Test helper for podcast subscription data
PodcastSubscriptionModel createMockSubscription({
  int id = 1,
  String title = 'Test Podcast',
  String? description,
  String status = 'active',
  int episodeCount = 10,
  int unplayedCount = 5,
  DateTime? createdAt,
  List<Category>? categories,
}) {
  return PodcastSubscriptionModel(
    id: id,
    userId: 1,
    title: title,
    description: description,
    sourceUrl: 'https://example.com/podcast$id.xml',
    status: status,
    fetchInterval: 3600,
    episodeCount: episodeCount,
    unplayedCount: unplayedCount,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 30)),
    categories: categories,
  );
}

/// Test helper for podcast episode data
PodcastEpisodeModel createMockEpisode({
  int id = 1,
  int subscriptionId = 1,
  String title = 'Test Episode',
  String? description,
  String audioUrl = 'https://example.com/episode1.mp3',
  int? playbackPosition,
  bool isPlayed = false,
}) {
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: subscriptionId,
    title: title,
    description: description,
    audioUrl: audioUrl,
    audioDuration: 1800, // 30 minutes
    publishedAt: DateTime.now().subtract(const Duration(days: 1)),
    playbackPosition: playbackPosition,
    isPlayed: isPlayed,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  );
}