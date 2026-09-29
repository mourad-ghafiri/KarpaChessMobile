# Russian translation guide

The Russian corpus lives in `assets/data/lessons/ru/` and
`assets/data/puzzles/ru/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart ru` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Russian conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/ru.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Standard literary Russian, clear and warm: a coach speaking to one learner.
  The reader is «вы» (lowercase), as everywhere in the UI («Ваш ход», «Найдите
  лучший ход»). Instructions are imperatives in the вы-form: «Сыграйте»,
  «Возьмите», «Найдите», «Посчитайте».
- The sides are «белые» and «чёрные» (lowercase inside a sentence, as Russian
  chess writing has it), or «соперник». Pieces take the pronoun of their
  grammatical gender (ферзь — он, ладья — она); people are named rather than
  given a pronoun the English does not state.
- Always write ё where the standard spelling has it: чёрные, ещё, лёгкие фигуры.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that the app writes the English letters K, Q, R, B, N,
  while Russian books print Кр, Ф, Л, С, К.
- Squares stay as written: e4, d5, h7. Files and ranks: «вертикаль e»,
  «седьмая горизонталь»; the back rank is «последняя горизонталь» (one's own:
  «первая горизонталь»).
- Numbers: years and ratings without separator (1851, 2800); decimal comma
  (3,5 очка); ordinals in words for ranks («восьмая горизонталь»).
- Typography: «ёлочки» for quotations, „лапки“ inside them if ever needed,
  never straight quotes. Dashes are « — » with spaces. No space before
  punctuation.
- Puzzle explanations open with `## Идея`.

## Pieces and core terms

| English | Russian |
|---|---|
| king / queen / rook / bishop / knight / pawn | король / ферзь / ладья / слон / конь / пешка (never королева, тура, офицер) |
| piece / minor piece / heavy piece | фигура / лёгкая фигура / тяжёлая фигура |
| square / file / rank / diagonal / board | поле / вертикаль / горизонталь / диагональ / доска |
| light / dark square, light-squared bishop | белое / чёрное поле, белопольный слон |
| back rank | последняя горизонталь |
| center / wing, kingside / queenside | центр / фланг, королевский / ферзевый фланг |
| check / checkmate / mate / to be mated | шах / мат / мат / получить мат |
| stalemate / draw | пат / ничья |
| castling (short / long) | рокировка (короткая / длинная) |
| en passant | взятие на проходе |
| promotion / to queen / underpromotion | превращение / провести в ферзи / превращение в слабую фигуру |
| capture / recapture | взятие, взять / взять обратно |
| move / tempo | ход / темп |
| opening / middlegame / endgame | дебют / миттельшпиль / эндшпиль (окончание) |
| development / material | развитие / материал |
| exchange (rook for minor) / exchange sacrifice | качество (выиграть / отдать качество) / жертва качества |
| sacrifice | жертва, пожертвовать |
| blunder / mistake / inaccuracy | зевок / ошибка / неточность |
| hanging / loose piece | висячая фигура / незащищённая фигура |
| threat / defender / attacker | угроза / защитник / атакующая фигура |
| fork / double attack / royal fork | вилка / двойной удар / королевская вилка |
| pin (absolute / relative) / skewer | связка (полная / неполная) / сквозной удар |
| discovered attack / discovered check / double check | вскрытое нападение / вскрытый шах / двойной шах |
| removing the defender | устранение защитника |
| deflection / decoy / overload | отвлечение / завлечение / перегрузка |
| interference / in-between move / x-ray | перекрытие / промежуточный ход / рентген |
| trapped piece / quiet move | пойманная фигура / тихий ход |
| king hunt / mating net | охота на короля / матовая сеть |
| zugzwang / opposition / key squares / rule of the square | цугцванг / оппозиция / ключевые поля / правило квадрата |
| passed / isolated / doubled / backward pawn | проходная / изолированная / сдвоенная / отсталая пешка |
| pawn chain / pawn break / breakthrough | пешечная цепь / подрыв / прорыв |
| minority attack / pawn storm | атака меньшинства / пешечный штурм |
| open / half-open file | открытая / полуоткрытая вертикаль |
| outpost / weak square (hole) | форпост / слабое поле («дыра») |
| good / bad bishop / bishop pair / opposite-colored bishops | хороший / плохой слон / два слона / разноцветные слоны |
| candidate moves / initiative / counterplay | ходы-кандидаты / инициатива / контригра |
| prophylaxis / maneuvering / space | профилактика / маневрирование / пространство |
| rook lift / cutting off the king / battery | подъём ладьи / отрезать короля / батарея |
| fianchetto / gambit | фианкетто / гамбит |
| back-rank mate / escape square (luft) | мат по последней горизонтали / «форточка» |
| smothered mate / Philidor's Legacy | спёртый мат / мат Филидора |
| Greek gift / windmill / rook ladder | «греческий дар» / мельница / линейный мат |
| Arabian mate / Boden's mate / Anastasia's mate | арабский мат / мат Бодена / мат Анастасии |
| Légal's mate / Noah's Ark trap / Scholar's mate | мат Легаля / ловушка «Ноев ковчег» / детский мат |
| supported queen mate ("kiss") | «поцелуй смерти» |
| Philidor position / Lucena position, building a bridge | позиция Филидора / позиция Лусены, построение моста |
| perpetual check / dead position | вечный шах / мёртвая позиция |
| blitz / rapid / classical / bullet | блиц / рапид / классика / пуля |
| increment / delay / flag fall | добавление времени / задержка / падение флажка |
| arbiter / Swiss / round robin / bye / tie-break | арбитр / швейцарская система / круговой турнир / пропуск тура / дополнительные показатели |
| norm / GM / IM / FM / CM | норма / гроссмейстер / международный мастер / мастер ФИДЕ / кандидат в мастера |
| rating / touch-move / j'adoube | рейтинг (Эло) / «тронул — ходи» / «поправляю» |
| fair play / premove | честная игра / премув |
| chaturanga / shatranj / ferz / alfil | чатуранга / шатрандж / ферзь (фарзин) / альфиль |
| legal / illegal move | возможный / невозможный ход (the FIDE Laws' words; never «законный»/«незаконный», which the gate rejects in both the long and the short adjective forms), «по правилам» where English says *legally* |
| long diagonal | большая диагональ or длинная диагональ (both standard; the corpus uses both) |
| Fried Liver Attack | атака Фегателло (never «жареная печень», a calque) |
| blockader | блокирующая фигура, or «блокёр» where the English is terse |
| the Immortal Game / Turochamp | «Бессмертная партия» / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | позиция Сааведры / этюд Рети |
| Buchholz / Sonneborn-Berger / bye | коэффициент Бухгольца / коэффициент Зоннеборна — Бергера / пропуск тура |
| royal fork / supported queen mate | королевская вилка / «поцелуй смерти» |

Opening names follow the UI bundle: Сицилианская защита, Французская защита,
защита Каро-Канн, Скандинавская защита, Русская партия (Petroff),
Итальянская партия (тихая итальянская, защита двух коней), Испанская партия,
Шотландская партия, Венская партия, Королевский гамбит, Ферзевый гамбит
(отказанный / принятый), Славянская защита, Староиндийская защита, защита
Нимцовича, Новоиндийская защита, Голландская защита, Лондонская система,
Английское начало, дебют Рети, Королевско-индийская атака, защита Грюнфельда,
Каталонское начало, вариант Найдорфа, Центральный дебют.

Player names take their established Russian spelling: Филидор, Морфи,
Андерсен, Стейниц, Ласкер, Капабланка, Алехин, Ботвинник, Таль, Фишер, Спасский,
Карпов, Каспаров, Крамник, Топалов, Ананд, Карлсен, Дин Лижэнь, Гукеш, Корчной,
Чигорин, Боголюбов, Нимцович, Найдорф, Грюнфельд, Тартаковер, Юдит Полгар,
Руй Лопес, Лусена, Сааведра, Рети. ФИДЕ is written in Cyrillic; engines keep
their names (Stockfish, AlphaZero), and Deep Blue is «Дип Блю».

## Culture

Russian is the home language of the Soviet chess school, and the Russian reader
knows its names and its words. Where the English names them, the familiar
Russian forms are used (Ботвинник, Спасский, Чигорин; «детский мат», «спёртый
мат», «форточка», «тронул — ходи»). Nothing is added that the English does not
say, with three deliberate exceptions where the Russian reader's own words need
it: the notation lesson notes the Russian piece letters Кр, Ф, Л, С, К that
Russian books print; the story of shatranj notes that Russian kept «шахматы»,
«шах» and «мат» from *shāh māt*; and the story of chess reaching Europe notes
that, where other languages renamed the piece a queen, Russian kept «ферзь».

- Facts, dates, names and game scores stay exactly as in English.
- The standard Russian chess idiom wins over a literal rendering.
- Idioms are adapted, not translated word for word («убить двух зайцев» for
  "two birds with one stone").
- The tone is clear and encouraging, like a good тренер: a mistake is a
  mistake, said kindly.

## Words that read as something else

Russian has three traps this corpus has already fallen into once each. Check
for them before you write.

- **«ничья» is a draw.** It is also the feminine of «ничей», "nobody's", and in
  a chess app the reader sees the draw first. Never write «ничья вертикаль» for
  *nobody's file* — write «без хозяина». (The masculine «ничей» is safe: «ничей
  телохранитель» cannot be misread.)
- **«висячая фигура» is the term; «висит» is the state.** *Loose piece* /
  *hanging piece* as a named thing is «висячая фигура» (worldchess.com/ru), and
  the UI bundle now says so. Describing a piece that happens to be undefended —
  "the piece hanging", "it still hangs" — takes the ordinary verb: «фигура
  висит», «висящая фигура». Never «висящая» where the glossary word is meant.
- **«последняя горизонталь» is relative.** It is the contract's word for *back
  rank* everywhere, including a side's own home rank ("the knights leave the
  back rank"). Every site in the corpus names the concrete squares beside it,
  which is what keeps it unambiguous; keep doing that.

## Where the vocabulary was checked

Every ruling below was verified against a source outside this repo, in
September 2026. Where two Russian words are both standard, both are listed
above rather than one being imposed.

- **FIDE Laws of Chess, official Russian text** (`handbook.fide.com`,
  `LawsOfChess2023Russian.pdf`) — the highest authority for board vocabulary,
  and it settles the one the gate enforces:
  - Art. 3.10.1–3.10.3: «Ход считается возможным, когда все соответствующие
    требования статей 3.1 - 3.9 выполнены. Ход считается **невозможным**, если
    он не отвечает соответствующим требованиям…», and Art. 7.5 speaks of «был
    завершён невозможный ход». The glossary repeats it: «невозможный: 3.10.2. и
    3.10.3. Позиция или ход, который не возможен по правилам игры в шахматы.»
    So **возможный / невозможный ход**, never «законный/незаконный» — the
    contract was right, and the gate now catches the short form «незаконен»
    too, which had slipped through in three lessons.
  - Glossary: «вертикаль: 2.4. Вертикальная колонка из восьми квадратов»,
    «горизонталь: 2.4. Горизонтальный ряд», «диагональ», «королевский фланг»,
    «ферзевый фланг», «лёгкая фигура: Слон или конь», «пат», «мат», «шах»,
    «рокировка», «превращение», «взятие на проходе», «тронул - ходи».
    **«поле»** is the working word for a square throughout (3.1, 3.7.5.1);
    «квадрат»/«клетка» appear only in the board description, so «клетка» is
    reserved here for the metaphor *cage*.
  - FIDE's own word for *increment* is «добавка»; the UI bundle's «Добавление
    времени» is the longer everyday form and stays.
- **Russian Wikipedia, Глоссарий шахматных терминов** — вилка, двойной удар,
  связка, рентген, отвлечение, завлечение, перегрузка, промежуточный ход,
  вскрытый шах, двойной шах, мат спёртый, матовая сеть, форпост, форточка,
  мельница, оппозиция, цугцванг, профилактика, зевок, качество, батарея,
  фианкетто, изолированная / отсталая / сдвоенные пешки, детский мат, мат
  Легаля, and **«Мат линейный — мат на крайних вертикалях (горизонталях),
  который ставится тяжёлыми фигурами»** — which is why *skewer* stays
  **сквозной удар**: lichess's «линейный удар» would collide with the rook
  ladder. Also «Карлсбадская пешечная структура» and «Открытые дебюты».
- **lichess puzzle themes, ru-RU** (`translation/dest/puzzleTheme/ru-RU.xml`) —
  confirms завлечение, отвлечение, перекрытие, промежуточный ход, вскрытое
  нападение, двойной шах, спёртый мат, тихий ход, рентген, цугцванг, вилка,
  and names the Fried Liver **«атака Фегателло»**.
- **worldchess.com/ru** — «висячая фигура» for *hanging piece*.
- **chessrussian.ru, stepchess.ru** — «сквозной удар» («копьё») as the standard
  name for the skewer, defined as the pin with the values reversed.
