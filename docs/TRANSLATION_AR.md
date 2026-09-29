# Arabic translation guide

The Arabic corpus lives in `assets/data/lessons/ar/` and
`assets/data/puzzles/ar/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Arabic conventions below. A file that is not
translated yet falls back to English in the app.

## Register

- Modern Standard Arabic, clear and warm: a coach speaking to one learner.
- Address the reader in the second person singular (masculine generic, the
  norm of Arabic instructional writing): «العب»، «انظر»، «لديك».
- The sides are «الأبيض» and «الأسود», or «خصمك». Pieces are «هو/هي» by
  grammatical gender of the word, never a person.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make.

## Notation and numbers

- Moves stay in international notation, inside chips: `{{Nf3}}`, `{{O-O}}`.
  Chips must match the English field exactly.
- Squares stay Latin: e4, d5, h7. Files and ranks: «العمود e»، «الصف الثامن».
- Western digits only: 0 1 2 3 … never ٠ ١ ٢ ٣.
- Punctuation: «،» «؛» «؟». Full stop «.». Quotation marks «…».
- Puzzle explanations open with `## الفكرة`.

## Pieces and core terms

| English | Arabic |
|---|---|
| king | الملك |
| queen | الوزير |
| rook | الرخ (plural الرخاخ) |
| bishop | الفيل (plural الفيلة) |
| knight | الحصان (plural الأحصنة) |
| pawn | البيدق (plural البيادق) |
| piece (minor piece) | قطعة (قطعة خفيفة) |
| check / checkmate | كش / كش مات (noun: المات) |
| stalemate | التعادل بالجمود (باط) |
| draw | التعادل |
| castling (short / long) | التبييت (القصير / الطويل) |
| en passant | الأخذ بالتجاوز |
| promotion | الترقية |
| capture | الأسر / يأسر |
| square / file / rank / diagonal | مربع / عمود / صف / قطر |
| center | المركز |
| development | التطوير / تطوير القطع |
| tempo | نقلة (كسب الوقت) |
| exchange (rook for minor) | فارق النوعية |
| sacrifice | التضحية |
| material / blunder / mistake | المادة / خطأ فادح / خطأ |
| hanging (undefended) piece | قطعة معلّقة |
| fork | الشوكة |
| pin / skewer | التثبيت / السيخ |
| discovered attack / check | الهجوم المكشوف / الكش المكشوف |
| double check | الكش المزدوج |
| deflection / decoy / overload | الإبعاد / الاستدراج / الإثقال |
| removing the defender | إزالة المدافع |
| interference | الاعتراض (never «القطع», which reads as "pieces") |
| clearance | الإفساح |
| in-between move (zwischenzug) | النقلة البينية |
| x-ray | الأشعة السينية (الهجوم عبر القطعة) |
| zugzwang | الإرغام (الزوغزوانغ) |
| opposition | المعارضة |
| underpromotion | الترقية الصغرى |
| candidate moves / initiative / counterplay | النقلات المرشّحة / المبادرة / اللعب المضاد |
| pawn chain / minority attack / pawn storm | سلسلة البيادق / هجوم الأقلية / عاصفة البيادق |
| good / bad bishop / bishop pair | فيل جيد / فيل سيئ / زوج الفيلين |
| weak square (hole) / outpost | مربع ضعيف (ثغرة) / نقطة ارتكاز |
| exchange sacrifice | التضحية بفارق النوعية |
| prophylaxis / maneuvering / space | الوقاية / المناورة / المساحة |
| rook lift / cut (rook cuts the king off) | رفع الرخ / العزل |
| Greek gift / windmill / mating net | الهدية اليونانية / الطاحونة / شبكة المات |
| Arabian mate / Noah's Ark trap / Legall's mate | المات العربي / فخ سفينة نوح / مات ليغال |
| perpetual check / dead position | الكش الدائم / الوضعية الميتة |
| blitz / rapid / classical / bullet | خاطف / سريع / كلاسيكي / رصاصي |
| increment / delay / flag | الزيادة / التأخير / العلَم |
| arbiter / Swiss / round robin / bye / tie-break | الحَكَم / النظام السويسري / نظام الدوري / استراحة / كسر التعادل |
| norm / GM / IM / FM / CM | معيار / أستاذ كبير / أستاذ دولي / أستاذ FIDE / أستاذ مرشّح |
| premove / fair play | النقلة المسبقة / اللعب النظيف |
| historical European queen (before the reform) | السيدة (the piece itself is always الوزير) |
| back rank | الصف الأخير |
| back-rank mate / escape square | مات الصف الأخير / مربع الهروب |
| passed / isolated / doubled / backward pawn | بيدق حر / معزول / مزدوج / متأخر |
| outpost / hole | نقطة ارتكاز / ثغرة |
| open / half-open file | عمود مفتوح / نصف مفتوح |
| fianchetto | الفيانكيتو |
| gambit | الغامبيت |
| bishop pair | زوج الفيلين |
| smothered mate | المات المخنوق |
| back-rank mate | مات الصف الأخير |
| opening / middlegame / endgame | الافتتاح / وسط اللعبة / النهاية |
| variation / transposes into | التفريعة / ينتقل إلى (يتحوّل إلى) — never «يتبادل إلى» |
| resign / threefold repetition | الاستسلام (استسلم) / التكرار الثلاثي |

Words that are **not Arabic chess vocabulary** and must never appear:
«تبنين»، «تبنّن» (castling is التبييت، the verb بيّت); «مقامرة» for a gambit (it
means gambling; the term is الغامبيت); «القطع الصغيرة» (minor pieces are القطع
الخفيفة); «مضاعف» for a doubled pawn (مزدوج); «تيمبو» (نقلة، كسب الوقت);
«القلعة»، «الملكة»، «الجندي»، «الجنود».

Sources checked (September 2026): lichess.org community translations
(ar-SA `site`, `learn`, `puzzleTheme`), chess.com/ar terms, and ar.wikipedia
(شطرنج). Where lichess uses a word this guide forbids (قلعة، جنود), the guide
wins: those are colloquial, not the standard terms.

Opening names: الدفاع الصقلي، الدفاع الفرنسي، دفاع كارو-كان، اللعب الإيطالي،
الافتتاح الإسباني (روي لوبيز)، غامبيت الوزير، الدفاع الهندي الملكي، الدفاع
النيمزو-هندي، دفاع غرونفيلد، الافتتاح الكتالوني، الافتتاح الإنجليزي، نظام
لندن، هجوم الهندي الملكي، دفاع نايدورف.

Player names are written in Arabic script by their usual Arabic spelling
(كاسباروف، كاربوف، فيشر، تال، ستاينتس، أندرسن، فيليدور).

## Culture

Facts, dates, names and game scores stay exactly as in English. Tone adapts:

- No romance imagery: the "kiss" mate is «مات الملاصقة» (the queen lands next
  to the king); a love poem is named as a poem, without dwelling on its theme.
- No gambling images: "bet", "gamble" and "jackpot" become risk, venture or
  calculation («مجازفة»، «مخاطرة محسوبة»).
- Religious figures and places in history (a priest, a monastery) are named
  plainly and respectfully, without commentary.
- The Arab and Persian chapter of chess history (الشطرنج، العالية، المنصوبات،
  الصولي، العدلي) uses its established Arabic names.
