import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';
import 'package:personal_ai_assistant/core/glass/glass_vibrancy.dart';

void main() {
  group('GlassVibrancy', () {
    group('primaryText', () {
      testWidgets('returns black in light mode regardless of tier',
          (WidgetTester tester) async {
        for (final tier in GlassTier.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Builder(
                builder: (context) {
                  final color = GlassVibrancy.primaryText(context, tier: tier);
                  expect(color, const Color(0xFF000000));
                  return const SizedBox();
                },
              ),
            ),
          );
        }
      });

      testWidgets('returns white in dark mode regardless of tier',
          (WidgetTester tester) async {
        for (final tier in GlassTier.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Builder(
                builder: (context) {
                  final color = GlassVibrancy.primaryText(context, tier: tier);
                  expect(color, const Color(0xFFFFFFFF));
                  return const SizedBox();
                },
              ),
            ),
          );
        }
      });

      testWidgets('always has full opacity', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                for (final tier in GlassTier.values) {
                  final color = GlassVibrancy.primaryText(context, tier: tier);
                  expect(color.alpha, 255);
                }
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('secondaryText', () {
      testWidgets('returns correct base color in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final color = GlassVibrancy.secondaryText(
                  context,
                  tier: GlassTier.standard,
                );
                // Base color is #3C3C43
                expect(color.red, equals(0x3C));
                expect(color.green, equals(0x3C));
                expect(color.blue, equals(0x43));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns correct base color in dark mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final color = GlassVibrancy.secondaryText(
                  context,
                  tier: GlassTier.standard,
                );
                // Base color is #EBEBF5
                expect(color.red, equals(0xEB));
                expect(color.green, equals(0xEB));
                expect(color.blue, equals(0xF5));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('applies 60% base alpha on overlay tier in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final overlayColor =
                    GlassVibrancy.secondaryText(context, tier: GlassTier.overlay);
                // 60% of 255 = 153
                expect(overlayColor.alpha, 153);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('boosts alpha to 70% on standard tier in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final color = GlassVibrancy.secondaryText(
                  context,
                  tier: GlassTier.standard,
                );
                // (0.6 + 0.1) * 255 = 178.5 = 179
                expect(color.alpha, 179);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('standard tier alpha is higher than overlay tier',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final standardAlpha =
                    GlassVibrancy.secondaryText(context, tier: GlassTier.standard).alpha;
                final overlayAlpha =
                    GlassVibrancy.secondaryText(context, tier: GlassTier.overlay).alpha;

                expect(standardAlpha, greaterThan(overlayAlpha));
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('tertiaryText', () {
      testWidgets('returns correct base color in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final color = GlassVibrancy.tertiaryText(
                  context,
                  tier: GlassTier.standard,
                );
                // Base color is #3C3C43
                expect(color.red, equals(0x3C));
                expect(color.green, equals(0x3C));
                expect(color.blue, equals(0x43));
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('applies 30% base alpha on overlay tier in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final overlayColor =
                    GlassVibrancy.tertiaryText(context, tier: GlassTier.overlay);
                // 30% of 255 = 76.5 = 77
                expect(overlayColor.alpha, 77);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('boosts alpha to 45% on standard tier in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final color = GlassVibrancy.tertiaryText(
                  context,
                  tier: GlassTier.standard,
                );
                // (0.3 + 0.15) * 255 = 114.75 = 115
                expect(color.alpha, 115);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('standard tier alpha is higher than overlay tier',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final standardAlpha =
                    GlassVibrancy.tertiaryText(context, tier: GlassTier.standard).alpha;
                final overlayAlpha =
                    GlassVibrancy.tertiaryText(context, tier: GlassTier.overlay).alpha;

                expect(standardAlpha, greaterThan(overlayAlpha));
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });
  });
}
