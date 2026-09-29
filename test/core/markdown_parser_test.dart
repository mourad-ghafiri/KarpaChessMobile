import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/markdown/karpa_markdown_parser.dart';

void main() {
  group('blocks', () {
    test('empty source parses to no blocks', () {
      expect(parseKarpaMarkdown(''), isEmpty);
      expect(parseKarpaMarkdown('\n\n  \n'), isEmpty);
    });

    test('headings level 2-4 with inline formatting', () {
      final blocks = parseKarpaMarkdown('## Two\n### **Three**\n#### {{e4}}');
      expect(blocks, const [
        MdHeading(2, [MdText('Two')]),
        MdHeading(3, [
          MdBold([MdText('Three')])
        ]),
        MdHeading(4, [MdSanChip('e4')]),
      ]);
    });

    test('one # or five # is not a heading', () {
      expect(parseKarpaMarkdown('# One'), const [
        MdParagraph([MdText('# One')]),
      ]);
      expect(parseKarpaMarkdown('##### Five'), const [
        MdParagraph([MdText('##### Five')]),
      ]);
    });

    test('horizontal rule, including long and indented forms', () {
      expect(parseKarpaMarkdown('---'), const [MdRule()]);
      expect(parseKarpaMarkdown('  -----  '), const [MdRule()]);
    });

    test('multi-line paragraph joins lines with a single space', () {
      final blocks = parseKarpaMarkdown('line one\nline two\n\nline three');
      expect(blocks, const [
        MdParagraph([MdText('line one line two')]),
        MdParagraph([MdText('line three')]),
      ]);
    });

    test('paragraph is terminated by any block starter', () {
      final blocks = parseKarpaMarkdown('text\n## H\nmore\n- item\ntail');
      expect(blocks, const [
        MdParagraph([MdText('text')]),
        MdHeading(2, [MdText('H')]),
        MdParagraph([MdText('more')]),
        MdListBlock(ordered: false, items: [
          [MdText('item')]
        ]),
        MdParagraph([MdText('tail')]),
      ]);
    });

    test('consecutive quote lines merge into one quote joined by spaces', () {
      final blocks = parseKarpaMarkdown('> first line\n> second *line*');
      expect(blocks, const [
        MdQuote([
          MdText('first line second '),
          MdItalic([MdText('line')]),
        ]),
      ]);
    });

    test('unordered list accepts - and * markers with inline formatting', () {
      final blocks = parseKarpaMarkdown('- plain\n* **bold** item\n- has `f8=Q`');
      expect(blocks, const [
        MdListBlock(ordered: false, items: [
          [MdText('plain')],
          [
            MdBold([MdText('bold')]),
            MdText(' item')
          ],
          [MdText('has '), MdCode('f8=Q')],
        ]),
      ]);
    });

    test('ordered list', () {
      final blocks = parseKarpaMarkdown('1. push {{e4}}\n2. develop\n10. castle');
      expect(blocks, const [
        MdListBlock(ordered: true, items: [
          [MdText('push '), MdSanChip('e4')],
          [MdText('develop')],
          [MdText('castle')],
        ]),
      ]);
    });

    test('windows newlines are normalized', () {
      final blocks = parseKarpaMarkdown('a\r\nb\r\n\r\nc');
      expect(blocks, const [
        MdParagraph([MdText('a b')]),
        MdParagraph([MdText('c')]),
      ]);
    });
  });

  group('inline', () {
    List<MdInline> inline(String s) =>
        (parseKarpaMarkdown(s).single as MdParagraph).spans;

    test('bold then italic then code then chip', () {
      expect(inline('a **b** *c* `d` {{e5}} f'), const [
        MdText('a '),
        MdBold([MdText('b')]),
        MdText(' '),
        MdItalic([MdText('c')]),
        MdText(' '),
        MdCode('d'),
        MdText(' '),
        MdSanChip('e5'),
        MdText(' f'),
      ]);
    });

    test('code content is locked from further processing', () {
      expect(inline('use `**not bold** {{e4}} *x*` here'), const [
        MdText('use '),
        MdCode('**not bold** {{e4}} *x*'),
        MdText(' here'),
      ]);
    });

    test('chip content is trimmed', () {
      expect(inline('{{ Nf3 }} and {{O-O}}'), const [
        MdSanChip('Nf3'),
        MdText(' and '),
        MdSanChip('O-O'),
      ]);
    });

    test('bold may contain a SAN chip (chips resolved before bold)', () {
      expect(inline('**{{e4}}**'), const [
        MdBold([MdSanChip('e4')]),
      ]);
    });

    test('bold may contain a code span', () {
      expect(inline('**a `b` c**'), const [
        MdBold([MdText('a '), MdCode('b'), MdText(' c')]),
      ]);
    });

    test('italic may wrap a complete bold span', () {
      expect(inline('*a **b** c*'), const [
        MdItalic([
          MdText('a '),
          MdBold([MdText('b')]),
          MdText(' c'),
        ]),
      ]);
    });

    test('bold cannot contain italic — inner asterisks stay literal', () {
      // Bold content may not include '*', so the outer '**' pairs never
      // match and only the inner '*b*' is italicised.
      expect(inline('**a *b* c**'), const [
        MdText('**a '),
        MdItalic([MdText('b')]),
        MdText(' c**'),
      ]);
    });

    test('triple asterisk resolves as bold followed by italic', () {
      expect(inline('**a***b*'), const [
        MdBold([MdText('a')]),
        MdItalic([MdText('b')]),
      ]);
    });

    test('unpaired bold falls through to the italic pass', () {
      // `**` never closes, so the second `*` of `**a*` pairs with the lone
      // `*` later in the line.
      expect(inline('**a* and lone * star'), const [
        MdText('**a'),
        MdItalic([MdText(' and lone ')]),
        MdText(' star'),
      ]);
    });

    test('a single unpaired marker stays literal', () {
      expect(inline('**a* b'), const [MdText('**a* b')]);
      expect(inline('a ** b'), const [MdText('a ** b')]);
      expect(inline('rate * price'), const [MdText('rate * price')]);
    });

    test('space-surrounded numbers survive next to code spans', () {
      // Guards the placeholder scheme: numeric slot indices must never
      // collide with real digit-bearing text.
      expect(inline('move 3 pawns and `Rd1` then 7 more'), const [
        MdText('move 3 pawns and '),
        MdCode('Rd1'),
        MdText(' then 7 more'),
      ]);
    });
  });

  group('real lesson content (basics-01-how-pieces-move)', () {
    test('play-step prompt: bold wrapping a SAN chip', () {
      const prompt =
          'Push the e-pawn two squares to claim the center with **{{e4}}**.';
      expect(parseKarpaMarkdown(prompt), const [
        MdParagraph([
          MdText('Push the e-pawn two squares to claim the center with '),
          MdBold([MdSanChip('e4')]),
          MdText('.'),
        ]),
      ]);
    });

    test('teach-step sentence with two SAN chips', () {
      const text =
          'For example, from the starting square, the e-pawn can play {{e3}} or {{e4}}.';
      expect(parseKarpaMarkdown(text), const [
        MdParagraph([
          MdText(
              'For example, from the starting square, the e-pawn can play '),
          MdSanChip('e3'),
          MdText(' or '),
          MdSanChip('e4'),
          MdText('.'),
        ]),
      ]);
    });

    test('welcome-step section: heading, bullets with bold, quote', () {
      const text = "## What you'll learn here\n"
          '\n'
          '- How each of the **six piece types** moves and captures\n'
          '- Why some pieces are stronger than others\n'
          "- The vocabulary you'll use for the rest of your chess life\n"
          '\n'
          '> The pieces are characters in a story. Learn how each one walks before you ask them to dance.';
      expect(parseKarpaMarkdown(text), const [
        MdHeading(2, [MdText("What you'll learn here")]),
        MdListBlock(ordered: false, items: [
          [
            MdText('How each of the '),
            MdBold([MdText('six piece types')]),
            MdText(' moves and captures'),
          ],
          [MdText('Why some pieces are stronger than others')],
          [MdText("The vocabulary you'll use for the rest of your chess life")],
        ]),
        MdQuote([
          MdText(
              'The pieces are characters in a story. Learn how each one walks before you ask them to dance.'),
        ]),
      ]);
    });
  });
}
