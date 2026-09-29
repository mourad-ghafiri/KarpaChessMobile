/// Chess-native progression titles — the face of the XP level curve.
enum AcademyRank {
  novice,
  apprentice,
  clubPlayer,
  tactician,
  strategist,
  candidateMaster,
  master,
  grandmaster;

  /// Two XP levels per rank; grandmaster from level 14 on.
  static AcademyRank fromLevel(int level) {
    final index = (level ~/ 2).clamp(0, AcademyRank.values.length - 1);
    return AcademyRank.values[index];
  }

  /// i18n key for the title label.
  String get labelKey => 'academy.rank.$name';

  /// Crest glyph shown on the title card.
  String get glyph => switch (this) {
        AcademyRank.novice => '♙',
        AcademyRank.apprentice => '♘',
        AcademyRank.clubPlayer => '♗',
        AcademyRank.tactician => '⚔',
        AcademyRank.strategist => '♖',
        AcademyRank.candidateMaster => '♕',
        AcademyRank.master => '♔',
        AcademyRank.grandmaster => '👑',
      };
}
