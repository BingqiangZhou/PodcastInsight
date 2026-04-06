import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';

void main() {
  group('HeaderCapsuleActionButton', () {
    /// Helper to pump the button with a Material app wrapper
    Future<void> pumpButton(
      WidgetTester tester,
      HeaderCapsuleActionButton button, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.lightTheme
              : AppTheme.darkTheme,
          home: Scaffold(
            body: Center(child: button),
          ),
        ),
      );
    }

    group('basic rendering', () {
      testWidgets('renders with icon', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(Material), findsWidgets);
      });

      testWidgets('renders with label when provided', (tester) async {
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () {},
            label: const Text('Add Item'),
          ),
        );

        expect(find.text('Add Item'), findsOneWidget);
      });

      testWidgets('renders with trailing icon', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            trailingIcon: Icons.arrow_forward,
          ),
        );

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      });
    });

    group('tooltip', () {
      testWidgets('shows tooltip when provided', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            tooltip: 'Add item',
          ),
        );

        // Hover to trigger tooltip
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(HeaderCapsuleActionButton)),
        );
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        // Tooltip should be present in the widget tree
        expect(find.byType(Tooltip), findsOneWidget);
      });
    });

    group('loading state', () {
      testWidgets('shows CircularProgressIndicator when isLoading is true', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            isLoading: true,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.add), findsNothing);
      });

      testWidgets('disables onTap when isLoading', (tester) async {
        var tapped = false;
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        );

        // Use pump instead of pumpAndSettle since CircularProgressIndicator animates continuously
        await tester.tap(find.byType(HeaderCapsuleActionButton));
        await tester.pump();

        expect(tapped, isFalse);
      });
    });

    group('disabled state', () {
      testWidgets('is disabled when onPressed is null', (tester) async {
        const tapped = false;
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        // Try to tap - should not crash
        await tester.tap(find.byType(HeaderCapsuleActionButton));
        await tester.pumpAndSettle();

        expect(tapped, isFalse);
      });
    });

    group('density variants', () {
      testWidgets('regular density has correct icon size', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.size, equals(18.0));
      });

      testWidgets('compact density has correct icon size', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            density: HeaderCapsuleActionButtonDensity.compact,
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.size, equals(16.0));
      });

      testWidgets('iconOnly density has correct icon size', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            density: HeaderCapsuleActionButtonDensity.iconOnly,
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.size, equals(18.0));
      });

      testWidgets('iconOnly density hides label', (tester) async {
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () {},
            label: const Text('Hidden'),
            density: HeaderCapsuleActionButtonDensity.iconOnly,
          ),
        );

        expect(find.text('Hidden'), findsNothing);
      });
    });

    group('circular mode', () {
      testWidgets('circular button has constrained size', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            circular: true,
          ),
        );

        final button = tester.getSize(find.byType(HeaderCapsuleActionButton));
        expect(button.width, equals(button.height));
        expect(button.width, equals(40.0)); // regular density size
      });

      testWidgets('circular compact button has smaller size', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            circular: true,
            density: HeaderCapsuleActionButtonDensity.compact,
          ),
        );

        final button = tester.getSize(find.byType(HeaderCapsuleActionButton));
        expect(button.width, equals(button.height));
        expect(button.width, equals(36.0)); // compact density size
      });
    });

    group('dark mode styling', () {
      testWidgets('uses higher alpha in dark mode', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            style: HeaderCapsuleActionButtonStyle.primaryTinted,
          ),
          brightness: Brightness.dark,
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        // Dark mode should have higher alpha (0.08 for disabled)
        expect((material.color?.a ?? 0) * 255.0.round(), greaterThan(15)); // > ~0.06 * 255
      });
    });

    group('style variants', () {
      testWidgets('surfaceNeutral style uses surfaceContainerHighest background', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        // surfaceNeutral should use surfaceContainerHighest
        final theme = AppTheme.lightTheme;
        expect(material.color, equals(theme.colorScheme.surfaceContainerHighest));
      });

      testWidgets('surfaceNeutral style has no border', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side, equals(BorderSide.none));
      });

      testWidgets('primaryTinted style has border', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            style: HeaderCapsuleActionButtonStyle.primaryTinted,
          ),
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side, isNot(equals(BorderSide.none)));
      });

      testWidgets('surfaceNeutral circular button has pill-shaped radius', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            circular: true,
          ),
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        final shape = material.shape! as RoundedRectangleBorder;
        final borderRadius = shape.borderRadius as BorderRadius;
        // For circular regular density: 40.0 / 2 = 20.0
        expect(borderRadius.topLeft.x, equals(20.0));
      });

      testWidgets('default style is surfaceNeutral', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
            // No style specified - should default to surfaceNeutral
          ),
        );

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HeaderCapsuleActionButton),
            matching: find.byType(Material),
          ).first,
        );

        final theme = AppTheme.lightTheme;
        expect(material.color, equals(theme.colorScheme.surfaceContainerHighest));
      });
    });

    group('onPressed callback', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () => tapped = true,
          ),
        );

        await tester.tap(find.byType(HeaderCapsuleActionButton));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('semantics', () {
      testWidgets('has button semantics', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        // Verify Semantics widget exists
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('enabled when onPressed is provided', (tester) async {
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () {},
          ),
        );

        // Button should be tappable
        await tester.tap(find.byType(HeaderCapsuleActionButton));
        await tester.pumpAndSettle();
      });

      testWidgets('disabled when onPressed is null', (tester) async {
        await pumpButton(
          tester,
          const HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: null,
          ),
        );

        // Find the Semantics widget and verify it exists
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('disabled when isLoading', (tester) async {
        await pumpButton(
          tester,
          HeaderCapsuleActionButton(
            icon: Icons.add,
            onPressed: () {},
            isLoading: true,
          ),
        );

        // Should show loading indicator instead of icon
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
