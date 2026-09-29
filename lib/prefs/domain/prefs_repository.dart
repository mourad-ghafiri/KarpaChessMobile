import 'prefs.dart';

/// Persistence boundary for user preferences.
abstract interface class PrefsRepository {
  /// Returns the persisted prefs, or null when nothing was ever saved
  /// (first run) or the stored blob is unreadable.
  Future<Prefs?> load();
  Future<void> save(Prefs prefs);
  Future<void> clear();
}
