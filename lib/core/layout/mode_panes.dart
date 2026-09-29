import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../ui/mode_header_bar.dart';
import '../ui/player_card.dart';
import 'window_class.dart';

/// The four compositions [ModePanes] can produce. Decided by
/// [ModePanes.layoutFor] and nowhere else: a screen that gates content on
/// the layout switches on this exhaustively, so a new branch is a compile
/// error until every such screen has decided what it shows there.
enum ModeLayout {
  /// Phones, portrait: the column, with the board at full width.
  compact,

  /// Phones on their side and other short windows: board left, side pane.
  landscapeCompact,

  /// Portrait tablets: the phone column, centred, with the board as large
  /// as the height allows once the panel has its share.
  stacked,

  /// Landscape tablets and desktops: the board fills the height, and a side
  /// pane takes the width it cannot use.
  twoPane;

  /// The panel has room for a move list: every composition but the phone
  /// column, whose panel is a strip under a width-bound board.
  bool get listsMoves => this != ModeLayout.compact;

  /// The cards and the header live in a side pane beside the board.
  bool get sidePane =>
      this == ModeLayout.landscapeCompact || this == ModeLayout.twoPane;
}

/// The stacked tablet column's rows, every one decided by the window alone.
typedef _StackedGeometry = ({
  double header,
  double lead,
  double card,
  double board,
});

/// The two-pane branch's board edge and side-pane width.
typedef _TwoPaneGeometry = ({double board, double pane});

/// The shared scaffold for every board screen, built around one contract:
/// **the board's position and size derive only from the window constraints —
/// never from what content happens to be visible around it.**
///
/// Compact (phones, portrait): a column of fixed-height slots — optional
/// route [topBar], above-board row, the board, below-board row — with the
/// remaining space given to the panel pane.
///
/// Landscape-compact (phones sideways / short windows): the board pane gets
/// every vertical pixel; the player bars render at FULL size at the top and
/// bottom of the side panel. Surplus width goes to breathing room around
/// the board, not to an oversized panel.
///
/// Tablets take whichever of the next two gives the larger board — the
/// window's SHAPE decides, not its width class, which is the same for an
/// iPad in both orientations ([layoutFor]):
///
/// Stacked (portrait tablets): the phone column, centred at the board's
/// width plus the phone's 8dp insets. Its rows are ONE canonical
/// reservation — header, lead row, above card, below card, and a panel
/// floor that grows with the height — booked for every mode whether or not
/// it fills them, so all six boards share one rect in a given window.
///
/// Two-pane (landscape tablets, desktop): the board fills the height; a side
/// pane of 320–460dp takes the width the board cannot use and carries the
/// header, the player/context cards and the panel, exactly as the
/// landscape-compact branch does. Surplus width becomes symmetric margin
/// around the group.
///
/// Whichever branch runs, the pane is assembled by [_paneStack] from the same
/// three parts: the mode's content, the pinned [actionBar], and the
/// [toast]/[overlayBar] float stack laid over that content as the topmost
/// layer, docked against the action bar's measured top edge. It covers, never
/// resizes — and it can never reach the control that dismisses it.
///
/// On a phone (portrait or landscape) and in the stacked tablet column, the
/// content handed to [_paneStack] is the WHOLE column, board included, so a
/// hint covers everything but the controls that dismiss it. The two-pane
/// branch hands in its side pane's column, which is already full height and
/// owns the action bar.
class ModePanes extends StatelessWidget {
  const ModePanes({
    super.key,
    required this.boardBuilder,
    required this.panel,
    this.actionBar,
    this.overlayBar,
    this.toast,
    this.topBar,
    this.aboveBoard,
    this.belowBoard,
    this.leadContent,
    this.leadAlignment = Alignment.bottomCenter,
    this.topBarHeight = 52,
    this.aboveHeight = 44,
    this.belowHeight = 44,
    // `DrawingModeBar.height` IS this constant by reference, so the bar
    // and its booking cannot drift (they were once unlinked 56/60 literals
    // in different files).
    this.overlayBarHeight = defaultOverlayBarHeight,
    this.compactPanelMinHeight = defaultPanelMinHeight,
  });

  /// Builds the board (plus its overlay stack) at the computed square size.
  final Widget Function(BuildContext context, double boardSize) boardBuilder;

  /// The mode's contextual content. MUST handle its own scrolling.
  final Widget panel;

  /// The mode's pinned controls (action bar, replay bar, lesson actions),
  /// held at the bottom of the panel pane and never scrolled away.
  ///
  /// This belongs to the layout rather than to [panel] because the float
  /// stack has to sit exactly on top of it, and only the layout knows where
  /// the bottom of the pane is in each branch.
  final Widget? actionBar;

  /// Floating bar (drawing tools), laid out directly above [actionBar].
  final Widget? overlayBar;

  /// Transient hint toast (a [HintToast]), laid out above [overlayBar] —
  /// near the hint button in every branch. Bounded to a share of the mode so
  /// it can never grow past the top of the screen and lose its close button.
  final Widget? toast;

  /// Route chrome (close button, progress). Rendered as a fixed slot above
  /// the board in both column branches (phone and tablet portrait), and
  /// folded into the side pane in both side-pane branches so the board keeps
  /// the full height.
  final Widget? topBar;

  /// Fixed-height rows hugging the board (player bars, progress).
  final Widget? aboveBoard;
  final Widget? belowBoard;

  /// Decoration for the compact branch's computed lead gap — the slack
  /// between the header and [aboveBoard]. It RESERVES NOTHING: the board's
  /// rect is computed exactly as if this were null, and the widget renders
  /// inside whatever lead the constraints yield, hugging the card below.
  /// When the gap is too small ([_leadContentMin]) it simply does not
  /// render — the one contract here is that decoration may never move the
  /// board. The stacked tablet column books a lead row of exactly the gate's
  /// height for every mode, so there it always renders. The side-pane
  /// branches, which have no lead gap, stack it above the [aboveBoard] slot,
  /// where height costs the panel and never the board.
  final Widget? leadContent;

  /// Where [leadContent] sits inside the gap: hugging the card below
  /// (default — Learn's journey line) or pinned under the header
  /// (`Alignment.topCenter` — the trainer's category title). Placement
  /// only; the gap's size never changes for it.
  final AlignmentGeometry leadAlignment;

  /// Nominal slot heights. The rendered heights grow with the reader's text
  /// scale — see [slotHeightFor].
  final double topBarHeight;
  final double aboveHeight;
  final double belowHeight;

  /// Clearance booked under the board for [overlayBar] in the phone column —
  /// the branch where board and pane compete hardest for pixels, and the
  /// tools you are
  /// drawing WITH may not cover what you are drawing on (a hint may; see the
  /// float rules). It is folded into the reservation as
  /// `max(compactPanelMinHeight, overlayBarHeight + action bar)` — the bar
  /// floats OVER the panel, so the two claims share pixels and must never be
  /// stacked, which once shrank every drawing screen's board by the bar's
  /// full height.
  ///
  /// It has nothing to do with the board moving: the float is a layer, so
  /// opening the tools costs no layout anywhere.
  final double overlayBarHeight;

  /// Phone column: space always kept for the panel pane under the board.
  /// The stacked tablet column ignores it and books at least
  /// [defaultPanelMinHeight] for every mode — a per-mode floor there would
  /// give each mode its own board.
  final double compactPanelMinHeight;

  /// The panel's reservation under the board when a screen names none, and
  /// the stacked column's floor.
  static const double defaultPanelMinHeight = 132;

  /// Share of the compact branch's leftover height spent as a gap above the
  /// board, lifting the group off the top bar.
  ///
  /// The column used to end in a single greedy `Expanded(panel)`, so every
  /// spare pixel fell *below* the board and the whole group hugged the top
  /// bar — most visibly in the Studio, whose panel is `SizedBox.shrink()`, so
  /// the slack was simply empty screen.
  ///
  /// The gap is COMPUTED, not a flex: a flex pair hands the pane only its
  /// fraction of the leftover, so the board reservation had to be inflated by
  /// the inverse fraction to keep the pane's guarantee — which shrank the
  /// board on height-bound windows for the benefit of an empty gap. Computing
  /// the gap as "a fifth of the leftover, but never eating into the pane's
  /// minimum" lets the gap be the FIRST thing to collapse when space is
  /// tight, and the board pays nothing for it.
  static const _compactLeadShare = 0.2;

  static const _landscapeHPad = 8.0;
  static const _landscapeVPad = 4.0;
  static const _landscapeGap = 12.0;

  /// The default booking for an open drawing toolbar: one 44dp row plus
  /// its padding and outer margin. `DrawingModeBar.height` references this
  /// constant, which is what keeps the bar and the space reserved for it
  /// from drifting apart.
  static const double defaultOverlayBarHeight = 60;

  /// Breathing room between the player cards and the board ("near, not
  /// attached").
  static const _boardGap = 6.0;

  /// Smallest lead gap [leadContent] renders into: a title line plus its
  /// padding. Below this the decoration yields entirely — it may never be
  /// the reason anything else moves, and it may never clip. Through
  /// [slotHeightFor]'s 48dp floor the effective gate is 48dp at every
  /// allowed text scale; the stacked column books exactly that row.
  static const _leadContentMin = 34.0;

  /// The gate scaled the way the content it guards scales: the lead widgets
  /// hold text, so an unscaled 34 admitted rows that no longer fit at 1.3×.
  double _leadContentMinFor(BuildContext context) =>
      slotHeightFor(context, _leadContentMin);

  /// How far the float stack sits from the panel's edges. Matches the action
  /// bar's horizontal margin so the drawing tools and the buttons below
  /// them share one vertical edge.
  static const _floatHPad = 12.0;

  /// Ceiling on a float, as a share of the whole mode.
  ///
  /// A share of the MODE rather than of the pane, so a tall tablet panel does
  /// not turn a two-line hint into a 700dp slab. The panel box is the other
  /// bound, and on a phone it is the binding one.
  static const _floatModeFraction = 0.55;

  /// Widest the two-pane side pane gets; past it, extra width belongs to
  /// margin, not to a panel whose content was set for a phone measure.
  static const _twoPanePanelMax = 460.0;

  /// Narrowest the two-pane side pane gets: the cards, the controls and the
  /// prose keep a phone's measure. The board takes everything else, up to
  /// the window's height.
  static const _twoPanePanelMin = 320.0;

  /// The two-pane group's outer padding, on every side.
  static const _twoPanePad = 8.0;

  /// The stacked column's inset: the header, the panel and the controls span
  /// the board plus this on each side — the phone's screen edge — while the
  /// lead row, the cards and the board span the board itself, 8dp inside,
  /// exactly as on a phone.
  static const _columnInset = 8.0;

  /// Between the board group's last row and the panel.
  static const _panelGap = 4.0;

  /// Share of the window height the stacked column keeps for its panel, the
  /// pinned controls included. A phone's width-bound board leaves it ~20–28%
  /// by accident; a portrait tablet's board is height-bound and would take
  /// everything, leaving the prose a line and the move list a row.
  static const _stackedPanelShare = 0.22;

  /// Which composition these constraints get — the ONE decision, shared by
  /// [build] and by every screen that gates content on it. Phones take
  /// exactly the branches they always have. A tablet window takes whichever
  /// of [ModeLayout.stacked] and [ModeLayout.twoPane] gives the larger
  /// board, judged at the nominal type size so Dynamic Type can never flip
  /// it: a portrait tablet stacks, a landscape one splits, and a near-square
  /// window gets whichever serves the board.
  static ModeLayout layoutFor(BoxConstraints constraints) {
    final spec = LayoutSpec.of(constraints);
    if (spec.landscapeCompact) return ModeLayout.landscapeCompact;
    if (spec.windowClass.isCompact) return ModeLayout.compact;
    final stacked = _stackedGeometry(constraints, TextScaler.noScaling).board;
    return stacked > _twoPaneGeometry(constraints).board
        ? ModeLayout.stacked
        : ModeLayout.twoPane;
  }

  /// A board mode's loading, error or empty shell, with its header exactly
  /// where the loaded mode will put it — so the close button does not jump
  /// across the screen when the content arrives. [body] (a spinner, a
  /// message) takes the board's place. On a phone this is the full-width
  /// header row over the body the shells have always drawn.
  static Widget pending({required Widget topBar, required Widget body}) =>
      _PendingPanes(topBar: topBar, body: body);

  /// The stacked column's rows. The canonical slot heights come from the
  /// widgets that fill them, by reference — a screen's own slot parameters
  /// would let a mode without cards (Review) fall back to other heights and
  /// move its board.
  static _StackedGeometry _stackedGeometry(
    BoxConstraints constraints,
    TextScaler scaler,
  ) {
    final header = slotHeightAt(scaler, ModeHeaderBar.height);
    final lead = slotHeightAt(scaler, _leadContentMin);
    final card = slotHeightAt(scaler, PlayerBarCard.height);
    final fixed = header + lead + 2 * (card + _boardGap) + _panelGap;
    // Every mode books the same floor, so the board is the window's alone.
    // The drawing clearance is the phone's rule with the below row always
    // discounted, since it is always booked here; the height share dwarfs it,
    // but the two claims are still max()ed, never summed.
    final floor = math.max(
      math.max(
        defaultPanelMinHeight,
        constraints.maxHeight * _stackedPanelShare,
      ),
      defaultOverlayBarHeight + _actionBarAllowance - (card + _boardGap),
    );
    final board = boardSizeFor(
      constraints,
      reservedHeight: fixed + floor,
      horizontalPadding: 2 * _columnInset,
    );
    // A width-bound board leaves slack. As on a phone, a fifth of it lifts
    // the group off the header and the rest falls to the panel.
    final slack = math.max(0.0, constraints.maxHeight - fixed - floor - board);
    return (
      header: header,
      lead: lead + slack * _compactLeadShare,
      card: card,
      board: board,
    );
  }

  /// The board fills the height unless the pane's floor needs the width;
  /// the pane then takes what the board leaves, up to its ceiling.
  static _TwoPaneGeometry _twoPaneGeometry(BoxConstraints constraints) {
    final room = constraints.maxWidth - 2 * _twoPanePad - _landscapeGap;
    final board = math.max(
      0.0,
      math.min(
        math.min(
          constraints.maxHeight - 2 * _twoPanePad,
          room - _twoPanePanelMin,
        ),
        boardMaxSize,
      ),
    );
    final pane = (room - board).clamp(_twoPanePanelMin, _twoPanePanelMax);
    return (board: board, pane: pane);
  }

  /// Side-panel width in the landscape-compact branch: whatever the board
  /// (height-bound) leaves over, clamped to a usable band, and never so
  /// wide that the board starves.
  static double landscapePanelWidth(BoxConstraints constraints) {
    final availH = constraints.maxHeight - 2 * _landscapeVPad;
    final availW = constraints.maxWidth - 2 * _landscapeHPad - _landscapeGap;
    final panelW = math.min(math.max(availW - availH, 260.0), 420.0);
    return math.min(panelW, math.max(availW - 160.0, 160.0));
  }

  double _topBarH(BuildContext context) =>
      topBar == null ? 0 : slotHeightFor(context, topBarHeight);
  double _aboveH(BuildContext context) =>
      aboveBoard == null ? 0 : slotHeightFor(context, aboveHeight);
  double _belowH(BuildContext context) =>
      belowBoard == null ? 0 : slotHeightFor(context, belowHeight);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => switch (layoutFor(constraints)) {
        ModeLayout.landscapeCompact => _landscapeCompact(context, constraints),
        ModeLayout.compact => _compact(context, constraints),
        ModeLayout.stacked => _stacked(context, constraints),
        ModeLayout.twoPane => _twoPane(context, constraints),
      },
    );
  }

  /// The panel side of every branch: scrolling content with the float stack
  /// laid OVER it, and the pinned controls below both. Assembled here exactly
  /// once so the three layouts can never disagree about what sits above what.
  ///
  /// The float is a **layer, not a row**, and the TOP one. Two earlier shapes
  /// each fixed one half of the problem and broke the other:
  ///
  /// - a Column sibling consumed the panel's height, so opening a hint
  ///   reflowed the panel and, where the pinned zone is two rows deep, pushed
  ///   the action bar off a short phone;
  /// - docked inside the panel's box it stopped moving anything, but it was
  ///   painted before the action bar (whose floating shadow then bled across
  ///   it) and boxed into whatever the controls left over — 90dp in the
  ///   Studio.
  ///
  /// [_PaneLayout] settles both: it MEASURES the bar, docks the float against
  /// its top edge, and paints the float LAST — so nothing beneath it, the
  /// action bar's own shadow included, is ever drawn across it. The float still
  /// cannot reach the control that dismisses it, not because of a constant but
  /// because the bar's rect is an output of the layout rather than a guess.
  ///
  /// **What [content] is decides how far the float can reach**, and that is the
  /// whole third fix. A child laid outside its parent's box paints but is never
  /// hit-tested, so the float has to stay inside this layout — which means the
  /// layout has to span everything the float is allowed to cover. Handing it
  /// only the scrolling panel is why the Studio's hint was unusable: that
  /// mode's panel is `SizedBox.shrink()`, so the float's entire world was
  /// whatever a two-row pinned zone left over, and it could not rise over the
  /// board no matter what it was told to paint over. The compact and landscape
  /// branches therefore hand in the whole column — board, player bars and all —
  /// so the hint covers them and its close button still works.
  Widget _paneStack(Widget content, double modeHeight) {
    final float = _floatStack();
    return CustomMultiChildLayout(
      delegate: _PaneLayout(maxFloatHeight: modeHeight * _floatModeFraction),
      children: [
        LayoutId(id: _PaneLayout.panel, child: content),
        if (actionBar case final bar?)
          LayoutId(id: _PaneLayout.bar, child: bar),
        // LAST, so it paints last: over the panel, over the board it may rise
        // across, and over the action bar's own shadow.
        if (float != null)
          LayoutId(
            id: _PaneLayout.float,
            child: Padding(
              // The float owns its inset from the pane edge, matching the
              // action bar's margin so the two share one vertical edge.
              padding: const EdgeInsets.symmetric(horizontal: _floatHPad),
              child: float,
            ),
          ),
      ],
    );
  }

  /// The hint toast above the drawing tools, both of them optional. Returns
  /// null when neither is showing, so an idle screen pays no layout at all.
  ///
  /// Height needs no cap of its own: the panel box bounds it, and covering the
  /// panel is exactly what an overlay is for.
  Widget? _floatStack() {
    if (toast == null && overlayBar == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      // The float sits under loose constraints now, so the width is claimed
      // here rather than left to whatever the children happen to force.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The toast is the part that yields: it scrolls inside whatever is
        // left once the drawing tools have taken their fixed height.
        Flexible(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: toast ?? const SizedBox.shrink(),
          ),
        ),
        ?overlayBar,
      ],
    );
  }

  /// Phone landscape: the board pane is height-bound and centred; the
  /// panel column carries the route chrome and FULL-SIZE player bars.
  Widget _landscapeCompact(BuildContext context, BoxConstraints constraints) {
    final availH = constraints.maxHeight - 2 * _landscapeVPad;
    final availW = constraints.maxWidth - 2 * _landscapeHPad - _landscapeGap;
    final panelW = landscapePanelWidth(constraints);
    final boardSize = math.max(120.0, math.min(availH, availW - panelW));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _landscapeHPad,
        vertical: _landscapeVPad,
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: boardBuilder(context, boardSize))),
          const SizedBox(width: _landscapeGap),
          SizedBox(
            width: panelW,
            // The whole side column goes in as the float's world, so a hint
            // can cover the player bars here too rather than being trapped
            // between them.
            child: _paneStack(
              Column(
                children: [
                  if (topBar != null)
                    SizedBox(height: _topBarH(context), child: topBar),
                  if (leadContent case final content?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: content,
                    ),
                  if (aboveBoard != null)
                    SizedBox(height: _aboveH(context), child: aboveBoard),
                  Expanded(child: panel),
                  if (belowBoard != null)
                    SizedBox(height: _belowH(context), child: belowBoard),
                ],
              ),
              constraints.maxHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(double height, Widget? child, double width) => SizedBox(
    height: height,
    width: width,
    child: child == null
        ? null
        : Align(alignment: Alignment.center, child: child),
  );

  /// Room the pinned action bar takes at the bottom of the pane; the float
  /// docks on top of it, so the drawing-bar clearance has to include it.
  static const _actionBarAllowance = 64.0;

  Widget _compact(BuildContext context, BoxConstraints constraints) {
    // The panel minimum and the drawing-bar clearance are NOT additive: the
    // bar floats OVER the panel, so both claims are on the same pixels and
    // the reservation is whichever is larger. Stacking them (as this used to)
    // shrank every drawing screen's board by the full height of the bar.
    //
    // Screens with a below-board card get that card's slot discounted from
    // the clearance: drawing is modal — the clock is paused and the board is
    // annotation-only — so the open tools may ride over the bottom player
    // card, which shows nothing actionable, before they may ever touch the
    // board. Without the discount the board paid the card's height to keep
    // the tools off a card nobody needs mid-drawing.
    final coverable = belowBoard == null ? 0.0 : _belowH(context) + _boardGap;
    final paneNeed = math.max(
      compactPanelMinHeight,
      overlayBar == null
          ? 0
          : overlayBarHeight + _actionBarAllowance - coverable,
    );
    final fixedRows =
        _topBarH(context) +
        _aboveH(context) +
        _belowH(context) +
        2 * _boardGap +
        4;
    // The board and the cards share one width: screen minus 8dp each side.
    // 16 here and in `_slot` below are the same number on purpose — a board
    // narrower than the cards above it reads as a mistake.
    final boardSize = boardSizeFor(
      constraints,
      reservedHeight: fixedRows + paneNeed + 4,
      horizontalPadding: 16,
    );
    // The lift off the top bar: a fifth of whatever is genuinely spare, and
    // the FIRST thing to collapse when nothing is — it may never eat into
    // the pane's minimum, so it costs the board and the panel nothing. Still
    // a pure function of the constraints: entering drawing mode moves no
    // pixel of this.
    final leftover = math.max(
      0.0,
      constraints.maxHeight - fixedRows - boardSize,
    );
    final lead = math.min(
      leftover * _compactLeadShare,
      math.max(0.0, leftover - paneNeed),
    );

    return _paneStack(
      Column(
        children: [
          if (topBar != null)
            _slot(_topBarH(context), topBar, constraints.maxWidth),
          // The lead gap, optionally decorated: content sits at its bottom,
          // hugging the card below, and vanishes when the gap is tight. The
          // gap's SIZE never changes for it — decoration may not move the
          // board.
          SizedBox(
            height: lead,
            width: constraints.maxWidth - 16,
            child: leadContent != null && lead >= _leadContentMinFor(context)
                ? Align(
                    alignment: leadAlignment,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: leadContent,
                    ),
                  )
                : null,
          ),
          // The cards span the screen minus 8dp each side rather than the
          // board's width — the same edge the board itself now sits on.
          if (aboveBoard != null) ...[
            _slot(_aboveH(context), aboveBoard, constraints.maxWidth - 16),
            const SizedBox(height: _boardGap),
          ],
          Center(child: boardBuilder(context, boardSize)),
          if (belowBoard != null) ...[
            const SizedBox(height: _boardGap),
            _slot(_belowH(context), belowBoard, constraints.maxWidth - 16),
          ],
          const SizedBox(height: 4),
          Expanded(child: panel),
        ],
      ),
      constraints.maxHeight,
    );
  }

  /// Portrait tablets: the phone column, centred, and the same for every
  /// mode.
  ///
  /// Every row is booked whether or not the mode fills it — the header, a
  /// lead row exactly the height [leadContent] needs, both card rows and the
  /// panel's floor — so the board's rect is the window's and never the
  /// mode's: Review opens from Play's result sheet with the board exactly
  /// where it was. A mode without a below card gives that row to its panel.
  ///
  /// Widths copy the phone's insets: the header, the panel, the controls and
  /// the float span the board plus 8dp a side (the phone's screen edge); the
  /// lead row, the cards and the board span the board. The cards stay in the
  /// column, unlike the side-pane branches, because [layoutFor] only picks
  /// this branch when, cards paid for, it still gives the larger board.
  Widget _stacked(BuildContext context, BoxConstraints constraints) {
    assert(
      (topBar == null || topBarHeight == ModeHeaderBar.height) &&
          (aboveBoard == null || aboveHeight == PlayerBarCard.height) &&
          (belowBoard == null || belowHeight == PlayerBarCard.height),
      'The stacked column books canonical rows (ModeHeaderBar.height, '
      'PlayerBarCard.height); a slot of another height would be clipped.',
    );
    final g = _stackedGeometry(constraints, MediaQuery.textScalerOf(context));
    final box = g.board + 2 * _columnInset;
    return Center(
      child: SizedBox(
        width: box,
        height: constraints.maxHeight,
        // The whole column goes in as the float's world, as on a phone: a
        // hint may rise over the board and still keep a live close button.
        child: _paneStack(
          Column(
            children: [
              _slot(g.header, topBar, box),
              SizedBox(
                height: g.lead,
                width: g.board,
                child: leadContent == null
                    ? null
                    : Align(
                        alignment: leadAlignment,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: leadContent,
                        ),
                      ),
              ),
              _slot(g.card, aboveBoard, g.board),
              const SizedBox(height: _boardGap),
              Center(child: boardBuilder(context, g.board)),
              if (belowBoard != null) ...[
                const SizedBox(height: _boardGap),
                _slot(g.card, belowBoard, g.board),
              ],
              const SizedBox(height: _panelGap),
              Expanded(child: panel),
            ],
          ),
          constraints.maxHeight,
        ),
      ),
    );
  }

  /// Landscape tablets and desktops: the board fills the height; the header,
  /// the player/context cards and the panel all live in a side pane that
  /// takes the width the board cannot use — the same shape [_landscapeCompact]
  /// uses. The cards used to stack in the BOARD's column here, so every dp
  /// they grew came straight out of the board on any height-bound window; in
  /// the side pane they cost the board nothing.
  ///
  /// The group is centred at its computed width, so surplus width becomes
  /// symmetric margin rather than a gutter between a drifting board and a
  /// pane glued to the trailing edge. Still a pure function of the window.
  Widget _twoPane(BuildContext context, BoxConstraints constraints) {
    final g = _twoPaneGeometry(constraints);
    return Center(
      child: SizedBox(
        width: g.board + _landscapeGap + g.pane + 2 * _twoPanePad,
        height: constraints.maxHeight,
        child: _twoPaneRow(context, constraints, g.pane, g.board),
      ),
    );
  }

  Widget _twoPaneRow(
    BuildContext context,
    BoxConstraints constraints,
    double panelWidth,
    double boardSize,
  ) {
    return Padding(
      padding: const EdgeInsets.all(_twoPanePad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: boardBuilder(context, boardSize))),
          const SizedBox(width: _landscapeGap),
          SizedBox(
            width: panelWidth,
            child: _paneStack(
              Column(
                children: [
                  if (topBar != null)
                    SizedBox(height: _topBarH(context), child: topBar),
                  if (leadContent case final content?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: content,
                    ),
                  if (aboveBoard != null)
                    SizedBox(height: _aboveH(context), child: aboveBoard),
                  Expanded(child: panel),
                  if (belowBoard != null)
                    SizedBox(height: _belowH(context), child: belowBoard),
                ],
              ),
              constraints.maxHeight,
            ),
          ),
        ],
      ),
    );
  }
}

/// [ModePanes.pending]: the header in its loaded position, the body where the
/// board will be.
class _PendingPanes extends StatelessWidget {
  const _PendingPanes({required this.topBar, required this.body});

  final Widget topBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = slotHeightFor(context, ModeHeaderBar.height);
        Widget column(double? width) => SizedBox(
          width: width,
          child: Column(
            children: [
              SizedBox(height: header, child: topBar),
              Expanded(child: body),
            ],
          ),
        );
        switch (ModePanes.layoutFor(constraints)) {
          case ModeLayout.compact || ModeLayout.landscapeCompact:
            return column(null);
          case ModeLayout.stacked:
            final g = ModePanes._stackedGeometry(
              constraints,
              MediaQuery.textScalerOf(context),
            );
            return Center(child: column(g.board + 2 * ModePanes._columnInset));
          case ModeLayout.twoPane:
            final g = ModePanes._twoPaneGeometry(constraints);
            return Center(
              child: SizedBox(
                width:
                    g.board +
                    ModePanes._landscapeGap +
                    g.pane +
                    2 * ModePanes._twoPanePad,
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.all(ModePanes._twoPanePad),
                  child: Row(
                    children: [
                      Expanded(child: body),
                      const SizedBox(width: ModePanes._landscapeGap),
                      SizedBox(
                        width: g.pane,
                        child: Column(
                          children: [
                            SizedBox(height: header, child: topBar),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

/// Lays the panel pane out as: content, pinned controls, and the float as the
/// TOP layer docked directly above those controls.
///
/// A `Stack` cannot do this. The float has to sit against the action bar's top
/// edge, and the bar's height is whatever the mode's controls happen to be —
/// one row in Review, two in the Studio, none at all in a lesson. Positioning
/// one child against a **measured** sibling is exactly what a
/// [MultiChildLayoutDelegate] is for, and measuring is what keeps the old
/// `bottom: 72` class of bug from ever coming back.
class _PaneLayout extends MultiChildLayoutDelegate {
  _PaneLayout({required this.maxFloatHeight});

  static const panel = 'panel';
  static const bar = 'bar';
  static const float = 'float';

  /// Ceiling on the float, so a tall tablet pane does not produce a 700dp
  /// toast. The panel box bounds it too — see [performLayout].
  final double maxFloatHeight;

  @override
  void performLayout(Size size) {
    var barHeight = 0.0;
    if (hasChild(bar)) {
      // Measured under UNBOUNDED height, deliberately: this is the seam's
      // guard. Bounding the bar by the pane's height handed every pixel of
      // it to any height-greedy control — a default-`max` Column in one
      // mode's actions was enough — which measured the bar as the whole
      // pane and laid the entire mode out at zero height: buttons visible,
      // board and prose gone. Unbounded, a flex column can only shrink-wrap
      // its children, so the bar is always its content's height. (An
      // IntrinsicHeight wrapper would guard too, but Play's ActionBar holds
      // a LayoutBuilder, which intrinsics reject at runtime.)
      barHeight = math.min(
        layoutChild(
          bar,
          BoxConstraints(minWidth: size.width, maxWidth: size.width),
        ).height,
        size.height,
      );
      positionChild(bar, Offset(0, size.height - barHeight));
    }

    final panelHeight = math.max(0.0, size.height - barHeight);
    if (hasChild(panel)) {
      layoutChild(panel, BoxConstraints.tight(Size(size.width, panelHeight)));
      positionChild(panel, Offset.zero);
    }

    if (hasChild(float)) {
      // Bounded by the panel box as well as the ceiling, and deliberately so.
      // Letting it overflow upward would paint fine — this delegate does not
      // clip — but a child positioned outside its parent's box is never
      // hit-tested, and the part that would stick out is the toast's header:
      // its close button would be visible and dead. A roomier hint is not
      // worth a button that does nothing.
      final floatSize = layoutChild(
        float,
        BoxConstraints.loose(
          Size(size.width, math.min(panelHeight, maxFloatHeight)),
        ),
      );
      // Flush against the bar's measured top edge — never a constant, which is
      // what used to put a floating bar on top of the control that closed it.
      positionChild(float, Offset(0, panelHeight - floatSize.height));
    }
  }

  @override
  bool shouldRelayout(_PaneLayout old) => old.maxFloatHeight != maxFloatHeight;
}
