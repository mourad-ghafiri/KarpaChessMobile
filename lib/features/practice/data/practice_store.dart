import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/io/atomic_write.dart';
import '../domain/practice_session.dart';

/// Persistence seam for the game in progress — a file implementation for the
/// app, an in-memory fake for tests (so tests never touch path_provider).
abstract class PracticeStore {
  /// The saved game, or null when there is none (or it is unreadable).
  Future<PracticeSession?> load();
  Future<void> save(PracticeSession session);
  Future<void> clear();
}

/// One JSON file in the documents directory, alongside the studio's session.
///
/// Every path swallows its errors: a game must never be lost — or crash —
/// because the disk misbehaved. A failed read simply means "no saved game".
class FilePracticeStore implements PracticeStore {
  static const _fileName = 'practice_session.json';

  Future<Directory>? _dir;

  Future<Directory> _documentsDir() =>
      _dir ??= getApplicationDocumentsDirectory();

  Future<File> _sessionFile() async =>
      File('${(await _documentsDir()).path}/$_fileName');

  @override
  Future<PracticeSession?> load() async {
    try {
      final file = await _sessionFile();
      if (!await file.exists()) return null;
      final decoded = json.decode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final session = PracticeSession.fromJson(decoded);
      // A game with no moves is a game not worth restoring: the reader is
      // better served by the setup screen than by an untouched board.
      return session.uciMoves.isEmpty ? null : session;
    } catch (_) {
      return null; // Corrupt session — start fresh.
    }
  }

  @override
  Future<void> save(PracticeSession session) async {
    try {
      final file = await _sessionFile();
      await writeStringAtomically(file, json.encode(session.toJson()));
    } catch (_) {
      // Persistence is best-effort; never crash a game over disk issues.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _sessionFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// The app-wide store; overridden with a fake in tests.
final practiceStoreProvider =
    Provider<PracticeStore>((ref) => FilePracticeStore());
