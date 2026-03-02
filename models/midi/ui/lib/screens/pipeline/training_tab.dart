import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_status.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/pipeline_jobs_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/directory_browser.dart';
import '../../widgets/parameter_controls.dart';

const _configPresets = <String, String>{
  'Default': '',
  'M4 Max 128GB': 'configs/m4_max_128gb.json',
  'A100 40GB': 'configs/a100_40gb.json',
  'A100 40GB (5K)': 'configs/a100_40gb_5k.json',
  '8x A100': 'configs/8x_a100.json',
  'RTX Pro 6000': 'configs/rtx_pro_6000_5k.json',
  'Debug Overfit': 'configs/debug_overfit.json',
};

class TrainingTab extends ConsumerStatefulWidget {
  final VoidCallback onTaskSubmitted;

  const TrainingTab({super.key, required this.onTaskSubmitted});

  @override
  ConsumerState<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends ConsumerState<TrainingTab> {
  bool _submitting = false;
  bool _autoTuning = false;

  // Config preset
  String _selectedPreset = 'Default';

  // Paths
  final _midiDirController = TextEditingController(text: 'midi_files');
  final _checkpointDirController = TextEditingController(text: 'checkpoints');

  // Essential training params
  int _epochs = 20;
  final _batchSizeController = TextEditingController(text: '12');
  final _lrController = TextEditingController(text: '3e-4');
  int _gradAccum = 4;

  // Fine-tuning
  final _loadFromController = TextEditingController();
  bool _finetune = false;
  int _freezeLayers = 0;

  // LoRA
  bool _lora = false;
  int _loraRank = 8;
  final _loraAlphaController = TextEditingController(text: '16.0');

  // Advanced: Model
  final _dModelController = TextEditingController(text: '512');
  final _nHeadsController = TextEditingController(text: '8');
  final _nLayersController = TextEditingController(text: '12');
  final _seqLengthController = TextEditingController(text: '8192');

  // Advanced: Training
  double _valSplit = 0.1;
  int _earlyStoppingPatience = 5;
  double _warmupPct = 0.05;
  String _scheduler = 'cosine';
  bool _noWarmup = false;

  // Advanced: Regularization
  double _dropout = 0.1;
  double _weightDecay = 0.1;
  double _gradClipNorm = 1.0;

  // Advanced: Features
  bool _useTags = true;
  bool _useCompile = true;
  bool _debug = false;
  final _maxFilesController = TextEditingController();

  @override
  void dispose() {
    _midiDirController.dispose();
    _checkpointDirController.dispose();
    _batchSizeController.dispose();
    _lrController.dispose();
    _loadFromController.dispose();
    _loraAlphaController.dispose();
    _dModelController.dispose();
    _nHeadsController.dispose();
    _nLayersController.dispose();
    _seqLengthController.dispose();
    _maxFilesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Train or fine-tune a MIDI music generation model. '
            'Requires pre-tokenized data in the checkpoint directory.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Config Preset
          _buildDropdownRow(
            context,
            label: 'Config Preset',
            tooltip:
                'Hardware-specific config preset. Overrides model and training defaults for the target GPU.',
            value: _selectedPreset,
            items: _configPresets.keys.toList(),
            onChanged: (v) => setState(() => _selectedPreset = v!),
          ),
          const SizedBox(height: 12),

          // Paths
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
                    'Directory containing .mid/.midi files (or pre-tokenized cache)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                    tooltip: 'Browse for directory',
                    onPressed: () => _pickDirectory(_checkpointDirController),
                  ),
                  _infoIcon(
                    'Directory for saving model checkpoints and training state',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Essential Training Params
          Row(
            children: [
              Text('Training', style: theme.textTheme.titleSmall),
              _infoIcon(
                'Core hyperparameters that control training duration and optimization',
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSliderRow(
            context,
            label: 'Epochs',
            tooltip:
                'Number of complete passes through the training dataset',
            value: _epochs.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            displayValue: '$_epochs',
            onChanged: (v) => setState(() => _epochs = v.round()),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _batchSizeController,
                  decoration: InputDecoration(
                    labelText: 'Batch Size',
                    hintText: '12',
                    suffixIcon: _infoIcon(
                      'Sequences per GPU per step. Larger = faster but more VRAM',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lrController,
                  decoration: InputDecoration(
                    labelText: 'Learning Rate',
                    hintText: '3e-4',
                    suffixIcon: _infoIcon(
                      'Peak learning rate. Use ~3e-4 for training from scratch, ~1e-5 for fine-tuning',
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSliderRow(
            context,
            label: 'Grad Accum',
            tooltip:
                'Accumulate gradients over N steps before updating. Effective batch = batch_size x grad_accum.',
            value: _gradAccum.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            displayValue: '$_gradAccum',
            onChanged: (v) => setState(() => _gradAccum = v.round()),
          ),
          const SizedBox(height: 16),

          // Fine-tuning Section
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fine-tuning', style: theme.textTheme.titleSmall),
                  _infoIcon(
                    'Resume from a pretrained checkpoint, optionally with LoRA adapters',
                  ),
                ],
              ),
              tilePadding: EdgeInsets.zero,
              children: [
                TextField(
                  controller: _loadFromController,
                  decoration: InputDecoration(
                    labelText: 'Load From (checkpoint path)',
                    hintText: 'path/to/checkpoint.pt',
                    suffixIcon: _infoIcon(
                      'Path to a .pt checkpoint to resume from or fine-tune',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSwitchTile(
                  title: 'Fine-tune Mode',
                  tooltip:
                      'Reset epoch counter and optimizer state for fine-tuning on new data',
                  value: _finetune,
                  onChanged: (v) => setState(() => _finetune = v),
                ),
                _buildSliderRow(
                  context,
                  label: 'Freeze Layers',
                  tooltip:
                      'Freeze the first N transformer layers. Keeps lower-level features fixed during fine-tuning.',
                  value: _freezeLayers.toDouble(),
                  min: 0,
                  max: 16,
                  divisions: 16,
                  displayValue: '$_freezeLayers',
                  onChanged: (v) =>
                      setState(() => _freezeLayers = v.round()),
                ),
                const SizedBox(height: 12),

                // LoRA
                _buildSwitchTile(
                  title: 'LoRA',
                  tooltip:
                      'Low-Rank Adaptation: freeze base model weights and train small adapter matrices. Much less VRAM.',
                  value: _lora,
                  onChanged: (v) => setState(() => _lora = v),
                ),
                if (_lora) ...[
                  if (_loadFromController.text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'LoRA requires a checkpoint path in "Load From" above.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  _buildSliderRow(
                    context,
                    label: 'LoRA Rank',
                    tooltip:
                        'Rank of the low-rank decomposition. Higher = more capacity but more parameters.',
                    value: _loraRank.toDouble(),
                    min: 2,
                    max: 64,
                    divisions: 31,
                    displayValue: '$_loraRank',
                    onChanged: (v) =>
                        setState(() => _loraRank = v.round()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _loraAlphaController,
                    decoration: InputDecoration(
                      labelText: 'LoRA Alpha',
                      hintText: '16.0',
                      suffixIcon: _infoIcon(
                        'Scaling factor for LoRA updates. Effective scale = alpha / rank.',
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Advanced Settings
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title:
                  Text('Advanced Settings', style: theme.textTheme.titleSmall),
              tilePadding: EdgeInsets.zero,
              children: [
                // Model Architecture
                Row(
                  children: [
                    Text('Model Architecture',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted)),
                    _infoIcon(
                      'Transformer dimensions. Only change when training from scratch.',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dModelController,
                        decoration: InputDecoration(
                          labelText: 'd_model',
                          hintText: '512',
                          suffixIcon: _infoIcon(
                            'Hidden dimension size of the transformer model',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nHeadsController,
                        decoration: InputDecoration(
                          labelText: 'n_heads',
                          hintText: '8',
                          suffixIcon: _infoIcon(
                            'Number of attention heads. Must evenly divide d_model.',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nLayersController,
                        decoration: InputDecoration(
                          labelText: 'n_layers',
                          hintText: '12',
                          suffixIcon: _infoIcon(
                            'Number of transformer layers. More layers = more capacity but slower.',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _seqLengthController,
                        decoration: InputDecoration(
                          labelText: 'seq_length',
                          hintText: '8192',
                          suffixIcon: _infoIcon(
                            'Maximum token sequence length. Longer = more context but quadratic memory.',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Training params
                Row(
                  children: [
                    Text('Training Parameters',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted)),
                    _infoIcon(
                      'Learning rate schedule, validation, and early stopping settings',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  context,
                  label: 'Val Split',
                  tooltip:
                      'Fraction of data reserved for validation. 0 = no validation.',
                  value: _valSplit,
                  min: 0.0,
                  max: 0.3,
                  divisions: 30,
                  displayValue: _valSplit.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _valSplit = v),
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  context,
                  label: 'Patience',
                  tooltip:
                      'Stop training after N epochs without validation loss improvement',
                  value: _earlyStoppingPatience.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  displayValue: '$_earlyStoppingPatience',
                  onChanged: (v) =>
                      setState(() => _earlyStoppingPatience = v.round()),
                ),
                const SizedBox(height: 8),

                // Scheduler
                _buildDropdownRow(
                  context,
                  label: 'Scheduler',
                  tooltip:
                      'LR schedule. Cosine decays smoothly to 0. OneCycle ramps up then down.',
                  value: _scheduler,
                  items: const ['cosine', 'onecycle'],
                  onChanged: (v) => setState(() => _scheduler = v!),
                ),
                const SizedBox(height: 8),

                _buildSwitchTile(
                  title: 'No Warmup',
                  tooltip:
                      'Skip the LR warmup phase. Useful when resuming an interrupted run.',
                  value: _noWarmup,
                  onChanged: (v) => setState(() => _noWarmup = v),
                ),
                if (!_noWarmup) ...[
                  _buildSliderRow(
                    context,
                    label: 'Warmup',
                    tooltip:
                        'Fraction of first epoch spent linearly ramping LR from 0 to peak',
                    value: _warmupPct,
                    min: 0.0,
                    max: 0.2,
                    divisions: 20,
                    displayValue: '${(_warmupPct * 100).round()}%',
                    onChanged: (v) => setState(() => _warmupPct = v),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),

                // Regularization
                Row(
                  children: [
                    Text('Regularization',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted)),
                    _infoIcon(
                      'Techniques to prevent overfitting and stabilize training',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  context,
                  label: 'Dropout',
                  tooltip:
                      'Randomly zero out this fraction of activations during training to prevent overfitting',
                  value: _dropout,
                  min: 0.0,
                  max: 0.5,
                  divisions: 50,
                  displayValue: _dropout.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _dropout = v),
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  context,
                  label: 'Weight Decay',
                  tooltip:
                      'L2 regularization strength. Penalizes large weights to reduce overfitting.',
                  value: _weightDecay,
                  min: 0.0,
                  max: 0.5,
                  divisions: 50,
                  displayValue: _weightDecay.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _weightDecay = v),
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  context,
                  label: 'Grad Clip',
                  tooltip:
                      'Maximum gradient norm. Clips gradients to prevent exploding updates.',
                  value: _gradClipNorm,
                  min: 0.1,
                  max: 5.0,
                  divisions: 49,
                  displayValue: _gradClipNorm.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _gradClipNorm = v),
                ),
                const SizedBox(height: 16),

                // Features
                Row(
                  children: [
                    Text('Features',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted)),
                    _infoIcon(
                      'Optional features for conditional generation and performance',
                    ),
                  ],
                ),
                _buildSwitchTile(
                  title: 'Use Tags',
                  tooltip:
                      'Train with genre/mood/tempo tag tokens for conditional generation',
                  value: _useTags,
                  onChanged: (v) => setState(() => _useTags = v),
                ),
                _buildSwitchTile(
                  title: 'Use torch.compile',
                  tooltip:
                      'JIT-compile the model for faster training. May increase startup time.',
                  value: _useCompile,
                  onChanged: (v) => setState(() => _useCompile = v),
                ),
                _buildSwitchTile(
                  title: 'Debug Logging',
                  tooltip:
                      'Enable verbose logging with per-step loss, grad norms, and timing',
                  value: _debug,
                  onChanged: (v) => setState(() => _debug = v),
                ),
                TextField(
                  controller: _maxFilesController,
                  decoration: InputDecoration(
                    labelText: 'Max Files (optional)',
                    hintText: 'Limit sequences to train on (for testing)',
                    suffixIcon: _infoIcon(
                      'Limit the number of sequences loaded. Useful for quick pipeline tests.',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit + Auto Tune + Reset
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
              OutlinedButton(
                onPressed: _autoTuning ? null : _autoTune,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.controlBlue,
                  side: const BorderSide(color: AppColors.controlBlue),
                ),
                child: _autoTuning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Auto Tune'),
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
                      : const Text('Start Training'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
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

  Widget _buildSwitchTile({
    required String title,
    required String tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          _infoIcon(tooltip),
        ],
      ),
      value: value,
      activeTrackColor: AppColors.controlBlue,
      activeThumbColor: Colors.white,
      inactiveTrackColor: AppColors.border,
      inactiveThumbColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderRow(
    BuildContext context, {
    required String label,
    String? tooltip,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (tooltip != null) _infoIcon(tooltip),
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
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: displayValue,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow(
    BuildContext context, {
    required String label,
    String? tooltip,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (tooltip != null) _infoIcon(tooltip),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            dropdownColor: AppColors.surfaceHigh,
          ),
        ),
      ],
    );
  }

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

  void _reset() {
    setState(() {
      _selectedPreset = 'Default';
      _midiDirController.text = 'midi_files';
      _checkpointDirController.text = 'checkpoints';
      _epochs = 20;
      _batchSizeController.text = '12';
      _lrController.text = '3e-4';
      _gradAccum = 4;
      _loadFromController.clear();
      _finetune = false;
      _freezeLayers = 0;
      _lora = false;
      _loraRank = 8;
      _loraAlphaController.text = '16.0';
      _dModelController.text = '512';
      _nHeadsController.text = '8';
      _nLayersController.text = '12';
      _seqLengthController.text = '8192';
      _valSplit = 0.1;
      _earlyStoppingPatience = 5;
      _warmupPct = 0.05;
      _scheduler = 'cosine';
      _noWarmup = false;
      _dropout = 0.1;
      _weightDecay = 0.1;
      _gradClipNorm = 1.0;
      _useTags = true;
      _useCompile = true;
      _debug = false;
      _maxFilesController.clear();
    });
  }

  Future<void> _autoTune() async {
    setState(() => _autoTuning = true);

    try {
      final api = ref.read(apiClientProvider);
      final config = await api.getAutoConfig({
        'midi_dir': _midiDirController.text,
        'checkpoint_dir': _checkpointDirController.text,
      });

      setState(() {
        if (config['epochs'] != null) _epochs = config['epochs'] as int;
        if (config['batch_size_per_gpu'] != null) {
          _batchSizeController.text = '${config['batch_size_per_gpu']}';
        }
        if (config['learning_rate'] != null) {
          _lrController.text = '${config['learning_rate']}';
        }
        if (config['gradient_accumulation'] != null) {
          _gradAccum = config['gradient_accumulation'] as int;
        }
        if (config['d_model'] != null) {
          _dModelController.text = '${config['d_model']}';
        }
        if (config['n_heads'] != null) {
          _nHeadsController.text = '${config['n_heads']}';
        }
        if (config['n_layers'] != null) {
          _nLayersController.text = '${config['n_layers']}';
        }
        if (config['seq_length'] != null) {
          _seqLengthController.text = '${config['seq_length']}';
        }
        if (config['dropout'] != null) {
          _dropout = (config['dropout'] as num).toDouble();
        }
        if (config['warmup_pct'] != null) {
          _warmupPct = (config['warmup_pct'] as num).toDouble();
        }
        if (config['val_split'] != null) {
          _valSplit = (config['val_split'] as num).toDouble();
        }
        if (config['early_stopping_patience'] != null) {
          _earlyStoppingPatience = config['early_stopping_patience'] as int;
        }
        if (config['weight_decay'] != null) {
          _weightDecay = (config['weight_decay'] as num).toDouble();
        }
        if (config['grad_clip_norm'] != null) {
          _gradClipNorm = (config['grad_clip_norm'] as num).toDouble();
        }
        if (config['use_compile'] != null) {
          _useCompile = config['use_compile'] as bool;
        }
        if (config['use_tags'] != null) {
          _useTags = config['use_tags'] as bool;
        }
        if (config['scheduler'] != null) {
          _scheduler = config['scheduler'] as String;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-tuned config applied')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-tune failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _autoTuning = false);
    }
  }

  Future<void> _submit() async {
    // Validate LoRA requires load-from
    if (_lora && _loadFromController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LoRA requires a checkpoint path in "Load From"'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);

      final params = <String, dynamic>{
        'midi_dir': _midiDirController.text,
        'checkpoint_dir': _checkpointDirController.text,
        'epochs': _epochs,
        'grad_accum': _gradAccum,
        'no_warmup': _noWarmup,
        'debug': _debug,
      };

      // Config preset
      final configPath = _configPresets[_selectedPreset] ?? '';
      if (configPath.isNotEmpty) params['config'] = configPath;

      // Numeric fields from text controllers
      final batchSize = int.tryParse(_batchSizeController.text);
      if (batchSize != null) params['batch_size'] = batchSize;

      final lr = double.tryParse(_lrController.text);
      if (lr != null) params['lr'] = lr;

      // Fine-tuning
      if (_loadFromController.text.isNotEmpty) {
        params['load_from'] = _loadFromController.text;
      }
      if (_finetune) params['finetune'] = true;
      if (_freezeLayers > 0) params['freeze_layers'] = _freezeLayers;

      // LoRA
      if (_lora) {
        params['lora'] = true;
        params['lora_rank'] = _loraRank;
        final loraAlpha = double.tryParse(_loraAlphaController.text);
        if (loraAlpha != null) params['lora_alpha'] = loraAlpha;
      }

      // Advanced: model
      final dModel = int.tryParse(_dModelController.text);
      if (dModel != null) params['d_model'] = dModel;
      final nHeads = int.tryParse(_nHeadsController.text);
      if (nHeads != null) params['n_heads'] = nHeads;
      final nLayers = int.tryParse(_nLayersController.text);
      if (nLayers != null) params['n_layers'] = nLayers;
      final seqLength = int.tryParse(_seqLengthController.text);
      if (seqLength != null) params['seq_length'] = seqLength;

      // Advanced: training
      params['val_split'] = _valSplit;
      params['early_stopping_patience'] = _earlyStoppingPatience;
      params['warmup_pct'] = _warmupPct;
      params['scheduler'] = _scheduler;

      // Advanced: regularization
      params['dropout'] = _dropout;
      params['weight_decay'] = _weightDecay;
      params['grad_clip_norm'] = _gradClipNorm;

      // Advanced: features
      params['use_tags'] = _useTags;
      params['use_compile'] = _useCompile;

      if (_maxFilesController.text.isNotEmpty) {
        params['max_files'] = int.tryParse(_maxFilesController.text);
      }

      final taskId = await api.startTraining(params);

      final initial = TaskStatus(
        taskId: taskId,
        status: TaskState.pending,
        submittedAt: DateTime.now(),
        generationType: 'training',
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
}
