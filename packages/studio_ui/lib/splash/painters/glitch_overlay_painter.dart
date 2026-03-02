import 'dart:math';

import 'package:flutter/material.dart';

import '../glitch_effects.dart';

class GlitchOverlayPainter extends CustomPainter {
  GlitchOverlayPainter({required this.progress, required this.seed});

  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed + 42); // offset seed from background painter
    _drawBlockDisplacement(canvas, size, rng);
    _drawAccentBleeds(canvas, size, rng);
  }

  void _drawBlockDisplacement(Canvas canvas, Size size, Random rng) {
    final intensity = GlitchEffects.blockDisplacementIntensity(progress);
    if (intensity <= 0.01) return;

    final bandCount = 4 + (intensity * 10).toInt();
    for (int i = 0; i < bandCount; i++) {
      final y = rng.nextDouble() * size.height;
      final h = 8.0 + rng.nextDouble() * 120.0 * intensity;
      final xOffset = (rng.nextDouble() - 0.5) * 400.0 * intensity;

      final bandPaint = Paint()
        ..color = Color.fromRGBO(
          12 + rng.nextInt(40),
          12 + rng.nextInt(24),
          12 + rng.nextInt(40),
          0.5 + rng.nextDouble() * 0.5,
        )
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(xOffset, y, size.width, h), bandPaint);
    }
  }

  void _drawAccentBleeds(Canvas canvas, Size size, Random rng) {
    final intensity = GlitchEffects.blockDisplacementIntensity(progress);
    if (intensity <= 0.05) return;

    final lineCount = (intensity * 16).toInt();
    final colors = [
      const Color(0xFFEC407A),
      const Color(0xFF1E88E5),
      const Color(0xFF00FF80),
      const Color(0xFFFF0040),
    ];
    for (int i = 0; i < lineCount; i++) {
      if (rng.nextDouble() > 0.6) continue;
      final y = rng.nextDouble() * size.height;
      final color = colors[rng.nextInt(colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.4 * intensity)
        ..strokeWidth = 1.0 + rng.nextDouble() * 3.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GlitchOverlayPainter oldDelegate) => true;
}
