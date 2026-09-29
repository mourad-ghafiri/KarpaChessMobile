import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'src/chess_proofs.dart';

/// An authoring aid: searches for positions whose tactic is **provable**.
///
/// Composing by hand does not scale, and composing by taste produces puzzles
/// that turn out to have two solutions. This samples sparse positions from a
/// piece inventory, keeps only those with exactly ONE first move forcing mate
/// in the requested length, and then applies a theme predicate — so what comes
/// out the far end is already proved unique before a word of prose is written.
///
///   dart run tool/compose.dart --theme king-hunt --plies 5 --want 6 --shelter
///
/// Themes are predicates over the proved line, not labels:
///   king-hunt   the defending king is forced to move at least twice
///   sacrifice   the key move gives away material that can legally be taken
///   quiet       the key move is not a check and not a capture
///   any         no predicate
void main(List<String> args) {
  final options = _Options.parse(args);
  final random = Random(options.seed);
  final found = <String>{};
  var tried = 0;

  while (found.length < options.want && tried < options.budget) {
    tried++;
    final position = _sample(random, options);
    if (position == null) continue;

    final mate = forcedMateIn(position, maxPlies: options.plies);
    // Exactly the requested length: a shorter mate means the puzzle is not the
    // one asked for, and the solver already searched shortest-first. A search
    // that ran out of budget is skipped — the composer wants candidates it can
    // prove, and there are always more samples.
    final plies = mate.plies;
    if (mate.exhausted || plies == null || plies != options.plies) continue;
    final firsts = movesForcingMateIn(position, plies);
    if (firsts.exhausted || firsts.moves.length != 1) continue;
    final key = firsts.moves.single;

    final line = _principalLine(position, key, plies);
    if (!options.matches(position, key, line)) continue;
    if (!found.add(position.fen)) continue;

    final sans = _sans(position, line);
    stdout.writeln(position.fen);
    stdout.writeln('  mate in ${(plies + 1) ~/ 2}: ${sans.join(' ')}');
  }
  stdout.writeln('\n${found.length} found in $tried samples');
}

/// A random sparse position: kings placed apart, then the inventory dropped on
/// free squares. Most samples are rejected; that is fine, they cost microseconds.
Position? _sample(Random random, _Options options) {
  final used = <Square>{};
  Square? free() {
    for (var attempt = 0; attempt < 40; attempt++) {
      final square = Square(random.nextInt(64));
      if (used.add(square)) return square;
    }
    return null;
  }

  final board = <Square, Piece>{};

  if (options.shelter) {
    // A castled king behind its own pawns, which is what a puzzle from a real
    // game looks like. Unconstrained sampling produces provable tactics that
    // teach nothing, because the pieces land where no game would leave them.
    final blackKing = random.nextBool() ? Square.g8 : Square.h8;
    for (final square in [blackKing, Square.f7, Square.g7, Square.h7]) {
      used.add(square);
    }
    board[blackKing] = const Piece(color: Side.black, role: Role.king);
    for (final square in [Square.f7, Square.g7, Square.h7]) {
      board[square] = const Piece(color: Side.black, role: Role.pawn);
    }
    // White's king out of the way on the first rank, and its own shelter, so
    // the reader is never distracted by a white king in danger.
    for (final square in [Square.a1, Square.a2, Square.b2]) {
      used.add(square);
    }
    board[Square.a1] = const Piece(color: Side.white, role: Role.king);
    board[Square.a2] = const Piece(color: Side.white, role: Role.pawn);
    board[Square.b2] = const Piece(color: Side.white, role: Role.pawn);
  } else {
    final whiteKing = free();
    final blackKing = free();
    if (whiteKing == null || blackKing == null) return null;
    if (_touching(whiteKing, blackKing)) return null;
    board[whiteKing] = const Piece(color: Side.white, role: Role.king);
    board[blackKing] = const Piece(color: Side.black, role: Role.king);
  }

  for (final entry in options.inventory) {
    final square = free();
    if (square == null) return null;
    // No pawn may stand on a back rank.
    if (entry.role == Role.pawn &&
        (square.rank == Rank.first || square.rank == Rank.eighth)) {
      return null;
    }
    board[square] = entry;
  }

  var pieces = Board.empty;
  board.forEach((square, piece) => pieces = pieces.setPieceAt(square, piece));

  final setup = Setup(
    board: pieces,
    turn: Side.white,
    // No castling: a composed study has no move history to justify it, and a
    // stray right would let the solver find mates the position cannot reach.
    castlingRights: SquareSet.empty,
    halfmoves: 0,
    fullmoves: 1,
  );
  try {
    final position = Chess.fromSetup(setup);
    // The defender must not already be in check, and the position must be a
    // live one — otherwise "every move mates" and the puzzle is nonsense.
    if (position.copyWith(turn: Side.black).isCheck) return null;
    if (position.isCheckmate || position.isStalemate) return null;
    return position;
  } on Object {
    return null;
  }
}

bool _touching(Square a, Square b) =>
    (a.file.value - b.file.value).abs() <= 1 &&
    (a.rank.value - b.rank.value).abs() <= 1;

/// One concrete mating line: the key move, the defence that holds out longest,
/// and the mate.
///
/// The defender's choice matters. Every defence loses by construction, but a
/// line that shows the one collapsing immediately teaches nothing — the puzzle
/// should script the move that makes the attacker prove it.
List<NormalMove> _principalLine(Position start, NormalMove key, int plies) {
  final line = <NormalMove>[key];
  var position = start.playUnchecked(key);
  var left = plies - 1;
  var attackerToMove = false; // the defence answers the key move

  while (left > 0 && !position.isCheckmate) {
    final moves = legalMovesOf(position);
    if (moves.isEmpty) break;
    final choice = moves.firstWhere(
      (move) {
        final after = position.playUnchecked(move);
        if (attackerToMove) {
          // After the attacker moves it is the DEFENDER's turn, so the
          // question is whether the defender is lost — not whether it can mate.
          return left == 1
              ? after.isCheckmate
              : isMatedWithin(after, left - 1);
        }
        // After the defence it is the attacker's turn again, and there
        // `forcedMateIn` asks exactly the right question.
        return forcedMateIn(after, maxPlies: left - 1).plies == left - 1;
      },
      orElse: () => moves.first,
    );
    line.add(choice);
    position = position.playUnchecked(choice);
    left--;
    attackerToMove = !attackerToMove;
  }
  return line;
}

List<String> _sans(Position start, List<NormalMove> line) {
  final out = <String>[];
  var position = start;
  for (final move in line) {
    final (next, san) = position.makeSan(move);
    out.add(san);
    position = next;
  }
  return out;
}

class _Options {
  _Options({
    required this.inventory,
    required this.plies,
    required this.want,
    required this.theme,
    required this.seed,
    required this.budget,
    required this.shelter,
  });

  factory _Options.parse(List<String> args) {
    var pieces = 'QRRBN:rb';
    var plies = 3;
    var want = 8;
    var theme = 'any';
    var seed = 1;
    var budget = 400000;
    var shelter = false;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--pieces':
          pieces = args[++i];
        case '--plies':
          plies = int.parse(args[++i]);
        case '--want':
          want = int.parse(args[++i]);
        case '--theme':
          theme = args[++i];
        case '--seed':
          seed = int.parse(args[++i]);
        case '--budget':
          budget = int.parse(args[++i]);
        case '--shelter':
          shelter = true;
      }
    }
    return _Options(
      inventory: _inventory(pieces),
      plies: plies,
      want: want,
      theme: theme,
      seed: seed,
      budget: budget,
      shelter: shelter,
    );
  }

  /// `QRRBN:rbpp` — White's pieces before the colon, Black's after.
  static List<Piece> _inventory(String spec) {
    final parts = spec.split(':');
    final out = <Piece>[];
    for (final (index, group) in parts.indexed) {
      final side = index == 0 ? Side.white : Side.black;
      for (final letter in group.toLowerCase().split('')) {
        final role = Role.fromChar(letter);
        if (role != null) out.add(Piece(color: side, role: role));
      }
    }
    return out;
  }

  final List<Piece> inventory;
  final int plies;
  final int want;
  final String theme;
  final int seed;
  final int budget;

  /// Place the black king castled behind f7/g7/h7 rather than at random.
  final bool shelter;

  bool matches(Position start, NormalMove key, List<NormalMove> line) {
    switch (theme) {
      case 'king-hunt':
        final king = start.board.kingOf(Side.black);
        if (king == null) return false;
        var square = king;
        var walked = 0;
        var position = start;
        for (final move in line) {
          if (move.from == square) {
            square = move.to;
            walked++;
          }
          position = position.playUnchecked(move);
        }
        return walked >= 2;
      case 'sacrifice':
        // The key move puts a piece where the defender can legally take it.
        final after = start.playUnchecked(key);
        return legalMovesOf(after).any((m) => m.to == key.to);
      case 'quiet':
        final after = start.playUnchecked(key);
        return !after.isCheck && start.board.pieceAt(key.to) == null;
      case 'defence':
        // The reader is genuinely lost if they do nothing: hand Black the move
        // and Black mates quickly. Both halves are proved, so the puzzle can
        // honestly claim there is exactly one way out.
        return forcedMateIn(start.copyWith(turn: Side.black), maxPlies: 3)
                .plies !=
            null;
      case 'zwischenzug':
        // The in-between move only reads as one when there is something else
        // the reader would rather do first: a piece of theirs is hanging, a
        // capture is on offer, and the answer is neither — it is a check.
        if (!start.playUnchecked(key).isCheck) return false;
        final hanging = legalMovesOf(start.copyWith(turn: Side.black))
            .any((m) => start.board.pieceAt(m.to)?.color == Side.white);
        final tempting = legalMovesOf(start).any((m) =>
            m.uci != key.uci && start.board.pieceAt(m.to)?.color == Side.black);
        return hanging && tempting;
      default:
        return true;
    }
  }
}
