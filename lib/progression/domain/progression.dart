import '../../core/json/json_read.dart';
import 'lesson_progress.dart';
import 'puzzle_outcome.dart';
import 'puzzle_rating.dart';
import 'srs_scheduler.dart';

/// XP award table and the level curve. One place, no magic numbers elsewhere.
abstract final class XpRules {
  static const teachStep = 5;
  static const playStep = 10;

  /// A proof puzzle solved unaided — the hardest beat in a lesson, and the
  /// only one that used to pay nothing at all.
  static const proofStep = 15;

  /// Win XP per engine difficulty level (1..4).
  static const winByDifficulty = {1: 15, 2: 30, 3: 60, 4: 100};

  /// XP for owning a concept as a pattern (SEE→PLAY→OWN completed).
  static const patternOwned = 60;

  /// XP for replaying an already-owned concept's lesson (no re-mint).
  static const patternReplayed = 10;

  /// XP per successful Sharpen review.
  static const patternSharpened = 15;

  /// XP for a trainer puzzle, by the puzzle's own rating band — a 1900
  /// puzzle is not worth what a 700 one is. Solved after a wrong move pays
  /// [puzzleSolvedAfterMiss] instead.
  static int puzzleSolved(int puzzleRating) {
    if (puzzleRating < 900) return 10;
    if (puzzleRating < 1200) return 15;
    if (puzzleRating < 1500) return 20;
    if (puzzleRating < 1800) return 30;
    return 40;
  }

  /// Found, but not first time. Two thirds, rounded down.
  static int puzzleSolvedAfterMiss(int puzzleRating) =>
      (puzzleSolved(puzzleRating) * 2) ~/ 3;

  /// A replay that raised the puzzle's stored best. One third of the solve
  /// award — small enough that grinding replays never rivals fresh puzzles,
  /// while still feeding the same daily ring.
  static int puzzleUpgraded(int puzzleRating) =>
      puzzleSolved(puzzleRating) ~/ 3;

  /// The daily XP goal shown as a ring on the academy home.
  static const dailyGoalXp = 50;

  /// Total XP needed to *reach* [level] (level 0 = 0, 1 = 100, 2 = 300,
  /// 3 = 600 ... triangular curve: each level costs 100 more than the last).
  static int xpToReach(int level) => 50 * level * (level + 1);

  static int levelFor(int xp) {
    var level = 0;
    while (xpToReach(level + 1) <= xp) {
      level++;
    }
    return level;
  }
}

/// Immutable local progression: XP, daily streak, daily goal/quest,
/// completed journey nodes.
class ProgressionState {
  const ProgressionState({
    this.xp = 0,
    this.streakDays = 0,
    this.lastActiveDay,
    this.xpToday = 0,
    this.completedNodes = const {},
    this.patterns = const {},
    this.puzzleRating = PuzzleRating.initial,
    this.puzzleResults = const {},
    this.lessonProgress = const {},
  });

  final int xp;
  final int streakDays;

  /// Local calendar day of the last XP-earning action, as 'yyyy-MM-dd'.
  final String? lastActiveDay;

  /// XP earned on [lastActiveDay] (the daily-goal counter).
  final int xpToday;

  /// Owned concept ids (`concept:{lesson file}`).
  final Set<String> completedNodes;

  /// SRS mastery per owned pattern, keyed by concept id.
  final Map<String, PatternMastery> patterns;

  /// The trainer rating. Separate from [xp] on purpose: XP measures how much
  /// you have done, the rating measures how hard what you can do is.
  final int puzzleRating;

  /// The best outcome each attempted trainer puzzle has ever produced.
  /// A key's presence means the rating already moved for that puzzle; the
  /// value only ever upgrades (failed → solved → flawless), never down.
  final Map<String, PuzzleOutcome> puzzleResults;

  /// Unfinished lesson runs, keyed by concept id — cleared when the lesson
  /// is owned. Feeds the card's progress bar and the player's resume.
  final Map<String, LessonProgress> lessonProgress;

  /// Puzzle ids whose best outcome counts as solved (failed ones stay
  /// servable — retrying them is the point).
  Set<String> get solvedPuzzleIds => {
        for (final entry in puzzleResults.entries)
          if (entry.value.isSolved) entry.key,
      };

  int get level => XpRules.levelFor(xp);

  /// 0..1 progress from the current level to the next.
  double get levelProgress {
    final floor = XpRules.xpToReach(level);
    final ceiling = XpRules.xpToReach(level + 1);
    return (xp - floor) / (ceiling - floor);
  }

  static String dayKey(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  /// Awards [amount] XP at [now], updating the daily streak (same day keeps
  /// it, consecutive day extends it, a gap resets to 1) and the daily-goal
  /// counter (resets when the day changes).
  ProgressionState award(int amount, DateTime now) {
    final today = dayKey(now);
    final int streak;
    if (lastActiveDay == today) {
      streak = streakDays == 0 ? 1 : streakDays;
    } else if (lastActiveDay == dayKey(now.subtract(const Duration(days: 1)))) {
      streak = streakDays + 1;
    } else {
      streak = 1;
    }
    return copyWith(
      xp: xp + amount,
      streakDays: streak,
      lastActiveDay: () => today,
      xpToday: (lastActiveDay == today ? xpToday : 0) + amount,
    );
  }

  /// The daily-goal counter as seen at [now]: 0 once the day rolls over.
  int xpTodayAt(DateTime now) =>
      lastActiveDay == dayKey(now) ? xpToday : 0;

  /// Pattern ids due for sharpening at [now].
  List<String> duePatterns(DateTime now) {
    final today = PatternMastery.epochDay(now);
    return [
      for (final entry in patterns.entries)
        if (entry.value.isDue(today)) entry.key,
    ];
  }

  /// Mints a newly owned pattern into the SRS. Owning an already-owned
  /// pattern is idempotent: the existing mastery is left untouched. Any
  /// in-lesson progress record is superseded by ownership and dropped.
  ProgressionState ownPattern(String conceptId, DateTime now) => copyWith(
        completedNodes: {...completedNodes, conceptId},
        patterns: {
          ...patterns,
          conceptId: patterns[conceptId] ??
              SrsScheduler.mint(PatternMastery.epochDay(now)),
        },
        lessonProgress: lessonProgress.containsKey(conceptId)
            ? ({...lessonProgress}..remove(conceptId))
            : lessonProgress,
      );

  /// Records where an unfinished lesson run stands (resume point + solved
  /// and awarded beats). No XP moves here — awards flow through [award].
  ProgressionState updateLessonProgress(
          String conceptId, LessonProgress progress) =>
      copyWith(lessonProgress: {...lessonProgress, conceptId: progress});

  /// Drops a lesson's progress record (restart, or content drift).
  ProgressionState clearLessonProgress(String conceptId) =>
      lessonProgress.containsKey(conceptId)
          ? copyWith(
              lessonProgress: {...lessonProgress}..remove(conceptId))
          : this;

  /// XP due for completing this concept's run right now: the full mint
  /// award the first time, a small replay award afterwards (no farming).
  int ownPatternXp(String conceptId) => patterns.containsKey(conceptId)
      ? XpRules.patternReplayed
      : XpRules.patternOwned;

  /// Applies a Sharpen review result.
  ProgressionState reviewPattern(
    String conceptId,
    bool success,
    DateTime now,
  ) {
    final mastery = patterns[conceptId];
    if (mastery == null) return this;
    final today = PatternMastery.epochDay(now);
    return copyWith(patterns: {
      ...patterns,
      conceptId: success
          ? SrsScheduler.reviewSuccess(mastery, today)
          : SrsScheduler.reviewFail(mastery, today),
    });
  }

  /// The streak the user *sees* at [now]: broken (0) when the last activity
  /// is older than yesterday.
  int streakAt(DateTime now) {
    final last = lastActiveDay;
    if (last == null) return 0;
    if (last == dayKey(now) ||
        last == dayKey(now.subtract(const Duration(days: 1)))) {
      return streakDays;
    }
    return 0;
  }

  ProgressionState copyWith({
    int? xp,
    int? streakDays,
    String? Function()? lastActiveDay,
    int? xpToday,
    Set<String>? completedNodes,
    Map<String, PatternMastery>? patterns,
    int? puzzleRating,
    Map<String, PuzzleOutcome>? puzzleResults,
    Map<String, LessonProgress>? lessonProgress,
  }) {
    return ProgressionState(
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDay:
          lastActiveDay != null ? lastActiveDay() : this.lastActiveDay,
      xpToday: xpToday ?? this.xpToday,
      completedNodes: completedNodes ?? this.completedNodes,
      patterns: patterns ?? this.patterns,
      puzzleRating: puzzleRating ?? this.puzzleRating,
      puzzleResults: puzzleResults ?? this.puzzleResults,
      lessonProgress: lessonProgress ?? this.lessonProgress,
    );
  }

  /// Records a trainer puzzle solve. The outcome map decides what it pays:
  /// the rating moves only on a puzzle's first-ever attempt (no stored
  /// outcome yet), full XP mints with it, and a replay pays the small
  /// upgrade award only when it beats the stored best — so replaying is
  /// worth doing but never farmable. XP flows into the SAME pool the
  /// lessons feed, which is what makes level, rank, streak and the daily
  /// ring one score across the whole app rather than two.
  ProgressionState solvePuzzle({
    required String puzzleId,
    required int puzzleRating,
    required bool firstTry,
    required DateTime now,
  }) {
    final achieved = firstTry ? PuzzleOutcome.flawless : PuzzleOutcome.solved;
    final prior = puzzleResults[puzzleId];
    if (prior == null) {
      // Replaced, never mutated — `==` compares these by identity.
      return copyWith(
        puzzleRating: PuzzleRating.updated(
          player: this.puzzleRating,
          puzzle: puzzleRating,
          solved: true,
          firstTry: firstTry,
          solvedCount: puzzleResults.length,
        ),
        puzzleResults: {...puzzleResults, puzzleId: achieved},
      ).award(
        firstTry
            ? XpRules.puzzleSolved(puzzleRating)
            : XpRules.puzzleSolvedAfterMiss(puzzleRating),
        now,
      );
    }
    if (!achieved.improvesOn(prior)) return this;
    return copyWith(puzzleResults: {...puzzleResults, puzzleId: achieved})
        .award(XpRules.puzzleUpgraded(puzzleRating), now);
  }

  /// Records a shown solution. On a puzzle's first attempt this is a loss:
  /// the rating drops and the outcome is stored as failed — retryable, and
  /// still servable by the streams. It pays no XP and ticks neither the
  /// streak nor the daily ring. Once any outcome exists this is a no-op:
  /// the rating is settled and a best never goes down.
  ProgressionState failPuzzle({
    required String puzzleId,
    required int puzzleRating,
  }) {
    if (puzzleResults.containsKey(puzzleId)) return this;
    return copyWith(
      puzzleRating: PuzzleRating.updated(
        player: this.puzzleRating,
        puzzle: puzzleRating,
        solved: false,
        firstTry: false,
        solvedCount: puzzleResults.length,
      ),
      puzzleResults: {...puzzleResults, puzzleId: PuzzleOutcome.failed},
    );
  }

  /// Field-wise equality with identity for the collections — all of them
  /// are replaced, never mutated, so identity is exact change detection and
  /// `.select` guards actually short-circuit.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressionState &&
          other.xp == xp &&
          other.streakDays == streakDays &&
          other.lastActiveDay == lastActiveDay &&
          other.xpToday == xpToday &&
          identical(other.completedNodes, completedNodes) &&
          identical(other.patterns, patterns) &&
          other.puzzleRating == puzzleRating &&
          identical(other.puzzleResults, puzzleResults) &&
          identical(other.lessonProgress, lessonProgress);

  @override
  int get hashCode => Object.hash(xp, streakDays, lastActiveDay, xpToday,
      identityHashCode(completedNodes), identityHashCode(patterns),
      puzzleRating, identityHashCode(puzzleResults),
      identityHashCode(lessonProgress));

  Map<String, Object?> toJson() => {
        'xp': xp,
        'streakDays': streakDays,
        'lastActiveDay': lastActiveDay,
        'xpToday': xpToday,
        'puzzleRating': puzzleRating,
        'puzzleResults': {
          for (final entry in puzzleResults.entries)
            entry.key: entry.value.toJson(),
        },
        'completedNodes': completedNodes.toList(),
        'patterns': {
          for (final entry in patterns.entries)
            entry.key: entry.value.toJson(),
        },
        'lessonProgress': {
          for (final entry in lessonProgress.entries)
            entry.key: entry.value.toJson(),
        },
      };

  /// Tolerant: a field of the wrong type falls back to its own default (see
  /// `json_read.dart`), so one bad field never costs the learner's whole
  /// record.
  factory ProgressionState.fromJson(Map<String, Object?> json) {
    return ProgressionState(
      xp: readInt(json['xp']) ?? 0,
      streakDays: readInt(json['streakDays']) ?? 0,
      lastActiveDay: readString(json['lastActiveDay']),
      xpToday: readInt(json['xpToday']) ?? 0,
      puzzleRating: readInt(json['puzzleRating']) ?? PuzzleRating.initial,
      puzzleResults: {
        for (final entry in readMap(json['puzzleResults']).entries)
          if (entry.key is String && PuzzleOutcome.fromJson(entry.value) != null)
            entry.key as String: PuzzleOutcome.fromJson(entry.value)!,
      },
      completedNodes: readStringSet(json['completedNodes']),
      patterns: {
        for (final entry in readMap(json['patterns']).entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: PatternMastery.fromJson(
                (entry.value as Map).cast<String, Object?>()),
      },
      lessonProgress: {
        for (final entry in readMap(json['lessonProgress']).entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: LessonProgress.fromJson(
                (entry.value as Map).cast<String, Object?>()),
      },
    );
  }
}
