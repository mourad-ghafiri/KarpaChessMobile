import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/app_spacing.dart';
import '../theme/tokens_context.dart';
import 'surface.dart';

/// The app's ONE transient-hint surface: a closable, non-modal toast that
/// floats near the control that summoned it (HIG popover semantics). Hosted
/// by `ModePanes.toast`, which docks it above the drawing tools and caps its
/// height against the window — so the header, and with it the close button,
/// can never be pushed off the top of a short screen. Content scrolls
/// inside whatever height it is given. Always closable — even while loading.
class HintToast extends StatelessWidget {
  const HintToast({
    super.key,
    required this.title,
    required this.onClose,
    this.icon = Icons.lightbulb_outline,
    this.loading = false,
    this.child,
  });

  final String title;
  final VoidCallback onClose;
  final IconData icon;

  /// Shows a spinner in the header; the close button stays.
  final bool loading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.enter,
      builder: (context, t, content) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: content,
        ),
      ),
      // Solid, not frosted: the toast floats over the board and panel, so
      // its text has to stay perfectly legible over whatever is behind it.
      child: Surface(
        elevation: Elevation.floating,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: tokens.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                    ),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: Icon(Icons.close, size: 18, color: tokens.textDim),
                ),
              ],
            ),
            if (child != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
