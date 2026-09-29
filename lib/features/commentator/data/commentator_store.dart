import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/json/json_read.dart';
import '../../../core/io/atomic_write.dart';
import '../../../core/io/stored_files.dart';

/// Everything needed to restore a commentator session across app restarts:
/// the (re-serialized) PGN including user variations, custom player names and
/// photo paths, and the current node as a child-index path.
class CommentatorSession {
  const CommentatorSession({
    required this.pgn,
    this.whiteName = '',
    this.blackName = '',
    this.whitePhotoPath,
    this.blackPhotoPath,
    this.path = const [],
    this.drawings,
  });

  final String pgn;
  final String whiteName;
  final String blackName;
  final String? whitePhotoPath;
  final String? blackPhotoPath;

  /// Child-index path from the root to the current node.
  final List<int> path;

  /// Per-node drawing shapes, keyed by the node's child-index path joined
  /// with '.' ('' = root). Null means "unspecified": stores preserve the
  /// previously saved drawings so writers that don't know about drawings
  /// (the commentator controller) never wipe them.
  final Map<String, List<Map<String, Object?>>>? drawings;

  CommentatorSession copyWith({Map<String, List<Map<String, Object?>>>? drawings}) =>
      CommentatorSession(
        pgn: pgn,
        whiteName: whiteName,
        blackName: blackName,
        whitePhotoPath: whitePhotoPath,
        blackPhotoPath: blackPhotoPath,
        path: path,
        drawings: drawings ?? this.drawings,
      );

  Map<String, Object?> toJson() => {
        'pgn': pgn,
        'whiteName': whiteName,
        'blackName': blackName,
        'whitePhotoPath': whitePhotoPath,
        'blackPhotoPath': blackPhotoPath,
        'path': path,
        if (drawings != null) 'drawings': drawings,
      };

  factory CommentatorSession.fromJson(Map<String, Object?> json) =>
      CommentatorSession(
        pgn: readString(json['pgn']) ?? '',
        whiteName: readString(json['whiteName']) ?? '',
        blackName: readString(json['blackName']) ?? '',
        whitePhotoPath: readString(json['whitePhotoPath']),
        blackPhotoPath: readString(json['blackPhotoPath']),
        path: readIntList(json['path']),
        drawings: _drawingsFrom(json['drawings']),
      );

  /// Tolerant parse: sessions saved before the drawings feature (or with a
  /// mangled field) load with `drawings: null`.
  static Map<String, List<Map<String, Object?>>>? _drawingsFrom(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final entry in raw.entries)
        '${entry.key}': [
          for (final item in entry.value is List ? entry.value as List : const [])
            if (item is Map) readStringMap(item),
        ],
    };
  }
}

/// Persistence seam for the commentator feature — a file implementation for
/// the app, an in-memory fake for tests (so tests never touch path_provider).
abstract class CommentatorStore {
  Future<CommentatorSession?> load();
  Future<void> save(CommentatorSession session);
  Future<void> clear();

  /// Replaces the persisted per-node drawings on the saved session. A no-op
  /// when no session has been saved yet (drawings without a game make no
  /// sense to restore).
  Future<void> saveDrawings(Map<String, List<Map<String, Object?>>> drawings);

  /// Copies the picked image at [sourcePath] into app-owned storage and
  /// returns the stored path. [side] is 'w' or 'b'.
  Future<String> storePhoto(String side, String sourcePath);
}

/// Stores the session as `commentator_session.json` in the app documents
/// directory; player photos are copied next to it.
class FileCommentatorStore implements CommentatorStore {
  static const _fileName = 'commentator_session.json';

  Future<Directory>? _dir;

  /// Last known drawings, so a session save that leaves `drawings` null
  /// (the commentator controller's) carries them forward instead of wiping.
  Map<String, List<Map<String, Object?>>>? _drawingsCache;

  Future<Directory> _documentsDir() =>
      _dir ??= getApplicationDocumentsDirectory();

  Future<File> _sessionFile() async =>
      File('${(await _documentsDir()).path}/$_fileName');

  @override
  Future<CommentatorSession?> load() async {
    try {
      final file = await _sessionFile();
      if (!await file.exists()) return null;
      final decoded = json.decode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final session = CommentatorSession.fromJson(decoded);
      if (session.pgn.trim().isEmpty) return null;
      _drawingsCache = session.drawings;
      // Photo paths are absolute and go stale when iOS moves the container;
      // re-find them by name so a Studio photo survives an app update.
      final dir = await _documentsDir();
      return CommentatorSession(
        pgn: session.pgn,
        whiteName: session.whiteName,
        blackName: session.blackName,
        whitePhotoPath: await relocateStoredFile(session.whitePhotoPath, dir),
        blackPhotoPath: await relocateStoredFile(session.blackPhotoPath, dir),
        path: session.path,
        drawings: session.drawings,
      );
    } catch (_) {
      return null; // Corrupt session — start fresh.
    }
  }

  @override
  Future<void> save(CommentatorSession session) async {
    try {
      final toWrite = session.drawings == null
          ? session.copyWith(drawings: _drawingsCache)
          : session;
      _drawingsCache = toWrite.drawings;
      final file = await _sessionFile();
      await writeStringAtomically(file, json.encode(toWrite.toJson()));
    } catch (_) {
      // Persistence is best-effort; never crash the studio over disk issues.
    }
  }

  @override
  Future<void> saveDrawings(
      Map<String, List<Map<String, Object?>>> drawings) async {
    try {
      final session = await load();
      _drawingsCache = drawings;
      if (session == null) return;
      await save(session.copyWith(drawings: drawings));
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _drawingsCache = null;
    try {
      final file = await _sessionFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  Future<String> storePhoto(String side, String sourcePath) async {
    final dir = await _documentsDir();
    // Drop previous photos for this side so we don't accumulate files, and so
    // the fresh timestamped name busts Flutter's image cache.
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('commentator_photo_$side')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final target = File(
      '${dir.path}/commentator_photo_${side}_'
      '${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(target.path);
    return target.path;
  }
}

/// The app-wide store; overridden with a fake in tests.
final commentatorStoreProvider =
    Provider<CommentatorStore>((ref) => FileCommentatorStore());
