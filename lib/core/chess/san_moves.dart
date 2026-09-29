import 'package:dartchess/dartchess.dart';

import 'castling_moves.dart';

/// Ordered, de-duplicated `{{san}}` chip tokens found in markdown text.
/// Mirrors the markdown parser's chip syntax without rendering anything.
List<String> extractSanTokens(String markdown) {
  final seen = <String>{};
  final out = <String>[];
  for (final match in RegExp(r'\{\{([^{}]+)\}\}').allMatches(markdown)) {
    final san = match[1]!.trim();
    if (san.isNotEmpty && seen.add(san)) out.add(san);
  }
  return out;
}

/// SAN without its check/mate decoration, so `Qxf7` matches `Qxf7#`.
///
/// Every place that compares one SAN against another uses this — the
/// academy's lesson and Sharpen loops, the puzzle trainer's, and the studio
/// looking for an existing child of a move-tree node.
String cleanSan(String san) => san.replaceAll(RegExp(r'[+#]'), '');

/// Whether [move], played in [position], answers the [authored] move.
///
/// The authored move always does. So does any OTHER checkmate, when the
/// authored move is itself a checkmate: a puzzle that rejects a mate because
/// its author happened to write down a different one teaches the reader that
/// mating was the mistake. Anything short of mate must still be the authored
/// move — a line is accepted exactly as written until the game is over.
///
/// The one judge every solve loop asks: the trainer's [PuzzleSolver], the
/// academy's play and proof beats, and Sharpen.
bool acceptsAuthored(Position position, NormalMove move, String authored) {
  final (next, san) = position.makeSan(move);
  if (cleanSan(san) == cleanSan(authored)) return true;
  if (!next.isCheckmate) return false;
  final scripted = legalMoveFromSan(position, authored);
  return scripted != null && position.play(scripted).isCheckmate;
}

/// Parses [san] against [position]; null when illegal or unparseable.
///
/// The one seam authored SAN enters through — lesson `{{san}}` chips, puzzle
/// solutions and their scripted replies, Sharpen's answers — so it is where
/// castling is put into the king's own form (see [kingCastlingForm]).
NormalMove? legalMoveFromSan(Position position, String san) {
  final move = position.parseSan(san);
  return move is NormalMove ? kingCastlingForm(position, move) : null;
}
