// r10.dart -- the brief's own architecture, on a core that keeps its mismatches.
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
// The frontier is exact rather than approximate, so the brief's own rule --
// commit on the FIRST match found, at the smallest span, deepest site first --
// is applied to a list that is actually the leaves of the failure.

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

  /// Characters the current tree already accounts for. A repair may not deny
  /// one: the input is primal, and a span the parse read is evidence.
  List<bool> _held = const [];

  sp.MatchResult recover(String s) {
    _p.repairs = null;
    _p.retarget(s, 0);
    var root = _p.matchRule(topRuleName, 0);
    // Each round denies at least one character that no round denied before, so
    // the input length bounds the rounds outright.
    for (var round = 0; round <= s.length; round++) {
      if (!root.isMismatch && root.len == s.length) break;
      final next = _round(root, s.length);
      if (next == null) break;
      root = next;
    }
    return toLib(_emit(root, s.length), _back);
  }

  // -- stages 3, 4 and 5 -----------------------------------------------------

  /// One widening round: find the cheapest span whose removal lets some frontier
  /// clause match, install it, and re-descend. Null when no span does.
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
    for (var l = 1; l <= n; l++) {
      for (final (c, p) in _frontier) {
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
        final r = _p.matchSub(c, p + l);
        final readEnd = _p.maxRead;
        _p.maxRead = saved > readEnd ? saved : readEnd;
        if (r.isMismatch) continue;
        // A zero-length match explains nothing and denies l characters to buy
        // it. A predicate is the exception -- it is zero-width by definition,
        // and a `!X` that failed here and succeeds l along IS the recovery.
        if (r.len == 0 && !(c is FollowedBy || c is NotFollowedBy)) continue;
        final node = Match(null, 0, 0,
            subClauseMatches: [SyntaxError(pos: p, len: l), r]);
        ((_p.repairs ??= {})[c] ??= {})[p] = Repair(node, readEnd);
        _invalidate(p);
        return _p.matchRule(topRuleName, 0);
      }
    }
    return null;
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
    // The brief's leaf rule: a clause that mismatched BECAUSE its subclauses did
    // is an interior node of the failure, and the frontier is the leaves. And
    // its rule for `First`: an ordered choice whose arms all failed is never a
    // frontier clause itself, only a way through to the arms.
    if (any || c is First) return any;
    return c == null ? false : _add(c, m.pos);
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
    final kids = <MatchResult>[];
    var at = m.pos;
    for (final k in m.subClauseMatches) {
      if (!k.isMismatch) {
        kids.add(k);
        at = k.pos + k.len;
        continue;
      }
      final deep = _salvage(k);
      if (deep != null && deep.pos == at && deep.len > 0) kids.add(deep);
      break;
    }
    if (kids.isEmpty) return _salved[m] = null;
    if (kids.length == 1) return _salved[m] = kids.first;
    return _salved[m] = Match(null, 0, 0, subClauseMatches: kids);
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
