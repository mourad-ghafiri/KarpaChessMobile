import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/application/content_providers.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/puzzles/application/puzzles_providers.dart';
import 'package:karpachess/features/puzzles/presentation/pack_detail_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/domain/progression.dart';
import 'package:karpachess/progression/domain/puzzle_outcome.dart';

import '../../progression/progression_test.dart'
    show MemoryProgressionRepository;
import '../practice/practice_controller_test.dart' show MemoryPrefsRepository;

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _pack = PuzzlePack(
  id: 'fork',
  icon: '⚔',
  puzzleFiles: ['p1.json', 'p2.json', 'p3.json', 'p4.json'],
);

Puzzle _puzzle(String id, int rating, String title) => Puzzle(
      id: id,
      fen: _fen,
      solution: const ['e4'],
      rating: rating,
      title: title,
    );

final _corpus = [
  _puzzle('p1', 600, 'Alpha'),
  _puzzle('p2', 700, 'Bravo'),
  _puzzle('p3', 800, 'Charlie'),
  _puzzle('p4', 900, 'Delta'),
];

Future<(ProviderContainer, I18nService)> pumpDetail(
    WidgetTester tester) async {
  final repo = MemoryProgressionRepository()
    ..stored = const ProgressionState(puzzleResults: {
      'p2': PuzzleOutcome.solved,
      'p3': PuzzleOutcome.flawless,
      'p4': PuzzleOutcome.failed,
    });
  final container = ProviderContainer(overrides: [
    puzzlePackManifestProvider.overrideWith(
      (ref) async => const PuzzlePackManifest(packs: [_pack]),
    ),
    trainerPuzzlesProvider.overrideWith((ref) async => _corpus),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    progressionRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await container.read(progressionControllerProvider.notifier).restore();
  final i18n = await container.read(i18nProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const PackDetailScreen(pack: _pack),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('header shows the blurb, the rating range and solved tally',
      (tester) async {
    final (_, i18n) = await pumpDetail(tester);
    expect(find.text(i18n.t(_pack.blurbKey)), findsOneWidget);
    expect(find.text('600–900'), findsOneWidget);
    // Failed p4 does not count toward the tally.
    expect(find.text('2 / 4', findRichText: true), findsOneWidget);
    expect(find.text(i18n.t('puzzles.continuePack')), findsOneWidget);
  });

  testWidgets('rows wear their state and unsolved rows hide the title',
      (tester) async {
    final (_, i18n) = await pumpDetail(tester);

    // p1 has no outcome: numbered, no title, no state word.
    expect(find.text(i18n.t('puzzles.puzzleN', {'n': 1})), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Resolved outcomes show the title and their state word — failed
    // included, because the solution has been seen.
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text(i18n.t('puzzles.solved')), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.text(i18n.t('puzzles.flawless')), findsOneWidget);
    expect(find.text('Delta'), findsOneWidget);
    expect(find.text(i18n.t('puzzles.failed')), findsOneWidget);
  });
}
