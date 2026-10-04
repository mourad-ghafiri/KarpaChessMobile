import 'package:chessground/chessground.dart' show Annotation, PlayerSide;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../content/domain/models.dart';
import '../../../core/chess/captured_material.dart';
import '../../../core/chess/tolerant_position.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/action_bar.dart';
import '../../../core/ui/captured_pieces.dart';
import '../../board/presentation/board_stage.dart';
import '../../../core/ui/drawing_mode_bar.dart';
import '../../../core/ui/hint_toast.dart';
import '../../../core/ui/mode_header_bar.dart';
import '../../../core/ui/move_list_card.dart';
import '../../../core/ui/player_card.dart';
import '../../../core/ui/quality_style.dart';
import '../../../core/ui/replay_bar.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../prefs/application/prefs_controller.dart';
import '../../board/presentation/karpa_board.dart';
import '../../coach/application/coach_hint_controller.dart';
import '../../coach/domain/coach_menu.dart';
import '../../coach/presentation/coach_hint_view.dart';
import '../application/commentator_controller.dart';
import '../application/drawing_controller.dart';
import '../domain/move_tree.dart';
import 'drawing_overlay.dart';
import 'move_rows.dart';

/// The Studio's study mode: a board-first study surface — nothing is
/// written under the board, the move's verdict rides on the piece as a
/// badge, and the moves button opens the full game list. Drawing mode is
/// modal: while active the board is annotation-only.
class StudioStudyView extends ConsumerStatefulWidget {
  const StudioStudyView({super.key});

  @override
  ConsumerState<StudioStudyView> createState() => _StudioStudyViewState();
}

class _StudioStudyViewState extends ConsumerState<StudioStudyView> {
  /// Whether the moves overlay (move-list HintToast) is open. The insight
  /// toast takes visual priority when both want the slot.
  bool _showMoves = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final state = ref.watch(commentatorControllerProvider);
    final tree = state.tree;
    final node = state.currentNode;
    if (tree == null || node == null) return const SizedBox.shrink();
    final notifier = ref.read(commentatorControllerProvider.notifier);
    final prefs = ref.watch(prefsControllerProvider);
    final drawingActive = ref.watch(
      drawingControllerProvider(DrawingScope.studio).select((s) => s.active),
    );

    final position = positionFromFen(node.positionFen);
    final hint = ref.watch(coachHintControllerProvider(HintScope.studio));
    final hintController = ref.read(
      coachHintControllerProvider(HintScope.studio).notifier,
    );

    final topSide = state.orientation == Side.white ? 'b' : 'w';
    final bottomSide = topSide == 'w' ? 'b' : 'w';

    // One read of the board answers for both cards, and it tracks the node —
    // so stepping into a side line and back updates what each player has taken.
    final material = CapturedMaterial.of(position.board);

    // ReplayBar navigates the mainline: one tick per move (root = -1).
    final mainlineMoves = tree.mainline().skip(1).toList();
    final replayBar = ReplayBar(
      t: t,
      count: mainlineMoves.length,
      index: tree.plyOf(tree.mainlineAncestor(node)) - 1,
      onSeek: (i) =>
          i < 0 ? notifier.goToStart() : notifier.goToNode(mainlineMoves[i].id),
      onReadoutTap: () => setState(() => _showMoves = true),
    );

    // Slim bar under the ReplayBar: hint, analyze, flip, main line,
    // badges, recap, draw.
    final controls = Row(
      children: [
        Expanded(
          child: ActionBar(
            actions: [
              BarAction(
                icon: Icons.lightbulb_outline,
                tooltip: t('ui.button.hint'),
                active: hint.open,
                onTap: () {
                  // The hint owns the toast slot; drop the moves overlay so
                  // it doesn't pop back when the hint closes.
                  setState(() => _showMoves = false);
                  hintController.toggle();
                },
              ),
              BarAction(
                icon: Icons.swap_vert,
                tooltip: t('ui.button.flip'),
                onTap: notifier.flipOrientation,
              ),
              // Always present so the icon row never reflows; it lights up
              // as the branch indicator and returns to the main line.
              BarAction(
                icon: Icons.alt_route,
                tooltip: t('commentator.mainLine'),
                active: state.offMainline,
                onTap: state.offMainline ? notifier.returnToMainline : null,
              ),
              BarAction(
                icon: prefs.commentatorBadges
                    ? Icons.visibility
                    : Icons.visibility_off,
                tooltip: t(
                  prefs.commentatorBadges
                      ? 'commentator.badgesHide'
                      : 'commentator.badgesShow',
                ),
                active: prefs.commentatorBadges,
                onTap: () => ref
                    .read(prefsControllerProvider.notifier)
                    .setCommentatorBadges(!prefs.commentatorBadges),
              ),
              BarAction(
                icon: Icons.emoji_events_outlined,
                tooltip: t('commentator.result.title'),
                onTap: notifier.openRecap,
              ),
            ],
          ),
        ),
        DrawingModeButton(scope: DrawingScope.studio, t: t),
        const SizedBox(width: 12),
      ],
    );

    // Board stability contract: the board pane holds only fixed-height
    // slots (drawing bar + player bars); everything variable scrolls in
    // the panel, so content changes can never move the board.
    final whiteName = state.white.name.isNotEmpty
        ? state.white.name
        : t('game.side.white');
    final blackName = state.black.name.isNotEmpty
        ? state.black.name
        : t('game.side.black');

    Widget panes(ModeLayout composition) => ModePanes(
      topBar: ModeHeaderBar(
        // Named the way its library card names it ("Réti – Tartakower"),
        // not as the database writes players ("Reti, Richard – …").
        label: GameRecord.pairingOf(whiteName, blackName),
        actionIcon: Icons.close,
        actionTooltip: t('commentator.close'),
        onAction: () => _confirmClose(context, t),
      ),
      topBarHeight: ModeHeaderBar.height,
      // No overlayBar: the Studio is the one mode where the drawing tools do
      // not float. Drawing is modal here — the board is annotation-only and
      // the replay controls are meaningless while it runs — so the tools
      // take the replay row's place in the pinned zone instead of stacking
      // a second bar over a row nobody can use.
      // The toast slot: the coach hint wins over the moves overlay, and
      // drawing wins over both. Drawing is already modal here — the board
      // is annotation-only while it runs — and the Studio is the one mode
      // whose pinned zone is two rows deep, so a toast on top of the tools
      // is the single combination that will not fit a phone panel.
      toast: drawingActive
          ? null
          : hint.open
          ? HintToast(
              title: hint.intent == null
                  ? t('ui.button.hint')
                  : t(coachIntentLabelKey(hint.intent!)),
              loading: hint.loading,
              onClose: hintController.close,
              child: const CoachHintView(scope: HintScope.studio),
            )
          : _showMoves
          ? HintToast(
              icon: Icons.format_list_bulleted,
              title: t('commentator.moves'),
              onClose: () => setState(() => _showMoves = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: moveLineRows(
                  tree: tree,
                  currentNodeId: node.id,
                  onSelect: notifier.goToNode,
                ),
              ),
            )
          : null,
      aboveHeight: PlayerBarCard.height,
      belowHeight: PlayerBarCard.height,
      aboveBoard: _PlayerBar(
        t: t,
        side: topSide,
        state: state,
        tree: tree,
        node: node,
        toMove: _sideOf(position.turn) == topSide,
        material: material,
      ),
      belowBoard: _PlayerBar(
        t: t,
        side: bottomSide,
        state: state,
        tree: tree,
        node: node,
        toMove: _sideOf(position.turn) == bottomSide,
        material: material,
      ),
      boardBuilder: (context, boardSize) {
        Widget stage = BoardStage(
          size: boardSize,
          // A side line is a different reality: the frame leaves the wood
          // until the user is back on the game that was actually played.
          sideline: state.offMainline,
          builder: (board) => [
            KarpaBoard(
              size: board,
              position: position,
              orientation: state.orientation,
              lastMove: node.move,
              // The side line reads on the wood too: the same info hue the
              // bezel turns, washed under the pieces at matched strength.
              wash: state.offMainline
                  ? tokens.info.withValues(alpha: BoardStage.sidelineWash)
                  : null,
              // Drawing mode is modal: no variation-forking moves while
              // active.
              playerSide: drawingActive ? PlayerSide.none : PlayerSide.both,
              onMove: notifier.playMove,
              annotations: {
                if (prefs.commentatorBadges &&
                    node.quality != null &&
                    node.move != null)
                  node.move!.to: Annotation(
                    symbol: node.quality!.glyph,
                    color: node.quality!.colorOf(tokens),
                  ),
              },
            ),
            DrawingOverlay(size: board, t: t),
          ],
        );
        if (!drawingActive) {
          stage = GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -240) {
                notifier.forward();
              } else if (velocity > 240) {
                notifier.back();
              }
            },
            child: stage,
          );
        }
        return stage;
      },
      // The panel NEVER lists a move past the board. A study is walked move
      // by move, and a list that shows the line ahead spoils the whole match
      // before the reader has played through it; the moves toast is the one
      // deliberate, opt-in view of the game. On a phone the panel stays
      // empty. A tablet has a side pane (or the room under a portrait
      // board) to fill, and fills it with the moves SO FAR — the path from
      // the start to the position on the board, which is the one list that
      // cannot give anything away.
      panel: switch (composition) {
        ModeLayout.compact ||
        ModeLayout.landscapeCompact => const SizedBox.shrink(),
        ModeLayout.stacked || ModeLayout.twoPane => Padding(
          padding: AppInsets.panel,
          child: _MovesSoFar(
            t: t,
            tree: tree,
            node: node,
            badges: prefs.commentatorBadges,
            // Drawing is modal — the board is annotation-only, so the list
            // does not navigate either.
            onSelect: drawingActive ? null : notifier.goToNode,
          ),
        ),
      },
      actionBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The top row is EITHER the replay controls OR the drawing tools,
          // never both: entering drawing mode swaps the tools into the
          // navigation row's place. The pencil on the row below stays, so
          // leaving the mode is the same tap that entered it.
          AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            child: drawingActive
                ? Padding(
                    key: const ValueKey('drawing-row'),
                    // The bar carries no horizontal margin of its own (its
                    // float slot used to inset it); match the action rows'
                    // 12dp edges here instead.
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DrawingModeBar(scope: DrawingScope.studio, t: t),
                  )
                // No extra horizontal padding on the ReplayBar side: it
                // packs a five-button nav row that needs the width on
                // narrow phones.
                : Row(
                    key: const ValueKey('replay-row'),
                    children: [
                      Expanded(child: replayBar),
                      // Same button geometry and same 12dp trailing gap as
                      // the DrawingModeButton on the row below, so the two
                      // trailing icons sit on one vertical axis instead of
                      // 10dp apart.
                      IconButton(
                        tooltip: t('commentator.moves'),
                        icon: Icon(
                          Icons.format_list_bulleted,
                          color: _showMoves ? tokens.accent : tokens.textDim,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _showMoves
                              ? tokens.accentSoft
                              : null,
                        ),
                        onPressed: () =>
                            setState(() => _showMoves = !_showMoves),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
          ),
          controls,
        ],
      ),
    );

    // Desktop keyboard: arrows/Home/End navigate, Escape exits drawing.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): notifier.back,
        const SingleActivator(LogicalKeyboardKey.arrowRight): notifier.forward,
        const SingleActivator(LogicalKeyboardKey.home): notifier.goToStart,
        const SingleActivator(LogicalKeyboardKey.end): notifier.goToEnd,
        const SingleActivator(LogicalKeyboardKey.escape): () => ref
            .read(drawingControllerProvider(DrawingScope.studio).notifier)
            .exitMode(),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              panes(ModePanes.layoutFor(constraints)),
        ),
      ),
    );
  }

  Future<void> _confirmClose(BuildContext context, Translate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('commentator.close')),
        content: Text(t('commentator.confirmClose')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ui.button.dismiss')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('ui.button.close')),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      ref.read(commentatorControllerProvider.notifier).closeGame();
    }
  }

  static String _sideOf(Side side) => side == Side.white ? 'w' : 'b';
}

// ===================================================================
// Player bars
// ===================================================================

/// The tablet panel's move list: the moves that led to the board and
/// nothing past it — [MoveTree.lineTo] of the current node. It shrinks when
/// the reader steps back, because it is the path to the position shown, not
/// a record of how far they once read. The verdict glyphs follow the board's
/// badges switch; the side-line marker stays off, since it would hint at
/// where the annotator branched ahead of the reader.
class _MovesSoFar extends StatelessWidget {
  const _MovesSoFar({
    required this.t,
    required this.tree,
    required this.node,
    required this.badges,
    required this.onSelect,
  });

  final Translate t;
  final MoveTree tree;
  final MoveTreeNode node;
  final bool badges;

  /// Jumps to a node by id; null while drawing makes the list read-only.
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final line = tree.lineTo(node);
    final select = onSelect;
    return MoveListCard(
      t: t,
      entries: [
        for (final move in line)
          MoveListEntry(
            san: move.san!,
            // From the parent's FEN, so a study that starts mid-game from a
            // [FEN] tag numbers its moves correctly.
            moveNumber: tree.moveNumberOf(move),
            isWhite: move.mover == 'w',
            quality: badges ? move.quality : null,
          ),
      ],
      currentIndex: line.length - 1,
      onSelect: select == null ? null : (i) => select(line[i].id),
    );
  }
}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.t,
    required this.side,
    required this.state,
    required this.tree,
    required this.node,
    required this.toMove,
    required this.material,
  });

  final Translate t;

  /// 'w' | 'b'.
  final String side;
  final CommentatorState state;
  final MoveTree tree;
  final MoveTreeNode node;
  final bool toMove;

  /// Read from the node's own position, which is the only thing that is true
  /// once the reader steps into a side line — a list of moves played would
  /// describe a game other than the one on screen.
  final CapturedMaterial material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final info = side == 'w' ? state.white : state.black;
    final name = info.name.isNotEmpty
        ? info.name
        : t(side == 'w' ? 'game.side.white' : 'game.side.black');
    final clock = tree.clockFor(node, side);
    final photo = info.photoPath;

    return PlayerBarCard(
      toMove: toMove,
      identity: PlayerIdentity(
        name: name,
        subtitle: t(side == 'w' ? 'game.side.white' : 'game.side.black'),
        avatarPath: photo,
        glyph: side == 'w' ? '♔' : '♚',
        active: toMove,
        onEdit: () => _editPlayer(context, ref, name),
      ),
      trailing: clock == null
          ? null
          : StatChip(
              label: _clockText(clock),
              icon: Icons.timer_outlined,
              color: toMove ? tokens.accent : tokens.textDim,
              filled: toMove,
            ),
      captured: CapturedPieces(
        roles: material.capturedBy(side == 'w' ? Side.white : Side.black),
        lead: material.leadFor(side == 'w' ? Side.white : Side.black),
        semanticsLabel: t(side == 'w'
            ? 'ui.aria.capturedByWhite'
            : 'ui.aria.capturedByBlack'),
      ),
    );
  }

  static String _clockText(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return d.inHours > 0
        ? '${d.inHours}:${two(minutes)}:${two(seconds)}'
        : '$minutes:${two(seconds)}';
  }

  Future<void> _editPlayer(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final notifier = ref.read(commentatorControllerProvider.notifier);
    final input = TextEditingController(text: currentName);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Hosts a TextField: the keyboard leaves little room on a
        // landscape phone, so the content scrolls rather than overflows.
        scrollable: true,
        title: Text(t(side == 'w' ? 'game.side.white' : 'game.side.black')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: input,
              autofocus: true,
              maxLength: 40,
              style: context.type.body,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Photo picking lives in the content (HIG: dialog actions are
            // dismiss/confirm only).
            OutlinedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(t('ui.button.chooseFile')),
              onPressed: () async {
                final navigator = Navigator.of(context);
                try {
                  // Capped at 1024px: player photos draw small, and a
                  // full-resolution copy would bloat app storage.
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 90,
                  );
                  if (picked != null) {
                    await notifier.setPlayerPhoto(side, picked.path);
                  }
                } on Exception {
                  // Picker unavailable — keep the dialog open.
                }
                if (navigator.mounted) navigator.pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('ui.button.dismiss')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(input.text),
            child: Text(t('ui.button.save')),
          ),
        ],
      ),
    );
    if (saved != null && saved.trim().isNotEmpty) {
      notifier.setPlayerName(side, saved);
    }
    input.dispose();
  }
}
