import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_progression_repository.dart';
import '../domain/lesson_progress.dart';
import '../domain/progression.dart';
import '../domain/progression_repository.dart';

final progressionRepositoryProvider = Provider<ProgressionRepository>(
  (ref) => SharedPrefsProgressionRepository(),
);

final progressionControllerProvider =
    NotifierProvider<ProgressionController, ProgressionState>(
        ProgressionController.new);

/// Owns the local XP / streak / completion state. All awards flow through
/// [award] so the streak clock stays consistent.
class ProgressionController extends Notifier<ProgressionState> {
  @override
  bool updateShouldNotify(ProgressionState previous, ProgressionState next) =>
      previous != next;

  /// Injectable for tests.
  DateTime Function() now = DateTime.now;

  @override
  ProgressionState build() => const ProgressionState();

  ProgressionRepository get _repo => ref.read(progressionRepositoryProvider);

  Future<void> restore() async {
    state = await _repo.load() ?? const ProgressionState();
  }

  Future<void> _commit(ProgressionState next) async {
    state = next;
    await _repo.save(next);
  }

  /// Awards XP (updating the streak and daily goal). Returns true when the
  /// award crossed a level boundary — callers fire the level-up celebration.
  Future<bool> award(int amount) async {
    final levelBefore = state.level;
    await _commit(state.award(amount, now()));
    return state.level > levelBefore;
  }


  /// Owns a concept as a pattern (mints it into the SRS on first
  /// completion) and awards its XP in one commit — the full award the
  /// first time, a small replay award afterwards. Returns true on level-up.
  Future<bool> ownPattern(String conceptId) async {
    final levelBefore = state.level;
    final xp = state.ownPatternXp(conceptId);
    final next = state.ownPattern(conceptId, now()).award(xp, now());
    await _commit(next);
    return state.level > levelBefore;
  }

  /// Records a trainer puzzle solve in one commit — the domain decides what
  /// it pays (first attempt: rating + full XP; best-upgrade replay: small
  /// XP; anything else: nothing). Returns whether the award crossed a
  /// level, so the caller can fire the same level-up celebration every
  /// other surface uses.
  Future<bool> solvePuzzle({
    required String puzzleId,
    required int puzzleRating,
    required bool firstTry,
  }) async {
    final levelBefore = state.level;
    await _commit(state.solvePuzzle(
      puzzleId: puzzleId,
      puzzleRating: puzzleRating,
      firstTry: firstTry,
      now: now(),
    ));
    return state.level > levelBefore;
  }

  /// Records a shown solution. A pure rating event on the first attempt,
  /// a no-op afterwards — no XP, so no level-up to report.
  Future<void> failPuzzle({
    required String puzzleId,
    required int puzzleRating,
  }) =>
      _commit(state.failPuzzle(puzzleId: puzzleId, puzzleRating: puzzleRating));

  /// Persists where an unfinished lesson run stands.
  Future<void> saveLessonProgress(String conceptId, LessonProgress progress) =>
      _commit(state.updateLessonProgress(conceptId, progress));

  /// Drops a lesson's saved progress (restart, or content drift).
  Future<void> clearLessonProgress(String conceptId) =>
      _commit(state.clearLessonProgress(conceptId));

  /// Applies a Sharpen review outcome; successful reviews earn XP.
  /// Returns true on level-up.
  Future<bool> reviewPattern(String conceptId, {required bool success}) async {
    final levelBefore = state.level;
    var next = state.reviewPattern(conceptId, success, now());
    if (success) next = next.award(XpRules.patternSharpened, now());
    await _commit(next);
    return state.level > levelBefore;
  }

  Future<void> reset() async {
    await _repo.clear();
    state = const ProgressionState();
  }
}
