import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karpachess/content/application/content_providers.dart';
import 'package:karpachess/core/layout/mode_shell.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/academy/presentation/art_view.dart';
import 'package:karpachess/features/academy/presentation/concept_player_screen.dart';
import 'package:karpachess/features/academy/presentation/pattern_book_screen.dart';
import 'package:karpachess/features/academy/presentation/sharpen_screen.dart';
import 'package:karpachess/features/coach/application/coach_hint_controller.dart';
import 'package:karpachess/features/coach/domain/coach_menu.dart';
import 'package:karpachess/features/coach/domain/coach_service.dart';
import 'package:karpachess/features/commentator/application/commentator_controller.dart';
import 'package:karpachess/features/commentator/application/drawing_controller.dart';
import 'package:karpachess/features/commentator/domain/drawing_shapes.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/features/puzzles/presentation/pack_detail_screen.dart';
import 'package:karpachess/features/puzzles/presentation/puzzle_solve_screen.dart';
import 'package:karpachess/features/review/application/review_controller.dart';
import 'package:karpachess/features/review/presentation/review_screen.dart';
import 'package:karpachess/progression/application/progression_controller.dart';

import 'support/shots.dart';

/// A look at every screen on one device, for judging layouts by eye — the
/// board modes with their hint and drawing states, the home tabs and their
/// detail pages, Settings and a dialog. NOT part of the test suite (hence no
/// `_test.dart` suffix — see `driver.dart`), and not the store set
/// (`store_screenshots.dart`).
///
/// Run through `flutter drive`; every capture lands in
/// `build/screenshots/audit/<SHOT_DEVICE>/`, never in `screenshots/`, which
/// holds only what gets published:
///
///     flutter drive --driver=test/device/driver.dart \
///       --target=test/device/layout_audit.dart -d <device> \
///       --dart-define=SHOT_DEVICE=<folder> [--dart-define=SHOT_LANDSCAPE=true]
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const device = String.fromEnvironment('SHOT_DEVICE', defaultValue: 'device');
  const landscape = bool.fromEnvironment('SHOT_LANDSCAPE');

  testWidgets('layout audit', (tester) async {
    final (:container, :greekGift) = await launchSeeded(
      tester,
      binding,
      landscape: landscape,
    );

    Future<void> shot(String name) async {
      await waitFor(tester, 1000);
      await binding.takeScreenshot('audit/$device/$name');
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<void> visit(
      Widget screen,
      String name, {
      bool fullscreen = true,
      int settleMs = 3000,
    }) async {
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => screen,
            fullscreenDialog: fullscreen,
          ),
        ),
      );
      await waitFor(tester, settleMs);
      await shot(name);
      nav.pop();
      await waitFor(tester, 1200);
    }

    // ---- Learn ----
    await shot('01-learn-home');
    final map = await container.read(skillMapProvider.future);
    await visit(
      ArtView(artId: map.arts[2].id),
      '02-art-view',
      fullscreen: false,
    );
    await visit(
      const PatternBookScreen(),
      '03-pattern-book',
      fullscreen: false,
    );
    await visit(ConceptPlayerScreen(conceptId: greekGift), '04-lesson');
    final due = container
        .read(progressionControllerProvider)
        .duePatterns(DateTime.now());
    await visit(SharpenScreen(conceptIds: due.take(10).toList()), '05-sharpen');

    // ---- Puzzles ----
    container.read(activeTabProvider.notifier).state = AppTab.puzzles;
    await waitFor(tester, 2000);
    await shot('06-puzzles-home');
    final packs = await container.read(puzzlePackManifestProvider.future);
    final fork = packs.packs.firstWhere((p) => p.id == 'fork');
    await visit(
      PackDetailScreen(pack: fork),
      '07-pack-detail',
      fullscreen: false,
    );
    await visit(
      PuzzleSolveScreen(run: SinglePuzzleRun(fork, 'fork-12')),
      '08-puzzle',
    );

    // ---- Play ----
    container.read(activeTabProvider.notifier).state = AppTab.play;
    await waitFor(tester, 3000);
    await shot('09-play-game');

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
    await shot('10-play-hint');
    hint.close();
    await waitFor(tester, 800);

    final playDrawing = container.read(
      drawingControllerProvider(DrawingScope.play).notifier,
    );
    playDrawing.enterMode();
    playDrawing.addShape(
      ArrowShape(
        points: arrowPointsBetween(
          const BoardSquare(5, 5),
          const BoardSquare(3, 6),
        ),
        color: paletteHex('green'),
        stroke: 0.08,
      ),
    );
    await shot('11-play-drawing');
    playDrawing.clearCurrentNode();
    playDrawing.exitMode();
    await waitFor(tester, 800);

    unawaited(
      nav.push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen())),
    );
    await waitUntil(
      tester,
      () => container.read(reviewControllerProvider).done,
      timeout: const Duration(minutes: 3),
    );
    container.read(reviewControllerProvider.notifier).select(20);
    await shot('12-review');
    nav.pop();
    await waitFor(tester, 1200);

    await tester.tap(find.byTooltip('Exit match'));
    await waitFor(tester, 1000);
    await shot('13-play-exit-dialog');
    nav.pop();
    await waitFor(tester, 800);

    container.read(practiceControllerProvider.notifier).abandon();
    await waitFor(tester, 1500);
    await shot('14-play-setup');

    // ---- Studio ----
    container.read(activeTabProvider.notifier).state = AppTab.studio;
    await waitFor(tester, 2500);
    await shot('15-studio-library');

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
    await shot('16-studio-study');

    final drawing = container.read(
      drawingControllerProvider(DrawingScope.studio).notifier,
    );
    studio.goToNode(line[16].id);
    await waitFor(tester, 1500);
    drawing.enterMode();
    for (final shape in mateInThreeAnnotation()) {
      drawing.addShape(shape);
    }
    await shot('17-studio-drawing');
    drawing.exitMode();

    // ---- Settings ----
    container.read(activeTabProvider.notifier).state = AppTab.learn;
    await waitFor(tester, 1500);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await waitFor(tester, 2000);
    await shot('18-settings');
    nav.pop();
    await waitFor(tester, 800);
  });
}
