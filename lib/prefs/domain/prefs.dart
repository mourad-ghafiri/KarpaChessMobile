import '../../core/json/json_read.dart';

/// User preferences and their defaults.
class Prefs {
  const Prefs({
    this.appTheme = 'midnightGrove',
    this.boardTheme = 'tournament',
    this.pieceSet = 'classic',
    this.font = 'classic',
    this.coords = true,
    this.legalHighlight = true,
    this.lastMoveHighlight = true,
    this.sound = true,
    this.soundPack = 'wood',
    this.haptics = true,
    this.animations = true,
    this.lang = 'en',
    this.difficulty = 1,
    this.playAs = 'w',
    this.timeControlMinutes,
    this.timeControlIncrement = 0,
    this.commentatorBadges = true,
    this.lessonsCompleted = const {},
    this.playerName = '',
    this.playerAvatarPath,
  });

  /// App theme id (an AppThemeId name).
  final String appTheme;

  /// Typeface choice (an AppFont name).
  final String font;

  /// Board colorway id (a BoardColorTheme name).
  final String boardTheme;

  /// Piece set id (a PieceSetId name).
  final String pieceSet;
  final bool coords;
  final bool legalHighlight;
  final bool lastMoveHighlight;
  final bool sound;

  /// Board sound pack: wood | plastic | soft.
  final String soundPack;

  /// Haptic feedback on meaningful touches.
  final bool haptics;
  final bool animations;
  final String lang;

  /// Practice difficulty 1..4 (Beginner, Casual, Club, Master).
  final int difficulty;

  /// 'w' | 'b' | 'random'.
  final String playAs;

  /// null means unlimited time.
  final int? timeControlMinutes;
  final int timeControlIncrement;

  final bool commentatorBadges;
  final Set<String> lessonsCompleted;

  /// Display name for the human player ('' = localized "You").
  final String playerName;

  /// Absolute path of the picked profile picture (null = glyph avatar).
  final String? playerAvatarPath;

  /// Field-wise equality with identity for [lessonsCompleted] (replaced,
  /// never mutated), so `.select` guards and `updateShouldNotify` actually
  /// short-circuit — the same contract every state class in the app keeps.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prefs &&
          other.appTheme == appTheme &&
          other.boardTheme == boardTheme &&
          other.pieceSet == pieceSet &&
          other.font == font &&
          other.coords == coords &&
          other.legalHighlight == legalHighlight &&
          other.lastMoveHighlight == lastMoveHighlight &&
          other.sound == sound &&
          other.soundPack == soundPack &&
          other.haptics == haptics &&
          other.animations == animations &&
          other.lang == lang &&
          other.difficulty == difficulty &&
          other.playAs == playAs &&
          other.timeControlMinutes == timeControlMinutes &&
          other.timeControlIncrement == timeControlIncrement &&
          other.commentatorBadges == commentatorBadges &&
          identical(other.lessonsCompleted, lessonsCompleted) &&
          other.playerName == playerName &&
          other.playerAvatarPath == playerAvatarPath;

  @override
  int get hashCode => Object.hashAll([
        appTheme, boardTheme, pieceSet, font, coords, legalHighlight,
        lastMoveHighlight, sound, soundPack, haptics, animations, lang,
        difficulty, playAs, timeControlMinutes, timeControlIncrement,
        commentatorBadges, identityHashCode(lessonsCompleted), playerName,
        playerAvatarPath, //
      ]);

  Prefs copyWith({
    String? appTheme,
    String? boardTheme,
    String? pieceSet,
    String? font,
    bool? coords,
    bool? legalHighlight,
    bool? lastMoveHighlight,
    bool? sound,
    String? soundPack,
    bool? haptics,
    bool? animations,
    String? lang,
    int? difficulty,
    String? playAs,
    int? Function()? timeControlMinutes,
    int? timeControlIncrement,
    bool? commentatorBadges,
    Set<String>? lessonsCompleted,
    String? playerName,
    String? Function()? playerAvatarPath,
  }) {
    return Prefs(
      appTheme: appTheme ?? this.appTheme,
      boardTheme: boardTheme ?? this.boardTheme,
      pieceSet: pieceSet ?? this.pieceSet,
      font: font ?? this.font,
      coords: coords ?? this.coords,
      legalHighlight: legalHighlight ?? this.legalHighlight,
      lastMoveHighlight: lastMoveHighlight ?? this.lastMoveHighlight,
      sound: sound ?? this.sound,
      soundPack: soundPack ?? this.soundPack,
      haptics: haptics ?? this.haptics,
      animations: animations ?? this.animations,
      lang: lang ?? this.lang,
      difficulty: difficulty ?? this.difficulty,
      playAs: playAs ?? this.playAs,
      timeControlMinutes: timeControlMinutes != null
          ? timeControlMinutes()
          : this.timeControlMinutes,
      timeControlIncrement: timeControlIncrement ?? this.timeControlIncrement,
      commentatorBadges: commentatorBadges ?? this.commentatorBadges,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      playerName: playerName ?? this.playerName,
      playerAvatarPath: playerAvatarPath != null
          ? playerAvatarPath()
          : this.playerAvatarPath,
    );
  }

  bool isLessonComplete(String id) => lessonsCompleted.contains(id);

  Map<String, Object?> toJson() => {
        'appTheme': appTheme,
        'boardTheme': boardTheme,
        'pieceSet': pieceSet,
        'font': font,
        'coords': coords,
        'legalHighlight': legalHighlight,
        'lastMoveHighlight': lastMoveHighlight,
        'sound': sound,
        'soundPack': soundPack,
        'haptics': haptics,
        'animations': animations,
        'lang': lang,
        'difficulty': difficulty,
        'playAs': playAs,
        'timeControlMinutes': timeControlMinutes,
        'timeControlIncrement': timeControlIncrement,
        'commentatorBadges': commentatorBadges,
        'lessonsCompleted': lessonsCompleted.toList(),
        'playerName': playerName,
        'playerAvatarPath': playerAvatarPath,
      };

  /// Tolerant: a field of the wrong type falls back to its own default (see
  /// `json_read.dart`), so one bad field never costs the whole blob — or,
  /// at startup, the app.
  factory Prefs.fromJson(Map<String, Object?> json) {
    const defaults = Prefs();
    return Prefs(
      appTheme: readString(json['appTheme']) ?? defaults.appTheme,
      boardTheme: readString(json['boardTheme']) ?? defaults.boardTheme,
      pieceSet: readString(json['pieceSet']) ?? defaults.pieceSet,
      font: readString(json['font']) ?? defaults.font,
      coords: readBool(json['coords']) ?? defaults.coords,
      legalHighlight:
          readBool(json['legalHighlight']) ?? defaults.legalHighlight,
      lastMoveHighlight:
          readBool(json['lastMoveHighlight']) ?? defaults.lastMoveHighlight,
      sound: readBool(json['sound']) ?? defaults.sound,
      soundPack: readString(json['soundPack']) ?? defaults.soundPack,
      haptics: readBool(json['haptics']) ?? defaults.haptics,
      animations: readBool(json['animations']) ?? defaults.animations,
      lang: readString(json['lang']) ?? defaults.lang,
      difficulty: readInt(json['difficulty']) ?? defaults.difficulty,
      playAs: readString(json['playAs']) ?? defaults.playAs,
      timeControlMinutes: readInt(json['timeControlMinutes']),
      timeControlIncrement: readInt(json['timeControlIncrement']) ??
          defaults.timeControlIncrement,
      commentatorBadges:
          readBool(json['commentatorBadges']) ?? defaults.commentatorBadges,
      lessonsCompleted: readStringSet(json['lessonsCompleted']),
      playerName: readString(json['playerName']) ?? defaults.playerName,
      playerAvatarPath: readString(json['playerAvatarPath']),
    );
  }
}
