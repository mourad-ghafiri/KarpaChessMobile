import 'package:dartchess/dartchess.dart' show NormalMove, Square;
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/puzzles/domain/puzzle_solver.dart';

const _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _e4 = NormalMove(from: Square.e2, to: Square.e4);
const _d4 = NormalMove(from: Square.d2, to: Square.d4);
const _nf3 = NormalMove(from: Square.g1, to: Square.f3);

void main() {
  group('PuzzleSolver.of', () {
    test('rejects an empty line, a bad FEN and an illegal first move', () {
      expect(PuzzleSolver.of(fen: _startFen, solution: const []), isNull);
      expect(
        PuzzleSolver.of(fen: 'not a fen', solution: const ['e4']),
        isNull,
      );
      expect(
        PuzzleSolver.of(fen: _startFen, solution: const ['Qxf7#']),
        isNull,
      );
    });
  });

  group('offer / playReply', () {
    test('walks the line: wrong counts a miss, correct advances, end solves',
        () {
      final solver = PuzzleSolver.of(
        fen: _startFen,
        solution: const ['e4', 'e5', 'Nf3'],
      )!;
      expect(solver.offer(_d4), SolveOutcome.wrong);
      expect(solver.misses, 1);
      expect(solver.firstTry, isFalse);

      expect(solver.offer(_e4), SolveOutcome.correct);
      expect(solver.awaitsReply, isTrue);
      expect(solver.playReply(), isTrue);
      expect(solver.awaitsReply, isFalse);

      expect(solver.offer(_nf3), SolveOutcome.solved);
      expect(solver.isSolved, isTrue);
    });
  });

  group('accept any mate', () {
    const twoMates = '6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1';

    test('a different mate solves a line that ends in mate', () {
      final solver = PuzzleSolver.of(fen: twoMates, solution: const ['Ra8#'])!;
      expect(
        solver.offer(const NormalMove(from: Square.b1, to: Square.b8)),
        SolveOutcome.solved,
      );
      expect(solver.firstTry, isTrue);
      expect(solver.position.isCheckmate, isTrue);
    });

    test('a move short of mate is still wrong', () {
      final solver = PuzzleSolver.of(fen: twoMates, solution: const ['Ra8#'])!;
      expect(
        solver.offer(const NormalMove(from: Square.a1, to: Square.a7)),
        SolveOutcome.wrong,
      );
      expect(solver.misses, 1);
    });
  });

  group('advanceSolution', () {
    test('plays the whole authored line regardless of side', () {
      final solver = PuzzleSolver.of(
        fen: _startFen,
        solution: const ['e4', 'e5', 'Nf3'],
      )!;
      expect(solver.advanceSolution(), _e4);
      expect(solver.advanceSolution(), isNotNull); // ...e5
      expect(solver.advanceSolution(), _nf3);
      expect(solver.isSolved, isTrue);
      expect(solver.advanceSolution(), isNull);
    });

    test('a corrupt move ends the line instead of dead-ending', () {
      final solver = PuzzleSolver.of(
        fen: _startFen,
        solution: const ['e4', 'Qxa8'],
      )!;
      expect(solver.advanceSolution(), _e4);
      expect(solver.advanceSolution(), isNull);
      expect(solver.isSolved, isTrue);
    });

    test('resumes from wherever the reader got to', () {
      final solver = PuzzleSolver.of(
        fen: _startFen,
        solution: const ['e4', 'e5', 'Nf3'],
      )!;
      expect(solver.offer(_e4), SolveOutcome.correct);
      expect(solver.playReply(), isTrue);
      expect(solver.advanceSolution(), _nf3);
      expect(solver.isSolved, isTrue);
    });
  });
}
