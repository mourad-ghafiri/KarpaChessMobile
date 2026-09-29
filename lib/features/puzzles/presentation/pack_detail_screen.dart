import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/domain/models.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/progress_bar.dart';
import '../../../core/ui/measure.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../core/ui/surface.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/puzzle_outcome.dart';
import '../application/puzzles_providers.dart';
import 'puzzle_solve_screen.dart';

/// One pack, opened from the Puzzles home: what it teaches, how far through
/// it you are, and every puzzle as its own row — tap any row to play it, or
/// replay it to improve its stored best. A browse screen, not a board
/// screen, so it wears the same chrome as the academy's lesson list.
class PackDetailScreen extends ConsumerWidget {
  const PackDetailScreen({super.key, required this.pack});

  final PuzzlePack pack;

  void _open(BuildContext context, PuzzleRun run) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleSolveScreen(run: run),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final puzzles = ref.watch(packPuzzlesProvider(pack.id)).valueOrNull;
    final results = ref.watch(
      progressionControllerProvider.select((p) => p.puzzleResults),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pack.icon,
              style: TextStyle(fontSize: 20, color: tokens.accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                t(pack.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: context.type.font.display),
              ),
            ),
          ],
        ),
      ),
      body: puzzles == null
          ? const SafeArea(child: Center(child: CircularProgressIndicator()))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The same split ArtView makes: a multi-column grid of
                  // rows whenever there is width for it, a reading-width
                  // column otherwise — rotating a phone should change this
                  // screen's shape the way it changes the academy's.
                  final spec = LayoutSpec.of(constraints);
                  final grid =
                      spec.landscapeCompact || spec.windowClass.atLeastMedium;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Tablets: the grid cap in portrait (three columns,
                        // the pack's twelve as four rows) and the wide cap
                        // in landscape (four columns, three rows). Phones on
                        // their side keep the cap they always had.
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
                      child: _body(
                        context,
                        t,
                        puzzles,
                        results,
                        grid: grid,
                        tablet: spec.tablet,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  static Widget _startButton({required bool tablet, required Widget button}) =>
      tablet ? ButtonMeasure(child: button) : button;

  Widget _body(
    BuildContext context,
    Translate t,
    List<Puzzle> puzzles,
    Map<String, PuzzleOutcome> results, {
    required bool grid,
    required bool tablet,
  }) {
    final solved = puzzles
        .where((p) => results[p.id]?.isSolved ?? false)
        .length;
    final allSolved = puzzles.isNotEmpty && solved == puzzles.length;
    Widget rowAt(int index) => _PuzzleRow(
      puzzle: puzzles[index],
      number: index + 1,
      outcome: results[puzzles[index].id],
      t: t,
      onTap: () => _open(context, SinglePuzzleRun(pack, puzzles[index].id)),
    );
    return ListView(
      padding: AppInsets.page,
      children: [
        _Header(pack: pack, t: t, puzzles: puzzles, solved: solved),
        const SizedBox(height: AppSpacing.md),
        // On a tablet a full-width button here was a ~1000dp slab.
        _startButton(
          tablet: tablet,
          button: FilledButton(
            onPressed: () => _open(context, PackRun(pack)),
            child: Text(
              t(allSolved ? 'puzzles.playAgain' : 'puzzles.continuePack'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              // Fixed cells must cover the tallest row — title plus state
              // word — at the largest text scale the app allows.
              mainAxisExtent: slotHeightFor(context, 72, minimum: 72),
              mainAxisSpacing: AppInsets.gridGap,
              crossAxisSpacing: AppInsets.gridGap,
            ),
            itemCount: puzzles.length,
            itemBuilder: (context, index) => rowAt(index),
          )
        else
          for (final (index, _) in puzzles.indexed) ...[
            if (index > 0) const SizedBox(height: AppInsets.gridGap),
            rowAt(index),
          ],
      ],
    );
  }
}

/// What the pack is about: the authored blurb, the rating range its puzzles
/// span, and how far through it the reader is.
class _Header extends StatelessWidget {
  const _Header({
    required this.pack,
    required this.t,
    required this.puzzles,
    required this.solved,
  });

  final PuzzlePack pack;
  final Translate t;
  final List<Puzzle> puzzles;
  final int solved;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final total = puzzles.length;
    final ratings = [for (final puzzle in puzzles) ?puzzle.rating];
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Top-aligned: a blurb that wraps must not float the rating
            // chip against the middle of its paragraph.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t(pack.blurbKey),
                  style: context.type.label.copyWith(color: tokens.textDim),
                ),
              ),
              if (ratings.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                StatChip(
                  // LTR-isolated (LRI…PDI): in an RTL paragraph the bidi
                  // algorithm would otherwise flip "600-900" to "900-600".
                  label: ratings.length == 1
                      ? '${ratings.first}'
                      : '\u2066${ratings.reduce((a, b) => a < b ? a : b)}–'
                            '${ratings.reduce((a, b) => a > b ? a : b)}\u2069',
                  emoji: '🧩',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedProgressBar(
            value: total == 0 ? 0 : solved / total,
            height: 4,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$solved / $total',
            // A number tally reads left-to-right in every locale; RTL
            // would render 2-of-4 as "4 / 2".
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 11.5, color: tokens.textDim),
          ),
        ],
      ),
    );
  }
}

/// One puzzle of the pack: its state at a glance and a tap to play it.
/// An unattempted or unsolved row shows only its number — a title like
/// "Royal Fork" is half the answer — while any resolved outcome (failed
/// included: the solution was shown) may wear the name.
class _PuzzleRow extends StatelessWidget {
  const _PuzzleRow({
    required this.puzzle,
    required this.number,
    required this.outcome,
    required this.t,
    required this.onTap,
  });

  final Puzzle puzzle;
  final int number;
  final PuzzleOutcome? outcome;
  final Translate t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (IconData glyph, Color glyphColor) = switch (outcome) {
      null => (Icons.circle_outlined, tokens.textFaint),
      PuzzleOutcome.failed => (Icons.close, tokens.danger),
      PuzzleOutcome.solved => (Icons.check_circle, tokens.success),
      PuzzleOutcome.flawless => (Icons.star_rounded, tokens.best),
    };
    final numbered = t('puzzles.puzzleN', {'n': number});
    final title = outcome == null ? numbered : (puzzle.title ?? numbered);
    final stateWord = switch (outcome) {
      null => null,
      PuzzleOutcome.failed => t('puzzles.failed'),
      PuzzleOutcome.solved => t('puzzles.solved'),
      PuzzleOutcome.flawless => t('puzzles.flawless'),
    };
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // An outcome-less row is a single text line (~40dp with padding) —
      // the floor keeps every row a legal tap target.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(glyph, size: 20, color: glyphColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (stateWord != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      stateWord,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: glyphColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (puzzle.rating case final rating?) ...[
              const SizedBox(width: AppSpacing.sm),
              StatChip(label: '$rating'),
            ],
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, size: 18, color: tokens.textFaint),
          ],
        ),
      ),
    );
  }
}
