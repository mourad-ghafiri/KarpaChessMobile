import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Builds a [ThemeData] from an [AppTokens] set and the reader's chosen
/// [AppFont] — one builder serves all ten themes, dark and light alike.
/// Both ride along as [ThemeExtension]s, so widgets read colors via
/// `context.tokens` and type via `context.type`.
abstract final class AppTheme {
  static ThemeData build(AppTokens t, AppFont font) {
    final type = AppTypography(font);
    final float = t.surfaceAt(Elevation.floating);
    final colorScheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.info,
      onSecondary: t.onAccent,
      // What a tonal button fills with: the accent's soft wash and the
      // accent ink, the pair every selected chip and well already wears.
      secondaryContainer: t.accentSoft,
      onSecondaryContainer: t.accent,
      tertiary: t.brilliant,
      onTertiary: t.onAccent,
      error: t.danger,
      onError: t.onAccent,
      surface: t.panel,
      onSurface: t.text,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.panel,
      surfaceContainer: t.raised,
      surfaceContainerHigh: t.raised,
      surfaceContainerHighest: t.float,
      outline: t.edge,
      outlineVariant: t.textFaint,
      shadow: t.shadow,
      scrim: t.scrim,
      inverseSurface: t.text,
      onInverseSurface: t.bg,
      onSurfaceVariant: t.textDim,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: colorScheme,
      fontFamily: font.body,
      scaffoldBackgroundColor: t.bg,
      splashFactory: InkSparkle.splashFactory,
      // Every InkWell in the app inherits its response from here, which is
      // why there is no per-widget hover/press wiring anywhere else.
      hoverColor: t.accent.withValues(alpha: 0.07),
      focusColor: t.accent.withValues(alpha: 0.12),
      highlightColor: t.accent.withValues(alpha: 0.09),
      splashColor: t.accent.withValues(alpha: 0.14),
      extensions: [t, type],
    );

    final textTheme = base.textTheme
        .apply(bodyColor: t.text, displayColor: t.text)
        .copyWith(
          displayLarge: _display(base.textTheme.displayLarge, font),
          displayMedium: _display(base.textTheme.displayMedium, font),
          displaySmall: _display(base.textTheme.displaySmall, font),
          headlineLarge: _display(base.textTheme.headlineLarge, font),
          headlineMedium: _display(base.textTheme.headlineMedium, font),
          headlineSmall: _display(base.textTheme.headlineSmall, font),
          titleLarge: _display(base.textTheme.titleLarge, font),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        // Content scrolling under the bar tints it, so the bar stops
        // dissolving into the page the moment the page starts moving.
        scrolledUnderElevation: 3,
        surfaceTintColor: t.tint,
        shadowColor: t.shadow,
        centerTitle: false,
        titleTextStyle: type.title.copyWith(color: t.text, fontSize: 21),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.panel,
        indicatorColor: t.accentSoft,
        surfaceTintColor: Colors.transparent,
        overlayColor: _overlay(t.accent),
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? t.accent
                : t.textDim,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            letterSpacing: -0.1,
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.ellipsis,
            color: states.contains(WidgetState.selected)
                ? t.accent
                : t.textDim,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.panel,
        indicatorColor: t.accentSoft,
        selectedIconTheme: IconThemeData(color: t.accent),
        unselectedIconTheme: IconThemeData(color: t.textDim),
        selectedLabelTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.accent,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.textDim,
        ),
      ),
      // No colours here: `FilledButton.tonal` reads this same theme, so
      // naming the accent fill made every tonal button an identical second
      // primary. The scheme already gives the filled one accent on
      // onAccent, and the tonal one its soft container (above).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ).copyWith(overlayColor: _overlay(t.onAccent)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          // The filled button's height: the two share rows (Cancel beside
          // Import, Rematch beside Review), and at 44 against 48 their edges
          // never lined up.
          minimumSize: const Size(64, 48),
          side: BorderSide(color: t.edge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ).copyWith(overlayColor: _overlay(t.accent)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.accent)
            .copyWith(overlayColor: _overlay(t.accent)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.textDim)
            .copyWith(overlayColor: _overlay(t.accent)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: t.accentSoft,
          selectedForegroundColor: t.accent,
          foregroundColor: t.textDim,
          side: BorderSide(color: t.edge),
        ).copyWith(overlayColor: _overlay(t.accent)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: t.raised,
        side: BorderSide(color: t.edge),
        labelStyle: TextStyle(color: t.text),
      ),
      // One field, app-wide: a `raised` well with the theme's hairline,
      // ringed in the accent while it has focus. The Studio's search and
      // import fields each built this by hand while the three dialog fields
      // fell back to Material's underline, so the app had two text inputs.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: t.raised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        // The dim ink, not the faint one: on a field's raised fill the faint
        // ink read 3.9:1, and 3.1:1 for helper text on a sheet.
        hintStyle: TextStyle(color: t.textDim),
        labelStyle: TextStyle(color: t.textDim),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? t.danger
                : states.contains(WidgetState.focused)
                ? t.accent
                : t.textDim,
          ),
        ),
        helperStyle: type.caption.copyWith(color: t.textDim),
        helperMaxLines: 2,
        counterStyle: type.caption.copyWith(color: t.textDim),
        errorStyle: type.caption.copyWith(
          color: t.legible(t.danger, on: float.fill),
        ),
        errorMaxLines: 3,
        prefixIconColor: t.textDim,
        suffixIconColor: t.textDim,
        border: _field(t.edge),
        enabledBorder: _field(t.edge),
        focusedBorder: _field(t.accent, width: 1.6),
        errorBorder: _field(t.danger),
        focusedErrorBorder: _field(t.danger, width: 1.6),
        disabledBorder: _field(t.edge.withValues(alpha: t.edge.a * 0.5)),
      ),
      dividerTheme: DividerThemeData(color: t.edge, thickness: 1),
      // Matches the HintToast voice: a floating surface with a hairline —
      // one transient-message look app-wide.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: float.fill,
        contentTextStyle: TextStyle(color: t.text, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: float.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: float.fill,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: t.scrim,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: float.fill,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: float.border),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        thumbColor: t.accent,
        inactiveTrackColor: t.track,
        overlayColor: t.accent.withValues(alpha: 0.14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.accent
              : t.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.accentSoft
              : t.track,
        ),
        overlayColor: _overlay(t.accent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.track,
        circularTrackColor: t.track,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: float.decoration(AppRadius.control),
        textStyle: TextStyle(fontSize: 12, color: t.text),
      ),
    );
  }

  /// The one interaction ramp: hover, focus and press all read as the same
  /// gesture in every control.
  static WidgetStateProperty<Color?> _overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.focused)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        return null;
      });

  static OutlineInputBorder _field(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextStyle? _display(TextStyle? style, AppFont font) =>
      style?.copyWith(fontFamily: font.display, fontWeight: FontWeight.w600);
}
