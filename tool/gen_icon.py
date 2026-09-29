#!/usr/bin/env python3
"""Generates the KarpaChess launcher icon for every platform.

The mark is the chess knight from the app's own board wearing a graduation
cap: chess, plus learning. The knight is the Classic set's, rendered by
`tool/gen_pieces.py`, the same drawing `KarpaBoard` shows by default. It is
KarpaChess's own art (CC0), so the icon and the board stay one character.

The mortarboard is DRAWN here, in the piece's own visual language, so the
two read as one illustration rather than an icon stuck onto a drawing:

  * the knight's outline (#3C3C3C, 2.6% of its width) on every silhouette,
    and the thinner stroke the pieces use for seams inside a shape;
  * flat fills with one shade, lit from the front-left as the knight is —
    a lit top face, a darker board edge, the skullcap in the board's shade,
    a glint on the lit rim like the knight's own white highlight;
  * a warm gold tassel on a cord from the button, hanging by gravity.

It is WORN, not balanced on top: everything is anchored to the knight's
measured anatomy, in fractions of the knight image, so the fit survives any
resize. The skullcap's bottom edge IS the knight's crown contour (sampled
from its alpha), so the cap seats on the head wherever the head curves; it
sits on the poll just behind the ear, which stays in front of it; and the
board tilts back with the crest (which slopes ~25°), a little less than the
head does, so it rests rather than slides.

The whole mark — knight and cap — is then placed by one balance rule: scaled
to MARK_H of the canvas, with the mean of its bounding-box centre and its
visual centroid on the canvas centre (nudged by MARK_DY).

Only the background is generated from the palette, so the icon tracks the
default theme (Midnight Grove). Re-run after changing the palette:

    python3 tool/gen_icon.py

Writes the 1024 master plus every size iOS, Android and macOS declare, and
the iOS launch image: the mark alone, without the icon's field, which
`ios/Runner/Base.lproj/LaunchScreen.storyboard` centres on the default
theme's `bg` so the launch hands over to the app's first frame without a
change of colour.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import gen_pieces

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --- Midnight Grove -------------------------------------------------------
# Straight off the default palette in lib/core/theme/themes.dart. The field
# is the theme's own surface ladder, top plane to page, which is why the
# icon and the app it opens read as the same material.
BG_TOP = (41, 48, 42)      # #29302A  `raised` — the lit top of the field
BG_BOTTOM = (9, 19, 11)    # #09130B  `bg` — deep shade at the bottom
ACCENT = (121, 187, 116)   # #79BB74  `accent` — leaf green

# --- the cap, in the knight's language ------------------------------------
OUTLINE = (60, 60, 60)      # #3C3C3C — the knight's own outline
KNIGHT_SHADE = (204, 204, 204)  # #CCCCCC — the knight's own shade
CAP_TOP = (137, 224, 131)   # #89E083 `highlight` — the lit top face
CAP_GLINT = (190, 243, 186)  # the lit rim, as the knight's white highlight
CAP_EDGE = (79, 138, 75)    # the board's thickness, facing the viewer
CAP_BAND = (95, 162, 90)    # the skullcap, in the board's shade
GOLD = (232, 190, 85)       # tassel — the palette's #C9A45C, lifted to read
GOLD_SHADE = (196, 152, 58)  # the tassel's knot

MASTER = 1024
SS = 2  # supersample the composite so downsizing stays clean

KNIGHT_SPACE = 2048  # the knight is drawn at this size, straight from its curves

# --- the cap's geometry, in fractions of the knight image -----------------
# From the Classic knight's own curves (gen_pieces.KNIGHT, drawn 0.014 left
# of its pedestal for optical centring): its one ear's tip is at
# (0.356, 0.112) and the poll behind it at (0.456, 0.19), from where the
# crest falls through (0.68, 0.288), about 25°.
STROKE = 0.026        # the knight's outline width
INNER = 0.6           # seams inside a shape: this share of STROKE
SMALL = 0.7           # cord and tassel: this share of STROKE
ANCHOR_U = 0.535      # the skullcap's centre on the crest, just behind the ear
TILT = 20.0           # degrees, back side down: with the crest, but less
LIFT = 0.115          # board centre above the crest
BOARD_W, BOARD_H, BOARD_T = 0.40, 0.165, 0.034  # diamond width/height, slab
BAND_FRONT, BAND_BACK = 0.095, 0.105  # skullcap reach either side of centre
BAND_TOP = 0.03       # where the skullcap meets the board's underside
BAND_DROP = 0.024     # below the crown line, so it covers the head's outline
CONTACT_SHADE = 0.030  # the cap's shade on the crown, under the skullcap
BUTTON_R = 0.020
CORD_W, CORD_LEN = 0.016, 0.105
TASSEL_W, TASSEL_H = 0.060, 0.092

# --- balance --------------------------------------------------------------
MARK_H = 0.68    # the whole mark's height, as a share of the canvas
MARK_DY = 0.010  # optical nudge: a mark with a heavy base reads best a hair low


def _lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _field(size: int) -> Image.Image:
    """Deep forest ramp with a pool of light behind the mark's body."""
    img = Image.new("RGB", (size, size), BG_TOP)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        draw.line([(0, y), (size, y)],
                  fill=_lerp(BG_TOP, BG_BOTTOM, (y / size) ** 1.25))

    glow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glow).ellipse(
        [size * 0.10, size * 0.36, size * 0.90, size * 0.94], fill=58)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.14))
    img.paste(Image.new("RGB", (size, size), ACCENT), (0, 0), glow)
    return img


def _rot(p, deg):
    """Rotates [p] by [deg] in image space (y down): positive tips the right
    side down."""
    a = math.radians(deg)
    return (p[0] * math.cos(a) - p[1] * math.sin(a),
            p[0] * math.sin(a) + p[1] * math.cos(a))


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _mark() -> Image.Image:
    """The knight wearing the cap, on a transparent canvas in knight space."""
    k = KNIGHT_SPACE
    knight = gen_pieces.render_piece("classic", "wN", size=k, ss=2)
    kpx = knight.split()[-1].load()

    def crown(u):
        """The knight's top edge at [u]: the first opaque row."""
        x = min(k - 1, max(0, round(u * k)))
        for y in range(k):
            if kpx[x, y] > 128:
                return y / k
        return 1.0

    # The cap rises above the knight's own square, so the canvas has a
    # margin on every side; knight fractions map into it through px().
    pad = round(0.3 * k)
    size = k + 2 * pad

    def px(pt):
        return (pad + pt[0] * k, pad + pt[1] * k)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(knight, (pad, pad))
    bare = layer.copy()
    draw = ImageDraw.Draw(layer)
    stroke = STROKE * k

    def outline(points, *, closed=True, width=stroke, colour=OUTLINE):
        """A stroke centred on the path with round joins — the pieces' line."""
        pts = [px(q) for q in points]
        seq = pts + ([pts[0]] if closed else [])
        for a, b in zip(seq, seq[1:]):
            draw.line([a, b], fill=colour, width=round(width))
        r = width / 2
        for q in pts:
            draw.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=colour)

    def fill(points, colour):
        draw.polygon([px(q) for q in points], fill=colour)

    # --- the cap's frame: centred over the crown, tilted with it -----------
    anchor = (ANCHOR_U, crown(ANCHOR_U))
    centre = _add(anchor, _rot((0, -LIFT), TILT))

    def local(x, y):
        return _add(centre, _rot((x, y), TILT))

    bw, bh = BOARD_W / 2, BOARD_H / 2
    left, back, right, front = local(-bw, 0), local(0, -bh), local(bw, 0), local(0, bh)
    left_d, front_d, right_d = (_add(q, (0, BOARD_T)) for q in (left, front, right))

    # --- the skullcap: sides fall along the cap's own "down" until they
    # meet the head; its bottom edge is the crown contour itself ------------
    down = _rot((0, 1), TILT)

    def foot(x_local):
        top = local(x_local, BAND_TOP)
        for i in range(4 * k):
            q = _add(top, (down[0] * i / k, down[1] * i / k))
            if q[1] >= crown(q[0]) + BAND_DROP:
                return top, q
        return top, top

    band_ft, band_ff = foot(-BAND_FRONT)
    band_bt, band_bf = foot(BAND_BACK)
    steps = 48
    seat = [(band_ff[0] + (band_bf[0] - band_ff[0]) * i / steps,)
            for i in range(steps + 1)]
    seat = [(u[0], crown(u[0]) + BAND_DROP) for u in seat]
    band = [band_ft, band_ff] + seat[1:-1] + [band_bf, band_bt]

    # --- the cap's shade on the crown: the knight's own grey, only where
    # the knight is lit fill, in a strip just under the skullcap ------------
    lit = Image.new("L", (size, size), 0)
    lit_px, bare_px = lit.load(), bare.load()
    x0, x1 = int(px(band_ff)[0]) - 5, int(px(band_bf)[0]) + 5
    for x in range(max(0, x0), min(size, x1)):
        for y in range(size):
            r, g, b, a = bare_px[x, y]
            if a > 250 and min(r, g, b) > 225:
                lit_px[x, y] = 255
    strip = Image.new("L", (size, size), 0)
    ImageDraw.Draw(strip).polygon(
        [px(q) for q in seat + [(u, v + CONTACT_SHADE) for u, v in reversed(seat)]],
        fill=255)
    layer.paste(Image.new("RGBA", (size, size), (*KNIGHT_SHADE, 255)), (0, 0),
                ImageChops.multiply(strip, lit))
    draw = ImageDraw.Draw(layer)

    # --- back to front. The pieces stroke silhouettes thick and seams thin:
    # fills first, then the seam, then the outline ------------------------
    fill(band, CAP_BAND)
    outline(band)
    fill([left, front, right, right_d, front_d, left_d], CAP_EDGE)
    fill([left, back, right, front], CAP_TOP)
    outline([left, front, right], closed=False, width=stroke * INNER)
    inset = 0.028  # the glint, just inside the lit back-left rim
    outline([local(-bw + inset * 1.9, 0), local(-inset * 0.35, -bh + inset)],
            closed=False, width=stroke * 0.45, colour=CAP_GLINT)
    outline([left, back, right, right_d, front_d, left_d])

    # The cord runs from the button to the back corner, then hangs straight
    # down — gravity, not the board's tilt.
    hang = _add(right, (0, CORD_LEN))
    cord = [centre, right, hang]
    cord_w = CORD_W * k
    outline(cord, closed=False, width=cord_w + stroke * SMALL)
    outline(cord, closed=False, width=cord_w, colour=GOLD)

    tw = TASSEL_W / 2
    knot = [_add(hang, (-tw * 0.55, -0.004)), _add(hang, (tw * 0.55, -0.004)),
            _add(hang, (tw * 0.55, 0.022)), _add(hang, (-tw * 0.55, 0.022))]
    skirt_top = _add(hang, (0, 0.022))
    skirt = [_add(skirt_top, (-tw * 0.60, 0)), _add(skirt_top, (tw * 0.60, 0)),
             _add(skirt_top, (tw, TASSEL_H)), _add(skirt_top, (-tw, TASSEL_H))]
    fill(skirt, GOLD)
    outline(skirt, width=stroke * SMALL)
    fill(knot, GOLD_SHADE)
    outline(knot, width=stroke * SMALL * 0.8)

    c, r = px(centre), BUTTON_R * k
    draw.ellipse([c[0] - r - stroke / 2, c[1] - r - stroke / 2,
                  c[0] + r + stroke / 2, c[1] + r + stroke / 2], fill=OUTLINE)
    draw.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=GOLD)
    return layer


def _placed(mark: Image.Image, size: int) -> Image.Image:
    """The mark on a [size] canvas, balanced.

    Scaled to MARK_H of the canvas; the mean of its bounding-box centre and
    its visual centroid goes to the centre (plus MARK_DY). The box alone
    would let the long muzzle pull the knight left; the centroid alone
    would let the heavy base pull it up.
    """
    crop = mark.crop(mark.split()[-1].getbbox())
    thumb = crop.split()[-1].resize((256, round(256 * crop.height / crop.width)))
    tpx = thumb.load()
    total = sx = sy = 0
    for y in range(thumb.height):
        for x in range(thumb.width):
            w = tpx[x, y]
            if w:
                total += w
                sx += w * x
                sy += w * y
    cx, cy = sx / total / thumb.width, sy / total / thumb.height
    h = MARK_H * size
    w = h * crop.width / crop.height
    art = crop.resize((round(w), round(h)), Image.Resampling.LANCZOS)
    left = size * 0.5 - (0.5 + cx) / 2 * w
    top = size * (0.5 + MARK_DY) - (0.5 + cy) / 2 * h
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(art, (round(left), round(top)), art)
    return layer


def master(size: int = MASTER, *, safe_zone: bool = False,
           mark: Image.Image | None = None) -> Image.Image:
    """The full icon. [safe_zone] shrinks the art to the 66% Android
    adaptive-icon keyline so launcher masks never clip the mark."""
    big = size * SS
    img = _field(big)
    art = _placed(mark or _mark(), big)
    if safe_zone:
        scaled = round(big * 0.66)
        art = art.resize((scaled, scaled), Image.Resampling.LANCZOS)
        pad = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        off = (big - scaled) // 2
        pad.paste(art, (off, off), art)
        art = pad
    out = Image.alpha_composite(img.convert("RGBA"), art)
    return out.resize((size, size), Image.Resampling.LANCZOS)


def _write(img: Image.Image, path: str, *, opaque: bool) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if opaque else img).save(path, "PNG")


def _resized(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


IOS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-50x50@1x.png": 50,
    "Icon-App-50x50@2x.png": 100, "Icon-App-57x57@1x.png": 57,
    "Icon-App-57x57@2x.png": 114, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-72x72@1x.png": 72,
    "Icon-App-72x72@2x.png": 144, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS = {
    "app_icon_16.png": 16, "app_icon_32.png": 32, "app_icon_64.png": 64,
    "app_icon_128.png": 128, "app_icon_256.png": 256,
    "app_icon_512.png": 512, "app_icon_1024.png": 1024,
}

# The launch image: the mark, LAUNCH_PT points tall, at each screen scale.
# The storyboard draws it at its own size, centred, so the points are what
# the reader sees on every iPhone and iPad.
LAUNCH_PT = 128
IOS_LAUNCH = {"LaunchImage.png": 1, "LaunchImage@2x.png": 2, "LaunchImage@3x.png": 3}

ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ANDROID_FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def _launch(mark: Image.Image, scale: int) -> Image.Image:
    """The mark cropped to its ink, LAUNCH_PT points tall at [scale]."""
    crop = mark.crop(mark.split()[-1].getbbox())
    # Whole points first, so every scale is an exact multiple of 1x.
    width_pt = round(crop.width * LAUNCH_PT / crop.height)
    return crop.resize((width_pt * scale, LAUNCH_PT * scale),
                       Image.Resampling.LANCZOS)


def main() -> None:
    mark = _mark()
    full = master(mark=mark)
    safe = master(safe_zone=True, mark=mark)

    _write(full, os.path.join(ROOT, "assets/images/icon.png"), opaque=True)

    ios_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    for name, size in IOS.items():
        _write(_resized(full, size), os.path.join(ios_dir, name), opaque=True)

    launch_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/LaunchImage.imageset")
    for name, scale in IOS_LAUNCH.items():
        _write(_launch(mark, scale), os.path.join(launch_dir, name), opaque=False)

    mac_dir = os.path.join(ROOT, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    for name, size in MACOS.items():
        _write(_resized(full, size), os.path.join(mac_dir, name), opaque=False)

    res = os.path.join(ROOT, "android/app/src/main/res")
    for density, size in ANDROID_LEGACY.items():
        _write(_resized(full, size),
               os.path.join(res, f"mipmap-{density}/ic_launcher.png"), opaque=True)
    for density, size in ANDROID_FOREGROUND.items():
        _write(_resized(safe, size),
               os.path.join(res, f"drawable-{density}/ic_launcher_foreground.png"),
               opaque=False)

    total = (1 + len(IOS) + len(IOS_LAUNCH) + len(MACOS) + len(ANDROID_LEGACY)
             + len(ANDROID_FOREGROUND))
    print(f"wrote {total} icon files")


if __name__ == "__main__":
    main()
