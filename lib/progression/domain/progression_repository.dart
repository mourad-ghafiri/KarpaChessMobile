import 'progression.dart';

/// Persistence boundary for progression (XP / streak / completed nodes).
abstract interface class ProgressionRepository {
  Future<ProgressionState?> load();
  Future<void> save(ProgressionState state);
  Future<void> clear();
}
