import 'dart:convert';
import 'dart:io';

import 'corpus.dart';

/// The packs, in the order the Puzzles tab shows them — roughly easiest first,
/// so a reader scanning the grid meets the simple ideas before the subtle ones.
///
/// Nothing here gates anything. Every pack is open to every reader: the app
/// serves players of all strengths, who arrive knowing what they want to work
/// on. This list is the only place a pack's existence and icon are decided;
/// the puzzles themselves are found on disk.
const packOrder = <String, String>{
  'mate-in-one': '♛',
  'fork': '♞',
  'back-rank-mate': '♜',
  'pin': '♝',
  'skewer': '⚔',
  'mate-in-two': '♚',
  'discovery': '🎯',
  'trapped': '🕸',
  'promotion': '⇧',
  'remove-guard': '🛡',
  'deflection': '↗',
  'decoy': '🪤',
  'smothered': '♘',
  'pawn-ending': '♟',
  'rook-ending': '♖',
  'overload': '⚖',
  'zwischenzug': '⏸',
  'king-hunt': '👑',
  'zugzwang': '🔒',
  'defence': '🛟',
};

/// Builds `puzzles/packs.json` from whatever pack files are on disk.
///
/// Authors write puzzle files and never touch a manifest; this is the central
/// step that picks them up. Packs that are planned but unwritten are reported
/// as pending, not as an error — authoring proceeds one pack at a time.
class PackManifestBuilder {
  PackManifestBuilder(this.corpus);

  final Corpus corpus;

  String get path => '${corpus.root}/puzzles/packs.json';

  /// The manifest text, plus the ids of packs that have no files yet.
  ({String text, List<String> pending}) build() {
    final puzzles = corpus.puzzles();
    final packs = <Map<String, Object?>>[];
    final pending = <String>[];

    for (final entry in packOrder.entries) {
      final files = puzzles.values
          .where((p) => p.isTrainer && p.pack == entry.key)
          .map((p) => '${p.fileId}.json')
          .toList()
        ..sort();
      if (files.isEmpty) {
        pending.add(entry.key);
        continue;
      }
      packs.add({'id': entry.key, 'icon': entry.value, 'puzzles': files});
    }

    final manifest = {'version': 1, 'packs': packs};
    return (
      text: '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      pending: pending,
    );
  }

  void write(String text) => File(path).writeAsStringSync(text);

  String read() => File(path).readAsStringSync();
}
