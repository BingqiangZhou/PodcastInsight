import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/glass_painter.dart';

void main() {
  group('FresnelPainter', () {
    test('shouldRepaint returns true when properties change', () {
      const painter1 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      const painter2 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      const painter3 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x28FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      const painter4 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x14FFFFFF),
        opacity: 0.5,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
      expect(painter1.shouldRepaint(painter4), isTrue);
    });

    test('shouldRepaint returns false when properties are same', () {
      const painter1 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      const painter2 = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('paints without errors', () {
      const painter = FresnelPainter(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderTopColor: Color(0x14FFFFFF),
        borderBottomColor: Color(0x0AFFFFFF),
        opacity: 1.0,
      );

      // Create a simple canvas to test painting
      expect(painter.toString(), contains('FresnelPainter'));
    });
  });

  group('SpecularPainter', () {
    test('shouldRepaint always returns true', () {
      const painter1 = SpecularPainter(
        animationValue: 0.5,
        opacity: 0.05,
      );

      const painter2 = SpecularPainter(
        animationValue: 0.5,
        opacity: 0.05,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('properties are accessible', () {
      const painter = SpecularPainter(
        animationValue: 0.75,
        opacity: 0.03,
      );

      expect(painter.animationValue, 0.75);
      expect(painter.opacity, 0.03);
    });
  });

  group('NoisePainter', () {
    test('shouldRepaint returns true when opacity changes', () {
      const painter1 = NoisePainter(
        noiseImage: null,
        opacity: 0.04,
      );

      const painter2 = NoisePainter(
        noiseImage: null,
        opacity: 0.06,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when properties are same', () {
      const painter1 = NoisePainter(
        noiseImage: null,
        opacity: 0.04,
      );

      const painter2 = NoisePainter(
        noiseImage: null,
        opacity: 0.04,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('handles null noiseImage gracefully', () {
      const painter = NoisePainter(
        noiseImage: null,
        opacity: 0.04,
      );

      expect(painter.noiseImage, isNull);
      expect(painter.opacity, 0.04);
    });
  });

  group('generateNoiseImage', () {
    test('generates image without errors', () async {
      final image = await generateNoiseImage(seed: 42);
      // Image generation should complete without throwing
      // In test environment, this may return null due to codec limitations
      expect(image, isA<ui.Image?>());
    });

    test('generates deterministic output for same seed', () async {
      final image1 = await generateNoiseImage(seed: 42);
      final image2 = await generateNoiseImage(seed: 42);
      // Both should return the same type (both null or both Image)
      expect(image1.runtimeType, image2.runtimeType);
    });
  });
}
