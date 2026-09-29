import 'dart:io';

/// Replaces [target]'s contents with [contents] so that a reader always sees
/// either the old file or the new one — never a truncated mix.
///
/// `File.writeAsString` truncates the target first and then writes. When the
/// app is killed mid-write (or the disk fills), what is left on disk is a
/// fragment, the next load cannot parse it, and the store "starts fresh":
/// the reader's own imported games, gone. Writing a sibling temp file,
/// flushing it, and renaming it over the target makes the swap atomic —
/// rename is atomic on every platform the app ships on when both paths share
/// a directory.
Future<void> writeStringAtomically(File target, String contents) async {
  final temp = File('${target.path}.tmp');
  await temp.writeAsString(contents, flush: true);
  await temp.rename(target.path);
}
