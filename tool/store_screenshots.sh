#!/bin/sh
# Captures the App Store and Google Play screenshots on simulators, then checks
# and files them with tool/store_screenshots.py: the raw captures land in
# build/screenshots/raw/, and only the publishing sets reach screenshots/.
# See docs/RELEASE.md, "Store screenshots".
#
#   sh tool/store_screenshots.sh [ios|android|all]
#
# iOS: the iPhone 6.9" (iPhone 17 Pro Max) and iPad 13" (iPad Pro 13-inch
# (M5)) simulators, taken from the newest runtime that has them. Both are shot
# in portrait: iPadOS ignores an app's orientation request while the app
# supports multitasking, and the App Store takes portrait iPad shots at the
# same size class.
#
# Android: the first running emulator (start one first). Its display is
# resized for each capture: 1080x1920 at 420 dpi for the phone, then
# 1440x2560 at 320 dpi for the tablet — portrait, like the iPad set: turned
# landscape, the emulated phone's camera cutout moves to a side the app may not
# draw into before Android 15, and the capture comes out short of 16:9. The
# size and density are ALWAYS reset afterwards, including when a capture
# fails.
set -eu
cd "$(dirname "$0")/.."

drive() { # <device id> <folder> <landscape: true|false>
  flutter drive --driver=test/device/driver.dart \
    --target=test/device/store_screenshots.dart -d "$1" \
    --dart-define=SHOT_DEVICE="$2" --dart-define=SHOT_LANDSCAPE="$3"
}

# The udid of the simulator called $1 on the newest runtime that has one.
sim_id() {
  xcrun simctl list devices available | awk -v name="$1" '
    index($0, "    " name " (") == 1 {
      match($0, /\([0-9A-F-]+\)/)
      id = substr($0, RSTART + 1, RLENGTH - 2)
    }
    END { print id }'
}

ios_device() { # <simulator name> <folder> <landscape>
  id=$(sim_id "$1")
  if [ -z "$id" ]; then
    echo "no available simulator named \"$1\"" >&2
    exit 1
  fi
  xcrun simctl boot "$id" 2>/dev/null || true
  xcrun simctl bootstatus "$id" -b >/dev/null
  drive "$id" "$2" "$3"
}

ios() {
  ios_device "iPhone 17 Pro Max" iphone-6.9 false
  ios_device "iPad Pro 13-inch (M5)" ipad-13 false
}

# adb from the PATH, or from the Android SDK: ANDROID_HOME, ANDROID_SDK_ROOT,
# then the SDK's default location on a Mac. It is often not on the PATH.
find_adb() {
  if command -v adb >/dev/null 2>&1; then
    echo adb
    return
  fi
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    if [ -n "$sdk" ] && [ -x "$sdk/platform-tools/adb" ]; then
      echo "$sdk/platform-tools/adb"
      return
    fi
  done
}

android() {
  adb=$(find_adb)
  if [ -z "$adb" ]; then
    echo "adb not found: put the SDK's platform-tools on the PATH or set ANDROID_HOME" >&2
    exit 1
  fi
  serial=$("$adb" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
  if [ -z "$serial" ]; then
    echo "start an Android emulator first" >&2
    exit 1
  fi
  trap '"$adb" -s "$serial" shell wm size reset; "$adb" -s "$serial" shell wm density reset' EXIT
  "$adb" -s "$serial" shell wm size 1080x1920
  "$adb" -s "$serial" shell wm density 420
  drive "$serial" android-phone false
  "$adb" -s "$serial" shell wm size 1440x2560
  "$adb" -s "$serial" shell wm density 320
  drive "$serial" android-tablet false
}

case "${1:-all}" in
  ios) ios ;;
  android) android ;;
  all) ios; android ;;
  *) echo "usage: sh tool/store_screenshots.sh [ios|android|all]" >&2; exit 2 ;;
esac

python3 tool/store_screenshots.py
