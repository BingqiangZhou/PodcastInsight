import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_downloads_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';

// ---------------------------------------------------------------------------
// Fakes & helpers (must be top-level — Dart does not allow classes inside
// functions)
// ---------------------------------------------------------------------------

/// A fake [AudioDownloadService] backed by an in-memory database so the
/// constructor does not need a real file-system path.
class FakeAudioDownloadService extends AudioDownloadService {
  FakeAudioDownloadService() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<void> download({
    required int episodeId,
    required String audioUrl,
    String? title,
    String? subscriptionTitle,
    String? imageUrl,
    String? subscriptionImageUrl,
    int? subscriptionId,
    int? audioDuration,
    DateTime? publishedAt,
  }) async {}

  @override
  Future<void> delete(int episodeId) async {}

  @override
  Future<void> cancel(int episodeId) async {}

  @override
  void dispose() {}
}

DownloadTask createTestDownloadTask({
  int id = 1,
  int episodeId = 100,
  DownloadStatus status = DownloadStatus.completed,
  double progress = 1.0,
}) {
  return DownloadTask(
    id: id,
    episodeId: episodeId,
    audioUrl: 'https://example.com/audio.mp3',
    status: status,
    progress: progress,
    createdAt: DateTime(2026, 1, 15),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PodcastDownloadsPage', () {
    testWidgets('renders without crashing (smoke test)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          downloadsListProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => (
              active: <DownloadTask>[],
              failed: <DownloadTask>[],
              completed: <DownloadTask>[],
            ),
          ),
          downloadManagerProvider
              .overrideWithValue(FakeAudioDownloadService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastDownloadsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastDownloadsPage), findsOneWidget);
    });

    testWidgets('shows loading spinner when data is loading', (tester) async {
      final container = ProviderContainer(
        overrides: [
          // Never emit data => stays in loading state
          downloadsListProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => (
              active: <DownloadTask>[],
              failed: <DownloadTask>[],
              completed: <DownloadTask>[],
            ),
          ),
          downloadManagerProvider
              .overrideWithValue(FakeAudioDownloadService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastDownloadsPage(),
          ),
        ),
      );
      // Let async providers start resolving
      await tester.pump();

      // The loading state shows a CircularProgressIndicator.adaptive
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows empty state when no downloads exist', (tester) async {
      final container = ProviderContainer(
        overrides: [
          downloadsListProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => (
              active: <DownloadTask>[],
              failed: <DownloadTask>[],
              completed: <DownloadTask>[],
            ),
          ),
          downloadManagerProvider
              .overrideWithValue(FakeAudioDownloadService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastDownloadsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state shows the download icon and the subtitle text
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(
        find.text('Downloaded episodes will appear here'),
        findsOneWidget,
      );
    });

    testWidgets('shows download items when data is available', (tester) async {
      final tasks = [
        createTestDownloadTask(
          id: 1,
          episodeId: 101,
          status: DownloadStatus.completed,
        ),
        createTestDownloadTask(
          id: 2,
          episodeId: 102,
          status: DownloadStatus.downloading,
          progress: 0.5,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          downloadsListProvider.overrideWith(
            (ref) => Stream.value(tasks),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => (
              active: [tasks[1]],
              failed: <DownloadTask>[],
              completed: [tasks[0]],
            ),
          ),
          downloadManagerProvider
              .overrideWithValue(FakeAudioDownloadService()),
          // Override episode detail/cache providers so cards render without
          // hitting the real repository or database.
          episodeCacheMetaProvider.overrideWith(
            (ref, episodeId) async => null,
          ),
          episodeDetailProvider.overrideWith(
            (ref, episodeId) async => null,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastDownloadsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two download task cards should be rendered (one per task).
      // Each card is wrapped in an AdaptiveDismissible keyed by task ID.
      expect(find.byKey(ValueKey(tasks[0].id)), findsAtLeast(1));
      expect(find.byKey(ValueKey(tasks[1].id)), findsAtLeast(1));

      // The downloading task should show a LinearProgressIndicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // The completed task should show a download_done icon inside the
      // _StatusIcon widget (rendered because episodeCacheMetaProvider
      // returns null).
      expect(find.byIcon(Icons.download_done), findsOneWidget);
    });

    testWidgets('shows error state and retry button on error',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          downloadsListProvider.overrideWith(
            (ref) => Stream.error(Exception('DB error')),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => (
              active: <DownloadTask>[],
              failed: <DownloadTask>[],
              completed: <DownloadTask>[],
            ),
          ),
          downloadManagerProvider
              .overrideWithValue(FakeAudioDownloadService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastDownloadsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
