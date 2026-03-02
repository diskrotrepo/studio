/// Pure functions that compute glitch effect intensities from animation progress.
/// Progress is 0.0 (start) to 1.0 (end of 4s timeline).
class GlitchEffects {
  GlitchEffects._();

  // Phase boundaries — continuous build, no hold at end.
  // boot: 0.00–0.10  (quick ramp)
  // signal: 0.10–0.28 (intensify)
  // glitch: 0.28–0.52 (peak chaos)
  // resolve: 0.52–0.78 (text snaps in, effects decay)
  // fadeout: 0.78–1.0  (transition out)
  static const double _boot = 0.10;
  static const double _signal = 0.28;
  static const double _glitch = 0.52;
  static const double _resolve = 0.78;

  /// Noise density: moderate levels, reduced for seizure safety.
  static double noiseDensity(double p) {
    if (p < _boot) return 0.2 + p / _boot * 0.1;
    if (p < _signal) return 0.3 - (p - _boot) / (_signal - _boot) * 0.1;
    if (p < _glitch) return 0.2 + (p - _signal) / (_glitch - _signal) * 0.2;
    if (p < _resolve) {
      return 0.4 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// RGB channel separation in pixels (max ~15px, reduced for seizure safety).
  static double channelSeparation(double p) {
    if (p < _boot) return 0.0;
    if (p < _signal) return (p - _boot) / (_signal - _boot) * 8.0;
    if (p < _glitch) return 8.0 + (p - _signal) / (_glitch - _signal) * 7.0;
    if (p < _resolve) {
      return 15.0 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// Icon horizontal shake intensity in pixels (reduced for seizure safety).
  static double iconShake(double p) {
    if (p < _boot) return 0.0;
    if (p < _signal) return (p - _boot) / (_signal - _boot) * 4.0;
    if (p < _glitch) return 4.0 + (p - _signal) / (_glitch - _signal) * 8.0;
    if (p < _resolve) {
      return 12.0 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// Icon scale multiplier (1.0 = normal, gentle pulse during glitch).
  static double iconScale(double p) {
    if (p < _signal) return 1.0;
    if (p < _glitch) {
      final t = (p - _signal) / (_glitch - _signal);
      return 1.0 + 0.08 * _triangle(t * 3.0) * t;
    }
    if (p < _resolve) {
      final t = 1.0 - (p - _glitch) / (_resolve - _glitch);
      return 1.0 + 0.05 * _triangle(t * 2.0) * t;
    }
    return 1.0;
  }

  /// Icon rotation in radians (gentle tilts during glitch).
  static double iconRotation(double p) {
    if (p < _signal) return 0.0;
    if (p < _glitch) {
      final t = (p - _signal) / (_glitch - _signal);
      return 0.04 * _triangle(t * 4.0) * t;
    }
    if (p < _resolve) {
      final t = 1.0 - (p - _glitch) / (_resolve - _glitch);
      return 0.03 * _triangle(t * 2.0) * t;
    }
    return 0.0;
  }

  /// Triangle wave helper: oscillates -1..1 over period 1.
  static double _triangle(double t) {
    final v = t % 1.0;
    return v < 0.5 ? (v * 4.0 - 1.0) : (3.0 - v * 4.0);
  }

  /// Block displacement band intensity (reduced for seizure safety).
  static double blockDisplacementIntensity(double p) {
    if (p < _boot) return 0.05;
    if (p < _signal) return 0.05 + (p - _boot) / (_signal - _boot) * 0.15;
    if (p < _glitch) return 0.2 + (p - _signal) / (_glitch - _signal) * 0.15;
    if (p < _resolve) {
      return 0.35 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// Scanline overlay opacity (0.0–0.20).
  static double scanlineOpacity(double p) {
    if (p < _glitch) return 0.20;
    if (p < _resolve) {
      return 0.20 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// Character displacement intensity for brand text (reduced for seizure safety).
  static double charDisplacementIntensity(double p) {
    if (p < 0.18) return 0.0;
    if (p < _glitch) return (p - 0.18) / (_glitch - 0.18) * 0.4;
    if (p < _resolve) {
      return 0.4 * (1.0 - (p - _glitch) / (_resolve - _glitch));
    }
    return 0.0;
  }

  /// Text resolve: characters snap into place L-to-R (0.0–1.0).
  static double textResolveProgress(double p) {
    if (p < 0.54) return 0.0;
    if (p < 0.70) return (p - 0.54) / 0.16;
    return 1.0;
  }

  /// Slashes icon opacity (smooth fade-in, no strobing).
  static double iconOpacity(double p) {
    if (p < 0.04) return 0.0;
    if (p < _boot) return (p - 0.04) / (_boot - 0.04) * 0.5;
    if (p < _signal) return 0.5 + (p - _boot) / (_signal - _boot) * 0.5;
    return 1.0;
  }

  /// Overall splash opacity (fade-out at the very end).
  static double splashOpacity(double p) {
    if (p < _resolve) return 1.0;
    return 1.0 - (p - _resolve) / (1.0 - _resolve);
  }
}
