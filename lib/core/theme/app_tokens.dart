import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How far a surface sits above the page.
///
/// This is the app's only depth vocabulary. A widget names the plane it
/// belongs to and [AppTokens.surfaceAt] decides how that plane is drawn —
/// which differs by brightness, because dark themes get their depth from
/// tone and light themes get theirs from shadow.
enum Elevation {
  /// Cards, sheets, list rows — content resting on the page.
  card,

  /// Inner surfaces on a card: chips, tracks, wells.
  raised,

  /// Toasts, menus and dialogs floating over content.
  floating,
}

/// Everything needed to paint one plane: what fills it, what edges it, what
/// it casts, and the light that catches its top edge.
@immutable
class SurfaceStyle {
  const SurfaceStyle({
    required this.fill,
    required this.border,
    required this.shadows,
    this.sheen,
  });

  final Color fill;
  final Color border;
  final List<BoxShadow> shadows;

  /// A faint top-edge gradient that makes a dark surface read as lit rather
  /// than painted. Null in light themes, where shadow does the work.
  final Gradient? sheen;

  /// The decoration for a surface with the given corner radius.
  BoxDecoration decoration(double radius) => BoxDecoration(
        color: fill,
        gradient: sheen,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: shadows,
      );
}

/// Every color the app uses, as one immutable token set. Ten complete themes
/// instantiate this (see themes.dart); widgets read it via `context.tokens`
/// and never hardcode colors.
///
/// Eleven colors are authored per theme; everything below is derived from
/// them, so a theme cannot drift out of step with the rest of the system.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.bg,
    required this.panel,
    required this.raised,
    required this.float,
    required this.edge,
    required this.tint,
    required this.shadow,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.brilliant,
    required this.best,
    required this.good,
    required this.inaccuracy,
    required this.mistake,
    required this.blunder,
    required this.hiMove,
    required this.hiLegal,
    required this.hiSelect,
    required this.hiCheck,
    required this.scrim,
  });

  final Brightness brightness;

  // ---- the four planes, ~7 L* apart in dark themes ----
  final Color bg;
  final Color panel;
  final Color raised;
  final Color float;

  /// The hairline that separates one plane from the next.
  final Color edge;

  /// The theme's own hue at mid lightness. Surfaces, hairlines and shadows
  /// all carry a trace of it, which is what stops seven dark themes from
  /// rendering as the same grey.
  final Color tint;

  /// Opaque shadow base — a darkened, saturated [tint], never pure black.
  /// [surfaceAt] applies the alpha.
  final Color shadow;

  // ---- Ink ----
  final Color text;
  final Color textDim;
  final Color textFaint;

  // ---- Brand accent ----
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  // ---- Semantic ----
  final Color success;
  final Color danger;
  final Color dangerSoft;
  final Color info;

  // ---- Move-quality ladder ----
  final Color brilliant;
  final Color best;
  final Color good;
  final Color inaccuracy;
  final Color mistake;
  final Color blunder;

  // ---- Board interaction overlays ----
  final Color hiMove;
  final Color hiLegal;
  final Color hiSelect;

  /// The king-in-check wash. Ours rather than chessground's hardcoded red,
  /// which clashes with every non-red palette.
  final Color hiCheck;

  final Color scrim;

  /// The empty part of a progress bar, ring, slider or switch. It used to be
  /// [raised], which sits ~1.06:1 against a light theme's cards, so an
  /// unstarted bar (every "0 / 12" pack) vanished and the XP ring lost its
  /// outline. A trace of the ink over [panel] keeps it visible in every theme
  /// (~1.7:1 dark, ~1.5:1 light) while the accent fill still reads at better
  /// than 3.5:1 against it.
  Color get track => Color.alphaBlend(
        text.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.22),
        panel,
      );

  /// [fg] as text that reads on [on]: returned unchanged when it already
  /// meets [minRatio], otherwise stepped toward [text] until it does.
  ///
  /// For the hue-carrying inks — quality colours, the accent on its own soft
  /// wash, danger on a floating sheet — whose base values were picked to
  /// read on the page, not on every tinted fill they end up on. [on] must be
  /// opaque; composite a translucent fill over its surface first.
  Color legible(Color fg, {required Color on, double minRatio = 4.5}) {
    var ink = fg;
    for (var step = 1; step <= 10 && contrast(ink, on) < minRatio; step++) {
      ink = Color.lerp(fg, text, step / 10)!;
    }
    return ink;
  }

  /// WCAG contrast ratio between two opaque colours.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// How a surface on [e] is painted in this theme.
  ///
  /// Dark themes step the fill up the tonal ladder and keep shadows quiet;
  /// light themes barely move the fill and let the shadow do the lifting.
  /// Either way [Elevation.raised] reads as above [Elevation.card].
  SurfaceStyle surfaceAt(Elevation e) {
    final dark = brightness == Brightness.dark;
    final fill = switch (e) {
      Elevation.card => panel,
      Elevation.raised => raised,
      Elevation.floating => float,
    };
    final borderAlpha = switch (e) {
      Elevation.card => dark ? 0.55 : 0.75,
      Elevation.raised => dark ? 0.80 : 0.60,
      Elevation.floating => dark ? 1.0 : 0.45,
    };
    return SurfaceStyle(
      fill: fill,
      border: edge.withValues(alpha: edge.a * borderAlpha),
      shadows: _shadows(e, dark),
      sheen: dark ? _sheen(e) : null,
    );
  }

  List<BoxShadow> _shadows(Elevation e, bool dark) {
    // Ambient + key. In dark themes the tone already carries the hierarchy,
    // so shadows only ground the surface; in light themes they are the
    // hierarchy, so they are deeper and reach further.
    final (ambient, key) = switch (e) {
      Elevation.card => dark ? (0.22, 0.16) : (0.07, 0.05),
      Elevation.raised => dark ? (0.28, 0.20) : (0.10, 0.07),
      Elevation.floating => dark ? (0.40, 0.30) : (0.16, 0.11),
    };
    final spread = switch (e) {
      Elevation.card => 1.0,
      Elevation.raised => 1.6,
      _ => 2.4,
    };
    return [
      BoxShadow(
        color: shadow.withValues(alpha: ambient),
        blurRadius: 14 * spread,
        offset: Offset(0, 5 * spread),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: key),
        blurRadius: 3 * spread,
        offset: Offset(0, 1.5 * spread),
      ),
    ];
  }

  Gradient _sheen(Elevation e) {
    final strength = switch (e) {
      Elevation.card => 0.030,
      Elevation.raised => 0.045,
      Elevation.floating => 0.065,
    };
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.alphaBlend(
          text.withValues(alpha: strength),
          switch (e) {
            Elevation.card => panel,
            Elevation.raised => raised,
            _ => float,
          },
        ),
        switch (e) {
          Elevation.card => panel,
          Elevation.raised => raised,
          _ => float,
        },
      ],
      stops: const [0, 0.55],
    );
  }

  @override
  AppTokens copyWith({
    Brightness? brightness,
    Color? bg,
    Color? panel,
    Color? raised,
    Color? float,
    Color? edge,
    Color? tint,
    Color? shadow,
    Color? text,
    Color? textDim,
    Color? textFaint,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? brilliant,
    Color? best,
    Color? good,
    Color? inaccuracy,
    Color? mistake,
    Color? blunder,
    Color? hiMove,
    Color? hiLegal,
    Color? hiSelect,
    Color? hiCheck,
    Color? scrim,
  }) {
    return AppTokens(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      float: float ?? this.float,
      edge: edge ?? this.edge,
      tint: tint ?? this.tint,
      shadow: shadow ?? this.shadow,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      brilliant: brilliant ?? this.brilliant,
      best: best ?? this.best,
      good: good ?? this.good,
      inaccuracy: inaccuracy ?? this.inaccuracy,
      mistake: mistake ?? this.mistake,
      blunder: blunder ?? this.blunder,
      hiMove: hiMove ?? this.hiMove,
      hiLegal: hiLegal ?? this.hiLegal,
      hiSelect: hiSelect ?? this.hiSelect,
      hiCheck: hiCheck ?? this.hiCheck,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      panel: mix(panel, other.panel),
      raised: mix(raised, other.raised),
      float: mix(float, other.float),
      edge: mix(edge, other.edge),
      tint: mix(tint, other.tint),
      shadow: mix(shadow, other.shadow),
      text: mix(text, other.text),
      textDim: mix(textDim, other.textDim),
      textFaint: mix(textFaint, other.textFaint),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      info: mix(info, other.info),
      brilliant: mix(brilliant, other.brilliant),
      best: mix(best, other.best),
      good: mix(good, other.good),
      inaccuracy: mix(inaccuracy, other.inaccuracy),
      mistake: mix(mistake, other.mistake),
      blunder: mix(blunder, other.blunder),
      hiMove: mix(hiMove, other.hiMove),
      hiLegal: mix(hiLegal, other.hiLegal),
      hiSelect: mix(hiSelect, other.hiSelect),
      hiCheck: mix(hiCheck, other.hiCheck),
      scrim: mix(scrim, other.scrim),
    );
  }
}
