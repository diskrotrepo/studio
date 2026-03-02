import 'dart:ui' as ui;

import 'visualizer_type.dart';

/// Loads and caches the three fragment-shader programs.  Loading is triggered
/// once and the programs are reused across the application.
class ShaderCache {
  static ui.FragmentProgram? _creamdrop;
  static ui.FragmentProgram? _waveform;
  static ui.FragmentProgram? _spectrum;
  static bool _loading = false;
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    _creamdrop =
        await ui.FragmentProgram.fromAsset('shaders/creamdrop.frag');
    _waveform =
        await ui.FragmentProgram.fromAsset('shaders/waveform.frag');
    _spectrum =
        await ui.FragmentProgram.fromAsset('shaders/spectrum.frag');
    _loaded = true;
    _loading = false;
  }

  static ui.FragmentProgram? forType(VisualizerType type) {
    return switch (type) {
      VisualizerType.creamdrop => _creamdrop,
      VisualizerType.waveform => _waveform,
      VisualizerType.spectrum => _spectrum,
    };
  }
}
