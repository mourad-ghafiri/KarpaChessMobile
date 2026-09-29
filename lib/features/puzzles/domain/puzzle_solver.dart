import 'package:dartchess/dartchess.dart';

import '../../../core/chess/san_moves.dart';
import '../../../core/chess/tolerant_position.dart';

/// How a move offered to [PuzzleSolver] was judged.
enum SolveOutcome {
  /// On the solution line, and there is more line to play.
  correct,

  /// The last move of the line — the puzzle is solved.
  solved,

  /// Not the move. The position is unchanged; the caller shows the miss.
  wrong,
}

/// One puzzle, mid-solve.
///
/// The solve loop that lived inside the lesson player, lifted out so the
/// trainer and the academy cannot drift apart on what "solving a puzzle"
/// means: walk the solution line, accept only the authored move, and play
/// the opponent's forced reply from the odd indices.
///
/// Pure Dart — no Flutter, no timers, no sound. The screen owns the pauses
/// and the feedback; this owns what is true.
class PuzzleSolver {
  PuzzleSolver._(this._solution, this._position);

  /// Null when the puzzle is unusable — an unparseable FEN, an empty line,
  /// or a first move that is not legal in its own position. A trainer must
  /// never hand the reader a position they cannot solve.
  static PuzzleSolver? of({required String fen, required List<String> solution}) {
    if (solution.isEmpty) return null;
    final Position position;
    try {
      position = positionFromFen(fen);
    } on Object {
      return null;
    }
    if (legalMoveFromSan(position, solution.first) == null) return null;
    return PuzzleSolver._(List.unmodifiable(solution), position);
  }

  final List<String> _solution;

  Position _position;
  int _cursor = 0;
  int _misses = 0;
  NormalMove? _lastMove;

  /// The position on the board right now.
  Position get position => _position;

  /// The move that produced [position], for the board's last-move highlight.
  NormalMove? get lastMove => _lastMove;

  /// Wrong moves so far. Zero at the end means solved unaided.
  int get misses => _misses;
  bool get firstTry => _misses == 0;

  bool get isSolved => _cursor >= _solution.length;

  /// True while the line still owes an opponent reply — the caller pauses,
  /// then calls [playReply].
  bool get awaitsReply => !isSolved && _cursor.isOdd;

  /// Judges [move] against the line, advancing when it is right.
  SolveOutcome offer(NormalMove move) {
    if (isSolved) return SolveOutcome.solved;
    if (!acceptsAuthored(_position, move, _solution[_cursor])) {
      _misses++;
      return SolveOutcome.wrong;
    }
    _position = _position.play(move);
    _lastMove = move;
    _cursor++;
    return isSolved ? SolveOutcome.solved : SolveOutcome.correct;
  }

  /// Plays the opponent's scripted reply. Returns false when the authored
  /// line is corrupt at this point, which the caller should treat as solved
  /// rather than dead-ending the reader.
  bool playReply() {
    if (!awaitsReply) return false;
    final reply = legalMoveFromSan(_position, _solution[_cursor]);
    if (reply == null) return false;
    _position = _position.play(reply);
    _lastMove = reply;
    _cursor++;
    return true;
  }

  /// Plays the next authored move regardless of whose it is — the
  /// show-solution playout. Null when the line is done; a corrupt move ends
  /// the line rather than dead-ending the playout.
  NormalMove? advanceSolution() {
    if (isSolved) return null;
    final move = legalMoveFromSan(_position, _solution[_cursor]);
    if (move == null) {
      _cursor = _solution.length;
      return null;
    }
    _position = _position.play(move);
    _lastMove = move;
    _cursor++;
    return move;
  }
}
