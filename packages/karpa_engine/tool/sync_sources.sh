#!/bin/sh
# Copies the canonical engine sources (stockfish/, native/) and the verified
# net fetcher (tool/fetch_nnue.sh) into the iOS and macOS platform
# directories. CocoaPods cannot reference files outside a local pod's root,
# so each platform carries a synced copy. Re-run after upgrading Stockfish,
# editing the bridge or editing the fetcher.
set -e
cd "$(dirname "$0")/.."
for platform in ios macos; do
  rm -rf "$platform/stockfish" "$platform/native"
  cp -R stockfish "$platform/stockfish"
  cp -R native "$platform/native"
  mkdir -p "$platform/tool"
  cp tool/fetch_nnue.sh "$platform/tool/fetch_nnue.sh"
done
echo "synced stockfish/ + native/ + tool/fetch_nnue.sh into ios/ and macos/"
