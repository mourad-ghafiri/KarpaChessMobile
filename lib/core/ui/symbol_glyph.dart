import 'package:flutter/widgets.dart';

import '../theme/tokens_context.dart';

/// A symbol standing in as a mark — an art's, a pack's, a persona's, a rank's
/// — drawn so that every kind of symbol sits at one optical size.
///
/// A bare `Text` got two things wrong, and both showed most on the grids,
/// where twenty marks sit side by side:
///
/// - **Size.** A chess glyph or an arrow set at a font size inks about half as
///   tall as an emoji set at the same size, so a row of pack cards mixed marks
///   of two sizes. Type symbols are drawn [_typeScale] larger to meet the
///   emoji.
/// - **The black pawn.** ♟ is the one chess glyph that is also an emoji, and
///   the system draws it as one — a glossy black pawn, nearly invisible on a
///   dark card, among type pieces that take the accent. Flutter does not
///   honour the text-presentation selector (U+FE0E), and none of the app's
///   fonts carries chess glyphs, so the mark draws its outline twin ♙ (see
///   [typeSafe]).
///
/// The box is square and fixed, so whatever follows a mark starts on the same
/// column whichever mark it is; and, like an [Icon], it does not grow with the
/// reader's text size.
class SymbolGlyph extends StatelessWidget {
  const SymbolGlyph(this.symbol, {super.key, this.size = 22, this.color});

  final String symbol;

  /// The emoji size the mark is matched to. The box is [extent].
  final double size;

  /// Ink for type symbols. Emoji keep their own colours.
  final Color? color;

  /// How much larger a type symbol is set than an emoji, to ink as tall.
  static const _typeScale = 1.4;

  /// The side of the square the mark occupies.
  double get extent => size * _typeScale;

  /// Whether [symbol] draws as type rather than as an emoji: the arrows, the
  /// geometric shapes, the dice and the chess pieces. Everything else in the
  /// symbol blocks (⚔, ⚖, ⏸ …) is drawn by the emoji font whatever it is
  /// asked, so it is sized as the emoji it will be.
  static bool isType(String symbol) {
    final runes = symbol.runes.where((r) => r != 0xFE0E && r != 0xFE0F);
    if (runes.length != 1) return false;
    final r = runes.first;
    return (r >= 0x2190 && r <= 0x21FF) || // arrows
        (r >= 0x25A0 && r <= 0x25FC) || // geometric shapes, less ◽◾
        (r >= 0x2680 && r <= 0x2685) || // dice
        (r >= 0x2654 && r <= 0x265F); // chess
  }

  /// The stroke laid over a type symbol, as a share of its size.
  static const _weight = 0.035;

  @override
  Widget build(BuildContext context) {
    final type = isType(symbol);
    final base = TextStyle(fontSize: type ? extent : size, height: 1);
    Widget glyph(TextStyle style) => Text(
      typeSafe(symbol),
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
      style: style,
    );
    final fill = glyph(base.copyWith(color: color));
    return SizedBox.square(
      dimension: extent,
      child: Center(
        child: !type
            ? fill
            // One weight for every type mark. The system draws the outline
            // pieces (♘ ♖ ♙) in hairlines, which vanished beside the filled
            // ones on the same grid even in the accent; a stroke traced over
            // the glyph gives every mark the same line.
            : Stack(
                alignment: Alignment.center,
                children: [
                  ExcludeSemantics(
                    child: glyph(
                      base.copyWith(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = extent * _weight
                          ..strokeJoin = StrokeJoin.round
                          ..color =
                              color ??
                              DefaultTextStyle.of(context).style.color ??
                              context.tokens.text,
                      ),
                    ),
                  ),
                  fill,
                ],
              ),
      ),
    );
  }
}

/// [symbol] with the black pawn ♟ swapped for its outline twin ♙ — the one
/// chess glyph the system would otherwise draw as an emoji. For the places a
/// piece sits inline in a line of text rather than as a mark of its own.
String typeSafe(String symbol) =>
    symbol.replaceAll('️', '').replaceAll('︎', '').replaceAll('♟', '♙');
