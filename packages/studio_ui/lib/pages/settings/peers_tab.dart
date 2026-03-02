import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';

class PeersTab extends StatefulWidget {
  const PeersTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<PeersTab> createState() => _PeersTabState();
}

class _PeersTabState extends State<PeersTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _peers = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPeers();
  }

  Future<void> _loadPeers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final peers = await widget.apiClient.getPeers();
      setState(() => _peers = peers);
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> peer) async {
    final id = peer['id'] as String;
    final blocked = peer['blocked'] as bool? ?? false;
    try {
      if (blocked) {
        await widget.apiClient.unblockPeer(id);
      } else {
        await widget.apiClient.blockPeer(id);
      }
      await _loadPeers();
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    }
  }

  String _truncateKey(String key) {
    if (key.length <= 16) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 8)}';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

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
                s.peersHeading,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.settingsHeading,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: s.infoPeers,
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
                  onPressed: _loading ? null : _loadPeers,
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
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            if (_peers.isEmpty)
              Text(
                s.peersEmpty,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else
              ..._peers.map(_buildPeerRow),
          ],
        ],
      ),
    );
  }

  Widget _buildPeerRow(Map<String, dynamic> peer) {
    final s = S.of(context);
    final publicKey = peer['public_key'] as String? ?? '';
    final firstSeen = peer['first_seen_at'] as String?;
    final lastSeen = peer['last_seen_at'] as String?;
    final requestCount = peer['request_count'] as int? ?? 0;
    final blocked = peer['blocked'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: blocked
              ? Colors.redAccent.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _truncateKey(publicKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: blocked ? Colors.redAccent : AppColors.text,
                  ),
                ),
              ),
              if (blocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.peerBlocked,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: () => _toggleBlock(peer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        blocked ? AppColors.textMuted : Colors.redAccent,
                    side: BorderSide(
                      color: blocked
                          ? AppColors.border
                          : Colors.redAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    blocked ? s.buttonUnblock : s.buttonBlock,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoChip(s.peerFirstSeen, _formatDate(firstSeen)),
              const SizedBox(width: 16),
              _infoChip(s.peerLastSeen, _formatDate(lastSeen)),
              const SizedBox(width: 16),
              _infoChip(s.peerRequests, '$requestCount'),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _infoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(color: AppColors.text, fontSize: 12),
        ),
      ],
    );
  }
}
