// c8.dart -- a PEG parser with built-in error recovery, in one file.
//
// WHAT THIS IS. A parser that, given a grammar and an input string, returns
// the best complete parse tree it can -- even when the input has errors.
// Damage is reported inside the tree as SyntaxError nodes: a SyntaxError
// with length > 0 marks real input characters that were skipped as noise;
// a SyntaxError of length 0 marks a place where something required was
// missing. The engine never invents characters; it only records what it
// skipped and where something was absent.
//
// HOW IT WORKS, IN ONE PARAGRAPH. The engine runs the ordinary squirrel
// parsing algorithm (a memoizing recursive-descent parser that supports
// left recursion) as its "plain parse". When the plain parse fails to
// explain the whole input, the engine re-runs the descent in a costed
// form: every grammar node now returns a set of candidate READINGS -- ways
// its part of the grammar could account for the input, each carrying a
// repair bill. Candidates compete: for each (grammar node, position,
// end position) only the best-priced reading survives. The search runs in
// rounds with a rising repair budget (1 edit, then 2, ...) and stops at
// the first budget where some reading explains the entire input; that
// bound is what keeps the search fast. The winning reading is then turned
// into the output tree.
//
// The grammar arrives as the squirrel library's Clause objects and the
// output tree uses the library's Match/SyntaxError types, so this file
// interoperates with everything else; but all parsing logic lives here.
// The library's clause tree is converted once, at construction, into this
// engine's own node classes (see _convert), and each node kind carries its
// whole behavior: how to parse plainly, how to propose repairs, and a few
// precomputed facts about itself.
//
// The design decisions in this file were each settled by measurement over
// a large mutation battery; the history and the numbers live in
// LESSONS_LEARNED.md at the repository root.
import 'package:squirrel_parser/squirrel_parser.dart';

/// Sentinel values for [_Reading.firstDoubt], both larger than any input
/// position. A reading whose firstDoubt is a real position has a repair
/// there; `_clean` means "no repairs, but not the plain parser's own
/// choice"; `_chosen` means "no repairs, and this is exactly what the
/// plain parser would do". Bigger is more trustworthy.
const int _clean = 1 << 30;
const int _chosen = _clean + 1;

/// "This grammar node cannot match at all" for [_Node.minChars].
const int _impossible = 1 << 30;

int _min(int a, int b) => a < b ? a : b;

/// A grammar construct's name wrapped around the steps that filled it in:
/// the piece of tree that says "these children together form one <label>".
class _Labeled {
  const _Labeled(this.label, this.from, this.inner);

  /// The grammar clause whose name the finished tree node will carry.
  final Clause label;

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
      : this(t, t - f, 0, 0, f, piece: SyntaxError(pos: f, len: t - f));

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

  /// This reading carrying a finished tree [m] as its piece (used for
  /// zero-width results such as an empty optional or a lookahead).
  _Reading withTree(MatchResult m, [int rank = _chosen]) =>
      _Reading(end, deleted, missing, evidence, _min(firstDoubt, rank),
          missingAtEnd: missingAtEnd,
          penalties: penalties,
          endsIncomplete: endsIncomplete,
          piece: m);

  /// This reading wrapped under a construct's name, starting at [from].
  _Reading labeled(Clause label, int from, [int rank = _chosen]) =>
      _Reading(end, deleted, missing, evidence, _min(firstDoubt, rank),
          missingAtEnd: missingAtEnd,
          penalties: penalties,
          endsIncomplete: endsIncomplete,
          piece: _Labeled(label, from, this));

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
/// [atBudget] and [memoVersion] record the budget and the position's
/// version this cell was computed at; the cell is only trusted while both
/// still hold (see Squirrel._grow). [inRecPath] / [foundLeftRec] play the
/// same roles as in the plain parser's memo: cycle detection and the
/// signal that a left-recursive cycle needs growing.
class _RepairCell {
  _RepairCell(this.pos);
  final int pos;
  final Map<int, _Reading> _bestByEnd = {};
  bool inRecPath = false, foundLeftRec = false, usedSeed = false;
  int atBudget = -1, memoVersion = 0;

  /// Offer a reading; keep it if it beats (or ties) the current holder of
  /// its end position. Returns true only on a strict improvement.
  bool add(_Reading r) {
    final holder = _bestByEnd[r.end];
    if (holder == null) {
      _bestByEnd[r.end] = r;
      return true;
    }
    final cmp = Squirrel._compare(r, holder, pos);
    if (cmp > 0) return false;
    // On an exact tie the NEWCOMER takes the slot. This is deliberate and
    // measured: tied readings can differ in details the comparison cannot
    // see, and the later one -- produced by a later, better-informed pass
    // -- is right more often. A tie still reports "no improvement", or
    // two tied rivals would re-trigger each other forever.
    _bestByEnd[r.end] = r;
    return cmp < 0;
  }

  /// The cell's readings, filtered to what [budget] can afford. Among
  /// repair-free preferred readings, only the FARTHEST-reaching keeps its
  /// preferred status: the plain parser, being greedy, would have chosen
  /// that one; shorter clean readings are real alternatives but must not
  /// claim to be the parser's own choice.
  List<_Reading> readings([int budget = _clean]) {
    var farthest = -1;
    for (final r in _bestByEnd.values) {
      if (r.preferred && r.end > farthest) farthest = r.end;
    }
    return [
      for (final r in _bestByEnd.values)
        if (r.spent <= budget) r.preferred && r.end != farthest ? r.demoted : r
    ];
  }
}

/// The memo cell for the plain parse: one (rule, position) entry holding
/// the parse tree (null = did not match), the same tree prepackaged as a
/// clean [_Reading] for the repair machinery, and the left-recursion
/// bookkeeping the squirrel algorithm needs. [computed] distinguishes
/// "computed, and it was a mismatch" from "not computed yet".
class _ParseCell {
  MatchResult? tree;
  _Reading? reading;
  bool computed = false, inRecPath = false, foundLeftRec = false;
  int memoVersion = 0;
}

// ---------------------------------------------------------------------------
// The grammar, converted into this engine's own node classes. Each node
// carries the library clause it came from (so tree nodes are labeled with
// the caller's own grammar objects) and its complete behavior as methods:
//
//   match(pos)         parse plainly here; null means "does not match"
//   readings(pos)      all candidate readings here, repairs included
//   cleanReading(pos)  the plain parse packaged as a single reading
//   picky / hasOneShape / minChars   small static facts, described below
// ---------------------------------------------------------------------------

abstract class _Node {
  _Node(this.source);

  /// The library clause this node was converted from. Every tree node and
  /// label carries it, so callers see trees over their own grammar.
  final Clause source;

  /// Parse plainly at [pos] (no repairs). Null means "does not match".
  MatchResult? match(Squirrel e, int pos);

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
  /// Never allocates; only memoized nodes override this.
  _RepairCell? cellAt(Squirrel e, int pos) => null;

  /// Whether this node can produce only ONE possible tree shape, whatever
  /// input it reads. If so, "it was missing" is unambiguous -- there is
  /// exactly one thing it could have been -- which matters for the
  /// penalty rule in _readSlots. Computed once and cached; a recursive
  /// cycle counts as "no".
  bool? _oneShape;
  bool hasOneShape() {
    if (_oneShape != null) return _oneShape!;
    _oneShape = false; // cycle-breaker: while computing, assume "no"
    return _oneShape = computeOneShape();
  }

  bool computeOneShape();

  /// The fewest input characters any successful match of this node can
  /// consume ([_impossible] if it can never match). Used only to bound
  /// the repair search: no repair can need more budget than the whole
  /// input plus the shortest possible document. Deliberately NOT cached:
  /// caching under the cycle-breaker records wrong values inside
  /// recursive grammars, and it is only computed once anyway.
  int minChars(Set<_Node> path) {
    if (!path.add(this)) return _impossible;
    final v = computeMinChars(path);
    path.remove(this);
    return v;
  }

  int computeMinChars(Set<_Node> path);
}

/// A node whose repair results are memoized: it owns one [_RepairCell]
/// per input position, filled in by Squirrel._grow around this node's
/// [proposeReadings]. The cell array is stamped with the run it belongs
/// to, so starting a new input resets every node by bumping one counter.
abstract class _MemoNode extends _Node {
  _MemoNode(super.source);

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

  @override
  List<_Reading> findReadings(Squirrel e, int pos) => e._grow(this, pos);

  /// One pass of candidate generation for the cell at [pos]. May be run
  /// several times when a left-recursive cycle is being grown.
  List<_Reading> proposeReadings(Squirrel e, int pos);
}

/// A sequence: each part in order (the grammar's juxtaposition).
class _Sequence extends _MemoNode {
  _Sequence(super.source, this.parts);
  final List<_Node> parts;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final kids = <MatchResult>[];
    var p = pos;
    for (final part in parts) {
      final m = part.match(e, p);
      if (m == null) return null;
      kids.add(m);
      p += m.len;
    }
    return kids.isEmpty
        ? Match(source, pos, 0)
        : Match(source, 0, 0, subClauseMatches: kids);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) =>
      e._readSlots(parts, source, pos);

  @override
  bool computeOneShape() => parts.every((p) => p.hasOneShape());

  @override
  int computeMinChars(Set<_Node> path) {
    var total = 0;
    for (final part in parts) {
      final n = part.minChars(path);
      total =
          n >= _impossible || total >= _impossible ? _impossible : total + n;
    }
    return total;
  }
}

/// An ordered choice (the grammar's `/`): try each arm in order; plainly,
/// the first match wins.
///
/// Under repair, every arm contributes candidates -- but once some arm has
/// read the input exactly as it stands, the choice is considered settled
/// in that arm's favor, and a LATER arm's repaired reading is admitted
/// only if it proves more than it swallows. Without that rule, a loose
/// later arm (say, a quoted-string rule) can "explain" almost anything by
/// absorbing it, stealing the parse from the arm the document really
/// used. Note the >=: a settled choice demands the challenger prove
/// strictly more than half its span, one notch stricter than the general
/// absorb penalty.
class _Choice extends _MemoNode {
  _Choice(super.source, this.arms);
  final List<_Node> arms;

  @override
  MatchResult? match(Squirrel e, int pos) {
    for (final arm in arms) {
      final m = arm.match(e, pos);
      if (m != null) return Match(source, 0, 0, subClauseMatches: [m]);
    }
    return null;
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final out = <_Reading>[];
    var settled = false;
    for (final arm in arms) {
      final rs = arm.readings(e, pos);
      for (final r in rs) {
        if (settled && !r.clean && r.absorbed(pos) >= r.evidence) continue;
        out.add(r.labeled(source, pos, settled ? _clean : _chosen));
      }
      settled = settled || rs.any((r) => r.preferred);
    }
    return out;
  }

  @override
  bool computeOneShape() => false;

  @override
  int computeMinChars(Set<_Node> path) {
    var least = _impossible;
    for (final arm in arms) {
      final n = arm.minChars(path);
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
class _Repeat extends _MemoNode {
  _Repeat(super.source, this.body, this.atLeastOne);
  final _Node body;
  final bool atLeastOne;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final kids = <MatchResult>[];
    var p = pos;
    while (p <= e._len) {
      final m = body.match(e, p);
      if (m == null) break;
      // Never take more than one zero-length body match, or a grammar
      // like ()* would loop forever.
      if (m.len == 0) break;
      kids.add(m);
      p += m.len;
    }
    if (atLeastOne && kids.isEmpty) return null;
    return kids.isEmpty
        ? Match(source, pos, 0)
        : Match(source, 0, 0, subClauseMatches: kids);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final zero = _Reading.empty(pos);
    final best = <int, _Reading>{if (!atLeastOne) pos: zero};
    var moved = <_Reading>[zero];
    while (moved.isNotEmpty) {
      final changed = <int>{};
      for (final r in moved) {
        for (final step in body.readings(e, r.end)) {
          if (step.end <= r.end) continue;
          final longer = r.then(step);
          final holder = best[longer.end];
          if (holder != null && Squirrel._compare(longer, holder, pos) >= 0) {
            continue;
          }
          best[longer.end] = longer;
          changed.add(longer.end);
        }
      }
      moved = [for (final end in changed) best[end]!];
    }
    final all = best.values.toList();
    if (all.isEmpty) {
      // A `+` with nothing at all: take the body's own zero-width
      // "missing" readings as the one owed occurrence.
      for (final step in body.readings(e, pos)) {
        if (step.end != pos) continue;
        all.add(zero.then(step).demoted);
      }
    }
    return [for (final r in e._bestPerEnd(all, pos)) r.labeled(source, pos)];
  }

  @override
  bool computeOneShape() => atLeastOne && body.hasOneShape();

  @override
  int computeMinChars(Set<_Node> path) => atLeastOne ? body.minChars(path) : 0;
}

/// An optional part (the grammar's `?`): its child, or nothing. The
/// empty alternative keeps its "parser's own choice" status only if the
/// child cannot match plainly -- the plain parser always takes the child
/// when it can.
class _Maybe extends _MemoNode {
  _Maybe(super.source, this.child);
  final _Node child;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final m = child.match(e, pos);
    return m == null
        ? Match(source, pos, 0)
        : Match(source, 0, 0, subClauseMatches: [m]);
  }

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final rs = child.readings(e, pos);
    return [
      _Reading.empty(pos).withTree(
          Match(source, pos, 0), rs.any((r) => r.preferred) ? _clean : _chosen),
      for (final r in rs) r.labeled(source, pos)
    ];
  }

  @override
  bool computeOneShape() => false;

  @override
  int computeMinChars(Set<_Node> path) => 0;
}

/// A lookahead (the grammar's `&X` or `!X`): succeeds or fails without
/// consuming anything. No repair may live inside one -- input a lookahead
/// "accepted" would be input the parse then refuses to consume -- so its
/// answer is simply whether any repair-free reading of its child exists.
/// (It still gets a memo cell like other composites: that cell is also
/// the only cache over the child's work here, and removing it was
/// measured to re-run that work far too often.)
class _Lookahead extends _MemoNode {
  _Lookahead(super.source, this.child, this.expectMatch);
  final _Node child;
  final bool expectMatch;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      (child.match(e, pos) != null) == expectMatch
          ? Match(source, pos, 0)
          : null;

  @override
  List<_Reading> proposeReadings(Squirrel e, int pos) {
    final ok = child.readings(e, pos).any((r) => r.clean);
    return expectMatch == ok
        ? [_Reading.empty(pos).withTree(Match(source, pos, 0))]
        : const [];
  }

  @override
  bool computeOneShape() => true;

  @override
  int computeMinChars(Set<_Node> path) => 0;
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
class _Rule {
  _Rule(this.name);
  final String name;
  late _Node body;

  List<_ParseCell?>? _cells;
  int _run = -1;

  _ParseCell parseCell(Squirrel e, int pos) {
    if (_run != e._runId) {
      _cells = List<_ParseCell?>.filled(e._len + 2, null);
      _run = e._runId;
    }
    final cell = _cells![pos] ??= _ParseCell();
    if (cell.computed &&
        (cell.inRecPath || cell.memoVersion == e._parseVersions[pos])) {
      return cell;
    }
    if (cell.inRecPath) {
      // Re-entered while already being computed: a left-recursive cycle.
      // Seed it with a mismatch and let the outer frame grow it.
      cell.foundLeftRec = true;
      cell.computed = true;
      cell.tree = null;
      return cell;
    }
    cell.inRecPath = true;
    do {
      final m = body.match(e, pos);
      // Fixed point: a match is never replaced by a mismatch, and an
      // attempt that did not consume more than the last one is no better.
      if (cell.computed &&
          (m == null || (cell.tree != null && m.len <= cell.tree!.len))) {
        break;
      }
      cell.tree = m;
      cell.reading = null; // the packaged reading is stale now
      cell.computed = true;
      if (!cell.foundLeftRec) break;
      cell.memoVersion = ++e._parseVersions[pos];
    } while (true);
    cell.inRecPath = false;
    cell.memoVersion = e._parseVersions[pos];
    return cell;
  }
}

/// A reference to a named rule -- the only node kind that goes through the
/// plain-parse memo, and the place where a rule's readings get the rule's
/// name wrapped around them.
class _RuleRef extends _Node {
  _RuleRef(super.source, this.rule);
  final _Rule rule;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos > e._len) return null;
    final m = rule.parseCell(e, pos).tree;
    return m == null ? null : Match(source, 0, 0, subClauseMatches: [m]);
  }

  /// The rule's plain parse as a reading. Built ONCE per (rule, position)
  /// and cached in the parse cell, however many callers ask; the whole
  /// finished subtree is reused, never re-parsed. (All references to a
  /// rule share the cached reading; its tree label is whichever
  /// reference asked first, and only the rule NAME on it is ever read.)
  @override
  _Reading? cleanReading(Squirrel e, int pos) {
    if (pos > e._len) return null;
    final cell = rule.parseCell(e, pos);
    final m = cell.tree;
    if (m == null) return null;
    return cell.reading ??= _Reading(
        pos + m.len, 0, 0, e._evidenceIn(m), _chosen,
        piece: Match(source, 0, 0, subClauseMatches: [m]));
  }

  @override
  List<_Reading> findReadings(Squirrel e, int pos) {
    // WITH NO BUDGET LEFT, REPAIR IS PARSING. A reading that has spent
    // all its edits can only continue by reading the input exactly as it
    // stands -- which is precisely what the plain parser computes. So the
    // memoized plain parse answers outright: one cache lookup for the
    // whole rest of this rule, instead of a costed descent that could
    // discover nothing new anyway.
    if (e._budget == 0 && pos < e._len) {
      final r = cleanReading(e, pos);
      return r == null ? const [] : [r];
    }
    // Wrap the rule's name around the body's readings. One filter: a
    // repaired reading that consumed input yet proved NONE of it (no
    // evidence) is an invention that explains nothing, and is refused --
    // unless the rule has only one possible shape (then "it was missing"
    // is unambiguous), or the reading consumed nothing (a pure "missing"
    // marker, which is honest).
    return [
      for (final r in rule.body.readings(e, pos))
        if (r.evidence > 0 || r.clean || r.end == pos || hasOneShape())
          r.labeled(source, pos)
    ];
  }

  @override
  bool computeOneShape() => rule.body.hasOneShape();

  @override
  int computeMinChars(Set<_Node> path) => rule.body.minChars(path);

  /// Whether this reference points back into a rule whose repair cell is
  /// being computed right now -- i.e. this is the left-recursive re-entry
  /// itself. Used by _readSlots to exempt the seed from the penalty rule.
  bool isGrowingAt(Squirrel e, int pos) =>
      rule.body.cellAt(e, pos)?.inRecPath ?? false;
}

/// A leaf: matches characters directly. If it cannot match, it can
/// instead be recorded as MISSING -- a zero-length SyntaxError in the
/// tree that says "the grammar required this here and the input did not
/// have it". Nothing is invented: the tree records the absence, never a
/// made-up character.
abstract class _Leaf extends _Node {
  _Leaf(super.source);

  /// Whether this leaf only accepts specific characters (a literal, an
  /// exact character, a character class). Picky matches are the
  /// evidence a reading carries; a wildcard proves nothing. This is
  /// also exactly what _evidenceIn computes per leaf, known here without
  /// walking a tree.
  bool get picky;

  @override
  _Reading? cleanReading(Squirrel e, int pos) {
    final m = match(e, pos);
    return m == null
        ? null
        : _Reading(pos + m.len, 0, 0, picky ? m.len : 0, _chosen, piece: m);
  }

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
    return recordMissing(e, pos);
  }

  /// The reading that records this leaf as missing at [pos].
  List<_Reading> recordMissing(Squirrel e, int pos) {
    final atEnd = pos == e._len;
    return [
      _Reading(pos, 0, atEnd ? 0 : 1, 0, pos,
          missingAtEnd: atEnd ? 1 : 0,
          endsIncomplete: true,
          piece: Match(source, pos, 0,
              subClauseMatches: [SyntaxError(pos: pos, len: 0)]))
    ];
  }

  @override
  bool computeOneShape() => true;

  @override
  int computeMinChars(Set<_Node> path) => 1;
}

/// A multi-character literal like "true".
///
/// When it fails to match whole, it is treated as a SEQUENCE of its
/// characters and run through the general slot machinery: that yields
/// partial prefixes ("tru" + one missing), deletions inside it, and the
/// replace repair (wrong character deleted AND right one recorded
/// missing) with no special alignment code. Single-character literals
/// just act as plain leaves. (Giving literals their own memo cells was
/// measured: identical results, a quarter slower -- the cell ceremony on
/// every literal that MATCHES costs more than caching the failures
/// saves.)
class _Literal extends _Leaf {
  _Literal(super.source, this.text)
      : letters = text.length > 1
            ? [
                for (final u in text.codeUnits)
                  _OneChar(Char(String.fromCharCode(u)), u)
              ]
            : const [];
  final String text;
  final List<_Node> letters;

  @override
  bool get picky => true;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos + text.length > e._len) return null;
    for (var i = 0; i < text.length; i++) {
      if (e._input.codeUnitAt(pos + i) != text.codeUnitAt(i)) return null;
    }
    return Match(source, pos, text.length);
  }

  @override
  List<_Reading> recordMissing(Squirrel e, int pos) => letters.isEmpty
      ? super.recordMissing(e, pos)
      : e._bestPerEnd(
          e._readSlots(letters, source, pos, insideLiteral: true), pos);

  @override
  int computeMinChars(Set<_Node> path) => text.length;
}

/// A single exact character.
class _OneChar extends _Leaf {
  _OneChar(super.source, this.code);
  final int code;

  @override
  bool get picky => true;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      pos < e._len && e._input.codeUnitAt(pos) == code
          ? Match(source, pos, 1)
          : null;
}

/// A character class like [a-z], possibly negated like [^"\].
class _CharClass extends _Leaf {
  _CharClass(super.source, this.ranges, this.negated);
  final List<(int, int)> ranges;
  final bool negated;

  /// A negated class accepts almost anything, so its matches prove
  /// nothing about the input fitting the grammar.
  @override
  bool get picky => !negated;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos >= e._len) return null;
    final c = e._input.codeUnitAt(pos);
    var inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }
    return (negated ? !inSet : inSet) ? Match(source, pos, 1) : null;
  }
}

/// The wildcard `.`: any single character.
class _Wildcard extends _Leaf {
  _Wildcard(super.source);

  @override
  bool get picky => false;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      pos < e._len ? Match(source, pos, 1) : null;
}

/// Matches the empty string; always succeeds.
class _Empty extends _Leaf {
  _Empty(super.source);

  @override
  bool get picky => false;

  @override
  MatchResult? match(Squirrel e, int pos) => Match(source, pos, 0);

  @override
  int computeMinChars(Set<_Node> path) => 0;
}

// ---------------------------------------------------------------------------
// The engine.
// ---------------------------------------------------------------------------

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    // Strip the library's '~' (transparent-rule) markers, set up a _Rule
    // shell per name, then convert every body; references resolve against
    // the shells, so rule order and cycles need no special handling.
    final defs = <String, Clause>{
      for (final e in rules.entries)
        e.key.startsWith('~') ? e.key.substring(1) : e.key: e.value
    };
    for (final name in defs.keys) {
      _rules[name] = _Rule(name);
    }
    for (final e in defs.entries) {
      _rules[e.key]!.body = _convert(e.value);
    }
    _topRule = _rules[topRuleName]!;
  }

  final String topRuleName;
  final Map<String, _Rule> _rules = {};
  late final _Rule _topRule;

  /// The input being parsed and its length.
  String _input = '';
  int _len = 0;

  /// Bumped once per [recover] call; node-held memo arrays compare their
  /// stamp against it, so starting a new input resets everything without
  /// walking the grammar.
  int _runId = 0;

  /// Per-position version counters for left-recursion growth: one for the
  /// plain parse, one for repairs. Bumping a position's counter is how a
  /// growth pass tells memo entries computed against the half-grown seed
  /// to answer again (see _Rule.parseCell and _grow).
  List<int> _parseVersions = const [], _repairVersions = const [];

  /// Set when the reading of a growing cell's seed happens; every
  /// computation on the call stack at that moment depends on the seed and
  /// must not be trusted across growth passes. Saved and restored around
  /// each cell computation, which records it as the cell's
  /// [_RepairCell.usedSeed].
  bool _seedWasRead = false;

  /// The current search round and its repair budget (equal by
  /// construction; see [recover]).
  int _round = 0, _budget = 0;

  /// Cached: the shortest document the grammar accepts (bounds the search).
  int? _minDocLen;

  /// The repair bill of the last [recover] run (0 for a clean parse).
  /// Deletions count per character; missing pieces count per piece;
  /// the end-of-input cut-off counts each stranded piece here (this is
  /// the tree's own error count, unlike [_Reading.cost]'s single charge).
  int lastCost = 0;

  /// The one place that inspects library clause types: convert the
  /// caller's grammar into this engine's nodes.
  _Node _convert(Clause c) {
    if (c is Ref) {
      final r = _rules[c.ruleName];
      if (r == null) throw ArgumentError('rule "${c.ruleName}" not found');
      return _RuleRef(c, r);
    }
    if (c is Seq) {
      return _Sequence(c, [for (final s in c.subClauses) _convert(s)]);
    }
    if (c is First) {
      return _Choice(c, [for (final s in c.subClauses) _convert(s)]);
    }
    if (c is Repetition) return _Repeat(c, _convert(c.subClause), c.requireOne);
    if (c is Optional) return _Maybe(c, _convert(c.subClause));
    if (c is FollowedBy) return _Lookahead(c, _convert(c.subClause), true);
    if (c is NotFollowedBy) {
      return _Lookahead(c, _convert(c.subClause), false);
    }
    if (c is Str) return _Literal(c, c.text);
    if (c is Char) return _OneChar(c, c.char.codeUnitAt(0));
    if (c is CharSet) return _CharClass(c, c.ranges, c.inverted);
    if (c is AnyChar) return _Wildcard(c);
    if (c is Nothing) return _Empty(c);
    throw UnsupportedError('clause kind ${c.runtimeType}');
  }

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

  /// Keep only the best reading per end position (a throwaway
  /// [_RepairCell] does the judging).
  List<_Reading> _bestPerEnd(List<_Reading> rs, int pos) {
    if (rs.length <= 1) return rs;
    final cell = _RepairCell(pos);
    rs.forEach(cell.add);
    return cell.readings();
  }

  /// Fill in (or reuse) a node's repair cell at [pos]. This is the same
  /// fixed-point algorithm as the plain parser's left recursion handling
  /// in [_Rule.parseCell], applied to priced readings:
  ///
  ///   - Re-entry into a cell being computed is the seed of a
  ///     left-recursive cycle. It is answered with the cell's current
  ///     contents, UNFILTERED by budget -- the growth about to happen
  ///     must see the seed's repair-carrying readings to build on them.
  ///   - The owner keeps re-running [_MemoNode.proposeReadings] until a
  ///     pass improves nothing; each pass bumps the position's version.
  ///   - A cell is trusted only at its stamped budget and, if its
  ///     computation ever read a growing seed ([usedSeed]), its stamped
  ///     version. A cell that read no seed cannot be stale, no matter
  ///     what grew: everything else it read is indexed by position, and
  ///     growth only ever changes the growing cell itself.
  List<_Reading> _grow(_MemoNode node, int pos) {
    final cell = node.cells(this)[pos] ??= _RepairCell(pos);
    if (cell.inRecPath) {
      cell.foundLeftRec = true;
      _seedWasRead = true;
      return cell.readings();
    }
    if (cell.atBudget >= _budget &&
        (!cell.usedSeed || cell.memoVersion == _repairVersions[pos])) {
      return cell.readings(_budget);
    }
    if (_budget == 0 && cell.atBudget < 0 && pos < _len) {
      // No budget: repair IS parsing (see _RuleRef.findReadings), for
      // composite nodes too. The plain parse is the cell's whole answer.
      cell.atBudget = 0;
      final r = node.cleanReading(this, pos);
      if (r != null) cell.add(r);
      return cell.readings();
    }
    cell.inRecPath = true;
    final outer = _seedWasRead;
    _seedWasRead = false;
    do {
      var improved = false;
      for (final r in node.proposeReadings(this, pos)) {
        if (cell.add(r)) improved = true;
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
  List<_Reading> _readSlots(List<_Node> slots, Clause label, int pos,
      {bool insideLiteral = false}) {
    var sofar = <_Reading>[_Reading.empty(pos)];
    for (final slot in slots) {
      final next = <_Reading>[];
      for (final r in sofar) {
        if (r.spent > _budget) continue;
        // Hand the slot only the budget this reading has not spent.
        final whole = _budget;
        _budget = whole - r.spent;
        final options = slot.readings(this, r.end);
        _budget = whole;
        var cleanHere = false;
        for (final o in options) {
          if (o.clean) cleanHere = true;
        }
        var deletedAhead = -1;
        if (!cleanHere) {
          final room = _budget - r.cost;
          for (var j = r.end + 1; j <= r.end + room && j <= _len; j++) {
            final parsed = slot.cleanReading(this, j);
            if (parsed == null) continue;
            next.add(r.then(_Reading.deleting(r.end, j)).then(parsed));
            deletedAhead = j - r.end;
            break;
          }
        }
        final seed = slot is _RuleRef && slot.isGrowingAt(this, r.end);
        final penalize = deletedAhead > 0 && !seed && !slot.hasOneShape();
        for (final o in options) {
          next.add(r.then(penalize &&
                  o.end == r.end &&
                  !o.clean &&
                  deletedAhead <= o.missing
              ? o.penalized()
              : o));
        }
        if (insideLiteral && !cleanHere && r.end < _len) {
          final replaced = r.then(_Reading.deleting(r.end, r.end + 1));
          for (final o in slot.readings(this, r.end + 1)) {
            next.add(replaced.then(o));
          }
        }
      }
      if (next.isEmpty) return const [];
      sofar = _bestPerEnd(next, pos);
    }
    return [for (final r in _bestPerEnd(sofar, pos)) r.labeled(label, pos)];
  }

  /// Count the characters in tree [m] that were matched by picky leaves
  /// (see [_Leaf.picky]) -- the evidence a finished subtree contributes.
  /// This is the one walk over library-typed trees, hence the type tests.
  int _evidenceIn(MatchResult m) {
    if (m.subClauseMatches.isEmpty) {
      final c = m.clause;
      return !m.isMismatch &&
              (c is Str || c is Char || (c is CharSet && !c.inverted))
          ? m.len
          : 0;
    }
    var total = 0;
    for (final k in m.subClauseMatches) {
      total += _evidenceIn(k);
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
  MatchResult _treeOf(Object piece, int end) {
    if (piece is MatchResult) return piece;
    final l = piece as _Labeled;
    final kids = <MatchResult>[];
    for (_Reading? r = l.inner; r != null; r = r.prev) {
      if (r.piece != null) kids.add(_treeOf(r.piece!, r.end));
    }
    final name = end == l.from && l.from >= _len ? null : l.label;
    return kids.isEmpty
        ? Match(name, l.from, end - l.from)
        : Match(name, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  /// The winner's tree. Only the winning reading is ever materialized;
  /// during the search, readings stay as chains (building trees for
  /// every candidate was measured 20-31% slower).
  MatchResult _buildTree(_Reading r) {
    if (r.prev == null && r.piece != null) return _treeOf(r.piece!, r.end);
    final kids = <MatchResult>[];
    for (_Reading? p = r; p != null; p = p.prev) {
      if (p.piece != null) kids.add(_treeOf(p.piece!, p.end));
    }
    return kids.length == 1
        ? kids.single
        : Match(null, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  // -- the entry point -------------------------------------------------------

  /// Parse [s], repairing if needed, and return the best complete tree.
  MatchResult recover(String s) {
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
    final shortest = _minDocLen ??= _topRule.body.minChars(<_Node>{});
    final ceiling = shortest >= _impossible ? -1 : s.length + shortest;
    _Reading? best, fallback;
    for (_round = 1; _round <= ceiling; _round++) {
      _budget = _round;
      final incomplete = <_Reading>[];
      for (final r in _topRule.body.readings(this, 0)) {
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
    return best == null ? SyntaxError(pos: 0, len: s.length) : _buildTree(best);
  }

  /// [recover], returning the repair bill instead of the tree.
  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
