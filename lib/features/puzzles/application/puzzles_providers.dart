import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/application/content_providers.dart';
import '../../../content/domain/models.dart';
import '../../../progression/application/progression_controller.dart';

/// Every trainer puzzle, in pack order, loaded once.
///
/// The rated stream and the daily puzzle both need the whole corpus, and at
/// a few hundred small files that is one parallel load rather than something
/// worth paging.
final trainerPuzzlesProvider = FutureProvider<List<Puzzle>>((ref) async {
  final manifest = await ref.watch(puzzlePackManifestProvider.future);
  final repo = ref.watch(contentRepositoryProvider);
  final byPack = await Future.wait(
    manifest.packs.map(repo.puzzlesForPack),
  );
  return [for (final packPuzzles in byPack) ...packPuzzles];
});

/// How many puzzles of each pack the reader has solved, keyed by pack id.
/// A failed puzzle does not count — its row is still work to do.
final packProgressProvider = FutureProvider<Map<String, int>>((ref) async {
  final manifest = await ref.watch(puzzlePackManifestProvider.future);
  final results = ref.watch(
    progressionControllerProvider.select((p) => p.puzzleResults),
  );
  return {
    for (final pack in manifest.packs)
      pack.id: pack.puzzleFiles
          .where((f) => results[puzzleIdOf(f)]?.isSolved ?? false)
          .length,
  };
});

/// One pack's puzzles in authored order, filtered from the corpus already
/// in memory — no second asset load.
final packPuzzlesProvider =
    FutureProvider.family<List<Puzzle>, String>((ref, packId) async {
  final manifest = await ref.watch(puzzlePackManifestProvider.future);
  final corpus = await ref.watch(trainerPuzzlesProvider.future);
  final pack = manifest.packs.where((p) => p.id == packId).firstOrNull;
  if (pack == null) return const [];
  final byId = {for (final puzzle in corpus) puzzle.id: puzzle};
  return [
    for (final file in pack.puzzleFiles) ?byId[puzzleIdOf(file)],
  ];
});

/// Puzzle ids are their filename without the extension — the authoring
/// contract requires it, and the pack manifest lists files.
String puzzleIdOf(String file) =>
    file.endsWith('.json') ? file.substring(0, file.length - 5) : file;
