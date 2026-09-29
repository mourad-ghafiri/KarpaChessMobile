#!/bin/sh
# Builds a host Stockfish from the SAME sources the app ships, so the content
# gates judge chess with the engine the learner actually plays.
#
#   sh packages/karpa_engine/tool/build_host.sh [ARCH]
#
# The binary lands at stockfish/src/stockfish and is gitignored along with its
# objects and its embedded net. `tool/src/process_uci_transport.dart` finds it
# there; without it the engine screen refuses to run rather than falling back
# to a search of its own.
#
# ARCH defaults to the host. `make build` (not `all`) is used because it also
# fetches and verifies the NNUE net via stockfish/scripts/net.sh — those
# scripts are vendored, which they were not before Stockfish 19.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
src="$here/../stockfish/src"

arch=${1:-}
if [ -z "$arch" ]; then
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) arch=apple-silicon ;;
    Darwin-x86_64) arch=x86-64-avx2 ;;
    Linux-aarch64) arch=armv8-dotprod ;;
    Linux-x86_64) arch=x86-64-avx2 ;;
    *) arch=native ;;
  esac
fi

jobs=$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu || echo 4 )

echo "building Stockfish for the host: ARCH=$arch, -j$jobs"
make -C "$src" -j"$jobs" build ARCH="$arch"

echo
"$src/stockfish" <<'EOF' | sed -n '1,2p'
uci
quit
EOF
echo
echo "built: $src/stockfish"
