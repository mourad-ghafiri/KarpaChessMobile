import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/application/content_providers.dart';
import '../../../content/domain/models.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/nav_card.dart';
import '../../../core/ui/progress_bar.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../core/ui/surface.dart';
import '../../../core/ui/symbol_glyph.dart';
import '../../../core/ui/tablet_hero.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/presentation/score_card.dart';
import '../application/puzzles_providers.dart';
import 'pack_detail_screen.dart';
import 'puzzle_solve_screen.dart';

/// The Puzzles home: your rating, one button that always has something to
/// give you, today's puzzle, and the packs.
///
/// The score card at the top is the same widget the Learn tab shows — level,
/// rank, streak and the daily ring are one score across the whole app, and
/// puzzles feed it exactly like lessons do.
class PuzzlesScreen extends ConsumerWidget {
  const PuzzlesScreen({super.key});

  /// A tablet's pack grid: twenty packs as five rows of four in portrait
  /// and four rows of five in landscape — never a row left short.
  static const _packColumnsPortrait = 4;
  static const _packColumnsLandscape = 5;

  static void _open(BuildContext context, PuzzleRun run) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleSolveScreen(run: run),
        fullscreenDialog: true,
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
    final packs = ref.watch(puzzlePackManifestProvider).valueOrNull;
    if (packs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rating = ref.watch(
      progressionControllerProvider.select((p) => p.puzzleRating),
    );
    final progress = ref.watch(packProgressProvider).valueOrNull ?? const {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = LayoutSpec.of(constraints);
        final wc = spec.windowClass;
        final keepGoing = NavCard(
          icon: Icons.play_arrow_rounded,
          title: t('puzzles.keepGoing'),
          subtitle: t('puzzles.keepGoingBlurb'),
          // The rating lives here, on the one control it actually
          // governs — it picks what this button serves. It is not a
          // score and it gates nothing.
          // In words: the same 🧩 chip on the puzzle screen is the PUZZLE's
          // difficulty, so a bare "🧩 1480" here read as one more of those.
          trailing: StatChip(label: '${t('puzzles.rating')} $rating'),
          onTap: () => _open(context, const RatedRun()),
        );
        final daily = NavCard(
          icon: Icons.today_rounded,
          title: t('puzzles.daily'),
          subtitle: t('puzzles.dailyBlurb'),
          onTap: () => _open(context, const DailyRun()),
        );
        final packGrid = GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: spec.tablet
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: spec.split
                      ? _packColumnsLandscape
                      : _packColumnsPortrait,
                  mainAxisSpacing: AppInsets.gridGap,
                  crossAxisSpacing: AppInsets.gridGap,
                  // Four to a row on an iPad mini leaves a card ~147dp wide,
                  // where "Discovered Attacks" takes two lines and 112 came
                  // up 11dp short. 124 is also the height of the art cards on
                  // the Learn home, so the two homes' grids match.
                  mainAxisExtent: slotHeightFor(context, 124, minimum: 124),
                )
              : SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: AppInsets.gridGap,
                  crossAxisSpacing: AppInsets.gridGap,
                  // Fixed cells must cover the tallest card — the mark's
                  // fixed box, a two-line name, bar and tally — at the
                  // largest text scale the app allows; a bare 104
                  // overflowed with a two-line name even at scale 1.0, and
                  // 112 by a hair once the mark had a box of its own.
                  mainAxisExtent: slotHeightFor(context, 118, minimum: 118),
                ),
          children: [
            for (final pack in packs.packs)
              _PackCard(
                pack: pack,
                t: t,
                solved: progress[pack.id] ?? 0,
                // The card opens the pack's own page — pick a
                // puzzle, replay one, or run the pack — rather than
                // dropping straight onto a board.
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PackDetailScreen(pack: pack),
                  ),
                ),
              ),
          ],
        );

        if (spec.tablet) {
          // Tablets: the grid cap in portrait, the wide cap in landscape;
          // the profile and the two big actions as one block on top.
          final pageWidth = math.min(
            constraints.maxWidth,
            spec.split ? ContentWidth.wide : ContentWidth.grid,
          );
          final padding = AppInsets.pageFor(wc);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: pageWidth),
              child: ListView(
                padding: padding,
                children: [
                  Text(t('puzzles.title'), style: context.type.display),
                  const SizedBox(height: AppSpacing.md),
                  TabletHero(
                    profile: const ScoreCard(),
                    actions: [keepGoing, daily],
                    beside:
                        pageWidth - padding.horizontal >= TabletHero.besideAt,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(t('puzzles.packs'), style: context.type.title),
                  const SizedBox(height: AppSpacing.sm),
                  packGrid,
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            // Expanded-and-up windows compose at the wide cap — the grid
            // gains a column and the big actions pair up side by side
            // instead of stacking as two full-width slabs.
            constraints: BoxConstraints(
              maxWidth: wc.atLeastExpanded
                  ? ContentWidth.wide
                  : ContentWidth.grid,
            ),
            child: ListView(
              padding: AppInsets.pageFor(wc),
              children: [
                Text(t('puzzles.title'), style: context.type.display),
                const SizedBox(height: AppSpacing.md),
                const ScoreCard(),
                const SizedBox(height: AppSpacing.md),
                if (wc.isCompact) ...[
                  keepGoing,
                  const SizedBox(height: AppSpacing.md),
                  daily,
                ] else
                  // IntrinsicHeight gives the pair a height to stretch to.
                  // A list hands its children unbounded height, so a bare
                  // stretching Row asked both cards to be infinitely tall and
                  // the whole Puzzles home failed layout on every tablet.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: keepGoing),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: daily),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(t('puzzles.packs'), style: context.type.title),
                const SizedBox(height: AppSpacing.sm),
                packGrid,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.t,
    required this.solved,
    required this.onTap,
  });

  final PuzzlePack pack;
  final Translate t;
  final int solved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final total = pack.puzzleFiles.length;
    final done = total == 0 ? 0.0 : solved / total;

    // Every pack is open. The only thing a card reports is how far through
    // it you are — pick whatever you want to work on.
    return Surface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // In the accent, like the art cards on Learn: the two homes'
              // grids are one kind of tile.
              SymbolGlyph(pack.icon, size: 18, color: tokens.accent),
              const Spacer(),
              if (solved >= total && total > 0)
                Icon(Icons.check_circle, size: 16, color: tokens.success),
            ],
          ),
          const Spacer(),
          Text(
            t(pack.nameKey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.subheading,
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedProgressBar(value: done, height: 4),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                '$solved / $total',
                // A number tally reads left-to-right in every locale; RTL
                // would render 2-of-4 as "4 / 2".
                textDirection: TextDirection.ltr,
                style: context.type.caption.copyWith(color: tokens.textDim),
              ),
              // A finished pack still opens — it runs again as unscored
              // practice — so the card says so. The check alone read as
              // "done, nothing here for you".
              if (solved >= total && total > 0) ...[
                const Spacer(),
                Text(
                  t('puzzles.replay'),
                  style: context.type.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
