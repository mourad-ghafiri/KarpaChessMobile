import 'dart:ui' show Color, Offset;

import 'package:dartchess/dartchess.dart' show Side;

/// The drawing palette: seven hues, in order.
class DrawColor {
  const DrawColor(this.id, this.hex);

  final String id;
  final String hex;

  Color get color => colorFromHex(hex);
}

const drawColors = [
  DrawColor('red', '#c25a3c'),
  DrawColor('orange', '#d88a3d'),
  DrawColor('yellow', '#e5b445'),
  DrawColor('green', '#3b7a55'),
  DrawColor('blue', '#2f4a6b'),
  DrawColor('purple', '#7a4f8a'),
  DrawColor('white', '#fbf6e8'),
];

/// Parses `#rrggbb` (web format). Malformed input falls back to the palette's
/// first color so a corrupt session never crashes rendering.
Color colorFromHex(String hex) {
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  final value = int.tryParse(cleaned, radix: 16);
  // The palette's first color, by reference — typing its hex twice let the
  // fallback drift from the palette.
  if (value == null || cleaned.length != 6) return drawColors.first.color;
  return Color(0xFF000000 | value);
}

/// A board square in board coordinates: row 0 = rank 8, col 0 = file a
/// (a8 top-left in the White-oriented view).
class BoardSquare {
  const BoardSquare(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is BoardSquare && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'BoardSquare($row, $col)';
}

// ===================================================================
// Coordinate mapping (board units, 0..8; a8 = top-left when White)
// ===================================================================

/// Maps a point between view units and board units (both 0..8). The White
/// orientation is the identity; Black rotates the board 180°. The transform
/// is an involution, so the same function converts in either direction.
Offset orientPoint(Offset p, Side orientation) =>
    orientation == Side.white ? p : Offset(8 - p.dx, 8 - p.dy);

/// The square containing a board-units point, or null when off-board.
BoardSquare? squareAt(Offset boardPt) {
  if (boardPt.dx < 0 || boardPt.dx > 8 || boardPt.dy < 0 || boardPt.dy > 8) {
    return null;
  }
  final col = boardPt.dx.floor();
  final row = boardPt.dy.floor();
  if (col < 0 || col > 7 || row < 0 || row > 7) return null;
  return BoardSquare(row, col);
}

/// Center of [sq] in board units.
Offset squareCenter(BoardSquare sq) => Offset(sq.col + 0.5, sq.row + 0.5);

/// True for a (1,2) / (2,1) knight displacement between two squares.
bool isKnightDisplacement(BoardSquare from, BoardSquare to) {
  final dr = (to.row - from.row).abs();
  final dc = (to.col - from.col).abs();
  return (dr == 1 && dc == 2) || (dr == 2 && dc == 1);
}

/// Points list for an arrow between two squares (web's #arrowGeometry):
/// a knight displacement renders as a 3-point L-bend with the longer leg
/// first (the canonical chess "L" reading direction); everything else is a
/// straight 2-point arrow between square centers.
List<Offset> arrowPointsBetween(BoardSquare from, BoardSquare to) {
  if (!isKnightDisplacement(from, to)) {
    return [squareCenter(from), squareCenter(to)];
  }
  final dr = (to.row - from.row).abs();
  final dc = (to.col - from.col).abs();
  final corner = dr > dc
      ? BoardSquare(to.row, from.col)
      : BoardSquare(from.row, to.col);
  return [squareCenter(from), squareCenter(corner), squareCenter(to)];
}

// ===================================================================
// Shapes
// ===================================================================

/// One annotation drawn over the board, in board-unit coordinates.
///
/// Immutable value objects with a JSON round-trip (the persisted format is
/// `kind`, `color` as `#rrggbb`, `stroke` in board units, then kind-specific
/// geometry).
sealed class DrawShape {
  const DrawShape({required this.color, required this.stroke});

  /// `#rrggbb` hex, one of [drawColors] in practice.
  final String color;

  /// Stroke width in board units (1.0 = one square).
  final double stroke;

  Color get uiColor => colorFromHex(color);

  Map<String, Object?> toJson();

  /// The same shape translated by [delta] board units. Highlights snap to
  /// the square containing their translated center (they are square-bound).
  DrawShape movedBy(Offset delta);

  /// The same shape in a different color.
  DrawShape withColor(String hex);

  /// The same shape with a different stroke width.
  DrawShape withStroke(double stroke);

  /// Tolerant parse: returns null for unknown kinds or malformed geometry so
  /// one bad entry never sinks the rest of a session.
  static DrawShape? fromJson(Map<String, Object?> json) {
    final color = json['color'] is String ? json['color'] as String : '#c25a3c';
    final stroke = json['stroke'] is num
        ? (json['stroke'] as num).toDouble()
        : 0.08;
    final points = _pointsFrom(json['points']);
    switch (json['kind']) {
      case 'arrow':
        return points.length >= 2
            ? ArrowShape(points: points, color: color, stroke: stroke)
            : null;
      case 'line':
        return points.length >= 2
            ? LineShape(a: points[0], b: points[1], color: color, stroke: stroke)
            : null;
      case 'highlight':
        final sq = json['sq'];
        if (sq is! List || sq.length < 2 || sq[0] is! num || sq[1] is! num) {
          return null;
        }
        return HighlightShape(
          square: BoardSquare((sq[0] as num).toInt(), (sq[1] as num).toInt()),
          color: color,
          stroke: stroke,
        );
      case 'rect':
        return points.length >= 2
            ? RectShape(a: points[0], b: points[1], color: color, stroke: stroke)
            : null;
      case 'circle':
        return points.length >= 2
            ? CircleShape(
                a: points[0], b: points[1], color: color, stroke: stroke)
            : null;
      case 'pen':
        return points.length >= 2
            ? PenShape(points: points, color: color, stroke: stroke)
            : null;
      case 'text':
        final text = json['text'];
        return points.isNotEmpty && text is String && text.isNotEmpty
            ? TextShape(
                at: points[0], text: text, color: color, stroke: stroke)
            : null;
    }
    return null;
  }

  static List<Offset> _pointsFrom(Object? raw) => [
        if (raw is List)
          for (final p in raw)
            if (p is List && p.length >= 2 && p[0] is num && p[1] is num)
              Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];

  static List<List<double>> _pointsJson(List<Offset> points) =>
      [for (final p in points) [p.dx, p.dy]];
}

bool _sameOffsets(List<Offset> a, List<Offset> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Straight or knight-bent arrow between square centers ([points] has 2 or 3
/// entries; the last segment carries the arrowhead).
class ArrowShape extends DrawShape {
  ArrowShape({required List<Offset> points, required super.color, required super.stroke})
      : points = List.unmodifiable(points);

  final List<Offset> points;

  @override
  ArrowShape movedBy(Offset delta) => ArrowShape(
      points: [for (final p in points) p + delta],
      color: color,
      stroke: stroke);

  @override
  ArrowShape withColor(String hex) =>
      ArrowShape(points: points, color: hex, stroke: stroke);

  @override
  ArrowShape withStroke(double width) =>
      ArrowShape(points: points, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'arrow',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson(points),
      };

  @override
  bool operator ==(Object other) =>
      other is ArrowShape &&
      other.color == color &&
      other.stroke == stroke &&
      _sameOffsets(other.points, points);

  @override
  int get hashCode => Object.hash('arrow', color, stroke, points.length);
}

/// Straight segment (no head).
class LineShape extends DrawShape {
  const LineShape(
      {required this.a, required this.b, required super.color, required super.stroke});

  final Offset a;
  final Offset b;

  @override
  LineShape movedBy(Offset delta) =>
      LineShape(a: a + delta, b: b + delta, color: color, stroke: stroke);

  @override
  LineShape withColor(String hex) =>
      LineShape(a: a, b: b, color: hex, stroke: stroke);

  @override
  LineShape withStroke(double width) =>
      LineShape(a: a, b: b, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'line',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson([a, b]),
      };

  @override
  bool operator ==(Object other) =>
      other is LineShape &&
      other.color == color &&
      other.stroke == stroke &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash('line', color, stroke, a, b);
}

/// Full-square tint on [square] (board coordinates, not view-flipped).
class HighlightShape extends DrawShape {
  const HighlightShape(
      {required this.square, required super.color, required super.stroke});

  final BoardSquare square;

  @override
  HighlightShape movedBy(Offset delta) {
    final row = (square.row + delta.dy).round().clamp(0, 7);
    final col = (square.col + delta.dx).round().clamp(0, 7);
    return HighlightShape(
        square: BoardSquare(row, col), color: color, stroke: stroke);
  }

  @override
  HighlightShape withColor(String hex) =>
      HighlightShape(square: square, color: hex, stroke: stroke);

  @override
  HighlightShape withStroke(double width) =>
      HighlightShape(square: square, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'highlight',
        'color': color,
        'stroke': stroke,
        'sq': [square.row, square.col],
      };

  @override
  bool operator ==(Object other) =>
      other is HighlightShape &&
      other.color == color &&
      other.stroke == stroke &&
      other.square == square;

  @override
  int get hashCode => Object.hash('highlight', color, stroke, square);
}

/// Outlined rectangle spanning corners [a]..[b].
class RectShape extends DrawShape {
  const RectShape(
      {required this.a, required this.b, required super.color, required super.stroke});

  final Offset a;
  final Offset b;

  @override
  RectShape movedBy(Offset delta) =>
      RectShape(a: a + delta, b: b + delta, color: color, stroke: stroke);

  @override
  RectShape withColor(String hex) =>
      RectShape(a: a, b: b, color: hex, stroke: stroke);

  @override
  RectShape withStroke(double width) =>
      RectShape(a: a, b: b, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'rect',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson([a, b]),
      };

  @override
  bool operator ==(Object other) =>
      other is RectShape &&
      other.color == color &&
      other.stroke == stroke &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash('rect', color, stroke, a, b);
}

/// Outlined ellipse inscribed in the box spanned by corners [a]..[b].
class CircleShape extends DrawShape {
  const CircleShape(
      {required this.a, required this.b, required super.color, required super.stroke});

  final Offset a;
  final Offset b;

  @override
  CircleShape movedBy(Offset delta) =>
      CircleShape(a: a + delta, b: b + delta, color: color, stroke: stroke);

  @override
  CircleShape withColor(String hex) =>
      CircleShape(a: a, b: b, color: hex, stroke: stroke);

  @override
  CircleShape withStroke(double width) =>
      CircleShape(a: a, b: b, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'circle',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson([a, b]),
      };

  @override
  bool operator ==(Object other) =>
      other is CircleShape &&
      other.color == color &&
      other.stroke == stroke &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash('circle', color, stroke, a, b);
}

/// Freehand polyline.
class PenShape extends DrawShape {
  PenShape({required List<Offset> points, required super.color, required super.stroke})
      : points = List.unmodifiable(points);

  final List<Offset> points;

  @override
  PenShape movedBy(Offset delta) => PenShape(
      points: [for (final p in points) p + delta],
      color: color,
      stroke: stroke);

  @override
  PenShape withColor(String hex) =>
      PenShape(points: points, color: hex, stroke: stroke);

  @override
  PenShape withStroke(double width) =>
      PenShape(points: points, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'pen',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson(points),
      };

  @override
  bool operator ==(Object other) =>
      other is PenShape &&
      other.color == color &&
      other.stroke == stroke &&
      _sameOffsets(other.points, points);

  @override
  int get hashCode => Object.hash('pen', color, stroke, points.length);
}

/// Short label centered at [at]; font size scales with [stroke].
class TextShape extends DrawShape {
  const TextShape(
      {required this.at, required this.text, required super.color, required super.stroke});

  final Offset at;
  final String text;

  @override
  TextShape movedBy(Offset delta) {
    final moved = at + delta;
    return TextShape(
      at: Offset(moved.dx.clamp(0.0, 8.0), moved.dy.clamp(0.0, 8.0)),
      text: text,
      color: color,
      stroke: stroke,
    );
  }

  @override
  TextShape withColor(String hex) =>
      TextShape(at: at, text: text, color: hex, stroke: stroke);

  @override
  TextShape withStroke(double width) =>
      TextShape(at: at, text: text, color: color, stroke: width);

  @override
  Map<String, Object?> toJson() => {
        'kind': 'text',
        'color': color,
        'stroke': stroke,
        'points': DrawShape._pointsJson([at]),
        'text': text,
      };

  @override
  bool operator ==(Object other) =>
      other is TextShape &&
      other.color == color &&
      other.stroke == stroke &&
      other.at == at &&
      other.text == text;

  @override
  int get hashCode => Object.hash('text', color, stroke, at, text);
}

// ===================================================================
// Hit testing (long-press delete)
// ===================================================================

/// Index of the topmost shape whose hit region contains [p] (board units),
/// or null.
int? hitTestShapes(List<DrawShape> shapes, Offset p) {
  for (var i = shapes.length - 1; i >= 0; i--) {
    if (shapeContainsPoint(shapes[i], p)) return i;
  }
  return null;
}

bool shapeContainsPoint(DrawShape shape, Offset p) {
  switch (shape) {
    case HighlightShape(:final square):
      return p.dx >= square.col &&
          p.dx <= square.col + 1 &&
          p.dy >= square.row &&
          p.dy <= square.row + 1;
    case ArrowShape(:final points):
      return _nearPolyline(points, p, shape.stroke);
    case PenShape(:final points):
      return _nearPolyline(points, p, shape.stroke);
    case LineShape(:final a, :final b):
      return _nearPolyline([a, b], p, shape.stroke);
    case RectShape(:final a, :final b):
      return _inBox(a, b, p);
    case CircleShape(:final a, :final b):
      return _inBox(a, b, p);
    case TextShape():
      // Finger-friendly: the glyph box padded to at least ~0.9×0.6 squares
      // (≥ 40×27dp on a 360dp board) so short labels stay grabbable.
      final box = textBounds(shape);
      final w = box.$3 < 0.9 ? 0.9 : box.$3;
      final h = box.$4 < 0.6 ? 0.6 : box.$4;
      final cx = box.$1 + box.$3 / 2;
      final cy = box.$2 + box.$4 / 2;
      return p.dx >= cx - w / 2 - 0.18 &&
          p.dx <= cx + w / 2 + 0.18 &&
          p.dy >= cy - h / 2 - 0.18 &&
          p.dy <= cy + h / 2 + 0.18;
  }
}

/// Approximate (x, y, w, h) glyph box for a text shape, synthesized from the
/// stroke-driven font size and text length (web's #shapeBoundingBox).
(double, double, double, double) textBounds(TextShape shape) {
  final fontSize = shape.stroke * 5 < 0.35 ? 0.35 : shape.stroke * 5;
  final len = shape.text.isEmpty ? 1 : shape.text.length;
  final w = len * fontSize * 0.55 < 0.5 ? 0.5 : len * fontSize * 0.55;
  final h = fontSize * 1.1;
  return (shape.at.dx - w / 2, shape.at.dy - h / 2, w, h);
}

bool _inBox(Offset a, Offset b, Offset p) {
  final minX = a.dx < b.dx ? a.dx : b.dx;
  final maxX = a.dx < b.dx ? b.dx : a.dx;
  final minY = a.dy < b.dy ? a.dy : b.dy;
  final maxY = a.dy < b.dy ? b.dy : a.dy;
  return p.dx >= minX - 0.05 &&
      p.dx <= maxX + 0.05 &&
      p.dy >= minY - 0.05 &&
      p.dy <= maxY + 0.05;
}

bool _nearPolyline(List<Offset> points, Offset p, double stroke) {
  final r = stroke * 2 > 0.18 ? stroke * 2 : 0.18;
  for (var i = 0; i < points.length - 1; i++) {
    if (_distPointSeg(p, points[i], points[i + 1]) < r) return true;
  }
  return false;
}

double _distPointSeg(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  var t = lenSq == 0
      ? 0.0
      : ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}
