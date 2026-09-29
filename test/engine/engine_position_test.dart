import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/engine_position.dart';

const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

Matcher get refused => throwsA(isA<EngineRejectedPosition>());

void main() {
  group('engineAcceptedPosition', () {
    test('accepts the start position and composed ones a game can reach', () {
      expect(engineAcceptedPosition(startFen).fen, startFen);
      // Two queens with seven pawns: one promotion, one missing pawn.
      expect(
          () => engineAcceptedPosition('k7/8/8/8/8/8/PPPPPPP1/KQQ5 w - - 0 1'),
          returnsNormally);
    });

    // Each of these makes Stockfish 19 print "CRITICAL ERROR" and exit.
    test('refuses a missing or an extra king', () {
      expect(() => engineAcceptedPosition('8/8/8/8/8/8/8/K7 w - - 0 1'), refused);
      expect(() => engineAcceptedPosition('k7/8/8/8/8/8/8/K5KK w - - 0 1'),
          refused);
    });

    test('refuses a pawn on a back rank', () {
      expect(() => engineAcceptedPosition('P6k/8/8/8/8/8/8/K7 w - - 0 1'),
          refused);
    });

    test('refuses the side not to move standing in check', () {
      // White to move, and White's queen already attacks Black's king.
      expect(() => engineAcceptedPosition('k7/8/8/8/8/8/8/K6Q w - - 0 1'),
          refused);
    });

    test('refuses more pawns or promoted pieces than a game can produce', () {
      // Nine white pawns.
      expect(() => engineAcceptedPosition('k7/8/8/8/8/P7/PPPPPPPP/K7 w - - 0 1'),
          refused);
      // Eight pawns and a third knight.
      expect(() => engineAcceptedPosition('k7/8/8/8/8/8/PPPPPPPP/KNNN4 w - - 0 1'),
          refused);
    });

    test('refuses crazyhouse pockets, promotion marks and unreadable text', () {
      expect(
          () => engineAcceptedPosition(
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[] w KQkq - 0 1'),
          refused);
      expect(() => engineAcceptedPosition('k7/8/8/8/8/8/8/K5Q~1 w - - 0 1'),
          refused);
      expect(() => engineAcceptedPosition('not a position'), refused);
    });
  });

  group('EnginePosition', () {
    test('sends the start position as a position command', () {
      final position = EnginePosition.of(startFen);
      expect(position.command, 'position fen $startFen');
      expect(position.sideToMove, 'w');
    });

    test("canonicalizes what dartchess reads more loosely than Stockfish", () {
      // A wrong-rank en passant square, `_` separators, surplus castling
      // letters, and a bare board: Stockfish exits on each as written.
      expect(
          EnginePosition.of(
                  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e4 0 1')
              .command,
          'position fen rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      expect(
          EnginePosition.of(
                  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR_w_KQkq_-_0_1')
              .command,
          'position fen $startFen');
      expect(
          EnginePosition.of(
                  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkqKQ - 0 1')
              .command,
          'position fen $startFen');
      expect(
          EnginePosition.of('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
              .command,
          'position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1');
    });

    test('appends the history, castling in the king-destination form', () {
      final position = EnginePosition.of(startFen, moves: const [
        'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'e1h1', //
      ]);
      expect(position.command,
          'position fen $startFen moves e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 e1g1');
      expect(position.sideToMove, 'b');
    });

    test('refuses a history with an illegal or malformed move', () {
      expect(() => EnginePosition.of(startFen, moves: const ['e2e5']), refused);
      expect(() => EnginePosition.of(startFen, moves: const ['e2e4', 'e2e4']),
          refused);
      expect(() => EnginePosition.of(startFen, moves: const ['Q@e4']), refused);
      expect(() => EnginePosition.of(startFen, moves: const ['e2']), refused);
    });
  });
}
