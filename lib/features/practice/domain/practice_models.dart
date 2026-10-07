import 'package:dartchess/dartchess.dart';

import '../../../engine/domain/engine_models.dart';

/// One committed move with everything the UI/review need to describe it.
class PlayedMove {
  const PlayedMove({
    required this.move,
    required this.san,
    required this.fenBefore,
    required this.fenAfter,
    required this.moverColor,
    required this.moverRole,
    this.captured,
    required this.isCastle,
    required this.isPromotion,
    required this.givesCheck,
  });

  /// Describes [move] played in [position]. The ONE place a ply is derived,
  /// shared by live play and by replaying a restored game — everything here
  /// except the move itself is derived, so two constructions could otherwise
  /// disagree about the same move.
  ///
  /// Returns null when the move is not legal in [position].
  static (PlayedMove, Chess)? build(Chess position, NormalMove move) {
    if (!position.isLegal(move)) return null;
    final moverColor = position.turn == Side.white ? 'w' : 'b';
    final moverRole = position.board.pieceAt(move.from)?.role ?? Role.pawn;
    final captured = _capturedRole(position, move);
    final (next, san) = position.makeSan(move);
    final after = next as Chess;
    return (
      PlayedMove(
        move: move,
        san: san,
        fenBefore: position.fen,
        fenAfter: after.fen,
        moverColor: moverColor,
        moverRole: moverRole,
        captured: captured,
        isCastle: san.startsWith('O-O'),
        isPromotion: move.promotion != null,
        givesCheck: after.isCheck,
      ),
      after,
    );
  }

  static Role? _capturedRole(Chess position, NormalMove move) {
    final direct = position.board.pieceAt(move.to);
    if (direct != null && direct.color != position.turn) return direct.role;
    final mover = position.board.pieceAt(move.from);
    if (mover?.role == Role.pawn && move.to == position.epSquare) {
      return Role.pawn;
    }
    return null;
  }

  final NormalMove move;
  final String san;
  final String fenBefore;
  final String fenAfter;

  /// 'w' | 'b'.
  final String moverColor;

  /// Role of the piece that moved.
  final Role moverRole;

  /// Role of the captured piece, if any.
  final Role? captured;
  final bool isCastle;
  final bool isPromotion;
  final bool givesCheck;
}

/// Replays [uciMoves] from the initial position.
///
/// A saved game stores its line as UCI and nothing else: SAN, the captured
/// role, the check flag and both FENs are all derivable, and a file that
/// stored them could come back disagreeing with its own moves. Stops at the
/// first illegal move rather than throwing, so a corrupt tail costs the tail
/// and not the game.
(Chess, List<PlayedMove>) replayMoves(List<String> uciMoves) {
  var position = Chess.initial;
  final moves = <PlayedMove>[];
  for (final uci in uciMoves) {
    final NormalMove move;
    try {
      move = NormalMove.fromUci(uci);
    } on FormatException {
      break;
    }
    final built = PlayedMove.build(position, move);
    if (built == null) break;
    moves.add(built.$1);
    position = built.$2;
  }
  return (position, moves);
}

enum GameResultKind {
  checkmate,
  stalemate,
  draw50,
  drawMaterial,
  repetition,
  timeout,

  /// The user conceded; [GameResult.winner] is Stockfish's side.
  resigned,
}

class GameResult {
  const GameResult(this.kind, {this.winner});

  final GameResultKind kind;

  /// 'w' | 'b' | null for draws.
  final String? winner;
}

/// Evaluates the terminal status of the game standing at [position] after
/// [moves]: checkmate / stalemate / 50-move / insufficient material /
/// threefold repetition.
GameResult? terminalResult(Position position, List<PlayedMove> moves) {
  if (position.isCheckmate) {
    return GameResult(
      GameResultKind.checkmate,
      winner: position.turn == Side.white ? 'b' : 'w',
    );
  }
  if (position.isStalemate) return const GameResult(GameResultKind.stalemate);
  if (position.halfmoves >= 100) return const GameResult(GameResultKind.draw50);
  if (position.isInsufficientMaterial) {
    return const GameResult(GameResultKind.drawMaterial);
  }
  if (isThreefold(position, moves)) {
    return const GameResult(GameResultKind.repetition);
  }
  return null;
}

/// Whether [position], reached by [moves], has now stood on the board three
/// times — drawn at once, as online play does, rather than on a claim.
///
/// "The same position" is FIDE's (Art. 9.2.2): the same player to move, the
/// same pieces on the same squares, the same castling rights and en passant
/// possibilities. The first four FEN fields say exactly that, because
/// dartchess writes an en passant square only when a capture there is legal.
/// A capture or a pawn move can never be undone, and both reset the halfmove
/// clock, so only the last `halfmoves` plies can hold a repetition.
bool isThreefold(Position position, List<PlayedMove> moves) {
  final key = _repetitionKey(position.fen);
  final reach =
      position.halfmoves < moves.length ? position.halfmoves : moves.length;
  var seen = 1;
  for (var i = moves.length - 1; i >= moves.length - reach; i--) {
    if (_repetitionKey(moves[i].fenBefore) == key && ++seen >= 3) return true;
  }
  return false;
}

String _repetitionKey(String fen) => fen.split(' ').take(4).join(' ');

/// The pause before Stockfish answers at [strength], on top of the reply
/// delay. A handicapped reply now searches only to the depth where it picks
/// its move and comes back in milliseconds; this keeps the rhythm the old
/// 80 / 150 / 400 ms searches gave each level — as a timer, which costs no
/// CPU. Full strength still thinks for real.
Duration replyPace(EngineStrength strength) => switch (strength) {
      EngineStrength.beginner => const Duration(milliseconds: 80),
      EngineStrength.casual => const Duration(milliseconds: 150),
      EngineStrength.club => const Duration(milliseconds: 400),
      EngineStrength.master => Duration.zero,
    };

