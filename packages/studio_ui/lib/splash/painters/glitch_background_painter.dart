import 'dart:math';

import 'package:flutter/material.dart';

import '../glitch_effects.dart';

class GlitchBackgroundPainter extends CustomPainter {
  GlitchBackgroundPainter({required this.progress, required this.seed});

  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    _drawScanlines(canvas, size);
    _drawNoise(canvas, size, rng);
    _drawScanBeam(canvas, size);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final opacity = GlitchEffects.scanlineOpacity(progress);
    if (opacity <= 0.001) return;

    final paint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, opacity)
      ..style = PaintingStyle.fill;

    for (double y = 0; y < size.height; y += 3.0) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.0), paint);
    }
  }

  void _drawNoise(Canvas canvas, Size size, Random rng) {
    final density = GlitchEffects.noiseDensity(progress);
    if (density <= 0.001) return;

    final blockCount = (density * 600).toInt();
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < blockCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 2.0 + rng.nextDouble() * 10.0;
      final h = 1.0 + rng.nextDouble() * 3.0;
      final brightness = rng.nextInt(200);
      paint.color = Color.fromRGBO(
        brightness,
        brightness,
        brightness,
        0.15 + rng.nextDouble() * 0.35,
      );
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }
  }

  void _drawScanBeam(Canvas canvas, Size size) {
    if (progress > 0.22) return;
    final beamY = (progress / 0.22) * size.height;

    final paint = Paint()
      ..color = const Color(0xFF1E88E5).withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawLine(Offset(0, beamY), Offset(size.width, beamY), paint);

    final trailPaint = Paint()
      ..color = const Color(0xFF1E88E5).withValues(alpha: 0.10)
      ..strokeWidth = 12.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawLine(
      Offset(0, beamY - 4),
      Offset(size.width, beamY - 4),
      trailPaint,
    );
  }

  @override
  bool shouldRepaint(GlitchBackgroundPainter oldDelegate) => true;
}
