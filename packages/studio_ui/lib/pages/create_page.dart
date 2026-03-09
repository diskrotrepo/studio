import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../application/now_playing.dart';
import '../audio_player/bytes_audio_source.dart';
import '../models/model_capabilities.dart';
import '../models/task_status.dart';
import '../models/workspace.dart';
import '../models/lyric_sheet.dart';
import '../models/lyrics_block.dart';
import '../services/api_client.dart';
import '../utils/error_helpers.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';
import '../utils/amplitude_extractor.dart';
import '../utils/file_saver.dart';
import '../l10n/app_localizations.dart';
import '../models/genre_data.dart';
import '../widgets/cover_art.dart';
import '../widgets/genre_autocomplete.dart';
import '../widgets/lyrics_block_editor.dart';

const _taskTypes = [
  'generate',
  'generate_long',
  'upload',
  'infill',
  'cover',
  'extract',
  'add_stem',
  'extend',
];

IconData _taskTypeIcon(String taskType) => switch (taskType) {
      'generate' => Icons.music_note,
      'generate_long' => Icons.queue_music,
      'upload' => Icons.upload_file,
      'infill' => Icons.format_color_fill,
      'cover' => Icons.library_music,
      'extract' => Icons.call_split,
      'add_stem' => Icons.move_down,
      'extend' => Icons.expand,
      _ => Icons.music_note,
    };

Color _taskTypeColor(String taskType) => switch (taskType) {
      'generate' => const Color(0xFF5C9CE6),
      'generate_long' => const Color(0xFF9B59B6),
      'upload' => const Color(0xFF2ECC71),
      'infill' => const Color(0xFFE67E22),
      'cover' => const Color(0xFFE91E63),
      'extract' => const Color(0xFF00BCD4),
      'add_stem' => const Color(0xFFFFEB3B),
      'extend' => const Color(0xFF26A69A),
      _ => const Color(0xFF5C9CE6),
    };

String _taskTypeDescription(String taskType, S s) => switch (taskType) {
      'generate' => s.taskTypeGenerate,
      'generate_long' => s.taskTypeGenerateLong,
      'upload' => s.taskTypeUpload,
      'infill' => s.taskTypeInfill,
      'cover' => s.taskTypeCover,
      'extract' => s.taskTypeExtract,
      'add_stem' => s.taskTypeAddStem,
      'extend' => s.taskTypeExtend,
      _ => taskType,
    };

String _modelDisplayName(String model) => switch (model) {
      'ace_step_15' => 'ACE Step 1.5',
      'ltx' => 'LTX-2',
      _ => model,
    };

Widget _modelBadge(String model) {
  final color = switch (model) {
    'bark' => const Color(0xFFE091A5),
    'ace_step_15' => const Color(0xFFB39DDB),
    'ltx' => const Color(0xFF4FC3F7),
    _ => AppColors.textMuted,
  };
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 100),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _modelDisplayName(model),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

/// Offline fallback capabilities per model so the UI is correct even without
/// the server.
final _fallbackCapabilities = <String, ModelCapabilities>{
  'ace_step_15': ModelCapabilities(
    model: 'ace_step_15',
    enabled: true,
    taskTypes: [
      'generate',
      'generate_long',
      'infill',
      'cover',
      'extract',
      'add_stem',
      'extend',
    ],
    parameters: [
      'temperature',
      'guidance_scale',
      'inference_steps',
      'audio_duration',
      'thinking',
      'constrained_decoding',
    ],
    features: {'lora': true, 'lyrics': true, 'negative_prompt': true},
  ),
  'bark': ModelCapabilities(
    model: 'bark',
    enabled: true,
    taskTypes: ['generate', 'generate_long'],
    parameters: ['prompt', 'temperature'],
    features: {'lora': false, 'lyrics': false, 'negative_prompt': false},
  ),
  'ltx': ModelCapabilities(
    model: 'ltx',
    enabled: true,
    taskTypes: ['generate'],
    parameters: [
      'prompt',
      'negative_prompt',
      'guidance_scale',
      'audio_duration',
      'batch_size',
    ],
    features: {'lora': true, 'lyrics': false, 'negative_prompt': true},
  ),
};

const _stemNames = [
  'vocals',
  'drums',
  'bass',
  'guitar',
  'keyboard',
  'strings',
  'synth',
  'percussion',
  'brass',
  'woodwinds',
  'fx',
  'backing_vocals',
];

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  String _taskType = 'generate';
  String _model = 'ace_step_15';
  String _stemName = 'vocals';
  bool _instrumental = false;

  // Advanced parameter controls
  bool _advancedExpanded = false;
  double _creativity = _defaultCreativity;
  double _promptStrength = _defaultPromptStrength;
  double _quality = _defaultQuality;
  double _duration = _defaultDuration;
  double _variations = _defaultVariations;

  // Additional advanced parameters
  bool _thinking = false;
  bool _constrainedDecoding = false;
  bool _useRandomSeed = true;
  final _seedController = TextEditingController(text: '42');
  double _cfgScale = _defaultCfgScale;
  double _topP = _defaultTopP;
  double _repetitionPenalty = _defaultRepetitionPenalty;
  double _shift = _defaultShift;
  double _cfgIntervalStart = _defaultCfgIntervalStart;
  double _cfgIntervalEnd = _defaultCfgIntervalEnd;

  // ACE Step 1.5 recommended defaults
  static const double _defaultCreativity = 0.85; // temperature
  static const double _defaultPromptStrength = 7.0; // guidance_scale
  static const double _defaultQuality = 50; // inference_steps
  static const double _defaultDuration = 150; // audio_duration (seconds)
  static const double _defaultVariations = 1; // batch_size
  static const double _defaultCfgScale = 2.0; // lm_cfg_scale
  static const double _defaultTopP = 0.9; // nucleus sampling
  static const double _defaultRepetitionPenalty = 1.0; // repetition penalty
  static const double _defaultShift = 3.0; // timestep shift factor
  static const double _defaultCfgIntervalStart = 0.0;
  static const double _defaultCfgIntervalEnd = 1.0;

  // Server-provided defaults (per model); null until fetched.
  Map<String, dynamic>? _serverDefaults;

  // Server-provided capabilities (per model); null until fetched.
  ModelCapabilities? _capabilities;

  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController();
  final _srcAudioPathController = TextEditingController();
  String? _srcAudioLabel;
  String? _srcAudioUrl;
  final _infillStartMinController = TextEditingController(text: '0');
  final _infillStartSecController = TextEditingController(text: '0');
  final _infillEndMinController = TextEditingController(text: '0');
  final _infillEndSecController = TextEditingController(text: '0');
  final _trackClassesController = TextEditingController();
  final _repaintStartMinController = TextEditingController(text: '0');
  final _repaintStartSecController = TextEditingController(text: '0');
  final _repaintEndMinController = TextEditingController(text: '0');
  final _repaintEndSecController = TextEditingController(text: '0');

  // Crop controllers
  final _cropStartMinController = TextEditingController(text: '0');
  final _cropStartSecController = TextEditingController(text: '0');
  final _cropEndMinController = TextEditingController(text: '0');
  final _cropEndSecController = TextEditingController(text: '0');

  // Fade controllers (duration in seconds)
  final _fadeInController = TextEditingController(text: '0');
  final _fadeOutController = TextEditingController(text: '0');

  // Upload state
  PlatformFile? _pickedFile;
  double _uploadProgress = 0;

  // Infill waveform state
  Uint8List? _infillBytes;
  Duration? _infillDuration;
  bool _loadingWaveform = false;

  final List<MapEntry<String, MajorGenre>> _selectedGenres = [];

  final List<TaskStatus> _tasks = [];
  final List<TaskStatus> _songs = [];
  Timer? _pollTimer;
  bool _submitting = false;
  bool _loadingSongs = false;
  String? _songsCursor;
  bool _hasMoreSongs = true;
  String? _error;
  TaskStatus? _selectedTask;

  // Filter/sort state
  int? _filterRating;
  String _sortOrder = 'newest';

  // Multi-select state
  bool _multiSelectMode = false;
  bool _shiftHeld = false;
  final Set<String> _selectedTaskIds = {};
  int? _lastSelectedIndex;
  bool _batchDeleting = false;
  bool _batchMoving = false;

  // Compact layout state
  bool _showFormPanel = false;
  bool _showLyricBook = false;
  String? _selectedLyricSheetId;

  // Detail panel state
  bool _editingDetailTitle = false;
  bool _editingDetailLyrics = false;
  final _detailTitleController = TextEditingController();
  final _detailLyricsController = TextEditingController();
  Map<String, dynamic>? _detailParameters;
  bool _loadingDetails = false;
  bool _parametersExpanded = false;

  // Lyric book picker state
  List<LyricSheet> _lyricSheets = [];
  bool _lyricSheetsLoaded = false;
  LyricSheet? _previewingSheet;

  // AI text generation state
  static const _textModel = 'yulan_mini';
  bool _generatingLyrics = false;
  bool _generatingPrompt = false;

  // LoRA state
  bool _loraExpanded = false;
  bool _loraLoadExpanded = false;
  bool _loraLoading = false;
  String? _loraError;
  bool _loraLoaded = false;
  bool _useLora = false;
  double _loraScale = 1.0;
  List<Map<String, dynamic>> _availableLoras = [];
  String? _loraActiveAdapter;
  String? _loraToLoad;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollActiveTasks(),
    );
    _loadSongs();
    _client.activeWorkspace.addListener(_onWorkspaceChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDefaults());
  }

  bool _handleKeyEvent(KeyEvent event) {
    final shifted = HardwareKeyboard.instance.isShiftPressed;
    if (shifted != _shiftHeld) {
      setState(() => _shiftHeld = shifted);
    }
    return false;
  }

  void _onWorkspaceChanged() {
    _applyFilter(rating: _filterRating);
  }

  Future<void> _loadSongs() async {
    if (_loadingSongs || !_hasMoreSongs) return;
    setState(() => _loadingSongs = true);

    try {
      final result = await _client.getSongs(
        cursor: _songsCursor,
        rating: _filterRating,
        sort: _sortOrder,
        workspaceId: _client.activeWorkspace.value?.id,
      );
      if (mounted) {
        setState(() {
          _songs.addAll(result.songs);
          _songsCursor = result.nextCursor;
          _hasMoreSongs = result.hasMore;
        });
      }
    } catch (_) {
      // Songs loading is best-effort; don't block the UI.
    } finally {
      if (mounted) setState(() => _loadingSongs = false);
    }
  }

  void _applyFilter({int? rating, String? sort}) {
    setState(() {
      _filterRating = rating;
      if (sort != null) _sortOrder = sort;
      _songs.clear();
      _songsCursor = null;
      _hasMoreSongs = true;
      _loadingSongs = false;
    });
    _loadSongs();
  }

  Future<void> _fetchSongDetails(String taskId) async {
    setState(() => _loadingDetails = true);
    try {
      final details = await _client.getSongDetails(taskId);
      if (mounted && _selectedTask?.taskId == taskId) {
        setState(() {
          _detailParameters = details.parameters;
          _updateTaskInLists(details);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _client.activeWorkspace.removeListener(_onWorkspaceChanged);
    _pollTimer?.cancel();
    _titleController.dispose();
    _lyricsController.dispose();
    _promptController.dispose();
    _negativePromptController.dispose();
    _seedController.dispose();
    _srcAudioPathController.dispose();
    _infillStartMinController.dispose();
    _infillStartSecController.dispose();
    _infillEndMinController.dispose();
    _infillEndSecController.dispose();
    _repaintStartMinController.dispose();
    _repaintStartSecController.dispose();
    _repaintEndMinController.dispose();
    _repaintEndSecController.dispose();
    _cropStartMinController.dispose();
    _cropStartSecController.dispose();
    _cropEndMinController.dispose();
    _cropEndSecController.dispose();
    _fadeInController.dispose();
    _fadeOutController.dispose();
    _trackClassesController.dispose();
    _detailTitleController.dispose();
    _detailLyricsController.dispose();
    super.dispose();
  }

  ApiClient get _client => context.read<ApiClient>();

  List<PlayingTrack> _allPlayableTracks() {
    final result = <PlayingTrack>[];
    for (final task in _tasks) {
      if (!task.isComplete) continue;
      final label = task.title ?? task.prompt ?? task.taskType;
      final url = _client.songDownloadUrl(task.taskId);
      result.add(PlayingTrack(id: task.taskId, title: label, audioUrl: url));
    }
    for (final song in _songs) {
      if (!song.isComplete) continue;
      final label = song.title ?? song.prompt ?? song.taskType;
      final url = _client.songDownloadUrl(song.taskId);
      result.add(PlayingTrack(id: song.taskId, title: label, audioUrl: url));
    }
    return result;
  }

  double _timeToSeconds(
    TextEditingController minCtrl,
    TextEditingController secCtrl,
  ) {
    final min = int.tryParse(minCtrl.text) ?? 0;
    final sec = double.tryParse(secCtrl.text) ?? 0;
    return min * 60.0 + sec;
  }

  void _setTimeFromSeconds(
    double totalSeconds,
    TextEditingController minCtrl,
    TextEditingController secCtrl,
  ) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds - min * 60;
    minCtrl.text = min.toString();
    secCtrl.text = sec == sec.roundToDouble() ? sec.toInt().toString() : sec.toStringAsFixed(1);
  }

  void _selectTask(TaskStatus? task) {
    _editingDetailTitle = false;
    _editingDetailLyrics = false;
    _selectedTask = task;
    _detailParameters = null;
    if (task != null) {
      _detailTitleController.text = task.title ?? '';
      _detailLyricsController.text = task.lyrics ?? '';
      if (task.isComplete && task.parameters == null) {
        _fetchSongDetails(task.taskId);
      } else {
        _detailParameters = task.parameters;
      }
    }
  }

  void _updateTaskInLists(TaskStatus updated) {
    final taskIdx = _tasks.indexWhere((t) => t.taskId == updated.taskId);
    if (taskIdx != -1) {
      _tasks[taskIdx] = updated;
    }
    final songIdx = _songs.indexWhere((t) => t.taskId == updated.taskId);
    if (songIdx != -1) {
      _songs[songIdx] = updated;
    }
    if (_selectedTask?.taskId == updated.taskId) {
      _selectedTask = updated;
    }
  }

  String? _taskIdAtIndex(int index) {
    if (index < _tasks.length) return _tasks[index].taskId;
    final songIndex = index - _tasks.length;
    if (songIndex < _songs.length) return _songs[songIndex].taskId;
    return null;
  }

  void _handleMultiSelectTap(int index) {
    setState(() {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      if (isShift && _lastSelectedIndex != null) {
        final start = math.min(_lastSelectedIndex!, index);
        final end = math.max(_lastSelectedIndex!, index);
        for (var i = start; i <= end; i++) {
          final id = _taskIdAtIndex(i);
          if (id != null) _selectedTaskIds.add(id);
        }
      } else {
        final id = _taskIdAtIndex(index);
        if (id != null) {
          if (!_selectedTaskIds.remove(id)) {
            _selectedTaskIds.add(id);
          }
        }
      }
      _lastSelectedIndex = index;
      if (_selectedTaskIds.isEmpty) {
        _multiSelectMode = false;
        _lastSelectedIndex = null;
      }
    });
  }

  Future<void> _saveDetailTitle() async {
    final title = _detailTitleController.text.trim();
    if (title.isEmpty || _selectedTask == null) {
      setState(() => _editingDetailTitle = false);
      return;
    }
    try {
      await _client.updateSong(taskId: _selectedTask!.taskId, title: title);
      setState(() {
        _updateTaskInLists(_selectedTask!.copyWith(title: title));
        _editingDetailTitle = false;
      });
    } catch (_) {
      if (mounted) setState(() => _editingDetailTitle = false);
    }
  }

  Future<void> _saveDetailLyrics() async {
    final lyrics = _detailLyricsController.text;
    if (_selectedTask == null) {
      setState(() => _editingDetailLyrics = false);
      return;
    }
    try {
      await _client.updateSong(
        taskId: _selectedTask!.taskId,
        lyrics: lyrics,
      );
      setState(() {
        _updateTaskInLists(lyrics.isEmpty
            ? _selectedTask!.copyWith(clearLyrics: true)
            : _selectedTask!.copyWith(lyrics: lyrics));
        _editingDetailLyrics = false;
      });
    } catch (_) {
      if (mounted) setState(() => _editingDetailLyrics = false);
    }
  }

  bool get _needsSourceClip =>
      const {'infill', 'cover', 'extract', 'add_stem', 'extend', 'crop', 'fade'}
          .contains(_taskType);

  List<String> get _availableTaskTypes {
    final caps = _capabilities ?? _fallbackCapabilities[_model];
    if (caps == null) return _taskTypes;
    return _taskTypes.where((t) {
      if (t == 'upload' && _model == 'ace_step_15') return false;
      return caps.supportsTaskType(t);
    }).toList();
  }

  bool _supportsParam(String param) =>
      (_capabilities ?? _fallbackCapabilities[_model])
          ?.supportsParameter(param) ??
      true;

  bool _hasFeature(String feature) =>
      (_capabilities ?? _fallbackCapabilities[_model])
          ?.hasFeature(feature) ??
      true;

  void _useAs(
    String taskType,
    String audioPath,
    String audioUrl,
    String label,
  ) {
    setState(() {
      _taskType = taskType;
      _srcAudioPathController.text = audioPath;
      _srcAudioLabel = label;
      _srcAudioUrl = audioUrl;
      _infillBytes = null;
      _infillDuration = null;
    });
    if (taskType == 'infill') {
      _loadWaveform(audioUrl);
    }
  }

  /// Apply parameters from a completed task to the create form.
  void _applyParametersFromTask(TaskStatus task) {
    final params = _detailParameters ?? task.parameters;
    setState(() {
      // Task type
      if (_taskTypes.contains(task.taskType)) {
        _taskType = task.taskType;
      }
      // Model
      if (task.model != null) _model = task.model!;
      // Prompt
      _promptController.text = task.prompt ?? '';
      // Lyrics
      _lyricsController.text = task.lyrics ?? '';

      if (params != null) {
        // Numerical parameters
        if (params['temperature'] != null) {
          _creativity = (params['temperature'] as num).toDouble();
        }
        if (params['guidance_scale'] != null) {
          _promptStrength = (params['guidance_scale'] as num).toDouble();
        }
        if (params['inference_steps'] != null) {
          _quality = (params['inference_steps'] as num).toDouble();
        }
        if (params['audio_duration'] != null) {
          _duration = (params['audio_duration'] as num).toDouble();
        }
        if (params['batch_size'] != null) {
          _variations = (params['batch_size'] as num).toDouble();
        }
        if (params['cfg_scale'] != null) {
          _cfgScale = (params['cfg_scale'] as num).toDouble();
        }
        if (params['top_p'] != null) {
          _topP = (params['top_p'] as num).toDouble();
        }
        if (params['repetition_penalty'] != null) {
          _repetitionPenalty =
              (params['repetition_penalty'] as num).toDouble();
        }
        if (params['shift'] != null) {
          _shift = (params['shift'] as num).toDouble();
        }
        if (params['cfg_interval_start'] != null) {
          _cfgIntervalStart =
              (params['cfg_interval_start'] as num).toDouble();
        }
        if (params['cfg_interval_end'] != null) {
          _cfgIntervalEnd =
              (params['cfg_interval_end'] as num).toDouble();
        }
        // Boolean parameters
        if (params['thinking'] != null) {
          _thinking = params['thinking'] as bool;
        }
        if (params['constrained_decoding'] != null) {
          _constrainedDecoding = params['constrained_decoding'] as bool;
        }
        if (params['use_random_seed'] != null) {
          _useRandomSeed = params['use_random_seed'] as bool;
        }
        // Negative prompt
        if (params['negative_prompt'] != null) {
          _negativePromptController.text =
              params['negative_prompt'] as String;
        }
      }

      // Expand advanced section so user can see applied params
      _advancedExpanded = true;
    });
    // Refresh capabilities for the selected model
    _fetchDefaults();
  }

  /// Extract audio object path from a task result.
  static String? _audioPathFromTask(TaskStatus task) {
    final r = task.result;
    if (r == null) return null;
    final object = r['object'] as String?;
    if (object != null) return object;
    final results = r['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final first = results.first as Map<String, dynamic>;
      return first['file'] as String?;
    }
    return null;
  }

  /// Set the source clip from a dropped task without changing the task type.
  void _setSourceFromTask(TaskStatus task) {
    final audioPath = _audioPathFromTask(task);
    if (audioPath == null || !task.isComplete) return;
    final audioUrl = _client.songDownloadUrl(task.taskId);
    final label = task.title ?? task.prompt ?? task.taskType;
    setState(() {
      _srcAudioPathController.text = audioPath;
      _srcAudioLabel = label;
      _srcAudioUrl = audioUrl;
      _infillBytes = null;
      _infillDuration = null;
    });
    if (_taskType == 'infill') {
      _loadWaveform(audioUrl);
    }
  }

  Future<void> _loadWaveform(String audioUrl) async {
    setState(() => _loadingWaveform = true);
    try {
      final bytes = await _client.downloadAudioBytes(audioUrl);
      final player = AudioPlayer();
      try {
        await player.setAudioSource(BytesAudioSource(bytes));
        final dur = player.duration ?? Duration.zero;
        if (mounted) {
          setState(() {
            _infillBytes = bytes;
            _infillDuration = dur;
            _setTimeFromSeconds(
              dur.inMilliseconds / 1000,
              _infillEndMinController,
              _infillEndSecController,
            );
          });
        }
      } finally {
        await player.dispose();
      }
    } catch (_) {
      // Waveform loading is best-effort; text fields remain usable.
    } finally {
      if (mounted) setState(() => _loadingWaveform = false);
    }
  }

  /// Validates numeric/time fields before submission.
  /// Returns an error message, or `null` if valid.
  String? _validateForm() {
    if (_supportsParam('use_random_seed') && !_useRandomSeed) {
      final err = seedField(_seedController.text);
      if (err != null) return err;
    }

    // Time fields for task types that use them.
    if (_taskType == 'infill') {
      final err = minutesField(_infillStartMinController.text) ??
          secondsField(_infillStartSecController.text) ??
          minutesField(_infillEndMinController.text) ??
          secondsField(_infillEndSecController.text);
      if (err != null) return err;
    }
    if (_taskType == 'extend') {
      final err = minutesField(_repaintStartMinController.text) ??
          secondsField(_repaintStartSecController.text) ??
          minutesField(_repaintEndMinController.text) ??
          secondsField(_repaintEndSecController.text);
      if (err != null) return err;
    }
    if (_taskType == 'crop') {
      final err = minutesField(_cropStartMinController.text) ??
          secondsField(_cropStartSecController.text) ??
          minutesField(_cropEndMinController.text) ??
          secondsField(_cropEndSecController.text);
      if (err != null) return err;
    }
    if (_taskType == 'fade') {
      final err =
          nonNegativeDouble(_fadeInController.text, fieldName: 'Fade in') ??
          nonNegativeDouble(_fadeOutController.text, fieldName: 'Fade out');
      if (err != null) return err;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_taskType == 'upload') {
      return _submitUpload();
    }

    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{
        'model': _model,
        'task_type': _taskType,
        if (_client.activeWorkspace.value != null)
          'workspace_id': _client.activeWorkspace.value!.id,
        if (_selectedLyricSheetId != null)
          'lyric_sheet_id': _selectedLyricSheetId,
        if (_supportsParam('temperature'))
          'temperature': _creativity,
        if (_supportsParam('guidance_scale'))
          'guidance_scale': _promptStrength,
        if (_supportsParam('inference_steps'))
          'inference_steps': _quality.round(),
        if (_supportsParam('audio_duration'))
          'audio_duration': _duration.round(),
        if (_supportsParam('batch_size'))
          'batch_size': _variations.round(),
        if (_supportsParam('cfg_scale'))
          'cfg_scale': _cfgScale,
        if (_supportsParam('top_p'))
          'top_p': _topP,
        if (_supportsParam('repetition_penalty'))
          'repetition_penalty': _repetitionPenalty,
        if (_supportsParam('shift'))
          'shift': _shift,
        if (_supportsParam('cfg_interval_start'))
          'cfg_interval_start': _cfgIntervalStart,
        if (_supportsParam('cfg_interval_end'))
          'cfg_interval_end': _cfgIntervalEnd,
        if (_supportsParam('thinking'))
          'thinking': _thinking,
        if (_supportsParam('constrained_decoding'))
          'constrained_decoding': _constrainedDecoding,
        if (_supportsParam('use_random_seed'))
          'use_random_seed': _useRandomSeed,
        if (_supportsParam('use_random_seed') &&
            !_useRandomSeed && _seedController.text.isNotEmpty)
          'seed': int.tryParse(_seedController.text) ?? 42,
        if (_hasFeature('negative_prompt') &&
            _negativePromptController.text.isNotEmpty)
          'negative_prompt': _negativePromptController.text,
      };

      switch (_taskType) {
        case 'generate':
        case 'generate_long':
          body['prompt'] = _buildPromptWithGenres();
          if (_titleController.text.isNotEmpty) {
            body['title'] = _titleController.text;
          }
          if (_hasFeature('lyrics')) {
            if (_instrumental) {
              body['lyrics'] = '[Instrumental]';
            } else if (_lyricsController.text.isNotEmpty) {
              body['lyrics'] = _lyricsController.text;
            }
          }
        case 'infill':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['infill_start'] = _timeToSeconds(
            _infillStartMinController,
            _infillStartSecController,
          );
          body['infill_end'] = _timeToSeconds(
            _infillEndMinController,
            _infillEndSecController,
          );
          final infillPrompt = _buildPromptWithGenres();
          if (infillPrompt.isNotEmpty) {
            body['prompt'] = infillPrompt;
          }
          if (_hasFeature('lyrics')) {
            if (_instrumental) {
              body['lyrics'] = '[Instrumental]';
            } else if (_lyricsController.text.isNotEmpty) {
              body['lyrics'] = _lyricsController.text;
            }
          }
        case 'cover':
          body['src_audio_path'] = _srcAudioPathController.text;
          final coverPrompt = _buildPromptWithGenres();
          if (coverPrompt.isNotEmpty) {
            body['prompt'] = coverPrompt;
          }
          if (_hasFeature('lyrics')) {
            if (_instrumental) {
              body['lyrics'] = '[Instrumental]';
            } else if (_lyricsController.text.isNotEmpty) {
              body['lyrics'] = _lyricsController.text;
            }
          }
          if (_hasFeature('lora') && _useLora && _loraActiveAdapter != null) {
            body['use_lora'] = true;
            body['lora_scale'] = _loraScale;
            body['lora_adapter'] = _loraActiveAdapter;
          }
        case 'extract':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['stem_name'] = _stemName;
        case 'add_stem':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['stem_name'] = _stemName;
          final stemPrompt = _buildPromptWithGenres();
          if (stemPrompt.isNotEmpty) {
            body['prompt'] = stemPrompt;
          }
        case 'extend':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['repainting_start'] = _timeToSeconds(
            _repaintStartMinController,
            _repaintStartSecController,
          );
          body['repainting_end'] =
              _repaintEndMinController.text.isEmpty &&
                      _repaintEndSecController.text.isEmpty
                  ? -1.0
                  : _timeToSeconds(
                      _repaintEndMinController,
                      _repaintEndSecController,
                    );
          final extendPrompt = _buildPromptWithGenres();
          if (extendPrompt.isNotEmpty) {
            body['prompt'] = extendPrompt;
          }
          if (_hasFeature('lyrics')) {
            if (_instrumental) {
              body['lyrics'] = '[Instrumental]';
            } else if (_lyricsController.text.isNotEmpty) {
              body['lyrics'] = _lyricsController.text;
            }
          }
          final classes = _trackClassesController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (classes.isNotEmpty) {
            body['track_classes'] = classes;
          }
        case 'crop':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['crop_start'] = _timeToSeconds(
            _cropStartMinController,
            _cropStartSecController,
          );
          body['crop_end'] =
              _cropEndMinController.text.isEmpty &&
                      _cropEndSecController.text.isEmpty
                  ? -1.0
                  : _timeToSeconds(
                      _cropEndMinController,
                      _cropEndSecController,
                    );
        case 'fade':
          body['src_audio_path'] = _srcAudioPathController.text;
          body['fade_in'] =
              double.tryParse(_fadeInController.text) ?? 0;
          body['fade_out'] =
              double.tryParse(_fadeOutController.text) ?? 0;
      }

      final client = _client;
      final taskId = await client.submitTask(body);
      final status = TaskStatus(
        taskId: taskId,
        status: TaskStatus.statusProcessing,
        taskType: _taskType,
        model: _model,
      );

      setState(() => _tasks.insert(0, status));
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitUpload() async {
    final s = S.of(context);
    final file = _pickedFile;
    if (file == null || file.bytes == null) {
      setState(() => _error = s.errorSelectAudioFile);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _uploadProgress = 0;
    });

    try {
      final client = _client;
      final bytes = Uint8List.fromList(file.bytes!);
      final ext = file.extension ?? 'wav';
      final contentType = switch (ext) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'flac' => 'audio/flac',
        'ogg' => 'audio/ogg',
        'aac' => 'audio/aac',
        'm4a' => 'audio/mp4',
        _ => 'application/octet-stream',
      };

      // 1. Init upload session
      setState(() => _uploadProgress = 0.1);
      final session = await client.createUpload(
        filename: file.name,
        contentType: contentType,
        size: bytes.length,
      );

      final uploadUrl = session['uploadUrl'] as String;
      final fileId = session['id'] as String;

      // Add task to list immediately
      setState(() {
        _tasks.insert(
          0,
          TaskStatus(taskId: fileId, status: TaskStatus.statusUploading, taskType: 'upload'),
        );
        _uploadProgress = 0.2;
      });

      // 2. Upload bytes through finalize endpoint
      final contentRange = 'bytes 0-${bytes.length - 1}/${bytes.length}';
      final response = await client.finalizeUpload(
        sessionUrl: uploadUrl,
        contentType: contentType,
        contentRange: contentRange,
        fileId: fileId,
        bytes: bytes,
      );

      if (mounted) {
        setState(() => _uploadProgress = 1.0);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Upload complete — update the task in our list
        final index = _tasks.indexWhere((t) => t.taskId == fileId);
        if (index != -1 && mounted) {
          setState(() {
            _tasks[index] = TaskStatus(
              taskId: fileId,
              status: TaskStatus.statusComplete,
              taskType: 'upload',
            );
            _pickedFile = null;
            _uploadProgress = 0;
          });
        }
      } else if (response.statusCode == 308) {
        // Partial upload — the task stays as uploading and will be
        // picked up by polling.
        if (mounted) setState(() => _uploadProgress = 0);
      } else {
        throw ApiException(
          response.statusCode,
          'Upload failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _pollActiveTasks() async {
    final activeTasks = _tasks.where((t) => t.isActive).toList();
    if (activeTasks.isEmpty) return;

    final client = _client;

    for (final task in activeTasks) {
      try {
        final updated = await client.getTaskStatus(task.taskId);
        final index = _tasks.indexWhere((t) => t.taskId == task.taskId);
        if (index != -1 && mounted) {
          setState(() => _tasks[index] = updated);
        }
      } catch (_) {}
    }
  }

  Widget _buildFormPanelContent() {
    final s = S.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.createHeading,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                _label(s.labelModel),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  dropdownColor: AppColors.surfaceHigh,
                  items: [
                    DropdownMenuItem(
                      value: 'ace_step_15',
                      child: Text(s.modelAceStep),
                    ),
                    DropdownMenuItem(
                      value: 'bark',
                      child: Text(s.modelBark),
                    ),
                    DropdownMenuItem(
                      value: 'ltx',
                      child: Text(s.modelLtx),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _model = v!;
                      _capabilities = _fallbackCapabilities[_model];
                      if (_capabilities != null &&
                          !_capabilities!.supportsTaskType(_taskType)) {
                        _taskType = 'generate';
                      }
                      if (!_hasFeature('lyrics')) _showLyricBook = false;
                    });
                    _fetchDefaults();
                  },
                ),
                const SizedBox(height: 12),
                _label(s.labelTaskType),
                const SizedBox(height: 6),
                _buildDropdown(
                  value: _taskType,
                  items: _availableTaskTypes,
                  onChanged: (v) => setState(() => _taskType = v!),
                ),
                const SizedBox(height: 12),
                _buildTaskFields(),
                const SizedBox(height: 12),
                _buildAdvancedSection(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Tooltip(
            message: _needsSourceClip && _srcAudioPathController.text.isEmpty
                ? s.tooltipSourceClipRequired(_taskType)
                : '',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ||
                        (_needsSourceClip && _srcAudioPathController.text.isEmpty)
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_taskType == 'upload' ? s.buttonUpload : s.buttonGenerate),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskListContent({required bool compact}) {
    final s = S.of(context);
    return Container(
      color: const Color(0xFF0E0E0E),
      child: Column(
        children: [
          _buildFilterBar(compact: compact),
          if (_multiSelectMode || _shiftHeld) _buildMultiSelectBar(),
          Expanded(
            child: _tasks.isEmpty && _songs.isEmpty && !_loadingSongs
                ? Center(
                    child: Text(
                      s.noTasksYet,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification &&
                          notification.metrics.extentAfter < 200) {
                        _loadSongs();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _tasks.length +
                          _songs.length +
                          (_loadingSongs ? 1 : 0),
                      itemBuilder: (context, index) {
                        final queueTracks = _allPlayableTracks();
                        // Session tasks first, then songs from the server.
                        if (index < _tasks.length) {
                          final task = _tasks[index];
                          return _TaskCard(
                            task: task,
                            selected: _selectedTask?.taskId == task.taskId,
                            queueTracks: queueTracks,
                            multiSelectMode: _multiSelectMode,
                            multiSelected: _selectedTaskIds.contains(task.taskId),
                            onMultiSelectToggle: () => _handleMultiSelectTap(index),
                            onTap: () {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                if (!_multiSelectMode) {
                                  setState(() => _multiSelectMode = true);
                                }
                                _handleMultiSelectTap(index);
                              } else if (_multiSelectMode) {
                                _handleMultiSelectTap(index);
                              } else {
                                setState(() {
                                  _selectTask(
                                    _selectedTask?.taskId == task.taskId ? null : task,
                                  );
                                });
                              }
                            },
                            onUseAs: _useAs,
                            onUpdate: (updated) => setState(() {
                              _updateTaskInLists(updated);
                            }),
                            onDelete: () => setState(() {
                              if (_selectedTask?.taskId == task.taskId) {
                                _selectTask(null);
                              }
                              _tasks.removeAt(index);
                            }),
                          );
                        }
                        final songIndex = index - _tasks.length;
                        if (songIndex < _songs.length) {
                          final song = _songs[songIndex];
                          return _TaskCard(
                            task: song,
                            selected: _selectedTask?.taskId == song.taskId,
                            queueTracks: queueTracks,
                            multiSelectMode: _multiSelectMode,
                            multiSelected: _selectedTaskIds.contains(song.taskId),
                            onMultiSelectToggle: () => _handleMultiSelectTap(index),
                            onTap: () {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                if (!_multiSelectMode) {
                                  setState(() => _multiSelectMode = true);
                                }
                                _handleMultiSelectTap(index);
                              } else if (_multiSelectMode) {
                                _handleMultiSelectTap(index);
                              } else {
                                setState(() {
                                  _selectTask(
                                    _selectedTask?.taskId == song.taskId ? null : song,
                                  );
                                });
                              }
                            },
                            onUseAs: _useAs,
                            onUpdate: (updated) => setState(() {
                              _updateTaskInLists(updated);
                            }),
                            onDelete: () => setState(() {
                              if (_selectedTask?.taskId == song.taskId) {
                                _selectTask(null);
                              }
                              _songs.removeAt(songIndex);
                            }),
                          );
                        }
                        // Loading indicator at the bottom.
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = S.of(context);
        final screen = Responsive.of(constraints.maxWidth);
        final compact = screen == ScreenSize.compact;
        final panelWidth = Responsive.formPanelWidth(screen);
        final detailWidth = Responsive.detailPanelWidth(screen);

        // Compact mode: show one view at a time
        if (compact) {
          if (_showFormPanel) {
            return Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.textMuted),
                          onPressed: () => setState(() => _showFormPanel = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.backToTasks,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildFormPanelContent()),
                ],
              ),
            );
          }
          if (_selectedTask != null) {
            return Container(
              color: AppColors.surface,
              child: _buildDetailPanel(_selectedTask!, detailWidth),
            );
          }
          return Stack(
            children: [
              _buildTaskListContent(compact: true),
              if (_showLyricBook && _hasFeature('lyrics'))
                _buildLyricBookModal(),
            ],
          );
        }

        // Normal mode: Row with form panel, task list, detail panel
        return Row(
          children: [
            Container(
              width: panelWidth,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  right: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: _buildFormPanelContent(),
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildTaskListContent(compact: false),
                  if (_showLyricBook && _hasFeature('lyrics'))
                    _buildLyricBookModal(),
                ],
              ),
            ),
            if (_selectedTask != null)
              _buildDetailPanel(_selectedTask!, detailWidth),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar({bool compact = false}) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (compact) ...[
            _HoverIcon(
              icon: Icons.add_circle_outline,
              size: 20,
              color: AppColors.accent,
              hoverColor: Colors.white,
              tooltip: s.tooltipNew,
              onTap: () => setState(() => _showFormPanel = true),
            ),
            const SizedBox(width: 8),
          ],
          _buildWorkspaceDropdown(),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: s.tooltipFilter,
            elevation: 8,
            shadowColor: Colors.black54,
            onSelected: (rating) => _applyFilter(rating: rating == 0 ? null : rating),
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: Text(s.filterAll)),
              PopupMenuItem(value: 1, child: Text(s.filterLiked)),
              PopupMenuItem(value: -1, child: Text(s.filterDisliked)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list, size: 14, color: Color(0xFF5C9CE6)),
                  const SizedBox(width: 6),
                  Text(
                    _filterRating == null
                        ? s.filterAll
                        : _filterRating == 1
                            ? s.filterLiked
                            : s.filterDisliked,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: s.tooltipSortOrder,
            elevation: 8,
            shadowColor: Colors.black54,
            onSelected: (sort) => _applyFilter(sort: sort),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'newest', child: Text(s.sortNewestFirst)),
              PopupMenuItem(value: 'oldest', child: Text(s.sortOldestFirst)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 14, color: Color(0xFF5C9CE6)),
                  const SizedBox(width: 6),
                  Text(
                    _sortOrder == 'newest' ? s.sortNewestFirst : s.sortOldestFirst,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceDropdown() {
    return ValueListenableBuilder<List<Workspace>>(
      valueListenable: _client.workspaces,
      builder: (context, workspaces, _) {
        return ValueListenableBuilder<Workspace?>(
          valueListenable: _client.activeWorkspace,
          builder: (context, active, _) {
            if (workspaces.isEmpty || active == null) {
              return const SizedBox.shrink();
            }
            return PopupMenuButton<String>(
              tooltip: 'Workspace',
              elevation: 8,
              shadowColor: Colors.black54,
              onSelected: (value) {
                if (value == 'create') {
                  _showCreateWorkspaceDialog();
                } else if (value.startsWith('select:')) {
                  final id = value.substring(7);
                  final ws = workspaces.firstWhere((w) => w.id == id);
                  _client.activeWorkspace.value = ws;
                }
              },
              itemBuilder: (_) => [
                for (final ws in workspaces)
                  PopupMenuItem(
                    value: 'select:${ws.id}',
                    child: Row(
                      children: [
                        if (ws.id == active.id)
                          const Icon(Icons.check,
                              size: 16, color: AppColors.accent)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ws.name,
                            style: TextStyle(
                              color: ws.id == active.id
                                  ? AppColors.accent
                                  : AppColors.text,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!ws.isDefault) ...[
                          const SizedBox(width: 8),
                          _HoverIcon(
                            icon: Icons.edit_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                            hoverColor: AppColors.accent,
                            tooltip: 'Rename',
                            onTap: () {
                              Navigator.of(context).pop();
                              _showRenameWorkspaceDialog(ws);
                            },
                          ),
                          const SizedBox(width: 4),
                          _HoverIcon(
                            icon: Icons.delete_outline,
                            size: 14,
                            color: AppColors.textMuted,
                            hoverColor: Colors.redAccent,
                            tooltip: 'Delete',
                            onTap: () {
                              Navigator.of(context).pop();
                              _showDeleteWorkspaceDialog(ws);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.accent),
                      SizedBox(width: 8),
                      Text(
                        'New workspace',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined,
                        size: 14, color: Color(0xFF5C9CE6)),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        active.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateWorkspaceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workspace name'),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(ctx).pop();
              final ws = await _client.createWorkspace(name);
              await _client.loadWorkspaces();
              _client.activeWorkspace.value = ws;
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop();
                final ws = await _client.createWorkspace(name);
                await _client.loadWorkspaces();
                _client.activeWorkspace.value = ws;
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameWorkspaceDialog(Workspace ws) {
    final controller = TextEditingController(text: ws.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workspace name'),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(ctx).pop();
              await _client.renameWorkspace(ws.id, name);
              await _client.loadWorkspaces();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop();
                await _client.renameWorkspace(ws.id, name);
                await _client.loadWorkspaces();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteWorkspaceDialog(Workspace ws) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workspace'),
        content: Text(
          'Songs in "${ws.name}" will be moved to My Workspace. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final wasActive = _client.activeWorkspace.value?.id == ws.id;
              await _client.deleteWorkspace(ws.id);
              await _client.loadWorkspaces();
              if (wasActive) {
                final list = _client.workspaces.value;
                _client.activeWorkspace.value = list.firstWhere(
                  (w) => w.isDefault,
                  orElse: () => list.first,
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar() {
    final s = S.of(context);
    final count = _selectedTaskIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (count > 0) ...[
            SizedBox(
              height: 28,
              child: TextButton(
                onPressed: () => setState(() {
                  _selectedTaskIds.clear();
                  _lastSelectedIndex = null;
                  _multiSelectMode = false;
                }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(s.buttonUnselect,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                onPressed: _batchMoving ? null : _batchMoveToWorkspace,
                icon: _batchMoving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.drive_file_move_outline, size: 16),
                label: Text(s.buttonMoveCount(count),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A3A), fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C9CE6),
                  foregroundColor: const Color(0xFF1A1A3A),
                  side: const BorderSide(color: Color(0xFF1A1A3A)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                onPressed: _batchDeleting ? null : _confirmBatchDelete,
                icon: _batchDeleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_outline, size: 16),
                label: Text(s.buttonDeleteCount(count),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF3A1A1A), fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: const Color(0xFF3A1A1A),
                  side: const BorderSide(color: Color(0xFF3A1A1A)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmBatchDelete() async {
    final s = S.of(context);
    final count = _selectedTaskIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title:
            Text(s.dialogDeleteSongsTitle, style: const TextStyle(color: AppColors.text)),
        content: Text(
          s.dialogDeleteSongsContent(count),
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.buttonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _batchDeleting = true);
    try {
      await _client.batchDeleteSongs(taskIds: _selectedTaskIds.toList());
      if (mounted) {
        setState(() {
          _tasks.removeWhere((t) => _selectedTaskIds.contains(t.taskId));
          _songs.removeWhere((t) => _selectedTaskIds.contains(t.taskId));
          if (_selectedTask != null &&
              _selectedTaskIds.contains(_selectedTask!.taskId)) {
            _selectTask(null);
          }
          _selectedTaskIds.clear();
          _multiSelectMode = false;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _batchDeleting = false);
  }

  Future<void> _batchMoveToWorkspace() async {
    final s = S.of(context);
    final workspaces = _client.workspaces.value;
    final currentId = _client.activeWorkspace.value?.id;
    final others = workspaces.where((w) => w.id != currentId).toList();

    final selected = await showDialog<Workspace>(
      context: context,
      builder: (dialogCtx) => _MoveToWorkspaceDialog(
        workspaces: others,
        api: _client,
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _batchMoving = true);
    try {
      for (final taskId in _selectedTaskIds) {
        await _client.moveSong(taskId: taskId, workspaceId: selected.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.movedToWorkspace(selected.name))),
        );
        setState(() {
          _tasks.removeWhere((t) => _selectedTaskIds.contains(t.taskId));
          _songs.removeWhere((t) => _selectedTaskIds.contains(t.taskId));
          if (_selectedTask != null &&
              _selectedTaskIds.contains(_selectedTask!.taskId)) {
            _selectTask(null);
          }
          _selectedTaskIds.clear();
          _multiSelectMode = false;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _batchMoving = false);
  }

  Widget _buildDetailPanel(TaskStatus task, double width) {
    final s = S.of(context);
    final displayTitle = task.title ?? task.prompt ?? task.taskType;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.detailsHeading,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _detailLabelColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: _detailLabelColor),
                  onPressed: () => setState(() => _selectTask(null)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover art
                  if (task.isComplete)
                    ValueListenableBuilder<PlayingTrack?>(
                      valueListenable: NowPlaying.instance.track,
                      builder: (context, currentTrack, _) {
                        final taskUrl = _client.songDownloadUrl(task.taskId);
                        final isThisTrack = currentTrack?.audioUrl == taskUrl;
                        return ValueListenableBuilder<bool>(
                          valueListenable: NowPlaying.instance.playing,
                          builder: (context, playing, _) {
                            return ValueListenableBuilder<double>(
                              valueListenable: NowPlaying.instance.progress,
                              builder: (context, progress, _) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Center(
                                    child: CoverArt(
                                      audioUrl: taskUrl,
                                      size: 268,
                                      borderRadius: 6,
                                      isPlaying: isThisTrack && playing,
                                      playbackProgress:
                                          isThisTrack && playing ? progress : null,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  // Title
                  _detailLabelWithAction(
                    s.labelTitle,
                    icon: _editingDetailTitle ? Icons.close : Icons.edit,
                    onTap: () => setState(() {
                      if (_editingDetailTitle) {
                        _editingDetailTitle = false;
                      } else {
                        _detailTitleController.text =
                            task.title ?? task.prompt ?? task.taskType;
                        _editingDetailTitle = true;
                      }
                    }),
                  ),
                  const SizedBox(height: 4),
                  if (_editingDetailTitle)
                    TextField(
                      controller: _detailTitleController,
                      autofocus: true,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _saveDetailTitle(),
                    )
                  else
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Model
                  if (task.model != null) ...[
                    _detailLabel(s.labelModel),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _modelBadge(task.model!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Prompt
                  if (task.prompt != null && task.prompt!.isNotEmpty) ...[
                    _detailLabelWithCopy(s.labelPrompt, task.prompt!),
                    const SizedBox(height: 4),
                    Text(
                      task.prompt!,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Lyrics
                  _detailLabelWithActions(
                    s.labelLyrics,
                    actions: [
                      if (task.lyrics != null && task.lyrics!.isNotEmpty)
                        _iconAction(
                          Icons.copy,
                          () {
                            Clipboard.setData(
                              ClipboardData(text: task.lyrics!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.accent,
                                content: Text(s.snackbarLyricsCopied),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      _iconAction(
                        _editingDetailLyrics ? Icons.close : Icons.edit,
                        () => setState(() {
                          if (_editingDetailLyrics) {
                            _editingDetailLyrics = false;
                          } else {
                            _detailLyricsController.text =
                                task.lyrics ?? '';
                            _editingDetailLyrics = true;
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_editingDetailLyrics)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _detailLyricsController,
                          autofocus: true,
                          maxLines: null,
                          minLines: 4,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.all(8),
                            border: const OutlineInputBorder(),
                            hintText: s.hintEnterLyrics,
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: _saveDetailLyrics,
                              child: Text(s.buttonSave, style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (task.lyrics != null &&
                      task.lyrics!.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        children: _buildLyricsSpans(task.lyrics!),
                      ),
                    )
                  else
                    Text(
                      s.noLyrics,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Created at
                  if (task.createdAt != null) ...[
                    _detailLabel(s.labelCreated),
                    const SizedBox(height: 4),
                    Text(
                      _formatDetailDate(task.createdAt!),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Creation parameters (collapsible)
                  if (_detailParameters != null &&
                      _detailParameters!.isNotEmpty) ...[
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() =>
                          _parametersExpanded = !_parametersExpanded),
                      child: Row(
                        children: [
                          _detailLabel(s.labelParameters),
                          const SizedBox(width: 4),
                          Icon(
                            _parametersExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: _detailLabelColor,
                          ),
                        ],
                      ),
                    ),
                    if (_parametersExpanded) ...[
                      const SizedBox(height: 8),
                      ..._detailParameters!.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  _formatParamLabel(e.key),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value.toString(),
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                  ] else if (_loadingDetails) ...[
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Set Parameters button
                  if (task.taskType != 'upload') ...[
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () => _applyParametersFromTask(task),
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(
                          s.labelSetParameters,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.lightBlue,
                          side: const BorderSide(color: Colors.lightBlue),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailDate(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day}/${date.year} at $h:$m';
  }

  static String _formatParamLabel(String snakeCase) {
    return snakeCase
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  List<TextSpan> _buildLyricsSpans(String lyrics) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\[([^\]]*)\]');
    var lastEnd = 0;
    for (final match in regex.allMatches(lyrics)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: lyrics.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: AppColors.accent),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < lyrics.length) {
      spans.add(TextSpan(text: lyrics.substring(lastEnd)));
    }
    return spans;
  }

  static const _detailLabelColor = Color(0xFF90CAF9);

  Widget _detailLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _detailLabelColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _detailLabelWithCopy(String label, String copyText) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailLabelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: copyText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.accent,
                content: Text(S.of(context).labelCopied(label)),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: const MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(
              Icons.copy,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailLabelWithAction(
    String label, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailLabelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        _iconAction(icon, onTap),
      ],
    );
  }

  Widget _detailLabelWithActions(
    String label, {
    required List<Widget> actions,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailLabelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        ...actions,
      ],
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final s = seconds.round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}m' : '${m}m ${rem}s';
  }

  // ---------------------------------------------------------------------------
  // Model defaults
  // ---------------------------------------------------------------------------

  double _default(String key, double fallback) =>
      (_serverDefaults?[key] as num?)?.toDouble() ?? fallback;

  void _applyDefaults() {
    setState(() {
      _creativity = _default('temperature', _defaultCreativity);
      _promptStrength = _default('guidance_scale', _defaultPromptStrength);
      _quality = _default('inference_steps', _defaultQuality);
      _duration = _default('duration', _defaultDuration);
      _variations = _default('batch_size', _defaultVariations);
      _cfgScale = _default('cfg_scale', _defaultCfgScale);
      _topP = _default('top_p', _defaultTopP);
      _repetitionPenalty =
          _default('repetition_penalty', _defaultRepetitionPenalty);
      _shift = _default('shift', _defaultShift);
      _cfgIntervalStart =
          _default('cfg_interval_start', _defaultCfgIntervalStart);
      _cfgIntervalEnd = _default('cfg_interval_end', _defaultCfgIntervalEnd);
      _thinking = (_serverDefaults?['thinking'] as bool?) ?? false;
      _constrainedDecoding =
          (_serverDefaults?['constrained_decoding'] as bool?) ?? false;
      _useRandomSeed =
          (_serverDefaults?['use_random_seed'] as bool?) ?? true;

    });
  }

  Future<void> _fetchDefaults() async {
    final requestedModel = _model;
    try {
      _serverDefaults = await _client.getModelDefaults(_model);
      _applyDefaults();
    } catch (_) {
      // Server unreachable — keep current (fallback) values.
    }
    try {
      final caps = await _client.getModelCapabilities(requestedModel);
      if (!mounted || _model != requestedModel) return;
      setState(() {
        _capabilities = caps;
        if (!_capabilities!.supportsTaskType(_taskType)) {
          _taskType = 'generate';
        }
      });
    } catch (_) {
      // Server unreachable — keep showing all controls.
    }
  }

  void _resetToDefaults() => _applyDefaults();

  // LoRA
  // ---------------------------------------------------------------------------

  Future<void> _refreshLoraStatus() async {
    setState(() {
      _loraLoading = true;
      _loraError = null;
    });
    try {
      final results = await Future.wait([
        _client.getLoraList(),
        _client.getLoraStatus(),
      ]);
      final loras = results[0] as List<Map<String, dynamic>>;
      final status = results[1] as Map<String, dynamic>;
      final active = loras.where((l) => l['active'] == true).toList();
      setState(() {
        _availableLoras = loras;
        _loraLoaded = loras.any((l) => l['loaded'] == true);
        _loraActiveAdapter = active.isNotEmpty
            ? active.first['name'] as String?
            : null;
        _useLora = status['use_lora'] as bool? ?? _loraActiveAdapter != null;
        _loraScale = (status['lora_scale'] as num?)?.toDouble() ?? 1.0;
      });
    } catch (e) {
      setState(() => _loraError = userFriendlyError(e));
    } finally {
      setState(() => _loraLoading = false);
    }
  }

  Future<void> _selectLora(String name) async {
    setState(() {
      _loraLoading = true;
      _loraError = null;
    });
    try {
      await _client.loadLora(name);
      _loraToLoad = null;
      await _refreshLoraStatus();
    } catch (e) {
      setState(() {
        _loraError = userFriendlyError(e);
        _loraLoading = false;
      });
    }
  }

  Future<void> _unloadLora() async {
    setState(() {
      _loraLoading = true;
      _loraError = null;
    });
    try {
      await _client.unloadLora();
      await _refreshLoraStatus();
    } catch (e) {
      setState(() {
        _loraError = userFriendlyError(e);
        _loraLoading = false;
      });
    }
  }

  Future<void> _toggleLora(bool value) async {
    setState(() => _useLora = value);
    try {
      await _client.toggleLora(value);
    } catch (e) {
      setState(() => _loraError = userFriendlyError(e));
      await _refreshLoraStatus();
    }
  }

  Future<void> _setLoraScale(double value) async {
    try {
      await _client.setLoraScale(value);
    } catch (e) {
      setState(() => _loraError = userFriendlyError(e));
      await _refreshLoraStatus();
    }
  }

  Widget _buildLoraScaleSlider() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.labelLoraScale,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              _loraScale.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.controlPink,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          s.subtitleLoraScale,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.controlPink,
            inactiveTrackColor: AppColors.surfaceHigh,
            thumbColor: AppColors.controlPink,
            overlayColor: AppColors.controlPink.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _loraScale,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (v) => setState(() => _loraScale = v),
            onChangeEnd: _setLoraScale,
          ),
        ),
      ],
    );
  }

  Widget _buildLoraSection() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            final wasExpanded = _loraExpanded;
            setState(() => _loraExpanded = !_loraExpanded);
            if (!wasExpanded) _refreshLoraStatus();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Transform.rotate(
                  angle: _loraExpanded ? 1.5708 : 0,
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  s.labelLora,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                if (_loraLoaded) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _useLora ? Colors.greenAccent : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_loraExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _loraLoading && !_loraLoaded
                ? const Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active adapter dropdown (loaded only)
                      _label(s.labelActiveAdapter),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        value: _loraActiveAdapter ?? 'none',
                        items: [
                          'none',
                          ..._availableLoras
                              .where((l) => l['loaded'] == true)
                              .map((l) => l['name'] as String),
                        ],
                        onChanged: (v) {
                          if (v == null || v == 'none') {
                            _toggleLora(false);
                          } else {
                            _selectLora(v);
                          }
                        },
                      ),
                      if (_useLora) ...[
                        const SizedBox(height: 8),
                        _buildLoraScaleSlider(),
                      ],
                      if (_loraLoaded) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _loraLoading ? null : _unloadLora,
                            child: Text(s.buttonUnloadAll),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 12),
                      // Load new LoRA (collapsed)
                      GestureDetector(
                        onTap: () => setState(
                          () => _loraLoadExpanded = !_loraLoadExpanded,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            children: [
                              Transform.rotate(
                                angle: _loraLoadExpanded ? 1.5708 : 0,
                                child: const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.labelLoadNew,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_loraLoadExpanded) ...[
                        const SizedBox(height: 8),
                        _label(s.labelAvailableLoras),
                        const SizedBox(height: 6),
                        _buildDropdown(
                          value: _loraToLoad ?? '',
                          items: [
                            '',
                            ..._availableLoras
                                .where((l) => l['loaded'] != true)
                                .map((l) => l['name'] as String),
                          ],
                          onChanged: (v) =>
                              setState(() => _loraToLoad = v?.isEmpty == true ? null : v),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loraLoading || _loraToLoad == null
                                ? null
                                : () => _selectLora(_loraToLoad!),
                            child: _loraLoading
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(s.buttonLoadLora),
                          ),
                        ),
                      ],
                      if (_loraError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _loraError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _advancedExpanded = !_advancedExpanded),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: _advancedExpanded ? 1.5708 : 0,
                        child: const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.labelAdvanced,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_advancedExpanded)
              GestureDetector(
                onTap: _resetToDefaults,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    s.buttonReset,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_advancedExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                if (_supportsParam('temperature'))
                  _buildSlider(
                    label: s.labelCreativity,
                    subtitle: s.subtitleCreativity,
                    info: s.infoCreativity,
                    value: _creativity,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    displayValue: _creativity.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _creativity = v),
                  ),
                if (_supportsParam('guidance_scale')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelPromptStrength,
                    subtitle: s.subtitlePromptStrength,
                    info: s.infoPromptStrength,
                    value: _promptStrength,
                    min: 1.0,
                    max: 15.0,
                    divisions: 28,
                    displayValue: _promptStrength.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _promptStrength = v),
                  ),
                ],
                if (_supportsParam('inference_steps')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelQuality,
                    subtitle: s.subtitleQuality,
                    info: s.infoQuality,
                    value: _quality,
                    min: 10,
                    max: 150,
                    divisions: 14,
                    displayValue: _quality.round().toString(),
                    onChanged: (v) => setState(() => _quality = v),
                  ),
                ],
                if (_supportsParam('audio_duration')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelDuration,
                    subtitle: s.subtitleDuration,
                    info: s.infoDuration,
                    value: _duration,
                    min: 5,
                    max: 300,
                    divisions: 59,
                    displayValue: _formatDuration(_duration),
                    onChanged: (v) => setState(() => _duration = v),
                  ),
                ],
                if (_supportsParam('batch_size')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelVariations,
                    subtitle: s.subtitleVariations,
                    info: s.infoVariations,
                    value: _variations,
                    min: 1,
                    max: 4,
                    divisions: 3,
                    displayValue: _variations.round().toString(),
                    onChanged: (v) => setState(() => _variations = v),
                  ),
                ],
                if (_supportsParam('cfg_scale')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelCfgScale,
                    subtitle: s.subtitleCfgScale,
                    info: s.infoCfgScale,
                    value: _cfgScale,
                    min: 0.0,
                    max: 15.0,
                    divisions: 30,
                    displayValue: _cfgScale.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _cfgScale = v),
                  ),
                ],
                if (_supportsParam('top_p')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelTopP,
                    subtitle: s.subtitleTopP,
                    info: s.infoTopP,
                    value: _topP,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    displayValue: _topP.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _topP = v),
                  ),
                ],
                if (_supportsParam('repetition_penalty')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelRepetitionPenalty,
                    subtitle: s.subtitleRepetitionPenalty,
                    info: s.infoRepetitionPenalty,
                    value: _repetitionPenalty,
                    min: 1.0,
                    max: 2.0,
                    divisions: 20,
                    displayValue: _repetitionPenalty.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _repetitionPenalty = v),
                  ),
                ],
                if (_supportsParam('shift')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelShift,
                    subtitle: s.subtitleShift,
                    info: s.infoShift,
                    value: _shift,
                    min: 0.0,
                    max: 5.0,
                    divisions: 50,
                    displayValue: _shift.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _shift = v),
                  ),
                ],
                if (_supportsParam('cfg_interval_start')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelCfgIntervalStart,
                    subtitle: s.subtitleCfgIntervalStart,
                    info: s.infoCfgIntervalStart,
                    value: _cfgIntervalStart,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    displayValue: _cfgIntervalStart.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _cfgIntervalStart = v),
                  ),
                ],
                if (_supportsParam('cfg_interval_end')) ...[
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelCfgIntervalEnd,
                    subtitle: s.subtitleCfgIntervalEnd,
                    info: s.infoCfgIntervalEnd,
                    value: _cfgIntervalEnd,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    displayValue: _cfgIntervalEnd.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _cfgIntervalEnd = v),
                  ),
                ],
                if (_hasFeature('negative_prompt')) ...[
                  const SizedBox(height: 12),
                  _label(s.labelAvoid),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _negativePromptController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: s.hintDescribeAvoid,
                    ),
                  ),
                ],
                if (_supportsParam('thinking')) ...[
                  const SizedBox(height: 12),
                  _buildToggle(
                    label: s.labelThinking,
                    subtitle: s.subtitleThinking,
                    info: s.infoThinking,
                    value: _thinking,
                    onChanged: (v) => setState(() => _thinking = v),
                  ),
                ],
                if (_supportsParam('constrained_decoding')) ...[
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelConstrainedDecoding,
                    subtitle: s.subtitleConstrainedDecoding,
                    info: s.infoConstrainedDecoding,
                    value: _constrainedDecoding,
                    onChanged: (v) => setState(() => _constrainedDecoding = v),
                  ),
                ],
                if (_supportsParam('use_random_seed')) ...[
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelRandomSeed,
                    subtitle: s.subtitleRandomSeed,
                    info: s.infoRandomSeed,
                    value: _useRandomSeed,
                    onChanged: (v) => setState(() => _useRandomSeed = v),
                  ),
                ],
                if (!_useRandomSeed) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _seedController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: s.labelSeed,
                            hintText: s.hintEnterNumber,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (_hasFeature('lora')) ...[
                  const SizedBox(height: 12),
                  _buildLoraSection(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
    String? info,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (info != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: info,
                      child: const Icon(
                        Icons.info_outline,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.controlPink,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.controlPink,
            inactiveTrackColor: AppColors.surfaceHigh,
            thumbColor: AppColors.controlPink,
            overlayColor: AppColors.controlPink.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? info,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (info != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: info,
                      child: const Icon(
                        Icons.info_outline,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.controlPink,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskFields() {
    return switch (_taskType) {
      'generate' => _buildGenerateFields(),
      'generate_long' => _buildGenerateFields(),
      'upload' => _buildUploadFields(),
      'infill' => _buildInfillFields(),
      'cover' => _buildCoverFields(),
      'extract' => _buildStemFields(),
      'add_stem' => _buildAddStemFields(),
      'extend' => _buildExtendFields(),
      'crop' => _buildCropFields(),
      'fade' => _buildFadeFields(),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'ogg', 'aac', 'm4a'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Widget _buildUploadFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelAudioFile),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _submitting ? null : _pickFile,
          child: MouseRegion(
            cursor: _submitting
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _pickedFile != null
                      ? AppColors.controlPink
                      : AppColors.border,
                ),
              ),
              child: _pickedFile != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedFile!.name,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(_pickedFile!.size),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(
                          Icons.upload_file,
                          color: AppColors.textMuted,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.clickToSelectAudioFile,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_uploadProgress > 0 && _uploadProgress < 1) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.controlPink,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _buildPromptWithGenres() {
    final prompt = _promptController.text;
    if (_selectedGenres.isEmpty) return prompt;
    final genreStr = _selectedGenres.map((g) => g.key).join(', ');
    if (prompt.isEmpty) return genreStr;
    return '$genreStr. $prompt';
  }

  void _onGenresChanged(List<MapEntry<String, MajorGenre>> genres) {
    setState(() {
      _selectedGenres
        ..clear()
        ..addAll(genres);
    });
  }

  Widget _buildGenrePrompt({required String hintText}) {
    return GenreAutocomplete(
      promptController: _promptController,
      selectedGenres: _selectedGenres,
      onChanged: _onGenresChanged,
      hintText: hintText,
    );
  }

  Widget _buildGenerateFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasFeature('lyrics')) ...[
          _buildInstrumentalToggle(),
          const SizedBox(height: 12),
        ],
        if (_instrumental) ...[
          _label(s.labelTitle),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: s.hintSongTitle,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!_instrumental && _hasFeature('lyrics')) ...[
          _label(s.labelTitle),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: s.hintSongTitle,
            ),
          ),
          const SizedBox(height: 12),
          _buildLyricsBookRow(),
          const SizedBox(height: 6),
          _buildLyricsTextField(s),
          const SizedBox(height: 12),
        ],
        _labelWithGenerate(
          s.labelPrompt,
          onGenerate: _generatingPrompt ? null : _generatePromptAi,
          generating: _generatingPrompt,
        ),
        const SizedBox(height: 6),
        _buildGenrePrompt(hintText: s.hintDescribeStyle),
      ],
    );
  }

  Widget _buildTimeRow({
    required String startLabel,
    required TextEditingController startMinController,
    required TextEditingController startSecController,
    required String endLabel,
    required TextEditingController endMinController,
    required TextEditingController endSecController,
  }) {
    Widget timeField(
      String label,
      TextEditingController minCtrl,
      TextEditingController secCtrl,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 'm',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':', style: TextStyle(color: AppColors.text)),
              ),
              Expanded(
                child: TextField(
                  controller: secCtrl,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 's',
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: timeField(startLabel, startMinController, startSecController),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: timeField(
            endLabel,
            endMinController,
            endSecController,
          ),
        ),
      ],
    );
  }

  Widget _buildInfillFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_infillBytes != null && _infillDuration != null) ...[
          _WaveformEditor(
            bytes: _infillBytes!,
            duration: _infillDuration!,
            initialStart: _timeToSeconds(
              _infillStartMinController,
              _infillStartSecController,
            ),
            initialEnd: _timeToSeconds(
              _infillEndMinController,
              _infillEndSecController,
            ),
            onChanged: (startSec, endSec) {
              _setTimeFromSeconds(
                startSec,
                _infillStartMinController,
                _infillStartSecController,
              );
              _setTimeFromSeconds(
                endSec,
                _infillEndMinController,
                _infillEndSecController,
              );
            },
          ),
          const SizedBox(height: 12),
        ] else if (_loadingWaveform) ...[
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _buildTimeRow(
          startLabel: s.labelStart,
          startMinController: _infillStartMinController,
          startSecController: _infillStartSecController,
          endLabel: s.labelEnd,
          endMinController: _infillEndMinController,
          endSecController: _infillEndSecController,
        ),
        const SizedBox(height: 12),
        _labelWithGenerate(
          s.labelPrompt,
          onGenerate: _generatingPrompt ? null : _generatePromptAi,
          generating: _generatingPrompt,
        ),
        const SizedBox(height: 6),
        _buildGenrePrompt(hintText: s.hintDescribeStyle),
        if (_hasFeature('lyrics')) ...[
          const SizedBox(height: 12),
          _buildInstrumentalToggle(),
          const SizedBox(height: 12),
          if (!_instrumental) ...[
            _buildLyricsBookRow(),
            const SizedBox(height: 6),
            _buildLyricsTextField(s),
          ],
        ],
      ],
    );
  }

  Widget _buildCoverFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _labelWithGenerate(
          s.labelPrompt,
          onGenerate: _generatingPrompt ? null : _generatePromptAi,
          generating: _generatingPrompt,
        ),
        const SizedBox(height: 6),
        _buildGenrePrompt(hintText: s.hintDescribeStyle),
        if (_hasFeature('lyrics')) ...[
          const SizedBox(height: 12),
          _buildInstrumentalToggle(),
          const SizedBox(height: 12),
          if (!_instrumental) ...[
            _buildLyricsBookRow(),
            const SizedBox(height: 6),
            _buildLyricsTextField(s),
          ],
        ],
      ],
    );
  }

  Widget _buildStemFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _label(s.labelStem),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _stemName,
          items: _stemNames,
          onChanged: (v) => setState(() => _stemName = v!),
        ),
      ],
    );
  }

  Widget _buildAddStemFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _label(s.labelStem),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _stemName,
          items: _stemNames,
          onChanged: (v) => setState(() => _stemName = v!),
        ),
        const SizedBox(height: 12),
        _label(s.labelPrompt),
        const SizedBox(height: 6),
        _buildGenrePrompt(hintText: s.hintDescribeStem),
      ],
    );
  }

  Widget _buildExtendFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _buildTimeRow(
          startLabel: s.labelStart,
          startMinController: _repaintStartMinController,
          startSecController: _repaintStartSecController,
          endLabel: s.labelEnd,
          endMinController: _repaintEndMinController,
          endSecController: _repaintEndSecController,
        ),
        const SizedBox(height: 12),
        _label(s.labelPrompt),
        const SizedBox(height: 6),
        _buildGenrePrompt(hintText: s.hintDescribeExtendStyle),
        if (_hasFeature('lyrics')) ...[
          const SizedBox(height: 12),
          _buildInstrumentalToggle(),
          const SizedBox(height: 12),
          if (!_instrumental) _buildLyricsBookRow(),
        ],
        const SizedBox(height: 12),
        _label(s.labelTrackClasses),
        const SizedBox(height: 6),
        TextField(
          controller: _trackClassesController,
          decoration: InputDecoration(hintText: s.hintTrackClasses),
        ),
      ],
    );
  }

  Widget _buildCropFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        _buildTimeRow(
          startLabel: s.labelStart,
          startMinController: _cropStartMinController,
          startSecController: _cropStartSecController,
          endLabel: s.labelEnd,
          endMinController: _cropEndMinController,
          endSecController: _cropEndSecController,
        ),
      ],
    );
  }

  Widget _buildFadeFields() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(s.labelSourceClip),
        const SizedBox(height: 6),
        _buildSourceClip(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(s.labelFadeIn),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _fadeInController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(s.labelFadeOut),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _fadeOutController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      dropdownColor: AppColors.surfaceHigh,
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Tooltip(
                  message: _taskTypeDescription(e, S.of(context)),
                  child: Row(
                    children: [
                      Icon(_taskTypeIcon(e), size: 16, color: _taskTypeColor(e)),
                      const SizedBox(width: 8),
                      Text(e),
                    ],
                  ),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  void _clearSourceClip() {
    setState(() {
      _srcAudioPathController.clear();
      _srcAudioLabel = null;
      _srcAudioUrl = null;
      _infillBytes = null;
      _infillDuration = null;
    });
  }

  Widget _buildSourceClip() {
    final s = S.of(context);
    final label = _srcAudioLabel;
    final url = _srcAudioUrl;

    return DragTarget<TaskStatus>(
      onWillAcceptWithDetails: (details) =>
          details.data.isComplete && _audioPathFromTask(details.data) != null,
      onAcceptWithDetails: (details) => _setSourceFromTask(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;

        if (label == null || url == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovering ? AppColors.controlPink : AppColors.border,
              ),
            ),
            child: Text(
              hovering ? s.dropToSetSourceClip : s.dragAndDropClip,
              style: TextStyle(
                color: hovering ? AppColors.controlPink : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovering
                  ? AppColors.controlPink
                  : AppColors.controlPink.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  NowPlaying.instance.setQueue([
                    PlayingTrack(id: url, title: label, audioUrl: url),
                  ], startAt: 0);
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.play_arrow,
                    color: AppColors.controlPink,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _clearSourceClip,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(Icons.close, color: AppColors.textMuted, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF90CAF9),
      ),
    );
  }

  /// A label row with an AI generate button on the trailing edge.
  Widget _labelWithGenerate(
    String text, {
    required VoidCallback? onGenerate,
    required bool generating,
  }) {
    final s = S.of(context);
    return Row(
      children: [
        _label(text),
        const Spacer(),
        if (generating)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        else
          Tooltip(
            message: s.tooltipGenerateWithAi(text),
            child: GestureDetector(
              onTap: onGenerate,
              child: Icon(
                Icons.psychology,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstrumentalToggle() {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _instrumental = false;
              _showLyricBook = false;
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: !_instrumental
                          ? AppColors.accent
                          : AppColors.border,
                      width: !_instrumental ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  s.labelLyrics,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !_instrumental
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _instrumental = true;
              _showLyricBook = false;
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _instrumental
                          ? AppColors.accent
                          : AppColors.border,
                      width: _instrumental ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  s.sampleLabelInstrumental,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _instrumental
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A label row with an AI generate button and a lyric book toggle button.
  Widget _buildLyricsBookRow() {
    final s = S.of(context);
    return Row(
      children: [
        _label(s.labelLyrics),
        const SizedBox(width: 6),
        Tooltip(
          message: s.tooltipOpenLyricBook,
          child: GestureDetector(
            onTap: () => setState(() => _showLyricBook = !_showLyricBook),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                _showLyricBook ? Icons.menu_book : Icons.menu_book_outlined,
                size: 16,
                color: _showLyricBook
                    ? AppColors.accent
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (_generatingLyrics)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        else
          Tooltip(
            message: s.tooltipGenerateWithAi(s.labelLyrics),
            child: GestureDetector(
              onTap: _generateLyricsAi,
              child: Icon(
                Icons.psychology,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLyricsTextField(S s) {
    return TextField(
      controller: _lyricsController,
      maxLines: 8,
      minLines: 3,
      style: const TextStyle(fontSize: 13, color: AppColors.text),
      decoration: InputDecoration(
        hintText: s.hintEnterLyrics,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.accent),
        ),
        contentPadding: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _loadLyricSheets() async {
    if (_lyricSheetsLoaded) return;
    try {
      final sheets = await _client.getLyricSheets();
      if (!mounted) return;
      setState(() {
        _lyricSheets = sheets;
        _lyricSheetsLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _saveToLyricBook() async {
    final s = S.of(context);
    final content = _lyricsController.text;
    if (content.trim().isEmpty) return;
    try {
      final sheet = await _client.createLyricSheet(
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'Untitled',
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _lyricSheets.insert(0, sheet);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.lyricBookSaved)),
      );
    } catch (_) {}
  }

  void _onLyricSheetTap(LyricSheet sheet) {
    if (_lyricsController.text.trim().isNotEmpty) {
      setState(() => _previewingSheet = sheet);
    } else {
      _applyLyricSheet(sheet);
    }
  }

  void _applyLyricSheet(LyricSheet sheet) {
    setState(() {
      _lyricsController.text = sheet.content;
      _selectedLyricSheetId = sheet.id;
      if (sheet.title.isNotEmpty && _titleController.text.isEmpty) {
        _titleController.text = sheet.title;
      }
      _previewingSheet = null;
    });
  }

  Future<void> _deleteLyricSheetFromModal(LyricSheet sheet) async {
    final s = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.lyricBookDeleteTitle),
        content: Text(s.lyricBookDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.buttonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _client.deleteLyricSheet(sheet.id);
      if (!mounted) return;
      setState(() {
        _lyricSheets.removeWhere((s) => s.id == sheet.id);
        if (_selectedLyricSheetId == sheet.id) {
          _selectedLyricSheetId = null;
        }
      });
    } catch (_) {}
  }

  Widget _buildLyricSheetPreview(S s, LyricSheet sheet) {
    final blocks = parseLyricsBlocks(sheet.content);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheet.title.isEmpty ? 'Untitled' : sheet.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                for (final block in blocks)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                                child: Text(
                                  block.header,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                child: Text(
                                  block.content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            color: blockTypeColor(block.header),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                s.lyricBookReplaceContent,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _previewingSheet = null),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      s.buttonCancel,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _applyLyricSheet(sheet),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.buttonReplace,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLyricBookModal() {
    final s = S.of(context);
    _loadLyricSheets();
    return Positioned.fill(
      child: Container(
        color: AppColors.overlay(0.5),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, size: 18, color: _detailLabelColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.labelLyricBook,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _detailLabelColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _saveToLyricBook,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.save_outlined, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  s.lyricBookSaveToBook,
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: _detailLabelColor),
                        onPressed: () => setState(() { _showLyricBook = false; _previewingSheet = null; }),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        width: 220,
                        color: AppColors.background,
                        child: Column(
                          children: [
                            Expanded(
                              child: _lyricSheets.isEmpty
                                  ? Center(
                                      child: Text(
                                        s.lyricBookNoSheets,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _lyricSheets.length,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (_, i) {
                                        final sheet = _lyricSheets[i];
                                        final selected = _previewingSheet?.id == sheet.id;
                                        return GestureDetector(
                                          onTap: () => _onLyricSheetTap(sheet),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? AppColors.accent.withValues(alpha: 0.10)
                                                    : Colors.transparent,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      sheet.title.isEmpty ? 'Untitled' : sheet.title,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: selected ? AppColors.accent : AppColors.text,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () => _deleteLyricSheetFromModal(sheet),
                                                    child: const MouseRegion(
                                                      cursor: SystemMouseCursors.click,
                                                      child: Padding(
                                                        padding: EdgeInsets.all(2),
                                                        child: Icon(
                                                          Icons.delete_outline,
                                                          size: 14,
                                                          color: AppColors.accent,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, color: AppColors.border),
                      Expanded(
                        child: _previewingSheet != null
                            ? _buildLyricSheetPreview(s, _previewingSheet!)
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label(s.labelTitle),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _titleController,
                                      decoration: InputDecoration(
                                        hintText: s.hintSongTitle,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _label(s.labelLyrics),
                                    const SizedBox(height: 6),
                                    LyricsBlockEditor(
                                      controller: _lyricsController,
                                      hintText: s.hintEnterLyrics,
                                      onGenerateBlock: _generatingLyrics ? null : (_) => _generateLyricsAi(),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateLyricsAi() async {
    final s = S.of(context);
    final description = await _showDescriptionDialog(
      title: s.dialogGenerateLyricsTitle,
      hint: s.hintDescribeSongForLyrics,
    );
    if (description == null || !mounted) return;

    setState(() => _generatingLyrics = true);
    try {
      final lyrics = await _client.generateLyrics(
        _textModel, description, audioModel: _model);
      if (mounted) _lyricsController.text = lyrics;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.snackbarFailedGenerateLyrics(userFriendlyError(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingLyrics = false);
    }
  }

  Future<void> _generatePromptAi() async {
    final s = S.of(context);
    final description = await _showDescriptionDialog(
      title: s.dialogGeneratePromptTitle,
      hint: s.hintDescribeSongStyle,
    );
    if (description == null || !mounted) return;

    setState(() => _generatingPrompt = true);
    try {
      final prompt = await _client.generatePrompt(
        _textModel, description, audioModel: _model);
      if (mounted) _promptController.text = prompt;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.snackbarFailedGeneratePrompt(userFriendlyError(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPrompt = false);
    }
  }

  Future<String?> _showDescriptionDialog({
    required String title,
    required String hint,
  }) async {
    final s = S.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(s.buttonGenerate),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty == true ? null : result;
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    this.selected = false,
    this.multiSelectMode = false,
    this.multiSelected = false,
    this.onMultiSelectToggle,
    this.onTap,
    this.onUseAs,
    this.onUpdate,
    this.onDelete,
    this.queueTracks = const [],
  });
  final TaskStatus task;
  final bool selected;
  final bool multiSelectMode;
  final bool multiSelected;
  final VoidCallback? onMultiSelectToggle;
  final VoidCallback? onTap;
  final void Function(
    String taskType,
    String audioPath,
    String audioUrl,
    String label,
  )?
  onUseAs;
  final ValueChanged<TaskStatus>? onUpdate;
  final VoidCallback? onDelete;
  final List<PlayingTrack> queueTracks;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rainbowController;
  bool _hovered = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.task.isProcessing || widget.task.isUploading) {
      _rainbowController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.isProcessing || widget.task.isUploading) {
      if (!_rainbowController.isAnimating) _rainbowController.repeat();
    } else {
      _rainbowController.stop();
    }
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    super.dispose();
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return S.of(context).justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  String? _audioPath() {
    final r = widget.task.result;
    if (r == null) return null;
    final object = r['object'] as String?;
    if (object != null) return object;
    final results = r['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final first = results.first as Map<String, dynamic>;
      return first['file'] as String?;
    }
    return null;
  }

  List<PlayingTrack> _playingTracks() {
    if (!widget.task.isComplete) return [];
    final label =
        widget.task.title ?? widget.task.prompt ?? widget.task.taskType;
    final url =
        context.read<ApiClient>().songDownloadUrl(widget.task.taskId);
    return [PlayingTrack(id: widget.task.taskId, title: label, audioUrl: url)];
  }


  Future<void> _download() async {
    final s = S.of(context);
    setState(() => _downloading = true);
    try {
      final api = context.read<ApiClient>();
      final url = api.songDownloadUrl(widget.task.taskId);
      final bytes = await api.downloadAudioBytes(url);
      if (!mounted) return;
      final filename =
          '${widget.task.title ?? widget.task.taskId}.mp3';
      await saveFile(bytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accent,
            content: Text(s.snackbarDownloadComplete),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _confirmDelete() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          s.dialogDeleteSongTitle,
          style: const TextStyle(color: AppColors.text),
        ),
        content: Text(
          s.dialogDeleteSongContent,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.buttonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<ApiClient>().deleteSong(taskId: widget.task.taskId);
      widget.onDelete?.call();
    } catch (_) {}
  }

  Future<void> _toggleRating(int value) async {
    final current = widget.task.rating;
    final newRating = current == value ? 0 : value;
    try {
      await context.read<ApiClient>().updateSong(
        taskId: widget.task.taskId,
        rating: newRating,
      );
      widget.onUpdate?.call(
        newRating == 0
            ? widget.task.copyWith(clearRating: true)
            : widget.task.copyWith(rating: newRating),
      );
    } catch (_) {}
  }

  Future<void> _moveToWorkspace() async {
    final s = S.of(context);
    final api = context.read<ApiClient>();
    final workspaces = api.workspaces.value;
    final currentId = api.activeWorkspace.value?.id;
    final others = workspaces.where((w) => w.id != currentId).toList();

    final selected = await showDialog<Workspace>(
      context: context,
      builder: (dialogCtx) => _MoveToWorkspaceDialog(
        workspaces: others,
        api: api,
      ),
    );

    if (selected == null || !mounted) return;

    try {
      await api.moveSong(
        taskId: widget.task.taskId,
        workspaceId: selected.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.movedToWorkspace(selected.name))),
        );
        widget.onDelete?.call();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final task = widget.task;
    final tracks = _playingTracks();
    final playable = tracks.isNotEmpty;
    final displayTitle = task.title ?? task.prompt ?? task.taskType;

    return ValueListenableBuilder<PlayingTrack?>(
      valueListenable: NowPlaying.instance.track,
      builder: (context, currentTrack, _) {
        final isPlaying =
            playable && tracks.any((t) => t.audioUrl == currentTrack?.audioUrl);

        final canDrag = widget.task.isComplete && _audioPath() != null;

        final isGenerating = task.isProcessing || task.isUploading;

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.multiSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: widget.onMultiSelectToggle,
                      child: Icon(
                        widget.multiSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: widget.multiSelected
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                if (task.isComplete)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: isPlaying
                        ? ValueListenableBuilder<bool>(
                            valueListenable: NowPlaying.instance.playing,
                            builder: (context, actuallyPlaying, _) =>
                                ValueListenableBuilder<double>(
                              valueListenable: NowPlaying.instance.progress,
                              builder: (context, progress, _) => CoverArt(
                                audioUrl: context
                                    .read<ApiClient>()
                                    .songDownloadUrl(task.taskId),
                                size: 36,
                                selected: widget.selected,
                                isPlaying: actuallyPlaying,
                                playbackProgress:
                                    actuallyPlaying ? progress : null,
                              ),
                            ),
                          )
                        : CoverArt(
                            audioUrl: context
                                .read<ApiClient>()
                                .songDownloadUrl(task.taskId),
                            size: 36,
                            selected: widget.selected,
                          ),
                  ),
                if (playable)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: isPlaying
                        ? ValueListenableBuilder<bool>(
                            valueListenable: NowPlaying.instance.playing,
                            builder: (context, actuallyPlaying, _) =>
                                _AnimatedEqualizer(
                              size: 20,
                              color: AppColors.controlPink,
                              tooltip: s.tooltipNowPlaying,
                              playing: actuallyPlaying,
                              onTap: () {
                                final queue = widget.queueTracks.isNotEmpty
                                    ? widget.queueTracks
                                    : tracks;
                                final startAt = queue.indexWhere(
                                  (t) => t.id == widget.task.taskId,
                                );
                                NowPlaying.instance.setQueue(
                                  queue,
                                  startAt: startAt >= 0 ? startAt : 0,
                                );
                              },
                            ),
                          )
                        : _HoverIcon(
                            icon: Icons.play_arrow,
                            size: 20,
                            color: AppColors.controlPink,
                            hoverColor: Colors.white,
                            tooltip: s.tooltipPlay,
                            onTap: () {
                              final queue = widget.queueTracks.isNotEmpty
                                  ? widget.queueTracks
                                  : tracks;
                              final startAt = queue.indexWhere(
                                (t) => t.id == widget.task.taskId,
                              );
                              NowPlaying.instance.setQueue(
                                queue,
                                startAt: startAt >= 0 ? startAt : 0,
                              );
                            },
                          ),
                  ),
                if (!task.isComplete)
                  Flexible(
                    flex: 0,
                    child: _statusBadge(),
                  ),
                const SizedBox(width: 6),
                Tooltip(
                  message: task.taskType,
                  child: Icon(
                    _taskTypeIcon(task.taskType),
                    size: 14,
                    color: _taskTypeColor(task.taskType),
                  ),
                ),
                if (task.model != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 0,
                    child: _modelBadge(task.model!),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.isComplete) ...[
                  _thumbButton(
                    icon: Icons.thumb_up_outlined,
                    activeIcon: Icons.thumb_up,
                    active: task.rating == 1,
                    color: const Color(0xFF5C9CE6),
                    tooltip: s.tooltipLike,
                    onTap: () => _toggleRating(1),
                  ),
                  _thumbButton(
                    icon: Icons.thumb_down_outlined,
                    activeIcon: Icons.thumb_down,
                    active: task.rating == -1,
                    color: const Color(0xFF5C9CE6),
                    tooltip: s.tooltipDislike,
                    onTap: () => _toggleRating(-1),
                  ),
                  if (!_downloading)
                    _HoverIcon(
                      icon: Icons.download,
                      size: 16,
                      color: AppColors.textMuted,
                      hoverColor: AppColors.controlPink,
                      tooltip: s.tooltipDownload,
                      onTap: _download,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.controlPink,
                        ),
                      ),
                    ),
                ],
                if (task.isComplete)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _HoverIcon(
                      icon: Icons.drive_file_move_outline,
                      size: 16,
                      color: AppColors.textMuted,
                      hoverColor: AppColors.controlPink,
                      tooltip: s.tooltipMoveWorkspace,
                      onTap: _moveToWorkspace,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _HoverIcon(
                    icon: Icons.delete_outline,
                    size: 16,
                    color: AppColors.textMuted,
                    hoverColor: Colors.redAccent,
                    tooltip: s.tooltipDelete,
                    onTap: _confirmDelete,
                  ),
                ),
              ],
            ),
            if (task.prompt != null && task.prompt!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.prompt!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (task.isFailed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                task.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (task.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(task.createdAt!),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );

        final card = GestureDetector(
          onTap: widget.onTap,
          child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: isGenerating
              ? ListenableBuilder(
                  listenable: _rainbowController,
                  builder: (context, _) {
                    final shift = _rainbowController.value * 2;
                    const rainbowColors = [
                      Color(0xFFFF0000),
                      Color(0xFFFF8800),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF0088FF),
                      Color(0xFF8800FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ];
                    final gradient = LinearGradient(
                      begin: Alignment(shift - 1, 0),
                      end: Alignment(shift + 1, 0),
                      colors: rainbowColors,
                    );
                    // Outer border layer
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      // Inner card with background fill
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: gradient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: AppColors.surface.withValues(alpha: 0.82),
                          child: cardContent,
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  decoration: BoxDecoration(
                    color: _hovered ? AppColors.surfaceHigh : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.multiSelected
                          ? Colors.white
                          : widget.selected
                              ? AppColors.controlPink
                              : isPlaying
                                  ? AppColors.controlPink.withValues(alpha: 0.5)
                                  : _hovered
                                      ? AppColors.textMuted
                                      : AppColors.border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: cardContent,
                  ),
                ),
          ),
        ),
        );

        if (!canDrag) return card;

        final dragLabel =
            widget.task.title ?? widget.task.prompt ?? widget.task.taskType;

        return Draggable<TaskStatus>(
          data: widget.task,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.controlPink),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.music_note,
                    color: AppColors.controlPink,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      dragLabel.length > 40
                          ? '${dragLabel.substring(0, 40)}...'
                          : dragLabel,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: card,
        );
      },
    );
  }

  Widget _thumbButton({
    required IconData icon,
    required IconData activeIcon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: _HoverIcon(
        icon: active ? activeIcon : icon,
        size: 16,
        color: active ? color : AppColors.textMuted,
        hoverColor: color,
        tooltip: tooltip,
        onTap: onTap,
      ),
    );
  }

  Widget _statusBadge() {
    final s = S.of(context);
    final (color, label) = switch (widget.task.status) {
      TaskStatus.statusProcessing => (AppColors.controlPink, s.statusProcessing),
      TaskStatus.statusUploading => (Colors.orange, s.statusUploading),
      TaskStatus.statusComplete => (Colors.green, s.statusComplete),
      TaskStatus.statusFailed => (Colors.redAccent, s.statusFailed),
      _ => (AppColors.textMuted, widget.task.status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated equalizer icon (shown on currently-playing task)
// ---------------------------------------------------------------------------

class _AnimatedEqualizer extends StatefulWidget {
  const _AnimatedEqualizer({
    required this.size,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.playing = true,
  });

  final double size;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  final bool playing;

  @override
  State<_AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<_AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedEqualizer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _EqualizerPainter(
              phase: _controller.value,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 4;
    final gap = size.width * 0.12;
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;
    final paint = Paint()..color = color;
    final tau = 2 * 3.14159265;

    for (int i = 0; i < barCount; i++) {
      // Each bar oscillates with a phase offset
      final t = (phase * tau + i * 1.8).remainder(tau);
      final sinVal = (math.sin(t) * 0.5 + 0.5); // 0..1
      final barHeight = size.height * (0.25 + sinVal * 0.75);
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(barWidth * 0.3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Hover icon button
// ---------------------------------------------------------------------------

class _HoverIcon extends StatefulWidget {
  const _HoverIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.hoverColor,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Transform.scale(
          scale: _hovered ? 1.2 : 1.0,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: _hovered ? widget.hoverColor : widget.color,
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

// ---------------------------------------------------------------------------
// Move-to-workspace dialog
// ---------------------------------------------------------------------------

class _MoveToWorkspaceDialog extends StatefulWidget {
  const _MoveToWorkspaceDialog({
    required this.workspaces,
    required this.api,
  });

  final List<Workspace> workspaces;
  final ApiClient api;

  @override
  State<_MoveToWorkspaceDialog> createState() =>
      _MoveToWorkspaceDialogState();
}

class _MoveToWorkspaceDialogState extends State<_MoveToWorkspaceDialog> {
  late final List<Workspace> _workspaces = widget.workspaces;
  bool _creating = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final ws = await widget.api.createWorkspace(name);
      await widget.api.loadWorkspaces();
      if (mounted) Navigator.pop(context, ws);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(
        s.dialogMoveToWorkspaceTitle,
        style: const TextStyle(color: AppColors.text),
      ),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ws in _workspaces)
              ListTile(
                dense: true,
                title: Text(
                  ws.name,
                  style: const TextStyle(color: AppColors.text),
                ),
                hoverColor: Colors.white10,
                onTap: () => Navigator.pop(context, ws),
              ),
            if (_creating) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Workspace name',
                ),
                onSubmitted: (_) => _createAndSelect(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _creating = false),
                    child: Text(s.buttonCancel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _createAndSelect,
                    child: const Text('Create'),
                  ),
                ],
              ),
            ] else
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: const Text(
                  'New workspace',
                  style: TextStyle(color: AppColors.accent),
                ),
                hoverColor: Colors.white10,
                onTap: () => setState(() => _creating = true),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform editor for infill
// ---------------------------------------------------------------------------

class _WaveformEditor extends StatefulWidget {
  const _WaveformEditor({
    required this.bytes,
    required this.duration,
    required this.onChanged,
    this.initialStart = 0,
    this.initialEnd,
  });

  final Uint8List bytes;
  final Duration duration;
  final double initialStart;
  final double? initialEnd; // defaults to total duration
  final void Function(double startSec, double endSec) onChanged;

  @override
  State<_WaveformEditor> createState() => _WaveformEditorState();
}

class _WaveformEditorState extends State<_WaveformEditor> {
  static const _barCount = 120;
  static const _keepColor = Color(0xFF42A5F5);

  late List<double> _amplitudes;
  late double _startFraction; // left handle 0.0–1.0
  late double _endFraction; // right handle 0.0–1.0
  _DragTarget? _activeDrag;

  @override
  void initState() {
    super.initState();
    _amplitudes = extractAmplitudes(widget.bytes, _barCount);
    final totalSeconds = widget.duration.inMilliseconds / 1000;
    _startFraction = totalSeconds > 0
        ? (widget.initialStart / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final endSec = widget.initialEnd ?? totalSeconds;
    _endFraction = totalSeconds > 0
        ? (endSec / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
  }


  String _formatTimestamp(double seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final sFmt = s == s.roundToDouble() ? s.toInt().toString() : s.toStringAsFixed(1);
    return '${m.toString().padLeft(2, '0')}:${sFmt.padLeft(2, '0')}';
  }

  void _fireCallback() {
    final totalSeconds = widget.duration.inMilliseconds / 1000;
    final startSec = double.parse(
      (_startFraction * totalSeconds).toStringAsFixed(1),
    );
    final endSec = double.parse(
      (_endFraction * totalSeconds).toStringAsFixed(1),
    );
    widget.onChanged(startSec, endSec);
  }

  void _onDragStart(double fraction) {
    // Pick the nearest handle.
    final distStart = (fraction - _startFraction).abs();
    final distEnd = (fraction - _endFraction).abs();
    _activeDrag = distStart <= distEnd ? _DragTarget.start : _DragTarget.end;
    _onDragUpdate(fraction);
  }

  void _onDragUpdate(double fraction) {
    setState(() {
      if (_activeDrag == _DragTarget.start) {
        _startFraction = fraction.clamp(0.0, _endFraction);
      } else {
        _endFraction = fraction.clamp(_startFraction, 1.0);
      }
    });
    _fireCallback();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final totalSeconds = widget.duration.inMilliseconds / 1000;
    final startSeconds = _startFraction * totalSeconds;
    final endSeconds = _endFraction * totalSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels row — KEEP bar expands with the blue section, both edges draggable
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final leftOffset = _startFraction * totalWidth;
            final keepWidth = (_endFraction - _startFraction) * totalWidth;
            final clampedKeepWidth = math.max(keepWidth, 70.0);
            final hasRecreateLeft = leftOffset > 50;
            final hasRecreateRight =
                totalWidth - leftOffset - clampedKeepWidth > 50;
            return Row(
              children: [
                if (hasRecreateLeft)
                  SizedBox(
                    width: leftOffset,
                    child: Text(
                      s.labelRecreate,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  SizedBox(width: leftOffset),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) => _onDragStart(
                    (leftOffset + d.localPosition.dx) / totalWidth,
                  ),
                  onHorizontalDragUpdate: (d) => _onDragUpdate(
                    (leftOffset + d.localPosition.dx) / totalWidth,
                  ),
                  child: Container(
                    width: clampedKeepWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _keepColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Text(
                          s.labelKeep,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                ),
                if (hasRecreateRight)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        s.labelRecreate,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        // Waveform
        SizedBox(
          height: 100,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _onDragStart(d.localPosition.dx / w),
                onHorizontalDragStart: (d) =>
                    _onDragStart(d.localPosition.dx / w),
                onHorizontalDragUpdate: (d) =>
                    _onDragUpdate(d.localPosition.dx / w),
                child: CustomPaint(
                  size: Size(w, 100),
                  painter: _WaveformPainter(
                    amplitudes: _amplitudes,
                    startFraction: _startFraction,
                    endFraction: _endFraction,
                    keepColor: _keepColor,
                    recreateColor: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Timestamps
        Row(
          children: [
            Text(
              s.labelStart,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _formatTimestamp(startSeconds),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              s.labelEnd,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _formatTimestamp(endSeconds),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _DragTarget { start, end }

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.startFraction,
    required this.endFraction,
    required this.keepColor,
    required this.recreateColor,
  });

  final List<double> amplitudes;
  final double startFraction;
  final double endFraction;
  final Color keepColor;
  final Color recreateColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barCount = amplitudes.length;
    final barWidth = size.width / barCount;
    final gap = math.max(1.0, barWidth * 0.15);
    final drawWidth = barWidth - gap;
    final startX = startFraction * size.width;
    final endX = endFraction * size.width;
    final maxBarHeight = size.height - 8;
    final radius = const Radius.circular(6);

    // Draw left RECREATE region background
    if (startX > 0) {
      final leftRect = Rect.fromLTWH(0, 0, startX, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(leftRect, radius),
        Paint()..color = recreateColor.withValues(alpha: 0.06),
      );
    }

    // Draw KEEP region background + border
    final keepRect = Rect.fromLTWH(startX, 0, endX - startX, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(keepRect, radius),
      Paint()..color = keepColor.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(keepRect, radius),
      Paint()
        ..color = keepColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw right RECREATE region background
    if (endX < size.width) {
      final rightRect = Rect.fromLTWH(endX, 0, size.width - endX, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rightRect, radius),
        Paint()..color = recreateColor.withValues(alpha: 0.06),
      );
    }

    // Draw bars
    final keepPaint = Paint()..color = keepColor;
    final recreatePaint = Paint()..color = recreateColor;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + gap / 2;
      final barCenter = x + drawWidth / 2;
      final amp = amplitudes[i].clamp(0.05, 1.0);
      final halfHeight = amp * maxBarHeight / 2;
      final paint = barCenter >= startX && barCenter <= endX
          ? keepPaint
          : recreatePaint;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(barCenter, centerY),
            width: drawWidth,
            height: halfHeight * 2,
          ),
          Radius.circular(drawWidth / 2),
        ),
        paint,
      );
    }

    // Draw handle lines
    final handlePaint = Paint()
      ..color = keepColor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      handlePaint,
    );
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), handlePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      startFraction != old.startFraction ||
      endFraction != old.endFraction ||
      amplitudes != old.amplitudes;
}
