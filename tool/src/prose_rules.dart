import 'package:dartchess/dartchess.dart';
import 'package:karpachess/core/chess/san_moves.dart';

import 'lesson_glossary.dart';

/// The prose rules lessons and puzzles share.
///
/// `tool/lint_lessons.dart` and `tool/lint_puzzles.dart` read two different
/// file shapes and hold them to one register: the same answer-leak test, the
/// same spelling, the same banned furniture, the same check of a sentence
/// about a square against the board it describes. Each rule lives here once,
/// so the two gates cannot drift apart on what a rule means.

/// L04 / P02 — the field of [haystacks] (name → text) that hands over [san],
/// or null when none does.
///
/// Only the decorated forms count. A pawn move's SAN *is* a square name, so
/// "open the file behind d5" must stay legal while "trade with **{{cxd4}}**"
/// must not.
String? answerLeakIn(String san, Map<String, String> haystacks) {
  final core = cleanSan(san);
  if (core.isEmpty) return null;
  final bare = RegExp(r'[NBRQK]|x|=|O-O').hasMatch(core);
  final escaped = RegExp.escape(core);
  final decorated = RegExp(
    r'(\{\{\s*' // a chip
    '$escaped'
    r'[+#]?\s*\}\}'
    r'|`' // inline code
    '$escaped'
    r'[+#]?`'
    r'|\*\*' // bold
    '$escaped'
    r'[+#]?\*\*)',
  );
  // A move that names a piece, a capture or a castle cannot be mistaken for
  // ordinary prose, so it counts wherever it appears.
  final plain = RegExp(r'\b' '$escaped' r'[+#]?\b');

  for (final entry in haystacks.entries) {
    final text = entry.value;
    if (text.isEmpty) continue;
    if (decorated.hasMatch(text) || (bare && plain.hasMatch(text))) {
      return entry.key;
    }
  }
  return null;
}

/// P02 — the field of [haystacks] that picks out [san]'s landing square as a
/// chip, in bold or as code: pointing at the answer without naming it.
///
/// Null for a pawn push, whose SAN *is* the square and which [answerLeakIn]
/// already judges, and for castling, which lands nowhere a sentence names.
String? landingSquareLeakIn(String san, Map<String, String> haystacks) {
  final core = cleanSan(san);
  final match = RegExp(r'([a-h][1-8])(=[NBRQ])?$').firstMatch(core);
  if (match == null) return null;
  final square = match[1]!;
  if (square == core) return null;
  final marked = RegExp(
    r'(\{\{\s*' '$square' r'\s*\}\}|\*\*' '$square' r'\*\*|`' '$square' '`)',
  );
  for (final entry in haystacks.entries) {
    if (marked.hasMatch(entry.value)) return entry.key;
  }
  return null;
}

final _sanRe = RegExp(
  r'^(O-O-O|O-O|[NBRQK][a-h1-8]?x?[a-h][1-8]|[a-h]x?[a-h][1-8](=[NBRQ])?)[+#]?$',
);
final _codeRe = RegExp(r'`([^`]+)`');

/// L05 / P06 — every span of inline code in [prose] that is a move.
///
/// A chip is tappable and previews the move on the board; backticks render as
/// inert type. Backticks are for text that must *not* become a move.
Iterable<String> backtickSans(String prose) sync* {
  for (final match in _codeRe.allMatches(prose)) {
    final span = match[1]!.trim();
    if (_sanRe.hasMatch(span)) yield span;
  }
}

/// L07 / P06 — every off-register spelling in [text], as (found, wanted).
Iterable<(String, String)> offRegister(String text) sync* {
  for (final entry in spellingRegister.entries) {
    if (entry.key == entry.value) continue;
    final re = RegExp(r'\b' + entry.key + r'\b', caseSensitive: false);
    if (re.hasMatch(text)) yield (entry.key, entry.value);
  }
}

/// L09 / P06 — the banned phrases [text] contains.
Iterable<String> bannedIn(String text) {
  final lower = text.toLowerCase();
  return bannedPhrases.where(lower.contains);
}

final _pronounRe = RegExp(r'\b(he|him|his|she|her|hers)\b', caseSensitive: false);

/// L09 / P06 — the first gendered pronoun in [text]. The opponent is White,
/// Black or your opponent; pieces are "it"; people are "they".
RegExpMatch? firstPronoun(String text) => _pronounRe.firstMatch(text);

/// A sentence's claim that a piece stands on a square: "the knight on f6",
/// "Black's rook on a8", "your queen on d1".
class SquareClaim {
  const SquareClaim(
    this.text,
    this.role,
    this.square, {
    this.side,
    this.mine,
  });

  /// The words as written, for the finding.
  final String text;
  final Role role;
  final Square square;

  /// The side when it is named outright — "Black's rook", "the white king".
  final Side? side;

  /// The side when it is named by owner: true for "your", false for "your
  /// opponent's". Resolved against the learner's side in [claimHolds].
  final bool? mine;
}

final _claimRe = RegExp(
  r"\b(?:(white|black)(?:['’]s)?\s+"
  r"|(your opponent['’]s|the opponent['’]s|opponent['’]s|your)\s+)?"
  // "on", never "at": a piece *on* f7 is a claim about the board, while a queen
  // thrown *at* f7 is aim, and the queen is somewhere else entirely.
  r'(pawn|knight|bishop|rook|queen|king)\s+on\s+([a-h][1-8])\b',
  caseSensitive: false,
);

const _roleOf = {
  'pawn': Role.pawn,
  'knight': Role.knight,
  'bishop': Role.bishop,
  'rook': Role.rook,
  'queen': Role.queen,
  'king': Role.king,
};

/// L03 / P05 — every piece-on-square claim in [text].
Iterable<SquareClaim> squareClaims(String text) sync* {
  for (final match in _claimRe.allMatches(text)) {
    final named = match[1]?.toLowerCase();
    final owner = match[2]?.toLowerCase();
    yield SquareClaim(
      // One line in a finding, even when the sentence wrapped mid-claim.
      match[0]!.replaceAll(RegExp(r'\s+'), ' ').trim(),
      _roleOf[match[3]!.toLowerCase()]!,
      Square.fromName(match[4]!.toLowerCase()),
      side: named == null ? null : (named == 'white' ? Side.white : Side.black),
      mine: owner == null ? null : owner == 'your',
    );
  }
}

/// Whether [claim] is true of at least one of [boards]. "Your" is the
/// [learner]'s side.
///
/// Any of the boards will do: prose that walks through its own line ("after
/// {{e4}}, the pawn on e4…") describes a later frame, and that is fine. What
/// this catches is prose edited while its position stayed put.
bool claimHolds(
  SquareClaim claim,
  Iterable<Board> boards, {
  required Side learner,
}) {
  final side = claim.side ??
      switch (claim.mine) {
        true => learner,
        false => learner.opposite,
        null => null,
      };
  return boards.any((board) {
    final piece = board.pieceAt(claim.square);
    if (piece == null || piece.role != claim.role) return false;
    return side == null || piece.color == side;
  });
}

/// Markdown stripped down to the words a reader actually reads. A chip counts
/// as the move it names, because that is what is on the page.
String plain(String markdown) => markdown
    .replaceAll(RegExp(r'\{\{\s*|\s*\}\}'), '')
    .replaceAll(RegExp(r'[`*_>#]'), '')
    .replaceAll(RegExp(r'^\s*(\d+\.|[-])\s', multiLine: true), '')
    .trim();

int wordCount(String markdown) {
  final text = plain(markdown);
  if (text.isEmpty) return 0;
  return text.split(RegExp(r'\s+')).length;
}

/// Sentences, tolerating the two things chess prose does with a full stop:
/// `1.e4` and the `...d5` that marks a black move.
int sentenceCount(String markdown) {
  final text = plain(markdown)
      .replaceAll(RegExp(r'\.{2,}'), '')
      .replaceAll(RegExp(r'(?<=\d)\.(?=[a-hA-Z])'), '');
  return RegExp(r'[.!?](\s|$)').allMatches(text).length.clamp(1, 99);
}
