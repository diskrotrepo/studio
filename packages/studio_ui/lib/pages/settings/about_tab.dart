import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  static const _buildDate =
      String.fromEnvironment('BUILD_DATE', defaultValue: 'dev');
  static const _buildBranch =
      String.fromEnvironment('BUILD_BRANCH', defaultValue: 'dev');

  String? _publicKey;
  bool _copied = false;
  bool _keyExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPublicKey();
  }

  Future<void> _loadPublicKey() async {
    try {
      final settings = await widget.apiClient.getSettings();
      final key = settings['server_public_key'];
      if (mounted && key != null) {
        setState(() => _publicKey = key);
      }
    } catch (_) {}
  }

  void _copyKey() {
    if (_publicKey == null) return;
    Clipboard.setData(ClipboardData(text: _publicKey!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.aboutVersion,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.settingsHeading,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('ACE-Step', '1.5'),
          _infoRow('Bark', 'v0 (suno-ai)'),
          _infoRow('YuLan-Mini', '2.4B'),
          _infoRow('UI', _buildDate),
          _infoRow('Backend', _buildDate),
          _infoRow(s.aboutBranch, _buildBranch),
          const SizedBox(height: 32),
          Text(
            s.aboutCredits,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.settingsHeading,
            ),
          ),
          const SizedBox(height: 8),
          _creditRow(
            'ACE-Step',
            'ACE Studio & Jinhao Chen et al.',
            'https://github.com/ACE-Step/ACE-Step',
          ),
          _creditRow(
            'Bark',
            'Suno AI',
            'https://github.com/suno-ai/bark',
          ),
          _creditRow(
            'YuLan-Mini',
            'RUC AI Box',
            'https://github.com/RUC-GSAI/YuLan-Mini',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                s.aboutStudioBy,
                style: const TextStyle(color: AppColors.text, fontSize: 13),
              ),
              GestureDetector(
                onTap: () =>
                    web.window.open('https://diskrot.com', '_blank'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    s.aboutDiskrot,
                    style: const TextStyle(
                      color: AppColors.hotPink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => web.window.open(
                'https://github.com/diskrotrepo/studio', '_blank'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                s.aboutSourceOnGithub,
                style: const TextStyle(
                  color: AppColors.hotPink,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (_publicKey != null) ...[
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => setState(() => _keyExpanded = !_keyExpanded),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Icon(
                      _keyExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.aboutServerPublicKey,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.settingsHeading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_keyExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        _publicKey!,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyKey,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Tooltip(
                          message:
                              _copied ? s.tooltipCopied : s.tooltipCopyToClipboard,
                          child: Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 16,
                            color: _copied
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static Widget _creditRow(String label, String team, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => web.window.open(url, '_blank'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                team,
                style: const TextStyle(
                  color: AppColors.hotPink,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
