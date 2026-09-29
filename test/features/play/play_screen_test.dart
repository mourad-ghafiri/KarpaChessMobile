import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/ui/drawing_mode_bar.dart';
import 'package:karpachess/core/ui/move_list_card.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/features/board/presentation/karpa_board.dart';
import 'package:karpachess/features/commentator/application/drawing_controller.dart';
import 'package:karpachess/features/play/presentation/play_screen.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';

import '../practice/fake_engine_service.dart';
import '../practice/practice_controller_test.dart' show MemoryPrefsRepository;

ProviderContainer makeContainer() => ProviderContainer(overrides: [
      engineServiceProvider.overrideWithValue(FakeEngineService()),
      soundServiceProvider.overrideWithValue(const SilentSoundService()),
      prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    ]);

Future<I18nService> pumpPlay(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final i18n = await container.read(i18nProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const Scaffold(body: PlayScreen()),
      ),
    ),
  );
  await tester.pump();
  return i18n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'entering drawing mode locks the board, pauses the clock and shows '
      'the paused chip', (tester) async {
    final container = makeContainer();

    // Timed game so the paused chip has a real clock to talk about.
    await container
        .read(prefsControllerProvider.notifier)
        .setTimeControl(minutes: 10, increment: 0);
    container.read(practiceControllerProvider.notifier).newGame();

    final i18n = await pumpPlay(tester, container);

    // Live game: the user (white) can move, both clocks render 10:00.
    var board = tester.widget<KarpaBoard>(find.byType(KarpaBoard));
    expect(board.playerSide, PlayerSide.white);
    expect(find.text('10:00'), findsNWidgets(2));
    expect(find.text(i18n.t('draw.paused')), findsNothing);

    // Enter drawing mode via the pencil toggle in the action row.
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // AnimatedSize

    board = tester.widget<KarpaBoard>(find.byType(KarpaBoard));
    expect(board.playerSide, PlayerSide.none);
    expect(
      container.read(drawingControllerProvider(DrawingScope.play)).active,
      isTrue,
    );
    expect(find.text(i18n.t('draw.paused')), findsOneWidget);
    // Drawing is left through the same pencil that entered it — there is no
    // separate "Done" button (the old `draw.done` key no longer exists).
    expect(find.byType(DrawingModeButton), findsOneWidget);

    // Clock display stays frozen across pumps while drawing.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10:00'), findsNWidgets(2));

    // Re-tapping the pencil leaves drawing mode: board unlocks, chip goes.
    await tester.tap(find.byType(DrawingModeButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    board = tester.widget<KarpaBoard>(find.byType(KarpaBoard));
    expect(board.playerSide, PlayerSide.white);
    expect(find.text(i18n.t('draw.paused')), findsNothing);

    // Flush the coach-bubble lifetime timer, then tear down the tree
    // before disposing the container (dispose cancels the clock timer).
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('setup view renders without overflow at 320dp width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    final i18n = await pumpPlay(tester, container);
    await tester.pump(const Duration(milliseconds: 200));

    // Setup screen: title, the four persona cards and the full-width CTA.
    expect(find.text(i18n.t('play.title')), findsOneWidget);
    for (var level = 1; level <= 4; level++) {
      expect(find.text(i18n.t('game.difficulty.$level')), findsOneWidget);
    }
    expect(find.text(i18n.t('play.nav')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> atSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tearDownGame(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('a portrait tablet stacks the game and lists its moves', (
    tester,
  ) async {
    await atSize(tester, const Size(1032, 1332));
    final container = makeContainer();
    container.read(practiceControllerProvider.notifier).newGame();
    await pumpPlay(tester, container);

    // The move list sits under the board, in the room a portrait tablet
    // keeps there — a phone keeps only slack.
    expect(find.byType(MoveListCard), findsOneWidget);
    final board = tester.getRect(find.byType(KarpaBoard));
    expect(
      tester.getRect(find.byType(MoveListCard)).top,
      greaterThan(board.bottom),
    );
    expect(tester.takeException(), isNull);
    await tearDownGame(tester, container);
  });

  testWidgets('a phone keeps the move list off the game', (tester) async {
    await atSize(tester, const Size(390, 844));
    final container = makeContainer();
    container.read(practiceControllerProvider.notifier).newGame();
    await pumpPlay(tester, container);

    expect(find.byType(MoveListCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tearDownGame(tester, container);
  });

  testWidgets('setup never leaves a persona alone on a row', (tester) async {
    // Portrait, landscape and the iPad mini: two by two every time, where a
    // 600-720dp column used to fit three and orphan the fourth.
    for (final size in const [
      Size(1032, 1376),
      Size(1376, 1032),
      Size(744, 1133),
    ]) {
      await atSize(tester, size);
      final container = makeContainer();
      await pumpPlay(tester, container);
      await tester.pump(const Duration(milliseconds: 200));

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
}
