import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';

void main() {
  group('SurfaceCard', () {
    group('Rendering', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                child: Text('Test content'),
              ),
            ),
          ),
        );

        expect(find.text('Test content'), findsOneWidget);
      });

      testWidgets('applies default border radius of 16',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        final borderRadius = decoration.borderRadius! as BorderRadius;
        expect(borderRadius.topLeft.x, 16);
      });

      testWidgets('applies custom border radius', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                borderRadius: 24,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        final borderRadius = decoration.borderRadius! as BorderRadius;
        expect(borderRadius.topLeft.x, 24);
      });

      testWidgets('applies padding when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                padding: EdgeInsets.all(16),
                child: Text('Test'),
              ),
            ),
          ),
        );

        // Find the Padding widget that wraps the Text child
        final paddingWidgets = find.descendant(
          of: find.byType(SurfaceCard),
          matching: find.byType(Padding),
        );

        // Get all Padding widgets and find one with EdgeInsets.all(16)
        expect(paddingWidgets, findsWidgets);

        // The ClipRRect contains the Padding
        final clipRRect = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(ClipRRect),
          ),
        );

        expect(clipRRect.child, isA<Padding>());
        final padding = clipRRect.child! as Padding;
        expect(padding.padding, const EdgeInsets.all(16));
      });

      testWidgets('renders without padding when not provided',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        // The ClipRRect should directly contain the child Text, not Padding
        final clipRRect = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(ClipRRect),
          ),
        );

        expect(clipRRect.child, isA<Text>());
        expect(clipRRect.child, isNot(isA<Padding>()));
      });
    });

    group('Variants', () {
      testWidgets('normal variant uses card tier fill in light mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.normal,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        // normal variant maps to CardTier.card → lightCardTierFill
        expect(decoration.color, AppColors.lightCardTierFill);
      });

      testWidgets('normal variant uses card tier fill in dark mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.normal,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        // normal variant maps to CardTier.card → cardTierFill
        expect(decoration.color, AppColors.cardTierFill);
      });

      testWidgets('elevated variant uses elevated tier fill in light mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.elevated,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        // elevated variant maps to CardTier.elevated → lightElevatedTierFill
        expect(decoration.color, AppColors.lightElevatedTierFill);
      });

      testWidgets('flat variant uses surface tier fill in light mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.flat,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        // flat variant maps to CardTier.surface → lightSurfaceTierFill
        expect(decoration.color, AppColors.lightSurfaceTierFill);
      });

      testWidgets('flat variant uses surface tier fill in dark mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.flat,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        // flat variant maps to CardTier.surface → surfaceTierFill
        expect(decoration.color, AppColors.surfaceTierFill);
      });
    });

    group('Border', () {
      testWidgets('applies border with card tier border color in light mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SurfaceCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.border, isNotNull);
        final border = decoration.border! as Border;
        // Default tier is card → lightCardTierBorder
        expect(border.top.color, AppColors.lightCardTierBorder);
      });

      testWidgets('applies border with card tier border color in dark mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SurfaceCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.border, isNotNull);
        final border = decoration.border! as Border;
        // Default tier is card → cardTierBorder
        expect(border.top.color, AppColors.cardTierBorder);
      });

      testWidgets('applies ClipRRect for border radius',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        expect(find.byType(ClipRRect), findsOneWidget);
      });
    });

    group('Custom Background Color', () {
      testWidgets('uses custom background color when provided',
          (tester) async {
        const customColor = Color(0xFFFF0000);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SurfaceCard(
                backgroundColor: customColor,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, customColor);
      });

      testWidgets('custom background color overrides variant color',
          (tester) async {
        const customColor = Color(0xFF00FF00);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SurfaceCard(
                variant: SurfaceCardVariant.flat,
                backgroundColor: customColor,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, customColor);
        expect(decoration.color, isNot(AppColors.lightSurfaceTierFill));
      });
    });
  });
}
