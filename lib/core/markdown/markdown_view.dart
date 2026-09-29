/// Flutter renderer for the KarpaChess markdown dialect.
///
/// [MarkdownView] parses its source with `parseKarpaMarkdown` and renders the
/// resulting blocks with plain [Text.rich] spans — headings in 'Fraunces',
/// code and SAN chips in 'JetBrainsMono', SAN chips as inline rounded chips.
library;

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'karpa_markdown_parser.dart';

/// Visual configuration for [MarkdownView]. Build one via
/// [KarpaMarkdownStyle.fromTheme] (the widget's default) or construct it
/// directly to override individual pieces.
class KarpaMarkdownStyle {
  const KarpaMarkdownStyle({
    required this.body,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.code,
    required this.quote,
    required this.quoteBarColor,
    required this.sanChip,
    required this.sanChipBackground,
    required this.ruleColor,
    this.blockSpacing = 12,
  });

  /// Derives a style from the ambient [ThemeData].
  factory KarpaMarkdownStyle.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final type = theme.extension<AppTypography>() ??
        const AppTypography(AppFont.classic);
    final body = text.bodyMedium ?? const TextStyle(fontSize: 14);
    TextStyle heading(TextStyle? base) => (base ?? body).copyWith(
          fontFamily: type.font.display,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        );
    return KarpaMarkdownStyle(
      body: body.copyWith(color: scheme.onSurface, height: 1.45),
      h2: heading(text.titleLarge),
      h3: heading(text.titleMedium),
      h4: heading(text.titleSmall),
      code: body.copyWith(
        fontFamily: type.font.mono,
        fontSize: (body.fontSize ?? 14) - 1,
        color: scheme.onSurfaceVariant,
        backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
      ),
      quote: body.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        height: 1.45,
      ),
      quoteBarColor: scheme.primary.withValues(alpha: 0.4),
      sanChip: body.copyWith(
        fontFamily: type.font.mono,
        fontSize: (body.fontSize ?? 14) - 1,
        fontWeight: FontWeight.w600,
        color: scheme.primary,
        height: 1.2,
      ),
      sanChipBackground: scheme.primary.withValues(alpha: 0.1),
      ruleColor: theme.dividerColor,
    );
  }

  final TextStyle body;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle h4;
  final TextStyle code;
  final TextStyle quote;
  final Color quoteBarColor;

  /// Foreground style of a `{{...}}` SAN chip.
  final TextStyle sanChip;
  final Color sanChipBackground;
  final Color ruleColor;

  /// Vertical gap between consecutive blocks.
  final double blockSpacing;

  TextStyle headingStyle(int level) => switch (level) {
        2 => h2,
        3 => h3,
        _ => h4,
      };
}

/// Renders KarpaChess-flavoured markdown [source] as a column of blocks.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key, this.style, this.onSanTap});

  final String source;

  /// Null derives the style from [Theme.of].
  final KarpaMarkdownStyle? style;

  /// When set, `{{san}}` chips become tappable (e.g. to preview the move
  /// as an arrow on a nearby board).
  final ValueChanged<String>? onSanTap;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? KarpaMarkdownStyle.fromTheme(Theme.of(context));
    final blocks = parseKarpaMarkdown(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: resolved.blockSpacing,
      children: [for (final block in blocks) _buildBlock(block, resolved)],
    );
  }

  Widget _buildBlock(MdBlock block, KarpaMarkdownStyle style) =>
      switch (block) {
        MdHeading(:final level, :final spans) => Text.rich(
            TextSpan(children: _inlineSpans(spans, style)),
            style: style.headingStyle(level),
          ),
        MdParagraph(:final spans) => Text.rich(
            TextSpan(children: _inlineSpans(spans, style)),
            style: style.body,
          ),
        MdQuote(:final spans) => Container(
            padding: const EdgeInsetsDirectional.only(start: 12),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: style.quoteBarColor, width: 3),
              ),
            ),
            child: Text.rich(
              TextSpan(children: _inlineSpans(spans, style)),
              style: style.quote,
            ),
          ),
        MdListBlock(:final ordered, :final items) =>
          _buildList(ordered: ordered, items: items, style: style),
        MdRule() => Container(height: 1, color: style.ruleColor),
      };

  Widget _buildList({
    required bool ordered,
    required List<List<MdInline>> items,
    required KarpaMarkdownStyle style,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final (index, item) in items.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  ordered ? '${index + 1}.' : '•',
                  style: style.body,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _inlineSpans(item, style)),
                  style: style.body,
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<InlineSpan> _inlineSpans(List<MdInline> spans, KarpaMarkdownStyle style) {
    return [
      for (final span in spans)
        switch (span) {
          MdText(:final text) => TextSpan(text: text),
          MdBold(:final children) => TextSpan(
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: _inlineSpans(children, style),
            ),
          MdItalic(:final children) => TextSpan(
              style: const TextStyle(fontStyle: FontStyle.italic),
              children: _inlineSpans(children, style),
            ),
          MdCode(:final text) => TextSpan(text: text, style: style.code),
          MdSanChip(:final san) => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: _SanChip(
                san: san,
                style: style,
                onTap: onSanTap == null ? null : () => onSanTap!(san),
              ),
            ),
        },
    ];
  }
}

class _SanChip extends StatelessWidget {
  const _SanChip({required this.san, required this.style, this.onTap});

  final String san;
  final KarpaMarkdownStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.sanChipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(san, style: style.sanChip),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: chip,
    );
  }
}
