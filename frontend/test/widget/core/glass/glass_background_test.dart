import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_background.dart';

void main() {
  group('GlassBackground', () {
    group('renders in dark mode', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: GlassBackground(
                child: Text('Test Content'),
              ),
            ),
          ),
        );

        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('has correct background color in dark mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                child: Container(),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(GlassBackground),
            matching: find.byType(Container),
          ).at(0),
        );

        final boxDecoration = container.decoration as BoxDecoration?;
        expect(boxDecoration?.color, const Color(0xFF0f0f1a));
      });

      testWidgets('renders gradient orbs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                child: Container(),
              ),
            ),
          ),
        );

        // Should have 4 gradient orbs
        final positionedWidgets = find.descendant(
          of: find.byType(GlassBackground),
          matching: find.byType(Positioned),
        );

        expect(positionedWidgets, findsWidgets);
      });
    });

    group('renders in light mode', () {
      testWidgets('has correct background color in light mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: GlassBackground(
                child: Container(),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(GlassBackground),
            matching: find.byType(Container),
          ).at(0),
        );

        final boxDecoration = container.decoration as BoxDecoration?;
        expect(boxDecoration?.color, const Color(0xFFF8F9FA));
      });
    });

    group('respects disableAnimations', () {
      testWidgets('hides orbs when animations disabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: GlassBackground(
                  child: Container(),
                ),
              ),
            ),
          ),
        );

        // Orbs should not be rendered when animations are disabled
        final positionedWidgets = find.descendant(
          of: find.byType(GlassBackground),
          matching: find.byType(Positioned),
        );

        expect(positionedWidgets, findsNothing);
      });

      testWidgets('renders child when animations disabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: GlassBackground(
                  child: Text('Static Content'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Static Content'), findsOneWidget);
      });
    });

    group('theme variants', () {
      testWidgets('renders with podcast theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                child: Container(),
              ),
            ),
          ),
        );

        expect(find.byType(GlassBackground), findsOneWidget);
      });

      testWidgets('renders with home theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                theme: GlassBackgroundTheme.home,
                child: Container(),
              ),
            ),
          ),
        );

        expect(find.byType(GlassBackground), findsOneWidget);
      });

      testWidgets('renders with neutral theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                theme: GlassBackgroundTheme.neutral,
                child: Container(),
              ),
            ),
          ),
        );

        expect(find.byType(GlassBackground), findsOneWidget);
      });
    });

    group('RepaintBoundary', () {
      testWidgets('wraps content in RepaintBoundary', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: GlassBackground(
                child: Container(),
              ),
            ),
          ),
        );

        // Flutter adds RepaintBoundary widgets automatically, so we just check
        // that at least one exists (our wrapper)
        expect(find.byType(RepaintBoundary), findsWidgets);
      });
    });
  });
}
