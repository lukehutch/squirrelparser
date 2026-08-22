// c12.dart -- a recovery engine over the library's own grammar, in one file.
//
// WHAT THIS IS. Given the library's grammar AST (as produced by
// `MetaGrammar.parseGrammar`) and an input string, return the best complete
// parse tree the input supports -- even when the input has errors. Damage is
// reported inside the tree as SyntaxError nodes: length > 0 marks real input
// characters skipped as noise; length 0 marks a place where something
// required was missing. The engine never invents characters.
//
// WHAT c12 TAKES FROM ITS THREE PARENTS. c9, c10 and c11 each won one axis
// and lost the others; c12 is the synthesis the measurements force:
//
//   * From c11, the ARCHITECTURE: the parser library stays untouched, and
//     recovery is one separate module consuming the library's own Clause
//     objects. There is no adapter layer: the constructor takes the
//     library grammar directly, and every tree label is the caller's own
//     clause object by construction.
//   * From c9, the LATENCY: a dedicated plain parser behind the
//     "repair is parsing" divert. Measured paired and interleaved, c10's
//     one-machine plain path cost 2.23x on clean documents -- the tax is
//     per budget-zero consult, and budget-zero consults dominate the
//     search -- and reusing the library's Parser directly costs 3.16x
//     (its memo is two hash-map lookups per rule consult, and its
//     mismatches allocate frontier trees). So the plain matcher lives
//     here, as one cheap method per clause kind, bare results, memoized
//     per rule in flat arrays.
//   * From c10, the CLASS ALGEBRA: one Terminal class (a literal, an
//     exact character, a character class, the wildcard and the empty
//     match are one kind with two payloads), one Lookahead class (the
//     `&X`/`!X` polarity is a flag), and the demotion of non-farthest
//     preferred readings shared as one helper instead of three loops.
//
// HOW IT WORKS, IN ONE PARAGRAPH. The engine runs the ordinary squirrel
// parsing algorithm (a memoizing recursive-descent parser that supports
// left recursion) as its "plain parse". When the plain parse fails to
// explain the whole input, the engine re-runs the descent in a costed
// form: every grammar node returns a set of candidate READINGS -- ways its
// part of the grammar could account for the input, each carrying a repair
// bill. Candidates compete: for each (grammar node, position, end
// position) only the best-priced reading survives. The search runs in
// rounds with a rising repair budget and stops at the first budget where
// some reading explains the entire input; the winning reading becomes the
// output tree. A reading that runs out of budget mid-descent is answered
// by the plain parser outright -- repair IS parsing at budget zero, and
// that divert is where the latency lives.
//
// The design decisions inherited from the c-line were each settled by
// measurement over the mutation battery; the history and the numbers live
// in LESSONS_LEARNED.md at the repository root.
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

/// A tree node labeled [src] over [kids] ([pos] anchors an empty node).
lib.MatchResult _node(lib.Clause? src, int pos, List<lib.MatchResult> kids) =>
    kids.isEmpty
        ? lib.Match(src, pos, 0)
        : lib.Match(src, 0, 0, subClauseMatches: kids);

/// A grammar construct's name wrapped around the steps that filled it in:
/// the piece of tree that says "these children together form one <label>".
class _Labeled {
  const _Labeled(this.label, this.from, this.inner);

  /// The library clause whose name the finished tree node will carry.
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
      this.prev,
      int? lastDoubt})
      : _lastDoubt = lastDoubt;

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

  /// The input position of the LATEST repair (stored only by [then];
  /// a single-step reading's one repair is at [firstDoubt]). With
  /// [firstDoubt], this brackets where the trouble lies: between
  /// otherwise equal readings the one whose trouble is confined
  /// earliest wins -- edits clustered at the flaw beat a story that
  /// spreads a second edit into text the input got right.
  final int? _lastDoubt;
  int get lastDoubt => _lastDoubt ?? (clean ? -1 : firstDoubt);

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
      prev: this,
      lastDoubt: lastDoubt > step.lastDoubt ? lastDoubt : step.lastDoubt);

  /// This reading's totals under a single new piece (the chain, if any,
  /// is inside the piece, not behind it).
  _Reading _tagged(Object piece, int rank) =>
      _Reading(end, deleted, missing, evidence, _min(firstDoubt, rank),
          missingAtEnd: missingAtEnd,
          penalties: penalties,
          endsIncomplete: endsIncomplete,
          piece: piece,
          lastDoubt: _lastDoubt);

  /// This reading carrying a finished tree [m] as its piece (used for
  /// zero-width results such as an empty optional or a lookahead).
  _Reading withTree(lib.MatchResult m, [int rank = _chosen]) =>
      _tagged(m, rank);

  /// This reading wrapped under a construct's name, starting at [from].
  _Reading labeled(lib.Clause label, int from, [int rank = _chosen]) =>
      _tagged(_Labeled(label, from, this), rank);

  _Reading _with({int? firstDoubt, int? penalties}) =>
      _Reading(end, deleted, missing, evidence, firstDoubt ?? this.firstDoubt,
          missingAtEnd: missingAtEnd,
          penalties: penalties ?? this.penalties,
          endsIncomplete: endsIncomplete,
          piece: piece,
          prev: prev,
          lastDoubt: _lastDoubt);

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
/// in insertion order, so iteration is deterministic and no sorting is
/// ever needed.
///
/// The champion list is filled LAZILY, to the highest budget any query
/// has yet needed ([atBudget], a watermark); smaller queries are served
/// by filtering at read time ([readings]). Budget-zero queries never
/// read the champion list at all -- they get exactly the plain parser's
/// answer, cached once in [plain] (see Squirrel._grow) -- so the
/// budget-zero serve is order-independent by construction.
///
/// [atBudget] and [memoVersion] stamp when the cell was filled; the cell
/// is only trusted while both still hold (see Squirrel._grow).
/// [inRecPath] / [foundLeftRec] play the same roles as in the plain
/// parser's memo: cycle detection and the signal that a left-recursive
/// cycle needs growing.
class _RepairCell {
  _RepairCell(this.pos);
  final int pos;

  /// Best reading per end position, in first-offer order. A plain list
  /// scanned by each reading's own `end` -- the end IS the key, so a map
  /// would only duplicate it, and cells are tiny (measured over the
  /// battery: 71% of consults see at most one reading, 90% at most
  /// three), so a linear scan beats hashing.
  final List<_Reading> _best = [];
  bool inRecPath = false, foundLeftRec = false, usedSeed = false;
  int atBudget = -1, memoVersion = 0;

  /// The plain parser's answer here, computed at most once and served in
  /// a one-element list: null = not asked yet, an empty (const) list =
  /// asked and it was a mismatch, a one-element list = the match.
  List<_Reading>? plainList;

  /// The built view, cached between changes. Any budget at or above
  /// [_maxSpent] -- the most any stored reading has spent, kept
  /// conservatively high across replacements -- filters nothing, so ONE
  /// cached list serves every such query; smaller budgets (rare) build
  /// fresh. Any store invalidates it, which also gives the view a useful
  /// property: its object identity changes exactly when its content may
  /// have (see RuleRef.findReadings).
  List<_Reading>? _view;
  int _maxSpent = 0;

  /// A rule reference's filtered-and-labeled wrapping of this cell's
  /// view: valid exactly while [refSrc] is still the cell's current
  /// [_view] object (see RuleRef.findReadings).
  List<_Reading>? refSrc, refView;

  /// The composite this cell belongs to -- its [Composite.finish] names
  /// each reading as the view is built. Null only in the throwaway cells
  /// [Squirrel._bestPerEnd] makes, whose output stays nameless.
  Composite? owner;

  /// Offer a reading; keep it if it beats (or ties) the current holder of
  /// its end position. Returns true only on a strict improvement.
  bool add(_Reading r) {
    final i = Squirrel._indexOfEnd(_best, r.end);
    var cmp = -1;
    if (i < 0) {
      _best.add(r);
    } else {
      cmp = Squirrel._compare(r, _best[i], pos);
      if (cmp > 0) return false;
      // On an exact tie the NEWCOMER takes the slot. This is deliberate and
      // measured: tied readings can differ in details the comparison cannot
      // see, and the later one -- produced by a later, better-informed pass
      // -- is right more often. A tie still reports "no improvement", or
      // two tied rivals would re-trigger each other forever.
      _best[i] = r;
    }
    _view = null;
    if (r.spent > _maxSpent) _maxSpent = r.spent;
    return cmp < 0;
  }

  /// The cell's readings, filtered to what [budget] can afford, with
  /// non-farthest preferred readings demoted (see Squirrel._farthest).
  List<_Reading> readings([int budget = _unlimited]) {
    if (budget >= _maxSpent) return _view ??= _buildView(_unlimited);
    return _buildView(budget);
  }

  List<_Reading> _buildView(int budget) {
    final farthest = Squirrel._farthest(_best);
    final out = <_Reading>[];
    for (var i = 0; i < _best.length; i++) {
      final r = _best[i];
      if (r.spent > budget) continue;
      final f = r.preferred && r.end != farthest ? r.demoted : r;
      out.add(owner == null ? f : owner!.finish(f, pos));
    }
    return out;
  }
}

/// The memo cell for the plain parse: one (rule, position) entry holding
/// the parse tree (null = did not match), the same tree prepackaged as a
/// clean [_Reading] for the repair machinery, and the left-recursion
/// bookkeeping the squirrel algorithm needs. "Not computed yet" is
/// [memoVersion] == -1: a cell that has never been filled was computed
/// at no version at all, which no real version ever equals. (The repair
/// cell encodes the same fact the same way, as atBudget == -1.)
class _ParseCell {
  lib.MatchResult? tree;
  _Reading? reading;

  /// [reading] as a one-element list, built at most once (the shape the
  /// budget-zero divert serves; see RuleRef.findReadings).
  List<_Reading>? asList;

  /// [tree] wrapped for a caller, built at most once (the shape
  /// RuleRef.match returns). As with [reading], only the rule name on the
  /// wrapper's label is ever read, so all references share one wrapper.
  lib.MatchResult? wrapped;
  bool inRecPath = false, foundLeftRec = false;
  int memoVersion = -1;
}

// ---------------------------------------------------------------------------
// The grammar, as this engine's own clause classes -- built by the
// constructor from the library's grammar AST, one node per library clause,
// each keeping its source clause as the label the caller's trees carry.
// A clause's whole behavior is methods:
//
//   match(pos)         parse plainly here; null means "does not match"
//   readings(pos)      all candidate readings here, repairs included
//   cleanReading(pos)  the plain parse packaged as a single reading
//   picky / hasOneShape / minChars   small static facts, described below
// ---------------------------------------------------------------------------

abstract class Clause {
  Clause(this.source);

  /// The library clause this one was built from: the label every tree
  /// node carries, so the caller sees trees over its own grammar.
  final lib.Clause source;

  /// Parse plainly at [pos] (no repairs). Null means "does not match".
  lib.MatchResult? match(Squirrel e, int pos);

  /// All candidate readings at [pos], repairs included. The bounds guard
  /// lives here so the per-kind implementations never see an out-of-range
  /// position.
  List<_Reading> readings(Squirrel e, int pos) =>
      pos > e._len ? const [] : findReadings(e, pos);

  /// The per-kind implementation behind [readings].
  List<_Reading> findReadings(Squirrel e, int pos);

  /// The plain parse at [pos] packaged as one clean reading, or null if
  /// it does not match. This is the ONE doorway through which repair
  /// work consults the plain parser -- used when the budget is spent,
  /// and by the delete-ahead scan in _readSlots.
  _Reading? cleanReading(Squirrel e, int pos) {
    final m = match(e, pos);
    return m == null
        ? null
        : _Reading(pos + m.len, 0, 0, e._evidenceIn(m), _chosen, piece: m);
  }

  /// The repair cell at [pos], if one exists for the current input.
  /// Never allocates; only composite clauses override this.
  _RepairCell? cellAt(Squirrel e, int pos) => null;

  /// Whether this clause can produce only ONE possible tree shape,
  /// whatever input it reads. If so, "it was missing" is unambiguous --
  /// there is exactly one thing it could have been -- which matters for
  /// the penalty rule in _readSlots. Computed once and cached; a
  /// recursive cycle counts as "no". The two static facts live here as
  /// one dispatch each rather than a method per class: they run once per
  /// grammar, never per consult.
  bool? _oneShape;
  bool hasOneShape() {
    if (_oneShape != null) return _oneShape!;
    _oneShape = false; // cycle-breaker: while computing, assume "no"
    final self = this;
    return _oneShape = switch (self) {
      Seq() => self.subClauses.every((s) => s.hasOneShape()),
      Repetition() => self.requireOne && self.subClause.hasOneShape(),
      RuleRef() => self.rule.body.hasOneShape(),
      Lookahead() || Terminal() => true,
      _ => false, // First, Optional
    };
  }

  /// The fewest input characters any successful match of this clause can
  /// consume ([_impossible] if it can never match). Used only to bound
  /// the repair search: no repair can need more budget than the whole
  /// input plus the shortest possible document. Deliberately NOT cached:
  /// caching under the cycle-breaker records wrong values inside
  /// recursive grammars, and it is only computed once anyway.
  int minChars(Set<Clause> path) {
    if (!path.add(this)) return _impossible;
    final self = this;
    final v = switch (self) {
      Seq() => self.subClauses
          .fold(0, (int a, s) => _min(_impossible, a + s.minChars(path))),
      First() => self.subClauses
          .fold(_impossible, (int a, s) => _min(a, s.minChars(path))),
      Repetition() when self.requireOne => self.subClause.minChars(path),
      RuleRef() => self.rule.body.minChars(path),
      Terminal() => self.text?.length ?? 1,
      _ => 0, // Optional, Lookahead, `*`
    };
    path.remove(this);
    return v;
  }
}

/// A per-input-position memo array, remade lazily when the engine moves
/// to a new input ([Squirrel._runId] is the stamp) -- so starting a new
/// input resets every memo in the grammar by bumping one counter.
mixin _PerPos<T> {
  List<T?>? _arr;
  int _run = -1;

  List<T?> slots(Squirrel e) {
    if (_run != e._runId) {
      _arr = List<T?>.filled(e._len + 2, null);
      _run = e._runId;
    }
    return _arr!;
  }
}

/// A composite clause: its repair results are memoized in one
/// [_RepairCell] per input position, filled in by Squirrel._grow around
/// this clause's [proposeReadings].
abstract class Composite extends Clause with _PerPos<_RepairCell> {
  Composite(super.source);

  @override
  _RepairCell? cellAt(Squirrel e, int pos) =>
      _run == e._runId ? _arr![pos] : null;

  @override
  List<_Reading> findReadings(Squirrel e, int pos) => e._grow(this, pos);

  /// One pass of candidate generation for the cell at [pos]. May be run
  /// several times when a left-recursive cycle is being grown.
  List<_Reading> proposeReadings(Squirrel e, int pos);

  /// Wrap one stored reading for consumers. The kinds whose proposals
  /// are built nameless (sequence, choice, repetition) put the
  /// construct's name on HERE -- once per cell change, since the
  /// finished view is cached -- instead of on every proposal of every
  /// fill pass. The name changes no comparison key, so the cell judges
  /// raw and labeled readings identically. Optional and the lookahead
  /// override this with the identity: their proposals carry finished
  /// pieces (a zero-width tree among them) that must not be re-wrapped.
  _Reading finish(_Reading r, int pos) => r.labeled(source, pos);
}

/// A sequence: each part in order (the grammar's juxtaposition).
class Seq extends Composite {
  Seq(super.source, this.subClauses);
  final List<Clause> subClauses;

  @override
  lib.MatchResult? match(Squirrel e, int pos) {
    final kids = <lib.MatchResult>[];
    var p = pos;
    for (var i = 0; i < subClauses.length; i++) {
      final m = subClauses[i].match(e, p);
      if (m == null) return null;
      kids.add(m);
      p += m.len;
    }
    return _node(source, pos, kids);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) =>
      e._readSlots(subClauses, null, pos);
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

  @override
  lib.MatchResult? match(Squirrel e, int pos) {
    for (var i = 0; i < subClauses.length; i++) {
      final m = subClauses[i].match(e, pos);
      if (m != null) return lib.Match(source, 0, 0, subClauseMatches: [m]);
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
        // own choice" status here (the label itself goes on at the view).
        out.add(settled ? r.demoted : r);
      }
      settled = settled || Squirrel._farthest(rs) >= 0;
    }
    return out;
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
  Repetition(super.source, Clause sub, this.requireOne) : subClause = sub {
    if (!requireOne && sub is Terminal) sub.voluntary = true;
  }
  final Clause subClause;
  final bool requireOne;

  @override
  lib.MatchResult? match(Squirrel e, int pos) {
    final kids = <lib.MatchResult>[];
    var p = pos;
    while (p <= e._len) {
      final m = subClause.match(e, p);
      if (m == null) break;
      // Never take more than one zero-length body match, or a grammar
      // like ()* would loop forever.
      if (m.len == 0) break;
      kids.add(m);
      p += m.len;
    }
    if (requireOne && kids.isEmpty) return null;
    return _node(source, pos, kids);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final zero = _Reading.empty(pos);
    final best = <_Reading>[if (!requireOne) zero];
    var moved = <_Reading>[zero];
    while (moved.isNotEmpty) {
      // Indices into [best] that changed this round; an index is stable
      // (append + in-place replace only), so this is the same set, in the
      // same first-change order, as tracking end positions. Deduplicated
      // by a scan -- it is as tiny as the cells are.
      final changed = <int>[];
      for (var i = 0; i < moved.length; i++) {
        final r = moved[i];
        final steps = subClause.readings(e, r.end);
        for (var j = 0; j < steps.length; j++) {
          final step = steps[j];
          if (step.end <= r.end) continue;
          // A repetition never REQUIRES another occurrence, so it may not
          // manufacture one out of pure noise: a step that proved nothing
          // and consumed only deleted characters (a bare replace) is
          // refused. It would also mask the owed-occurrence fallback
          // below, whose zero-width reading is the left-recursive seed.
          if (step.evidence == 0 &&
              step.missing == 0 &&
              step.end - r.end == step.deleted) {
            continue;
          }
          final longer = r.then(step);
          final slot = Squirrel._indexOfEnd(best, longer.end);
          if (slot < 0) {
            best.add(longer);
            changed.add(best.length - 1); // a fresh index, never seen
          } else if (Squirrel._compare(longer, best[slot], pos) < 0) {
            best[slot] = longer;
            if (!changed.contains(slot)) changed.add(slot);
          }
        }
      }
      moved = [for (var k = 0; k < changed.length; k++) best[changed[k]]];
    }
    if (best.isEmpty) {
      // A `+` with nothing at all: take the body's own zero-width
      // "missing" readings as the one owed occurrence.
      final steps = subClause.readings(e, pos);
      for (var j = 0; j < steps.length; j++) {
        if (steps[j].end != pos) continue;
        best.add(zero.then(steps[j]).demoted);
      }
    }
    return e._bestPerEnd(best, pos);
  }
}

/// An optional part (the grammar's `?`): its child, or nothing. The
/// empty alternative keeps its "parser's own choice" status only if the
/// child cannot match plainly -- the plain parser always takes the child
/// when it can.
class Optional extends Composite {
  Optional(super.source, this.subClause);
  final Clause subClause;

  @override
  lib.MatchResult? match(Squirrel e, int pos) {
    final m = subClause.match(e, pos);
    return m == null
        ? lib.Match(source, pos, 0)
        : lib.Match(source, 0, 0, subClauseMatches: [m]);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final rs = subClause.readings(e, pos);
    return [
      _Reading.empty(pos).withTree(lib.Match(source, pos, 0),
          Squirrel._farthest(rs) >= 0 ? _clean : _chosen),
      for (var i = 0; i < rs.length; i++) rs[i].labeled(source, pos),
    ];
  }

  @override
  _Reading finish(_Reading r, int pos) => r;
}

/// A lookahead: `&X` ([expectMatch] true) or `!X` (false); succeeds or
/// fails without consuming anything. No repair may live inside one --
/// input a lookahead "accepted" would be input the parse then refuses to
/// consume -- so its answer is simply whether any repair-free reading of
/// its child exists. (It still gets a memo cell like other composites:
/// that cell is also the only cache over the child's work here, and
/// removing it was measured to re-run that work far too often.)
class Lookahead extends Composite {
  Lookahead(super.source, this.subClause, this.expectMatch);
  final Clause subClause;
  final bool expectMatch;

  @override
  lib.MatchResult? match(Squirrel e, int pos) =>
      (subClause.match(e, pos) != null) == expectMatch
          ? lib.Match(source, pos, 0)
          : null;

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) =>
      expectMatch == Squirrel._anyClean(subClause.readings(e, pos))
          ? [_Reading.empty(pos).withTree(lib.Match(source, pos, 0))]
          : const [];

  @override
  _Reading finish(_Reading r, int pos) => r;
}

/// A named grammar rule: the body all references share, plus the memo row
/// for the PLAIN parse. This is where the squirrel left-recursion
/// algorithm lives:
///
///   - If a rule re-enters itself at the same position (a left-recursive
///     cycle), the inner attempt is answered with a deliberate mismatch
///     (the SEED) and the cell is flagged.
///   - The outer attempt then re-parses the body repeatedly; each pass
///     can consume a bit more (the seed "grows") until a pass stops
///     improving.
///   - Each growth pass bumps a per-position version number. Any memo
///     entry filled in against the half-grown seed carries the old
///     version and is recomputed when next consulted, instead of serving
///     a stale answer.
class Rule with _PerPos<_ParseCell> {
  Rule(this.name);
  final String name;
  late Clause body;

  _ParseCell parseCell(Squirrel e, int pos) {
    final cell = slots(e)[pos] ??= _ParseCell();
    if (cell.memoVersion >= 0 &&
        (cell.inRecPath || cell.memoVersion == e._parseVersions[pos])) {
      return cell;
    }
    if (cell.inRecPath) {
      // Re-entered while already being computed: a left-recursive cycle.
      // Seed it with a mismatch and let the outer frame grow it. (The
      // stamp only marks the cell as filled; while inRecPath is set, the
      // hit test above never consults its value.)
      cell.foundLeftRec = true;
      cell.memoVersion = e._parseVersions[pos];
      cell.tree = null;
      return cell;
    }
    cell.inRecPath = true;
    do {
      final m = body.match(e, pos);
      // Fixed point: a match is never replaced by a mismatch, and an
      // attempt that did not consume more than the last one is no better.
      if (cell.memoVersion >= 0 &&
          (m == null || (cell.tree != null && m.len <= cell.tree!.len))) {
        break;
      }
      cell.tree = m;
      cell.reading = null; // the packaged reading is stale now
      cell.asList = null;
      cell.wrapped = null;
      if (!cell.foundLeftRec) break;
      cell.memoVersion = ++e._parseVersions[pos];
    } while (true);
    cell.inRecPath = false;
    cell.memoVersion = e._parseVersions[pos];
    return cell;
  }
}

/// A reference to a named rule -- the only clause kind that goes through
/// the plain-parse memo, and the place where a rule's readings get the
/// rule's name wrapped around them.
class RuleRef extends Clause {
  RuleRef(super.source, this.rule);
  final Rule rule;

  @override
  lib.MatchResult? match(Squirrel e, int pos) {
    if (pos > e._len) return null;
    final cell = rule.parseCell(e, pos);
    final m = cell.tree;
    if (m == null) return null;
    return cell.wrapped ??= lib.Match(source, 0, 0, subClauseMatches: [m]);
  }

  /// The rule's plain parse as a reading. Built ONCE per (rule, position)
  /// and cached in the parse cell, however many callers ask; the whole
  /// finished subtree is reused, never re-parsed. (All references to a
  /// rule share the cached reading; its tree label is whichever
  /// reference asked first, and only the rule NAME on it is ever read.)
  _Reading? _pack(Squirrel e, _ParseCell cell, int pos) {
    final m = cell.tree;
    if (m == null) return null;
    return cell.reading ??= _Reading(
        pos + m.len, 0, 0, e._evidenceIn(m), _chosen,
        piece: lib.Match(source, 0, 0, subClauseMatches: [m]));
  }

  @override
  _Reading? cleanReading(Squirrel e, int pos) =>
      pos > e._len ? null : _pack(e, rule.parseCell(e, pos), pos);

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    // WITH NO BUDGET LEFT, REPAIR IS PARSING. A reading that has spent
    // all its edits can only continue by reading the input exactly as it
    // stands -- which is precisely what the plain parser computes. So the
    // memoized plain parse answers outright: one cache lookup for the
    // whole rest of this rule, instead of a costed descent that could
    // discover nothing new anyway. (Same packaging as [cleanReading],
    // plus the served list itself is built at most once per cell.)
    if (e._budget == 0 && pos < e._len) {
      final cell = rule.parseCell(e, pos);
      final r = _pack(e, cell, pos);
      return r == null ? const [] : (cell.asList ??= [r]);
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
    // does): however many times -- and through however many references,
    // which share it, as they already share the plain [cleanReading] --
    // a rule is consulted between changes, the name is wrapped once.
    // Only full-budget views are used as keys; a budget-filtered view is
    // a fresh list every time and could never match again.
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

  /// Whether this reference points back into a rule whose repair cell is
  /// being computed right now -- i.e. this is the left-recursive re-entry
  /// itself. Used by _readSlots to exempt the seed from the penalty rule.
  bool isGrowingAt(Squirrel e, int pos) =>
      rule.body.cellAt(e, pos)?.inRecPath ?? false;
}

/// A terminal: matches characters directly. One class for every kind --
/// a literal or exact character ([text] non-null), a character class
/// ([ranges], possibly [inverted]), the wildcard `.` (empty ranges,
/// inverted -- "not in the empty set" accepts anything), and the empty
/// match (empty [text]). If it cannot match, it can instead be recorded
/// as MISSING -- a zero-length SyntaxError in the tree that says "the
/// grammar required this here and the input did not have it". Nothing is
/// invented: the tree records the absence, never a made-up character.
class Terminal extends Clause with _PerPos<Object> {
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

  /// True when this terminal is the whole body of a zero-minimum
  /// repetition (typically whitespace). Its matches count no evidence:
  /// a character the grammar accepts in any number, including none,
  /// could be consumed by EVERY reading, so consuming it distinguishes
  /// nothing -- and rewarding it lets a dishonest reading buy a tie-
  /// breaking point by rearranging edits around a space.
  bool voluntary = false;
  final List<(int, int)> ranges;
  final bool inverted;

  /// A failing multi-character literal is treated as a SEQUENCE of its
  /// characters and run through the general slot machinery: that yields
  /// partial prefixes ("tru" + one missing), deletions inside it, and
  /// the replace repair (wrong character deleted AND right one recorded
  /// missing) with no special alignment code. (Giving literals their own
  /// memo cells was measured: identical results, a quarter slower -- the
  /// cell ceremony on every literal that MATCHES costs more than caching
  /// the failures saves.)
  final List<Clause> chars;

  /// Whether this terminal only accepts specific characters (a literal,
  /// an exact character, a non-inverted class). Picky matches are the
  /// evidence a reading carries; an inverted class accepts almost
  /// anything and a wildcard everything, so their matches prove nothing
  /// about the input fitting the grammar.
  bool get picky => text != null ? text!.isNotEmpty : !inverted;

  @override
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

  /// Per-position memo of this terminal's answers, run-stamped like every
  /// other memo. A terminal's match depends only on the input characters,
  /// so both its matched reading and its "missing" reading are computed
  /// once per position and served forever after. (The budget gate below
  /// is re-applied on every consult; only the READINGS are cached.)
  /// Slot value: null = not asked; _noMatch = asked, no match; a list =
  /// the matched reading -- or, once a repair consult has been served,
  /// the cached "missing" reading, told apart by [_Reading.endsIncomplete]
  /// (a match never ends incomplete; a missing reading always does).
  static const Object _noMatch = Object();

  @override
  _Reading? cleanReading(Squirrel e, int pos) {
    final a = slots(e);
    var v = a[pos];
    if (v == null) {
      final m = match(e, pos);
      final ev = picky && !voluntary && m != null ? m.len : 0;
      v = a[pos] = m == null
          ? _noMatch
          : <_Reading>[_Reading(pos + m.len, 0, 0, ev, _chosen, piece: m)];
    }
    return v is List<_Reading> && !v[0].endsIncomplete ? v[0] : null;
  }

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    final a = slots(e);
    if (a[pos] == null) cleanReading(e, pos);
    final v = a[pos];
    if (v is List<_Reading> && !v[0].endsIncomplete) return v;
    // A "missing" reading at the very end of the input is offered even
    // with no budget left: it belongs to the single end-of-input charge
    // (see _Reading.cost), which the budget never pays locally. Without
    // this, a truncated document's completion would die at its second
    // missing piece.
    if (e._budget < 1 && pos < e._len) return const [];
    // The missing reading is positional too -- except a failing
    // multi-character literal, whose repair search depends on the budget
    // (so it is recomputed per consult and the slot stays _noMatch).
    if (chars.isNotEmpty) {
      return e._bestPerEnd(e._readSlots(chars, source, pos), pos);
    }
    return v is List<_Reading>
        ? v
        : (a[pos] = <_Reading>[
            _Reading(pos, 0, pos == e._len ? 0 : 1, 0, pos,
                missingAtEnd: pos == e._len ? 1 : 0,
                endsIncomplete: true,
                piece: lib.Match(source, pos, 0,
                    subClauseMatches: [lib.SyntaxError(pos: pos, len: 0)])),
          ]);
  }
}

// ---------------------------------------------------------------------------
// The engine.
// ---------------------------------------------------------------------------

class Squirrel {
  /// Build the engine from the library's own grammar AST (as produced by
  /// `MetaGrammar.parseGrammar`) and a top rule name. Strips the
  /// library's `~` (transparent-rule) markers, sets up a rule shell per
  /// name, then converts every rule body; references resolve against the
  /// shells, so rule order and cycles need no special handling. Every
  /// converted clause keeps its source clause, so the trees the engine
  /// returns are labeled with the caller's own grammar objects.
  Squirrel(
      {required Map<String, lib.Clause> rules, required this.topRuleName}) {
    final defs = <String, lib.Clause>{
      for (final e in rules.entries)
        e.key.startsWith('~') ? e.key.substring(1) : e.key: e.value
    };
    this.rules = {for (final name in defs.keys) name: Rule(name)};

    Clause node(lib.Clause c) => switch (c) {
          lib.Ref() => RuleRef(c, this.rules[c.ruleName]!),
          lib.Seq() => Seq(c, [for (final s in c.subClauses) node(s)]),
          lib.First() => First(c, [for (final s in c.subClauses) node(s)]),
          lib.Repetition() => Repetition(c, node(c.subClause), c.requireOne),
          lib.Optional() => Optional(c, node(c.subClause)),
          lib.FollowedBy() => Lookahead(c, node(c.subClause), true),
          lib.NotFollowedBy() => Lookahead(c, node(c.subClause), false),
          lib.Str() => Terminal(c, c.text),
          lib.Char() => Terminal(c, c.char),
          lib.CharSet() => Terminal.set(c, c.ranges, c.inverted),
          lib.AnyChar() => Terminal.set(c, const [], true),
          lib.Nothing() => Terminal(c, ''),
          _ => throw UnsupportedError('clause kind ${c.runtimeType}'),
        };

    for (final e in defs.entries) {
      this.rules[e.key]!.body = node(e.value);
    }
    _topRule = this.rules[topRuleName]!;
  }

  late final Map<String, Rule> rules;
  final String topRuleName;
  late final Rule _topRule;

  /// The input being parsed and its length.
  String _input = '';
  int _len = 0;

  /// Bumped once per [recover] call; clause-held memo arrays compare
  /// their stamp against it, so starting a new input resets everything
  /// without walking the grammar.
  int _runId = 0;

  /// Per-position version counters for left-recursion growth: one for the
  /// plain parse, one for repairs. Bumping a position's counter is how a
  /// growth pass tells memo entries computed against the half-grown seed
  /// to answer again (see Rule.parseCell and _grow).
  List<int> _parseVersions = const [], _repairVersions = const [];

  /// Set when the reading of a growing cell's seed happens; every
  /// computation on the call stack at that moment depends on the seed and
  /// must not be trusted across growth passes. Saved and restored around
  /// each cell computation, which records it as the cell's
  /// [_RepairCell.usedSeed].
  bool _seedWasRead = false;

  /// The current search round and its repair budget (equal by
  /// construction; see [recover]).
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
  static int _charge(_Reading r, int pos) =>
      r.cost + r.penalties + r.absorbPenalty(pos);

  static int _compare(_Reading a, _Reading b, int pos) {
    final chargeA = _charge(a, pos), chargeB = _charge(b, pos);
    if (chargeA != chargeB) return chargeA - chargeB;
    if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
    if (a.evidence != b.evidence) return b.evidence - a.evidence;
    if (a.firstDoubt != b.firstDoubt) return b.firstDoubt - a.firstDoubt;
    if (a.lastDoubt != b.lastDoubt) return a.lastDoubt - b.lastDoubt;
    if (a.missingAtEnd != b.missingAtEnd) {
      return a.missingAtEnd - b.missingAtEnd;
    }
    return _min(a.deleted, a.missing + a.missingAtEnd) -
        _min(b.deleted, b.missing + b.missingAtEnd);
  }

  /// The index of the reading ending at [end], or -1. Best-per-end lists
  /// are keyed by each reading's own `end`; a linear scan beats hashing
  /// at their measured sizes (71% of consults see at most one reading).
  static int _indexOfEnd(List<_Reading> xs, int end) {
    for (var i = 0; i < xs.length; i++) {
      if (xs[i].end == end) return i;
    }
    return -1;
  }

  static List<_Reading> _listOf(_Reading? r) => r == null ? const [] : [r];

  /// Whether any reading in [rs] is repair-free / the parser's own choice.
  static bool _anyClean(List<_Reading> rs) {
    for (var i = 0; i < rs.length; i++) {
      if (rs[i].clean) return true;
    }
    return false;
  }

  /// The farthest end any preferred reading in [rs] reaches (-1 if none).
  /// Among repair-free preferred readings, only the FARTHEST-reaching
  /// keeps its preferred status when served: the plain parser, being
  /// greedy, would have chosen that one; shorter clean readings are real
  /// alternatives but must not claim to be the parser's own choice.
  static int _farthest(List<_Reading> rs) {
    var farthest = -1;
    for (var i = 0; i < rs.length; i++) {
      final r = rs[i];
      if (r.preferred && r.end > farthest) farthest = r.end;
    }
    return farthest;
  }

  /// Offer [r] to the best-per-end list [best]: the same judging as
  /// [_RepairCell.add] (first occupant takes the slot; a challenger
  /// replaces it unless strictly worse -- ties go to the newcomer),
  /// without a cell around it. [pos] is the comparing position.
  static void _keepBest(List<_Reading> best, _Reading r, int pos) {
    final i = _indexOfEnd(best, r.end);
    if (i < 0) {
      best.add(r);
    } else if (_compare(r, best[i], pos) <= 0) {
      best[i] = r;
    }
  }

  /// Keep only the best reading per end position (a throwaway
  /// [_RepairCell] does the judging).
  List<_Reading> _bestPerEnd(List<_Reading> rs, int pos) {
    if (rs.length <= 1) return rs;
    final cell = _RepairCell(pos);
    rs.forEach(cell.add);
    return cell.readings();
  }

  /// Fill in (or reuse) a composite clause's repair cell at [pos]. This
  /// is the same fixed-point algorithm as the plain parser's left
  /// recursion handling in [Rule.parseCell], applied to priced readings:
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
    final cell = clause.slots(this)[pos] ??= (_RepairCell(pos)..owner = clause);
    if (cell.inRecPath) {
      // Re-entered while being computed: the left-recursive seed. It is
      // read RAW -- no budget filter -- because the growth about to
      // happen must see the seed's repair-carrying readings to build on
      // them. Reading a seed also marks every computation currently on
      // the stack as seed-dependent (see [_seedWasRead]).
      cell.foundLeftRec = true;
      _seedWasRead = true;
      return cell.readings();
    }
    // NO BUDGET LEFT: repair IS parsing, exactly. A reading that has
    // spent all its edits can only continue by reading the input as it
    // stands, so the plain parser's answer -- computed at most once per
    // cell -- is the whole answer, whatever else the cell holds. (Serving
    // the champion list's zero-cost view here instead would offer clean
    // but non-greedy readings the plain parser would never produce.)
    if (_budget == 0 && pos < _len) {
      return cell.plainList ??= _listOf(clause.cleanReading(this, pos));
    }
    // TWO CLOCKS, DIFFERENT SHAPES. [atBudget] is a lazy WATERMARK,
    // compared with >=: the champion list is filled only as deep as anyone
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
    // check was measured 13% slower.
    if (cell.atBudget >= _budget &&
        (!cell.usedSeed || cell.memoVersion == _repairVersions[pos])) {
      return cell.readings(_budget);
    }
    cell.inRecPath = true;
    final outer = _seedWasRead;
    _seedWasRead = false;
    do {
      var improved = false;
      final proposed = clause.proposeReadings(this, pos);
      for (var i = 0; i < proposed.length; i++) {
        if (cell.add(proposed[i])) improved = true;
      }
      if (!improved || !cell.foundLeftRec) break;
      cell.memoVersion = ++_repairVersions[pos];
    } while (true);
    cell.usedSeed = _seedWasRead;
    _seedWasRead = outer || _seedWasRead;
    cell.inRecPath = false;
    cell.atBudget = _budget;
    cell.memoVersion = _repairVersions[pos];
    return cell.readings(_budget);
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
  ///   3. REPLACE: when the slot is an exact-text terminal and the
  ///      prefix so far is the plain parser's own reading, consume the
  ///      one wrong character as the slot's error span -- substitution
  ///      as a single edit. (Details at the site below.)
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
  List<_Reading> _readSlots(List<Clause> slots, lib.Clause? label, int pos) {
    // The fold state is the best-per-end list itself: extensions are
    // judged as they are produced ([_keepBest]), never collected first.
    // Demotion of non-farthest preferred readings -- which _bestPerEnd
    // used to apply between slots -- happens on read instead: same
    // objects, same order, no intermediate cell.
    var cur = <_Reading>[_Reading.empty(pos)];
    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final next = <_Reading>[];
      final farthest = _farthest(cur);
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
          // REPLACE: the slot satisfied by the one wrong character --
          // the input had something else where the grammar required this
          // exact text, so the character is consumed as an error span
          // and the sequence moves on: substitution as a single edit,
          // not delete-plus-missing at two. Offered only off a PREFERRED
          // prefix (the substitution shape: everything before the swap
          // parsed as the plain parser's own choice), which keeps the
          // search from spawning replace chains out of every
          // already-repaired partial. Exact-text slots only: an unpicky
          // class fails only on a structural delimiter, and a charset's
          // replace was measured to win nothing.
          if (r.preferred &&
              r.spent < _budget &&
              r.end < _len &&
              slot is Terminal &&
              slot.text != null &&
              _resumes(slots, s, r.end + 1)) {
            _keepBest(next, r.then(_Reading.deleting(r.end, r.end + 1)), pos);
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
      }
      if (next.isEmpty) return const [];
      cur = next;
    }
    final farthest = _farthest(cur);
    final out = <_Reading>[];
    for (var i = 0; i < cur.length; i++) {
      final v = cur[i];
      final r = v.preferred && v.end != farthest ? v.demoted : v;
      out.add(label == null ? r : r.labeled(label, pos));
    }
    return out;
  }

  /// True when the sequence can carry on from [at], the position just
  /// after a wrong character was consumed in place of slot [s]: some
  /// later slot reads cleanly there and proves something, or the
  /// sequence simply ends. A swap the rest of the sequence cannot read
  /// from is not a substitution, it is a guess -- and every such guess
  /// opens a position the search would never otherwise visit, which is
  /// what made this repair expensive when it was offered unconditionally.
  bool _resumes(List<Clause> slots, int s, int at) {
    for (var i = s + 1; i < slots.length; i++) {
      final n = slots[i].cleanReading(this, at);
      if (n == null || n.end > at) return n != null;
      at = n.end;
    }
    return true;
  }

  /// Count the characters in tree [m] that were matched by picky
  /// terminals (see [Terminal.picky]) -- the evidence a finished subtree
  /// contributes. This is the one walk over library-typed trees, hence
  /// the type tests.
  int _evidenceIn(lib.MatchResult m) {
    final kids = m.subClauseMatches;
    final r = m.clause;
    if (r is lib.Repetition && !r.requireOne && r.subClause is lib.Terminal) {
      return 0; // a voluntary terminal's span: see Terminal.voluntary
    }
    if (kids.isEmpty) {
      final c = m.clause;
      if (m.isMismatch) return 0;
      return c is lib.Str || c is lib.Char || (c is lib.CharSet && !c.inverted)
          ? m.len
          : 0;
    }
    var total = 0;
    for (var i = 0; i < kids.length; i++) {
      total += _evidenceIn(kids[i]);
    }
    return total;
  }

  /// Turn one piece into a tree node. A _Labeled piece walks its chain
  /// (backwards, then reversed) and puts the construct's name on -- with
  /// one exception: a construct that matched NOTHING at the very end of
  /// the input loses its name. The input never reached it, so claiming
  /// "an X was here" would be an invention; the bare marker suffices.
  /// Mid-document, the name is kept: the surroundings prove which
  /// construct it was.
  lib.MatchResult _treeOf(Object piece, int end) {
    if (piece is lib.MatchResult) return piece;
    final l = piece as _Labeled;
    final kids = <lib.MatchResult>[];
    for (_Reading? r = l.inner; r != null; r = r.prev) {
      if (r.piece != null) kids.add(_treeOf(r.piece!, r.end));
    }
    final name = end == l.from && l.from >= _len ? null : l.label;
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
    _parseVersions = List<int>.filled(_len + 2, 0);
    _repairVersions = List<int>.filled(_len + 2, 0);
    // Round zero: the plain parse. If it explains the whole input, done.
    final plain = _topRule.parseCell(this, 0).tree;
    if (plain != null && plain.len == _len) {
      lastCost = 0;
      return plain;
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
        if (_charge(whole, 0) > _budget) continue;
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
        best = incomplete.fold(
            b,
            (top, r) =>
                _charge(r, 0) <= _charge(b, 0) && r.evidence > top.evidence
                    ? r
                    : top);
        break;
      }
      if (fallback == null && incomplete.isNotEmpty) {
        fallback = incomplete.reduce((f, r) => _compare(r, f, 0) < 0 ? r : f);
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
