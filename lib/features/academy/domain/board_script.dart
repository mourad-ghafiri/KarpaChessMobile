import 'package:dartchess/dartchess.dart';

import '../../../core/chess/san_moves.dart';

/// One step of a [MoveSequence]: the position to show and the move that just
/// landed (drawn as an arrow and a last-move highlight).
class ScriptFrame {
  const ScriptFrame({required this.position, this.move});

  final Position position;
  final NormalMove? move;

  @override
  bool operator ==(Object other) =>
      other is ScriptFrame && other.position == position && other.move == move;

  @override
  int get hashCode => Object.hash(position, move);
}

/// What a teach step asks the board to say.
///
/// `{{san}}` chips carry two different authorial intents, and the board has to
/// speak them differently:
///
///  * a **line** — "watch these moves played in order" — becomes a
///    [MoveSequence] and animates;
///  * a **menu** — "here are the squares this piece can reach" — becomes a
///    [MoveMenu] and draws every option at once on the one position the prose
///    is describing.
///
/// The intent is *classified*, never guessed while walking the moves. The rule
/// is total and deterministic: two or more chips that are all legal from the
/// step's own position can only be alternatives, because a real line alternates
/// sides — after White's `e4`, Black's `d5` is illegal from that same position.
///
/// The predecessor of this class chained greedily and latched: a menu's first
/// chip chained, the rest could not (it was now the opponent's turn), and the
/// leftovers were drawn as arrows over a board that had already moved. That
/// produced knight lessons showing seven arrows fanning out of a square the
/// knight had just left.
sealed class BoardScript {
  const BoardScript({required this.start});

  /// The position the step is authored against.
  final Position start;

  /// Classifies [markdown]'s chips against [start].
  factory BoardScript.of(Position start, String markdown) {
    final tokens = extractSanTokens(markdown);

    if (tokens.length >= 2) {
      final menu = <NormalMove>[];
      for (final san in tokens) {
        final move = legalMoveFromSan(start, san);
        if (move == null) {
          menu.clear();
          break;
        }
        menu.add(move);
      }
      if (menu.isNotEmpty) return MoveMenu(start: start, moves: menu);
    }

    // A line. Chips that do not chain are dropped rather than drawn against a
    // position they were never validated for; `tool/lint_lessons.dart` rule
    // L01 rejects such a step upstream, so this is a safety net, not a
    // feature.
    final frames = <ScriptFrame>[ScriptFrame(position: start)];
    var position = start;
    for (final san in tokens) {
      final move = legalMoveFromSan(position, san);
      if (move == null) break;
      position = position.play(move);
      frames.add(ScriptFrame(position: position, move: move));
    }
    return MoveSequence(start: start, frames: frames);
  }
}

/// Moves played one after another; the board animates through [frames].
final class MoveSequence extends BoardScript {
  const MoveSequence({required super.start, required this.frames});

  /// Always begins with the bare [start] position carrying no move.
  final List<ScriptFrame> frames;

  bool get hasMotion => frames.length > 1;
}

/// Alternatives from one position; every move is drawn at once on [start].
final class MoveMenu extends BoardScript {
  const MoveMenu({required super.start, required this.moves});

  final List<NormalMove> moves;
}
