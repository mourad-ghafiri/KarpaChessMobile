# French translation guide

The French corpus lives in `assets/data/lessons/fr/` and
`assets/data/puzzles/fr/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart fr` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the French conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/fr.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Standard French, clear and warm: a coach speaking to one learner. The reader
  is «vous» (vouvoiement), as everywhere in the UI. Instructions use the
  imperative: «Jouez», «Prenez», «Cherchez», «Comptez».
- The sides are «les Blancs» and «les Noirs» (capitalized, plural, as French
  chess writing names the players), or «votre adversaire». Adjectives stay
  lowercase: «le roi noir», «un pion blanc». A piece is «il/elle» by the
  grammatical gender of its name (la tour… elle ; le fou… il), never a person.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make. Anglicisms are avoided: «gaffe», not «blunder».

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`), as in
  the UI bundle: the board reads them. Chips must match the English field
  exactly. In prose, a piece letter is explained once in the notation lesson
  (K, Q, R, B, N come from the English names).
- Squares stay as written: e4, d5, h7. Files and ranks: «la colonne e»,
  «la huitième rangée» / «la 8e rangée».
- Numbers: years and ratings without separator (1851, 2800); other thousands
  with a space (1 000 ans); decimals with a comma (3,5 points); ordinals 1er,
  2e, 8e.
- Typography: a non-breaking space (U+00A0) before `: ; ! ?` and `»`, and after
  `«`; quotations in « guillemets », never "straight quotes". Em dashes — with
  spaces — as in English. Apostrophe: the straight `'`, as in the UI bundle.
- Puzzle explanations open with `## L'idée`.

## Pieces and core terms

| English | French |
|---|---|
| king / queen / rook / bishop / knight / pawn | roi / dame / tour / fou / cavalier / pion |
| piece / minor piece / heavy piece | pièce / pièce mineure / pièce lourde |
| square / file / rank / diagonal | case / colonne / rangée / diagonale |
| board | échiquier |
| light / dark square, light-squared bishop | case blanche / case noire, fou de cases blanches (never «claire / foncée», as French chess writing and the UI bundle say it) |
| to queen / promote | aller à dame (never «faire dame») / promouvoir |
| battery / rook ladder | batterie / mat de l'escalier |
| the Immortal Game / Center Game / Saavedra position | l'Immortelle / Partie du centre / position de Saavedra |
| back rank | dernière rangée (rangée du fond when it is one's own) |
| center / wing, kingside / queenside | centre / aile, aile roi / aile dame |
| check / checkmate / mate / to be mated / supported queen mate ("kiss") | échec / échec et mat / mat / être maté / baiser de la dame (baiser de la mort) |
| stalemate / draw | pat / nulle (partie nulle) |
| castling (short / long) | roque (petit roque / grand roque) |
| en passant | prise en passant |
| promotion / underpromotion | promotion / sous-promotion |
| capture / recapture | prise, prendre / reprendre |
| move | coup |
| opening / middlegame / endgame | ouverture / milieu de partie / finale |
| development / tempo / material | développement / temps (tempo) / matériel |
| exchange (rook for minor) / exchange sacrifice | qualité / sacrifice de qualité |
| sacrifice | sacrifice / sacrifier |
| blunder / mistake / inaccuracy | gaffe / erreur / imprécision |
| hanging piece | pièce en prise |
| threat / defender / attacker | menace / défenseur / attaquant |
| fork / double attack | fourchette / attaque double |
| pin (absolute / relative) / skewer | clouage (absolu / relatif) / enfilade |
| discovered attack / discovered check / double check | attaque à la découverte / échec à la découverte / échec double |
| removing the defender | élimination du défenseur |
| deflection / decoy / overload | déviation / attraction / surcharge |
| interference | interception |
| in-between move (zwischenzug) | coup intermédiaire |
| x-ray | rayons X |
| trapped piece / quiet move | pièce piégée / coup tranquille |
| king hunt / mating net | chasse au roi / filet de mat |
| zugzwang / opposition / key squares / rule of the square | zugzwang / opposition / cases clés / règle du carré |
| passed / isolated / doubled / backward pawn | pion passé / isolé / doublé / arriéré |
| pawn chain / pawn break / breakthrough | chaîne de pions / rupture / percée |
| minority attack / pawn storm | attaque de minorité / assaut de pions |
| open / half-open file | colonne ouverte / semi-ouverte |
| outpost / weak square (hole) | avant-poste / case faible (trou) |
| good / bad bishop / bishop pair / opposite-colored bishops | bon fou / mauvais fou / paire de fous / fous de couleurs opposées |
| candidate moves / initiative / counterplay | coups candidats / initiative / contre-jeu |
| prophylaxis / maneuvering / space | prophylaxie / manœuvre / espace |
| rook lift / cutting off the king | levée de tour / couper le roi |
| fianchetto / gambit | fianchetto / gambit |
| back-rank mate / escape square (luft) | mat du couloir / case de fuite |
| smothered mate / Philidor's Legacy | mat étouffé / le legs de Philidor |
| Greek gift / windmill | sacrifice grec / moulin |
| Arabian mate / Boden's mate / Anastasia's mate | mat arabe / mat de Boden / mat d'Anastasia |
| Légal's mate (the trap that leads to it) / Noah's Ark trap / Scholar's mate | mat de Légal (piège de Légal) / piège de l'arche de Noé / coup du berger |
| Philidor position / Lucena position, building a bridge | position de Philidor / position de Lucena, construire le pont |
| perpetual check / dead position | échec perpétuel / position morte |
| blitz / rapid / classical / bullet | blitz / rapide / cadence lente (classique) / bullet |
| increment / delay / flag fall | incrément / délai / chute du drapeau |
| arbiter / Swiss / round robin / bye / tie-break | arbitre / système suisse / toutes rondes / exempt / départage |
| norm / GM / IM / FM / CM | norme / Grand Maître International / Maître International / Maître FIDE / Candidat Maître |
| rating | classement Elo (Elo) |
| touch-move | pièce touchée, pièce jouée |
| fair play / premove | *fair-play* (italic, as a loan word) / pré-coup (*premove*) |
| historical names of the queen (ferz, *regina*) | ferz in bold as a term, foreign names in italics; the piece itself is always «dame», never «reine» (the gate rejects it outside italics) |

Opening names follow the UI bundle: Défense sicilienne, Défense française,
Défense Caro-Kann, Défense scandinave, Défense Petroff, Partie italienne
(Giuoco Piano, Deux Cavaliers), Ruy López (partie espagnole), Partie écossaise,
Partie viennoise, Gambit du Roi, Gambit Dame (refusé / accepté), Défense slave,
Défense est-indienne, Nimzo-indienne, Défense hollandaise, Système de Londres,
Ouverture anglaise, Ouverture Réti, Attaque est-indienne, Défense Grünfeld,
Catalane, variante Najdorf.

Player names keep their usual French spelling (Kasparov, Karpov, Fischer, Tal,
Steinitz, Anderssen, Philidor, Alekhine, al-Adli, as-Suli); Russian names take
their French transliteration (Kortchnoï, Tchigorine).

## Culture

France has a long chess history, and the French reader knows its names:
François-André Danican Philidor, the Café de la Régence, Kermur de Légal,
La Bourdonnais. Where the English already names them, their French spellings
and titles are used (the mat de Légal, not Legall). Nothing is added that the
English does not say.

- Facts, dates, names and game scores stay exactly as in English.
- The standard French chess idiom wins over a literal rendering: «coup du
  berger», «pièce touchée, pièce jouée», «le mat du couloir».
- Idioms are adapted, not translated word for word («faire d'une pierre deux
  coups» for "two birds with one stone").
- The tone is precise and elegant, never stiff: a mistake is a mistake, said
  kindly.
