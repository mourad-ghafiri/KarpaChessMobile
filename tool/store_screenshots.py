#!/usr/bin/env python3
"""Checks and files the store screenshots.

`test/device/store_screenshots.dart`, run through `tool/store_screenshots.sh`,
leaves raw captures in `build/screenshots/raw/<device>/<NN-name>.png`. This
script:

- flattens each to RGB, because both stores reject an alpha channel;
- checks its size against what that store accepts for the device class;
- writes it to `screenshots/<store>/<device>/<NN-name>.png`.

`screenshots/` holds the publishing sets and nothing else. The script never
deletes: a PNG already in a store folder that is not part of the set it files
stops it, naming the stray to remove.

Google Play takes at most eight screenshots per device type and the harness
shoots ten, so the Android folders get the eight in PLAY_SET, renumbered 01-08
in upload order; the App Store takes all ten.

Some sets are not shot at all but derived from a filed one (DERIVED): App
Store Connect asks for a 6.5" iPhone set whenever it is not given a 6.9" one,
and the 6.5" set is the 6.9" captures fitted to its frame.

It exits non-zero on the first capture that fails a rule. The sizes come from:
- Apple: developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Google Play: support.google.com/googleplay/android-developer/answer/9866151

Needs Pillow, like tool/gen_icon.py.
"""

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / 'build' / 'screenshots' / 'raw'
OUT = ROOT / 'screenshots'

# Apple accepts exact sizes only.
APPLE = {
    # iPhone 6.9" display. Required unless 6.5" is supplied; covers every
    # smaller iPhone by scaling.
    'iphone-6.9': [(1320, 2868), (2868, 1320), (1290, 2796), (2796, 1290),
                   (1260, 2736), (2736, 1260)],
    # iPhone 6.5" display. Required when the 6.9" set is not provided, and
    # the slot App Store Connect may show instead. Derived, see DERIVED.
    'iphone-6.5': [(1284, 2778), (2778, 1284), (1242, 2688), (2688, 1242)],
    # iPad 13" display. Required, since the app runs on iPad.
    'ipad-13': [(2064, 2752), (2752, 2064), (2048, 2732), (2732, 2048)],
}

# Sets made from a filed set instead of from captures: device -> (the filed
# device it comes from, its size). The 6.5" frame is a little taller for its
# width than the 6.9" one (1284:2778 against 1320:2868), so each capture loses
# the rows the frame has no room for, then scales down to fit exactly.
# The rows come off the TOP: the empty band under the status bar, as tall
# as the safe area, which never holds content. derive() checks that every
# row it removes is a single colour, and stops rather than crop into the app.
DERIVED = {
    'iphone-6.5': ('iphone-6.9', (1284, 2778)),
}

# Google Play: 320-3840 px per side, and the long side at most twice the
# short one. For large-format promotion: at least 1080 px, and 9:16 or 16:9.
PLAY = {
    'android-phone': 1080,
    'android-tablet': 1080,
}

# Google Play's eight, in upload order: the coach hint (a toast over the Play
# screen) and the Studio library (a list) give way to the screens that show
# more of the app.
PLAY_SET = [
    '01-learn',
    '02-lesson',
    '03-puzzles',
    '04-play',
    '06-review',
    '08-studio-analysis',
    '09-studio-drawing',
    '10-personalize',
]


def check_play(size, minimum):
    w, h = size
    short, long_ = min(w, h), max(w, h)
    if not (320 <= short and long_ <= 3840):
        return f'{w}x{h}: each side must be 320-3840 px'
    if long_ > 2 * short:
        return f'{w}x{h}: the long side is more than twice the short side'
    if short < minimum:
        return f'{w}x{h}: under {minimum} px on the short side'
    if long_ * 9 != short * 16:
        return f'{w}x{h}: not 9:16 or 16:9'
    return None


def blank_rows(image, rows):
    """Whether every one of [rows] is a single colour (within 2 per
    channel), the empty band a crop may remove."""
    px = image.load()
    ref = px[image.width // 2, rows[0]]
    return all(
        max(abs(a - b) for a, b in zip(px[x, y], ref)) <= 2
        for y in rows for x in range(0, image.width, 3))


def derive():
    made = 0
    for device, (source, (width, height)) in DERIVED.items():
        source_dir = OUT / 'ios' / source
        shots = sorted(source_dir.glob('*.png'))
        if not shots:
            sys.exit(f'{device}: nothing filed in {source_dir.relative_to(ROOT)}')
        target_dir = OUT / 'ios' / device
        if target_dir.is_dir():
            wanted = {shot.name for shot in shots}
            strays = sorted(p.name for p in target_dir.iterdir()
                            if p.name not in wanted)
            if strays:
                sys.exit(f'{target_dir.relative_to(ROOT)}: not in the set, '
                         f'remove first: {", ".join(strays)}')
        for shot in shots:
            image = Image.open(shot).convert('RGB')
            if image.width > image.height:
                sys.exit(f'{source}/{shot.name}: landscape; only portrait '
                         f'sets are derived')
            # The height this width keeps at the target's proportions.
            keep = round(image.width * height / width)
            extra = image.height - keep
            if extra < 0:
                sys.exit(f'{source}/{shot.name}: too short for {device}')
            if extra and not blank_rows(image, range(extra)):
                sys.exit(f'{source}/{shot.name}: the top {extra} rows are not '
                         f'empty, so {device} cannot be cut from it')
            fitted = image.crop((0, extra, image.width, image.height)).resize(
                (width, height), Image.LANCZOS)
            if fitted.size not in APPLE[device]:
                sys.exit(f'{device}/{shot.name}: {fitted.size} is not accepted')
            target = target_dir / shot.name
            target.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(target, optimize=True)
            made += 1
            print(f'ios/{device}/{shot.name}  {width}x{height}  '
                  f'(from {source}, top {extra} rows cut)')
    return made


def main():
    if not RAW.is_dir():
        sys.exit(f'nothing to file: {RAW} does not exist')
    filed = 0
    for device_dir in sorted(p for p in RAW.iterdir() if p.is_dir()):
        device = device_dir.name
        if device in DERIVED:
            sys.exit(f'{device}: derived from {DERIVED[device][0]}, never '
                     f'captured; remove {device_dir.relative_to(ROOT)}')
        if device in APPLE:
            store = 'ios'
        elif device in PLAY:
            store = 'android'
        else:
            sys.exit(f'{device}: unknown device class')
        raws = sorted(device_dir.glob('*.png'))
        if device in PLAY:
            by_name = {raw.stem: raw for raw in raws}
            missing = [name for name in PLAY_SET if name not in by_name]
            if missing:
                sys.exit(f'{device}: missing {", ".join(missing)}')
            # (source, the name it is filed under)
            picks = [
                (by_name[name], f'{i:02d}-{name.split("-", 1)[1]}.png')
                for i, name in enumerate(PLAY_SET, 1)
            ]
        else:
            picks = [(raw, raw.name) for raw in raws]
        target_dir = OUT / store / device
        if target_dir.is_dir():
            wanted = {filed_name for _, filed_name in picks}
            strays = sorted(p.name for p in target_dir.iterdir()
                            if p.name not in wanted)
            if strays:
                sys.exit(f'{target_dir.relative_to(ROOT)}: not in the set, '
                         f'remove first: {", ".join(strays)}')
        for raw, filed_name in picks:
            image = Image.open(raw)
            if device in APPLE:
                problem = (None if image.size in APPLE[device]
                           else f'{image.size[0]}x{image.size[1]}: not an '
                                f'accepted {device} size')
            else:
                problem = check_play(image.size, PLAY[device])
            if problem:
                sys.exit(f'{device}/{raw.name}: {problem}')
            target = target_dir / filed_name
            target.parent.mkdir(parents=True, exist_ok=True)
            image.convert('RGB').save(target, optimize=True)
            filed += 1
            print(f'{store}/{device}/{filed_name}  {image.size[0]}x{image.size[1]}')
    filed += derive()
    print(f'filed {filed} screenshot(s)')


if __name__ == '__main__':
    main()
