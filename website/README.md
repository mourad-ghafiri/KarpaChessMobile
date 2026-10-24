# karpachess.com

The website of KarpaChess, served at <https://karpachess.com>: one page about
the app (`index.html`), its privacy policy (`privacy.html`, the address both
stores and the app's Settings › About link to), and the legal notice and
accessibility statement that French, EU and US rules expect (`legal.html`,
`accessibility.html`).

It is a static site with no build step: upload the contents of this folder to
the web host, as they are.

## What is in it

| Path | What | Written by |
|---|---|---|
| `index.html` | The page: what KarpaChess teaches, its six modes, the screens, the themes and piece sets, the twelve languages, privacy, source and support | hand |
| `privacy.html` | The privacy policy page | hand, except the policy itself (below) |
| `legal.html` | The legal notice (*mentions légales*): publisher, host, licences, trademarks | hand |
| `accessibility.html` | The accessibility statement (WCAG 2.2 AA, self-assessed) | hand |
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
  no embeds, no cookies of our own, so there is no cookie banner. The privacy
  policy says so in its "This website" section: keep the two true together.
- **The host is described as it is.** Cloudflare serves the site and routes
  `contact@karpachess.com`, and its bot protection injects a script
  (`/cdn-cgi/challenge-platform/…`) that may set the `cf_clearance` and
  `__cf_bm` security cookies. The policy says so, and the CNIL exempts such
  cookies from consent, which is why there is still no banner. If the host,
  its address or that setting changes, update `docs/PRIVACY.md` ("This
  website", "Sharing and transfers") and `legal.html` ("Hosting provider")
  in the same edit.
- **Every page carries the same footer**, in the same order: the site links
  (Support among them, WCAG 3.2.6), then Privacy policy · Legal notice ·
  Accessibility. A new page copies it, with `aria-current="page"` on its own
  link, and goes into `sitemap.xml`.
- **The accessibility statement only claims what was checked.** Re-check it,
  and its date, when a page, a colour or a script changes: contrast in both
  palettes (4.5:1 for text), keyboard use, and every page at 320px wide
  with no sideways scroll.
- **Only true claims.** Every number and feature on the page is what the app
  does today: 100 lessons, 441 puzzles, 240 master games, twelve languages,
  ten piece sets. The coach is offline rules behind one hint button, not AI.
  Change the page when the app changes.
- **Search metadata says what the page says.** The `<title>`, the meta
  description and the JSON-LD block in `index.html` (`WebSite`, `WebPage`,
  `MobileApplication`) repeat the page's counts, features and languages, and
  Google requires structured data to match visible content: change them with
  the page. Never add `aggregateRating` or `review` markup unless real ratings
  are shown on the page. Pages link home as `./`, the canonical URL, never
  `index.html`.
- **Store badges.** The App Store badge is Apple's official black badge
  (`badges/app-store.svg`, from Apple's App Store Marketing Tools), never
  modified, first in the row. It links to
  `https://apps.apple.com/app/karpachess/id6808091046`, which has no country
  code, so the App Store sends each visitor to their own storefront. Second
  comes Google's official English "Get it on Google Play" badge
  (`badges/google-play.svg`, from Google's Partner Marketing Hub, whose
  download form you accept yourself), never modified, linking to
  `https://play.google.com/store/apps/details?id=com.mouradghafiri.karpachess`.
  Google asks for its badge at the same size as the others or larger, so
  both are 56px tall. `tool/website.py --check` fails while a badge a page
  links to is missing.

## Preview locally

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory website
# then open http://127.0.0.1:8000/
```

Opening the files directly (`file://`) mostly works, but browsers are strict
about fonts loaded that way. A local server shows the page as the web host
will.
