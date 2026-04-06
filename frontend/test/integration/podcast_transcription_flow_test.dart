import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';

import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription_status_widget.dart';

/// End-to-End tests for Podcast Transcription Flow
/// These tests verify the complete user experience through the transcription lifecycle
void main() {
  group('Podcast Transcription Flow - End to End Tests', () {
    testWidgets(
      'User Journey: Start transcription and see progress through all stages',
      (tester) async {
        // Stage 1: User sees "Start Transcription" button
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
              ),
            ),
          ),
        );

        // Verify initial state
        expect(
          find.text('Start Transcription'),
          findsNWidgets(2),
        ); // Title + Button
        expect(
          find.text(
            'Generate full text transcription for this episode\nSupports multi-language and high accuracy',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.transcribe), findsOneWidget);

        // Stage 2: User starts transcription, enters pending state
        final pendingTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: pendingTranscription,
              ),
            ),
          ),
        );

        // Verify pending state
        expect(find.text('Pending'), findsOneWidget);
        expect(
          find.text(
            'Transcription task has been queued\nProcessing will start shortly',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.pending_actions), findsOneWidget);

        // Stage 3: Transcription progresses through downloading
        final downloadingTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'downloading',
          processingProgress: 15,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: downloadingTranscription,
              ),
            ),
          ),
        );

        // Verify downloading state
        expect(find.text('15%'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Download'), findsOneWidget);

        // Stage 4: Transcription progresses through converting
        final convertingTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'converting',
          processingProgress: 30,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: convertingTranscription,
              ),
            ),
          ),
        );

        // Verify converting state
        expect(find.text('30%'), findsOneWidget);
        expect(find.text('Convert'), findsOneWidget);

        // Stage 5: Transcription progresses through transcribing (main stage)
        final transcribingTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'transcribing',
          processingProgress: 65,
          wordCount: 1200,
          debugMessage: 'Processing chunk 5/10',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: transcribingTranscription,
              ),
            ),
          ),
        );

        // Verify transcribing state
        expect(find.text('65%'), findsOneWidget);
        expect(find.text('Transcribe'), findsOneWidget);
        expect(find.text('Processing chunk 5/10'), findsOneWidget);

        // Stage 6: Transcription completes
        final completedTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'completed',
          transcriptContent: 'Full transcript content...',
          wordCount: 3500,
          durationSeconds: 1200,
          processingProgress: 100,
          completedAt: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: completedTranscription,
              ),
            ),
          ),
        );

        // Verify completed state
        expect(find.text('Transcription Complete'), findsOneWidget);
        expect(
          find.text(
            'Transcript generated successfully\nYou can now read and search the content',
          ),
          findsOneWidget,
        );
        expect(find.text('3.5K'), findsOneWidget);
        expect(find.text('20:00'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('View Transcript'), findsOneWidget);
      },
    );

    testWidgets(
      'Error Journey: Transcription fails with network error and user retries',
      (tester) async {
        // Stage 1: Transcription starts normally
        final processingTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'downloading',
          processingProgress: 10,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: processingTranscription,
              ),
            ),
          ),
        );

        expect(find.text('10%'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Stage 2: Network error occurs
        final failedTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'failed',
          errorMessage: 'Network connection timeout',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: failedTranscription,
              ),
            ),
          ),
        );

        // Verify error state with friendly message
        expect(find.text('Transcription Failed'), findsOneWidget);
        expect(find.text('Network connection failed'), findsOneWidget);
        expect(
          find.textContaining('Check your internet connection'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Verify retry and clear options
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);
      },
    );

    testWidgets('User Journey: Server restart during transcription', (
      tester,
    ) async {
      // Transcription was in progress when server restarted
      final failedTranscription = PodcastTranscriptionResponse(
        id: 1,
        episodeId: 1,
        status: 'failed',
        errorMessage: 'Task interrupted by server restart',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptionStatusWidget(
              episodeId: 1,
              transcription: failedTranscription,
            ),
          ),
        ),
      );

      // Verify server restart specific message
      expect(find.text('Service was restarted'), findsOneWidget);
      expect(
        find.text('Click Retry to start a new transcription task'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets(
      'User Journey: Completed transcription allows viewing and deleting',
      (tester) async {
        final completedTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'completed',
          transcriptContent: 'Sample transcript content',
          wordCount: 5000,
          durationSeconds: 1800,
          processingProgress: 100,
          completedAt: DateTime(2024, 12, 22, 14, 30),
          createdAt: DateTime(2024, 12, 22, 14, 10),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: completedTranscription,
              ),
            ),
          ),
        );

        // Verify completion state with all actions available
        expect(find.text('Transcription Complete'), findsOneWidget);
        expect(find.text('5.0K'), findsOneWidget);
        expect(find.text('30:00'), findsOneWidget);
        expect(find.text('Completed at: 2024-12-22 14:30'), findsOneWidget);

        // Verify action buttons
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('View Transcript'), findsOneWidget);
      },
    );

    testWidgets(
      'User Journey: Transcription with missing stats still shows completion',
      (tester) async {
        // Some transcriptions may not have all stats populated
        final completedTranscription = PodcastTranscriptionResponse(
          id: 1,
          episodeId: 1,
          status: 'completed',
          transcriptContent: 'Transcript',
          processingProgress: 100,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptionStatusWidget(
                episodeId: 1,
                transcription: completedTranscription,
              ),
            ),
          ),
        );

        // Should still show completed state with default values
        expect(find.text('Transcription Complete'), findsOneWidget);
        expect(find.text('0.0K'), findsOneWidget);
        expect(find.text('00:00'), findsOneWidget);
        expect(find.text('--'), findsOneWidget); // No accuracy data
      },
    );

    testWidgets(
      'Visual Journey: Progress indicators update correctly through stages',
      (tester) async {
        final stages = [
          {'status': 'downloading', 'progress': 10.0, 'icon': 'Download'},
          {'status': 'converting', 'progress': 30.0, 'icon': 'Convert'},
          {
            'status': 'transcribing',
            'progress': 50.0,
            'icon': 'Split',
          }, // Early transcribing shows Split
          {'status': 'transcribing', 'progress': 70.0, 'icon': 'Transcribe'},
          {'status': 'processing', 'progress': 98.0, 'icon': 'Merge'},
        ];

        for (final stage in stages) {
          final transcription = PodcastTranscriptionResponse(
            id: 1,
            episodeId: 1,
            status: stage['status']! as String,
            processingProgress: stage['progress']! as double,
            createdAt: DateTime.now(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TranscriptionStatusWidget(
                  episodeId: 1,
                  transcription: transcription,
                ),
              ),
            ),
          );

          // Verify progress percentage
          final progressText =
              '${(stage['progress']! as double).toStringAsFixed(0)}%';
          expect(find.text(progressText), findsOneWidget);

          // Verify step indicators exist
          expect(find.text('Download'), findsOneWidget);
          expect(find.text('Convert'), findsOneWidget);
          expect(find.text('Split'), findsOneWidget);
          expect(find.text('Transcribe'), findsOneWidget);
          expect(find.text('Merge'), findsOneWidget);

          // Verify progress indicators
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);

          await tester.pumpWidget(Container()); // Clean up for next stage
        }
      },
    );

    testWidgets('UX Journey: Auto-transcription hint is shown to users', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: TranscriptionStatusWidget(episodeId: 1),
          ),
        ),
      );

      // Verify auto-transcription hint is displayed
      expect(
        find.text('Or enable auto-transcription in settings'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
