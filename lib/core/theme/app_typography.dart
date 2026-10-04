import 'package:flutter/material.dart';

/// The typefaces a reader can choose in Settings. All three families ship
/// with the app, so switching never touches the network.
///
/// Chess notation is monospaced in every choice — SAN columns have to line
/// up — so only the display face changes personality.
enum AppFont {
  /// Editorial serif headings over a quiet sans body.
  classic(display: _fraunces),

  /// One calm sans throughout: the most legible at small sizes.
  modern(display: _inter),

  /// Engine-room character: notation-style headings.
  technical(display: _mono);

  const AppFont({required this.display});

  /// Family used for headings and other display text.
  final String display;

  static const _fraunces = 'Fraunces';
  static const _inter = 'Inter';
  static const _mono = 'JetBrainsMono';

  /// Reading text is always the sans — display faces don't set body copy.
  String get body => _inter;

  /// Notation, clocks and engine lines.
  String get mono => _mono;

  static AppFont fromName(String? name) => AppFont.values.firstWhere(
        (f) => f.name == name,
        orElse: () => AppFont.classic,
      );
}

/// The app's type scale, carried on the theme so a font change reaches
/// every screen. Read it through `context.type`; never hardcode a family.
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography(this.font);

  final AppFont font;

  /// Screen titles and celebration headlines.
  ///
  /// The scale runs 29 / 20 / 16 / 14 / 12.5 / 11.5 rather than crowding
  /// every heading into a three-point band: a screen title has to be
  /// unmistakably a screen title before anything under it can rank itself.
  TextStyle get display => TextStyle(
        fontFamily: font.display,
        fontSize: 29,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.4,
      );

  /// Section and card titles.
  TextStyle get title => TextStyle(
        fontFamily: font.display,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  /// Titles inside a card — one rank below [title].
  TextStyle get heading => TextStyle(
        fontFamily: font.display,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );

  /// Names on grid tiles and game rows — a [heading] one step smaller, so a
  /// two-line name fits a fixed cell. The art, pack and game cards typed
  /// this as 14, 14.5 and 15 before it had a name.
  TextStyle get subheading => TextStyle(
        fontFamily: font.display,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  /// Default reading text.
  TextStyle get body =>
      TextStyle(fontFamily: font.body, fontSize: 14, height: 1.45);

  /// Field labels and meta rows that are not quite captions.
  TextStyle get label => TextStyle(
        fontFamily: font.body,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      );

  /// Secondary/meta lines (pair with `tokens.textDim`).
  TextStyle get caption => TextStyle(fontFamily: font.body, fontSize: 11.5);

  /// Moves, clocks and evaluations.
  TextStyle get san => TextStyle(fontFamily: font.mono, fontSize: 13);

  /// A display style at an arbitrary size — for the few headings that need
  /// to deviate from [display]/[title].
  TextStyle displayAt(double size, {FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: font.display, fontSize: size, fontWeight: weight);

  /// A monospace style at an arbitrary size.
  TextStyle monoAt(double size, {FontWeight? weight}) =>
      TextStyle(fontFamily: font.mono, fontSize: size, fontWeight: weight);

  @override
  AppTypography copyWith({AppFont? font}) => AppTypography(font ?? this.font);

  @override
  AppTypography lerp(AppTypography? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
