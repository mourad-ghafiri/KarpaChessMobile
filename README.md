# KarpaChess Mobile

KarpaChess: learn chess with guided lessons, a rated puzzle trainer, practice
games against Stockfish and a study studio, in twelve languages. Built with
Flutter for iOS and Android, phones and tablets, and macOS.

Everything runs on the device. No account, no server, no analytics, no
network access.

## Features

- **Learn**: 100 lessons across eight arts: Foundations, The Story of Chess,
  The Blade (tactics), The First Moves (openings), The Finish (endgames),
  The Plan (strategy), The Hunt (attack) and The Chess World. Every lesson
  runs **SEE → PLAY → OWN**, ending on its own proof puzzle. Mastered
  patterns come back in **Sharpen**, a spaced-repetition review, and are
  collected in the **Pattern Book**.
- **Puzzles**: a rated trainer of 240 puzzles in 20 packs (600–2000), with an
  Elo-style puzzle rating, streaks, replayable packs and multi-move solutions.
- **Play**: games against **Stockfish 19** (NNUE) at four strengths, with
  working clocks (increment included, or unlimited), hints and undo. An
  unfinished game survives closing the app.
- **Review**: every move of a finished game classified as best, good,
  inaccuracy, mistake or blunder.
- **Studio**: a library of 240 short, decisive master games in 24
  collections, plus your own PGN imports (comments, variations and NAGs
  kept). It has per-move classification with brilliancy detection, variation
  trees, editable player cards, drawing tools and an accuracy recap.
- **Coach**: an offline, rule-based coach behind a single hint button,
  reading material, king safety, pawn structure, development and loose
  pieces.
- **Twelve languages**, with the interface **and** every lesson and puzzle
  translated by hand: English, French, Spanish, Arabic (right to left),
  Chinese, Russian, Indonesian, Japanese, Hindi, Turkish, Italian and
  European Portuguese.
- **Ten themes**, five board colorways, **ten piece sets** (Classic, Wood,
  Marble, Diagram, Modern, Deco, Facet, Silhouette, Soft, Bold), three
  typefaces and three synthesized sound packs.

## Development

```sh
flutter pub get
flutter run -d <device>
flutter analyze            # must stay at zero issues
flutter test               # unit + widget suite
flutter drive --driver=test/device/driver.dart --target=test/device/engine_smoke.dart -d <device>
flutter drive --driver=test/device/driver.dart --target=test/device/app_flow.dart -d <device>
```

The on-device programs live in `test/device/` and run through `flutter drive`;
they carry no `_test.dart` suffix so the host suite never picks them up.

- The engine is the first-party module `packages/karpa_engine`: official
  Stockfish 19 sources and an in-memory UCI bridge, with no third-party
  plugin. Its NNUE networks are downloaded **and verified** at build time; see
  the module's README.
- The pieces and the launcher icon are drawn by code: `python3
  tool/gen_pieces.py` audits the ten sets against its quality gate and
  writes them to `assets/pieces/`, and `python3 tool/gen_icon.py` writes
  every platform's icon, with the Classic knight taken from the piece
  generator. Both need only Pillow.
- Content (`assets/data/`) is authored and gated in this repository:
  `dart run tool/content.dart`, `tool/translations.dart`,
  `tool/lint_lessons.dart`, `tool/lint_puzzles.dart`, `tool/puzzles.dart`.
- Minimum iOS 15.0 and Android 7.0 (API 24). CocoaPods is required for iOS
  and macOS.
- To sign iOS builds, put your team in `ios/Flutter/Signing.xcconfig`
  (`DEVELOPMENT_TEAM = <Team ID>`). The file is git-ignored, and the shared
  project carries no team. `dart run tool/shareable.dart` checks that
  nothing personal or machine-specific is committed.
- Architecture and invariants: `CLAUDE.md`. The lesson-writing contract:
  `docs/LESSON_STYLE.md`. Translation contracts: `docs/TRANSLATION_*.md`.

## Website

[`website/`](website/) is <https://karpachess.com>, a static site with no build
step. Its privacy page is the policy both stores link to. `python3
tool/website.py` renders it from [`docs/PRIVACY.md`](docs/PRIVACY.md), and
derives the site's screenshots, icons, piece previews and fonts from the
repository. `--check` fails when any of them is out of date. See
[`website/README.md`](website/README.md).

## Releasing

See [`docs/RELEASE.md`](docs/RELEASE.md) for signing, obfuscated builds,
store forms and the pre-release device checks.

## License

KarpaChess is free software: you can redistribute it and/or modify it under
the terms of the **GNU General Public License, version 3 or (at your option)
any later version** (see [`LICENSE`](LICENSE)). The app embeds GPL-3.0 code,
namely Stockfish, chessground and dartchess, so the combined work is GPL-3.0 as
a whole. This repository is its complete corresponding source.

The GPL permits selling the app. What it requires, and how a paid store
release meets it, is in [`docs/RELEASE.md`](docs/RELEASE.md).

The artwork is original and **public domain**: the ten piece sets
(`assets/pieces/`) and the launcher icon are dedicated under
[CC0 1.0](assets/pieces/LICENSE). CC0 waives copyright only. Trademark rights
in the KarpaChess name and icon are not waived (CC0 §4a).

### Credits

- [Stockfish](https://stockfishchess.org) 19, © 2004–2026 The Stockfish
  developers, GPL-3.0-or-later.
- [chessground](https://pub.dev/packages/chessground) and
  [dartchess](https://pub.dev/packages/dartchess), from lichess.org, GPL-3.0.
  chessground is vendored in `packages/chessground/` without the piece sets
  and board textures its package bundles. `packages/chessground/NOTICE.md`
  records the change.
- Fraunces, Inter and JetBrains Mono, under the SIL Open Font License 1.1.

In the app, **Settings › About › Open-source licenses** lists every
component and its full license text.
