import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/pipeline_jobs_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/directory_browser.dart';

class PretokenizeTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const PretokenizeTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<PretokenizeTab> createState() => _PretokenizeTabState();
}

class _PretokenizeTabState extends ConsumerState<PretokenizeTab> {
  bool _submitting = false;

  final _midiDirController = TextEditingController(text: 'staging');
  final _outputController =
      TextEditingController(text: 'checkpoints/token_cache.pkl');

  @override
  void dispose() {
    _midiDirController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _midiDirController,
            decoration: InputDecoration(
              labelText: 'MIDI Directory',
              hintText: 'staging',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 20),
                    tooltip: 'Browse for directory',
                    onPressed: () => _pickDirectory(_midiDirController),
                  ),
                  _infoIcon(
                    'Directory containing .mid/.midi files to tokenize',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outputController,
            decoration: InputDecoration(
              labelText: 'Output Cache File',
              hintText: 'checkpoints/token_cache.pkl',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 20),
                    tooltip: 'Browse for output directory',
                    onPressed: _pickOutputDirectory,
                  ),
                  _infoIcon(
                    'Path where the tokenized cache (.pkl) will be saved',
                  ),
                ],
              ),
            ),
          ),
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
                  : const Text('Start Pretokenization'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDirectory(TextEditingController controller) async {
    final api = ref.read(apiClientProvider);
    final path = await showDirectoryBrowser(
      context,
      api,
      initialPath: controller.text,
    );
    if (path != null) {
      setState(() => controller.text = path);
    }
  }

  Future<void> _pickOutputDirectory() async {
    final api = ref.read(apiClientProvider);
    final current = _outputController.text;
    final lastSlash = current.lastIndexOf('/');
    final dirPart = lastSlash > 0 ? current.substring(0, lastSlash) : '.';
    final filePart =
        lastSlash >= 0 ? current.substring(lastSlash + 1) : current;

    final path = await showDirectoryBrowser(
      context,
      api,
      initialPath: dirPart,
    );
    if (path != null) {
      setState(() => _outputController.text = '$path/$filePart');
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);

      final params = <String, dynamic>{
        'midi_dir': _midiDirController.text,
        'output': _outputController.text,
        'single_track': false,
        'use_tags': true,
        'skip_validation': false,
        'validate_only': false,
        'checkpoint_interval': 500,
        'max_tracks': 16,
      };

      final taskId = await api.pretokenize(params);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'pretokenize',
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

