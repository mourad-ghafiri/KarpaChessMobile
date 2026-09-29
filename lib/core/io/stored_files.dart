import 'dart:io';

/// Re-finds a file the app copied into its own storage, given the path it
/// stored at the time.
///
/// Stored photo paths are absolute, and iOS moves an app's container — a new
/// UUID in the path — when the app is updated or restored. The file is still
/// there, under the same name in the same app-owned directory; only the
/// prefix went stale. So: a path that still exists is kept; otherwise the
/// same file name is looked up in [currentDir]; otherwise the file is truly
/// gone and the answer is null, so callers fall back to their placeholder
/// instead of drawing a broken image.
Future<String?> relocateStoredFile(String? stored, Directory currentDir) async {
  if (stored == null || stored.isEmpty) return null;
  try {
    if (await File(stored).exists()) return stored;
    final name = stored.split(RegExp(r'[/\\]')).last;
    if (name.isEmpty) return null;
    final candidate = '${currentDir.path}/$name';
    if (await File(candidate).exists()) return candidate;
  } on Object {
    // Unreadable storage reads as "gone": the placeholder is always safe.
  }
  return null;
}
