import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prefs/application/prefs_controller.dart';
import '../data/asset_content_repository.dart';
import '../domain/content_repository.dart';
import '../domain/models.dart';

/// Rebuilt when the UI language changes, so lessons and puzzles re-resolve to
/// the translated files for that language (English where none exists).
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => AssetContentRepository(
    language: ref.watch(prefsControllerProvider.select((p) => p.lang)),
  ),
);

final lessonManifestProvider = FutureProvider<LessonManifest>(
  (ref) => ref.watch(contentRepositoryProvider).lessonManifest(),
);

final puzzleManifestProvider = FutureProvider<PuzzleManifest>(
  (ref) => ref.watch(contentRepositoryProvider).puzzleManifest(),
);

/// The Studio's study library.
final gameLibraryProvider = FutureProvider<GameLibrary>(
  (ref) => ref.watch(contentRepositoryProvider).gameLibrary(),
);

/// The trainer's packs.
final puzzlePackManifestProvider = FutureProvider<PuzzlePackManifest>(
  (ref) => ref.watch(contentRepositoryProvider).puzzlePackManifest(),
);
