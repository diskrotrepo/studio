import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/directory_browser.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab>
    with AutomaticKeepAliveClientMixin {
  // ── Adapter type ──────────────────────────────────────────────────────────
  String _adapterType = 'lora'; // 'lora' or 'lokr'

  // ── Dataset ───────────────────────────────────────────────────────────────
  final _tensorDirController = TextEditingController();
  String? _datasetName;
  int? _numSamples;
  bool _loadingTensorInfo = false;

  // ── LoRA params ───────────────────────────────────────────────────────────
  double _loraRank = 64;
  double _loraAlpha = 128;
  double _loraDropout = 0.1;
  bool _useFp8 = false;

  // ── LoKR params ───────────────────────────────────────────────────────────
  double _lokrLinearDim = 64;
  double _lokrLinearAlpha = 128;
  final _lokrFactorController = TextEditingController(text: '-1');
  bool _lokrDecomposeBoth = false;
  bool _lokrUseTucker = false;
  bool _lokrUseScalar = false;
  bool _lokrWeightDecompose = true;

  // ── Training params ───────────────────────────────────────────────────────
  final _learningRateController = TextEditingController(text: '1e-4');
  double _trainEpochs = 10;
  double _trainBatchSize = 1;
  double _gradientAccumulation = 4;
  double _saveEveryNEpochs = 5;
  double _trainingShift = 3.0;
  final _seedController = TextEditingController(text: '42');
  bool _gradientCheckpointing = false;
  final _outputDirController =
      TextEditingController(text: './lora_output');

  // ── Training status ───────────────────────────────────────────────────────
  bool _isTraining = false;
  int _currentStep = 0;
  double? _currentLoss;
  String _statusText = '';
  int _currentEpoch = 0;
  double _stepsPerSecond = 0;
  double _estimatedTimeRemaining = 0;
  String? _trainingError;
  String? _tensorboardUrl;
  List<Map<String, dynamic>> _lossHistory = [];

  // ── Export ────────────────────────────────────────────────────────────────
  final _exportPathController = TextEditingController();
  bool _exporting = false;

  // ── General ───────────────────────────────────────────────────────────────
  String? _error;
  String? _success;
  Timer? _pollTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Check if training is already running.
    _pollTrainingStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tensorDirController.dispose();
    _lokrFactorController.dispose();
    _learningRateController.dispose();
    _seedController.dispose();
    _outputDirController.dispose();
    _exportPathController.dispose();
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

  Future<void> _loadTensorInfo() async {
    final dir = _tensorDirController.text.trim();
    if (dir.isEmpty) return;
    setState(() {
      _loadingTensorInfo = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.loadTensorInfo(dir);
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      setState(() {
        _datasetName = data['dataset_name'] as String?;
        _numSamples = data['num_samples'] as int?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingTensorInfo = false);
    }
  }

  void _onAdapterTypeChanged(String? type) {
    if (type == null || type == _adapterType) return;
    setState(() {
      _adapterType = type;
      // Update defaults that differ between adapter types.
      if (type == 'lokr') {
        if (_learningRateController.text == '1e-4') {
          _learningRateController.text = '0.03';
        }
        if (_trainEpochs == 10) _trainEpochs = 500;
        if (_outputDirController.text == './lora_output') {
          _outputDirController.text = './lokr_output';
        }
      } else {
        if (_learningRateController.text == '0.03') {
          _learningRateController.text = '1e-4';
        }
        if (_trainEpochs == 500) _trainEpochs = 10;
        if (_outputDirController.text == './lokr_output') {
          _outputDirController.text = './lora_output';
        }
      }
    });
  }

  Future<void> _startTraining() async {
    setState(() {
      _error = null;
      _success = null;
    });
    // Validate inputs before submission.
    final tensorErr =
        requiredField(_tensorDirController.text, fieldName: 'Tensor directory');
    if (tensorErr != null) {
      setState(() => _error = tensorErr);
      return;
    }
    final outputErr =
        requiredField(_outputDirController.text, fieldName: 'Output directory');
    if (outputErr != null) {
      setState(() => _error = outputErr);
      return;
    }
    final lrErr = positiveDouble(
        _learningRateController.text, fieldName: 'Learning rate');
    if (lrErr != null) {
      setState(() => _error = lrErr);
      return;
    }
    final seedErr = seedField(_seedController.text);
    if (seedErr != null) {
      setState(() => _error = seedErr);
      return;
    }

    try {
      final lr = double.parse(_learningRateController.text.trim());
      final seed = int.tryParse(_seedController.text.trim()) ?? 42;

      if (_adapterType == 'lora') {
        await widget.apiClient.startTraining({
          'tensor_dir': _tensorDirController.text.trim(),
          'lora_rank': _loraRank.round(),
          'lora_alpha': _loraAlpha.round(),
          'lora_dropout': _loraDropout,
          'learning_rate': lr,
          'train_epochs': _trainEpochs.round(),
          'train_batch_size': _trainBatchSize.round(),
          'gradient_accumulation': _gradientAccumulation.round(),
          'save_every_n_epochs': _saveEveryNEpochs.round(),
          'training_shift': _trainingShift,
          'training_seed': seed,
          'lora_output_dir': _outputDirController.text.trim(),
          'use_fp8': _useFp8,
          'gradient_checkpointing': _gradientCheckpointing,
        });
      } else {
        final factor =
            int.tryParse(_lokrFactorController.text.trim()) ?? -1;
        await widget.apiClient.startLoKRTraining({
          'tensor_dir': _tensorDirController.text.trim(),
          'lokr_linear_dim': _lokrLinearDim.round(),
          'lokr_linear_alpha': _lokrLinearAlpha.round(),
          'lokr_factor': factor,
          'lokr_decompose_both': _lokrDecomposeBoth,
          'lokr_use_tucker': _lokrUseTucker,
          'lokr_use_scalar': _lokrUseScalar,
          'lokr_weight_decompose': _lokrWeightDecompose,
          'learning_rate': lr,
          'train_epochs': _trainEpochs.round(),
          'train_batch_size': _trainBatchSize.round(),
          'gradient_accumulation': _gradientAccumulation.round(),
          'save_every_n_epochs': _saveEveryNEpochs.round(),
          'training_shift': _trainingShift,
          'training_seed': seed,
          'output_dir': _outputDirController.text.trim(),
          'gradient_checkpointing': _gradientCheckpointing,
        });
      }
      if (!mounted) return;
      setState(() => _isTraining = true);
      _startPolling();
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    }
  }

  Future<void> _stopTraining() async {
    final s = S.of(context);
    setState(() => _error = null);
    try {
      await widget.apiClient.stopTraining();
      if (mounted) setState(() => _success = s.trainingStopRequested);
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    }
  }

  Future<void> _exportLora() async {
    final s = S.of(context);
    final exportPath = _exportPathController.text.trim();
    if (exportPath.isEmpty) {
      setState(() => _error = s.errorExportPathRequired);
      return;
    }
    setState(() {
      _exporting = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.apiClient.exportLora(
        exportPath: exportPath,
        loraOutputDir: _outputDirController.text.trim(),
      );
      if (mounted) setState(() => _success = s.loraExportedSuccessfully);
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTrainingStatus(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTrainingStatus() async {
    try {
      final result = await widget.apiClient.getTrainingStatus();
      if (!mounted) return;
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final wasTraining = _isTraining;
      setState(() {
        _isTraining = data['is_training'] as bool? ?? false;
        _currentStep = data['current_step'] as int? ?? 0;
        _currentLoss = (data['current_loss'] as num?)?.toDouble();
        _statusText = data['status'] as String? ?? '';
        _currentEpoch = data['current_epoch'] as int? ?? 0;
        _stepsPerSecond =
            (data['steps_per_second'] as num?)?.toDouble() ?? 0;
        _estimatedTimeRemaining =
            (data['estimated_time_remaining'] as num?)?.toDouble() ?? 0;
        _trainingError = data['error'] as String?;
        _tensorboardUrl = data['tensorboard_url'] as String?;

        final history = data['loss_history'];
        if (history is List) {
          _lossHistory = history.cast<Map<String, dynamic>>();
        }
      });

      if (_isTraining && _pollTimer == null) {
        _startPolling();
      } else if (!_isTraining && wasTraining) {
        _stopPolling();
        if (_trainingError != null) {
          _error = _trainingError;
        } else {
          _success = 'Training complete';
        }
      }
    } catch (_) {
      // Silently ignore polling errors.
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

          // ── Dataset section ───────────────────────────────────────────
          _sectionHeader(s.trainingSectionDataset),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _field(
                    label: s.labelTensorDirectory,
                    controller: _tensorDirController,
                    hint: s.hintTensorPath,
                    info: s.infoTensorDirectory,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _browseButton(() => _pickDirectory(_tensorDirController), tooltip: s.tooltipBrowse),
              const SizedBox(width: 12),
              _actionButton(
                label: _loadingTensorInfo ? s.loadingEllipsis : s.buttonLoadInfo,
                onPressed: _loadingTensorInfo ? null : _loadTensorInfo,
              ),
            ],
          ),
          if (_datasetName != null || _numSamples != null) ...[
            const SizedBox(height: 8),
            _infoRow(s.labelDataset, _datasetName ?? s.labelUnknown),
            _infoRow(s.labelSamples, '${_numSamples ?? 0}'),
          ],

          const SizedBox(height: 32),

          // ── Adapter type ──────────────────────────────────────────────
          _sectionHeader(s.trainingSectionAdapterType),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: _dropdown(
              value: _adapterType,
              items: const ['lora', 'lokr'],
              labels: const ['LoRA', 'LoKR'],
              onChanged: _onAdapterTypeChanged,
            ),
          ),

          const SizedBox(height: 24),

          // ── Adapter-specific params ───────────────────────────────────
          if (_adapterType == 'lora') ...[
            _sectionHeader(s.trainingSectionLoraParams),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  _buildSlider(
                    label: s.labelRank,
                    subtitle: s.subtitleRank,
                    value: _loraRank,
                    min: 1,
                    max: 256,
                    divisions: 255,
                    displayValue: '${_loraRank.round()}',
                    onChanged: (v) =>
                        setState(() => _loraRank = v.roundToDouble()),
                    info: s.infoRank,
                  ),
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelAlpha,
                    subtitle: s.subtitleAlpha,
                    value: _loraAlpha,
                    min: 1,
                    max: 512,
                    divisions: 511,
                    displayValue: '${_loraAlpha.round()}',
                    onChanged: (v) =>
                        setState(() => _loraAlpha = v.roundToDouble()),
                    info: s.infoAlpha,
                  ),
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelDropout,
                    subtitle: s.subtitleDropout,
                    value: _loraDropout,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    displayValue: _loraDropout.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _loraDropout = v),
                    info: s.infoDropout,
                  ),
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelUseFp8,
                    subtitle: s.subtitleUseFp8,
                    value: _useFp8,
                    onChanged: (v) => setState(() => _useFp8 = v),
                    info: s.infoUseFp8,
                  ),
                ],
              ),
            ),
          ] else ...[
            _sectionHeader(s.trainingSectionLokrParams),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  _buildSlider(
                    label: s.labelLinearDim,
                    subtitle: s.subtitleLinearDim,
                    value: _lokrLinearDim,
                    min: 1,
                    max: 256,
                    divisions: 255,
                    displayValue: '${_lokrLinearDim.round()}',
                    onChanged: (v) => setState(
                        () => _lokrLinearDim = v.roundToDouble()),
                    info: s.infoLinearDim,
                  ),
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: s.labelLinearAlpha,
                    subtitle: s.subtitleLinearAlpha,
                    value: _lokrLinearAlpha,
                    min: 1,
                    max: 512,
                    divisions: 511,
                    displayValue: '${_lokrLinearAlpha.round()}',
                    onChanged: (v) => setState(
                        () => _lokrLinearAlpha = v.roundToDouble()),
                    info: s.infoLinearAlpha,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    label: s.labelFactor,
                    controller: _lokrFactorController,
                    hint: s.hintFactorAuto,
                    info: s.infoFactor,
                  ),
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelDecomposeBoth,
                    subtitle: s.subtitleDecomposeBoth,
                    value: _lokrDecomposeBoth,
                    onChanged: (v) =>
                        setState(() => _lokrDecomposeBoth = v),
                    info: s.infoDecomposeBoth,
                  ),
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelUseTucker,
                    subtitle: s.subtitleUseTucker,
                    value: _lokrUseTucker,
                    onChanged: (v) =>
                        setState(() => _lokrUseTucker = v),
                    info: s.infoUseTucker,
                  ),
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelUseScalar,
                    subtitle: s.subtitleUseScalar,
                    value: _lokrUseScalar,
                    onChanged: (v) =>
                        setState(() => _lokrUseScalar = v),
                    info: s.infoUseScalar,
                  ),
                  const SizedBox(height: 8),
                  _buildToggle(
                    label: s.labelWeightDecompose,
                    subtitle: s.subtitleWeightDecompose,
                    value: _lokrWeightDecompose,
                    onChanged: (v) =>
                        setState(() => _lokrWeightDecompose = v),
                    info: s.infoWeightDecompose,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Training params ───────────────────────────────────────────
          _sectionHeader(s.trainingSectionTrainingParams),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                _field(
                  label: s.labelLearningRate,
                  controller: _learningRateController,
                  hint: _adapterType == 'lora' ? '1e-4' : '0.03',
                  info: s.infoLearningRate,
                ),
                const SizedBox(height: 8),
                _buildSlider(
                  label: s.labelEpochs,
                  subtitle: s.subtitleEpochs,
                  value: _trainEpochs,
                  min: 1,
                  max: 4000,
                  divisions: 3999,
                  displayValue: '${_trainEpochs.round()}',
                  onChanged: (v) =>
                      setState(() => _trainEpochs = v.roundToDouble()),
                  info: s.infoEpochs,
                ),
                const SizedBox(height: 8),
                _buildSlider(
                  label: s.labelBatchSize,
                  subtitle: s.subtitleBatchSize,
                  value: _trainBatchSize,
                  min: 1,
                  max: 16,
                  divisions: 15,
                  displayValue: '${_trainBatchSize.round()}',
                  onChanged: (v) => setState(
                      () => _trainBatchSize = v.roundToDouble()),
                  info: s.infoBatchSize,
                ),
                const SizedBox(height: 8),
                _buildSlider(
                  label: s.labelGradientAccumulation,
                  subtitle: s.subtitleGradientAccumulation,
                  value: _gradientAccumulation,
                  min: 1,
                  max: 32,
                  divisions: 31,
                  displayValue: '${_gradientAccumulation.round()}',
                  onChanged: (v) => setState(
                      () => _gradientAccumulation = v.roundToDouble()),
                  info: s.infoGradientAccumulation,
                ),
                const SizedBox(height: 8),
                _buildSlider(
                  label: s.labelSaveEveryNEpochs,
                  subtitle: s.subtitleSaveEveryNEpochs,
                  value: _saveEveryNEpochs,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  displayValue: '${_saveEveryNEpochs.round()}',
                  onChanged: (v) => setState(
                      () => _saveEveryNEpochs = v.roundToDouble()),
                  info: s.infoSaveEveryNEpochs,
                ),
                const SizedBox(height: 8),
                _buildSlider(
                  label: s.labelShift,
                  subtitle: s.subtitleTrainingShift,
                  value: _trainingShift,
                  min: 0,
                  max: 10,
                  divisions: 100,
                  displayValue: _trainingShift.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _trainingShift = v),
                  info: s.infoTrainingShift,
                ),
                const SizedBox(height: 8),
                _field(
                  label: s.labelSeed,
                  controller: _seedController,
                  hint: '42',
                  info: s.infoSeed,
                ),
                const SizedBox(height: 8),
                _buildToggle(
                  label: s.labelGradientCheckpointing,
                  subtitle: s.subtitleGradientCheckpointing,
                  value: _gradientCheckpointing,
                  onChanged: (v) =>
                      setState(() => _gradientCheckpointing = v),
                  info: s.infoGradientCheckpointing,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        label: s.labelOutputDirectory,
                        controller: _outputDirController,
                        hint: './lora_output',
                        info: s.infoOutputDirectory,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _browseButton(
                        () => _pickDirectory(_outputDirController), tooltip: s.tooltipBrowse),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Controls ──────────────────────────────────────────────────
          _sectionHeader(s.trainingSectionControls),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(
                label: s.buttonStartTraining,
                onPressed: _isTraining ? null : _startTraining,
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: _isTraining ? _stopTraining : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: _isTraining
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    s.buttonStopTraining,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Status ────────────────────────────────────────────────────
          if (_isTraining ||
              _statusText.isNotEmpty ||
              _trainingError != null) ...[
            _sectionHeader(s.trainingSectionStatus),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(s.trainingLabelStatus, _statusText),
                    _infoRow(s.trainingLabelEpoch, '$_currentEpoch'),
                    _infoRow(s.trainingLabelStep, '$_currentStep'),
                    if (_currentLoss != null)
                      _infoRow(
                        s.trainingLabelLoss,
                        _currentLoss!.toStringAsFixed(6),
                      ),
                    _infoRow(
                      s.trainingLabelSpeed,
                      s.trainingSpeedValue(_stepsPerSecond.toStringAsFixed(2)),
                    ),
                    if (_estimatedTimeRemaining > 0)
                      _infoRow(
                        s.trainingLabelETA,
                        _formatDuration(_estimatedTimeRemaining),
                      ),
                    if (_trainingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          s.trainingErrorPrefix(_trainingError!),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_tensorboardUrl != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.trainingTensorboard(_tensorboardUrl!),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Loss chart
            if (_lossHistory.length >= 2) ...[
              const SizedBox(height: 16),
              _sectionHeader(s.trainingSectionLoss),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CustomPaint(
                    painter: _LossChartPainter(
                      _lossHistory
                          .map((e) => (e['loss'] as num).toDouble())
                          .toList(),
                    ),
                    size: const Size(500, 120),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],

          // ── Export ────────────────────────────────────────────────────
          _sectionHeader(s.trainingSectionExport),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Row(
              children: [
                Expanded(
                  child: _field(
                    label: s.labelExportPath,
                    controller: _exportPathController,
                    hint: s.hintExportPath,
                    info: s.infoExportPath,
                  ),
                ),
                const SizedBox(width: 4),
                _browseButton(
                    () => _pickDirectory(_exportPathController), tooltip: s.tooltipBrowse),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: _exporting ? s.exportingEllipsis : s.buttonExportLora,
            onPressed: _exporting ? null : _exportLora,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

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

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
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
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
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
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem(value: items[i], child: Text(labels[i])),
      ),
      onChanged: onChanged,
    );
  }

  static Widget _buildSlider({
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
          style:
              const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.controlPink,
            inactiveTrackColor: AppColors.surfaceHigh,
            thumbColor: AppColors.controlPink,
            overlayColor: AppColors.controlPink.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 6),
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

  static Widget _buildToggle({
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
          disabledBackgroundColor:
              AppColors.accent.withValues(alpha: 0.3),
          disabledForegroundColor:
              Colors.black.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Loss chart painter ────────────────────────────────────────────────────────

class _LossChartPainter extends CustomPainter {
  _LossChartPainter(this.lossHistory);

  final List<double> lossHistory;

  @override
  void paint(Canvas canvas, Size size) {
    if (lossHistory.length < 2) return;

    final padding = 8.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    final maxLoss = lossHistory.reduce(math.max);
    final minLoss = lossHistory.reduce(math.min);
    final range = maxLoss - minLoss;
    if (range == 0) return;

    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < lossHistory.length; i++) {
      final x = padding + (i / (lossHistory.length - 1)) * w;
      final y =
          padding + h - ((lossHistory[i] - minLoss) / range) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Axis lines.
    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, padding + h),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, padding + h),
      Offset(padding + w, padding + h),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LossChartPainter oldDelegate) =>
      oldDelegate.lossHistory != lossHistory;
}
