import '../../../content/domain/models.dart';
import 'move_tree.dart';

/// A game the reader brought in, kept in their library.
///
/// It stores the **PGN exactly as it arrived**, not a re-serialization: an
/// imported game may carry comments, variations, NAGs and clock times, and a
/// library that quietly dropped them would be editing someone's study. The
/// attributes beside it are read from the headers once, at import, so the list
/// can name, sort and search a game without parsing 60 of them.
class ImportedGame implements StudyGame {
  const ImportedGame({
    required this.id,
    required this.name,
    required this.white,
    required this.black,
    required this.event,
    required this.site,
    required this.year,
    required this.result,
    required this.plies,
    required this.pgn,
    required this.importedAt,
    this.eco,
  });

  /// Reads the attributes of an already-parsed [tree]. Parsing is the caller's
  /// job precisely because it is the step that can fail, and the person who
  /// pasted the text is the only one who can do anything about that.
  factory ImportedGame.fromTree(
    MoveTree tree, {
    required String id,
    required String name,
    required String pgn,
    required DateTime importedAt,
  }) {
    final result = tree.header('Result');
    final eco = tree.header('ECO');
    return ImportedGame(
      id: id,
      name: name.trim(),
      white: tree.header('White'),
      black: tree.header('Black'),
      event: tree.header('Event'),
      site: tree.header('Site'),
      year: _year(tree.header('Date')),
      result: result.isEmpty ? '*' : result,
      eco: eco.isEmpty ? null : eco,
      plies: tree.mainline().length - 1,
      pgn: pgn,
      importedAt: importedAt,
    );
  }

  factory ImportedGame.fromJson(Map<String, Object?> json) => ImportedGame(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        white: json['white'] as String? ?? '',
        black: json['black'] as String? ?? '',
        event: json['event'] as String? ?? '',
        site: json['site'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        result: json['result'] as String? ?? '*',
        eco: json['eco'] as String?,
        plies: (json['plies'] as num?)?.toInt() ?? 0,
        pgn: json['pgn'] as String? ?? '',
        importedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['importedAt'] as num?)?.toInt() ?? 0,
        ),
      );

  /// A PGN date is `YYYY.MM.DD` with `??` for anything unknown, so the year is
  /// null far more often than it is malformed.
  static int? _year(String date) => int.tryParse(date.split('.').first);

  @override
  final String id;

  /// What the reader called it. Empty when they left the field alone, which is
  /// the common case for a PGN that names its own players.
  final String name;

  final String white;
  final String black;

  final String event;
  final String site;

  /// The event, not the site: a lichess or chess.com export's `[Site]` is a
  /// URL or the server's name, while its event says what the game was.
  @override
  String get place => event;

  @override
  final int? year;

  @override
  final String result;

  final String? eco;
  final int plies;

  /// The original text, byte for byte.
  final String pgn;

  final DateTime importedAt;

  @override
  String get shelf => importedShelf;

  /// The name if there is one, else the pairing the headers give. Empty when
  /// the source was a bare move list and no name was typed — the UI is what
  /// substitutes a localized "Untitled" for that, never the domain.
  @override
  String get title {
    if (name.isNotEmpty) return name;
    if (white.isEmpty && black.isEmpty) return '';
    return GameRecord.pairingOf(white, black);
  }

  /// The winner's initials when the PGN declared one, else whatever the game
  /// is called. An imported game is often a draw, or unfinished, or has no
  /// players at all.
  @override
  String get monogram {
    final winner = switch (result) {
      '1-0' => white,
      '0-1' => black,
      _ => '',
    };
    return winner.isNotEmpty
        ? GameRecord.initialsOf(winner)
        : GameRecord.initialsOf(title);
  }

  @override
  int get moveCount => (plies + 1) ~/ 2;

  @override
  String get searchText =>
      '$name $white $black $event $site ${year ?? ''} ${eco ?? ''}'
          .toLowerCase();

  @override
  String toPgn() => pgn;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'white': white,
        'black': black,
        'event': event,
        'site': site,
        'year': year,
        'result': result,
        'eco': eco,
        'plies': plies,
        'pgn': pgn,
        'importedAt': importedAt.millisecondsSinceEpoch,
      };
}
