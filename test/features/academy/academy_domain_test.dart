import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/features/academy/domain/academy_rank.dart';
import 'package:karpachess/features/academy/domain/skill_map.dart';

LessonManifest lessons(Map<String, List<String>> byCategory) => LessonManifest(
      categories: [
        for (final entry in byCategory.entries)
          LessonCategoryRef(
            id: entry.key,
            icon: '♟',
            lessonFiles: entry.value,
          ),
      ],
    );

PuzzleManifest puzzles(Map<String, List<String>> byTheme) => PuzzleManifest(
      themes: [
        for (final entry in byTheme.entries)
          PuzzleThemeRef(
            id: entry.key,
            icon: '⚡',
            difficulty: 'beginner',
            puzzleFiles: entry.value,
          ),
      ],
    );

void main() {
  group('SkillMap.build', () {
    test('arts follow curriculum order and carry their concepts', () {
      final map = SkillMap.build(
        lessons({
          'basics': ['b1.json', 'b2.json'],
          'tactics': ['t1.json'],
          'openings': ['o1.json'],
        }),
      );
      // `artOrder`, not the manifest order and not alphabetical: tactics
      // deliberately precedes openings (skill_map.dart documents why).
      expect(map.arts.map((a) => a.id), ['basics', 'tactics', 'openings']);
      expect(map.arts.first.concepts.map((c) => c.id),
          ['concept:b1.json', 'concept:b2.json']);
    });

    test('sequential unlock inside an art, free choice across arts', () {
      final map = SkillMap.build(
        lessons({
          'basics': ['b1.json', 'b2.json'],
          'tactics': ['t1.json'],
        }),
      );
      expect(map.continueTarget({'concept:b1.json'})!.id, 'concept:b2.json');
      expect(
        map.continueTarget(
            {'concept:b1.json', 'concept:b2.json', 'concept:t1.json'}),
        isNull,
      );
    });
  });

  group('AcademyRank', () {
    test('two levels per rank, capped at grandmaster', () {
      expect(AcademyRank.fromLevel(0), AcademyRank.novice);
      expect(AcademyRank.fromLevel(1), AcademyRank.novice);
      expect(AcademyRank.fromLevel(2), AcademyRank.apprentice);
      expect(AcademyRank.fromLevel(7), AcademyRank.tactician);
      expect(AcademyRank.fromLevel(14), AcademyRank.grandmaster);
      expect(AcademyRank.fromLevel(99), AcademyRank.grandmaster);
    });
  });
}
