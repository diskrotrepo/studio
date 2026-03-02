import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/directory_browser.dart';

class DatasetTab extends StatefulWidget {
  const DatasetTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<DatasetTab> createState() => _DatasetTabState();
}

class _DatasetTabState extends State<DatasetTab>
    with AutomaticKeepAliveClientMixin {
  // ── Upload ────────────────────────────────────────────────────────────────
  String? _zipFileName;
  Uint8List? _zipBytes;
  final _datasetNameController =
      TextEditingController(text: 'my_lora_dataset');
  final _customTagController = TextEditingController();
  String _tagPosition = 'prepend';
  bool _allInstrumental = true;
  bool _uploading = false;

  // ── Load ──────────────────────────────────────────────────────────────────
  final _datasetPathController = TextEditingController();
  bool _loadingDataset = false;

  // ── Auto-label ────────────────────────────────────────────────────────────
  bool _autoLabeling = false;
  String? _autoLabelTaskId;
  String _autoLabelStatusText = '';
  int _autoLabelCurrent = 0;
  int _autoLabelTotal = 0;
  bool _skipMetas = false;
  bool _formatLyrics = false;
  bool _transcribeLyrics = false;
  bool _onlyUnlabeled = false;
  final _autoLabelSavePathController = TextEditingController();
  int _autoLabelChunkSize = 16;
  int _autoLabelBatchSize = 1;

  // ── Samples ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _samples = [];
  int? _selectedSampleIdx;
  bool _updatingSample = false;

  // Sample edit controllers
  final _sampleCaptionController = TextEditingController();
  final _sampleGenreController = TextEditingController();
  final _sampleLyricsController = TextEditingController();
  final _sampleBpmController = TextEditingController();
  final _sampleKeyController = TextEditingController();
  final _sampleTimeSigController = TextEditingController();
  final _sampleLanguageController = TextEditingController();
  bool _sampleIsInstrumental = true;

  // ── Save ──────────────────────────────────────────────────────────────────
  final _savePathController = TextEditingController();
  bool _saving = false;

  // ── Preprocess ────────────────────────────────────────────────────────────
  final _preprocessOutputDirController = TextEditingController();
  bool _preprocessSkipExisting = true;
  bool _preprocessing = false;
  String? _preprocessTaskId;
  String _preprocessStatusText = '';
  int _preprocessCurrent = 0;
  int _preprocessTotal = 0;

  // ── General ───────────────────────────────────────────────────────────────
  String? _error;
  String? _success;
  Timer? _pollTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollAsyncTasks(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _datasetNameController.dispose();
    _customTagController.dispose();
    _datasetPathController.dispose();
    _autoLabelSavePathController.dispose();
    _sampleCaptionController.dispose();
    _sampleGenreController.dispose();
    _sampleLyricsController.dispose();
    _sampleBpmController.dispose();
    _sampleKeyController.dispose();
    _sampleTimeSigController.dispose();
    _sampleLanguageController.dispose();
    _savePathController.dispose();
    _preprocessOutputDirController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDirectory(TextEditingController controller) async {
    final initial = controller.text.trim();
    final path = await showDirectoryBrowser(
      context,
      widget.apiClient,
      initialPath: initial.isEmpty ? '.' : initial,
    );
    if (path != null && mounted) {
      setState(() => controller.text = path);
    }
  }

  Future<void> _pickFile(
    TextEditingController controller, {
    List<String>? extensions,
  }) async {
    final initial = controller.text.trim();
    final path = await showFileBrowser(
      context,
      widget.apiClient,
      initialPath: initial.isEmpty ? '.' : initial,
      extensions: extensions ?? [],
    );
    if (path != null && mounted) {
      setState(() => controller.text = path);
    }
  }

  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _zipFileName = file.name;
      _zipBytes = file.bytes;
    });
  }

  Future<void> _uploadZip() async {
    if (_zipBytes == null || _zipFileName == null) return;
    final nameErr = requiredField(
        _datasetNameController.text, fieldName: 'Dataset name');
    if (nameErr != null) {
      setState(() => _error = nameErr);
      return;
    }
    final s = S.of(context);
    setState(() {
      _uploading = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await widget.apiClient.uploadDatasetZip(
        bytes: _zipBytes!,
        filename: _zipFileName!,
        datasetName: _datasetNameController.text.trim(),
        customTag: _customTagController.text.trim(),
        tagPosition: _tagPosition,
        allInstrumental: _allInstrumental,
      );
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final samples =
          (data['samples'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      setState(() {
        _samples = samples;
        _selectedSampleIdx = null;
        _success =
            s.uploadedSamples(data['num_samples'] as int? ?? samples.length);
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _loadDataset() async {
    final path = _datasetPathController.text.trim();
    if (path.isEmpty) return;
    final s = S.of(context);
    setState(() {
      _loadingDataset = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await widget.apiClient.loadDataset(path);
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final samples =
          (data['samples'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      setState(() {
        _samples = samples;
        _selectedSampleIdx = null;
        _success =
            s.loadedSamples(data['num_samples'] as int? ?? samples.length);
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingDataset = false);
    }
  }

  Future<void> _startAutoLabel() async {
    final s = S.of(context);
    setState(() {
      _autoLabeling = true;
      _error = null;
      _success = null;
      _autoLabelStatusText = s.startingEllipsis;
      _autoLabelCurrent = 0;
      _autoLabelTotal = 0;
    });
    try {
      final params = <String, dynamic>{
        'skip_metas': _skipMetas,
        'format_lyrics': _formatLyrics,
        'transcribe_lyrics': _transcribeLyrics,
        'only_unlabeled': _onlyUnlabeled,
        'chunk_size': _autoLabelChunkSize,
        'batch_size': _autoLabelBatchSize,
      };
      final savePath = _autoLabelSavePathController.text.trim();
      if (savePath.isNotEmpty) params['save_path'] = savePath;

      final result = await widget.apiClient.startAutoLabel(params);
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      setState(() {
        _autoLabelTaskId = data['task_id'] as String?;
        _autoLabelTotal = data['total'] as int? ?? 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFriendlyError(e);
          _autoLabeling = false;
        });
      }
    }
  }

  Future<void> _saveDataset() async {
    final s = S.of(context);
    final path = _savePathController.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final params = <String, dynamic>{
        'save_path': path,
        'dataset_name': _datasetNameController.text.trim(),
      };
      final tag = _customTagController.text.trim();
      if (tag.isNotEmpty) {
        params['custom_tag'] = tag;
        params['tag_position'] = _tagPosition;
      }
      params['all_instrumental'] = _allInstrumental;

      await widget.apiClient.saveDataset(params);
      if (mounted) setState(() => _success = s.datasetSaved);
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startPreprocess() async {
    final s = S.of(context);
    final dir = _preprocessOutputDirController.text.trim();
    if (dir.isEmpty) return;
    setState(() {
      _preprocessing = true;
      _error = null;
      _success = null;
      _preprocessStatusText = s.startingEllipsis;
      _preprocessCurrent = 0;
      _preprocessTotal = 0;
    });
    try {
      final result = await widget.apiClient.startPreprocess({
        'output_dir': dir,
        'skip_existing': _preprocessSkipExisting,
      });
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      setState(() {
        _preprocessTaskId = data['task_id'] as String?;
        _preprocessTotal = data['total'] as int? ?? 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFriendlyError(e);
          _preprocessing = false;
        });
      }
    }
  }

  void _selectSample(int idx) {
    if (idx < 0 || idx >= _samples.length) return;
    final s = _samples[idx];
    setState(() {
      _selectedSampleIdx = idx;
      _sampleCaptionController.text = s['caption'] as String? ?? '';
      _sampleGenreController.text = s['genre'] as String? ?? '';
      _sampleLyricsController.text = s['lyrics'] as String? ?? '';
      _sampleBpmController.text = (s['bpm'] ?? '').toString();
      _sampleKeyController.text = s['keyscale'] as String? ?? '';
      _sampleTimeSigController.text = s['timesignature'] as String? ?? '';
      _sampleLanguageController.text = s['language'] as String? ?? 'unknown';
      _sampleIsInstrumental = s['is_instrumental'] as bool? ?? true;
    });
  }

  Future<void> _updateSample() async {
    if (_selectedSampleIdx == null) return;
    final s = S.of(context);
    setState(() {
      _updatingSample = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'caption': _sampleCaptionController.text,
        'genre': _sampleGenreController.text,
        'lyrics': _sampleLyricsController.text,
        'keyscale': _sampleKeyController.text,
        'timesignature': _sampleTimeSigController.text,
        'language': _sampleLanguageController.text,
        'is_instrumental': _sampleIsInstrumental,
      };
      final bpm = int.tryParse(_sampleBpmController.text);
      if (bpm != null) data['bpm'] = bpm;

      await widget.apiClient.updateDatasetSample(_selectedSampleIdx!, data);
      if (!mounted) return;
      // Refresh samples list.
      try {
        final res = await widget.apiClient.getDatasetSamples();
        final d = res['data'] as Map<String, dynamic>? ?? res;
        final samples =
            (d['samples'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [];
        if (mounted) setState(() => _samples = samples);
      } catch (_) {}
      if (mounted) setState(() => _success = s.sampleUpdated);
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _updatingSample = false);
    }
  }

  Future<void> _pollAsyncTasks() async {
    if (_autoLabelTaskId != null) {
      try {
        final result =
            await widget.apiClient.getAutoLabelTaskStatus(_autoLabelTaskId!);
        if (!mounted) return;
        final data = result['data'] as Map<String, dynamic>? ?? result;
        final status = data['status'] as String? ?? '';
        setState(() {
          _autoLabelStatusText = data['progress'] as String? ?? status;
          _autoLabelCurrent = data['current'] as int? ?? 0;
          _autoLabelTotal = data['total'] as int? ?? _autoLabelTotal;
        });
        if (status == 'completed' || status == 'failed') {
          setState(() {
            _autoLabeling = false;
            _autoLabelTaskId = null;
            if (status == 'completed') {
              _success = 'Auto-labeling complete';
              // Refresh samples from result.
              final resultData = data['result'] as Map<String, dynamic>?;
              if (resultData != null) {
                final samples = (resultData['samples'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                _samples = samples;
              }
            } else {
              _error = data['error'] as String? ?? 'Auto-labeling failed';
            }
          });
        }
      } catch (_) {}
    }

    if (_preprocessTaskId != null) {
      try {
        final result =
            await widget.apiClient.getPreprocessTaskStatus(_preprocessTaskId!);
        if (!mounted) return;
        final data = result['data'] as Map<String, dynamic>? ?? result;
        final status = data['status'] as String? ?? '';
        setState(() {
          _preprocessStatusText = data['progress'] as String? ?? status;
          _preprocessCurrent = data['current'] as int? ?? 0;
          _preprocessTotal = data['total'] as int? ?? _preprocessTotal;
        });
        if (status == 'completed' || status == 'failed') {
          setState(() {
            _preprocessing = false;
            _preprocessTaskId = null;
            if (status == 'completed') {
              _success = 'Preprocessing complete';
            } else {
              _error = data['error'] as String? ?? 'Preprocessing failed';
            }
          });
        }
      } catch (_) {}
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status messages
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _success!,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 13,
                ),
              ),
            ),

          // ── Upload section ────────────────────────────────────────────
          _sectionHeader(s.datasetSectionUpload),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(
                label: s.buttonChooseZip,
                onPressed: _uploading ? null : _pickZip,
              ),
              const SizedBox(width: 12),
              if (_zipFileName != null)
                Text(
                  _zipFileName!,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _field(
            label: s.labelDatasetName,
            controller: _datasetNameController,
            hint: 'my_lora_dataset',
            info: s.infoDatasetName,
          ),
          const SizedBox(height: 8),
          _field(
            label: s.labelCustomTag,
            controller: _customTagController,
            hint: s.hintCustomTag,
            info: s.infoCustomTag,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: _dropdown(
                  label: s.labelTagPosition,
                  value: _tagPosition,
                  items: const ['prepend', 'append', 'replace'],
                  onChanged: (v) {
                    if (v != null) setState(() => _tagPosition = v);
                  },
                  info: s.infoTagPosition,
                ),
              ),
              const SizedBox(width: 16),
              _buildToggle(
                label: s.labelAllInstrumental,
                subtitle: s.subtitleAllInstrumental,
                value: _allInstrumental,
                onChanged: (v) => setState(() => _allInstrumental = v),
                info: s.infoAllInstrumental,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: _uploading ? s.uploadingEllipsis : s.buttonUpload,
            onPressed:
                _uploading || _zipBytes == null ? null : _uploadZip,
          ),

          const SizedBox(height: 32),

          // ── Load section ──────────────────────────────────────────────
          _sectionHeader(s.datasetSectionLoad),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  label: s.labelDatasetJsonPath,
                  controller: _datasetPathController,
                  hint: '/path/to/dataset.json',
                  info: s.infoDatasetJsonPath,
                ),
              ),
              const SizedBox(width: 4),
              _browseButton(() => _pickFile(
                    _datasetPathController,
                    extensions: ['json'],
                  ), tooltip: s.tooltipBrowse),
            ],
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: _loadingDataset ? s.loadingEllipsis : s.buttonLoad,
            onPressed: _loadingDataset ? null : _loadDataset,
          ),

          if (_samples.isNotEmpty) ...[
            const SizedBox(height: 32),

            // ── Auto-label section ──────────────────────────────────────
            _sectionHeader(s.datasetSectionAutoLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildToggle(
                  label: s.labelSkipMetas,
                  subtitle: s.subtitleSkipMetas,
                  value: _skipMetas,
                  onChanged: (v) => setState(() => _skipMetas = v),
                  info: s.infoSkipMetas,
                ),
                _buildToggle(
                  label: s.labelFormatLyrics,
                  subtitle: s.subtitleFormatLyrics,
                  value: _formatLyrics,
                  onChanged: (v) => setState(() => _formatLyrics = v),
                  info: s.infoFormatLyrics,
                ),
                _buildToggle(
                  label: s.labelTranscribeLyrics,
                  subtitle: s.subtitleTranscribeLyrics,
                  value: _transcribeLyrics,
                  onChanged: (v) => setState(() => _transcribeLyrics = v),
                  info: s.infoTranscribeLyrics,
                ),
                _buildToggle(
                  label: s.labelOnlyUnlabeled,
                  subtitle: s.subtitleOnlyUnlabeled,
                  value: _onlyUnlabeled,
                  onChanged: (v) => setState(() => _onlyUnlabeled = v),
                  info: s.infoOnlyUnlabeled,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    label: s.labelSavePathOptional,
                    controller: _autoLabelSavePathController,
                    hint: '/path/to/save/labeled_dataset.json',
                    info: s.infoAutoLabelSavePath,
                  ),
                ),
                const SizedBox(width: 4),
                _browseButton(() => _pickFile(
                      _autoLabelSavePathController,
                      extensions: ['json'],
                    ), tooltip: s.tooltipBrowse),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: _numberField(
                    label: s.labelChunkSize,
                    value: _autoLabelChunkSize,
                    onChanged: (v) =>
                        setState(() => _autoLabelChunkSize = v),
                    info: s.infoChunkSize,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: _numberField(
                    label: s.labelBatchSizeDataset,
                    value: _autoLabelBatchSize,
                    onChanged: (v) =>
                        setState(() => _autoLabelBatchSize = v),
                    info: s.infoBatchSizeDataset,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: _autoLabeling ? s.labelingEllipsis : s.buttonStartAutoLabel,
              onPressed: _autoLabeling ? null : _startAutoLabel,
            ),
            if (_autoLabeling) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: LinearProgressIndicator(
                  value: _autoLabelTotal > 0
                      ? _autoLabelCurrent / _autoLabelTotal
                      : null,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _autoLabelStatusText.isNotEmpty
                    ? '$_autoLabelStatusText ($_autoLabelCurrent/$_autoLabelTotal)'
                    : s.processingEllipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Samples section ─────────────────────────────────────────
            _sectionHeader(s.datasetSectionSamples(_samples.length)),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sample list
                  Flexible(
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.builder(
                        itemCount: _samples.length,
                        itemExtent: 40,
                        itemBuilder: (context, idx) {
                          final sample = _samples[idx];
                          final selected = idx == _selectedSampleIdx;
                          return GestureDetector(
                            onTap: () => _selectSample(idx),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.accent
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.border
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${sample['index'] ?? idx}',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        sample['filename'] as String? ??
                                            sample['audio_path'] as String? ??
                                            s.labelUnknown,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? AppColors.text
                                              : AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (sample['labeled'] == true)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.greenAccent,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ),

                  // Sample detail
                  if (_selectedSampleIdx != null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildSampleEditor(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Save section ────────────────────────────────────────────
            _sectionHeader(s.datasetSectionSave),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    label: s.labelSavePath,
                    controller: _savePathController,
                    hint: '/path/to/dataset.json',
                    info: s.infoSavePath,
                  ),
                ),
                const SizedBox(width: 4),
                _browseButton(() => _pickFile(
                      _savePathController,
                      extensions: ['json'],
                    ), tooltip: s.tooltipBrowse),
              ],
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: _saving ? s.savingEllipsis : s.buttonSave,
              onPressed: _saving ? null : _saveDataset,
            ),

            const SizedBox(height: 32),

            // ── Preprocess section ──────────────────────────────────────
            _sectionHeader(s.datasetSectionPreprocess),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    label: s.labelOutputDirectory,
                    controller: _preprocessOutputDirController,
                    hint: '/path/to/tensors',
                    info: s.infoOutputDirectoryPreprocess,
                  ),
                ),
                const SizedBox(width: 4),
                _browseButton(
                    () => _pickDirectory(_preprocessOutputDirController), tooltip: s.tooltipBrowse),
              ],
            ),
            const SizedBox(height: 8),
            _buildToggle(
              label: s.labelSkipExisting,
              subtitle: s.subtitleSkipExisting,
              value: _preprocessSkipExisting,
              onChanged: (v) =>
                  setState(() => _preprocessSkipExisting = v),
              info: s.infoSkipExisting,
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: _preprocessing ? s.preprocessingEllipsis : s.buttonPreprocess,
              onPressed: _preprocessing ? null : _startPreprocess,
            ),
            if (_preprocessing) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: LinearProgressIndicator(
                  value: _preprocessTotal > 0
                      ? _preprocessCurrent / _preprocessTotal
                      : null,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _preprocessStatusText.isNotEmpty
                    ? '$_preprocessStatusText ($_preprocessCurrent/$_preprocessTotal)'
                    : s.processingEllipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Sample editor ─────────────────────────────────────────────────────────

  Widget _buildSampleEditor() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          label: s.sampleLabelCaption,
          controller: _sampleCaptionController,
          info: s.infoCaption,
        ),
        const SizedBox(height: 8),
        _field(
          label: s.sampleLabelGenre,
          controller: _sampleGenreController,
          info: s.infoGenre,
        ),
        const SizedBox(height: 8),
        _field(
          label: s.sampleLabelLyrics,
          controller: _sampleLyricsController,
          maxLines: 3,
          info: s.infoLyrics,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: _field(
                label: s.sampleLabelBpm,
                controller: _sampleBpmController,
                info: s.infoBpm,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: _field(
                label: s.sampleLabelKey,
                controller: _sampleKeyController,
                info: s.infoKey,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: _field(
                label: s.sampleLabelTimeSig,
                controller: _sampleTimeSigController,
                info: s.infoTimeSig,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _field(
          label: s.sampleLabelLanguage,
          controller: _sampleLanguageController,
          info: s.infoLanguage,
        ),
        const SizedBox(height: 8),
        _buildToggle(
          label: s.sampleLabelInstrumental,
          subtitle: '',
          value: _sampleIsInstrumental,
          onChanged: (v) => setState(() => _sampleIsInstrumental = v),
          info: s.infoInstrumental,
        ),
        const SizedBox(height: 12),
        _actionButton(
          label: _updatingSample ? s.updatingEllipsis : s.buttonUpdateSample,
          onPressed: _updatingSample ? null : _updateSample,
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }

  static Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? info,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceHigh,
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? info,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.surfaceHigh,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  static Widget _numberField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    String? info,
  }) {
    final controller = TextEditingController(text: '$value');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) onChanged(n);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? info,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
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

  static Widget _browseButton(VoidCallback onPressed, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.folder_open, size: 18),
        tooltip: tooltip,
        color: AppColors.textMuted,
        hoverColor: AppColors.accent.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        splashRadius: 16,
      ),
    );
  }

  static Widget _actionButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.black.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
