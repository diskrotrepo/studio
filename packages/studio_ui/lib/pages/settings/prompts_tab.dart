import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';

const _audioModels = [
  ('ace_step_15', 'ACE Step 1.5'),
  ('bark', 'Bark'),
];

class PromptsTab extends StatefulWidget {
  const PromptsTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<PromptsTab> createState() => _PromptsTabState();
}

class _PromptsTabState extends State<PromptsTab>
    with AutomaticKeepAliveClientMixin {
  final _lyricsPromptController = TextEditingController();
  final _audioPromptController = TextEditingController();

  String _selectedModel = 'ace_step_15';

  /// In-memory cache of per-model prompt values keyed by model name.
  /// Each value maps 'lyrics' and 'prompt' to the text.
  final Map<String, Map<String, String>> _modelPrompts = {};

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
  }

  @override
  void dispose() {
    _lyricsPromptController.dispose();
    _audioPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.apiClient.getSettings();

      // Populate cache from all model-keyed settings.
      for (final (modelId, _) in _audioModels) {
        _modelPrompts[modelId] = {
          'lyrics': settings['lyrics_system_prompt:$modelId'] ?? '',
          'prompt': settings['prompt_system_prompt:$modelId'] ?? '',
        };
      }

      // Show the selected model's values.
      _applyModel(_selectedModel);
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _storeCurrentToCache() {
    _modelPrompts[_selectedModel] = {
      'lyrics': _lyricsPromptController.text,
      'prompt': _audioPromptController.text,
    };
  }

  void _applyModel(String model) {
    final data = _modelPrompts[model];
    _lyricsPromptController.text = data?['lyrics'] ?? '';
    _audioPromptController.text = data?['prompt'] ?? '';
  }

  void _onModelChanged(String? model) {
    if (model == null || model == _selectedModel) return;
    _storeCurrentToCache();
    setState(() {
      _selectedModel = model;
      _successMessage = null;
      _error = null;
    });
    _applyModel(model);
  }

  Future<void> _saveSettings() async {
    _storeCurrentToCache();
    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await widget.apiClient.updateSettings({
        'lyrics_system_prompt:$_selectedModel':
            _lyricsPromptController.text,
        'prompt_system_prompt:$_selectedModel':
            _audioPromptController.text,
      });
      setState(() => _successMessage = S.of(context).promptsSettingsSaved);
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      setState(() => _saving = false);
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
          Row(
            children: [
              Text(
                s.promptsHeading,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.settingsHeading,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: s.infoPrompts,
                child: const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator(strokeWidth: 2)
          else ...[
            // Model selector
            Text(
              s.promptsAudioModel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              dropdownColor: AppColors.surfaceHigh,
              items: [
                for (final (id, label) in _audioModels)
                  DropdownMenuItem(value: id, child: Text(label)),
              ],
              onChanged: _onModelChanged,
            ),
            const SizedBox(height: 16),
            _promptField(
              label: s.promptsLyricsGeneration,
              controller: _lyricsPromptController,
            ),
            const SizedBox(height: 16),
            _promptField(
              label: s.promptsAudioPromptGeneration,
              controller: _audioPromptController,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        s.buttonSave,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _promptField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
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
}
