// r13.dart -- the brief's own architecture, on a core that keeps its mismatches.
//
//   1. parse            the pure squirrel parser, unmodified input, one memo table
//   2. frontier finding READ the leaf mismatches off the partial AST
//   3. span widening    for l = 1, 2, ..., ask each frontier clause whether it
//                       matches l characters later; take the first that does
//   4. advancement      install `syntax error + match` at that (clause, pos) and
//                       re-descend, keeping every memo entry that never read it
//   5. resume           repeat until the top rule spans the input
//
// WHAT IS DIFFERENT FROM r7, WHICH IS THE SAME ARCHITECTURE. Two things, both of
// them consequences of `_core2.dart`.
//
// Stage 2 is a tree walk. r7's design note says why it could not be: "`Seq.match`
// discards its partial children on failure -- it returns the bare `mismatch`
// singleton. There is therefore no partial AST to traverse." So r7 re-derives the
// failed descent by re-matching, in `_walk`/`_descend`/`_stops`. A `_core2`
// mismatch is a node with a position, a real consumed length and its subclause
// results, so the failing side of the frontier is read rather than recomputed.
//
// Stage 4 is a continuation, not a re-parse. r7 scores each candidate with
// `_forget()` + a full cold parse -- measured, 114 re-parses per case, and that
// is its 7180 ms. Here the input never changes and the memo table persists;
// installing a repair at position p invalidates exactly the entries that could
// have read p, by the same `readEnd < e` rule the core already carries for
// incremental re-parse. Everything before the repair is a memo hit.
//
// The frontier is exact rather than approximate, so the brief's list is actually
// the leaves of the failure, and stage 3 is asked of the right sites.
//
// THE GRAMMAR SIDE (from r11). r10 is the brief taken literally and is
// deletion-only: 0.6440, worst at truncate (0.403), which is the case where
// there is nothing to delete -- the document simply stopped. The owner's own
// unification says what is missing:
//
//   "the first case is deletion of input characters, the second case is deletion
//    of grammar clauses"
//
// So the widening loop's `l` is not a span, it is a PRICE, and at each price two
// operations are offered at every frontier site: deny `l` characters the grammar
// did not want, or give up a clause that wanted `l` characters the input never
// supplied. Same unit, one loop, no tuning constant. `_minFill(c)` is that
// price: the least fixed point over the grammar of "cheapest way to satisfy this
// clause with no input at all".
//
// THE SCORE (from r12). The two operations cannot share the brief's
// first-match-wins rule -- a give-up supplies what the clause wanted, so it can
// never fail, and the earliest leaf priced l is committed before anything else
// at that price is tried; r11 measures that at 0.3143. So every candidate at
// price l is installed, re-descended, scored over the whole tree and uninstalled,
// and the cheapest is committed. 18 us per trial, because stage 4 is a memo-hit
// continuation and not a re-parse.
//
// WHAT r13 ADDS. Four corrections, each measured on its own:
//
//   * THE SHALLOW SIDE. The brief's frontier is the leaf mismatches only. But an
//     interior clause that failed can be given up as a unit, and that is the
//     "deletion of grammar clauses" half of the unification -- a whole subtree
//     the input never supplied. `_failDescend` adds every failed clause, not
//     only the leaves.
//   * COMPLETENESS LEADS THE COST. A partial derivation that happens to reach
//     the end of input read as free, so on `{` nothing could be strictly cheaper
//     than salvaging the object and stopping: score 0.000 against r7's 1.000.
//     The first cost key is now `whole`.
//   * ABANDONING AN OBLIGATION COSTS WHAT GIVING IT UP COSTS. `_salvage` used to
//     walk away from the unsatisfied tail of a `Seq` for free while the give-up
//     that satisfied the same tail was charged, so deciding always cost more
//     than not deciding and `(` deadlocked. `_owed`/`_owedAt` price the walked-
//     away tail identically, and the 4th cost key breaks ties toward deciding.
//   * A `First` SALVAGES BY ITS FURTHEST ARM. Breaking at arm 0 threw away later
//     arms' derivations: on `(` the arm `Num` derives nothing, so `Factor`
//     salvaged to null and the `'('` the parse had already matched was
//     discarded. truncate 0.784 -> 0.836.
//
// A fifth fix was in the core, not here: `MemoEntry.match` seeded a left-
// recursive cycle with a childless `Mismatch(clause, pos, 0)` and, on breaking
// with both sides mismatching, kept the SEED instead of the structured failure.
// On `(a` the whole expr grammar then offered a one-site frontier and salvaged
// nothing, so recovery deleted the `(` instead of supplying the `)`. With the
// informative mismatch kept, the same input offers 35 sites.
//
// WHERE THIS LANDS. 0.9008 / 51.9% perfect / 6829 ms / 327 lines, against r7 --
// the same architecture without an exact frontier -- at 0.8970 / 51.4% / 7116 ms
// / 492 lines. So the brief's architecture, given a core that keeps its
// mismatches, is worth 0.90 and 327 lines. What it is not worth is r9's 0.9721
// at 1630 ms, and the reason is measured, not guessed: 123.7 candidate trials
// per case, 4121 of 5966 ms in the re-descents. An exact frontier makes each
// candidate about twice as cheap; it does not make fewer of them. Only not
// enumerating does, which is what r9 does.

import 'package:squirrel_parser/squirrel_parser.dart' as sp;

import '_core2.dart';

class Squirrel {
  final String topRuleName;
  final Parser _p;
  final Map<Clause, sp.Clause> _back;

  factory Squirrel(
      {required Map<String, sp.Clause> rules, required String topRuleName}) {
    final back = <Clause, sp.Clause>{};
    final core = rulesToCore(rules, back);
    return Squirrel._(
        Parser(rules: core, topRuleName: topRuleName, input: ''), back, topRuleName);
  }

  Squirrel._(this._p, this._back, this.topRuleName);

  /// The frontier, in postorder: deepest and earliest first, which is the order
  /// the brief asks for so that a repair is as localized as it can be.
  final List<(Clause, int)> _frontier = [];
  final Set<(Clause, int)> _seen = {};
  final Map<MatchResult, bool> _walked = {};
  final Map<MatchResult, MatchResult?> _salved = {};

  /// What the current salvage walked away from, in the same unit a give-up is
  /// priced in. Reset per [_cost].
  int _owed = 0;

  /// Characters the current tree already accounts for. A repair may not deny
  /// one: the input is primal, and a span the parse read is evidence.
  List<bool> _held = const [];

  /// Sites already given up. A give-up consumes nothing, so unlike a denial it
  /// leaves no mark in [_held] to stop it being offered again.
  final Set<(Clause, int)> _given = {};

  sp.MatchResult recover(String s) {
    _p.repairs = null;
    _p.retarget(s, 0);
    _given.clear();
    var root = _p.matchRule(topRuleName, 0);
    // A denial consumes at least one character no round denied before, and a
    // give-up retires a `(clause, pos)` that is never offered again, so every
    // round makes progress against one of two finite quantities.
    for (var round = 0; round <= 4 * s.length + 16; round++) {
      if (!root.isMismatch && root.len == s.length) break;
      final next = _round(root, s.length);
      if (next == null) break;
      root = next;
    }
    return toLib(_emit(root, s.length), _back);
  }

  // -- stages 3, 4 and 5 -----------------------------------------------------

  /// One widening round: at the cheapest price that buys anything, take the
  /// repair that leaves the whole document best explained. Null when none does.
  ///
  /// A CANDIDATE MUST BEAT THE CURRENT TREE, and for that the two have to be
  /// priced in the same currency. Letting the round commit its best offer
  /// unconditionally instead gives up `Stmt+` at 0 -- the entire program, for
  /// the price of the cheapest statement -- and scores the whole stmt corpus
  /// 0.000, because at every price SOMETHING is always on offer.
  ///
  /// r11 committed on the FIRST offer that matched, which is what the brief asks
  /// for and what r10 does. That rule works only while every offer can fail: a
  /// deletion is self-selecting, because it counts only if a real match follows
  /// it. A give-up cannot fail -- it needs no input -- so under first-match-wins
  /// the earliest frontier leaf priced 1 is taken every time and nothing is ever
  /// compared. Measured: 0.6316 -> 0.3143. Offering both sides therefore forces
  /// a comparison, and the comparison is over the WHOLE tree, because a repair
  /// is only worth what the rest of the parse then makes of it.
  MatchResult? _round(MatchResult root, int n) {
    _frontier.clear();
    _seen.clear();
    _walked.clear();
    _held = List.filled(n, false);
    _mark(root);
    if (root.isMismatch) {
      _fail(root);
    } else {
      _ok(root);
    }
    final base = _cost(root, n);
    for (var l = 1; l <= n; l++) {
      Prof.newRound();
      Prof.rounds++;
      (Clause, int, Repair)? win;
      var best = base;
      // NO FLOOR SHORT-CIRCUIT. `_paid + l` looks like a lower bound on the
      // cost and is not one: a committed repair that ends up inside a subtree
      // the parse later discards never appears in the emitted tree, so a
      // candidate can read as cheaper than everything paid for it and break the
      // scan on a false optimum. Measured, that cost 0.8571 -> 0.8541 for 13%
      // of the latency.
      for (final (c, p) in _frontier) {
        // THE GRAMMAR SIDE. This clause wanted `l` characters the document never
        // supplied, so give it up and mark them missing. Nothing is invented and
        // no character is denied, which is what makes the end of a truncated
        // document recoverable at all -- the input side has nothing to work with
        // there, because there is no input left to deny.
        if (!_given.contains((c, p)) &&
            _minFill(c) == l &&
            (!Prof.collapse || Prof.first('g|$p|$l'))) {
          final gap = Repair(
              Match(null, 0, 0, subClauseMatches: [
                for (var j = 0; j < l; j++) SyntaxError(pos: p, len: 0),
              ]),
              p);
          final got = _try(c, p, gap, n);
          Prof.give++;
          if (Prof.dup('g|$p|$l|$got')) Prof.giveDup++;
          Prof.group('g|$p|$l', '$got');
          Prof.size('g|$p|$l');
          if (_cheaper(got, best)) {
            best = got;
            win = (c, p, gap);
          }
        }
        if (p + l > n) continue;
        var denies = false;
        for (var i = p; i < p + l; i++) {
          if (_held[i]) {
            denies = true;
            break;
          }
        }
        if (denies) continue;
        // Bracket the trial so the repair carries its own read extent, which is
        // what lets a LATER repair invalidate whatever read this one.
        final saved = _p.maxRead;
        _p.maxRead = -1;
        Prof.sub++;
        final r = _p.matchSub(c, p + l);
        final readEnd = _p.maxRead;
        _p.maxRead = saved > readEnd ? saved : readEnd;
        if (r.isMismatch) continue;
        // A zero-length match explains nothing and denies l characters to buy
        // it. A predicate is the exception -- it is zero-width by definition,
        // and a `!X` that failed here and succeeds l along IS the recovery.
        if (r.len == 0 && !(c is FollowedBy || c is NotFollowedBy)) continue;
        final cut = Repair(
            Match(null, 0, 0,
                subClauseMatches: [SyntaxError(pos: p, len: l), r]),
            readEnd);
        Prof.subKept++;
        final got = _try(c, p, cut, n);
        Prof.deny++;
        if (Prof.dup('d|$p|$l|$got')) Prof.denyDup++;
        Prof.group('d|$p|$l', '$got');
        Prof.size('d|$p|$l');
        if (_cheaper(got, best)) {
          best = got;
          win = (c, p, cut);
        }
      }
      if (win == null) continue;
      final (c, p, fix) = win;
      if (fix.node.len == 0) _given.add((c, p));
      ((_p.repairs ??= {})[c] ??= {})[p] = fix;
      _invalidate(p);
      return _p.matchRule(topRuleName, 0);
    }
    return null;
  }

  /// Install a candidate, re-descend, cost the result, and take it back out.
  /// The re-descent is a continuation: everything the repair could not have been
  /// read by is a memo hit, so this is not r7's cold re-parse.
  (int, int, int, int) _try(Clause c, int p, Repair fix, int n) {
    final at = (_p.repairs ??= {}).putIfAbsent(c, () => {});
    at[p] = fix;
    _invalidate(p);
    final got = _cost(_p.matchRule(topRuleName, 0), n);
    at.remove(p);
    _invalidate(p);
    return got;
  }

  /// What a tree costs: whether it is a parse at all, then characters denied,
  /// then obligations left open.
  ///
  /// COMPLETENESS LEADS, and it is not a tuning knob -- a tree that does not
  /// derive the top rule over the whole input is not a candidate answer, it is
  /// a failure with some structure attached. Costing it on denials alone reads
  /// a partial derivation that happens to reach the end as FREE: on the input
  /// `{` the salvaged object covers its one character with no syntax error, so
  /// it costs (0, 0), no repair can be strictly cheaper, and the recovery gives
  /// up on a document one character long. Measured, that case scored 0.000
  /// against r7's 1.000, and truncate as a whole 0.706 against 0.839.
  ///
  /// Denials then dominate obligations, because the input is primal: no number
  /// of missing tokens justifies throwing away one character the document
  /// really contains.
  (int, int, int, int) _cost(MatchResult root, int n) {
    _salved.clear();
    _owed = 0;
    final t = root.isMismatch ? _salvage(root) : root;
    if (t == null) return (1, n + 1, 0, 0);
    final whole = !root.isMismatch && root.pos + root.len == n ? 0 : 1;
    var del = n - (t.pos + t.len);
    var gap = 0;
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        if (m.len > 0) {
          del += m.len;
        } else {
          gap++;
        }
        return;
      }
      for (final k in m.subClauseMatches) {
        walk(k);
      }
    }

    walk(t);
    // Same currency on both sides. A clause the salvage walked away from is an
    // unmet obligation exactly like one a give-up paid for, so it is charged at
    // the same `_minFill` -- otherwise abandoning is free and deciding costs,
    // and the round can never take the step that makes a failure explicit. The
    // last key then separates the two at equal price: of two trees that owe the
    // same, the one that has DECIDED more of it is further along, which is what
    // lets `(` give up `Expr` and then, next round, `')'`.
    return (whole, del, gap + _owed, _owed);
  }

  bool _cheaper((int, int, int, int) a, (int, int, int, int) b) {
    if (a.$1 != b.$1) return a.$1 < b.$1;
    if (a.$2 != b.$2) return a.$2 < b.$2;
    if (a.$3 != b.$3) return a.$3 < b.$3;
    return a.$4 < b.$4;
  }

  /// Drop every memo entry that could have read position [p], and no others.
  ///
  /// Sound because matching a clause at [p] and mismatching there always reads
  /// index [p] or later -- a terminal reads it, a repetition reads its loop
  /// bound, a `First` reads through every failed arm, and a `Ref` propagates its
  /// entry's own extent. So an entry whose descent reached the repaired site has
  /// `readEnd >= p`, and every entry kept here provably never saw it.
  void _invalidate(int p) {
    for (final byPos in _p.memoTable.values) {
      byPos.removeWhere((pos, e) => pos >= p || e.readEnd >= p);
    }
  }

  /// Mark what the tree accounts for: every leaf that spans characters, which is
  /// every terminal match and every syntax error already committed.
  void _mark(MatchResult m) {
    if (m.subClauseMatches.isEmpty) {
      for (var i = m.pos; i < m.pos + m.len && i < _held.length; i++) {
        _held[i] = true;
      }
      return;
    }
    for (final k in m.subClauseMatches) {
      _mark(k);
    }
  }

  // -- the price of giving a clause up ---------------------------------------

  static const int _never = 1 << 30;
  final Map<Clause, int> _fill = {};

  /// The fewest characters any derivation of [c] can consume -- what giving [c]
  /// up costs. A least fixed point, because a rule's floor depends on the floors
  /// of the rules it calls, and a cycle with no base case has none: `S <- S;` has
  /// no finite derivation, so its floor stays at [_never] and it is never given
  /// up rather than given up for free.
  int _minFill(Clause c) {
    if (_fill.isEmpty) {
      final all = <Clause>[];
      void collect(Clause k) {
        if (_fill.containsKey(k)) return;
        _fill[k] = _never;
        all.add(k);
        if (k is Ref) {
          collect(_p.rules[k.ruleName]!);
        } else if (k is HasOneSubClause) {
          collect(k.subClause);
        } else if (k is HasMultipleSubClauses) {
          k.subClauses.forEach(collect);
        }
      }

      _p.rules.values.forEach(collect);
      for (var moved = true; moved;) {
        moved = false;
        for (final k in all) {
          final v = _fillOf(k);
          if (v < _fill[k]!) {
            _fill[k] = v;
            moved = true;
          }
        }
      }
    }
    return _fill[c] ?? _never;
  }

  int _fillOf(Clause c) {
    if (c is Ref) return _fill[_p.rules[c.ruleName]!]!;
    if (c is Seq) {
      var n = 0;
      for (final k in c.subClauses) {
        final v = _fill[k]!;
        if (v >= _never) return _never;
        n += v;
      }
      return n;
    }
    if (c is First) {
      var n = _never;
      for (final k in c.subClauses) {
        if (_fill[k]! < n) n = _fill[k]!;
      }
      return n;
    }
    if (c is Repetition) return c.requireOne ? _fill[c.subClause]! : 0;
    // An option and a predicate are both satisfied by nothing at all.
    if (c is Optional || c is FollowedBy || c is NotFollowedBy) return 0;
    // A literal is worth its own length. r7 charges every terminal 1, which
    // prices giving up `"false"` the same as giving up one comma.
    if (c is Str) return c.text.length;
    return c is Nothing ? 0 : 1;
  }

  // -- stage 2: frontier finding ---------------------------------------------

  bool _add(Clause c, int pos) {
    if (_seen.add((c, pos))) _frontier.add((c, pos));
    return true;
  }

  /// Collect the leaf mismatches beneath a MISMATCH node, deepest first, and say
  /// whether any were found. Memoized on node identity: `Ref` hands back the
  /// memoized mismatch of the rule it names, so the failure is a DAG and the
  /// same subtree is reachable by many paths.
  bool _fail(MatchResult m) {
    final done = _walked[m];
    if (done != null) return done;
    _walked[m] = false;
    return _walked[m] = _failDescend(m);
  }

  bool _failDescend(MatchResult m) {
    final c = m.clause;
    // A repair BENEATH a predicate is invisible to the enclosing parse, because
    // a predicate consumes nothing; and repairing inside a `!X` that failed
    // would only make the body match harder. The predicate is the leaf.
    if (c is FollowedBy) return _add(c, m.pos);
    if (c is NotFollowedBy) return _add(c, m.pos);
    var any = false;
    for (final k in m.subClauseMatches) {
      if (k.isMismatch ? _fail(k) : _ok(k)) any = true;
    }
    // THE SHALLOW SIDE, which the brief's leaf rule excludes and which the
    // owner's own unification asks for: "if partial recovery was possible deeper
    // in the AST, but then a more full recovery were possible at a shallower
    // node in the AST, then effectively an entire subtree of grammar has been
    // skipped". A leaf-only frontier can give up one terminal; it can never give
    // up the rest of a truncated array, because that obligation is held by the
    // interior clause, not by any one leaf. So every mismatching clause is
    // offered -- deepest first, since the children were added above, and the
    // cost comparison decides which depth actually pays.
    if (c == null) return any;
    return _add(c, m.pos) || any;
  }

  /// The same, beneath a node that MATCHED. A match can still hold the boundary:
  /// every clause that succeeded by trying something and giving up on it threw
  /// that attempt away, and those attempts are frontier sites that no mismatch
  /// node records.
  bool _ok(MatchResult m) {
    final done = _walked[m];
    if (done != null) return done;
    _walked[m] = false;
    return _walked[m] = _okDescend(m);
  }

  bool _okDescend(MatchResult m) {
    final c = m.clause;
    if (c is FollowedBy || c is NotFollowedBy) return false;
    var any = false;
    for (final k in m.subClauseMatches) {
      if (_ok(k)) any = true;
    }
    if (c is Optional && m.subClauseMatches.isEmpty) {
      // Matched empty: the body was tried at `pos` and failed.
      if (_gaveUp(c.subClause, m.pos)) any = true;
    } else if (c is Repetition) {
      // Stopped: the body was tried once more, at the end, and failed.
      if (_gaveUp(c.subClause, m.pos + m.len)) any = true;
    } else if (c is First && m.subClauseMatches.length == 1) {
      // Every arm before the winner failed here, and one of them may have agreed
      // much further than the winner did -- `("abcd" / "ab") 'z'` on `abcX`
      // commits to `ab` at 2 while the input was consistent through 3.
      final took = m.subClauseMatches.first.clause;
      for (final s in c.subClauses) {
        if (identical(s, took)) break;
        if (_gaveUp(s, m.pos)) any = true;
      }
    }
    return any;
  }

  /// Walk one attempt a successful clause discarded. `_core2` folds a discarded
  /// subtree's frontier into an int and drops the subtree, so this is the one
  /// place the descent is re-derived -- and it is re-derived only at the sites
  /// that structurally must have discarded something, never by searching.
  bool _gaveUp(Clause c, int pos) {
    if (pos > _p.input.length) return false;
    final r = _p.matchSub(c, pos);
    return r.isMismatch && _fail(r);
  }

  // -- emit ------------------------------------------------------------------

  /// A full-coverage tree over `[0, end)` holding matches and syntax errors and
  /// nothing else. Every mismatch left over is rewritten to the derivation it
  /// still contains plus a syntax error for the rest, so no mismatch reaches the
  /// caller -- `toLib` throws if one does.
  MatchResult _emit(MatchResult m, int end) {
    _salved.clear();
    final s = m.isMismatch ? _salvage(m) : m;
    if (s == null) return SyntaxError(pos: 0, len: end);
    final e = s.pos + s.len;
    if (e >= end) return s;
    return Match(null, 0, 0,
        subClauseMatches: [s, SyntaxError(pos: e, len: end - e)]);
  }

  /// The derivation a failed clause still contains: its satisfied prefix, plus
  /// whatever the slot that broke had itself derived. Null when it derived
  /// nothing at all.
  MatchResult? _salvage(MatchResult m) {
    if (!m.isMismatch) return m;
    if (_salved.containsKey(m)) return _salved[m];
    _salved[m] = null;
    final cl = m.clause;
    // AN ORDERED CHOICE LEAVES ITS EVIDENCE IN THE ARM THAT GOT FURTHEST, not in
    // the first one. Breaking at slot 0 the way a `Seq` does throws away every
    // later arm's derivation: on `(` the arm `Num` derives nothing, so `Primary`
    // salvaged to null and the `'('` that the second arm really did match was
    // discarded along with it -- the whole one-character document came back as a
    // single syntax error, scoring 0.000 against r7's 1.000.
    if (cl is First) {
      final before = _owed;
      MatchResult? pick;
      var owedOfPick = 0;
      for (final k in m.subClauseMatches) {
        _owed = before;
        final d = _salvage(k);
        if (d != null && d.pos == m.pos && (pick == null || d.len > pick.len)) {
          pick = d;
          owedOfPick = _owed;
        }
      }
      if (pick == null) {
        _owed = before + _minFill(cl);
        return _salved[m] = null;
      }
      _owed = owedOfPick;
      return _salved[m] = Match(cl, 0, 0, subClauseMatches: [pick]);
    }
    final kids = <MatchResult>[];
    var at = m.pos;
    for (var i = 0; i < m.subClauseMatches.length; i++) {
      final k = m.subClauseMatches[i];
      if (!k.isMismatch) {
        kids.add(k);
        at = k.pos + k.len;
        continue;
      }
      final deep = _salvage(k);
      if (deep != null && deep.pos == at && deep.len > 0) kids.add(deep);
      _owed += _owedAt(m, k, i);
      break;
    }
    if (kids.isEmpty) return _salved[m] = null;
    // KEEP THE CLAUSE. A salvaged node is still an Object that failed, not an
    // anonymous bag of children, and dropping the label drops exactly what the
    // caller reads the tree for. `Match` recomputes its own span from the
    // children, so claiming the clause claims only the part that did derive.
    return _salved[m] = Match(m.clause, 0, 0, subClauseMatches: kids);
  }

  /// What clause [m] still owes, having broken at its child [k] in slot [i].
  /// For a `Seq` that is the broken slot plus every slot behind it; for anything
  /// else the clause owes one satisfying derivation of itself, and no more.
  int _owedAt(MatchResult m, MatchResult k, int i) {
    final c = m.clause;
    if (c is! Seq) return c == null ? 0 : _minFill(c);
    var owed = k.clause == null ? 0 : _minFill(k.clause!);
    for (var j = i + 1; j < c.subClauses.length; j++) {
      owed += _minFill(c.subClauses[j]);
    }
    return owed >= _never ? 0 : owed;
  }
}

void main() {
  final rules = sp.MetaGrammar.parseGrammar(
      "S <- Item+;\nItem <- 'a' 'b';\n");
  final eng = Squirrel(rules: rules, topRuleName: 'S');
  for (final s in ['abab', 'abXab', 'abaXb', 'ab', 'XXab']) {
    final t = eng.recover(s);
    print('"$s" -> ${t.runtimeType} @${t.pos}+${t.len} :: '
        '${t.toPrettyString(s).split('\n').first}');
  }
}


/// Trial counters for the enumeration-slack probe (scratch only).
class Prof {
  static int cases = 0, rounds = 0, give = 0, deny = 0, sub = 0, subKept = 0;
  static int giveDup = 0, denyDup = 0;
  /// When true, at most ONE give-up trial runs per (position, price) group --
  /// the 4x reduction the group measurement says is available. Unsound by
  /// construction: 37% of groups disagree, so the representative is arbitrary.
  static bool collapse = false;
  static final Set<String> _tried = {};
  static bool first(String k) => _tried.add(k);
  static final Set<String> _keys = {};
  /// Per round: pre-computable key `kind|pos|price` -> the distinct cost tuples
  /// the members of that group actually produced. A group with ONE distinct
  /// tuple could have been collapsed to a single representative trial with no
  /// change to the scan's outcome; a group with more could not.
  static final Map<String, Set<String>> _groups = {};
  static int groups = 0, unanimous = 0, membersInUnanimous = 0, members = 0;
  static void newRound() {
    _flush();
    _keys.clear();
    _tried.clear();
  }
  static void _flush() {
    for (final g in _groups.values) {
      groups++;
      members += g.length == 1 ? 1 : 0;
    }
    _groups.forEach((k, v) {
      if (v.length == 1) unanimous++;
    });
    _groups.clear();
  }
  static void group(String key, String tuple) =>
      (_groups[key] ??= <String>{}).add(tuple);
  static final Map<String, int> _sizes = {};
  static void size(String key) => _sizes[key] = (_sizes[key] ?? 0) + 1;
  static bool dup(String k) => !_keys.add(k);
}
