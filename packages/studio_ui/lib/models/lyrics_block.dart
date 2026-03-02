class LyricsBlock {
  LyricsBlock({required this.header, this.content = ''});

  String header;
  String content;
}

final _headerPattern = RegExp(r'^\[(.+)\]$');

List<LyricsBlock> parseLyricsBlocks(String text) {
  if (text.trim().isEmpty) return [];
  final lines = text.split('\n');
  final blocks = <LyricsBlock>[];
  final buffer = StringBuffer();
  String? currentHeader;

  for (final line in lines) {
    final match = _headerPattern.firstMatch(line.trim());
    if (match != null) {
      if (currentHeader != null || buffer.isNotEmpty) {
        blocks.add(LyricsBlock(
          header: currentHeader ?? 'verse',
          content: buffer.toString().trim(),
        ));
        buffer.clear();
      }
      currentHeader = match.group(1)!;
    } else {
      if (buffer.isNotEmpty || line.trim().isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(line);
      }
    }
  }

  if (currentHeader != null || buffer.isNotEmpty) {
    blocks.add(LyricsBlock(
      header: currentHeader ?? 'verse',
      content: buffer.toString().trim(),
    ));
  }

  return blocks;
}

String serializeLyricsBlocks(List<LyricsBlock> blocks) {
  if (blocks.isEmpty) return '';
  return blocks.map((b) => '[${b.header}]\n${b.content}').join('\n\n');
}
