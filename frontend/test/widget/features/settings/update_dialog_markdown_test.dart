import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/settings/presentation/widgets/update_dialog.dart';
import 'package:personal_ai_assistant/shared/models/github_release.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'canLaunch':
            case 'canLaunchUrl':
              return true;
            case 'launch':
            case 'launchUrl':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    methodCalls.clear();
  });

  group('AppUpdateDialog Markdown', () {
    testWidgets('renders markdown release notes', (tester) async {
      final release = _buildRelease('''
## Highlights
- Added Markdown rendering
- Improved update dialog
This is an **important** update.
''');

      await tester.pumpWidget(_buildTestApp(release));
      await tester.pumpAndSettle();

      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Added Markdown rendering'), findsOneWidget);
      expect(find.textContaining('Improved update'), findsOneWidget);
      expect(find.textContaining('important'), findsOneWidget);
    });

    testWidgets('shows fallback text when release notes are empty', (
      tester,
    ) async {
      final release = _buildRelease('   \n\t  ');

      await tester.pumpWidget(_buildTestApp(release));
      await tester.pumpAndSettle();

      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('opens markdown links via url_launcher', (tester) async {
      final release = _buildRelease('[OpenAI](https://openai.com)');

      await tester.pumpWidget(_buildTestApp(release));
      await tester.pumpAndSettle();

      final linkFinder = find.text('OpenAI');
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      final launchCalls = methodCalls
          .where(
            (call) => call.method == 'launch' || call.method == 'launchUrl',
          )
          .toList();
      expect(launchCalls, isNotEmpty);

      final firstLaunchArgs = launchCalls.first.arguments;
      if (firstLaunchArgs is String) {
        expect(firstLaunchArgs, 'https://openai.com');
      } else if (firstLaunchArgs is Map) {
        expect(firstLaunchArgs['url'], 'https://openai.com');
      }
    });

    testWidgets('uses mobile width consistent with profile dialogs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final release = _buildRelease('## Notes');
      await tester.pumpWidget(_buildTestApp(release));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 358.0,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'uses onPrimary over primary for download button in dark mode',
      (tester) async {
        final release = _buildRelease('## Notes');
        await tester.pumpWidget(
          _buildTestApp(release, themeMode: ThemeMode.dark),
        );
        await tester.pumpAndSettle();

        final filledButton = tester.widget<FilledButton>(
          find.bySubtype<FilledButton>().first,
        );
        final resolvedBackgroundColor = filledButton.style?.backgroundColor
            ?.resolve(<WidgetState>{});
        final resolvedForegroundColor = filledButton.style?.foregroundColor
            ?.resolve(<WidgetState>{});

        expect(resolvedBackgroundColor, AppTheme.darkTheme.colorScheme.primary);
        expect(
          resolvedForegroundColor,
          AppTheme.darkTheme.colorScheme.onPrimary,
        );
      },
    );

    testWidgets('uses shared primary accent for update header icon', (
      tester,
    ) async {
      final release = _buildRelease('## Notes');
      await tester.pumpWidget(_buildTestApp(release));
      await tester.pumpAndSettle();

      final headerIcon = tester.widget<Icon>(
        find.byIcon(Icons.system_update_alt),
      );
      expect(headerIcon.color, AppTheme.lightTheme.colorScheme.primary);
    });
  });
}

Widget _buildTestApp(
  GitHubRelease release, {
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AppUpdateDialog(release: release, currentVersion: '1.0.0'),
      ),
    ),
  );
}

GitHubRelease _buildRelease(String body) {
  return GitHubRelease(
    tagName: 'v1.2.3',
    name: 'Release v1.2.3',
    version: '1.2.3',
    body: body,
    prerelease: false,
    draft: false,
    createdAt: DateTime(2026),
    publishedAt: DateTime(2026, 1, 2),
    htmlUrl: 'https://github.com/example/repo/releases/tag/v1.2.3',
  );
}
