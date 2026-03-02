/// Strips path traversal sequences and unsafe characters from a filename
/// before sending it to the server in a multipart upload.
///
/// This is a defense-in-depth measure; the server should also validate
/// filenames, but the client should not send obviously dangerous values.
String sanitizeFilename(String filename) {
  var name = filename;

  // 1. Take only the basename (strip any directory components).
  final lastSlash = name.lastIndexOf('/');
  if (lastSlash >= 0) name = name.substring(lastSlash + 1);
  final lastBackslash = name.lastIndexOf('\\');
  if (lastBackslash >= 0) name = name.substring(lastBackslash + 1);

  // 2. Remove path traversal sequences.
  name = name.replaceAll('..', '');

  // 3. Remove characters that are unsafe in filenames across platforms.
  //    Allow alphanumerics, dots, hyphens, underscores, spaces.
  name = name.replaceAll(RegExp(r'[^\w.\- ]'), '');

  // 4. Collapse multiple dots and trim.
  name = name.replaceAll(RegExp(r'\.{2,}'), '.').trim();

  // 5. Fallback if the name is now empty.
  if (name.isEmpty) name = 'upload';

  return name;
}
