// c10.dart -- a PEG parser with built-in error recovery, in one file.
//
// WHAT THIS IS. A parser that, given a grammar and an input string, returns
// the best complete parse tree it can -- even when the input has errors.
// Damage is reported inside the tree as SyntaxError nodes: a SyntaxError
// with length > 0 marks real input characters that were skipped as noise;
// a SyntaxError of length 0 marks a place where something required was
// missing. The engine never invents characters; it only records what it
// skipped and where something was absent.
//
// HOW IT WORKS, IN ONE PARAGRAPH. The engine is ONE costed descent: every
// grammar node returns a set of candidate READINGS -- ways its part of
// the grammar could account for the input, each carrying a repair bill.
// Candidates compete: for each (grammar node, position, end position)
// only the best-priced reading survives. The search runs in rounds with a
// rising repair budget (0 edits, then 1, then 2, ...) and stops at the
// first budget where some reading explains the entire input; that bound
// is what keeps the search fast. The winning reading is then turned into
// the output tree. There is NO separate plain parser: round zero -- the
// same descent run with nothing to spend -- IS the plain parse (a
// memoizing recursive descent supporting left recursion), and a costed
// frame that has spent its whole budget continues by the same rule.
//
// WHAT c10 CHANGES OVER c9. Nothing in the judgment: over the whole
// mutation battery, c10 returns bit-identical trees to c9 (and c8). c9
// carried TWO engines -- a dedicated plain parser for the zero-budget
// work, plus the costed search, with laws keeping their answers aligned.
// c10 deletes the dedicated parser and runs the one machine at every
// budget: 890 -> 785 lines (-12%) at a measured ~1.07-1.09x paired latency.
// Each construct keeps two faces of one behavior: proposePlain, the
// classic PEG parse (one preferred reading, tree built as it returns,
// no lists between stores), and proposeReadings, the costed candidate
// generation -- the same cells, the same judging, the same growth loop
// fill both. Three rules make the collapse exact, to the tree and the
// label:
//
//   * WITH NO BUDGET LEFT, REPAIR IS PARSING. A budget-zero consult
//     belongs to the plain parse (see Squirrel._isPlainConsult), and its
//     answer is the plain parse's one PREFERRED reading: demotion
//     (Squirrel._greedyOnly) strips "the parser's own choice" status from
//     every reading the greedy plain parser would not itself produce, so
//     the preferred survivor IS the plain answer.
//   * EACH SIDE OWNS ITS STORE. A plain consult fills the cell's TWIN
//     (_RepairCell.plainTwin), never the costed cell: fill order and
//     who-asked-first are observable through label sharing, so the two
//     sides share machinery -- one growth loop, one version clock --
//     but never data. Ties in a cell follow the side: the repair search
//     keeps the newcomer (a later pass is better informed -- measured),
//     the plain parse keeps the incumbent (a fixed point discards an
//     equal re-derivation).
//   * SHARING FOLLOWS THE VIEW. Every packaged answer -- a cell's served
//     list, a reference's labeled wrapping, the budget-zero tree wrap --
//     is cached keyed by the IDENTITY of the view it was built over,
//     which changes exactly when the underlying content may have. The
//     first asker builds it, every later asker shares it (so a tree
//     node's label object is the same whichever reference asked), and
//     any store retires it.
//
// Two "obvious" optimizations went the other way and are deliberately
// absent, both for the same reason: Dart's generational GC makes young,
// short-lived allocations nearly free, so avoiding them buys nothing and
// the machinery to avoid them costs real time. Judging a candidate
// WITHOUT allocating it first measured 1.02-1.04x slower than allocate-
// then-compare, and reusing cell arrays ACROSS runs (epoch stamps and
// in-place resets instead of fresh allocation) measured 1.10x slower --
// old-generation stores pay a write barrier that fresh young arrays
// never do. The boundary is the per-candidate hot path, though: routing
// the slot walk and the store's view build through the shared helpers
// (an intermediate list per store, a judging cell with its cache
// bookkeeping per slot) measured 1.18x slower than inlining the same
// rules, so there -- and only there -- the code repeats a rule instead
// of calling it.
//
// The clause classes here carry the same names as the original squirrel
// parser (Seq, First, Repetition, Optional, RuleRef) where a construct
// keeps its own class, because they are the same grammar constructs with
// the recovery behavior added as methods; both lookaheads are one
// Lookahead class, and every terminal kind (literal, character, class,
// wildcard, empty) is one Terminal class.
// The engine is self-contained: the library (imported as `lib`)
// contributes only the interchange types -- the grammar AST callers hand
// over (converted to these classes by the harness's _convert.dart) and
// the Match/SyntaxError tree types callers read back. Every tree node is
// labeled with the caller's own clause object ([Clause.source]), so
// callers see trees over the grammar they supplied.
//
// The design decisions in this file were each settled by measurement over
// a large mutation battery; the history and the numbers live in
// LESSONS_LEARNED.md at the repository root.
import 'package:squirrel_parser/squirrel_parser.dart' as lib;

/// Sentinel values for [_Reading.firstDoubt], both larger than any input
/// position. A reading whose firstDoubt is a real position has a repair
/// there; `_clean` means "no repairs, but not the plain parser's own
/// choice"; `_chosen` means "no repairs, and this is exactly what the
/// plain parser would do". Bigger is more trustworthy.
const int _clean = 1 << 30;
const int _chosen = _clean + 1;

/// "This grammar node cannot match at all" for [Clause.minChars].
const int _impossible = 1 << 30;

/// "No budget limit" for [_RepairCell.readings] (larger than any real
/// budget; distinct in meaning from the firstDoubt sentinels above).
const int _unlimited = 1 << 30;

int _min(int a, int b) => a < b ? a : b;

/// A finished tree node over already-finished children -- the exact shape
/// [Squirrel._treeOf] gives a labeled chain, built eagerly by the
/// plain-parse proposals.
lib.MatchResult _node(lib.Clause name, int from, List<lib.MatchResult> kids) =>
    kids.isEmpty
        ? lib.Match(name, from, 0)
        : lib.Match(name, 0, 0, subClauseMatches: kids);

/// A grammar construct's name wrapped around the steps that filled it in:
/// the piece of tree that says "these children together form one <label>".
class _Labeled {
  const _Labeled(this.label, this.from, this.inner);

  /// The caller's clause whose name the finished tree node will carry.
  final lib.Clause label;

  /// The input position where the construct started.
  final int from;

  /// The chain of steps (see [_Reading]) that make up its children.
  final _Reading inner;
}

/// One candidate way of reading a stretch of input, with its repair bill.
///
/// A reading is a LINKED LIST built backwards: [piece] is what the most
/// recent step contributed to the eventual tree, and [prev] is the reading
/// up to that point. A piece is one of three things:
///   - a SyntaxError        (input characters deleted as noise),
///   - a MatchResult        (a finished subtree, parsed normally),
///   - a _Labeled           (a construct's name over an inner chain).
/// Alongside the list, each reading carries running totals of its costs,
/// so comparing two readings never needs to walk their chains.
class _Reading {
  const _Reading(
      this.end, this.deleted, this.missing, this.evidence, this.firstDoubt,
      {this.missingAtEnd = 0,
      this.penalties = 0,
      this.endsIncomplete = false,
      this.piece,
      this.prev});

  /// A reading of nothing at all, standing at position [p].
  const _Reading.empty(int p) : this(p, 0, 0, 0, _chosen);

  /// A reading that deletes the input from [f] up to [t] as noise. Its
  /// firstDoubt is f -- the deletion is exactly where it became doubtful.
  _Reading.deleting(int f, int t)
      : this(t, t - f, 0, 0, f, piece: lib.SyntaxError(pos: f, len: t - f));

  /// Where this reading stops in the input.
  final int end;

  /// How many input characters it deleted as noise.
  final int deleted;

  /// How many required things were found missing BEFORE the end of the
  /// input (each is recorded as a zero-length SyntaxError; nothing is
  /// ever invented to fill them).
  final int missing;

  /// How many required things were missing AT the end of the input --
  /// the "document just stops here" case. Counted separately from
  /// [missing] because it is billed differently: see [cost].
  final int missingAtEnd;

  /// How many input characters were matched by PICKY matchers -- literals,
  /// exact characters, character classes -- which could only have matched
  /// because the input really contained those characters. This is the
  /// reading's evidence that it fits the document. (Characters consumed by
  /// wildcards or negated classes prove nothing and do not count.)
  final int evidence;

  /// The input position of this reading's first repair, or a sentinel
  /// (`_clean` / `_chosen`) if it has none. Combining readings keeps the
  /// minimum, i.e. the earliest doubt. Used as a tie-breaker: between
  /// otherwise equal readings, the one that stayed faithful LONGER wins.
  final int firstDoubt;

  /// Extra charges that are not real edits: a penalty makes a reading
  /// lose ties without showing up in the tree or in the reported repair
  /// cost. See _readSlots for the one rule that levies them.
  final int penalties;

  /// True if something required is still missing exactly at [end] -- the
  /// reading stopped mid-thought. A later step that actually consumes
  /// input clears this.
  final bool endsIncomplete;

  /// What the latest step contributes to the tree (see class comment).
  final Object? piece;

  /// The reading up to the previous step.
  final _Reading? prev;

  /// The total repair bill: deletions, mid-document missing pieces, and
  /// ONE charge for the end of input, no matter how many required pieces
  /// the cut-off stranded. ("The document stopped" is a single fact about
  /// the input; a truncated file is not more broken because the grammar
  /// wanted five more tokens rather than one.)
  int get cost => deleted + missing + (missingAtEnd > 0 ? 1 : 0);

  /// The part of the bill that counts against the search budget. The
  /// end-of-input charge is deliberately excluded: the budget is split
  /// between the parts of a sequence as work proceeds, and a charge that
  /// must only be paid once cannot be handed down through those splits
  /// without being paid at every level. It is charged globally instead,
  /// through [cost].
  int get spent => deleted + missing;

  /// No repairs, and this is the plain parser's own preferred reading.
  bool get preferred => firstDoubt > _clean;

  /// No repairs at all (preferred or not).
  bool get clean => firstDoubt >= _clean;

  /// How many characters this reading consumed WITHOUT evidence, seen
  /// from [from]: its span, minus deletions, minus evidence. These were
  /// swallowed by loose matchers (wildcards, negated classes) that would
  /// have accepted anything.
  int absorbed(int from) => (end - from) - deleted - evidence;

  /// One extra point against a repaired reading that absorbed more than
  /// it proved: a reading that mostly swallowed the input has not really
  /// explained it. Computed fresh at every comparison from the totals the
  /// reading already carries -- deliberately never stored, so it can
  /// never be double-charged no matter how many levels compare it.
  int absorbPenalty(int from) => !clean && absorbed(from) > evidence ? 1 : 0;

  /// This reading extended by one more step.
  _Reading then(_Reading step) => _Reading(
      step.end,
      deleted + step.deleted,
      missing + step.missing,
      evidence + step.evidence,
      _min(firstDoubt, step.firstDoubt),
      missingAtEnd: missingAtEnd + step.missingAtEnd,
      penalties: penalties + step.penalties,
      // The step either consumed input (curing any earlier incompleteness)
      // or it didn't (in which case incompleteness carries through).
      endsIncomplete:
          step.endsIncomplete || (step.end == end && endsIncomplete),
      piece: step.piece,
      prev: this);

  /// This reading repackaged behind a new piece: a finished tree
  /// ([withTree], used for zero-width results such as an empty optional
  /// or a lookahead), or a construct's name over the whole chain
  /// ([labeled]) -- the chain moves inside the piece, so the copy
  /// carries no prev.
  _Reading _packed(Object piece, int rank) =>
      _Reading(end, deleted, missing, evidence, _min(firstDoubt, rank),
          missingAtEnd: missingAtEnd,
          penalties: penalties,
          endsIncomplete: endsIncomplete,
          piece: piece);

  _Reading withTree(lib.MatchResult m, [int rank = _chosen]) =>
      _packed(m, rank);

  _Reading labeled(lib.Clause label, int from, [int rank = _chosen]) =>
      _packed(_Labeled(label, from, this), rank);

  _Reading _with({int? firstDoubt, int? penalties}) =>
      _Reading(end, deleted, missing, evidence, firstDoubt ?? this.firstDoubt,
          missingAtEnd: missingAtEnd,
          penalties: penalties ?? this.penalties,
          endsIncomplete: endsIncomplete,
          piece: piece,
          prev: prev);

  /// A copy carrying one more penalty point.
  _Reading penalized() => _with(penalties: penalties + 1);

  /// A copy stripped of "the plain parser's own choice" status (it stays
  /// clean if it was clean, but no longer outranks rivals on that alone).
  _Reading get demoted => _with(firstDoubt: _min(firstDoubt, _clean));
}

/// The memo cell for repairs: for one (grammar node, input position), the
/// best reading found so far for EACH possible end position.
///
/// Inserting is also how improvement is detected: [add] answers whether
/// the newcomer changed anything, and the fixed-point loop in
/// Squirrel._grow stops when a whole pass adds nothing. Results are kept
/// in insertion order (a plain map), so iteration is deterministic and no
/// sorting is ever needed.
///
/// The champion map is filled LAZILY, to the highest budget any query
/// has yet needed ([atBudget], a watermark); smaller queries are served
/// by filtering at read time ([readings]). A budget-zero query is served
/// the [plainTwin]'s one PREFERRED reading alone ([plainServe]; see
/// Squirrel._grow): demotion has stripped that status from everything
/// the plain parser would not itself produce, so the zero serve IS the
/// plain parse, run by the same machinery into the twin's own map.
///
/// [atBudget] and [memoVersion] stamp when the cell was filled; the cell
/// is only trusted while both still hold (see Squirrel._grow).
/// [inRecPath] / [foundLeftRec] play the same roles as in the plain
/// parser's memo: cycle detection and the signal that a left-recursive
/// cycle needs growing.
class _RepairCell {
  _RepairCell(this.pos, {this.plainCell = false});
  final int pos;

  /// True for a [plainTwin]: this cell belongs to the plain parse.
  /// The one behavioral difference is the tie rule in [add].
  final bool plainCell;

  /// Best reading per end position, in first-offer order. A plain list
  /// scanned by each reading's own `end` -- the end IS the key, so a map
  /// would only duplicate it, and cells are tiny (measured over the
  /// battery: 71% of consults see at most one reading, 90% at most
  /// three), so a linear scan beats hashing.
  final List<_Reading> _best = [];
  bool inRecPath = false, foundLeftRec = false, usedSeed = false;

  /// The plain parse's own store. The plain parse and the repair search
  /// run the SAME machinery, but they may not share a store: both fill
  /// order and who-asked-first are observable through label sharing, so
  /// each side gets its own cell and neither ever reads the other's
  /// (see Squirrel._grow, which picks the twin whenever the budget is
  /// zero).
  _RepairCell? plainTwin;
  int atBudget = -1, memoVersion = 0;

  /// The budget-zero serve: the view's one preferred reading -- the plain
  /// parser's own answer -- materialized to a concrete tree and served
  /// alone. Frozen at the first ask that saw a settled answer (no live
  /// left-recursive seed below it) and never invalidated: the plain
  /// answer is a fact of the input, whatever later rounds store here,
  /// and freezing keeps every asker sharing one served object.
  List<_Reading>? plainServe;

  /// The built view, cached between changes. Any budget at or above
  /// [_maxSpent] -- the most any stored reading has spent, kept
  /// conservatively high across replacements -- filters nothing, so ONE
  /// cached list serves every such query; smaller budgets (rare) build
  /// fresh. Any store invalidates it, which also gives the view a useful
  /// property: its object identity changes exactly when its content may
  /// have (see RuleRef.findReadings).
  List<_Reading>? _view;
  int _maxSpent = 0;

  /// A rule reference's wrapping of this cell's view: valid exactly while
  /// [refSrc] is still the cell's current [_view] object. Not only a
  /// cache: it makes every reference to a rule SHARE one wrapped list, so
  /// a tree node's label object is the same whichever reference asked
  /// (first asker wins), exactly as the budget-zero wrap already behaves
  /// (see RuleRef.findReadings).
  List<_Reading>? refSrc, refView;

  /// Offer a reading; keep it if it beats (or ties) the current holder of
  /// its end position. Returns true only on a strict improvement.
  bool add(_Reading r) {
    final end = r.end;
    for (var i = 0; i < _best.length; i++) {
      final holder = _best[i];
      if (holder.end != end) continue;
      final cmp = Squirrel._compare(r, holder, pos);
      // On an exact tie the two sides differ, each way deliberate. In
      // the costed search the NEWCOMER takes the slot (measured): tied
      // readings can differ in details the comparison cannot see, and the
      // later one -- produced by a later, better-informed pass -- is
      // right more often. In the plain parse the INCUMBENT keeps it: the
      // plain parse is deterministic, a growth pass's re-derivation of an
      // equal reading is the same answer re-spelled, and keeping the
      // holder keeps the view -- and every wrap keyed to its identity --
      // alive through the confirmation pass, exactly as the plain
      // parser's fixed point discards an attempt that consumed no more
      // than the last. Either way a tie reports "no improvement", or two
      // tied rivals would re-trigger each other forever.
      if (cmp > 0 || (cmp == 0 && plainCell)) return false;
      _best[i] = r;
      _view = null;
      if (r.spent > _maxSpent) _maxSpent = r.spent;
      return cmp < 0;
    }
    _best.add(r);
    _view = null;
    if (r.spent > _maxSpent) _maxSpent = r.spent;
    return true;
  }

  /// The cell's readings, filtered to what [budget] can afford, with
  /// non-farthest preferred readings demoted (see Squirrel._greedyOnly).
  List<_Reading> readings([int budget = _unlimited]) {
    if (budget >= _maxSpent) return _view ??= _buildView(_unlimited);
    return _buildView(budget);
  }

  // The same demotion as Squirrel._greedyOnly, interleaved with the
  // budget filter (this runs on every store; the intermediate list was
  // measured to cost real time).
  List<_Reading> _buildView(int budget) {
    var farthest = -1;
    for (var i = 0; i < _best.length; i++) {
      final r = _best[i];
      if (r.preferred && r.end > farthest) farthest = r.end;
    }
    final out = <_Reading>[];
    for (var i = 0; i < _best.length; i++) {
      final r = _best[i];
      if (r.spent > budget) continue;
      out.add(r.preferred && r.end != farthest ? r.demoted : r);
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// The grammar, as this engine's own clause classes -- the same constructs,
// and the same names, as the original squirrel parser, with the recovery
// behavior added. Each clause carries the caller's source clause (for the
// trees the caller reads), its analyses, its memo state, and its whole
// behavior as methods:
//
//   readings(pos)      all candidate readings here, repairs included
//   cleanReading(pos)  the plain parse: the budget-zero preferred reading
//   picky / hasOneShape / minChars   small static facts, described below
// ---------------------------------------------------------------------------

abstract class Clause {
  Clause(this.source);

  /// The caller's clause this one was converted from: the label every
  /// tree node carries, so the caller sees trees over its own grammar.
  final lib.Clause source;

  /// All candidate readings at [pos], repairs included. The bounds guard
  /// lives here so the per-kind implementations never see an out-of-range
  /// position.
  List<_Reading> readings(Squirrel e, int pos) =>
      pos > e._len ? const [] : findReadings(e, pos);

  /// The per-kind implementation behind [readings].
  List<_Reading> findReadings(Squirrel e, int pos);

  /// The plain parse's own consult: this clause read plainly at
  /// [pos] -- its one preferred reading, carrying a finished tree -- or
  /// null where it cannot match plainly. The single reading travels up
  /// bare; lists exist only where readings are stored (cells and the
  /// cached rule wraps), never on the way between them.
  _Reading? plainReading(Squirrel e, int pos) =>
      pos > e._len ? null : Squirrel._preferredOf(findReadings(e, pos));

  /// The plain parse at [pos] asked from a costed frame. There is no
  /// separate plain parser: this switches the budget to zero and runs
  /// the SAME descent. Used by the delete-ahead scan in _readSlots;
  /// terminals override it with a direct character test.
  _Reading? cleanReading(Squirrel e, int pos) {
    final whole = e._budget;
    final probing = e._probing;
    e._budget = 0;
    e._probing = true;
    final r = plainReading(e, pos);
    e._budget = whole;
    e._probing = probing;
    return r;
  }

  /// The repair cell at [pos], if one exists for the current input.
  /// Never allocates; only composite clauses override this.
  _RepairCell? cellAt(Squirrel e, int pos) => null;

  /// Whether this clause can produce only ONE possible tree shape,
  /// whatever input it reads. If so, "it was missing" is unambiguous --
  /// there is exactly one thing it could have been -- which matters for
  /// the penalty rule in _readSlots. Computed once and cached; a
  /// recursive cycle counts as "no".
  bool? _oneShape;
  bool hasOneShape() {
    if (_oneShape != null) return _oneShape!;
    _oneShape = false; // cycle-breaker: while computing, assume "no"
    return _oneShape = computeOneShape();
  }

  bool computeOneShape();

  /// The fewest input characters any successful match of this clause can
  /// consume ([_impossible] if it can never match). Used only to bound
  /// the repair search: no repair can need more budget than the whole
  /// input plus the shortest possible document. Deliberately NOT cached:
  /// caching under the cycle-breaker records wrong values inside
  /// recursive grammars, and it is only computed once anyway.
  int minChars(Set<Clause> path) {
    if (!path.add(this)) return _impossible;
    final v = computeMinChars(path);
    path.remove(this);
    return v;
  }

  int computeMinChars(Set<Clause> path);
}

/// A composite clause: its repair results are memoized in one
/// [_RepairCell] per input position, filled in by Squirrel._grow around
/// this clause's [proposeReadings]. The cell array is stamped with the
/// run it belongs to, so starting a new input resets every clause by
/// bumping one counter.
abstract class Composite extends Clause {
  Composite(super.source);

  /// True for the body of a named rule (marked by the Squirrel
  /// constructor). Read by one exemption in Squirrel._grow: a budget-zero
  /// consult of a rule body is independent of any costed growth of the
  /// same cell, while one of an inline composite is not.
  bool isRuleBody = false;

  List<_RepairCell?>? _cells;
  int _run = -1;

  List<_RepairCell?> cells(Squirrel e) {
    if (_run != e._runId) {
      _cells = List<_RepairCell?>.filled(e._len + 2, null);
      _run = e._runId;
    }
    return _cells!;
  }

  @override
  _RepairCell? cellAt(Squirrel e, int pos) =>
      _run == e._runId ? _cells![pos] : null;

  /// Inside a twin fill ([Squirrel._inPlainFill]) an inline composite is
  /// computed directly, with no cell: the plain parse recurses straight
  /// through a rule's body, memoized only at rule boundaries -- exactly
  /// the plain parser's own shape. (Rule bodies keep their twins: they
  /// are the left-recursion anchors, and every cycle in the clause graph
  /// passes through a rule.) Outside a twin fill, a budget-zero consult
  /// may need a growing costed cell's seed (see crossSeed in
  /// [Squirrel._grow]), so it goes through the cell machinery.
  @override
  _Reading? plainReading(Squirrel e, int pos) => pos > e._len
      ? null
      : e._inPlainFill && !isRuleBody
          ? proposePlain(e, pos)
          : Squirrel._preferredOf(e._grow(this, pos));

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    if (e._inPlainFill && !isRuleBody) {
      final r = proposePlain(e, pos);
      return r == null ? const [] : [r];
    }
    return e._grow(this, pos);
  }

  /// The plain parse of this construct: one preferred reading over the
  /// input exactly as it stands, its tree already built, or null. Every
  /// consult inside it is served at most one preferred reading, so the
  /// descent is deterministic -- the classic PEG parse, run by the same
  /// clause objects.
  _Reading? proposePlain(Squirrel e, int pos);

  /// One pass of costed candidate generation for the cell at [pos]. May
  /// be run several times when a left-recursive cycle is being grown.
  /// Proposals arrive finished: each carries the construct's name (or,
  /// for the zero-width results of an optional or a lookahead, a
  /// finished tree) already wrapped on. The name changes no comparison
  /// key, so the cell judges them exactly as it would raw readings.
  List<_Reading> proposeReadings(Squirrel e, int pos);
}

/// A sequence: each part in order (the grammar's juxtaposition).
class Seq extends Composite {
  Seq(super.source, this.subClauses);
  final List<Clause> subClauses;

  // Plainly: each part in order; any part that cannot match plainly
  // fails the sequence.
  @override
  _Reading? proposePlain(Squirrel e, int pos) {
    final kids = <lib.MatchResult>[];
    var p = pos, evidence = 0;
    for (var i = 0; i < subClauses.length; i++) {
      final step = subClauses[i].plainReading(e, p);
      if (step == null) return null;
      kids.add(step.piece as lib.MatchResult);
      evidence += step.evidence;
      p = step.end;
    }
    return _Reading(p, 0, 0, evidence, _chosen,
        piece: _node(source, pos, kids));
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) =>
      e._readSlots(subClauses, source, pos);

  @override
  bool computeOneShape() => subClauses.every((s) => s.hasOneShape());

  @override
  int computeMinChars(Set<Clause> path) {
    var total = 0;
    for (final sub in subClauses) {
      final n = sub.minChars(path);
      total =
          n >= _impossible || total >= _impossible ? _impossible : total + n;
    }
    return total;
  }
}

/// An ordered choice (the grammar's `/`): try each alternative in order;
/// plainly, the first match wins.
///
/// Under repair, every alternative contributes candidates -- but once
/// some alternative has read the input exactly as it stands, the choice
/// is considered settled in that alternative's favor, and a LATER
/// alternative's repaired reading is admitted only if it proves more
/// than it swallows. Without that rule, a loose later alternative (say,
/// a quoted-string rule) can "explain" almost anything by absorbing it,
/// stealing the parse from the alternative the document really used.
/// Note the >=: a settled choice demands the challenger prove strictly
/// more than half its span, one notch stricter than the general absorb
/// penalty.
class First extends Composite {
  First(super.source, this.subClauses);
  final List<Clause> subClauses;

  // Plainly the first match wins, and nothing after it is consulted.
  @override
  _Reading? proposePlain(Squirrel e, int pos) {
    for (var i = 0; i < subClauses.length; i++) {
      final r = subClauses[i].plainReading(e, pos);
      if (r != null) {
        return r._packed(
            _node(source, pos, [r.piece as lib.MatchResult]), _chosen);
      }
    }
    return null;
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final out = <_Reading>[];
    var settled = false;
    for (var i = 0; i < subClauses.length; i++) {
      final rs = subClauses[i].readings(e, pos);
      for (var j = 0; j < rs.length; j++) {
        final r = rs[j];
        if (settled && !r.clean && r.absorbed(pos) >= r.evidence) continue;
        // A later alternative under a settled choice loses its "parser's
        // own choice" status here.
        out.add((settled ? r.demoted : r).labeled(source, pos));
      }
      settled = settled || Squirrel._preferredOf(rs) != null;
      // Plainly the first match wins: with no budget, a later
      // alternative could only offer what a settled choice refuses.
      if (settled && e._budget == 0) break;
    }
    return out;
  }

  @override
  bool computeOneShape() => false;

  @override
  int computeMinChars(Set<Clause> path) {
    var least = _impossible;
    for (final sub in subClauses) {
      final n = sub.minChars(path);
      if (n < least) least = n;
    }
    return least;
  }
}

/// A repetition (the grammar's `*` or `+`).
///
/// Repairs are found by a reachability sweep: starting from the empty
/// reading, repeatedly extend by one occurrence of the body, keeping the
/// best reading per end position, until nothing improves. (Running the
/// repetition through the general memoized fixed point instead was
/// measured much slower, with no accuracy change: the general loop
/// re-proposes everything on every pass, where this sweep only extends
/// what moved.) A `+` that matched nothing at all still owes one
/// occurrence; the body's own "it was missing" readings supply that.
class Repetition extends Composite {
  Repetition(super.source, this.subClause, this.requireOne);
  final Clause subClause;
  final bool requireOne;

  // Plainly: greedy munch, stopping at the first non-match or the first
  // occurrence that consumes nothing.
  @override
  _Reading? proposePlain(Squirrel e, int pos) {
    final kids = <lib.MatchResult>[];
    var p = pos, evidence = 0;
    while (true) {
      final step = subClause.plainReading(e, p);
      if (step == null || step.end <= p) break;
      kids.add(step.piece as lib.MatchResult);
      evidence += step.evidence;
      p = step.end;
    }
    if (kids.isEmpty && requireOne) return null;
    return _Reading(p, 0, 0, evidence, _chosen,
        piece: _node(source, pos, kids));
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final zero = _Reading.empty(pos);
    // A throwaway cell judges the sweep, with the plain parse's own tie
    // rule (incumbent wins): re-deriving an equal reading is the same
    // answer re-spelled, and treating it as "no change" is what
    // terminates the sweep. [add]'s answer drives the worklist.
    final best = _RepairCell(pos, plainCell: true);
    if (!requireOne) best.add(zero);
    var moved = <_Reading>[zero];
    while (moved.isNotEmpty) {
      // The readings that changed this round, best-per-end in
      // first-change order; each gets re-extended next round.
      final changed = <_Reading>[];
      for (var i = 0; i < moved.length; i++) {
        final r = moved[i];
        final steps = subClause.readings(e, r.end);
        for (var j = 0; j < steps.length; j++) {
          final step = steps[j];
          if (step.end <= r.end) continue;
          final longer = r.then(step);
          if (!best.add(longer)) continue;
          var seen = false;
          for (var k = 0; k < changed.length; k++) {
            if (changed[k].end == longer.end) {
              changed[k] = longer;
              seen = true;
              break;
            }
          }
          if (!seen) changed.add(longer);
        }
      }
      moved = changed;
    }
    final all = best._best;
    if (all.isEmpty) {
      // A `+` with nothing at all: take the body's own zero-width
      // "missing" readings as the one owed occurrence.
      final steps = subClause.readings(e, pos);
      for (var j = 0; j < steps.length; j++) {
        if (steps[j].end != pos) continue;
        all.add(zero.then(steps[j]).demoted);
      }
    }
    return [for (final r in e._bestPerEnd(all, pos)) r.labeled(source, pos)];
  }

  @override
  bool computeOneShape() => requireOne && subClause.hasOneShape();

  @override
  int computeMinChars(Set<Clause> path) =>
      requireOne ? subClause.minChars(path) : 0;
}

/// An optional part (the grammar's `?`): its child, or nothing. The
/// empty alternative keeps its "parser's own choice" status only if the
/// child cannot match plainly -- the plain parser always takes the child
/// when it can.
class Optional extends Composite {
  Optional(super.source, this.subClause);
  final Clause subClause;

  // Plainly: the child when it matches, else nothing.
  @override
  _Reading? proposePlain(Squirrel e, int pos) {
    final r = subClause.plainReading(e, pos);
    return r == null
        ? _Reading.empty(pos).withTree(lib.Match(source, pos, 0), _chosen)
        : r._packed(_node(source, pos, [r.piece as lib.MatchResult]), _chosen);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final rs = subClause.readings(e, pos);
    final out = <_Reading>[
      _Reading.empty(pos).withTree(lib.Match(source, pos, 0),
          Squirrel._preferredOf(rs) != null ? _clean : _chosen)
    ];
    for (var i = 0; i < rs.length; i++) {
      out.add(rs[i].labeled(source, pos));
    }
    return out;
  }

  @override
  bool computeOneShape() => false;

  @override
  int computeMinChars(Set<Clause> path) => 0;
}

/// A lookahead: positive (`&X`, [expectMatch] true) or negative (`!X`,
/// false). Succeeds or fails without consuming anything. No repair may
/// live inside one -- input a lookahead "accepted" would be input the
/// parse then refuses to consume -- so its answer is simply whether any
/// repair-free reading of its child exists. (It still gets a memo cell
/// like other composites: that cell is also the only cache over the
/// child's work here, and removing it was measured to re-run that work
/// far too often.)
class Lookahead extends Composite {
  Lookahead(super.source, this.subClause, this.expectMatch);
  final Clause subClause;
  final bool expectMatch;

  // Plainly, "does the child match" IS the child's plain answer: in the
  // plain parse every serve is at most one preferred reading, so clean
  // and preferred coincide.
  @override
  _Reading? proposePlain(Squirrel e, int pos) =>
      expectMatch == (subClause.plainReading(e, pos) != null)
          ? _Reading.empty(pos).withTree(lib.Match(source, pos, 0))
          : null;

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    return expectMatch == Squirrel._anyClean(subClause.readings(e, pos))
        ? [_Reading.empty(pos).withTree(lib.Match(source, pos, 0))]
        : const [];
  }

  @override
  bool computeOneShape() => true;

  @override
  int computeMinChars(Set<Clause> path) => 0;
}

/// A named grammar rule: a name, and the body all references share. The
/// left-recursion machinery lives on the body's own repair cells (see
/// Squirrel._grow); the rule itself keeps only the budget-zero wrap
/// cache -- see RuleRef.findReadings.
class Rule {
  Rule(this.name);
  final String name;
  late Clause body;

  /// Per position: a content key for the body's budget-zero answer the
  /// wraps were built over (see RuleRef.findReadings for what it is per
  /// body kind; identity says whether the wraps are still current), and
  /// the two wraps themselves -- one for consults INSIDE a budget-zero
  /// descent, one for consults that CROSSED to zero from a costed frame.
  /// Two, not one, because each is shared under its own first-asker
  /// label.
  List<(Object?, List<_Reading>?, List<_Reading>?)?>? _plainWraps;
  int _plainWrapsRun = -1;

  List<(Object?, List<_Reading>?, List<_Reading>?)?> plainWraps(Squirrel e) {
    if (_plainWrapsRun != e._runId) {
      _plainWraps = List<(Object?, List<_Reading>?, List<_Reading>?)?>.filled(
          e._len + 2, null);
      _plainWrapsRun = e._runId;
    }
    return _plainWraps!;
  }
}

/// A reference to a named rule -- the place where a rule's readings get
/// the rule's name wrapped around them.
class RuleRef extends Clause {
  RuleRef(super.source, this.rule);
  final Rule rule;

  String get ruleName => rule.name;

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    // WITH NO BUDGET LEFT, REPAIR IS PARSING. A reading that has spent
    // all its edits can only continue by reading the input exactly as it
    // stands -- the body's budget-zero answer (its one PREFERRED
    // reading), wrapped in the rule's name. The wrap is cached per
    // (rule, position), keyed by the identity of the body's served list
    // -- stable exactly while that serve is the frozen one -- and shared
    // by every reference to the rule, so a tree node's label object is
    // the same whichever reference asked (first asker wins). TWO wraps,
    // because a rule node is reached two ways with different first
    // askers: INSIDE a budget-zero descent (the plain parse of some
    // larger construct, from round zero on), or at the CROSSING where a
    // costed frame's remaining budget first hits zero (a spent chain's
    // next slot, a delete-ahead probe). Both wrap the same served tree.
    if (e._isPlainConsult(pos)) {
      final wraps = rule.plainWraps(e);
      // The body's zero answer: the frozen serve if there is one, else a
      // live consult (which creates and fills the body twin).
      var c = rule.body.cellAt(e, pos);
      final raw = c?.plainServe ?? rule.body.readings(e, pos);
      // The consult above may have just created the cell.
      c ??= rule.body.cellAt(e, pos);
      // The content key: the wraps are current exactly while the answer
      // they packaged may still be served. For a composite body that is
      // the body twin's view, whose object identity changes exactly when
      // the twin's content may have -- and which, unlike the served list,
      // is stable across the freeze (the freeze re-packages, it does not
      // change content). A terminal body's answer is a fact of the input:
      // null, never stale. A body that is itself a reference serves the
      // inner rule's wrap, already view-keyed one level down: the list
      // itself is the key.
      final Object? key =
          c != null ? c.plainTwin?._view : (rule.body is RuleRef ? raw : null);
      final have = wraps[pos];
      final current = have != null && identical(have.$1, key);
      if (current) {
        final out = e._inPlainFill ? have.$2 : have.$3;
        if (out != null) return out;
      }
      final r = Squirrel._preferredOf(raw);
      final out = r == null
          ? const <_Reading>[]
          : [
              r._packed(
                  lib.Match(source, 0, 0,
                      subClauseMatches: [r.piece as lib.MatchResult]),
                  _chosen)
            ];
      // Stored even mid-growth: the key retires it the moment the body's
      // answer can change again, exactly as the plain parser drops its
      // packagings on every tree change -- so the wrap that survives is
      // the one built by the confirmation pass's first asker. A stale
      // record drops BOTH sides: each is rebuilt on its next ask, under
      // that asker's label.
      wraps[pos] = e._inPlainFill
          ? (key, out, current ? have.$3 : null)
          : (key, current ? have.$2 : null, out);
      return out;
    }
    // Wrap the rule's name around the body's readings. One filter: a
    // repaired reading that consumed input yet proved NONE of it (no
    // evidence) is an invention that explains nothing, and is refused --
    // unless the rule has only one possible shape (then "it was missing"
    // is unambiguous), or the reading consumed nothing (a pure "missing"
    // marker, which is honest).
    //
    // The wrapped list is cached on the body's own cell, keyed by the
    // IDENTITY of the body's view (which changes exactly when the cell
    // does), and shared by every reference to the rule -- as the plain
    // [cleanReading] already is. Only full-budget views are used as
    // keys; a budget-filtered view is a fresh list every time and could
    // never match again.
    final raw = rule.body.readings(e, pos);
    final cell = rule.body.cellAt(e, pos);
    final cacheable = cell != null && identical(cell._view, raw);
    if (cacheable && identical(cell.refSrc, raw)) return cell.refView!;
    final out = <_Reading>[
      for (final r in raw)
        if (r.evidence > 0 || r.clean || r.end == pos || hasOneShape())
          r.labeled(source, pos)
    ];
    if (cacheable) {
      cell.refSrc = raw;
      cell.refView = out;
    }
    return out;
  }

  @override
  bool computeOneShape() => rule.body.hasOneShape();

  @override
  int computeMinChars(Set<Clause> path) => rule.body.minChars(path);

  /// Whether this reference points back into a rule whose repair cell is
  /// being computed right now -- i.e. this is the left-recursive re-entry
  /// itself. Used by _readSlots to exempt the seed from the penalty rule.
  bool isGrowingAt(Squirrel e, int pos) =>
      rule.body.cellAt(e, pos)?.inRecPath ?? false;
}

/// A terminal: matches characters directly. If it cannot match, it can
/// instead be recorded as MISSING -- a zero-length SyntaxError in the
/// tree that says "the grammar required this here and the input did not
/// have it". Nothing is invented: the tree records the absence, never a
/// made-up character.
///
/// One class covers every kind: a literal ([text] non-null -- the empty
/// string, one exact character, or a multi-character string) or a
/// character class ([text] null -- [ranges], possibly [inverted]; no
/// ranges inverted is the wildcard `.`).
///
/// A multi-character literal that fails to match whole is treated as a
/// SEQUENCE of its characters ([chars]) and run through the general slot
/// machinery: that yields partial prefixes ("tru" + one missing),
/// deletions inside it, and the replace repair (wrong character deleted
/// AND right one recorded missing) with no special alignment code.
/// (Giving literals their own memo cells was measured: identical
/// results, a quarter slower -- the cell ceremony on every literal that
/// MATCHES costs more than caching the failures saves.)
class Terminal extends Clause {
  Terminal(super.source, String this.text)
      : ranges = const [],
        inverted = false,
        chars = text.length > 1
            ? [for (final s in text.split('')) Terminal(lib.Char(s), s)]
            : const [];
  Terminal.set(super.source, this.ranges, this.inverted)
      : text = null,
        chars = const [];
  final String? text;
  final List<(int, int)> ranges;
  final bool inverted;
  final List<Clause> chars;

  /// Whether this terminal only accepts specific characters (a literal,
  /// an exact character, a non-inverted class). Picky matches are the
  /// evidence a reading carries; an inverted class accepts almost
  /// anything and a wildcard everything, so their matches prove nothing
  /// about the input fitting the grammar.
  bool get picky => text != null || !inverted;

  lib.MatchResult? match(Squirrel e, int pos) {
    final t = text;
    if (t != null) {
      if (pos + t.length > e._len) return null;
      for (var i = 0; i < t.length; i++) {
        if (e._input.codeUnitAt(pos + i) != t.codeUnitAt(i)) return null;
      }
      return lib.Match(source, pos, t.length);
    }
    if (pos >= e._len) return null;
    final c = e._input.codeUnitAt(pos);
    var inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }
    return inSet != inverted ? lib.Match(source, pos, 1) : null;
  }

  @override
  _Reading? cleanReading(Squirrel e, int pos) {
    final m = match(e, pos);
    return m == null
        ? null
        : _Reading(pos + m.len, 0, 0, picky ? m.len : 0, _chosen, piece: m);
  }

  // A terminal's plain answer never depends on the budget, so it is the
  // same direct character test.
  @override
  _Reading? plainReading(Squirrel e, int pos) => cleanReading(e, pos);

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    final r = cleanReading(e, pos);
    if (r != null) return [r];
    // A "missing" reading at the very end of the input is offered even
    // with no budget left: it belongs to the single end-of-input charge
    // (see _Reading.cost), which the budget never pays locally. Without
    // this, a truncated document's completion would die at its second
    // missing piece.
    if (e._budget < 1 && pos < e._len) return const [];
    // Record the terminal as missing; a multi-character literal instead
    // runs its characters as slots.
    if (chars.isNotEmpty) {
      return e._bestPerEnd(
          e._readSlots(chars, source, pos, insideLiteral: true), pos);
    }
    final atEnd = pos == e._len;
    return [
      _Reading(pos, 0, atEnd ? 0 : 1, 0, pos,
          missingAtEnd: atEnd ? 1 : 0,
          endsIncomplete: true,
          piece: lib.Match(source, pos, 0,
              subClauseMatches: [lib.SyntaxError(pos: pos, len: 0)]))
    ];
  }

  @override
  bool computeOneShape() => true;

  @override
  int computeMinChars(Set<Clause> path) => text?.length ?? 1;
}

// ---------------------------------------------------------------------------
// The engine.
// ---------------------------------------------------------------------------

class Squirrel {
  /// [rules] must already be in this engine's clause classes; the harness
  /// file _convert.dart builds them from the library's grammar AST.
  Squirrel({required this.rules, required this.topRuleName}) {
    _topRule = rules[topRuleName]!;
    for (final r in rules.values) {
      final b = r.body;
      if (b is Composite) b.isRuleBody = true;
    }
  }

  final Map<String, Rule> rules;
  final String topRuleName;
  late final Rule _topRule;

  /// The input being parsed and its length.
  String _input = '';
  int _len = 0;

  /// Bumped once per [recover] call; clause-held memo arrays compare
  /// their stamp against it, so starting a new input resets everything
  /// without walking the grammar.
  int _runId = 0;

  /// Per-position version counters for left-recursion growth. Bumping a
  /// position's counter is how a growth pass tells memo entries computed
  /// against the half-grown seed to answer again (see _grow). One clock
  /// for both the plain and the costed stores: they are disjoint, so a
  /// bump from the other side can at worst force a refill that
  /// re-derives the same content.
  List<int> _versions = const [];

  /// Set when the reading of a growing cell's seed happens; every
  /// computation on the call stack at that moment depends on the seed and
  /// must not be trusted across growth passes. Saved and restored around
  /// each cell computation, which records it as the cell's
  /// [_RepairCell.usedSeed].
  bool _seedWasRead = false;

  /// True while a composite's cell is being filled at budget zero: every
  /// consult below is part of some construct's plain parse, as opposed to
  /// the crossing where a costed frame first ran out of budget. Rule
  /// wraps are shared separately per side (see RuleRef.findReadings).
  bool _inPlainFill = false;

  /// True inside [Clause.cleanReading]: a delete-ahead probe's whole
  /// descent is a plain parse. Read only by [_isPlainConsult], and only
  /// at the input's end -- with input left, being at budget zero already
  /// says so.
  bool _probing = false;

  /// Whether a budget-zero consult at [pos] belongs to the plain parse.
  /// With input left, every one does: repair is parsing, and the consult
  /// diverts into the plain parse. At the input's end only a consult
  /// already parsing plainly (a twin fill, a probe's descent) stays
  /// there; a spent chain's ask at the end is answered by the repair
  /// machinery like any costed ask, there being nothing left to parse
  /// plainly.
  bool _isPlainConsult(int pos) =>
      _budget == 0 && (pos < _len || _inPlainFill || _probing);

  /// The current round's repair budget (see [recover]).
  int _budget = 0;

  /// Cached: the shortest document the grammar accepts (bounds the search).
  int? _minDocLen;

  /// The repair bill of the last [recover] run (0 for a clean parse).
  /// Deletions count per character; missing pieces count per piece;
  /// the end-of-input cut-off counts each stranded piece here (this is
  /// the tree's own error count, unlike [_Reading.cost]'s single charge).
  int lastCost = 0;

  /// Which of two readings is better (negative = [a] wins). Five
  /// tie-breakers, in order:
  ///
  ///   1. Lower total charge: repair cost, plus penalties, plus the
  ///      absorb penalty judged from the comparing cell's position.
  ///   2. The plain parser's own reading beats any rival.
  ///   3. More evidence: the reading that PROVED more characters.
  ///   4. Later first doubt: the reading that stayed faithful longer.
  ///   5. Fewer pieces stranded at the end of the input. (Tie-breaker 1
  ///      charges the cut-off only once however big it is, so this is
  ///      where "missing two things" still beats "missing five".)
  static int _compare(_Reading a, _Reading b, int pos) {
    final chargeA = a.cost + a.penalties + a.absorbPenalty(pos),
        chargeB = b.cost + b.penalties + b.absorbPenalty(pos);
    if (chargeA != chargeB) return chargeA - chargeB;
    if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
    if (a.evidence != b.evidence) return b.evidence - a.evidence;
    if (a.firstDoubt != b.firstDoubt) return b.firstDoubt - a.firstDoubt;
    return a.missingAtEnd - b.missingAtEnd;
  }

  /// The parser's own choice among [rs]: the one reading that kept its
  /// PREFERRED status (a served view holds at most one), or null. At
  /// budget zero this IS the plain parse's answer.
  static _Reading? _preferredOf(List<_Reading> rs) {
    for (var i = 0; i < rs.length; i++) {
      if (rs[i].preferred) return rs[i];
    }
    return null;
  }

  /// Whether any reading in [rs] is repair-free.
  static bool _anyClean(List<_Reading> rs) {
    for (var i = 0; i < rs.length; i++) {
      if (rs[i].clean) return true;
    }
    return false;
  }

  /// [rs] with every preferred reading except the FARTHEST-reaching one
  /// demoted. The plain parser, being greedy, would have chosen only that
  /// one; shorter clean readings are real alternatives but must not claim
  /// to be the parser's own choice. This is applied wherever readings
  /// from different sources meet: a cell's view as it is built, and a
  /// slot walk's survivors between and after slots.
  static List<_Reading> _greedyOnly(List<_Reading> rs) {
    var farthest = -1;
    for (var i = 0; i < rs.length; i++) {
      final v = rs[i];
      if (v.preferred && v.end > farthest) farthest = v.end;
    }
    return [
      for (final v in rs) v.preferred && v.end != farthest ? v.demoted : v
    ];
  }

  /// Offer [r] to the best-per-end list [best]: the same judging as
  /// [_RepairCell.add] in the repair search (a challenger replaces the
  /// holder unless strictly worse -- ties go to the newcomer), without a
  /// cell around it: this runs once per candidate offer, and the cell's
  /// bookkeeping was measured to cost real time here.
  static void _keepBest(List<_Reading> best, _Reading r, int pos) {
    final end = r.end;
    for (var i = 0; i < best.length; i++) {
      if (best[i].end != end) continue;
      if (_compare(r, best[i], pos) <= 0) best[i] = r;
      return;
    }
    best.add(r);
  }

  /// Keep only the best reading per end position (a throwaway
  /// [_RepairCell] does the judging).
  List<_Reading> _bestPerEnd(List<_Reading> rs, int pos) {
    if (rs.length <= 1) return rs;
    final cell = _RepairCell(pos);
    for (var i = 0; i < rs.length; i++) {
      cell.add(rs[i]);
    }
    return cell.readings();
  }

  /// Fill in (or reuse) a composite clause's repair cell at [pos] -- the
  /// squirrel left-recursion algorithm, applied to priced readings:
  ///
  ///   - Re-entry into a cell being computed is the seed of a
  ///     left-recursive cycle. It is answered with the cell's current
  ///     contents, UNFILTERED by budget -- the growth about to happen
  ///     must see the seed's repair-carrying readings to build on them.
  ///   - The owner keeps re-running [Composite.proposeReadings] until a
  ///     pass improves nothing; each pass bumps the position's version.
  ///   - A cell is trusted only at its stamped budget and, if its
  ///     computation ever read a growing seed ([usedSeed]), its stamped
  ///     version. A cell that read no seed cannot be stale, no matter
  ///     what grew: everything else it read is indexed by position, and
  ///     growth only ever changes the growing cell itself.
  List<_Reading> _grow(Composite clause, int pos) {
    final plain = _isPlainConsult(pos);
    final home = clause.cells(this)[pos] ??= _RepairCell(pos);
    // A budget-zero consult of a growing COSTED cell takes that cell's
    // seed only when it CROSSED from a costed frame straight into a
    // growing inline cell: a spent chain re-entering mid-costed-growth is
    // part of that growth, not a fresh plain parse. The plain parse
    // proper is independent of costed growth -- a rule body reached
    // through the divert, or anything consulted from inside a twin fill
    // [_inPlainFill], computes its plain answer in the twin as if no search
    // were running.
    final crossSeed =
        home.inRecPath && !(plain && (_inPlainFill || clause.isRuleBody));
    // THE PLAIN PARSE OWNS ITS OWN STORE. At budget zero this descent IS
    // the plain parse; it fills and reads the cell's twin, so the plain
    // parse and the repair search never share a store. Fill order and
    // who-asked-first are both observable (label sharing follows the
    // view), and a plain answer carved from a costed store would wear
    // the costed search's labels.
    final cell = plain && !crossSeed
        ? (home.plainTwin ??= _RepairCell(pos, plainCell: true))
        : home;
    if (cell.inRecPath) {
      // Re-entered while being computed (the crossing above, or either
      // side's own cycle): the left-recursive seed. It is read RAW -- no
      // budget filter -- because the growth about to happen must see the
      // seed's repair-carrying readings to build on them. Reading a seed
      // also marks every computation currently on the stack as
      // seed-dependent (see [_seedWasRead]).
      cell.foundLeftRec = true;
      _seedWasRead = true;
      return cell.readings();
    }
    // TWO STAMPS, DIFFERENT SHAPES. [atBudget] is a lazy WATERMARK,
    // compared with >=: the champion map is filled only as deep as anyone
    // has actually needed this round, and a cell filled at a bigger
    // budget serves every smaller query through the read-time filter.
    // (Filling every cell at the round's full budget instead -- which
    // would also make cell content independent of who asked first -- was
    // measured 1.6x slower: most cells are only ever reached by readings
    // that have already spent most of the budget, and the laziness of
    // never exploring deeper than asked is where that time goes.)
    // [memoVersion] is a per-position EQUALITY stamp consulted only by
    // cells whose computation read a growing seed: a cell that read no
    // seed cannot be stale, whatever grew, and unscoping the version
    // check was measured 13% slower. One clock serves both stores: a
    // bump from the other side can only force a refill that re-derives
    // the same content (the plain parse is deterministic, and a plain
    // cell keeps its incumbent on ties), so nothing observable moves.
    if (!(cell.atBudget >= _budget &&
        (!cell.usedSeed || cell.memoVersion == _versions[pos]))) {
      cell.inRecPath = true;
      final outer = _seedWasRead;
      final outerFill = _inPlainFill;
      _seedWasRead = false;
      // A twin fill is plain-parse territory: every consult below it
      // belongs to the plain parse (see [_inPlainFill]).
      if (!identical(cell, home)) _inPlainFill = true;
      do {
        var improved = false;
        // A plain consult fills with the plain parse (crossSeed never
        // fills: a growing home returned its seed above), a costed
        // consult with the repair search; the cell judges both the same.
        if (plain) {
          final r = clause.proposePlain(this, pos);
          if (r != null && cell.add(r)) improved = true;
        } else {
          final proposed = clause.proposeReadings(this, pos);
          for (var i = 0; i < proposed.length; i++) {
            if (cell.add(proposed[i])) improved = true;
          }
        }
        if (!improved || !cell.foundLeftRec) break;
        cell.memoVersion = ++_versions[pos];
      } while (true);
      cell.usedSeed = _seedWasRead;
      _seedWasRead = outer || _seedWasRead;
      _inPlainFill = outerFill;
      cell.inRecPath = false;
      cell.atBudget = _budget;
      cell.memoVersion = _versions[pos];
    }
    // WITH NO BUDGET LEFT, REPAIR IS PARSING: a twin serves its one
    // PREFERRED reading -- the plain parser's own greedy choice,
    // demotion having stripped that status from every reading the plain
    // parser would not produce -- alone, as a concrete tree. Frozen (on
    // the home cell, where the next consult finds it) once no live seed
    // could still change it (see [_RepairCell.plainServe]).
    if (!identical(cell, home)) {
      final out = home.plainServe ?? _plainServeOf(cell);
      if (!cell.usedSeed || !_seedWasRead) home.plainServe ??= out;
      return out;
    }
    return cell.readings(_budget);
  }

  /// The budget-zero serve for a filled cell: its one preferred reading,
  /// alone. It is served as stored: a plain proposal already carries
  /// its finished tree (see Composite), so there is nothing to translate.
  List<_Reading> _plainServeOf(_RepairCell cell) {
    final r = _preferredOf(cell.readings(0));
    return r == null ? const [] : [r];
  }

  /// Read a list of slots in order -- the engine of both sequences and
  /// failing literals, and the place all repairs enter. For each partial
  /// reading and each next slot, three things are tried:
  ///
  ///   1. USE the slot's own readings (clean or repaired) as the next
  ///      step. A slot that cannot match contributes its "missing"
  ///      readings here, so obligations flow through automatically.
  ///   2. DELETE AHEAD: if the slot cannot match cleanly where it
  ///      stands, skip characters -- charged one each -- up to the FIRST
  ///      position where the plain parser can read the slot, and reuse
  ///      that finished parse whole. (Only as far as the budget allows.)
  ///   3. REPLACE, inside literals only: delete exactly one character
  ///      and also record the expected one missing, so "i\"" can be read
  ///      as the literal "if" for a cost of two. Offering this at every
  ///      slot was measured twice: it fixed nothing new and doubled the
  ///      run time.
  ///
  /// THE PENALTY RULE. When deleting ahead was possible (some real input
  /// would have satisfied the slot for k deletions), a rival that instead
  /// stands still and declares the slot missing -- while offering no
  /// evidence, with as many missing pieces as the deletion cost -- gets
  /// one penalty point. Preferring "this text is noise" over "something
  /// unknowable was missing" at equal price is what makes the engine
  /// delete a stray comma rather than claim some value was omitted
  /// before it. Two exemptions: a slot with only one possible shape (its
  /// absence is unambiguous, nothing unknowable about it), and the
  /// left-recursive seed (its "missing" reading is the anchor the growth
  /// pass builds the whole spine on; penalizing it kills the growth).
  ///
  /// After each slot, only the best reading per end position survives --
  /// that pruning is what keeps this whole search polynomial.
  List<_Reading> _readSlots(List<Clause> slots, lib.Clause? label, int pos,
      {bool insideLiteral = false}) {
    // The fold state is a throwaway cell: extensions are judged as they
    // are produced, never collected first. Demotion of non-farthest
    // preferred readings happens on read instead ([_greedyOnly]): same
    // objects, same order.
    var cur = <_Reading>[_Reading.empty(pos)];
    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final next = <_Reading>[];
      var farthest = -1;
      for (var i = 0; i < cur.length; i++) {
        final v = cur[i];
        if (v.preferred && v.end > farthest) farthest = v.end;
      }
      for (var i = 0; i < cur.length; i++) {
        final v = cur[i];
        final r = v.preferred && v.end != farthest ? v.demoted : v;
        if (r.spent > _budget) continue;
        // Hand the slot only the budget this reading has not spent.
        final whole = _budget;
        _budget = whole - r.spent;
        final options = slot.readings(this, r.end);
        _budget = whole;
        final cleanHere = _anyClean(options);
        var deletedAhead = -1;
        if (!cleanHere) {
          final room = _budget - r.cost;
          for (var j = r.end + 1; j <= r.end + room && j <= _len; j++) {
            final parsed = slot.cleanReading(this, j);
            if (parsed == null) continue;
            _keepBest(
                next, r.then(_Reading.deleting(r.end, j)).then(parsed), pos);
            deletedAhead = j - r.end;
            break;
          }
        }
        final seed = slot is RuleRef && slot.isGrowingAt(this, r.end);
        final penalize = deletedAhead > 0 && !seed && !slot.hasOneShape();
        for (var k = 0; k < options.length; k++) {
          final o = options[k];
          _keepBest(
              next,
              r.then(penalize &&
                      o.end == r.end &&
                      !o.clean &&
                      deletedAhead <= o.missing
                  ? o.penalized()
                  : o),
              pos);
        }
        if (insideLiteral && !cleanHere && r.end < _len) {
          final replaced = r.then(_Reading.deleting(r.end, r.end + 1));
          final more = slot.readings(this, r.end + 1);
          for (var k = 0; k < more.length; k++) {
            _keepBest(next, replaced.then(more[k]), pos);
          }
        }
      }
      if (next.isEmpty) return const [];
      cur = next;
    }
    return [
      for (final r in _greedyOnly(cur))
        label == null ? r : r.labeled(label, pos)
    ];
  }

  /// Turn one piece into a tree node. A _Labeled piece walks its chain
  /// (backwards, then reversed) and puts the construct's name on -- with
  /// one exception: a construct that matched NOTHING at the very end of
  /// the input loses its name. The input never reached it, so claiming
  /// "an X was here" would be an invention; the bare marker suffices.
  /// Mid-document, the name is kept: the surroundings prove which
  /// construct it was. [keepAll] keeps every name: the budget-zero serve
  /// is the plain parser's own tree, and the plain parser names whatever
  /// it matched, zero-width at the end of the input or not.
  lib.MatchResult _treeOf(Object piece, int end, {bool keepAll = false}) {
    if (piece is lib.MatchResult) return piece;
    final l = piece as _Labeled;
    final kids = <lib.MatchResult>[];
    for (_Reading? r = l.inner; r != null; r = r.prev) {
      if (r.piece != null) kids.add(_treeOf(r.piece!, r.end, keepAll: keepAll));
    }
    final name = !keepAll && end == l.from && l.from >= _len ? null : l.label;
    return kids.isEmpty
        ? lib.Match(name, l.from, end - l.from)
        : lib.Match(name, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  /// The winner's tree. Only the winning reading is ever materialized;
  /// during the search, readings stay as chains (building trees for
  /// every candidate was measured 20-31% slower).
  lib.MatchResult _buildTree(_Reading r) {
    if (r.prev == null && r.piece != null) return _treeOf(r.piece!, r.end);
    final kids = <lib.MatchResult>[];
    for (_Reading? p = r; p != null; p = p.prev) {
      if (p.piece != null) kids.add(_treeOf(p.piece!, p.end));
    }
    return kids.length == 1
        ? kids.single
        : lib.Match(null, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  // -- the entry point -------------------------------------------------------

  /// Parse [s], repairing if needed, and return the best complete tree.
  lib.MatchResult recover(String s) {
    _input = s;
    _len = s.length;
    _runId++;
    _versions = List<int>.filled(_len + 2, 0);
    // Round zero: the plain parse -- the same descent, run with nothing
    // to spend. If its preferred reading explains the whole input, done.
    _budget = 0;
    _inPlainFill = false;
    final plain = _topRule.body.plainReading(this, 0);
    if (plain != null && plain.end == _len) {
      lastCost = 0;
      return _treeOf(plain.piece!, plain.end, keepAll: true);
    }
    // Otherwise, search with a rising repair budget. No repair can need
    // more than deleting the whole input and providing the shortest
    // document, so that bounds the ladder ([-1] = grammar accepts
    // nothing at all).
    final shortest = _minDocLen ??= _topRule.body.minChars(<Clause>{});
    final ceiling = shortest >= _impossible ? -1 : s.length + shortest;
    _Reading? best, fallback;
    for (_budget = 1; _budget <= ceiling; _budget++) {
      final incomplete = <_Reading>[];
      final roots = _topRule.body.readings(this, 0);
      for (var ri = 0; ri < roots.length; ri++) {
        final r = roots[ri];
        // A reading that stops short of the end is charged for the
        // unread tail exactly like any other deletion, through the
        // ordinary step mechanism -- no special case; the tail's
        // SyntaxError reaches the tree like every other one.
        final tail = s.length - r.end;
        final whole = tail == 0 ? r : r.then(_Reading.deleting(r.end, _len));
        if (whole.cost + whole.penalties + whole.absorbPenalty(0) > _budget) {
          continue;
        }
        if (whole.firstDoubt == _clean) continue;
        if (tail > 0 && r.endsIncomplete) {
          // It stopped mid-thought with input still ahead: incoherent as
          // a story about the document. Held aside rather than discarded:
          incomplete.add(whole);
          continue;
        }
        if (best == null || _compare(whole, best, 0) < 0) best = whole;
      }
      // An incomplete reading may still displace the winner, but only if
      // it costs no more AND proves strictly more of the input. (This is
      // what lets "an unfinished real construct plus noise" beat "a
      // dubious construct that happens to swallow everything".)
      if (best != null) {
        final b = best;
        var top = b;
        for (final r in incomplete) {
          if (r.cost + r.penalties + r.absorbPenalty(0) <=
                  b.cost + b.penalties + b.absorbPenalty(0) &&
              r.evidence > top.evidence) {
            top = r;
          }
        }
        best = top;
        break;
      }
      if (fallback == null && incomplete.isNotEmpty) {
        var f = incomplete.first;
        for (final r in incomplete) {
          if (_compare(r, f, 0) < 0) f = r;
        }
        fallback = f;
      }
    }
    best ??= fallback;
    // The reported cost is the tree's own error content by construction:
    // every deleted character and every missing piece in the winning
    // chain reaches the tree exactly once.
    lastCost = best == null
        ? s.length
        : best.deleted + best.missing + best.missingAtEnd;
    return best == null
        ? lib.SyntaxError(pos: 0, len: s.length)
        : _buildTree(best);
  }

  /// [recover], returning the repair bill instead of the tree.
  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
