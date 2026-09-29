/// What the store screenshots (`store_screenshots.dart`) and the layout audit
/// (`layout_audit.dart`) share: one learner a few weeks in, seeded through the
/// app's own repositories before and after launch, and the waits that let the
/// real engine answer on its own thread while frames keep drawing.
///
/// Neither program is part of the test suite. Both run through `flutter drive`
/// with `test/device/driver.dart`, which writes every capture under
/// `build/screenshots/`.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karpachess/app.dart';
import 'package:karpachess/bootstrap.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';
import 'package:karpachess/features/commentator/domain/drawing_shapes.dart';
import 'package:karpachess/features/practice/data/practice_store.dart';
import 'package:karpachess/features/practice/domain/chess_clock.dart';
import 'package:karpachess/features/practice/domain/practice_session.dart';
import 'package:karpachess/prefs/data/shared_prefs_repository.dart';
import 'package:karpachess/prefs/domain/prefs.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/data/shared_prefs_progression_repository.dart';
import 'package:karpachess/progression/domain/lesson_progress.dart';
import 'package:karpachess/progression/domain/progression.dart';
import 'package:karpachess/progression/domain/puzzle_outcome.dart';
import 'package:karpachess/progression/domain/srs_scheduler.dart';

/// The running app, seeded, and the lesson the learner left half-done.
typedef SeededApp = ({ProviderContainer container, String greekGift});

/// Launches the app exactly as a device would restore it: settings, a saved
/// game and an empty Studio on disk before boot, then the learner's progress.
/// [landscape] asks for landscape; iPadOS ignores the request for an app that
/// supports multitasking, Android honours it.
Future<SeededApp> launchSeeded(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required bool landscape,
}) async {
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  await SystemChrome.setPreferredOrientations(
    landscape
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [DeviceOrientation.portraitUp],
  );
  if (Platform.isAndroid) {
    // Draw behind the system bars, as Android 15 and later does for every app
    // that targets API 35+ (this one targets 36). The emulator runs an older
    // Android, where the app's surface stopped short of the bars and a
    // 1080x1920 display captured shorter than the 9:16 Google Play promotes.
    // The app's SafeAreas keep its content clear of the bars either way.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await _seedBeforeLaunch();
  final container = await bootstrap();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const KarpaChessApp(),
    ),
  );
  await waitFor(tester, 3000);
  final greekGift = await _seedProgress(container);
  await waitFor(tester, 1500);
  if (Platform.isAndroid) {
    await binding.convertFlutterSurfaceToImage();
    await waitFor(tester, 500);
  }
  return (container: container, greekGift: greekGift);
}

/// The game on the Play tab: an Italian with two slips of the learner's for
/// Review to find (9.Bd5?! and 11.Ng5?), Black's replies Stockfish's own.
/// White to move, so the restored game sits waiting on the learner.
const practiceGame = [
  'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'd2d3', 'f8c5', //
  'c2c3', 'a7a5', 'e1g1', 'd7d6', 'f1e1', 'e8g8', 'h2h3', 'c5a7', //
  'c4d5', 'f6d5', 'e4d5', 'c6e7', 'f3g5', 'e7d5', 'g5f3', 'd5e7', //
  'c1e3', 'f7f5',
];

/// Settings, the saved game, and an empty Studio — before the app boots, so
/// it restores them exactly as it would on a real launch.
Future<void> _seedBeforeLaunch() async {
  await SharedPrefsRepository().save(
    const Prefs(difficulty: 3, timeControlMinutes: 10, timeControlIncrement: 5),
  );
  await FilePracticeStore().save(
    const PracticeSession(
      uciMoves: practiceGame,
      playAs: 'w',
      orientationIsWhite: true,
      clock: ClockSnapshot(
        initialMs: 600000,
        incrementMs: 5000,
        whiteMs: 462000,
        blackMs: 493000,
      ),
    ),
  );
  await FileCommentatorStore().clear();
}

/// A learner a few weeks in: Foundations done and a start on two more arts,
/// level 8, a twelve-day streak, some trainer packs under way, a few
/// patterns due for review, and the Greek gift lesson left on its beat 5 —
/// ids taken from the app's own skill map. Returns the Greek gift's id.
Future<String> _seedProgress(ProviderContainer container) async {
  final map = await container.read(skillMapProvider.future);
  final greekGift = map.allConcepts
      .firstWhere((c) => c.lessonFile == 'attack-03-greek-gift.json')
      .id;
  final now = DateTime.now();
  final today = PatternMastery.epochDay(now);
  final owned = <String>[
    ...map.arts[0].concepts.map((c) => c.id),
    for (final art in map.arts.skip(1).take(2))
      ...art.concepts.take(4).map((c) => c.id),
  ]..remove(greekGift);
  await SharedPrefsProgressionRepository().save(
    ProgressionState(
      xp: 4200,
      streakDays: 12,
      lastActiveDay: ProgressionState.dayKey(now),
      xpToday: 35,
      puzzleRating: 1480,
      completedNodes: owned.toSet(),
      patterns: {
        for (final (i, id) in owned.indexed)
          id: PatternMastery(
            intervalIndex: 2,
            // Four due today, the rest spread over the coming week.
            dueDay: i < 4 ? today : today + 1 + i % 7,
          ),
      },
      puzzleResults: {
        for (var n = 1; n <= 12; n++)
          'mate-in-one-${n.toString().padLeft(2, '0')}': n.isEven
              ? PuzzleOutcome.flawless
              : PuzzleOutcome.solved,
        for (var n = 1; n <= 7; n++)
          'fork-${n.toString().padLeft(2, '0')}': PuzzleOutcome.solved,
        for (var n = 1; n <= 4; n++)
          'back-rank-mate-${n.toString().padLeft(2, '0')}':
              PuzzleOutcome.solved,
      },
      lessonProgress: {
        greekGift: LessonProgress(
          beat: 5,
          beatCount: 10,
          solvedBeats: {2, 4},
          awardedBeats: {0, 1, 2, 3, 4},
        ),
      },
    ),
  );
  await container.read(progressionControllerProvider.notifier).restore();
  return greekGift;
}

/// Réti–Tartakower, Vienna 1910, before 9.Qd8+, annotated the way the
/// drawing tools draw it: the queen's road to d8, the bishop's double check
/// that follows, the king ringed by hand, and a label. The label is a fact —
/// `dart run tool/puzzles.dart prove` finds a forced mate in 3 there, with
/// 9.Qd8+ its only first move.
///
/// Board units: a8 is the origin, one square per unit. Only shapes the
/// toolbar can make: highlight, arrow, pen, text.
List<DrawShape> mateInThreeAnnotation() {
  BoardSquare at(String square) => BoardSquare(
    8 - int.parse(square[1]),
    square.codeUnitAt(0) - 'a'.codeUnitAt(0),
  );
  final king = squareCenter(at('e8'));
  return [
    HighlightShape(square: at('d8'), color: paletteHex('yellow'), stroke: 0.08),
    ArrowShape(
      points: arrowPointsBetween(at('d3'), at('d8')),
      color: paletteHex('green'),
      stroke: 0.08,
    ),
    ArrowShape(
      points: arrowPointsBetween(at('d2'), at('g5')),
      color: paletteHex('orange'),
      stroke: 0.08,
    ),
    // A pen loop, drawn the way a hand draws one: it starts at the top,
    // widens as it goes round and overshoots where it closes.
    PenShape(
      points: [
        for (var i = 0; i <= 48; i++)
          king +
              Offset(
                cos(-1.9 + i / 48 * 2.2 * pi) * (0.40 + 0.05 * i / 48),
                sin(-1.9 + i / 48 * 2.2 * pi) * (0.35 + 0.04 * i / 48),
              ),
      ],
      color: paletteHex('red'),
      stroke: 0.05,
    ),
    // On e6-h6, the empty stretch of the sixth rank.
    TextShape(
      at: const Offset(6, 2.5),
      text: 'Mate in 3!',
      color: paletteHex('yellow'),
      stroke: 0.08,
    ),
  ];
}

/// A drawing-palette colour by name, so no hex is typed twice.
String paletteHex(String id) => drawColors.firstWhere((c) => c.id == id).hex;

/// Lets real time pass — the engine answers on its own thread — while
/// frames keep drawing.
Future<void> waitFor(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [done] holds, then lets the screen settle.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      fail('timed out after $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await waitFor(tester, 800);
}
