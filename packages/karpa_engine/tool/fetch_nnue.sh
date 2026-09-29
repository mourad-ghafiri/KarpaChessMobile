#!/bin/sh
# Fetches one default Stockfish NNUE network into a directory, verified.
#
#   fetch_nnue.sh <net-file-name> [dest-dir]
#
# Called by the iOS and macOS podspec script phases (Android's CMakeLists.txt
# does the same natively). A net's file name carries the first 12 hex digits
# of its SHA-256 — Stockfish's own convention, checked the same way by its
# Makefile — so a file is only kept when its hash matches its name. A file
# that fails the check is replaced, never trusted: a download that saved an
# HTTP error page under the net's name would otherwise be embedded, and
# Stockfish exits the whole process when its embedded net does not load.
set -eu

net="$1"
dest="${2:-.}"
expected="${net#nn-}"
expected="${expected%.nnue}"
target="$dest/$net"

verified() {
  [ -f "$1" ] && [ "$(shasum -a 256 "$1" | cut -c1-12)" = "$expected" ]
}

if verified "$target"; then
  exit 0
fi
rm -f "$target"

partial="$target.$$.part"
attempt=1
while [ "$attempt" -le 3 ]; do
  if curl --fail --location --silent --show-error --output "$partial" \
      "https://tests.stockfishchess.org/api/nn/$net" && verified "$partial"; then
    mv "$partial" "$target"
    exit 0
  fi
  rm -f "$partial"
  attempt=$((attempt + 1))
  sleep 2
done

echo "error: could not download a verified $net" >&2
exit 1
