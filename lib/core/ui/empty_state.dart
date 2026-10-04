import 'package:flutter/material.dart';

import '../layout/content_width.dart';
import '../theme/app_spacing.dart';
import '../theme/tokens_context.dart';
import 'symbol_glyph.dart';

/// What a screen shows when it has nothing to show: a quiet mark, the
/// sentence that says why, and — when something went wrong — what.
///
/// The Pattern Book, the lesson player and the Studio's search each drew
/// their own: a pawn at 44 over a 13pt line, a pawn at 40 over a 12pt error,
/// and a bare 13pt sentence. One widget, so an empty screen reads the same
/// wherever a reader meets one.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.glyph = '♟',
    this.icon,
    this.message,
    this.error,
  });

  /// The mark, when there is no [icon].
  final String glyph;

  /// A Material icon in place of the [glyph] (a search with no results).
  final IconData? icon;

  /// Why the screen is empty.
  final String? message;

  /// What failed, set in the danger ink.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        // A reading measure, or a tablet sets the sentence on one line
        // across the whole window.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 40, color: tokens.textFaint)
              else
                SymbolGlyph(glyph, size: 30, color: tokens.textFaint),
              if (message case final line?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: context.type.body.copyWith(color: tokens.textDim),
                ),
              ],
              if (error case final line?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: context.type.caption.copyWith(color: tokens.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
