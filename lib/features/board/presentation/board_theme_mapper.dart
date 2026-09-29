import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/painting.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/board_themes.dart';

/// Builds a chessground [ChessboardColorScheme] for one of the app's board
/// colorways, using the active theme's overlay colors for last-move /
/// selection / legal-move highlights.
///
/// [wash], when given, is alpha-blended onto the square colors — a tint
/// painted on the wood UNDER the pieces, which stay at full strength. The
/// Studio uses it to say "side line" on the board surface itself, in the
/// same hue its bezel turns.
ChessboardColorScheme boardColorScheme(
  BoardColorTheme theme,
  AppTokens tokens, {
  Color? wash,
}) {
  final light =
      wash == null ? theme.lightSquare : Color.alphaBlend(wash, theme.lightSquare);
  final dark =
      wash == null ? theme.darkSquare : Color.alphaBlend(wash, theme.darkSquare);
  return ChessboardColorScheme(
    lightSquare: light,
    darkSquare: dark,
    background: SolidColorChessboardBackground(
      lightSquare: light,
      darkSquare: dark,
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: light,
      darkSquare: dark,
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: light,
      darkSquare: dark,
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: tokens.hiMove),
    selected: HighlightDetails(solidColor: tokens.hiSelect),
    validMoves: tokens.hiLegal,
    validPremoves: tokens.hiSelect,
  );
}
