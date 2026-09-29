import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Material window size classes plus a desktop-wide tier. Every screen
/// derives its layout from this — never from raw pixel checks.
enum WindowClass {
  /// Phones, portrait (< 600dp).
  compact,

  /// Large phones landscape / small tablets (600–839dp).
  medium,

  /// Tablets / small desktop windows (840–1199dp).
  expanded,

  /// Full desktop (≥ 1200dp).
  wide;

  /// The width at which each class begins. Named because these numbers are
  /// read by `fromWidth` and by screens deciding column counts, and a
  /// second hardcoded copy is how layouts drift apart.
  static const mediumAt = 600.0;
  static const expandedAt = 840.0;
  static const wideAt = 1200.0;

  /// The width at which the navigation rail extends into labelled rows. Not
  /// [wideAt]: a 13" iPad in landscape is 1376dp, and a 168dp rail there cost
  /// the in-game board width it needs — only a desktop-sized window has
  /// width to spare for it.
  static const extendedRailAt = 1600.0;

  static WindowClass fromWidth(double width) {
    if (width >= wideAt) return WindowClass.wide;
    if (width >= expandedAt) return WindowClass.expanded;
    if (width >= mediumAt) return WindowClass.medium;
    return WindowClass.compact;
  }

  static WindowClass of(BoxConstraints constraints) =>
      fromWidth(constraints.maxWidth);

  bool get isCompact => this == WindowClass.compact;
  bool get atLeastMedium => index >= WindowClass.medium.index;
  bool get atLeastExpanded => index >= WindowClass.expanded.index;
}

/// Full layout context: width class plus the landscape-phone special case
/// (wide but very short windows need their own board-left layout).
class LayoutSpec {
  const LayoutSpec(
    this.windowClass, {
    required this.landscapeCompact,
    this.landscape = false,
  });

  /// Below this height a stacked layout has nowhere left to stack.
  static const shortAt = 500.0;

  final WindowClass windowClass;

  /// True for phone-landscape-like geometry: too short for stacked
  /// layouts regardless of width.
  final bool landscapeCompact;

  /// Wider than tall. On its own it decides nothing for phones — their
  /// classes already say it — but a tablet's width class is the same in
  /// both orientations, and the shape is what tells a portrait iPad (one
  /// column, stacked) from a landscape one (side by side).
  final bool landscape;

  /// Browse screens compose side by side: a phone on its side, or a tablet
  /// window that is both expanded and landscape. The ONE gate for two-column
  /// browse layouts — a portrait iPad is 1032dp wide, and splitting it by
  /// width alone left half of every home screen empty.
  bool get split =>
      landscapeCompact || (windowClass.atLeastExpanded && landscape);

  /// Neither a phone in portrait nor a phone on its side: the windows the
  /// tablet compositions are for.
  bool get tablet => !windowClass.isCompact && !landscapeCompact;

  static LayoutSpec of(BoxConstraints constraints) =>
      LayoutSpec.fromSize(Size(constraints.maxWidth, constraints.maxHeight));

  /// The same decision from a raw size — for the few callers that must
  /// decide outside a `LayoutBuilder`. Prefer [of].
  static LayoutSpec fromSize(Size size) => LayoutSpec(
    WindowClass.fromWidth(size.width),
    landscapeCompact: size.height < shortAt && size.width > size.height,
    landscape: size.width > size.height,
  );
}

/// The height a fixed chrome slot needs at the reader's text scale.
///
/// Slot heights used to be compile-time constants while the app allows text
/// up to 1.3×, so the header bar and the player bars overflowed their own
/// slots on large-type devices. Growing the slot with the type keeps the
/// board geometry predictable without clipping the labels inside it.
///
/// [minimum] is the HIG tap target: a slot holding an icon button can never
/// be shorter than 48dp, whatever its nominal height.
double slotHeightFor(
  BuildContext context,
  double base, {
  double minimum = 48,
}) => slotHeightAt(MediaQuery.textScalerOf(context), base, minimum: minimum);

/// [slotHeightFor] without a context, for decisions that must be a pure
/// function of the window — `ModePanes.layoutFor` judges its branches at
/// [TextScaler.noScaling] so the reader's type size can never flip one.
double slotHeightAt(TextScaler scaler, double base, {double minimum = 48}) =>
    math.max(minimum, scaler.scale(base));

/// Ceiling on the board's edge. It used to be 760, which on a 13" iPad in
/// landscape left ~110dp of empty band above and below a board that had the
/// height to fill; the tablet layouts now let the board take the window's
/// short side, and this only stops a desktop-sized window from producing a
/// board nobody's eyes can take in at once. Phones never come near it.
const double boardMaxSize = 1000;

/// The square board edge that fits [constraints] after reserving
/// [reservedHeight] for surrounding chrome.
///
/// Never larger than the space actually available. This used to clamp *up*
/// to a 220dp floor, which on a short window handed the caller a board
/// bigger than the room it had measured — the chrome below it was then
/// squeezed out of its own layout.
double boardSizeFor(
  BoxConstraints constraints, {
  double reservedHeight = 0,
  double horizontalPadding = 16,
  double maxSize = boardMaxSize,
}) {
  final byWidth = constraints.maxWidth - horizontalPadding;
  final byHeight = constraints.maxHeight - reservedHeight;
  return math.max(0, math.min(math.min(byWidth, byHeight), maxSize));
}
