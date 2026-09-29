# Releasing KarpaChess

The checklist a store build goes through. Everything here is done by a
person with the signing keys. Nothing in the repository holds a secret, and
nothing should ever be committed that does.

## 0. Blockers, once

- **Publish the source.** KarpaChess embeds GPL-3.0 code (Stockfish,
  chessground, dartchess), so the app is GPL-3.0-or-later as a whole, and
  every distributed build must offer its complete corresponding source. The
  app points readers to `AppInfo.sourceUrl`
  (`https://github.com/mourad-ghafiri/KarpaChessMobile`), shown under
  Settings › About. That repository must be **public**, and must hold the
  exact source of the build, before the first store release. Tag each release.

  Publish only what git would: never a zip of the working folder, whose
  ignored files carry absolute paths of the machine that built it (`build/`,
  `.dart_tool/`, `android/local.properties`, `ios/Flutter/Generated.xcconfig`
  and more).
  - `dart run tool/shareable.dart` checks exactly the publishable set and
    must print 0 errors.
  - To start a fresh repository from a checkout, copy that same set (new files
    and uncommitted edits included, no `.git`):

    ```sh
    git ls-files -z --cached --others --exclude-standard \
      | rsync -a --from0 --files-from=- ./ ../KarpaChessMobile-public/
    ```
- **Selling it is allowed.** See "Selling under the GPL" below. Every asset
  the app bundles is cleared for commercial use, so a paid release needs no
  asset change.
- **Privacy policy.** Both stores require one even though the app collects
  nothing. Google Play requires it "even [for] apps that do not collect any
  user data". Apple requires a link in App Store Connect *and* in the app
  (Guideline 5.1.1(i)).
  - The policy is `docs/PRIVACY.md`. Its public address is
    `AppInfo.privacyUrl`, `https://karpachess.com/privacy.html`, a page of the
    website in `website/`.
  - `python3 tool/website.py` renders the policy into that page. Run it after
    every edit to the policy: `--check` fails until you do.
  - The app shows the notice under Settings › About › Privacy policy, in all
    twelve languages.
- **The website is live** before the first submission. Both stores open the
  privacy page, and Apple opens the support URL (`https://karpachess.com/#support`),
  which must lead to real contact details. Upload the contents of `website/`
  after `python3 tool/website.py --check` passes.

## Selling under the GPL

The GPL decides how the app is shared, not whether it is paid for. A price,
a subscription, in-app purchases or ads are all compatible with it. Stockfish
says so plainly: it may be sold "either by itself or as part of some bigger
software package". What a paid release must do:

- **Publish the exact source of every build you ship**, tagged, at
  `AppInfo.sourceUrl`. That includes the vendored `packages/chessground/` and
  `packages/karpa_engine/`. This is the one condition, and it is not optional.
- **Accept that buyers may share and rebuild it.** Anyone may compile the
  published source and give it away. That right belongs to them under the
  GPL. The GPL gives no rights to the **name** or the **icon as a brand**,
  and CC0 keeps trademark rights too (§4a). Protect "KarpaChess" and the icon
  by registering the trademark. A rebuild that uses them can then be asked to
  rename.
- **Keep the notices intact**: Settings › About (source notice) and the
  licenses page, which lists Stockfish, the fonts and the artwork.
- **Ship your own EULA on the App Store.** Apple's standard EULA forbids
  redistribution, which conflicts with GPL §10. See step 5. Google Play
  needs none.

What is bundled, and why each part may be sold:

| Part | License | Commercial use |
|---|---|---|
| App code | GPL-3.0-or-later (this repository) | Yes, with source |
| Stockfish 19 + NNUE net | GPL-3.0 | Yes, with source |
| chessground, dartchess | GPL-3.0 | Yes, with source |
| Piece sets, launcher icon | Original, CC0 1.0 (`assets/pieces/LICENSE`) | Yes |
| Fraunces, Inter, JetBrains Mono | SIL OFL 1.1 | Yes (not sold on their own) |
| Move sounds | Synthesized by `tool/gen_sounds.py` | Yes |
| Lessons, puzzles, games | Authored here; game moves are facts | Yes |
| Other dependencies | MIT, BSD, Apache-2.0 | Yes |

chessground is vendored in `packages/chessground/` **without** its asset
library. The hosted package bundles 40 piece sets, several licensed for
non-commercial use only. `test/core/commercial_assets_test.dart` fails if the
app goes back to the hosted package or uses any of its assets.

Not legal advice. This follows common practice (lichess ships a GPL app
through both stores), but have a lawyer review it, and `docs/EULA.md`,
before the first paid release.

## 1. Android signing, once

Create an upload keystore **outside the repository**:

```sh
keytool -genkey -v -keystore ~/karpachess-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (git-ignored; never commit it):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/karpachess-upload.jks
```

`android/app/build.gradle.kts` signs release builds with it. Without the
file, release builds fall back to the debug key and Gradle warns: such a
build runs, but Google Play rejects it. Enroll in Play App Signing and keep
a backup of the keystore somewhere safe. A lost upload key is recoverable
through Play support, but only with that enrollment.

## 1b. iOS signing, once

The signing team is **not** in the shared Xcode project. A Team ID identifies
an Apple Developer account, so it lives in a git-ignored file instead. Create
`ios/Flutter/Signing.xcconfig`:

```
DEVELOPMENT_TEAM = <your 10-character Team ID>
```

`ios/Flutter/Debug.xcconfig` and `Release.xcconfig` include it with the
optional `#include?`, so a checkout without it still builds. Profile uses the
Release one. Check that it took:
`xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -showBuildSettings | grep DEVELOPMENT_TEAM`.

Choosing a team in Xcode's Signing & Capabilities tab writes
`DEVELOPMENT_TEAM` back into `project.pbxproj`. Move it back into
`Signing.xcconfig` when that happens; `dart run tool/shareable.dart` fails
until you do.

## 2. Version

Bump `version:` in `pubspec.yaml` (`name+build`: the build number must grow
on every upload) **and** `AppInfo.version` in `lib/core/app_info.dart` to the
same name. `test/core/app_info_test.dart` fails if they disagree.

## 3. Gates

```sh
flutter analyze                       # 0 issues
flutter test                          # full suite green
dart run tool/content.dart            # 0 errors (lessons, puzzles, manifests, the 240 Studio games)
dart run tool/translations.dart       # 0 errors
dart run tool/app_check.dart          # clean
dart run tool/lint_lessons.dart       # 0 errors (flags are triaged, see below)
dart run tool/lint_puzzles.dart       # 0 errors (flags are triaged, see below)
dart run tool/puzzles.dart check      # 0 errors (flags are triaged, see below)
dart run tool/shareable.dart          # 0 errors: nothing personal or machine-specific is published
python3 tool/website.py --check       # the website matches the policy and the screenshots
flutter drive --driver=test/device/driver.dart --target=test/device/engine_smoke.dart -d <device>
flutter drive --driver=test/device/driver.dart --target=test/device/app_flow.dart -d <device>
```

The three prose/chess linters were missing from this list, so a release could
go out green while the corpus regressed. Their **errors must be zero**; their
flags are expected and every one is triaged in `docs/content-audit.md` —
compare the counts against the ones recorded there rather than reading each
flag again.

## 4. Builds

The first build of each platform downloads the NNUE network (~94 MB) and
**verifies** it against the SHA-256 prefix in its name. Stockfish 19 retired
the second (small) net, so there is one to fetch. Android caches it in
`packages/karpa_engine/.nnue/`; iOS and macOS keep it in the Pods directory.

```sh
# Android — App Bundle for Play
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/android

# iOS — archive for App Store Connect
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ios
```

Keep `build/symbols/` for every uploaded build. Obfuscated stack traces can
only be read back with the symbols of that exact build
(`flutter symbolize`).

The App Bundle also carries native debug symbols
(`ndk.debugSymbolLevel = "FULL"` in `android/app/build.gradle.kts`), so
Play Console can symbolicate a crash in the Stockfish library. They are
uploaded, never delivered to devices. `FULL`, not `SYMBOL_TABLE`:
SYMBOL_TABLE keeps every non-debug section, including the engine's ~98 MB
embedded net, so the bundle was 542 MB. With FULL it is ~400 MB, and it
gains file and line numbers.

Measured on 2026-09-23:
- The per-device download is ~98 MB (limit 200 MB).
- Every 64-bit library is 16 KB-aligned.
- The arm64 engine has 0 dot-product instructions.

Before the first Android build, you can seed the net cache with the copy
`tool/build_host.sh` already verified. CMake re-hashes it anyway.

```sh
mkdir -p packages/karpa_engine/.nnue
cp packages/karpa_engine/stockfish/src/nn-1a298aa575a0.nnue packages/karpa_engine/.nnue/
```

Check what goes to Play. Paths below assume the default SDK location and
NDK r28.2. bundletool is optional: the checks read the bundle directly.

```sh
NDK=~/Library/Android/sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin
mkdir -p build/release_check && unzip -o -q build/app/outputs/bundle/release/app-release.aab -d build/release_check

# Portable engine: no dot-product instructions, which crash older ARM cores.
$NDK/llvm-objdump -d build/release_check/base/lib/arm64-v8a/libkarpa_engine.so | grep -cE '\b[su]dot\b'   # must print 0

# 16 KB pages (enforced for updates from 2027-02-01): every LOAD segment of
# every 64-bit library must say align 2**14.
for so in build/release_check/base/lib/*64*/*.so; do
  echo "$so"; $NDK/llvm-objdump -p "$so" | grep LOAD
done

# Per-device size: Play's limit is 200 MB compressed per device.
flutter build apk --release --split-per-abi
~/Library/Android/sdk/build-tools/37.0.0/zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | tail -1
~/Library/Android/sdk/cmdline-tools/latest/bin/apkanalyzer apk download-size build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 5. Store forms

Today's platform floors are met by the toolchain this repository is built
with:
- **Apple:** uploads must be built with Xcode 26 and the iOS 26 SDK
  (since 2026-04-28), and target iOS 13 or later. This app targets 14.0
  (developer.apple.com/news/upcoming-requirements).
- **Google Play:** new apps and updates must target Android 16, API 36 (since
  2026-08-31). Flutter 3.44 sets that
  (developer.android.com/google/play/requirements/target-sdk).

- **Privacy policy URL, in both consoles**: `AppInfo.privacyUrl`. See step 0.
- **Google Play, App content**:
  - **Data safety**: no data collected, no data shared.
  - **Content rating**: the IARC questionnaire (no violence, no user
    interaction, no purchases).
  - **Target audience**: pick the age groups you mean. Including under-13s
    brings the Families policy into play; the app already meets it, since it
    has no ads and collects nothing.
  - **Ads**: no. **App access**: everything is available without an account.
- **App Store Connect › App Information › License Agreement**: replace
  Apple's standard EULA with `docs/EULA.md`, after legal review and with
  your details filled in. The same agreement applies to the macOS listing.
- **App Store, App Privacy**: Data Not Collected. Encryption: the app uses
  none (`ITSAppUsesNonExemptEncryption` is already `false` in
  `ios/Runner/Info.plist`). The engine's privacy manifest ships in the
  `karpa_engine` pod.
- **App Store, Age Rating**: Apple's age-rating system changed in 2026.
  Answer the new questionnaire in App Store Connect, or submissions stop.
  There is no user-generated content shared with others, no web access and no
  chat.
- Languages: the iOS binary declares all twelve (`CFBundleLocalizations`).
  Add the matching store listings, in Portuguese (Portugal) and Chinese
  (Simplified).

### Store screenshots

`sh tool/store_screenshots.sh [ios|android|all]` shoots the set on simulators
with `test/device/store_screenshots.dart` — a learner a few weeks in, seeded
through the app's own repositories, with Stockfish 19 answering for real —
then `tool/store_screenshots.py` checks every capture against its store's
rules and files it. `screenshots/` holds the publishing sets and nothing else;
the raw captures stay in `build/screenshots/raw/`. The website shows the App
Store sets too: run `python3 tool/website.py` after re-shooting them. For Android, start the
emulator first; the script resizes its display for each set and always resets
it.

| Folder | Device | Size | Shots |
|---|---|---|---|
| `screenshots/ios/iphone-6.9/` | iPhone 17 Pro Max | 1320×2868 | 10 |
| `screenshots/ios/iphone-6.5/` | derived from the 6.9" set | 1284×2778 | 10 |
| `screenshots/ios/ipad-13/` | iPad Pro 13-inch (M5), portrait | 2064×2752 | 10 |
| `screenshots/android/android-phone/` | emulator at 1080×1920 | 1080×1920 | 8 |
| `screenshots/android/android-tablet/` | emulator at 1440×2560, portrait | 1440×2560 | 8 |

The ten, in order: Learn home · a lesson (the Greek gift, its four king moves
drawn as arrows) · the puzzle trainer · Play against Stockfish · the coach's
hint · Review · the Studio library · the Studio's brilliancy (Réti–Tartakower,
Vienna 1910, 9.Qd8+!!) · the drawing tools (its "Mate in 3!" label is proven by
`dart run tool/puzzles.dart prove`) · Settings. Google Play takes at most
eight per device type, so the Android folders hold shots 1–4, 6 and 8–10,
renumbered 01–08 in upload order (`PLAY_SET` in the filer); the App Store
takes all ten. iPadOS ignores an app's orientation request while the app
supports multitasking, so the iPad set is portrait, which the App Store
accepts at the same size class. The Android tablet set is portrait too:
turned landscape, the emulated phone's camera cutout moves to a side the app
may not draw into before Android 15, so the capture would fall short of 16:9.

App Store Connect may ask for the iPhone 6.5" slot instead of the 6.9" one:
Apple requires a 6.5" set whenever no 6.9" set is provided. The 6.5" set is
never shot. The filer derives it from the filed 6.9" set:
- it removes the 12 rows the taller 6.5" frame has no room for;
- they come from the empty band under the status bar, and the filer checks
  that every removed row is blank;
- it then scales the image down to 1284×2778.

Upload whichever set the slot asks for.

The rules the filer checks:
- App Store: the exact sizes above, no alpha channel
  (developer.apple.com/help/app-store-connect/reference/screenshot-specifications).
- Google Play: PNG or JPEG without alpha, 320–3840 px a side, the long side
  at most twice the short one, and at least 1080 px at 9:16 or 16:9 for
  promotion (support.google.com/googleplay/android-developer/answer/9866151).

## 6. Device checks before release

- An **ARMv8.0 Android phone** (Cortex-A53, e.g. a Snapdragon 4xx or Helio
  G25/P22 device) and an **iPhone XS or older**: play a game and open
  Review. The engine must answer.
- Android 16 (API 36): the system back gesture from a lesson, a puzzle run,
  the Studio and a game in progress.
- Arabic (right to left) end to end, including the text-selection menu in
  the Studio import field.
- Largest system text size (the app clamps at 1.3×) on a small phone.
- iPad Split View and Slide Over, and macOS window resizing.
- Music playing in another app during a game: move sounds must mix with it,
  not stop it.
- Update over a previous build: the avatar, Studio photos, the imported
  library and progress all survive.
- Background the app while Stockfish is thinking in Play, then return.
  Stockfish still moves; the engine is held, not cancelled. Do the same
  during a Review scan and in the Studio.
- Import a PGN set up on an impossible position, for example
  `[FEN "8/8/8/8/8/8/8/K7 w - - 0 1"]`. The import sheet refuses it, and the
  app keeps running. Stockfish 19 exits its process — the app — on such a
  position, which is why nothing reaches it without `EnginePosition`.
- Repeat a position three times in Play (a knight out and back, twice). The
  game ends drawn by threefold repetition.
- Casual plays weaker than Club, and Club weaker than Full strength.
- Settings › About › Privacy policy opens the notice in the reader's language.
