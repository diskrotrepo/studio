import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'glitch_effects.dart';
import 'painters/glitch_background_painter.dart';
import 'painters/glitch_overlay_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  bool _imagesReady = false;

  @override
  void initState() {
    super.initState();
    // Remove the HTML loading placeholder so it doesn't show through.
    web.document.getElementById('loading')?.remove();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _master.addListener(() => setState(() {}));
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesReady) {
      _imagesReady = true;
      precacheImage(
        const AssetImage('assets/tropical_slashes_black.png'),
        context,
      ).then((_) {
        if (mounted) _master.forward();
      });
    }
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  /// Noise seed that changes every ~200ms for a calmer visual rhythm.
  int get _noiseSeed => (DateTime.now().millisecondsSinceEpoch ~/ 200);

  @override
  Widget build(BuildContext context) {
    final p = _master.value;
    // Fade-out progress: 0.0 during splash, ramps to 1.0 at the end.
    final whiteOverlay = 1.0 - GlitchEffects.splashOpacity(p);

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Layer 1: background effects (noise, scanlines, scan beam)
          Positioned.fill(
            child: CustomPaint(
              painter: GlitchBackgroundPainter(
                progress: p,
                seed: _noiseSeed,
              ),
            ),
          ),

          // Layer 2: centered branding (text overlays image)
          Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _buildSlashesIcon(p),
                _buildBrandText(p),
              ],
            ),
          ),

          // Layer 3: overlay effects (block displacement, accent bleeds)
          Positioned.fill(
            child: CustomPaint(
              painter: GlitchOverlayPainter(
                progress: p,
                seed: _noiseSeed,
              ),
            ),
          ),

          // Layer 4: subtle tint shifts (reduced from flashes for seizure safety)
          if (p > 0.54 && p < 0.68)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),

          // Layer 5: white fade-out overlay
          if (whiteOverlay > 0.0)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: whiteOverlay),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlashesIcon(double progress) {
    final iconOpacity = GlitchEffects.iconOpacity(progress);
    if (iconOpacity <= 0) return const SizedBox(width: 280, height: 240);

    final channelOffset = GlitchEffects.channelSeparation(progress);
    final shake = GlitchEffects.iconShake(progress);
    final scale = GlitchEffects.iconScale(progress);
    final rotation = GlitchEffects.iconRotation(progress);
    const size = 200.0;

    // Deterministic shake displacement from noise seed
    final shakeX = shake * ((_noiseSeed % 7) / 3.0 - 1.0);
    final shakeY = shake * 0.6 * ((_noiseSeed % 5) / 2.5 - 1.0);

    Widget img({Color? tint, double opacity = 1.0}) {
      Widget image = Image.asset(
        'assets/tropical_slashes_black.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
      if (tint != null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
          child: image,
        );
      }
      if (opacity < 1.0) {
        image = Opacity(opacity: opacity, child: image);
      }
      return image;
    }

    final icon = SizedBox(
      width: size + 80,
      height: size + 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Red channel (shifted left-up)
          if (channelOffset > 0.5)
            Transform.translate(
              offset: Offset(-channelOffset, -channelOffset * 0.4),
              child: img(tint: const Color(0xFFFF0040), opacity: 0.55),
            ),
          // Green channel (shifted up-right)
          if (channelOffset > 2.0)
            Transform.translate(
              offset: Offset(channelOffset * 0.5, -channelOffset * 0.7),
              child: img(tint: const Color(0xFF00FF80), opacity: 0.35),
            ),
          // Main image (center)
          img(),
          // Blue channel (shifted right-down)
          if (channelOffset > 0.5)
            Transform.translate(
              offset: Offset(channelOffset, channelOffset * 0.5),
              child: img(tint: const Color(0xFF4488FF), opacity: 0.55),
            ),
          // Magenta echo removed for seizure safety
        ],
      ),
    );

    // Apply shake, scale, and rotation transforms
    Widget result = Transform.translate(
      offset: Offset(shakeX, shakeY),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: icon,
        ),
      ),
    );

    return Opacity(opacity: iconOpacity, child: result);
  }

  static const _brandText = 's t u d i o ///diskrot';
  static const _glitchChars = r'!@#$%^&*<>{}[]|/\~`░▒▓█▄▀';

  Widget _buildBrandText(double progress) {
    if (progress < 0.15) return const SizedBox.shrink();

    final charDisplacement = GlitchEffects.charDisplacementIntensity(progress);
    final resolveProgress = GlitchEffects.textResolveProgress(progress);
    final channelOffset = GlitchEffects.channelSeparation(progress) * 0.6;
    final rng = Random(_noiseSeed + 99);

    // Build per-character widgets
    final chars = <Widget>[];
    for (int i = 0; i < _brandText.length; i++) {
      final resolved = i / _brandText.length < resolveProgress;
      final char = resolved
          ? _brandText[i]
          : _glitchChars[rng.nextInt(_glitchChars.length)];

      final dy =
          resolved ? 0.0 : (rng.nextDouble() - 0.5) * 60 * charDisplacement;
      final dx =
          resolved ? 0.0 : (rng.nextDouble() - 0.5) * 24 * charDisplacement;

      chars.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Text(
            char,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              decoration: TextDecoration.none,
              color: resolved
                  ? Colors.white
                  : Color.lerp(
                      const Color(0xFFFF0040),
                      const Color(0xFF4488FF),
                      rng.nextDouble(),
                    ),
            ),
          ),
        ),
      );
    }

    final textRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: chars,
    );

    // Stack with channel-split copies
    Widget result = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (channelOffset > 1.0)
          Transform.translate(
            offset: Offset(-channelOffset, -channelOffset * 0.3),
            child: Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFF0040),
                  BlendMode.modulate,
                ),
                child: textRow,
              ),
            ),
          ),
        textRow,
        if (channelOffset > 1.0)
          Transform.translate(
            offset: Offset(channelOffset, channelOffset * 0.3),
            child: Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF4488FF),
                  BlendMode.modulate,
                ),
                child: textRow,
              ),
            ),
          ),
      ],
    );

    final textOpacity = progress < 0.20
        ? ((progress - 0.15) / 0.05).clamp(0.0, 1.0)
        : 1.0;

    return Opacity(
      opacity: textOpacity,
      child: result,
    );
  }
}
