# Italian translation guide

The Italian corpus lives in `assets/data/lessons/it/` and
`assets/data/puzzles/it/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart it` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Italian conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/it.json`) and
the Federazione Scacchistica Italiana: a lesson must call a piece, a pack or a
theme exactly what the buttons and cards around it call it.

## Register

- Standard written Italian, warm and direct: a coach talking to one learner.
  The reader is **voi** — instructions are the plural imperative («guardate»,
  «contate», «giocate»), which keeps the same distance as the English second
  person without the stiffness of *Lei*. Possessives follow: «il vostro re»,
  «la vostra donna».
- The sides are **il Bianco** and **il Nero**, capitalized as Italian chess
  writing does, or «il vostro avversario». A piece is «questo pezzo», never
  *lui*; people are named or called «questo giocatore», and no gendered
  pronoun is added where the English says *they*.
- Short sentences, one idea per beat. Italian loves the subordinate chain;
  resist it. Keep the English beat's length and let the next sentence start.
- Do not explain more than the English does.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that K, Q, R, B, N come from the English piece names,
  and notes that Italian scoresheets also use R, D, T, A, C for
  Re, Donna, Torre, Alfiere, Cavallo.
- Squares stay as written: e4, d5, h7. Files and ranks are **colonna** and
  **traversa** («la colonna e», «la settima traversa»); a diagonal is
  **diagonale**, the long diagonal **la grande diagonale**, the back rank
  **la traversa di fondo**.
- Squares take the preposition, never an apostrophe: «in e4», «l'alfiere in
  c4», «il pedone in e5», «da d1 a h5». Never *e4'*.
- Western digits for years, ratings, counts and scores (1851, 2800). A decimal
  is a comma: 3,5–2,5. Ordinals are written out or with the masculine
  degree sign: «la 3ª traversa» is avoided; write «la terza traversa».
- Quotation marks are « » (caporali), never straight `"`. The apostrophe is
  the straight `'` — «l'alfiere», «dell'alfiere», «un'idea» — and the curly
  `’` is rejected, so the corpus has one spelling to search for.
- Accents are not optional: perché, più, può, così, già, cioè, città, perciò.
  The gate rejects the bare forms, and `e'` instead of è.
- No space before `, . : ; ? !`. A lone Black move keeps the ellipsis: «...d5».
- Puzzle explanations open with `## L'idea`.

## Pieces and core terms

| English | Italian |
|---|---|
| king / queen / rook / bishop / knight / pawn | re / donna / torre / alfiere / cavallo / pedone (never regina, vescovo, cavaliere, castello, pedina) |
| piece / minor piece / heavy piece | pezzo / pezzo leggero / pezzo pesante |
| square / file / rank / diagonal / board | casa / colonna / traversa / diagonale / scacchiera |
| light / dark square, light-squared bishop | casa chiara / casa scura, alfiere campochiaro |
| back rank | traversa di fondo |
| center / wing, kingside / queenside | centro / ala, lato di re / lato di donna |
| check / to give check / checkmate / to be mated | scacco / dare scacco / scacco matto / subire matto |
| stalemate / draw | stallo / patta |
| castling (short / long) | arrocco (corto / lungo) |
| en passant | presa en passant |
| promotion / to queen / underpromotion | promozione / promuovere a donna / sottopromozione |
| capture / recapture | presa (prendere) / riprendere |
| move / tempo | mossa / tempo |
| opening / middlegame / endgame | apertura / mediogioco / finale |
| development / material | sviluppo / materiale |
| exchange (rook for minor) / exchange sacrifice | qualità / sacrificio di qualità |
| sacrifice | sacrificio (sacrificare) |
| blunder / mistake / inaccuracy | errore grave / errore / imprecisione |
| hanging / loose piece | pezzo in presa / pezzo indifeso |
| threat / defender / attacker | minaccia / difensore / attaccante |
| fork / double attack / royal fork | forchetta / doppio attacco / forchetta reale |
| pin (absolute / relative) / skewer | inchiodatura (assoluta / relativa) / infilata |
| discovered attack / discovered check / double check | attacco di scoperta / scacco di scoperta / scacco doppio |
| removing the defender | eliminazione del difensore |
| deflection / decoy / overload | deviazione / adescamento / sovraccarico |
| interference / in-between move / x-ray | interferenza / mossa intermedia (intermezzo) / raggi X |
| trapped piece / quiet move | pezzo intrappolato / mossa tranquilla |
| king hunt / mating net | caccia al re / rete di matto |
| zugzwang / opposition / key squares / rule of the square | zugzwang / opposizione / case chiave / regola del quadrato |
| passed / isolated / doubled / backward pawn | pedone passato / isolato / doppiato / arretrato |
| pawn chain / pawn break / breakthrough | catena di pedoni / rottura / sfondamento |
| minority attack / pawn storm | attacco di minoranza / valanga di pedoni |
| open / half-open file | colonna aperta / semiaperta |
| outpost / weak square (hole) | avamposto / casa debole (buco) |
| good / bad bishop / bishop pair / opposite-colored bishops | alfiere buono / cattivo / coppia degli alfieri / alfieri di colore contrario |
| candidate moves / initiative / counterplay | mosse candidate / iniziativa / controgioco |
| prophylaxis / maneuvering / space | profilassi / manovra / spazio |
| rook lift / cutting off the king / battery | sollevamento di torre / taglio del re / batteria |
| fianchetto / gambit | fianchetto / gambetto |
| back-rank mate / escape square (luft) | matto del corridoio / casa di fuga (presa d'aria) |
| smothered mate / Philidor's Legacy | matto affogato / il Lascito di Philidor |
| Greek gift / windmill / rook ladder | dono greco / mulino / matto a scaletta |
| Arabian mate / Boden's mate / Anastasia's mate | matto arabo / matto di Boden / matto di Anastasia |
| Légal's mate / Noah's Ark trap / Scholar's mate | matto di Légal / trappola dell'Arca di Noè / matto del barbiere |
| supported queen mate ("kiss") | matto del bacio |
| Philidor position / Lucena position, building a bridge | posizione di Philidor / posizione di Lucena, costruire il ponte |
| perpetual check / dead position | scacco perpetuo / posizione morta |
| blitz / rapid / classical / bullet | blitz (lampo) / rapid / classico / bullet |
| increment / delay / flag fall | incremento / ritardo / caduta della bandierina |
| arbiter / Swiss / round robin / bye / tie-break | arbitro / sistema svizzero / girone all'italiana / bye / spareggio tecnico |
| norm / GM / IM / FM / CM | norma / Grande Maestro / Maestro Internazionale / Maestro FIDE / Candidato Maestro |
| rating / touch-move / j'adoube | punteggio Elo / pezzo toccato pezzo mosso / «aggiusto» |
| fair play / premove | fair play / premossa |
| chaturanga / shatranj / ferz / alfil | chaturanga / shatranj / *ferz* / *alfil* |
| foot soldiers / horses / elephants / chariots (chaturanga's divisions) | fanti / cavalli / elefanti / carri da guerra |
| legal / illegal move | mossa legale / mossa illegale |
| the Immortal Game / Turochamp | la Partita Immortale / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | posizione di Saavedra / lo studio di Réti |
| Buchholz / Sonneborn-Berger | Buchholz / Sonneborn-Berger |

### Where the table comes from

The table is not taste; every entry was checked against the places Italian
players actually write. The sources consulted are the Italian Wikipedia
(«Tattica (scacchi)», «Adescamento (scacchi)», «Termini scacchistici», «Matto
del barbiere», «Scacco matto», «Pedone (scacchi)», «Finali elementari»), the
tactical-theme index of AIChess (`albanesi.it`), the tactics series of
MattoScacco, `corso-di-scacchi.it`, chess.com's Italian pages, and lichess's
own Italian puzzle-theme file (`lichess-org/lila`,
`translation/dest/puzzleTheme/it-IT.xml`).

Three rulings, where the sources disagreed:

- **decoy is «adescamento», never *attrazione*.** Italian Wikipedia gives the
  motif a dedicated article under that name, lists it among the elementary
  motifs in «Tattica (scacchi)», and lichess translates its `attraction` theme
  the same way. *Attrazione* is a word-for-word rendering of the English with
  no currency in Italian chess writing, and it was corrected corpus-wide.
- **interference is «interferenza», never *interposizione*.** lichess's file
  uses «Interposizione», but in Italian that names the different act of
  stepping a piece in front of a check; AIChess lists «Interferenza» as its own
  preparatory theme, which is the sense the lessons use.
- **a quiet move is a «mossa tranquilla».** lichess writes «mossa calma»;
  Italian coaching writing (MattoScacco, «Le mosse tranquille») settled on
  *tranquilla*, and the corpus follows it.

Two further choices are deliberate rather than disputed. A pawn storm is a
«valanga di pedoni» (the term Italian strategy manuals use; chess.com's Italian
lesson says «tempesta di pedoni», and both are attested) and removing the
defender is «eliminazione del difensore» (AIChess says «rimozione della
difesa», lichess «cattura del difensore»). *Forchetta* is kept for the
one-piece fork and *attacco doppio* for the family, exactly as Wikipedia
separates them.

Opening names follow Italian usage: Difesa Siciliana, Difesa Francese, Difesa
Caro-Kann, Difesa Scandinava, Difesa Petroff, Partita Italiana (Giuoco Piano,
Due Cavalli), Partita Spagnola (Ruy Lopez), Partita Scozzese, Partita Viennese,
Gambetto di Re, Gambetto di Donna (accettato / rifiutato), Difesa Slava, Difesa
Est-Indiana, Nimzo-Indiana, Ovest-Indiana, Difesa Olandese, Sistema Londra,
Apertura Inglese, Apertura Réti, Attacco Est-Indiano, Difesa Grünfeld,
Catalana, variante Najdorf, Partita del Centro.

Player names keep their own spelling: Philidor, Morphy, Anderssen, Kieseritzky,
Steinitz, Lasker, Capablanca, Alekhine, Botvinnik, Tal, Fischer, Spassky,
Karpov, Kasparov, Kramnik, Topalov, Anand, Carlsen, Korchnoi, Chigorin,
Nimzowitsch, Judit Polgár, Ruy López de Segura, Lucena, Saavedra, Réti,
Turing, Arpad Elo. China's world champion is Ding Liren, and Gukesh Dommaraju
is Gukesh. Engines keep their names (Stockfish, AlphaZero, Deep Blue).

## Culture

Italy gave chess two of its oldest names and one of its rulebooks: the Partita
Italiana is still called that everywhere, and the 1470s rewrite that created
the modern queen and bishop reached Italy within a generation. The trap for a
translator is the everyday word: the piece beside the king is **la donna**, as
the Federazione Scacchistica Italiana writes it — *regina* belongs to a real
queen, and to the historical note in italics. **L'alfiere** is the bishop
(never *vescovo*), **il cavallo** the knight (never *cavaliere*), **la torre**
the rook, **il pedone** the pawn (never *pedina*, which is a draughtsman).

- Facts, dates, names and game scores stay exactly as in English.
- The standard Italian idiom wins over a literal rendering: «matto del
  corridoio», «matto affogato», «pezzo toccato pezzo mosso».
- Idioms are adapted, not translated word for word («prendere due piccioni con
  una fava» for two birds with one stone).
- Nothing is added that the English does not say, with one deliberate
  exception where the Italian reader's own words need it: the notation lesson
  notes that Italian scoresheets write R, D, T, A, C beside the international
  K, Q, R, B, N.
- The tone is encouraging and direct, the way a good allenatore speaks: a
  mistake is a mistake, said kindly.
