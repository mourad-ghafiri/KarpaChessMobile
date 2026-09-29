import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';

void main() {
  group('LessonManifest', () {
    test('parses categories with lesson file lists', () {
      final json = jsonDecode('''
      {
        "version": 1,
        "categories": [
          {"id": "basics", "icon": "P", "lessons": ["a.json", "b.json"]},
          {"id": "tactics", "icon": "N", "lessons": []}
        ]
      }
      ''') as Map<String, dynamic>;

      final manifest = LessonManifest.fromJson(json);

      expect(manifest.categories, hasLength(2));
      expect(manifest.categories.first.id, 'basics');
      expect(manifest.categories.first.icon, 'P');
      expect(manifest.categories.first.lessonFiles, ['a.json', 'b.json']);
      expect(manifest.categories.last.lessonFiles, isEmpty);
    });

    test('tolerates missing categories', () {
      final manifest = LessonManifest.fromJson(const {'version': 1});
      expect(manifest.categories, isEmpty);
    });
  });

  group('Lesson', () {
    test('parses teach and play steps', () {
      final json = jsonDecode('''
      {
        "id": "how-pieces-move",
        "title": "How the Pieces Move",
        "summary": "Meet every piece",
        "difficulty": "beginner",
        "steps": [
          {
            "type": "teach",
            "fen": "8/8/8/8/8/8/4P3/4K3 w - - 0 1",
            "title": "The Pawn",
            "text": "Pawns move forward."
          },
          {
            "type": "play",
            "fen": "8/8/8/8/8/8/4P3/4K3 w - - 0 1",
            "prompt": "Push the pawn.",
            "targetSan": ["e4", "e3"],
            "hint": "Two squares on the first move."
          }
        ]
      }
      ''') as Map<String, dynamic>;

      final lesson = Lesson.fromJson(json);

      expect(lesson.id, 'how-pieces-move');
      expect(lesson.title, 'How the Pieces Move');
      expect(lesson.summary, 'Meet every piece');
      expect(lesson.steps, hasLength(2));

      final teach = lesson.steps[0] as TeachStep;
      expect(teach.fen, '8/8/8/8/8/8/4P3/4K3 w - - 0 1');
      expect(teach.title, 'The Pawn');
      expect(teach.text, 'Pawns move forward.');

      final play = lesson.steps[1] as PlayStep;
      expect(play.prompt, 'Push the pawn.');
      expect(play.targetSan, ['e4', 'e3']);
      expect(play.hint, 'Two squares on the first move.');
    });

    test('teach step title and play step hint are optional', () {
      final lesson = Lesson.fromJson(const {
        'id': 'x',
        'title': 't',
        'summary': 's',
        'difficulty': 'beginner',
        'steps': [
          {'type': 'teach', 'fen': 'f', 'text': 'body'},
          {'type': 'play', 'fen': 'f', 'prompt': 'p', 'targetSan': 'e4'},
        ],
      });

      expect((lesson.steps[0] as TeachStep).title, isNull);
      final play = lesson.steps[1] as PlayStep;
      expect(play.hint, isNull);
      expect(play.targetSan, ['e4'], reason: 'bare string is wrapped');
    });

    test('unknown step type throws FormatException', () {
      expect(
        () => LessonStep.fromJson(const {'type': 'quiz', 'fen': 'f'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LessonStep.fromJson(const {'fen': 'f'}),
        throwsA(isA<FormatException>()),
        reason: 'missing type is unknown too',
      );
    });
  });

  group('PuzzleManifest', () {
    test('parses themes', () {
      final json = jsonDecode('''
      {
        "version": 1,
        "themes": [
          {
            "id": "mate-in-1",
            "icon": "Q",
            "difficulty": "beginner",
            "puzzles": ["mate-in-1-01.json"]
          }
        ]
      }
      ''') as Map<String, dynamic>;

      final manifest = PuzzleManifest.fromJson(json);

      expect(manifest.themes, hasLength(1));
      final theme = manifest.themes.single;
      expect(theme.id, 'mate-in-1');
      expect(theme.icon, 'Q');
      expect(theme.difficulty, 'beginner');
      expect(theme.puzzleFiles, ['mate-in-1-01.json']);
    });
  });

  group('Puzzle', () {
    test('parses full puzzle', () {
      final puzzle = Puzzle.fromJson(const {
        'id': 'mate-in-1-01',
        'fen': 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1',
        'solution': ['Qxf7#'],
        'title': "Scholar's Strike",
        'setup': 'Queen and bishop aim at f7.',
        'hint': 'Look at f7.',
        'explanation': 'Classic Scholar\'s Mate.',
      });

      expect(puzzle.id, 'mate-in-1-01');
      expect(puzzle.solution, ['Qxf7#']);
      expect(puzzle.title, "Scholar's Strike");
      expect(puzzle.setup, 'Queen and bishop aim at f7.');
      expect(puzzle.hint, 'Look at f7.');
      expect(puzzle.explanation, "Classic Scholar's Mate.");
    });

    test('optional fields default to null and solution tolerates a string', () {
      final puzzle = Puzzle.fromJson(const {
        'id': 'p',
        'fen': '8/8/8/8/8/8/8/K6k w - - 0 1',
        'solution': 'Kb2',
      });

      expect(puzzle.solution, ['Kb2']);
      expect(puzzle.title, isNull);
      expect(puzzle.setup, isNull);
      expect(puzzle.hint, isNull);
      expect(puzzle.explanation, isNull);
    });
  });
}
