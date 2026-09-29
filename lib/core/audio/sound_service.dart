import 'package:audioplayers/audioplayers.dart';
import '../errors/app_errors.dart';

/// The nine app sound effects.
enum AppSound { move, capture, check, castle, promote, win, lose, good, bad }

/// Playback boundary so features never touch the audio plugin directly.
abstract interface class SoundService {
  Future<void> play(AppSound sound);

  /// Switches the active sound pack ('wood' | 'plastic' | 'soft').
  void setPack(String pack);
  Future<void> dispose();
}

/// Plays the pre-rendered WAV assets (`assets/audio/*.wav`) through a
/// low-latency [AudioPool] per effect. Whether a sound actually plays is
/// decided by the caller (sound pref) — this class just plays.
class AudioPlayersSoundService implements SoundService {
  AudioPlayersSoundService({this.pack = 'wood'});

  String pack;

  /// One pool per effect, cached as the FUTURE of its creation: two plays
  /// of a sound that is still loading share one pool instead of each
  /// building its own and leaking the loser.
  final Map<String, Future<AudioPool>> _pools = {};

  /// How move sounds share the device with other audio. The plugin's
  /// default takes exclusive focus — Android AUDIOFOCUS_GAIN, an unmixed iOS
  /// session — so every move PAUSED the reader's music or podcast. Effects
  /// now mix: Android plays them as game sonification on the same media
  /// stream (the volume keys still control them) without requesting focus;
  /// iOS keeps its `playback` category, so the ring/silent switch behaves
  /// exactly as before, with `mixWithOthers` added.
  static final _effects = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  @override
  void setPack(String next) => pack = next;

  Future<AudioPool> _pool(AppSound sound) {
    final key = '$pack/${sound.name}';
    return _pools[key] ??= AudioPool.create(
      source: AssetSource('audio/$key.wav'),
      maxPlayers: 2,
      audioContext: _effects,
    ).catchError((Object error, StackTrace stack) {
      // A load that failed is forgotten, so the next play retries it.
      _pools.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
  }

  @override
  Future<void> play(AppSound sound) async {
    try {
      final pool = await _pool(sound);
      await pool.start();
    } catch (e) {
      // Sounds are cosmetic — never let audio failures surface.
      AppErrors.note('sound playback failed for ${sound.name}: $e');
    }
  }

  @override
  Future<void> dispose() async {
    final pools = List.of(_pools.values);
    _pools.clear();
    for (final pool in pools) {
      try {
        await (await pool).dispose();
      } catch (_) {
        // A pool that never loaded has nothing to release.
      }
    }
  }
}

/// No-op implementation for tests.
class SilentSoundService implements SoundService {
  const SilentSoundService();

  @override
  Future<void> play(AppSound sound) async {}

  @override
  void setPack(String pack) {}

  @override
  Future<void> dispose() async {}
}
