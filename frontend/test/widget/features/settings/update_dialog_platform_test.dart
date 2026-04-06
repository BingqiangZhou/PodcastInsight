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

  // Mock url_launcher
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
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
  });

  group('AppUpdateDialog platform-aware rendering', () {
    testWidgets(
      'shows correct file size from platform asset, not assets.first',
      (tester) async {
        // Android APK is first, Windows ZIP is second — file sizes differ.
        final release = _buildReleaseWithAssets([
          _buildAsset(
            'personal-ai-assistant-android-arm64-1.0.0.apk',
            5 * 1024 * 1024, // 5MB
          ),
          _buildAsset(
            'personal-ai-assistant-windows-1.0.0.zip',
            80 * 1024 * 1024, // 80MB
          ),
        ]);

        await tester.pumpWidget(_buildTestApp(release));
        await tester.pumpAndSettle();

        // On Windows test environment, the platform asset is the Windows ZIP.
        // If running on a non-Windows test runner, platform may differ —
        // this test verifies the logic regardless: the file size should NOT
        // come from assets.first (the Android APK at 5.0MB).
        // We check that the size text does NOT contain the Android APK size.
        // Since this is a desktop test environment, it uses 'windows'.
        //
        // Note: In the Flutter test environment, Platform.isWindows is true
        // when running on Windows, so getAssetForPlatform('windows') will
        // match the 80MB ZIP.
        final sizeText = find.textContaining('80.0MB');
        final wrongSize = find.textContaining('5.0MB');

        // One of these should be present depending on the platform.
        // The key invariant is: if the wrong platform size appears, the test fails.
        final hasPlatformSize = sizeText.evaluate().isNotEmpty;
        final hasWrongSize = wrongSize.evaluate().isNotEmpty;

        // On Windows: should see 80.0MB (the windows zip), NOT 5.0MB
        // On non-Windows: should see neither (no platform asset → no size row)
        expect(
          hasPlatformSize || !hasWrongSize,
          isTrue,
          reason:
              'File size must come from platform asset, not assets.first',
        );
      },
    );

    testWidgets(
      'download button is disabled when no platform asset is available',
      (tester) async {
        // Only has a macOS DMG — on Windows, there's no matching asset.
        final release = _buildReleaseWithAssets([
          _buildAsset('personal-ai-assistant-macos-1.0.0.dmg', 100 * 1024 * 1024),
        ]);

        await tester.pumpWidget(_buildTestApp(release));
        await tester.pumpAndSettle();

        // Find the download FilledButton
        final filledButtons = find.bySubtype<FilledButton>();
        expect(filledButtons, findsOneWidget);

        final button = tester.widget<FilledButton>(filledButtons.first);
        // The button should be disabled (onPressed is null) when no platform asset
        expect(button.onPressed, isNull,
            reason: 'Download button must be disabled when no platform asset');
      },
    );

    testWidgets(
      'shows "no installer" text when no platform asset is available',
      (tester) async {
        final release = _buildReleaseWithAssets([
          _buildAsset('personal-ai-assistant-macos-1.0.0.dmg', 100 * 1024 * 1024),
        ]);

        await tester.pumpWidget(_buildTestApp(release));
        await tester.pumpAndSettle();

        // Should show the platform_no_asset localization text
        // Use textContaining because the button label may be truncated with ellipsis
        expect(
          find.textContaining('No installer'),
          findsOneWidget,
          reason: 'Should display platform no asset message',
        );
      },
    );

    testWidgets(
      'hides file size row when no platform asset',
      (tester) async {
        final release = _buildReleaseWithAssets([
          _buildAsset('personal-ai-assistant-macos-1.0.0.dmg', 100 * 1024 * 1024),
        ]);

        await tester.pumpWidget(_buildTestApp(release));
        await tester.pumpAndSettle();

        // The file_download icon should not appear (no file size to show)
        expect(
          find.byIcon(Icons.file_download),
          findsNothing,
          reason: 'File size row should be hidden when no platform asset',
        );
      },
    );
  });
}

Widget _buildTestApp(GitHubRelease release) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: AppUpdateDialog(release: release, currentVersion: '0.9.0'),
      ),
    ),
  );
}

GitHubRelease _buildReleaseWithAssets(List<GitHubAsset> assets) {
  return GitHubRelease(
    tagName: 'v1.0.0',
    name: 'Release v1.0.0',
    version: '1.0.0',
    body: '## Test release notes',
    prerelease: false,
    draft: false,
    createdAt: DateTime(2026),
    publishedAt: DateTime(2026, 1, 2),
    htmlUrl: 'https://github.com/example/repo/releases/tag/v1.0.0',
    assets: assets,
  );
}

GitHubAsset _buildAsset(String name, int size) {
  return GitHubAsset(
    name: name,
    downloadUrl: 'https://github.com/example/repo/releases/download/v1.0.0/$name',
    size: size,
    downloadCount: 100,
    contentType: 'application/octet-stream',
  );
}
