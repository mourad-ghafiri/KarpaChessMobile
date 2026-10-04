import 'package:chessground/chessground.dart' show Annotation, PlayerSide;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/chess/tolerant_position.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/text/html_lite.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../board/presentation/board_stage.dart';
import '../../../core/ui/surface.dart';
import '../../../core/ui/mode_header_bar.dart';
import '../../../core/ui/move_list_card.dart';
import '../../../core/ui/player_card.dart';
import '../../../core/ui/quality_style.dart';
import '../../../core/ui/replay_bar.dart';
import '../../../core/ui/stat_chip.dart';
import '../../board/presentation/karpa_board.dart';
import '../application/review_controller.dart';
import '../domain/review_explainer.dart';

/// Match Review: the replay controls drive the board while an always-open
/// coaching card explains the selected move — verdict, evaluation swing,
/// what the engine preferred and why, plus what to notice in the position.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  /// Ceiling on the coaching card in a side pane, as a share of the whole
  /// mode's height — the list above it absorbs what the card leaves.
  static const _explanationShare = 0.45;

  /// Held from initState: `ref` may not be used in dispose(), where the
  /// batch has to be stopped.
  late final ReviewController _review;

  @override
  void initState() {
    super.initState();
    _review = ref.read(reviewControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _review.start();
    });
  }

  @override
  void dispose() {
    // Popping review must stop the batch — the engine would otherwise burn
    // through every remaining position of the game.
    _review.cancel();
    super.dispose();
  }

  /// Seek to ply [index]; -1 (or below) selects the start position.
  void _seekTo(int index) {
    final moves = ref.read(reviewControllerProvider).moves;
    final notifier = ref.read(reviewControllerProvider.notifier);
    if (moves.isEmpty) {
      notifier.select(null);
      return;
    }
    final clamped = index.clamp(-1, moves.length - 1);
    notifier.select(clamped < 0 ? null : clamped);
  }

  void _seekBy(int delta) {
    final current = ref.read(reviewControllerProvider).selectedIndex ?? -1;
    _seekTo(current + delta);
  }

  /// The learner's next move in tally [bucket] after the one shown, wrapping
  /// round — so a tally chip walks its own moves ("1 Mistake" → that move).
  void _seekToNextIn(String bucket) {
    final review = ref.read(reviewControllerProvider);
    final moves = review.moves;
    final from = review.selectedIndex ?? -1;
    for (var step = 1; step <= moves.length; step++) {
      final i = (from + step) % moves.length;
      if (moves[i].isUserTurn && moves[i].labelKey == bucket) {
        _seekTo(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(reviewControllerProvider);
    final i18n = ref.watch(i18nProvider).requireValue;
    final t = i18n.t;
    final tokens = context.tokens;

    final selected = review.selected;
    final position = positionFromFen(review.boardFen);
    // No drawn elements in review — the verdict rides on the piece as a
    // studio-style quality badge; the engine's preference stays textual.
    final annotations = {
      if (selected != null && selected.quality != null)
        selected.played.move.to: Annotation(
          symbol: selected.quality!.glyph,
          color: selected.quality!.colorOf(tokens),
        ),
    };

    final tallies = review.tallies;

    // Sized by the panel it lands in: a fixed 280dp overflowed the side
    // panel in landscape, which is the one place this is on screen longest.
    Widget progress() => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: review.totalCount == 0
                ? null
                : review.analyzedCount / review.totalCount,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            review.totalCount == 0
                ? t('review.analyzing')
                : t('review.progress', {
                    'i': review.analyzedCount,
                    'total': review.totalCount,
                  }),
            style: context.type.caption.copyWith(color: tokens.textDim),
          ),
        ],
      ),
    );

    // Five buckets, five chips. `review_controller` folds MoveQuality into
    // five keys; rendering only four silently dropped every move in the
    // 20-60cp band, so the chips did not add up to the game.
    List<Widget> tallyChips() => [
      for (final (key, labelKey, color) in [
        ('good', 'review.tally.best', tokens.best),
        ('ok', 'review.tally.ok', tokens.good),
        ('inaccuracy', 'review.tally.inaccurate', tokens.inaccuracy),
        ('mistake', 'review.tally.mistake', tokens.mistake),
        ('blunder', 'review.tally.blunder', tokens.blunder),
      ])
        // A count of zero is a fact, not a warning: it stays neutral rather
        // than wearing the blunder red. A non-zero chip jumps to its moves.
        Semantics(
          button: tallies[key]! > 0,
          child: InkWell(
            onTap: tallies[key]! > 0 ? () => _seekToNextIn(key) : null,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: StatChip(
                label: '${tallies[key]} ${t(labelKey)}',
                color: tallies[key]! > 0 ? color : null,
                filled: tallies[key]! > 0,
              ),
            ),
          ),
        ),
    ];

    // Two lines by meaning — what went right, then what went wrong — rather
    // than one wrap: five chips are a little wider than a phone, so the wrap
    // broke four and one and left "0 Blunder" alone on its row.
    Widget talliesRow() {
      final chips = tallyChips();
      Widget line(List<Widget> group) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 0,
        alignment: WrapAlignment.center,
        children: group,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          line(chips.sublist(0, 2)),
          line(chips.sublist(2)),
        ],
      );
    }

    // The stacked column's above-board row is a fixed slot, so there the
    // tallies are ONE line that scrolls sideways rather than a wrap that
    // could outgrow it on a narrow window. Centred while it fits.
    Widget talliesStrip() => Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, chip) in tallyChips().indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              chip,
            ],
          ],
        ),
      ),
    );

    // The coaching card: always visible for the selected ply — the whole
    // point of Review is reading these, so nothing is hidden behind a
    // toggle. It follows the scrubber because it derives from `selected`.
    Widget explanationCard() => selected == null
        ? const SizedBox.shrink()
        : Surface(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _ExplanationBody(
              t: t,
              explanation: explainMove(selected, t, i18n.plural),
            ),
          );

    Widget replayBar() => ReplayBar(
      t: t,
      count: review.moves.length,
      index: review.selectedIndex ?? -1,
      onSeek: _seekTo,
    );

    // The side pane's move list: the whole game with its verdicts, the
    // scrubber's random-access twin. Badges land progressively as the
    // batch analyzes.
    Widget moveList() => MoveListCard(
      t: t,
      entries: [
        for (var i = 0; i < review.moves.length; i++)
          MoveListEntry(
            san: review.moves[i].played.san,
            // Reviews replay practice games, which always start from
            // the initial position — ply arithmetic is exact.
            moveNumber: i ~/ 2 + 1,
            isWhite: review.moves[i].played.moverColor == 'w',
            quality: review.moves[i].quality,
          ),
      ],
      currentIndex: review.selectedIndex ?? -1,
      onSelect: _seekTo,
    );

    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _seekBy(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _seekBy(1),
            const SingleActivator(LogicalKeyboardKey.home): () => _seekTo(-1),
            const SingleActivator(LogicalKeyboardKey.end): () =>
                _seekTo(review.moves.length - 1),
          },
          child: Focus(
            autofocus: true,
            // ModePanes owns the board geometry; the tallies/context/replay
            // content lives in the panel and can never move the board.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = ModePanes.layoutFor(constraints);
                return ModePanes(
                  // Review used to wear a Material AppBar while every other
                  // board screen used the shared header, which cost it 56dp of
                  // unconditional chrome on a landscape phone and made it the
                  // one mode with different game furniture.
                  topBar: ModeHeaderBar(
                    label: t('review.title'),
                    actionIcon: Icons.close,
                    actionTooltip: t('ui.button.close'),
                    onAction: () => Navigator.of(context).pop(),
                  ),
                  topBarHeight: ModeHeaderBar.height,
                  // The stacked column books an above-board row for every
                  // mode, so the board sits exactly where Play's did; Review
                  // spends it on the tallies instead of leaving it bare.
                  aboveBoard: layout == ModeLayout.stacked && !review.running
                      ? talliesStrip()
                      : null,
                  aboveHeight: PlayerBarCard.height,
                  boardBuilder: (context, boardSize) => BoardStage(
                    size: boardSize,
                    builder: (board) => [
                      KarpaBoard(
                        size: board,
                        position: position,
                        orientation: review.orientation,
                        lastMove: selected?.played.move,
                        playerSide: PlayerSide.none,
                        annotations: annotations,
                        animate: false,
                      ),
                    ],
                  ),
                  panel: review.running
                      ? SingleChildScrollView(
                          padding: AppInsets.panel,
                          child: Center(child: progress()),
                        )
                      : switch (layout) {
                          // A phone on its side keeps the phone column's
                          // panel: its pane is ~330dp tall, and the tallies
                          // plus the coaching card left the move list a few
                          // dp of clipped rows. The card is what Review is
                          // for; the replay bar under it still walks the game.
                          ModeLayout.compact ||
                          ModeLayout.landscapeCompact => SingleChildScrollView(
                            padding: AppInsets.panel,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                talliesRow(),
                                const SizedBox(height: AppSpacing.sm),
                                explanationCard(),
                              ],
                            ),
                          ),
                          // Side pane: the move list fills the slack between
                          // the tallies and the coaching card — the pane used
                          // to be mostly empty screen. The card keeps its
                          // natural height up to a share of the mode, then
                          // scrolls inside itself; the list absorbs whatever
                          // the card leaves.
                          ModeLayout.twoPane => Padding(
                            padding: AppInsets.panel,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                talliesRow(),
                                const SizedBox(height: AppSpacing.sm),
                                Expanded(child: moveList()),
                                if (selected != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          constraints.maxHeight *
                                          _explanationShare,
                                    ),
                                    child: SingleChildScrollView(
                                      child: explanationCard(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Under a portrait tablet's board the panel is wide
                          // and short: the list and the card sit side by side,
                          // each scrolling in its own half, rather than one
                          // pushing the other below the fold.
                          ModeLayout.stacked => Padding(
                            padding: AppInsets.panel,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 2, child: moveList()),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    child: explanationCard(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        },
                  // No horizontal padding: same replay-bar treatment as the
                  // Studio panel.
                  actionBar: review.running ? null : replayBar(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The review explanation rendered in the
/// same visual grammar as the studio's insight body: verdict row, "better
/// was" prose, bulleted insights, then the narrative sentence in an accent
/// wash. Engine plies arrive as the light form (SAN + eval swing only).
class _ExplanationBody extends StatelessWidget {
  const _ExplanationBody({required this.t, required this.explanation});

  final Translate t;
  final ReviewExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final e = explanation;
    final quality = e.quality;

    // Every string here comes from the coach's i18n, which carries the
    // html-lite subset — the same renderer as the bullets below.
    final type = context.type;
    // Quality hues are picked to read on the page; on a card some fall short
    // of 4.5:1 (blunder 3.9, inaccuracy 3.8 in the lights), so the words
    // take a legible ink of the same hue.
    final verdictInk = quality == null
        ? null
        : tokens.legible(quality.colorOf(tokens), on: tokens.panel);
    Widget prose(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: HtmlLiteText(
        text,
        style: type.label.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.35,
          color: tokens.textDim,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (quality != null) ...[
              Text(
                quality.glyph,
                style: type.heading.copyWith(
                  fontFamily: type.font.body,
                  fontWeight: FontWeight.w900,
                  color: verdictInk,
                ),
              ),
              const SizedBox(width: 7),
              // Flexible: a long localized verdict ("Неточность") must
              // ellipsize, not push the SAN and swing out of the pane.
              Flexible(
                child: Text(
                  t(e.verdictLabelKey!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.body.copyWith(
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: verdictInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                e.playedSan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.san.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (e.evalSwing != null) ...[
              const SizedBox(width: 8),
              Text(
                e.evalSwing!,
                style: context.type.san.copyWith(color: tokens.textDim),
              ),
            ],
          ],
        ),
        if (e.betterLine != null) prose(e.betterLine!),
        if (e.bestWhy != null) prose(e.bestWhy!),
        for (final insight in e.insights)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsetsDirectional.only(top: 6, end: 7),
                  decoration: BoxDecoration(
                    color: tokens.info,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: HtmlLiteText(
                    insight,
                    style: context.type.caption.copyWith(color: tokens.textDim),
                  ),
                ),
              ],
            ),
          ),
        if (e.narrativeKey != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: HtmlLiteText(
              t(e.narrativeKey!, e.narrativeParams),
              style: type.label.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.35,
                color: tokens.text,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
