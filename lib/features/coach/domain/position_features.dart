/// Position feature computations for the built-in coach.
///
/// The heuristics behind the coach's answers:
/// material count, game phase, king safety, pawn structure
/// (isolated/doubled/passed), development, center control and loose pieces.
///
/// Board coordinates: `r` runs 0..7 from rank 8 down
/// to rank 1, `c` runs 0..7 from the a-file to the h-file.
library;

import 'package:dartchess/dartchess.dart' as chess;

import 'coach_service.dart';

const String _files = 'abcdefgh';

int _sq(int r, int c) => r * 8 + c;
String _squareName(int r, int c) => '${_files[c]}${8 - r}';
bool _inBoard(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

/// A piece placed on the board, in JS-style coordinates.
class PlacedPiece {
  const PlacedPiece({
    required this.piece,
    required this.color,
    required this.r,
    required this.c,
  });

  /// Lowercase piece letter: p, n, b, r, q or k.
  final String piece;

  /// 'w' or 'b'.
  final String color;

  final int r;
  final int c;

  String get square => _squareName(r, c);
}

/// Structured position parsed from a FEN string.
///
/// Invalid or empty FENs yield an empty board with white to move, matching the
/// forgiving behaviour of the JS `parseFEN`.
class ParsedPosition {
  ParsedPosition._({
    required this.board,
    required this.turn,
    required this.halfmove,
    required this.fullmove,
    required this.pieces,
    required this.material,
    required this.kingPos,
  });

  factory ParsedPosition.fromFen(String fen) {
    chess.Setup setup;
    try {
      setup = chess.Setup.parseFen(fen);
    } on Exception {
      return ParsedPosition._empty();
    }
    final board = List<PlacedPiece?>.filled(64, null);
    final pieces = {'w': <PlacedPiece>[], 'b': <PlacedPiece>[]};
    final material = {
      'w': {'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, 'k': 0},
      'b': {'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, 'k': 0},
    };
    final kingPos = <String, ({int r, int c})?>{'w': null, 'b': null};
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final piece = setup.board.pieceAt(
          chess.Square.fromCoords(chess.File(c), chess.Rank(7 - r)),
        );
        if (piece == null) continue;
        final color = piece.color == chess.Side.white ? 'w' : 'b';
        final letter = piece.role.letter;
        final placed = PlacedPiece(piece: letter, color: color, r: r, c: c);
        board[_sq(r, c)] = placed;
        pieces[color]!.add(placed);
        material[color]![letter] = material[color]![letter]! + 1;
        if (letter == 'k') kingPos[color] = (r: r, c: c);
      }
    }
    return ParsedPosition._(
      board: board,
      turn: setup.turn == chess.Side.black ? 'b' : 'w',
      halfmove: setup.halfmoves,
      fullmove: setup.fullmoves,
      pieces: pieces,
      material: material,
      kingPos: kingPos,
    );
  }

  factory ParsedPosition._empty() => ParsedPosition._(
        board: List<PlacedPiece?>.filled(64, null),
        turn: 'w',
        halfmove: 0,
        fullmove: 1,
        pieces: {'w': <PlacedPiece>[], 'b': <PlacedPiece>[]},
        material: {
          'w': {'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, 'k': 0},
          'b': {'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, 'k': 0},
        },
        kingPos: {'w': null, 'b': null},
      );

  /// 64 cells indexed `r * 8 + c` (r 0 = rank 8).
  final List<PlacedPiece?> board;

  /// 'w' or 'b'.
  final String turn;

  final int halfmove;
  final int fullmove;

  /// Pieces per color, in board-scan order (rank 8 first, a-file first).
  final Map<String, List<PlacedPiece>> pieces;

  /// Piece counts per color, keyed by lowercase piece letter.
  final Map<String, Map<String, int>> material;

  final Map<String, ({int r, int c})?> kingPos;
}

/// Material points and non-pawn piece counts for both sides.
class MaterialReport {
  const MaterialReport({
    required this.whitePoints,
    required this.blackPoints,
    required this.diff,
    required this.nonPawnWhite,
    required this.nonPawnBlack,
  });

  final int whitePoints;
  final int blackPoints;
  final int diff;
  final int nonPawnWhite;
  final int nonPawnBlack;
}

MaterialReport materialReport(ParsedPosition pos) {
  final w = pos.material['w']!;
  final b = pos.material['b']!;
  final nonPawnW = w['n']! + w['b']! + w['r']! + w['q']!;
  final nonPawnB = b['n']! + b['b']! + b['r']! + b['q']!;
  final ptsW = w['p']! + w['n']! * 3 + w['b']! * 3 + w['r']! * 5 + w['q']! * 9;
  final ptsB = b['p']! + b['n']! * 3 + b['b']! * 3 + b['r']! * 5 + b['q']! * 9;
  return MaterialReport(
    whitePoints: ptsW,
    blackPoints: ptsB,
    diff: ptsW - ptsB,
    nonPawnWhite: nonPawnW,
    nonPawnBlack: nonPawnB,
  );
}

/// Game phase: 'opening', 'middlegame' or 'endgame'.
String phaseKey(ParsedPosition pos, int moveCount) {
  final mr = materialReport(pos);
  final totalNonPawn = mr.nonPawnWhite + mr.nonPawnBlack;
  final hasQueens = pos.material['w']!['q']! + pos.material['b']!['q']! > 0;
  if (moveCount < 12 && totalNonPawn >= 12) return 'opening';
  if (totalNonPawn <= 6 && !hasQueens) return 'endgame';
  if (totalNonPawn <= 8) return 'endgame';
  return 'middlegame';
}

/// King safety verdict for one side.
class KingSafetyReport {
  const KingSafetyReport({
    required this.score,
    this.castled = false,
    this.center = false,
    this.shieldCount = 0,
    this.notes = const [],
  });

  /// One of: safe, exposed, danger, shelter, waiting, active, unknown.
  /// Matches the `coach.builtin.kingScore.*` i18n keys.
  final String score;
  final bool castled;
  final bool center;
  final int shieldCount;

  /// Translated observations built via the injected [Translate].
  final List<String> notes;
}

KingSafetyReport kingSafety(
  ParsedPosition pos,
  String color,
  String gamePhase,
  Translate t,
) {
  final k = pos.kingPos[color];
  if (k == null) return const KingSafetyReport(score: 'unknown');
  final notes = <String>[];
  final backRank = color == 'w' ? 7 : 0;
  final castled = k.r == backRank && (k.c == 6 || k.c == 2);
  final center = k.r == backRank && k.c == 4;
  final pawnRank = color == 'w' ? k.r - 1 : k.r + 1;
  var shieldCount = 0;
  for (var dc = -1; dc <= 1; dc++) {
    final pc = k.c + dc;
    if (!_inBoard(pawnRank, pc)) continue;
    final x = pos.board[_sq(pawnRank, pc)];
    if (x != null && x.piece == 'p' && x.color == color) shieldCount++;
  }
  // An enemy rook or queen bearing on the king's file with NOTHING between
  // them. This used to scan the whole file and ignore blockers, so a rook
  // behind five of its own pawns "endangered" a castled king — and `danger`
  // is the loudest verdict the coach gives.
  var dangerFile = false;
  for (final dr in const [-1, 1]) {
    var r = k.r + dr;
    while (_inBoard(r, k.c)) {
      final p = pos.board[_sq(r, k.c)];
      if (p != null) {
        if (p.color != color && (p.piece == 'r' || p.piece == 'q')) {
          dangerFile = true;
        }
        break; // the first piece either is the threat or blocks it
      }
      r += dr;
    }
    if (dangerFile) break;
  }

  if (gamePhase == 'endgame') {
    var score = 'active';
    if (castled) {
      score = 'shelter';
      notes.add(t('coach.builtin.kingNote.tuckedCorner'));
    } else if (center) {
      score = 'waiting';
      notes.add(t('coach.builtin.kingNote.startingSquare'));
    } else {
      notes.add(t('coach.builtin.kingNote.activeOn',
          {'square': _squareName(k.r, k.c)}));
    }
    return KingSafetyReport(
      score: score,
      castled: castled,
      center: center,
      shieldCount: shieldCount,
      notes: notes,
    );
  }

  var score = 'safe';
  if (!castled && !center) {
    score = 'exposed';
    notes.add(t('coach.builtin.kingNote.wanderingOn',
        {'square': _squareName(k.r, k.c)}));
  } else if (center && pos.fullmove > 8) {
    score = 'exposed';
    notes.add(t('coach.builtin.kingNote.centerAfter8'));
  }
  if (shieldCount <= 1 && (castled || center)) {
    score = 'exposed';
    notes.add(t('coach.builtin.kingNote.thinShield', {'count': shieldCount}));
  }
  if (dangerFile) {
    score = 'danger';
    notes.add(t('coach.builtin.kingNote.enemyHeavy'));
  }
  if (castled && shieldCount == 3 && !dangerFile) {
    notes.add(t('coach.builtin.kingNote.fullShield'));
  }
  return KingSafetyReport(
    score: score,
    castled: castled,
    center: center,
    shieldCount: shieldCount,
    notes: notes,
  );
}

/// Pawn structure highlights for one side.
class PawnStructureReport {
  const PawnStructureReport({
    required this.count,
    required this.isolated,
    required this.doubled,
    required this.passed,
  });

  final int count;

  /// Squares of isolated pawns (e.g. 'd4').
  final List<String> isolated;

  /// File letters containing doubled pawns (e.g. 'c').
  final List<String> doubled;

  /// Squares of passed pawns.
  final List<String> passed;
}

PawnStructureReport pawnStructure(ParsedPosition pos, String color) {
  final pawns = pos.pieces[color]!.where((p) => p.piece == 'p').toList();
  final filesOccupied = <int, int>{};
  for (final p in pawns) {
    filesOccupied[p.c] = (filesOccupied[p.c] ?? 0) + 1;
  }
  final isolated = <String>[];
  final doubled = <String>[];
  final passed = <String>[];

  for (final p in pawns) {
    final left = filesOccupied[p.c - 1] ?? 0;
    final right = filesOccupied[p.c + 1] ?? 0;
    if (left == 0 && right == 0) isolated.add(p.square);
    if (filesOccupied[p.c]! > 1) doubled.add(p.square);

    final enemy = color == 'w' ? 'b' : 'w';
    bool ahead(int rr) => color == 'w' ? rr < p.r : rr > p.r;
    var isPassed = true;
    for (final ep in pos.pieces[enemy]!) {
      if (ep.piece != 'p') continue;
      if (!ahead(ep.r)) continue;
      if ((ep.c - p.c).abs() <= 1) {
        isPassed = false;
        break;
      }
    }
    if (isPassed) passed.add(p.square);
  }
  return PawnStructureReport(
    count: pawns.length,
    isolated: isolated.toSet().toList(),
    doubled: doubled.map((s) => s[0]).toSet().toList(),
    passed: passed.toSet().toList(),
  );
}

/// Minor-piece development snapshot for one side.
class DevelopmentReport {
  const DevelopmentReport({
    required this.minorDev,
    required this.minorHome,
    required this.queenMoved,
    required this.castled,
  });

  final int minorDev;
  final List<String> minorHome;
  final bool queenMoved;
  final bool castled;
}

DevelopmentReport developmentReport(ParsedPosition pos, String color) {
  final starts = color == 'w'
      ? {
          'n': ['b1', 'g1'],
          'b': ['c1', 'f1'],
          'q': ['d1'],
        }
      : {
          'n': ['b8', 'g8'],
          'b': ['c8', 'f8'],
          'q': ['d8'],
        };
  final minorHome = <String>[];
  var minorDev = 0;
  for (final p in pos.pieces[color]!) {
    if (p.piece == 'n' || p.piece == 'b') {
      if (starts[p.piece]!.contains(p.square)) {
        minorHome.add(p.square);
      } else {
        minorDev++;
      }
    }
  }
  final queenMoved = !pos.pieces[color]!
      .any((p) => p.piece == 'q' && starts['q']!.contains(p.square));
  final k = pos.kingPos[color];
  final backRank = color == 'w' ? 7 : 0;
  final castled = k != null && k.r == backRank && (k.c == 6 || k.c == 2);
  return DevelopmentReport(
    minorDev: minorDev,
    minorHome: minorHome,
    queenMoved: queenMoved,
    castled: castled,
  );
}

/// Occupation of the four central squares by one side.
class CenterControlReport {
  const CenterControlReport({
    required this.occupied,
    required this.pawnsOnCenter,
  });

  final int occupied;
  final int pawnsOnCenter;
}

CenterControlReport centerControl(ParsedPosition pos, String color) {
  const centers = [(3, 3), (3, 4), (4, 3), (4, 4)];
  var occ = 0;
  var pawnsOnCenter = 0;
  for (final (r, c) in centers) {
    final p = pos.board[_sq(r, c)];
    if (p != null && p.color == color) {
      occ++;
      if (p.piece == 'p') pawnsOnCenter++;
    }
  }
  return CenterControlReport(occupied: occ, pawnsOnCenter: pawnsOnCenter);
}

/// An undefended non-pawn, non-king piece.
class LoosePiece {
  const LoosePiece({required this.piece, required this.square});

  final String piece;
  final String square;
}

/// Pieces of [color] that nothing of theirs defends — targets worth naming.
List<LoosePiece> loosePieces(ParsedPosition pos, String color) {
  final loose = <LoosePiece>[];
  for (final p in pos.pieces[color]!) {
    if (p.piece == 'p' || p.piece == 'k') continue;
    if (!_attackedBy(pos, p.r, p.c, color)) {
      loose.add(LoosePiece(piece: p.piece, square: p.square));
    }
  }
  return loose;
}

/// Does any piece of [color] attack the square at [r],[c]?
///
/// A real attack test, with blockers. The coach used to answer "is this piece
/// defended?" by looking at the eight ADJACENT squares, which called a rook
/// defending down a file undefended and counted a pinned neighbour as a
/// defender. Both errors reached the Match Review bullets, beside genuine
/// engine verdicts, where a reader cannot tell them apart.
///
/// Pins are deliberately ignored: a pinned defender still deters a capture in
/// the sense the coach means, and deciding otherwise is the engine's job.
bool _attackedBy(ParsedPosition pos, int r, int c, String color) {
  // Pawns attack diagonally forward. A white pawn on r+1 attacks r.
  final pawnRow = color == 'w' ? r + 1 : r - 1;
  for (final dc in const [-1, 1]) {
    if (!_inBoard(pawnRow, c + dc)) continue;
    final x = pos.board[_sq(pawnRow, c + dc)];
    if (x != null && x.color == color && x.piece == 'p') return true;
  }

  const knightJumps = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1],
  ];
  for (final j in knightJumps) {
    final jr = r + j[0], jc = c + j[1];
    if (!_inBoard(jr, jc)) continue;
    final x = pos.board[_sq(jr, jc)];
    if (x != null && x.color == color && x.piece == 'n') return true;
  }

  for (var dr = -1; dr <= 1; dr++) {
    for (var dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      if (!_inBoard(r + dr, c + dc)) continue;
      final x = pos.board[_sq(r + dr, c + dc)];
      if (x != null && x.color == color && x.piece == 'k') return true;
    }
  }

  // Sliders: walk each ray until something blocks it.
  const rays = [
    [-1, 0], [1, 0], [0, -1], [0, 1], // rook / queen
    [-1, -1], [-1, 1], [1, -1], [1, 1], // bishop / queen
  ];
  for (var i = 0; i < rays.length; i++) {
    final straight = i < 4;
    var rr = r + rays[i][0], cc = c + rays[i][1];
    while (_inBoard(rr, cc)) {
      final x = pos.board[_sq(rr, cc)];
      if (x != null) {
        if (x.color == color &&
            (x.piece == 'q' || x.piece == (straight ? 'r' : 'b'))) {
          return true;
        }
        break; // any other piece blocks the ray
      }
      rr += rays[i][0];
      cc += rays[i][1];
    }
  }
  return false;
}

