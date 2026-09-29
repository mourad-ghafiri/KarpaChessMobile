import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n_service.dart';
import '../data/shared_prefs_repository.dart';
import '../domain/prefs.dart';
import '../domain/prefs_repository.dart';

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => SharedPrefsRepository(),
);

/// Loaded once at bootstrap (see main.dart) and overridden with the real
/// value, so the rest of the app can read prefs synchronously.
final prefsControllerProvider =
    NotifierProvider<PrefsController, Prefs>(PrefsController.new);

class PrefsController extends Notifier<Prefs> {
  @override
  bool updateShouldNotify(Prefs previous, Prefs next) => previous != next;

  @override
  Prefs build() => const Prefs();

  PrefsRepository get _repo => ref.read(prefsRepositoryProvider);

  /// Replaces state with the persisted value; called during bootstrap.
  /// On first run the app language is resolved from [systemLangCandidate]
  Future<void> restore({String? systemLangCandidate}) async {
    final persisted = await _repo.load();
    if (persisted != null) {
      state = persisted;
      return;
    }
    final first = Prefs(lang: I18nService.resolveLang(systemLangCandidate));
    state = first;
    await _repo.save(first);
  }

  Future<void> _commit(Prefs next) async {
    state = next;
    await _repo.save(next);
  }

  Future<void> setAppTheme(String id) =>
      _commit(state.copyWith(appTheme: id));
  Future<void> setFont(String id) => _commit(state.copyWith(font: id));
  Future<void> setBoardTheme(String id) =>
      _commit(state.copyWith(boardTheme: id));
  Future<void> setPieceSet(String id) =>
      _commit(state.copyWith(pieceSet: id));
  Future<void> setCoords(bool v) => _commit(state.copyWith(coords: v));
  Future<void> setLegalHighlight(bool v) =>
      _commit(state.copyWith(legalHighlight: v));
  Future<void> setLastMoveHighlight(bool v) =>
      _commit(state.copyWith(lastMoveHighlight: v));
  Future<void> setSound(bool v) => _commit(state.copyWith(sound: v));
  Future<void> setSoundPack(String pack) =>
      _commit(state.copyWith(soundPack: pack));
  Future<void> setHaptics(bool v) => _commit(state.copyWith(haptics: v));
  Future<void> setAnimations(bool v) => _commit(state.copyWith(animations: v));
  Future<void> setLang(String lang) => _commit(state.copyWith(lang: lang));
  Future<void> setDifficulty(int level) =>
      _commit(state.copyWith(difficulty: level));
  Future<void> setPlayAs(String playAs) =>
      _commit(state.copyWith(playAs: playAs));
  Future<void> setTimeControl({int? minutes, required int increment}) =>
      _commit(state.copyWith(
        timeControlMinutes: () => minutes,
        timeControlIncrement: increment,
      ));
  Future<void> setCommentatorBadges(bool v) =>
      _commit(state.copyWith(commentatorBadges: v));
  Future<void> setPlayerName(String name) =>
      _commit(state.copyWith(playerName: name.trim()));
  Future<void> setPlayerAvatarPath(String? path) =>
      _commit(state.copyWith(playerAvatarPath: () => path));

  Future<void> markLessonComplete(String id) => _commit(state.copyWith(
        lessonsCompleted: {...state.lessonsCompleted, id},
      ));

  /// "Reset progress" — wipes everything back to defaults.
  Future<void> reset() async {
    await _repo.clear();
    state = const Prefs();
  }
}
