import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/i18n/i18n_providers.dart';
import 'core/i18n/i18n_service.dart';
import 'core/layout/content_width.dart';
import 'core/layout/mode_shell.dart';
import 'core/layout/window_class.dart';
import 'core/lifecycle/app_lifecycle.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/themes.dart';
import 'prefs/application/prefs_controller.dart';
import 'core/theme/tokens_context.dart';

class KarpaChessApp extends ConsumerWidget {
  const KarpaChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the background/foreground battery gate alive for the app's
    // whole lifetime.
    ref.watch(appLifecycleGuardProvider);
    final i18n = ref.watch(i18nProvider);
    final themeId = AppThemeIdX.fromName(
      ref.watch(prefsControllerProvider.select((p) => p.appTheme)),
    );
    final font = AppFont.fromName(
      ref.watch(prefsControllerProvider.select((p) => p.font)),
    );

    final tokens = AppThemes.of(themeId);
    final lang = ref.watch(prefsControllerProvider.select((p) => p.lang));

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(tokens, font),
      // The framework's own strings — the text-selection menu, tooltips,
      // screen-reader labels, the licenses page — in the reader's language
      // rather than English. The app's copy stays in its i18n bundles.
      locale: materialLocaleFor(lang),
      supportedLocales: supportedMaterialLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Support Dynamic Type but keep board chrome intact: the fixed
      // slots are audited up to 1.3× (HIG allows clamping in dense,
      // board-first layouts).
      //
      // Both wrappers live in `builder` because it is an ANCESTOR of the
      // Navigator: every pushed route, root-navigator dialog and modal
      // sheet inherits them. Directionality once wrapped only `home:` —
      // one route inside the Navigator — which left every pushed screen,
      // dialog and sheet LTR in Arabic.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3),
        ),
        child: Directionality(
          textDirection: i18n.valueOrNull?.textDirection ?? TextDirection.ltr,
          // Status-bar icons readable on every screen. An AppBar sets its
          // own; screens without one (in-game, landscape, the fullscreen
          // modes) used to inherit whatever the last bar or the OS chose,
          // which could be dark icons on a dark theme.
          child: _TabletDialogs(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: _statusBarFor(tokens.brightness),
              child: child!,
            ),
          ),
        ),
      ),
      home: i18n.when(
        data: (_) => const ModeShell(),
        loading: () => const _Splash(),
        // Translations could not load, so English is the only language
        // left to say it in. The cause goes to the error sink, not the
        // screen.
        error: (_, _) => const _Splash(
          message: 'KarpaChess could not start. Please restart the app.',
        ),
      ),
    );
  }

  static SystemUiOverlayStyle _statusBarFor(Brightness theme) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Android: the icons' own brightness.
        statusBarIconBrightness:
            theme == Brightness.dark ? Brightness.light : Brightness.dark,
        // iOS: the brightness of what is BEHIND the status bar.
        statusBarBrightness: theme,
      );
}

/// The framework locale for an app language. The codes map one to one,
/// except Portuguese: the app's Portuguese is European, and Flutter ships
/// European Portuguese as `pt_PT`.
Locale materialLocaleFor(String lang) =>
    lang == 'pt' ? const Locale('pt', 'PT') : Locale(lang);

/// Every app language, as the framework locale that renders it.
final supportedMaterialLocales = [
  for (final lang in I18nService.supportedLangs) materialLocaleFor(lang),
];

/// Caps every dialog at [ContentWidth.dialog] on a tablet window.
///
/// Flutter lets an `AlertDialog` grow to the window minus 80dp, and sizes it
/// to its content's intrinsic width, so on an iPad a confirmation laid its
/// question out on one ~700dp line and the privacy notice ran to ~950dp.
/// Phones keep the framework default, untouched. Lives in the app's
/// `builder`, above the Navigator, so every dialog route inherits it; a
/// dialog that wants to be wider (Settings) passes its own constraints.
class _TabletDialogs extends StatelessWidget {
  const _TabletDialogs({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!LayoutSpec.fromSize(MediaQuery.sizeOf(context)).tablet) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          // The framework's own floor, kept.
          constraints: const BoxConstraints(
            minWidth: 280,
            maxWidth: ContentWidth.dialog,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    // Prefs haven't loaded yet, so the splash wears the default palette
    // rather than a hand-picked colour that drifts from the themes.
    final tokens = AppThemes.fallback;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('♞', style: TextStyle(fontSize: 64, color: tokens.accent)),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? 'KarpaChess',
              style: context.type.display.copyWith(color: tokens.text),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
