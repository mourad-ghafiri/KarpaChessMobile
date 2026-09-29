import 'package:flutter/material.dart';

import '../../engine/domain/move_classifier.dart';
import '../i18n/i18n_service.dart';
import '../layout/window_class.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tokens_context.dart';
import 'quality_style.dart';
import 'surface.dart';

/// One ply in a [MoveListCard]. Plain data — the owning screen adapts its
/// own state (practice moves, a study line, reviewed moves) into these, so
/// the card needs no domain type beyond [MoveQuality].
class MoveListEntry {
  const MoveListEntry({
    required this.san,
    required this.moveNumber,
    required this.isWhite,
    this.quality,
    this.hasSideline = false,
  });

  final String san;

  /// Fullmove number — supplied, not derived, because Studio games may
  /// start mid-game from a FEN.
  final int moveNumber;

  /// Which cell of the pair this ply fills.
  final bool isWhite;

  /// Renders as the shared quality glyph/color when known.
  final MoveQuality? quality;

  /// Studio: another branch leaves this position — marked with the same
  /// alt-route glyph the Studio's chrome uses for off-mainline.
  final bool hasSideline;

  @override
  bool operator ==(Object other) =>
      other is MoveListEntry &&
      other.san == san &&
      other.moveNumber == moveNumber &&
      other.isWhite == isWhite &&
      other.quality == quality &&
      other.hasSideline == hasSideline;

  @override
  int get hashCode =>
      Object.hash(san, moveNumber, isWhite, quality, hasSideline);
}

/// The ONE move-list surface: SAN history as paired rows (number gutter,
/// White's cell, Black's cell), the current ply highlighted and kept in
/// view. Mounted wherever the board layout has room for it — every
/// `ModeLayout` but the phone column. Play mounts it read-only ([onSelect]
/// null); Review and the Studio's moves-so-far list pass a jump callback.
///
/// In a box wider than two pairs need — the panel under a portrait tablet's
/// board — the pairs flow row-major into as many columns as fit, like a
/// paragraph of notation, instead of one sparse pair per full-width row.
/// Side panes are always narrower than two pairs, so they keep one column.
///
/// Pure presentation, the replay bar's contract: plain entries + a
/// [Translate] + a callback; no Riverpod, no feature imports.
class MoveListCard extends StatefulWidget {
  const MoveListCard({
    super.key,
    required this.t,
    required this.entries,
    required this.currentIndex,
    this.onSelect,
  });

  final Translate t;

  /// Plies in played order.
  final List<MoveListEntry> entries;

  /// Index into [entries] of the position on the board; -1 = before the
  /// first move.
  final int currentIndex;

  /// Called with the tapped ply's index; null renders the list read-only.
  final ValueChanged<int>? onSelect;

  @override
  State<MoveListCard> createState() => _MoveListCardState();
}

/// One rendered row: the fullmove number plus the ply index filling each
/// cell (null while a cell has no move — a game from a Black-to-move FEN
/// starts with an empty White cell).
class _PairRow {
  _PairRow(this.number, {this.white, this.black});

  final int number;
  int? white;
  int? black;
}

class _MoveListCardState extends State<MoveListCard> {
  /// The narrowest a pair renders at 1.0× text: the number gutter and two
  /// cells, room for the longest pair notation writes ("100." then two
  /// promotions with check and a verdict). Two of them are wider than any
  /// side pane's list, which is what keeps side panes at one column.
  static const _pairMinWidth = 220.0;

  /// Past this, more columns stop reading as one list.
  static const _maxColumns = 4;

  final _controller = ScrollController();

  /// Columns and line height in the last layout — what [_revealCurrent]
  /// scrolls by.
  int _columns = 1;
  double _extent = 44;

  /// A finger (or wheel) owns the viewport right now: auto-scroll yields
  /// rather than yanking the list out from under the reader — autoplay in
  /// the Studio advances every second.
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    // A list that opens on a game already under way — a restored game, a
    // review picked up on a move — starts on the move on the board rather
    // than on move one, with the current line cut off under the fold.
    if (widget.currentIndex >= 0) _revealCurrent(animate: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_PairRow> _rowsOf(List<MoveListEntry> entries) {
    final rows = <_PairRow>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.isWhite) {
        rows.add(_PairRow(entry.moveNumber, white: i));
      } else if (rows.isNotEmpty &&
          rows.last.black == null &&
          rows.last.number == entry.moveNumber) {
        rows.last.black = i;
      } else {
        rows.add(_PairRow(entry.moveNumber, black: i));
      }
    }
    return rows;
  }

  static int _rowOfPly(List<MoveListEntry> entries, int ply) {
    var row = -1;
    for (var i = 0; i <= ply && i < entries.length; i++) {
      final entry = entries[i];
      if (entry.isWhite || row < 0 || !entries[i - 1].isWhite) row++;
    }
    return row;
  }

  @override
  void didUpdateWidget(MoveListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        widget.currentIndex >= 0) {
      _revealCurrent();
    }
  }

  void _revealCurrent({bool animate = true}) {
    if (_userScrolling) return;
    final row = _rowOfPly(widget.entries, widget.currentIndex);
    if (row < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || _userScrolling) return;
      // The line the pair sits on, read after this frame's layout has
      // settled how many columns there are and how tall a line is.
      final line = row ~/ _columns;
      final position = _controller.position;
      final target =
          (line * _extent - (position.viewportDimension - _extent) / 2).clamp(
            0.0,
            position.maxScrollExtent,
          );
      if (animate) {
        _controller.animateTo(
          target,
          duration: Motion.base,
          curve: Motion.enter,
        );
      } else {
        _controller.jumpTo(target);
      }
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _userScrolling = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _userScrolling = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rows = _rowsOf(widget.entries);
    final extent = _extent = slotHeightFor(context, 44, minimum: 44);

    if (rows.isEmpty) {
      return Surface(
        child: Center(
          child: Text(
            widget.t('commentator.moves'),
            style: TextStyle(fontSize: 12.5, color: tokens.textFaint),
          ),
        ),
      );
    }

    return Surface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      // SAN never mirrors: "1. e4" must not bidi-reorder under an RTL app
      // locale — the same rule the board itself applies.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pairWidth = MediaQuery.textScalerOf(
                context,
              ).scale(_pairMinWidth);
              final columns = (constraints.maxWidth / pairWidth).floor().clamp(
                1,
                _maxColumns,
              );
              _columns = columns;
              return ListView.builder(
                controller: _controller,
                itemExtent: extent,
                itemCount: (rows.length / columns).ceil(),
                itemBuilder: (context, line) {
                  if (columns == 1) return _pair(tokens, rows[line]);
                  // Row-major, like reading notation: the next pair sits to
                  // the right, and the line wraps. The last line is padded
                  // with empty cells so every pair keeps one width.
                  return Row(
                    children: [
                      for (var c = 0; c < columns; c++)
                        Expanded(
                          child: line * columns + c < rows.length
                              ? _pair(tokens, rows[line * columns + c])
                              : const SizedBox.shrink(),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// One move pair: the fullmove number in its gutter, then White's and
  /// Black's cells.
  Widget _pair(AppTokens tokens, _PairRow row) => Row(
    children: [
      SizedBox(
        width: 34,
        child: Text(
          '${row.number}.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: context.type.font.mono,
            fontSize: 12,
            color: tokens.textFaint,
          ),
        ),
      ),
      Expanded(child: _cell(tokens, row.white)),
      Expanded(child: _cell(tokens, row.black)),
    ],
  );

  /// One ply cell. An [InkWell] only when the list can jump; the current
  /// ply takes the selected-chip treatment the Studio's move chips use.
  Widget _cell(AppTokens tokens, int? ply) {
    if (ply == null) return const SizedBox.shrink();
    final entry = widget.entries[ply];
    final selected = ply == widget.currentIndex;
    final onSelect = widget.onSelect;

    final label = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: selected ? tokens.accentSoft : null,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: entry.san),
            if (entry.quality case final quality?)
              TextSpan(
                text: quality.glyph,
                style: TextStyle(color: quality.colorOf(tokens)),
              ),
            if (entry.hasSideline)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.alt_route, size: 12, color: tokens.info),
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: context.type.font.mono,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? tokens.accent : tokens.text,
        ),
      ),
    );

    if (onSelect == null) return label;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: () => onSelect(ply),
      child: label,
    );
  }
}
