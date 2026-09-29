import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prefs.dart';
import '../domain/prefs_repository.dart';

/// Stores the whole [Prefs] blob as one JSON string.
class SharedPrefsRepository implements PrefsRepository {
  SharedPrefsRepository({SharedPreferencesAsync? store})
      : _store = store ?? SharedPreferencesAsync();

  /// v2: the Nightboard redesign reshaped the model (new board theme ids);
  /// no migration from v1 by design.
  static const _key = 'karpachess.v2';

  final SharedPreferencesAsync _store;

  /// Where an unreadable blob is set aside before the app starts over, so
  /// the next [save] cannot destroy the only copy.
  static const unreadableKey = '$_key.unreadable';

  /// Never throws: prefs are read before the first frame, and a throw here
  /// would leave the app unable to open. Anything unreadable — bad JSON, a
  /// non-object, a storage error — reads as "no prefs yet".
  @override
  Future<Prefs?> load() async {
    String? raw;
    try {
      raw = await _store.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return Prefs.fromJson(decoded);
    } on Object {
      // Falls through to set the blob aside.
    }
    if (raw != null) {
      try {
        await _store.setString(unreadableKey, raw);
      } on Object {
        // Best effort: the app still opens on defaults.
      }
    }
    return null;
  }

  @override
  Future<void> save(Prefs prefs) =>
      _store.setString(_key, jsonEncode(prefs.toJson()));

  /// "Reset progress" wipes everything, the set-aside copy included.
  @override
  Future<void> clear() async {
    await _store.remove(_key);
    await _store.remove(unreadableKey);
  }
}
