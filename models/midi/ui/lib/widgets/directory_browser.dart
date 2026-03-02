import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isFilePicker ? 'Select File' : 'Select Directory';

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current path display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.surfaceHigh,
              child: Text(
                _currentPath ?? '...',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Directory + file listing
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.redAccent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            // Parent directory
                            if (_parentPath != null)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.arrow_upward,
                                    size: 18, color: AppColors.textMuted),
                                title: Text('..',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.textMuted)),
                                onTap: () => _browse(_parentPath!),
                              ),
                            // Subdirectories
                            for (final dir in _directories)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.folder,
                                    size: 18, color: AppColors.controlBlue),
                                title: Text(dir,
                                    style: theme.textTheme.bodyMedium),
                                onTap: () =>
                                    _browse('$_currentPath/$dir'),
                              ),
                            // Files (only in file picker mode)
                            for (final file in _files)
                              ListTile(
                                dense: true,
                                selected: _selectedFile == file,
                                selectedTileColor:
                                    AppColors.controlBlue.withValues(alpha: 0.15),
                                leading: Icon(Icons.description,
                                    size: 18,
                                    color: _selectedFile == file
                                        ? AppColors.controlBlue
                                        : AppColors.textMuted),
                                title: Text(file,
                                    style: theme.textTheme.bodyMedium),
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
                                      ? 'No matching files'
                                      : 'No subdirectories',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
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
          child: const Text('Cancel'),
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
          child: const Text('Select'),
        ),
      ],
    );
  }

  bool get _canSelect {
    if (_isFilePicker) return _selectedFile != null;
    return _currentPath != null;
  }
}
