/// Facts the app states about itself: in Settings › About and on the
/// open-source licenses page.
abstract final class AppInfo {
  static const name = 'KarpaChess';

  /// The release version. It must equal the version name in pubspec.yaml
  /// (the part before `+`); `test/core/app_info_test.dart` holds the two
  /// together, so a version bump that misses one fails the suite.
  static const version = '1.1.1';

  /// Where the complete corresponding source is published. KarpaChess ships
  /// Stockfish, chessground and dartchess, all GPL-3.0, so the app as a
  /// whole is GPL-3.0-or-later and every build must point to its source.
  static const sourceUrl = 'https://github.com/mourad-ghafiri/KarpaChessMobile';

  /// The privacy policy both stores link to: `docs/PRIVACY.md`, rendered
  /// onto the app's website (`website/privacy.html`) by `tool/website.py`.
  /// Apple also requires it to be reachable in the app (Guideline
  /// 5.1.1(i)): Settings › About shows it.
  static const privacyUrl = 'https://karpachess.com/privacy.html';

  static const copyright = '© 2026 KarpaChess';

  static const license = 'GPL-3.0-or-later';
}
