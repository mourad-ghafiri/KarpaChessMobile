# KarpaChess pieces

Ten original piece sets: `classic`, `wood`, `marble`, `diagram`, `modern`,
`deco`, `facet`, `silhouette`, `soft` and `bold`.
Each set has twelve pieces at 128 px, with `2.0x/`, `3.0x/` and `4.0x/`
variants (256, 384 and 512 px).

Don't edit these files by hand. `tool/gen_pieces.py` draws every piece from
its own curves, audits every set against its quality gate (one baseline, the
height ladder, silhouettes that tell the pieces apart at 24 px, calm
contrast), and only then writes them all:

    python3 tool/gen_pieces.py

The artwork is dedicated to the public domain under CC0 1.0 (`LICENSE`). The
launcher icon, drawn by `tool/gen_icon.py` from the Classic knight, is
dedicated the same way.
