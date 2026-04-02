import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/ai_summary_control_widget.dart';

void main() {
  testWidgets(
    'summary tab hides custom prompt input and never sends custom_prompt',
    (tester) async {
      final repository = _FakeSummaryRepository();

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(repository.customPromptValues, [null]);
      expect(repository.summaryModelValues, ['default-model']);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(repository.customPromptValues, [null, null]);
      expect(repository.summaryModelValues, ['default-model', 'default-model']);
    },
  );

  testWidgets('regenerate shows task list notice after request is accepted', (
    tester,
  ) async {
    final repository = _FakeSummaryRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        summaryOverride: summaryProvider(
          2001,
        ).overrideWith(() => _SummaryWithContentNotifier()),
      ),
    );
    await tester.pumpAndSettle();

    final regenerateButton = find.byType(OutlinedButton);
    expect(regenerateButton, findsOneWidget);
    await tester.tap(regenerateButton);
    await tester.pump();

    expect(find.text('Summary task added to task list'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

Widget _buildTestApp(
  _FakeSummaryRepository repository, {
  Override? summaryOverride,
}) {
  return ProviderScope(
    overrides: [
      podcastRepositoryProvider.overrideWithValue(repository),
      if (summaryOverride != null) summaryOverride,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const Scaffold(
        body: AISummaryControlWidget(episodeId: 2001, hasTranscript: true),
      ),
    ),
  );
}

class _FakeSummaryRepository extends PodcastRepository {
  _FakeSummaryRepository() : super(PodcastApiService(Dio()));

  final List<String?> customPromptValues = [];
  final List<String?> summaryModelValues = [];

  @override
  Future<List<SummaryModelInfo>> getSummaryModels() async {
    return const [
      SummaryModelInfo(
        id: 1,
        name: 'default-model',
        displayName: 'Default Model',
        provider: 'openai',
        modelId: 'gpt-4o-mini',
        isDefault: true,
      ),
      SummaryModelInfo(
        id: 2,
        name: 'backup-model',
        displayName: 'Backup Model',
        provider: 'openai',
        modelId: 'gpt-4o',
        isDefault: false,
      ),
    ];
  }

  @override
  Future<PodcastSummaryStartResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) async {
    customPromptValues.add(customPrompt);
    summaryModelValues.add(summaryModel);

    return PodcastSummaryStartResponse(
      episodeId: episodeId,
      summaryStatus: 'summary_generating',
      acceptedAt: DateTime.utc(2026, 3, 12),
      messageEn: 'accepted',
      messageZh: 'accepted',
    );
  }

  @override
  Future<PodcastEpisodeDetailResponse> getEpisode(int id) async {
    return PodcastEpisodeDetailResponse(
      id: id,
      subscriptionId: 1,
      title: 'Episode',
      description: 'Description',
      audioUrl: 'https://example.com/audio.mp3',
      publishedAt: DateTime.utc(2026, 3, 12),
      createdAt: DateTime.utc(2026, 3, 12),
      aiSummary: 'Persisted summary',
      summaryStatus: 'summarized',
    );
  }
}

class _SummaryWithContentNotifier extends SummaryNotifier {
  _SummaryWithContentNotifier() : super(2001);

  @override
  SummaryState build() {
    return const SummaryState(summary: 'Persisted summary');
  }
}
