import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/generation_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/model_selector.dart';
import '../../widgets/tag_selector.dart';
import '../../widgets/parameter_controls.dart';
import '../../widgets/track_type_selector.dart';
import '../../widgets/instrument_picker.dart';

class MultiTrackTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const MultiTrackTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<MultiTrackTab> createState() => _MultiTrackTabState();
}

class _MultiTrackTabState extends ConsumerState<MultiTrackTab> {
  final _selectedTags = <String>{};
  bool _submitting = false;
  bool _customTrackTypes = false;
  bool _customInstruments = false;

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(multiTrackFormProvider);
    final theme = Theme.of(context);

    // Build track types list for the selector
    final trackTypes = params.trackTypes ??
        List.generate(params.numTracks, (i) {
          const defaults = ['melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'];
          return defaults[i % defaults.length];
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model
          ModelSelector(
            selected: params.base.model,
            onChanged: ref.read(multiTrackFormProvider.notifier).updateModel,
          ),
          const SizedBox(height: 16),

          // Tags
          TagSelector(
            selectedTags: _selectedTags,
            onChanged: (tags) {
              setState(() => _selectedTags.clear());
              setState(() => _selectedTags.addAll(tags));
              ref.read(multiTrackFormProvider.notifier).updateTags(
                tags.isEmpty ? null : tags.join(' '),
              );
            },
          ),
          const SizedBox(height: 16),

          // Core parameters
          ParameterControls(
            duration: params.base.duration,
            bpm: params.base.bpm,
            temperature: params.base.temperature,
            onDurationChanged: ref.read(multiTrackFormProvider.notifier).updateDuration,
            onBpmChanged: ref.read(multiTrackFormProvider.notifier).updateBpm,
            onTemperatureChanged: ref.read(multiTrackFormProvider.notifier).updateTemperature,
          ),
          const SizedBox(height: 16),

          // Number of tracks
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  'Tracks',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: SquareThumbShape(),
                    thumbColor: AppColors.controlBlue,
                    activeTrackColor: AppColors.controlBlue,
                    overlayColor: AppColors.controlBlue.withValues(alpha: 0.2),
                    inactiveTrackColor: AppColors.border,
                    tickMarkShape: SliderTickMarkShape.noTickMark,
                  ),
                  child: Slider(
                    value: params.numTracks.toDouble(),
                    min: 1,
                    max: 16,
                    divisions: 15,
                    activeColor: AppColors.controlBlue,
                    label: '${params.numTracks}',
                    onChanged: (v) {
                      ref.read(multiTrackFormProvider.notifier).updateNumTracks(v.round());
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${params.numTracks}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom track types toggle
          SwitchListTile(
            title: const Text('Customize Track Types'),
            value: _customTrackTypes,
            activeTrackColor: AppColors.controlBlue,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.border,
            inactiveThumbColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              setState(() => _customTrackTypes = v);
              if (!v) {
                ref.read(multiTrackFormProvider.notifier).updateTrackTypes(null);
              }
            },
          ),
          if (_customTrackTypes) ...[
            TrackTypeSelector(
              trackTypes: trackTypes.take(params.numTracks).toList(),
              onChanged: (types) {
                ref.read(multiTrackFormProvider.notifier).updateTrackTypes(types);
              },
            ),
            const SizedBox(height: 16),
          ],

          // Custom instruments toggle
          SwitchListTile(
            title: const Text('Customize Instruments'),
            value: _customInstruments,
            activeTrackColor: AppColors.controlBlue,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.border,
            inactiveThumbColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              setState(() => _customInstruments = v);
              if (!v) {
                ref.read(multiTrackFormProvider.notifier).updateInstruments(null);
              }
            },
          ),
          if (_customInstruments) ...[
            ...List.generate(params.numTracks, (i) {
              final instruments = params.instruments ??
                  List.filled(params.numTracks, 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Track ${i + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InstrumentPicker(
                        selectedProgram: i < instruments.length ? instruments[i] : 0,
                        showAuto: false,
                        onChanged: (v) {
                          final updated = List<int>.from(
                            instruments.length >= params.numTracks
                                ? instruments
                                : List.filled(params.numTracks, 0),
                          );
                          updated[i] = v ?? 0;
                          ref.read(multiTrackFormProvider.notifier).updateInstruments(updated);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Advanced settings
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text('Advanced Settings', style: theme.textTheme.titleSmall),
              tilePadding: EdgeInsets.zero,
              children: [
                AdvancedControls(
                  topK: params.base.topK,
                  topP: params.base.topP,
                  repetitionPenalty: params.base.repetitionPenalty,
                  humanize: params.base.humanize,
                  seed: params.base.seed,
                  onTopKChanged: ref.read(multiTrackFormProvider.notifier).updateTopK,
                  onTopPChanged: ref.read(multiTrackFormProvider.notifier).updateTopP,
                  onRepetitionPenaltyChanged: ref.read(multiTrackFormProvider.notifier).updateRepetitionPenalty,
                  onHumanizeChanged: ref.read(multiTrackFormProvider.notifier).updateHumanize,
                  onSeedChanged: ref.read(multiTrackFormProvider.notifier).updateSeed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Generate + Reset buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ref.read(multiTrackFormProvider.notifier).reset();
                  setState(() {
                    _selectedTags.clear();
                    _customTrackTypes = false;
                    _customInstruments = false;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final params = ref.read(multiTrackFormProvider);

      final taskId = await api.generateMultitrack(params);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'multitrack',
        tagsUsed: params.base.tags,
        params: params.base,
      );

      ref.read(historyProvider.notifier).addTask(initial);
      ref.read(taskStatusProvider(initial));
      widget.onTaskSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
