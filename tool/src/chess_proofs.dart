import 'package:dartchess/dartchess.dart';

/// Exact, exhaustive answers about a position — the only kind worth having
/// when the app accepts exactly one line.
///
/// Everything here is a **proof**: a bounded, complete enumeration that either
/// settles the question or says it could not. "Is there a forced mate in five,
/// and is the key move unique" is decidable, and answering it by exhaustion is
/// strictly stronger than asking an engine, which reports *a* mate at *a*
/// depth rather than *every* mating first move.
///
/// **Opinions do not live here.** Whether one move is as good as another is
/// not decidable by enumeration, and this file used to answer it anyway with a
/// depth-4 negamax on material alone. That is now `tool/src/engine_screen.dart`,
/// which asks Stockfish — the same engine the app ships.

/// Legal moves, deduplicated to the king's own castling form so a castle is
/// counted once rather than twice.
///
/// `makeLegalMoves` offers both `e1g1` and `e1h1` for the same castle; a
/// "the opponent had only one legal reply" check that counted them separately
/// would call a forced position unforced.
List<NormalMove> legalMovesOf(Position position) {
  final out = <NormalMove>[];
  final seen = <String>{};
  for (final entry in position.legalMoves.entries) {
    for (final to in entry.value.squares) {
      final move = NormalMove(from: entry.key, to: to);
      final promotions = _promotionsFor(position, move);
      for (final promotion in promotions) {
        final full = NormalMove(from: move.from, to: move.to, promotion: promotion);
        if (seen.add(full.uci)) out.add(full);
      }
    }
  }
  return out;
}

/// A pawn reaching the back rank is four moves, not one — and a queening check
/// is a different move from a knight-promotion fork.
List<Role?> _promotionsFor(Position position, NormalMove move) {
  final piece = position.board.pieceAt(move.from);
  final promotes = piece?.role == Role.pawn &&
      (move.to.rank == Rank.first || move.to.rank == Rank.eighth);
  return promotes
      ? const [Role.queen, Role.rook, Role.bishop, Role.knight]
      : const [null];
}

/// How many plies of forced mate [position] has for the side to move.
///
/// "Forced" in the strict sense: the mover has SOME move such that EVERY
/// defence is mated. Depth is counted in plies and always odd — the mating
/// side moves first and last.
///
/// [budget] caps nodes so a badly-composed position reports nothing rather
/// than hanging. Puzzle lines are forcing, so the tree is tiny in practice.
///
/// **`exhausted` is not the same as "no mate".** When the budget runs out the
/// answer is *unknown*, and a caller that reads it as "none" turns a search
/// that gave up into a clean bill of health.
({int? plies, bool exhausted}) forcedMateIn(
  Position position, {
  int maxPlies = 7,
  int budget = 400000,
}) {
  for (var plies = 1; plies <= maxPlies; plies += 2) {
    final counter = _Budget(budget);
    if (_matesIn(position, plies, counter)) {
      return (plies: plies, exhausted: false);
    }
    if (counter.exhausted) return (plies: null, exhausted: true);
  }
  return (plies: null, exhausted: false);
}

/// Every move that forces mate in exactly [plies] — the uniqueness check.
///
/// **`exhausted` means [moves] may be SHORT.** The search stops the moment the
/// budget is gone, so a list of one proves uniqueness only when the search
/// actually finished. Reading a truncated list as "the key move is unique" is
/// precisely how a puzzle with two solutions passes a uniqueness check.
({List<NormalMove> moves, bool exhausted}) movesForcingMateIn(
  Position position,
  int plies, {
  int budget = 400000,
}) {
  final counter = _Budget(budget);
  final out = <NormalMove>[];
  for (final move in legalMovesOf(position)) {
    final after = position.playUnchecked(move);
    if (plies == 1) {
      if (after.isCheckmate) out.add(move);
    } else if (_defenderIsLost(after, plies - 1, counter)) {
      out.add(move);
    }
    if (counter.exhausted) break;
  }
  return (moves: out, exhausted: counter.exhausted);
}

/// Is the side to move mated within [plies], whatever it tries?
///
/// The mirror of [forcedMateIn], and the one to ask after the ATTACKER has
/// moved: `forcedMateIn` always answers for the side to move, so asking it
/// about the defender's turn asks whether the defender can mate.
bool isMatedWithin(Position position, int plies, {int budget = 400000}) =>
    _defenderIsLost(position, plies, _Budget(budget));

/// Can the side to move force mate within [plies]?
bool _matesIn(Position position, int plies, _Budget budget) {
  if (plies <= 0 || budget.spend()) return false;
  for (final move in legalMovesOf(position)) {
    final after = position.playUnchecked(move);
    if (after.isCheckmate) return true;
    if (plies >= 3 && _defenderIsLost(after, plies - 1, budget)) return true;
  }
  return false;
}

/// Is the side to move mated within [plies] against every defence?
bool _defenderIsLost(Position position, int plies, _Budget budget) {
  if (budget.spend()) return false;
  final defences = legalMovesOf(position);
  // Stalemate is not mate: an empty defence list here means the defender is
  // already mated (handled by the caller) or stalemated (not a win).
  if (defences.isEmpty) return false;
  for (final defence in defences) {
    final after = position.playUnchecked(defence);
    if (!_matesIn(after, plies - 1, budget)) return false;
  }
  return true;
}

class _Budget {
  _Budget(this._left);
  int _left;
  bool exhausted = false;

  /// Returns true when the budget is gone — callers then bail out.
  bool spend() {
    if (_left <= 0) {
      exhausted = true;
      return true;
    }
    _left--;
    return false;
  }
}

const _values = {
  Role.pawn: 1,
  Role.knight: 3,
  Role.bishop: 3,
  Role.rook: 5,
  Role.queen: 9,
  Role.king: 0,
};

/// Material balance in pawns from [side]'s point of view.
int materialFor(Position position, Side side) {
  var total = 0;
  for (final entry in _values.entries) {
    total += (position.board.piecesOf(side, entry.key).size -
            position.board.piecesOf(side.opposite, entry.key).size) *
        entry.value;
  }
  return total;
}

