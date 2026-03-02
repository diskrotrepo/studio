import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/genre_data.dart';
import '../theme/app_theme.dart';
import 'genre_chip.dart';

/// A prompt text field with inline genre autocomplete and chips displayed
/// inside the field container. Genres are selected via tab/enter/click from
/// the autocomplete dropdown. Chips appear above the text area.
class GenreAutocomplete extends StatefulWidget {
  const GenreAutocomplete({
    super.key,
    required this.promptController,
    required this.selectedGenres,
    required this.onChanged,
    this.hintText,
    this.maxLines = 6,
  });

  final TextEditingController promptController;
  final List<MapEntry<String, MajorGenre>> selectedGenres;
  final ValueChanged<List<MapEntry<String, MajorGenre>>> onChanged;
  final String? hintText;
  final int maxLines;

  @override
  State<GenreAutocomplete> createState() => _GenreAutocompleteState();
}

class _GenreAutocompleteState extends State<GenreAutocomplete> {
  final _focusNode = FocusNode();
  List<MapEntry<String, MajorGenre>> _filteredResults = [];
  bool _showOverlay = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.promptController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    widget.promptController.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  /// Extract the current token being typed: text from the last comma/newline
  /// backward from the cursor position.
  String _currentToken() {
    final text = widget.promptController.text;
    final selection = widget.promptController.selection;
    if (!selection.isValid || !selection.isCollapsed) return '';
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return '';

    var start = cursor;
    while (start > 0) {
      final c = text[start - 1];
      if (c == ',' || c == '\n') break;
      start--;
    }
    return text.substring(start, cursor).trim();
  }

  void _onTextChanged() {
    if (!_focusNode.hasFocus) return;
    final query = _currentToken();
    if (query.isEmpty) {
      _filteredResults = [];
      _removeOverlay();
      return;
    }
    _filteredResults = _filterGenres(query);
    _highlightedIndex = 0;
    if (_filteredResults.isNotEmpty) {
      _showResultsOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onFocusChanged() {
    setState(() {}); // rebuild for border color
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  List<MapEntry<String, MajorGenre>> _filterGenres(String query) {
    final lower = query.toLowerCase();
    final selected =
        widget.selectedGenres.map((e) => e.key.toLowerCase()).toSet();

    final startsWith = <MapEntry<String, MajorGenre>>[];
    final contains = <MapEntry<String, MajorGenre>>[];

    for (final entry in genreDatabase.entries) {
      if (selected.contains(entry.key.toLowerCase())) continue;
      final nameLower = entry.key.toLowerCase();
      if (nameLower == lower) {
        startsWith.insert(0, entry);
      } else if (nameLower.startsWith(lower)) {
        startsWith.add(entry);
      } else if (nameLower.contains(lower)) {
        contains.add(entry);
      }
    }

    return [...startsWith, ...contains].take(50).toList();
  }

  void _selectGenre(MapEntry<String, MajorGenre> genre) {
    final text = widget.promptController.text;
    final cursor = widget.promptController.selection.baseOffset;

    // Find token start.
    var start = cursor;
    while (start > 0) {
      final c = text[start - 1];
      if (c == ',' || c == '\n') break;
      start--;
    }

    // Consume trailing whitespace/comma after cursor.
    var end = cursor;
    while (end < text.length && text[end] == ' ') {
      end++;
    }
    if (end < text.length && text[end] == ',') {
      end++;
      while (end < text.length && text[end] == ' ') {
        end++;
      }
    }

    final before = text.substring(0, start);
    final after = text.substring(end);

    String newText;
    if (before.isEmpty) {
      newText = after;
    } else if (after.isEmpty) {
      newText = before.replaceAll(RegExp(r'[,\s]+$'), '');
    } else {
      newText = before + after;
    }

    widget.promptController.text = newText;
    widget.promptController.selection = TextSelection.collapsed(
      offset: (before.isEmpty ? 0 : before.length).clamp(0, newText.length),
    );

    final updated = [...widget.selectedGenres, genre];
    widget.onChanged(updated);

    _filteredResults = [];
    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _removeGenre(MapEntry<String, MajorGenre> genre) {
    final updated =
        widget.selectedGenres.where((e) => e.key != genre.key).toList();
    widget.onChanged(updated);
  }

  // ── Overlay management ──────────────────────────────────────────────

  void _showResultsOverlay() {
    _removeOverlay();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _showOverlay = true;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showOverlay = false;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 0,
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _filteredResults.length,
                itemBuilder: (context, index) {
                  final genre = _filteredResults[index];
                  final isHighlighted = index == _highlightedIndex;
                  return _GenreOptionTile(
                    genre: genre,
                    highlighted: isHighlighted,
                    onTap: () => _selectGenre(genre),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Keyboard handling ───────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Backspace when text is empty removes last chip.
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.selectedGenres.isNotEmpty &&
          widget.promptController.text.isEmpty) {
        final updated = [...widget.selectedGenres]..removeLast();
        widget.onChanged(updated);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (_showOverlay && _filteredResults.isNotEmpty) {
        _selectGenre(_filteredResults[_highlightedIndex]);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_showOverlay && _filteredResults.isNotEmpty) {
        _selectGenre(_filteredResults[_highlightedIndex]);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_showOverlay && _filteredResults.isNotEmpty) {
        _highlightedIndex =
            (_highlightedIndex + 1).clamp(0, _filteredResults.length - 1);
        _updateOverlay();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_showOverlay && _filteredResults.isNotEmpty) {
        _highlightedIndex =
            (_highlightedIndex - 1).clamp(0, _filteredResults.length - 1);
        _updateOverlay();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_showOverlay) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = _focusNode.hasFocus;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: hasFocus ? AppColors.text : AppColors.border,
            width: hasFocus ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.selectedGenres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final genre in widget.selectedGenres)
                      GenreChip(
                        name: genre.key,
                        genre: genre.value,
                        onRemove: () => _removeGenre(genre),
                      ),
                  ],
                ),
              ),
            Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: widget.promptController,
                focusNode: _focusNode,
                maxLines: widget.maxLines,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreOptionTile extends StatelessWidget {
  const _GenreOptionTile({
    required this.genre,
    required this.highlighted,
    required this.onTap,
  });

  final MapEntry<String, MajorGenre> genre;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = genre.value.color;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: highlighted ? Colors.white10 : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  genre.key,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                genre.value.name,
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
