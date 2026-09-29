import 'package:flutter/material.dart';

/// Converts the html-lite subset used by ported i18n strings into the app's
/// markdown dialect, so the text can flow through [MarkdownView]:
/// `<b>`→`**`, `<i>`→`*`, `<br>`→newline; any other tag is stripped.
String htmlLiteToMarkdown(String source) {
  var text = source;
  text = text.replaceAllMapped(
    RegExp('<b>(.*?)</b>', caseSensitive: false, dotAll: true),
    (m) => '**${m[1]}**',
  );
  text = text.replaceAllMapped(
    RegExp('<i>(.*?)</i>', caseSensitive: false, dotAll: true),
    (m) => '*${m[1]}*',
  );
  text = text.replaceAll(RegExp('<br\\s*/?>', caseSensitive: false), '\n');
  return text.replaceAll(RegExp('<[^>]*>'), '');
}

/// Renders the tiny HTML subset used by the i18n strings
/// (`<b>`, `<i>`, `<br>`); any other tag is stripped.
TextSpan htmlLiteSpan(String source, {TextStyle? style, TextStyle? boldStyle}) {
  final spans = <InlineSpan>[];
  final pattern = RegExp('<(/?)(b|i|br)\\s*/?>', caseSensitive: false);
  var bold = 0;
  var italic = 0;
  var index = 0;

  void addText(String text) {
    if (text.isEmpty) return;
    final clean = text.replaceAll(RegExp('<[^>]*>'), '');
    if (clean.isEmpty) return;
    spans.add(TextSpan(
      text: clean,
      style: TextStyle(
        fontWeight: bold > 0 ? FontWeight.w700 : null,
        fontStyle: italic > 0 ? FontStyle.italic : null,
      ).merge(bold > 0 ? boldStyle : null),
    ));
  }

  for (final match in pattern.allMatches(source)) {
    addText(source.substring(index, match.start));
    final closing = match.group(1) == '/';
    switch (match.group(2)!.toLowerCase()) {
      case 'b':
        bold += closing ? -1 : 1;
      case 'i':
        italic += closing ? -1 : 1;
      case 'br':
        spans.add(const TextSpan(text: '\n'));
    }
    index = match.end;
  }
  addText(source.substring(index));

  return TextSpan(style: style, children: spans);
}

/// Convenience widget for [htmlLiteSpan].
class HtmlLiteText extends StatelessWidget {
  const HtmlLiteText(this.source, {super.key, this.style, this.textAlign});

  final String source;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      htmlLiteSpan(source, style: style),
      textAlign: textAlign,
    );
  }
}
