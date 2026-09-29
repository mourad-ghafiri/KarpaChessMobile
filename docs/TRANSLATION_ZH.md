# Chinese translation guide

The Chinese corpus lives in `assets/data/lessons/zh/` and
`assets/data/puzzles/zh/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart zh` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Chinese conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/zh.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Simplified Chinese (简体中文), standard Mandarin as written on the mainland,
  clear and warm: a coach speaking to one learner. The reader is «你», as
  everywhere in the UI («找出着法», «轮到你了»). Instructions are short
  imperatives: «走…», «吃掉…», «找出…», «数一数…».
- The sides are «白方» and «黑方», or «对手». A piece is «它», never 他/她 — a
  piece is not a person. People are named, or «这位棋手»; no gendered pronoun
  is added where English says *they*.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make. Four-character idioms are welcome where they are
  the natural phrase («一箭双雕»), never as decoration.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that the letters K, Q, R, B, N come from the English
  piece names, as every Chinese scoresheet and app writes them.
- Squares stay as written: e4, d5, h7. Files and ranks: «e 线», «第 8 横线»;
  a diagonal is «斜线», the long diagonal «大斜线», the back rank «底线».
- Western digits for ranks, years, ratings and scores (1851, 2800, 第 7 横线).
  Small counts in running prose are words («两枚子», «三步»), as Chinese writes
  them.
- Full-width punctuation: ，。：；？！、（）. Quotations in 「」, titles of books in
  《》. Dashes are «——». No space beside full-width punctuation.
- One half-width space between Chinese and any Latin text, digit or chip:
  «走 {{Nf3}} 之后», «e4 上的兵», «1851 年». Bold and italics follow the same rule.
- Puzzle explanations open with `## 思路`.

## Pieces and core terms

| English | Chinese |
|---|---|
| king / queen / rook / bishop / knight / pawn | 王 / 后 / 车 / 象 / 马 / 兵 (never 皇后、城堡、主教、骑士、卒) |
| piece / minor piece / heavy piece | 子（棋子）/ 轻子 / 重子 |
| square / file / rank / diagonal / board | 格 / 直线（e 线）/ 横线（第 8 横线）/ 斜线 / 棋盘 |
| light / dark square, light-squared bishop | 白格 / 黑格, 白格象 |
| back rank | 底线 |
| center / wing, kingside / queenside | 中心 / 翼, 王翼 / 后翼 |
| check / checkmate / mate / to be mated | 将军 / 将杀 / 杀 / 被将杀 |
| stalemate / draw | 逼和 / 和棋 |
| castling (short / long) | 王车易位（短易位 / 长易位） |
| en passant | 吃过路兵 |
| promotion / to queen / underpromotion | 升变 / 升变为后 / 低升变 |
| capture / recapture | 吃子、吃掉 / 回吃 |
| move / tempo | 着法、一步棋 / 先手（一步棋的时间） |
| opening / middlegame / endgame | 开局 / 中局 / 残局 |
| development / material | 出子 / 子力 |
| exchange (rook for minor) / exchange sacrifice | 交换优势（以车换轻子；win / give up the exchange: 获得 / 放弃交换优势）/ 弃车换轻子 |
| sacrifice | 弃子 |
| blunder / mistake / inaccuracy | 严重失误 / 错着 / 不准确 |
| hanging / loose piece | 悬子 / 无防守子 |
| threat / defender / attacker | 威胁 / 防守子 / 进攻子 |
| fork / double attack / royal fork | 叉击（lichess 与 chess.com 写作「捉双」；两者都通行，语料统一用「叉击」）/ 双重攻击 / 皇家叉击 |
| pin (absolute / relative) / skewer | 牵制（绝对 / 相对）/ 串击 |
| discovered attack / discovered check / double check | 闪击 / 闪将 / 双将 |
| removing the defender | 消除防守 |
| deflection / decoy / overload | 引离 / 引入 / 超负荷 |
| interference / in-between move / x-ray | 拦截 / 中间着 / X 光攻击 |
| trapped piece / quiet move | 困子 / 静着 |
| king hunt / mating net | 猎王 / 杀网 |
| zugzwang / opposition / key squares / rule of the square | 迫移（zugzwang 用斜体时照写）/ 对王 / 关键格 / 方框规则 |
| passed / isolated / doubled / backward pawn | 通路兵 / 孤兵 / 叠兵 / 落后兵 |
| pawn chain / pawn break / breakthrough | 兵链 / 兵的突破 / 突破 |
| minority attack / pawn storm | 少数派进攻 / 兵暴 |
| open / half-open file | 开放线 / 半开放线 |
| outpost / weak square (hole) | 前哨 / 弱格（空洞） |
| good / bad bishop / bishop pair / opposite-colored bishops | 好象 / 坏象 / 双象 / 异色格象 |
| candidate moves / initiative / counterplay | 候选着法 / 主动权 / 反击 |
| prophylaxis / maneuvering / space | 预防 / 调动 / 空间 |
| rook lift / cutting off the king / battery | 车的抬升 / 隔断王 / 炮台 |
| fianchetto / gambit | 侧翼象 / 弃兵 |
| back-rank mate / escape square (luft) | 底线杀 / 出路格 |
| smothered mate / Philidor's Legacy | 闷杀 / 菲利道尔闷杀 |
| Greek gift / windmill / rook ladder | 希腊礼物 / 风车 / 梯子杀 |
| Arabian mate / Boden's mate / Anastasia's mate | 阿拉伯杀 / 博登杀 / 阿纳斯塔西娅杀 |
| Légal's mate / Noah's Ark trap / Scholar's mate | 莱加尔杀 / 诺亚方舟陷阱 / 四步杀 |
| supported queen mate ("kiss") | 贴身杀 |
| Philidor position / Lucena position, building a bridge | 菲利道尔局面 / 卢塞纳局面, 搭桥 |
| perpetual check / dead position | 长将 / 死局面 |
| blitz / rapid / classical / bullet | 超快棋 / 快棋 / 慢棋 / 子弹棋 |
| increment / delay / flag fall | 加秒 / 延时 / 超时（落旗） |
| arbiter / Swiss / round robin / bye / tie-break | 裁判 / 瑞士制 / 循环赛 / 轮空 / 破同分 |
| norm / GM / IM / FM / CM | 称号成绩 / 特级大师 / 国际大师 / 国际棋联大师 / 候补大师 |
| rating / touch-move / j'adoube | 等级分 / 摸子走子 / 「我摆正」 |
| fair play / premove | 公平竞赛 / 预走 |
| chaturanga / shatranj / ferz / alfil / shāh māt | 恰图兰卡 / 沙特兰兹 / 弗尔兹 / 阿尔菲尔 / 沙阿·马特 (the original word in italics beside it) |
| al-Adli / as-Suli / mansubat / Lewis chessmen | 阿德利 / 苏利 / *mansubat* / 刘易斯棋子 |
| the Immortal Game / Réti's study / Saavedra position / Carlsbad structure | 不朽之局 / 雷蒂的习题 / 萨维德拉局面 / 卡尔斯巴德结构 |
| Buchholz / Sonneborn-Berger / World Cup / crosstable | 布赫霍尔茨分 / 索内伯恩-贝格尔分 / 世界杯 / 交叉表 |
| women's titles WCM, WFM, WIM, WGM | kept as the Latin abbreviations |

Opening names follow the UI bundle: 西西里防御、法兰西防御、卡罗-卡恩防御、
斯堪的纳维亚防御、彼得罗夫防御、意大利开局（缓手变例、双马防御）、西班牙开局、
苏格兰开局、维也纳开局、王翼弃兵、后翼弃兵（拒绝 / 接受）、斯拉夫防御、
王翼印度防御、尼姆佐-印度防御、后翼印度防御、荷兰防御、伦敦体系、英国式开局、
雷蒂开局、王翼印度攻击、格林菲尔德防御、卡塔兰开局、纳道夫变例、中心开局。

Player names take their established Chinese forms: 菲利道尔、莫菲、安德森、
斯坦尼茨、拉斯克、卡帕布兰卡、阿廖欣、鲍特维尼克、塔尔、费舍尔、斯帕斯基、
卡尔波夫、卡斯帕罗夫、克拉姆尼克、托帕洛夫、阿南德、卡尔森、科尔奇诺伊、
奇戈林、鲍戈柳博夫、塔尔塔科维尔、尼姆佐维奇、纳道夫、格林菲尔德、
尤迪特·波尔加、鲁伊·洛佩斯·德·塞古拉、卢塞纳、萨尔维奥、萨维德拉、雷蒂、
安德森、基塞里茨基、图灵、阿帕德·埃洛. China's own world champion keeps the
name Chinese readers know: 丁立人; Gukesh Dommaraju is 古凯什·多马拉朱. A name the reader will not recognize in
Chinese keeps the Chinese transliteration; engines keep their names
(Stockfish, AlphaZero), and Deep Blue is «深蓝».

## Culture

Chinese readers know chess's sister game: 象棋 (xiangqi) also has a 车, a 马
and a 兵, and its general is also mated. Nothing is added that the English does
not say, with three deliberate exceptions where the Chinese reader's own words
need it: the story of chaturanga notes that 兵、马、象、车 still name the army's
divisions; the knight lesson notes that its L-shape is the 「日」字 familiar from
xiangqi; and the notation lesson notes that Chinese scoresheets and apps write
the English letters K, Q, R, B, N. The xiangqi words that would mislead are
avoided: the pawn is 兵, never 卒; the queen is 后, never 皇后 or 王后; «将军» is
check, as both games say it.

- Facts, dates, names and game scores stay exactly as in English.
- The standard Chinese chess idiom wins over a literal rendering: «闷杀»,
  «底线杀», «摸子走子», «四步杀».
- Idioms are adapted, not translated word for word («一箭双雕» for "two birds
  with one stone").
- The tone is encouraging and direct: a mistake is a mistake, said kindly —
  the way a good 教练 says it.

## Where the vocabulary was checked (September 2026)

This document is not the authority; the sources below are. Every ruling names
the evidence it rests on.

- **zugzwang = 迫移** (this file used to say 窒息 — corrected). Chinese
  Wikipedia's article is titled 迫移, and opens: 「**迫移局面**（德语：
  **Zugzwang**……常用译名包括：**楚茨文格**、**强制被动**、**逼走劣著**、
  **无等著**等）为一个国际象棋术语」. The word 窒息 appears nowhere in it.
  窒息 means *asphyxiation*, and in a Chinese chess context reads as 闷 —
  colliding with 闷杀, the smothered mate. All 7 corpus uses were changed, and
  `_zhAgreed` in `tool/translations.dart` now bans it so it cannot come back.
  Source: zh.wikipedia.org, 迫移.
- **fork = 叉击** (kept). lichess's Simplified-Chinese puzzle themes
  (`translation/dest/puzzleTheme/zh-CN.xml`) and chess.com's Chinese glossary
  both write 捉双; zh.wikipedia's 国际象棋战术 lists both 捉双 and 叉击. Both are
  genuine 国际象棋 (not xiangqi) terms; the corpus is internally consistent on
  叉击 across 60 sites, so it stays.
- **pin 牵制 · skewer 串击 · deflection 引离 · decoy 引入 · interference 拦截 ·
  discovered attack 闪击 · double check 双将 · smothered mate 闷杀 ·
  hanging 悬子 · quiet move 静着 · underpromotion 低升变 · castling 王车易位**:
  each matches lichess's zh-CN puzzle-theme file exactly. Confirmed.
- **checkmate = 将杀** (kept; 将死 stays banned). zh.wikipedia's 国际象棋 article
  uses 将死; lichess zh-CN uses 将杀 (`mate`→将杀, `arabianMate`→阿拉伯将杀,
  `backRankMate`→底线杀王). Both are current. The corpus and the UI are
  uniformly 将杀, so the ban stays.
- **inaccuracy = 不准确** (this file used to say 欠准确 — corrected to match the
  UI). `i18n/zh.json` wrote 不准确 in `review.badge.inaccuracy` and
  `review.tally.inaccurate` and 欠准确 only in `review.verdict.inaccuracy`;
  the odd one out was changed.
- **No xiangqi vocabulary has leaked in.** Every corpus occurrence of 相 (118),
  炮 (8) and 士 (3) was opened and read: they are 相邻/相同/互相 …, 炮台 (battery)
  and 炮火 (figurative "under fire"), and 士兵/瑞士制. 主教 appears once, inside an
  *italic* gloss in history-03 explaining the literal sense of English *bishop*,
  which is legitimate.
- **格 / 方格**: FIDE's Chinese rules and zh.wikipedia both use 方格/棋格. The
  corpus uses 格子 as a free-standing noun and 格 as a bound morpheme (白格、
  黑格、空格、关键格). Both are natural modern Chinese and the division of
  labour is consistent, so neither was changed.
