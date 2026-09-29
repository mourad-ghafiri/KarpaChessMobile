# Turkish translation guide

The Turkish corpus lives in `assets/data/lessons/tr/` and
`assets/data/puzzles/tr/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart tr` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Turkish conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/tr.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Standard written Turkish (ölçünlü Türkçe), warm and direct: a coach talking
  to one learner. The reader is **siz** — instructions are the plural
  imperative («bakın», «oynayın», «sayın»), and `sen/senin/sana/seni` are
  rejected by the gate. The possessive follows: «şahınız», «atınız»,
  «rakibiniz».
- The sides are **beyaz** and **siyah**, lowercase, or **rakibiniz**. A piece
  is «bu taş», never *o adam*; people are named or called «bu oyuncu». Turkish
  has no gendered pronoun, so nothing is added where the English says *they*.
- Short sentences, one idea per beat, exactly as the English has it. Turkish
  can chain clauses forever with `-ip`, `-erek`, `-diği için`; resist it. Keep
  the verb where the sentence ends and let the next sentence start.
- Do not explain more than the English does. A lesson that says «şah çekmeyin»
  does not get a new clause about why.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them, and a chip must match the English field exactly. Note that
  the TSF translation of the FIDE Laws assigns **Turkish** letters (Ş V K F A),
  so the notation lesson may not claim that Turkish books use K, Q, R, B, N —
  it says the app follows the international letters, which Turkish players also
  read. Castling is written with the letter **O** (`O-O`), never with zeros.
- Squares stay as written: e4, d5, h7. Files and ranks are **dikey** and
  **yatay** («e dikeyi», «8. yatay»); a diagonal is **çapraz**, the long
  diagonal **uzun çapraz**, the back rank **son yatay**.
- **A suffix on notation takes an apostrophe**: e4'te, g8'e, f7'yi,
  {{Nf3}}'ten sonra, h dikeyi'nde is wrong — write «h dikeyinde». The suffix
  follows how the square is *said*: e4'te (dört), d5'e (beş), a1'de (bir),
  c6'ya (altı), g8'i (sekiz), h7'ye (yedi), b2'ye (iki), f3'ü (üç). The gate
  rejects a square or chip glued to a letter without the apostrophe.
- The apostrophe is the straight `'`. The curly `’` is rejected, so the corpus
  has one spelling to search for.
- Western digits for years, ratings, counts and scores (1851, 2800). A decimal
  is a comma, as Turkish writes it: 3,5–2,5. Ordinals take a period: «3.
  hamlede», «8. yatay».
- Quotation marks are “ ” (never straight `"`). A thought or a said phrase:
  «Buna “iki hamlelik mat” denir.»
- No space before `, . : ; ? !`.
- Puzzle explanations open with `## Fikir`.

## Pieces and core terms

| English | Turkish |
|---|---|
| king / queen / rook / bishop / knight / pawn | şah / vezir / kale / fil / at / piyon (never kral, kraliçe, kule, piskopos, şövalye, piyade) |
| piece / minor piece / heavy piece | taş / hafif taş / ağır taş |
| square / file / rank / diagonal / board | kare / dikey / yatay / çapraz / tahta (satranç tahtası) |
| light / dark square, light-squared bishop | açık kare / koyu kare, açık kare fili |
| back rank | **arka yatay** (the mate: arka yatay matı) — *son yatay* is the LAST rank, where a pawn promotes |
| center / wing, kingside / queenside | merkez / kanat, şah kanadı / vezir kanadı |
| check / to give check / checkmate / to be mated | şah / şah çekmek / mat / mat olmak |
| stalemate / draw | pat / beraberlik |
| castling (short / long) | rok (kısa rok / uzun rok) |
| en passant | geçerken alma |
| promotion / to queen / underpromotion | terfi / vezire terfi / küçük terfi |
| capture / recapture | almak (taş alma) / geri almak |
| move / tempo | hamle / tempo |
| opening / middlegame / endgame | açılış / orta oyun / oyun sonu |
| development / material | gelişim / taş dengesi (taş kazanmak, taş kaybetmek) |
| exchange (rook for minor) / exchange sacrifice | kalite (kale ile hafif taş farkı) / kalite fedası |
| sacrifice | feda (feda etmek) |
| blunder / mistake / inaccuracy | vahim hata / hata / yanlışlık |
| hanging / loose piece | askıda taş / korumasız taş |
| threat / defender / attacker | tehdit / koruyan taş / saldıran taş |
| fork / double attack / royal fork | çatal / çifte tehdit / şah çatalı |
| pin (absolute / relative) / skewer | **açmaz** (mutlak / göreceli) / şiş — never *bağlama* |
| discovered attack / discovered check / double check | açılan saldırı / açılan şah / çifte şah |
| removing the defender | koruyanı uzaklaştırma |
| deflection / decoy / overload | saptırma / **cezbetme** / aşırı yüklenme |
| interference / in-between move / x-ray | araya girme / ara hamle / röntgen |
| trapped piece / quiet move | kapana kısılmış taş / sessiz hamle |
| king hunt / mating net | şah avı / mat ağı |
| zugzwang / opposition / key squares / rule of the square | zugzwang / **opozisyon** (one p) / anahtar kareler / kare kuralı |
| passed / isolated / doubled / backward pawn | geçer piyon / izole piyon / ikili piyon / geri piyon |
| pawn chain / pawn break / breakthrough | piyon zinciri / piyon kırılması / yarma |
| minority attack / pawn storm | azınlık saldırısı / piyon fırtınası |
| open / half-open file | açık dikey / yarı açık dikey |
| outpost / weak square (hole) | ileri karakol / zayıf kare (delik) |
| good / bad bishop / bishop pair / opposite-colored bishops | iyi fil / kötü fil / fil ikilisi / zıt renk filler |
| candidate moves / initiative / counterplay | aday hamleler / inisiyatif / karşı oyun |
| prophylaxis / maneuvering / space | profilaksi / manevra / alan |
| rook lift / cutting off the king / battery | kale kaldırma / şahı kesmek / batarya |
| fianchetto / gambit | fianketto / gambit |
| back-rank mate / escape square (luft) | son yatay matı / kaçış karesi (hava deliği) |
| smothered mate / Philidor's Legacy | **boğmaca matı** / Philidor'un Mirası |
| Greek gift / windmill / rook ladder | Yunan hediyesi / yel değirmeni / merdiven matı |
| Arabian mate / Boden's mate / Anastasia's mate | Arap matı / Boden matı / Anastasia matı |
| Légal's mate / Noah's Ark trap / Scholar's mate | Légal matı / Nuh'un Gemisi tuzağı / çoban matı |
| supported queen mate ("kiss") | desteklenen vezir matı |
| Philidor position / Lucena position, building a bridge | Philidor pozisyonu / Lucena pozisyonu, köprü kurmak |
| perpetual check / dead position | **sürekli şah** / ölü pozisyon |
| blitz / rapid / classical / bullet | yıldırım / hızlı / klasik / bullet |
| increment / delay / flag fall | eklemeli süre (increment) / gecikmeli süre / süre bitimi |
| arbiter / Swiss / round robin / bye / tie-break | hakem / İsviçre sistemi / lig usulü / bay / averaj (tie-break) |
| norm / GM / IM / FM / CM | norm / büyükusta / uluslararası usta / FIDE ustası / aday usta |
| rating / touch-move / j'adoube | puan (Elo) / dokunulan taş oynanır / «düzeltiyorum» |
| fair play / premove | dürüst oyun / ön hamle |
| chaturanga / shatranj / ferz / alfil | çaturanga / şatranç (eski oyun) / *ferz* / *alfil* |
| foot soldiers / horses / elephants / chariots (chaturanga's divisions) | *piyade* / at / fil / savaş arabası — the ancient divisions, in italics where *piyade* would otherwise read as the piece |
| legal / illegal move | kurallı hamle / kuraldışı hamle |
| the Immortal Game / Turochamp | Ölümsüz Parti / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | Saavedra pozisyonu / Réti'nin etüdü |
| Buchholz / Sonneborn-Berger | Buchholz / Sonneborn-Berger |

Opening names follow the UI bundle: Sicilya Savunması, Fransız Savunması,
Caro-Kann Savunması, İskandinav Savunması, Petrov Savunması, İtalyan Oyunu
(Giuoco Piano, İki At), İspanyol Oyunu (Ruy Lopez), İskoç Oyunu, Viyana Oyunu,
Şah Gambiti, Vezir Gambiti (kabul / ret), Slav Savunması, Kral Hint Savunması
— written **Şah Hint Savunması** here, because the piece is şah — Nimzo-Hint,
Vezir Hint, Hollanda Savunması, Londra Sistemi, İngiliz Açılışı, Réti Açılışı,
Şah Hint Saldırısı, Grünfeld Savunması, Katalan, Najdorf Varyantı, Merkez
Oyunu.

Player names keep their own spelling and take a Turkish suffix with an
apostrophe: Philidor'un, Morphy'nin, Anderssen'in, Steinitz'in, Lasker'in,
Capablanca'nın, Aljehin'in, Botvinnik'in, Tal'in, Fischer'in, Spassky'nin,
Karpov'un, Kasparov'un, Kramnik'in, Topalov'un, Anand'ın, Carlsen'in,
Korçnoy'un, Çigorin'in, Nimzovich'in, Judit Polgar'ın, Réti'nin, Lucena'nın,
Saavedra'nın, Turing'in, Arpad Elo'nun. China's world champion is Ding Liren,
Gukesh Dommaraju is Gukesh. Engines keep their names (Stockfish, AlphaZero),
and Deep Blue stays Deep Blue.

## Culture

Turkish has its own long chess history and its own settled words, and the trap
is the everyday ones: **kral** is a real king, never the piece — the piece is
**şah**, which is also the word for check, exactly as a Turkish player says it
(«şah çektim», «şah mat»). **Kale** is the rook (a castle), **fil** the bishop
(an elephant), **at** the knight, **piyon** the pawn. *Piyade*, the infantry,
belongs to chaturanga's four divisions and is written in italics there.

- Facts, dates, names and game scores stay exactly as in English.
- The standard Turkish idiom wins over a literal rendering: «boğma mat»,
  «son yatay matı», «dokunulan taş oynanır».
- Idioms are adapted, not translated word for word («bir taşla iki kuş» for
  two birds with one stone).
- Nothing is added that the English does not say, with one deliberate
  exception where the Turkish reader's own words need it: the notation lesson
  notes that Turkish scoresheets and apps write the English letters K, Q, R,
  B, N, and the history lesson notes that the word *satranç* comes through
  Arabic *şatranc* from Sanskrit *chaturanga*.
- The tone is encouraging and direct, the way a good antrenör speaks: a
  mistake is a mistake, said kindly.

## Sources, and what they overturned

`docs/TRANSLATION_TR.md` is checked against published Turkish chess writing,
not against itself. The sources consulted, in the order they were trusted:

1. **Türkiye Satranç Federasyonu — FIDE Satranç Kuralları** (TSF's own Turkish
   translation of the FIDE Laws of Chess, 2023 and 2017 editions:
   `konya.tsf.org.tr/images/fide-satranc-kurallari_-son-hali.pdf`,
   `fenerweb.com/.../fide_satranc_kurallari_01.18.pdf`).
2. **Turkish Wikipedia** — *Satranç*, *Açmaz (satranç)*, *Şiş (satranç)*,
   *Çatal (satranç)*, *Saptırma (satranç)*, *Boğmaca matı*, *Sürekli şah*,
   *Pat*, *Rok*, *Zugzwang*, *Çoban matı*, *Büyükusta (satranç)*.
3. **lichess** Turkish puzzle themes
   (`lichess-org/lila` → `translation/dest/puzzleTheme/tr-TR.xml`).
4. chess.com/tr, satrancokulu.com, satrancistanbul.com.tr,
   gokyaysatrancvakfi.org.tr.

Confirmed as written here:

- **dikey / yatay / çapraz / kare** for file / rank / diagonal / square. The
  Laws define them: «Sekiz dik karenin oluşturduğu sütunlara 'dikey'ler … denir»
  (Madde 2.4). Turkish Wikipedia's general article says *sütun*/*satır*; the
  federation's wording wins.
- **şah / vezir / kale / fil / at / piyon**, and *şah* for check as well.
- **rok**, **geçerken alma**, **terfi**, **pat**, **kalite / kalite fedası**,
  **geçer piyon**, **izole piyon**, **zugzwang** (German, untranslated),
  **çatal**, **şiş**, **saptırma**, **aşırı yükleme**, **yel değirmeni**,
  **Yunan hediyesi**, **çoban matı**, **büyükusta / uluslararası usta /
  FIDE ustası / aday usta**, **İsviçre sistemi**, **yıldırım / hızlı**.

Overturned — the table above was wrong and has been corrected:

- **pin is «açmaz», not «bağlama».** Turkish Wikipedia carries a dedicated
  article *Açmaz (satranç)*; lichess's Turkish names the theme «Açmaz»;
  chess.com/tr, satrancokulu.com and the satrancistanbul.com.tr glossary
  («Açmaz (Pin): bir taşın, arkasındaki daha değerli taşı koruduğu için hareket
  edemediği durum») all agree. No source uses *bağlama* for the tactic. The verb
  is **açmaza almak**, the state **açmazda**, the piece **açmazdaki taş**; the
  two kinds are **mutlak açmaz** and **göreceli açmaz**. Note that *bağlamak*
  stays the ordinary verb (to tie, to depend on, to commit) and is still used
  that way in the corpus — it is only the tactic that changed.
- **decoy is «cezbetme», not «kandırma».** *Kandırmak* is to deceive somebody,
  not to lure a piece; lichess's Turkish uses «Cezbetme» for the theme.
- **opposition is spelled «opozisyon», with one p.**
- **smothered mate is «boğmaca matı».** Turkish Wikipedia titles the article
  *Boğmaca matı* and chess.com/tr, satrancokulu.com and lichess agree.
- **perpetual check is «sürekli şah»** (Turkish Wikipedia's article title).
- **back rank is «arka yatay»**, which is also how satrancokulu.com titles its
  lesson *Arka Yatay Matı*; «son yatay» is kept for the *last* rank, the one a
  pawn promotes on, so the two senses stay apart.

Considered and deliberately left alone:

- **kısa rok / uzun rok.** Turkish Wikipedia's *Rok* article heads its sections
  «Küçük Rok» / «Büyük Rok», but the Laws themselves only say «rok», and both
  pairs are in live use. Not changed.
- **fianketto**, **ileri karakol** (outpost), **azınlık saldırısı**, **ikili
  piyon**: each has a competing form in one source only. Too thin to move a
  whole corpus on.
