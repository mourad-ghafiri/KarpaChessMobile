/// Structured parser for the KarpaChess markdown dialect. It produces a block
/// tree rather than HTML.
///
/// Supported:
///   `## H2`, `### H3`, `#### H4`
///   `**bold**`, `*italic*`, `_italic_` (never intraword), `` `code` ``
///   `> blockquote`
///   `- ` bullet list / `1. ` ordered list
///   `---` horizontal rule
///   blank line = paragraph break
///   `{{e4}}`, `{{Nf3}}`, `{{O-O}}` -> SAN move chip
///
/// The parser is line-based, and the order is exact:
/// inline code is locked first (its content is never further processed), then
/// SAN chips, then bold, then italic. Bold content can contain code spans and
/// chips but never `*` (so no italic inside bold); italic content can wrap a
/// complete bold span. Consecutive paragraph / quote lines are joined with a
/// single space.
library;

import 'package:collection/collection.dart';

const _deepEq = DeepCollectionEquality();

// ---------------------------------------------------------------- blocks

sealed class MdBlock {
  const MdBlock();
}

/// `##` / `###` / `####` heading; [level] is 2..4.
class MdHeading extends MdBlock {
  const MdHeading(this.level, this.spans);

  final int level;
  final List<MdInline> spans;

  @override
  bool operator ==(Object other) =>
      other is MdHeading &&
      other.level == level &&
      _deepEq.equals(other.spans, spans);

  @override
  int get hashCode => Object.hash(level, _deepEq.hash(spans));

  @override
  String toString() => 'MdHeading($level, $spans)';
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);

  final List<MdInline> spans;

  @override
  bool operator ==(Object other) =>
      other is MdParagraph && _deepEq.equals(other.spans, spans);

  @override
  int get hashCode => _deepEq.hash(spans);

  @override
  String toString() => 'MdParagraph($spans)';
}

class MdQuote extends MdBlock {
  const MdQuote(this.spans);

  final List<MdInline> spans;

  @override
  bool operator ==(Object other) =>
      other is MdQuote && _deepEq.equals(other.spans, spans);

  @override
  int get hashCode => _deepEq.hash(spans);

  @override
  String toString() => 'MdQuote($spans)';
}

class MdListBlock extends MdBlock {
  const MdListBlock({required this.ordered, required this.items});

  final bool ordered;
  final List<List<MdInline>> items;

  @override
  bool operator ==(Object other) =>
      other is MdListBlock &&
      other.ordered == ordered &&
      _deepEq.equals(other.items, items);

  @override
  int get hashCode => Object.hash(ordered, _deepEq.hash(items));

  @override
  String toString() => 'MdListBlock(ordered: $ordered, $items)';
}

class MdRule extends MdBlock {
  const MdRule();

  @override
  bool operator ==(Object other) => other is MdRule;

  @override
  int get hashCode => (MdRule).hashCode;

  @override
  String toString() => 'MdRule()';
}

// ---------------------------------------------------------------- inlines

sealed class MdInline {
  const MdInline();
}

class MdText extends MdInline {
  const MdText(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is MdText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MdText(${_quote(text)})';
}

class MdBold extends MdInline {
  const MdBold(this.children);

  final List<MdInline> children;

  @override
  bool operator ==(Object other) =>
      other is MdBold && _deepEq.equals(other.children, children);

  @override
  int get hashCode => _deepEq.hash(children);

  @override
  String toString() => 'MdBold($children)';
}

class MdItalic extends MdInline {
  const MdItalic(this.children);

  final List<MdInline> children;

  @override
  bool operator ==(Object other) =>
      other is MdItalic && _deepEq.equals(other.children, children);

  @override
  int get hashCode => _deepEq.hash(children);

  @override
  String toString() => 'MdItalic($children)';
}

class MdCode extends MdInline {
  const MdCode(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is MdCode && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MdCode(${_quote(text)})';
}

/// A `{{...}}` SAN move chip; [san] is trimmed.
class MdSanChip extends MdInline {
  const MdSanChip(this.san);

  final String san;

  @override
  bool operator ==(Object other) => other is MdSanChip && other.san == san;

  @override
  int get hashCode => san.hashCode;

  @override
  String toString() => 'MdSanChip(${_quote(san)})';
}

String _quote(String s) => "'${s.replaceAll("'", r"\'")}'";

// ---------------------------------------------------------------- parsing

final _ruleRe = RegExp(r'^\s*---+\s*$');
final _headingRe = RegExp(r'^\s*(#{2,4})\s+(.+?)\s*$');
final _headingStartRe = RegExp(r'^\s*#{2,4}\s+');
final _quoteRe = RegExp(r'^\s*>\s?');
final _bulletRe = RegExp(r'^\s*[-*]\s+');
final _orderedRe = RegExp(r'^\s*\d+\.\s+');

final _codeRe = RegExp(r'`([^`]+)`');
final _chipRe = RegExp(r'\{\{([^{}]+)\}\}');
final _boldRe = RegExp(r'\*\*([^*]+)\*\*');
final _italicRe = RegExp(r'(?<!\*)\*([^*\n]+)\*');

/// Underscore emphasis, `_like this_` — the coach strings are written with it
/// (`_({phase})_`), so without this rule they showed literal underscores. The lookarounds keep intraword
/// underscores (snake_case in an imported PGN comment) out of italics, the
/// same restraint standard markdown shows.
final _italicUnderscoreRe = RegExp(r'(?<![\w_])_([^_\n]+)_(?![\w_])');
final _slotRe = RegExp('\u0000(\\d+)\u0000');

/// Parses [source] into a list of blocks. Line-based; never throws.
List<MdBlock> parseKarpaMarkdown(String source) {
  final lines = source.replaceAll(RegExp('\r\n?'), '\n').split('\n');

  final blocks = <MdBlock>[];
  var i = 0;

  bool startsBlock(String line) =>
      _headingStartRe.hasMatch(line) ||
      _bulletRe.hasMatch(line) ||
      _orderedRe.hasMatch(line) ||
      _quoteRe.hasMatch(line) ||
      _ruleRe.hasMatch(line);

  while (i < lines.length) {
    final raw = lines[i];

    // Skip blank lines between blocks.
    if (raw.trim().isEmpty) {
      i++;
      continue;
    }

    // Horizontal rule.
    if (_ruleRe.hasMatch(raw)) {
      blocks.add(const MdRule());
      i++;
      continue;
    }

    // Heading.
    final heading = _headingRe.firstMatch(raw);
    if (heading != null) {
      blocks.add(MdHeading(heading[1]!.length, parseInline(heading[2]!)));
      i++;
      continue;
    }

    // Blockquote — consume consecutive `> ` lines, joined with a space.
    if (_quoteRe.hasMatch(raw)) {
      final buf = <String>[];
      while (i < lines.length && _quoteRe.hasMatch(lines[i])) {
        buf.add(lines[i].replaceFirst(_quoteRe, ''));
        i++;
      }
      blocks.add(MdQuote(parseInline(buf.join(' '))));
      continue;
    }

    // Unordered list.
    if (_bulletRe.hasMatch(raw)) {
      final items = <List<MdInline>>[];
      while (i < lines.length && _bulletRe.hasMatch(lines[i])) {
        items.add(parseInline(lines[i].replaceFirst(_bulletRe, '')));
        i++;
      }
      blocks.add(MdListBlock(ordered: false, items: items));
      continue;
    }

    // Ordered list.
    if (_orderedRe.hasMatch(raw)) {
      final items = <List<MdInline>>[];
      while (i < lines.length && _orderedRe.hasMatch(lines[i])) {
        items.add(parseInline(lines[i].replaceFirst(_orderedRe, '')));
        i++;
      }
      blocks.add(MdListBlock(ordered: true, items: items));
      continue;
    }

    // Paragraph — gather consecutive non-blank, non-block lines.
    final buf = <String>[lines[i]];
    i++;
    while (i < lines.length) {
      final next = lines[i];
      if (next.trim().isEmpty || startsBlock(next)) break;
      buf.add(next);
      i++;
    }
    blocks.add(MdParagraph(parseInline(buf.join(' '))));
  }

  return blocks;
}

/// Parses inline markdown within one block's text, in this order: code spans
/// first (their content is locked), then SAN chips, then bold, then italic.
List<MdInline> parseInline(String text) {
  // Locked nodes are swapped out for NUL-delimited index slots so later
  // passes cannot see inside them - the placeholder scheme that locks code
  // spans.
  final locked = <MdInline>[];
  var s = text.replaceAll('\u0000', '');

  String lock(MdInline node) {
    locked.add(node);
    return '\u0000${locked.length - 1}\u0000';
  }

  List<MdInline> expand(String value) {
    final spans = <MdInline>[];
    var last = 0;
    for (final m in _slotRe.allMatches(value)) {
      if (m.start > last) spans.add(MdText(value.substring(last, m.start)));
      spans.add(locked[int.parse(m[1]!)]);
      last = m.end;
    }
    if (last < value.length) spans.add(MdText(value.substring(last)));
    return spans;
  }

  // Inline code first so its content is locked from further processing.
  s = s.replaceAllMapped(_codeRe, (m) => lock(MdCode(m[1]!)));

  // SAN move chip — {{Nf3}} or {{e4}} or {{O-O}}.
  s = s.replaceAllMapped(_chipRe, (m) => lock(MdSanChip(m[1]!.trim())));

  // Bold, then italic. Bold content contains no `*`, so it may hold code
  // spans and chips but never italics; italic content may wrap a bold slot.
  s = s.replaceAllMapped(_boldRe, (m) => lock(MdBold(expand(m[1]!))));
  s = s.replaceAllMapped(_italicRe, (m) => lock(MdItalic(expand(m[1]!))));
  s = s.replaceAllMapped(
    _italicUnderscoreRe,
    (m) => lock(MdItalic(expand(m[1]!))),
  );

  return expand(s);
}
