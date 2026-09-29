import 'package:dartchess/dartchess.dart' show NormalMove, Square;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/academy/presentation/sharpen_screen.dart';
import 'package:karpachess/features/board/presentation/karpa_board.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';

import '../../progression/progression_test.dart'
    show MemoryProgressionRepository;
import '../practice/practice_controller_test.dart' show MemoryPrefsRepository;

// NOTE: bounded pumps only — the done screen hosts confetti that never
// settles.

const _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

Future<(ProviderContainer, I18nService)> pumpSharpen(
  WidgetTester tester, {
  String fen = _startFen,
  List<String> answers = const ['e4'],
  String prompt = '',
}) async {
  final container = ProviderContainer(overrides: [
    sharpenChallengeProvider.overrideWith(
      (ref, id) async => SharpenChallenge(
        conceptId: id,
        fen: fen,
        answers: answers,
        prompt: prompt,
      ),
    ),
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
        home: const SharpenScreen(conceptIds: ['concept:test.json']),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

void miss(WidgetTester tester) => tester
    .widget<KarpaBoard>(find.byType(KarpaBoard))
    .onMove!(const NormalMove(from: Square.g1, to: Square.f3));

Future<void> teardownOverlay(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'second miss shows the answer and waits for "Got it" — no timer '
      'advance', (tester) async {
    final (_, i18n) = await pumpSharpen(tester);

    miss(tester);
    await tester.pump(const Duration(milliseconds: 800)); // revert
    expect(find.text(i18n.t('academy.showAnswer')), findsNothing);

    miss(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(i18n.t('academy.showAnswer')), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    final gotIt = find.text(i18n.t('academy.gotIt'));
    expect(gotIt, findsOneWidget);

    // Well past the old 1500ms auto-advance: still waiting on the user.
    await tester.pump(const Duration(seconds: 2));
    expect(gotIt, findsOneWidget);

    await tester.tap(gotIt);
    await tester.pump(const Duration(milliseconds: 100));
    // Single-concept queue: acknowledging the answer ends the session.
    expect(find.text(i18n.t('academy.gotIt')), findsNothing);
    expect(find.text(i18n.t('academy.sharpen')), findsOneWidget);

    await teardownOverlay(tester);
  });

  testWidgets('the author\'s setup is shown under "Find the move"',
      (tester) async {
    final (_, i18n) = await pumpSharpen(
      tester,
      prompt: 'Claim the center with a pawn.',
    );

    expect(find.text(i18n.t('academy.findTheMove')), findsOneWidget);
    expect(find.textContaining('Claim the center with a pawn.'), findsOneWidget);

    await teardownOverlay(tester);
  });

  testWidgets('success still auto-advances after its short beat',
      (tester) async {
    final (_, i18n) = await pumpSharpen(tester);

    tester
        .widget<KarpaBoard>(find.byType(KarpaBoard))
        .onMove!(const NormalMove(from: Square.e2, to: Square.e4));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(i18n.t('academy.gotIt')), findsNothing);

    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(i18n.t('academy.sharpen')), findsOneWidget);

    await teardownOverlay(tester);
  });

  testWidgets('a mate other than the authored one is a success',
      (tester) async {
    final (_, i18n) = await pumpSharpen(
      tester,
      // Two rooks and an open back rank: Ra8# and Rb8# both mate.
      fen: '6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1',
      answers: const ['Ra8#'],
    );

    tester
        .widget<KarpaBoard>(find.byType(KarpaBoard))
        .onMove!(const NormalMove(from: Square.b1, to: Square.b8));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(i18n.t('academy.gotIt')), findsNothing);

    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(i18n.t('academy.sharpen')), findsOneWidget);

    await teardownOverlay(tester);
  });

  for (final size in const [Size(1032, 1332), Size(1376, 988)]) {
    testWidgets('renders on a tablet in either orientation ($size)', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (_, i18n) = await pumpSharpen(tester);

      expect(find.byType(KarpaBoard), findsOneWidget);
      expect(find.text(i18n.t('academy.findTheMove')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await teardownOverlay(tester);
    });
  }
}
