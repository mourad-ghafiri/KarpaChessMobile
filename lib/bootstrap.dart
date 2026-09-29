import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/media/avatar_store.dart';
import 'prefs/application/prefs_controller.dart';
import 'progression/application/progression_controller.dart';

/// Everything that must happen before the first frame, each step guarded.
///
/// A device whose stored data cannot be read still opens the app — on
/// defaults, with the failure reported through the app's error sink — rather
/// than on a blank screen. The repositories already never throw; this is
/// the backstop for anything else (a platform-channel failure, say).
Future<ProviderContainer> bootstrap() async {
  final container = ProviderContainer();

  await _step('restoring preferences', () async {
    await container.read(prefsControllerProvider.notifier).restore(
          systemLangCandidate:
              PlatformDispatcher.instance.locale.toLanguageTag(),
        );
  });

  // The avatar's stored path goes stale when iOS moves the app container on
  // update. Re-find it (or drop it, so the glyph shows) before any screen
  // tries to draw it.
  await _step('relocating the player photo', () async {
    final prefs = container.read(prefsControllerProvider);
    final relocated = await container
        .read(avatarStoreProvider)
        .relocate(prefs.playerAvatarPath);
    if (relocated != prefs.playerAvatarPath) {
      await container
          .read(prefsControllerProvider.notifier)
          .setPlayerAvatarPath(relocated);
    }
  });

  await _step('restoring progression', () async {
    await container.read(progressionControllerProvider.notifier).restore();
  });

  return container;
}

Future<void> _step(String what, Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'KarpaChess bootstrap',
      context: ErrorDescription('while $what'),
    ));
  }
}
