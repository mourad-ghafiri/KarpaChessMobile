import 'dart:convert';
import 'dart:io';

import 'src/corpus.dart';
import 'src/findings.dart';

/// The translation gate: every translated lesson and puzzle must be the
/// English file with only its prose rewritten.
///
///   dart run tool/translations.dart [lang]      (default: every language)
///
/// It never translates anything. It proves that a hand translation changed
/// nothing a reader plays against, and that the prose keeps the conventions of
/// its language:
///
/// - Same keys, same step types and order; every non-prose value (FEN,
///   solution, targetSan, rating, id, proof) identical to English.
/// - The same `{{chips}}` in every prose field, as a multiset. A chip drives
///   the board (BoardScript arrows, tap previews), so a dropped or added chip
///   changes behavior, not just wording.
/// - The same number of headings and blockquotes, and a non-empty value
///   wherever English has one.
/// - Arabic: Western digits only (0–9), Arabic punctuation (، ؛ ؟), the
///   agreed piece names (الوزير، الرخ، البيدق — never الملكة، القلعة، الجندي),
///   and no Latin words outside chips and square names.
/// - Indonesian: the piece and board names the app's UI bundle already uses
///   (menteri, benteng, pion, petak, lajur, sekak — never ratu, bidak,
///   kotak, jalur, skak),
///   `## Ide` wherever English opens with `## The Idea`, and no English
///   words left behind in the prose.
/// - French: the piece and tactic names of the app's UI bundle (dame, fou,
///   fourchette, clouage — never reine, évêque, fourche, épingle), `## L'idée`
///   wherever English opens with `## The Idea`, French typography (a
///   non-breaking space before `: ; ! ?` and inside `« »`, never straight
///   double quotes), and no English words left behind in the prose.
/// - Spanish: the piece and tactic names of the app's UI bundle (dama, caballo,
///   horquilla — never reina, caballero, tenedor), `## La idea` wherever
///   English opens with `## The Idea`, opening marks for every `?` and `!`
///   (¿…? ¡…!), angular quotes, and no English words left in the prose.
/// - Chinese: Simplified characters, the piece and tactic names of the app's
///   UI bundle (后、车、象、马、兵 — never 皇后、城堡、主教、骑士、卒),
///   `## 思路` wherever English opens with `## The Idea`, full-width
///   punctuation (，。：；？！「」（）) with no space beside it, one space
///   between Chinese and Latin text or digits, and no Latin words outside
///   chips, squares, notation and a short list of names.
/// - Russian: the piece and tactic names of the app's UI bundle (ферзь, ладья,
///   слон — never королева, тура, офицер), `## Идея` wherever English opens
///   with `## The Idea`, «ёлочки» never straight quotes, «чёрные» always with
///   ё, no word mixing Cyrillic and Latin letters, and no Latin words outside
///   chips, squares, notation and a short list of names.
///
/// Missing translations are reported as a count, not as errors: a partly
/// translated corpus loads, file by file, with English as the fallback.
void main(List<String> args) {
  final corpus = Corpus();
  final langs = args.isEmpty ? Corpus.translatedLanguages : args.toSet();
  final findings = <Finding>[];
  for (final lang in langs) {
    findings.addAll(_area(corpus, lang, 'lessons', _lessonProse));
    findings.addAll(_area(corpus, lang, 'puzzles', _puzzleProse));
  }
  exit(report(findings, 'checked translations (${langs.join(', ')})'));
}

const _lessonProse = {'title', 'summary', 'text', 'prompt', 'hint'};
const _puzzleProse = {'title', 'setup', 'hint', 'explanation'};

Iterable<Finding> _area(
  Corpus corpus,
  String lang,
  String area,
  Set<String> prose,
) sync* {
  final enDir = Directory('${corpus.root}/$area/en');
  final trDir = Directory('${corpus.root}/$area/$lang');
  if (!trDir.existsSync()) {
    yield Finding.flag('$area/$lang', 'directory missing');
    return;
  }
  final english = {
    for (final f in enDir.listSync().whereType<File>())
      if (f.path.endsWith('.json')) _name(f): f,
  }..remove('index.json');
  var translated = 0;
  for (final f in trDir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final name = _name(f);
    final where = '$area/$lang/$name';
    final en = english[name];
    if (en == null) {
      yield Finding.error(where, 'no English original with this name');
      continue;
    }
    translated++;
    final Object? a;
    final Object? b;
    try {
      a = json.decode(en.readAsStringSync());
      b = json.decode(f.readAsStringSync());
    } on Object catch (e) {
      yield Finding.error(where, 'not readable JSON: $e');
      continue;
    }
    yield* _compare(where, a, b, prose, lang, '');
  }
  final missing = english.length - translated;
  if (missing > 0) {
    yield Finding.flag(
        '$area/$lang', '$translated of ${english.length} translated, $missing still English');
  }
}

Iterable<Finding> _compare(
  String where,
  Object? en,
  Object? tr,
  Set<String> prose,
  String lang,
  String path,
) sync* {
  if (en is Map) {
    if (tr is! Map) {
      yield Finding.error(where, '$path: expected an object');
      return;
    }
    final ek = en.keys.toSet();
    final tk = tr.keys.toSet();
    for (final k in ek.difference(tk)) {
      yield Finding.error(where, '$path.$k: missing in translation');
    }
    for (final k in tk.difference(ek)) {
      yield Finding.error(where, '$path.$k: not in the English original');
    }
    for (final k in ek.intersection(tk)) {
      final key = k as String;
      final sub = '$path.$key';
      if (prose.contains(key) && en[key] is String) {
        yield* _prose(where, sub, en[key] as String, tr[key], lang);
      } else {
        yield* _compare(where, en[key], tr[key], prose, lang, sub);
      }
    }
  } else if (en is List) {
    if (tr is! List || tr.length != en.length) {
      yield Finding.error(where, '$path: list differs from English');
      return;
    }
    for (var i = 0; i < en.length; i++) {
      yield* _compare(where, en[i], tr[i], prose, lang, '$path[$i]');
    }
  } else if (en != tr) {
    yield Finding.error(where, '$path: "$tr" differs from English "$en"');
  }
}

final _chip = RegExp(r'\{\{([^}]+)\}\}');
final _square = RegExp(r'^[a-h][1-8]$');
final _san = RegExp(
    r'^(O-O(-O)?|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](=[QRBN])?|[a-h](x[a-h])?[1-8]?(=[QRBN])?)[+#]?$');

Iterable<Finding> _prose(
  String where,
  String path,
  String en,
  Object? tr,
  String lang,
) sync* {
  if (tr is! String) {
    yield Finding.error(where, '$path: expected text');
    return;
  }
  if (en.trim().isNotEmpty && tr.trim().isEmpty) {
    yield Finding.error(where, '$path: empty translation');
    return;
  }
  final enChips = [for (final m in _chip.allMatches(en)) m.group(1)!]..sort();
  final trChips = [for (final m in _chip.allMatches(tr)) m.group(1)!]..sort();
  if (enChips.join(' ') != trChips.join(' ')) {
    yield Finding.error(where,
        '$path: chips differ — English ${enChips.join(' ')} | translation ${trChips.join(' ')}');
  }
  int count(String s, RegExp r) => r.allMatches(s).length;
  final heading = RegExp(r'^#{1,6} ', multiLine: true);
  final quote = RegExp(r'^> ', multiLine: true);
  if (count(en, heading) != count(tr, heading)) {
    yield Finding.error(where, '$path: heading count differs from English');
  }
  if (count(en, quote) != count(tr, quote)) {
    yield Finding.error(where, '$path: blockquote count differs from English');
  }
  if (tr.contains('`') != en.contains('`')) {
    yield Finding.error(where, '$path: backticks differ from English');
  }
  if (lang == 'ar') yield* _arabic(where, path, tr);
  if (lang == 'id') yield* _indonesian(where, path, en, tr);
  if (lang == 'fr') yield* _french(where, path, en, tr);
  if (lang == 'es') yield* _spanish(where, path, en, tr);
  if (lang == 'zh') yield* _chinese(where, path, en, tr);
  if (lang == 'ru') yield* _russian(where, path, en, tr);
  if (lang == 'ja') yield* _japanese(where, path, en, tr);
  if (lang == 'hi') yield* _hindi(where, path, en, tr);
  if (lang == 'tr') yield* _turkish(where, path, en, tr);
  if (lang == 'it') yield* _italian(where, path, en, tr);
  if (lang == 'pt') yield* _portuguese(where, path, en, tr);
}

/// Italian shares the Latin alphabet with English, so the gate reads the words:
/// the agreed piece names, the accents, «caporali» and the elision apostrophe.
Iterable<Finding> _italian(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith("## L'idea\n")) {
    yield Finding.error(where, '$path: explanation must open with "## L\'idea"');
  }
  // A chip is a word of the sentence, so it keeps its boundary here.
  final notation = text
      .replaceAll(_chip, '\u0001')
      .replaceAll(RegExp(r'`[^`]*`'), '\u0001');
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « »');
  }
  if (notation.contains('\u2019')) {
    yield Finding.error(where,
        "$path: curly apostrophe — the corpus writes l'alfiere with a straight one");
  }
  // «...d5» keeps its space; nothing else does.
  if (RegExp(r' [,:;?!]| \.(?!\.)').hasMatch(notation)) {
    yield Finding.error(where, '$path: no space before , . : ; ? !');
  }
  if (RegExp(r"(^|[^a-zA-ZÀ-ÿ])e'").hasMatch(notation)) {
    yield Finding.error(where, "$path: \"e'\" — the accented form is è");
  }
  // A single-asterisk *italic* marks a historical or foreign term (*regina*).
  final prose = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  final words = [
    for (final m in RegExp(r"[A-Za-zÀ-ÿ]+(?:'[a-zà-ÿ]+)?").allMatches(prose))
      if (!_notationNames.contains(m.group(0))) m.group(0)!,
  ];
  for (final word in words) {
    final w = word.toLowerCase();
    final stem = w.contains("'") ? w.split("'").last : w;
    for (final e in _itAgreed.entries) {
      if (stem.startsWith(e.key)) {
        yield Finding.error(where, '$path: "$word" — the agreed word is ${e.value}');
      }
    }
    if (_itBareLatin.contains(w)) {
      yield Finding.error(where, '$path: "$word" — Italian writes it with its accent');
    }
    if (!_itFalseFriends.contains(w) && _englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$word" left in the prose');
    }
  }
}

/// Stems whose whole family is wrong, as the Italian chess federation and the
/// `it` UI bundle name the pieces. Matched at the start of a word, because
/// Italian inflects on the same stem (regina/regine, vescovo/vescovi).
const _itAgreed = <String, String>{
  'regin': 'donna',
  'vescov': 'alfiere',
  'cavalier': 'cavallo',
  'castell': 'torre',
  'soldat': 'pedone',
  'pedin': 'pedone',
};

/// Italian written without its accents — the mistake a reader notices first.
const _itBareLatin = <String>{
  'perche', 'piu', 'puo', 'cosi', 'gia', 'cioe', 'poiche', 'finche', 'benche',
  'citta', 'verita', 'liberta', 'difficolta', 'possibilita', 'realta',
  'qualita', 'percio', 'affinche', 'restera', 'necessita',
};

/// English words that are also Italian: *in* and *idea* are spelled the same.
const _itFalseFriends = {'in', 'idea'};

/// European Portuguese shares the Latin alphabet with English, so the gate
/// reads the words: the agreed piece names, the accents, «aspas angulares»,
/// the «tu» register and the Brazilian forms Portugal does not use.
Iterable<Finding> _portuguese(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## A Ideia\n')) {
    yield Finding.error(where, '$path: explanation must open with "## A Ideia"');
  }
  // A chip is a word of the sentence, so it keeps its boundary here.
  final notation = text
      .replaceAll(_chip, '\u0001')
      .replaceAll(RegExp(r'`[^`]*`'), '\u0001');
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « »');
  }
  if (notation.contains('\u2019')) {
    yield Finding.error(where,
        '$path: curly apostrophe — the corpus writes the straight one');
  }
  // «...d5» keeps its space; nothing else does.
  if (RegExp(r' [,:;?!]| \.(?!\.)').hasMatch(notation)) {
    yield Finding.error(where, '$path: no space before , . : ; ? !');
  }
  // Portugal says «estar a jogar», never «estar jogando».
  if (_ptGerund.hasMatch(notation.toLowerCase())) {
    yield Finding.error(where,
        '$path: Brazilian gerund — Portugal writes "estar a" + infinitive');
  }
  // A single-asterisk *italic* marks a historical or foreign term (*alfil*).
  final prose = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  final words = [
    for (final m in RegExp(r'[A-Za-zÀ-ÿ]+').allMatches(prose))
      if (!_notationNames.contains(m.group(0))) m.group(0)!,
  ];
  for (final word in words) {
    final w = word.toLowerCase();
    for (final e in _ptAgreed.entries) {
      if (w.startsWith(e.key)) {
        yield Finding.error(where, '$path: "$word" — the agreed word is ${e.value}');
      }
    }
    final pt = _ptBrazilian[w];
    if (pt != null) {
      yield Finding.error(where,
          '$path: "$word" is Brazilian — European Portuguese writes "$pt"');
    }
    if (_ptBareLatin.contains(w)) {
      yield Finding.error(
          where, '$path: "$word" — Portuguese writes it with its accent');
    }
    if (!_ptFalseFriends.contains(w) && _englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$word" left in the prose');
    }
  }
}

/// «estar a fazer» is the European construction, and «estar fazendo» is the
/// single loudest Brazilian marker in running prose. `ir` + gerund («vai
/// tirando») is idiomatic in Portugal, so it is deliberately not matched.
final _ptGerund = RegExp(
    r'\b(est(ou|ás|á|amos|ão|ava|avas|avam|ar|ará)|continua|continuam)'
    r'\s+[a-zà-ÿ]{3,}ndo\b');

/// Stems whose whole family is wrong, as the Federação Portuguesa de Xadrez
/// and the `pt` UI bundle name the pieces. Matched at the start of a word,
/// because Portuguese inflects on the same stem (rainha/rainhas). «quadrado»
/// is deliberately absent: it is the endgame term, «a regra do quadrado».
const _ptAgreed = <String, String>{
  'rainh': 'dama',
  'cavaleir': 'cavalo',
  'castelo': 'torre',
  'soldad': 'peão',
  'enroqu': 'roque',
  'alfil': 'bispo',
  'casill': 'casa',
  'peon': 'peão',
};

/// Brazilian spellings and words European Portuguese does not use.
const _ptBrazilian = <String, String>{
  'você': 'tu',
  'voce': 'tu',
  'vocês': 'tu',
  'voces': 'tu',
  'pra': 'para',
  'fato': 'facto',
  'fatos': 'factos',
  'contato': 'contacto',
  'contatos': 'contactos',
  'registro': 'registo',
  'registros': 'registos',
  'esporte': 'desporto',
  'esportes': 'desporto',
  'usuário': 'utilizador',
  'usuario': 'utilizador',
  'planejar': 'planear',
  'planeja': 'planeia',
  'planejamento': 'planeamento',
  'gerenciar': 'gerir',
  'gerencia': 'gere',
  'bilhão': 'mil milhões',
  'bilhões': 'mil milhões',
  'econômico': 'económico',
  'econômica': 'económica',
  'eletrônico': 'eletrónico',
  'eletrônica': 'eletrónica',
  'fenômeno': 'fenómeno',
  'anônimo': 'anónimo',
  'sinônimo': 'sinónimo',
  'polêmica': 'polémica',
  'gênero': 'género',
  'gênio': 'génio',
  'acadêmico': 'académico',
  'acadêmica': 'académica',
  'tênis': 'ténis',
};

/// Portuguese written without its accents — the mistake a reader notices
/// first. Only words with no unaccented homograph are listed.
const _ptBareLatin = <String>{
  'nao', 'sao', 'estao', 'entao', 'tambem', 'alem', 'atras', 'ja', 'so',
  'tres', 'apos', 'proximo', 'ultimo', 'unico', 'possivel', 'dificil',
  'facil', 'rapido', 'logica', 'basico', 'publico', 'varios', 'sequencia',
  'consequencia', 'frequencia', 'ninguem', 'alguem', 'porem', 'atraves',
  'peao', 'peoes', 'area', 'tatica', 'taticas', 'estrategia', 'historia',
  'memoria', 'materia', 'criterio', 'minimo', 'maximo', 'otimo', 'tecnica',
  'tecnico', 'especifico', 'automatico', 'ingles', 'frances', 'japones',
  'chines', 'portugues', 'alemao', 'arabe', 'serie', 'numero', 'xadres',
};

/// English words that are also Portuguese: «mate» is the second half of
/// xeque-mate, and the word regex splits on the hyphen; «for» is the future
/// subjunctive of ser («se a casa for escura»).
const _ptFalseFriends = {'mate', 'for'};

/// Turkish is written in the Latin alphabet, so the gate reads the words
/// themselves: the agreed piece names, the diacritics, the «siz» register and
/// the apostrophe Turkish puts between notation and a suffix (e4'te).
Iterable<Finding> _turkish(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## Fikir\n')) {
    yield Finding.error(where, '$path: explanation must open with "## Fikir"');
  }
  // A chip is a word of the sentence, so it keeps its boundary here.
  final notation = text
      .replaceAll(_chip, '\u0001')
      .replaceAll(RegExp(r'`[^`]*`'), '\u0001');
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use “ ”');
  }
  if (notation.contains('’')) {
    yield Finding.error(where,
        '$path: curly apostrophe — the corpus writes e4\'te with a straight one');
  }
  // «...d5» is how a lone Black move is written, so an ellipsis keeps its space.
  if (RegExp(r' [,:;?!]| \.(?!\.)').hasMatch(notation)) {
    yield Finding.error(where, '$path: no space before , . : ; ? !');
  }
  // Turkish glues its suffixes to notation with an apostrophe: e4'te, g8'e,
  // {{Nf3}}'ten. Without it the square is read as part of the word.
  final glued =
      RegExp('([a-h][1-8]|\u0001)([a-z$_trLower])').firstMatch(notation);
  if (glued != null) {
    yield Finding.error(where,
        '$path: "${glued.group(0)}" — a suffix on notation needs an apostrophe (e4\'te)');
  }
  // A single-asterisk *italic* marks a historical or foreign term (*piyade*,
  // a real king) that the agreed-name rule must not catch.
  final prose = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  // A suffix hangs off notation and names by an apostrophe (e4'te, Morphy'nin);
  // it is not a word of its own and must not be read as one.
  final plain = prose.replaceAll(RegExp("'[a-z\u0131$_trLower]+"), ' ');
  final words = [
    for (final m in RegExp('[A-Za-zÀ-ÿ$_trUpper$_trLower]+').allMatches(plain))
      if (!_notationNames.contains(m.group(0))) m.group(0)!,
  ];
  for (final word in words) {
    // «Kral Alfonso» is a person; the piece is always şah.
    final capitalized = RegExp('^[A-ZÀ-Þ$_trUpper]').hasMatch(word);
    final w = _trLowerCase(word);
    for (final e in _trAgreed.entries) {
      if (!w.startsWith(e.key)) continue;
      // Only the bare title: «Kral Alfonso» is a person, «Kralın» is the piece.
      if (capitalized && w == e.key && _trTitles.contains(e.key)) continue;
      yield Finding.error(where, '$path: "$word" — the agreed word is ${e.value}');
    }
    if (_trBareLatin.contains(w)) {
      yield Finding.error(where, '$path: "$word" — Turkish spells it with its diacritics');
    }
    if (_trYou.contains(w)) {
      yield Finding.error(where, '$path: "$word" — the reader is «siz»');
    }
    if (!_trFalseFriends.contains(w) && _englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$word" left in the prose');
    }
  }
}

const _trLower = 'çğıöşü';
const _trUpper = 'ÇĞİÖŞÜ';

/// `toLowerCase` on a dotted capital İ leaves a combining dot behind, which no
/// stem in the tables below carries.
String _trLowerCase(String w) =>
    w.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Stems whose whole suffix family is wrong, as Turkish chess writing and the
/// `tr` UI bundle name the pieces. Matched at the start of a word, because
/// Turkish builds «kralın», «kuleye», «piyadeler» on the same stem.
const _trAgreed = <String, String>{
  'kral': 'şah',
  'kraliçe': 'vezir',
  'kule': 'kale',
  'piskopos': 'fil',
  'papaz': 'fil',
  'şövalye': 'at',
  'beygir': 'at',
  'piyade': 'piyon',
};

/// Stems a capital letter excuses: a real monarch keeps the title «Kral».
const _trTitles = {'kral'};

/// Turkish written without its diacritics — the one mistake a Turkish reader
/// notices before the chess.
const _trBareLatin = <String>{
  'sah', 'sahi', 'sahin', 'cift', 'cifte', 'capraz', 'carpraz', 'kose',
  'kucuk', 'buyuk', 'guclu', 'icin', 'cunku', 'degil', 'simdi', 'oyle',
  'sira', 'siralar', 'tas', 'tasi', 'hucum', 'uc', 'dort', 'bes', 'alti',
  'oldugu', 'dusun', 'dusunun', 'gec', 'gecer', 'oteki', 'onemli', 'zayif',
  'acik', 'acilis', 'savas', 'yatayi', 'sahina', 'sahini',
};

/// The reader is «siz» everywhere, as in the UI bundle's own buttons.
const _trYou = <String>{'sen', 'senin', 'sana', 'seni', 'sende', 'senden'};

/// English words that are also Turkish: *on* (ten), *not* (a note),
/// *can* (life), *at* is the knight itself.
const _trFalseFriends = {'on', 'not', 'can', 'at'};

Iterable<Finding> _hindi(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## विचार\n')) {
    yield Finding.error(where, '$path: explanation must open with "## विचार"');
  }
  const hi = r'ऀ-ॿ';
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (!RegExp('[$hi]').hasMatch(notation)) {
    yield Finding.error(where, '$path: no Hindi text');
  }
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « » or “ ”');
  }
  if (RegExp('[०-९]').hasMatch(notation)) {
    yield Finding.error(where, '$path: Devanagari digits — use 1851, 2800, 3.5');
  }
  // The sentence ends on a danda. A period belongs to notation or a number.
  if (RegExp('[$hi]\\.').hasMatch(notation)) {
    yield Finding.error(where, '$path: sentence ends with "." — the full stop is "।"');
  }
  if (RegExp(r' [,:;?!।]').hasMatch(text.replaceAll(_chip, 'X'))) {
    yield Finding.error(where, '$path: no space before , : ; ? ! ।');
  }
  // A single-asterisk *italic* marks a foreign or historical term (a real
  // queen, a chaturanga division) that the piece-name rule must not catch.
  final prose = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  for (final e in _hiAgreed.entries) {
    // Word-initial only: «पुरानी» is not «रानी», «दिखाने» is not «ख़ाने».
    if (RegExp('(?<![$hi])${e.key}').hasMatch(prose)) {
      yield Finding.error(where, '$path: "${e.key}" — the agreed word is ${e.value}');
    }
  }
  // The reader is आप, as everywhere in the UI bundle.
  final you = RegExp(r'(^|[\s(«“])(तुम|तू|तुम्हार[ेाी]|तुम्हें|तेर[ेाी])([\s,।?!)»”]|$)')
      .firstMatch(prose);
  if (you != null) {
    yield Finding.error(where,
        '$path: "${you.group(2)}" — the reader is आप');
  }
  for (final m
      in RegExp(r'[A-Za-z][A-Za-z\-\.]*[A-Za-z0-9=+#]*').allMatches(prose)) {
    final w = m.group(0)!.replaceAll(RegExp(r'[.\-]+$'), '');
    if (_square.hasMatch(w) ||
        _san.hasMatch(w) ||
        _allowedLatin.contains(w) ||
        _zhLatin.contains(w)) {
      continue;
    }
    yield Finding.error(where, '$path: Latin word "$w" outside a chip');
  }
}

/// Words the Hindi UI bundle (`i18n/hi.json`) settled differently, plus the
/// nukta-less spellings and English piece names Hindi chess writing avoids.
/// Keys are regular expressions.
const _hiAgreed = <String, String>{
  'रानी': 'वज़ीर',
  'मंत्री': 'वज़ीर',
  'किश्ती': 'हाथी',
  'सिपाही': 'प्यादा',
  'बिशप': 'ऊँट',
  'नाइट': 'घोड़ा',
  'पॉन': 'प्यादा',
  'क्वीन(?!साइड|स)': 'वज़ीर',
  'किंग(?!साइड|स|्)': 'राजा', // किंगसाइड, किंग्स इंडियन are opening names
  'रूक': 'हाथी',
  'चेक(?!र्स)': 'शह (मात के लिए शहमात)', // चेकर्स is the game Checkers
  'वजीर': 'वज़ीर',
  'सफेद': 'सफ़ेद',
  'फाइल': 'फ़ाइल',
  'खान[ाेों]': 'ख़ाना',
  'खाली': 'ख़ाली',
  'शह-मात': 'शहमात',
  'स्टेलमेट': 'गतिरोध',
};

Iterable<Finding> _japanese(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## 狙い\n')) {
    yield Finding.error(where, '$path: explanation must open with "## 狙い"');
  }
  // Kana and kanji. A chip reads as one Latin token (`spaced`) or as a
  // word-shaped hole (`notation`), depending on what is being checked.
  const ja = r'぀-ゟ゠-ヿ一-鿿';
  final spaced = text.replaceAll(_chip, 'X').replaceAll(RegExp(r'`[^`]*`'), 'X');
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (!RegExp('[$ja]').hasMatch(notation)) {
    yield Finding.error(where, '$path: no Japanese text');
  }
  if (RegExp(r'[,;:?!()"]').hasMatch(notation) ||
      RegExp('[$ja]\\.').hasMatch(notation)) {
    yield Finding.error(where,
        '$path: half-width punctuation — use 、。：；？！（）「」');
  }
  if (RegExp('[０-９Ａ-Ｚａ-ｚ]').hasMatch(notation)) {
    yield Finding.error(where, '$path: full-width digits or letters');
  }
  // Japanese sets Latin text solid: 「{{Nf3}}のあと」, 「cファイル」, 「1851年」.
  if (RegExp('[$ja] [A-Za-z0-9]|[A-Za-z0-9] [$ja]').hasMatch(spaced)) {
    yield Finding.error(where,
        '$path: no space between Japanese and Latin text or digits');
  }
  if (RegExp(r' [、。：；？！」）』]|[「（『、。：；？！] ').hasMatch(spaced)) {
    yield Finding.error(where, '$path: no space beside full-width punctuation');
  }
  // A single-asterisk *italic* marks a foreign or historical term.
  final plain = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  for (final e in _jaAgreed.entries) {
    if (plain.contains(e.key)) {
      yield Finding.error(where, '$path: "${e.key}" — the agreed word is ${e.value}');
    }
  }
  // The UI speaks to the reader in ですます; a lesson must not slip into 常体.
  for (final m in RegExp(r'(だ|である)(。|！|$)', multiLine: true).allMatches(plain)) {
    yield Finding.error(where,
        '$path: plain form "${m.group(0)}" — the register is ですます');
  }
  for (final m
      in RegExp(r'[A-Za-z][A-Za-z\-\.]*[A-Za-z0-9=+#]*').allMatches(plain)) {
    final w = m.group(0)!.replaceAll(RegExp(r'[.\-]+$'), '');
    if (_square.hasMatch(w) ||
        _san.hasMatch(w) ||
        _allowedLatin.contains(w) ||
        _zhLatin.contains(w)) {
      continue;
    }
    yield Finding.error(where, '$path: Latin word "$w" outside a chip');
  }
}

/// Words the Japanese UI bundle (`i18n/ja.json`) settled differently, plus the
/// shogi words that would mislead a chess reader.
const _jaAgreed = <String, String>{
  '女王': 'クイーン',
  '僧侶': 'ビショップ',
  '司教': 'ビショップ',
  '騎士': 'ナイト',
  '塔': 'ルーク',
  '歩兵': 'ポーン',
  '王将': 'キング',
  '玉将': 'キング',
  '飛車': 'ルーク',
  '角行': 'ビショップ',
  '桂馬': 'ナイト',
  '香車': 'ルーク',
  'チェックメート': 'チェックメイト',
  'ステールメイト': 'ステイルメイト',
  // Calques no Japanese chess source uses. ja.wikipedia titles its article
  // 「ディスカバードアタック」; chess.com JA and lichess ja-JP both write
  // 「ディフレクション（そらし）」.
  '発見攻撃': 'ディスカバードアタック',
  '発見チェック': 'ディスカバードチェック',
  'デフレクション': 'ディフレクション',
  'スキューア': 'スキュア',
  '串刺し': 'スキュア',
  '両取り': 'フォーク',
  'パスドポーン': 'パスポーン',
  'アンパサン': 'アンパッサン',
  'アン・パッサン': 'アンパッサン',
  '成り駒': '昇格した駒',
  '成る': '昇格する',
  'プロモーション': '昇格',
};

Iterable<Finding> _spanish(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## La idea\n')) {
    yield Finding.error(where, '$path: explanation must open with "## La idea"');
  }
  // Chips and code spans are notation (SAN keeps its `!?` glued on).
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  int count(String c) => c.allMatches(notation).length;
  if (count('?') != count('¿') || count('!') != count('¡')) {
    yield Finding.error(where,
        '$path: Spanish punctuation — every ? and ! needs its opening ¿ and ¡');
  }
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « »');
  }
  // A chip stands for a word here, so it must not read as a space.
  if (RegExp(r' [:;?!]').hasMatch(text.replaceAll(_chip, 'X'))) {
    yield Finding.error(where, '$path: no space before : ; ? ! in Spanish');
  }
  // A single-asterisk *italic* marks a foreign or historical term.
  final plain = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  final words = [
    for (final m in RegExp(r"[A-Za-zÀ-ÿ]+").allMatches(plain))
      if (!_notationNames.contains(m.group(0))) m.group(0)!.toLowerCase(),
  ];
  for (final w in words) {
    final agreed = _esAgreed[w];
    if (agreed != null) {
      yield Finding.error(where, '$path: "$w" — the agreed word is $agreed');
    }
    if (!_esFalseFriends.contains(w) && _englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$w" left in the prose');
    }
  }
}

Iterable<Finding> _chinese(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## 思路\n')) {
    yield Finding.error(where, '$path: explanation must open with "## 思路"');
  }
  const han = r'\u4e00-\u9fff';
  // Chips and code spans are notation; a chip reads as a Latin token.
  final spaced = text.replaceAll(_chip, 'X').replaceAll(RegExp(r'`[^`]*`'), 'X');
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (!RegExp('[$han]').hasMatch(notation)) {
    yield Finding.error(where, '$path: no Chinese text');
  }
  if (RegExp(r'[,;:?!()"]').hasMatch(notation) ||
      RegExp('[$han]\\.').hasMatch(notation)) {
    yield Finding.error(where,
        '$path: half-width punctuation — use ，。：；？！（）「」');
  }
  if (RegExp('[０-９Ａ-Ｚａ-ｚ]').hasMatch(notation)) {
    yield Finding.error(where, '$path: full-width digits or letters');
  }
  if (RegExp('[$han][A-Za-z0-9]|[A-Za-z0-9][$han]').hasMatch(spaced)) {
    yield Finding.error(where,
        '$path: put one space between Chinese and Latin text or digits');
  }
  if (RegExp(r' [，。：；？！、」）》]|[「（《，。：；？！、] ').hasMatch(spaced)) {
    yield Finding.error(where, '$path: no space beside full-width punctuation');
  }
  for (final c in _zhTraditional.split('')) {
    if (notation.contains(c)) {
      yield Finding.error(where, '$path: traditional character "$c"');
    }
  }
  // A single-asterisk *italic* marks a foreign or historical term.
  final plain = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  for (final e in _zhAgreed.entries) {
    if (plain.contains(e.key)) {
      yield Finding.error(where, '$path: "${e.key}" — the agreed word is ${e.value}');
    }
  }
  for (final m
      in RegExp(r'[A-Za-z][A-Za-z\-\.]*[A-Za-z0-9=+#]*').allMatches(plain)) {
    final w = m.group(0)!.replaceAll(RegExp(r'[.\-]+$'), '');
    if (_square.hasMatch(w) ||
        _san.hasMatch(w) ||
        _allowedLatin.contains(w) ||
        _zhLatin.contains(w)) {
      continue;
    }
    yield Finding.error(where, '$path: Latin word "$w" outside a chip');
  }
}

Iterable<Finding> _russian(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## Идея\n')) {
    yield Finding.error(where, '$path: explanation must open with "## Идея"');
  }
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (!RegExp('[а-яё]', caseSensitive: false).hasMatch(notation)) {
    yield Finding.error(where, '$path: no Russian text');
  }
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « »');
  }
  // `...d5` is notation: a dot that opens an ellipsis may follow a space.
  if (RegExp(r' [,:;?!]| \.(?!\.)').hasMatch(text.replaceAll(_chip, 'X'))) {
    yield Finding.error(where, '$path: no space before , . : ; ? !');
  }
  final lower = notation.toLowerCase();
  if (RegExp('черн(?!ополь)|ещe|еще[^а-я]').hasMatch(lower)) {
    yield Finding.error(where, '$path: write ё — «чёрные», «ещё»');
  }
  final prose = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  for (final e in _ruAgreed.entries) {
    if (RegExp('(?<![а-яё])${e.key}', caseSensitive: false).hasMatch(prose)) {
      yield Finding.error(where, '$path: "${e.key}" — the agreed word is ${e.value}');
    }
  }
  if (RegExp(r'[а-яё][a-z]|[a-z][а-яё]', caseSensitive: false)
      .hasMatch(notation)) {
    yield Finding.error(where, '$path: a word mixes Cyrillic and Latin letters');
  }
  final plain = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  for (final m
      in RegExp(r'[A-Za-z][A-Za-z\-\.]*[A-Za-z0-9=+#]*').allMatches(plain)) {
    final w = m.group(0)!.replaceAll(RegExp(r'[.\-]+$'), '');
    if (_square.hasMatch(w) ||
        _san.hasMatch(w) ||
        _allowedLatin.contains(w) ||
        _zhLatin.contains(w) ||
        RegExp(r'^[IVXLC]+$').hasMatch(w)) { // centuries: VI век
      continue;
    }
    yield Finding.error(where, '$path: Latin word "$w" outside a chip');
  }
}

/// Names the Russian UI bundle (`i18n/ru.json`) and Russian chess writing
/// settled differently. Keys match the start of a word.
const _ruAgreed = <String, String>{
  'королев(?!ств|ск)': 'ферзь',
  'офицер': 'слон',
  'лошад': 'конь',
  'шах и мат': 'мат',
  'шахмат мат': 'мат',
  'блундер': 'зевок',
  'сквозная атака': 'сквозной удар',
  // Both the long and the SHORT adjective forms: «незаконен» has one н and
  // slipped past a bare `законн` in three lessons.
  'закон(н|ен|на|но)': 'возможный ход (FIDE: «невозможный ход»)',
  'незакон(н|ен|на|но)': 'невозможный',
};

/// Names the Chinese UI bundle (`i18n/zh.json`) and Chinese chess writing
/// settled differently.
const _zhAgreed = <String, String>{
  '皇后': '后',
  '王后': '后',
  '城堡': '车',
  '主教': '象',
  '骑士': '马',
  '卒': '兵',
  '将死': '将杀',
  '僵局': '逼和',
  '双重将军': '双将',
  '分叉': '叉击',
  // zugzwang is 迫移 (zh.wikipedia's own article title); 窒息 means
  // "asphyxiation" and reads as 闷杀, which is the smothered mate.
  '窒息': '迫移',
};

/// Traditional forms of characters the corpus uses: the text is Simplified.
const _zhTraditional = '車馬將後國這們來為對與個點開關殺覺應還進邊線條無當擊時從變樣發過實';

/// Latin tokens Chinese prose keeps as they are.
const _zhLatin = <String>{
  'PGN', 'FEN', 'GM', 'IM', 'FM', 'CM', 'WGM', 'WIM', 'WFM', 'WCM', 'Stockfish', 'AlphaZero', 'IBM', 'X',
};

/// English words that are also Spanish: *mate*, *idea*.
const _esFalseFriends = {'mate', 'idea'};

/// Words with an agreed Spanish alternative, as the UI bundle (`i18n/es.json`)
/// and Spanish chess writing name them.
const _esAgreed = <String, String>{
  'reina': 'dama',
  'reinas': 'damas',
  'caballero': 'caballo',
  'obispo': 'alfil',
  'tenedor': 'horquilla',
  'jaquemate': 'jaque mate',
  'escaque': 'casilla',
  'escaques': 'casillas',
  'peon': 'peón',
  'blunder': 'error grave',
  'checkmate': 'jaque mate',
};

Iterable<Finding> _french(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith("## L'idée\n")) {
    yield Finding.error(where, "$path: explanation must open with \"## L'idée\"");
  }
  // Chips and code spans are notation (SAN keeps its `!?` glued on).
  final notation = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (RegExp(r'[^\s\u00a0\u202f][:;!?»]').hasMatch(notation) ||
      RegExp(r'«[^\u00a0\u202f]').hasMatch(notation)) {
    yield Finding.error(where,
        '$path: French typography — a non-breaking space before : ; ! ? » and after «');
  }
  if (RegExp(r' [:;!?»]|« ').hasMatch(notation)) {
    yield Finding.error(where,
        '$path: a breaking space before : ; ! ? » or after « — use U+00A0');
  }
  if (notation.contains('"')) {
    yield Finding.error(where, '$path: straight double quotes — use « »');
  }
  // A single-asterisk *italic* marks a foreign or historical term (*regina*).
  final plain = notation.replaceAll(
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  final words = [
    for (final m in RegExp(r"[A-Za-zÀ-ÿœŒ]+").allMatches(plain))
      if (!_notationNames.contains(m.group(0))) m.group(0)!.toLowerCase(),
  ];
  for (final w in words) {
    final agreed = _frAgreed[w];
    if (agreed != null) {
      yield Finding.error(where, '$path: "$w" — the agreed word is $agreed');
    }
    if (!_frFalseFriends.contains(w) && _englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$w" left in the prose');
    }
  }
}

/// English words that are also French: *on* (the pronoun), *but* (a goal),
/// *mate* (from *mater*, to mate).
const _frFalseFriends = {'on', 'but', 'mate'};

/// Words with an agreed French alternative, as the UI bundle (`i18n/fr.json`)
/// and French chess writing name them.
const _frAgreed = <String, String>{
  'reine': 'dame',
  'reines': 'dames',
  'évêque': 'fou',
  'chevalier': 'cavalier',
  'fourche': 'fourchette',
  'épingle': 'clouage',
  'embrochage': 'enfilade',
  'carreau': 'case',
  'damier': 'échiquier',
  'blunder': 'gaffe',
  'checkmate': 'échec et mat',
};

Iterable<Finding> _indonesian(
  String where,
  String path,
  String en,
  String text,
) sync* {
  if (en.startsWith('## The Idea') && !text.startsWith('## Ide\n')) {
    yield Finding.error(where, '$path: explanation must open with "## Ide"');
  }
  // Chips and code spans are notation; a single-asterisk *italic* is how the
  // corpus marks a foreign term (*jaque mate*, *regina*), kept as written.
  final plain = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ')
      .replaceAll(RegExp(r'(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)'), ' ');
  final words = [
    for (final m in RegExp(r"[A-Za-z][A-Za-z']*").allMatches(plain))
      // The notation lesson names where the letters come from: K for King.
      if (!_notationNames.contains(m.group(0))) m.group(0)!.toLowerCase(),
  ];
  for (final w in words) {
    final agreed = _idAgreed[w];
    if (agreed != null) {
      yield Finding.error(where, '$path: "$w" — the agreed word is $agreed');
    }
    if (_englishWords.contains(w)) {
      yield Finding.error(where, '$path: English word "$w" left in the prose');
    }
  }
}

/// Words with an agreed Indonesian alternative, as the UI bundle
/// (`i18n/id.json`) already names them.
const _idAgreed = <String, String>{
  'ratu': 'menteri',
  'bidak': 'pion',
  'kotak': 'petak',
  'jalur': 'lajur',
  'skak': 'sekak',
  'skakmat': 'sekakmat',
  'peluncur': 'gajah',
  'kastil': 'benteng',
  'rokad': 'rokade',
};

/// The English piece names, capitalized, that the piece letters come from.
const _notationNames = {'King', 'Queen', 'Rook', 'Bishop', 'Knight'};

/// Common English words that never belong in Indonesian prose: a leftover of
/// an unfinished sentence. Names and titles that contain them are rewritten.
const _englishWords = <String>{
  'the', 'and', 'your', 'you', 'with', 'of', 'is', 'are', 'this', 'that',
  'it', 'its', 'to', 'for', 'on', 'in', 'from', 'but', 'not', 'what',
  'move', 'moves', 'white', 'black', 'piece', 'pieces', 'pawn', 'knight',
  'bishop', 'rook', 'queen', 'king', 'check', 'checkmate', 'mate', 'square',
  'idea', 'play', 'takes', 'wins', 'can', 'will', 'one', 'two',
};

Iterable<Finding> _arabic(String where, String path, String text) sync* {
  // Chips and code spans are notation, not prose.
  final plain = text
      .replaceAll(_chip, ' ')
      .replaceAll(RegExp(r'`[^`]*`'), ' ');
  if (RegExp(r'[٠-٩۰-۹]').hasMatch(plain)) {
    yield Finding.error(where, '$path: Eastern Arabic digits — use 0–9');
  }
  for (final bad in const ['الملكة', 'القلعة', 'الجندي', 'جندي']) {
    if (plain.contains(bad)) {
      yield Finding.error(where,
          '$path: "$bad" — the agreed names are الوزير، الرخ، البيدق');
    }
  }
  if (RegExp(r'[?;]').hasMatch(plain)) {
    yield Finding.error(where, '$path: Latin ? or ; — use ؟ and ؛');
  }
  if (RegExp(r'[؀-ۿ],|,[\s]*[؀-ۿ]').hasMatch(plain)) {
    yield Finding.error(where, '$path: Latin comma in Arabic text — use ،');
  }
  if (!RegExp(r'[؀-ۿ]').hasMatch(plain) && plain.trim().isNotEmpty) {
    yield Finding.error(where, '$path: no Arabic text');
  }
  for (final m in RegExp(r'[A-Za-z][A-Za-z\-\.]*[A-Za-z0-9=+#]*').allMatches(plain)) {
    final w = m.group(0)!.replaceAll(RegExp(r'[.\-]+$'), '');
    if (_square.hasMatch(w) || _san.hasMatch(w) || _allowedLatin.contains(w)) {
      continue;
    }
    yield Finding.error(where, '$path: Latin word "$w" outside a chip');
  }
}

/// Latin tokens that are legitimately written in Latin inside Arabic prose:
/// file/rank names used as labels and SAN written in a code span's absence.
const _allowedLatin = <String>{
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', // files
  'K', 'Q', 'R', 'B', 'N', // piece letters of the notation
  'x', // the capture mark
  'L', // the knight's L-shape
  'King', 'Queen', 'Rook', 'Bishop', 'Knight', // where the letters come from
  'O-O', 'O-O-O', 'FIDE', 'Elo', 'NNUE',
};

String _name(File f) => f.path.split(Platform.pathSeparator).last;
