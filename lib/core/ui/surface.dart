import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tokens_context.dart';

/// The app's one surface. A widget names the plane it belongs to and the
/// theme decides how that plane is drawn — tonal step in the darks, shadow
/// in the lights.
///
/// This replaced a translucent card and an opaque one that differed only in
/// whether they cast a shadow. With a real elevation ladder that distinction
/// is just [Elevation], so there is a single surface to reason about.
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.elevation = Elevation.card,
    // md is the scale's own "inside a card" gutter; the old bare 14 sat
    // between tokens and made the default impossible to reason about.
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.card,
    this.wash,
    this.onTap,
  });

  final Widget child;

  /// How far above the page this surface sits.
  final Elevation elevation;

  final EdgeInsetsGeometry padding;
  final double radius;

  /// An optional color washed into the fill — how a card says "this one is
  /// the accented one" without leaving the elevation system.
  final Color? wash;

  /// When set, the surface responds: ink on tap, and a small press-scale.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = context.tokens.surfaceAt(elevation);
    final decoration = style.decoration(radius);
    final content = Container(
      padding: padding,
      decoration: wash == null
          ? decoration
          : decoration.copyWith(
              color: Color.alphaBlend(
                wash!.withValues(alpha: 0.12),
                style.fill,
              ),
              gradient: null,
            ),
      child: child,
    );

    if (onTap == null) return content;
    return _PressScale(
      onTap: onTap!,
      radius: radius,
      child: content,
    );
  }
}

/// Wraps a tappable surface in ink plus a brief scale-down.
///
/// The ink alone is invisible on a card that already fills its bounds with a
/// solid color; the scale is what actually acknowledges the touch.
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.onTap,
    required this.radius,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _down ? 0.975 : 1,
      duration: Motion.fast,
      curve: Motion.enter,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          borderRadius: borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
