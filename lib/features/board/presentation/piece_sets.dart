import 'package:chessground/chessground.dart' show PieceAssets;
import 'package:dartchess/dartchess.dart' show PieceKind, Side;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../prefs/application/prefs_controller.dart';

/// The app's own piece sets, in the order Settings offers them; the first is
/// the default.
///
/// Every set is original artwork drawn by `tool/gen_pieces.py` and dedicated
/// to the public domain (CC0 1.0, `assets/pieces/LICENSE`). Every board reads
/// its pieces through here — `KarpaBoard`, the pattern thumbnails, the
/// Settings previews — and never through chessground's `PieceSet`: those sets
/// are other people's art, several of them licensed for non-commercial use
/// only, and the vendored chessground no longer bundles them.
///
/// The five sets after the original five (marble to soft) crown the king
/// with a cut gem instead of a cross.
enum PieceSetId {
  /// Staunton forms, flat fill with one shade and a lit edge.
  classic,

  /// The Staunton forms turned in boxwood and rosewood.
  wood,

  /// A slender Staunton on a stepped pedestal, in polished stone.
  marble,

  /// The Staunton forms as a chess-book diagram: paper and ink.
  diagram,

  /// The pieces reduced to geometry, two-tone.
  modern,

  /// Art Deco: steps, flutes, a sunburst queen, lines of gold.
  deco,

  /// Low-poly: straight edges and planar facets.
  facet,

  /// Told apart by outline alone, with no line inside.
  silhouette,

  /// Rounded river-stone forms, softly lit, with a warm grey line.
  soft,

  /// Chunky, rounded forms with a thick line, for small screens.
  bold;

  /// This set's image of every [PieceKind].
  PieceAssets get assets => _assets[index];

  /// The stored choice, falling back to the default for an id this build
  /// does not know (a set removed, a hand-edited blob).
  static PieceSetId fromId(String id) => values.firstWhere(
        (s) => s.name == id,
        orElse: () => PieceSetId.classic,
      );

  /// The 1x image of [kind]; Flutter picks the 2.0x/3.0x/4.0x variant beside
  /// it for the screen's pixel ratio.
  String assetPath(PieceKind kind) {
    final side = kind.side == Side.white ? 'w' : 'b';
    return 'assets/pieces/$name/$side${kind.role.uppercaseLetter}.webp';
  }

  static final List<PieceAssets> _assets = [
    for (final s in values)
      {for (final kind in PieceKind.values) kind: AssetImage(s.assetPath(kind))},
  ];
}

/// The pieces the reader chose in Settings.
final pieceAssetsProvider = Provider<PieceAssets>(
  (ref) => PieceSetId.fromId(
    ref.watch(prefsControllerProvider.select((p) => p.pieceSet)),
  ).assets,
);
