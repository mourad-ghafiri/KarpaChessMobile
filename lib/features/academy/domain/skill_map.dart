import '../../../content/domain/models.dart';

/// Puzzle theme → art.
///
/// A lesson names its own proof (`Lesson.proof`), so this no longer decides
/// which puzzle proves which concept. It builds each art's **review pool**:
/// the surplus puzzles Sharpen rotates through so a pattern is not reviewed
/// on the same position forever.
const Map<String, String> puzzleThemeArt = {
  'first-steps': 'basics',
  'mate-in-1': 'basics',
  'forks': 'tactics',
  'pins-skewers': 'tactics',
  'discovered': 'tactics',
  'tactics-mix': 'tactics',
  'back-rank': 'attack',
  'mate-in-2': 'attack',
  'endgame': 'endgames',
  'openings': 'openings',
  'endgames': 'endgames',
  'strategy': 'strategy',
  'history': 'history',
  'culture': 'culture',
};

/// The eight Arts of the academy, in curriculum order, keyed by the lesson
/// category ids they are built from.
///
/// This list — not the manifest — is what the academy grid and the Continue
/// button follow. A category missing from here is invisible in the app; an id
/// here with no manifest category is skipped silently.
///
/// Tactics deliberately precedes openings: below master level games are
/// decided by tactics, not by opening theory. `history` sits second so the
/// learner meets the story of the game right after learning the rules, and
/// `culture` closes the curriculum with everything that is not a move.
const artOrder = [
  'basics',
  'history',
  'tactics',
  'openings',
  'endgames',
  'strategy',
  'attack',
  'culture',
];

/// One learnable concept: SEE it (teach steps) → PLAY it (play steps) →
/// OWN it (proof puzzles). Owning mints the concept as a Pattern.
class Concept {
  const Concept({
    required this.id,
    required this.artId,
    required this.lessonFile,
  });

  /// Stable id: `concept:{lesson file name}`.
  final String id;
  final String artId;
  final String lessonFile;

  @override
  bool operator ==(Object other) =>
      other is Concept &&
      other.id == id &&
      other.artId == artId &&
      other.lessonFile == lessonFile;

  @override
  int get hashCode => Object.hash(id, artId, lessonFile);
}

/// One art: an ordered run of concepts sharing a category.
class Art {
  const Art({required this.id, required this.icon, required this.concepts});

  final String id;
  final String icon;
  final List<Concept> concepts;

  /// 0..1 owned fraction given the set of owned concept ids.
  double progress(Set<String> owned) => concepts.isEmpty
      ? 0
      : concepts.where((c) => owned.contains(c.id)).length /
          concepts.length;

  @override
  bool operator ==(Object other) =>
      other is Art &&
      other.id == id &&
      other.icon == icon &&
      _sameList(other.concepts, concepts);

  @override
  int get hashCode => Object.hash(id, icon, Object.hashAll(concepts));
}

/// Element-wise list equality, so these value objects can be compared by
/// content rather than identity — Riverpod's `.select` guards depend on it.
bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The whole academy curriculum, derived deterministically from the two
/// content manifests.
class SkillMap {
  const SkillMap({required this.arts});

  final List<Art> arts;

  @override
  bool operator ==(Object other) =>
      other is SkillMap && _sameList(other.arts, arts);

  @override
  int get hashCode => Object.hashAll(arts);

  Iterable<Concept> get allConcepts sync* {
    for (final art in arts) {
      yield* art.concepts;
    }
  }

  Concept? conceptById(String id) {
    for (final concept in allConcepts) {
      if (concept.id == id) return concept;
    }
    return null;
  }

  /// The first unowned concept in curriculum order within [artId] — a
  /// suggestion only ("up next"); nothing is gated anywhere.
  Concept? nextConceptIn(String artId, Set<String> owned) {
    final art = arts.firstWhere((a) => a.id == artId,
        orElse: () => const Art(id: '', icon: '', concepts: []));
    for (final concept in art.concepts) {
      if (!owned.contains(concept.id)) return concept;
    }
    return null;
  }

  /// The overall "Continue" suggestion: the first art (in order) that still
  /// has an unowned concept. A suggestion only — nothing is gated, so this
  /// exists to answer "where was I?", not to decide what you may open.
  Concept? continueTarget(Set<String> owned) {
    for (final art in arts) {
      final next = nextConceptIn(art.id, owned);
      if (next != null) return next;
    }
    return null;
  }

  /// Builds the curriculum from the lesson manifest. Puzzles are no longer
  /// dealt here: each lesson names its own proof (`Lesson.proof`), so a
  /// concept's proof is resolved by loading the lesson rather than by counting
  /// positions in a pool. The old dealer handed the five endgame puzzles to
  /// the five *easiest* endgames and left Philidor and Lucena with none.
  factory SkillMap.build(LessonManifest lessons) {
    final categories = {for (final c in lessons.categories) c.id: c};
    final arts = <Art>[];
    for (final artId in artOrder) {
      final category = categories[artId];
      if (category == null) continue;
      arts.add(Art(
        id: artId,
        icon: category.icon,
        concepts: [
          for (final file in category.lessonFiles)
            Concept(id: 'concept:$file', artId: artId, lessonFile: file),
        ],
      ));
    }
    return SkillMap(arts: arts);
  }
}
