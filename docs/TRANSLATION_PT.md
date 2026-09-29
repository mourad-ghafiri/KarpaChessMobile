# Portuguese translation guide

The Portuguese corpus lives in `assets/data/lessons/pt/` and
`assets/data/puzzles/pt/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart pt` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Portuguese conventions below. A file that is
not translated yet falls back to English in the app.

**This is European Portuguese.** Not a Brazilian text with a few words swapped:
the register, the syntax, the orthography and the chess vocabulary are all the
ones a reader in Portugal uses. The vocabulary follows the app's own UI bundle
(`assets/data/i18n/pt.json`) and the Federação Portuguesa de Xadrez — a lesson
must call a piece, a pack or a theme exactly what the buttons and cards around
it call it.

## Register

- Standard written European Portuguese, warm and direct: a coach talking to one
  learner. The reader is **tu** — instructions are the second-person singular
  imperative («olha», «conta», «joga»), and the possessive follows: «o teu
  rei», «a tua dama», «os teus peões». `você` and `vocês` are rejected by the
  gate; they are the Brazilian address, and in Portugal they would put a desk
  between the coach and the learner.
- Verbs agree with *tu* throughout: «tens», «podes», «vês», «fazes»,
  «perdes». A stray «tem» or «pode» where the reader is meant reads as
  Brazilian even when the word itself is fine.
- **«estar a» + infinitive, never the gerund periphrasis.** «o rei está a
  fugir», not «está fugindo». The gate rejects the second form.
- **Enclisis**, the European pronoun placement: «dá-lhe uma casa»,
  «toma-a agora», «perde-se um tempo» — not «lhe dá» / «a toma».
- The sides are **as brancas** and **as pretas**, or «o teu adversário». A
  piece is «esta peça», never *ele*; people are named or called «este
  jogador», and no gendered pronoun is added where the English says *they*.
- Short sentences, one idea per beat. Portuguese happily chains subordinates;
  resist it. Keep the English beat's length and let the next sentence start.
- Do not explain more than the English does.

## Orthography, notation, numbers, typography

- The **Acordo Ortográfico de 1990** as Portugal applies it: «ação»,
  «direção», «objeto», «atividade» — but the consonants Portugal still
  pronounces stay, so **facto** and **contacto**, never *fato*/*contato*
  (in Portugal *fato* is a suit of clothes). The gate rejects the Brazilian
  spellings, including the `ô`/`ê` family: **económico**, **eletrónico**,
  **fenómeno**, **género**.
- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that K, Q, R, B, N come from the English piece names,
  and notes that Portuguese scoresheets also use R, D, T, B, C for
  Rei, Dama, Torre, Bispo, Cavalo.
- Squares stay as written: e4, d5, h7. Files and ranks are **coluna** and
  **linha** («a coluna e», «a sétima linha»); a diagonal is **diagonal**, the
  long diagonal **a grande diagonal**, the back rank **a linha de fundo**.
- Squares take the preposition, never an apostrophe: «em e4», «o bispo em
  c4», «o peão em e5», «de d1 a h5».
- Western digits for years, ratings, counts and scores (1851, 2800). A decimal
  is a comma: 3,5–2,5. Large numbers follow Portugal: «mil milhões», never
  *bilhão*. Ordinals are written out: «a terceira linha», «a oitava linha».
- Quotation marks are « » (aspas angulares), never straight `"`. The
  apostrophe, where Portuguese needs one, is the straight `'`; the curly `’`
  is rejected, so the corpus has one spelling to search for.
- Accents are not optional: não, são, então, também, além, já, só, três,
  após, próximo, último, único, possível, difícil, peão, área, tática. The
  gate rejects the bare forms.
- No space before `, . : ; ? !`. A lone Black move keeps the ellipsis: «...d5».
- Puzzle explanations open with `## A Ideia`.

## Pieces and core terms

| English | Portuguese |
|---|---|
| king / queen / rook / bishop / knight / pawn | rei / dama / torre / bispo / cavalo / peão (never rainha, cavaleiro, castelo, soldado) |
| piece / minor piece / heavy piece | peça / peça menor / peça pesada |
| square / file / rank / diagonal / board | casa / coluna / linha / diagonal / tabuleiro |
| light / dark square, light-squared bishop | casa clara / casa escura, bispo das casas claras |
| back rank | linha de fundo |
| center / wing, kingside / queenside | centro / ala, ala do rei / ala da dama |
| check / to give check / checkmate / to be mated | xeque / dar xeque / xeque-mate / sofrer mate |
| stalemate / draw | afogamento / empate |
| castling (short / long) | roque (curto / longo); to castle is **rocar** — «roca», «rocou», «rocado» |
| en passant | captura en passant |
| promotion / to queen / underpromotion | promoção / promover a dama / subpromoção |
| capture / recapture | captura (capturar) / recapturar |
| move / tempo | jogada / tempo |
| opening / middlegame / endgame | abertura / meio-jogo / final |
| development / material | desenvolvimento / material |
| exchange (rook for minor) / exchange sacrifice | qualidade / sacrifício de qualidade |
| sacrifice | sacrifício (sacrificar) |
| blunder / mistake / inaccuracy | erro grave / erro / imprecisão |
| hanging / loose piece | peça pendurada / peça desprotegida |
| threat / defender / attacker | ameaça / defensor / atacante |
| fork / double attack / royal fork | garfo / ataque duplo / garfo real |
| pin (absolute / relative) / skewer | cravada (absoluta / relativa) / espeto — a piece is cravada **contra** the piece behind it, never *cravada ao* |
| discovered attack / discovered check / double check | ataque à descoberta / xeque à descoberta / xeque duplo |
| removing the defender | eliminação do defensor |
| deflection / decoy / overload | desvio / atração / sobrecarga |
| interference / in-between move / x-ray | interferência / jogada intermédia / raios X |
| trapped piece / quiet move | peça encurralada / jogada silenciosa |
| king hunt / mating net | caça ao rei / rede de mate |
| zugzwang / opposition / key squares / rule of the square | zugzwang / oposição / casas-chave / regra do quadrado |
| passed / isolated / doubled / backward pawn | peão passado / isolado / dobrado / atrasado |
| pawn chain / pawn break / breakthrough | cadeia de peões / rutura / rutura decisiva |
| minority attack / pawn storm | ataque de minorias / avalanche de peões |
| open / half-open file | coluna aberta / semiaberta |
| outpost / weak square (hole) | posto avançado / casa fraca (buraco) |
| good / bad bishop / bishop pair / opposite-colored bishops | bispo bom / bispo mau / par de bispos / bispos de cores opostas |
| candidate moves / initiative / counterplay | jogadas candidatas / iniciativa / contrajogo |
| prophylaxis / maneuvering / space | profilaxia / manobra / espaço |
| rook lift / cutting off the king / battery | elevação de torre / corte do rei / bateria |
| fianchetto / gambit | fianqueto / gambito |
| back-rank mate / escape square (luft) | mate da linha de fundo / casa de fuga (respiradouro) |
| smothered mate / Philidor's Legacy | mate sufocado / o Legado de Philidor |
| Greek gift / windmill / rook ladder | oferta grega / moinho / mate em escada |
| Arabian mate / Boden's mate / Anastasia's mate | mate árabe / mate de Boden / mate de Anastasia |
| Légal's mate / Noah's Ark trap / Scholar's mate | mate de Légal / armadilha da Arca de Noé / mate do pastor |
| supported queen mate ("kiss") | mate do beijo |
| Philidor position / Lucena position, building a bridge | posição de Philidor / posição de Lucena, construir a ponte |
| perpetual check / dead position | xeque perpétuo / posição morta |
| blitz / rapid / classical / bullet | blitz / rápidas / clássico / bullet |
| increment / delay / flag fall | incremento / atraso / queda da bandeira |
| arbiter / Swiss / round robin / bye / tie-break | árbitro / sistema suíço / todos-contra-todos / bye / desempate |
| norm / GM / IM / FM / CM | norma / Grande Mestre / Mestre Internacional / Mestre FIDE / Candidato a Mestre |
| rating / touch-move / j'adoube | rating Elo / peça tocada, peça jogada / «componho» |
| fair play / premove | fair play / pré-jogada |
| chaturanga / shatranj / ferz / alfil | chaturanga / shatranj / *ferz* / *alfil* |
| foot soldiers / horses / elephants / chariots (chaturanga's divisions) | infantes / cavalos / elefantes / carros de guerra |
| legal / illegal move | jogada legal / jogada ilegal |
| the Immortal Game / Turochamp | a Partida Imortal / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | posição de Saavedra / o estudo de Réti |
| Buchholz / Sonneborn-Berger | Buchholz / Sonneborn-Berger |

### Where these words were checked, and the calls that were made

The table above was verified against the places Portuguese-speaking players
actually write, preferring European sources: the **lichess pt-PT** puzzle-theme
bundle (`lichess-org/lila`, `translation/dest/puzzleTheme/pt-PT.xml`),
**pt.wikipedia** (the articles *Espetos (xadrez)*, *Fianqueto*, *Roque
(xadrez)*, *Mate do Corredor*, *Glossário de enxadrismo*), **chess.com** and
**chesskid** Portuguese term pages, the **Federação Portuguesa de Xadrez**
translation of the FIDE Laws, and **Ciberdúvidas da Língua Portuguesa** (ISCTE)
for the verb *rocar*. Rulings:

- **espeto** for *skewer*, not lichess's descriptive «cravada inversa».
  pt.wikipedia titles its article *Espetos (xadrez)*, and chess.com and
  chesskid both use *espeto*; «raio X» is the neighbouring idea, not this one.
- **fianqueto**, not the Italian *fianchetto*: pt.wikipedia's article is
  *Fianqueto*, and the verb **fianquetar** is attested with it.
- **rocar** is the dictionary verb — Ciberdúvidas records only this entry and
  gives «rocou» and «rocado». «fazer roque» is also correct; the corpus uses
  *rocar* and says **roque curto / roque longo**, which is what the castling
  lesson contrasts. (Portugal also says *roque pequeno / grande*; both are
  attested, and only one spelling belongs in one corpus.)
- **mate da linha de fundo** is kept over the commoner **mate do corredor**,
  for one corpus-internal reason: *corredor* already means a *running pawn*
  throughout these lessons («ganha a corrida o corredor…»), and the board term
  *linha de fundo* is used 118 times. A reader meeting «mate do corredor» here
  would read it as a mate by a runner.
- **ala do rei / ala da dama** for the two wings (attested beside *flanco*),
  while **flanco** is reserved for *aberturas de flanco*, which is what
  Portuguese calls the English, the Réti and the rest.
- **oferta grega** is kept for the *Greek gift*. chess.com's Portuguese says
  *presente grego*, but that is the Brazilian form of the idiom — Portugal says
  *presente de grego* — and the lesson defines the term on the spot anyway.
- **atração** (lichess pt-PT: *Atração*), **desvio** (*Desvio*), **garfo**
  (*Garfo*), **cravada** (*Cravada*), **interferência**, **jogada intermédia**
  (European; Brazil says *intermediária*), **peça encurralada**, **subpromoção**
  and **afogamento** are all confirmed by those sources and stand unchanged.
- The forbidden words hold: *rainha*, *cavaleiro*, *castelo*, *soldado* and
  *enroque* appear nowhere in any of the sources as the piece or the move.

Opening names follow Portuguese usage: Defesa Siciliana, Defesa Francesa,
Defesa Caro-Kann, Defesa Escandinava, Defesa Petroff, Abertura Italiana
(Giuoco Piano, Dois Cavalos), Abertura Espanhola (Ruy López), Abertura
Escocesa, Abertura Vienense, Gambito de Rei, Gambito de Dama (aceite /
recusado), Defesa Eslava, Defesa Índia do Rei, Índia de Nimzowitsch
(Nimzo-Índia), Índia da Dama, Defesa Holandesa, Sistema Londres, Abertura
Inglesa, Abertura Réti, Ataque Índio do Rei, Defesa Grünfeld, Catalã,
variante Najdorf, Abertura do Centro.

Player names keep their own spelling: Philidor, Morphy, Anderssen,
Kieseritzky, Steinitz, Lasker, Capablanca, Alekhine, Botvinnik, Tal, Fischer,
Spassky, Karpov, Kasparov, Kramnik, Topalov, Anand, Carlsen, Korchnoi,
Chigorin, Nimzowitsch, Judit Polgár, Ruy López de Segura, Lucena, Saavedra,
Réti, Turing, Arpad Elo. China's world champion is Ding Liren, and Gukesh
Dommaraju is Gukesh. Engines keep their names (Stockfish, AlphaZero,
Deep Blue).

## Culture

Portugal met chess through al-Andalus and kept the Arabic word in its own:
**xadrez** comes through *xatrez* from *shatranj*. The traps for a translator
are the everyday words. The piece beside the king is **a dama** — *rainha*
belongs to a real monarch, and to the historical note. **O bispo** is the
bishop, and unlike Italian or French, Portuguese really did take the church
word, so it needs no apology; **o cavalo** is the knight (never *cavaleiro*,
which is the rider), **a torre** the rook (never *castelo*), **o peão** the
pawn (never *soldado*).

- Facts, dates, names and game scores stay exactly as in English.
- The standard Portuguese idiom wins over a literal rendering: «mate da linha
  de fundo», «mate sufocado», «peça tocada, peça jogada».
- Idioms are adapted, not translated word for word («matar dois coelhos de
  uma cajadada só» for two birds with one stone).
- Nothing is added that the English does not say, with exactly two deliberate
  exceptions, both where the Portuguese reader's own words need it. The
  notation lesson notes that Portuguese scoresheets write R, D, T, B, C beside
  the international K, Q, R, B, N. And `history-03`, which lists what every
  other language did to the *alfil* — *alfiere*, *fou*, *Läufer*, *aufin* —
  closes with the sentence that answers the question a Portuguese reader is
  left holding: «O português foi buscar a mesma palavra da igreja, e por isso o
  nosso bispo não precisa de desculpas.» There is no third exception.
- The tone is encouraging and direct, the way a good treinador speaks: a
  mistake is a mistake, said kindly.
