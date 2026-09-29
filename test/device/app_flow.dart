import 'package:dartchess/dartchess.dart' show NormalMove;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karpachess/app.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/layout/mode_shell.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';

/// End-to-end smoke of the real app on a device: real assets, real i18n,
/// real Stockfish. Walks all five tabs, plays a practice move against the
/// engine, and flips the app to Arabic (RTL).
///
/// Runs on a device, through `flutter drive` (see `driver.dart` for why it
/// has no `_test.dart` suffix):
///
///     flutter drive --driver=test/device/driver.dart \
///       --target=test/device/app_flow.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full app flow across tabs, engine game, and RTL',
      (tester) async {
    final container = ProviderContainer();
    await container
        .read(prefsControllerProvider.notifier)
        .restore(systemLangCandidate: 'en');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KarpaChessApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Assert through the real bundle, never English literals: labels are
    // content, and a renamed art once left this test checking for names the
    // app no longer shows.
    final t = (await container.read(i18nProvider.future)).t;

    // Learn tab (default): the real skill map, its arts on screen.
    expect(find.text(t('academy.art.basics')), findsWidgets);
    expect(find.text(t('academy.art.tactics'), skipOffstage: false),
        findsWidgets);

    // Puzzles tab: the rated trainer's packs.
    container.read(activeTabProvider.notifier).state = AppTab.puzzles;
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text(t('puzzles.packs'), skipOffstage: false), findsWidgets);

    // Practice tab: start a game, play 1.e4 and wait for Stockfish. The tab
    // opens on the setup screen — nothing auto-starts a game.
    container.read(activeTabProvider.notifier).state = AppTab.play;
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    container.read(practiceControllerProvider.notifier).newGame();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(container.read(practiceControllerProvider).hasGame, isTrue);

    container
        .read(practiceControllerProvider.notifier)
        .userMove(NormalMove.fromUci('e2e4'));
    // Wait (real time, engine runs off the fake clock) for the reply.
    var replied = false;
    for (var i = 0; i < 40 && !replied; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
      replied = container.read(practiceControllerProvider).moves.length >= 2;
    }
    expect(replied, isTrue, reason: 'Stockfish never replied to 1.e4');

    // The Studio tab lands on its library, search field included.
    container.read(activeTabProvider.notifier).state = AppTab.studio;
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text(t('commentator.searchGames'), skipOffstage: false),
        findsWidgets);

    // Switch to Arabic: app must flip to RTL with the Arabic bundle.
    await container.read(prefsControllerProvider.notifier).setLang('ar');
    var rtl = false;
    for (var i = 0; i < 40 && !rtl; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
      final shell = find.byType(ModeShell);
      rtl = shell.evaluate().isNotEmpty &&
          Directionality.of(tester.element(shell)) == TextDirection.rtl;
    }
    expect(rtl, isTrue, reason: 'app never flipped to RTL after setLang(ar)');

    // Back to English for a clean device state.
    await container.read(prefsControllerProvider.notifier).setLang('en');
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
      final shell = find.byType(ModeShell);
      if (shell.evaluate().isNotEmpty &&
          Directionality.of(tester.element(shell)) == TextDirection.ltr) {
        break;
      }
    }
  });
}
