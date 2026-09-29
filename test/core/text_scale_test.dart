import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/application/content_providers.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/academy/domain/skill_map.dart';
import 'package:karpachess/features/academy/presentation/art_view.dart';
import 'package:karpachess/features/puzzles/application/puzzles_providers.dart';
import 'package:karpachess/features/puzzles/presentation/pack_detail_screen.dart';
import 'package:karpachess/features/puzzles/presentation/puzzles_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/domain/lesson_progress.dart';
import 'package:karpachess/progression/domain/progression.dart';
import 'package:karpachess/progression/domain/puzzle_outcome.dart';

import '../features/practice/practice_controller_test.dart'
    show MemoryPrefsRepository;
import '../progression/progression_test.dart'
    show MemoryProgressionRepository;

// The app clamps Dynamic Type at 1.3× (lib/app.dart) and its fixed slots
// are audited to that ceiling. These are the suite's guard that the grids
// and cards actually survive it: a RenderFlex overflow fails the test.

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _pack = PuzzlePack(
  id: 'discovery',
  icon: '⚡',
  puzzleFiles: ['p1.json', 'p2.json'],
);

const _corpus = [
  Puzzle(id: 'p1', fen: _fen, solution: ['e4'], rating: 700, title: 'One'),
  Puzzle(id: 'p2', fen: _fen, solution: ['e4'], rating: 900, title: 'Two'),
];

const _lesson = Lesson(
  id: 'discovered-attack',
  title: 'The Discovered Attack Uncovered',
  summary: 'Move one piece so another one strikes from behind it.',
  steps: [TeachStep(fen: _fen, text: 'One idea.')],
);

ProviderContainer _container({ProgressionState? progression}) {
  final repo = MemoryProgressionRepository()..stored = progression;
  final container = ProviderContainer(overrides: [
    puzzlePackManifestProvider.overrideWith(
      (ref) async => const PuzzlePackManifest(packs: [_pack]),
    ),
    trainerPuzzlesProvider.overrideWith((ref) async => _corpus),
    skillMapProvider.overrideWith(
      (ref) async => const SkillMap(arts: [
        Art(id: 'tactics', icon: '⚔', concepts: [
          Concept(
            id: 'concept:discovered-attack.json',
            artId: 'tactics',
            lessonFile: 'discovered-attack.json',
          ),
        ]),
      ]),
    ),
    conceptLessonProvider.overrideWith((ref, id) async => _lesson),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    progressionRepositoryProvider.overrideWithValue(repo),
  ]);
  return container;
}

Future<void> _pumpAt13(
  WidgetTester tester,
  ProviderContainer container,
  Widget home, {
  Size logicalSize = const Size(360, 690),
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await container.read(progressionControllerProvider.notifier).restore();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
          home: home,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('puzzles home pack grid survives 1.3× text', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt13(tester, container, const PuzzlesScreen());
    expect(find.byType(PuzzlesScreen), findsOneWidget);
  });

  testWidgets('pack detail rows survive 1.3× text and stay ≥44dp tall',
      (tester) async {
    final container = _container(
      progression: const ProgressionState(
        puzzleResults: {'p1': PuzzleOutcome.solved},
      ),
    );
    addTearDown(container.dispose);
    await _pumpAt13(
        tester, container, const PackDetailScreen(pack: _pack));
    // Every puzzle row — resolved or not — meets the 44dp target floor.
    final rows = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.minHeight == 44);
    expect(rows, findsNWidgets(2));
    for (final element in rows.evaluate()) {
      expect(element.size!.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets(
      'lesson cards (grid branch, in-progress row) survive 1.3× text',
      (tester) async {
    final container = _container(
      progression: ProgressionState(lessonProgress: {
        'concept:discovered-attack.json': LessonProgress(
          beat: 2,
          beatCount: 5,
          solvedBeats: const {0, 1},
          awardedBeats: const {0, 1},
        ),
      }),
    );
    addTearDown(container.dispose);
    // Landscape-compact so ArtView takes its fixed-extent GRID branch —
    // the branch where an overgrown card cannot stretch its cell.
    await _pumpAt13(
      tester,
      container,
      const ArtView(artId: 'tactics'),
      logicalSize: const Size(700, 360),
    );
    expect(find.byType(ArtView), findsOneWidget);
  });
}
