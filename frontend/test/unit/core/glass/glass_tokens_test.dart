import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

void main() {
  group('GlassTier', () {
    test('has correct sigma values', () {
      expect(GlassTier.ultraHeavy.sigma, 28);
      expect(GlassTier.heavy.sigma, 20);
      expect(GlassTier.medium.sigma, 14);
      expect(GlassTier.light.sigma, 8);
    });
  });

  group('GlassTokens', () {
    group('dark mode factory', () {
      const tokens = GlassTokens.dark();

      test('has dark brightness', () {
        expect(tokens.brightness, Brightness.dark);
      });

      test('ultraHeavy params match spec', () {
        final params = tokens.ultraHeavy;
        expect(params.fill, const Color(0x0AFFFFFF));
        expect(params.borderTop, const Color(0x14FFFFFF));
        expect(params.borderBottom, const Color(0x0AFFFFFF));
        expect(params.innerGlow, const Color(0x08FFFFFF));
        expect(params.shadow, const Color(0x80000000));
        expect(params.saturationBoost, 2.0);
        expect(params.noiseOpacity, 0.06);
      });

      test('heavy params match spec', () {
        final params = tokens.heavy;
        expect(params.fill, const Color(0x0DFFFFFF));
        expect(params.borderTop, const Color(0x19FFFFFF));
        expect(params.borderBottom, const Color(0x0DFFFFFF));
        expect(params.innerGlow, const Color(0x0AFFFFFF));
        expect(params.shadow, const Color(0x66000000));
        expect(params.saturationBoost, 1.8);
        expect(params.noiseOpacity, 0.05);
      });

      test('medium params match spec', () {
        final params = tokens.medium;
        expect(params.fill, const Color(0x0FFFFFFF));
        expect(params.borderTop, const Color(0x21FFFFFF));
        expect(params.borderBottom, const Color(0x12FFFFFF));
        expect(params.innerGlow, const Color(0x0DFFFFFF));
        expect(params.shadow, const Color(0x4D000000));
        expect(params.saturationBoost, 1.5);
        expect(params.noiseOpacity, 0.04);
      });

      test('light params match spec', () {
        final params = tokens.light;
        expect(params.fill, const Color(0x12FFFFFF));
        expect(params.borderTop, const Color(0x28FFFFFF));
        expect(params.borderBottom, const Color(0x14FFFFFF));
        expect(params.innerGlow, const Color(0x0FFFFFFF));
        expect(params.shadow, const Color(0x33000000));
        expect(params.saturationBoost, 1.3);
        expect(params.noiseOpacity, 0.03);
      });

      test('paramsForTier returns correct params', () {
        expect(tokens.paramsForTier(GlassTier.ultraHeavy), same(tokens.ultraHeavy));
        expect(tokens.paramsForTier(GlassTier.heavy), same(tokens.heavy));
        expect(tokens.paramsForTier(GlassTier.medium), same(tokens.medium));
        expect(tokens.paramsForTier(GlassTier.light), same(tokens.light));
      });

      test('glassFill returns medium tier fill', () {
        expect(tokens.glassFill, tokens.medium.fill);
      });
    });

    group('light mode factory', () {
      const tokens = GlassTokens.light();

      test('has light brightness', () {
        expect(tokens.brightness, Brightness.light);
      });

      test('ultraHeavy params match spec', () {
        final params = tokens.ultraHeavy;
        expect(params.fill, const Color(0x99FFFFFF));
        expect(params.borderTop, const Color(0xB2FFFFFF));
        expect(params.borderBottom, const Color(0x66FFFFFF));
        expect(params.innerGlow, const Color(0x26FFFFFF));
        expect(params.shadow, const Color(0x1F000000));
        expect(params.saturationBoost, 1.2);
        expect(params.noiseOpacity, 0.04);
      });

      test('heavy params match spec', () {
        final params = tokens.heavy;
        expect(params.fill, const Color(0x8CFFFFFF));
        expect(params.borderTop, const Color(0xA5FFFFFF));
        expect(params.borderBottom, const Color(0x59FFFFFF));
        expect(params.innerGlow, const Color(0x23FFFFFF));
        expect(params.shadow, const Color(0x19000000));
        expect(params.saturationBoost, 1.2);
        expect(params.noiseOpacity, 0.03);
      });

      test('medium params match spec', () {
        final params = tokens.medium;
        expect(params.fill, const Color(0x7FFFFFFF));
        expect(params.borderTop, const Color(0x99FFFFFF));
        expect(params.borderBottom, const Color(0x4DFFFFFF));
        expect(params.innerGlow, const Color(0x1EFFFFFF));
        expect(params.shadow, const Color(0x14000000));
        expect(params.saturationBoost, 1.15);
        expect(params.noiseOpacity, 0.03);
      });

      test('light params match spec', () {
        final params = tokens.light;
        expect(params.fill, const Color(0x72FFFFFF));
        expect(params.borderTop, const Color(0x8BFFFFFF));
        expect(params.borderBottom, const Color(0x3EFFFFFF));
        expect(params.innerGlow, const Color(0x19FFFFFF));
        expect(params.shadow, const Color(0x0F000000));
        expect(params.saturationBoost, 1.1);
        expect(params.noiseOpacity, 0.02);
      });

      test('glassFill returns medium tier fill', () {
        expect(tokens.glassFill, tokens.medium.fill);
      });
    });
  });
}
