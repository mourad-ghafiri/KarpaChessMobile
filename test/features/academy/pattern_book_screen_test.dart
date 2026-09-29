import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/academy/application/academy_providers.dart';
import 'package:karpachess/features/academy/domain/skill_map.dart';
import 'package:karpachess/progression/domain/srs_scheduler.dart';
import 'package:karpachess/features/academy/presentation/concept_player_screen.dart';
import 'package:karpachess/features/academy/presentation/pattern_book_screen.dart';
import 'package:karpachess/features/academy/presentation/sharpen_screen.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/progression/application/progression_controller.dart';
import 'package:karpachess/progression/domain/progression.dart';

import '../../progression/progression_test.dart'
    show MemoryProgressionRepository;
import '../practice/practice_controller_test.dart' show MemoryPrefsRepository;

const _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _conceptId = 'concept:b1.json';

const _lesson = Lesson(
  id: 'b1',
  title: 'Fork Basics',
  summary: 'Forks',
  steps: [
    PlayStep(fen: _startFen, prompt: 'Find it.', targetSan: ['e4']),
  ],
);

SkillMap _map() => SkillMap.build(
      const LessonManifest(categories: [
        LessonCategoryRef(id: 'basics', icon: '♟', lessonFiles: ['b1.json']),
      ]),
    );

Future<(ProviderContainer, I18nService)> pumpBook(
  WidgetTester tester, {
  required PatternMastery mastery,
}) async {
  final repo = MemoryProgressionRepository()
    ..stored = ProgressionState(
      completedNodes: const {_conceptId},
      patterns: {_conceptId: mastery},
    );
  final container = ProviderContainer(overrides: [
    skillMapProvider.overrideWith((ref) async => _map()),
    conceptLessonProvider.overrideWith((ref, id) async => _lesson),
    conceptProofProvider.overrideWith((ref, id) async => null),
    soundServiceProvider.overrideWithValue(const SilentSoundService()),
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
        home: const PatternBookScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return (container, i18n);
}

PatternMastery _dueMastery() {
  final today = PatternMastery.epochDay(DateTime.now());
  return PatternMastery(
    intervalIndex: 1,
    dueDay: today - 1,
  );
}

PatternMastery _sharpMastery() {
  final today = PatternMastery.epochDay(DateTime.now());
  return PatternMastery(
    intervalIndex: 3,
    dueDay: today + 21,
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Fork Basics'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'book shows intro copy and titled cells; the detail sheet reads the '
      'star tier and due state', (tester) async {
    final (_, i18n) = await pumpBook(tester, mastery: _dueMastery());

    expect(find.text(i18n.t('academy.bookIntro')), findsOneWidget);
    expect(find.text('Fork Basics'), findsOneWidget);
    // Tapping a cell opens the sheet — no silent SRS session anymore.
    expect(find.byType(SharpenScreen), findsNothing);

    await openSheet(tester);
    expect(find.text(i18n.t('academy.starBronze')), findsOneWidget);
    expect(find.text(i18n.t('academy.due')), findsOneWidget);
    expect(find.text(i18n.t('academy.reviewNow')), findsOneWidget);
    expect(find.text(i18n.t('academy.replayLesson')), findsOneWidget);
  });

  testWidgets('a sharp gold pattern reads Sharp / Gold in the sheet',
      (tester) async {
    final (_, i18n) = await pumpBook(tester, mastery: _sharpMastery());

    await openSheet(tester);
    expect(find.text(i18n.t('academy.starGold')), findsOneWidget);
    expect(find.text(i18n.t('academy.sharp')), findsOneWidget);
    expect(find.text(i18n.t('academy.due')), findsNothing);
  });

  testWidgets('"Sharpen this pattern" closes the sheet and pushes Sharpen',
      (tester) async {
    final (_, i18n) = await pumpBook(tester, mastery: _dueMastery());

    await openSheet(tester);
    await tester.tap(find.text(i18n.t('academy.reviewNow')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SharpenScreen), findsOneWidget);
    expect(find.text(i18n.t('academy.reviewNow')), findsNothing);
  });

  testWidgets('"Replay lesson" closes the sheet and pushes the player',
      (tester) async {
    final (_, i18n) = await pumpBook(tester, mastery: _dueMastery());

    await openSheet(tester);
    await tester.tap(find.text(i18n.t('academy.replayLesson')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConceptPlayerScreen), findsOneWidget);
  });
}
