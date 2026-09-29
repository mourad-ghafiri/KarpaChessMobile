import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/json/json_read.dart';
import 'package:karpachess/prefs/domain/prefs.dart';
import 'package:karpachess/progression/domain/progression.dart';
import 'package:karpachess/progression/domain/puzzle_rating.dart';

// Stored data outlives the code that wrote it. A wrong-typed field must cost
// that one field — never the whole blob, and never the app at startup.

void main() {
  group('readers', () {
    test('well-typed values read unchanged', () {
      expect(readString('a'), 'a');
      expect(readBool(false), isFalse);
      expect(readInt(7), 7);
      expect(readStringSet(['a', 'b']), {'a', 'b'});
      expect(readIntSet([1, 2]), {1, 2});
      expect(readMap({'k': 1}), {'k': 1});
    });

    test('wrong types read as absent', () {
      expect(readString(3), isNull);
      expect(readBool('true'), isNull);
      expect(readInt('7'), isNull);
      expect(readStringSet('a'), isEmpty);
      expect(readIntSet({'a': 1}), isEmpty);
      expect(readMap([1]), isEmpty);
    });

    test('a JSON number is an int whatever its encoding', () {
      expect(readInt(3.0), 3);
    });

    test('mixed lists keep only the right entries', () {
      expect(readStringSet(['a', 1, null, 'b']), {'a', 'b'});
      expect(readIntSet([1, '2', 3]), {1, 3});
    });
  });

  group('Prefs.fromJson', () {
    test('a wrong-typed field falls back to its default; the rest loads', () {
      const defaults = Prefs();
      final prefs = Prefs.fromJson({
        'appTheme': 42,
        'lang': 'pt',
        'difficulty': 'three',
        'sound': 'yes',
        'timeControlMinutes': 5,
        'lessonsCompleted': ['a', 7, 'b'],
      });
      expect(prefs.appTheme, defaults.appTheme);
      expect(prefs.lang, 'pt');
      expect(prefs.difficulty, defaults.difficulty);
      expect(prefs.sound, defaults.sound);
      expect(prefs.timeControlMinutes, 5);
      expect(prefs.lessonsCompleted, {'a', 'b'});
    });

    test('valid prefs round-trip exactly', () {
      final prefs = const Prefs().copyWith(
        lang: 'ar',
        difficulty: 4,
        timeControlMinutes: () => 10,
        timeControlIncrement: 5,
        playerName: 'Mira',
        lessonsCompleted: {'x', 'y'},
      );
      // Compared as JSON: Prefs == holds its set by identity (the app's
      // field-identity contract), so a decoded copy is never `==`.
      expect(Prefs.fromJson(prefs.toJson()).toJson(), prefs.toJson());
    });
  });

  group('ProgressionState.fromJson', () {
    test('wrong-typed fields fall back; valid ones load', () {
      final state = ProgressionState.fromJson({
        'xp': '1200',
        'streakDays': 3,
        'puzzleRating': 1234.0,
        'puzzleResults': ['not', 'a', 'map'],
        'completedNodes': 'n',
        'lessonProgress': {
          'lesson-a': {'b': 2, 'n': '5', 's': [0, '1'], 'a': null},
          'lesson-b': 'not a map',
        },
        'patterns': {
          'pattern-a': {'i': 1, 'd': 'soon'},
        },
      });
      expect(state.xp, 0);
      expect(state.streakDays, 3);
      expect(state.puzzleRating, 1234);
      expect(state.puzzleResults, isEmpty);
      expect(state.completedNodes, isEmpty);
      final progress = state.lessonProgress['lesson-a']!;
      expect(progress.beat, 2);
      expect(progress.beatCount, 0);
      expect(progress.solvedBeats, {0});
      expect(progress.awardedBeats, isEmpty);
      expect(state.lessonProgress.containsKey('lesson-b'), isFalse);
      expect(state.patterns['pattern-a']!.intervalIndex, 1);
      expect(state.patterns['pattern-a']!.dueDay, 0);
    });

    test('an empty record reads as a fresh one', () {
      final state = ProgressionState.fromJson(const {});
      expect(state.xp, 0);
      expect(state.puzzleRating, PuzzleRating.initial);
    });
  });
}
