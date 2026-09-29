import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progression.dart';
import '../domain/progression_repository.dart';

class SharedPrefsProgressionRepository implements ProgressionRepository {
  SharedPrefsProgressionRepository({SharedPreferencesAsync? store})
      : _store = store ?? SharedPreferencesAsync();

  static const _key = 'karpachess.progression.v1';

  final SharedPreferencesAsync _store;

  /// Where an unreadable record is set aside before the app starts over.
  /// The learner's XP, rating and streak live in this one blob: without the
  /// copy, the first award after a failed read would overwrite the only one.
  static const unreadableKey = '$_key.unreadable';

  /// Never throws: progression is restored before the first frame, and a
  /// throw here would leave the app unable to open. Anything unreadable —
  /// bad JSON, a non-object, a storage error — reads as "no record yet",
  /// after the raw text is preserved under [unreadableKey].
  @override
  Future<ProgressionState?> load() async {
    String? raw;
    try {
      raw = await _store.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return ProgressionState.fromJson(decoded);
      }
    } on Object {
      // Falls through to set the record aside.
    }
    if (raw != null) {
      try {
        await _store.setString(unreadableKey, raw);
      } on Object {
        // Best effort: the app still opens on a fresh record.
      }
    }
    return null;
  }

  @override
  Future<void> save(ProgressionState state) =>
      _store.setString(_key, jsonEncode(state.toJson()));

  /// "Reset progress" wipes everything, the set-aside copy included.
  @override
  Future<void> clear() async {
    await _store.remove(_key);
    await _store.remove(unreadableKey);
  }
}
