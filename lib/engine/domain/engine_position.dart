import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import '../../core/chess/castling_moves.dart';
import 'engine_models.dart';

/// A position Stockfish 19 will accept, and the one way a position reaches
/// the engine.
///
/// Stockfish 19 validates every `position` command, and on anything it
/// refuses it prints `info string CRITICAL ERROR` and calls `std::exit(1)`
/// (`uci.cpp`, `terminate_on_critical_error`). The engine runs inside the
/// app's process, so that exit closes the app: a Studio import whose `[FEN]`
/// had one king, or a hint asked for while in check, used to do exactly that.
///
/// So nothing is sent that has not passed here:
/// - the FEN is re-serialized by dartchess from a validated [Chess] — never
///   the caller's string, which dartchess reads more loosely than Stockfish
///   does (a wrong-rank en-passant square, `_` separators, surplus castling
///   letters, a board with no other fields);
/// - every move of the history is legal where it is played, and is sent in
///   the king-destination castling form standard UCI means (`e1g1`), since
///   Stockfish also exits on an illegal move in `position … moves`
///   (`engine.cpp`, `Engine::set_position`).
///
/// This is the deliberate exception to reading FENs with the tolerant
/// `positionFromFen`: lessons may teach on positions no game can reach, the
/// engine may not see them.
class EnginePosition {
  const EnginePosition._({required this.command, required this.sideToMove});

  /// [fen], followed by [moves] (UCI, oldest first) when a game history
  /// matters — Stockfish uses it to see repetitions.
  ///
  /// Throws [EngineRejectedPosition] when Stockfish would refuse either.
  factory EnginePosition.of(String fen, {List<String> moves = const []}) {
    final start = engineAcceptedPosition(fen);
    Position current = start;
    final played = <String>[];
    for (final token in moves) {
      final parsed =
          token.length == 4 || token.length == 5 ? Move.parse(token) : null;
      if (parsed is! NormalMove || !current.isLegal(parsed)) {
        throw EngineRejectedPosition('illegal move "$token" in the history');
      }
      final move = kingCastlingForm(current, parsed);
      played.add(move.uci);
      current = current.play(move);
    }
    return EnginePosition._(
      command: played.isEmpty
          ? 'position fen ${start.fen}'
          : 'position fen ${start.fen} moves ${played.join(' ')}',
      sideToMove: current.turn == Side.white ? 'w' : 'b',
    );
  }

  /// The complete UCI `position` command.
  final String command;

  /// 'w' or 'b': the side to move once the history is played — the side
  /// Stockfish scores from.
  final String sideToMove;
}

/// [fen] as a position Stockfish 19 accepts, or [EngineRejectedPosition].
///
/// Mirrors `Position::set` in Stockfish's `position.cpp`: exactly one king a
/// side, no pawn on a back rank, the side not to move not in check (all three
/// are dartchess's own [Position.validate]; Stockfish has no impossible-check
/// rule, hence [Chess.fromSetup]'s `ignoreImpossibleCheck`), at most eight
/// pawns a side, and no more promoted pieces than missing pawns. Crazyhouse
/// pockets and `~` promotion marks survive dartchess's re-serialization, and
/// Stockfish reads neither.
Chess engineAcceptedPosition(String fen) {
  final Setup setup;
  try {
    setup = Setup.parseFen(fen.trim());
  } on Object {
    throw EngineRejectedPosition('unreadable FEN "$fen"');
  }
  if (setup.pockets != null) {
    throw const EngineRejectedPosition('the FEN carries pockets');
  }
  if (setup.board.promoted.isNotEmpty) {
    throw const EngineRejectedPosition('the FEN marks promoted pieces');
  }
  final Chess position;
  try {
    position = Chess.fromSetup(setup, ignoreImpossibleCheck: true);
  } on PositionSetupException catch (e) {
    throw EngineRejectedPosition('illegal position (${e.cause.name})');
  }
  for (final side in Side.values) {
    int count(Role role) => position.board.piecesOf(side, role).size;
    final pawns = count(Role.pawn);
    if (pawns > 8) {
      throw EngineRejectedPosition('${side.name} has $pawns pawns');
    }
    final promoted = math.max(count(Role.knight) - 2, 0) +
        math.max(count(Role.bishop) - 2, 0) +
        math.max(count(Role.rook) - 2, 0) +
        math.max(count(Role.queen) - 1, 0);
    if (promoted > 8 - pawns) {
      throw EngineRejectedPosition(
          '${side.name} has more pieces than promotions can explain');
    }
  }
  return position;
}
