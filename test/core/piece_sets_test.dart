import 'dart:io';

import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/board/presentation/piece_sets.dart';
import 'package:karpachess/prefs/domain/prefs.dart';

void main() {
  // chessground's own layout: the 1x file, and a variant per pixel ratio
  // beside it. A missing variant would not fail — Flutter falls back to
  // another resolution — so a board would go soft on one class of phone and
  // nobody would notice.
  const variants = ['', '2.0x/', '3.0x/', '4.0x/'];

  group('every piece set', () {
    for (final option in PieceSetId.values) {
      test('${option.name} draws all twelve pieces at every resolution', () {
        expect(option.assets.keys.toSet(), PieceKind.values.toSet());
        for (final kind in PieceKind.values) {
          final path = option.assets[kind]!.assetName;
          expect(path, option.assetPath(kind));
          final dir = path.substring(0, path.lastIndexOf('/') + 1);
          final file = path.substring(dir.length);
          for (final variant in variants) {
            expect(File('$dir$variant$file').existsSync(), isTrue,
                reason: '$dir$variant$file is missing — '
                    'run python3 tool/gen_pieces.py');
          }
        }
      });

      test('${option.name} is bundled', () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('- assets/pieces/${option.name}/'));
      });
    }
  });

  test('the Dart sets are the generator sets, in the same order', () {
    // tool/gen_pieces.py writes the files and fixes the Settings order; the
    // enum is what the app offers. A set drawn but never offered, or offered
    // but never drawn, is the drift this pins.
    final source = File('tool/gen_pieces.py').readAsStringSync();
    final block = RegExp(r'^SETS = \{(.*?)^\}', multiLine: true, dotAll: true)
        .firstMatch(source);
    expect(block, isNotNull, reason: 'gen_pieces.py has no SETS table');
    final ids = RegExp(r'^\s*"(\w+)":', multiLine: true)
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1))
        .toList();
    expect(ids, PieceSetId.values.map((s) => s.name).toList());
  });

  test('the default is the first set, and unknown ids fall back to it', () {
    expect(const Prefs().pieceSet, PieceSetId.values.first.name);
    expect(PieceSetId.fromId('staunty'), PieceSetId.classic);
    expect(PieceSetId.fromId(''), PieceSetId.classic);
    for (final option in PieceSetId.values) {
      expect(PieceSetId.fromId(option.name), option);
    }
  });

  test('the choice survives a prefs round trip', () {
    final prefs = const Prefs().copyWith(pieceSet: 'modern');
    expect(Prefs.fromJson(prefs.toJson()).pieceSet, 'modern');
    // A blob from before piece sets existed opens on the default.
    expect(Prefs.fromJson(const {}).pieceSet, 'classic');
  });
}
