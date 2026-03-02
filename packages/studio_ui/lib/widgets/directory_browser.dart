import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/error_helpers.dart';

/// Shows a server-side directory browser dialog.
/// Returns the selected directory path, or null if cancelled.
Future<String?> showDirectoryBrowser(
  BuildContext context,
  ApiClient api, {
  String initialPath = '.',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BrowserDialog(api: api, initialPath: initialPath),
  );
}

/// Shows a server-side file browser dialog filtered by extensions.
/// Returns the selected file path, or null if cancelled.
Future<String?> showFileBrowser(
  BuildContext context,
  ApiClient api, {
  String initialPath = '.',
  required List<String> extensions,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BrowserDialog(
      api: api,
      initialPath: initialPath,
      fileExtensions: extensions,
    ),
  );
}

class _BrowserDialog extends StatefulWidget {
  final ApiClient api;
  final String initialPath;
  final List<String>? fileExtensions;

  const _BrowserDialog({
    required this.api,
    required this.initialPath,
    this.fileExtensions,
  });

  @override
  State<_BrowserDialog> createState() => _BrowserDialogState();
}

class _BrowserDialogState extends State<_BrowserDialog> {
  String? _currentPath;
  String? _parentPath;
  List<String> _directories = [];
  List<String> _files = [];
  String? _selectedFile;
  bool _loading = true;
  String? _error;

  bool get _isFilePicker => widget.fileExtensions != null;

  @override
  void initState() {
    super.initState();
    _browse(widget.initialPath);
  }

  Future<void> _browse(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedFile = null;
    });

    try {
      final result = await widget.api.browseDirectory(
        path,
        fileExtensions: widget.fileExtensions,
      );
      if (!mounted) return;

      setState(() {
        _currentPath = result['path'] as String;
        _parentPath = result['parent'] as String?;
        _directories = (result['directories'] as List).cast<String>();
        _files = (result['files'] as List?)?.cast<String>() ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = _isFilePicker ? s.dialogSelectFile : s.dialogSelectDirectory;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: const TextStyle(color: AppColors.text, fontSize: 16),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.surfaceHigh,
              child: Text(
                _currentPath ?? '...',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            if (_parentPath != null)
                              _entry(
                                icon: Icons.arrow_upward,
                                iconColor: AppColors.textMuted,
                                label: '..',
                                onTap: () => _browse(_parentPath!),
                              ),
                            for (final dir in _directories)
                              _entry(
                                icon: Icons.folder,
                                iconColor: AppColors.accent,
                                label: dir,
                                onTap: () =>
                                    _browse('$_currentPath/$dir'),
                              ),
                            for (final file in _files)
                              _entry(
                                icon: Icons.description,
                                iconColor: _selectedFile == file
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                                label: file,
                                selected: _selectedFile == file,
                                onTap: () =>
                                    setState(() => _selectedFile = file),
                              ),
                            if (_directories.isEmpty &&
                                _files.isEmpty &&
                                _parentPath == null)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _isFilePicker
                                      ? s.noMatchingFiles
                                      : s.noSubdirectories,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            s.buttonCancel,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _canSelect
              ? () {
                  if (_isFilePicker && _selectedFile != null) {
                    Navigator.of(context)
                        .pop('$_currentPath/$_selectedFile');
                  } else if (!_isFilePicker && _currentPath != null) {
                    Navigator.of(context).pop(_currentPath);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            disabledBackgroundColor:
                AppColors.accent.withValues(alpha: 0.3),
            disabledForegroundColor:
                Colors.black.withValues(alpha: 0.4),
          ),
          child: Text(s.buttonSelect),
        ),
      ],
    );
  }

  Widget _entry({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSelect {
    if (_isFilePicker) return _selectedFile != null;
    return _currentPath != null;
  }
}
