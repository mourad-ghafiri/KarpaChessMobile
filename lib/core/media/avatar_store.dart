import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../io/stored_files.dart';

/// Owns the on-disk copy of the user's profile picture: picked images are
/// copied into app support storage (picker caches are transient) and old
/// copies are cleaned up on replace/remove.
abstract interface class AvatarStore {
  /// Copies [sourcePath] into app storage and returns the stored path.
  Future<String> store(String sourcePath);

  /// Deletes any stored avatar files.
  Future<void> remove();

  /// The current path of the avatar once stored at [storedPath]: unchanged
  /// when it still exists, re-found by name after the app's container moved
  /// (iOS does that on update), or null when the file is gone.
  Future<String?> relocate(String? storedPath);
}

final avatarStoreProvider = Provider<AvatarStore>((ref) => FileAvatarStore());

class FileAvatarStore implements AvatarStore {
  static const _prefix = 'player_avatar_';

  Future<Directory> get _dir => getApplicationSupportDirectory();

  @override
  Future<String> store(String sourcePath) async {
    final dir = await _dir;
    await _deleteExisting(dir);
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot >= 0 ? sourcePath.substring(dot) : '';
    final target = File(
      '${dir.path}/$_prefix${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  @override
  Future<void> remove() async => _deleteExisting(await _dir);

  @override
  Future<String?> relocate(String? storedPath) async =>
      relocateStoredFile(storedPath, await _dir);

  Future<void> _deleteExisting(Directory dir) async {
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith(_prefix)) {
        try {
          await entity.delete();
        } catch (_) {
          // Best effort — an undeletable stale file is harmless.
        }
      }
    }
  }
}
