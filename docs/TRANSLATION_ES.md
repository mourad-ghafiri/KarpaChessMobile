# Spanish translation guide

The Spanish corpus lives in `assets/data/lessons/es/` and
`assets/data/puzzles/es/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart es` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Spanish conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/es.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Neutral, standard Spanish (usable from Madrid to Mexico City), clear and
  warm: a coach speaking to one learner. The reader is «tú», as everywhere in
  the UI («Encuentra la jugada», «Juégalo»). Imperatives: «Juega», «Toma»,
  «Busca», «Cuenta». No regional slang, no «vosotros», no «vos».
- The sides are «las Blancas» and «las Negras» (capitalized, as in the UI:
  «Ganan las Blancas»), or «tu rival». Adjectives stay lowercase: «el rey
  negro», «un peón blanco». A piece is referred to by the grammatical gender
  of its name (la torre… ella; el alfil… él), never as a person.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. In prose, the
  notation lesson explains once that the app's letters (K, Q, R, B, N) come
  from the English names; Spanish books use R, D, T, A, C.
- Squares stay as written: e4, d5, h7. Files and ranks: «la columna e»,
  «la octava fila».
- Numbers: years and ratings without separator (1851, 2800); decimal comma
  (3,5 puntos); percent with a space (76 %).
- Typography: opening marks are mandatory (¿…? ¡…!), no space before `: ; ? !`;
  quotations in « comillas angulares », never "straight quotes"; em dashes —
  with spaces — as in English.
- Puzzle explanations open with `## La idea`.

## Pieces and core terms

The table below was checked against what Spanish-speaking players actually say:
the Spanish Wikipedia glossary (*Anexo:Glosario de ajedrez*, *Enfilada
(ajedrez)*), lichess's Spanish puzzle themes and chess.com's Spanish tactics
articles. Where those disagree, the term Spanish chess literature settled on
wins: **horquilla** (not *tenedor*, which Wikipedia lists but which players
reserve for a pawn's double attack), **enfilada** (not lichess's *espada*, nor
*pincho*/*brocheta*), **atracción** (not *señuelo*), **mate de la coz** (not
lichess's *mate ahogado*, which collides with *ahogado* = stalemate).

| English | Spanish |
|---|---|
| king / queen / rook / bishop / knight / pawn | rey / dama / torre / alfil / caballo / peón (never «reina») |
| piece / minor piece / heavy piece | pieza / pieza menor / pieza mayor |
| square / file / rank / diagonal / board | casilla / columna / fila / diagonal / tablero |
| light / dark square, light-squared bishop | casilla blanca / negra, alfil de casillas blancas |
| back rank | última fila (primera fila when it is one's own) |
| center / wing, kingside / queenside | centro / flanco, flanco de rey / flanco de dama |
| check / checkmate / mate / to be mated | jaque / jaque mate / mate / recibir mate |
| stalemate / draw | rey ahogado (ahogado) / tablas |
| castling (short / long) | enroque (corto / largo) |
| en passant | captura al paso |
| promotion / to queen / underpromotion | promoción / coronar / subpromoción |
| capture / recapture | captura, capturar / recapturar |
| move / tempo | jugada / tiempo |
| opening / middlegame / endgame | apertura / medio juego / final |
| development / material | desarrollo / material |
| exchange (rook for minor) / exchange sacrifice | calidad / sacrificio de calidad |
| blunder / mistake / inaccuracy | error grave / error / imprecisión |
| hanging / loose piece | pieza colgada / pieza sin defensa |
| threat / defender / attacker | amenaza / defensor / atacante |
| fork / double attack | horquilla / ataque doble |
| pin (absolute / relative) / skewer | clavada (absoluta / relativa) / enfilada |
| discovered attack / discovered check / double check | ataque al descubierto / jaque al descubierto / jaque doble |
| removing the defender | eliminar al defensor |
| deflection / decoy / overload | desviación / atracción / sobrecarga (never «señuelo»: the pair Spanish players learn is *atracción* ↔ *desviación*) |
| interference / in-between move / x-ray | interferencia / jugada intermedia / rayos X |
| trapped piece / quiet move | pieza atrapada / jugada tranquila |
| king hunt / mating net | caza al rey / red de mate |
| zugzwang / opposition / key squares / rule of the square | zugzwang / oposición / casillas clave / regla del cuadrado |
| passed / isolated / doubled / backward pawn | peón pasado / aislado / doblado / retrasado |
| pawn chain / pawn break / breakthrough | cadena de peones / ruptura / irrupción |
| minority attack / pawn storm | ataque de minorías / avalancha de peones |
| open / half-open file | columna abierta / semiabierta |
| outpost / weak square (hole) | puesto avanzado / casilla débil (agujero) |
| good / bad bishop / bishop pair / opposite-colored bishops | alfil bueno / alfil malo / pareja de alfiles / alfiles de distinto color |
| candidate moves / initiative / counterplay | jugadas candidatas / iniciativa / contrajuego |
| prophylaxis / maneuvering / space | profilaxis / maniobra / espacio |
| rook lift / cutting off the king / battery | elevación de torre / cortar al rey / batería |
| fianchetto / gambit | fianchetto / gambito |
| back-rank mate / escape square (luft) | mate del pasillo / casilla de escape |
| smothered mate / Philidor's Legacy | mate de la coz / el legado de Philidor |
| Greek gift / windmill / rook ladder | sacrificio griego / el molino / mate de la escalera |
| Arabian mate / Boden's mate / Anastasia's mate | mate árabe / mate de Boden / mate de Anastasia |
| Légal's mate / Noah's Ark trap / Scholar's mate | mate de Legal / trampa del Arca de Noé / mate del pastor |
| Philidor position / Lucena position, building a bridge | posición de Philidor / posición de Lucena, construir el puente |
| perpetual check / dead position | jaque perpetuo / posición muerta |
| blitz / rapid / classical / bullet | blitz (partidas relámpago) / rápidas / clásicas / bullet |
| increment / delay / flag fall | incremento / retardo / caída de bandera |
| arbiter / Swiss / round robin / bye / tie-break | árbitro / sistema suizo / liguilla (todos contra todos) / descanso (*bye*) / desempate |
| norm / GM / IM / FM / CM | norma / Gran Maestro Internacional / Maestro Internacional / Maestro FIDE / Candidato a Maestro |
| rating / touch-move / j'adoube | Elo / pieza tocada, pieza movida / «compongo» |
| fair play / premove | juego limpio / premovimiento (*premove*) |
| supported queen mate ("kiss") | beso de la dama (beso de la muerte) |
| the Immortal Game / Center Game / Saavedra position / Réti's study | la Inmortal / Partida del Centro / posición de Saavedra / estudio de Réti |
| historical queen (ferz) | alferza; the piece itself is always «dama», never «reina» (the gate rejects it) |
| double check / skewer (verb) | jaque doble (never «doble jaque») / dar una enfilada (never «ensartar») |

Opening names follow the UI bundle: Defensa Siciliana, Defensa Francesa,
Defensa Caro-Kann, Defensa Escandinava, Defensa Petrov, Apertura Italiana
(Giuoco Piano, Dos Caballos), Apertura Española (Ruy López), Apertura Escocesa,
Apertura Vienesa, Gambito de Rey, Gambito de Dama (Rehusado / Aceptado),
Defensa Eslava, Defensa India de Rey, Nimzo-India, India de Dama, Defensa
Holandesa, Sistema Londres, Apertura Inglesa, Apertura Réti, Ataque Indio de
Rey, Defensa Grünfeld, Catalana, variante Najdorf, Partida del Centro.

## Culture

Spanish is where modern chess was born: the new queen appears in *Scachs
d'amor* (Valencia, around 1475), Lucena printed his book in Salamanca around
1497, and Ruy López de Segura was a Spanish priest. Where the English names
these, the Spanish spellings are used (Isabel de Castilla, al-Ándalus,
Salamanca). Nothing is added that the English does not say, with two
deliberate exceptions where the Spanish reader's own words need it: the
notation lesson notes that Spanish books use R, D, T, A, C, and the history of
the bishop notes that Spanish kept the Arabic name *alfil*.

Russian names follow Spanish press transliteration: Spaski, Kárpov, Kaspárov,
Krámnik, Topálov, Korchnói, Chigorin, Bogoliúbov.

- Facts, dates, names and game scores stay exactly as in English.
- The standard Spanish chess idiom wins over a literal rendering: «mate del
  pastor», «mate de la coz», «pieza tocada, pieza movida», «compongo».
- Idioms are adapted («matar dos pájaros de un tiro»).
- The tone is direct and encouraging, never stiff: a mistake is a mistake,
  said kindly.
