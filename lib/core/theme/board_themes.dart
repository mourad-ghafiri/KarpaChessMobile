import 'package:flutter/material.dart';

/// The five board colorways (light/dark square pairs) — all muted greens and
/// warm woods per the eye-comfort research; the tournament green pair is the
/// competitive standard and the default.
///
/// Each colorway also derives the frame it sits in. A board painted edge to
/// edge dissolves into a light-theme page (tournament's light square is
/// within 2 L\* of ivory paper); the bezel is what makes it an object on a
/// table instead of a pattern on the wall.
enum BoardColorTheme {
  tournament(Color(0xFFEEEED2), Color(0xFF769656)),
  walnut(Color(0xFFF0D9B5), Color(0xFFB58863)),
  sheesham(Color(0xFFEAD8C0), Color(0xFFA16F4A)),
  slate(Color(0xFFDDE1DA), Color(0xFF8A968A)),
  sage(Color(0xFFEFE7CF), Color(0xFF7D8F69));

  const BoardColorTheme(this.lightSquare, this.darkSquare);

  final Color lightSquare;
  final Color darkSquare;

  /// The frame around the squares: the dark square taken well down, so it
  /// separates from every page color in both modes.
  Color get bezel => Color.lerp(darkSquare, Colors.black, 0.38)!;

  /// The catch of light along the frame's top edge — what stops the bezel
  /// from reading as a flat black border.
  Color get bezelRim =>
      Color.lerp(lightSquare, Colors.white, 0.30)!.withValues(alpha: 0.28);

  /// The shadow the frame casts. Tinted by the wood rather than pure black,
  /// which is what keeps it from going muddy on a dark page.
  Color get bezelShadow => Color.lerp(darkSquare, Colors.black, 0.88)!;

  static BoardColorTheme fromId(String id) =>
      BoardColorTheme.values.firstWhere(
        (t) => t.name == id,
        orElse: () => BoardColorTheme.tournament,
      );
}
