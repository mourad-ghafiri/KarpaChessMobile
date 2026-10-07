/// Immutable domain models for the learning content (lessons and puzzles).
///
/// The JSON schemas are two language-agnostic
/// manifests (`lessons/index.json`, `puzzles/index.json`) that reference
/// per-language content files under `lessons/<lang>/` and `puzzles/<lang>/`.
library;

/// A category entry from `lessons/index.json`.
class LessonCategoryRef {
  const LessonCategoryRef({
    required this.id,
    required this.icon,
    required this.lessonFiles,
  });

  factory LessonCategoryRef.fromJson(Map<String, dynamic> json) {
    return LessonCategoryRef(
      id: json['id'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      lessonFiles: _stringList(json['lessons']),
    );
  }

  final String id;
  final String icon;
  final List<String> lessonFiles;
}

/// The parsed `lessons/index.json` manifest.
class LessonManifest {
  const LessonManifest({required this.categories});

  factory LessonManifest.fromJson(Map<String, dynamic> json) {
    return LessonManifest(
      categories: [
        for (final c in json['categories'] as List<dynamic>? ?? const [])
          LessonCategoryRef.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  final List<LessonCategoryRef> categories;
}

/// A single lesson file (e.g. `lessons/en/basics-01-how-pieces-move.json`).
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
    this.proof,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      proof: json['proof'] as String?,
      steps: [
        for (final s in json['steps'] as List<dynamic>? ?? const [])
          LessonStep.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final String title;

  /// The one line under the title on the art card and in the Pattern Book —
  /// what this lesson promises, not what it is filed under.
  final String summary;

  /// The puzzle file that proves this concept — the lesson's OWN beat.
  /// Named by the lesson rather than dealt from a pool, so a proof can be
  /// chosen because it matches the lesson.
  final String? proof;

  final List<LessonStep> steps;
}

/// A single step within a [Lesson]. Discriminated by the JSON `type` field:
/// `'teach'` -> [TeachStep], `'play'` -> [PlayStep].
sealed class LessonStep {
  const LessonStep({required this.fen});

  factory LessonStep.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'teach' => TeachStep.fromJson(json),
      'play' => PlayStep.fromJson(json),
      _ => throw FormatException('Unknown lesson step type: $type'),
    };
  }

  final String fen;
}

/// An explanatory step: a position plus markdown text.
class TeachStep extends LessonStep {
  const TeachStep({required super.fen, this.title, required this.text});

  factory TeachStep.fromJson(Map<String, dynamic> json) {
    return TeachStep(
      fen: json['fen'] as String? ?? '',
      title: json['title'] as String?,
      text: json['text'] as String? ?? '',
    );
  }

  final String? title;
  final String text;
}

/// An interactive step: the learner must play one of [targetSan].
class PlayStep extends LessonStep {
  const PlayStep({
    required super.fen,
    required this.prompt,
    required this.targetSan,
    this.hint,
  });

  factory PlayStep.fromJson(Map<String, dynamic> json) {
    return PlayStep(
      fen: json['fen'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      targetSan: _stringList(json['targetSan']),
      hint: json['hint'] as String?,
    );
  }

  final String prompt;
  final List<String> targetSan;
  final String? hint;
}

/// A theme entry from `puzzles/index.json`.
class PuzzleThemeRef {
  const PuzzleThemeRef({
    required this.id,
    required this.icon,
    required this.difficulty,
    required this.puzzleFiles,
  });

  factory PuzzleThemeRef.fromJson(Map<String, dynamic> json) {
    return PuzzleThemeRef(
      id: json['id'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      puzzleFiles: _stringList(json['puzzles']),
    );
  }

  final String id;
  final String icon;
  final String difficulty;
  final List<String> puzzleFiles;
}

/// The parsed `puzzles/index.json` manifest.
class PuzzleManifest {
  const PuzzleManifest({required this.themes});

  factory PuzzleManifest.fromJson(Map<String, dynamic> json) {
    return PuzzleManifest(
      themes: [
        for (final t in json['themes'] as List<dynamic>? ?? const [])
          PuzzleThemeRef.fromJson(t as Map<String, dynamic>),
      ],
    );
  }

  final List<PuzzleThemeRef> themes;
}

/// One trainer pack: twelve puzzles on a single idea, ascending in
/// difficulty. Packs are the Puzzles tab's unit of structure, and they live
/// in their own manifest — the themes in `puzzles/index.json` are mapped to
/// arts to build Sharpen's review pools, and trainer packs must never leak
/// into lesson revision.
///
/// Every pack is open to everyone. The app is for players of all strengths,
/// who arrive knowing what they want to work on; a rating is a description
/// of where you are, never a door.
class PuzzlePack {
  const PuzzlePack({
    required this.id,
    required this.icon,
    required this.puzzleFiles,
  });

  factory PuzzlePack.fromJson(Map<String, dynamic> json) {
    return PuzzlePack(
      id: json['id'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      puzzleFiles: _stringList(json['puzzles']),
    );
  }

  final String id;
  final String icon;
  final List<String> puzzleFiles;

  /// i18n keys; pack names are UI strings, not content.
  String get nameKey => 'puzzles.pack.$id.name';
  String get blurbKey => 'puzzles.pack.$id.blurb';
}

/// The parsed `puzzles/packs.json` manifest.
class PuzzlePackManifest {
  const PuzzlePackManifest({required this.packs});

  factory PuzzlePackManifest.fromJson(Map<String, dynamic> json) {
    return PuzzlePackManifest(
      packs: [
        for (final p in json['packs'] as List<dynamic>? ?? const [])
          PuzzlePack.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  final List<PuzzlePack> packs;

  /// Every puzzle file across every pack, in manifest order.
  List<String> get allPuzzleFiles => [
        for (final pack in packs) ...pack.puzzleFiles,
      ];
}

/// A single puzzle file (e.g. `puzzles/en/mate-in-1-01.json`).
class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.solution,
    this.rating,
    this.title,
    this.setup,
    this.hint,
    this.explanation,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String? ?? '',
      fen: json['fen'] as String? ?? '',
      solution: _stringList(json['solution']),
      rating: (json['rating'] as num?)?.toInt(),
      title: json['title'] as String?,
      setup: json['setup'] as String?,
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
    );
  }

  final String id;
  final String fen;
  final List<String> solution;

  /// Difficulty on the trainer's scale (roughly 600–2000). Null on the
  /// teaching puzzles, which are ordered by their lesson rather than rated.
  final int? rating;

  final String? title;
  final String? setup;
  final String? hint;
  final String? explanation;
}

/// Anything the Studio can open from its library.
///
/// The list, the filter strip, the search box and the card speak this and
/// nothing else, so a bundled master game and one the reader imported are the
/// same thing to every one of them. The two differ only in where the PGN comes
/// from — composed from a stored move list, or kept verbatim as it was pasted.
abstract interface class StudyGame {
  /// Unique across the whole library, bundled and imported alike.
  String get id;

  /// Which chip in the filter strip this game sits under.
  String get shelf;

  /// The card's heading: a pairing, or the name the reader gave it.
  String get title;

  /// Two characters standing in for the game on its card. Empty when there is
  /// nothing to abbreviate — the UI decides what to draw instead.
  String get monogram;

  /// Where the card says the game was played, or empty when the source does
  /// not say: the city for a master game ("Paris"), as a game is cited in
  /// print, and the event for a pasted PGN, whose `[Site]` is often a URL.
  String get place;

  /// Null when the source declared no usable date.
  int? get year;

  /// '1-0', '0-1', '1/2-1/2' or '*'.
  String get result;

  int get moveCount;

  /// Lower-cased haystack for the search box, so callers only fold the query.
  String get searchText;

  /// The game as PGN, ready for `MoveTree.fromPgn`.
  String toPgn();
}

/// The shelf every imported game sits on. Bundled games use their collection
/// id, and no collection may be called this.
const String importedShelf = 'imported';

/// One master game in the Studio's study library.
///
/// The movetext is stored as bare SAN with no move numbers, because numbers
/// are derivable and a stored number can disagree with the moves it counts.
/// [toPgn] puts them back on the way out.
class GameRecord implements StudyGame {
  const GameRecord({
    required this.id,
    required this.collection,
    required this.white,
    required this.black,
    required this.event,
    required this.site,
    required this.year,
    required this.result,
    required this.plies,
    required this.moves,
    this.eco,
  });

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      id: json['id'] as String? ?? '',
      collection: json['collection'] as String? ?? '',
      white: json['white'] as String? ?? '',
      black: json['black'] as String? ?? '',
      event: json['event'] as String? ?? '',
      site: json['site'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      result: json['result'] as String? ?? '*',
      eco: json['eco'] as String?,
      plies: json['plies'] as int? ?? 0,
      moves: (json['moves'] as String? ?? '')
          .split(' ')
          .where((san) => san.isNotEmpty)
          .toList(),
    );
  }

  @override
  final String id;

  /// Id of the [GameCollection] this game belongs to — and the shelf it sits
  /// on in the filter strip.
  final String collection;

  final String white;
  final String black;

  /// The database's event label, which is often a code ("Paris it" is an
  /// international tournament, "Berlin m" a match): searched, written to the
  /// PGN, but never shown — the card cites [site].
  final String event;
  final String site;

  /// The site, with the PGN standard's `?` read as absent (the rule
  /// `MoveTree.header` applies to imports).
  @override
  String get place => site == '?' ? '' : site;

  @override
  final int year;

  /// '1-0' or '0-1'. The bundled library is decisive games only.
  @override
  final String result;

  /// Encyclopaedia of Chess Openings code, when the source carried one.
  final String? eco;

  final int plies;

  /// The game in SAN, one move per entry, White first.
  final List<String> moves;

  @override
  String get shelf => collection;

  @override
  String get title => pairing;

  /// The WINNER's initials, not White's: the bundled library is decisive
  /// games only, so this is the one place a card says who it was that won.
  @override
  String get monogram => initialsOf(result == '1-0' ? white : black);

  /// First two characters of a name, or empty when there is no name.
  static String initialsOf(String name) =>
      name.length >= 2 ? name.substring(0, 2) : '';

  /// Full moves, rounded up — what a reader means by "a 23-move game".
  @override
  int get moveCount => (plies + 1) ~/ 2;

  /// How a game is named: the two surnames. "Morphy, Paul" is how a database
  /// writes a player and not how anyone says one, and two full names do not
  /// fit a phone card.
  String get pairing => pairingOf(white, black);

  /// Shared with imported games, whose headers are written the same way.
  static String pairingOf(String white, String black) =>
      '${_surname(white)} – ${_surname(black)}';

  static String _surname(String name) => name.split(',').first.trim();

  /// Everything a reader might type to find this game, folded to lower case
  /// so the caller only has to fold the query.
  @override
  String get searchText =>
      '$white $black $event $site $year ${eco ?? ''}'.toLowerCase();

  /// A standard PGN for [MoveTree.fromPgn]: the seven tag pairs the studio
  /// reads its player names from, then the numbered movetext.
  @override
  String toPgn() {
    final buffer = StringBuffer()
      ..writeln('[Event "$event"]')
      ..writeln('[Site "$site"]')
      ..writeln('[Date "$year.??.??"]')
      ..writeln('[Round "?"]')
      ..writeln('[White "$white"]')
      ..writeln('[Black "$black"]')
      ..writeln('[Result "$result"]');
    if (eco != null) buffer.writeln('[ECO "$eco"]');
    buffer.writeln();
    for (final (i, san) in moves.indexed) {
      if (i.isEven) buffer.write('${i ~/ 2 + 1}. ');
      buffer.write('$san ');
    }
    return (buffer..write(result)).toString();
  }
}

/// One player's games, the library's unit of browsing.
class GameCollection {
  const GameCollection({
    required this.id,
    required this.player,
    required this.era,
    required this.count,
  });

  factory GameCollection.fromJson(Map<String, dynamic> json) {
    return GameCollection(
      id: json['id'] as String? ?? '',
      player: json['player'] as String? ?? '',
      era: json['era'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  final String id;

  /// Display name. Not an i18n key: a player's name is the same in every
  /// language, and so is the era beside it.
  final String player;
  final String era;
  final int count;
}

/// The parsed `games/games.json` — the whole study library.
///
/// One file rather than the index-plus-files shape lessons and puzzles use.
/// Those split because they are per-language and individually large; games
/// are neither, so a single ~100KB asset is the honest shape — and it lets a
/// search run across the whole library without loading anything else.
class GameLibrary {
  const GameLibrary({required this.collections, required this.games});

  factory GameLibrary.fromJson(Map<String, dynamic> json) {
    return GameLibrary(
      collections: [
        for (final c in json['collections'] as List<dynamic>? ?? const [])
          GameCollection.fromJson(c as Map<String, dynamic>),
      ],
      games: [
        for (final g in json['games'] as List<dynamic>? ?? const [])
          GameRecord.fromJson(g as Map<String, dynamic>),
      ],
    );
  }

  final List<GameCollection> collections;
  final List<GameRecord> games;
}

/// Tolerant string-list reader: accepts a JSON array, a bare string
/// (wrapped in a single-element list), or null/absent (empty list).
List<String> _stringList(Object? value) {
  return switch (value) {
    null => const [],
    String s => [s],
    List<dynamic> l => [for (final e in l) e as String],
    _ => throw FormatException('Expected a string or list of strings: $value'),
  };
}
