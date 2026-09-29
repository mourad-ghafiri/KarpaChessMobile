import 'dart:convert';
import 'dart:io';

import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/features/academy/domain/skill_map.dart';

/// A position's identity for "is this the same board": placement, side to
/// move, castling rights and en passant — the FEN without its move counters,
/// which differ between two authors writing down one board.
String boardKey(String fen) =>
    fen.trim().split(RegExp(r'\s+')).take(4).join(' ');

/// Reads the bundled corpus off disk the way the app reads it out of the
/// bundle — through the app's OWN models.
///
/// That is the whole point of the gate living here rather than in another
/// language: a puzzle that loads through [Puzzle.fromJson] is a puzzle the app
/// can load, because it is the same code. A parallel parser can only ever
/// prove something about itself.
class Corpus {
  Corpus({this.root = 'assets/data'});

  final String root;

  Directory get _puzzleDir => Directory('$root/puzzles/en');

  /// Every puzzle file in the English corpus, keyed by id, in filename order.
  ///
  /// Throws [FormatException] naming the file when one will not parse, because
  /// a corpus you cannot read is not a corpus with a finding in it — it is a
  /// broken checkout.
  Map<String, PuzzleFile> puzzles() {
    final out = <String, PuzzleFile>{};
    for (final file in _jsonFiles(_puzzleDir)) {
      final name = _basename(file);
      final id = name.replaceAll('.json', '');
      final Map<String, dynamic> raw;
      try {
        raw = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      } on Object catch (e) {
        throw FormatException('$name is not readable JSON: $e');
      }
      out[id] = PuzzleFile(
        fileId: id,
        raw: raw,
        puzzle: Puzzle.fromJson(raw),
      );
    }
    return out;
  }

  /// Lesson files for [lang], keyed by filename.
  Map<String, Lesson> lessons(String lang) {
    final out = <String, Lesson>{};
    final dir = Directory('$root/lessons/$lang');
    if (!dir.existsSync()) return out;
    for (final file in _jsonFiles(dir)) {
      final name = _basename(file);
      if (name == 'index.json') continue;
      final raw = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      out[name] = Lesson.fromJson(raw);
    }
    return out;
  }

  LessonManifest lessonManifest() =>
      LessonManifest.fromJson(_readJson('$root/lessons/index.json'));

  PuzzleManifest puzzleManifest() =>
      PuzzleManifest.fromJson(_readJson('$root/puzzles/index.json'));

  PuzzlePackManifest packManifest() =>
      PuzzlePackManifest.fromJson(_readJson('$root/puzzles/packs.json'));

  /// The Studio's study library.
  GameLibrary gameLibrary() =>
      GameLibrary.fromJson(_readJson('$root/games/games.json'));

  /// The languages with a translated content directory. English is the
  /// canonical corpus; these mirror it file for file (`tool/translations.dart`).
  static const translatedLanguages = {
    'ar',
    'id',
    'fr',
    'es',
    'zh',
    'ru',
    'ja',
    'hi',
    'tr',
    'it',
    'pt',
  };

  /// Every directory under `lessons/` and `puzzles/` other than `en/` and the
  /// translated languages, as `lessons/de`.
  ///
  /// pubspec bundles only those, so anything else there is a leftover: never
  /// read by the app, never shipped, and worth a look — but no reason to check
  /// it as if it were content.
  List<String> strayDirectories() => [
        for (final area in ['lessons', 'puzzles'])
          if (Directory('$root/$area').existsSync())
            for (final dir
                in Directory('$root/$area').listSync().whereType<Directory>())
              if (_basename(dir) != 'en' &&
                  !translatedLanguages.contains(_basename(dir)))
                '$area/${_basename(dir)}',
      ]..sort();

  /// The order a reader meets the lessons: `artOrder` zipped with the
  /// manifest, exactly as `SkillMap.build` does it. Computed, never typed.
  List<String> readingOrder() {
    final categories = {
      for (final c in lessonManifest().categories) c.id: c,
    };
    return [
      for (final art in artOrder) ...?categories[art]?.lessonFiles,
    ];
  }

  Map<String, dynamic> _readJson(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

  static List<File> _jsonFiles(Directory dir) => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// From the path, not the URI: a [Directory]'s URI ends in a separator, so
  /// `uri.pathSegments.last` is the empty string for every directory.
  static String _basename(FileSystemEntity e) =>
      e.path.split(Platform.pathSeparator).last;
}

/// One puzzle file: the parsed model, plus the raw map and the filename the
/// structural rules need (the model deliberately drops unknown keys, and
/// "exactly these eight keys" is a rule about the FILE).
class PuzzleFile {
  const PuzzleFile({
    required this.fileId,
    required this.raw,
    required this.puzzle,
  });

  final String fileId;
  final Map<String, dynamic> raw;
  final Puzzle puzzle;

  /// A trainer puzzle iff it carries a rating; the teaching puzzles do not.
  bool get isTrainer => puzzle.rating != null;

  /// `decoy-07` → `decoy`; null when the name is not `<pack>-NN`.
  String? get pack {
    final match = RegExp(r'^(.*)-\d+$').firstMatch(fileId);
    return match?.group(1);
  }
}
