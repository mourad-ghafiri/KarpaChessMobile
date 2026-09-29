/// Integrity check of the real bundled content.
///
/// Reads the actual files under `assets/data/` with dart:io (flutter test
/// runs with the project root as cwd) and validates, for the English corpus
/// (the only content language shipped):
///
/// - every manifest-listed lesson/puzzle file exists;
/// - every lesson parses into the domain models and every step FEN is a
///   valid position;
/// - every play step has at least one legal `targetSan`;
/// - every puzzle solution replays legally from its FEN;
/// - mate-in-N puzzles end in checkmate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';

String get _dataRoot => '${Directory.current.path}/assets/data';

Map<String, dynamic> _readJson(String path) {
  return json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

/// Parses [fen] into a position, or records a failure and returns null.
///
/// Lesson and puzzle FENs may be pedagogical positions that strict chess
/// validation rejects: single-king teaching boards and positions where the
/// side not to move is already "in check" by construction. dartchess move
/// generation handles both fine, so for those two causes we fall back to an
/// unchecked [Chess] construction. Anything else is a genuine data error.
Position? _parsePosition(String context, String fen, List<String> failures) {
  final Setup setup;
  try {
    setup = Setup.parseFen(fen);
  } on Object catch (e) {
    failures.add('$context: bad FEN "$fen" — $e');
    return null;
  }
  try {
    return Chess.fromSetup(setup, ignoreImpossibleCheck: true);
  } on PositionSetupException catch (e) {
    if (e.cause == IllegalSetupCause.kings ||
        e.cause == IllegalSetupCause.oppositeCheck) {
      return Chess(
        board: setup.board,
        turn: setup.turn,
        castles: Castles.fromSetup(setup),
        epSquare: setup.epSquare,
        halfmoves: setup.halfmoves,
        fullmoves: setup.fullmoves,
      );
    }
    failures.add('$context: bad FEN "$fen" — $e');
    return null;
  }
}

void _expectClean(List<String> failures) {
  for (final f in failures) {
    stdout.writeln('FAIL: $f');
  }
  expect(failures, isEmpty,
      reason: '${failures.length} content error(s) — see log above');
}

void main() {
  late LessonManifest lessonManifest;
  late PuzzleManifest puzzleManifest;

  setUpAll(() {
    lessonManifest =
        LessonManifest.fromJson(_readJson('$_dataRoot/lessons/index.json'));
    puzzleManifest =
        PuzzleManifest.fromJson(_readJson('$_dataRoot/puzzles/index.json'));
  });

  test('every manifest entry exists on disk', () {
    final failures = <String>[];
    for (final category in lessonManifest.categories) {
      for (final file in category.lessonFiles) {
        if (!File('$_dataRoot/lessons/en/$file').existsSync()) {
          failures.add('lessons/en/$file: missing (category ${category.id})');
        }
      }
    }
    for (final theme in puzzleManifest.themes) {
      for (final file in theme.puzzleFiles) {
        if (!File('$_dataRoot/puzzles/en/$file').existsSync()) {
          failures.add('puzzles/en/$file: missing (theme ${theme.id})');
        }
      }
    }
    _expectClean(failures);
  });

  test('every lesson parses; FENs are valid; play steps have a legal target',
      () {
    final failures = <String>[];
    for (final category in lessonManifest.categories) {
      for (final file in category.lessonFiles) {
        final path = '$_dataRoot/lessons/en/$file';
        if (!File(path).existsSync()) continue; // reported by the test above
        final context = 'lessons/en/$file';

        final Lesson lesson;
        try {
          lesson = Lesson.fromJson(_readJson(path));
        } on Object catch (e) {
          failures.add('$context: failed to parse — $e');
          continue;
        }

        for (var i = 0; i < lesson.steps.length; i++) {
          final step = lesson.steps[i];
          final position =
              _parsePosition('$context step $i', step.fen, failures);
          if (position == null) continue;

          if (step case PlayStep(:final targetSan)) {
            if (targetSan.isEmpty) {
              failures.add('$context step $i: play step has no targetSan');
            } else if (!targetSan
                .any((san) => position.parseSan(san) != null)) {
              failures.add('$context step $i: no target SAN is legal '
                  'in "${step.fen}" — $targetSan');
            }
          }
        }
      }
    }
    _expectClean(failures);
  });

  test('every puzzle solution replays legally; mate-in-N ends in checkmate',
      () {
    final failures = <String>[];
    for (final theme in puzzleManifest.themes) {
      final expectMate = theme.id.startsWith('mate-in-');
      for (final file in theme.puzzleFiles) {
        final path = '$_dataRoot/puzzles/en/$file';
        if (!File(path).existsSync()) continue; // reported by the test above
        final context = 'puzzles/en/$file';

        final Puzzle puzzle;
        try {
          puzzle = Puzzle.fromJson(_readJson(path));
        } on Object catch (e) {
          failures.add('$context: failed to parse — $e');
          continue;
        }
        if (puzzle.fen.isEmpty) {
          failures.add('$context: missing fen');
          continue;
        }
        if (puzzle.solution.isEmpty) {
          failures.add('$context: empty solution');
          continue;
        }

        Position? position = _parsePosition(context, puzzle.fen, failures);
        if (position == null) continue;

        var replayed = true;
        for (var i = 0; i < puzzle.solution.length; i++) {
          final san = puzzle.solution[i];
          final move = position!.parseSan(san);
          if (move == null) {
            failures.add('$context: move ${i + 1} ($san) is illegal '
                '(fen "${puzzle.fen}")');
            replayed = false;
            break;
          }
          position = position.play(move);
        }

        if (replayed && expectMate && !position!.isCheckmate) {
          failures.add('$context: expected checkmate at end of solution '
              '(theme ${theme.id})');
        }
      }
    }
    _expectClean(failures);
  });
}
