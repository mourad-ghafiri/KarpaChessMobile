import 'package:dartchess/dartchess.dart';

/// Builds a [Chess] position from a FEN, tolerating the pedagogical setups
/// used by lessons/puzzles that strict validation rejects: single-king
/// teaching boards and "opposite check" compositions. dartchess's move
/// generation handles both correctly; only [Chess.fromSetup] refuses them.
Chess positionFromFen(String fen) {
  final setup = Setup.parseFen(fen);
  try {
    return Chess.fromSetup(setup, ignoreImpossibleCheck: true);
  } on PositionSetupException {
    return Chess(
      board: setup.board,
      turn: setup.turn,
      castles: Castles.fromSetup(setup),
      epSquare: setup.epSquare,
      halfmoves: setup.halfmoves,
      fullmoves: setup.fullmoves,
    );
  }
}
