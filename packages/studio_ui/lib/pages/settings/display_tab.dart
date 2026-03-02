import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';
import '../../widgets/visualizers/shader_cache.dart';
import '../../widgets/visualizers/shader_visualizer_painter.dart';
import '../../widgets/visualizers/visualizer_type.dart';

class DisplayTab extends StatefulWidget {
  const DisplayTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<DisplayTab> createState() => _DisplayTabState();
}

class _DisplayTabState extends State<DisplayTab>
    with AutomaticKeepAliveClientMixin {
  VisualizerType _selected = VisualizerType.creamdrop;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    ShaderCache.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.apiClient.getSettings();
      if (!mounted) return;
      setState(() {
        _selected =
            VisualizerType.fromSettingsValue(settings['visualizer_type']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFriendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await widget.apiClient.updateSettings({
        'visualizer_type': _selected.settingsValue,
      });
      widget.apiClient.visualizerType.value = _selected;
      if (mounted) {
        setState(
            () => _successMessage = S.of(context).displaySettingsSaved);
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.displayVisualizerHeading,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.settingsHeading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.displayVisualizerDescription,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator(strokeWidth: 2)
          else ...[
            for (final type in VisualizerType.values)
              _VisualizerOption(
                type: type,
                selected: _selected == type,
                onTap: () => setState(() {
                  _selected = type;
                  _successMessage = null;
                  _error = null;
                }),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saving ? null : _saveSettings,
                  child: Text(_saving ? '...' : s.buttonSave),
                ),
                const SizedBox(width: 12),
                if (_successMessage != null)
                  Text(
                    _successMessage!,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
                if (_error != null)
                  Flexible(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VisualizerOption extends StatelessWidget {
  const _VisualizerOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final VisualizerType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    final (label, description) = switch (type) {
      VisualizerType.creamdrop => (
          s.visualizerCreamdrop,
          s.visualizerCreamdropDescription,
        ),
      VisualizerType.waveform => (
          s.visualizerWaveform,
          s.visualizerWaveformDescription,
        ),
      VisualizerType.spectrum => (
          s.visualizerSpectrum,
          s.visualizerSpectrumDescription,
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.controlPink : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color:
                  selected ? AppColors.controlPink : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            _ShaderPreview(type: type),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.text
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a small live shader preview thumbnail for a visualizer type.
class _ShaderPreview extends StatefulWidget {
  const _ShaderPreview({required this.type});

  final VisualizerType type;

  @override
  State<_ShaderPreview> createState() => _ShaderPreviewState();
}

class _ShaderPreviewState extends State<_ShaderPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = ShaderCache.forType(widget.type);
    if (program == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF08080E),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => CustomPaint(
            size: const Size.square(48),
            painter: ShaderVisualizerPainter(
              shader: program.fragmentShader(),
              time: _anim.value,
              bass: 0.5,
              mid: 0.4,
              treble: 0.3,
              beat: 0.2,
              colorSeed: switch (widget.type) {
                VisualizerType.creamdrop => 30.0,
                VisualizerType.waveform => 180.0,
                VisualizerType.spectrum => 280.0,
              },
              selected: false,
              playbackProgress: null,
            ),
          ),
        ),
      ),
    );
  }
}
