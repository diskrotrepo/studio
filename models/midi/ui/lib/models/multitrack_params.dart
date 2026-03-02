import 'generation_params.dart';

class MultitrackParams {
  final GenerationParams base;
  final int numTracks;
  final List<String>? trackTypes;
  final List<int>? instruments;

  const MultitrackParams({
    required this.base,
    this.numTracks = 4,
    this.trackTypes,
    this.instruments,
  });

  MultitrackParams copyWith({
    GenerationParams? base,
    int? numTracks,
    List<String>? trackTypes,
    List<int>? instruments,
    bool clearTrackTypes = false,
    bool clearInstruments = false,
  }) {
    return MultitrackParams(
      base: base ?? this.base,
      numTracks: numTracks ?? this.numTracks,
      trackTypes: clearTrackTypes ? null : (trackTypes ?? this.trackTypes),
      instruments: clearInstruments ? null : (instruments ?? this.instruments),
    );
  }

  factory MultitrackParams.fromJson(Map<String, dynamic> json) {
    return MultitrackParams(
      base: GenerationParams.fromJson(json),
      numTracks: json['num_tracks'] as int? ?? 4,
      trackTypes: (json['track_types'] as List<dynamic>?)?.cast<String>(),
      instruments: (json['instruments'] as List<dynamic>?)?.cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = base.toJson();
    json['num_tracks'] = numTracks;
    if (trackTypes != null) json['track_types'] = trackTypes;
    if (instruments != null) json['instruments'] = instruments;
    return json;
  }
}
