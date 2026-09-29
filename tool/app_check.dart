// Replays the APP's own runtime loading pipeline (not the content tools'
// mirror of it) over every lesson and puzzle.
//
//   dart run tool/app_check.dart
//
// `content.dart` proves the corpus is well-formed; this proves the app's own
// code loads it: the same positionFromFen, BoardScript.of and
// legalMoveFromSan the screens call. It exists because the two once
// disagreed only inside a stale build — but the classifier is mirrored, not
// shared, so only this run exercises the real one.
//
// Mirrors ConceptPlayerScreen._buildBeats / _scriptFor / grading and the
// trainer's PuzzleSolver preconditions, using the very same functions the
// widgets call: positionFromFen, BoardScript.of, legalMoveFromSan.
import 'dart:convert';
import 'dart:io';

import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';
import 'package:karpachess/features/academy/domain/board_script.dart';
import 'package:karpachess/features/academy/domain/skill_map.dart';

Map<String, dynamic> readJson(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final problems = <String>[];
  final notes = <String>[];

  final manifest =
      LessonManifest.fromJson(readJson('assets/data/lessons/index.json'));
  final map = SkillMap.build(manifest);
  final concepts = map.allConcepts.toList();
  stdout.writeln('skill map: ${map.arts.length} arts, '
      '${concepts.length} concepts');

  var beatsTotal = 0;
  for (final concept in concepts) {
    final path = 'assets/data/lessons/en/${concept.lessonFile}';
    if (!File(path).existsSync()) {
      problems.add('${concept.lessonFile}: file missing');
      continue;
    }
    final Lesson lesson;
    try {
      lesson = Lesson.fromJson(readJson(path));
    } catch (e) {
      problems.add('${concept.lessonFile}: Lesson.fromJson threw: $e');
      continue;
    }
    if (lesson.title.isEmpty) problems.add('${concept.lessonFile}: no title');
    if (lesson.steps.isEmpty) {
      problems.add('${concept.lessonFile}: no steps — empty screen');
      continue;
    }

    // _buildBeats: a step whose FEN throws is silently dropped in the app.
    var kept = 0;
    for (var i = 0; i < lesson.steps.length; i++) {
      final step = lesson.steps[i];
      final dynamic position;
      try {
        position = positionFromFen(step.fen);
      } catch (e) {
        problems.add('${concept.lessonFile} step $i: positionFromFen threw '
            '(step silently dropped in app): $e');
        continue;
      }
      kept++;
      switch (step) {
        case TeachStep():
          // _scriptFor runs BoardScript.of at render time — the tools only
          // mirror its rules, so run the real thing.
          try {
            final script = BoardScript.of(position, step.text);
            final chips = extractSanTokens(step.text);
            final drawn = switch (script) {
              MoveMenu(:final moves) => moves.length,
              MoveSequence(:final frames) => frames.length - 1,
            };
            if (chips.isNotEmpty && drawn < chips.length) {
              problems.add('${concept.lessonFile} step $i: '
                  '${chips.length - (drawn < 0 ? 0 : drawn)} of '
                  '${chips.length} chips silently dropped by BoardScript '
                  '(chips: $chips)');
            }
          } catch (e) {
            problems.add('${concept.lessonFile} step $i: BoardScript.of '
                'threw at render: $e');
          }
        case PlayStep():
          if (step.targetSan.isEmpty) {
            notes.add('${concept.lessonFile} step $i: no targetSan '
                '(beat dropped in app)');
          } else if (!step.targetSan
              .any((san) => legalMoveFromSan(position, san) != null)) {
            problems.add('${concept.lessonFile} step $i: NO targetSan is '
                'playable via legalMoveFromSan — beat unwinnable '
                '(${step.targetSan})');
          }
      }
    }
    if (kept == 0) {
      problems.add('${concept.lessonFile}: every step dropped — the app '
          'shows the empty board glyph');
    }
    beatsTotal += kept;

    // Proof: load + replay the full solution the way the OWN beat grades it.
    final proofFile = lesson.proof;
    if (proofFile == null || proofFile.isEmpty) {
      notes.add('${concept.lessonFile}: no proof (no OWN beat)');
    } else {
      final proofPath = 'assets/data/puzzles/en/$proofFile';
      if (!File(proofPath).existsSync()) {
        problems.add('${concept.lessonFile}: proof $proofFile missing');
      } else {
        try {
          final puzzle = Puzzle.fromJson(readJson(proofPath));
          dynamic position = positionFromFen(puzzle.fen);
          for (var i = 0; i < puzzle.solution.length; i++) {
            final move = legalMoveFromSan(position, puzzle.solution[i]);
            if (move == null) {
              problems.add('$proofFile: solution ply $i '
                  '(${puzzle.solution[i]}) not playable via '
                  'legalMoveFromSan');
              break;
            }
            position = position.play(move);
          }
        } catch (e) {
          problems.add('$proofFile: threw while loading/replaying: $e');
        }
      }
    }
  }
  stdout.writeln('lessons: ${concepts.length} loaded, $beatsTotal beats kept');

  // The trainer: every pack puzzle must parse and its ply-0 move must grade.
  final packs =
      PuzzlePackManifest.fromJson(readJson('assets/data/puzzles/packs.json'));
  var trainerOk = 0;
  for (final pack in packs.packs) {
    for (final file in pack.puzzleFiles) {
      final path = 'assets/data/puzzles/en/$file';
      try {
        final puzzle = Puzzle.fromJson(readJson(path));
        dynamic position = positionFromFen(puzzle.fen);
        for (var i = 0; i < puzzle.solution.length; i++) {
          final move = legalMoveFromSan(position, puzzle.solution[i]);
          if (move == null) {
            problems.add('trainer $file: ply $i (${puzzle.solution[i]}) '
                'not playable');
            break;
          }
          position = position.play(move);
        }
        trainerOk++;
      } catch (e) {
        problems.add('trainer $file: threw: $e');
      }
    }
  }
  stdout.writeln('trainer: $trainerOk puzzles replayed');

  for (final n in notes) {
    stdout.writeln('note: $n');
  }
  if (problems.isEmpty) {
    stdout.writeln('APP PIPELINE CLEAN — no runtime loading defects found.');
  } else {
    stdout.writeln('\n${problems.length} PROBLEM(S):');
    for (final p in problems) {
      stdout.writeln('  ✗ $p');
    }
    exitCode = 1;
  }
}
