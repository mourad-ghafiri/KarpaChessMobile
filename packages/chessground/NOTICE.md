# Modified copy of chessground

This directory holds a **modified version** of
[chessground](https://github.com/lichess-org/flutter-chessground) 10.1.1, the
chessboard widget by the lichess.org team. It is licensed under the GNU
General Public License, version 3 or later (see `LICENSE`).

## What was changed

These changes were made on 2026-09-19 for KarpaChess:

- **`pubspec.yaml`**:
  - The `flutter: assets:` block is removed, along with the upstream
    `dev_dependencies`.
  - The version is marked `10.1.1+karpa.1` and `publish_to: 'none'`.
- **Not copied**: upstream's `assets/` (40 piece sets and the board textures),
  `swift/` and `Package.swift` (an Xcode asset catalog), `example/`, `test/`,
  `scripts/` and `doc/`.

`lib/` is upstream's code, byte for byte. `LICENSE`, `README.md` and
`CHANGELOG.md` are upstream's files.

## Why

Flutter bundles every asset a dependency declares into the app, whether the
app uses it or not. Upstream declares all of its piece sets. Several of them
are licensed for non-commercial use only (lichess's `COPYING.md` lists each
set's terms), so the hosted package would ship them inside a paid app.

KarpaChess draws its own pieces (`assets/pieces/`, from `tool/gen_pieces.py`)
and its own board squares. It always passes both to chessground, so no
chessground asset is ever loaded.

## Rules for this copy

- Keep this copy. Going back to the hosted `chessground` package brings the
  non-commercial sets back into the binary. `test/core/commercial_assets_test.dart`
  fails if that happens.
- The app must never use `PieceSet.*`, `ChessboardColorScheme.*` presets, or any
  other `package: 'chessground'` asset. Those constants remain in `lib/` but
  now point at files that are not bundled.
- To update: copy a newer upstream `lib/` over this one, then re-apply the
  `pubspec.yaml` edits above and update this notice.

The combined work, KarpaChess, is distributed under GPL-3.0-or-later with its
complete source. See the app's README.
