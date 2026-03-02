import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await widget.apiClient.getLogs();
      setState(() => _logs = logs.reversed.toList());
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.orangeAccent;
      case 'INFO':
        return AppColors.accent;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              s.logsHeading,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.settingsHeading,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: s.infoLogs,
              child: const Icon(
                Icons.info_outline,
                size: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 28,
              child: IconButton(
                onPressed: _loading ? null : _loadLogs,
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
                color: Colors.lightBlue,
                tooltip: s.tooltipRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const CircularProgressIndicator(strokeWidth: 2)
        else if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          )
        else if (_logs.isEmpty)
          Text(
            s.logsEmpty,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          )
        else
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final entry = _logs[index];
                  final severity = entry['severity'] as String?;
                  final timestamp = entry['timestamp'] as String? ?? '';
                  final message = entry['message'] as String? ?? '';
                  final error = entry['error'] as String?;

                  // Show short local time.
                  final dt = DateTime.tryParse(timestamp);
                  final timeStr = dt != null
                      ? '${_pad(dt.toLocal().hour)}:${_pad(dt.toLocal().minute)}:${_pad(dt.toLocal().second)}'
                      : timestamp;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                        children: [
                          TextSpan(
                            text: '$timeStr ',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: '${severity ?? 'LOG'} ',
                            style: TextStyle(
                              color: _severityColor(severity),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: message),
                          if (error != null)
                            TextSpan(
                              text: '\n  $error',
                              style: const TextStyle(
                                color: Colors.redAccent,
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
      ],
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
