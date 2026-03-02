import 'package:flutter/material.dart';

import '../models/lyrics_block.dart';
import '../theme/app_theme.dart';

/// Maps a block header name to a distinct accent color for its left border.
Color blockTypeColor(String header) {
  return switch (header.toLowerCase()) {
    'verse' => const Color(0xFF42A5F5),
    'chorus' => const Color(0xFFEC407A),
    'pre-chorus' => const Color(0xFFAB47BC),
    'bridge' => const Color(0xFF26A69A),
    'intro' => const Color(0xFF66BB6A),
    'outro' => const Color(0xFFFFA726),
    'hook' => const Color(0xFFEF5350),
    'interlude' => const Color(0xFF5C6BC0),
    'breakdown' => const Color(0xFFFF7043),
    'ad-lib' => const Color(0xFF78909C),
    _ => AppColors.border,
  };
}

class LyricsBlockEditor extends StatefulWidget {
  const LyricsBlockEditor({
    super.key,
    required this.controller,
    this.hintText,
    this.onGenerateBlock,
  });

  final TextEditingController controller;
  final String? hintText;
  /// Called when the user taps the AI generate icon on a block.
  /// Receives the block index.
  final void Function(int index)? onGenerateBlock;

  @override
  State<LyricsBlockEditor> createState() => _LyricsBlockEditorState();
}

class _LyricsBlockEditorState extends State<LyricsBlockEditor> {
  List<LyricsBlock> _blocks = [];
  List<TextEditingController> _contentControllers = [];
  bool _isSyncing = false;
  String _lastSyncedText = '';

  static const _sectionPresets = [
    'verse',
    'chorus',
    'pre-chorus',
    'bridge',
    'intro',
    'outro',
    'hook',
    'interlude',
    'breakdown',
    'ad-lib',
  ];

  @override
  void initState() {
    super.initState();
    _rebuildFromText();
    widget.controller.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    for (final c in _contentControllers) {
      c.removeListener(_onBlockContentChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onExternalChange() {
    if (_isSyncing) return;
    // Ignore selection-only changes from other TextFields sharing the
    // same controller — only rebuild when the actual text differs.
    if (widget.controller.text == _lastSyncedText) return;
    setState(_rebuildFromText);
  }

  void _rebuildFromText() {
    for (final c in _contentControllers) {
      c.removeListener(_onBlockContentChanged);
      c.dispose();
    }
    _lastSyncedText = widget.controller.text;
    _blocks = parseLyricsBlocks(_lastSyncedText);
    _contentControllers = _blocks.map((b) {
      final c = TextEditingController(text: b.content);
      c.addListener(_onBlockContentChanged);
      return c;
    }).toList();
  }

  void _onBlockContentChanged() {
    for (var i = 0; i < _blocks.length; i++) {
      _blocks[i].content = _contentControllers[i].text;
    }
    _syncToController();
  }

  void _syncToController() {
    _isSyncing = true;
    _lastSyncedText = serializeLyricsBlocks(_blocks);
    widget.controller.text = _lastSyncedText;
    _isSyncing = false;
  }

  void _addBlock() {
    setState(() {
      final block = LyricsBlock(header: 'verse');
      _blocks.add(block);
      final c = TextEditingController();
      c.addListener(_onBlockContentChanged);
      _contentControllers.add(c);
    });
    _syncToController();
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      final c = _contentControllers.removeAt(index);
      c.removeListener(_onBlockContentChanged);
      c.dispose();
    });
    _syncToController();
  }

  void _duplicateBlock(int index) {
    setState(() {
      final source = _blocks[index];
      final block = LyricsBlock(
        header: source.header,
        content: source.content,
      );
      _blocks.insert(index + 1, block);
      final c = TextEditingController(text: block.content);
      c.addListener(_onBlockContentChanged);
      _contentControllers.insert(index + 1, c);
    });
    _syncToController();
  }

  void _moveBlock(int index, int direction) {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _blocks.length) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(newIndex, block);
      final c = _contentControllers.removeAt(index);
      _contentControllers.insert(newIndex, c);
    });
    _syncToController();
  }

  void _changeHeader(int index, String newHeader) {
    setState(() {
      _blocks[index].header = newHeader;
    });
    _syncToController();
  }

  Future<void> _showCustomHeaderDialog(int index) async {
    final controller = TextEditingController(text: _blocks[index].header);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter section name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null &&
        result.isNotEmpty &&
        !result.contains('[') &&
        !result.contains(']')) {
      _changeHeader(index, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _addBlock,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.hintText ?? 'Enter lyrics...',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAddButton(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _blocks.length; i++) _buildBlockCard(i),
        const SizedBox(height: 8),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addBlock,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Add Block',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockCard(int index) {
    final block = _blocks[index];
    final accentColor = blockTypeColor(block.header);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: index > 0
                            ? () => _moveBlock(index, -1)
                            : null,
                        child: MouseRegion(
                          cursor: index > 0
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: index > 0
                                  ? AppColors.textMuted
                                  : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: index < _blocks.length - 1
                            ? () => _moveBlock(index, 1)
                            : null,
                        child: MouseRegion(
                          cursor: index < _blocks.length - 1
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 16,
                              color: index < _blocks.length - 1
                                  ? AppColors.textMuted
                                  : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      _buildHeaderDropdown(index, block.header),
                      const Spacer(),
                      if (widget.onGenerateBlock != null)
                        GestureDetector(
                          onTap: () => widget.onGenerateBlock!(index),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.psychology,
                                size: 16,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _duplicateBlock(index),
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeBlock(index),
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TextField(
                    controller: _contentControllers[index],
                    maxLines: null,
                    minLines: 4,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Enter lyrics...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDropdown(int index, String currentHeader) {
    return PopupMenuButton<String>(
      tooltip: 'Section type',
      onSelected: (value) {
        if (value == '_custom') {
          _showCustomHeaderDialog(index);
        } else {
          _changeHeader(index, value);
        }
      },
      itemBuilder: (_) => [
        for (final preset in _sectionPresets)
          PopupMenuItem(
            value: preset,
            child: Row(
              children: [
                if (preset == currentHeader)
                  const Icon(Icons.check, size: 14, color: AppColors.accent)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 8),
                Text(preset, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '_custom',
          child: Row(
            children: [
              Icon(Icons.edit, size: 14, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text('Custom...', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentHeader,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
