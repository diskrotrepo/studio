import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(serverUrlProvider));
    _urlController.addListener(() {
      final isDirty = _urlController.text.trim() != ref.read(serverUrlProvider);
      if (isDirty != _dirty) setState(() => _dirty = isDirty);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    updateServerUrl(ref, url);
    ref.invalidate(healthProvider);
    setState(() => _dirty = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server URL updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF161616),
        foregroundColor: AppColors.text,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Server', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://localhost:8000',
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 4),
          Text(
            'The address of the machine running the MIDI API server.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dirty ? _save : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
