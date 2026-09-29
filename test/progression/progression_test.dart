import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/progression/domain/srs_scheduler.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/domain/lesson_progress.dart';
import 'package:karpachess/progression/domain/progression.dart';
import 'package:karpachess/progression/domain/progression_repository.dart';
import 'package:karpachess/progression/domain/puzzle_outcome.dart';
import 'package:karpachess/progression/domain/puzzle_rating.dart';

/// In-memory persistence double for controller-level tests.
class MemoryProgressionRepository implements ProgressionRepository {
  ProgressionState? stored;

  @override
  Future<ProgressionState?> load() async => stored;

  @override
  Future<void> save(ProgressionState state) async => stored = state;

  @override
  Future<void> clear() async => stored = null;
}

void main() {
  group('XpRules level curve', () {
    test('thresholds are triangular', () {
      expect(XpRules.xpToReach(0), 0);
      expect(XpRules.xpToReach(1), 100);
      expect(XpRules.xpToReach(2), 300);
      expect(XpRules.xpToReach(3), 600);
      expect(XpRules.xpToReach(4), 1000);
    });

    test('levelFor boundaries', () {
      expect(XpRules.levelFor(0), 0);
      expect(XpRules.levelFor(99), 0);
      expect(XpRules.levelFor(100), 1);
      expect(XpRules.levelFor(299), 1);
      expect(XpRules.levelFor(300), 2);
      expect(XpRules.levelFor(600), 3);
    });
  });

  group('streak', () {
    final monday = DateTime(2026, 8, 10, 21, 30);

    test('first activity starts a 1-day streak', () {
      final s = const ProgressionState().award(10, monday);
      expect(s.streakDays, 1);
      expect(s.xp, 10);
      expect(s.streakAt(monday), 1);
    });

    test('same-day activity keeps the streak', () {
      final s = const ProgressionState()
          .award(10, monday)
          .award(10, monday.add(const Duration(hours: 2)));
      expect(s.streakDays, 1);
      expect(s.xp, 20);
    });

    test('consecutive day extends, including across midnight', () {
      final lateNight = DateTime(2026, 8, 10, 23, 59);
      final nextMorning = DateTime(2026, 8, 11, 0, 10);
      final s = const ProgressionState()
          .award(10, lateNight)
          .award(10, nextMorning);
      expect(s.streakDays, 2);
    });

    test('a missed day resets to 1', () {
      final s = const ProgressionState()
          .award(10, monday)
          .award(10, monday.add(const Duration(days: 3)));
      expect(s.streakDays, 1);
    });

    test('streakAt reports 0 when broken, without mutating', () {
      final s = const ProgressionState().award(10, monday);
      expect(s.streakAt(monday.add(const Duration(days: 1))), 1);
      expect(s.streakAt(monday.add(const Duration(days: 2))), 0);
      expect(s.streakDays, 1);
    });
  });

  group('level progress and nodes', () {
    test('levelProgress interpolates within the level', () {
      const s = ProgressionState(xp: 200); // level 1: 100..300
      expect(s.level, 1);
      expect(s.levelProgress, closeTo(0.5, 0.001));
    });

    test('json round-trip', () {
      final s = const ProgressionState()
          .award(120, DateTime(2026, 8, 15))
          .ownPattern('concept:a', DateTime(2026, 8, 15))
          .solvePuzzle(
            puzzleId: 'p1',
            puzzleRating: 900,
            firstTry: true,
            now: DateTime(2026, 8, 15),
          )
          .failPuzzle(puzzleId: 'p2', puzzleRating: 900)
          .updateLessonProgress(
            'concept:b',
            LessonProgress(
              beat: 3,
              beatCount: 7,
              solvedBeats: const {1, 3},
              awardedBeats: const {0, 1, 3},
            ),
          );
      final back = ProgressionState.fromJson(s.toJson());
      expect(back.xp, s.xp);
      expect(back.streakDays, s.streakDays);
      expect(back.lastActiveDay, s.lastActiveDay);
      expect(back.completedNodes, s.completedNodes);
      expect(back.puzzleRating, s.puzzleRating);
      expect(back.puzzleResults, s.puzzleResults);
      expect(back.lessonProgress, s.lessonProgress);
      expect(back.lessonProgress['concept:b']!.completion,
          closeTo(4 / 7, 0.001));
    });
  });

  group('daily goal', () {
    final day1 = DateTime(2026, 8, 15, 9);
    final day2 = DateTime(2026, 8, 16, 9);

    test('xpToday accumulates within a day and resets on rollover', () {
      var s = const ProgressionState().award(10, day1).award(15, day1);
      expect(s.xpToday, 25);
      expect(s.xpTodayAt(day1), 25);
      expect(s.xpTodayAt(day2), 0);
      s = s.award(5, day2);
      expect(s.xpToday, 5);
    });
  });

  group('patterns and SRS', () {
    final day1 = DateTime(2026, 8, 15, 9);

    test('owning mints a due-tomorrow mastery and marks the concept', () {
      final s = const ProgressionState()
          .ownPattern('concept:basics-01.json', day1);
      expect(s.completedNodes, contains('concept:basics-01.json'));
      final m = s.patterns['concept:basics-01.json']!;
      expect(m.stars, 0);
      expect(m.dueDay, PatternMastery.epochDay(day1) + 1);
      // Owning again never resets mastery.
      final again = s.ownPattern('concept:basics-01.json', day1.add(const Duration(days: 9)));
      expect(again.patterns['concept:basics-01.json']!.dueDay, m.dueDay);
    });

    test('ownPatternXp pays the mint award once, then the replay award', () {
      const fresh = ProgressionState();
      expect(fresh.ownPatternXp('c'), XpRules.patternOwned);

      final owned = fresh.ownPattern('c', day1);
      expect(owned.ownPatternXp('c'), XpRules.patternReplayed);

      // Replaying never touches the existing mastery.
      final replayed =
          owned.ownPattern('c', day1.add(const Duration(days: 9)));
      expect(replayed.patterns['c']!.dueDay, owned.patterns['c']!.dueDay);
      expect(replayed.patterns['c']!.intervalIndex,
          owned.patterns['c']!.intervalIndex);
      expect(replayed.completedNodes, owned.completedNodes);
    });

    test('successful reviews climb the interval ladder to gold', () {
      var s = const ProgressionState().ownPattern('c', day1);
      var day = day1;
      for (final expectedStars in [1, 2, 3, 3]) {
        day = day.add(const Duration(days: 30));
        s = s.reviewPattern('c', true, day);
        expect(s.patterns['c']!.stars, expectedStars);
      }
      expect(
        s.patterns['c']!.dueDay,
        PatternMastery.epochDay(day) + SrsScheduler.intervalsDays.last,
      );
    });

    test('a failed review drops one interval and is due tomorrow', () {
      var s = const ProgressionState().ownPattern('c', day1);
      var day = day1.add(const Duration(days: 2));
      s = s.reviewPattern('c', true, day); // -> stars 1
      day = day.add(const Duration(days: 5));
      s = s.reviewPattern('c', false, day);
      final m = s.patterns['c']!;
      expect(m.stars, 0);
      expect(m.dueDay, PatternMastery.epochDay(day) + 1);
    });

    test('duePatterns lists only due ones; json round-trips mastery', () {
      final s = const ProgressionState()
          .ownPattern('a', day1)
          .ownPattern('b', day1)
          .reviewPattern('b', true, day1.add(const Duration(days: 1)));
      final dayAfter = day1.add(const Duration(days: 1, hours: 3));
      expect(s.duePatterns(dayAfter), ['a']);
      final back = ProgressionState.fromJson(s.toJson());
      expect(back.patterns.length, 2);
      expect(back.patterns['b']!.stars, 1);
      expect(back.duePatterns(dayAfter), ['a']);
    });
  });

  group('puzzle outcomes', () {
    final day = DateTime(2026, 8, 15, 9);

    test('first-attempt flawless solve pays full XP and moves the rating up',
        () {
      final s = const ProgressionState().solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: true,
        now: day,
      );
      // Equal ratings, K=40, score 1.0 → +20.
      expect(s.puzzleRating, PuzzleRating.initial + 20);
      expect(s.puzzleResults['p'], PuzzleOutcome.flawless);
      expect(s.xp, XpRules.puzzleSolved(800));
      expect(s.streakDays, 1);
    });

    test('first-attempt solve after a miss pays two thirds and half a point',
        () {
      final s = const ProgressionState().solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: false,
        now: day,
      );
      // Equal ratings, K=40, score 0.5 → no movement.
      expect(s.puzzleRating, PuzzleRating.initial);
      expect(s.puzzleResults['p'], PuzzleOutcome.solved);
      expect(s.xp, XpRules.puzzleSolvedAfterMiss(800));
    });

    test('failPuzzle on the first attempt drops the rating, pays nothing',
        () {
      final s = const ProgressionState()
          .failPuzzle(puzzleId: 'p', puzzleRating: 800);
      // Equal ratings, K=40, score 0 → -20.
      expect(s.puzzleRating, PuzzleRating.initial - 20);
      expect(s.puzzleResults['p'], PuzzleOutcome.failed);
      expect(s.xp, 0);
      expect(s.streakDays, 0);
      expect(s.xpToday, 0);
    });

    test('a replay never moves the rating; beating the best mints upgrade XP',
        () {
      final failed = const ProgressionState()
          .failPuzzle(puzzleId: 'p', puzzleRating: 800);
      final solved = failed.solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: false,
        now: day,
      );
      expect(solved.puzzleRating, failed.puzzleRating);
      expect(solved.puzzleResults['p'], PuzzleOutcome.solved);
      expect(solved.xp, XpRules.puzzleUpgraded(800));

      final flawless = solved.solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: true,
        now: day,
      );
      expect(flawless.puzzleRating, failed.puzzleRating);
      expect(flawless.puzzleResults['p'], PuzzleOutcome.flawless);
      expect(flawless.xp, XpRules.puzzleUpgraded(800) * 2);
    });

    test('a best never downgrades and a settled result is identity', () {
      final flawless = const ProgressionState().solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: true,
        now: day,
      );
      final replayedWorse = flawless.solvePuzzle(
        puzzleId: 'p',
        puzzleRating: 800,
        firstTry: false,
        now: day,
      );
      expect(identical(replayedWorse, flawless), isTrue);
      final failedAfter =
          flawless.failPuzzle(puzzleId: 'p', puzzleRating: 800);
      expect(identical(failedAfter, flawless), isTrue);
    });

    test('the K factor counts resolved first attempts, fails included', () {
      var s = const ProgressionState();
      for (var i = 0; i < 10; i++) {
        s = s.failPuzzle(puzzleId: 'p$i', puzzleRating: s.puzzleRating);
      }
      expect(s.puzzleResults.length, 10);
      // The 11th attempt sees K=24, not 40: equal ratings, score 1 → +12.
      final before = s.puzzleRating;
      s = s.solvePuzzle(
        puzzleId: 'p10',
        puzzleRating: before,
        firstTry: true,
        now: day,
      );
      expect(s.puzzleRating, before + 12);
    });
  });

  group('lesson progress', () {
    final day = DateTime(2026, 8, 15, 9);
    final record = LessonProgress(
      beat: 2,
      beatCount: 5,
      solvedBeats: const {1},
      awardedBeats: const {0, 1},
    );

    test('update stores the record; clear drops it', () {
      final s = const ProgressionState().updateLessonProgress('c', record);
      expect(s.lessonProgress['c'], record);
      final cleared = s.clearLessonProgress('c');
      expect(cleared.lessonProgress, isEmpty);
      // Clearing what is not there changes nothing.
      expect(identical(cleared.clearLessonProgress('c'), cleared), isTrue);
    });

    test('owning the pattern supersedes and drops the record', () {
      final s = const ProgressionState()
          .updateLessonProgress('c', record)
          .ownPattern('c', day);
      expect(s.completedNodes, contains('c'));
      expect(s.lessonProgress, isEmpty);
    });

    test('completion is the header-bar fraction', () {
      expect(record.completion, closeTo(3 / 5, 0.001));
      expect(
        LessonProgress(
          beat: 0,
          beatCount: 0,
          solvedBeats: const {},
          awardedBeats: const {},
        ).completion,
        0,
      );
    });
  });

  group('ProgressionController.ownPattern', () {
    test('first own = mint + 60 XP; replay = 10 XP, mastery untouched',
        () async {
      final container = ProviderContainer(overrides: [
        progressionRepositoryProvider
            .overrideWithValue(MemoryProgressionRepository()),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(progressionControllerProvider.notifier);
      controller.now = () => DateTime(2026, 8, 15, 9);

      await controller.ownPattern('c');
      final first = container.read(progressionControllerProvider);
      expect(first.xp, XpRules.patternOwned);
      expect(first.completedNodes, contains('c'));
      final minted = first.patterns['c']!;
      expect(minted.stars, 0);

      controller.now = () => DateTime(2026, 8, 24, 9);
      await controller.ownPattern('c');
      final second = container.read(progressionControllerProvider);
      expect(second.xp, XpRules.patternOwned + XpRules.patternReplayed);
      expect(second.completedNodes, contains('c'));
      expect(second.patterns['c']!.dueDay, minted.dueDay);
    });
  });
}
