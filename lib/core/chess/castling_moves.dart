import 'package:dartchess/dartchess.dart';

/// [move] with castling expressed as the king's own move (e1→g1 / e1→c1)
/// instead of dartchess's king-takes-rook normalization. Every other move is
/// returned untouched.
///
/// dartchess normalizes a castle to king-takes-rook (e1→h1) so that Chess960
/// has one unambiguous representation, and hands that form back from
/// [Position.parseSan] and [Position.normalizeMove]. It is the wrong form for
/// a UI: everything the app draws *about* a move — the quality badge, the
/// last-move highlight, a teaching arrow — is anchored on `to`, and the rook's
/// origin is precisely the square castling empties. The badge landed on bare
/// wood while the king wore nothing.
///
/// The king form is what standard UCI means, and dartchess accepts it
/// everywhere that matters: [Position.isLegal] tests both, and [Position.play]
/// and [Position.makeSan] detect a two-file king step. So the app normalizes
/// the other way, at the seams a move enters from, and every consumer is
/// correct by construction.
NormalMove kingCastlingForm(Position before, NormalMove move) {
  final side = _castlingSideOf(before, move);
  return side == null
      ? move
      : NormalMove(from: move.from, to: kingCastlesTo(before.turn, side));
}

/// Which side [move] castles to in [before], or null when it is not a castle.
///
/// Mirrors dartchess's own (private) detector: only the king can castle, and
/// it does so either by stepping two files or by moving onto its own rook —
/// the king-to-rook form, and the only legal form in Chess960.
CastlingSide? _castlingSideOf(Position before, NormalMove move) {
  if (before.board.kingOf(before.turn) != move.from) return null;
  final target = before.board.pieceAt(move.to);
  final onOwnRook =
      target != null && target.color == before.turn && target.role == Role.rook;
  final steps = move.to - move.from;
  if (steps.abs() != 2 && !onOwnRook) return null;
  return steps > 0 ? CastlingSide.king : CastlingSide.queen;
}
