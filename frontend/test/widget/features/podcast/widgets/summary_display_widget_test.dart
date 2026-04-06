import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/summary_display_widget.dart';

void main() {
  testWidgets('SummaryDisplayWidget renders markdown content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SummaryDisplayWidget(
              episodeTitle: 'Test Episode',
              summary: '# Hello\n\nThis is **bold** text.\n\n- Item 1\n- Item 2',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify markdown is rendered
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    // Verify share button is present
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
  });

  testWidgets('SummaryDisplayWidget disables share button when no onShareAll callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SummaryDisplayWidget(
              episodeTitle: 'Test Episode',
              summary: 'Simple summary',
              compact: true,
              // No onShareAll callback provided
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify share button is present but disabled (onPressed is null)
    final buttonFinder = find.widgetWithText(TextButton, 'Share All');
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<TextButton>(buttonFinder);
    expect(button.onPressed, isNull);
  });

  testWidgets('SummaryDisplayWidget with internal scrolling can scroll to top', (
    tester,
  ) async {
    final longContent = '## Long Content\n\n${'Line \n' * 50}This is the end.';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: SummaryDisplayWidget(
                episodeTitle: 'Test Episode',
                summary: longContent,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify scroll view is present
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Get the state and call scrollToTop
    final state = tester.state<SummaryDisplayWidgetState>(
      find.byType(SummaryDisplayWidget),
    );

    // Scroll down a bit first
    await tester.drag(find.byType(SummaryDisplayWidget), const Offset(0, -100));
    await tester.pump();

    // Now scroll to top
    state.scrollToTop();
    await tester.pumpAndSettle();

    // Verify we're at the top
    expect(find.text('Long Content'), findsOneWidget);
  });

  testWidgets('SummaryDisplayWidget preserves state with AutomaticKeepAliveClientMixin', (
    tester,
  ) async {
    // This test verifies that the widget uses AutomaticKeepAliveClientMixin
    // by checking that the state is preserved when the widget is rebuilt
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SummaryDisplayWidget(
              episodeTitle: 'Test Episode',
              summary: 'Test summary content',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the widget is built with keep alive
    final state = tester.state<SummaryDisplayWidgetState>(
      find.byType(SummaryDisplayWidget),
    );

    expect(state.wantKeepAlive, isTrue);
  });

  testWidgets('SummaryDisplayWidget with onShareSelected callback renders correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SummaryDisplayWidget(
              episodeTitle: 'Test Episode',
              summary: 'Test summary content for selection',
              onShareSelected: (episodeTitle, summary, selectedText) async {
                // Callback works
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify widget renders without errors
    expect(find.text('Test summary content for selection'), findsOneWidget);
  });
}
