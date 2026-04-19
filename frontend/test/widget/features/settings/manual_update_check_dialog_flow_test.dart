import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/services/app_update_service.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/settings/presentation/providers/app_update_provider.dart';
import 'package:personal_ai_assistant/features/settings/presentation/widgets/update_dialog.dart';
import 'package:personal_ai_assistant/shared/models/github_release.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ManualUpdateCheckDialog flow', () {
    testWidgets('shows single dialog on check trigger', (
      tester,
    ) async {
      final service = _FakeAppUpdateService(
        delay: const Duration(milliseconds: 250),
      );

      await tester.pumpWidget(_buildHost(service: service));

      await tester.tap(find.text('Open Check Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ManualUpdateCheckDialog), findsOneWidget);
      expect(find.text("You're up to date"), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('redirects to AppUpdateDialog when update is available', (
      tester,
    ) async {
      final service = _FakeAppUpdateService(release: _buildRelease());

      await tester.pumpWidget(_buildHost(service: service));

      await tester.tap(find.text('Open Check Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(
        find.text('A new version is available. Would you like to update now?'),
        findsNothing,
      );

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows up-to-date state when no update is available', (
      tester,
    ) async {
      final service = _FakeAppUpdateService();

      await tester.pumpWidget(_buildHost(service: service));

      await tester.tap(find.text('Open Check Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text("You're up to date"), findsOneWidget);
      expect(
        find.byKey(const Key('manual_update_uptodate_mark')),
        findsOneWidget,
      );
      final markIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('manual_update_uptodate_mark')),
          matching: find.byIcon(Icons.check),
        ),
      );
      expect(markIcon.color, AppTheme.lightTheme.colorScheme.onSurfaceVariant);

      final upToDateText = tester.widget<Text>(
        find.byKey(const Key('manual_update_uptodate_text')),
      );
      expect(
        upToDateText.style?.color,
        AppTheme.lightTheme.colorScheme.onSurfaceVariant,
      );
      final okButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'OK'),
      );
      final okColor = okButton.style?.foregroundColor?.resolve(<WidgetState>{});
      expect(okColor, AppTheme.lightTheme.colorScheme.onSurfaceVariant);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('uses themed colors for up-to-date state in dark mode', (
      tester,
    ) async {
      final service = _FakeAppUpdateService();

      await tester.pumpWidget(
        _buildHost(service: service, themeMode: ThemeMode.dark),
      );

      await tester.tap(find.text('Open Check Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();

      final markIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('manual_update_uptodate_mark')),
          matching: find.byIcon(Icons.check),
        ),
      );
      expect(markIcon.color, AppTheme.darkTheme.colorScheme.onSurfaceVariant);

      final upToDateText = tester.widget<Text>(
        find.byKey(const Key('manual_update_uptodate_text')),
      );
      expect(
        upToDateText.style?.color,
        AppTheme.darkTheme.colorScheme.onSurfaceVariant,
      );
      final okButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'OK'),
      );
      final okColor = okButton.style?.foregroundColor?.resolve(<WidgetState>{});
      expect(okColor, AppTheme.darkTheme.colorScheme.onSurfaceVariant);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state and retry button when check fails', (
      tester,
    ) async {
      final service = _FakeAppUpdateService(error: Exception('network error'));

      await tester.pumpWidget(_buildHost(service: service));

      await tester.tap(find.text('Open Check Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Check Failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('uses mobile width consistent with profile dialogs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeAppUpdateService(error: Exception('network error'));

      await tester.pumpWidget(_buildHost(service: service));
      await tester.tap(find.text('Open Check Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 358.0,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}

Widget _buildHost({
  required AppUpdateService service,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [appUpdateServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  ManualUpdateCheckDialog.show(context);
                },
                child: const Text('Open Check Dialog'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _FakeAppUpdateService extends AppUpdateService {
  _FakeAppUpdateService({this.release, this.error, this.delay = Duration.zero});

  final GitHubRelease? release;
  final Object? error;
  final Duration delay;

  @override
  Future<GitHubRelease?> checkForUpdates({
    bool forceRefresh = false,
    bool includePrerelease = false,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) {
      throw error!;
    }
    return release;
  }

  @override
  Future<void> clearSkippedVersion() async {}
}

GitHubRelease _buildRelease() {
  return GitHubRelease(
    tagName: 'v0.5.4',
    name: 'Release v0.5.4',
    version: '0.5.4',
    body: '## Highlights\n- Direct open detailed update dialog',
    prerelease: false,
    draft: false,
    createdAt: DateTime(2026, 2, 12),
    publishedAt: DateTime(2026, 2, 12),
    htmlUrl: 'https://github.com/example/repo/releases/tag/v0.5.4',
  );
}
