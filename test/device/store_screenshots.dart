import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karpachess/content/application/content_providers.dart';
import 'package:karpachess/core/layout/mode_shell.dart';
import 'package:karpachess/features/academy/presentation/concept_player_screen.dart';
import 'package:karpachess/features/coach/application/coach_hint_controller.dart';
import 'package:karpachess/features/coach/domain/coach_menu.dart';
import 'package:karpachess/features/coach/domain/coach_service.dart';
import 'package:karpachess/features/commentator/application/commentator_controller.dart';
import 'package:karpachess/features/commentator/application/drawing_controller.dart';
import 'package:karpachess/features/puzzles/presentation/puzzle_solve_screen.dart';
import 'package:karpachess/features/review/application/review_controller.dart';
import 'package:karpachess/features/review/presentation/review_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';

import 'support/shots.dart';

/// The App Store and Google Play screenshots, captured from the real app.
///
/// NOT part of the test suite (hence no `_test.dart` suffix — see
/// `driver.dart`). `tool/store_screenshots.sh` runs it on each simulator
/// through `flutter drive`, which writes every capture to
/// `build/screenshots/raw/<device>/`; then `tool/store_screenshots.py` checks
/// each against the store's sizes and files the publishing set into
/// `screenshots/<store>/<device>/`. See docs/RELEASE.md, "Store screenshots".
///
/// Everything on screen is seeded through the app's own repositories
/// (`support/shots.dart`) — a learner a few weeks in, a practice game against
/// Stockfish, a lesson resumed on its richest beat — so every device shows
/// the same story. The engine is real: the hint, the review and the Studio's
/// brilliancy are Stockfish 19 answering on the simulator.
///
/// Two defines: `SHOT_DEVICE` names the output folder (`iphone-6.9`,
/// `ipad-13`, `android-phone`, `android-tablet`), and `SHOT_LANDSCAPE=true`
/// asks for landscape — the Android tablet's. iPadOS ignores an orientation
/// request from an app that supports multitasking, so the iPad is shot in
/// portrait, which the App Store accepts at the same size class.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const device = String.fromEnvironment('SHOT_DEVICE', defaultValue: 'device');
  const landscape = bool.fromEnvironment('SHOT_LANDSCAPE');

  testWidgets('store screenshots', (tester) async {
    final (:container, :greekGift) = await launchSeeded(
      tester,
      binding,
      landscape: landscape,
    );

    Future<void> shot(String name) async {
      await waitFor(tester, 1000);
      await binding.takeScreenshot('raw/$device/$name');
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    // 1 — Learn: the course home, a learner a few weeks in.
    await shot('01-learn');

    // 2 — A lesson, resumed on the Greek gift's "Four Squares, One King":
    // the four king moves drawn at once as a menu of arrows.
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ConceptPlayerScreen(conceptId: greekGift),
          fullscreenDialog: true,
        ),
      ),
    );
    await waitFor(tester, 3500);
    expect(
      find.text('Four Squares, One King'),
      findsWidgets,
      reason: 'the lesson did not resume on beat 5',
    );
    await shot('02-lesson');
    nav.pop();
    await waitFor(tester, 1200);

    // 3 — The rated puzzle trainer.
    final packs = await container.read(puzzlePackManifestProvider.future);
    final fork = packs.packs.firstWhere((p) => p.id == 'fork');
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PuzzleSolveScreen(run: SinglePuzzleRun(fork, 'fork-12')),
          fullscreenDialog: true,
        ),
      ),
    );
    await waitFor(tester, 3500);
    await shot('03-puzzles');
    nav.pop();
    await waitFor(tester, 1200);

    // 4 — Play against Stockfish 19: the seeded game, restored.
    container.read(activeTabProvider.notifier).state = AppTab.play;
    await waitFor(tester, 3000);
    await shot('04-play');

    // 5 — The coach, in the same game.
    final hint = container.read(
      coachHintControllerProvider(HintScope.practice).notifier,
    );
    hint.toggle();
    await waitFor(tester, 600);
    await hint.ask(CoachIntent.plan).timeout(const Duration(seconds: 60));
    await waitUntil(tester, () {
      final state = container.read(
        coachHintControllerProvider(HintScope.practice),
      );
      return !state.loading && state.answer != null;
    });
    await shot('05-coach');
    hint.close();
    await waitFor(tester, 800);

    // 6 — Review: every move of the game classified, on 11.Ng5?.
    unawaited(
      nav.push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen())),
    );
    await waitUntil(
      tester,
      () => container.read(reviewControllerProvider).done,
      timeout: const Duration(minutes: 3),
    );
    container.read(reviewControllerProvider.notifier).select(20);
    await shot('06-review');
    nav.pop();
    await waitFor(tester, 1200);

    // 7 — The Studio's library of master games.
    container.read(activeTabProvider.notifier).state = AppTab.studio;
    await waitFor(tester, 3000);
    await shot('07-studio-library');

    // 8 — Réti–Tartakower, Vienna 1910: 9.Qd8+!!, found brilliant.
    final library = await container.read(gameLibraryProvider.future);
    final reti = library.games.firstWhere((g) => g.id == 'reti-01');
    final studio = container.read(commentatorControllerProvider.notifier);
    studio.loadPgn(reti.toPgn());
    final line = container.read(commentatorControllerProvider).tree!.mainline();
    final queenSacrifice = line[17];
    studio.goToNode(queenSacrifice.id);
    await waitUntil(
      tester,
      () => queenSacrifice.quality != null,
      timeout: const Duration(minutes: 2),
    );
    await shot('08-studio-analysis');

    // 9 — The drawing tools, on the move before the sacrifice: the shapes a
    // reader makes with them, added through the controller the toolbar uses.
    final beforeSacrifice = line[16];
    studio.goToNode(beforeSacrifice.id);
    await waitUntil(
      tester,
      () => beforeSacrifice.quality != null,
      timeout: const Duration(minutes: 2),
    );
    final drawing = container.read(
      drawingControllerProvider(DrawingScope.studio).notifier,
    );
    // The engine's verdict on 8...Nxe4 rides on the board as a badge, and a
    // quick simulator search can rate it well — beside a "Mate in 3!" label
    // that reads as a contradiction. The shot is about the drawing, so the
    // badges step aside for it (the reader's own switch, in the action bar).
    final prefs = container.read(prefsControllerProvider.notifier);
    await prefs.setCommentatorBadges(false);
    drawing.enterMode();
    for (final shape in mateInThreeAnnotation()) {
      drawing.addShape(shape);
    }
    drawing.setColor(paletteHex('yellow'));
    await shot('09-studio-drawing');
    drawing.exitMode();
    await prefs.setCommentatorBadges(true);

    // 10 — Make it yours: themes, boards and piece sets.
    container.read(activeTabProvider.notifier).state = AppTab.learn;
    await waitFor(tester, 1500);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await waitFor(tester, 2000);
    await shot('10-personalize');
  });
}
