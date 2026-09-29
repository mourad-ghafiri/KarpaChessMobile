# Hindi translation guide

The Hindi corpus lives in `assets/data/lessons/hi/` and
`assets/data/puzzles/hi/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart hi` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Hindi conventions below. A file that is not
translated yet falls back to English in the app.

Hindi is the first content language that needed its own UI bundle
(`assets/data/i18n/hi.json`, added with this corpus). Bundle and lessons were
written together and must agree: a lesson calls a piece, a pack or a theme
exactly what the buttons and cards around it call it.

## Register

- Standard written Hindi (मानक हिन्दी), warm and direct: a coach speaking to one
  learner. The reader is **आप**, and instructions take the आप-imperative:
  «खेलें», «गिनें», «देखें», «ढूँढ़ें». Explanations end «… है।» / «… हैं।».
  तू/तुम are never used.
- The sides are **सफ़ेद** and **काला**, or «आपका विरोधी». All six pieces are
  masculine (राजा, वज़ीर, हाथी, ऊँट, घोड़ा, प्यादा), so agreement is uniform;
  a piece is «यह मोहरा», never a person. Hindi «वह» is gender-neutral, so
  nothing in the English *they* needs a gendered guess; people are named.
- Short sentences, one idea per beat, exactly as the English has it. Do not add
  explanations the English does not make. Sanskritized officialese (तत्पश्चात्,
  उपरांत) and Hinglish padding (फिर आप कर सकते हैं वो move) are both wrong: the
  target is the register of Hindi chess commentary.
- Established chess loans are written in Devanagari and are preferred over
  invented calques: कैसलिंग, फ़ोर्क, पिन, ओपनिंग, एंडगेम. Everything that has a
  real Hindi word keeps it: शह, मात, चाल, ख़ाना, विकर्ण.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that the letters K, Q, R, B, N come from the English
  piece names, which is what Indian scoresheets and books print.
- Squares stay as written: e4, d5, h7. «e-फ़ाइल», «आठवीं रैंक»; a diagonal is
  **विकर्ण**, the long diagonal «लंबा विकर्ण», the back rank «आख़िरी रैंक» and
  one's own «अपनी पहली रैंक».
- **Western digits only** (1851, 2800, 3.5) — never ०-९. Counters read
  naturally: «दो प्यादे», «तीन चालें», «एक ख़ाना».
- The full stop is the **danda «।»**, never an ASCII period. A period may appear
  only inside notation or a number (`2...Nc6`, 3.5). `,` `?` `!` `:` `;` are the
  usual Latin marks, with no space before them. Quotations take « » or “ ”,
  never straight quotes.
- Nukta is mandatory where the standard spelling has it: वज़ीर, सफ़ेद, फ़ाइल,
  ख़ाना, ख़ाली, फ़ोर्क, क़िला. The gate rejects वजीर, सफेद, फाइल, खाना (which
  without the nukta is *food*) — so a meal is always भोजन, never खाना, and the
  square keeps the nukta everywhere.
- A Black move quoted on its own is written «…d5», never `...d5`.
- Puzzle explanations open with `## विचार`.

## Pieces and core terms

| English | Hindi |
|---|---|
| king / queen / rook / bishop / knight / pawn | राजा / वज़ीर / हाथी / ऊँट / घोड़ा / प्यादा (never रानी, मंत्री, किश्ती, सिपाही, or an English name in Devanagari) |
| piece / minor piece / heavy piece | मोहरा / हल्का मोहरा / भारी मोहरा |
| square / file / rank / diagonal / board | ख़ाना / फ़ाइल (e-फ़ाइल) / रैंक (आठवीं रैंक) / विकर्ण / बोर्ड (बिसात) |
| light / dark square, light-squared bishop | सफ़ेद ख़ाना / काला ख़ाना, सफ़ेद ख़ानों वाला ऊँट |
| back rank | आख़िरी रैंक |
| center / wing, kingside / queenside | केंद्र / पंख, किंगसाइड / क्वींसाइड |
| check / checkmate / mate / to be mated | शह / शहमात / मात / मात खाना |
| stalemate / draw | गतिरोध (स्टेलमेट) / ड्रॉ |
| castling (short / long) | कैसलिंग (छोटी / लंबी) |
| en passant | एन पासां |
| promotion / to queen / underpromotion | प्रमोशन / वज़ीर बनाना / छोटे मोहरे का प्रमोशन |
| capture / recapture | मारना / वापस मारना |
| move / tempo | चाल / टेम्पो |
| opening / middlegame / endgame | ओपनिंग / मिडलगेम / एंडगेम |
| development / material | विकास / मोहरों का पलड़ा (बढ़त, नुक़सान) |
| exchange (rook for minor) / exchange sacrifice | एक्सचेंज (हाथी बनाम हल्का मोहरा) / एक्सचेंज की क़ुर्बानी |
| sacrifice | क़ुर्बानी, क़ुर्बान करना |
| blunder / mistake / inaccuracy | भारी भूल / ग़लती / चूक |
| hanging / loose piece | खुला पड़ा मोहरा / बिना बचाव वाला मोहरा |
| threat / defender / attacker | ख़तरा / बचाव करने वाला मोहरा / हमलावर |
| fork / double attack / royal fork | फ़ोर्क / दोहरा हमला / शाही फ़ोर्क |
| pin (absolute / relative) / skewer | पिन (पूर्ण / आंशिक) / स्क्यूअर |
| discovered attack / discovered check / double check | खुलता हमला / खुलती शह / दोहरी शह |
| removing the defender | बचाव करने वाले को हटाना |
| deflection / decoy / overload | भटकाव / चारा / बोझ |
| interference / in-between move / x-ray | रुकावट / बीच की चाल / एक्स-रे |
| trapped piece / quiet move | फँसा मोहरा / शांत चाल |
| king hunt / mating net | राजा का शिकार / मात का जाल |
| zugzwang / opposition / key squares / rule of the square | ज़ुगज़्वांग / ऑपोज़िशन / मुख्य ख़ाने / वर्ग का नियम |
| passed / isolated / doubled / backward pawn | मुक्त प्यादा / अकेला प्यादा / दोहरे प्यादे / पिछड़ा प्यादा |
| pawn chain / pawn break / breakthrough | प्यादों की कड़ी / प्यादे का धक्का / सेंध |
| minority attack / pawn storm | अल्पसंख्यक हमला / प्यादों का तूफ़ान |
| open / half-open file | खुली फ़ाइल / आधी खुली फ़ाइल |
| outpost / weak square (hole) | चौकी / कमज़ोर ख़ाना (छेद) |
| good / bad bishop / bishop pair / opposite-colored bishops | अच्छा ऊँट / ख़राब ऊँट / दो ऊँटों की जोड़ी / विपरीत रंग के ऊँट |
| candidate moves / initiative / counterplay | संभावित चालें / पहल / जवाबी खेल |
| prophylaxis / maneuvering / space | रोकथाम / मोहरों की पैंतरेबाज़ी / जगह |
| rook lift / cutting off the king / battery | हाथी को ऊपर उठाना / राजा का रास्ता काटना / बैटरी |
| fianchetto / gambit | फ़ियानकेटो / गैम्बिट |
| back-rank mate / escape square (luft) | आख़िरी रैंक की मात / निकलने का ख़ाना (हवा) |
| smothered mate / Philidor's Legacy | घुटी हुई मात / फ़िलिडोर की विरासत |
| Greek gift / windmill / rook ladder | यूनानी भेंट / चक्की / हाथियों की सीढ़ी |
| Arabian mate / Boden's mate / Anastasia's mate | अरबी मात / बोडेन की मात / अनास्तासिया की मात |
| Légal's mate / Noah's Ark trap / Scholar's mate | लेगाल की मात / नूह की नाव वाला जाल / चार चालों की मात |
| supported queen mate ("kiss") | सटे वज़ीर की मात |
| Philidor position / Lucena position, building a bridge | फ़िलिडोर की पोज़ीशन / लुसेना की पोज़ीशन, पुल बनाना |
| perpetual check / dead position | लगातार शह / मरी हुई पोज़ीशन |
| blitz / rapid / classical / bullet | ब्लिट्ज़ / रैपिड / क्लासिकल / बुलेट |
| increment / delay / flag fall | इंक्रीमेंट / डिले / समय ख़त्म होना |
| arbiter / Swiss / round robin / bye / tie-break | आर्बिटर / स्विस पद्धति / राउंड रॉबिन / बाई / टाई-ब्रेक |
| norm / GM / IM / FM / CM | नॉर्म / ग्रैंडमास्टर / इंटरनेशनल मास्टर / फ़ीडे मास्टर / कैंडिडेट मास्टर |
| rating / touch-move / j'adoube | रेटिंग (एलो) / छुआ सो चला / «ठीक कर रहा हूँ» |
| fair play / premove | निष्पक्ष खेल / प्रीमूव |
| chaturanga / shatranj / ferz / alfil | चतुरंग / शतरंज / फ़र्ज़ीन / अल्फ़ील |
| foot soldiers / horses / elephants / chariots (chaturanga's divisions) | पैदल / घुड़सवार / हाथी / रथ — the four ancient divisions, named as an army, not as pieces |
| legal / illegal move | नियमानुसार चाल / नियमविरुद्ध चाल |
| the Immortal Game / Turochamp | अमर बाज़ी / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | सावेद्रा की पोज़ीशन / रेती की रचना |
| Buchholz / Sonneborn-Berger | बुखहोल्ट्ज़ / सोनेबोर्न-बर्गर |

Opening names follow the UI bundle: सिसिलियन डिफ़ेंस, फ़्रेंच डिफ़ेंस,
कैरो-कान डिफ़ेंस, स्कैंडिनेवियन डिफ़ेंस, पेट्रोफ़ डिफ़ेंस, इटैलियन गेम
(जोको पियानो, टू नाइट्स), रुय लोपेज़, स्कॉच गेम, वियना गेम, किंग्स गैम्बिट,
क्वींस गैम्बिट (डिक्लाइंड / एक्सेप्टेड), स्लाव डिफ़ेंस, किंग्स इंडियन डिफ़ेंस,
निम्ज़ो-इंडियन, क्वींस इंडियन, डच डिफ़ेंस, लंदन सिस्टम, इंग्लिश ओपनिंग,
रेती ओपनिंग, किंग्स इंडियन अटैक, ग्रुनफ़ेल्ड डिफ़ेंस, कैटलन, नायडोर्फ़,
सेंटर गेम।

An opening name is a **proper name** and is transliterated whole, so the banned
English piece words are allowed inside one and nowhere else: किंग्स गैम्बिट,
किंग्स इंडियन, «इटैलियन गेम — टू नाइट्स», क्वींस गैम्बिट. The same goes for
किंगसाइड and क्वींसाइड, which are the board's two sides, not the pieces. The
gate's `_hiAgreed` map encodes exactly these exceptions; a new opening name that
contains a piece word must be checked against it before it is added.

Player names take their established Devanagari spelling: फ़िलिडोर, मॉर्फ़ी,
आंदरसन, कीज़ेरित्ज़्की, स्टाइनिट्ज़, लास्कर, कापाब्लांका, अलेखिन, बोटविनिक,
ताल, फ़िशर, स्पास्की, कार्पोव, कास्परोव, क्राम्निक, टोपालोव, आनंद, कार्लसन,
कोर्चनोई, चिगोरिन, बोगोल्युबोव, निम्ज़ोविच, नायडोर्फ़, ग्रुनफ़ेल्ड,
तार्ताकोवर, यूडिट पोलगार, रुय लोपेज़ दे सेगुरा, लुसेना, सावेद्रा, रेती,
ट्यूरिंग, आर्पद एलो. Indian names take their own spelling: विश्वनाथन आनंद,
गुकेश डोम्माराजू, कोनेरू हम्पी. Ding Liren is डिंग लिरेन. Engines keep their
Latin names (Stockfish, AlphaZero); Deep Blue is «डीप ब्लू».

## Culture

Chess was born in India, and the Hindi reader meets that fact in their own
language: चतुरंग is not a foreign curiosity here but the ancestor of the game,
and शतरंज is the word Hindi still uses for chess itself. So the history lessons
are translated straight, without adding pride the English does not claim and
without flattening the Indian names (चतुरंग, अष्टापद, शह, मात — «शह» and
«मात» are Persian-Hindi words the reader already owns; *shāh māt* needs no
gloss beyond the one the English gives).

- Facts, dates, names and game scores stay exactly as in English.
- Hindi's own chess idiom wins over a literal rendering: «शह», «मात»,
  «छुआ सो चला», «घुटी हुई मात».
- Idioms are adapted, not translated word for word («एक पंथ दो काज» for
  "two birds with one stone").
- India's modern chess is named where the English names it (आनंद, गुकेश,
  हम्पी), and nowhere else.
- The tone is encouraging and plain, the way a good कोच speaks: a mistake is a
  mistake, said kindly.

## Grammar the corpus and the bundle have to obey

Hindi inflects where English does not, and two places in this app punish that.

- **"X is covered by Y" is said with Y as the subject**, not with a genitive
  agent: «X को Y ढके है», «X पर Y की नज़र है». A chain drops the verb, not the
  case marker: «c6 को घोड़ा ढके है, d6 को e5 का प्यादा, e6 को f5 का प्यादा»।
  The shape «X, Y के ढके हुए है» is not Hindi and is a known past defect —
  a genitive cannot govern a participle that way. «ढके हुए है/हैं» on its own
  ("both are covered", "the three squares are covered") is fine.
- **An agreeing word may never sit next to a `{placeholder}` in the UI bundle.**
  `{piece}`, `{target}` and `{side}` are filled from other keys and always
  arrive in the direct case, so a का/की/के, an adjective or a verb beside one
  can only ever be right for one of the fillers. Reword the template so
  nothing agrees with them («चाल: {side}»).
- **A message whose wording changes with a count is a plural map, not a
  template plus a noun.** `{pieceWord}` and `{pawnWord}` are gone: a
  count-bearing key now carries a `one` and an `other` form, and the noun,
  its adjective, the copula and the oblique case all live **inside each
  form**, where they are free to agree —
  «…बिना बचाव वाला मोहरा है» against «…बिना बचाव वाले मोहरे हैं».
  This replaced a workaround in which the agreement was smuggled into a
  separate filler key; never reintroduce one.
- Postpositions take the oblique: प्यादा→प्यादे, घोड़ा→घोड़े before को/से/पर/का.
  राजा, वज़ीर, हाथी and ऊँट do not change, which is why a bad agreement in the
  corpus usually shows up on the pawn and the knight first.
- **घुड़सवार is cavalry, घोड़ा is the piece.** Chaturanga's four divisions are
  पैदल / घुड़सवार / हाथी / रथ — an army, never the modern piece names.
- Three notes address the Hindi reader directly and have no English original:
  the notation lesson's remark that K/Q/R/B/N come from the English names, the
  शह/मात gloss in the shatranj lesson, and the ख़ाना/खाना nukta warning. They are
  deliberate and must survive edits; nothing else may be added to them.
- «अल्पसंख्यक हमला» (minority attack) is the one calque in the glossary that no
  outside source attests. It is kept because the lesson that owns it defines it
  on the board, but it should be the first term revisited if a Hindi chess
  source ever settles on another.

## Sources and rulings

The glossary above was checked against outside Hindi usage rather than against
itself. What each source shows, and what was decided:

- **Hindi Wikipedia, «शतरंज»** names the pieces «राजा», «रानी या मन्त्री»
  (also «वज़ीर»), «हाथी», «ऊँट», «घोड़ा», «सैनिक या प्यादा», and gives «शह»,
  «गतिरोध», «प्रमोशन», «कैसलिंग». Five of our six piece names are its first
  choice; **वज़ीर** is one of the three it lists for the queen. So the set is
  attested, and the only editorial decision in it is preferring वज़ीर to रानी —
  taken for consistency with the शह/मात layer the corpus already uses and with
  the history lessons, and kept. Its «टेढ़ा» for diagonal and «वर्ग» for square were **not**
  adopted: विकर्ण and ख़ाना are what the lessons need, and the same article
  gives «खाना» too.
- **chesshere.com Hindi glossary** lists every piece as a native word beside
  its English loan — «रानी/वज़ीर», «हाथी/रुक», «ऊंट/बिशप», «घोड़ा/नाइट» — and
  defines fork, pin, skewer and zugzwang in plain Hindi. It confirms both the
  native set and the register split: written Hindi leads with the native word.
- **lichess hi-IN `puzzleTheme`** uses «वज़ीर एंडगेम», «ऊँट का एंडगेम»,
  «फँसा हुआ मोहरा», «शांत चाल», «एक्स-रे हमला», «कैसलिंग», «पिन», «किंगसाइड»,
  corroborating वज़ीर, ऊँट, मोहरा and the loan policy. It is weak authority
  elsewhere — it renders fork as «कांटा», deflection as «नीचे को झुकाव» and a
  hanging piece as «लटकता हुआ टुकड़ा» — and its «रूक एंडगेम» / «नाइट एंडगेम»
  are exactly the loans this corpus refuses. Nothing was adopted from it.
- **The register question, answered honestly.** Spoken Indian chess is full of
  किंग, क्वीन, रूक, बिशप, नाइट, and chess.com's Hindi pages use them outright.
  This corpus is written मानक हिन्दी, where every source above leads with the
  native word, so the native set stays. The trade-off is real and is the
  reason the notation lesson explains the Latin letters rather than pretending
  they are Hindi.
- **zugzwang was corrected**, from `ज़ुग्त्स्वांग` to **`ज़ुगज़्वांग`**. No
  source renders the German /ts/ as त्स; the only attested transliteration,
  lichess's «ज़ुग्ज्वांग», puts a ज-sound there. `ज़ुगज़्वांग` keeps that
  consonant and the corpus's mandatory nukta. (It is a judgement, not a
  citation: lichess's exact spelling drops the second nukta.)
- **`_hiAgreed` in `tool/translations.dart` was read and left alone.** Its keys
  are written with the decomposed nukta U+093C, which is what the corpus uses,
  so the gate really is matching — a precomposed key (U+095B) would have made
  it silently pass everything. Anything searched for by hand must be typed the
  same way.
