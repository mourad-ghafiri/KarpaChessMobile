import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/coach/domain/position_features.dart';

/// Stub translate: returns the key plus sorted params inline, e.g.
/// 'coach.builtin.kingNote.activeOn{square:a1}'.
String stubT(String key, [Map<String, Object?>? params]) {
  if (params == null || params.isEmpty) return key;
  final entries = params.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return '$key{${entries.map((e) => '${e.key}:${e.value}').join(',')}}';
}

const startpos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  group('ParsedPosition.fromFen', () {
    test('parses the starting position', () {
      final pos = ParsedPosition.fromFen(startpos);
      expect(pos.turn, 'w');
      expect(pos.fullmove, 1);
      expect(pos.halfmove, 0);
      expect(pos.material['w']!['p'], 8);
      expect(pos.material['b']!['q'], 1);
      expect(pos.kingPos['w'], (r: 7, c: 4));
      expect(pos.kingPos['b'], (r: 0, c: 4));
      expect(pos.board[7 * 8 + 4]!.piece, 'k');
      expect(pos.board[7 * 8 + 4]!.square, 'e1');
    });

    test('parses turn and counters', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/8/8/8/4K3 b - - 13 42');
      expect(pos.turn, 'b');
      expect(pos.halfmove, 13);
      expect(pos.fullmove, 42);
    });

    test('degrades to an empty board on invalid FEN', () {
      final pos = ParsedPosition.fromFen('not a fen');
      expect(pos.turn, 'w');
      expect(pos.pieces['w'], isEmpty);
      expect(pos.kingPos['w'], isNull);
      expect(materialReport(pos).whitePoints, 0);
    });
  });

  group('materialReport', () {
    test('startpos is balanced at 39 points and 7 non-pawn pieces', () {
      final mr = materialReport(ParsedPosition.fromFen(startpos));
      expect(mr.whitePoints, 39);
      expect(mr.blackPoints, 39);
      expect(mr.diff, 0);
      expect(mr.nonPawnWhite, 7);
      expect(mr.nonPawnBlack, 7);
    });

    test('counts a material edge', () {
      // White up a rook.
      final mr = materialReport(
          ParsedPosition.fromFen('4k3/8/8/8/8/8/8/R3K3 w - - 0 1'));
      expect(mr.diff, 5);
    });
  });

  group('phaseKey', () {
    test('startpos with few moves is the opening', () {
      final pos = ParsedPosition.fromFen(startpos);
      expect(phaseKey(pos, 0), 'opening');
      expect(phaseKey(pos, 11), 'opening');
    });

    test('move 12 leaves the opening even with full material', () {
      final pos = ParsedPosition.fromFen(startpos);
      expect(phaseKey(pos, 12), 'middlegame');
    });

    test('low material without queens is an endgame', () {
      final pos = ParsedPosition.fromFen('8/8/8/4k3/8/8/8/4K3 w - - 0 1');
      expect(phaseKey(pos, 60), 'endgame');
    });

    test('queens alone (<=8 non-pawn) still count as an endgame', () {
      final pos =
          ParsedPosition.fromFen('3qk3/8/8/8/8/8/8/3QK3 w - - 0 1');
      expect(phaseKey(pos, 30), 'endgame');
    });

    test('ten non-pawn pieces early on is a middlegame, not an opening', () {
      // 5 non-pawn pieces per side: below the 12 needed for "opening".
      final pos =
          ParsedPosition.fromFen('rnbqkb2/8/8/8/8/8/8/RNBQKB2 w - - 0 1');
      expect(phaseKey(pos, 0), 'middlegame');
      expect(phaseKey(pos, 20), 'middlegame');
    });
  });

  group('kingSafety', () {
    test('startpos: centered king with full shield is safe', () {
      final pos = ParsedPosition.fromFen(startpos);
      final ks = kingSafety(pos, 'w', 'opening', stubT);
      expect(ks.score, 'safe');
      expect(ks.center, isTrue);
      expect(ks.castled, isFalse);
      expect(ks.shieldCount, 3);
      expect(ks.notes, isEmpty);
    });

    test('castled king with full pawn shield gets the fullShield note', () {
      final pos = ParsedPosition.fromFen(
          'rnbq1rk1/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1RK1 w - - 4 5');
      final ks = kingSafety(pos, 'w', 'opening', stubT);
      expect(ks.score, 'safe');
      expect(ks.castled, isTrue);
      expect(ks.shieldCount, 3);
      expect(ks.notes, ['coach.builtin.kingNote.fullShield']);
    });

    test('castled king with a thin shield is exposed', () {
      final pos = ParsedPosition.fromFen(
          'rnbq1rk1/pppppppp/8/8/8/8/7P/6K1 w - - 0 5');
      final ks = kingSafety(pos, 'w', 'middlegame', stubT);
      expect(ks.score, 'exposed');
      expect(ks.shieldCount, 1);
      expect(ks.notes, ['coach.builtin.kingNote.thinShield{count:1}']);
    });

    test('enemy heavy piece on an OPEN king file means danger', () {
      final pos =
          ParsedPosition.fromFen('6r1/8/8/k7/8/8/7P/6K1 w - - 0 30');
      final ks = kingSafety(pos, 'w', 'middlegame', stubT);
      expect(ks.score, 'danger');
      expect(ks.notes, contains('coach.builtin.kingNote.enemyHeavy'));
    });

    test('a blocked file is not danger', () {
      // This case used to read `danger`: the check scanned the whole file and
      // ignored blockers, so a rook stopped dead by White's own g2 pawn
      // "endangered" a castled king. `danger` is the loudest verdict the
      // coach gives, and it was firing on the commonest middlegame shape
      // there is.
      final pos =
          ParsedPosition.fromFen('6r1/8/8/k7/8/8/6PP/6K1 w - - 0 30');
      expect(kingSafety(pos, 'w', 'middlegame', stubT).score, 'safe');

      // And the audit's own example: a rook behind its own pawns.
      final behind =
          ParsedPosition.fromFen('6r1/6p1/6p1/k7/8/8/6PP/6K1 w - - 0 30');
      expect(kingSafety(behind, 'w', 'middlegame', stubT).score, 'safe');
    });

    test('king still centered after move 8 is exposed', () {
      final pos = ParsedPosition.fromFen(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 10');
      final ks = kingSafety(pos, 'w', 'middlegame', stubT);
      expect(ks.score, 'exposed');
      expect(ks.notes, ['coach.builtin.kingNote.centerAfter8']);
    });

    test('wandering king is exposed', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/8/8/3K4/8 w - - 0 6');
      final ks = kingSafety(pos, 'w', 'middlegame', stubT);
      expect(ks.score, 'exposed');
      expect(ks.notes, ['coach.builtin.kingNote.wanderingOn{square:d2}']);
    });

    test('endgame: corner king shelters, centered king waits, other active',
        () {
      final corner =
          ParsedPosition.fromFen('6k1/8/8/8/8/8/8/6K1 w - - 0 50');
      expect(kingSafety(corner, 'w', 'endgame', stubT).score, 'shelter');
      expect(kingSafety(corner, 'w', 'endgame', stubT).notes,
          ['coach.builtin.kingNote.tuckedCorner']);

      final center =
          ParsedPosition.fromFen('4k3/8/8/8/8/8/8/4K3 w - - 0 50');
      expect(kingSafety(center, 'w', 'endgame', stubT).score, 'waiting');

      final active =
          ParsedPosition.fromFen('k7/8/8/4K3/8/8/8/8 w - - 0 50');
      final ks = kingSafety(active, 'w', 'endgame', stubT);
      expect(ks.score, 'active');
      expect(ks.notes, ['coach.builtin.kingNote.activeOn{square:e5}']);
    });

    test('missing king yields unknown', () {
      final pos = ParsedPosition.fromFen('not a fen');
      expect(kingSafety(pos, 'w', 'middlegame', stubT).score, 'unknown');
    });
  });

  group('pawnStructure', () {
    test('startpos is clean', () {
      final ps = pawnStructure(ParsedPosition.fromFen(startpos), 'w');
      expect(ps.count, 8);
      expect(ps.isolated, isEmpty);
      expect(ps.doubled, isEmpty);
      expect(ps.passed, isEmpty);
    });

    test('lone pawn is isolated and passed', () {
      final ps = pawnStructure(
          ParsedPosition.fromFen('k7/8/8/8/3P4/8/8/K7 w - - 0 1'), 'w');
      expect(ps.isolated, ['d4']);
      expect(ps.doubled, isEmpty);
      expect(ps.passed, ['d4']);
    });

    test('doubled pawns report the file once; a blocker kills passed', () {
      final pos =
          ParsedPosition.fromFen('k7/3p4/8/8/3P4/3P4/8/K7 w - - 0 1');
      final psW = pawnStructure(pos, 'w');
      expect(psW.count, 2);
      expect(psW.isolated, ['d4', 'd3']);
      expect(psW.doubled, ['d']);
      expect(psW.passed, isEmpty);

      final psB = pawnStructure(pos, 'b');
      expect(psB.isolated, ['d7']);
      expect(psB.doubled, isEmpty);
      expect(psB.passed, isEmpty);
    });

    test('pawns two files apart are passed for both sides', () {
      final pos =
          ParsedPosition.fromFen('k7/1p6/8/8/8/3P4/8/K7 w - - 0 1');
      expect(pawnStructure(pos, 'w').passed, ['d3']);
      expect(pawnStructure(pos, 'b').passed, ['b7']);
    });

    test('adjacent enemy pawn ahead blocks passage', () {
      // White pawn d4, black pawn e5: e5 is ahead of d4 on an adjacent file.
      final pos =
          ParsedPosition.fromFen('k7/8/8/4p3/3P4/8/8/K7 w - - 0 1');
      expect(pawnStructure(pos, 'w').passed, isEmpty);
      expect(pawnStructure(pos, 'b').passed, isEmpty);
    });
  });

  group('developmentReport', () {
    test('startpos: nothing developed', () {
      final dev =
          developmentReport(ParsedPosition.fromFen(startpos), 'w');
      expect(dev.minorDev, 0);
      expect(dev.minorHome, ['b1', 'c1', 'f1', 'g1']);
      expect(dev.queenMoved, isFalse);
      expect(dev.castled, isFalse);
    });

    test('counts developed minors and remaining home squares', () {
      final pos = ParsedPosition.fromFen(
          'r1bqkb1r/pppppppp/2n2n2/8/8/2N2N2/PPPPPPPP/R1BQKB1R w KQkq - 4 3');
      final w = developmentReport(pos, 'w');
      expect(w.minorDev, 2);
      expect(w.minorHome, ['c1', 'f1']);
      final b = developmentReport(pos, 'b');
      expect(b.minorDev, 2);
      expect(b.minorHome, ['c8', 'f8']);
    });

    test('queenMoved and castled flags', () {
      final pos = ParsedPosition.fromFen(
          'rnbq1rk1/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1RK1 w - - 4 5');
      expect(developmentReport(pos, 'w').castled, isTrue);
      expect(developmentReport(pos, 'w').queenMoved, isFalse);

      final moved =
          ParsedPosition.fromFen('q3k3/8/8/8/8/8/8/Q3K3 w - - 0 1');
      expect(developmentReport(moved, 'w').queenMoved, isTrue);
    });
  });

  group('centerControl', () {
    test('startpos occupies no central square', () {
      final cc = centerControl(ParsedPosition.fromFen(startpos), 'w');
      expect(cc.occupied, 0);
      expect(cc.pawnsOnCenter, 0);
    });

    test('counts pawns and pieces on the central four', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1');
      final w = centerControl(pos, 'w');
      expect(w.occupied, 1);
      expect(w.pawnsOnCenter, 1);
      final b = centerControl(pos, 'b');
      expect(b.occupied, 1);
      expect(b.pawnsOnCenter, 1);

      final knight =
          ParsedPosition.fromFen('4k3/8/8/4N3/8/8/8/4K3 w - - 0 1');
      final cc = centerControl(knight, 'w');
      expect(cc.occupied, 1);
      expect(cc.pawnsOnCenter, 0);
    });
  });

  group('loosePieces', () {
    test('an undefended knight is loose', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/4N3/8/8/4K3 w - - 0 1');
      final loose = loosePieces(pos, 'w');
      expect(loose, hasLength(1));
      expect(loose.first.piece, 'n');
      expect(loose.first.square, 'e4');
      expect(loosePieces(pos, 'b'), isEmpty);
    });

    test('a pawn-defended piece is not loose', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/4N3/3P4/8/4K3 w - - 0 1');
      expect(loosePieces(pos, 'w'), isEmpty);
    });

    test('the king defends the square beside it', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/8/8/8/3NK3 w - - 0 1');
      expect(loosePieces(pos, 'w'), isEmpty);
    });

    test('a distant defender counts — a rook down its own file', () {
      // The old test asked only about the eight ADJACENT squares, so this
      // knight was reported loose while a rook guarded it from e1.
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/4N3/8/8/4RK2 w - - 0 1');
      expect(loosePieces(pos, 'w'), isEmpty);
    });

    test('a blocked line does not defend', () {
      // Same rook, but a pawn stands between it and the knight.
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/4N3/4P3/8/4RK2 w - - 0 1');
      expect(loosePieces(pos, 'w').map((l) => l.square), ['e4']);
    });

    test('pawns and kings are never reported; distant rook is loose', () {
      final pos =
          ParsedPosition.fromFen('4k3/8/8/8/8/8/8/R3K3 w - - 0 1');
      final loose = loosePieces(pos, 'w');
      expect(loose, hasLength(1));
      expect(loose.first.square, 'a1');
    });

    test('in startpos the rooks are genuinely undefended', () {
      // This expectation changed with the move from adjacency to a real
      // attack test, and the new answer is the correct one: in the starting
      // position nothing guards a1 or h1. The knight on b1 covers a3/c3/d2,
      // the bishop on c1 is boxed in, and the queen's rank is blocked by the
      // knight. Adjacency said "defended" only because a2 and b1 sit next to
      // a1, which is not what defending means.
      expect(loosePieces(ParsedPosition.fromFen(startpos), 'w')
          .map((l) => l.square), ['a1', 'h1']);
      expect(loosePieces(ParsedPosition.fromFen(startpos), 'b')
          .map((l) => l.square), ['a8', 'h8']);
    });
  });
}
