import 'generation_params.dart';

class AddTrackParams {
  final GenerationParams base;
  final String trackType;
  final int? instrument;

  const AddTrackParams({
    required this.base,
    this.trackType = 'melody',
    this.instrument,
  });

  Map<String, String> toFormFields() {
    final fields = base.toFormFields();
    fields['track_type'] = trackType;
    if (instrument != null) fields['instrument'] = instrument.toString();
    return fields;
  }
}

class ReplaceTrackParams {
  final GenerationParams base;
  final int trackIndex;
  final String? trackType;
  final int? instrument;
  final String? replaceBars;

  const ReplaceTrackParams({
    required this.base,
    required this.trackIndex,
    this.trackType,
    this.instrument,
    this.replaceBars,
  });

  Map<String, String> toFormFields() {
    final fields = base.toFormFields();
    fields['track_index'] = trackIndex.toString();
    if (trackType != null) fields['track_type'] = trackType!;
    if (instrument != null) fields['instrument'] = instrument.toString();
    if (replaceBars != null) fields['replace_bars'] = replaceBars!;
    return fields;
  }
}

class CoverParams {
  final GenerationParams base;
  final int? numTracks;
  final List<String>? trackTypes;
  final List<int>? instruments;

  const CoverParams({
    required this.base,
    this.numTracks,
    this.trackTypes,
    this.instruments,
  });

  Map<String, String> toFormFields() {
    final fields = base.toFormFields();
    if (numTracks != null) fields['num_tracks'] = numTracks.toString();
    if (trackTypes != null) fields['track_types'] = trackTypes!.join(',');
    if (instruments != null) {
      fields['instruments'] = instruments!.map((i) => i.toString()).join(',');
    }
    return fields;
  }
}
