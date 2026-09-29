import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/surface.dart';
import '../../../core/ui/tablet_hero.dart';
import '../../../progression/presentation/score_card.dart';
import '../../../core/ui/progress_ring.dart';
import '../../../progression/application/progression_controller.dart';
import '../application/academy_providers.dart';
import '../domain/skill_map.dart';
import 'art_view.dart';
import 'pattern_book_screen.dart';
import 'sharpen_screen.dart';

/// Academy home — "The Master's Path". Collect chess patterns
/// (SEE → PLAY → OWN) and keep them sharp through spaced reviews.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  /// A tablet page this wide lays the eight arts out as two rows of four;
  /// a narrower one (the iPad mini in portrait) as four rows of two. Never
  /// three: eight arts in threes leave a row of two hanging.
  static const _fourArtsAt = 640.0;

  static void _push(
    BuildContext context,
    Widget screen, {
    bool fullscreenDialog = true,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider).valueOrNull;
    if (i18n == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = i18n.t;
    final map = ref.watch(skillMapProvider).valueOrNull;
    if (map == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tokens = context.tokens;
    final progression = ref.watch(progressionControllerProvider);
    final owned = progression.completedNodes;
    final now = DateTime.now();
    final due = progression.duePatterns(now);
    final continueTarget = map.continueTarget(owned);
    final totalConcepts = map.allConcepts.length;
    final ownedTotal = map.allConcepts
        .where((c) => owned.contains(c.id))
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = LayoutSpec.of(constraints);
        final wc = spec.windowClass;

        final title = Text(t('academy.title'), style: context.type.display);
        const titleCard = ScoreCard();
        final sharpenCard = _SharpenCard(
          t: t,
          p: i18n.plural,
          dueCount: due.length,
          onTap: due.isEmpty
              ? null
              : () => _push(
                  context,
                  SharpenScreen(conceptIds: due.take(10).toList()),
                ),
        );
        final continueButton = continueTarget == null
            ? null
            : _ContinueButton(
                t: t,
                target: continueTarget,
                onTap: () => _push(
                  context,
                  ArtView(artId: continueTarget.artId),
                  fullscreenDialog: false,
                ),
              );
        // Tablets compose the page from the width they have, in either
        // orientation (below); phones keep the two layouts they always had.
        final pageWidth = math.min(
          constraints.maxWidth,
          spec.split ? ContentWidth.wide : ContentWidth.grid,
        );
        final inner = pageWidth - AppInsets.pageFor(wc).horizontal;
        Widget artsGrid(int columns) => GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppInsets.gridGap,
            crossAxisSpacing: AppInsets.gridGap,
            // A card is icon row + a two-line title + a tally. All three
            // grow with the reader's type, so the cell has to as well —
            // at 1.3x the content measured ~121dp against a flat 124.
            mainAxisExtent: slotHeightFor(context, 124, minimum: 124),
          ),
          children: [
            for (final art in map.arts)
              _ArtCard(
                art: art,
                t: t,
                owned: owned,
                onTap: () => _push(
                  context,
                  ArtView(artId: art.id),
                  fullscreenDialog: false,
                ),
              ),
          ],
        );
        final patternBookCard = Surface(
          onTap: () => _push(
            context,
            const PatternBookScreen(),
            fullscreenDialog: false,
          ),
          child: Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('academy.patternBook'), style: context.type.heading),
                    const SizedBox(height: 2),
                    Text(
                      t('academy.ownedCount', {
                        'n': ownedTotal,
                        'total': totalConcepts,
                      }),
                      style: TextStyle(fontSize: 12, color: tokens.textDim),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.textDim),
            ],
          ),
        );

        if (spec.tablet) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: pageWidth),
              child: ListView(
                padding: AppInsets.pageFor(wc),
                children: [
                  title,
                  const SizedBox(height: AppSpacing.md),
                  TabletHero(
                    profile: titleCard,
                    actions: [sharpenCard, ?continueButton],
                    beside: inner >= TabletHero.besideAt,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  artsGrid(inner >= _fourArtsAt ? 4 : 2),
                  const SizedBox(height: AppSpacing.md),
                  patternBookCard,
                ],
              ),
            ),
          );
        }

        if (spec.landscapeCompact) {
          // Landscape phones: everything stacked is ~1.7 viewports of
          // scrolling — split into two side-by-side scrollable columns,
          // profile and continue on one side, the arts on the other.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.wide),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      // Directional: the Row flips in RTL and the inner
                      // half-gutter has to flip with it (lg edges, sm inner —
                      // the two halves meet as one lg-wide middle gutter).
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                      ),
                      children: [
                        title,
                        const SizedBox(height: AppSpacing.md),
                        titleCard,
                        const SizedBox(height: AppSpacing.md),
                        sharpenCard,
                        if (continueButton != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          continueButton,
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: [
                        artsGrid(2),
                        const SizedBox(height: AppSpacing.md),
                        patternBookCard,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.grid),
            child: ListView(
              padding: AppInsets.pageFor(wc),
              children: [
                title,
                const SizedBox(height: AppSpacing.md),
                titleCard,
                const SizedBox(height: AppSpacing.md),
                sharpenCard,
                if (continueButton != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  continueButton,
                ],
                const SizedBox(height: AppSpacing.lg),
                artsGrid(2),
                const SizedBox(height: AppSpacing.md),
                patternBookCard,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Continue · {lesson title}" — opens the lesson *list* (the art view)
/// so finishing a run always lands the learner back on the list. Falls
/// back to a bare "Continue" while the title is still loading.
class _ContinueButton extends ConsumerWidget {
  const _ContinueButton({
    required this.t,
    required this.target,
    required this.onTap,
  });

  final Translate t;
  final Concept target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref
        .watch(conceptLessonProvider(target.id))
        .valueOrNull
        ?.title;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        // Theme height and type; only the weight is this button's own.
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(
        title == null || title.isEmpty
            ? t('academy.continueBtn')
            : t('academy.continueLesson', {'title': title}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SharpenCard extends StatelessWidget {
  const _SharpenCard(
      {required this.t,
      required this.p,
      required this.dueCount,
      this.onTap});

  final Translate t;
  final Pluralize p;
  final int dueCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (dueCount == 0) {
      return Surface(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: tokens.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                t('academy.sharpenAllSharp'),
                style: TextStyle(color: tokens.textDim),
              ),
            ),
          ],
        ),
      );
    }
    return Surface(
      wash: tokens.accent,
      onTap: onTap,
      child: Row(
        children: [
          Text('⚔', style: TextStyle(fontSize: 26, color: tokens.accent)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('academy.sharpen'), style: context.type.heading),
                const SizedBox(height: 2),
                Text(
                  p('academy.sharpenDull', dueCount),
                  style: TextStyle(fontSize: 12.5, color: tokens.textDim),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: tokens.accent),
        ],
      ),
    );
  }
}

/// One of the Six Arts: glyph, mastery ring, owned tally.
class _ArtCard extends StatelessWidget {
  const _ArtCard({
    required this.art,
    required this.t,
    required this.owned,
    required this.onTap,
  });

  final Art art;
  final Translate t;
  final Set<String> owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ownedCount = art.concepts.where((c) => owned.contains(c.id)).length;
    return Surface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                art.icon,
                style: TextStyle(fontSize: 22, color: tokens.accent),
              ),
              const Spacer(),
              ProgressRing(
                progress: art.progress(owned),
                size: 28,
                strokeWidth: 3,
              ),
            ],
          ),
          const Spacer(),
          Text(
            t('academy.art.${art.id}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: context.type.font.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t('academy.ownedCount', {
              'n': ownedCount,
              'total': art.concepts.length,
            }),
            style: TextStyle(fontSize: 11, color: tokens.textDim),
          ),
        ],
      ),
    );
  }
}
