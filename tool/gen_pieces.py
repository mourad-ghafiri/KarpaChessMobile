#!/usr/bin/env python3
"""Generates KarpaChess's chess pieces: ten original sets.

    classic     Staunton forms; flat fill, one shade, a lit edge, grey line
    wood        the Staunton forms turned in boxwood and rosewood
    marble      a slender Staunton on a stepped pedestal, in polished stone
    diagram     the Staunton forms as a chess-book diagram: paper and ink
    modern      the pieces reduced to geometry; two-tone, a fine line
    deco        Art Deco: steps, flutes, a sunburst queen, gold lines
    facet       low-poly: straight edges, planar facets
    silhouette  told apart by outline alone; no line inside
    soft        rounded river-stone forms, lit like pillows, a warm grey line
    bold        chunky toy-like forms and a thick line, for small phones

Every king wears the arched crown players know: two round arches over a
banded brim, parted by a bulb that carries the cross. The five sets added
after the first five (marble to soft) set a cut gem between the arches
instead of the bulb and cross, so their king carries no religious symbol.
The gem is broad and set into the crown (`gem_crown`): perched on a neck, a
gem's post and girdle read as a small cross at thumbnail size.

Every piece here is drawn from scratch: outlines are Bézier and arc control
points, and Hobby splines through landmarks, all in this file, after the
public-domain 1849 Staunton pattern and plain geometry. Nothing is traced
from, or fitted to, another piece set. The artwork is dedicated to the public
domain under CC0 1.0 (assets/pieces/LICENSE).

How a piece is drawn
--------------------
A *family* gives each piece's geometry in the unit square, y down, as a
`Shape`: closed `Part`s listed back to front (each says how it is lit: turned
about the axis, a sphere, or a free volume), plus seams, dots, slits and
glints. Every family puts the silhouette's lowest point on 0.90.

A *style* colours a shape and draws its lines. Every part outline is split
into runs, and each run is classified as

  EDGE    on the piece's silhouette: drawn at the full outline weight,
  INNER   a part crossing another (a collar over a stem): lighter, thinner,
  HIDDEN  under a later part: not drawn at all.

Light comes from the top left, for every part of every piece: one model
(`Material`) shades turned parts, spheres and free volumes alike.

Pixels
------
Each piece is painted once onto a 3072 px canvas and reduced by exact area
averaging (Pillow's `reduce`, alpha premultiplied) to 512, 384, 256 and 128
px: true coverage anti-aliasing, and none of the light/dark halos a LANCZOS
resample leaves along every edge. Written as lossless WebP into
assets/pieces/<set>/ with chessground's 2.0x/3.0x/4.0x layout. Deterministic:
re-running without changes leaves git clean.

The quality gate
----------------
Nothing is written unless every piece of every selected set passes `audit`:
one baseline, the height ladder, optical centring, silhouettes that tell the
six pieces apart at 24 px, contrast calm enough for long sessions yet visible
on all ten square colours, one connected silhouette, curves without
unintended kinks (`Path.corner()` declares the deliberate ones), every piece
at the mass its set's knight sets (`MASS`, `CROWN_W`), and a knight with the
chess knight's shape: an open V under the jaw, a forward-leaning chest
(`knight_form`).

    python3 tool/gen_pieces.py                  # audit, then write every set
    python3 tool/gen_pieces.py --check          # audit only
    python3 tool/gen_pieces.py --only wood --review DIR [--draft]

Needs Pillow. `tool/gen_icon.py` takes its knight from here (the Classic
knight), so the launcher icon and the board are one character.
"""

from __future__ import annotations

import argparse
import math
import os
import sys
from dataclasses import dataclass, field

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pieces")

MASTER_PX = 3072  # 512 x 6 = 384 x 8 = 256 x 12 = 128 x 24
RESOLUTIONS = (("", 128), ("2.0x", 256), ("3.0x", 384), ("4.0x", 512))
CODES = [c + k for c in "wb" for k in "KQRBNP"]
ROLE = dict(K="king", Q="queen", R="rook", B="bishop", N="knight", P="pawn")


# =============================================================== geometry

_PATHS = []  # every Path built while a shape is drawn, for the kink audit


def bez(p0, p1, p2, p3, n):
    """[n] points along a cubic Bézier, excluding its start."""
    pts = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return pts


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _unit(v):
    n = math.hypot(v[0], v[1])
    return (v[0] / n, v[1] / n) if n > 1e-12 else None


def _same(a, b, eps=1e-9):
    return abs(a[0] - b[0]) < eps and abs(a[1] - b[1]) < eps


def _wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def _velocity(st, ct, sf, cf):
    """Hobby's control-arm length for a curve leaving at angle t, arriving at
    angle f (sines and cosines given), as a fraction of the chord."""
    num = 2 + math.sqrt(2) * (st - sf / 16) * (sf - st / 16) * (ct - cf)
    den = 3 * (1 + 0.5 * (math.sqrt(5) - 1) * ct + 0.5 * (3 - math.sqrt(5)) * cf)
    return min(4.0, num / den)


def hobby(z, d0=None, d1=None):
    """John Hobby's spline (METAFONT's `..`) through the points [z]: the
    cubic segments [(c1, c2, p)] whose curvature varies as evenly as the
    points allow. [d0] and [d1] are optional directions at the two ends; a
    free end curls. Curves drawn this way need only a few well-placed points,
    and come out without the wobble of hand-placed control arms."""
    n = len(z) - 1
    chord = [_sub(z[i + 1], z[i]) for i in range(n)]
    d = [math.hypot(*c) for c in chord]
    ang = [math.atan2(c[1], c[0]) for c in chord]
    psi = [0.0] * (n + 1)          # the turn at each inner point
    for i in range(1, n):
        psi[i] = _wrap(ang[i] - ang[i - 1])
    # theta[i]: the angle leaving z[i], against its chord. Mock curvature
    # continuity at inner points; a direction or a curl at the ends.
    a, b, c, r = ([0.0] * (n + 1) for _ in range(4))
    if d0 is not None:
        b[0], r[0] = 1.0, _wrap(math.atan2(d0[1], d0[0]) - ang[0])
    else:
        b[0], c[0], r[0] = 3.0, 3.0, -3.0 * psi[1]
    for i in range(1, n):
        a[i], b[i], c[i] = 1 / d[i - 1], 2 / d[i - 1] + 2 / d[i], 1 / d[i]
        r[i] = -2 * psi[i] / d[i - 1] - psi[i + 1] / d[i]
    if d1 is not None:
        b[n], r[n] = 1.0, _wrap(math.atan2(d1[1], d1[0]) - ang[n - 1])
    else:
        a[n], b[n] = 3.0, 3.0
    for i in range(1, n + 1):      # tridiagonal, solved in place
        m = a[i] / b[i - 1]
        b[i] -= m * c[i - 1]
        r[i] -= m * r[i - 1]
    theta = [0.0] * (n + 1)
    theta[n] = r[n] / b[n]
    for i in range(n - 1, -1, -1):
        theta[i] = (r[i] - c[i] * theta[i + 1]) / b[i]
    segs = []
    for i in range(n):
        th, ph = theta[i], -psi[i + 1] - theta[i + 1]
        st, ct, sf, cf = math.sin(th), math.cos(th), math.sin(ph), math.cos(ph)
        u, v = _velocity(st, ct, sf, cf) * d[i], _velocity(sf, cf, st, ct) * d[i]
        a0, a1 = ang[i] + th, ang[i] - ph
        segs.append(((z[i][0] + u * math.cos(a0), z[i][1] + u * math.sin(a0)),
                     (z[i + 1][0] - v * math.cos(a1), z[i + 1][1] - v * math.sin(a1)), z[i + 1]))
    return segs


class Path:
    """An outline built from lines and cubic curves, in unit space.

    It remembers how its segments join, so `kinks()` can find a tangent break
    between two curves that nobody asked for. `corner()` declares the next
    join deliberate (an ear tip, a crown point); `apex=True` does the same
    for a start point on the axis, and `corner()` just before `mirror()` for
    the end point.
    """

    def __init__(self, start, apex=False):
        self.pts = [start]
        self.segs = []  # (kind, tangent at start, tangent at end, deliberate, at)
        self.apex_start = apex
        self.apex_end = False
        self.axis_end = None
        self._corner = False
        _PATHS.append(self)

    def corner(self):
        self._corner = True
        return self

    def L(self, p):
        a = self.pts[-1]
        t = _unit(_sub(p, a))
        if t:
            self.segs.append(("L", t, t, self._corner, a))
        self._corner = False
        self.pts.append(p)
        return self

    def C(self, c1, c2, p, n=None):
        a = self.pts[-1]
        t0 = _unit(_sub(c1, a)) or _unit(_sub(c2, a)) or _unit(_sub(p, a))
        t1 = _unit(_sub(p, c2)) or _unit(_sub(p, c1)) or _unit(_sub(p, a))
        if n is None:  # about 1 px per segment at the master canvas' scale
            span = math.dist(a, c1) + math.dist(c1, c2) + math.dist(c2, p)
            n = max(12, min(240, math.ceil(span / 0.004)))
        self.segs.append(("C", t0, t1, self._corner, a))
        self._corner = False
        self.pts += bez(a, c1, c2, p, n)
        return self

    def through(self, pts, end=None, start=None):
        """A Hobby curve from here through [pts]. It leaves along [start], or
        else along the segment before it unless a corner was declared, and
        arrives along [end] if given."""
        if start is None and self.segs and not self._corner:
            start = self.segs[-1][2]
        for c1, c2, p in hobby([self.pts[-1], *pts], start, end):
            self.C(c1, c2, p)
        return self

    def fillet_to(self, corner, toward, r):
        """A straight run at [corner], rounded off by a circular arc of radius
        [r] as the outline turns to head for [toward]."""
        u, w = _unit(_sub(corner, self.pts[-1])), _unit(_sub(toward, corner))
        turn = math.acos(max(-1.0, min(1.0, u[0] * w[0] + u[1] * w[1])))
        t, h = r * math.tan(turn / 2), 4 / 3 * math.tan(turn / 4) * r
        p1 = (corner[0] - u[0] * t, corner[1] - u[1] * t)
        p2 = (corner[0] + w[0] * t, corner[1] + w[1] * t)
        if math.dist(self.pts[-1], p1) > 1e-6:
            self.L(p1)
        return self.C((p1[0] + u[0] * h, p1[1] + u[1] * h), (p2[0] - w[0] * h, p2[1] - w[1] * h), p2)

    def mirror(self, axis=0.5):
        """Closes a left half by mirroring it across x = [axis]."""
        self.apex_end = self._corner
        self._corner = False
        self.axis_end = self.pts[-1]
        right = [(2 * axis - x, y) for x, y in reversed(self.pts)]
        if right and _same(right[0], self.pts[-1]):
            right = right[1:]
        self.pts = self.pts + right
        return self

    def points(self):
        return self.pts

    def kinks(self, max_deg=12.0):
        found = []
        for prev, cur in zip(self.segs, self.segs[1:]):
            if prev[0] == "C" and cur[0] == "C" and not cur[3]:
                t0, t1 = prev[2], cur[1]
                a = math.degrees(math.acos(max(-1.0, min(1.0, t0[0] * t1[0] + t0[1] * t1[1]))))
                if a > max_deg:
                    found.append((cur[4], round(a, 1)))
        if self.axis_end is not None and self.segs:
            # A curve meeting the axis must cross it square-on, or its mirror
            # image makes a point there.
            for seg, apex, at, t in ((self.segs[0], self.apex_start, self.pts[0], self.segs[0][1]),
                                     (self.segs[-1], self.apex_end, self.axis_end, self.segs[-1][2])):
                if seg[0] == "C" and not apex:
                    a = 2 * math.degrees(math.asin(min(1.0, abs(t[1]))))
                    if a > max_deg:
                        found.append((at, round(a, 1)))
        return found


class Part(list):
    """A closed outline and how light falls on it: "cyl" (turned about the
    piece's axis), "sphere", "free" (a volume lit from its silhouette), or
    "gem" (a cut stone: four planes around its girdle and keel). [facets]
    are optional (polygon, normal) planes a faceted style paints instead."""

    def __init__(self, points, kind="cyl", facets=None):
        super().__init__(points)
        self.kind = kind
        self.facets = facets


def ellipse(cx, cy, rx, ry, n=192):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n))
            for i in range(n)]


def ball(cx, cy, r):
    return Part(ellipse(cx, cy, r, r), "sphere")


def rrect(x0, y0, x1, y1, r, n=12):
    """A rounded rectangle, clockwise from the top-left."""
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0),
                       (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def arc(cx, cy, r, a0, a1, n=48):
    """Points on a circle from angle [a0] to [a1] (degrees, y down)."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def fillet(points, r, n=10):
    """Rounds every corner of a closed polygon by radius [r], clamped to half
    of each adjoining edge."""
    out = []
    m = len(points)
    for i in range(m):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % m]
        v1, v2 = _sub(p0, p1), _sub(p2, p1)
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        if l1 < 1e-9 or l2 < 1e-9:
            continue
        u1, u2 = (v1[0] / l1, v1[1] / l1), (v2[0] / l2, v2[1] / l2)
        ang = math.acos(max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1])))
        if ang > math.pi - 1e-3:  # straight: nothing to round
            out.append(p1)
            continue
        d = min(r / math.tan(ang / 2), l1 / 2, l2 / 2)
        a = (p1[0] + u1[0] * d, p1[1] + u1[1] * d)
        b = (p1[0] + u2[0] * d, p1[1] + u2[1] * d)
        for k in range(n + 1):  # a quadratic through the corner
            t = k / n
            out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t * t * b[0],
                        (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t * t * b[1]))
    return out


def lathe(profile, bot_y, top_y=None, start=None, end=None):
    """A turned part from its left half: out from the axis at [top_y] (the
    first point's height if omitted) to the first of [profile]'s (half-width,
    y) points, down through the rest by a Hobby curve (leaving along [start],
    arriving along [end]), and back to the axis at [bot_y]; then mirrored."""
    hw0, y0 = profile[0]
    p = Path((0.5, y0 if top_y is None else top_y)).L((0.5 - hw0, y0)).corner()
    p.through([(0.5 - hw, y) for hw, y in profile[1:]], start=start, end=end)
    p.corner().L((0.5, bot_y))
    return Part(p.mirror().points())


def resample(pts, step, closed=True):
    """Points every [step] along a polyline, so long straight edges carry
    samples too."""
    seq = pts + ([pts[0]] if closed else [])
    out = [seq[0]]
    for a, b in zip(seq, seq[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for i in range(1, n + 1):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out[:-1] if closed else out


def length(pts):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:]))


@dataclass
class Shape:
    """One piece's geometry in the unit square."""

    parts: list                                 # closed outlines, back to front
    seams: list = field(default_factory=list)   # open lines inside the piece
    dots: list = field(default_factory=list)    # ((cx, cy), rx, ry): pips
    slits: list = field(default_factory=list)   # (part, y_open, tip, gap)
    glints: list = field(default_factory=list)  # ((cx, cy), r): catchlights
    marks: list = field(default_factory=list)   # closed outlines in the detail tone: an eye
    shades: list = field(default_factory=list)  # (part, outline): a shadow on that part


# =============================================================== canvas

EDGE, INNER, HIDDEN = 0, 1, 2


class Canvas:
    """An RGBA canvas addressed in unit coordinates."""

    def __init__(self, size):
        self.S = size
        self.img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    def px(self, pts):
        return [(x * self.S, y * self.S) for x, y in pts]

    def mask(self, pts):
        m = Image.new("L", (self.S, self.S), 0)
        ImageDraw.Draw(m).polygon(self.px(pts), fill=255)
        return m

    def paint(self, mask, colour, opacity=1.0):
        """[colour] through [mask]. A partial mask (a shadow, an opacity) must
        only ever land on opaque pixels: paste blends alpha too."""
        if opacity < 1.0:
            mask = mask.point(lambda v: round(v * opacity))
        self.img.paste(Image.new("RGBA", (self.S, self.S), tuple(colour[:3]) + (255,)), (0, 0), mask)

    def polyline(self, pts, width, colour, closed=False, into=None):
        """A line centred on [pts] with round joins and caps."""
        img = into if into is not None else self.img
        if img.mode == "RGBA":
            colour = tuple(colour[:3]) + (255,)
        d = ImageDraw.Draw(img)
        w = width * self.S
        p = self.px(pts)
        if len(p) == 1:
            p = p * 2
        seq = p + ([p[0]] if closed else [])
        for a, b in zip(seq, seq[1:]):
            d.line([a, b], fill=colour, width=max(1, round(w)))
        r = w / 2
        for q in p:
            d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=colour)

    def shifted(self, mask, dx, dy=0.0):
        return ImageChops.offset(mask, round(dx * self.S), round(dy * self.S))


def crescent(cv, mask, dx, dy=0.0):
    """The band of [mask] along its edges facing +(dx, dy): its shade."""
    return ImageChops.subtract(mask, cv.shifted(mask, -dx, -dy))


def inner_strip(cv, mask, inset, width, dy=0.0):
    """A strip parallel to the edges facing -x, [inset] inside them."""
    a = cv.shifted(mask, inset, dy)
    b = cv.shifted(mask, inset + width, dy * (1 + width / inset) if dy else 0)
    return ImageChops.multiply(ImageChops.subtract(a, b), mask)


def width_of(cv, mask):
    box = mask.getbbox()
    return (box[2] - box[0]) / cv.S if box else 0.0


def classify(cv, parts, masks, tol=0.0015):
    """Splits every part outline into runs of EDGE, INNER and HIDDEN.

    A sample on part i's outline is HIDDEN if a later part covers it, INNER
    if an earlier part lies under it, and otherwise on the silhouette. "Covers"
    means strictly inside, [tol] in from that part's own outline, so parts
    that merely share an edge do not hide each other's line.
    """
    strict = []
    for pts, m in zip(parts, masks):
        s = m.copy()
        cv.polyline(pts, 2 * tol, 0, closed=True, into=s)
        strict.append(s)
    runs = []
    for i, pts in enumerate(parts):
        later = Image.new("L", (cv.S, cv.S), 0)
        others = Image.new("L", (cv.S, cv.S), 0)
        for j, s in enumerate(strict):
            if j != i:
                others = ImageChops.lighter(others, s)
                if j > i:
                    later = ImageChops.lighter(later, s)
        lp, op = later.load(), others.load()
        samples = resample(list(pts), 0.0025)
        cls = []
        for x, y in samples:
            X = min(cv.S - 1, max(0, int(x * cv.S)))
            Y = min(cv.S - 1, max(0, int(y * cv.S)))
            cls.append(HIDDEN if lp[X, Y] > 127 else INNER if op[X, Y] > 127 else EDGE)
        runs += _runs(samples, cls)
    return runs


def _runs(samples, cls):
    """Cyclic runs of equal class. Runs share no samples: the one-step gap
    between two is always closed by the round caps of the lines drawn."""
    n = len(samples)
    if len(set(cls)) == 1:
        return [(cls[0], samples + [samples[0]])]
    start = next(i for i in range(n) if cls[i] != cls[i - 1])
    out, cur, pts = [], cls[start], []
    for k in range(n):
        i = (start + k) % n
        if cls[i] != cur:
            out.append((cur, pts))
            cur, pts = cls[i], []
        pts.append(samples[i])
    out.append((cur, pts))
    return out


# =============================================================== light


def _norm3(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


LIGHT = _norm3((-0.55, -0.45, 0.70))                 # top left, in front
HALF = _norm3((LIGHT[0], LIGHT[1], LIGHT[2] + 1.0))  # Blinn half-vector


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


@dataclass(frozen=True)
class Material:
    """How a surface answers the one light: [shadow] where no light reaches,
    [lit] where it falls square-on, and an optional soft specular."""

    shadow: tuple
    lit: tuple
    ambient: float = 0.3
    spec: float = 0.0
    shine: float = 24.0
    spec_colour: tuple = (250, 248, 244)

    def at(self, n):
        d = max(0.0, n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2])
        c = mix(self.shadow, self.lit, self.ambient + (1 - self.ambient) * d)
        if self.spec:
            h = max(0.0, n[0] * HALF[0] + n[1] * HALF[1] + n[2] * HALF[2]) ** self.shine
            c = mix(c, self.spec_colour, h * self.spec)
        return c


def _lowres(mask, box, limit=192):
    x0, y0, x1, y1 = box
    k = min(1.0, limit / max(x1 - x0, y1 - y0))
    size = (max(2, round((x1 - x0) * k)), max(2, round((y1 - y0) * k)))
    return mask.crop(box).resize(size, Image.Resampling.BILINEAR), k


def _paste_lit(cv, mask, box, small):
    full = small.resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.BILINEAR)
    layer = Image.new("RGBA", (cv.S, cv.S), (0, 0, 0, 0))
    layer.paste(full.convert("RGBA"), box[:2])
    cv.img.paste(layer, (0, 0), mask)


def light_turned(cv, mask, material):
    """A part turned about the piece's axis: each row is a cylinder."""
    box = mask.getbbox()
    small, k = _lowres(mask, box)
    sw, sh = small.size
    axis = (0.5 * cv.S - box[0]) * k
    sp = small.load()
    out = Image.new("RGB", (sw, sh))
    op = out.load()
    for y in range(sh):
        xs = [x for x in range(sw) if sp[x, y] > 64]
        if not xs:
            continue
        hw = max(abs(xs[0] - axis), abs(xs[-1] + 1 - axis), 0.5)
        for x in range(sw):
            u = max(-1.0, min(1.0, (x + 0.5 - axis) / hw))
            op[x, y] = material.at((u, 0.0, math.sqrt(max(0.0, 1 - u * u))))
    _paste_lit(cv, mask, box, out)


_SPHERES = {}


def light_sphere(cv, mask, material):
    box = mask.getbbox()
    if material not in _SPHERES:
        n = 128
        img = Image.new("RGB", (n, n))
        p = img.load()
        for y in range(n):
            v = (y + 0.5) / n * 2 - 1
            for x in range(n):
                u = (x + 0.5) / n * 2 - 1
                r2 = u * u + v * v
                if r2 >= 1:
                    s = math.sqrt(r2)
                    nrm = (u / s, v / s, 0.0)
                else:
                    nrm = (u, v, math.sqrt(1 - r2))
                p[x, y] = material.at(nrm)
        _SPHERES[material] = img
    _paste_lit(cv, mask, box, _SPHERES[material])


def light_free(cv, mask, material, soften=0.09, relief=1.0):
    """Any silhouette lit as a soft volume: normals from a blurred mask."""
    box = mask.getbbox()
    small, _ = _lowres(mask, box, 160)
    sw, sh = small.size
    radius = soften * max(sw, sh)
    b = small.filter(ImageFilter.GaussianBlur(radius))
    bp = b.load()
    s = relief * radius * 2.2 / 255
    out = Image.new("RGB", (sw, sh))
    op = out.load()
    for y in range(sh):
        for x in range(sw):
            gx = (bp[min(x + 1, sw - 1), y] - bp[max(x - 1, 0), y]) * 0.5 * s
            gy = (bp[x, min(y + 1, sh - 1)] - bp[x, max(y - 1, 0)]) * 0.5 * s
            op[x, y] = material.at(_norm3((-gx, -gy, 1.0)))
    _paste_lit(cv, mask, box, out)


def light_gem(cv, part, mask, material):
    """Four planes meeting at the girdle and the keel, each lit as it faces."""
    xs, ys = [p[0] for p in part], [p[1] for p in part]
    top, bot = min(ys), max(ys)
    cx = (min(xs) + max(xs)) / 2
    gy = [p[1] for p in part if abs(p[0] - min(xs)) < 1e-6][0]
    l, r = min(xs), max(xs)
    planes = [([(cx, top), (cx, gy), (l, gy)], (-0.55, -0.55, 0.63)),
              ([(cx, top), (r, gy), (cx, gy)], (0.55, -0.55, 0.63)),
              ([(l, gy), (cx, gy), (cx, bot)], (-0.45, 0.45, 0.77)),
              ([(cx, gy), (r, gy), (cx, bot)], (0.45, 0.45, 0.77))]
    for poly, n in planes:
        cv.paint(ImageChops.multiply(cv.mask(poly), mask), material.at(_norm3(n)))


def light_part(cv, part, mask, material):
    if part.kind == "gem":
        return light_gem(cv, part, mask, material)
    {"sphere": light_sphere, "free": light_free}.get(part.kind, light_turned)(cv, mask, material)


def contact_shadow(cv, mask, behind, amount, reach=0.014):
    """The part's shadow on what lies behind it: down and to the right of its
    edge, soft, and only on parts drawn before it."""
    sh = cv.shifted(mask, reach * 0.55, reach)
    sh = sh.filter(ImageFilter.GaussianBlur(reach * 0.6 * cv.S))
    sh = ImageChops.multiply(ImageChops.subtract(sh, mask), behind)
    cv.paint(sh, (0, 0, 0), opacity=amount)


# =============================================================== render


@dataclass
class Style:
    """How a shape is coloured and lined. Colours are keyed by side, 'w'/'b'."""

    edge: float           # silhouette line width
    inner: float          # a part crossing another
    seam: float           # seams, and slits drawn as lines
    fill: object          # fill(cv, part, mask, colour): paints one part
    line_edge: dict
    line_inner: dict
    detail: dict          # eyes and nostrils
    notch: bool = True    # a slit is cut into the outline, or drawn as a line
    glint: tuple = (248, 246, 242)
    min_inner: dict = field(default_factory=dict)  # shortest INNER run kept
    ao: float = 0.0       # contact-shadow strength
    seam_tone: dict = field(default_factory=dict)  # seams, when not line_inner
    shadow: object = None  # shadow(cv, mask, part_mask, colour): a shape's shades; None skips them


def flat_shadow(tones):
    """A shade painted flat in the style's own shade tone."""
    return lambda cv, m, part, colour: cv.paint(m, tones[colour])


def soft_shadow(amount, blur=0.006):
    """A shade on a lit material: a soft darkening, kept inside its part."""
    def paint(cv, m, part, colour):
        soft = ImageChops.multiply(m.filter(ImageFilter.GaussianBlur(blur * cv.S)), part)
        cv.paint(soft, (0, 0, 0), opacity=amount)
    return paint


def cut_slit(points, y_open, tip, gap):
    """Cuts a V slit into the right-hand side of a closed outline."""
    points = resample(list(points), 0.004)
    near = [i for i, (x, y) in enumerate(points) if x > 0.5 and abs(y - y_open) <= gap / 2]
    i0, i1 = min(near), max(near)
    return list(points[:i0]) + [points[i0], tip, points[i1]] + list(points[i1 + 1:])


def slit_line(points, y_open, tip):
    """The slit as a line, from the outline's right side at [y_open]."""
    edge = min((q for q in points if q[0] > 0.5), key=lambda q: abs(q[1] - y_open))
    return [edge, tip]


def render_master(shape: Shape, style: Style, colour: str, px=MASTER_PX):
    cv = Canvas(px)
    parts = [p if isinstance(p, Part) else Part(p) for p in shape.parts]
    lines = []
    for i, y_open, tip, gap in shape.slits:
        if style.notch:
            parts[i] = Part(cut_slit(parts[i], y_open, tip, gap), parts[i].kind)
        else:
            lines.append(slit_line(parts[i], y_open, tip))
    masks = [cv.mask(p) for p in parts]
    behind = Image.new("L", (px, px), 0)
    for i, (part, m) in enumerate(zip(parts, masks)):
        style.fill(cv, part, m, colour)
        if style.shadow:  # before later parts, so they cover it
            for _, outline in (s for s in shape.shades if s[0] == i):
                style.shadow(cv, ImageChops.multiply(cv.mask(outline), m), m, colour)
        if style.ao and i:
            contact_shadow(cv, m, behind, style.ao)
        behind = ImageChops.lighter(behind, m)
    runs = classify(cv, parts, masks)
    li, le = style.line_inner[colour], style.line_edge[colour]
    shortest = style.min_inner.get(colour, 0.0)
    for cls, pts in runs:
        if cls == INNER and style.inner and length(pts) >= shortest:
            cv.polyline(pts, style.inner, li)
    seam_colour = style.seam_tone.get(colour, li)
    for seam in shape.seams + lines:
        cv.polyline(seam, style.seam, seam_colour)
    for (cx, cy), rx, ry in shape.dots:
        cv.paint(cv.mask(ellipse(cx, cy, rx, ry)), style.detail[colour])
    for mark in shape.marks:
        cv.paint(cv.mask(mark), style.detail[colour])
    for (cx, cy), r in shape.glints:
        cv.paint(cv.mask(ellipse(cx, cy, r, r)), style.glint)
    for cls, pts in runs:  # the silhouette last, over every cap
        if cls == EDGE:
            cv.polyline(pts, style.edge, le)
    return cv.img


# =============================================================== styles


def _flat(palette, shade=0.26, shade_max=0.06, lit_inset=0.024, lit_w=0.016):
    """Fill, a shade band along the right, a lit strip inside the left; the
    bands scale with the part, so a pearl is not all shadow."""
    def fill(cv, part, m, colour):
        p = palette[colour]
        cv.paint(m, p["fill"])
        w = width_of(cv, m)
        cv.paint(crescent(cv, m, max(0.012, min(shade_max, shade * w))), p["shade"])
        inset = max(0.007, min(lit_inset, 0.1 * w))
        cv.paint(inner_strip(cv, m, inset, max(0.005, min(lit_w, 0.068 * w)), dy=-0.6 * inset),
                 p["light"])
    return fill


def _lines(palette, tone):
    """Edge colour, and inner lines moved [tone] of the way toward the fill."""
    edge = {c: palette[c]["line"] for c in "wb"}
    inner = {c: mix(palette[c]["line"], palette[c]["fill"], tone) for c in "wb"}
    return edge, inner


CLASSIC_COLOURS = {
    "w": dict(fill=(240, 239, 236), shade=(206, 204, 200), light=(251, 250, 248),
              line=(62, 60, 58), detail=(150, 148, 145)),
    "b": dict(fill=(95, 89, 85), shade=(78, 73, 70), light=(132, 127, 123),
              line=(30, 29, 28), detail=(60, 56, 54)),
}
_ce, _ci = _lines(CLASSIC_COLOURS, 0.2)
CLASSIC = Style(
    edge=0.026, inner=0.018, seam=0.016, fill=_flat(CLASSIC_COLOURS),
    line_edge=_ce, line_inner=_ci,
    detail={c: CLASSIC_COLOURS[c]["detail"] for c in "wb"}, ao=0.10,
    shadow=flat_shadow({c: CLASSIC_COLOURS[c]["shade"] for c in "wb"}))

# Wood: boxwood and rosewood, every part turned and lit as the solid it is.
WOOD_MATERIAL = {
    "w": Material(shadow=(170, 124, 76), lit=(247, 226, 190), ambient=0.34, spec=0.10, shine=18),
    "b": Material(shadow=(52, 30, 21), lit=(150, 98, 70), ambient=0.30, spec=0.10, shine=18,
                  spec_colour=(196, 150, 120)),
}
WOOD_LINE = {"w": (64, 41, 24), "b": (30, 18, 12)}
WOOD = Style(
    edge=0.024, inner=0.017, seam=0.015,
    fill=lambda cv, part, m, colour: light_part(cv, part, m, WOOD_MATERIAL[colour]),
    line_edge=WOOD_LINE,
    line_inner={"w": (122, 86, 54), "b": (40, 24, 16)},
    detail={"w": (112, 76, 46), "b": (36, 21, 14)}, ao=0.16, shadow=soft_shadow(0.16))

# Diagram: white is paper and ink; black is ink with its turnings cut back out
# in paper. Softened from a pure black on white (19:1) to about 12:1.
INK, PAPER = (48, 46, 43), (240, 238, 233)
DIAGRAM = Style(
    edge=0.027, inner=0.017, seam=0.016,
    fill=lambda cv, part, m, colour: cv.paint(m, PAPER if colour == "w" else INK),
    line_edge={"w": INK, "b": INK}, line_inner={"w": INK, "b": PAPER},
    detail={"w": INK, "b": PAPER}, notch=False, min_inner={"b": 0.1})

# Modern: flat two-tone, each part lit on the left and shaded right of the
# piece's axis, with a fine line.
MODERN_COLOURS = {
    "w": dict(fill=(243, 242, 239), shade=(219, 220, 221), line=(52, 55, 59),
              detail=(52, 55, 59)),
    "b": dict(fill=(68, 72, 78), shade=(52, 55, 60), line=(22, 24, 27),
              detail=(168, 172, 178)),
}


def _modern_fill(cv, part, m, colour):
    p = MODERN_COLOURS[colour]
    cv.paint(m, p["fill"])
    right = cv.mask([(0.5, -1), (2, -1), (2, 2), (0.5, 2)])
    cv.paint(ImageChops.multiply(m, right), p["shade"])


MODERN = Style(
    edge=0.022, inner=0.014, seam=0.015, fill=_modern_fill,
    line_edge={c: MODERN_COLOURS[c]["line"] for c in "wb"},
    line_inner={"w": (126, 129, 134), "b": (26, 28, 31)},
    detail={c: MODERN_COLOURS[c]["detail"] for c in "wb"},
    shadow=flat_shadow({c: MODERN_COLOURS[c]["shade"] for c in "wb"}))

BOLD_COLOURS = {
    "w": dict(fill=(246, 245, 243), shade=(213, 215, 219), light=(251, 250, 248),
              line=(56, 59, 64), detail=(56, 59, 64)),
    "b": dict(fill=(80, 84, 92), shade=(64, 67, 74), light=(116, 121, 130),
              line=(22, 24, 28), detail=(22, 24, 28)),
}
_be, _bi = _lines(BOLD_COLOURS, 0.12)
BOLD = Style(
    edge=0.031, inner=0.022, seam=0.019,
    fill=_flat(BOLD_COLOURS, shade=0.3, shade_max=0.075, lit_inset=0.03, lit_w=0.02),
    line_edge=_be, line_inner=_bi,
    detail={c: BOLD_COLOURS[c]["detail"] for c in "wb"}, ao=0.08,
    shadow=flat_shadow({c: BOLD_COLOURS[c]["shade"] for c in "wb"}))


# =============================================================== the knight

# The chess knight's archetype, measured across the canonical sets:
#
#   - ONE ear, standing up from the brow, its back falling to the poll;
#   - a straight face at about 50 degrees, down to a crisp, rounded muzzle;
#   - under it, the muzzle's underside running back to a rounded chin;
#   - the jowl: from the chin the jaw rises steeply, then rounds off and
#     reaches the throat almost level. It must, or the V under the jaw (the
#     throat notch) closes into a slit once the outline is drawn;
#   - from the notch, the neck front falls at about 50 degrees and swings
#     forward into the chest, under an arched crest and a near-vertical back.
#
# A neck that rises straight up reads as a horse bust on a column, and a jaw
# that climbs steeply into the throat pinches the V shut: `audit` measures
# the notch, the lean and the width (`knight_form`). Inside the head there
# is only an eye and a nostril, and on the styles that model light, the
# jowl's shadow along the jaw.
#
# The curves are Hobby splines through our own landmarks (`hobby`). Other
# sets were studied for proportion only, as an average of many, and never
# traced; the landmarks below are this file's.

KNIGHT_TOP, KNIGHT_FOOT = 0.112, 0.775  # the design space: ear tip to pedestal

KNIGHT = dict(
    foot=(0.288, KNIGHT_FOOT), chest=(0.278, 0.712),
    neck=[(0.306, 0.652), (0.362, 0.6), (0.43, 0.546), (0.478, 0.498)],
    notch=(0.508, 0.462),
    jowl=[(0.418, 0.486), (0.348, 0.521)], jaw=(0.3, 0.562), chin=(0.272, 0.592),
    muzzle=(0.132, 0.466), brow=(0.346, 0.222), ear=(0.356, 0.166), tip=(0.37, KNIGHT_TOP),
    poll=(0.47, 0.19),
    crest=[(0.59, 0.226), (0.694, 0.288), (0.758, 0.388), (0.782, 0.5), (0.772, 0.65)],
    heel=(0.75, KNIGHT_FOOT))


def _fit(pts, foot):
    """The knight re-seated on a pedestal whose top differs: y is stretched
    below the ear tip so the chest meets [foot]."""
    k = (foot - KNIGHT_TOP) / (KNIGHT_FOOT - KNIGHT_TOP)
    return [(x, KNIGHT_TOP + (y - KNIGHT_TOP) * k) for x, y in pts]


def _fit_pt(p, foot):
    return _fit([p], foot)[0]


def spline(pts, n=24):
    """Points along an open Hobby curve through [pts], free at both ends: for
    shading, which the kink audit does not read."""
    out = [pts[0]]
    for c1, c2, p in hobby(pts):
        out += bez(out[-1], c1, c2, p, n)
    return out


def almond(cx, cy, length, height, angle, lift=0.0, n=48):
    """A pointed oval (an eye, a nostril) turned by [angle] degrees; [lift]
    arches its upper lid above the lower one."""
    a = math.radians(angle)
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = math.cos(t) * length / 2
        y = math.sin(t) * height / 2 * math.sqrt(max(0.0, 1 - abs(math.cos(t)) ** 2.4))
        if y < 0:
            y *= 1 + lift
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return pts


def knight_outline(foot=KNIGHT_FOOT):
    """The smooth canonical knight, chest foot first, clockwise."""
    k = KNIGHT
    p = Path(k["foot"])
    p.through([k["chest"], *k["neck"], k["notch"]], start=(-0.02, -1), end=(0.643, -0.766))
    p.corner()                                               # the throat notch
    p.through([*k["jowl"], k["jaw"]], start=(-1, 0.2), end=_sub(k["chin"], k["jaw"]))
    p.fillet_to(k["chin"], k["muzzle"], 0.03)                # the chin
    p.fillet_to(k["muzzle"], k["brow"], 0.022)               # the muzzle
    p.L(k["brow"])                                           # the face, straight
    p.corner()
    p.through([k["ear"], k["tip"]], start=(0.05, -1), end=(0.1, -1))
    p.corner()                                               # the ear's tip
    p.through([k["poll"]], start=(0.4, 1), end=(0.8, 0.55))
    p.corner()                                               # the poll
    p.through([*k["crest"], k["heel"]], start=(1, 0.3), end=(-0.04, 1))
    p.L(k["foot"])
    return _fit(p.points(), foot)


def knight_features(foot=KNIGHT_FOOT, eye_scale=1.0):
    """The eye and the nostril, the jowl's shadow, and the eye's catchlight."""
    ex, ey = 0.382, 0.302
    lower = [(0.498, 0.466), (0.43, 0.482), (0.37, 0.505), (0.325, 0.535), (0.295, 0.568), (0.268, 0.572)]
    upper = [(0.3, 0.535), (0.34, 0.49), (0.4, 0.458), (0.46, 0.44), (0.52, 0.45)]
    shade = spline(lower) + spline([lower[-1], *upper, lower[0]])[1:]  # the jaw, then back over it
    return dict(eye=_fit(almond(ex, ey, 0.064 * eye_scale, 0.038 * eye_scale, -26, lift=0.35), foot),
                nostril=_fit(almond(0.19, 0.458, 0.03, 0.015, -58), foot),
                shade=_fit(shade, foot),
                glint=(_fit_pt((ex - 0.012 * eye_scale, ey - 0.008 * eye_scale), foot), 0.008 * eye_scale))


KNIGHT_MARKS = dict(        # the same knight's landmarks, for the straight-edged sets
    foot=KNIGHT["foot"], chest=(0.278, 0.705), neck=(0.33, 0.63), throat=(0.44, 0.535),
    notch=KNIGHT["notch"], jowl=(0.4, 0.492), jaw=(0.31, 0.555), chin=KNIGHT["chin"],
    muzzle=KNIGHT["muzzle"], brow=KNIGHT["brow"], tip=KNIGHT["tip"], poll=KNIGHT["poll"],
    back=(0.776, 0.65), heel=KNIGHT["heel"])


def knight_polygon(foot=KNIGHT_FOOT, mane=None):
    """The same knight in straight lines, for the geometric sets: the
    landmarks joined directly, the crest as one arc, or as the given [mane]
    (points from the poll down the back)."""
    m = KNIGHT_MARKS
    crest = mane if mane is not None else arc(0.47, 0.51, 0.318, -86, 2, n=24)[1:]
    pts = ([m["foot"], m["chest"], m["neck"], m["throat"], m["notch"], m["jowl"], m["jaw"], m["chin"],
            m["muzzle"], m["brow"], m["tip"], m["poll"]]
           + crest + [m["back"], m["heel"]])
    return _fit(pts, foot)


def knight_shape(outline, foot_parts, feats, nostril=True, glint=False, shade=True, dx=-0.014):
    """A knight Shape: the head, the pedestal parts under it, its eye (and
    nostril), and the jowl's shadow for the styles that paint one. Nudged
    sideways by [dx] for optical centring, the pedestal kept in place."""
    marks = [feats["eye"]] + ([feats["nostril"]] if nostril else [])
    glints = [feats["glint"]] if glint else []
    shape = Shape(parts=[outline, *foot_parts], marks=marks, glints=glints,
                  shades=[(0, feats["shade"])] if shade else [])
    return shift(shape, dx, keep=list(range(1, 1 + len(foot_parts))))


# =============================================================== Staunton


class Staunton:
    """Turned forms after the 1849 pattern: a cushion pedestal, a trumpet
    stem, a collar, and the piece's own head. The pedestal widens with the
    piece's rank, and each piece gets a body of its own (a squat tower, a
    slender royal waist), so the six still read apart at thumbnail size."""

    BOT = 0.887        # fill bottom; the silhouette line lands on 0.90

    @classmethod
    def base(cls, w, top):
        """A cushion: flat foot, softly rounded shoulders, a gently domed top."""
        x0, bot = 0.5 - w / 2, cls.BOT
        h = bot - top
        p = Path((0.5, bot)).L((x0 + 0.035, bot))
        p.C((x0 + 0.01, bot), (x0, bot - 0.01), (x0 + 0.002, bot - 0.035))
        p.C((x0 + 0.004, top + h * 0.52), (x0 + 0.012, top + h * 0.2), (x0 + 0.054, top + h * 0.08))
        p.C((x0 + 0.105, top - 0.003), (0.5 - 0.11, top - 0.01), (0.5, top - 0.01))
        return Part(p.mirror().points())

    @staticmethod
    def band(cy, hw, hh=0.024):
        """A collar: a flat, rounded ring."""
        p = Path((0.5, cy - hh)).L((0.5 - hw + hh, cy - hh))
        p.C((0.5 - hw + hh * 0.45, cy - hh), (0.5 - hw, cy - hh * 0.55), (0.5 - hw, cy))
        p.C((0.5 - hw, cy + hh * 0.55), (0.5 - hw + hh * 0.45, cy + hh), (0.5 - hw + hh, cy + hh))
        p.L((0.5, cy + hh))
        return Part(p.mirror().points())

    @staticmethod
    def stem(top_y, top_hw, bot_hw, bot_y, flare=0.5):
        """A trumpet: leaves the collar almost vertically, then sweeps out into
        the pedestal. [flare] is how late the sweep happens."""
        h = bot_y - top_y
        xt, xb = 0.5 - top_hw, 0.5 - bot_hw
        p = Path((0.5, top_y)).L((xt, top_y))
        p.C((xt, top_y + h * 0.5), (xb + (xt - xb) * flare, bot_y - h * 0.06), (xb, bot_y))
        p.L((0.5, bot_y))
        return Part(p.mirror().points())

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            lathe([(0.08, 0.53), (0.09, 0.6), (0.13, 0.69), (0.205, 0.786)], 0.786,
                  start=(-0.1, 1), end=(-1, 0.7)),                # the skirt
            cls.base(0.52, 0.766),
            Part(rrect(0.442, 0.46, 0.558, 0.52, 0.02)),           # a short neck
            cls.band(0.522, 0.142, 0.026),
            ball(0.5, 0.352, 0.128),
        ])

    @classmethod
    def rook(cls):
        top, notch, x0 = 0.172, 0.232, 0.23
        # the turret: crenellated, overhanging the body on a corbel
        t = (Path((0.5, 0.36)).L((0.31, 0.36))
             .through([(x0 + 0.01, 0.33)], start=(-1, 0), end=(-0.3, -1)).corner()
             .L((x0, top + 0.008))
             .C((x0, top + 0.002), (x0 + 0.004, top), (x0 + 0.01, top)).corner()
             .L((0.37, top))
             .C((0.376, top), (0.378, top + 0.004), (0.378, top + 0.01)).corner()
             .L((0.378, notch - 0.008))
             .C((0.378, notch - 0.002), (0.381, notch), (0.387, notch)).corner()
             .L((0.439, notch))
             .C((0.445, notch), (0.447, notch - 0.003), (0.447, notch - 0.009)).corner()
             .L((0.447, top + 0.01))
             .C((0.447, top + 0.004), (0.45, top), (0.456, top)).corner()
             .L((0.5, top))
             .mirror())
        return Shape(parts=[
            lathe([(0.186, 0.35), (0.182, 0.47), (0.196, 0.63), (0.248, 0.772)], 0.772,
                  start=(0, 1), end=(-0.7, 1)),                   # a tower, flaring into its foot
            cls.base(0.59, 0.756),
            Part(t.points()),
            cls.band(0.36, 0.208, 0.022),
        ])

    @classmethod
    def bishop(cls):
        return Shape(parts=[
            lathe([(0.12, 0.62), (0.132, 0.68), (0.222, 0.782)], 0.782,
                  start=(-0.1, 1), end=(-1, 0.55)),                # the skirt
            cls.base(0.54, 0.762),
            Part(mitre_outline(0.19, 0.46, 0.168, 0.6, 0.122)),
            cls.band(0.61, 0.172, 0.026),
            cls.band(0.19, 0.034, 0.011),        # the ring under the ball
            ball(0.5, 0.147, 0.038),
        ], slits=[(2, 0.35, (0.472, 0.462), 0.024)])

    @classmethod
    def queen(cls):
        # a coronet flaring from a low waist to five pearled points: widest at
        # its top, where the king is widest at its shoulders
        waist = 0.62
        outer, inner = (0.164, 0.228), (0.342, 0.206)
        crown = (Path((0.5, 0.262))
                 .C((0.48, 0.262), (0.462, 0.272), (0.452, 0.288)).corner()
                 .L(inner).corner()
                 .L((0.296, 0.29)).corner()
                 .C((0.28, 0.272), (0.232, 0.248), outer).corner()
                 .through([(0.215, 0.34), (0.3, 0.5), (0.34, waist - 0.012)], start=(0.25, 1), end=(0.4, 1))
                 .corner().L((0.5, waist - 0.012)).mirror())
        pearls = [ball(x, y, 0.037) for x, y in
                  ((outer[0], 0.221), (inner[0], 0.198), (1 - inner[0], 0.198), (1 - outer[0], 0.221))]
        return Shape(parts=[
            lathe([(0.155, waist), (0.17, 0.68), (0.232, 0.776)], 0.776, start=(-0.05, 1), end=(-1, 0.8)),
            cls.base(0.6, 0.752),
            Part(rrect(0.476, 0.18, 0.524, 0.27, 0.014)),   # the top pearl's post
            Part(crown.points()), *pearls,
            cls.band(waist, 0.18, 0.024),
            cls.band(0.206, 0.036, 0.012),
            ball(0.5, 0.14, 0.046),
        ])

    @classmethod
    def king(cls):
        # two round arches over a banded brim, parted by a tall bulb that
        # rises above them and carries the cross
        brim, waist = 0.46, 0.64
        crown = arched_crown(0.44, [(0.478, 0.38), (0.456, 0.33), (0.408, 0.274), (0.334, 0.252),
                                    (0.255, 0.275), (0.186, 0.35), (0.194, 0.42), (0.232, brim)], brim)
        return Shape(parts=[
            lathe([(0.17, waist), (0.184, 0.7), (0.232, 0.776)], 0.776, start=(-0.05, 1), end=(-1, 0.8)),
            cls.base(0.6, 0.752),
            lathe([(0.185, brim), (0.163, 0.55), (0.18, waist - 0.01)], waist - 0.01, start=(0.1, 1), end=(-0.1, 1)),
            king_cross(0.066, 0.19, 0.03, 0.088, 0.1, 0.14, 0.007),
            crown,
            crown_bulb(0.176, 0.072, 0.34, 0.45),
            cls.band(brim, 0.262, 0.026),             # the brim, in two bands
            cls.band(brim + 0.042, 0.226, 0.018),
            cls.band(waist, 0.198, 0.024),
        ])

    @classmethod
    def knight(cls):
        return knight_shape(Part(knight_outline(), "free"), [cls.base(0.56, 0.756)],
                            knight_features())


def shift(shape, dx, keep=()):
    """Moves a shape sideways, except the parts in [keep] (a pedestal that
    must stay centred)."""
    mv = lambda pts: [(x + dx, y) for x, y in pts]
    parts = [p if i in keep else
             Part(mv(p), p.kind, facets=[(mv(q), n) for q, n in p.facets] if p.facets else None)
             for i, p in enumerate(shape.parts)]
    return Shape(parts=parts, seams=[mv(s) for s in shape.seams],
                 dots=[((c[0] + dx, c[1]), rx, ry) for c, rx, ry in shape.dots],
                 slits=shape.slits, glints=[((c[0] + dx, c[1]), r) for c, r in shape.glints],
                 marks=[mv(m) for m in shape.marks],
                 shades=[(i, s if i in keep else mv(s)) for i, s in shape.shades])


# =============================================================== Modern


class Modern:
    """The pieces reduced to geometry: trapezoids, circles, straight cuts,
    every corner filleted, on a two-slab plinth."""

    BOT = 0.889

    @classmethod
    def plinth(cls, w=0.53):
        """Two slabs, a wide foot and a narrower step; [w] scales with rank."""
        a, b = 0.5 - w / 2, 0.5 - w / 2 + 0.05
        return [Part(fillet([(a, cls.BOT), (a, 0.826), (1 - a, 0.826), (1 - a, cls.BOT)], 0.026)),
                Part(fillet([(b, 0.832), (b, 0.79), (1 - b, 0.79), (1 - b, 0.832)], 0.014))]

    @staticmethod
    def trapezoid(y_top, hw_top, y_bot, hw_bot, r=0.012):
        return Part(fillet([(0.5 - hw_bot, y_bot), (0.5 - hw_top, y_top),
                            (0.5 + hw_top, y_top), (0.5 + hw_bot, y_bot)], r))

    @staticmethod
    def disc(cy, hw, hh=0.02):
        return Part(fillet([(0.5 - hw, cy + hh), (0.5 - hw, cy - hh),
                            (0.5 + hw, cy - hh), (0.5 + hw, cy + hh)], hh * 0.9))

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.trapezoid(0.52, 0.07, 0.8, 0.168),
            *cls.plinth(0.46),
            cls.disc(0.515, 0.13),
            ball(0.5, 0.368, 0.126),
        ])

    @classmethod
    def rook(cls):
        top, d = 0.19, 0.064
        xs = [0.252, 0.382, 0.448, 0.552, 0.618, 0.748]
        turret = fillet([(xs[0], 0.33), (xs[0], top), (xs[1], top), (xs[1], top + d),
                         (xs[2], top + d), (xs[2], top), (xs[3], top), (xs[3], top + d),
                         (xs[4], top + d), (xs[4], top), (xs[5], top), (xs[5], 0.33),
                         (0.5 + 0.2, 0.37), (0.5 - 0.2, 0.37)], 0.008)   # a corbel under it
        return Shape(parts=[
            cls.trapezoid(0.36, 0.184, 0.8, 0.214),
            *cls.plinth(0.55),
            Part(turret),
            cls.disc(0.372, 0.214),
        ])

    @classmethod
    def bishop(cls):
        return Shape(parts=[
            cls.trapezoid(0.6, 0.104, 0.8, 0.186),
            *cls.plinth(0.5),
            Part(fillet(lancet_outline(0.172, 0.49, 0.168, 0.6, 0.13), 0.006)),
            cls.disc(0.6, 0.16),
            ball(0.5, 0.146, 0.034),
        ], slits=[(3, 0.35, (0.474, 0.462), 0.028)])

    @classmethod
    def queen(cls):
        # a V from the collar to five points; the middle one carries the ball
        half = [(0.366, 0.6), (0.138, 0.21), (0.254, 0.29), (0.336, 0.196), (0.418, 0.28), (0.5, 0.17)]
        crown = half + [(1 - x, y) for x, y in reversed(half[:-1])]
        return Shape(parts=[
            cls.trapezoid(0.61, 0.12, 0.8, 0.2),
            *cls.plinth(0.54),
            Part(fillet(crown, 0.008)),
            cls.disc(0.61, 0.16),
            ball(0.5, 0.14, 0.032),
        ])

    @classmethod
    def king(cls):
        # the arched crown in straight cuts, rounded; a round orb; the cross
        brim = 0.47
        half = [(0.5, 0.44), (0.47, 0.37), (0.432, 0.29), (0.36, 0.25), (0.27, 0.258), (0.19, 0.33),
                (0.194, 0.43), (0.236, brim)]
        crown = fillet(half + [(1 - x, y) for x, y in reversed(half[1:])], 0.03)
        return Shape(parts=[
            cls.trapezoid(0.63, 0.12, 0.8, 0.214),
            *cls.plinth(0.56),
            cls.trapezoid(brim, 0.15, 0.63, 0.12),
            king_cross(0.056, 0.21, 0.034, 0.096, 0.098, 0.146, 0.008),
            Part(crown),
            ball(0.5, 0.25, 0.06),
            cls.disc(brim, 0.262, 0.024),
            cls.disc(0.63, 0.156),
        ])

    @classmethod
    def knight(cls):
        foot = 0.8
        return knight_shape(Part(fillet(knight_polygon(foot), 0.018), "free"), cls.plinth(),
                            knight_features(foot, eye_scale=0.9), nostril=False)


# =============================================================== Bold


class Bold:
    """Chunky, rounded, toy-like: big heads on short swelling cones, a puck
    for a base."""

    BOT = 0.884

    @classmethod
    def puck(cls, w=0.58):
        return Part(rrect(0.5 - w / 2, 0.79, 0.5 + w / 2, cls.BOT, 0.044))

    @staticmethod
    def cone(y_top, hw_top, hw_bot, y_bot=0.81, belly=0.16):
        """A cone whose flanks swell outward by [belly], as a share of its
        spread (0 is straight)."""
        xt, xb = 0.5 - hw_top, 0.5 - hw_bot
        spread = xt - xb

        def along(t, push):
            return (xt + (xb - xt) * t - spread * push, y_top + (y_bot - y_top) * t)

        p = Path((0.5, y_top)).L((xt, y_top))
        p.C(along(1 / 3, belly), along(2 / 3, belly * 0.5), (xb, y_bot))
        p.L((0.5, y_bot))
        return Part(p.mirror().points())

    @staticmethod
    def pill(cy, hw, hh=0.026):
        return Part(rrect(0.5 - hw, cy - hh, 0.5 + hw, cy + hh, hh))

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.cone(0.55, 0.1, 0.175),
            cls.puck(0.44),
            cls.pill(0.552, 0.13),
            ball(0.5, 0.402, 0.15),
        ])

    @classmethod
    def rook(cls):
        top, d = 0.19, 0.068
        turret = fillet([(0.25, 0.39), (0.25, top), (0.384, top), (0.384, top + d),
                         (0.446, top + d), (0.446, top), (0.554, top), (0.554, top + d),
                         (0.616, top + d), (0.616, top), (0.75, top), (0.75, 0.39)], 0.022)
        return Shape(parts=[
            cls.cone(0.38, 0.2, 0.24, belly=0.1),
            cls.puck(),
            Part(turret),
            cls.pill(0.392, 0.236, 0.028),
        ])

    @classmethod
    def bishop(cls):
        return Shape(parts=[
            cls.cone(0.59, 0.096, 0.214),
            cls.puck(0.56),
            Part(fillet(mitre_outline(0.19, 0.45, 0.162, 0.585, 0.118), 0.012)),
            cls.pill(0.592, 0.148, 0.028),
            ball(0.5, 0.15, 0.047),
        ], slits=[(2, 0.34, (0.468, 0.45), 0.034)])

    @classmethod
    def queen(cls):
        # an open cup flaring from a low waist, pearls along its rim
        waist = 0.6
        cup = (Path((0.5, 0.29))
               .C((0.42, 0.29), (0.26, 0.288), (0.2, 0.272)).corner()
               .through([(0.255, 0.38), (0.33, 0.5), (0.372, waist)], start=(0.3, 1), end=(0.45, 1))
               .corner().L((0.5, waist)).mirror().points())
        pearls = [ball(0.5 + dx, y, 0.047) for dx, y in
                  ((-0.298, 0.25), (-0.15, 0.214), (0.15, 0.214), (0.298, 0.25))]
        return Shape(parts=[
            cls.cone(waist, 0.11, 0.226), cls.puck(),
            Part(rrect(0.468, 0.16, 0.532, 0.29, 0.03)),   # the top pearl's post
            *pearls,
            Part(cup),
            cls.pill(waist, 0.166, 0.03),
            ball(0.5, 0.148, 0.05),
        ])

    @classmethod
    def king(cls):
        # the arched crown, chunky; the bulb; the thick cross
        brim, waist = 0.47, 0.62
        crown = arched_crown(0.44, [(0.476, 0.38), (0.452, 0.33), (0.404, 0.276), (0.334, 0.256), (0.255, 0.28),
                                    (0.186, 0.355), (0.194, 0.425), (0.232, brim)], brim)
        return Shape(parts=[
            cls.cone(waist, 0.12, 0.222), cls.puck(),
            cls.cone(brim, 0.18, 0.13, waist, belly=0.0),
            king_cross(0.054, 0.2, 0.047, 0.118, 0.1, 0.16, 0.024),
            crown,
            crown_bulb(0.18, 0.078, 0.34, 0.45),
            cls.pill(brim, 0.27, 0.028),
            cls.pill(waist, 0.17, 0.03),
        ])

    @classmethod
    def knight(cls):
        foot = 0.8
        return knight_shape(Part(knight_outline(foot), "free"), [cls.puck()],
                            knight_features(foot, eye_scale=1.35), glint=True)


# =============================================================== the jewel


def jewel(cx, cy, w, h, girdle=0.44):
    """The neutral king's finial: a cut gem, pointed above and below, its
    girdle [girdle] of the way down. A single point at the top that no other
    piece has: the queen wears pearls, the bishop a ball.

    It must stay a broad rhombus, wider than tall, set into the crown
    between its arches. Tall, on a long thin neck, a gem's post and girdle
    read as a small cross at thumbnail size, which is exactly what it
    replaces."""
    gy = cy - h / 2 + h * girdle
    return [(cx, cy - h / 2), (cx + w / 2, gy), (cx, cy + h / 2), (cx - w / 2, gy)]


def jewel_cuts(cx, cy, w, h, girdle=0.44):
    """The gem's girdle and its keel: the two lines that make it read as cut."""
    gy = cy - h / 2 + h * girdle
    return [[(cx - w / 2 + 0.006, gy), (cx + w / 2 - 0.006, gy)],
            [(cx, cy - h / 2 + 0.012), (cx, cy + h / 2 - 0.014)]]


# The king wears the ARCHED crown every player knows (cburnett, merida, the
# Staunton icons): two round arches over a banded brim, parted in the middle
# by a bulb that carries the cross, or, in the neutral sets, by the cut gem.
# `audit` checks for it (`king_form`): a domed crown read as a lidded pot.


def arched_crown(cusp, pts, brim, apex_dir=(-0.3, -1)):
    """The crown's two arches as one outline: from the cusp between them,
    through [pts] (the left arch: inner side, over its top, out to its
    widest, down) to the brim; mirrored."""
    p = Path((0.5, cusp), apex=True)
    p.through(pts, start=apex_dir)
    p.corner().L((0.5, brim))
    return Part(p.mirror().points())


def crown_bulb(tip, hw, neck_y, bottom):
    """The bulb between the arches: pointed above, round, pinched to a neck
    where the arches meet it, then down to the brim."""
    bulb = tip + (neck_y - tip) * 0.5
    p = Path((0.5, tip), apex=True)
    p.through([(0.5 - hw * 0.72, tip + (bulb - tip) * 0.5), (0.5 - hw, bulb), (0.5 - hw * 0.42, neck_y),
               (0.5 - hw * 0.55, bottom - 0.01)], start=(-0.8, 1))
    p.corner().L((0.5, bottom))
    return Part(p.mirror().points())


def king_cross(top, foot, sw, aw, arm0, arm1, r):
    """The cross on the bulb: upright half-width [sw], arms [aw], the arms
    between [arm0] and [arm1]."""
    return Part(fillet([(0.5 - sw, foot), (0.5 - sw, arm1), (0.5 - aw, arm1), (0.5 - aw, arm0),
                        (0.5 - sw, arm0), (0.5 - sw, top), (0.5 + sw, top), (0.5 + sw, arm0),
                        (0.5 + aw, arm0), (0.5 + aw, arm1), (0.5 + sw, arm1), (0.5 + sw, foot)], r), "free")


def gem_crown(gem_bottom, arch_top, arch_x, widest_x, widest_y, brim, brim_x):
    """Arches for a gem king. They meet in a cusp inside the gem's lower tip
    (gem and crown one silhouette), and their inner sides fall steeply from
    the arch tops, so the gem stands clear beside its girdle: set in the
    crown, broad, never on a neck."""
    cusp = gem_bottom - 0.01
    pts = [(0.462, cusp - 0.006), (0.43, cusp - 0.018), (0.395, arch_top + 0.034), (arch_x, arch_top),
           (widest_x + 0.062, arch_top + 0.026), (widest_x, widest_y), (widest_x + 0.008, brim - 0.04),
           (brim_x, brim)]
    return arched_crown(cusp, pts, brim, apex_dir=(-1, -0.25))


def set_gem(top, w, h):
    """The cut gem, its top at [top]: wider than tall."""
    return Part(jewel(0.5, top + h / 2, w, h, girdle=0.5), "gem")


# The bishop wears the Staunton MITRE (physical Staunton sets, chess.com):
# taller than wide, rising to a point under a small ball, cut by a thin slit
# from its upper right toward its middle. `audit` checks it (`bishop_form`):
# a rounder head, an egg with a wide cut, read as a Pac-Man.


def mitre_outline(tip, widest_y, hw, bottom, bottom_hw, tip_dir=(-0.75, 1)):
    """The mitre: a point at [tip], its sides swelling to half-width [hw] at
    [widest_y] (below its middle), closing to [bottom_hw] at [bottom]."""
    p = Path((0.5, tip), apex=True)
    p.through([(0.5 - hw * 0.36, tip + 0.05), (0.5 - hw * 0.8, tip + (widest_y - tip) * 0.55), (0.5 - hw, widest_y),
               (0.5 - hw * 0.94, (widest_y + bottom) / 2 + 0.02), (0.5 - bottom_hw, bottom)], start=tip_dir)
    p.corner().L((0.5, bottom))
    return p.mirror().points()


def lancet_outline(tip, widest_y, hw, bottom, bottom_hw):
    """The mitre as a lancet, for the geometric sets: two arcs meeting in a
    point, then straight down to the collar."""
    r = (hw * hw + (widest_y - tip) ** 2) / (2 * hw)
    cx = 0.5 - hw + r
    end = math.degrees(math.atan2(tip - widest_y, 0.5 - cx)) % 360
    half = ([(0.5, bottom), (0.5 - bottom_hw, bottom), (0.5 - hw + 0.012, (widest_y + bottom) / 2 + 0.03)]
            + arc(cx, widest_y, r, 180, end - 1.5, n=40))
    return half + [(0.5, tip)] + [(1 - x, y) for x, y in reversed(half[1:])]


def bishop_form(shape):
    """(height / width, width 10% below its tip / its widest) of the mitre:
    the part the bishop's slit is cut into."""
    pts = resample(list(shape.parts[shape.slits[0][0]]), 0.002)
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    top, bot, w = min(ys), max(ys), max(xs) - min(xs)
    band = [q[0] for q in pts if q[1] <= top + 0.1 * (bot - top)]
    return (bot - top) / w, (max(band) - min(band)) / w


# =============================================================== Regal


class Regal:
    """Marble's forms: an elegant Staunton descendant. Slim, tall stems; a
    stepped pedestal (a slab under a cushion); double collars on the royals;
    and, for the king, a closed crown under a cut jewel instead of a cross."""

    BOT = 0.889        # a finer line (2.1%) lands on 0.90

    @classmethod
    def pedestal(cls, w, top=0.8):
        """A slab under a softly domed cushion; [w] scales with rank."""
        x0 = 0.5 - w / 2
        c0 = x0 + 0.028
        p = Path((0.5, 0.852)).L((c0 + 0.02, 0.852))
        p.C((c0 + 0.006, 0.852), (c0, 0.843), (c0, 0.83))
        p.C((c0, top + 0.016), (c0 + 0.022, top + 0.002), (c0 + 0.066, top - 0.005))
        p.C((c0 + 0.12, top - 0.01), (0.5 - 0.1, top - 0.012), (0.5, top - 0.012))
        return [Part(rrect(x0, 0.844, 1 - x0, cls.BOT, 0.018)), Part(p.mirror().points())]

    @staticmethod
    def collars(cy, hw):
        """Two rings, the upper a little narrower: a royal waist."""
        return [Staunton.band(cy, hw, 0.015), Staunton.band(cy - 0.034, hw - 0.014, 0.013)]

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            lathe([(0.074, 0.54), (0.084, 0.62), (0.12, 0.72), (0.19, 0.818)], 0.818,
                  start=(-0.1, 1), end=(-1, 0.6)),
            *cls.pedestal(0.48, 0.806),
            Part(rrect(0.448, 0.46, 0.552, 0.53, 0.018)),
            Staunton.band(0.532, 0.13, 0.018),
            ball(0.5, 0.36, 0.122),
        ])

    @classmethod
    def rook(cls):
        top, notch, x0 = 0.172, 0.226, 0.24
        t = (Path((0.5, 0.35)).L((0.318, 0.35))
             .through([(x0 + 0.01, 0.322)], start=(-1, 0), end=(-0.3, -1)).corner()
             .L((x0, top + 0.008))
             .C((x0, top + 0.002), (x0 + 0.004, top), (x0 + 0.01, top)).corner()
             .L((0.376, top))
             .C((0.382, top), (0.384, top + 0.004), (0.384, top + 0.01)).corner()
             .L((0.384, notch - 0.008))
             .C((0.384, notch - 0.002), (0.387, notch), (0.393, notch)).corner()
             .L((0.441, notch))
             .C((0.447, notch), (0.449, notch - 0.003), (0.449, notch - 0.009)).corner()
             .L((0.449, top + 0.01))
             .C((0.449, top + 0.004), (0.452, top), (0.458, top)).corner()
             .L((0.5, top))
             .mirror())
        return Shape(parts=[
            lathe([(0.178, 0.345), (0.174, 0.48), (0.188, 0.66), (0.236, 0.816)], 0.816,
                  start=(0, 1), end=(-0.7, 1)),
            *cls.pedestal(0.56, 0.8),
            Part(t.points()),
            Staunton.band(0.354, 0.196, 0.017),
        ])

    @classmethod
    def bishop(cls):
        return Shape(parts=[
            lathe([(0.116, 0.62), (0.128, 0.69), (0.214, 0.82)], 0.82, start=(-0.1, 1), end=(-1, 0.55)),
            *cls.pedestal(0.52, 0.802),
            Part(mitre_outline(0.186, 0.465, 0.17, 0.592, 0.118)),
            *cls.collars(0.624, 0.16),
            Staunton.band(0.186, 0.03, 0.01),
            ball(0.5, 0.146, 0.034),
        ], slits=[(3, 0.35, (0.472, 0.462), 0.022)])

    @classmethod
    def queen(cls):
        waist = 0.63
        outer, inner = (0.17, 0.222), (0.346, 0.2)
        crown = (Path((0.5, 0.262))
                 .C((0.482, 0.262), (0.466, 0.272), (0.456, 0.288)).corner()
                 .L(inner).corner()
                 .L((0.302, 0.286)).corner()
                 .C((0.286, 0.268), (0.238, 0.244), outer).corner()
                 .through([(0.222, 0.34), (0.306, 0.49), (0.346, waist - 0.046)], start=(0.25, 1), end=(0.4, 1))
                 .corner().L((0.5, waist - 0.046)).mirror())
        pearls = [ball(x, y, 0.031) for x, y in
                  ((outer[0], 0.216), (inner[0], 0.194), (1 - inner[0], 0.194), (1 - outer[0], 0.216))]
        return Shape(parts=[
            lathe([(0.146, waist), (0.158, 0.7), (0.222, 0.818)], 0.818, start=(-0.05, 1), end=(-1, 0.8)),
            *cls.pedestal(0.58, 0.798),
            Part(rrect(0.479, 0.16, 0.521, 0.27, 0.014)),
            Part(crown.points()), *pearls,
            *cls.collars(waist, 0.17),
            Staunton.band(0.184, 0.03, 0.011),
            ball(0.5, 0.136, 0.036),
        ])

    @classmethod
    def king(cls):
        # the arched crown with the cut gem set between its arches
        brim, waist, top, w, h = 0.5, 0.64, 0.088, 0.24, 0.21
        return Shape(parts=[
            lathe([(0.128, waist), (0.142, 0.7), (0.222, 0.818)], 0.818, start=(-0.05, 1), end=(-1, 0.8)),
            *cls.pedestal(0.58, 0.798),
            lathe([(0.15, brim), (0.13, (brim + waist) / 2), (0.142, waist - 0.04)], waist - 0.04,
                  start=(0.1, 1), end=(-0.05, 1)),
            gem_crown(top + h, 0.236, 0.336, 0.19, 0.38, brim, 0.235),
            set_gem(top, w, h),
            Staunton.band(brim, 0.258, 0.022),
            Staunton.band(brim + 0.036, 0.222, 0.015),
            *cls.collars(waist, 0.15),
        ], seams=jewel_cuts(0.5, top + h / 2, w, h, girdle=0.5)[:1])

    @classmethod
    def knight(cls):
        foot = 0.814
        return knight_shape(Part(knight_outline(foot), "free"), cls.pedestal(0.54, 0.8),
                            knight_features(foot))


# =============================================================== Marble

MARBLE_MATERIAL = {
    "w": Material(shadow=(170, 166, 160), lit=(246, 244, 240), ambient=0.42,
                  spec=0.32, shine=36, spec_colour=(252, 251, 249)),
    "b": Material(shadow=(20, 24, 23), lit=(90, 100, 96), ambient=0.30,
                  spec=0.28, shine=36, spec_colour=(150, 164, 158)),
}
MARBLE = Style(
    edge=0.021, inner=0.013, seam=0.012,
    fill=lambda cv, part, m, colour: light_part(cv, part, m, MARBLE_MATERIAL[colour]),
    line_edge={"w": (62, 60, 57), "b": (12, 14, 13)},
    line_inner={"w": (136, 132, 126), "b": (24, 28, 27)},
    detail={"w": (104, 100, 95), "b": (14, 16, 15)}, ao=0.14,
    seam_tone={"w": (150, 146, 140), "b": (34, 40, 38)}, shadow=soft_shadow(0.14))


# =============================================================== Deco


def steps(cy_bottom, levels):
    """Stacked slabs, bottom first: [(half-width, height), ...]. A ziggurat
    when they narrow upward, a stepped crown when they widen."""
    parts, y = [], cy_bottom
    for hw, h in levels:
        parts.append(Part(fillet([(0.5 - hw, y), (0.5 - hw, y - h), (0.5 + hw, y - h), (0.5 + hw, y)], 0.004)))
        y -= h - 0.004
    return parts


class Deco:
    """Art Deco: a three-step plinth, tall fluted shafts, stepped collars, a
    sunburst queen, a ziggurat rook, a lancet bishop, a stepped mane."""

    BOT = 0.889

    @classmethod
    def plinth(cls, w):
        a = w / 2
        return steps(cls.BOT, [(a, 0.028), (a - 0.034, 0.028), (a - 0.068, 0.03)])

    @staticmethod
    def shaft(top_y, top_hw, bot_hw, bot_y=0.816):
        return Part(fillet([(0.5 - bot_hw, bot_y), (0.5 - top_hw, top_y), (0.5 + top_hw, top_y),
                            (0.5 + bot_hw, bot_y)], 0.004))

    @staticmethod
    def flutes(top_y, bot_y, dx):
        return [[(0.5 - dx, top_y), (0.5 - dx * 1.4, bot_y)], [(0.5 + dx, top_y), (0.5 + dx * 1.4, bot_y)]]

    @staticmethod
    def collar(cy, hw):
        return steps(cy + 0.016, [(hw, 0.022), (hw - 0.026, 0.02)])

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.shaft(0.5, 0.066, 0.132, 0.8),
            *cls.plinth(0.48),
            *cls.collar(0.5, 0.128),
            ball(0.5, 0.356, 0.122),
        ], seams=cls.flutes(0.54, 0.77, 0.03))

    @classmethod
    def rook(cls):
        # a ziggurat turret: the centre merlon steps up above the others
        top = [(0.27, 0.33), (0.27, 0.206), (0.378, 0.206), (0.378, 0.246), (0.426, 0.246),
               (0.426, 0.198), (0.452, 0.198), (0.452, 0.164), (0.548, 0.164), (0.548, 0.198),
               (0.574, 0.198), (0.574, 0.246), (0.622, 0.246), (0.622, 0.206), (0.73, 0.206), (0.73, 0.33)]
        return Shape(parts=[
            cls.shaft(0.33, 0.17, 0.206),
            *cls.plinth(0.58),
            Part(fillet(top, 0.005)),
            *steps(0.36, [(0.236, 0.024), (0.21, 0.02)]),
        ], seams=cls.flutes(0.4, 0.78, 0.06))

    @classmethod
    def bishop(cls):
        # a lancet arch: two arcs meeting in a point
        return Shape(parts=[
            cls.shaft(0.6, 0.088, 0.152),
            *cls.plinth(0.52),
            Part(fillet(lancet_outline(0.152, 0.48, 0.172, 0.596, 0.13), 0.006)),
            *cls.collar(0.602, 0.16),
            ball(0.5, 0.134, 0.026),
        ], slits=[(4, 0.34, (0.472, 0.452), 0.024)], seams=cls.flutes(0.64, 0.78, 0.026))

    @classmethod
    def queen(cls):
        # a sunburst: five rays fanning from the collar, beads at their tips
        cx, cy, rt, rv = 0.5, 0.43, (0.345, 0.31), (0.262, 0.236)
        pts = [(cx - 0.17, cy + 0.016)]
        for k, ang in enumerate((162, 144, 126, 108, 90, 72, 54, 36, 18)):
            rx, ry = rt if k % 2 == 0 else rv
            a = math.radians(ang)
            pts.append((cx + rx * math.cos(a), cy - ry * math.sin(a)))
        pts.append((cx + 0.17, cy + 0.016))
        fan = fillet(pts, 0.006)
        beads = [ball(cx + rt[0] * math.cos(math.radians(a)), cy - rt[1] * math.sin(math.radians(a)), 0.022)
                 for a in (162, 126, 54, 18)]
        rays = [[(cx + 0.08 * math.cos(math.radians(a)), cy - 0.08 * math.sin(math.radians(a))),
                 (cx + 0.2 * math.cos(math.radians(a)), cy - 0.19 * math.sin(math.radians(a)))]
                for a in (162, 126, 90, 54, 18)]
        return Shape(parts=[
            cls.shaft(cy + 0.018, 0.088, 0.15),
            *cls.plinth(0.58),
            Part(fan), *beads,
            *cls.collar(cy + 0.016, 0.18),
            ball(cx, cy - rt[1] - 0.006, 0.026),
        ], seams=rays + cls.flutes(0.49, 0.78, 0.026))

    @classmethod
    def king(cls):
        # the arched crown on a stepped brim, the cut gem between its arches
        brim, waist, top, w, h = 0.47, 0.6, 0.078, 0.24, 0.21
        return Shape(parts=[
            cls.shaft(waist, 0.1, 0.15),
            *cls.plinth(0.58),
            cls.shaft(brim, 0.17, 0.13, waist),
            gem_crown(top + h, 0.23, 0.336, 0.19, 0.345, brim, 0.235),
            set_gem(top, w, h),
            *steps(brim + 0.04, [(0.24, 0.024), (0.27, 0.022)]),
            *cls.collar(waist + 0.02, 0.19),
        ], seams=jewel_cuts(0.5, top + h / 2, w, h, girdle=0.5)[:1] + cls.flutes(0.64, 0.78, 0.03)
           + [[(0.4, 0.33), (0.3, 0.42)], [(0.6, 0.33), (0.7, 0.42)]])

    @classmethod
    def knight(cls):
        foot = 0.814
        # the crest in steps, the Deco mane
        mane = [(0.536, 0.19), (0.536, 0.236), (0.614, 0.236), (0.614, 0.298), (0.686, 0.298),
                (0.686, 0.376), (0.744, 0.376), (0.744, 0.468), (0.786, 0.468), (0.786, 0.566)]
        return knight_shape(Part(fillet(knight_polygon(foot, mane), 0.01), "free"), cls.plinth(0.54),
                            knight_features(foot), nostril=False)


DECO_MATERIAL = {
    "w": Material(shadow=(208, 198, 180), lit=(247, 243, 234), ambient=0.55),
    "b": Material(shadow=(24, 23, 26), lit=(74, 72, 78), ambient=0.42),
}
GOLD_LINE = {"w": (176, 142, 82), "b": (186, 152, 92)}
DECO = Style(
    edge=0.022, inner=0.013, seam=0.011,
    fill=lambda cv, part, m, colour: light_part(cv, part, m, DECO_MATERIAL[colour]),
    line_edge={"w": (62, 56, 48), "b": (16, 15, 18)},
    line_inner=GOLD_LINE, detail={"w": (62, 56, 48), "b": (186, 152, 92)}, ao=0.10,
    seam_tone=GOLD_LINE, shadow=soft_shadow(0.12))


# =============================================================== Facet


def half_width_at(points, y):
    """The widest reach right of the axis where the outline crosses [y]."""
    best = 0.0
    n = len(points)
    for i in range(n):
        (x0, y0), (x1, y1) = points[i], points[(i + 1) % n]
        if (y0 - y) * (y1 - y) <= 0 and y0 != y1:
            x = x0 + (x1 - x0) * (y - y0) / (y1 - y0)
            best = max(best, x - 0.5)
    return best


def facet_bands(cv, part, mask, material, cuts=(-0.5, 0.0, 0.5), tones=(1.0, 0.84, 0.62, 0.4)):
    """A turned part cut into flat vertical planes: each band between two
    [cuts] (fractions of the local half-width) is one evenly stepped tone,
    lit to shaded from the left. The bands follow the outline's own
    vertices, so on a straight-sided part every boundary is a straight line."""
    ys = sorted({round(p[1], 6) for p in part})
    edges = [-1.2, *cuts, 1.2]
    for (a, b), t in zip(zip(edges, edges[1:]), tones):
        left = [(0.5 + a * half_width_at(part, y), y) for y in ys]
        right = [(0.5 + b * half_width_at(part, y), y) for y in reversed(ys)]
        cv.paint(ImageChops.multiply(cv.mask(left + right), mask),
                 mix(material.shadow, material.lit, material.ambient + (1 - material.ambient) * t))


def facet_orb(cv, part, mask, material, inner=0.46):
    """A cut ball: a table facing the viewer, ringed by planes facing out."""
    xs, ys = [p[0] for p in part], [p[1] for p in part]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ring = [(cx + (x - cx) * inner, cy + (y - cy) * inner) for x, y in part]
    n = len(part)
    for i in range(n):
        a, b = part[i], part[(i + 1) % n]
        ia, ib = ring[i], ring[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        d = math.hypot(mx, my) or 1
        normal = _norm3((mx / d * 0.75, my / d * 0.75, 0.66))
        cv.paint(ImageChops.multiply(cv.mask([a, b, ib, ia]), mask), material.at(normal))
    cv.paint(ImageChops.multiply(cv.mask(ring), mask), material.at(_norm3((-0.12, -0.1, 1))))


def facet_fill(material):
    def fill(cv, part, m, colour):
        mat = material[colour]
        cv.paint(m, mat.at((0.0, 0.0, 1.0)))  # a base tone first: no plane may leave a hole
        if part.facets:
            for poly, n in part.facets:
                cv.paint(ImageChops.multiply(cv.mask(poly), m), mat.at(_norm3(n)))
        elif part.kind == "gem":
            light_gem(cv, part, m, mat)
        elif part.kind == "sphere":
            facet_orb(cv, part, m, mat)
        else:
            facet_bands(cv, part, m, mat)
    return fill


def orb(cx, cy, r, n=8):
    """A regular polygon ball, a flat side on top."""
    return Part([(cx + r * math.cos(math.radians(90 + 180 / n + 360 * i / n)),
                  cy - r * math.sin(math.radians(90 + 180 / n + 360 * i / n))) for i in range(n)],
                "sphere")


class Facet:
    """Low-poly: every outline straight, every surface a plane."""

    BOT = 0.89

    @classmethod
    def plinth(cls, w):
        a = 0.5 - w / 2
        return Part([(a, cls.BOT), (a, 0.858), (a + 0.034, 0.806), (1 - a - 0.034, 0.806),
                     (1 - a, 0.858), (1 - a, cls.BOT)])

    @staticmethod
    def prism(top_y, top_hw, bot_hw, bot_y=0.814):
        return Part([(0.5 - bot_hw, bot_y), (0.5 - top_hw, top_y), (0.5 + top_hw, top_y),
                     (0.5 + bot_hw, bot_y)])

    @staticmethod
    def collar(cy, hw, hh=0.022):
        return Part([(0.5 - hw + hh, cy - hh), (0.5 - hw, cy), (0.5 - hw + hh, cy + hh),
                     (0.5 + hw - hh, cy + hh), (0.5 + hw, cy), (0.5 + hw - hh, cy - hh)])

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.prism(0.52, 0.066, 0.172),
            cls.plinth(0.46),
            cls.collar(0.518, 0.13),
            orb(0.5, 0.364, 0.126),
        ])

    @classmethod
    def rook(cls):
        top, d = 0.196, 0.064
        xs = [0.256, 0.382, 0.448, 0.552, 0.618, 0.744]
        turret = [(xs[0], 0.36), (xs[0], top), (xs[1], top), (xs[1], top + d), (xs[2], top + d),
                  (xs[2], top), (xs[3], top), (xs[3], top + d), (xs[4], top + d), (xs[4], top),
                  (xs[5], top), (xs[5], 0.36)]
        return Shape(parts=[
            cls.prism(0.35, 0.18, 0.214),
            cls.plinth(0.57),
            Part(turret),
            cls.collar(0.362, 0.232, 0.02),
        ])

    @classmethod
    def bishop(cls):
        half = [(0.5, 0.6), (0.378, 0.6), (0.334, 0.53), (0.322, 0.45), (0.35, 0.35), (0.428, 0.25)]
        mitre = half + [(0.5, 0.17)] + [(1 - x, y) for x, y in reversed(half[1:])]
        return Shape(parts=[
            cls.prism(0.6, 0.1, 0.184),
            cls.plinth(0.52),
            Part(mitre),
            cls.collar(0.598, 0.166),
            orb(0.5, 0.136, 0.033, n=6),
        ], slits=[(2, 0.35, (0.472, 0.462), 0.024)])

    @classmethod
    def queen(cls):
        # a V of planes from the collar to five points: an open crown
        half = [(0.39, 0.6), (0.214, 0.33), (0.146, 0.206), (0.268, 0.29), (0.34, 0.188),
                (0.424, 0.285), (0.5, 0.16)]
        crown = half + [(1 - x, y) for x, y in reversed(half[:-1])]
        return Shape(parts=[
            cls.prism(0.61, 0.12, 0.2),
            cls.plinth(0.57),
            Part(crown),
            cls.collar(0.606, 0.162),
            orb(0.5, 0.13, 0.031, n=6),
        ])

    @classmethod
    def king(cls):
        # the arched crown in planes, carried low on a short prism, the gem
        # between its arches
        brim, top, w, h, stem = 0.56, 0.094, 0.24, 0.21, 0.13
        cusp = top + h - 0.01
        half = [(0.5, cusp), (0.44, cusp - 0.014), (0.396, 0.29), (0.336, 0.262), (0.25, 0.288),
                (0.195, 0.43), (0.225, brim - 0.04), (0.5 - stem - 0.03, brim)]
        return Shape(parts=[
            cls.prism(brim - 0.01, stem, 0.2),
            cls.plinth(0.57),
            Part(half + [(1 - x, y) for x, y in reversed(half[1:])]),
            set_gem(top, w, h),
            cls.collar(brim, stem + 0.05, 0.02),
        ])

    @classmethod
    def knight(cls):
        foot = 0.814
        m = {k: _fit_pt(v, foot) for k, v in KNIGHT_MARKS.items()}
        # the crest in three planes, and four points inside the head where
        # its planes meet: the cheekbone, behind the eye, mid-neck, the throat
        L, M, N = (_fit_pt(q, foot) for q in ((0.62, 0.232), (0.742, 0.345), (0.784, 0.52)))
        E, G, Q, R = (_fit_pt(q, foot) for q in ((0.37, 0.36), (0.48, 0.3), (0.6, 0.47), (0.47, 0.64)))
        facets = [([m["brow"], m["tip"], m["poll"]], (-0.45, -0.7, 0.55)),               # the ear
                  ([m["brow"], m["poll"], G, E], (-0.2, -0.5, 0.84)),                   # the brow
                  ([m["brow"], E, m["muzzle"]], (-0.62, -0.35, 0.7)),                   # the face
                  ([m["muzzle"], E, m["jaw"], m["chin"]], (-0.45, 0.25, 0.86)),         # the muzzle
                  ([E, G, m["notch"], m["jowl"], m["jaw"]], (0.08, 0.28, 0.96)),        # the jowl
                  ([m["poll"], L, G], (0.1, -0.88, 0.46)),                              # the crest
                  ([G, L, M, Q], (0.38, -0.45, 0.81)),
                  ([G, Q, m["notch"]], (0.15, 0.35, 0.92)),                             # behind the jowl
                  ([Q, M, N, m["back"]], (0.74, -0.05, 0.67)),                          # the back
                  ([m["notch"], Q, R, m["throat"]], (-0.1, 0.3, 0.95)),                 # the throat
                  ([m["throat"], R, m["chest"], m["neck"]], (-0.4, 0.15, 0.9)),         # the neck front
                  ([R, Q, m["back"], m["heel"], m["foot"], m["chest"]], (0.35, 0.12, 0.93))]
        head = Part([m["foot"], m["chest"], m["neck"], m["throat"], m["notch"], m["jowl"], m["jaw"], m["chin"],
                     m["muzzle"], m["brow"], m["tip"], m["poll"], L, M, N, m["back"], m["heel"]],
                    "free", facets=facets)
        return knight_shape(head, [cls.plinth(0.54)], knight_features(foot), nostril=False)


FACET_MATERIAL = {
    "w": Material(shadow=(132, 130, 126), lit=(248, 247, 244), ambient=0.36),
    "b": Material(shadow=(26, 28, 32), lit=(122, 126, 134), ambient=0.26),
}
FACET = Style(
    edge=0.02, inner=0.012, seam=0.012, fill=facet_fill(FACET_MATERIAL),
    line_edge={"w": (66, 66, 68), "b": (20, 21, 24)},
    line_inner={"w": (150, 150, 152), "b": (30, 32, 36)},
    detail={"w": (66, 66, 68), "b": (150, 154, 162)})


# =============================================================== Silhouette


class Glyph:
    """Silhouette's forms: pieces told apart by outline alone. Generous gaps
    between features (a queen's rays, a rook's crenels, the bishop's cut),
    each piece its own body, no line inside."""

    BOT = 0.886

    @classmethod
    def slab(cls, w):
        return Part(rrect(0.5 - w / 2, 0.828, 0.5 + w / 2, cls.BOT, 0.022))

    @staticmethod
    def cone(top_y, top_hw, bot_hw, bot_y=0.836):
        return Part(fillet([(0.5 - bot_hw, bot_y), (0.5 - top_hw, top_y), (0.5 + top_hw, top_y),
                            (0.5 + bot_hw, bot_y)], 0.008))

    @staticmethod
    def disc(cy, hw, hh=0.018):
        return Part(rrect(0.5 - hw, cy - hh, 0.5 + hw, cy + hh, hh))

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.cone(0.52, 0.064, 0.172),
            cls.slab(0.46),
            cls.disc(0.522, 0.118),
            ball(0.5, 0.372, 0.128),
        ])

    @classmethod
    def rook(cls):
        top, d = 0.196, 0.082
        xs = [0.268, 0.38, 0.452, 0.548, 0.62, 0.732]
        turret = fillet([(xs[0], 0.36), (xs[0], top), (xs[1], top), (xs[1], top + d), (xs[2], top + d),
                         (xs[2], top), (xs[3], top), (xs[3], top + d), (xs[4], top + d), (xs[4], top),
                         (xs[5], top), (xs[5], 0.36)], 0.008)
        return Shape(parts=[
            cls.cone(0.35, 0.172, 0.206),
            cls.slab(0.57),
            Part(turret),
        ])

    @classmethod
    def bishop(cls):
        # the slit opened wider: in outline alone it must still read
        return Shape(parts=[
            cls.cone(0.606, 0.088, 0.188),
            cls.slab(0.48),
            Part(mitre_outline(0.172, 0.47, 0.18, 0.6, 0.128)),
            cls.disc(0.604, 0.138),
            ball(0.5, 0.136, 0.034),
        ], slits=[(2, 0.33, (0.46, 0.47), 0.042)])

    @classmethod
    def queen(cls):
        # five rays with a pearl on each, deep gaps between them: an open crown
        half = [(0.404, 0.604), (0.27, 0.4), (0.15, 0.2), (0.3, 0.3), (0.35, 0.16),
                (0.418, 0.3), (0.5, 0.144)]
        crown = half + [(1 - x, y) for x, y in reversed(half[:-1])]
        pearls = [ball(x, y, 0.032) for x, y in ((0.15, 0.194), (0.35, 0.154), (0.65, 0.154), (0.85, 0.194))]
        return Shape(parts=[
            cls.cone(0.6, 0.096, 0.2),
            cls.slab(0.58),
            Part(fillet(crown, 0.006)), *pearls,
            cls.disc(0.598, 0.132),
            ball(0.5, 0.128, 0.03),
        ])

    @classmethod
    def king(cls):
        # the arched crown carried low, nearly all of the piece, on a short
        # stem: solid arches where the queen's rays are open; the gem
        brim, top, w, h, arch_top, wx = 0.54, 0.088, 0.24, 0.21, 0.27, 0.19
        cusp = top + h - 0.01
        pts = [(0.462, cusp - 0.006), (0.43, cusp - 0.018), (0.395, arch_top + 0.03), (0.336, arch_top),
               (wx + 0.062, arch_top + 0.03), (wx, 0.44), (wx + 0.03, brim - 0.05), (0.36, brim)]
        return Shape(parts=[
            cls.cone(brim - 0.01, 0.12, 0.19),
            cls.slab(0.58),
            arched_crown(cusp, pts, brim, apex_dir=(-1, -0.25)),
            set_gem(top, w, h),
        ])

    @classmethod
    def knight(cls):
        foot = 0.838
        return knight_shape(Part(knight_outline(foot), "free"), [cls.slab(0.54)],
                            knight_features(foot, eye_scale=1.05), nostril=False)


SILHOUETTE_COLOURS = {
    "w": dict(fill=(242, 240, 235), rim=(230, 227, 220), line=(62, 60, 56), detail=(62, 60, 56)),
    "b": dict(fill=(62, 62, 65), rim=(98, 98, 104), line=(26, 26, 28), detail=(150, 150, 156)),
}


def _silhouette_fill(cv, part, m, colour):
    p = SILHOUETTE_COLOURS[colour]
    cv.paint(m, p["fill"])
    w = width_of(cv, m)
    if colour == "b":  # a lit rim inside the left edge gives the dark army depth
        inset = max(0.006, min(0.018, 0.08 * w))
        cv.paint(inner_strip(cv, m, inset, max(0.006, min(0.014, 0.06 * w)), dy=-0.5 * inset), p["rim"])
    else:              # and the light army a whisper of shade on the right
        cv.paint(crescent(cv, m, max(0.01, min(0.04, 0.16 * w))), p["rim"])


SILHOUETTE = Style(
    edge=0.028, inner=0.0, seam=0.012, fill=_silhouette_fill,
    line_edge={c: SILHOUETTE_COLOURS[c]["line"] for c in "wb"},
    line_inner={c: SILHOUETTE_COLOURS[c]["line"] for c in "wb"},
    detail={c: SILHOUETTE_COLOURS[c]["detail"] for c in "wb"})


# =============================================================== Soft


class Pebble:
    """Soft's forms: everything rounded, like carvings in river stone.
    Plump bodies, big heads, no corner tighter than a thumb could smooth."""

    BOT = 0.888

    @classmethod
    def cushion(cls, w):
        return Part(rrect(0.5 - w / 2, 0.8, 0.5 + w / 2, cls.BOT, 0.042))

    @staticmethod
    def body(top_y, top_hw, bot_hw, bot_y=0.814, belly=0.12):
        """A soft cone: rounded shoulders, flanks that swell a little."""
        xt, xb = 0.5 - top_hw, 0.5 - bot_hw
        r = min(0.022, top_hw * 0.4)
        p = Path((0.5, top_y)).L((xt + r, top_y))
        p.C((xt + r * 0.45, top_y), (xt, top_y + r * 0.55), (xt - 0.002, top_y + r)).corner()
        h = bot_y - top_y - r
        p.C((xt - (xt - xb) * belly - 0.004, top_y + r + h * 0.35),
            (xb + 0.004, bot_y - h * 0.3), (xb, bot_y))
        p.L((0.5, bot_y))
        return Part(p.mirror().points())

    @staticmethod
    def ring(cy, hw, hh=0.024):
        return Part(rrect(0.5 - hw, cy - hh, 0.5 + hw, cy + hh, hh))

    @classmethod
    def pawn(cls):
        return Shape(parts=[
            cls.body(0.54, 0.084, 0.17),
            cls.cushion(0.46),
            cls.ring(0.546, 0.118),
            ball(0.5, 0.39, 0.138),
        ])

    @classmethod
    def rook(cls):
        top, d = 0.19, 0.066
        turret = fillet([(0.27, 0.37), (0.27, top), (0.39, top), (0.39, top + d), (0.448, top + d),
                         (0.448, top), (0.552, top), (0.552, top + d), (0.61, top + d), (0.61, top),
                         (0.73, top), (0.73, 0.37)], 0.024)
        return Shape(parts=[
            cls.body(0.37, 0.194, 0.222, belly=0.04),
            cls.cushion(0.56),
            Part(turret),
            cls.ring(0.372, 0.214, 0.026),
        ])

    @classmethod
    def bishop(cls):
        # the mitre's point softened, as every corner here is
        return Shape(parts=[
            cls.body(0.59, 0.104, 0.21),
            cls.cushion(0.54),
            Part(fillet(mitre_outline(0.188, 0.46, 0.168, 0.595, 0.126), 0.018)),
            cls.ring(0.594, 0.15, 0.026),
            ball(0.5, 0.158, 0.045),
        ], slits=[(2, 0.36, (0.472, 0.466), 0.026)])

    @classmethod
    def queen(cls):
        # an open cup flaring from a low waist, four big pearls on its rim
        waist = 0.6
        cup = (Path((0.5, 0.29))
               .C((0.42, 0.29), (0.25, 0.288), (0.19, 0.272)).corner()
               .through([(0.245, 0.38), (0.33, 0.5), (0.374, waist - 0.02)], start=(0.25, 1), end=(0.45, 1))
               .corner().L((0.5, waist - 0.02)).mirror().points())
        pearls = [ball(0.5 + dx, y, 0.047) for dx, y in
                  ((-0.3, 0.258), (-0.146, 0.238), (0.146, 0.238), (0.3, 0.258))]
        return Shape(parts=[
            cls.body(waist, 0.1, 0.214),
            cls.cushion(0.58),
            Part(rrect(0.47, 0.17, 0.53, 0.29, 0.03)),
            *pearls,
            Part(cup),
            cls.ring(waist, 0.15, 0.028),
            ball(0.5, 0.156, 0.047),
        ])

    @classmethod
    def king(cls):
        # the arched crown, plump, on a ring; the gem, softened
        brim, waist, top, w, h = 0.47, 0.62, 0.098, 0.24, 0.21
        return Shape(parts=[
            cls.body(waist, 0.11, 0.21),
            cls.cushion(0.58),
            cls.body(brim, 0.19, 0.14, waist, belly=0.0),
            gem_crown(top + h, 0.246, 0.336, 0.19, 0.35, brim, 0.235),
            Part(fillet(jewel(0.5, top + h / 2, w, h, girdle=0.5), 0.02), "gem"),
            cls.ring(brim, 0.27, 0.024),
            cls.ring(waist, 0.16, 0.028),
        ], seams=jewel_cuts(0.5, top + h / 2, w, h, girdle=0.5)[:1])

    @classmethod
    def knight(cls):
        foot = 0.812
        return knight_shape(Part(knight_outline(foot), "free"), [cls.cushion(0.56)],
                            knight_features(foot, eye_scale=1.15))


SOFT_MATERIAL = {
    "w": Material(shadow=(206, 198, 186), lit=(251, 248, 242), ambient=0.58),
    "b": Material(shadow=(58, 56, 54), lit=(132, 128, 124), ambient=0.46),
}


def _soft_fill(cv, part, m, colour):
    mat = SOFT_MATERIAL[colour]
    if part.kind == "gem":
        light_gem(cv, part, m, mat)
    elif part.kind == "sphere":
        light_sphere(cv, m, mat)
    else:  # every other part a pillow: lit as a volume from its outline
        light_free(cv, m, mat, soften=0.14, relief=0.8)


SOFT = Style(
    edge=0.02, inner=0.012, seam=0.011, fill=_soft_fill,
    line_edge={"w": (118, 110, 100), "b": (40, 38, 36)},
    line_inner={"w": (176, 168, 156), "b": (60, 58, 55)},
    detail={"w": (150, 142, 132), "b": (52, 50, 48)}, ao=0.08, shadow=soft_shadow(0.1))


# =============================================================== sets

# Order is the Settings order; the first is the default (`Prefs.pieceSet`).
SETS = {
    "classic": (Staunton, CLASSIC),
    "wood": (Staunton, WOOD),
    "marble": (Regal, MARBLE),
    "diagram": (Staunton, DIAGRAM),
    "modern": (Modern, MODERN),
    "deco": (Deco, DECO),
    "facet": (Facet, FACET),
    "silhouette": (Glyph, SILHOUETTE),
    "soft": (Pebble, SOFT),
    "bold": (Bold, BOLD),
}


def build(family, role):
    """The shape, and every unintended kink its paths made."""
    _PATHS.clear()
    shape = getattr(family, role)()
    kinks = [k for p in _PATHS for k in p.kinks()]
    _PATHS.clear()
    return shape, kinks


def render_piece(set_id, code, size=MASTER_PX // 6, ss=None):
    """One piece, e.g. ('classic', 'wN'), as an RGBA image of [size] px,
    area-averaged from a canvas at least 3072 px (or 2x) across."""
    family, style = SETS[set_id]
    ss = ss or max(2, math.ceil(MASTER_PX / size))
    shape, _ = build(family, ROLE[code[1]])
    return render_master(shape, style, code[0], px=size * ss).reduce(ss)


# =============================================================== audit

COLORWAYS = {  # lib/core/theme/board_themes.dart
    "tournament": ((0xEE, 0xEE, 0xD2), (0x76, 0x96, 0x56)),
    "walnut": ((0xF0, 0xD9, 0xB5), (0xB5, 0x88, 0x63)),
    "sheesham": ((0xEA, 0xD8, 0xC0), (0xA1, 0x6F, 0x4A)),
    "slate": ((0xDD, 0xE1, 0xDA), (0x8A, 0x96, 0x8A)),
    "sage": ((0xEF, 0xE7, 0xCF), (0x7D, 0x8F, 0x69)),
}
SQUARES = [c for pair in COLORWAYS.values() for c in pair]

# The bar (see docs in CLAUDE.md, "Everything bundled is cleared for sale").
BASELINE, BASELINE_TOL = 0.900, 0.003
CENTRE_TOL, KNIGHT_CENTRE_TOL = 0.012, 0.025
MAX_CONTRAST = 12.0        # the darkest line against the lightest light
EDGE_VISIBILITY = 2.5      # a piece's edge or body against every square
SAME_SILHOUETTE = 0.84     # IoU at 24 px above which two pieces blur
SAME_ROYALS = 0.82         # the king and queen, stricter
# For scale: cburnett, merida and alpha, the most legible lichess sets, keep
# every pair under ~0.77 and the royals near 0.68; Staunty sat at 0.85-0.86.

# The knight's archetype (`knight_form`), at the lower edge of what the
# canonical knights measure: Staunty 0.09 / 0.37 / 0.215 / 0.652, and
# cburnett, merida, maestro, companion, fresca, cardinal, tatiana and
# leipzig 0.086-0.18 / 0.28-0.42 / 0.27-0.41 / 0.70-0.83.
# Mass: the knight sets it. Each piece's ink, as a share of its own set's
# knight, and the royals' crown width (the widest run in the top 60% of the
# piece), must sit within what 25 classic sets measure: from their 10th
# percentile to their 90th. The first cut drew narrow crowns on trumpet
# stems (king 0.80 of the knight, its crown 0.43 wide), which made the
# knight look like it belonged to another, bolder set.
MASS = dict(K=(0.91, 1.25), Q=(0.84, 1.14), R=(0.83, 1.01), B=(0.66, 0.93), P=(0.48, 0.72))
CROWN_W = dict(K=0.60, Q=0.70)

# The king's archetype (`king_form`): some row across the top of the crown
# must cross the two arches and the bulb (or gem) between them, as three runs
# parted by gaps this wide. The domed crown it replaced crossed as one run.
KING_GAP = 0.015

# The bishop's archetype (`bishop_form`): the mitre (the part its slit cuts)
# at least this much taller than wide, and pointed: 10% below its tip no
# wider than this share of its widest. The egg it replaced measured 0.88 and
# 0.40; Soft's and Bold's ovals were tall enough but 0.58 at the tip.
MITRE_ASPECT, MITRE_TIP = 1.15, 0.32

KNIGHT_NOTCH = 0.07    # the V under the jaw, open this tall
KNIGHT_DEPTH = 0.30    # its apex this far behind the muzzle
KNIGHT_LEAN = 0.18     # the chest this far in front of the apex
KNIGHT_WIDTH = 0.65    # muzzle to back


def luminance(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(la, lb):
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


@dataclass
class Measure:
    code: str
    top: float
    bottom: float
    cx: float
    components: int
    max_contrast: float
    visibility: float
    silhouette: set
    kinks: list
    knight: dict = None
    area: float = 0.0      # ink, as a share of the square
    head_w: float = 0.0    # the widest run in the top 60% of the piece
    king_runs: int = 0     # the most arch-parted runs across the crown
    mitre: tuple = None    # the bishop's (aspect, tip) from `bishop_form`


def knight_form(solid):
    """The knight's archetype, measured on its thresholded silhouette: the V
    notch under the jaw (rows where the head and the neck are two runs), how
    far that notch sits behind the muzzle, how far the chest leans in front
    of it, and the knight's width."""
    n = solid.width
    px = solid.load()
    rows = {}
    for y in range(n):
        runs, start = [], None
        for x in range(n):
            on = px[x, y] > 127
            if on and start is None:
                start = x
            elif not on and start is not None:
                runs.append((start, x - 1))
                start = None
        if start is not None:
            runs.append((start, n - 1))
        rows[y] = runs
    head = [y for y in range(n) if rows[y] and y / n < 0.6]
    muzzle = min(rows[y][0][0] for y in head) / n
    width = max(rows[y][-1][1] for y in head) / n - muzzle
    v = [y for y in range(int(0.35 * n), int(0.72 * n))
         if len(rows[y]) >= 2 and rows[y][1][0] - rows[y][0][1] > 0.02 * n]
    if not v:
        return dict(notch=0.0, depth=0.0, lean=0.0, width=width)
    vertex = rows[v[0]][1][0] / n
    foot_rows = [y for y in range(int(0.66 * n), int(0.74 * n)) if rows[y]]
    chest = min(rows[y][0][0] for y in foot_rows) / n if foot_rows else vertex
    return dict(notch=(v[-1] - v[0]) / n, depth=vertex - muzzle, lean=vertex - chest, width=width)


def king_form(solid):
    """The most runs any row across the top 45% of the king crosses, when
    every gap between them is at least KING_GAP: 3 for two arches and the
    bulb or gem between them."""
    n = solid.width
    px = solid.load()
    x0, y0, x1, y1 = solid.getbbox()
    best = 0
    for y in range(y0, y0 + int(0.45 * (y1 - y0))):
        runs, start = [], None
        for x in range(n):
            on = px[x, y] > 127
            if on and start is None:
                start = x
            elif not on and start is not None:
                runs.append((start, x - 1))
                start = None
        if start is not None:
            runs.append((start, n - 1))
        if len(runs) >= 3 and all(runs[i + 1][0] - runs[i][1] >= KING_GAP * n for i in range(len(runs) - 1)):
            best = max(best, len(runs))
    return best


def measure(code, master, kinks):
    img = master.reduce(master.width // 512)
    a = img.getchannel("A")
    solid = a.point(lambda v: 255 if v > 127 else 0)
    x0, y0, x1, y1 = solid.getbbox()
    small = a.reduce(4)
    sp = small.load()
    tot = sx = 0
    for y in range(small.height):
        for x in range(small.width):
            w = sp[x, y]
            tot += w
            sx += w * (x + 0.5)
    # one connected silhouette
    half = solid.reduce(2).point(lambda v: 255 if v > 127 else 0)
    hp = half.load()
    seed = next(((x, y) for y in range(half.height) for x in range(half.width) if hp[x, y] == 255), None)
    comps = 0
    while seed:
        comps += 1
        ImageDraw.floodfill(half, seed, 100, thresh=0)
        hp = half.load()
        seed = next(((x, y) for y in range(half.height) for x in range(half.width) if hp[x, y] == 255), None)
    # contrast: the darkest line to the lightest light, and the piece's edge
    # (or body) against every square
    px = img.load()
    core = a.filter(ImageFilter.MinFilter(9))
    ring = ImageChops.subtract(a.point(lambda v: 255 if v > 250 else 0), core)
    lums, edge, body = [], [], []
    cp, rp = core.load(), ring.load()
    for y in range(0, img.height, 2):
        for x in range(0, img.width, 2):
            r, g, b, al = px[x, y]
            if al < 250:
                continue
            lv = luminance((r, g, b))
            lums.append(lv)
            if rp[x, y] > 127:
                edge.append(lv)
            elif cp[x, y] > 127:
                body.append(lv)
    lums.sort()
    lo, hi = lums[len(lums) // 200], lums[-1 - len(lums) // 200]
    e = sorted(edge)[len(edge) // 2] if edge else lo
    bdy = sorted(body)[len(body) // 2] if body else hi
    vis = min(max(contrast(e, luminance(s)), contrast(bdy, luminance(s))) for s in SQUARES)
    sil_img = master.getchannel("A").reduce(master.width // 24)
    sil = {(x, y) for y in range(24) for x in range(24) if sil_img.getpixel((x, y)) > 127}
    form = knight_form(solid.reduce(2)) if code[1] == "N" else None
    quarter = solid.reduce(2)
    qp = quarter.load()
    area = sum(1 for v in quarter.getdata() if v > 127) / (256 * 256)
    head_w = 0.0
    for y in range(y0 // 2, (y0 + int(0.6 * (y1 - y0))) // 2):
        xs = [x for x in range(256) if qp[x, y] > 127]
        if xs:
            head_w = max(head_w, (xs[-1] - xs[0]) / 256)
    runs = king_form(solid) if code[1] == "K" else 0
    return Measure(code, y0 / 512, y1 / 512, sx / tot / small.width, comps,
                   contrast(lo, hi), vis, sil, kinks, form, area, head_w, runs)


def iou(a, b):
    return len(a & b) / max(1, len(a | b))


# The set whose whole point is its outlines answers to a stricter bar.
STRICTER = {"silhouette": (0.76, 0.74)}


def audit(set_id, measures, style):
    """Every way this set falls short of the bar, as readable lines."""
    fails = []
    same, royals = STRICTER.get(set_id, (SAME_SILHOUETTE, SAME_ROYALS))
    by = {m.code: m for m in measures}
    for m in measures:
        tag = f"{set_id}/{m.code}"
        if abs(m.bottom - BASELINE) > BASELINE_TOL:
            fails.append(f"{tag}: stands on {m.bottom:.3f}, not {BASELINE:.3f}")
        tol = KNIGHT_CENTRE_TOL if m.code[1] == "N" else CENTRE_TOL
        if abs(m.cx - 0.5) > tol:
            fails.append(f"{tag}: optical centre at {m.cx:.3f}")
        if m.components != 1:
            fails.append(f"{tag}: {m.components} separate silhouettes")
        if m.max_contrast > MAX_CONTRAST:
            fails.append(f"{tag}: contrast {m.max_contrast:.1f}:1 is harsher than {MAX_CONTRAST}:1")
        if m.visibility < EDGE_VISIBILITY:
            fails.append(f"{tag}: edge only {m.visibility:.2f}:1 against some square")
        for at, deg in m.kinks:
            fails.append(f"{tag}: kink of {deg}° at ({at[0]:.3f}, {at[1]:.3f})")
        if m.mitre and not (m.mitre[0] >= MITRE_ASPECT and m.mitre[1] <= MITRE_TIP):
            fails.append(f"{tag}: not the Staunton mitre (aspect {m.mitre[0]:.2f} >= {MITRE_ASPECT}, "
                         f"tip {m.mitre[1]:.2f} <= {MITRE_TIP})")
        if m.code[1] == "K" and m.king_runs < 3:
            fails.append(f"{tag}: not the arched crown (no row parts two arches from the bulb or gem)")
        k = m.knight
        if k and not (k["notch"] >= KNIGHT_NOTCH and k["depth"] >= KNIGHT_DEPTH
                      and k["lean"] >= KNIGHT_LEAN and k["width"] >= KNIGHT_WIDTH):
            fails.append(f"{tag}: not the chess knight (V notch {k['notch']:.3f} >= {KNIGHT_NOTCH}, "
                         f"behind the muzzle {k['depth']:.3f} >= {KNIGHT_DEPTH}, chest lean "
                         f"{k['lean']:.3f} >= {KNIGHT_LEAN}, width {k['width']:.3f} >= {KNIGHT_WIDTH})")
    for c in "wb":
        t = {k: by[c + k].top for k in "KQRBNP"}
        if not (t["K"] < t["Q"] < t["B"] <= t["N"] + 0.006 and t["N"] < t["R"] < t["P"]):
            fails.append(f"{set_id}/{c}: heights break the ladder {({k: round(v, 3) for k, v in t.items()})}")
    knight_area = by["wN"].area
    for k, (lo, hi) in MASS.items():
        r = by["w" + k].area / knight_area
        if not lo <= r <= hi:
            fails.append(f"{set_id}/{k}: {r:.2f} of the knight's mass, not {lo}-{hi}")
    for k, w in CROWN_W.items():
        if by["w" + k].head_w < w:
            fails.append(f"{set_id}/{k}: crown {by['w' + k].head_w:.2f} wide, under {w}")
    sils = {k: by["w" + k].silhouette for k in "KQRBNP"}
    for i, a in enumerate("KQRBNP"):
        for b in "KQRBNP"[i + 1:]:
            limit = royals if {a, b} == {"K", "Q"} else same
            v = iou(sils[a], sils[b])
            if v >= limit:
                fails.append(f"{set_id}: {a} and {b} share {v:.2f} of their silhouette at 24 px")
    if style.edge < 0.02 or style.inner > 0.8 * style.edge:
        fails.append(f"{set_id}: line weights out of hierarchy")
    if min(w for w in (style.inner or 1, style.seam) if w) * 256 < 1.5:
        fails.append(f"{set_id}: a line thinner than 1.5 px at 2.0x")
    return fails


# =============================================================== review

REVIEW_FEN = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R"


def _board(pieces, colorway, sq):
    light, dark = COLORWAYS[colorway]
    img = Image.new("RGB", (8 * sq, 8 * sq))
    d = ImageDraw.Draw(img)
    for r in range(8):
        for f in range(8):
            d.rectangle([f * sq, r * sq, (f + 1) * sq, (r + 1) * sq],
                        fill=light if (r + f) % 2 == 0 else dark)
    for r, rank in enumerate(REVIEW_FEN.split("/")):
        f = 0
        for ch in rank:
            if ch.isdigit():
                f += int(ch)
                continue
            p = pieces[("w" if ch.isupper() else "b") + ch.upper()].resize(
                (sq, sq), Image.Resampling.BOX)
            img.paste(p, (f * sq, r * sq), p)
            f += 1
    return img


def _row(images, gap=12, bg=(255, 255, 255)):
    out = Image.new("RGB", (sum(i.width for i in images) + gap * (len(images) - 1),
                            max(i.height for i in images)), bg)
    x = 0
    for i in images:
        out.paste(i, (x, 0))
        x += i.width + gap
    return out


def _column(images, gap=12, bg=(255, 255, 255)):
    out = Image.new("RGB", (max(i.width for i in images),
                            sum(i.height for i in images) + gap * (len(images) - 1)), bg)
    y = 0
    for i in images:
        out.paste(i, (0, y))
        y += i.height + gap
    return out


def review(directory, set_id, pieces, measures):
    """Every piece large; the Italian game on every colorway at game size
    (48 px squares) and as a thumbnail (16 px); the six silhouettes at 24 px."""
    os.makedirs(directory, exist_ok=True)
    size = 200
    sheet = Image.new("RGB", (size * 6, size * 2), (224, 221, 214))
    for i, c in enumerate(CODES):
        p = pieces[c].resize((size, size), Image.Resampling.BOX)
        sheet.paste(p, ((i % 6) * size, (i // 6) * size), p)
    boards = _row([_board(pieces, cw, 48) for cw in COLORWAYS])
    thumbs = _row([_board(pieces, cw, 16) for cw in COLORWAYS])
    sil = Image.new("RGB", (6 * 24 * 4 + 5 * 8, 24 * 4), (255, 255, 255))
    by = {m.code: m for m in measures}
    for i, k in enumerate("KQRBNP"):
        tile = Image.new("L", (24, 24), 255)
        for x, y in by["w" + k].silhouette:
            tile.putpixel((x, y), 40)
        sil.paste(tile.resize((96, 96), Image.Resampling.NEAREST).convert("RGB"), (i * 104, 0))
    _column([sheet, boards, thumbs, sil]).save(os.path.join(directory, f"{set_id}.png"))


def gallery(directory, all_pieces):
    rows = []
    for set_id, pieces in all_pieces.items():
        tiles = Image.new("RGB", (12 * 64, 64), (224, 221, 214))
        for i, c in enumerate(CODES):
            p = pieces[c].resize((64, 64), Image.Resampling.BOX)
            tiles.paste(p, (i * 64, 0), p)
        rows.append(_row([tiles, _board(pieces, "tournament", 24), _board(pieces, "walnut", 24)], gap=8))
    _column(rows, gap=8).save(os.path.join(directory, "gallery.png"))


# =============================================================== main


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--only", nargs="+", metavar="SET", choices=list(SETS), help="these sets only")
    ap.add_argument("--check", action="store_true", help="audit only; write nothing")
    ap.add_argument("--draft", action="store_true", help="a 1536 px canvas; implies --check")
    ap.add_argument("--review", metavar="DIR", help="write review sheets to DIR")
    args = ap.parse_args()
    px = MASTER_PX // 2 if args.draft else MASTER_PX
    write = not (args.check or args.draft)
    rendered, failures = {}, []
    for set_id in args.only or SETS:
        family, style = SETS[set_id]
        pieces, measures = {}, []
        for code in CODES:
            shape, kinks = build(family, ROLE[code[1]])
            master = render_master(shape, style, code[0], px=px)
            m = measure(code, master, kinks)
            if code[1] == "B":
                m.mitre = bishop_form(shape)
            measures.append(m)
            pieces[code] = {size: master.reduce(px // size) for _, size in RESOLUTIONS}
        fails = audit(set_id, measures, style)
        failures += fails
        rendered[set_id] = pieces
        print(f"{set_id}: {'ok' if not fails else f'{len(fails)} problem(s)'}")
        if args.review:
            review(args.review, set_id, {c: v[512] for c, v in pieces.items()}, measures)
    if args.review and len(rendered) > 1:
        gallery(args.review, {s: {c: v[512] for c, v in p.items()} for s, p in rendered.items()})
    for f in failures:
        print("  " + f)
    if failures:
        print("nothing written: the gate failed" if write else "")
        sys.exit(1)
    if write:
        for set_id, pieces in rendered.items():
            for code, sizes in pieces.items():
                for folder, size in RESOLUTIONS:
                    path = os.path.join(OUT, set_id, folder, f"{code}.webp")
                    os.makedirs(os.path.dirname(path), exist_ok=True)
                    sizes[size].save(path, "WEBP", lossless=True, quality=100, method=6)
            print(f"wrote {set_id}: {len(CODES)} pieces x {len(RESOLUTIONS)} resolutions")


if __name__ == "__main__":
    main()
