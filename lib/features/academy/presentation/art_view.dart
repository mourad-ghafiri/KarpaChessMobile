import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/glyph_title.dart';
import '../../../core/ui/progress_bar.dart';
import '../../../core/ui/surface.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/lesson_progress.dart';
import '../application/academy_providers.dart';
import '../domain/skill_map.dart';
import '../../../progression/domain/srs_scheduler.dart';
import 'concept_player_screen.dart';
import 'pattern_thumb.dart';

/// One art's run of concepts: owned patterns (thumbnail + stars + dullness
/// fade), started lessons wearing their progress bar, and the glowing
/// suggestion of where to go next. Nothing is locked and nothing is dimmed.
class ArtView extends ConsumerWidget {
  const ArtView({super.key, required this.artId});

  final String artId;

  void _openConcept(BuildContext context, String conceptId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConceptPlayerScreen(conceptId: conceptId),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final map = ref.watch(skillMapProvider).valueOrNull;
    final progression = ref.watch(progressionControllerProvider);
    final owned = progression.completedNodes;

    final art = map?.arts.where((a) => a.id == artId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: GlyphTitle(
          glyph: art?.icon ?? '',
          title: t('academy.art.$artId'),
        ),
      ),
      body: map == null || art == null
          ? const SafeArea(child: Center(child: CircularProgressIndicator()))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Every lesson opens. The app is for players of all
                  // strengths, who arrive knowing what they want to work on
                  // — a club player should not have to grind the pawn
                  // lesson to reach the Lucena. `isNext` still marks the
                  // suggested one, which helps a beginner without standing
                  // in anyone's way.
                  final suggested = map.nextConceptIn(artId, owned)?.id;
                  final spec = LayoutSpec.of(constraints);
                  final grid =
                      spec.landscapeCompact || spec.windowClass.atLeastMedium;
                  Widget cardAt(BuildContext context, int index) {
                    final concept = art.concepts[index];
                    return _ConceptCard(
                      summaryLines: grid ? 1 : 2,
                      concept: concept,
                      isOwned: owned.contains(concept.id),
                      isNext: concept.id == suggested,
                      mastery: progression.patterns[concept.id],
                      progress: progression.lessonProgress[concept.id],
                      onTap: () => _openConcept(context, concept.id),
                    );
                  }

                  // A multi-column grid keeps more of the run in view than
                  // ~3.5 rows of a single column. It is worth having whenever
                  // there is width for it — gating on `landscapeCompact`
                  // alone made it a landscape-phone feature and left every
                  // tablet and desktop on one narrow column. (`grid` above.)
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Tablets: the grid cap in portrait, the wide cap in
                        // landscape. Phones on their side keep the cap they
                        // always had.
                        maxWidth: spec.tablet
                            ? spec.split
                                  ? ContentWidth.wide
                                  : ContentWidth.grid
                            : spec.windowClass.atLeastExpanded
                            ? ContentWidth.wide
                            : grid
                            ? ContentWidth.grid
                            : ContentWidth.reading,
                      ),
                      child: grid
                          ? GridView.builder(
                              padding: AppInsets.page,
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    // A tablet's cards are wide enough for
                                    // the title and summary to read whole:
                                    // two columns in portrait, three in
                                    // landscape. At 300 a portrait iPad got
                                    // four ~240dp cards whose summaries cut
                                    // off after twenty characters.
                                    // A phone on its side too: at 300 it
                                    // fitted three ~260dp cards whose titles
                                    // wrapped and whose summaries stopped
                                    // after fifteen characters.
                                    maxCrossAxisExtent: _cardExtent,
                                    // A grid cell is a FIXED height, so it has
                                    // to cover the tallest card — thumb,
                                    // two-line title, summary, star/due row —
                                    // at the largest text scale the app
                                    // allows. It used to be a bare 92, which
                                    // fit only at scale 1.0 with nothing under
                                    // the title; every card overflowed the
                                    // moment either grew. `slotHeightFor`
                                    // scales it the way the art grid already
                                    // scales its own cells.
                                    // 104 covers a two-line title, the
                                    // summary and the star row at the md
                                    // padding and the card's hairline; 100
                                    // overflowed by 2dp whenever a title
                                    // wrapped.
                                    mainAxisExtent: slotHeightFor(
                                      context,
                                      104,
                                      minimum: 104,
                                    ),
                                    mainAxisSpacing: AppInsets.gridGap,
                                    crossAxisSpacing: AppInsets.gridGap,
                                  ),
                              itemCount: art.concepts.length,
                              itemBuilder: cardAt,
                            )
                          : ListView.separated(
                              padding: AppInsets.page,
                              itemCount: art.concepts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppInsets.gridGap),
                              itemBuilder: cardAt,
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// A lesson card's widest in the grid branch; see the grid in [ArtView].
const _cardExtent = 460.0;

class _ConceptCard extends ConsumerWidget {
  const _ConceptCard({
    required this.summaryLines,
    required this.concept,
    required this.isOwned,
    required this.isNext,
    required this.mastery,
    required this.progress,
    required this.onTap,
  });

  /// How many lines the summary may take: two in the phone's list, where
  /// the card sizes itself, one in the fixed-height grid cell.
  final int summaryLines;

  final Concept concept;
  final bool isOwned;
  final bool isNext;
  final PatternMastery? mastery;

  /// Where an unfinished run of this lesson stands — the card's progress
  /// bar. Null when never started (or already owned, which clears it).
  final LessonProgress? progress;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final t = ref.watch(i18nProvider).requireValue.t;
    final lesson = ref.watch(conceptLessonProvider(concept.id)).valueOrNull;
    final title = lesson?.title ?? '';
    final summary = lesson?.summary ?? '';
    final today = PatternMastery.epochDay(DateTime.now());
    final dullness = isOwned ? (mastery?.dullness(today) ?? 0.0) : 0.0;
    final isDue = isOwned && (mastery?.isDue(today) ?? false);

    // Every lesson shows the position it teaches, whether or not you have
    // reached it — a padlock told you nothing about what was behind it.
    final leading = PatternThumb(
      conceptId: concept.id,
      size: 68,
      dullness: dullness,
    );

    final card = Surface(
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                  ),
                ),
                // The one line the lesson promises. It was authored for
                // every lesson and rendered nowhere, so a card carried a
                // title and a thumbnail and nothing that said why to tap it.
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    // One line in the grid branch, whose fixed cell would
                    // overflow with a second; two in the phone's list, where
                    // one line cut every summary mid-thought ("One move that
                    // asks two questions, and a…").
                    maxLines: summaryLines,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      height: 1.25,
                      color: tokens.textDim,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                if (isOwned && isDue)
                  Row(
                    children: [
                      StarPips(stars: mastery?.stars ?? 0),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          t('academy.due'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isOwned)
                  StarPips(stars: mastery?.stars ?? 0)
                else if (progress case final progress?)
                  // A started lesson wears its own progress and an
                  // invitation to pick it back up — reopening resumes at
                  // the recorded beat.
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedProgressBar(
                          value: progress.completion,
                          height: 4,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Flexible: a bare Text in a Row can never ellipsize
                      // — a long translation would stripe the card instead.
                      Flexible(
                        child: Text(
                          t('academy.resume'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isNext)
                  Text(
                    t('academy.upNext'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: isNext ? tokens.accent : tokens.textDim,
          ),
        ],
      ),
    );

    if (isNext) {
      // The next pattern to earn glows: accent ring + soft halo.
      return DecoratedBox(
        decoration: BoxDecoration(
          // The ring traces the Surface it decorates — same token, so the
          // two can never desync.
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tokens.accent, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: card,
      );
    }
    // Every card renders at full strength: a dimmed card reads as a locked
    // one, and nothing here is locked.
    return card;
  }
}
