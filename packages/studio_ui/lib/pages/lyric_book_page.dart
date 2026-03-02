import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/lyric_sheet.dart';
import '../models/lyrics_block.dart';
import '../models/task_status.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class LyricBookPage extends StatefulWidget {
  const LyricBookPage({super.key});

  @override
  State<LyricBookPage> createState() => _LyricBookPageState();
}

class _LyricBookPageState extends State<LyricBookPage> {
  late final ApiClient _api;
  List<LyricSheet> _sheets = [];
  LyricSheet? _selectedSheet;
  List<Map<String, dynamic>> _linkedSongs = [];
  bool _loading = true;
  List<TaskStatus> _matchedSongs = [];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _loadSheets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSheets() async {
    try {
      final sheets = await _api.getLyricSheets();
      if (!mounted) return;
      setState(() {
        _sheets = sheets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _selectSheet(LyricSheet sheet) async {
    setState(() {
      _selectedSheet = sheet;
      _linkedSongs = [];
    });
    try {
      final detail = await _api.getLyricSheetDetail(sheet.id);
      if (!mounted) return;
      final songs = (detail['songs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      setState(() => _linkedSongs = songs);
    } catch (_) {}
  }

  Future<void> _deleteSheet(LyricSheet sheet) async {
    final s = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.lyricBookDeleteTitle),
        content: Text(s.lyricBookDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.buttonDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteLyricSheet(sheet.id);
      if (!mounted) return;
      setState(() {
        _sheets.removeWhere((s) => s.id == sheet.id);
        if (_selectedSheet?.id == sheet.id) {
          _selectedSheet = null;
          _linkedSongs = [];
        }
      });
    } catch (_) {}
  }

  Future<void> _doSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _matchedSongs = []);
      await _loadSheets();
      return;
    }
    try {
      final sheets = await _api.searchLyricSheets(query);
      final songsResp = await _api.getSongs(lyricsSearch: query, limit: 20);
      if (!mounted) return;
      setState(() {
        _sheets = sheets;
        _matchedSongs = songsResp.songs;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: _buildListPanel(s),
        ),
        Container(width: 1, color: AppColors.border),
        Expanded(child: _buildDetailPanel(s)),
      ],
    );
  }

  Widget _buildListPanel(S s) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: s.lyricBookSearch,
                    prefixIcon:
                        const Icon(Icons.search, size: 18, color: AppColors.accent),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: _doSearch,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _sheets.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        s.lyricBookNoSheets,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sheets.length +
                          (_matchedSongs.isNotEmpty ? _matchedSongs.length + 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _sheets.length) {
                          return _buildSheetTile(_sheets[index]);
                        }
                        final songIdx = index - _sheets.length;
                        if (songIdx == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            child: Text(
                              s.lyricBookSearchSongs,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        }
                        final song = _matchedSongs[songIdx - 1];
                        return _buildSongResultTile(song);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSheetTile(LyricSheet sheet) {
    final selected = _selectedSheet?.id == sheet.id;
    final blocks = parseLyricsBlocks(sheet.content);
    final snippet = blocks.isNotEmpty
        ? blocks.first.content.split('\n').take(2).join(' ').trim()
        : '';
    return GestureDetector(
      onTap: () => _selectSheet(sheet),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFAB47BC).withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? const Color(0xFFAB47BC) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.title.isEmpty ? 'Untitled' : sheet.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFFAB47BC) : AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (snippet.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          snippet,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              _IconBtn(
                icon: Icons.delete_outline,
                size: 16,
                onTap: () => _deleteSheet(sheet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongResultTile(TaskStatus song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.music_note, size: 14, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                song.title ?? song.taskId,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              song.model ?? '',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(S s) {
    if (_selectedSheet == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              s.labelLyricBook,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.lyricBookNoSheets,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedSheet!.title.isEmpty
                  ? 'Untitled'
                  : _selectedSheet!.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _buildLinkedSongsSection(s),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedSongsSection(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              s.lyricBookLinkedSongs,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_linkedSongs.isEmpty)
          Text(
            s.lyricBookNoLinkedSongs,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          ..._linkedSongs.map((song) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (song['title'] as String?) ?? song['task_id'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song['model'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.size = 18,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: AppColors.accent,
          ),
        ),
      ),
    );
    return child;
  }
}
