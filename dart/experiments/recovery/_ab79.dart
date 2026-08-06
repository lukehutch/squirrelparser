// m79 -- THE AST IS PRIMAL; THE INPUT IS ONLY EVIDENCE.
//
// Every engine from sd3 to m78 treated recovery as STRING REPAIR: find a minimal
// edit script over the input, apply it, and reconstruct a tree from the repaired
// string.  That framing is what made m78 cost 1296 lines and 229ms.  Roughly 400
// of those lines are the obligation-residual algebra -- a parsing-expression
// derivative carried as a product-DFA state inside the memo key -- and its ENTIRE
// job is to answer one question: "if I repair the string here, what will a
// lookahead downstream read?"
//
// Delete the repaired string and the question does not arise.
//
// I35: A REPAIR IS A CLAIM ABOUT THE TREE, NOT AN EDIT TO THE EVIDENCE.
// Positions always index the ORIGINAL input.  Nothing is ever inserted into,
// deleted from, or substituted in the input -- not even transiently.  There are
// exactly two repair operations, and both are ANNOTATIONS ON THE TREE:
//
//   SKIP(p, n)  n characters at p that no clause explains.  Emitted as a
//               `SyntaxError` span child, exactly the node the frozen library
//               already uses for unmatched input.
//   FILL(c, p)  a clause c the grammar requires at p, for which the evidence
//               shows nothing.  Emitted as a ZERO-WIDTH `Filled` node, so the
//               tree gets the right SHAPE without the input gaining a character.
//
// Both preserve the invariant that a position indexes the original input: SKIP
// advances past real characters, FILL advances nothing.  That invariant is the
// whole proof of A4 below.
//
// I36: SYNTHESIS IS LEGAL EXACTLY WHERE IT CHOOSES NOTHING.
// The owner's rule -- "never invent a terminal of a class that isn't there (why
// pick 0?), but you may act as if a missing paren or brace were present" -- is
// not two rules.  It is one, and it is measurable: FILL a clause iff the clause
// has a UNIQUE MINIMAL WITNESS.  `')'` has one string of minimal length; `[0-9]`
// has ten; `"true" / "false"` has two.  Synthesizing the unique witness adds no
// information that was not already in the grammar, so it fabricates nothing;
// synthesizing one of ten is a choice, and a choice about content the evidence
// does not contain is fabrication.  This is m77's I33 ("destruction is the widest
// description") turned from a COST into a GATE, and it settles both of the
// owner's acceptance cases with no tie-break model at all:
//
//   `,3true`  the Seq needs `,` between two values.  `,` is the unique minimal
//             witness of that clause -> FILL legal -> reads as `,3,true`.
//   `[,2,`    keeping the leading comma needs a Value before it.  Value's minimal
//             witnesses include every digit, `[`, `{`, `"`, `true`, `false`,
//             `null` -> not unique -> FILL ILLEGAL -> the comma is SKIPped.
//
// The regret model, the (invention, loss) key and the (edits, invention,
// description) key are all deleted.  Nothing here is tuned.
//
// I37: THE BUDGET IS A SECOND memoVersion.
// The frozen `MemoEntry` already solves "a cached answer became stale" WITHOUT
// EVICTION: it stamps each entry with `memoVersion[pos]` and simply declines to
// read a stamp from an older left-recursion generation.  Cost is the same shape
// of problem, so it gets the same shape of answer -- a cell records the budget it
// was computed under and is re-derived, never evicted, when asked at a higher
// one.  A cell that succeeded at COST 0 is final forever: nothing can be cheaper,
// and a zero-cost match is what pure PEG returns.  So the undamaged part of a
// document is parsed exactly once no matter how many budgets are explored, and a
// clean document costs exactly one pure parse.
//
// A4, PROVED RATHER THAN ASSUMED.  A lookahead is a predicate over the evidence,
// and by I35 the evidence never changes, so `&e` / `!e` at p is decided by the
// PURE parser reading the ORIGINAL input at p.  No residual, no derivative, no
// product DFA, no obligation in the memo key.  This is not a relaxation that
// costs corner cases -- it is EXACT for every predicate body, including the
// nested ones the owner explicitly excused.  m78 needed 400 lines to approximate
// what costs zero lines once the input stops moving.
//
// KNOWN LOSS, NAMED.  One family gets worse, and it is worth stating plainly
// because it is the price of A4.  `S <- A 'b'; A <- 'a' &'b';` on `"a"`: the
// string-repair engines insert a `b` and let A's lookahead read the character
// they just invented, scoring cost 1.  Here the lookahead reads the evidence,
// which is EOF, so A's guard is discharged by FILL (its body has a unique minimal
// witness) and the `'b'` is filled again -- the tree is right, the cost reads 2
// where the old oracle says 1.  That is an over-report against a metric that
// assumes the input can be edited, which is the metric this engine rejects.
//
// PEG CONFORMANCE IS PRESERVED BY CONSTRUCTION, not by a conformance pass: a
// cost-0 match SHORT-CIRCUITS every choice point, so at cost 0 `First` returns
// its first matching alternative, `Repetition` is possessive, and no repair is
// ever considered.  Recovery is reachable only where pure PEG has already failed.

import 'package:squirrel_parser/squirrel_parser.dart';


/// A/B ONLY. 0 = m79 as written (got, cost, end).
///   1 = cost, got, end
///   2 = cost, end, got
///   3 = as 1, except `First` uses cost alone -- so a tie in cost is broken by
///       PEG's own ordered choice, which is the earliest alternative.
///   4 = as 3, but `First` prefers the earliest alternative that reaches
///       furthest at equal cost.
int abMode = 0;

bool _cmp(int ag, int ac, int ae, int bg, int bc, int be, bool isFirst) {
  if (isFirst && abMode == 3) return ac < bc;
  if (isFirst && abMode == 4) return ac < bc || (ac == bc && ae > be);
  switch (abMode) {
    case 1:
    case 3:
    case 4:
      if (ac != bc) return ac < bc;
      if (ag != bg) return ag > bg;
      return ae > be;
    case 2:
      if (ac != bc) return ac < bc;
      if (ae != be) return ae > be;
      return ag > bg;
    default:
      if (ag != bg) return ag > bg;
      if (ac != bc) return ac < bc;
      return ae > be;
  }
}

// ---------------------------------------------------------------------------
// The two repair marks.  Both are `Match` subclasses, so `treeShape`, `covers`
// and `buildAST` in the frozen library consume them with no changes.

/// Zero-width stand-in for text the grammar DETERMINES must be here, but which
/// the evidence does not show.  Legal only where [_witness] is unique.
class Filled extends Match {
  Filled(Clause? c, int pos, this.text) : super(c, pos, 0);

  /// The unique minimal witness of the filled clause.
  final String text;

  @override
  String toPrettyString(String input, {int indent = 0}) =>
      '${'  ' * indent}<Filled ${clause ?? '?'}>: "$text"\n';
}

// ---------------------------------------------------------------------------

/// One memo cell.  Successes are PERMANENT; failures carry the budget that
/// established them.  Nothing is ever evicted.
class _Cell {
  /// The best match found so far, or null if none has been found yet.
  MatchResult? win;

  /// Repair cost of [win], the end position it reached, and how many characters
  /// of real evidence it explained.
  int cost = 0, end = 0, got = 0;

  /// Highest budget this cell has been derived under. A cell is re-derived, not
  /// evicted, when asked at a higher budget -- unless [cost] is 0, which is
  /// final. Also the stamp for a failure: a failure at budget b says nothing
  /// about budget b+1.
  int at = -1;

  /// Left recursion, exactly as the frozen `MemoEntry` does it.
  bool inPath = false, foundLR = false;
  int gen = -1;
}

/// The outcome of matching a clause: a tree, what it cost, where it ended, and
/// how many characters of real evidence it explained.
class _Out {
  const _Out(this.m, this.cost, this.end, this.got);
  final MatchResult m;
  final int cost, end, got;
}

/// The outcome of matching one SEQUENCE ELEMENT, which may carry a leading skip.
class _El {
  const _El(this.nodes, this.cost, this.end, this.got);
  final List<MatchResult> nodes;
  final int cost, end, got;
}

// ---------------------------------------------------------------------------

class SuperDot3 {
  SuperDot3({required Map<String, Clause> rules, required this.topRuleName})
      : rules = {} {
    for (final e in rules.entries) {
      final name = e.key.startsWith('~') ? e.key.substring(1) : e.key;
      this.rules[name] = e.value;
      if (e.key.startsWith('~')) transparent.add(name);
    }
  }

  final Map<String, Clause> rules;
  final Set<String> transparent = {};
  final String topRuleName;

  /// Cost of the last [recover]; -1 if no whole-input tree was reachable.
  int lastCost = -1;

  String _in = '';
  List<int> _gen = const [];
  final Map<Clause, Map<int, _Cell>> _memo = {};

  // -------------------------------------------------------------------------
  // I36: the unique minimal witness.
  //
  // `(minimum length, the unique string of that length)`. A null string means
  // the minimum is reached by more than one string (or by none), and synthesis
  // would therefore be a CHOICE -- which is exactly what must never happen.
  // Recursive rules need a least fixed point, so lengths start at "unreachable"
  // and the pass repeats until nothing moves.

  static const int _inf = 1 << 29;
  final Map<Clause, (int, String?)> _wit = {};
  bool _witReady = false;

  bool _moved = false;

  void _solveWitnesses() {
    if (_witReady) return;
    _witReady = true;
    do {
      _moved = false;
      for (final body in rules.values) {
        _visitWitness(body, {});
      }
    } while (_moved);
  }

  /// Least fixed point: a clause on the current path is "unreachable so far",
  /// which is what makes a recursive rule converge upward to its true minimum
  /// rather than declaring itself free.
  void _visitWitness(Clause c, Set<Clause> path) {
    if (!path.add(c)) return;
    (int, String?) v;
    switch (c) {
      case Str s:
        v = (s.text.length, s.text);
      case Char ch:
        v = (ch.char.length, ch.char);
      case CharSet cs:
        // Unique only when the set names exactly one code unit. An inverted set
        // names 65535 of them, so it never qualifies.
        final one = !cs.inverted &&
            cs.ranges.length == 1 &&
            cs.ranges[0].$1 == cs.ranges[0].$2;
        v = (1, one ? String.fromCharCode(cs.ranges[0].$1) : null);
      case AnyChar _:
        v = (1, null); // 65536 choices
      case Nothing _:
        v = (0, '');
      case Seq s:
        var n = 0;
        var w = StringBuffer();
        String? text = '';
        for (final sub in s.subClauses) {
          _visitWitness(sub, path);
          final (ln, t) = _wit[sub] ?? (_inf, null);
          n += ln;
          if (t == null) {
            text = null;
          } else {
            w.write(t);
          }
        }
        v = (n > _inf ? _inf : n, text == null ? null : w.toString());
      case First f:
        var best = _inf;
        String? text;
        var many = false;
        for (final sub in f.subClauses) {
          _visitWitness(sub, path);
          final (ln, t) = _wit[sub] ?? (_inf, null);
          if (ln < best) {
            best = ln;
            text = t;
            many = t == null;
          } else if (ln == best && ln < _inf) {
            // A second way to reach the same minimal length: unique only if it
            // spells the same string.
            if (t == null || t != text) many = true;
          }
        }
        v = (best, many ? null : text);
      case Repetition r:
        _visitWitness(r.subClause, path);
        final (ln, t) = _wit[r.subClause] ?? (_inf, null);
        // `e*` is minimally empty; `e+` is minimally one `e`.
        v = r.requireOne ? (ln, t) : (0, '');
      // These three are minimally empty, but their BODIES still need solving:
      // every clause the engine may be asked to FILL has to be reachable from
      // this walk, and a `,` that lives inside `(... ',' ...)?` is otherwise
      // never visited at all.
      case Optional o:
        _visitWitness(o.subClause, path);
        v = (0, '');
      case FollowedBy f:
        _visitWitness(f.subClause, path);
        v = (0, ''); // zero-width; nothing to synthesize
      case NotFollowedBy n:
        _visitWitness(n.subClause, path);
        v = (0, '');
      case Ref r:
        final body = rules[r.ruleName];
        if (body == null) {
          v = (_inf, null);
        } else {
          _visitWitness(body, path);
          v = _wit[body] ?? (_inf, null);
        }
      default:
        v = (_inf, null);
    }
    path.remove(c);
    final old = _wit[c];
    if (old == null || old.$1 != v.$1 || old.$2 != v.$2) {
      _wit[c] = v;
      _moved = true;
    }
  }

  /// The text a FILL of [c] would stand for, or null if synthesis would be a
  /// choice. Zero-width clauses return `''`, which fills for free.
  String? _witness(Clause c) {
    final v = _wit[c];
    if (v == null || v.$1 >= _inf) return null;
    return v.$2;
  }

  // -------------------------------------------------------------------------
  // Entry points.

  /// Recover a whole-input tree over [s]. The input is never modified.
  MatchResult recover(String s) {
    _in = s;
    _memo.clear();
    _gen = List.filled(s.length + 1, 0);
    _solveWitnesses();

    final top = rules[topRuleName];
    if (top == null) throw ArgumentError('Rule "$topRuleName" not found');

    // The search is bounded, and the bound is DERIVED, not chosen: every
    // character can be skipped (|s|) and the shortest completion of the top rule
    // can be filled (its minimal witness length), so no whole-input tree needs
    // more than that. If the top rule has no finite fillable completion, skipping
    // the whole input is still the ceiling.
    final (topLen, _) = _wit[top] ?? (_inf, null);
    final ceiling = s.length + (topLen >= _inf ? 0 : topLen);

    for (var b = 0; b <= ceiling; b++) {
      final r = _whole(top, b);
      if (r != null) {
        lastCost = r.cost;
        return r.m;
      }
    }
    lastCost = -1;
    return SyntaxError(pos: 0, len: s.length);
  }

  /// The repair cost of [s], or -1 if no whole-input tree was reachable.
  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }

  /// The top rule, required to span the whole input. Input the top rule does not
  /// explain is a trailing SKIP and is charged for -- which is what makes the
  /// budget a GLOBAL objective, and what stops a construct from closing early and
  /// leaving the rest as somebody else's problem.
  _Out? _whole(Clause top, int b) {
    final e = _element(top, 0, b);
    if (e == null) return null;
    final nodes = [...e.nodes];
    var cost = e.cost;
    if (e.end < _in.length) {
      final n = _in.length - e.end;
      if (cost + n > b) return null;
      cost += n;
      nodes.add(SyntaxError(pos: e.end, len: n));
    }
    return _Out(Match(null, 0, _in.length, subClauseMatches: nodes), cost,
        _in.length, e.got);
  }

  // -------------------------------------------------------------------------
  // The matcher. `_clause` is structural (no memo); `_rule` memoizes, exactly as
  // the frozen parser memoizes only at rule granularity.

  _Out? _clause(Clause c, int pos, int b) {
    if (pos > _in.length || b < 0) return null;
    switch (c) {
      case Ref r:
        final body = rules[r.ruleName];
        if (body == null) throw ArgumentError('Rule "${r.ruleName}" not found');
        final o = _rule(body, pos, b);
        if (o == null) return null;
        return _Out(Match(r, 0, 0, subClauseMatches: [o.m]), o.cost, o.end, o.got);

      case Seq s:
        return _seq(s, s.subClauses, pos, b);

      case First f:
        return _first(f, pos, b);

      case Repetition r:
        return _rep(r, pos, b);

      case Optional o:
        // PEG prefers the body. Under repair, prefer whichever explains more
        // evidence; matching nothing explains none, so a body that recovers real
        // content wins -- this is what stops `[,2,` from reading as an empty
        // array with the rest thrown away.
        final e = _element(o.subClause, pos, b);
        if (e == null || e.got == 0) return _Out(Match(o, pos, 0), 0, pos, 0);
        return _Out(Match(o, 0, 0, subClauseMatches: e.nodes), e.cost, e.end,
            e.got);

      case FollowedBy f:
        // A4: predicates read the ORIGINAL input, at cost 0.
        if (_clause(f.subClause, pos, 0) != null) {
          return _Out(Match(f, pos, 0), 0, pos, 0);
        }
        // The evidence does not show it. If the grammar DETERMINES what belongs
        // here (I36), the guard may be discharged by asserting it; otherwise the
        // guard stands and the match fails.
        final w = _witness(f.subClause);
        if (w != null && w.length <= b) {
          return _Out(Filled(f, pos, w), w.length, pos, 0);
        }
        return null;

      case NotFollowedBy n:
        // A negative guard can only be satisfied by REMOVING evidence, and
        // removal is a SKIP, which belongs to the enclosing sequence. There is
        // nothing to synthesize, so this stays exactly pure PEG.
        if (_clause(n.subClause, pos, 0) == null) {
          return _Out(Match(n, pos, 0), 0, pos, 0);
        }
        return null;

      case Terminal t:
        final m = _term(t, pos);
        if (m != null) return _Out(m, 0, pos + m.len, m.len);
        return null;

      default:
        return null;
    }
  }

  /// Terminals, matched against the original input. Deliberately a copy of the
  /// frozen library's terminal semantics rather than a call into it, so the
  /// engine owns every decision it makes about the evidence.
  Match? _term(Terminal t, int pos) {
    switch (t) {
      case Str s:
        if (pos + s.text.length > _in.length) return null;
        for (var i = 0; i < s.text.length; i++) {
          if (_in.codeUnitAt(pos + i) != s.text.codeUnitAt(i)) return null;
        }
        return Match(s, pos, s.text.length);
      case Char c:
        if (pos >= _in.length) return null;
        return _in.codeUnitAt(pos) == c.char.codeUnitAt(0)
            ? Match(c, pos, 1)
            : null;
      case CharSet cs:
        if (pos >= _in.length) return null;
        final u = _in.codeUnitAt(pos);
        var inSet = false;
        for (final (lo, hi) in cs.ranges) {
          if (u >= lo && u <= hi) {
            inSet = true;
            break;
          }
        }
        return (cs.inverted ? !inSet : inSet) ? Match(cs, pos, 1) : null;
      case AnyChar _:
        return pos < _in.length ? Match(t, pos, 1) : null;
      case Nothing _:
        return Match(t, pos, 0);
      default:
        return null;
    }
  }

  // -------------------------------------------------------------------------

  /// I37: memoization with the budget as a second `memoVersion`, and left
  /// recursion handled exactly as the frozen `MemoEntry` handles it -- the frame
  /// that ENTERED the cycle iterates, the frame that CLOSED it only signals.
  _Out? _rule(Clause body, int pos, int b) {
    final cell = (_memo[body] ??= {}).putIfAbsent(pos, _Cell.new);

    final fresh = cell.inPath || cell.gen == _gen[pos];
    if (cell.win != null && fresh && (cell.cost == 0 || cell.at >= b)) {
      // A cost-0 answer is pure PEG's answer and can never be improved on, so it
      // is valid at every budget.
      return cell.cost <= b
          ? _Out(cell.win!, cell.cost, cell.end, cell.got)
          : null;
    }
    if (cell.inPath) {
      // Second visit with no result yet: the fixed point of a left recursive
      // cycle. Signal the ancestral frame and seed with a mismatch.
      cell.foundLR = true;
      return null;
    }
    if (cell.win == null && fresh && cell.at >= b) return null;

    cell.inPath = true;
    while (true) {
      final r = _clause(body, pos, b);
      if (r == null) break;
      // Progress, in the order that decides everything here: explain more
      // evidence, else cost less, else reach further.
      final better = cell.win == null ||
          _cmp(r.got, r.cost, r.end, cell.got, cell.cost, cell.end, false);
      if (!better) break;
      cell
        ..win = r.m
        ..cost = r.cost
        ..end = r.end
        ..got = r.got;
      if (!cell.foundLR) break;
      cell.gen = ++_gen[pos];
    }
    cell.inPath = false;
    cell.gen = _gen[pos];
    cell.at = b;
    if (cell.win == null || cell.cost > b) return null;
    return _Out(cell.win!, cell.cost, cell.end, cell.got);
  }

  // -------------------------------------------------------------------------

  _Out? _seq(Clause owner, List<Clause> subs, int pos, int b) {
    final kids = <MatchResult>[];
    var cur = pos, used = 0, got = 0;
    for (final sub in subs) {
      final e = _element(sub, cur, b - used);
      if (e == null) return null;
      kids.addAll(e.nodes);
      cur = e.end;
      used += e.cost;
      got += e.got;
    }
    if (kids.isEmpty) return _Out(Match(owner, pos, 0), 0, pos, 0);
    return _Out(Match(owner, 0, 0, subClauseMatches: kids), used, cur, got);
  }

  _Out? _first(First f, int pos, int b) {
    _Out? best;
    for (final a in f.subClauses) {
      final r = _clause(a, pos, b);
      if (r == null) continue;
      if (r.cost == 0) {
        // Pure PEG: the first alternative that the evidence supports outright
        // wins, and no repair is considered. This is what keeps conformance.
        return _Out(Match(f, 0, 0, subClauseMatches: [r.m]), 0, r.end, r.got);
      }
      if (best == null ||
          _cmp(r.got, r.cost, r.end, best.got, best.cost, best.end, true)) {
        best = r;
      }
    }
    if (best == null) return null;
    return _Out(Match(f, 0, 0, subClauseMatches: [best.m]), best.cost, best.end,
        best.got);
  }

  _Out? _rep(Repetition r, int pos, int b) {
    final kids = <MatchResult>[];
    var cur = pos, used = 0, got = 0;
    while (cur <= _in.length) {
      final e = _element(r.subClause, cur, b - used);
      // A repetition exists to consume evidence. An iteration that explains no
      // characters is not evidence of a repetition -- and it is also what would
      // make a fillable body loop forever. One rule retires both problems, and
      // it subsumes the frozen parser's zero-length guard.
      if (e == null || e.got == 0) break;
      kids.addAll(e.nodes);
      cur = e.end;
      used += e.cost;
      got += e.got;
    }
    if (kids.isEmpty) {
      if (!r.requireOne) return _Out(Match(r, pos, 0), 0, pos, 0);
      // `e+` still needs one. Allow a body that explains nothing only here.
      final e = _element(r.subClause, pos, b);
      if (e == null) return null;
      return _Out(Match(r, 0, 0, subClauseMatches: e.nodes), e.cost, e.end,
          e.got);
    }
    return _Out(Match(r, 0, 0, subClauseMatches: kids), used, cur, got);
  }

  // -------------------------------------------------------------------------

  /// Match one element, which is the ONLY place a repair is introduced.
  ///
  /// Three ways to satisfy a required clause, in the order the evidence supports
  /// them: match it outright; SKIP characters that explain nothing and then match
  /// it; or, if and only if the grammar determines the text (I36), FILL it.
  ///
  /// A cost-0 direct match short-circuits, so on undamaged input this function is
  /// exactly `clause.match(parser, pos)` and costs the same.
  _El? _element(Clause sub, int pos, int avail) {
    if (avail < 0) return null;

    final d = _clause(sub, pos, avail);
    if (d != null && d.cost == 0) return _El([d.m], 0, d.end, d.got);

    _El? best = d == null ? null : _El([d.m], d.cost, d.end, d.got);

    for (var k = 1; k <= avail && pos + k <= _in.length; k++) {
      final r = _clause(sub, pos + k, avail - k);
      if (r == null) continue;
      final cand = _El(
          [SyntaxError(pos: pos, len: k), r.m], k + r.cost, r.end, r.got);
      if (_beats(cand, best)) best = cand;
      if (r.cost == 0) break; // nothing further right is cheaper for the same k
    }

    final w = _witness(sub);
    if (w != null && w.length <= avail) {
      final cand = _El([Filled(sub, pos, w)], w.length, pos, 0);
      if (_beats(cand, best)) best = cand;
    }
    return best;
  }

  /// THE ONE ORDERING IN THE ENGINE, and every choice point uses it: explain more
  /// of the evidence; failing that, claim less; failing that, reach further. It
  /// is the owner's objective stated directly -- "recover as much of the expected
  /// AST shape as possible, with the minimal set of changes" -- rather than a
  /// proxy for it, and it has no parameters.
  bool _beats(_El a, _El? b) =>
      b == null || _cmp(a.got, a.cost, a.end, b.got, b.cost, b.end, false);
}
