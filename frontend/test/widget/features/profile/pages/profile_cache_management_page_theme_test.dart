import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_cache_management_page.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (methodCall) async {
          final base = Directory.systemTemp.path;
          switch (methodCall.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationSupportDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getDownloadsDirectory':
              return base;
            default:
              return base;
          }
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  group('ProfileCacheManagementPage theme', () {
    testWidgets('uses compact header and aligned content on mobile', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(560, 1600));
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.byType(CompactHeaderPanel), findsOneWidget);
      expect(
        find.byKey(const Key('cache_manage_content_panel')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      final refreshButton = tester.widget<HeaderCapsuleActionButton>(
        find.byKey(const Key('cache_manage_refresh_action')),
      );
      expect(refreshButton.circular, isTrue);

            final glassPanels = find.byType(SurfacePanel);
      final headerRect = tester.getRect(glassPanels.first);
      final contentRect = tester.getRect(
        find.byKey(const Key('cache_manage_content_panel')),
      );
      expect(contentRect.top - headerRect.bottom, closeTo(12, 0.1));

      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards, hasLength(3));
      for (final card in cards) {
        expect(
          card.margin,
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }

      final detailsRect = tester.getRect(find.text('DETAILS'));
      final overviewRect = tester.getRect(
        find.byKey(const Key('cache_manage_overview_section')),
      );
      final noticeRect = tester.getRect(
        find.byKey(const Key('cache_manage_notice_box')),
      );
      final deepCleanRect = tester.getRect(
        find.byKey(const Key('cache_manage_deep_clean_all')),
      );

      expect(overviewRect.left, closeTo(detailsRect.left, 0.1));
      expect(noticeRect.left, closeTo(detailsRect.left, 0.1));
      expect(deepCleanRect.left, closeTo(detailsRect.left, 0.1));
    });

    testWidgets('removes extra horizontal gutters on desktop', (tester) async {
      _setSurfaceSize(tester, const Size(1024, 1600));
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards, hasLength(3));
      for (final card in cards) {
        expect(
          card.margin,
          const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        );
      }

      final detailsRect = tester.getRect(find.text('DETAILS'));
      final overviewRect = tester.getRect(
        find.byKey(const Key('cache_manage_overview_section')),
      );
      final noticeRect = tester.getRect(
        find.byKey(const Key('cache_manage_notice_box')),
      );
      final deepCleanRect = tester.getRect(
        find.byKey(const Key('cache_manage_deep_clean_all')),
      );

      expect(overviewRect.left, closeTo(detailsRect.left, 0.1));
      expect(noticeRect.left, closeTo(detailsRect.left, 0.1));
      expect(deepCleanRect.left, closeTo(detailsRect.left, 0.1));
    });

    testWidgets('renders semantic category icons', (tester) async {
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.headphones), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('maps legend and segment colors to palette in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProfileCacheManagementPage));
      final l10n = AppLocalizations.of(context)!;

      final audioSegment = tester.widget<Container>(
        find.byKey(const Key('cache_segment_audio')),
      );
      expect(audioSegment.color, _buildTestTheme(brightness: Brightness.light).colorScheme.tertiary);

      final otherSegment = tester.widget<Container>(
        find.byKey(const Key('cache_segment_other')),
      );
      expect(otherSegment.color, _buildTestTheme(brightness: Brightness.light).colorScheme.secondary);

      final audioLegend = tester.widget<Container>(
        find.byKey(const Key('cache_legend_audio')),
      );
      final audioLegendDecoration = audioLegend.decoration as BoxDecoration;
      expect(
        audioLegendDecoration.color,
        _buildTestTheme(brightness: Brightness.light).colorScheme.tertiary,
      );

      final cleanButton = tester.widget<HeaderCapsuleActionButton>(
        find.byKey(const Key('cache_manage_clean_images')),
      );
      expect(cleanButton.circular, isTrue);
      expect(cleanButton.density, HeaderCapsuleActionButtonDensity.iconOnly);
      expect(cleanButton.tooltip, l10n.profile_cache_manage_clean);
      expect(find.byTooltip(l10n.profile_cache_manage_clean), findsNWidgets(3));

      final scrollable = find.descendant(
        of: find.byType(ProfileCacheManagementPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('cache_manage_notice_box')),
        200,
        scrollable: scrollable.first,
      );

      final noticeBox = tester.widget<Container>(
        find.byKey(const Key('cache_manage_notice_box')),
      );
      final noticeDecoration = noticeBox.decoration as BoxDecoration;
      expect(
        noticeDecoration.color,
        _buildTestTheme(brightness: Brightness.light).colorScheme.onSurfaceVariant.withValues(
          alpha: 0.16,
        ),
      );
      final noticeIcon = tester.widget<Icon>(
        find.byKey(const Key('cache_manage_notice_icon')),
      );
      expect(
        noticeIcon.color,
        _buildTestTheme(brightness: Brightness.light).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('uses high-contrast deep clean button in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      final deepCleanFinder = find.byKey(
        const Key('cache_manage_deep_clean_all'),
      );
      final scrollable = find.descendant(
        of: find.byType(ProfileCacheManagementPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        deepCleanFinder,
        200,
        scrollable: scrollable.first,
      );

      final deepCleanButton = tester.widget<ButtonStyleButton>(deepCleanFinder);
      final resolvedBackground = deepCleanButton.style?.backgroundColor
          ?.resolve(<WidgetState>{});
      final resolvedForeground = deepCleanButton.style?.foregroundColor
          ?.resolve(<WidgetState>{});

      expect(resolvedBackground, _buildTestTheme(brightness: Brightness.dark).colorScheme.surface);
      expect(resolvedForeground, _buildTestTheme(brightness: Brightness.dark).colorScheme.onSurface);
    });

    testWidgets('stays stable in zero-data state', (tester) async {
      await tester.pumpWidget(_buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCacheManagementPage), findsOneWidget);
      expect(find.byType(CompactHeaderPanel), findsOneWidget);
      expect(
        find.byKey(const Key('cache_manage_content_panel')),
        findsOneWidget,
      );

      final scrollable = find.descendant(
        of: find.byType(ProfileCacheManagementPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('cache_manage_notice_box')),
        200,
        scrollable: scrollable.first,
      );

      final noticeBox = tester.widget<Container>(
        find.byKey(const Key('cache_manage_notice_box')),
      );
      final noticeDecoration = noticeBox.decoration as BoxDecoration;
      expect(
        noticeDecoration.color,
        _buildTestTheme(brightness: Brightness.dark).colorScheme.onSurfaceVariant.withValues(alpha: 0.24),
      );
      expect(find.textContaining('0'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// Test theme that doesn't use Google Fonts to avoid network loading
ThemeData _buildTestTheme({required Brightness brightness}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [
      brightness == Brightness.dark
          ? AppThemeExtension.dark
          : AppThemeExtension.light,
    ],
  );
}

Widget _buildTestApp({required ThemeMode themeMode}) {
  return ProviderScope(
    child: MaterialApp(
      theme: _buildTestTheme(brightness: Brightness.light),
      darkTheme: _buildTestTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfileCacheManagementPage(),
    ),
  );
}
