import 'package:flutter/widgets.dart';

import '../layout/window_class.dart';

/// Spacing tokens on a 4pt grid, so gaps are chosen from a scale rather than
/// typed one literal at a time. Pair with [AppRadius] and [Motion].
abstract final class AppSpacing {
  /// Between an icon and its label; inside a chip.
  static const double xs = 4;

  /// Between stacked lines of related text.
  static const double sm = 8;

  /// The default gutter: inside a card, between adjacent controls.
  static const double md = 12;

  /// Screen margins and the gap between cards in a list.
  static const double lg = 16;

  /// Between sections of a screen.
  static const double xl = 24;

  /// Above a screen's first section, below its last.
  static const double xxl = 32;
}

/// Role-level insets composed from the [AppSpacing] scale. A screen never
/// invents its own page, sheet or panel padding — it names the role, so
/// sibling screens cannot drift apart one literal at a time.
///
/// Layout-contract constants (`ModePanes`' named paddings, the action-bar
/// margin, the pencil row's trailing 12) are deliberately NOT expressed
/// through these — they are documented in CLAUDE.md and owned where they
/// live.
abstract final class AppInsets {
  /// Outer padding of a detail screen's scroll body (lesson list, pack
  /// detail, pattern book, studio library).
  static const EdgeInsetsGeometry page = EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl);

  /// Outer padding of a HOME tab's scroll body — wider gutters once the
  /// window is not compact.
  static EdgeInsetsGeometry pageFor(WindowClass wc) => EdgeInsets.symmetric(
        horizontal: wc.isCompact ? AppSpacing.lg : AppSpacing.xl,
        vertical: AppSpacing.lg,
      );

  /// Content padding of a modal sheet, below the drag handle.
  static const EdgeInsetsGeometry sheet = EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl);

  /// A `ModePanes` panel's scroll padding — md horizontals, so panel prose
  /// shares an edge with the 12dp action-bar margin pinned below it.
  static const EdgeInsetsGeometry panel = EdgeInsetsDirectional.fromSTEB(
      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm);

  /// THE gutter between grid cells and between cards in a list.
  static const double gridGap = AppSpacing.md;
}
