import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/content_repository.dart';
import '../domain/models.dart';

/// [ContentRepository] backed by the bundled assets under `assets/data/`.
///
/// Manifests are cached after the first successful load. Lesson and puzzle
/// bodies live under `lessons/<lang>/` and `puzzles/<lang>/`. English (`en/`)
/// is the canonical corpus; a translated directory (today `ar/`, `id/`, `fr/`,
/// `es/`, `zh/`, `ru/`, `ja/`, `hi/`, `tr/`, `it/` and `pt/`) carries the
/// same files with only the prose changed, and any file it lacks falls back to
/// English, so a partly translated corpus still loads every lesson.
class AssetContentRepository implements ContentRepository {
  AssetContentRepository({AssetBundle? bundle, this.language = 'en'})
      : _bundle = bundle ?? rootBundle;

  static const _basePath = 'assets/data';

  /// Languages that ship translated lesson and puzzle files.
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

  final AssetBundle _bundle;

  /// The reader's UI language; content resolves to it when translated.
  final String language;

  LessonManifest? _lessonManifest;
  PuzzleManifest? _puzzleManifest;
  PuzzlePackManifest? _puzzlePackManifest;
  GameLibrary? _gameLibrary;

  @override
  Future<LessonManifest> lessonManifest() async {
    return _lessonManifest ??= LessonManifest.fromJson(
      await _loadJson('$_basePath/lessons/index.json'),
    );
  }

  @override
  Future<PuzzleManifest> puzzleManifest() async {
    return _puzzleManifest ??= PuzzleManifest.fromJson(
      await _loadJson('$_basePath/puzzles/index.json'),
    );
  }

  @override
  Future<PuzzlePackManifest> puzzlePackManifest() async {
    return _puzzlePackManifest ??= PuzzlePackManifest.fromJson(
      await _loadJson('$_basePath/puzzles/packs.json'),
    );
  }

  @override
  Future<GameLibrary> gameLibrary() async {
    return _gameLibrary ??= GameLibrary.fromJson(
      await _loadJson('$_basePath/games/games.json'),
    );
  }

  @override
  Future<Lesson> lesson(String file) async {
    return Lesson.fromJson(await _loadLocalized('lessons', file));
  }

  @override
  Future<Puzzle> puzzle(String file) async {
    return Puzzle.fromJson(await _loadLocalized('puzzles', file));
  }

  @override
  Future<List<Puzzle>> puzzlesForPack(PuzzlePack pack) async {
    // Loaded in parallel; an unreadable file is dropped rather than failing
    // the whole pack.
    final results = await Future.wait(
      pack.puzzleFiles.map((f) async {
        try {
          return await puzzle(f);
        } on Object {
          return null;
        }
      }),
    );
    return results.whereType<Puzzle>().toList();
  }

  /// The translated file when this language has one, English otherwise.
  Future<Map<String, dynamic>> _loadLocalized(String area, String file) async {
    if (language != 'en' && translatedLanguages.contains(language)) {
      try {
        return await _loadJson('$_basePath/$area/$language/$file');
      } on Object {
        // Not translated yet: fall through to the English original.
      }
    }
    return _loadJson('$_basePath/$area/en/$file');
  }

  Future<Map<String, dynamic>> _loadJson(String path) async {
    final raw = await _bundle.loadString(path);
    return json.decode(raw) as Map<String, dynamic>;
  }
}
