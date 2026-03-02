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

class ReplaceTrackTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const ReplaceTrackTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<ReplaceTrackTab> createState() => _ReplaceTrackTabState();
}

class _ReplaceTrackTabState extends ConsumerState<ReplaceTrackTab> {
  final _selectedTags = <String>{};
  PickedFile? _midiFile;
  int _trackIndex = 1;
  String? _trackType;
  int? _instrument;
  String? _replaceBars;
  bool _submitting = false;
  bool _convertingPreview = false;

  // Form state
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
            label: 'Select MIDI file to edit',
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

          // Track index
          TextField(
            decoration: const InputDecoration(
              labelText: 'Track number to replace (1-based)',
              hintText: '1',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: '$_trackIndex'),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && parsed >= 1) {
                setState(() => _trackIndex = parsed);
              }
            },
          ),
          const SizedBox(height: 16),

          // Replace bars (optional)
          TextField(
            decoration: const InputDecoration(
              labelText: 'Bar range (optional)',
              hintText: 'e.g. "8" (bar 8 to end) or "8-16"',
            ),
            onChanged: (v) => setState(() => _replaceBars = v.isEmpty ? null : v),
          ),
          const SizedBox(height: 16),

          // Track type (optional override)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _trackType,
                  decoration: const InputDecoration(
                    labelText: 'New track type (optional)',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Keep original'),
                    ),
                    ...TrackTypeSelector.availableTypes.map((type) {
                      return DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _trackType = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Instrument (optional override)
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
                    _trackIndex = 1;
                    _trackType = null;
                    _instrument = null;
                    _replaceBars = null;
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
                      : const Text('Replace Track'),
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

      final params = ReplaceTrackParams(
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
        trackIndex: _trackIndex,
        trackType: _trackType,
        instrument: _instrument,
        replaceBars: _replaceBars,
      );

      final taskId = await api.replaceTrack(params, promptMidi: _midiFile!);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'replace-track',
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
