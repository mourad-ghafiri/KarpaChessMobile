import 'models.dart';

/// Read-side of the learning content: manifests plus lesson/puzzle bodies.
///
/// English is the canonical corpus. Translated lesson and puzzle files (today
/// Arabic, Indonesian, French, Spanish, Chinese, Russian, Japanese, Hindi,
/// Turkish, Italian and Portuguese) are
/// resolved by the implementation
/// from the reader's language, file by file, with English as the fallback;
/// callers never pass a language.
abstract interface class ContentRepository {
  Future<LessonManifest> lessonManifest();

  /// The Studio's study library — player names and moves, language-neutral.
  Future<GameLibrary> gameLibrary();

  Future<PuzzleManifest> puzzleManifest();

  /// The trainer's pack manifest (`puzzles/packs.json`), separate from the
  /// theme manifest the academy uses.
  Future<PuzzlePackManifest> puzzlePackManifest();

  /// Loads one lesson file.
  Future<Lesson> lesson(String file);

  /// Loads one puzzle file.
  Future<Puzzle> puzzle(String file);

  /// Loads all puzzles of [pack] in parallel, dropping unreadable files.
  Future<List<Puzzle>> puzzlesForPack(PuzzlePack pack);
}
