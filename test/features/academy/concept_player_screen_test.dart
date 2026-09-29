import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:dartchess/dartchess.dart' show NormalMove, Square;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/markdown/markdown_view.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/academy/presentation/concept_player_screen.dart';
import 'package:karpachess/features/academy/presentation/lesson_journey_line.dart';
import 'package:karpachess/features/board/presentation/karpa_board.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/domain/progression.dart';

import '../../progression/progression_test.dart'
    show MemoryProgressionRepository;
import '../practice/practice_controller_test.dart' show MemoryPrefsRepository;

// NOTE: never use pumpAndSettle here — the player hosts effects that keep
// animating (XP floater, celebration confetti). Every pump is bounded.

const _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _summary = 'A knight fork attacks two pieces at once.';

const _lesson = Lesson(
  id: 'test-lesson',
  title: 'Knight Fork',
  summary: 'Forks',
  steps: [
    TeachStep(
      fen: _startFen,
      text: '$_summary\n\nRoyal forks hit king and queen together.',
    ),
    PlayStep(
      fen: _startFen,
      prompt: 'Push the king pawn.',
      targetSan: ['e4'],
    ),
  ],
);

const _proof = Puzzle(id: 'p1', fen: _startFen, solution: ['e4']);

Future<(ProviderContainer, I18nService)> pumpPlayer(
  WidgetTester tester, {
  Puzzle proof = _proof,
}) async {
  final container = ProviderContainer(overrides: [
    conceptLessonProvider.overrideWith((ref, id) async => _lesson),
    conceptProofProvider.overrideWith((ref, id) async => proof),
    soundServiceProvider.overrideWithValue(const SilentSoundService()),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    progressionRepositoryProvider
        .overrideWithValue(MemoryProgressionRepository()),
  ]);
  addTearDown(container.dispose);
  final i18n = await container.read(i18nProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const ConceptPlayerScreen(conceptId: 'concept:test.json'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

KarpaBoard boardOf(WidgetTester tester) =>
    tester.widget<KarpaBoard>(find.byType(KarpaBoard));

double progressValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

/// SEE → PLAY via the action row's advance button, which announces the
/// coming phase ("Play it") when the next beat crosses into it.
Future<void> advanceToPlay(WidgetTester tester, I18nService i18n) async {
  await tester.tap(find.text(i18n.t('academy.playIt')));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Solves the PLAY beat with the target move.
Future<void> solvePlay(WidgetTester tester) async {
  boardOf(tester).onMove!(const NormalMove(from: Square.e2, to: Square.e4));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SEE beat: pattern chip, thin progress bar, and a phase-labeled '
      'advance button', (tester) async {
    final (_, i18n) = await pumpPlayer(tester);

    // The lesson names itself on the context card above the board. (The old
    // `academy.newPattern` label beside it no longer exists.)
    expect(find.text('Knight Fork'), findsOneWidget);
    // The advance button announces the coming phase.
    expect(find.text(i18n.t('academy.playIt')), findsOneWidget);

    // Thin progress bar replaces the phase segments: beat 1 of 3.
    expect(progressValue(tester), closeTo(1 / 3, 0.001));
    expect(find.text(i18n.t('academy.seeIt')), findsNothing);

    // The whole lesson is always visible — no expand/collapse toggle.
    expect(find.byType(MarkdownView), findsOneWidget);

    // Only the Next button advances the beat.
    await advanceToPlay(tester, i18n);
    // An unsolved play beat asks for a move outright, rather than showing the
    // same soft phase pill the reading beats use.
    expect(find.text(i18n.t('academy.yourMove')), findsOneWidget);
    expect(progressValue(tester), closeTo(2 / 3, 0.001));
  });

  testWidgets(
      'PLAY beat: correct move locks the board and waits on the learner '
      '— no auto-advance; a board tap moves on', (tester) async {
    final (_, i18n) = await pumpPlayer(tester);
    await advanceToPlay(tester, i18n);

    // Wrong move: rejected, still on the beat after the revert — no
    // advance button appears until the beat is solved.
    boardOf(tester).onMove!(const NormalMove(from: Square.g1, to: Square.f3));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(i18n.t('academy.ownIt')), findsNothing);

    await solvePlay(tester);
    // Solved: the advance button appears, announcing the OWN phase.
    expect(find.text(i18n.t('academy.ownIt')), findsOneWidget);
    expect(boardOf(tester).playerSide, PlayerSide.none);

    // Stays put well past the old 850ms auto-advance.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(i18n.t('academy.ownIt')), findsOneWidget);

    // Tapping the board advances to the OWN beat.
    await tester.tap(find.byType(KarpaBoard), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    // An unsolved proof beat earns no advance button — the learner has to
    // prove the pattern first.
    expect(find.text(i18n.t('academy.finishLesson')), findsNothing);
    expect(progressValue(tester), closeTo(1.0, 0.001));
  });

  testWidgets(
      'OWN beat: proof solve shows "Finish lesson"; finishing celebrates '
      'with the Pattern Book line', (tester) async {
    final (container, i18n) = await pumpPlayer(tester);
    await advanceToPlay(tester, i18n);
    await solvePlay(tester);
    await tester.tap(find.text(i18n.t('academy.ownIt')));
    await tester.pump(const Duration(milliseconds: 50));

    boardOf(tester).onMove!(const NormalMove(from: Square.e2, to: Square.e4));
    await tester.pump(const Duration(milliseconds: 50));
    final finish = find.text(i18n.t('academy.finishLesson'));
    expect(finish, findsOneWidget);

    // No auto-advance on the last beat either.
    await tester.pump(const Duration(seconds: 1));
    expect(finish, findsOneWidget);

    await tester.tap(finish);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(i18n.t('academy.patternOwned')), findsOneWidget);
    expect(find.text(i18n.t('academy.addedToBook')), findsOneWidget);
    expect(
      container.read(progressionControllerProvider).xp,
      // teach + play + first-own awards, all user-driven.
      XpRules.teachStep + XpRules.playStep + XpRules.patternOwned,
    );

    // Let the confetti and XP count-up finish, then tear down cleanly.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'OWN beat: the proof title waits for the solve, and a mate other than '
      'the authored one solves it', (tester) async {
    const proof = Puzzle(
      id: 'p2',
      // Two rooks and an open back rank: Ra8# and Rb8# both mate.
      fen: '6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1',
      solution: ['Ra8#'],
      title: 'Back Rank Secret',
    );
    final (_, i18n) = await pumpPlayer(tester, proof: proof);
    await advanceToPlay(tester, i18n);
    await solvePlay(tester);
    await tester.tap(find.text(i18n.t('academy.ownIt')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Back Rank Secret'), findsNothing);

    boardOf(tester).onMove!(const NormalMove(from: Square.b1, to: Square.b8));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(i18n.t('academy.finishLesson')), findsOneWidget);
    expect(find.text('Back Rank Secret'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final size in const [Size(1032, 1332), Size(744, 1089)]) {
    testWidgets('a portrait tablet stacks the lesson, journey line on top '
        '($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpPlayer(tester);

      // The stacked column books a lead row for every mode, so the journey
      // line always has room above the card and the board.
      expect(find.byType(LessonJourneyLine), findsOneWidget);
      final board = tester.getRect(find.byType(KarpaBoard));
      expect(
        tester.getRect(find.byType(LessonJourneyLine)).bottom,
        lessThan(board.top),
      );
      // The prose reads under the board.
      expect(
        tester.getRect(find.byType(MarkdownView)).top,
        greaterThan(board.bottom),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
