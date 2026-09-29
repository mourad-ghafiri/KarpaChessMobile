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
import 'package:karpachess/features/academy/presentation/academy_screen.dart';
import 'package:karpachess/features/puzzles/application/puzzles_providers.dart';
import 'package:karpachess/features/puzzles/presentation/puzzles_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/presentation/score_card.dart';

import '../features/practice/practice_controller_test.dart'
    show MemoryPrefsRepository;
import '../progression/progression_test.dart' show MemoryProgressionRepository;

// Tablet windows compose the browse homes for their shape — a centred page
// whose hero and grids follow the width it has, in either orientation —
// instead of stretching the phone column or splitting a portrait iPad in
// two; compact windows keep the phone layout byte-identical. A RenderFlex
// overflow fails either way.

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _pack = PuzzlePack(id: 'discovery', icon: '⚡', puzzleFiles: ['p1.json']);

const _corpus = [
  Puzzle(id: 'p1', fen: _fen, solution: ['e4'], rating: 700, title: 'One'),
];

const _lesson = Lesson(
  id: 'discovered-attack',
  title: 'The Discovered Attack Uncovered',
  summary: 'Move one piece so another one strikes from behind it.',
  steps: [TeachStep(fen: _fen, text: 'One idea.')],
);

ProviderContainer _container() => ProviderContainer(
  overrides: [
    puzzlePackManifestProvider.overrideWith(
      (ref) async => const PuzzlePackManifest(packs: [_pack]),
    ),
    trainerPuzzlesProvider.overrideWith((ref) async => _corpus),
    skillMapProvider.overrideWith(
      (ref) async => const SkillMap(
        arts: [
          Art(
            id: 'tactics',
            icon: '⚔',
            concepts: [
              Concept(
                id: 'concept:discovered-attack.json',
                artId: 'tactics',
                lessonFile: 'discovered-attack.json',
              ),
            ],
          ),
        ],
      ),
    ),
    conceptLessonProvider.overrideWith((ref, id) async => _lesson),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    progressionRepositoryProvider.overrideWithValue(
      MemoryProgressionRepository(),
    ),
  ],
);

Future<void> _pumpAt(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
  Size logicalSize,
) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await container.read(progressionControllerProvider.notifier).restore();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The column count of the only grid on screen.
int _gridColumns(WidgetTester tester, {int index = 0}) {
  final grid = tester.widget<GridView>(find.byType(GridView).at(index));
  final delegate = grid.gridDelegate;
  return delegate is SliverGridDelegateWithFixedCrossAxisCount
      ? delegate.crossAxisCount
      : -1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('academy home on a landscape iPad: one page, profile beside', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const AcademyScreen(),
      const Size(1366, 1024),
    );
    // One page scroll, not two side-by-side columns scrolling on their own.
    expect(find.byType(ListView), findsOneWidget);
    // The page is the wide cap (1120) less 24dp a side: 1072. The profile
    // takes three fifths of it beside the day's actions.
    expect(
      tester.getSize(find.byType(ScoreCard)).width,
      moreOrLessEquals((1072 - 12) * 3 / 5, epsilon: 0.5),
    );
    expect(_gridColumns(tester), 4);
  });

  testWidgets('academy home on a portrait iPad: one column, four arts a row', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const AcademyScreen(),
      const Size(1032, 1376),
    );
    expect(find.byType(ListView), findsOneWidget);
    // The grid cap (880) less 24dp a side; the profile spans it.
    expect(
      tester.getSize(find.byType(ScoreCard)).width,
      moreOrLessEquals(880 - 48, epsilon: 0.5),
    );
    expect(_gridColumns(tester), 4);
  });

  testWidgets('academy home on an iPad mini: two arts a row, never three', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const AcademyScreen(),
      const Size(671, 1089),
    );
    expect(_gridColumns(tester), 2);
  });

  testWidgets('academy home keeps one column on a phone', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const AcademyScreen(),
      const Size(390, 844),
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(_gridColumns(tester), 2);
  });

  testWidgets('puzzles home renders wide without overflow', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const PuzzlesScreen(),
      const Size(1366, 1024),
    );
    expect(find.byType(PuzzlesScreen), findsOneWidget);
    // Twenty packs as four rows of five.
    expect(_gridColumns(tester), 5);
  });

  testWidgets('puzzles home on a portrait iPad: packs four a row', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const PuzzlesScreen(),
      const Size(1032, 1376),
    );
    expect(find.byType(PuzzlesScreen), findsOneWidget);
    expect(_gridColumns(tester), 4);
  });

  testWidgets('puzzles home renders compact without overflow', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpAt(
      tester,
      container,
      const PuzzlesScreen(),
      const Size(390, 844),
    );
    expect(find.byType(PuzzlesScreen), findsOneWidget);
  });
}
