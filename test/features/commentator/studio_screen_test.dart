import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/core/ui/move_list_card.dart';
import 'package:karpachess/core/ui/replay_bar.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/features/board/presentation/karpa_board.dart';
import 'package:karpachess/features/commentator/application/commentator_controller.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';
import 'package:karpachess/content/application/content_providers.dart';
import 'package:karpachess/features/commentator/presentation/studio_library_view.dart';
import 'package:karpachess/features/commentator/presentation/studio_screen.dart';
import 'package:karpachess/features/commentator/presentation/studio_study_view.dart';

import '../practice/fake_engine_service.dart';
import 'fakes.dart' show MemoryCommentatorStore;

// NOTE: never use pumpAndSettle in these tests. The study view hosts
// animations that can outlast a settle (board transitions, the hint
// toast), so pumpAndSettle risks hanging the suite. Every pump below is
// bounded.

Future<(ProviderContainer, I18nService)> pumpStudio(
    WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    engineServiceProvider.overrideWithValue(FakeEngineService()),
    commentatorStoreProvider.overrideWithValue(MemoryCommentatorStore()),
  ]);
  addTearDown(container.dispose);
  final i18n = await container.read(i18nProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const Scaffold(body: StudioScreen()),
      ),
    ),
  );
  // Flush the session-restore microtask (empty store → import view).
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

/// Taps the first card in the study library and pumps (bounded) until the
/// study view is up.
Future<void> loadFirstGame(
    WidgetTester tester, ProviderContainer container) async {
  final library = await container.read(gameLibraryProvider.future);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.text(library.games.first.pairing));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('library view renders the study library',
      (tester) async {
    final (container, i18n) = await pumpStudio(tester);
    final library = await container.read(gameLibraryProvider.future);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(StudioLibraryView), findsOneWidget);
    expect(find.text(i18n.t('commentator.sampleGames')), findsOneWidget);
    expect(find.text(library.games[0].pairing), findsOneWidget);
    expect(find.text(i18n.t('commentator.importTitle')), findsOneWidget);
  });

  testWidgets(
      'loading a sample opens the study view with a full-mainline ReplayBar',
      (tester) async {
    final (container, _) = await pumpStudio(tester);

    await loadFirstGame(tester, container);

    expect(find.byType(StudioStudyView), findsOneWidget);

    final state = container.read(commentatorControllerProvider);
    expect(state.hasGame, isTrue);

    final replayBar = tester.widget<ReplayBar>(find.byType(ReplayBar));
    // One entry per mainline move (the root position carries none).
    expect(
      replayBar.count,
      state.tree!.mainline().length - 1,
    );
    // Freshly loaded game sits on the root position (= index -1).
    expect(replayBar.index, -1);
  });

  testWidgets('entering drawing mode locks the study board', (tester) async {
    final (container, _) = await pumpStudio(tester);
    await loadFirstGame(tester, container);

    KarpaBoard board() =>
        tester.widget<KarpaBoard>(find.byType(KarpaBoard));
    expect(board().playerSide, PlayerSide.both);

    // The DrawingModeButton beside the ActionBar enters drawing mode.
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(board().playerSide, PlayerSide.none);

    // Re-tapping the drawing icon exits the mode and unlocks the board.
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));
    expect(board().playerSide, PlayerSide.both);
  });

  Future<void> atSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> step(WidgetTester tester, void Function() move) async {
    move();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));
  }

  MoveListCard movesSoFar(WidgetTester tester) =>
      tester.widget<MoveListCard>(find.byType(MoveListCard));

  for (final size in const [Size(1032, 1332), Size(1376, 988)]) {
    testWidgets('a tablet lists the moves so far, never past the board '
        '($size)', (tester) async {
      await atSize(tester, size);
      final (container, _) = await pumpStudio(tester);
      await loadFirstGame(tester, container);
      final studio = container.read(commentatorControllerProvider.notifier);

      // At the start there is nothing to list.
      expect(movesSoFar(tester).entries, isEmpty);

      // One entry per step taken, the move on the board last.
      for (var i = 0; i < 3; i++) {
        await step(tester, studio.forward);
      }
      expect(movesSoFar(tester).entries, hasLength(3));
      expect(movesSoFar(tester).currentIndex, 2);
      final line = container.read(commentatorControllerProvider).tree!
          .mainline();
      expect(
        movesSoFar(tester).entries.map((e) => e.san),
        [for (final node in line.skip(1).take(3)) node.san],
      );

      // Stepping back takes the move off the list: it is the path to the
      // position shown, not a record of how far the reader once went.
      await step(tester, studio.back);
      expect(movesSoFar(tester).entries, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the moves-so-far list is read-only while drawing', (
    tester,
  ) async {
    await atSize(tester, const Size(1032, 1332));
    final (container, _) = await pumpStudio(tester);
    await loadFirstGame(tester, container);
    await step(
      tester,
      container.read(commentatorControllerProvider.notifier).forward,
    );
    expect(movesSoFar(tester).onSelect, isNotNull);

    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));
    expect(movesSoFar(tester).onSelect, isNull);
  });

  for (final size in const [Size(390, 844), Size(832, 419)]) {
    testWidgets('a phone keeps the panel empty ($size)', (tester) async {
      await atSize(tester, size);
      final (container, _) = await pumpStudio(tester);
      await loadFirstGame(tester, container);
      await step(
        tester,
        container.read(commentatorControllerProvider.notifier).forward,
      );
      expect(find.byType(MoveListCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
