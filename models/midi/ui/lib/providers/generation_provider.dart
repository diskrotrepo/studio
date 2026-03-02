import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/generation_params.dart';
import '../models/multitrack_params.dart';
import '../services/persistence_service.dart';

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

class SingleTrackFormNotifier extends StateNotifier<GenerationParams> {
  final PersistenceService _persistence;

  SingleTrackFormNotifier(this._persistence)
      : super(_persistence.loadSingleTrackParams() ?? const GenerationParams());

  void _save() => _persistence.saveSingleTrackParams(state);

  void updateTags(String? tags) { state = state.copyWith(tags: tags, clearTags: tags == null); _save(); }
  void updateDuration(int v) { state = state.copyWith(duration: v); _save(); }
  void updateBpm(int v) { state = state.copyWith(bpm: v); _save(); }
  void updateTemperature(double v) { state = state.copyWith(temperature: v); _save(); }
  void updateTopK(int v) { state = state.copyWith(topK: v); _save(); }
  void updateTopP(double v) { state = state.copyWith(topP: v); _save(); }
  void updateRepetitionPenalty(double v) { state = state.copyWith(repetitionPenalty: v); _save(); }
  void updateHumanize(String? v) { state = state.copyWith(humanize: v, clearHumanize: v == null); _save(); }
  void updateSeed(int? v) { state = state.copyWith(seed: v, clearSeed: v == null); _save(); }
  void updateExtendFrom(double? v) { state = state.copyWith(extendFrom: v, clearExtendFrom: v == null); _save(); }
  void updateModel(String v) { state = state.copyWith(model: v); _save(); }
  void reset() { state = const GenerationParams(); _save(); }
}

final singleTrackFormProvider =
    StateNotifierProvider<SingleTrackFormNotifier, GenerationParams>(
  (ref) => SingleTrackFormNotifier(ref.watch(persistenceServiceProvider)),
);

class MultiTrackFormNotifier extends StateNotifier<MultitrackParams> {
  final PersistenceService _persistence;

  MultiTrackFormNotifier(this._persistence)
      : super(_persistence.loadMultiTrackParams() ??
            const MultitrackParams(base: GenerationParams()));

  void _save() => _persistence.saveMultiTrackParams(state);

  void updateBase(GenerationParams base) { state = state.copyWith(base: base); _save(); }
  void updateTags(String? tags) { state = state.copyWith(
      base: state.base.copyWith(tags: tags, clearTags: tags == null)); _save(); }
  void updateDuration(int v) { state = state.copyWith(
      base: state.base.copyWith(duration: v)); _save(); }
  void updateBpm(int v) { state = state.copyWith(
      base: state.base.copyWith(bpm: v)); _save(); }
  void updateTemperature(double v) { state = state.copyWith(
      base: state.base.copyWith(temperature: v)); _save(); }
  void updateTopK(int v) { state = state.copyWith(
      base: state.base.copyWith(topK: v)); _save(); }
  void updateTopP(double v) { state = state.copyWith(
      base: state.base.copyWith(topP: v)); _save(); }
  void updateRepetitionPenalty(double v) { state = state.copyWith(
      base: state.base.copyWith(repetitionPenalty: v)); _save(); }
  void updateHumanize(String? v) { state = state.copyWith(
      base: state.base.copyWith(humanize: v, clearHumanize: v == null)); _save(); }
  void updateSeed(int? v) { state = state.copyWith(
      base: state.base.copyWith(seed: v, clearSeed: v == null)); _save(); }
  void updateNumTracks(int v) { state = state.copyWith(numTracks: v); _save(); }
  void updateTrackTypes(List<String>? v) {
      state = state.copyWith(trackTypes: v, clearTrackTypes: v == null); _save(); }
  void updateInstruments(List<int>? v) {
      state = state.copyWith(instruments: v, clearInstruments: v == null); _save(); }
  void updateModel(String v) { state = state.copyWith(
      base: state.base.copyWith(model: v)); _save(); }
  void reset() { state = const MultitrackParams(base: GenerationParams()); _save(); }
}

final multiTrackFormProvider =
    StateNotifierProvider<MultiTrackFormNotifier, MultitrackParams>(
  (ref) => MultiTrackFormNotifier(ref.watch(persistenceServiceProvider)),
);
