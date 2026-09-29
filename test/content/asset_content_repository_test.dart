import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/data/asset_content_repository.dart';

/// In-memory [AssetBundle] that also counts loads per key.
class FakeAssetBundle extends AssetBundle {
  FakeAssetBundle(this.assets);

  final Map<String, String> assets;
  final Map<String, int> loadCounts = {};

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadCounts[key] = (loadCounts[key] ?? 0) + 1;
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return value;
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async {
    return parser(await loadString(key));
  }
}

const _lessonsIndex = '''
{
  "version": 1,
  "categories": [
    {"id": "basics", "icon": "P", "lessons": ["l1.json", "l2.json"]}
  ]
}
''';

const _puzzlesIndex = '''
{
  "version": 1,
  "themes": [
    {
      "id": "mate-in-1",
      "icon": "Q",
      "difficulty": "beginner",
      "puzzles": ["p1.json", "p2.json"]
    }
  ]
}
''';

const _packsIndex = '''
{
  "version": 1,
  "packs": [
    {"id": "first-steps", "icon": "P", "puzzles": ["p1.json", "p2.json"]}
  ]
}
''';

String _lessonJson(String id, String title) => '''
{
  "id": "$id",
  "title": "$title",
  "summary": "s",
  "difficulty": "beginner",
  "steps": [
    {"type": "teach", "fen": "8/8/8/8/8/8/4P3/4K3 w - - 0 1", "text": "t"}
  ]
}
''';

String _puzzleJson(String id, String title) => '''
{
  "id": "$id",
  "fen": "7k/8/8/8/8/8/8/K6R w - - 0 1",
  "solution": ["Rh1#"],
  "title": "$title"
}
''';

void main() {
  group('AssetContentRepository', () {
    test('loads and caches the lesson manifest', () async {
      final bundle = FakeAssetBundle({
        'assets/data/lessons/index.json': _lessonsIndex,
      });
      final repo = AssetContentRepository(bundle: bundle);

      final first = await repo.lessonManifest();
      final second = await repo.lessonManifest();

      expect(first.categories.single.id, 'basics');
      expect(first.categories.single.lessonFiles, ['l1.json', 'l2.json']);
      expect(identical(first, second), isTrue);
      expect(bundle.loadCounts['assets/data/lessons/index.json'], 1);
    });

    test('loads and caches the puzzle manifest', () async {
      final bundle = FakeAssetBundle({
        'assets/data/puzzles/index.json': _puzzlesIndex,
      });
      final repo = AssetContentRepository(bundle: bundle);

      final first = await repo.puzzleManifest();
      final second = await repo.puzzleManifest();

      expect(first.themes.single.id, 'mate-in-1');
      expect(first.themes.single.difficulty, 'beginner');
      expect(identical(first, second), isTrue);
      expect(bundle.loadCounts['assets/data/puzzles/index.json'], 1);
    });

    test('loads a lesson from the English corpus', () async {
      final bundle = FakeAssetBundle({
        'assets/data/lessons/en/l1.json': _lessonJson('l1', 'Hello'),
      });
      final repo = AssetContentRepository(bundle: bundle);

      final lesson = await repo.lesson('l1.json');

      expect(lesson.title, 'Hello');
    });

    test('loads a puzzle from the English corpus', () async {
      final bundle = FakeAssetBundle({
        'assets/data/puzzles/en/p1.json': _puzzleJson('p1', 'Back Rank'),
      });
      final repo = AssetContentRepository(bundle: bundle);

      final puzzle = await repo.puzzle('p1.json');

      expect(puzzle.title, 'Back Rank');
      expect(puzzle.solution, ['Rh1#']);
    });

    test('throws when the file is missing', () async {
      final bundle = FakeAssetBundle({});
      final repo = AssetContentRepository(bundle: bundle);

      expect(repo.lesson('l1.json'), throwsA(isA<FlutterError>()));
      expect(repo.puzzle('p1.json'), throwsA(isA<FlutterError>()));
    });

    test('throws when the file is corrupt', () async {
      final bundle = FakeAssetBundle({
        'assets/data/puzzles/en/p1.json': '{oops',
      });
      final repo = AssetContentRepository(bundle: bundle);

      expect(repo.puzzle('p1.json'), throwsA(isA<FormatException>()));
    });

    test('puzzlesForPack loads all files, dropping broken ones', () async {
      final bundle = FakeAssetBundle({
        'assets/data/puzzles/packs.json': _packsIndex,
        'assets/data/puzzles/en/p1.json': _puzzleJson('p1', 'One'),
        'assets/data/puzzles/en/p2.json': '{not valid json',
      });
      final repo = AssetContentRepository(bundle: bundle);
      final manifest = await repo.puzzlePackManifest();

      final puzzles = await repo.puzzlesForPack(manifest.packs.single);

      expect(puzzles.map((p) => p.title), ['One']);
    });
  });
}
