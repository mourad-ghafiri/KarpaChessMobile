import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens_context.dart';

/// The app's one error sink, installed before anything else runs.
///
/// Framework errors keep their usual presentation (`FlutterError.onError`).
/// Uncaught asynchronous errors — a failed future nobody awaited, a throw in
/// a timer — are routed into that same path instead of being printed by the
/// engine on the side, so there is exactly one place to attach a crash
/// reporter later. Nothing is sent anywhere: the app has no network access.
abstract final class AppErrors {
  static void install() {
    FlutterError.onError = FlutterError.presentError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'KarpaChess',
        context: ErrorDescription('while running asynchronous app code'),
      ));
      return true;
    };

    // Debug and profile keep Flutter's red error screen, which is what a
    // developer needs to see. A release build instead draws a quiet mark
    // where the widget failed, in the theme's faintest ink — never the
    // stock grey slab.
    if (kReleaseMode) {
      ErrorWidget.builder = (_) => const _QuietError();
    }
  }

  /// A diagnostic for something the app **handled**: a sound that would not
  /// warm up, a bundle that fell back to English, an engine line that
  /// arrived before the engine did. None of these is an error — each has a
  /// working fallback — so none goes to [FlutterError.reportError], which
  /// would present a failure the reader never experienced.
  ///
  /// They stay out of a release build entirely. `debugPrint` is throttled,
  /// not debug-gated, so a call site that used it wrote to the device log of
  /// a shipped app forever. Whether a diagnostic is printed is this sink's
  /// decision, not each call site's.
  static void note(String message) {
    if (kDebugMode) debugPrint('KarpaChess: $message');
  }
}

class _QuietError extends StatelessWidget {
  const _QuietError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.error_outline,
        size: 20,
        color: context.tokens.textFaint,
      ),
    );
  }
}
