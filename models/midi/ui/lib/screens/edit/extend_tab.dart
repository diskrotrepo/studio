import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config/api_config.dart';
import '../../models/generation_params.dart';
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

class ExtendTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const ExtendTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<ExtendTab> createState() => _ExtendTabState();
}

class _ExtendTabState extends ConsumerState<ExtendTab> {
  final _selectedTags = <String>{};
  PickedFile? _midiFile;
  bool _submitting = false;
  bool _convertingPreview = false;

  // Extend-specific
  double _contextSeconds = 15.0;

  // Track / instrument customisation
  int _numTracks = 4;
  bool _customTrackTypes = false;
  bool _customInstruments = false;
  List<String> _trackTypes = ['melody', 'bass', 'chords', 'drums'];
  List<int> _instruments = [0, 0, 0, 0];

  // Form state for generation params
  int _duration = 30;
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
          // Description
          Text(
            'Extend a MIDI file by generating new music appended to the end. '
            'The model uses the tail of the existing track as context to '
            'continue in the same style.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // MIDI file picker (required)
          FilePickerField(
            selectedFile: _midiFile,
            required: true,
            onFileSelected: (file) => setState(() => _midiFile = file),
            label: 'Select MIDI file to extend',
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

          // Context seconds
          Text('Context', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'How many seconds from the end of the track to use as context '
            'for generation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _contextSeconds,
                  min: 5,
                  max: 30,
                  divisions: 25,
                  activeColor: AppColors.controlBlue,
                  onChanged: (v) => setState(() => _contextSeconds = v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${_contextSeconds.toInt()}s',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
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
                    value: _numTracks.toDouble(),
                    min: 1,
                    max: 16,
                    divisions: 15,
                    activeColor: AppColors.controlBlue,
                    label: '$_numTracks',
                    onChanged: (v) {
                      final n = v.round();
                      setState(() {
                        _numTracks = n;
                        while (_trackTypes.length < n) {
                          const defaults = ['melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'];
                          _trackTypes.add(defaults[_trackTypes.length % defaults.length]);
                        }
                        while (_instruments.length < n) {
                          _instruments.add(0);
                        }
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$_numTracks',
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
            onChanged: (v) => setState(() => _customTrackTypes = v),
          ),
          if (_customTrackTypes) ...[
            TrackTypeSelector(
              trackTypes: _trackTypes.take(_numTracks).toList(),
              onChanged: (types) => setState(() => _trackTypes = types),
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
            onChanged: (v) => setState(() => _customInstruments = v),
          ),
          if (_customInstruments) ...[
            ...List.generate(_numTracks, (i) {
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
                        selectedProgram: i < _instruments.length ? _instruments[i] : 0,
                        showAuto: false,
                        onChanged: (v) {
                          setState(() {
                            while (_instruments.length < _numTracks) {
                              _instruments.add(0);
                            }
                            _instruments[i] = v ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

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
                    _contextSeconds = 15.0;
                    _numTracks = 4;
                    _customTrackTypes = false;
                    _customInstruments = false;
                    _trackTypes = ['melody', 'bass', 'chords', 'drums'];
                    _instruments = [0, 0, 0, 0];
                    _duration = 30;
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
                      : const Text('Extend'),
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
      final tags = _selectedTags.isEmpty ? null : _selectedTags.join(' ');

      final params = GenerationParams(
        tags: tags,
        duration: _duration,
        bpm: _bpm,
        temperature: _temperature,
        topK: _topK,
        topP: _topP,
        repetitionPenalty: _repetitionPenalty,
        humanize: _humanize,
        seed: _seed,
        extendFrom: -_contextSeconds,
      );

      final request = http.MultipartRequest('POST', ApiConfig.uri('/api/generate/'));
      request.fields.addAll(params.toFormFields());
      request.fields['num_tracks'] = _numTracks.toString();
      if (_customTrackTypes) {
        for (final t in _trackTypes.take(_numTracks)) {
          request.fields['track_types'] = t;
        }
      }
      if (_customInstruments) {
        for (final i in _instruments.take(_numTracks)) {
          request.fields['instruments'] = i.toString();
        }
      }
      request.files.add(
        http.MultipartFile.fromBytes('prompt_midi', _midiFile!.bytes, filename: _midiFile!.name),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 202) {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }
      final taskId = (jsonDecode(response.body) as Map<String, dynamic>)['task_id'] as String;

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'extend',
        tagsUsed: tags,
        params: params,
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
