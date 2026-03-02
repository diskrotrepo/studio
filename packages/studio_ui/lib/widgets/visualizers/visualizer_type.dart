/// Identifies the available visualizer styles.
enum VisualizerType {
  creamdrop,
  waveform,
  spectrum;

  /// Parses a stored settings string back to the enum.
  /// Returns [creamdrop] for null or unrecognised values.
  static VisualizerType fromSettingsValue(String? value) {
    if (value == null) return VisualizerType.creamdrop;
    return VisualizerType.values.firstWhere(
      (v) => v.name == value,
      orElse: () => VisualizerType.creamdrop,
    );
  }

  /// The string value persisted in the settings database.
  String get settingsValue => name;

  /// Human-readable label (English; localised labels live in ARB).
  String get label => switch (this) {
        VisualizerType.creamdrop => 'Creamdrop',
        VisualizerType.waveform => 'Waveform',
        VisualizerType.spectrum => 'Spectrum',
      };
}
