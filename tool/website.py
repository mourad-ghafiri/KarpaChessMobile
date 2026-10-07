#!/usr/bin/env python3
"""Writes the parts of the website that come from other files in the repo.

    python3 tool/website.py           # write whatever is out of date
    python3 tool/website.py --check   # write nothing; exit 1 if anything is

`website/` is the site served at karpachess.com. Its pages, stylesheet and
script are written by hand. Everything else in it is derived here, so that
none of it can drift from the thing it shows:

- **The privacy policy.** `docs/PRIVACY.md` is rendered into
  `website/privacy.html`, between its `privacy:begin` and `privacy:end`
  markers. That page is `AppInfo.privacyUrl`, the address both stores link
  to, so it must never say anything the policy does not.
- **The screenshots**, scaled down from the App Store sets in `screenshots/`.
- **The icons and the social card**, from the launcher icon that
  `tool/gen_icon.py` draws (`assets/images/icon.png`).
- **The piece previews**, copied from `assets/pieces/`.
- **The fonts.** These are the app's own Fraunces and Inter, cut down to
  Latin and packed as WOFF2, beside their licence.

The script never deletes. A file under `website/images/` or `website/fonts/`
that it did not produce stops it, and it names the file to remove.

Run it after changing the privacy policy, after re-shooting the store
screenshots, and after redrawing the icon or the pieces.

Needs Pillow (like `tool/gen_icon.py`), fontTools and brotli.
"""

import html
import io
import pathlib
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / 'website'

# Every directory the script owns outright, where a file it did not write is
# a stray.
OWNED = [SITE / 'images', SITE / 'fonts']

# The App Store sets, and the width each is scaled to: about twice the
# largest size the page draws them at.
SCREENS = {
    'iphone': (ROOT / 'screenshots' / 'ios' / 'iphone-6.9', 660),
    'ipad': (ROOT / 'screenshots' / 'ios' / 'ipad-13', 840),
}

PIECE_SETS = ['classic', 'wood', 'marble', 'diagram', 'modern',
              'deco', 'facet', 'silhouette', 'soft', 'bold']
# The four pieces the app's own set picker previews, in its order.
PREVIEW_PIECES = ['bK', 'bN', 'wN', 'wQ']

# Each font, and the axes pinned to one value. Fraunces keeps its weight and
# optical size but not its softness or its 'wonky' letters, which the page
# never varies: they are fixed at the font's own defaults, as the app draws
# them.
FONTS = {
    'fraunces.woff2': ('Fraunces.ttf', {'SOFT': 0, 'WONK': 1}),
    'inter.woff2': ('Inter.ttf', {}),
}
# Basic Latin, Latin-1, the typographic punctuation and the arrows. The page
# writes the twelve languages' names in their own scripts, and the browser
# draws those in a system font.
LATIN = [*range(0x20, 0x7F), *range(0xA0, 0x100), 0x131, 0x152, 0x153,
         0x2C6, 0x2DA, 0x2DC, *range(0x2000, 0x2070), 0x20AC, 0x2122,
         *range(0x2190, 0x2200), 0x2212, 0x2215, 0x2605, 0x265A, 0x265E]

# Midnight Grove, the app's default theme (lib/core/theme/themes.dart).
BG = (0x09, 0x13, 0x0B)
TEXT = (0xE4, 0xEA, 0xE5)
TEXT_DIM = (0xA7, 0xAD, 0xA8)
ACCENT = (0x79, 0xBB, 0x74)
TINT = (0x49, 0x7E, 0x50)


def main() -> None:
    check = '--check' in sys.argv[1:]
    outputs = {
        **privacy_page(),
        **screens(),
        **icons(),
        **social_card(),
        **pieces(),
        **fonts(),
    }
    strays = sorted(
        path for folder in OWNED if folder.exists()
        for path in folder.rglob('*')
        if path.is_file() and path.name != '.DS_Store' and path not in outputs)
    stale = sorted(path for path, data in outputs.items()
                   if not path.exists() or path.read_bytes() != data)

    for path in strays:
        print(f'stray: {rel(path)} is not produced by tool/website.py; '
              'remove it')
    if check:
        for path in stale:
            print(f'out of date: {rel(path)}')
        if stale or strays:
            print('run: python3 tool/website.py')
            sys.exit(1)
        print(f'website: {len(outputs)} derived files, all current')
        return
    if strays:
        sys.exit(1)
    for path in stale:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(outputs[path])
        print(f'wrote {rel(path)}')
    print(f'website: {len(stale)} of {len(outputs)} derived files written')


def rel(path: pathlib.Path) -> str:
    return str(path.relative_to(ROOT))


# ---------------------------------------------------------------- privacy


BEGIN = '<!-- privacy:begin -->'
END = '<!-- privacy:end -->'


def privacy_page() -> dict:
    page_path = SITE / 'privacy.html'
    page = page_path.read_text(encoding='utf-8')
    start, end = page.find(BEGIN), page.find(END)
    if start < 0 or end < start:
        sys.exit(f'{rel(page_path)}: missing the {BEGIN} / {END} markers')
    line_start = page.rfind('\n', 0, start) + 1
    indent = page[line_start:start]
    body = render_markdown(
        (ROOT / 'docs' / 'PRIVACY.md').read_text(encoding='utf-8'))
    spliced = (page[:start] + BEGIN + '\n'
               + ''.join(f'{indent}{line}\n' if line else '\n'
                         for line in body.splitlines())
               + indent + page[end:])
    return {page_path: spliced.encode('utf-8')}


def render_markdown(text: str) -> str:
    """The Markdown `docs/PRIVACY.md` uses, and no more: headings, paragraphs,
    nested `-` lists, `**bold**`, `` `code` `` and links. Anything else fails
    loudly rather than rendering wrong."""
    text = re.sub(r'<!--.*?-->\n?', '', text, flags=re.S)
    out = []
    paragraph = []
    items = []  # (depth, [lines]) for the list being read

    def flush():
        if paragraph:
            words = ' '.join(paragraph)
            # A paragraph that is bold throughout is one the policy sets
            # apart: its date, and its summary.
            lead = ' class="lead"' if re.fullmatch(r'\*\*[^*]+\*\*', words) else ''
            out.append(f'<p{lead}>{inline(words)}</p>')
            paragraph.clear()
        if items:
            out.extend(render_list(items))
            items.clear()

    for line in text.splitlines():
        heading = re.match(r'(#{1,3}) (.+)', line)
        item = re.match(r'( *)- (.+)', line)
        if not line.strip():
            flush()
        elif heading:
            flush()
            level = len(heading.group(1))
            title = heading.group(2).strip()
            anchor = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
            out.append(f'<h{level} id="{anchor}">{inline(title)}</h{level}>')
        elif item:
            if paragraph:
                flush()
            items.append((len(item.group(1)) // 2, [item.group(2)]))
        elif items and line.startswith('  '):
            items[-1][1].append(line.strip())
        elif line.startswith(('>', '|', '```', '* ', '1.')):
            sys.exit(f'docs/PRIVACY.md: tool/website.py cannot render {line!r}')
        else:
            paragraph.append(line.strip())
    flush()
    return '\n'.join(out) + '\n'


def render_list(items) -> list:
    lines = ['<ul>']
    depth = 0
    for level, words in items:
        if level > depth + 1:
            sys.exit('docs/PRIVACY.md: a list skips a level')
        while depth < level:
            lines[-1] = lines[-1].removesuffix('</li>')
            lines.append('  ' * depth + '  <ul>')
            depth += 1
        while depth > level:
            lines.append('  ' * depth + '</ul></li>')
            depth -= 1
        lines.append('  ' * depth + f'  <li>{inline(" ".join(words))}</li>')
    while depth > 0:
        lines.append('  ' * depth + '</ul></li>')
        depth -= 1
    lines.append('</ul>')
    return lines


def typographic(text: str) -> str:
    """Curly quotes and apostrophes, as the hand-set page uses: the policy
    stays plain ASCII Markdown, and the page reads as typeset. Code spans
    and link targets are left as written."""
    parts = re.split(r'(`[^`]+`|\]\([^)]+\))', text)
    for i in range(0, len(parts), 2):
        part = parts[i]
        part = re.sub(r"(^|[\s(\[\u2013\u2014])'", '\\1\u2018', part)
        part = part.replace("'", '\u2019')
        part = re.sub(r'(^|[\s(\[\u2013\u2014])"', '\\1\u201c', part)
        part = part.replace('"', '\u201d')
        parts[i] = part
    return ''.join(parts)


def inline(text: str) -> str:
    text = html.escape(typographic(text), quote=False)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
                  lambda m: f'<a href="{html.escape(m.group(2))}">'
                            f'{m.group(1)}</a>', text)
    if '*' in text or '_' in text.replace('_blank', ''):
        sys.exit(f'docs/PRIVACY.md: unrendered emphasis in {text!r}')
    return text


# ---------------------------------------------------------------- images


def encode(image: Image.Image, fmt: str, **options) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, fmt, **options)
    return buffer.getvalue()


def scaled(image: Image.Image, width: int) -> Image.Image:
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.LANCZOS)


def screens() -> dict:
    out = {}
    for device, (folder, width) in SCREENS.items():
        shots = sorted(folder.glob('*.png'))
        if not shots:
            sys.exit(f'{rel(folder)} is empty: '
                     'run sh tool/store_screenshots.sh ios first')
        for shot in shots:
            image = scaled(Image.open(shot).convert('RGB'), width)
            path = SITE / 'images' / 'screens' / device / f'{shot.stem}.webp'
            out[path] = encode(image, 'WEBP', quality=82, method=6)
    return out


def icon() -> Image.Image:
    return Image.open(ROOT / 'assets' / 'images' / 'icon.png').convert('RGB')


def icons() -> dict:
    master = icon()
    images = SITE / 'images'
    out = {
        images / 'icon-512.png': encode(scaled(master, 512), 'PNG'),
        images / 'icon-192.png': encode(scaled(master, 192), 'PNG'),
        images / 'apple-touch-icon.png': encode(scaled(master, 180), 'PNG'),
        images / 'favicon-32.png': encode(scaled(master, 32), 'PNG'),
    }
    # Browsers ask for /favicon.ico whatever the page declares.
    out[SITE / 'favicon.ico'] = encode(
        scaled(master, 256), 'ICO', sizes=[(16, 16), (32, 32), (48, 48)])
    return out


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius, fill=255)
    image = image.convert('RGBA')
    image.putalpha(mask)
    return image


def font(name: str, size: int, **axes) -> ImageFont.FreeTypeFont:
    """One of the app's variable fonts at [axes], given by tag (`wght=700`).
    Pillow takes the values in the font's own axis order, which its `fvar`
    table records."""
    path = ROOT / 'assets' / 'fonts' / name
    face = ImageFont.truetype(str(path), size)
    face.set_variation_by_axes(
        [axes.get(axis.axisTag, axis.defaultValue)
         for axis in TTFont(path)['fvar'].axes])
    return face


def social_card() -> dict:
    """The 1200x630 image link previews show (`og:image`): the icon, the
    name and one line, beside the lesson screenshot."""
    width, height = 1200, 630
    card = Image.new('RGB', (width, height), BG)

    # A board's worth of faint squares, fading out toward the text.
    board = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(board)
    square = 70
    for row in range(height // square + 1):
        for col in range(width // square + 1):
            if (row + col) % 2:
                alpha = max(0, min(26, (col * square - 360) // 18))
                draw.rectangle((col * square, row * square,
                                col * square + square - 1,
                                row * square + square - 1),
                               fill=(*TINT, alpha))
    card.paste(board, (0, 0), board)

    mark = rounded(scaled(icon(), 132), 30)
    card.paste(mark, (84, 118), mark)

    draw = ImageDraw.Draw(card)
    draw.text((80, 280), 'KarpaChess', fill=TEXT,
              font=font('Fraunces.ttf', 92, opsz=72, wght=700))
    draw.text((84, 404), 'Learn chess one idea at a time.', fill=TEXT_DIM,
              font=font('Inter.ttf', 36, opsz=32, wght=500))
    draw.text((84, 470), 'Lessons · Puzzles · Stockfish 19 · 12 languages',
              fill=ACCENT, font=font('Inter.ttf', 26, opsz=24, wght=600))

    shot = Image.open(ROOT / 'screenshots' / 'ios' / 'iphone-6.9'
                      / '02-lesson.png').convert('RGB')
    phone = rounded(scaled(shot, 300), 38)
    frame = Image.new('RGBA', (phone.width + 20, phone.height + 20),
                      (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (0, 0, frame.width - 1, frame.height - 1), 46, fill=(20, 27, 21, 255),
        outline=(*TINT, 255), width=2)
    frame.paste(phone, (10, 10), phone)
    card.paste(frame, (820, 64), frame)
    return {SITE / 'images' / 'social-card.png': encode(card, 'PNG',
                                                        optimize=True)}


def pieces() -> dict:
    out = {}
    for piece_set in PIECE_SETS:
        for piece in PREVIEW_PIECES:
            source = ROOT / 'assets' / 'pieces' / piece_set / f'{piece}.webp'
            out[SITE / 'images' / 'pieces' / piece_set / f'{piece}.webp'] = (
                source.read_bytes())
    return out


# ---------------------------------------------------------------- fonts


def fonts() -> dict:
    out = {}
    options = subset.Options()
    options.flavor = 'woff2'
    options.layout_features = ['*']
    options.name_IDs = ['*']  # keeps the copyright and licence records
    for target, (source, pinned) in FONTS.items():
        face = TTFont(ROOT / 'assets' / 'fonts' / source,
                      recalcTimestamp=False)
        if pinned:
            face = instancer.instantiateVariableFont(face, pinned)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=LATIN)
        subsetter.subset(face)
        buffer = io.BytesIO()
        face.flavor = 'woff2'
        face.save(buffer)
        out[SITE / 'fonts' / target] = buffer.getvalue()
    out[SITE / 'fonts' / 'OFL.txt'] = (
        ROOT / 'assets' / 'licenses' / 'OFL-1.1.txt').read_bytes()
    return out


if __name__ == '__main__':
    main()
