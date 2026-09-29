import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/tokens_context.dart';

/// Compact pill showing one stat (streak flame, XP, level, clock, tally).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final String? emoji;

  /// Defaults to the theme dim ink.
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = this.color ?? tokens.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : tokens.raised,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: tokens.edge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 13))
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          if (emoji != null || icon != null) const SizedBox(width: 4),
          // A chip is `mainAxisSize.min` but still inherits its parent's
          // width, so a long localized label overflowed rather than
          // shortening — and chips sit inside fixed-height slots.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? color : tokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
