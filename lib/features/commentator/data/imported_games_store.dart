import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/io/atomic_write.dart';
import '../domain/imported_game.dart';

/// Persistence seam for the reader's own games — a file implementation for the
/// app, an in-memory fake for tests (so tests never touch path_provider).
///
/// The whole list is written at once. It holds tens of games, not thousands,
/// and a single write can never leave the library half-updated.
abstract class ImportedGamesStore {
  /// The saved games, newest first; empty when there are none or the file is
  /// unreadable.
  Future<List<ImportedGame>> load();

  Future<void> save(List<ImportedGame> games);
}

/// One JSON file in the documents directory, alongside the studio's session
/// and the practice game.
///
/// Every path swallows its errors: a library must never crash the Studio
/// because the disk misbehaved. A failed read simply means "no imports yet".
class FileImportedGamesStore implements ImportedGamesStore {
  static const _fileName = 'studio_library.json';

  Future<Directory>? _dir;

  Future<Directory> _documentsDir() =>
      _dir ??= getApplicationDocumentsDirectory();

  Future<File> _libraryFile() async =>
      File('${(await _documentsDir()).path}/$_fileName');

  @override
  Future<List<ImportedGame>> load() async {
    try {
      final file = await _libraryFile();
      if (!await file.exists()) return const [];
      final decoded = json.decode(await file.readAsString());
      if (decoded is! List) return const [];
      final games = <ImportedGame>[];
      for (final entry in decoded) {
        if (entry is! Map<String, Object?>) continue;
        try {
          games.add(ImportedGame.fromJson(entry));
        } on Object {
          // One unreadable game costs that game, nothing else. This parse
          // used to sit inside the outer catch, so a single wrong-typed
          // field discarded every import the reader had.
          continue;
        }
      }
      return games;
    } catch (_) {
      return const []; // The file itself is unreadable — start empty.
    }
  }

  @override
  Future<void> save(List<ImportedGame> games) async {
    try {
      final file = await _libraryFile();
      await writeStringAtomically(
        file,
        json.encode([for (final game in games) game.toJson()]),
      );
    } catch (_) {
      // Persistence is best-effort; never crash the Studio over disk issues.
    }
  }
}

/// The app-wide store; overridden with a fake in tests.
final importedGamesStoreProvider =
    Provider<ImportedGamesStore>((ref) => FileImportedGamesStore());
