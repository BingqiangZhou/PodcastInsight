import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

void main() {
  group('GlassTier', () {
    test('has correct sigma values', () {
      expect(GlassTier.standard.sigma, 20);
      expect(GlassTier.overlay.sigma, 30);
    });

    test('has exactly 2 values', () {
      expect(GlassTier.values.length, 2);
    });
  });

  group('GlassTokens', () {
    group('dark mode factory', () {
      const tokens = GlassTokens.dark();

      test('has dark brightness', () {
        expect(tokens.brightness, Brightness.dark);
      });

      test('standard params match spec', () {
        final params = tokens.standard;
        expect(params.fill, const Color(0x0FFFFFFF)); // white 6%
        expect(params.sigma, 20);
      });

      test('overlay params match spec', () {
        final params = tokens.overlay;
        expect(params.fill, const Color(0x1AFFFFFF)); // white 10%
        expect(params.sigma, 30);
      });

      test('paramsForTier returns correct params', () {
        expect(tokens.paramsForTier(GlassTier.standard), same(tokens.standard));
        expect(tokens.paramsForTier(GlassTier.overlay), same(tokens.overlay));
      });

      test('glassFill returns standard tier fill', () {
        expect(tokens.glassFill, tokens.standard.fill);
      });
    });

    group('light mode factory', () {
      const tokens = GlassTokens.light();

      test('has light brightness', () {
        expect(tokens.brightness, Brightness.light);
      });

      test('standard params match spec', () {
        final params = tokens.standard;
        expect(params.fill, const Color(0x0D000000)); // black 5%
        expect(params.sigma, 20);
      });

      test('overlay params match spec', () {
        final params = tokens.overlay;
        expect(params.fill, const Color(0x14000000)); // black 8%
        expect(params.sigma, 30);
      });

      test('glassFill returns standard tier fill', () {
        expect(tokens.glassFill, tokens.standard.fill);
      });
    });
  });
}
