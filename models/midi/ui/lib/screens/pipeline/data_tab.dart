import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/pipeline_jobs_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/directory_browser.dart';

enum _DataTabPhase { idle, scanning, scanned, staging, staged }

class DataTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const DataTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<DataTab> createState() => _DataTabState();
}

class _DataTabState extends ConsumerState<DataTab> {
  _DataTabPhase _phase = _DataTabPhase.idle;

  // User inputs
  final _midiDirController = TextEditingController(text: 'midi_files');
  final _metadataController = TextEditingController();
  final _filterController = TextEditingController();
  final _randomCountController = TextEditingController();

  // Scan results
  int _totalSizeBytes = 0;
  String _resolvedDir = '';
  List<_MidiFileEntry> _allFiles = [];
  final Set<String> _selectedPaths = {};

  // Tag filters
  List<String> _availableGenres = [];
  List<String> _availableMoods = [];
  final Set<String> _activeGenres = {};
  final Set<String> _activeMoods = {};

  // Download state
  bool _downloading = false;

  // Staging result
  String? _stagedDir;
  int? _stagedCount;

  @override
  void dispose() {
    _midiDirController.dispose();
    _metadataController.dispose();
    _filterController.dispose();
    _randomCountController.dispose();
    super.dispose();
  }

  /// Files that pass all active filters (text + tags).
  List<_MidiFileEntry> get _filteredFiles {
    final textFilter = _filterController.text.toLowerCase();
    return _allFiles.where((f) {
      if (textFilter.isNotEmpty &&
          !f.relativePath.toLowerCase().contains(textFilter)) {
        return false;
      }
      if (_activeGenres.isNotEmpty &&
          !_activeGenres.any((g) => f.genres.contains(g))) {
        return false;
      }
      if (_activeMoods.isNotEmpty &&
          !_activeMoods.any((m) => f.moods.contains(m))) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed header area
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan a MIDI directory, select files, and stage them for '
                'processing. The staged folder can then be used in the '
                'Pretokenize and Training tabs.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Download training data
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloading ? null : _downloadTrainingData,
                  icon: _downloading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download, size: 18),
                  label: Text(
                    _downloading
                        ? 'Queuing download...'
                        : 'Download Training Data',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // MIDI Directory
              TextField(
                controller: _midiDirController,
                decoration: InputDecoration(
                  labelText: 'MIDI Directory',
                  hintText: 'midi_files',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 20),
                        tooltip: 'Browse for directory',
                        onPressed: () => _pickDirectory(_midiDirController),
                      ),
                      _infoIcon(
                        'Root directory containing .mid/.midi files (searched recursively)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Metadata file (optional)
              TextField(
                controller: _metadataController,
                decoration: InputDecoration(
                  labelText: 'Metadata File (optional)',
                  hintText: 'midi_files/midi_metadata.json',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 20),
                        tooltip: 'Browse for metadata file',
                        onPressed: _pickMetadataFile,
                      ),
                      _infoIcon(
                        'JSON metadata file with per-file genre/mood/artist tags. '
                        'Enables tag-based filtering.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scan button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _phase == _DataTabPhase.scanning ? null : _scan,
                  icon: _phase == _DataTabPhase.scanning
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(
                      _phase == _DataTabPhase.scanning
                          ? 'Scanning...'
                          : 'Scan Directory'),
                ),
              ),
            ],
          ),
        ),

        // File list area (scrollable)
        if (_phase.index >= _DataTabPhase.scanned.index)
          Expanded(child: _buildFileSelection(theme)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // File selection UI
  // ---------------------------------------------------------------------------

  Widget _buildFileSelection(ThemeData theme) {
    final sizeMB = (_totalSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final filtered = _filteredFiles;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              const Icon(Icons.folder_open,
                  color: AppColors.controlBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_allFiles.length} files ($sizeMB MB)',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${_selectedPaths.length} selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.controlBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tag filters (if metadata was loaded)
          if (_availableGenres.isNotEmpty || _availableMoods.isNotEmpty)
            _buildTagFilters(theme),

          // Text filter + select controls + random
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _filterController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Filter files...',
                      prefixIcon: Icon(Icons.filter_list, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  for (final f in filtered) {
                    _selectedPaths.add(f.relativePath);
                  }
                }),
                child: const Text('All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final f in filtered) {
                    _selectedPaths.remove(f.relativePath);
                  }
                }),
                child: const Text('None', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Random selection row
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 36,
                child: TextField(
                  controller: _randomCountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'N',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _selectRandom,
                icon: const Icon(Icons.shuffle, size: 16),
                label:
                    const Text('Random', style: TextStyle(fontSize: 12)),
              ),
              if (filtered.length != _allFiles.length) ...[
                const Spacer(),
                Text(
                  '${filtered.length} shown',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // File list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: filtered.length,
                itemExtent: 32,
                itemBuilder: (context, index) {
                  final file = filtered[index];
                  final selected =
                      _selectedPaths.contains(file.relativePath);
                  final sizeKB = (file.size / 1024).toStringAsFixed(0);

                  return InkWell(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedPaths.remove(file.relativePath);
                      } else {
                        _selectedPaths.add(file.relativePath);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: selected,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedPaths.add(file.relativePath);
                                } else {
                                  _selectedPaths.remove(file.relativePath);
                                }
                              }),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.relativePath,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '$sizeKB KB',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stage button + reset
          Row(
            children: [
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _phase == _DataTabPhase.staging ||
                          _selectedPaths.isEmpty
                      ? null
                      : _stage,
                  icon: _phase == _DataTabPhase.staging
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link, size: 18),
                  label: Text(
                    _phase == _DataTabPhase.staging
                        ? 'Staging...'
                        : 'Stage ${_selectedPaths.length} Files',
                  ),
                ),
              ),
            ],
          ),

          // Staged confirmation
          if (_phase == _DataTabPhase.staged && _stagedDir != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2e1a),
                border: Border.all(color: const Color(0xFF2d5a2d)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4caf50), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Staged $_stagedCount files to $_stagedDir',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF81c784),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tag filter chips
  // ---------------------------------------------------------------------------

  Widget _buildTagFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_availableGenres.isNotEmpty) ...[
            Text('Genres',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _availableGenres.map((g) {
                final active = _activeGenres.contains(g);
                final label = _tagLabel(g);
                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: active,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _activeGenres.add(g);
                    } else {
                      _activeGenres.remove(g);
                    }
                  }),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  selectedColor: AppColors.controlBlue.withValues(alpha: 0.3),
                  checkmarkColor: AppColors.controlBlue,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (_availableMoods.isNotEmpty) ...[
            Text('Moods',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _availableMoods.map((m) {
                final active = _activeMoods.contains(m);
                final label = _tagLabel(m);
                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: active,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _activeMoods.add(m);
                    } else {
                      _activeMoods.remove(m);
                    }
                  }),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  selectedColor: AppColors.controlBlue.withValues(alpha: 0.3),
                  checkmarkColor: AppColors.controlBlue,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// Convert "GENRE_HIP_HOP" → "Hip Hop", "MOOD_HAPPY" → "Happy"
  String _tagLabel(String tag) {
    final parts = tag.split('_');
    if (parts.length > 1) {
      // Drop prefix (GENRE, MOOD)
      return parts
          .skip(1)
          .map((w) =>
              w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }
    return tag;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDirectory(TextEditingController controller) async {
    final api = ref.read(apiClientProvider);
    final path = await showDirectoryBrowser(
      context,
      api,
      initialPath: controller.text.isEmpty ? '.' : controller.text,
    );
    if (path != null) {
      setState(() => controller.text = path);
    }
  }

  Future<void> _pickMetadataFile() async {
    final api = ref.read(apiClientProvider);
    final current = _metadataController.text.trim();
    // Start browsing from the directory part of the current path
    final lastSlash = current.lastIndexOf('/');
    final dirPart = lastSlash > 0 ? current.substring(0, lastSlash) : '.';

    final path = await showFileBrowser(
      context,
      api,
      initialPath: dirPart,
      extensions: ['json'],
    );
    if (path != null) {
      setState(() => _metadataController.text = path);
    }
  }

  Future<void> _downloadTrainingData() async {
    setState(() => _downloading = true);
    try {
      final api = ref.read(apiClientProvider);
      final taskId = await api.downloadTrainingData(
        outputDir: _midiDirController.text.trim().isEmpty
            ? 'midi_files'
            : _midiDirController.text.trim(),
      );

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'download',
      );

      ref.read(pipelineJobsProvider.notifier).addJob(initial);
      ref.read(taskStatusProvider(initial));
      widget.onTaskSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _scan() async {
    setState(() {
      _phase = _DataTabPhase.scanning;
    });

    try {
      final api = ref.read(apiClientProvider);
      final metaPath = _metadataController.text.trim();
      final result = await api.scanMidiDir(
        _midiDirController.text,
        metadata: metaPath.isEmpty ? null : metaPath,
      );

      final files = (result['files'] as List)
          .map((f) => _MidiFileEntry(
                relativePath: f['relative_path'] as String,
                size: f['size'] as int,
                genres: (f['genres'] as List?)?.cast<String>() ?? const [],
                moods: (f['moods'] as List?)?.cast<String>() ?? const [],
                artist: f['artist'] as String?,
              ))
          .toList();

      // Extract available filter values
      final filters = result['available_filters'] as Map<String, dynamic>?;

      setState(() {
        _allFiles = files;
        _totalSizeBytes = result['total_size_bytes'] as int;
        _resolvedDir = result['directory'] as String;
        _selectedPaths.clear();
        _selectedPaths.addAll(files.map((f) => f.relativePath));
        _filterController.clear();
        _randomCountController.clear();
        _activeGenres.clear();
        _activeMoods.clear();
        _availableGenres =
            (filters?['genres'] as List?)?.cast<String>() ?? [];
        _availableMoods =
            (filters?['moods'] as List?)?.cast<String>() ?? [];
        _stagedDir = null;
        _stagedCount = null;
        _phase = _DataTabPhase.scanned;
      });
    } catch (e) {
      setState(() {
        _phase = _DataTabPhase.idle;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  void _selectRandom() {
    final countText = _randomCountController.text.trim();
    final n = int.tryParse(countText);
    if (n == null || n <= 0) return;

    final pool = _filteredFiles;
    if (pool.isEmpty) return;

    final rng = Random();
    final shuffled = List<_MidiFileEntry>.from(pool)..shuffle(rng);
    final picked = shuffled.take(min(n, shuffled.length));

    setState(() {
      _selectedPaths.clear();
      for (final f in picked) {
        _selectedPaths.add(f.relativePath);
      }
    });
  }

  Future<void> _stage() async {
    setState(() => _phase = _DataTabPhase.staging);

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.stageFiles(
        _resolvedDir,
        _selectedPaths.toList(),
      );

      setState(() {
        _stagedDir = result['staged_dir'] as String;
        _stagedCount = result['file_count'] as int;
        _phase = _DataTabPhase.staged;
      });
    } catch (e) {
      setState(() => _phase = _DataTabPhase.scanned);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staging failed: $e')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _midiDirController.text = 'midi_files';
      _metadataController.clear();
      _filterController.clear();
      _randomCountController.clear();
      _allFiles = [];
      _selectedPaths.clear();
      _activeGenres.clear();
      _activeMoods.clear();
      _availableGenres = [];
      _availableMoods = [];
      _totalSizeBytes = 0;
      _resolvedDir = '';
      _stagedDir = null;
      _stagedCount = null;
      _phase = _DataTabPhase.idle;
    });
  }

  // ---------------------------------------------------------------------------
  // Shared UI helpers
  // ---------------------------------------------------------------------------

  Widget _infoIcon(String message) {
    return Tooltip(
      message: message,
      preferBelow: false,
      child: const Padding(
        padding: EdgeInsets.only(left: 4),
        child:
            Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}

class _MidiFileEntry {
  final String relativePath;
  final int size;
  final List<String> genres;
  final List<String> moods;
  final String? artist;

  const _MidiFileEntry({
    required this.relativePath,
    required this.size,
    this.genres = const [],
    this.moods = const [],
    this.artist,
  });
}
