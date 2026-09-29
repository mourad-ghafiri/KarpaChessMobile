import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/media/avatar_store.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/surface.dart';
import '../../../core/ui/measure.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/action_bar.dart';
import '../../board/presentation/board_stage.dart';
import '../../../core/ui/celebration_overlay.dart';
import '../../../core/ui/drawing_mode_bar.dart';
import '../../../core/ui/hint_toast.dart';
import '../../../core/ui/mode_header_bar.dart';
import '../../../core/ui/move_list_card.dart';
import '../../../core/chess/captured_material.dart';
import '../../../core/ui/captured_pieces.dart';
import '../../../core/ui/player_card.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../prefs/application/prefs_controller.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/progression.dart';
import '../../board/presentation/karpa_board.dart';
import '../../coach/application/coach_hint_controller.dart';
import '../../coach/domain/coach_menu.dart';
import '../../coach/presentation/coach_hint_view.dart';
import '../../commentator/application/drawing_controller.dart';
import '../../commentator/presentation/drawing_overlay.dart';
import '../../practice/application/practice_controller.dart';
import '../../practice/domain/practice_models.dart';
import '../../review/presentation/review_screen.dart';

/// Play mode: a persona-based setup screen, then a focus-mode game against
/// Stockfish — board front and center, no unsolicited text: coaching only
/// arrives through the on-demand hint card.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  bool _resultSheetShown = false;

  void _startGame() {
    _resultSheetShown = false;
    ref
        .read(drawingControllerProvider(DrawingScope.play).notifier)
        .resetLayer();
    ref.read(practiceControllerProvider.notifier).newGame();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(i18nProvider).requireValue.t;

    // Result celebration sheet (and haptic), once per game.
    ref.listen(practiceControllerProvider.select((s) => s.result), (
      previous,
      next,
    ) {
      if (previous == null && next != null) {
        ref.hapticMedium();
        if (!_resultSheetShown) {
          _resultSheetShown = true;
          _awardResultXp();
          _showResultSheet(t);
        }
      }
    });

    // Move haptics live in PracticeController._commit — one source only.

    // Drawing mode is modal: freeze the game clock while it is active.
    ref.listen(
      drawingControllerProvider(DrawingScope.play).select((s) => s.active),
      (previous, next) {
        final practice = ref.read(practiceControllerProvider.notifier);
        if (next) {
          practice.pauseClock();
        } else if (previous == true) {
          practice.resumeClock();
        }
      },
    );

    // Which screen to show is the controller's business, not this widget's.
    // Held as a local `bool` it was destroyed every time the shell swapped
    // between the bottom bar and the rail — so rotating mid-game dropped the
    // reader on the setup screen — and no restart could ever restore it.
    final status = ref.watch(
      practiceControllerProvider.select((s) => s.status),
    );
    return switch (status) {
      // Still asking the store whether a game was left behind. Showing the
      // setup screen here would flash it away a frame later.
      PracticeStatus.restoring => const SizedBox.shrink(),
      PracticeStatus.idle => _SetupView(onPlay: _startGame),
      PracticeStatus.active => _GameView(
        t: t,
        // Abandon the running game: the old clock must not keep ticking
        // toward a phantom timeout behind the setup screen.
        onNewGame: ref.read(practiceControllerProvider.notifier).abandon,
      ),
    };
  }

  /// Full-screen level-up celebration on the ROOT navigator, so the scrim
  /// covers the shell's navigation chrome too (the in-tab Stack left the
  /// nav bar tappable mid-celebration).
  void _showLevelUpCelebration() {
    final t = ref.read(i18nProvider).requireValue.t;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Motion.base,
        reverseTransitionDuration: Motion.fast,
        pageBuilder: (routeContext, animation, _) => FadeTransition(
          opacity: animation,
          child: CelebrationOverlay(
            emoji: '🚀',
            title: t('gamify.levelUp'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(routeContext).pop(),
                child: Text(t('ui.button.close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _awardResultXp() async {
    final state = ref.read(practiceControllerProvider);
    if (!state.userWon) return;
    final difficulty = ref.read(prefsControllerProvider).difficulty;
    final leveledUp = await ref
        .read(progressionControllerProvider.notifier)
        .award(XpRules.winByDifficulty[difficulty] ?? 15);
    if (leveledUp && mounted) {
      _showLevelUpCelebration();
    }
  }

  void _showResultSheet(Translate t) {
    final state = ref.read(practiceControllerProvider);
    final result = state.result;
    if (result == null || !mounted) return;

    final (emoji, title, sub) = switch (result.kind) {
      GameResultKind.checkmate => (
        state.userWon ? '🏆' : (state.userLost ? '🫡' : '🏁'),
        state.userWon ? t('play.youWon') : t('play.youLost'),
        t(
          result.winner == 'w'
              ? 'game.resultSub.whiteWins'
              : 'game.resultSub.blackWins',
        ),
      ),
      GameResultKind.stalemate => (
        '🤝',
        t('game.result.stalemate'),
        t('game.resultSub.stalemate'),
      ),
      GameResultKind.draw50 => (
        '🤝',
        t('game.result.draw'),
        t('game.resultSub.fiftyMove'),
      ),
      GameResultKind.drawMaterial => (
        '🤝',
        t('game.result.draw'),
        t('game.resultSub.insufficient'),
      ),
      GameResultKind.repetition => (
        '🤝',
        t('game.result.draw'),
        t('game.resultSub.repetition'),
      ),
      GameResultKind.timeout => (
        '⏱',
        t('game.result.timeout'),
        t(
          result.winner == 'w'
              ? 'game.resultSub.whiteWinsTime'
              : 'game.resultSub.blackWinsTime',
        ),
      ),
    };

    final difficulty = ref.read(prefsControllerProvider).difficulty;
    showAppSheet<void>(
      context,
      builder: (sheetContext) => Padding(
        padding: AppInsets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: context.type.display),
            Text(sub, style: TextStyle(color: sheetContext.tokens.textDim)),
            if (state.userWon) ...[
              const SizedBox(height: AppSpacing.sm),
              StatChip(
                label: t('gamify.earned', {
                  'n': XpRules.winByDifficulty[difficulty] ?? 15,
                }),
                color: sheetContext.tokens.accent,
                filled: true,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.query_stats, size: 18),
                    label: Text(t('play.review')),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReviewScreen(),
                          // A board screen, covered modally like the other
                          // five modes — not slid in like a browse page.
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text(t('play.rematch')),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _startGame();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Setup — persona cards, color, time, one accent CTA
// ===================================================================

class _SetupView extends ConsumerWidget {
  const _SetupView({required this.onPlay});

  final VoidCallback onPlay;

  static const _personaGlyphs = ['♟', '♞', '♝', '♛'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsControllerProvider);
    final prefsCtl = ref.read(prefsControllerProvider.notifier);
    final t = ref.watch(i18nProvider).requireValue.t;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = LayoutSpec.of(constraints);
        final wc = spec.windowClass;

        final cta = FilledButton(
          onPressed: onPlay,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(t('play.nav')),
        );

        final title = Text(t('play.title'), style: context.type.display);

        // The section idiom the other home tabs use: a `title`-role label over
        // its content (the Puzzles home does exactly this for "Packs").
        Widget section(String label) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(label, style: context.type.title),
        );

        // ---- opponent strength ----
        // Slim rows (glyph beside the text), so the whole setup — personas,
        // color, time and the Play button — fits a phone without scrolling.
        // Scaled: two text lines outgrow a flat 76 the moment the text scale
        // does.
        final personaExtent = slotHeightFor(context, 76, minimum: 76);
        final personasGrid = GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // A tablet always lays the four out two by two: its 600–720dp
          // column fitted three to a row, which left the fourth alone.
          gridDelegate: spec.tablet
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppInsets.gridGap,
                  crossAxisSpacing: AppInsets.gridGap,
                  mainAxisExtent: personaExtent,
                )
              : SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: AppInsets.gridGap,
                  crossAxisSpacing: AppInsets.gridGap,
                  mainAxisExtent: personaExtent,
                ),
          children: [
            for (var level = 1; level <= 4; level++)
              _PersonaCard(
                glyph: _personaGlyphs[level - 1],
                name: t('game.difficulty.$level'),
                hint: t('play.strengthHint.$level'),
                selected: prefs.difficulty == level,
                onTap: () => prefsCtl.setDifficulty(level),
              ),
          ],
        );

        // ---- color ----
        final colorRow = Row(
          children: [
            for (final (value, glyph, labelKey) in const [
              ('w', '♔', 'game.playAsOption.white'),
              ('random', '⚄', 'game.playAsOption.random'),
              ('b', '♚', 'game.playAsOption.black'),
            ]) ...[
              if (value != 'w') const SizedBox(width: 10),
              Expanded(
                child: _ColorTile(
                  glyph: glyph,
                  label: t(labelKey),
                  selected: prefs.playAs == value,
                  onTap: () => prefsCtl.setPlayAs(value),
                ),
              ),
            ],
          ],
        );

        // ---- time ----
        final timeWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (minutes, increment, label) in [
              (null, 0, t('game.timeControl.unlimited')),
              (10, 0, '10+0'),
              (15, 10, '15+10'),
              (3, 2, '3+2'),
            ])
              ChoiceChip(
                label: Text(label),
                selected:
                    prefs.timeControlMinutes == minutes &&
                    prefs.timeControlIncrement == increment,
                selectedColor: context.tokens.accentSoft,
                onSelected: (_) => prefsCtl.setTimeControl(
                  minutes: minutes,
                  increment: increment,
                ),
              ),
          ],
        );

        // Landscape phones: two columns so the CTA sits beside the
        // personas instead of below the fold; the ListView still scrolls
        // if the window gets even shorter. Landscape tablets reuse the same
        // split at the wide cap; a portrait tablet stacks in one column.
        final split = spec.split;
        final children = split
            ? <Widget>[
                title,
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          section(t('ui.label.difficulty')),
                          personasGrid,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          section(t('ui.label.playAs')),
                          colorRow,
                          const SizedBox(height: AppSpacing.lg),
                          section(t('ui.label.timeControl')),
                          timeWrap,
                          const SizedBox(height: AppSpacing.xl),
                          ButtonMeasure(child: cta),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : <Widget>[
                title,
                const SizedBox(height: AppSpacing.md),
                // No ScoreCard here, deliberately: with it the Play button
                // fell below the fold, and a setup screen whose CTA needs
                // scrolling is broken. The profile strip lives on the Learn
                // and Puzzles homes.
                section(t('ui.label.difficulty')),
                personasGrid,
                const SizedBox(height: AppSpacing.lg),
                section(t('ui.label.playAs')),
                colorRow,
                const SizedBox(height: AppSpacing.lg),
                section(t('ui.label.timeControl')),
                timeWrap,
                const SizedBox(height: AppSpacing.xl),
                if (wc.isCompact)
                  cta
                else
                  Center(
                    child: SizedBox(width: ContentWidth.button, child: cta),
                  ),
              ];

        final maxWidth = split ? ContentWidth.wide : ContentWidth.form;
        if (spec.tablet) {
          // A tablet's setup fits its window, so it is centred there as one
          // block, in both orientations, rather than hugging the top of a
          // page two-thirds empty. It still scrolls if a window is ever too
          // short for it.
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: AppInsets.pageFor(wc),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(padding: AppInsets.pageFor(wc), children: children),
          ),
        );
      },
    );
  }
}

/// The selection idiom the rest of the app already speaks — the academy's
/// "up next" glow, the player bar's to-move ring: an accent ring plus a soft
/// halo around a [Surface]. Animated so switching choices glides.
class _SelectedRing extends StatelessWidget {
  const _SelectedRing({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: Motion.fast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: selected ? tokens.accent : Colors.transparent,
          width: 1.6,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: tokens.accentSoft,
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.glyph,
    required this.name,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String name;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _SelectedRing(
      selected: selected,
      child: Surface(
        onTap: onTap,
        wash: selected ? tokens.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              glyph,
              style: TextStyle(
                fontSize: 22,
                color: selected ? tokens.accent : tokens.textDim,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.type.heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hint,
                    style: context.type.caption.copyWith(color: tokens.textDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _SelectedRing(
      selected: selected,
      child: Surface(
        onTap: onTap,
        wash: selected ? tokens.accent : null,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              glyph,
              style: TextStyle(
                fontSize: 22,
                color: selected ? tokens.accent : tokens.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: context.type.caption.copyWith(
                color: selected ? tokens.accent : tokens.textDim,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Game — focus mode
// ===================================================================

class _GameView extends ConsumerWidget {
  const _GameView({required this.t, required this.onNewGame});

  final Translate t;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);
    final prefs = ref.watch(prefsControllerProvider);
    final tokens = context.tokens;
    final drawingActive = ref.watch(
      drawingControllerProvider(DrawingScope.play).select((s) => s.active),
    );

    final engineSide = state.playAs == 'w' ? 'b' : 'w';
    final topSide = state.orientation == Side.white ? 'b' : 'w';
    final bottomSide = topSide == 'w' ? 'b' : 'w';

    // Drawing mode is modal: the board only annotates, never moves.
    final playerSide = drawingActive || state.result != null
        ? PlayerSide.none
        : state.playAs == 'w'
        ? PlayerSide.white
        : PlayerSide.black;

    // 'Game paused' chip: only while drawing over a live game with a clock.
    final showPausedChip = drawingActive && state.result == null;

    // Derived once for both bars: one read of the board answers for both
    // sides, and both cards then agree by construction.
    final material = CapturedMaterial.of(state.position.board);

    Widget playerBar(String side) => _PlayerBar(
      t: t,
      isEngine: side == engineSide,
      name: side == engineSide
          ? 'Stockfish'
          : (prefs.playerName.isNotEmpty
                ? prefs.playerName
                : t('game.playerDefault.bottom')),
      meta: side == engineSide
          ? t('game.difficulty.${prefs.difficulty}')
          : null,
      avatarPath: side == engineSide ? null : prefs.playerAvatarPath,
      clockMs: side == 'w' ? state.whiteMs : state.blackMs,
      timed: state.timedGame,
      active: state.result == null && state.turn == side,
      thinking: side == engineSide && state.engineThinking,
      material: material,
      side: side == 'w' ? Side.white : Side.black,
    );

    // The unified hint toast: floats above the action bar via
    // ModePanes.toast — never in the panel scroll, always closable.
    // The hint surface: pick a question, the coach answers. Text only —
    // no move arrows are drawn on the practice board.
    final hint = ref.watch(coachHintControllerProvider(HintScope.practice));
    final hintController = ref.read(
      coachHintControllerProvider(HintScope.practice).notifier,
    );
    final hintToast = !hint.open
        ? null
        : HintToast(
            title: hint.intent == null
                ? t('ui.button.hint')
                : t(coachIntentLabelKey(hint.intent!)),
            loading: hint.loading,
            onClose: hintController.close,
            child: const CoachHintView(scope: HintScope.practice),
          );

    Widget actionRow() => Row(
      children: [
        Expanded(
          child: ActionBar(
            actions: [
              BarAction(
                icon: Icons.lightbulb_outline,
                tooltip: t('ui.button.hint'),
                // Toggle semantics, matching the studio: tap again to
                // dismiss the toast.
                onTap: hintController.toggle,
                active: hint.open,
              ),
              BarAction(
                icon: Icons.swap_vert,
                tooltip: t('ui.button.flip'),
                onTap: controller.flipBoard,
              ),
              BarAction(
                icon: Icons.undo,
                tooltip: t('ui.button.undo'),
                onTap: state.moves.isEmpty ? null : controller.undo,
              ),
            ],
          ),
        ),
        DrawingModeButton(scope: DrawingScope.play, t: t),
        const SizedBox(width: 12),
      ],
    );

    // Destructive: leaving a live game asks first; a finished game exits
    // straight away.
    Future<void> confirmExit() async {
      if (state.result != null || state.moves.isEmpty) {
        onNewGame();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t('play.exitMatch')),
          content: Text(t('play.exitConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t('ui.button.dismiss')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t('play.exitMatch')),
            ),
          ],
        ),
      );
      if (confirmed ?? false) onNewGame();
    }

    Widget shortcuts(Widget child) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): controller.flipBoard,
        const SingleActivator(LogicalKeyboardKey.keyH): hintController.toggle,
        const SingleActivator(LogicalKeyboardKey.keyN): confirmExit,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final drawing = ref.read(
            drawingControllerProvider(DrawingScope.play),
          );
          if (drawing.active) {
            ref
                .read(drawingControllerProvider(DrawingScope.play).notifier)
                .exitMode();
          }
        },
      },
      child: Focus(autofocus: true, child: child),
    );

    // ModePanes owns the board geometry: fixed slots for the player bars,
    // a floating drawing bar; everything transient (paused chip, hint
    // card) lives in the panel so it can never move the board.
    return shortcuts(
      LayoutBuilder(
        builder: (context, constraints) => ModePanes(
          topBar: ModeHeaderBar(
            label: 'Stockfish · ${t('game.difficulty.${prefs.difficulty}')}',
            actionIcon: Icons.close,
            actionTooltip: t('play.exitMatch'),
            onAction: confirmExit,
          ),
          topBarHeight: ModeHeaderBar.height,
          overlayBar: DrawingModeBar(scope: DrawingScope.play, t: t),
          overlayBarHeight: DrawingModeBar.height,
          toast: hintToast,
          aboveBoard: playerBar(topSide),
          belowBoard: playerBar(bottomSide),
          aboveHeight: PlayerBarCard.height,
          belowHeight: PlayerBarCard.height,
          boardBuilder: (context, boardSize) => BoardStage(
            size: boardSize,
            builder: (board) => [
              KarpaBoard(
                size: board,
                position: state.position,
                orientation: state.orientation,
                lastMove: state.lastMove,
                playerSide: playerSide,
                onMove: controller.userMove,
              ),
              DrawingOverlay(
                size: board,
                t: t,
                scope: DrawingScope.play,
                orientation: state.orientation,
              ),
            ],
          ),
          // The phone column keeps the pane as pure slack under the board;
          // every other composition — a side pane, or the room a portrait
          // tablet keeps under its board — fills it with the game's move
          // list, read-only: Play is live, not a scrubber.
          panel: ModePanes.layoutFor(constraints).listsMoves
              ? Padding(
                  padding: AppInsets.panel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPausedChip) ...[
                        Center(
                          child: StatChip(
                            label: t('draw.paused'),
                            icon: Icons.pause_circle_outline,
                            color: tokens.accent,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Expanded(child: _PlayMoveList(t: t)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: AppInsets.panel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPausedChip)
                        Center(
                          child: StatChip(
                            label: t('draw.paused'),
                            icon: Icons.pause_circle_outline,
                            color: tokens.accent,
                            filled: true,
                          ),
                        ),
                    ],
                  ),
                ),
          actionBar: actionRow(),
        ),
      ),
    );
  }
}

/// The side pane's move list: the live game's SAN history, current move
/// last. Watches ONLY the move list — the per-second clock ticks that
/// rebuild the rest of the screen never touch it (`moves` is replaced,
/// never mutated, so the identity-compared select is airtight).
class _PlayMoveList extends ConsumerWidget {
  const _PlayMoveList({required this.t});

  final Translate t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(practiceControllerProvider.select((s) => s.moves));
    return MoveListCard(
      t: t,
      entries: [
        for (var i = 0; i < moves.length; i++)
          MoveListEntry(
            // Practice games always start from the initial position, so
            // ply arithmetic is exact and no FEN needs parsing.
            san: moves[i].san,
            moveNumber: i ~/ 2 + 1,
            isWhite: moves[i].moverColor == 'w',
          ),
      ],
      currentIndex: moves.length - 1,
    );
  }
}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.t,
    required this.isEngine,
    required this.name,
    required this.meta,
    required this.avatarPath,
    required this.clockMs,
    required this.timed,
    required this.active,
    required this.thinking,
    required this.material,
    required this.side,
  });

  final Translate t;
  final bool isEngine;
  final String name;
  final String? meta;
  final String? avatarPath;

  /// Remaining ms when [timed], accumulated thinking ms otherwise — the
  /// controller keeps this non-null for every game now, so the card always
  /// carries a time.
  final int clockMs;
  final bool timed;
  final bool active;
  final bool thinking;

  /// Read from the board, so it is the same derivation the Studio uses and it
  /// survives a restored game whose move list was cut short.
  final CapturedMaterial material;
  final Side side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return PlayerBarCard(
      toMove: active,
      identity: PlayerIdentity(
        name: name,
        subtitle: isEngine ? (thinking ? '…' : meta) : null,
        avatarPath: avatarPath,
        glyph: isEngine ? '🐟' : '🙂',
        active: active,
        // Stockfish keeps its identity; only the human is editable.
        onEdit: isEngine ? null : () => _editProfile(context, ref),
      ),
      trailing: StatChip(
        label: _format(clockMs, countUp: !timed),
        // The hourglass marks a count-UP: thinking time spent, not time left.
        icon: timed ? Icons.timer_outlined : Icons.hourglass_bottom,
        color: active ? tokens.accent : tokens.textDim,
        filled: active,
      ),
      captured: CapturedPieces(
        roles: material.capturedBy(side),
        lead: material.leadFor(side),
        semanticsLabel: t(side == Side.white
            ? 'ui.aria.capturedByWhite'
            : 'ui.aria.capturedByBlack'),
      ),
    );
  }

  /// Name + picture editor for the human player (prefs-backed).
  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(prefsControllerProvider);
    final prefsCtl = ref.read(prefsControllerProvider.notifier);
    final input = TextEditingController(text: prefs.playerName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, dialogRef, _) {
          final avatarPath = dialogRef.watch(
            prefsControllerProvider.select((p) => p.playerAvatarPath),
          );
          return AlertDialog(
            // Hosts a TextField: the keyboard leaves little room on a
            // landscape phone, so the content scrolls rather than overflows.
            scrollable: true,
            title: Text(t('play.editProfile')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: input,
                  autofocus: true,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: t('play.yourName'),
                    hintText: t('game.playerDefault.bottom'),
                  ),
                  onSubmitted: (value) {
                    prefsCtl.setPlayerName(value);
                    Navigator.of(dialogContext).pop();
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: Text(t('play.choosePicture')),
                  onPressed: () async {
                    try {
                      // Capped at 1024px: the avatar never draws larger than
                      // a small circle, and a full-resolution gallery photo
                      // would be a multi-megabyte copy in app storage.
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 90,
                      );
                      if (picked == null) return;
                      final stored = await dialogRef
                          .read(avatarStoreProvider)
                          .store(picked.path);
                      await prefsCtl.setPlayerAvatarPath(stored);
                    } catch (_) {
                      // Picker unavailable, or the copy failed: keep the
                      // previous picture.
                    }
                  },
                ),
                if (avatarPath != null)
                  TextButton.icon(
                    icon: const Icon(Icons.no_photography_outlined, size: 18),
                    label: Text(t('play.removePicture')),
                    onPressed: () async {
                      await dialogRef.read(avatarStoreProvider).remove();
                      await prefsCtl.setPlayerAvatarPath(null);
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(t('ui.button.dismiss')),
              ),
              FilledButton(
                onPressed: () {
                  prefsCtl.setPlayerName(input.text);
                  Navigator.of(dialogContext).pop();
                },
                child: Text(t('ui.button.save')),
              ),
            ],
          );
        },
      ),
    );
    input.dispose();
  }

  String _format(int ms, {required bool countUp}) {
    // Ceil for a countdown so a live clock never reads 0:00; floor for
    // elapsed so a fresh game starts at 0:00 rather than 0:01.
    final total = countUp ? ms ~/ 1000 : (ms / 1000).ceil();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}
