import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/io/atomic_write.dart';
import 'package:karpachess/core/io/stored_files.dart';
import 'package:karpachess/prefs/data/shared_prefs_repository.dart';
import 'package:karpachess/progression/data/shared_prefs_progression_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory stand-in for the platform store: just the three calls the
/// repositories make.
class _MemoryStore implements SharedPreferencesAsync {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('karpachess_storage_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('writeStringAtomically', () {
    test('replaces the file whole and leaves no temp file behind', () async {
      final file = File('${dir.path}/library.json');
      await file.writeAsString('[old]');

      await writeStringAtomically(file, '[new]');

      expect(await file.readAsString(), '[new]');
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });

    test('creates the file when there is none yet', () async {
      final file = File('${dir.path}/first.json');
      await writeStringAtomically(file, '{}');
      expect(await file.readAsString(), '{}');
    });
  });

  group('relocateStoredFile', () {
    test('keeps a path that still exists', () async {
      final photo = File('${dir.path}/player_avatar_1.jpg')
        ..writeAsStringSync('jpg');
      expect(await relocateStoredFile(photo.path, dir), photo.path);
    });

    test('re-finds the file by name after the container moved', () async {
      final photo = File('${dir.path}/player_avatar_1.jpg')
        ..writeAsStringSync('jpg');
      const stale = '/var/mobile/Containers/Data/Application/'
          'OLD-UUID/Library/Application Support/player_avatar_1.jpg';
      expect(await relocateStoredFile(stale, dir), photo.path);
    });

    test('a file that is truly gone reads as null', () async {
      expect(
        await relocateStoredFile('/nowhere/player_avatar_9.jpg', dir),
        isNull,
      );
    });

    test('no stored path stays null', () async {
      expect(await relocateStoredFile(null, dir), isNull);
      expect(await relocateStoredFile('', dir), isNull);
    });
  });

  group('repositories never lose an unreadable blob', () {
    test('progression: set aside under its own key, load reads as fresh',
        () async {
      final store = _MemoryStore()
        ..values['karpachess.progression.v1'] = '[1, 2, 3]';
      final repo = SharedPrefsProgressionRepository(store: store);

      expect(await repo.load(), isNull);
      expect(
        store.values[SharedPrefsProgressionRepository.unreadableKey],
        '[1, 2, 3]',
      );
    });

    test('progression: broken JSON is set aside too', () async {
      final store = _MemoryStore()
        ..values['karpachess.progression.v1'] = '{"xp": 12';
      final repo = SharedPrefsProgressionRepository(store: store);

      expect(await repo.load(), isNull);
      expect(
        store.values[SharedPrefsProgressionRepository.unreadableKey],
        '{"xp": 12',
      );
    });

    test('prefs: a non-object blob is set aside, load reads as none',
        () async {
      final store = _MemoryStore()..values['karpachess.v2'] = '"just text"';
      final repo = SharedPrefsRepository(store: store);

      expect(await repo.load(), isNull);
      expect(store.values[SharedPrefsRepository.unreadableKey], '"just text"');
    });

    test('a wrong-typed field no longer costs the whole record', () async {
      final store = _MemoryStore()
        ..values['karpachess.progression.v1'] =
            '{"xp": 1500, "streakDays": "many"}';
      final repo = SharedPrefsProgressionRepository(store: store);

      final state = await repo.load();
      expect(state, isNotNull);
      expect(state!.xp, 1500);
      expect(state.streakDays, 0);
      expect(
        store.values.containsKey(SharedPrefsProgressionRepository.unreadableKey),
        isFalse,
      );
    });

    test('reset clears the set-aside copy as well', () async {
      final store = _MemoryStore()
        ..values['karpachess.progression.v1'] = 'garbage';
      final repo = SharedPrefsProgressionRepository(store: store);
      await repo.load();

      await repo.clear();

      expect(store.values, isEmpty);
    });
  });
}
