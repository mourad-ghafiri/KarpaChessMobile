import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/commentator/domain/move_tree.dart';

const _annotatedPgn = '''
[Event "Test"]
[White "Alice"]
[Black "Bob"]
[Result "*"]

1. e4 {[%clk 0:05:00]} e5 {[%clk 0:04:58]} 2. Nf3 (2. f4 {gambit!} exf4)
2... Nc6 {[%clk 0:04:40]} *
''';

void main() {
  group('MoveTree.fromPgn', () {
    test('builds mainline, headers and SANs from an annotated PGN', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      expect(tree.headers['White'], 'Alice');
      expect(tree.headers['Black'], 'Bob');

      final main = tree.mainline();
      // root + e4 e5 Nf3 Nc6
      expect(main.map((n) => n.san).toList(), [null, 'e4', 'e5', 'Nf3', 'Nc6']);
      expect(main[1].mover, 'w');
      expect(main[2].mover, 'b');
      expect(tree.plyOf(main.last), 4);
      expect(tree.moveNumberOf(main[3]), 2);
    });

    test('variations hang off the branch point, first child is mainline', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final e5 = tree.mainline()[2];
      expect(e5.children, hasLength(2));
      expect(e5.children[0].san, 'Nf3');
      expect(e5.children[1].san, 'f4');
      expect(e5.children[1].comments, ['gambit!']);
      expect(e5.children[1].children.single.san, 'exf4');
      expect(tree.onMainline(e5.children[0]), isTrue);
      expect(tree.onMainline(e5.children[1]), isFalse);
      expect(tree.onMainline(e5.children[1].children.single), isFalse);
    });

    test('parses [%clk] comments into Durations', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final main = tree.mainline();
      expect(main[1].clk, const Duration(minutes: 5));
      expect(main[2].clk, const Duration(minutes: 4, seconds: 58));
      expect(main[3].clk, isNull);
      expect(main[4].clk, const Duration(minutes: 4, seconds: 40));
    });

    test('loads a bare move list without headers', () {
      final tree = MoveTree.fromPgn('e4 e5 Nf3');
      expect(tree.mainline().map((n) => n.san).toList(),
          [null, 'e4', 'e5', 'Nf3']);
    });

    test('rejects empty and unparseable input', () {
      expect(() => MoveTree.fromPgn('   '), throwsFormatException);
      expect(() => MoveTree.fromPgn('hello world'), throwsFormatException);
      expect(() => MoveTree.fromPgn('1. e4 e5 2. Ke2 Kxe2'),
          throwsFormatException);
    });

    /// A game set up on [fen], whose one [move] would be legal from it — so a
    /// rejection can only be the position's fault.
    String setUp(String fen, String move) =>
        '[SetUp "1"]\n[FEN "$fen"]\n\n1. $move *';

    test('starts from a legal [FEN] tag, re-serialized', () {
      final tree =
          MoveTree.fromPgn(setUp('4k3/8/8/8/8/8/4P3/4K3 w - - 0 1', 'e4'));
      expect(tree.root.positionFen, '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1');
      expect(tree.mainline().last.san, 'e4');
    });

    // Stockfish 19 exits the app's process on each of these, and the Studio
    // analyses what it loads — so the import turns them away instead.
    test('rejects a [FEN] tag Stockfish would refuse', () {
      for (final (fen, move) in [
        ('8/8/8/8/8/8/8/K7 w - - 0 1', 'Kb1'), // one king
        ('k7/8/8/8/8/8/8/K6Q w - - 0 1', 'Qh2'), // side not to move in check
        ('k7/8/8/8/8/P7/PPPPPPPP/K7 w - - 0 1', 'a4'), // nine pawns
      ]) {
        expect(() => MoveTree.fromPgn(setUp(fen, move)), throwsFormatException,
            reason: fen);
      }
    });

    test('reports a malformed [FEN] tag as a FormatException too', () {
      expect(() => MoveTree.fromPgn(setUp('not a position', 'e4')),
          throwsFormatException);
    });
  });

  group('clock lookup', () {
    test('walks back to each side\'s most recent clk', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final last = tree.mainline().last; // Nc6 (black)
      // White's most recent clk is on e4 (Nf3 carries none).
      expect(tree.clockFor(last, 'w'), const Duration(minutes: 5));
      expect(tree.clockFor(last, 'b'),
          const Duration(minutes: 4, seconds: 40));
      // At the root there is no clock info yet.
      expect(tree.clockFor(tree.root, 'w'), isNull);
    });
  });

  group('forking', () {
    test('addChild creates a variation when a mainline child exists', () {
      final tree = MoveTree.fromPgn('1. e4 e5 2. Nf3 Nc6 *');
      final e5 = tree.mainline()[2];
      final position = Chess.fromSetup(Setup.parseFen(e5.positionFen));
      final move = NormalMove.fromUci('f1c4'); // 2. Bc4 — a new idea
      final (next, san) = position.makeSan(move);
      expect(tree.childBySan(e5, san), isNull);

      final node = tree.addChild(e5,
          move: move, san: san, positionFen: next.fen, mover: 'w');
      expect(e5.children, hasLength(2));
      expect(e5.children.first.san, 'Nf3'); // mainline untouched
      expect(e5.children[1], same(node));
      expect(tree.onMainline(node), isFalse);
      expect(tree.nodeById(node.id), same(node));
    });

    test('childBySan matches ignoring check/mate suffixes', () {
      final tree = MoveTree.fromPgn('1. e4 e5 2. Nf3 Nc6 *');
      final e5 = tree.mainline()[2];
      expect(tree.childBySan(e5, 'Nf3'), same(e5.children.first));
      expect(tree.childBySan(e5, 'Nf3+'), same(e5.children.first));
      expect(tree.childBySan(e5, 'Bc4'), isNull);
    });

    test('extends the tip of a line as its mainline continuation', () {
      final tree = MoveTree.fromPgn('1. e4 *');
      final tip = tree.mainline().last;
      final position = Chess.fromSetup(Setup.parseFen(tip.positionFen));
      final move = NormalMove.fromUci('e7e5');
      final (next, san) = position.makeSan(move);
      final node = tree.addChild(tip,
          move: move, san: san, positionFen: next.fen, mover: 'b');
      expect(tip.children.single, same(node));
      expect(tree.onMainline(node), isTrue);
    });
  });

  group('mainline ancestor', () {
    test('returns the branch point for off-mainline nodes', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final e5 = tree.mainline()[2];
      final f4 = e5.children[1];
      final exf4 = f4.children.single;
      expect(tree.mainlineAncestor(exf4), same(e5));
      expect(tree.mainlineAncestor(f4), same(e5));
      // Already on the mainline: unchanged.
      expect(tree.mainlineAncestor(e5), same(e5));
    });
  });

  group('lineTo', () {
    test('is the path from the start to a node, never past it', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final main = tree.mainline();
      expect(tree.lineTo(main[3]).map((n) => n.san), ['e4', 'e5', 'Nf3']);
      expect(tree.lineTo(tree.root), isEmpty);
    });

    test('inside a side line: the mainline to the branch, then the branch',
        () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final exf4 = tree.mainline()[2].children[1].children.single;
      expect(
        tree.lineTo(exf4).map((n) => n.san),
        ['e4', 'e5', 'f4', 'exf4'],
      );
    });
  });

  group('node path serialization', () {
    test('pathIndices/nodeAtPath round-trip, including variations', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      final e5 = tree.mainline()[2];
      final exf4 = e5.children[1].children.single;
      expect(tree.pathIndices(tree.root), isEmpty);
      expect(tree.pathIndices(exf4), [0, 0, 1, 0]);
      expect(tree.nodeAtPath([0, 0, 1, 0]), same(exf4));
      expect(tree.nodeAtPath([]), same(tree.root));
    });

    test('nodeAtPath clamps out-of-range paths', () {
      final tree = MoveTree.fromPgn('1. e4 e5 *');
      // A stale, too-deep path stops at the last reachable node.
      final node = tree.nodeAtPath([0, 0, 4, 2]);
      expect(node.san, 'e5');
    });
  });

  group('toPgn round-trip', () {
    test('serializes variations, comments and clocks re-parseably', () {
      final tree = MoveTree.fromPgn(_annotatedPgn);
      // Simulate a user fork: 3. Bc4 alternative gets added live.
      final nf3 = tree.mainline()[3];
      final position = Chess.fromSetup(Setup.parseFen(nf3.positionFen));
      final move = NormalMove.fromUci('g8f6');
      final (next, san) = position.makeSan(move);
      tree.addChild(nf3,
          move: move, san: san, positionFen: next.fen, mover: 'b');

      final reparsed = MoveTree.fromPgn(tree.toPgn());
      expect(reparsed.headers['White'], 'Alice');
      expect(reparsed.mainline().map((n) => n.san).toList(),
          [null, 'e4', 'e5', 'Nf3', 'Nc6']);
      final e5 = reparsed.mainline()[2];
      expect(e5.children.map((c) => c.san).toList(), ['Nf3', 'f4']);
      expect(e5.children[1].comments, ['gambit!']);
      // Clocks survive.
      expect(reparsed.mainline()[1].clk, const Duration(minutes: 5));
      // The live fork survives too.
      final reNf3 = reparsed.mainline()[3];
      expect(reNf3.children.map((c) => c.san).toList(), ['Nc6', 'Nf6']);
    });
  });
}
