/// Upgrades a coach answer to the full markdown dialect.
///
/// The responders compose html-lite with typographic bullets (`• `) and
/// bold-only section headers, which the markdown renderer would show as
/// flat paragraphs. This rewrites those two shapes into real list and
/// heading blocks, so answers render with proper hierarchy, indented
/// bullets and Fraunces headings — without touching the translations.
///
/// Runs AFTER `htmlLiteToMarkdown` (it expects `**bold**`, not `<b>`).
String enrichCoachMarkdown(String markdown) {
  final lines = markdown.split('\n');
  return [
    for (final line in lines) _enrichLine(line),
  ].join('\n');
}

final _bullet = RegExp(r'^\s*•\s*');
final _boldOnly = RegExp(r'^\s*\*\*(.+?)\*\*\s*$');

String _enrichLine(String line) {
  if (_bullet.hasMatch(line)) return line.replaceFirst(_bullet, '- ');
  // A line that is nothing but bold text is a section header.
  final header = _boldOnly.firstMatch(line);
  if (header != null) return '### ${header[1]}';
  return line;
}
