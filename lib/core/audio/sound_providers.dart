import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prefs/application/prefs_controller.dart';
import 'sound_service.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = AudioPlayersSoundService(
    pack: ref.read(prefsControllerProvider).soundPack,
  );
  // Follow the pref without recreating pools for other packs eagerly.
  ref.listen(prefsControllerProvider.select((p) => p.soundPack),
      (_, pack) => service.setPack(pack));
  ref.onDispose(service.dispose);
  return service;
});

/// Plays [sound] iff the sound preference is on.
///
/// This is the ONE sound gate: every surface plays through it, so muting is
/// honored in a single place. It used to be four — this extension, a
/// byte-identical copy on `WidgetRef` in the academy providers, a third in
/// `PracticeController` and an inline check in the settings sheet — which is
/// four chances for a screen to play over a reader who asked for silence.
///
/// Riverpod's `Ref` (controllers) and `WidgetRef` (widgets) share no
/// supertype that carries `read`, so the gate is spelled twice over one
/// body rather than written twice.
extension SoundX on Ref {
  void playSound(AppSound sound) => _playIfOn(read, sound);
}

extension SoundWidgetX on WidgetRef {
  void playSound(AppSound sound) => _playIfOn(read, sound);
}

void _playIfOn(T Function<T>(ProviderListenable<T>) read, AppSound sound) {
  if (read(prefsControllerProvider).sound) {
    read(soundServiceProvider).play(sound);
  }
}
