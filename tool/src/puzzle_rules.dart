import 'package:dartchess/dartchess.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';

import 'chess_proofs.dart';
import 'corpus.dart';
import 'findings.dart';

/// The puzzle gate: everything that can be decided about a puzzle's chess
/// without asking an engine's opinion.
///
/// Every rule here is exact. That is the bar for a solve loop that accepts
/// exactly one line — if a puzzle's correctness rests on a judgement call, the
/// position is wrong for this corpus and should be recomposed rather than
/// argued about.
///
/// Trainer puzzles get the whole gate. Teaching puzzles — lesson proofs and
/// Sharpen's review pools — get the same proof of what the line achieves,
/// without the rating rules that only a rated ladder needs. They were once
/// skipped entirely, and a lesson's OWN beat shipped a final move that hung
/// its rook.
class PuzzleGate {
  PuzzleGate();

  static const _trainerKeys = {
    'id', 'fen', 'solution', 'rating', 'title', 'setup', 'hint', 'explanation',
  };

  /// A teaching puzzle is ordered by its lesson, never rated.
  static const _teachingKeys = {
    'id', 'fen', 'solution', 'title', 'setup', 'hint', 'explanation',
  };

  static const _minRating = 400;
  static const _maxRating = 2400;

  /// Checks every trainer puzzle in [files], optionally narrowed to [packs].
  /// An unnarrowed run checks every teaching puzzle as well.
  ///
  /// [lessons] are the boards puzzles may not repeat: a puzzle standing on a
  /// lesson's play position asks a question the reader has already answered.
  List<Finding> run(
    Map<String, PuzzleFile> files, {
    Set<String>? packs,
    Map<String, Lesson> lessons = const {},
  }) {
    final findings = <Finding>[];
    final byPack = <String, List<PuzzleFile>>{};
    final teaching = <PuzzleFile>[];
    for (final file in files.values) {
      if (!file.isTrainer) {
        teaching.add(file);
        continue;
      }
      final pack = file.pack;
      if (pack == null) {
        findings.add(Finding.error(file.fileId, 'filename is not <pack>-NN'));
        continue;
      }
      if (packs != null && !packs.contains(pack)) continue;
      byPack.putIfAbsent(pack, () => []).add(file);
    }

    // Duplicate positions are checked against the WHOLE corpus, never just the
    // packs being run: the defect this catches is one author reusing a
    // position another author already used, and a narrowed run would hide it.
    findings.addAll(_duplicatePositions(files, lessons));

    for (final pack in byPack.keys.toList()..sort()) {
      final inPack = byPack[pack]!..sort((a, b) => a.fileId.compareTo(b.fileId));
      var previousRating = -1;
      for (final file in inPack) {
        _checked++;
        findings.addAll(_structure(file, previousRating));
        previousRating = file.puzzle.rating ?? previousRating;
        findings.addAll(_line(file));
      }
    }

    if (packs == null) {
      teaching.sort((a, b) => a.fileId.compareTo(b.fileId));
      for (final file in teaching) {
        _checkedTeaching++;
        findings.addAll(_teachingStructure(file));
        findings.addAll(_line(file));
      }
    }
    return findings;
  }

  /// Trainer puzzles checked by the last [run].
  int get checked => _checked;
  int _checked = 0;

  /// Teaching puzzles checked by the last [run].
  int get checkedTeaching => _checkedTeaching;
  int _checkedTeaching = 0;

  /// One board, one place — puzzles against each other and against every
  /// lesson play position.
  ///
  /// A reader who meets a board twice is answering from memory: a trainer
  /// puzzle that repeats a lesson's play step hands out rating for a question
  /// already solved, and a review puzzle that repeats one re-asks the exact
  /// board the pattern was taught on. Lessons keep their boards; a puzzle
  /// that repeats one moves.
  Iterable<Finding> _duplicatePositions(
    Map<String, PuzzleFile> files,
    Map<String, Lesson> lessons,
  ) sync* {
    final seen = <String, String>{};
    for (final name in lessons.keys.toList()..sort()) {
      for (final (i, step) in lessons[name]!.steps.indexed) {
        if (step is! PlayStep) continue;
        seen.putIfAbsent(boardKey(step.fen), () => '$name play step ${i + 1}');
      }
    }
    for (final id in files.keys.toList()..sort()) {
      final key = boardKey(files[id]!.puzzle.fen);
      final previous = seen[key];
      if (previous == null) {
        seen[key] = id;
        continue;
      }
      yield Finding.error(id, 'same position as $previous');
    }
  }

  Iterable<Finding> _structure(PuzzleFile file, int previousRating) sync* {
    final id = file.fileId;
    final puzzle = file.puzzle;

    if (puzzle.id != id) yield Finding.error(id, 'id is "${puzzle.id}"');
    yield* _keys(file, _trainerKeys);

    final rating = puzzle.rating!;
    if (rating < _minRating || rating > _maxRating) {
      yield Finding.error(id, 'rating $rating out of range');
    }
    if (rating < previousRating) {
      yield Finding.error(
          id, 'rating $rating drops below the previous $previousRating');
    }

    for (final field in ['title', 'setup', 'hint', 'explanation']) {
      if ((file.raw[field] as String? ?? '').trim().isEmpty) {
        yield Finding.error(id, '$field is empty');
      }
    }
    if (!(puzzle.explanation ?? '').startsWith('## The Idea')) {
      yield Finding.error(id, 'explanation does not open with "## The Idea"');
    }
    yield* _lineLength(id, puzzle);
  }

  /// A teaching puzzle's file: named for itself, exactly its seven keys, and a
  /// line that ends on the learner's move. Its prose is `tool/lint_puzzles.dart`'s.
  Iterable<Finding> _teachingStructure(PuzzleFile file) sync* {
    final id = file.fileId;
    if (file.puzzle.id != id) yield Finding.error(id, 'id is "${file.puzzle.id}"');
    yield* _keys(file, _teachingKeys);
    yield* _lineLength(id, file.puzzle);
  }

  Iterable<Finding> _keys(PuzzleFile file, Set<String> wanted) sync* {
    final keys = file.raw.keys.toSet();
    final missing = wanted.difference(keys);
    final extra = keys.difference(wanted);
    if (missing.isNotEmpty) {
      yield Finding.error(
          file.fileId, 'missing key(s): ${(missing.toList()..sort()).join(", ")}');
    }
    if (extra.isNotEmpty) {
      yield Finding.error(
          file.fileId, 'unexpected key(s): ${(extra.toList()..sort()).join(", ")}');
    }
  }

  /// P09 — the line ends on the learner's move. One that ends on the
  /// opponent's leaves the reader watching a reply they cannot answer.
  Iterable<Finding> _lineLength(String id, Puzzle puzzle) sync* {
    if (puzzle.solution.isEmpty) {
      yield Finding.error(id, 'no solution');
    } else if (puzzle.solution.length.isEven) {
      yield Finding.error(
          id, 'line ends on the opponent (${puzzle.solution.length} plies)');
    }
  }

  /// Replays the line through the app's own parser, then proves what it can
  /// about the result.
  Iterable<Finding> _line(PuzzleFile file) sync* {
    final id = file.fileId;
    final puzzle = file.puzzle;

    Position position;
    try {
      position = positionFromFen(puzzle.fen);
    } on Object catch (e) {
      yield Finding.error(id, 'FEN does not parse — $e');
      return;
    }

    final mover = position.turn;
    final start = position;

    // A teaching board may hold a lone king — castling drills, a rook ladder.
    // With a king missing there is nothing to mate, so the mate proofs have
    // nothing to say and stay out of the way.
    final bothKings = start.board.kingOf(Side.white) != null &&
        start.board.kingOf(Side.black) != null;

    // A position where the side NOT to move is in check cannot arise in a
    // game, and the tolerant reader will happily hand one back — it exists for
    // pedagogical setups like a lone king. Left unchecked it produces nonsense
    // the solver reports as "every move mates", because the defender is
    // already mated before the reader has played anything.
    if (bothKings && position.copyWith(turn: mover.opposite).isCheck) {
      yield Finding.error(id, 'the side not to move is already in check');
      return;
    }
    if (position.isCheckmate || position.isStalemate) {
      yield Finding.error(id, 'the position is already over');
      return;
    }

    // Whether the whole line is a forced mate against EVERY defence, not just
    // the scripted one. Knowing this first is what lets the forcing screen
    // below stay quiet when it has nothing to say.
    final proven = bothKings && _provenMate(start, puzzle.solution);
    final forcing = <Finding>[];
    final positions = <Position>[start];

    for (var ply = 0; ply < puzzle.solution.length; ply++) {
      final san = puzzle.solution[ply];
      final move = legalMoveFromSan(position, san);
      if (move == null) {
        yield Finding.error(id, 'ply ${ply + 1} ($san) is illegal');
        return;
      }
      if (ply.isOdd) {
        // The opponent's move. A reply the defender was not forced into means
        // a reader who meets a different defence is on their own — unless the
        // mate is proved against all of them, in which case there is nothing
        // to warn about.
        final legal = legalMovesOf(position);
        if (legal.length > 1) {
          forcing.add(Finding.flag(
              id, 'ply ${ply + 1}: opponent had ${legal.length} legal replies, not 1'));
        }
      }
      position = position.playUnchecked(move);
      positions.add(position);
    }

    if (!proven) yield* forcing;
    if (bothKings) yield* _outcome(id, positions, mover);
  }

  /// Does the first move force mate in exactly the line's length, whatever the
  /// defender tries?
  ///
  /// This is the strongest thing the gate can say about a puzzle, and it makes
  /// several weaker checks redundant — which is why it is asked first.
  bool _provenMate(Position start, List<String> line) {
    if (line.length > _proofPlies) return false;
    final key = legalMoveFromSan(start, line.first);
    if (key == null) return false;
    final firsts = movesForcingMateIn(start, line.length);
    // A search that gave up proves nothing. Treating a truncated list as
    // "unique" would suppress the forcing-reply flags below on the strength
    // of a search that never finished.
    if (firsts.exhausted) return false;
    return firsts.moves.length == 1 && firsts.moves.single.uci == key.uci;
  }

  /// How deep the solver is allowed to prove things. A mate in three is
  /// settled in milliseconds; a mate in five is a different kind of search and
  /// is not what this gate is for.
  static const _proofPlies = 5;

  /// What the line actually achieved, given every position it passed through.
  ///
  /// A mating line whose every reply was forced is **already proved** by the
  /// forcing rule above — that is what "the opponent had one legal move"
  /// means. What is left to ask is whether the reader could have mated sooner
  /// or by a different move. Both are searches, so both are bounded, and both
  /// stay silent rather than guess when the bound is reached.
  ///
  /// A non-mating line is only ever *flagged*, never failed. "Ends level" is
  /// not a defect: trapping a piece wins it next move, and an endgame line
  /// ends when the win is clear rather than when it is collected. An error has
  /// to be a fact, and this one is a judgement.
  Iterable<Finding> _outcome(
    String id,
    List<Position> positions,
    Side mover,
  ) sync* {
    final start = positions.first;
    final end = positions.last;
    final plies = positions.length - 1;
    if (end.isCheckmate) {
      if (plies > _proofPlies) return;
      final faster = forcedMateIn(start, maxPlies: plies - 2);
      if (faster.exhausted) {
        yield Finding.error(
            id,
            'the shorter-mate search ran out of budget — cannot certify that '
            '$plies plies is the fastest mate');
        return;
      }
      if (faster.plies != null) {
        yield Finding.error(
            id,
            'a forced mate in ${faster.plies} plies exists — '
            'the line takes $plies');
        return;
      }
      final firsts = movesForcingMateIn(start, plies);
      if (firsts.exhausted) {
        yield Finding.error(
            id,
            'the uniqueness search ran out of budget — cannot certify that '
            'the key move is the only mate in $plies');
      } else if (firsts.moves.isEmpty) {
        // The line ENDS in checkmate, but nothing the mover plays forces one
        // — so the mate only happened because the scripted defence chose to
        // allow it. The gate used to ask only whether the key move was
        // unique, and read "no move forces mate" as "not more than one".
        // A FLAG, not an error. Sometimes this is the lesson: an opening trap
        // shows what happens *if* the opponent blunders, and the blunder is
        // the point. What it must never do is call that reply forced — which
        // is exactly what `docs/content-audit.md` recorded about
        // back-rank-02 and back-rank-12 and never fixed.
        yield Finding.flag(
            id,
            'the line ends in checkmate but no first move forces mate in '
            '$plies plies — the prose must not call the defence forced');
      } else if (firsts.moves.length > 1) {
        final names = firsts.moves.map((m) => m.uci).join(', ');
        yield Finding.error(id,
            '${firsts.moves.length} first moves force mate in $plies ($names)');
      }
      // Every later learner move must be the only one that still forces the
      // mate in time — except the last. A second mating move there is fine:
      // any checkmate answers an authored checkmate (`acceptsAuthored`).
      for (var ply = 2; ply < plies - 1; ply += 2) {
        final twins = movesForcingMateIn(positions[ply], plies - ply);
        if (twins.exhausted) {
          yield Finding.error(
            id,
            'ply ${ply + 1}: the uniqueness search ran out of budget — '
            'cannot certify that this move is the only one that still mates',
          );
        } else if (twins.moves.length > 1) {
          final names = twins.moves.map((m) => m.uci).join(', ');
          yield Finding.error(
            id,
            'ply ${ply + 1}: ${twins.moves.length} moves force mate in '
            '${plies - ply} ($names) — only the final move may have a twin',
          );
        }
      }
      return;
    }

    if (end.isStalemate) return; // a saved half point is its own outcome

    final gain = materialFor(end, mover) - materialFor(start, mover);
    if (gain <= 0) {
      yield Finding.flag(id,
          'ends level or worse (${gain}p) without mate — check the point lands');
    }
  }
}
