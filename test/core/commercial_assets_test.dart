import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KarpaChess is sold, so everything it bundles must be cleared for
/// commercial use (docs/RELEASE.md, "Selling under the GPL").
///
/// The risk is chessground. The hosted package declares 40 piece sets and
/// its board textures as assets. Flutter bundles every asset a dependency
/// declares, used or not, and several of those sets are licensed for
/// non-commercial use only. The app therefore vendors chessground WITHOUT its
/// assets (packages/chessground/NOTICE.md) and draws its own pieces and
/// boards. These tests fail on each way that could quietly come undone.
void main() {
  test('chessground resolves from the vendored copy, not pub.dev', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^  chessground:\s*\n\s+path: packages/chessground\s*$',
              multiLine: true)
          .hasMatch(pubspec),
      isTrue,
      reason: 'pubspec.yaml must depend on chessground by path',
    );

    final lock = File('pubspec.lock').readAsStringSync();
    final entry = RegExp(r'^  chessground:\n((?:    .*\n)+)', multiLine: true)
        .firstMatch(lock);
    expect(entry, isNotNull, reason: 'pubspec.lock has no chessground entry');
    expect(entry!.group(1), contains('source: path'));
    expect(entry.group(1), contains('path: "packages/chessground"'));
  });

  test('the vendored chessground declares no assets', () {
    final pubspec =
        File('packages/chessground/pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^\s*assets:', multiLine: true).hasMatch(pubspec), isFalse);
    expect(Directory('packages/chessground/assets').existsSync(), isFalse);
  });

  test('the app never reaches for a chessground asset', () {
    // PieceSet.* are chessground's piece sets. The ChessboardColorScheme
    // presets draw its board textures. `package: 'chessground'` is any other
    // asset it ships. Every board takes PieceSetId pieces and a
    // boardColorScheme() instead.
    final banned = {
      'PieceSet.': RegExp(r'\bPieceSet\.'),
      'ChessboardColorScheme.<preset>': RegExp(r'\bChessboardColorScheme\.\w'),
      "package: 'chessground'": RegExp(r'''package:\s*['"]chessground['"]'''),
    };
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final MapEntry(key: name, value: pattern) in banned.entries) {
        if (pattern.hasMatch(source)) offenders.add('${file.path}: $name');
      }
    }
    expect(offenders, isEmpty);
  });
}
