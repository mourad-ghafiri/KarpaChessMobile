import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/chess/castling_moves.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../prefs/application/prefs_controller.dart';
import 'board_theme_mapper.dart';
import 'piece_sets.dart';

/// The app's shared chessboard: a chessground [Chessboard] wired to the
/// user's preferences (colorway, piece set, coordinates, highlights,
/// animations).
///
/// Chess-agnostic by design: the owning feature supplies the [position],
/// decides [playerSide] (its move-gate strategy) and receives [onMove];
/// this widget never mutates game state.
class KarpaBoard extends ConsumerStatefulWidget {
  const KarpaBoard({
    super.key,
    required this.size,
    required this.position,
    this.orientation = Side.white,
    this.lastMove,
    this.playerSide = PlayerSide.both,
    this.onMove,
    this.shapes = const {},
    this.annotations = const {},
    this.animate = true,
    this.wash,
  });

  final double size;
  final Position position;
  final Side orientation;

  /// Origin/destination of the move that produced [position], if any.
  final NormalMove? lastMove;

  /// Which side(s) the user may move; [PlayerSide.none] makes it read-only.
  final PlayerSide playerSide;

  /// Called with a legal move chosen by the user (promotion already picked).
  ///
  /// Castling is reported as the king's own move (e1→g1), never chessground's
  /// alternative king-onto-rook destination — see [kingCastlingForm].
  final void Function(NormalMove move)? onMove;

  /// External shapes (hint arrows, engine arrows, annotations).
  final Set<Shape> shapes;

  /// Per-square badges (move classifications).
  final Map<Square, Annotation> annotations;

  /// Whether position changes animate (further gated by the animations pref).
  final bool animate;

  /// Optional tint blended onto the squares, UNDER the pieces — the pieces
  /// keep full strength while the wood takes the color. The Studio passes
  /// its side-line hue here so the mode reads on the board surface itself,
  /// matching the bezel `BoardStage` turns. Fades in and out with the same
  /// motion the bezel uses.
  final Color? wash;

  @override
  ConsumerState<KarpaBoard> createState() => _KarpaBoardState();
}

class _KarpaBoardState extends ConsumerState<KarpaBoard> {
  late ChessboardController _controller;

  /// The last non-null [KarpaBoard.wash], kept so the fade-OUT still knows
  /// which color it is fading from after the widget's wash goes null.
  Color? _lastWash;

  @override
  void initState() {
    super.initState();
    _controller = ChessboardController(game: _gameData());
  }

  @override
  void didUpdateWidget(KarpaBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.fen != widget.position.fen ||
        oldWidget.playerSide != widget.playerSide ||
        oldWidget.lastMove != widget.lastMove) {
      final animations = ref.read(prefsControllerProvider).animations;
      _controller.updatePosition(
        _gameData(),
        animate: widget.animate && animations,
        resetPremove: true,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GameData _gameData() {
    final position = widget.position;
    return GameData(
      fen: position.fen,
      lastMove: widget.lastMove,
      playerSide: widget.playerSide,
      sideToMove: position.turn,
      validMoves: makeLegalMoves(position),
      // Deliberately not `kingSquareInCheck`: chessground hardcodes a red
      // radial there and it is unreachable through ChessboardColorScheme,
      // so it clashes with every non-red palette. We paint our own below.
    );
  }

  Square? get _checkSquare {
    final position = widget.position;
    return position.isCheck ? position.board.kingOf(position.turn) : null;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsControllerProvider);
    final tokens = context.tokens;
    if (widget.wash != null) _lastWash = widget.wash;
    final colorway = BoardColorTheme.fromId(prefs.boardTheme);

    final checkSquare = _checkSquare;
    final i18n = ref.watch(i18nProvider).valueOrNull;

    // The board was the one unlabeled region on every board screen — the
    // `ui.aria.chessBoard` string existed and was never used. A screen reader
    // now finds it by name.
    return Semantics(
      container: true,
      label: i18n?.t('ui.aria.chessBoard'),
      child: Directionality(
      // The board never mirrors under RTL locales.
      textDirection: TextDirection.ltr,
      // The wash arrives and leaves on the same curve the BoardStage bezel
      // blends on, so the frame and the wood change as one material.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.wash != null ? 1.0 : 0.0),
        duration: Motion.base,
        curve: Motion.enter,
        builder: (context, amount, _) {
          final wash = _lastWash;
          final scheme = boardColorScheme(
            colorway,
            tokens,
            wash: wash == null || amount == 0
                ? null
                : wash.withValues(alpha: wash.a * amount),
          );
          return Stack(
            children: [
              Chessboard(
                size: widget.size,
                controller: _controller,
                orientation: widget.orientation,
                onMove: (move, {viaDragAndDrop}) {
                  if (move is NormalMove) {
                    widget.onMove?.call(
                      kingCastlingForm(widget.position, move),
                    );
                  }
                },
                shapes: widget.shapes,
                annotations: widget.annotations,
                settings: ChessboardSettings(
                  colorScheme: scheme,
                  pieceAssets: PieceSetId.fromId(prefs.pieceSet).assets,
                  enableCoordinates: prefs.coords,
                  showLastMove: prefs.lastMoveHighlight,
                  showValidMoves: prefs.legalHighlight,
                  animationDuration: prefs.animations
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  enablePremoves: false,
                  autoQueenPromotion: false,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  // Chessground's own two-finger arrow drawing stays OFF: the
                  // app draws exclusively through its own drawing mode, and
                  // boards outside Learn must never show move arrows.
                  drawShape: const DrawShapeOptions(enable: false),
                ),
              ),
              if (checkSquare != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CheckGlow(
                        square: checkSquare,
                        orientation: widget.orientation,
                        color: tokens.hiCheck,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      ),
    );
  }
}

/// The king-in-check highlight, in the theme's danger color.
///
/// Chessground draws this itself, but hardcodes a red radial gradient that
/// [ChessboardColorScheme] does not expose — red on a plum or jade palette
/// looks like a rendering bug. Ours is the same idea in the right hue.
class _CheckGlow extends CustomPainter {
  const _CheckGlow({
    required this.square,
    required this.orientation,
    required this.color,
  });

  final Square square;
  final Side orientation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 8;
    final white = orientation == Side.white;
    final center = Offset(
      ((white ? square.file.value : 7 - square.file.value) + 0.5) * unit,
      ((white ? 7 - square.rank.value : square.rank.value) + 0.5) * unit,
    );
    final radius = unit * 0.62;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.55),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_CheckGlow old) =>
      old.square != square ||
      old.orientation != orientation ||
      old.color != color;
}
