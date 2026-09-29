# Japanese translation guide

The Japanese corpus lives in `assets/data/lessons/ja/` and
`assets/data/puzzles/ja/`. Each file is the English file with only its prose
rewritten, by hand. `dart run tool/translations.dart ja` proves that: identical
FENs, solutions, answers and ids, the same `{{chips}}` in every field, the same
headings and blockquotes, and the Japanese conventions below. A file that is not
translated yet falls back to English in the app.

The vocabulary follows the app's own UI bundle (`assets/data/i18n/ja.json`):
a lesson must call a piece, a pack or a theme exactly what the buttons and
cards around it call it.

## Register

- Standard written Japanese (標準語), in ですます調 throughout, clear and warm:
  a coach speaking to one learner. 常体 (「〜だ。」「〜である。」) is rejected by
  the gate. Instructions are 「〜しましょう」「〜してください」 or the plain
  imperative of the UI's own buttons; explanations end 「〜です」「〜ます」.
  The reader is 「あなた」, and mostly left unsaid, as Japanese prefers.
- The sides are 「白」 and 「黒」, or 「相手」. A piece is 「この駒」, never
  彼/彼女 — a piece is not a person. People are named, or 「この棋士」; no
  gendered pronoun is added where the English says *they*.
- Short sentences. Keep the English beat's one idea; do not add explanations
  the English does not make. 体言止め is welcome for a card title or a chip
  label, never for a whole beat.

## Notation, numbers, typography

- Moves stay in international SAN inside chips (`{{Nf3}}`, `{{O-O}}`): the
  board reads them. Chips must match the English field exactly. The notation
  lesson explains once that K, Q, R, B, N come from the English piece names,
  as every Japanese chess book and app writes them.
- Squares stay as written: e4, d5, h7. Files and ranks: 「eファイル」,
  「第8ランク」; a diagonal is 「斜線」, the long diagonal 「ロングダイアゴナル」,
  the back rank 「バックランク」 and one's own last rank 「最奥段」.
- Western digits for years, ratings, counts and scores (1851, 2800, 3.5).
  Small counts read naturally with their counter: 「2枚のポーン」「3手」
  「1マス」.
- Full-width punctuation: 、。：；？！（）「」. Book titles in 『』. Dashes are
  「 ― 」 with spaces, as the UI bundle writes them. No space beside full-width
  punctuation.
- **No space between Japanese and Latin text, digits or chips**: 「{{Nf3}}のあと」
  「e4のポーン」「1851年」. This is the opposite of the Chinese rule, and the
  gate enforces it.
- A Black move quoted on its own takes the full-width ellipsis: 「…d5」, never `...d5`
  (an ASCII dot after a Japanese character is rejected by the gate).
- Puzzle explanations open with `## 狙い`.

## Pieces and core terms

| English | Japanese |
|---|---|
| king / queen / rook / bishop / knight / pawn | キング / クイーン / ルーク / ビショップ / ナイト / ポーン (never 女王、塔、司教、騎士、歩兵, and never a shogi name) |
| piece / minor piece / heavy piece | 駒 / マイナーピース / 重駒 |
| square / file / rank / diagonal / board | マス / ファイル（eファイル）/ ランク（第8ランク）/ 斜線 / 盤 |
| light / dark square, light-squared bishop | 白マス / 黒マス, 白マスビショップ |
| back rank | バックランク（自陣なら最奥段） |
| center / wing, kingside / queenside | 中央 / ウィング, キングサイド / クイーンサイド |
| check / checkmate / mate / to be mated | チェック / チェックメイト / 詰み / 詰まされる |
| stalemate / draw | ステイルメイト / 引き分け |
| castling (short / long) | キャスリング（キングサイド / クイーンサイド） |
| en passant | アンパッサン |
| promotion / to queen / underpromotion | 昇格 / クイーンに昇格 / 弱い駒への昇格 |
| capture / recapture | 取る（名詞は駒取り）/ 取り返す |
| move / tempo | 手 / テンポ |
| opening / middlegame / endgame | オープニング / ミドルゲーム / エンドゲーム |
| development / material | 展開 / 駒の量（駒得・駒損） |
| exchange (rook for minor) / exchange sacrifice | エクスチェンジ（ルークとマイナーピースの差）/ エクスチェンジの犠牲 |
| sacrifice | 犠牲、捨てる |
| blunder / mistake / inaccuracy | 大悪手 / 悪手 / 不正確 |
| hanging / loose piece | 取られる駒 / 守られていない駒 |
| threat / defender / attacker | 脅威 / 守り駒 / 攻め駒 |
| fork / double attack / royal fork | フォーク / ダブルアタック / ロイヤルフォーク |
| pin (absolute / relative) / skewer | ピン（絶対 / 相対）/ スキュア |
| discovered attack / discovered check / double check | ディスカバードアタック / ディスカバードチェック / ダブルチェック |
| removing the defender | 守り駒の排除 |
| deflection / decoy / overload | ディフレクション / デコイ / オーバーロード |
| interference / in-between move / x-ray | 遮断 / 中間手 / X線 |
| trapped piece / quiet move | 捕まった駒 / 静かな手 |
| king hunt / mating net | キングハント / 詰みの網 |
| zugzwang / opposition / key squares / rule of the square | ツークツワンク / オポジション / キーマス / スクエアの法則 |
| passed / isolated / doubled / backward pawn | パスポーン / 孤立ポーン / 二重ポーン / 遅れたポーン |
| pawn chain / pawn break / breakthrough | ポーンチェーン / ポーンブレイク / 突破 |
| minority attack / pawn storm | マイノリティーアタック / ポーンストーム |
| open / half-open file | オープンファイル / セミオープンファイル |
| outpost / weak square (hole) | 前哨地 / 弱いマス（穴） |
| good / bad bishop / bishop pair / opposite-colored bishops | 良いビショップ / 悪いビショップ / 2枚のビショップ / 異色ビショップ |
| candidate moves / initiative / counterplay | 候補手 / 主導権 / 反撃 |
| prophylaxis / maneuvering / space | 予防 / 駒の組み替え / スペース |
| rook lift / cutting off the king / battery | ルークリフト / キングを遮断する / バッテリー |
| fianchetto / gambit | フィアンケット / ギャンビット |
| back-rank mate / escape square (luft) | バックランクメイト / 逃げマス（風穴） |
| smothered mate / Philidor's Legacy | スマザードメイト / フィリドールの遺産 |
| Greek gift / windmill / rook ladder | ギリシャの贈り物 / 風車 / 階段詰み |
| Arabian mate / Boden's mate / Anastasia's mate | アラビアンメイト / ボーデンメイト / アナスタシアメイト |
| Légal's mate / Noah's Ark trap / Scholar's mate | レガールの詰み / ノアの方舟のトラップ / 4手詰め（スカラーズメイト） |
| supported queen mate ("kiss") | 寄り添うクイーンの詰み |
| Philidor position / Lucena position, building a bridge | フィリドールのポジション / ルセナのポジション、橋を架ける |
| perpetual check / dead position | 連続チェック（パーペチュアルチェック）/ 死んだ局面 |
| blitz / rapid / classical / bullet | ブリッツ / ラピッド / クラシカル / バレット |
| increment / delay / flag fall | インクリメント / ディレイ / 時間切れ（フラッグフォール） |
| arbiter / Swiss / round robin / bye / tie-break | アービター / スイス式 / 総当たり / 不戦勝（バイ）/ タイブレーク |
| norm / GM / IM / FM / CM | ノルム / グランドマスター / インターナショナルマスター / FIDEマスター / キャンディデートマスター |
| rating / touch-move / j'adoube | レーティング（イロ）/ 触ったら指す / 「直します」 |
| fair play / premove | フェアプレー / プリムーブ |
| chaturanga / shatranj / ferz / alfil | チャトランガ / シャトランジ / フェルズ / アルフィル |
| foot soldiers / horses / elephants / chariots (chaturanga's divisions) | *歩兵* / 馬 / 象 / 戦車 — the ancient divisions, in italics where 歩兵 would otherwise read as the piece |
| legal / illegal move | 合法手 / 反則手 |
| the Immortal Game / Turochamp | 不死の一局 / *Turochamp* (italic, untranslated) |
| Saavedra position / Réti's study | サアベドラのポジション / レティのスタディ |
| Buchholz / Sonneborn-Berger | ブッフホルツ / ゾンネボルン・ベルガー |

Opening names follow the UI bundle: シシリアン・ディフェンス、フレンチ・ディフェンス、
カロ・カン・ディフェンス、スカンジナビアン・ディフェンス、ペトロフ・ディフェンス、
イタリアン・ゲーム（ジョコ・ピアノ、トゥー・ナイツ）、ルイ・ロペス、スコッチ・ゲーム、
ウィーン・ゲーム、キングズ・ギャンビット、クイーンズ・ギャンビット（ディクライン／
アクセプテッド）、スラヴ・ディフェンス、キングズ・インディアン・ディフェンス、
ニムゾ・インディアン、クイーンズ・インディアン、ダッチ・ディフェンス、
ロンドン・システム、イングリッシュ・オープニング、レティ・オープニング、
キングズ・インディアン・アタック、グリュンフェルト・ディフェンス、カタラン、
ナイドルフ系、センター・ゲーム.

Player names take their established Japanese katakana: フィリドール、モーフィ、
アンデルセン、キーゼリツキー、シュタイニッツ、ラスカー、カパブランカ、
アリョーヒン、ボトヴィニク、タル、フィッシャー、スパスキー、カルポフ、
カスパロフ、クラムニク、トパロフ、アナンド、カールセン、コルチノイ、
チゴリン、ボゴリュボフ、ニムゾビッチ、ナイドルフ、グリュンフェルト、
タルタコワー、ジュディット・ポルガー、ルイ・ロペス・デ・セグラ、ルセナ、
サアベドラ、レティ、チューリング、アルパド・イロ。China's world champion
keeps the reading Japanese readers know: 丁立人（ディン・リレン）; Gukesh
Dommaraju is グケシ・ドンマラジュ. Engines keep their names (Stockfish,
AlphaZero), and Deep Blue is 「ディープ・ブルー」.

## Culture

Japanese readers know chess's sister game: 将棋 has a 王, a 桂馬 and 歩, its
king is also mated (詰み), and its own words would mislead here. So the shogi
names are avoided entirely — the pieces are katakana, as every Japanese chess
book writes them, and the gate rejects 飛車・角行・桂馬・香車・歩兵・王将.
Nothing is added that the English does not say, with one deliberate exception
where the Japanese reader's own words need it: the notation lesson notes that
Japanese scoresheets and apps write the English letters K, Q, R, B, N.

- Facts, dates, names and game scores stay exactly as in English.
- The standard Japanese chess idiom wins over a literal rendering:
  「スマザードメイト」「バックランクメイト」「触ったら指す」.
- Idioms are adapted, not translated word for word (「一石二鳥」 for "two birds
  with one stone").
- The tone is encouraging and direct, the way a good コーチ speaks: a mistake
  is a mistake, said kindly.

## Where the vocabulary was checked

The table above is not a matter of taste; every term in it was checked against
published Japanese chess usage. The sources, and what each settled:

- **Japanese Wikipedia** — the article 「[ディスカバードアタック](https://ja.wikipedia.org/wiki/ディスカバードアタック)」
  exists under that exact title and opens: 「ディスカバードアタックはチェスの用語で、
  駒を動かして背後にある駒（クイーン、ルーク、ビショップ）で駒取りをかける手筋である。
  特に、背後の駒でチェックをかける場合は、ディスカバードチェックという。」 The same
  article names the shogi equivalents only to set them aside — 「ディスカバードチェックは
  将棋で言えば空き王手に相当し、ダブルチェックは両王手に当たる」 — so 空き王手 and
  両王手 are shogi words and must not appear here.
  The glossary 「[チェス用語一覧](https://ja.wikipedia.org/wiki/チェス用語一覧)」 confirms
  フォーク, ピン, ツークツワンク, パスポーン, アンパッサン, ステイルメイト,
  スマザード・メイト, フィアンケット, ギャンビット, ファイル, ランク, キングサイド,
  クイーンサイド; and 「[チェス](https://ja.wikipedia.org/wiki/チェス)」 confirms the six
  piece names in katakana plus チェック / チェックメイト / ステイルメイト / キャスリング /
  アンパッサン and マス for square.
- **lichess, `translation/dest/puzzleTheme/ja-JP.xml`** — the shipped Japanese puzzle
  themes. They give 「ディフレクション（そらし）」 for deflection, 「ツークツワンク」,
  「静かな手」 for quiet move, 「Ｘ線攻撃」, 「スキュアー（串刺し）」,
  「フォーク（両取り）」, 「バックランク・メイト」, 「スマザード・メイト」 and
  「守り駒の除去」.
- **chess.com Japanese lessons** — the lesson at `/lessons/winning-with-tactics/deflection`
  is titled 「ディフレクション」, and `/lessons/theme/decoy-deflection` pairs it with
  「デコイ」. This, with lichess, is what settled the katakana for *deflection*.

### Rulings the sources overturned (September 2026 proofread)

- **discovered attack / discovered check** were written 発見攻撃 / 発見チェック.
  These are calques; no Japanese chess source uses them. Corrected to
  **ディスカバードアタック / ディスカバードチェック** at 15 sites in the corpus and
  2 keys in the UI bundle.
- **deflection** was written デフレクション. The katakana for English /dɪ/ is ディ,
  and both lichess and chess.com write **ディフレクション**; デフレクション also
  collides with デフレ (deflation). Corrected at 5 sites plus 1 bundle key.

Both corrections are now enforced by `_jaAgreed` in `tool/translations.dart`, so
they cannot come back.

**Shogi vocabulary was checked and none had leaked in**: 王手, 飛車, 角行, 桂馬,
香車, 王将, 玉将, 両取り, 成る all appear zero times as chess terms. The only hits
for 馬 / 象 / 戦車 / 歩兵 are in `history-01-born-in-india`, where the English itself
says *chariot*, *horse*, *elephant* and *foot soldiers* — the chaturanga divisions,
which the table above sanctions. One slip was found and fixed: `history-02-shatranj`
called the **knight on e4** 馬 while calling the rook beside it ルーク, although the
English says "knight". A piece the learner moves is always ナイト.
