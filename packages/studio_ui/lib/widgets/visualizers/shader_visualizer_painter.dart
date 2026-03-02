import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A [CustomPainter] that renders a GPU fragment shader with audio-reactive
/// uniforms.
///
/// The visual style is determined entirely by the [shader] program passed in
/// (creamdrop, waveform, or spectrum).  All shaders share the same 10-float
/// uniform layout.
class ShaderVisualizerPainter extends CustomPainter {
  ShaderVisualizerPainter({
    required this.shader,
    required this.time,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.beat,
    required this.colorSeed,
    required this.selected,
    required this.playbackProgress,
  });

  final ui.FragmentShader shader;
  final double time;
  final double bass;
  final double mid;
  final double treble;
  final double beat;

  /// Hue base (0–360).
  final double colorSeed;
  final bool selected;

  /// 0.0–1.0 or null (encoded as -1.0 in the shader).
  final double? playbackProgress;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, bass);
    shader.setFloat(4, mid);
    shader.setFloat(5, treble);
    shader.setFloat(6, beat);
    shader.setFloat(7, colorSeed);
    shader.setFloat(8, selected ? 1.0 : 0.0);
    shader.setFloat(9, playbackProgress ?? -1.0);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(ShaderVisualizerPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.bass != bass ||
      oldDelegate.mid != mid ||
      oldDelegate.treble != treble ||
      oldDelegate.beat != beat ||
      oldDelegate.colorSeed != colorSeed ||
      oldDelegate.selected != selected ||
      oldDelegate.playbackProgress != playbackProgress;
}
