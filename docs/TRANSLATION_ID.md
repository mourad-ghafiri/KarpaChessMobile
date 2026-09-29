# Indonesian translation guide

The Indonesian corpus lives in `assets/data/lessons/id/` and
`assets/data/puzzles/id/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart id` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Indonesian conventions below. A file that is
not translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/id.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Standard Indonesian (bahasa baku, EYD), clear and warm: a coach speaking to
  one learner. Not slang, not stiff officialese.
- Address the reader as «Anda» (always capitalized). Instructions use the
  imperative with the polite particle only where English is soft: «Mainkan»,
  «Lihat», «Cari», «Coba».
- The sides are «Putih» and «Hitam» (capitalized, as names of the sides), or
  «lawan Anda». Pieces are «ia»/«-nya», never «dia» — a piece is not a person.
  People in history are «ia» or named.
- The same rule in the plural: «mereka» is for people only. Two or more pieces
  are «keduanya», «semuanya», «-nya», or the noun repeated — never «mereka».
  Nor do pieces take the human classifier «seorang»: a piece is «sebuah» or
  just counted («satu pembela»). «Seekor kuda» and «seekor gajah» are the one
  deliberate exception, and they are used consistently.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make.

## Notation and numbers

- Moves stay in international notation, inside chips: `{{Nf3}}`, `{{O-O}}`.
  Chips must match the English field exactly. Piece letters K Q R B N stay
  English, as in the UI and every Indonesian scoresheet app.
- Squares stay as written: e4, d5, h7. Files and ranks: «lajur e», «baris
  kedelapan» / «baris ke-8». No hyphen between the word and the letter —
  «lajur c», «pion f», never «lajur-c» or «pion-f».
- Western digits. Years and ratings are written without separators (1851,
  2800); other thousands take a dot (1.000 tahun); decimals take a comma
  (3,5 poin).
- Puzzle explanations open with `## Ide`.

## Pieces and core terms

| English | Indonesian |
|---|---|
| king | raja |
| queen | menteri (never «ratu») |
| rook | benteng |
| bishop | gajah |
| knight | kuda |
| pawn | pion (never «bidak») |
| piece / minor piece / heavy piece | buah / buah ringan / buah berat |
| square | petak (never «kotak») |
| file / rank / diagonal | lajur / baris / diagonal |
| line (generic), lane, strip | garis, lorong (never «lajur», which is the file) |
| back rank | baris belakang |
| center | pusat |
| wing, kingside / queenside | sayap, sayap raja / sayap menteri |
| check / checkmate / mate | sekak / sekakmat / mat |
| to be mated | dimat |
| stalemate / draw | pat / remis |
| castling (short / long) | rokade (pendek / panjang) |
| en passant | en passant |
| promotion / underpromotion | promosi / promosi minor |
| capture / recapture | menangkap / menangkap balik |
| move (a turn) | langkah |
| opening / middlegame / endgame | pembukaan / tengah permainan / akhir permainan |
| development | pengembangan (mengembangkan buah) |
| tempo | tempo |
| material | materi |
| exchange (rook for minor) / exchange sacrifice | kualitas / pengorbanan kualitas |
| sacrifice | pengorbanan / mengorbankan |
| blunder / mistake / inaccuracy | blunder / kesalahan / kurang akurat |
| hanging piece | buah yang tak terlindungi |
| threat / defender / attacker | ancaman / pembela / penyerang |
| fork | garpu |
| pin / skewer | jepitan / tusukan |
| discovered attack / discovered check | serangan tersingkap / sekak tersingkap |
| double attack / double check | serangan ganda / sekak ganda |
| removing the defender | menyingkirkan pembela |
| deflection / decoy / overload | pengalihan / umpan / beban berlebih |
| interference | interferensi (memotong jalur) |
| in-between move (zwischenzug) | langkah perantara |
| x-ray | sinar-X |
| trapped piece | buah terperangkap |
| king hunt | perburuan raja |
| zugzwang | zugzwang |
| opposition / key squares / rule of the square | oposisi / petak kunci / aturan persegi (the geometric box a pawn's race draws is «persegi», never «petak») |
| passed / isolated / doubled / backward pawn | pion bebas / terisolasi / ganda / tertinggal |
| pawn chain / pawn break / breakthrough | rantai pion / terobosan pion / terobosan |
| minority attack / pawn storm | serangan minoritas / badai pion |
| open / half-open file | jalur terbuka / jalur setengah terbuka |
| outpost / weak square (hole) | pos terdepan / kotak lemah (lubang) |
| good / bad bishop / bishop pair | gajah baik / gajah buruk / pasangan gajah |
| candidate moves / initiative / counterplay | langkah kandidat / inisiatif / serangan balik |
| prophylaxis / maneuvering / space | profilaksis / manuver / ruang |
| rook lift / cutting off the king | angkat benteng / memotong raja |
| fianchetto / gambit | fianchetto / gambit |
| back-rank mate / escape square (luft) | mat baris belakang / petak pelarian |
| smothered mate | mat terkurung |
| box, cage (the king's) | kandang, terkurung / dikurung (never «petak») |
| Greek gift / windmill / mating net | hadiah Yunani / kincir angin / jaring mat |
| Arabian mate / Noah's Ark trap / Légal's mate, Légal's trap | mat Arab / jebakan Bahtera Nuh / mat Légal, jebakan Légal (always «Légal», never «Legall») |
| Boden's mate / Anastasia's mate / Philidor's Legacy / Scholar's mate | mat Boden / mat Anastasia / Warisan Philidor / mat empat langkah |
| royal fork / absolute / relative pin | garpu kerajaan / jepitan mutlak / jepitan relatif |
| battery / building a bridge | baterai / membangun jembatan |
| perpetual check / dead position | sekak abadi / posisi mati |
| blitz / rapid / classical / bullet | blitz / cepat / klasik / bullet |
| increment / delay / flag | tambahan waktu / tunda / bendera jatuh |
| arbiter / Swiss / round robin / bye / tie-break | wasit / sistem Swiss / setengah kompetisi / bye / penentu peringkat |
| norm / GM / IM / FM / CM | norma / Grandmaster / Master Internasional / FIDE Master / Candidate Master |
| premove / fair play | premove / *fair play* (italic, as a loan term) |
| historical European queen (before the reform) | «ratu» only as the piece's historical name in Europe; the piece itself is always menteri |

### Where these words come from

The table above was checked against the sources Indonesian players actually
use, not against a dictionary. The decisive one is the **official Indonesian
translation of the FIDE Laws of Chess** published by FIDE's arbiters' site and
used by PERCASI (`peraturan_permainan_catur_fide_law_of_chess_2018_indonesian`),
supported by **chess.com's Indonesian glossary** (`chess.com/id/terms`) and
**Wikipedia bahasa Indonesia** (*Catur*, *Taktik catur*, *Menteri (catur)*).

Rulings, and what changed:

- **square = «petak», not «kotak».** The FIDE laws use *petak* 104 times and
  *kotak* not once («Papan catur terdiri atas 8x8 kisi dari 64 petak bujur
  sangkar»); id.wikipedia and chess.com's *Aturan Petak* agree. The contract
  previously mandated the reverse, and the whole corpus was swept.
- **file = «lajur», not «jalur».** Pasal 2.4 verbatim: «Delapan jajaran
  petak-petak vertikal dinamakan "lajur". Delapan jajaran petak-petak
  horisontal dinamakan "baris".» chess.com titles its entry *Lajur dalam
  Catur*. «Jalur» is the everyday word for a lane or path and is no longer
  used for a file; a generic line is «garis», a lane or strip «lorong».
- **check = «sekak», checkmate = «sekakmat».** CONFIRMED against the contract:
  the FIDE laws write *Sekak* and *Sekak-mat* throughout. chess.com's
  *Skak*/*Skakmat* is the colloquial spelling; the app is written in bahasa
  baku, so «sekak» stands and «skak» stays banned.
- **pawn = «pion».** The FIDE laws say *Bidak*, but chess.com and current
  Indonesian chess writing say *Pion* (*Pion Bebas*, *Pion Terbelakang*,
  *Promosi Pion*), and id.wikipedia titles the article *Pion (catur)*. The
  app's house word stays «pion» and «bidak» stays banned — a deliberate
  choice of the modern register over the older legal text.
- **queen = «menteri».** Confirmed: the FIDE laws and id.wikipedia both use
  *Menteri*. «Ratu» survives only as the historical European name, in italics.
- **fork = «garpu», pin = «jepitan», deflection = «pengalihan», decoy =
  «umpan», overload = «beban berlebih», battery = «baterai».** All confirmed;
  chess.com's entries are *Taktik Garpu*, *Taktik Umpan*, *Beban Berlebih*,
  *Baterai*.
- **skewer = «tusukan».** Kept. id.wikipedia's *Taktik catur* lists *tusukan*;
  chess.com offers *Skewer/Tusuk Sate*. «Tusuk sate» is the vivid colloquial
  name, but «tusukan» is attested, unambiguous and already consistent across
  the corpus, so it stands.
- **smothered mate = «mat terkurung».** Kept over chess.com's *Skakmat
  Terjepit*, which collides with «jepitan» (pin), and over the popular *mat
  beranak*.
- **discovered attack = «serangan tersingkap».** Kept: id.wikipedia says
  *serangan terbuka* (which collides with «lajur terbuka») and chess.com says
  *serangan tarik*; the sources do not agree, and «tersingkap» is transparent.
- **zwischenzug = «langkah perantara»**, following chess.com. The contract
  previously said «langkah antara», which reads as a stray preposition.
- **minor/heavy piece = «buah ringan / buah berat».** Kept over chess.com's
  *Perwira Ringan / Perwira Berat*, so that «buah» stays the one word for a
  piece across the whole app.

Opening names follow the UI bundle: Pertahanan Sisilia, Pertahanan Prancis,
Pertahanan Caro-Kann, Pertahanan Skandinavia, Pertahanan Petroff, Permainan
Italia (Giuoco Piano, Dua Kuda), Ruy López, Permainan Skotlandia, Permainan
Wina, Gambit Raja, Gambit Menteri (Ditolak / Diterima), Pertahanan Slav,
Pertahanan India Raja, Nimzo-Indian, Pertahanan Belanda, Sistem London,
Pembukaan Inggris, Pembukaan Réti.

Player names keep their usual Latin spelling (Kasparov, Karpov, Fischer, Tal,
Steinitz, Anderssen, Philidor, al-Adli, as-Suli).

## Culture

Indonesia is diverse and majority Muslim. Facts, dates, names and game scores
stay exactly as in English. Tone adapts:

- No romance imagery: the "kiss" mate is «mat berdampingan» (the queen lands
  beside the king); a love poem is named as a poem, without dwelling on it.
- No gambling images: "bet", "gamble" and "jackpot" become risk, venture or
  calculation («risiko», «mengambil risiko yang terhitung»). No alcohol.
- Religious figures and places in history (a priest, a monastery, a caliph)
  are named plainly and respectfully, without commentary.
- The Persian and Arab chapter of chess history keeps its names in their
  common Indonesian spelling: syatranj, al-Adli, as-Suli, mansubat.
- The polite register never turns preachy: a mistake is a mistake, said
  kindly, the way a good «pelatih» says it.
