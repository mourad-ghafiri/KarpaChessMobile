import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/measure.dart';
import '../../../progression/application/progression_controller.dart';
import '../application/academy_providers.dart';
import '../../../progression/domain/srs_scheduler.dart';
import 'concept_player_screen.dart';
import 'pattern_thumb.dart';
import 'sharpen_screen.dart';

/// The Pattern Book: every owned pattern as a board thumbnail with its
/// title, stars and dullness. Tapping one opens a detail sheet with the
/// choice to sharpen the pattern or replay its lesson.
class PatternBookScreen extends ConsumerWidget {
  const PatternBookScreen({super.key});

  /// The page's cap. Tablets take the grid cap in portrait and the wide cap
  /// in landscape; phones keep the one they always had.
  static double _pageCap(LayoutSpec spec) => spec.tablet
      ? spec.split
            ? ContentWidth.wide
            : ContentWidth.grid
      : spec.windowClass.atLeastExpanded
      ? ContentWidth.wide
      : ContentWidth.grid;

  void _openDetail(BuildContext context, String conceptId) {
    showAppSheet<void>(
      context,
      builder: (_) => _PatternDetailSheet(
        conceptId: conceptId,
        // The sheet pops itself before invoking these, so the pushes run
        // on the still-mounted screen context.
        onSharpen: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SharpenScreen(conceptIds: [conceptId]),
            fullscreenDialog: true,
          ),
        ),
        onReplay: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConceptPlayerScreen(conceptId: conceptId),
            fullscreenDialog: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final map = ref.watch(skillMapProvider).valueOrNull;
    final progression = ref.watch(progressionControllerProvider);
    final owned = progression.completedNodes;
    final today = PatternMastery.epochDay(DateTime.now());

    final ownedConcepts = map == null
        ? const <String>[]
        : [
            for (final concept in map.allConcepts)
              if (owned.contains(concept.id)) concept.id,
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📖 ${t('academy.patternBook')}',
          style: TextStyle(fontFamily: context.type.font.display),
        ),
      ),
      body: map == null
          ? const SafeArea(child: Center(child: CircularProgressIndicator()))
          : ownedConcepts.isEmpty
          ? SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  // A reading measure, or a tablet sets the sentence on one
                  // line across the whole window.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ContentWidth.reading,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '♟',
                          style: TextStyle(
                            fontSize: 44,
                            color: tokens.textFaint,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // An unexplained pawn told a new reader nothing.
                        Text(
                          t('academy.bookEmpty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: tokens.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              // The class is read from the WINDOW, above the cap: the
              // cap itself is what the class chooses, so reading it
              // below the ConstrainedBox would pin the answer.
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _pageCap(LayoutSpec.of(constraints)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            0,
                          ),
                          // One line across a tablet's page ran to ~800dp.
                          child: ReadingMeasure(
                            child: Text(
                              t('academy.bookIntro'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: tokens.textDim,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          // Column count follows the width the grid is
                          // actually given. A `WindowClass` read here saw
                          // the enclosing cap rather than the window, so
                          // the expanded and wide tiers were unreachable
                          // and the count was effectively hardcoded.
                          child: GridView.builder(
                            padding: AppInsets.page,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 160,
                                  mainAxisSpacing: AppInsets.gridGap,
                                  crossAxisSpacing: AppInsets.gridGap,
                                  childAspectRatio: 0.66,
                                ),
                            itemCount: ownedConcepts.length,
                            itemBuilder: (context, index) {
                              final conceptId = ownedConcepts[index];
                              return _BookCell(
                                conceptId: conceptId,
                                mastery: progression.patterns[conceptId],
                                today: today,
                                onTap: () => _openDetail(context, conceptId),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// One grid entry: thumbnail (dullness-faded), stars, lesson title.
class _BookCell extends ConsumerWidget {
  const _BookCell({
    required this.conceptId,
    required this.mastery,
    required this.today,
    required this.onTap,
  });

  final String conceptId;
  final PatternMastery? mastery;
  final int today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final title =
        ref.watch(conceptLessonProvider(conceptId)).valueOrNull?.title ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, cell) => Center(
                child: PatternThumb(
                  conceptId: conceptId,
                  size: cell.biggest.shortestSide,
                  dullness: mastery?.dullness(today) ?? 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          StarPips(stars: mastery?.stars ?? 0),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: tokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet detail for one owned pattern: mini board, star tier, due
/// state, and the two actions (sharpen now / replay the lesson).
class _PatternDetailSheet extends ConsumerWidget {
  const _PatternDetailSheet({
    required this.conceptId,
    required this.onSharpen,
    required this.onReplay,
  });

  final String conceptId;
  final VoidCallback onSharpen;
  final VoidCallback onReplay;

  static String starLabelKey(int stars) => switch (stars) {
    1 => 'academy.starBronze',
    2 => 'academy.starSilver',
    3 => 'academy.starGold',
    _ => 'academy.starNone',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final lesson = ref.watch(conceptLessonProvider(conceptId)).valueOrNull;
    final title = lesson?.title ?? '';
    final summary = lesson?.summary ?? '';
    final mastery = ref.watch(
      progressionControllerProvider.select((p) => p.patterns[conceptId]),
    );
    final today = PatternMastery.epochDay(DateTime.now());
    final stars = mastery?.stars ?? 0;
    final isDue = mastery?.isDue(today) ?? false;

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      // No scroll view of its own: `showAppSheet` already provides one, and
      // a nested unbounded scrollable never actually scrolled — it only
      // split the keyboard inset and the content padding across two views.
      child: Padding(
        padding: AppInsets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.type.title,
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: tokens.textDim,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PatternThumb(
              conceptId: conceptId,
              size: 148,
              dullness: mastery?.dullness(today) ?? 0,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StarPips(stars: stars),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    t(starLabelKey(stars)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: tokens.textDim),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isDue ? t('academy.due') : t('academy.sharp'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDue ? tokens.accent : tokens.success,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Theme height (48) — these were the app's only sub-standard
            // primary buttons.
            FilledButton(
              onPressed: () => closeThen(onSharpen),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(t('academy.reviewNow')),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: () => closeThen(onReplay),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(t('academy.replayLesson')),
            ),
          ],
        ),
      ),
    );
  }
}
