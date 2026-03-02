import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/generation_params.dart';
import '../../models/edit_params.dart';
import '../../models/picked_file.dart';
import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/edit_file_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tag_selector.dart';
import '../../widgets/parameter_controls.dart';
import '../../widgets/file_picker_field.dart';
import '../../widgets/track_type_selector.dart';
import '../../widgets/instrument_picker.dart';

class AddTrackTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const AddTrackTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<AddTrackTab> createState() => _AddTrackTabState();
}

class _AddTrackTabState extends ConsumerState<AddTrackTab> {
  final _selectedTags = <String>{};
  PickedFile? _midiFile;
  String _trackType = 'melody';
  int? _instrument;
  bool _submitting = false;
  bool _convertingPreview = false;

  // Form state for generation params
  int _duration = 60;
  int _bpm = 120;
  double _temperature = 0.8;
  int _topK = 30;
  double _topP = 0.85;
  double _repetitionPenalty = 1.2;
  String? _humanize;
  int? _seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final editFile = ref.watch(editFileProvider);
    if (editFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _midiFile = editFile);
        ref.read(editFileProvider.notifier).state = null;
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MIDI file picker (required)
          FilePickerField(
            selectedFile: _midiFile,
            required: true,
            onFileSelected: (file) => setState(() => _midiFile = file),
            label: 'Select MIDI file to add a track to',
          ),
          if (_midiFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _convertingPreview ? null : _playPreview,
                  icon: _convertingPreview
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_convertingPreview ? 'Converting...' : 'Preview'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.controlBlue,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Track type
          SingleTrackTypeSelector(
            value: _trackType,
            onChanged: (v) => setState(() => _trackType = v),
          ),
          const SizedBox(height: 16),

          // Instrument
          InstrumentPicker(
            selectedProgram: _instrument,
            onChanged: (v) => setState(() => _instrument = v),
          ),
          const SizedBox(height: 16),

          // Tags
          TagSelector(
            selectedTags: _selectedTags,
            onChanged: (tags) {
              setState(() {
                _selectedTags.clear();
                _selectedTags.addAll(tags);
              });
            },
          ),
          const SizedBox(height: 16),

          // Parameters
          ParameterControls(
            duration: _duration,
            bpm: _bpm,
            temperature: _temperature,
            onDurationChanged: (v) => setState(() => _duration = v),
            onBpmChanged: (v) => setState(() => _bpm = v),
            onTemperatureChanged: (v) => setState(() => _temperature = v),
          ),
          const SizedBox(height: 16),

          // Advanced
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text('Advanced Settings', style: theme.textTheme.titleSmall),
              tilePadding: EdgeInsets.zero,
              children: [
                AdvancedControls(
                  topK: _topK,
                  topP: _topP,
                  repetitionPenalty: _repetitionPenalty,
                  humanize: _humanize,
                  seed: _seed,
                  onTopKChanged: (v) => setState(() => _topK = v),
                  onTopPChanged: (v) => setState(() => _topP = v),
                  onRepetitionPenaltyChanged: (v) => setState(() => _repetitionPenalty = v),
                  onHumanizeChanged: (v) => setState(() => _humanize = v),
                  onSeedChanged: (v) => setState(() => _seed = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit + Reset buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTags.clear();
                    _trackType = 'melody';
                    _instrument = null;
                    _duration = 60;
                    _bpm = 120;
                    _temperature = 0.8;
                    _topK = 30;
                    _topP = 0.85;
                    _repetitionPenalty = 1.2;
                    _humanize = null;
                    _seed = null;
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
                  onPressed: _submitting || _midiFile == null ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Track'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _playPreview() async {
    if (_midiFile == null) return;
    setState(() => _convertingPreview = true);
    try {
      final api = ref.read(apiClientProvider);
      final audio = ref.read(audioServiceProvider);
      final mp3Url = await api.convertMidi(_midiFile!);
      final url = api.getDownloadUrl(mp3Url);
      await audio.stop();
      await audio.loadUrl(url);
      await audio.play();
      ref.read(currentlyPlayingTaskProvider.notifier).state = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _convertingPreview = false);
    }
  }

  Future<void> _submit() async {
    if (_midiFile == null) return;
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final tags = _selectedTags.isEmpty ? null : _selectedTags.join(' ');

      final params = AddTrackParams(
        base: GenerationParams(
          tags: tags,
          duration: _duration,
          bpm: _bpm,
          temperature: _temperature,
          topK: _topK,
          topP: _topP,
          repetitionPenalty: _repetitionPenalty,
          humanize: _humanize,
          seed: _seed,
        ),
        trackType: _trackType,
        instrument: _instrument,
      );

      final taskId = await api.addTrack(params, promptMidi: _midiFile!);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'add-track',
        tagsUsed: tags,
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
