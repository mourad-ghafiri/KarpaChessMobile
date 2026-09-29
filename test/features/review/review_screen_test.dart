import 'package:dartchess/dartchess.dart' show NormalMove;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/ui/move_list_card.dart';
import 'package:karpachess/core/ui/replay_bar.dart';
import 'package:karpachess/core/ui/surface.dart';
import 'package:karpachess/features/board/presentation/karpa_board.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/features/review/application/review_controller.dart';
import 'package:karpachess/features/review/presentation/review_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';

import '../practice/fake_engine_service.dart';
import '../practice/practice_controller_test.dart'
    show MemoryPrefsRepository, firstLegalReply;

/// A one-move game (1.e4 and the engine's reply), played, then opened in
/// Review and analyzed.
Future<(ProviderContainer, I18nService)> pumpReviewedGame(
  WidgetTester tester,
) async {
  final container = ProviderContainer(overrides: [
    engineServiceProvider
        .overrideWithValue(FakeEngineService(onSearch: firstLegalReply)),
    soundServiceProvider.overrideWithValue(const SilentSoundService()),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
  ]);
  addTearDown(container.dispose);

  // Default prefs: unlimited time control → no clock timer to leak.
  final i18n = await container.read(i18nProvider.future);

  // Play one user move and let the engine reply.
  final practice = container.read(practiceControllerProvider.notifier);
  practice.newGame();
  practice.userMove(NormalMove.fromUci('e2e4'));
  await tester.pump(const Duration(milliseconds: 400));
  expect(container.read(practiceControllerProvider).moves, hasLength(2));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const ReviewScreen(),
      ),
    ),
  );
  // Post-frame start() + the per-ply engine awaits.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'review analyzes the finished game and the ReplayBar drives the board',
      (tester) async {
    final (container, i18n) = await pumpReviewedGame(tester);

    final review = container.read(reviewControllerProvider);
    expect(review.running, isFalse);
    expect(review.done, isTrue);
    expect(review.moves, hasLength(2));

    // ReplayBar replaced the raw scrubber; readout starts at 0 / 2.
    expect(find.byType(ReplayBar), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);

    // Tally chips render above the bar.
    expect(
      find.textContaining(i18n.t('review.tally.best')),
      findsOneWidget,
    );

    // Stepping forward selects the user ply and shows its context line.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(container.read(reviewControllerProvider).selectedIndex, 0);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);

    // Keyboard: arrow keys and Home drive the seek too.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(reviewControllerProvider).selectedIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(container.read(reviewControllerProvider).selectedIndex, isNull);
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets(
      'on a portrait tablet the tallies ride above the board and the list '
      'sits beside the explanation', (tester) async {
    tester.view.physicalSize = const Size(1032, 1332);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (container, i18n) = await pumpReviewedGame(tester);
    expect(container.read(reviewControllerProvider).done, isTrue);

    final board = tester.getRect(find.byType(KarpaBoard));
    // The tallies take the row every mode books above the board.
    final tally = tester.getRect(
      find.textContaining(i18n.t('review.tally.best')),
    );
    expect(tally.bottom, lessThanOrEqualTo(board.top));

    // Select the first ply: the list and its explanation share the panel.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    final list = tester.getRect(find.byType(MoveListCard));
    expect(list.top, greaterThan(board.bottom));
    final explanation = tester.getRect(find.byType(Surface).last);
    expect(explanation.left, greaterThan(list.right));
    expect(tester.takeException(), isNull);
  });
}
