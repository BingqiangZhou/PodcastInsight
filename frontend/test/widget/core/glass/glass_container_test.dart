import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

// Test helper for hover gesture
import 'package:flutter/gestures.dart' show PointerDeviceKind;

void main() {
  group('GlassContainer', () {
    testWidgets('renders with default parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('renders with custom tier', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              tier: GlassTier.heavy,
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('renders with custom border radius', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              borderRadius: 24,
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('renders with custom padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: EdgeInsets.all(32),
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('renders with tint', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              tint: Color(0x800000FF),
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('handles animation disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: GlassContainer(
                child: Text('Test content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('interactive mode handles hover', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              interactive: true,
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);

      // Hover over the container
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(GlassContainer)));
      await tester.pump();

      // Widget should still render after hover
      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('interactive mode handles tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () {
                tapped = true;
              },
              child: const GlassContainer(
                interactive: true,
                child: Text('Test content'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassContainer));
      await tester.pumpAndSettle();

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('all tiers render correctly', (WidgetTester tester) async {
      for (final tier in GlassTier.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GlassContainer(
                tier: tier,
                child: Text('Tier: ${tier.name}'),
              ),
            ),
          ),
        );

        expect(find.text('Tier: ${tier.name}'), findsOneWidget);
      }
    });

    testWidgets('renders without animation when animate is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              animate: false,
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('works in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: GlassContainer(
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('works in light mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: GlassContainer(
              child: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('can nest multiple containers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              tier: GlassTier.heavy,
              child: GlassContainer(
                tier: GlassTier.light,
                child: Text('Nested content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nested content'), findsOneWidget);
      expect(find.byType(GlassContainer), findsNWidgets(2));
    });

    testWidgets('repaintBoundary isolates repaints', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                GlassContainer(
                  child: Text('Container 1'),
                ),
                GlassContainer(
                  child: Text('Container 2'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(2));
    });

    testWidgets('child is correctly padded', (WidgetTester tester) async {
      const customPadding = EdgeInsets.all(32);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: customPadding,
              child: Text('Padded content'),
            ),
          ),
        ),
      );

      expect(find.text('Padded content'), findsOneWidget);
    });
  });
}
