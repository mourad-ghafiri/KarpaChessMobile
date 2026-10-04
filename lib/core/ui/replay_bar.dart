import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/i18n_service.dart';
import '../theme/tokens_context.dart';

/// The one game-navigation cluster: big first/prev/next/last buttons, a
/// tappable "N / M" readout and an autoplay toggle. Used by Studio and
/// Review (the moves overlay covers per-move browsing).
class ReplayBar extends StatefulWidget {
  const ReplayBar({
    super.key,
    required this.t,
    required this.count,
    required this.index,
    required this.onSeek,
    this.onReadoutTap,
    this.autoplayInterval = const Duration(milliseconds: 1400),
  });

  final Translate t;

  /// Number of plies in the game.
  final int count;

  /// Current ply index (-1 = start position).
  final int index;

  /// Seek to a ply index in [-1, count - 1].
  final ValueChanged<int> onSeek;

  /// Optional: tapping the "N / M" readout (Studio opens its moves overlay).
  final VoidCallback? onReadoutTap;

  final Duration autoplayInterval;

  @override
  State<ReplayBar> createState() => _ReplayBarState();
}

class _ReplayBarState extends State<ReplayBar> {
  Timer? _autoplay;

  bool get _playing => _autoplay != null;

  int get _last => widget.count - 1;

  @override
  void didUpdateWidget(ReplayBar old) {
    super.didUpdateWidget(old);
    if (_playing && widget.index >= _last) _stop();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    super.dispose();
  }

  void _stop() {
    _autoplay?.cancel();
    if (mounted) setState(() => _autoplay = null);
  }

  void _toggleAutoplay() {
    if (_playing) {
      _stop();
      return;
    }
    setState(() {
      _autoplay = Timer.periodic(widget.autoplayInterval, (_) {
        if (widget.index >= _last) {
          _stop();
        } else {
          widget.onSeek(widget.index + 1);
        }
      });
    });
  }

  void _seek(int index) {
    _stop();
    widget.onSeek(index.clamp(-1, _last));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final count = widget.count;

    Widget navButton(IconData icon, String tooltip, VoidCallback? onTap) =>
        Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                icon,
                size: 22,
                color: onTap == null ? tokens.textFaint : tokens.text,
              ),
            ),
          ),
        );

    // A narrow panel sheds cells instead of scaling: FittedBox once shrank
    // the whole cluster (~0.6× in the Studio's landscape pane), putting the
    // mode's primary navigation buttons far under the 44dp target floor.
    // The readout yields first, the first/last jumps second; prev/next and
    // autoplay — the essentials — never shrink.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showReadout = !width.isFinite || width >= 332;
        final showEnds = !width.isFinite || width >= 234;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEnds)
              navButton(
                Icons.first_page,
                widget.t('commentator.firstMove'),
                widget.index >= 0 ? () => _seek(-1) : null,
              ),
            navButton(
              Icons.chevron_left,
              widget.t('commentator.prevMove'),
              widget.index >= 0 ? () => _seek(widget.index - 1) : null,
            ),
            if (showReadout)
              InkWell(
                onTap: widget.onReadoutTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 76),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.edge),
                  ),
                  child: Text(
                    widget.t('replay.position', {
                      'i': widget.index + 1,
                      'total': count,
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: context.type.font.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                    ),
                  ),
                ),
              ),
            navButton(
              Icons.chevron_right,
              widget.t('commentator.nextMove'),
              widget.index < _last ? () => _seek(widget.index + 1) : null,
            ),
            if (showEnds)
              navButton(
                Icons.last_page,
                widget.t('commentator.lastMove'),
                widget.index < _last ? () => _seek(_last) : null,
              ),
            const SizedBox(width: 2),
            Tooltip(
              message: widget.t('replay.autoplay'),
              // Playing is said, not only tinted.
              child: Semantics(
                button: true,
                toggled: _playing,
                child: InkWell(
                onTap: count == 0 ? null : _toggleAutoplay,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _playing ? tokens.accentSoft : null,
                  ),
                  child: Icon(
                    _playing
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 22,
                    color: _playing ? tokens.accent : tokens.textDim,
                  ),
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}
