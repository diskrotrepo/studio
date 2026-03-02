import 'package:flutter/material.dart';
import '../../configuration/configuration.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helpers.dart';
import '../../utils/validators.dart';

class ServerTab extends StatefulWidget {
  const ServerTab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _backends = [];
  String? _selectedId;
  bool _loading = true;
  String? _error;
  bool _allowConnections = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBackends();
    _loadAllowConnections();
  }

  Future<void> _loadAllowConnections() async {
    try {
      final settings = await widget.apiClient.getSettings();
      setState(() {
        _allowConnections = settings['allow_peer_connections'] == 'true';
      });
    } catch (_) {}
  }

  Future<void> _toggleAllowConnections(bool value) async {
    setState(() => _allowConnections = value);
    try {
      await widget.apiClient.updateSettings({
        'allow_peer_connections': value.toString(),
      });
    } catch (e) {
      setState(() => _allowConnections = !value);
      setState(() => _error = userFriendlyError(e));
    }
  }

  Future<void> _loadBackends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final backends = await widget.apiClient.getServerBackends();
      final active = backends.where((b) => b['is_active'] == true).firstOrNull;
      setState(() {
        _backends = backends;
        _selectedId = active?['id'] as String? ??
            (backends.isNotEmpty ? backends.first['id'] as String : null);
      });
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _selectedBackend {
    if (_selectedId == null) return null;
    return _backends
        .where((b) => b['id'] == _selectedId)
        .firstOrNull;
  }

  Future<void> _activateBackend(String id) async {
    try {
      await widget.apiClient.activateServerBackend(id);
      await _loadBackends();
      await widget.apiClient.refreshRemoteStatus();
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    }
  }

  Future<void> _deleteBackend(String id) async {
    try {
      await widget.apiClient.deleteServerBackend(id);
      await _loadBackends();
      await widget.apiClient.refreshRemoteStatus();
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    }
  }

  Future<void> _showBackendDialog({Map<String, dynamic>? existing}) async {
    final nameController =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final hostController =
        TextEditingController(text: existing?['api_host'] as String? ?? '');
    bool secure = existing?['secure'] as bool? ?? false;
    final formKey = GlobalKey<FormState>();

    // Health-check state used inside the dialog.
    bool testing = false;
    // null = not tested, true = healthy, false = unhealthy
    bool? healthResult;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final s = S.of(context);

            Future<void> runHealthTest() async {
              if (!formKey.currentState!.validate()) return;
              final host = hostController.text.trim();
              setDialogState(() {
                testing = true;
                healthResult = null;
              });
              final ok = await ApiClient.testRemoteHealth(
                host: host,
                secure: secure,
              );
              setDialogState(() {
                testing = false;
                healthResult = ok;
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                existing != null ? s.dialogEditServer : s.dialogAddServer,
                style: const TextStyle(color: AppColors.text, fontSize: 16),
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      label: s.labelName,
                      controller: nameController,
                      validator: (v) => requiredField(v, fieldName: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      label: s.labelApiHost,
                      controller: hostController,
                      hint: s.hintLocalhost,
                      validator: hostField,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          s.labelHttps,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: secure,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) =>
                              setDialogState(() => secure = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: testing ? null : runHealthTest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              testing ? s.testingConnection : s.buttonTestConnection,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (healthResult == true)
                          Text(
                            s.healthHealthy,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                            ),
                          )
                        else if (healthResult == false)
                          Text(
                            s.healthUnreachable,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    s.buttonCancel,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: (existing == null && healthResult != true)
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        AppColors.accent.withValues(alpha: 0.3),
                    disabledForegroundColor:
                        Colors.black.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(s.buttonSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final name = nameController.text.trim();
    final host = hostController.text.trim();
    if (name.isEmpty || host.isEmpty) return;

    try {
      if (existing != null) {
        await widget.apiClient.updateServerBackend(
          id: existing['id'] as String,
          name: name,
          apiHost: host,
          secure: secure,
        );
      } else {
        await widget.apiClient.createServerBackend(
          name: name,
          apiHost: host,
          secure: secure,
        );
      }
      await _loadBackends();
      await widget.apiClient.refreshRemoteStatus();
    } catch (e) {
      setState(() => _error = userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final config = configuration;
    final selected = _selectedBackend;
    final isActive = selected?['is_active'] == true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.serverAllowConnections,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.settingsHeading,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _allowConnections,
                activeTrackColor: AppColors.accent,
                onChanged: _toggleAllowConnections,
              ),
            ],
          ),
          Text(
            s.serverAllowConnectionsDescription,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            s.serverEnvironment,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.settingsHeading,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow(s.serverLabelBuild, config.buildEnvironment.name),
          _infoRow(s.serverLabelApiHost, config.apiHost),
          _infoRow(s.serverLabelSecure, config.secure ? 'HTTPS' : 'HTTP'),
          const SizedBox(height: 32),
          Text(
            s.serverBackends,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.settingsHeading,
            ),
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
            if (_backends.isEmpty)
              Text(
                s.serverNoBackends,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedId,
                  dropdownColor: AppColors.surfaceHigh,
                  style:
                      const TextStyle(color: AppColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.accent),
                    ),
                  ),
                  items: _backends.map((b) {
                    final name = b['name'] as String;
                    final active = b['is_active'] == true;
                    return DropdownMenuItem<String>(
                      value: b['id'] as String,
                      child: Text(
                        active ? s.serverActiveLabel(name) : name,
                        style: TextStyle(
                          color: active
                              ? AppColors.accent
                              : AppColors.text,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedId = v);
                  },
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 16),
                _infoRow(s.serverLabelHost, selected['api_host'] as String? ?? ''),
                _infoRow(
                  s.serverLabelProtocol,
                  (selected['secure'] as bool? ?? false) ? 'HTTPS' : 'HTTP',
                ),
                _infoRow(
                  s.serverLabelStatus,
                  isActive ? s.serverStatusActive : s.serverStatusInactive,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isActive)
                      _actionButton(
                        label: s.buttonActivate,
                        color: AppColors.accent,
                        onPressed: () =>
                            _activateBackend(selected['id'] as String),
                      ),
                    _actionButton(
                      label: s.buttonEdit,
                      color: AppColors.textMuted,
                      onPressed: () =>
                          _showBackendDialog(existing: selected),
                    ),
                    _actionButton(
                      label: s.buttonDelete,
                      color: Colors.redAccent,
                      onPressed: () =>
                          _deleteBackend(selected['id'] as String),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _showBackendDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  s.buttonAddServer,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  static Widget _dialogField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
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

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
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
