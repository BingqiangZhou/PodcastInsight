import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fresnel Painter
///
/// Paints a gradient stroke along a rounded rect border path.
/// The gradient goes from borderTopColor (top edge) to borderBottomColor
/// (bottom edge), simulating the Fresnel effect where edges are brighter.
class FresnelPainter extends CustomPainter {
  const FresnelPainter({
    required this.borderRadius,
    required this.borderTopColor,
    required this.borderBottomColor,
    this.opacity = 1.0,
  });

  final BorderRadius borderRadius;
  final Color borderTopColor;
  final Color borderBottomColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = borderRadius.toRRect(rect);

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        borderTopColor.withValues(alpha: borderTopColor.alpha * opacity),
        borderBottomColor.withValues(alpha: borderBottomColor.alpha * opacity),
      ],
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant FresnelPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderTopColor != borderTopColor ||
        oldDelegate.borderBottomColor != borderBottomColor ||
        oldDelegate.opacity != opacity;
  }
}

/// Specular Painter
///
/// Paints a moving radial gradient highlight on the glass surface.
/// Position follows animation value: angle = animationValue * 2 * pi.
/// Creates a subtle white highlight that rotates around the surface.
class SpecularPainter extends CustomPainter {
  const SpecularPainter({
    required this.animationValue,
    this.opacity = 0.05,
  });

  final double animationValue;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = animationValue * 2 * math.pi;

    // Highlight position moves in circular pattern
    final highlightX = center.dx + math.cos(angle) * size.width * 0.3;
    final highlightY = center.dy + math.sin(angle) * size.height * 0.3;
    final highlightCenter = Offset(highlightX, highlightY);

    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFFFFFF).withValues(alpha: opacity),
        const Color(0xFFFFFFFF).withValues(alpha: 0.0),
      ],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(
        center: highlightCenter,
        radius: 40,
      ))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(highlightCenter, 40, paint);
  }

  @override
  bool shouldRepaint(covariant SpecularPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

/// Noise Painter
///
/// Paints procedural noise texture across the glass surface.
/// Uses a cached ui.Image (64x64, generated with seed 42) that is
/// tiled across the widget size. Adds subtle texture to the glass.
class NoisePainter extends CustomPainter {
  const NoisePainter({
    required this.noiseImage,
    this.opacity = 0.04,
  });

  final ui.Image? noiseImage;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (noiseImage == null) return;

    final paint = Paint()
      ..imageFilter = ui.ColorFilter.mode(
        const Color(0xFFFFFFFF).withValues(alpha: opacity),
        BlendMode.dstATop,
      );

    // Tile the noise image across the surface
    for (double x = 0; x < size.width; x += 64) {
      for (double y = 0; y < size.height; y += 64) {
        final src = Rect.fromLTWH(0, 0, 64, 64);
        final dst = Rect.fromLTWH(x, y, 64.0, 64.0);
        canvas.drawImageRect(noiseImage!, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NoisePainter oldDelegate) {
    return oldDelegate.noiseImage != noiseImage ||
        oldDelegate.opacity != opacity;
  }
}

/// Generate noise texture image
///
/// Creates a 64x64 noise texture with the given seed.
/// Uses a simple random number generator for reproducibility.
/// Returns null if generation fails.
Future<ui.Image?> generateNoiseImage({int seed = 42}) async {
  const size = 64;

  // Create a simple RGBA bitmap
  final bytes = Uint8List(size * size * 4);

  // Simple seeded random number generator
  var randomState = seed;

  int nextRandom() {
    randomState = (randomState * 1103515245 + 12345) & 0x7FFFFFFF;
    return randomState;
  }

  for (int i = 0; i < size * size; i++) {
    final value = nextRandom() & 0xFF;
    final index = i * 4;
    bytes[index] = value; // R
    bytes[index + 1] = value; // G
    bytes[index + 2] = value; // B
    bytes[index + 3] = 255; // A
  }

  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size,
      targetHeight: size,
    );

    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (e) {
    // In test environments, codec may not be available
    return null;
  }
}
