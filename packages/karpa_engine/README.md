# karpa_engine

KarpaChess's first-party Stockfish integration. No third-party plugin:
this module owns the whole path from C++ to Dart.

- **Engine**: official [Stockfish](https://github.com/official-stockfish/Stockfish)
  19 sources, unmodified, in `stockfish/` (GPL-3.0 — see below).
- **Bridge** (`native/karpa_bridge.{h,cpp}`): the UCI loop runs on a
  dedicated in-process thread. Input is an in-memory blocking line queue
  installed as `std::cin`'s streambuf; output is a line-splitting streambuf
  on `std::cout` that hands each line straight to Dart. No OS pipes, no
  reader threads, no polling. Restartable.
- **Dart API** (`lib/karpa_engine.dart`): `KarpaEngine` — `start()`,
  `lines` stream (pushed via `NativeCallable.listener`), `send()`,
  `dispose()`.
- **Builds**: per-arch, portable. Android arm64 and iOS arm64 use NEON
  without dot-product — the same kernels as Stockfish's official `armv8`
  build — because the phones the app installs on include ARMv8.0 cores
  (Cortex-A53/A73; iPhone 6s–XS/XR) that crash with SIGILL on dot-product
  instructions. macOS arm64 keeps dot-product (every Apple Silicon Mac has
  it); Intel and x86_64 use SSE4.1.
- **Network**: the default NNUE network named in `stockfish/src/evaluate.h`
  (Stockfish 19 retired the second, small one) is downloaded at build time
  from the official network server, **verified** against the SHA-256 prefix
  in its name (Stockfish's own convention), and embedded into the binary.
  Android caches it once in `.nnue/`; iOS/macOS fetch through
  `tool/fetch_nnue.sh`. A file that fails verification is replaced, never
  embedded.
- **Privacy manifest**: `ios|macos/Resources/PrivacyInfo.xcprivacy` declares
  the one required-reason API category the engine references, file
  timestamps (`fstat` in the Syzygy loader, `lstat` in Stockfish 19's
  shared-memory setup).
- **Stockfish 19 exits on a position it refuses** (`std::exit(1)`, and the
  engine runs in the app's process), so the app never sends one: every
  position passes the app's `EnginePosition` first.
- **Synced copies**: CocoaPods cannot reference files outside a pod root, so
  `tool/sync_sources.sh` copies `stockfish/`, `native/` and
  `tool/fetch_nnue.sh` into `ios/` and `macos/`. Re-run it after touching any
  of them.

## License

The Stockfish sources are GPL-3.0-or-later (`stockfish/Copying.txt`).
Distributing an app containing this module means the combined work must
comply with the GPL — in particular, making the corresponding source
available. This repository (with `packages/karpa_engine/`) is that source.
