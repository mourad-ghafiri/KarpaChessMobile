import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/application/content_providers.dart';
import '../../../content/domain/models.dart';
import '../../../progression/application/progression_controller.dart';
import '../domain/skill_map.dart';

/// The academy curriculum, built deterministically from the two content
/// manifests. Loaded once; every academy screen hangs off this.
final skillMapProvider = FutureProvider<SkillMap>((ref) async {
  final lessons = await ref.watch(lessonManifestProvider.future);
  return SkillMap.build(lessons);
});

/// The lesson behind one concept. Null for unknown concept ids.
final conceptLessonProvider =
    FutureProvider.family<Lesson?, String>((ref, conceptId) async {
  final map = await ref.watch(skillMapProvider.future);
  final concept = map.conceptById(conceptId);
  if (concept == null) return null;
  return ref.watch(contentRepositoryProvider).lesson(concept.lessonFile);
});

/// The one puzzle that proves a concept — its OWN beat. The lesson names it,
/// so a proof can be chosen because it matches the lesson rather than because
/// of where it fell in a pool. An unreadable file yields no proof rather than
/// failing the lesson.
final conceptProofProvider =
    FutureProvider.family<Puzzle?, String>((ref, conceptId) async {
  final lesson = await ref.watch(conceptLessonProvider(conceptId).future);
  final file = lesson?.proof;
  if (file == null || file.isEmpty) return null;
  try {
    return await ref.watch(contentRepositoryProvider).puzzle(file);
  } catch (_) {
    return null;
  }
});

/// The concept's signature position for Pattern Book / art thumbnails:
/// first PlayStep FEN, else first TeachStep FEN, else first proof FEN.
final conceptKeyFenProvider =
    FutureProvider.family<String?, String>((ref, conceptId) async {
  final lesson = await ref.watch(conceptLessonProvider(conceptId).future);
  if (lesson != null) {
    for (final step in lesson.steps) {
      if (step is PlayStep && step.fen.isNotEmpty) return step.fen;
    }
    for (final step in lesson.steps) {
      if (step is TeachStep && step.fen.isNotEmpty) return step.fen;
    }
  }
  final proof = await ref.watch(conceptProofProvider(conceptId).future);
  if (proof != null && proof.fen.isNotEmpty) return proof.fen;
  return null;
});

/// One quick-fire Sharpen position: play any of [answers] from [fen].
class SharpenChallenge {
  const SharpenChallenge({
    required this.conceptId,
    required this.fen,
    required this.answers,
    this.prompt = '',
  });

  final String conceptId;
  final String fen;

  /// Accepted SAN answers (check/mate suffixes ignored on comparison).
  final List<String> answers;

  /// The author's framing of the position: a puzzle's `setup`, or a play
  /// step's `prompt`. Shown under "Find the move" because many review
  /// positions — openings, plans, notation, castling — have more than one
  /// good move, and only this sentence says which one is being asked for.
  /// It never contains the answer (lint rule P02 for setups, L-rules for
  /// prompts). Empty when there is nothing to show.
  final String prompt;

  @override
  bool operator ==(Object other) =>
      other is SharpenChallenge &&
      other.conceptId == conceptId &&
      other.fen == fen &&
      other.prompt == prompt &&
      _sameAnswers(other.answers, answers);

  @override
  int get hashCode =>
      Object.hash(conceptId, fen, prompt, Object.hashAll(answers));
}

bool _sameAnswers(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Every puzzle belonging to an art, in manifest order.
///
/// With one proof per concept, many of the 201 teaching puzzles are surplus —
/// 101 of them — and this is where they earn their keep: as extra review
/// material so a pattern is not reviewed on the same position forever.
final artReviewPoolProvider =
    FutureProvider.family<List<String>, String>((ref, artId) async {
  final manifest = await ref.watch(puzzleManifestProvider.future);
  return [
    for (final theme in manifest.themes)
      if (puzzleThemeArt[theme.id] == artId) ...theme.puzzleFiles,
  ];
});

/// The position a concept is reviewed on.
///
/// **Never the lesson's first play step** on an ordinary review, because
/// `conceptKeyFenProvider` uses that same step for the Pattern Book and
/// art-row thumbnails — reviewing it meant staring at the answer position in
/// the grid, tapping "Review now", and being asked to find the move in the
/// position you had just been looking at.
///
/// The first review uses the concept's proof; later reviews rotate through
/// its art's pool, so a pattern reviewed ten times is ten positions. The play
/// step survives only as a fallback for a concept with no proof at all.
final sharpenChallengeProvider =
    FutureProvider.family<SharpenChallenge?, String>((ref, conceptId) async {
  final repo = ref.watch(contentRepositoryProvider);

  Future<SharpenChallenge?> from(Puzzle? puzzle) async {
    if (puzzle == null ||
        puzzle.fen.isEmpty ||
        puzzle.solution.isEmpty) {
      return null;
    }
    return SharpenChallenge(
      conceptId: conceptId,
      fen: puzzle.fen,
      answers: [puzzle.solution.first],
      prompt: puzzle.setup ?? '',
    );
  }

  // How many times this pattern has been reviewed successfully; 0 on the
  // first visit, which is the proof.
  final rounds = ref.watch(
    progressionControllerProvider
        .select((p) => p.patterns[conceptId]?.intervalIndex ?? 0),
  );

  if (rounds > 0) {
    final map = await ref.watch(skillMapProvider.future);
    final artId = map.conceptById(conceptId)?.artId;
    if (artId != null) {
      final pool = await ref.watch(artReviewPoolProvider(artId).future);
      if (pool.isNotEmpty) {
        // Offset by the concept id so two patterns in one art do not march
        // through the pool in lockstep.
        final index = (conceptId.hashCode.abs() + rounds) % pool.length;
        try {
          final rotated = await from(await repo.puzzle(pool[index]));
          if (rotated != null) return rotated;
        } catch (_) {
          // Fall through to the proof.
        }
      }
    }
  }

  final proof = await from(
    await ref.watch(conceptProofProvider(conceptId).future),
  );
  if (proof != null) return proof;

  final lesson = await ref.watch(conceptLessonProvider(conceptId).future);
  for (final step in lesson?.steps ?? const <LessonStep>[]) {
    if (step is PlayStep && step.fen.isNotEmpty && step.targetSan.isNotEmpty) {
      return SharpenChallenge(
        conceptId: conceptId,
        fen: step.fen,
        answers: step.targetSan,
        prompt: step.prompt,
      );
    }
  }
  return null;
});

