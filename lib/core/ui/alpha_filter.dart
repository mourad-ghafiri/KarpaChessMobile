import 'dart:ui' show ColorFilter;

/// The app's fade primitive: a colour matrix that scales alpha by [alpha]
/// (1.0 = untouched, 0.0 = invisible).
///
/// Preferred over [Opacity], which forces a `saveLayer` on every paint —
/// a real cost on subtrees that repaint often, like a live board or a grid
/// of miniature boards.
ColorFilter alphaFilter(double alpha) => ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, alpha, 0, //
    ]);
