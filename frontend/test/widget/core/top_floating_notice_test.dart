import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';

const double _defaultTopFloatingNoticeGap = 0;

void main() {
  group('TopFloatingNotice', () {
    testWidgets('uses default 3s duration and stays in upper area', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      final noticeFinder = find.byKey(const Key('top_floating_notice'));
      expect(noticeFinder, findsOneWidget);

      final noticeContext = tester.element(noticeFinder);
      final expectedTop =
          MediaQuery.of(noticeContext).viewPadding.top +
          kToolbarHeight +
          _defaultTopFloatingNoticeGap;
      final noticeRect = tester.getRect(noticeFinder);
      expect(noticeRect.top, closeTo(expectedTop, 0.01));
      expect(noticeRect.top, greaterThanOrEqualTo(kToolbarHeight));
      expect(noticeRect.top, lessThan(220));
      expect(noticeRect.center.dy, lessThan(400));

      await tester.pump(const Duration(seconds: 2));
      expect(noticeFinder, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(noticeFinder, findsNothing);
    });

    testWidgets('replaces previous notice without stacking', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_first')));
      await tester.pump();
      expect(find.text('First Notice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('show_notice_second')));
      await tester.pump();

      expect(find.text('First Notice'), findsNothing);
      expect(find.text('Second Notice'), findsOneWidget);
      expect(find.byKey(const Key('top_floating_notice')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('applies extraTopOffset below page header', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();
      final defaultTop = tester
          .getTopLeft(find.byKey(const Key('top_floating_notice')))
          .dy;

      await tester.tap(find.byKey(const Key('show_notice_with_offset')));
      await tester.pump();
      final offsetTop = tester
          .getTopLeft(find.byKey(const Key('top_floating_notice')))
          .dy;

      expect(offsetTop, greaterThan(defaultTop + 60));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses error icon for error notice', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_error')));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses success icon for success notice', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(
        find.byKey(const Key('top_floating_notice_message')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses glass container for success notice', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      // Verify GlassContainer is used
      expect(find.byType(GlassContainer), findsWidgets);

      final context = tester.element(
        find.byKey(const Key('top_floating_notice')),
      );
      final theme = Theme.of(context);

      final messageText = tester.widget<Text>(
        find.byKey(const Key('top_floating_notice_message')),
      );
      expect(messageText.style?.color, theme.colorScheme.onSurface);

      final successIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(successIcon.color, theme.colorScheme.onSurface);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses error tint for error notice', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_error')));
      await tester.pump();

      // Verify GlassContainer with error tint is rendered
      final glassContainer = tester.widget<GlassContainer>(
        find.byKey(const Key('top_floating_notice')),
      );
      expect(glassContainer.tint, isNotNull);

      final messageText = tester.widget<Text>(
        find.byKey(const Key('top_floating_notice_message')),
      );
      expect(messageText.style?.color, isNotNull);

      final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(errorIcon.color, isNotNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses glass container in dark mode for success notice', (
      tester,
    ) async {
      await _pumpHost(tester, themeMode: ThemeMode.dark);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      expect(find.byType(GlassContainer), findsWidgets);

      final context = tester.element(
        find.byKey(const Key('top_floating_notice')),
      );
      final theme = Theme.of(context);

      final messageText = tester.widget<Text>(
        find.byKey(const Key('top_floating_notice_message')),
      );
      expect(messageText.style?.color, theme.colorScheme.onSurface);

      final successIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(successIcon.color, theme.colorScheme.onSurface);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses glass container in dark mode for error notice', (
      tester,
    ) async {
      await _pumpHost(tester, themeMode: ThemeMode.dark);

      await tester.tap(find.byKey(const Key('show_notice_error')));
      await tester.pump();

      final glassContainer = tester.widget<GlassContainer>(
        find.byKey(const Key('top_floating_notice')),
      );
      expect(glassContainer.tint, isNotNull);

      final messageText = tester.widget<Text>(
        find.byKey(const Key('top_floating_notice_message')),
      );
      expect(messageText.style?.color, isNotNull);

      final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(errorIcon.color, isNotNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('glass container has standard tier and correct border radius', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      final glassContainer = tester.widget<GlassContainer>(
        find.byKey(const Key('top_floating_notice')),
      );
      expect(glassContainer.tier, GlassTier.standard);
      expect(glassContainer.borderRadius, 12);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('uses glass container when shown after theme toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: _ThemeSwitchingApp(),
        ),
      );

      await tester.tap(find.byKey(const Key('toggle_theme')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();
      expect(find.byKey(const Key('top_floating_notice')), findsOneWidget);
      expect(find.byType(GlassContainer), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('positions notice exactly at app bar when no top inset', (
      tester,
    ) async {
      await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('show_notice_default')));
      await tester.pump();

      final noticeTop = tester
          .getRect(find.byKey(const Key('top_floating_notice')))
          .top;
      expect(noticeTop, closeTo(kToolbarHeight, 0.01));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('positions notice below status bar inset on notch devices', (
      tester,
    ) async {
      const topInset = 32.0;
      late BuildContext hostContext;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    viewPadding: const EdgeInsets.only(top: topInset),
                    padding: const EdgeInsets.only(top: topInset),
                  ),
                  child: Builder(
                    builder: (context) {
                      hostContext = context;
                      return const _TopNoticeHost();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      showTopFloatingNotice(hostContext, message: 'Quick Notice');
      await tester.pump();

      final noticeTop = tester
          .getRect(find.byKey(const Key('top_floating_notice')))
          .top;
      expect(noticeTop, closeTo(topInset + kToolbarHeight, 0.01));
      await tester.pump(const Duration(seconds: 4));
    });
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                viewPadding: viewPadding,
                padding: viewPadding,
              ),
              child: const _TopNoticeHost(),
            );
          },
        ),
      ),
    ),
  );
}

// GlassContainer-based notice no longer exposes a BoxDecoration directly.

class _TopNoticeHost extends StatelessWidget {
  const _TopNoticeHost({this.onToggleTheme});

  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host')),
      body: Builder(
        builder: (context) {
          return Column(
            children: [
              const SizedBox(height: 120),
              if (onToggleTheme != null)
                TextButton(
                  key: const Key('toggle_theme'),
                  onPressed: onToggleTheme,
                  child: const Text('Toggle theme'),
                ),
              TextButton(
                key: const Key('show_notice_default'),
                onPressed: () {
                  showTopFloatingNotice(context, message: 'Quick Notice');
                },
                child: const Text('Show default'),
              ),
              TextButton(
                key: const Key('show_notice_with_offset'),
                onPressed: () {
                  showTopFloatingNotice(
                    context,
                    message: 'Offset Notice',
                    extraTopOffset: 80,
                  );
                },
                child: const Text('Show offset'),
              ),
              TextButton(
                key: const Key('show_notice_first'),
                onPressed: () {
                  showTopFloatingNotice(
                    context,
                    message: 'First Notice',
                    duration: const Duration(seconds: 3),
                  );
                },
                child: const Text('Show first'),
              ),
              TextButton(
                key: const Key('show_notice_second'),
                onPressed: () {
                  showTopFloatingNotice(
                    context,
                    message: 'Second Notice',
                    duration: const Duration(seconds: 3),
                  );
                },
                child: const Text('Show second'),
              ),
              TextButton(
                key: const Key('show_notice_error'),
                onPressed: () {
                  showTopFloatingNotice(
                    context,
                    message: 'Error Notice',
                    isError: true,
                    duration: const Duration(seconds: 3),
                  );
                },
                child: const Text('Show error'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeSwitchingApp extends StatefulWidget {
  const _ThemeSwitchingApp();

  @override
  State<_ThemeSwitchingApp> createState() => _ThemeSwitchingAppState();
}

class _ThemeSwitchingAppState extends State<_ThemeSwitchingApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _TopNoticeHost(
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light;
          });
        },
      ),
    );
  }
}
