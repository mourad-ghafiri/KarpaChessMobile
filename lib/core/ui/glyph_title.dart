import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/tokens_context.dart';
import 'symbol_glyph.dart';

/// A browse screen's app-bar title: its mark in the accent, then its name.
///
/// The art view and the pack page each built this row by hand, and the
/// Pattern Book typed its mark into the title string instead — three ways of
/// writing one title, with three different gaps between mark and name. The
/// name takes the app bar's own title style.
class GlyphTitle extends StatelessWidget {
  const GlyphTitle({super.key, required this.glyph, required this.title});

  final String glyph;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph.isNotEmpty) ...[
          SymbolGlyph(glyph, size: 18, color: context.tokens.accent),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
