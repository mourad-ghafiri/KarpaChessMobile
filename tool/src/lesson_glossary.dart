/// Which lesson owns which word.
///
/// A reader meets the lessons in one order — `artOrder` zipped with each art's
/// list in `lessons/index.json` — and a lesson that uses a term the reader has
/// not been given yet reads as a mistake the reader made. This file is the
/// ledger: term → the lesson that teaches it, plus the short list of lessons
/// allowed to use it earlier because they define it in place.
///
/// The order itself is never written down here. `tool/lint_lessons.dart`
/// computes it from `artOrder` and the manifest, exactly the way
/// `SkillMap.build` does, so the ledger cannot drift from what the app shows.
library;

/// One term and the lesson that introduces it.
class GlossaryTerm {
  GlossaryTerm(
    this.label,
    String pattern,
    this.owner, {
    this.okBefore = const [],
  }) : pattern = RegExp(pattern, caseSensitive: false);

  /// How the term is named in a finding.
  final String label;

  /// Matched against a step's prose. Word-bounded at the author's discretion —
  /// `\bpin(s|ned)?\b` and not `pin`, or every "spinning" is a violation.
  final RegExp pattern;

  /// The lesson file that teaches it. Every lesson at or after this one in the
  /// global order may use the term freely.
  final String owner;

  /// Lessons before [owner] that may still use it, because the term is defined
  /// in place there. Every entry is deliberate; see the comment beside it.
  final List<String> okBefore;
}

/// The load-bearing vocabulary of the corpus.
///
/// Not every chess word — only the ones a reader cannot infer and that a
/// specific lesson is responsible for handing over.
final List<GlossaryTerm> lessonGlossary = [
  // ---- Foundations owns the rules themselves -----------------------------
  GlossaryTerm('castling', r'\bcastl(e|es|ed|ing)\b',
      'basics-03-castling.json'),
  GlossaryTerm(
    'promotion',
    r'\bpromot(e|es|ed|ion|ing)\b',
    'basics-02b-promotion.json',
    // The pawn lesson cannot describe a pawn without its one reward.
    okBefore: ['basics-01a-pawn.json'],
  ),
  GlossaryTerm('underpromotion', r'\bunderpromot',
      'basics-02b-promotion.json'),
  GlossaryTerm('en passant', r'\ben passant\b', 'basics-04-en-passant.json'),
  GlossaryTerm('stalemate', r'\bstalemate', 'basics-06-draws.json'),
  GlossaryTerm('algebraic notation', r'\bnotation\b|\balgebraic\b',
      'basics-07-notation.json'),
  GlossaryTerm('material', r'\bmaterial\b', 'basics-05-piece-values.json'),
  GlossaryTerm('the exchange', r'\bthe exchange\b',
      'basics-05-piece-values.json'),
  GlossaryTerm('sacrifice', r'\bsacrific(e|es|ed|ing|ial)\b',
      'basics-05-piece-values.json'),
  GlossaryTerm('blunder', r'\bblunder', 'basics-05-piece-values.json'),
  GlossaryTerm(
    'open file',
    r'\bopen file|\bopen-file',
    // The rook lesson defines it — "a file with no pawns on it" — because a
    // rook cannot be described without one. `strategy-07` goes deep later.
    'basics-01d-rook.json',
  ),
  GlossaryTerm('candidate move', r'\bcandidate move',
      'basics-08-thinking-process.json'),

  // ---- The Blade owns the tactics ----------------------------------------
  GlossaryTerm('fork', r'\bfork(s|ed|ing)?\b', 'tactics-01-the-fork.json'),
  GlossaryTerm('pin', r'\bpin(s|ned|ning)?\b', 'tactics-02-the-pin.json'),
  GlossaryTerm(
    'back-rank mate',
    r'back[- ]rank mate|mate on the back rank',
    'tactics-03-back-rank-mate.json',
    // The mate lesson shows the pattern as the simplest mate there is; it may
    // name it, and the tactics lesson turns it into a weapon.
    okBefore: ['basics-02-check-and-mate.json'],
  ),
  GlossaryTerm('skewer', r'\bskewer', 'tactics-04-the-skewer.json'),
  GlossaryTerm('discovered attack', r'\bdiscover(ed|y)\b',
      'tactics-05-discovered-attack.json'),
  GlossaryTerm(
    'double attack',
    r'\bdouble attack',
    'tactics-06-double-attack.json',
    // A fork is one, and the fork lesson is allowed to say so.
    okBefore: ['tactics-01-the-fork.json'],
  ),
  GlossaryTerm('deflection', r'\bdeflect', 'tactics-08-deflection.json'),
  GlossaryTerm('overloading', r'\boverload', 'tactics-09-overloading.json'),
  GlossaryTerm('zwischenzug', r'\bzwischenzug|\bin-between move',
      'tactics-10-zwischenzug.json'),
  GlossaryTerm('x-ray', r'\bx-ray', 'tactics-11-xray.json'),
  GlossaryTerm('interference', r'\binterferen|\binterfere\b',
      'tactics-12-interference.json'),
  GlossaryTerm('windmill', r'\bwindmill', 'tactics-17-windmill.json'),

  // ---- The First Moves owns opening vocabulary ---------------------------
  GlossaryTerm('tempo', r'\btempo\b|\btempi\b',
      'openings-01-opening-principles.json'),
  GlossaryTerm('development', r'\bdevelop(s|ed|ing|ment)?\b',
      'openings-01-opening-principles.json'),
  GlossaryTerm('the initiative', r'\binitiative\b',
      'openings-01-opening-principles.json'),
  GlossaryTerm('battery', r'\bbatter(y|ies)\b', 'openings-03-sicilian.json'),
  GlossaryTerm('half-open file', r'\bhalf[- ]open',
      'openings-03-sicilian.json'),
  GlossaryTerm('counterplay', r'\bcounterplay\b', 'openings-03-sicilian.json'),
  GlossaryTerm('gambit', r'\bgambit', 'openings-04-queens-gambit.json'),
  GlossaryTerm('minority attack', r'\bminority attack',
      'openings-04-queens-gambit.json'),
  GlossaryTerm('pawn chain', r'\bpawn chain|\bchain\b',
      'openings-05-caro-kann.json'),
  GlossaryTerm('fianchetto', r'\bfianchett', 'openings-06-english.json'),
  GlossaryTerm('doubled pawns', r'\bdoubled\b', 'openings-10-ruy-lopez.json'),

  // ---- The Finish owns the endgame ---------------------------------------
  GlossaryTerm('zugzwang', r'\bzugzwang', 'endgames-01-king-activity.json'),
  GlossaryTerm('the opposition', r'\bopposition\b',
      'endgames-03-opposition.json'),
  GlossaryTerm('passed pawn', r'\bpassed pawn', 'endgames-05-passed-pawns.json'),

  // ---- The Plan owns structure -------------------------------------------
  GlossaryTerm('outpost', r'\boutpost', 'strategy-02-outposts.json'),
  GlossaryTerm('isolated pawn', r'\bisolated\b',
      'strategy-03-pawn-structure.json'),
  GlossaryTerm('backward pawn', r'\bbackward pawn',
      'strategy-03-pawn-structure.json'),
  GlossaryTerm('space advantage', r'\bspace advantage', 'strategy-05-space.json'),
  GlossaryTerm(
    'weak square',
    r'\bweak square|\bweak squares|\bholes?\b',
    // Steinitz is where a square you can never repair first matters, and the
    // lesson defines it on the board. `strategy-06` names the color complex.
    'history-06-steinitz.json',
  ),
  GlossaryTerm('bishop pair', r'\bbishop pair', 'strategy-08-bishop-pair.json'),
  GlossaryTerm('prophylaxis', r'\bprophyla', 'strategy-09-prophylaxis.json'),
];

/// Lessons where printing the answer in the prompt **is** the exercise.
///
/// Five lessons qualify, for two reasons. Naming or reading a move off the
/// page is the drill itself (`basics-00`, `basics-07`, `culture-03`); or the
/// written form of a mechanic is the thing being demonstrated (`basics-03`,
/// `basics-02b`). Rule L04 would be asking them not to do their job. Nothing
/// else is exempt; every other prompt states the goal and lets the reader
/// find the move.
const Map<String, String> answerLeakAllowed = {
  'basics-00-board-and-setup.json': 'naming the square IS the coordinate drill',
  'basics-07-notation.json': 'the lesson is reading a move off the page',
  'culture-03-recording-games.json': 'the lesson is writing the move down',
  'basics-03-castling.json': 'O-O is a mechanic being demonstrated, not found',
  'basics-02b-promotion.json': 'the promotion syntax is the thing being taught',
};

/// Lessons where a move may be written as inline code rather than as a chip.
///
/// Everywhere else a chip is strictly better — it is tappable and previews the
/// move on the board. These two are about the *written form* of a move, so the
/// move has to appear as type on a page rather than as a control.
const Set<String> backtickSanAllowed = {
  'basics-07-notation.json',
  'culture-03-recording-games.json',
};

/// American spellings the corpus settled on, and the variants that are errors.
///
/// The app's own UI strings are American (`center`, `defense`), and the reader
/// sees those on every screen, so the prose matches them rather than the other
/// way around.
const Map<String, String> spellingRegister = {
  'centre': 'center',
  'centres': 'centers',
  'counsellor': 'counselor',
  'colour': 'color',
  'colours': 'colors',
  'coloured': 'colored',
  'defence': 'defense',
  'defences': 'defenses',
  'offence': 'offense',
  'favour': 'favor',
  'favours': 'favors',
  'favourite': 'favorite',
  'analyse': 'analyze',
  'analysed': 'analyzed',
  'analysing': 'analyzing',
  'manoeuvre': 'maneuver',
  'manoeuvres': 'maneuvers',
  'manoeuvring': 'maneuvering',
  'practise': 'practice',
  'practised': 'practiced',
  'realise': 'realize',
  'realised': 'realized',
  'recognise': 'recognize',
  'recognised': 'recognized',
  'neighbour': 'neighbor',
  'neighbouring': 'neighboring',
  'travelling': 'traveling',
  'cancelled': 'canceled',
};

/// Phrases that mark the register the corpus is moving away from.
///
/// The first group is filler that announces the lesson instead of teaching it;
/// the second is the template's own furniture; the third is jargon a reader is
/// never given.
const List<String> bannedPhrases = [
  // Announcing
  'in this lesson',
  "let's learn",
  'let us learn',
  'today we',
  'as we saw',
  'as you know',
  'it is important to',
  "it's important to",
  'remember that',
  'now that you know',
  'first of all',
  'keep in mind',
  // Template furniture
  '**takeaway:**',
  'takeaway:',
  'rules of thumb',
  'a few useful',
  // Unexplained jargon
  'luft',
  'desperado',
  'en prise',
];
