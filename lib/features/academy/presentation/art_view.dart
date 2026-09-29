import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
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
    final tokens = context.tokens;
    final map = ref.watch(skillMapProvider).valueOrNull;
    final progression = ref.watch(progressionControllerProvider);
    final owned = progression.completedNodes;

    final art = map?.arts.where((a) => a.id == artId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (art != null) ...[
              Text(
                art.icon,
                style: TextStyle(fontSize: 20, color: tokens.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                t('academy.art.$artId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: context.type.font.display),
              ),
            ),
          ],
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
                  Widget cardAt(BuildContext context, int index) {
                    final concept = art.concepts[index];
                    return _ConceptCard(
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
                  // tablet and desktop on one narrow column.
                  final spec = LayoutSpec.of(constraints);
                  final grid =
                      spec.landscapeCompact || spec.windowClass.atLeastMedium;
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
                                    maxCrossAxisExtent: spec.tablet
                                        ? _tabletCardExtent
                                        : 300,
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
                                    // 100 covers the card at the default md
                                    // padding (it was 96 over a hand-tuned
                                    // all(10)).
                                    mainAxisExtent: slotHeightFor(
                                      context,
                                      100,
                                      minimum: 100,
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

/// A tablet lesson card's widest; see the grid in [ArtView].
const _tabletCardExtent = 460.0;

class _ConceptCard extends ConsumerWidget {
  const _ConceptCard({
    required this.concept,
    required this.isOwned,
    required this.isNext,
    required this.mastery,
    required this.progress,
    required this.onTap,
  });

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
                    // One line only: the grid branch gives this card a fixed
                    // height, so a second line would overflow every card on a
                    // tablet. The Pattern Book sheet, which scrolls, shows two.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
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
                          style: TextStyle(
                            fontSize: 11.5,
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
                          style: TextStyle(
                            fontSize: 11.5,
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
                    style: TextStyle(
                      fontSize: 11.5,
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
