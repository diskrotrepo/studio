import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/pipeline_jobs_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/directory_browser.dart';

enum DiagnosisCommand { tokens, generation, all }

class DiagnosisTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const DiagnosisTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<DiagnosisTab> createState() => _DiagnosisTabState();
}

class _DiagnosisTabState extends ConsumerState<DiagnosisTab> {
  bool _submitting = false;
  DiagnosisCommand _command = DiagnosisCommand.all;

  // tokens options
  final _cacheController =
      TextEditingController(text: 'checkpoints/token_cache.pkl');
  final _tokenizerController = TextEditingController();
  final _jsonReportController = TextEditingController();

  // generation options
  final _checkpointController =
      TextEditingController(text: 'checkpoints/best_model.pt');
  final _genTokenizerController = TextEditingController();
  int _samples = 3;
  final _seedController = TextEditingController(text: '42');

  // all options
  final _checkpointDirController =
      TextEditingController(text: 'checkpoints');
  final _allSeedController = TextEditingController(text: '42');

  @override
  void dispose() {
    _cacheController.dispose();
    _tokenizerController.dispose();
    _jsonReportController.dispose();
    _checkpointController.dispose();
    _genTokenizerController.dispose();
    _seedController.dispose();
    _checkpointDirController.dispose();
    _allSeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command selector
          Text('Diagnostic Command',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<DiagnosisCommand>(
            segments: const [
              ButtonSegment(
                value: DiagnosisCommand.all,
                label: Text('All'),
              ),
              ButtonSegment(
                value: DiagnosisCommand.tokens,
                label: Text('Tokens'),
              ),
              ButtonSegment(
                value: DiagnosisCommand.generation,
                label: Text('Generation'),
              ),
            ],
            selected: {_command},
            onSelectionChanged: (set) =>
                setState(() => _command = set.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.controlBlue;
                }
                return AppColors.surface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppColors.text;
              }),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          // Command-specific options
          ..._buildCommandOptions(),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Diagnosis'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommandOptions() {
    return switch (_command) {
      DiagnosisCommand.tokens => _buildTokensOptions(),
      DiagnosisCommand.generation => _buildGenerationOptions(),
      DiagnosisCommand.all => _buildAllOptions(),
    };
  }

  List<Widget> _buildTokensOptions() {
    return [
      TextField(
        controller: _cacheController,
        decoration: InputDecoration(
          labelText: 'Token Cache File',
          hintText: 'checkpoints/token_cache.pkl',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () => _pickFile(_cacheController),
              ),
              _infoIcon('Path to the pretokenized cache file (.pkl)'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tokenizerController,
        decoration: InputDecoration(
          labelText: 'Tokenizer Path (optional)',
          hintText: 'Auto-detected from cache directory',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () => _pickFile(_tokenizerController),
              ),
              _infoIcon(
                  'Path to tokenizer.json. Defaults to same directory as cache'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _jsonReportController,
        decoration: InputDecoration(
          labelText: 'JSON Report Output (optional)',
          hintText: 'Leave empty for console output only',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () => _pickDirectory(_jsonReportController),
              ),
              _infoIcon('Save a structured JSON report to this path'),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildGenerationOptions() {
    return [
      TextField(
        controller: _checkpointController,
        decoration: InputDecoration(
          labelText: 'Model Checkpoint',
          hintText: 'checkpoints/best_model.pt',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () => _pickFile(_checkpointController),
              ),
              _infoIcon('Path to the trained model checkpoint'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _genTokenizerController,
        decoration: InputDecoration(
          labelText: 'Tokenizer Path (optional)',
          hintText: 'Auto-detected from checkpoint directory',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () => _pickFile(_genTokenizerController),
              ),
              _infoIcon('Path to tokenizer.json'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Samples: $_samples',
                        style: Theme.of(context).textTheme.bodyMedium),
                    _infoIcon('Number of test samples to generate'),
                  ],
                ),
                Slider(
                  value: _samples.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_samples',
                  onChanged: (v) =>
                      setState(() => _samples = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _seedController,
              decoration: InputDecoration(
                labelText: 'Seed',
                suffixIcon: _infoIcon('Random seed for reproducibility'),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildAllOptions() {
    return [
      TextField(
        controller: _checkpointDirController,
        decoration: InputDecoration(
          labelText: 'Checkpoint Directory',
          hintText: 'checkpoints',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse',
                onPressed: () =>
                    _pickDirectory(_checkpointDirController),
              ),
              _infoIcon(
                  'Directory containing model checkpoint and token cache'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: 120,
        child: TextField(
          controller: _allSeedController,
          decoration: InputDecoration(
            labelText: 'Seed',
            suffixIcon: _infoIcon('Random seed for generation checks'),
          ),
          keyboardType: TextInputType.number,
        ),
      ),
    ];
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

  Future<void> _pickFile(TextEditingController controller) async {
    final api = ref.read(apiClientProvider);
    final current = controller.text;
    final lastSlash = current.lastIndexOf('/');
    final dirPart = lastSlash > 0 ? current.substring(0, lastSlash) : '.';

    final path = await showDirectoryBrowser(
      context,
      api,
      initialPath: dirPart,
    );
    if (path != null) {
      final filePart =
          lastSlash >= 0 ? current.substring(lastSlash + 1) : current;
      setState(() {
        controller.text = filePart.isNotEmpty ? '$path/$filePart' : path;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);

      final params = <String, dynamic>{
        'command': _command.name,
      };

      switch (_command) {
        case DiagnosisCommand.tokens:
          params['cache'] = _cacheController.text;
          if (_tokenizerController.text.isNotEmpty) {
            params['tokenizer'] = _tokenizerController.text;
          }
          if (_jsonReportController.text.isNotEmpty) {
            params['json_report'] = _jsonReportController.text;
          }
        case DiagnosisCommand.generation:
          params['checkpoint'] = _checkpointController.text;
          if (_genTokenizerController.text.isNotEmpty) {
            params['tokenizer'] = _genTokenizerController.text;
          }
          params['samples'] = _samples;
          params['seed'] = int.tryParse(_seedController.text) ?? 42;
        case DiagnosisCommand.all:
          params['checkpoint_dir'] = _checkpointDirController.text;
          params['seed'] = int.tryParse(_allSeedController.text) ?? 42;
      }

      final taskId = await api.runDiagnosis(params);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'diagnosis',
      );

      ref.read(pipelineJobsProvider.notifier).addJob(initial);
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
