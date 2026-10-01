# karpachess.com

The website of KarpaChess, served at <https://karpachess.com>: one page about
the app (`index.html`) and its privacy policy (`privacy.html`), the address
both stores and the app's Settings › About link to.

It is a static site with no build step: upload the contents of this folder to
the web host, as they are.

## What is in it

| Path | What | Written by |
|---|---|---|
| `index.html` | The page: what KarpaChess teaches, its six modes, the screens, the themes and piece sets, the twelve languages, privacy, source and support | hand |
| `privacy.html` | The privacy policy page | hand, except the policy itself (below) |
| `styles.css` | Every style. The palette is the app's own: Midnight Grove, or Ivory Hall when the reader's system is in light mode | hand |
| `script.js` | The menu, the iPhone/iPad tabs, the screenshot strip and its viewer | hand |
| `robots.txt`, `sitemap.xml` | For search engines | hand |
| `favicon.ico`, `images/`, `fonts/` | Icons, screenshots, piece previews, the social card, the fonts | `tool/website.py` |

## What is generated, and why

`python3 tool/website.py` (from the repository root) derives everything that
comes from elsewhere in the repository:

- **The policy** in `privacy.html` is rendered from `docs/PRIVACY.md`,
  between the `privacy:begin` and `privacy:end` markers. The published policy
  can then never differ from the one in the source. The app's short notice
  (Settings › About › Privacy policy) summarises the same text, and all of
  them must agree. Edit the Markdown, never the rendered block.
- **The screenshots** are scaled from the App Store sets in `screenshots/ios/`.
  Re-shoot with `sh tool/store_screenshots.sh ios`, then run the tool, and
  the site shows the same screens as the stores.
- **The icons and the social card** come from the launcher icon that
  `tool/gen_icon.py` draws.
- **The piece previews** are copied from `assets/pieces/`.
- **The fonts** are the app's own Fraunces and Inter, cut down to Latin, with
  their licence (`fonts/OFL.txt`).

`python3 tool/website.py --check` writes nothing, and fails if anything is out
of date. Run it before every upload. The tool never deletes: a file in
`images/` or `fonts/` that it did not produce stops it, and it names the file.
It needs Pillow, fontTools and brotli.

## Rules the page keeps

- **Nothing loads from another site.** No web fonts from a CDN, no analytics,
  no embeds, no cookies. The privacy policy says so in its "This website"
  section: keep the two true together.
- **Only true claims.** Every number and feature on the page is what the app
  does today: 100 lessons, 441 puzzles, 240 master games, twelve languages,
  ten piece sets. The coach is offline rules behind one hint button, not AI.
  Change the page when the app changes.
- **Store badges.** The App Store badge is Apple's official black badge
  (`badges/app-store.svg`, from Apple's App Store Marketing Tools), never
  modified, first in the row. It links to
  `https://apps.apple.com/app/karpachess/id6808091046`, which has no country
  code, so the App Store sends each visitor to their own storefront. Google
  Play still shows a plain "Coming soon" box. When that listing goes live,
  replace the box with Google's official badge, saved into `badges/` and
  linked to the listing.

## Preview locally

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory website
# then open http://127.0.0.1:8000/
```

Opening the files directly (`file://`) mostly works, but browsers are strict
about fonts loaded that way. A local server shows the page as the web host
will.
