import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'board_themes.dart';

/// The app's ten themes: calm, low-saturation surrounds that keep the board
/// the star. Darks are tinted charcoals rather than pure black (kinder on
/// OLED and on the eyes over long sessions); lights are warm papers and one
/// cool daylight.
///
/// Every theme authors eleven colors. Four of them are the surface ladder —
/// `bg`, `panel`, `raised`, `float` — which steps by about 7 L* per plane in
/// the darks, so a card is visibly a card. Everything else in [AppTokens]
/// (hairlines, shadows, sheen, overlay washes) is derived from those eleven
/// by [_dark] and [_light], which is what keeps ten themes in step.
enum AppThemeId {
  midnightGrove,
  emberStudy,
  slateFocus,
  indigoHour,
  bronzeAge,
  jadeTerrace,
  plumVelvet,
  ivoryHall,
  linenMorning,
  harborLight,
}

extension AppThemeIdX on AppThemeId {
  static AppThemeId fromName(String? name) => AppThemeId.values.firstWhere(
        (t) => t.name == name,
        orElse: () => AppThemeId.midnightGrove,
      );

  /// The board colorway this theme was designed around. Choosing a theme
  /// adopts it, so the board moves with the app instead of staying behind.
  BoardColorTheme get board => switch (this) {
        AppThemeId.midnightGrove => BoardColorTheme.tournament,
        AppThemeId.emberStudy => BoardColorTheme.walnut,
        AppThemeId.slateFocus => BoardColorTheme.slate,
        AppThemeId.indigoHour => BoardColorTheme.slate,
        AppThemeId.bronzeAge => BoardColorTheme.sheesham,
        AppThemeId.jadeTerrace => BoardColorTheme.sage,
        AppThemeId.plumVelvet => BoardColorTheme.walnut,
        AppThemeId.ivoryHall => BoardColorTheme.tournament,
        AppThemeId.linenMorning => BoardColorTheme.sheesham,
        AppThemeId.harborLight => BoardColorTheme.slate,
      };
}

/// Token sets for every theme.
abstract final class AppThemes {
  static AppTokens of(AppThemeId id) => switch (id) {
        AppThemeId.midnightGrove => midnightGrove,
        AppThemeId.emberStudy => emberStudy,
        AppThemeId.slateFocus => slateFocus,
        AppThemeId.indigoHour => indigoHour,
        AppThemeId.bronzeAge => bronzeAge,
        AppThemeId.jadeTerrace => jadeTerrace,
        AppThemeId.plumVelvet => plumVelvet,
        AppThemeId.ivoryHall => ivoryHall,
        AppThemeId.linenMorning => linenMorning,
        AppThemeId.harborLight => harborLight,
      };

  /// The default palette, used before prefs load and whenever a stored id
  /// no longer exists.
  static AppTokens get fallback => midnightGrove;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  // ---- quality ladders (de-neonized; hue meaning preserved) ----

  static const _darkQuality = (
    brilliant: Color(0xFF4FAE99),
    best: Color(0xFF7FA86A),
    good: Color(0xFF9AA26B),
    inaccuracy: Color(0xFFC9A45C),
    mistake: Color(0xFFC08552),
    blunder: Color(0xFFB9645A),
  );

  static const _lightQuality = (
    brilliant: Color(0xFF177D6B),
    best: Color(0xFF3F7040),
    good: Color(0xFF6B7A3C),
    inaccuracy: Color(0xFF9A7A26),
    mistake: Color(0xFFA05F24),
    blunder: Color(0xFF9A4335),
  );

  /// A dark theme. Depth comes from the four-plane tonal ladder; the
  /// hairline, the shadow and the ink that lights a surface's top edge are
  /// all pulled from [tint], so no two dark themes share a surface color.
  static AppTokens _dark({
    required Color bg,
    required Color panel,
    required Color raised,
    required Color float,
    required Color text,
    required Color textDim,
    required Color textFaint,
    required Color accent,
    required Color info,
    required Color tint,
    required Color highlight,
  }) {
    // Lifted from 0xFFB9645A, which read 3.9:1 on a dark card and 2.6:1 on
    // a sheet — the colour of every error, failed puzzle and reset button.
    const danger = Color(0xFFD98073);
    return AppTokens(
      brightness: Brightness.dark,
      bg: bg,
      panel: panel,
      raised: raised,
      float: float,
      // A hairline the theme's own hue rather than the same white wash in
      // all seven darks.
      edge: _mix(tint, text, 0.55).withValues(alpha: 0.22),
      tint: tint,
      shadow: _mix(tint, Colors.black, 0.86),
      text: text,
      textDim: textDim,
      textFaint: textFaint,
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.18),
      onAccent: _mix(tint, Colors.black, 0.86),
      success: const Color(0xFF7FA86A),
      danger: danger,
      dangerSoft: danger.withValues(alpha: 0.20),
      info: info,
      brilliant: _darkQuality.brilliant,
      best: _darkQuality.best,
      good: _darkQuality.good,
      inaccuracy: _darkQuality.inaccuracy,
      mistake: _darkQuality.mistake,
      blunder: _darkQuality.blunder,
      hiMove: highlight.withValues(alpha: 0.82),
      hiLegal: highlight.withValues(alpha: 0.42),
      hiSelect: highlight.withValues(alpha: 0.95),
      hiCheck: danger.withValues(alpha: 0.78),
      scrim: bg.withValues(alpha: 0.78),
    );
  }

  /// A light theme. The planes barely move — paper is paper — so the lift
  /// comes from the shadows [AppTokens.surfaceAt] hangs off [tint].
  static AppTokens _light({
    required Color bg,
    required Color panel,
    required Color raised,
    required Color float,
    required Color text,
    required Color textDim,
    required Color textFaint,
    required Color accent,
    required Color info,
    required Color tint,
    required Color highlight,
  }) {
    const danger = Color(0xFF9A4335);
    return AppTokens(
      brightness: Brightness.light,
      bg: bg,
      panel: panel,
      raised: raised,
      float: float,
      edge: _mix(tint, bg, 0.74),
      tint: tint,
      shadow: _mix(tint, Colors.black, 0.42),
      text: text,
      textDim: textDim,
      textFaint: textFaint,
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.14),
      onAccent: Colors.white,
      success: const Color(0xFF3F7040),
      danger: danger,
      dangerSoft: danger.withValues(alpha: 0.16),
      info: info,
      brilliant: _lightQuality.brilliant,
      best: _lightQuality.best,
      good: _lightQuality.good,
      inaccuracy: _lightQuality.inaccuracy,
      mistake: _lightQuality.mistake,
      blunder: _lightQuality.blunder,
      hiMove: highlight.withValues(alpha: 0.82),
      hiLegal: highlight.withValues(alpha: 0.42),
      hiSelect: highlight.withValues(alpha: 0.95),
      hiCheck: danger.withValues(alpha: 0.72),
      scrim: _mix(tint, Colors.black, 0.42).withValues(alpha: 0.55),
    );
  }

  // ---- the ten themes ----

  /// The tournament green, after dark: mossy charcoal lit from within by leaf green.
  static final midnightGrove = _dark(
    bg: const Color(0xFF09130B),
    panel: const Color(0xFF1A211B),
    raised: const Color(0xFF29302A),
    float: const Color(0xFF384039),
    text: const Color(0xFFE4EAE5),
    textDim: const Color(0xFFA7ADA8),
    textFaint: const Color(0xFF858A86),
    accent: const Color(0xFF79BB74),
    info: const Color(0xFF73B4CE),
    tint: const Color(0xFF497E50),
    highlight: const Color(0xFF89E083),
  );

  /// A lamp-lit library: espresso and scorched oak under copper light.
  static final emberStudy = _dark(
    bg: const Color(0xFF1A0E04),
    panel: const Color(0xFF271D18),
    raised: const Color(0xFF372C26),
    float: const Color(0xFF473B35),
    text: const Color(0xFFF0E6E1),
    textDim: const Color(0xFFB2AAA5),
    textFaint: const Color(0xFF908783),
    accent: const Color(0xFFF3985B),
    info: const Color(0xFF88B693),
    tint: const Color(0xFFA36231),
    highlight: const Color(0xFFE3E26E),
  );

  /// Neutral graphite and steel — nothing on screen competes with the board.
  static final slateFocus = _dark(
    bg: const Color(0xFF091217),
    panel: const Color(0xFF1A2025),
    raised: const Color(0xFF282F34),
    float: const Color(0xFF373F44),
    text: const Color(0xFFE4E9ED),
    textDim: const Color(0xFFA7ACAF),
    textFaint: const Color(0xFF85898D),
    accent: const Color(0xFF74B6DC),
    info: const Color(0xFF83B796),
    tint: const Color(0xFF3C789B),
    highlight: const Color(0xFF9ED3F5),
  );

  /// Late-night calm: deep indigo warmed by periwinkle.
  static final indigoHour = _dark(
    bg: const Color(0xFF0F101C),
    panel: const Color(0xFF1D1F2A),
    raised: const Color(0xFF2C2D39),
    float: const Color(0xFF3C3D49),
    text: const Color(0xFFE7E7F1),
    textDim: const Color(0xFFAAABB3),
    textFaint: const Color(0xFF888891),
    accent: const Color(0xFFA2A6EB),
    info: const Color(0xFF65B7C5),
    tint: const Color(0xFF616EB1),
    highlight: const Color(0xFFC8C8F5),
  );

  /// Trophy warmth: near-black walnut under antique bronze.
  static final bronzeAge = _dark(
    bg: const Color(0xFF171005),
    panel: const Color(0xFF241F18),
    raised: const Color(0xFF332D26),
    float: const Color(0xFF433D35),
    text: const Color(0xFFECE7E2),
    textDim: const Color(0xFFAFAAA5),
    textFaint: const Color(0xFF8D8883),
    accent: const Color(0xFFD3AE66),
    info: const Color(0xFF7AB7AC),
    tint: const Color(0xFF8F7033),
    highlight: const Color(0xFFF6C55D),
  );

  /// A jewel tone kept quiet: deep teal under jade.
  static final jadeTerrace = _dark(
    bg: const Color(0xFF001413),
    panel: const Color(0xFF132221),
    raised: const Color(0xFF213130),
    float: const Color(0xFF304140),
    text: const Color(0xFFDFEBEA),
    textDim: const Color(0xFFA2ADAC),
    textFaint: const Color(0xFF808B8A),
    accent: const Color(0xFF4FC0A8),
    info: const Color(0xFF81B0D9),
    tint: const Color(0xFF008173),
    highlight: const Color(0xFF5CE1C5),
  );

  /// Distinctive but muted: aubergine velvet and orchid.
  static final plumVelvet = _dark(
    bg: const Color(0xFF170E17),
    panel: const Color(0xFF241D25),
    raised: const Color(0xFF332C34),
    float: const Color(0xFF433B44),
    text: const Color(0xFFECE6ED),
    textDim: const Color(0xFFAFA9B0),
    textFaint: const Color(0xFF8D878D),
    accent: const Color(0xFFDA96C1),
    info: const Color(0xFF79B2D7),
    tint: const Color(0xFF96608F),
    highlight: const Color(0xFFF5BBDF),
  );

  /// The tournament hall by day: buff paper and forest green.
  static final ivoryHall = _light(
    bg: const Color(0xFFEFEAE2),
    panel: const Color(0xFFFBF6EE),
    raised: const Color(0xFFFFFDF5),
    float: const Color(0xFFFFFFFF),
    text: const Color(0xFF2F291E),
    textDim: const Color(0xFF534D41),
    textFaint: const Color(0xFF6E675B),
    accent: const Color(0xFF39693B),
    info: const Color(0xFF236B83),
    tint: const Color(0xFF72824F),
    highlight: const Color(0xFF84E186),
  );

  /// Soft linen and clay, warmed by terracotta.
  static final linenMorning = _light(
    bg: const Color(0xFFF2E9E4),
    panel: const Color(0xFFFEF5F0),
    raised: const Color(0xFFFFFCF6),
    float: const Color(0xFFFFFFFF),
    text: const Color(0xFF322821),
    textDim: const Color(0xFF574B43),
    textFaint: const Color(0xFF72665D),
    accent: const Color(0xFFA24D32),
    info: const Color(0xFF4A6E53),
    tint: const Color(0xFFB86F4D),
    highlight: const Color(0xFFE3E26E),
  );

  /// Crisp daylight: cool paper and harbour teal.
  static final harborLight = _light(
    bg: const Color(0xFFE4ECF0),
    panel: const Color(0xFFF0F8FC),
    raised: const Color(0xFFF7FFFF),
    float: const Color(0xFFFFFFFF),
    text: const Color(0xFF202C30),
    textDim: const Color(0xFF435055),
    textFaint: const Color(0xFF5E6A6F),
    accent: const Color(0xFF00687A),
    info: const Color(0xFF406C52),
    tint: const Color(0xFF2D8197),
    highlight: const Color(0xFF6BDBF5),
  );

}
