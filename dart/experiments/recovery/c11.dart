// c11.dart -- recovery as parser restarts with verdict directives.
//
// THE DESIGN, from the code-space study (`c11_study.md`): a damaged
// document's failed execution differs from the recovered execution by a
// handful of frame verdicts (measured: ~6.5 rule frames per single-site
// damage), located exactly where the parse stopped. So the engine is the
// PURE parser -- its match relation written out as one interpreter over
// the library's own clause objects -- plus one injection point:
//
//   consult(clause, pos)  --  every subclause evaluation goes through
//   here, and a DIRECTIVE addressed to this (clause, pos) may patch the
//   verdict before the ordinary code runs.
//
// Directive kinds (each is one verdict patch, priced like the c-line):
//   owe      -- the clause answers "matched, zero width, owed"
//   skip     -- one character is noise; consult again past it
//   replace  -- a terminal claims one real character as wrong content
//   skipIn/oweIn -- the literal-internal insert/delete (a literal is a
//                   char sequence, so its repairs stay literal-scoped)
//
// The search is uniform-cost over directive sets: run the parse (top
// rule wrapped with an end-of-input slot); a failed run reports its own
// candidate repair sites (every consult that failed AT the run's final
// frontier -- collected live, so silently discarded failures inside
// repetitions, optionals and taken choices are seen too); a completed
// run is a candidate. Nothing commits during search; all candidates at
// the winning charge are judged simultaneously with the c-line's keys.
// Left recursion needs nothing: the seed-and-grow loop is the library's
// own, and directives simply flow through its consults.
//
// PROGRESSIVE WIDENING (the I98 gap, closed): frontier sites cannot see
// a wrong SUCCESSFUL commit left of the failure -- the beaten earlier
// arm of a choice, a repetition's silent stop, an optional's rejection,
// a rival arm that read less than the furthest one. Every such rejected
// reading is kept as a SHADOW site, ring-ordered by its own read
// extent; rings are admitted only while the search is candidateless,
// highest extent first, before any deeper directive chain is explored.
// So ordinary damage stays frontier-cheap, and a wrong commit is found
// by re-asking the parse's own discarded questions, not by junk-eating.
import 'dart:collection';

import 'package:squirrel_parser/squirrel_parser.dart';

// Directive kinds.
const int _owe = 0, _skip = 1, _replace = 2, _skipIn = 3, _oweIn = 4,
    _oweTail = 5, _swap = 6, _veto = 7;

/// One verdict patch: when [clause] is consulted at [pos], answer
/// differently. Addressed by the memo key, so it commutes with
/// memoization; interned, so directive sets dedupe by identity.
class _Directive {
  final Clause clause;
  final int pos;
  final int kind;
  final int id;
  const _Directive(this.clause, this.pos, this.kind, this.id);
}

/// One search state: a set of directives and its repair cost. [eofOwes]
/// and [classKey] (the sorted non-EOF part of the set) exist for the
/// truncation dominance prune: a failed state already carrying as many
/// boundary owes as the best same-class candidate's missingAtEnd cannot
/// outrank it (boundary owes add no evidence and no names), so it is
/// never expanded.
class _State {
  final List<_Directive> ds;
  final int cost;
  final int seq;
  final int eofOwes;
  final String classKey;

  /// The parent run's failure frontier. A free re-ask (veto) that
  /// leaves the frontier here changed nothing: the same question,
  /// re-derived -- such a state is a dead end and must not expand.
  final int parentFrontier;
  const _State(this.ds, this.cost, this.seq, this.eofOwes, this.classKey,
      this.parentFrontier);
}

/// A rule's memo cell: the library's MemoEntry, verbatim, plus the
/// furthest position the frame probed while computing (tracked in the
/// pure run only, for cross-restart prefix reuse).
class _Cell {
  MatchResult? result;
  bool inRecPath = false, foundLeftRec = false;
  int memoVersion = 0;
  int reach = 0;
}

/// One restart: the pure parse of [input] under one directive set.
class _Run {
  _Run(this.eng, this.p, this.dirs, this.memoPure, this.pureMemo)
      : input = p.input,
        n = p.input.length,
        version = List<int>.filled(p.input.length + 1, 0),
        isPure = dirs.isEmpty {
    var m = 1 << 30;
    for (final q in dirs.keys) {
      if (q < m) m = q;
    }
    minDir = m;
  }

  final C11 eng;
  final Parser p; // carries input + stripped rules; terminals match via it
  final String input;
  final int n;
  final Map<int, List<_Directive>> dirs;
  final List<int> version;
  final Map<Clause, Map<int, _Cell>> memo = {};
  final Set<_Directive> fired = {};
  int predDepth = 0;

  /// Cross-restart reuse. Predicates never see directives, so their
  /// memo table [memoPure] is shared by every restart of one recover()
  /// call; a stale version only costs a recompute, never correctness.
  /// [pureMemo] is the directive-free run's main table: a directive run
  /// reuses a frame from it when the frame's whole probe stayed left of
  /// the run's first directive ([minDir]), because such a frame cannot
  /// have consulted anything a directive addresses (measured basis: 65%
  /// of a damaged run's frames are identical to the clean run's).
  final Map<Clause, Map<int, _Cell>> memoPure;
  final Map<Clause, Map<int, _Cell>>? pureMemo;
  final bool isPure;
  late final int minDir;
  final List<int> _reachStack = [];

  /// The run's failure frontier and every consult that failed there.
  int failFrontier = -1;
  final List<(Clause, int)> failSites = [];

  /// Rejected readings the parse discarded on its way to succeeding
  /// locally: a choice's beaten earlier arms, a repetition's stopping
  /// mismatch, an optional's rejected body. These are the shadow-site
  /// sources for progressive widening (I98: recovery's information is
  /// every rejected reading).
  final List<MatchResult> discarded = [];


  MatchResult consult(Clause c, int pos) {
    if (predDepth == 0 && dirs.isNotEmpty) {
      final ds = dirs[pos];
      if (ds != null) {
        for (final d in ds) {
          if (identical(d.clause, c)) return _apply(d, c, pos);
        }
      }
    }
    final r = _eval(c, pos);
    if (isPure && _reachStack.isNotEmpty) {
      // Probe extent: a mismatch looked one character past what it read.
      final pe = r.pos + (r.len < 0 ? 0 : r.len) + (r.isMismatch ? 1 : 0);
      if (pe > _reachStack.last) _reachStack[_reachStack.length - 1] = pe;
    }
    if (r.isMismatch && predDepth == 0) {
      final f = r.pos + (r.len < 0 ? 0 : r.len);
      if (f > failFrontier) {
        failFrontier = f;
        failSites.clear();
      }
      if (f == failFrontier) failSites.add((c, pos));
    }
    return r;
  }

  MatchResult _apply(_Directive d, Clause c, int pos) {
    fired.add(d);
    switch (d.kind) {
      case _owe:
        return SyntaxError(pos: pos, len: 0);
      case _veto: // challenge a choice's winning arm: refuse it, so the
        return Mismatch(c, pos, 0); // First falls through to later arms

      case _skip:
        if (pos >= n) return Mismatch(c, pos, 0);
        final inner = consult(c, pos + 1);
        if (inner.isMismatch) {
          final il = inner.len < 0 ? 0 : inner.len;
          return Mismatch(c, pos, 1 + il, subClauseMatches: [inner]);
        }
        return Match(null, 0, 0,
            subClauseMatches: [SyntaxError(pos: pos, len: 1), inner]);
      case _replace:
        if (c is Str) {
          final t = c.text;
          if (pos + t.length > n) return Mismatch(c, pos, 0);
          var bad = -1;
          for (var i = 0; i < t.length; i++) {
            if (input.codeUnitAt(pos + i) != t.codeUnitAt(i)) {
              if (bad >= 0) return Mismatch(c, pos, bad);
              bad = i;
            }
          }
          if (bad < 0) return Match(c, pos, t.length);
          return Match(null, 0, 0, subClauseMatches: [
            if (bad > 0) Match(c, pos, bad),
            SyntaxError(pos: pos + bad, len: 1),
            if (bad < t.length - 1)
              Match(c, pos + bad + 1, t.length - bad - 1),
          ]);
        }
        if (pos >= n) return Mismatch(c, pos, 0);
        return SyntaxError(pos: pos, len: 1);
      case _skipIn: // literal with one inserted junk character inside
        final t = (c as Str).text;
        if (pos + t.length + 1 > n) return Mismatch(c, pos, 0);
        for (var j = 1; j < t.length; j++) {
          if (_lit(t, 0, pos, j) && _lit(t, j, pos + j + 1, t.length - j)) {
            return Match(null, 0, 0, subClauseMatches: [
              Match(c, pos, j),
              SyntaxError(pos: pos + j, len: 1),
              Match(c, pos + j + 1, t.length - j),
            ]);
          }
        }
        return Mismatch(c, pos, 0);
      case _oweIn: // literal with one of its characters missing
        final t = (c as Str).text;
        if (pos + t.length - 1 > n) return Mismatch(c, pos, 0);
        // j == 0: the FIRST character is the missing one ("ull" for
        // "null") -- the tail must stand alone at pos.
        if (_lit(t, 1, pos, t.length - 1)) {
          return Match(null, 0, 0, subClauseMatches: [
            SyntaxError(pos: pos, len: 0),
            Match(c, pos, t.length - 1),
          ]);
        }
        for (var j = 1; j < t.length; j++) {
          if (_lit(t, 0, pos, j) && _lit(t, j + 1, pos + j, t.length - j - 1)) {
            return Match(null, 0, 0, subClauseMatches: [
              Match(c, pos, j),
              SyntaxError(pos: pos + j, len: 0),
              if (j < t.length - 1) Match(c, pos + j, t.length - j - 1),
            ]);
          }
        }
        return Mismatch(c, pos, 0);
      case _swap: // literal with two adjacent characters transposed
        final t = (c as Str).text;
        if (pos + t.length > n) return Mismatch(c, pos, 0);
        for (var j = 0; j + 1 < t.length; j++) {
          if (t.codeUnitAt(j) != t.codeUnitAt(j + 1) &&
              input.codeUnitAt(pos + j) == t.codeUnitAt(j + 1) &&
              input.codeUnitAt(pos + j + 1) == t.codeUnitAt(j) &&
              _lit(t, 0, pos, j) &&
              _lit(t, j + 2, pos + j + 2, t.length - j - 2)) {
            return Match(null, 0, 0, subClauseMatches: [
              if (j > 0) Match(c, pos, j),
              SyntaxError(pos: pos + j, len: 2),
              if (j + 2 < t.length) Match(c, pos + j + 2, t.length - j - 2),
            ]);
          }
        }
        return Mismatch(c, pos, 0);
      case _oweTail: // literal present only up to its first k characters
        final t = (c as Str).text;
        final k = _tailK(t, pos);
        if (k == t.length) return Match(c, pos, k);
        if (k == 0) return SyntaxError(pos: pos, len: 0);
        return Match(null, 0, 0, subClauseMatches: [
          Match(c, pos, k),
          SyntaxError(pos: pos + k, len: 0),
        ]);
    }
    throw StateError('directive kind ${d.kind}');
  }

  int _tailK(String t, int pos) {
    var k = 0;
    while (k < t.length &&
        pos + k < n &&
        input.codeUnitAt(pos + k) == t.codeUnitAt(k)) {
      k++;
    }
    return k;
  }

  bool _lit(String t, int ti, int pos, int len) {
    for (var i = 0; i < len; i++) {
      if (input.codeUnitAt(pos + i) != t.codeUnitAt(ti + i)) return false;
    }
    return true;
  }

  /// The pure parser's match relation, one clause kind at a time; the
  /// library's own code shapes, with subclause evaluation routed through
  /// [consult]. Terminals run the library's code directly.
  MatchResult _eval(Clause c, int pos) {
    if (c is Ref) {
      final clause = p.rules[c.ruleName]!;
      final r = _matchRule(clause, pos);
      if (r.isMismatch) return r; // passthrough, as the library does
      // An owed construct keeps its name mid-document and loses it at
      // the end of the input (names are evidence, I96). At pos >= n no
      // rule can read a real character, so ANY successful result there
      // -- bare owe or composite of owes -- spans zero input and
      // asserts nothing worth naming.
      if (pos >= n) return r;
      return Match(c, 0, 0, subClauseMatches: [r]);
    }
    if (c is Seq) {
      final children = <MatchResult>[];
      var curr = pos;
      for (final sub in c.subClauses) {
        final r = consult(sub, curr);
        if (r.isMismatch) {
          children.add(r);
          return Mismatch(c, pos, curr - pos, subClauseMatches: children);
        }
        children.add(r);
        curr += r.len;
      }
      if (children.isEmpty) return Match(c, pos, 0);
      return Match(c, 0, 0, subClauseMatches: children);
    }
    if (c is First) {
      List<MatchResult>? failedArms;
      var read = 0;
      final arms = c.subClauses;
      for (var i = 0; i < arms.length; i++) {
        final r = consult(arms[i], pos);
        if (!r.isMismatch) {
          if (predDepth == 0 && failedArms != null) {
            discarded.addAll(failedArms);
          }
          return Match(c, 0, 0, subClauseMatches: [r]);
        }
        (failedArms ??= <MatchResult>[]).add(r);
        if (r.len > read) read = r.len;
      }
      return Mismatch(c, pos, read, subClauseMatches: failedArms ?? const []);
    }
    if (c is Repetition) {
      final children = <MatchResult>[];
      var curr = pos;
      MatchResult? stoppedBy;
      while (curr <= n) {
        final r = consult(c.subClause, curr);
        if (r.isMismatch) {
          stoppedBy = r;
          break;
        }
        if (r.len == 0) break;
        children.add(r);
        curr += r.len;
      }
      if (c.requireOne && children.isEmpty) {
        return Mismatch(c, pos, 0,
            subClauseMatches: stoppedBy == null ? const [] : [stoppedBy]);
      }
      if (stoppedBy != null && predDepth == 0) discarded.add(stoppedBy);
      if (children.isEmpty) return Match(c, pos, 0);
      return Match(c, 0, 0, subClauseMatches: children);
    }
    if (c is Optional) {
      final r = consult(c.subClause, pos);
      if (r.isMismatch) {
        if (predDepth == 0) discarded.add(r);
        return Match(c, pos, 0);
      }
      return Match(c, 0, 0, subClauseMatches: [r]);
    }
    if (c is NotFollowedBy) {
      predDepth++;
      final r = consult(c.subClause, pos);
      predDepth--;
      return r.isMismatch ? Match(c, pos, 0) : Mismatch(c, pos, 0);
    }
    if (c is FollowedBy) {
      predDepth++;
      final r = consult(c.subClause, pos);
      predDepth--;
      return r.isMismatch ? Mismatch(c, pos, 0) : Match(c, pos, 0);
    }
    return c.match(p, pos); // terminals: the library's own code
  }

  /// The library's MemoEntry.match, verbatim, over [consult]. Inside a
  /// predicate the pure table is used instead: predicates never see
  /// directives, so their entries must not mix with patched ones.
  MatchResult _matchRule(Clause clause, int pos) {
    if (pos > n) return Mismatch(clause, pos, 0);
    final table = predDepth > 0 ? memoPure : memo;
    final cell = (table[clause] ??= {})[pos] ??= _Cell();
    if (cell.result != null &&
        (cell.inRecPath || cell.memoVersion == version[pos])) {
      if (isPure && _reachStack.isNotEmpty && cell.reach > _reachStack.last) {
        _reachStack[_reachStack.length - 1] = cell.reach;
      }
      return cell.result!;
    }
    if (cell.inRecPath) {
      cell.foundLeftRec = true;
      cell.result = Mismatch(clause, pos, 0);
      return cell.result!;
    }
    // Prefix reuse: the pure run's frame is this run's frame if its
    // whole probe stayed strictly left of the first directive.
    if (!isPure && predDepth == 0 && pos < minDir && cell.result == null) {
      final pc = pureMemo?[clause]?[pos];
      if (pc != null && pc.result != null && pc.reach < minDir) {
        cell.result = pc.result;
        cell.reach = pc.reach;
        cell.memoVersion = version[pos];
        return pc.result!;
      }
    }
    cell.inRecPath = true;
    if (isPure) _reachStack.add(pos);
    do {
      final nr = consult(clause, pos);
      if (cell.result != null &&
          (nr.isMismatch ||
              (!cell.result!.isMismatch && nr.len <= cell.result!.len))) {
        if (nr.isMismatch &&
            cell.result!.isMismatch &&
            nr.len >= cell.result!.len) {
          cell.result = nr;
        }
        break;
      }
      cell.result = nr;
      if (!cell.foundLeftRec) break;
      cell.memoVersion = ++version[pos];
    } while (true);
    cell.inRecPath = false;
    cell.memoVersion = version[pos];
    if (isPure) {
      var reach = _reachStack.removeLast();
      final rr = cell.result!;
      final pe = rr.pos + (rr.len < 0 ? 0 : rr.len) + (rr.isMismatch ? 1 : 0);
      if (pe > reach) reach = pe;
      cell.reach = reach;
      if (_reachStack.isNotEmpty && reach > _reachStack.last) {
        _reachStack[_reachStack.length - 1] = reach;
      }
    }
    return cell.result!;
  }
}

/// A completed candidate: the tree plus its rank keys.
class _Candidate {
  const _Candidate(this.tree, this.charge, this.pieces, this.evidence,
      this.names, this.firstDoubt, this.missingAtEnd, this.seq);
  final MatchResult tree;
  final int charge;
  final int pieces;
  final int evidence;
  final int names;
  final int firstDoubt;
  final int missingAtEnd;
  final int seq;
}

class C11 {
  C11(Map<String, Clause> rules, String topRuleName)
      : _raw = rules,
        _top = topRuleName,
        _topRef = Ref(topRuleName) {
    _topWrap = Seq([_topRef, const NotFollowedBy(AnyChar())]);
  }

  final Map<String, Clause> _raw;
  final String _top;
  final Ref _topRef;
  late final Clause _topWrap;

  /// Directive interning: same (clause, pos, kind) is the same object.
  final Map<Clause, int> _cid = Map<Clause, int>.identity();
  final Map<int, _Directive> _interned = {};

  _Directive _dir(Clause c, int pos, int kind) {
    final ci = _cid.putIfAbsent(c, () => _cid.length);
    final key = (ci * 200003 + pos) * 8 + kind;
    return _interned[key] ??= _Directive(c, pos, kind, key);
  }

  /// The c-line's price: skips and replaces per character, mid-document
  /// owes per piece, and every owe at the end of the input together
  /// worth one (the boundary claim is one, I94).
  /// Where a directive's owed (zero-width) piece sits, or -1 if it is
  /// not an owe.
  static int _owedAt(_Directive d, String input) {
    if (d.kind == _owe) return d.pos;
    if (d.kind != _oweTail) return -1;
    final t = (d.clause as Str).text;
    var k = 0;
    while (k < t.length &&
        d.pos + k < input.length &&
        input.codeUnitAt(d.pos + k) == t.codeUnitAt(k)) {
      k++;
    }
    return d.pos + k;
  }

  int _costOf(List<_Directive> ds, String input) {
    var cost = 0, eof = 0;
    for (final d in ds) {
      if (d.kind == _veto) continue; // re-asking is free; edits pay
      final at = _owedAt(d, input);
      if (at >= input.length) {
        eof = 1;
      } else {
        cost++;
      }
    }
    return cost + eof;
  }

  /// Search-resource guard (not a judgment constant): a case that
  /// exhausts it returns the best candidate found, or a bare error span.
  static const int _maxRuns = 20000;

  /// Diagnostics: restarts, candidates, winning charge and winning
  /// piece count of the last recover() call.
  int lastRuns = 0, lastCandidates = 0, lastCharge = 0, lastPieces = 0;

  /// The winner's repair count, one per piece (0 iff the pure parser
  /// accepts the input). The internal charge prices every boundary owe
  /// as one truncation event; reporting pieces keeps this comparable
  /// with the per-piece engines in the conformance gates.
  int recoverCost(String input) {
    recover(input);
    return lastPieces;
  }

  /// Every mismatch node in a run's returned tree and discarded
  /// readings, as a shadow site (clause, pos, own read extent). Results
  /// are memo-shared, so the walk guards against revisiting the DAG.
  List<(Clause, int, int)> _shadowSites(MatchResult root, _Run run) {
    final out = <(Clause, int, int)>[];
    final seenSites = <int>{};
    final seenNodes = HashSet<MatchResult>.identity();
    void walk(MatchResult m) {
      if (!seenNodes.add(m)) return;
      final c = m.clause;
      if (m.isMismatch && c != null) {
        final ci = _cid.putIfAbsent(c, () => _cid.length);
        if (seenSites.add(ci * 200003 + m.pos)) {
          out.add((c, m.pos, m.pos + (m.len < 0 ? 0 : m.len)));
        }
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(root);
    run.discarded.forEach(walk);
    return out;
  }

  MatchResult? recover(String input) {
    final p = Parser(rules: _raw, topRuleName: _top, input: input);
    final n = input.length;
    var seq = 0;
    var runs = 0;

    // Two priority indexes over one frontier, with a one-way switch.
    // While NO reading has completed: queue-cost bands (each directive
    // pays, vetoes included), furthest parent frontier first -- greedy
    // progress, so a capped multi-error search still completes and
    // holds some reading instead of wandering the free band. Once one
    // exists: CHARGE bands (free re-asks unpriced -- the judgment's
    // own coin, so an equal-charge veto rival is reached before any
    // dearer chain), expansion order within a band, the only order in
    // which no self-feeding family can starve another, since children
    // always queue behind their parents. Charge bands are finite: the
    // consecutive-veto ban caps vetoes at edits + 1. Both indexes hold
    // every state; the popped set reconciles them lazily at the switch.
    final pending = SplayTreeMap<int, SplayTreeMap<int, Queue<_State>>>();
    final fifo = SplayTreeMap<int, Queue<_State>>();
    final popped = HashSet<_State>.identity();
    void push(_State s, int charge) {
      ((pending[s.cost] ??= SplayTreeMap())[-s.parentFrontier] ??= Queue())
          .add(s);
      (fifo[charge] ??= Queue()).add(s);
    }
    push(const _State([], 0, 0, 0, '', -2), 0);
    seq++;
    final visited = <String>{};
    final candidates = <_Candidate>[];
    final bestMissingByClass = <String, int>{};
    var bestCharge = 1 << 30;

    // Progressive widening state: every run's shadow sites, kept so a
    // later ring can re-expand it; the distinct read-extent levels; and
    // the floor, above which shadow sites are admitted.
    final ran = <(
      _State,
      List<(Clause, int, int)>,
      List<(Clause, int, int, int)>,
      int
    )>[];
    final ringLevels = SplayTreeSet<int>();
    var floor = 1 << 30;

    // Cross-restart reuse (see _Run): the shared predicate table, and
    // the pure run's main table once the first restart has produced it.
    final sharedPredMemo = <Clause, Map<int, _Cell>>{};
    Map<Clause, Map<int, _Cell>>? pureMemo;

    void expand(_State st, int pf, Iterable<(Clause, int)> sites,
        {bool veto = false}) {
      final seen = <int>{};
      for (final (c, q) in sites) {
        void add(int kind) {
          final d = _dir(c, q, kind);
          if (!seen.add(d.id)) return;
          for (final have in st.ds) {
            if (identical(have, d)) return;
          }
          final ds2 = [...st.ds, d];
          final key = (ds2.map((x) => x.id).toList()..sort()).join(',');
          if (!visited.add(key)) return;
          // Greedy-phase queue price: a veto is free in the charge but
          // pays one unit of search order -- otherwise the pre-reading
          // search is a random walk in re-ask space and multi-error
          // cases never reach charge 2 before the cap.
          final chg = _costOf(ds2, input);
          var c2 = chg;
          for (final x in ds2) {
            if (x.kind == _veto) c2++;
          }
          var eof = 0;
          final classIds = <int>[];
          for (final x in ds2) {
            if (_owedAt(x, input) >= n) {
              eof++;
            } else {
              classIds.add(x.id);
            }
          }
          push(
              _State(ds2, c2, seq++, eof, (classIds..sort()).join(','), pf),
              chg);
        }

        if (veto) {
          // Two free re-asks with no payment between them are not a
          // composite repair: any same-rep pair is equivalent to its
          // earlier cut alone, and a cross-rep pair is a different
          // single question, already queued on its own. Requiring a
          // paid directive between vetoes bounds free states by cost.
          if (st.ds.isNotEmpty && st.ds.last.kind == _veto) return;
          add(_veto);
          continue;
        }
        // Owes are terminal-grade only: composites are owed as chains
        // of deep patches, so an owe's price is its pieces (the
        // c-line's law, emergent), ancestors run their real wrapping
        // code (names), and the EOI predicate can never be owed into
        // accepting uncovered trailing junk.
        if (c is Str) {
          add(_oweTail);
          add(_replace);
          if (c.text.length > 1) {
            add(_skipIn);
            add(_oweIn);
            add(_swap);
          }
        } else if (c is Char || c is CharSet || c is AnyChar) {
          add(_owe);
          add(_replace);
        } else if (c is Repetition &&
            c.requireOne &&
            c.subClause is Terminal) {
          add(_owe);
        }
        if (q < n) add(_skip);
      }
    }

    // Veto sites, read off the run's own tree as (clause, pos, ring,
    // span start). A choice that won with untried later arms is a
    // challengeable commit -- a veto is the only move that can re-ask
    // it, because a patch on a failing path cannot reroute a
    // SUCCESSFUL choice. A greedy Terminal-body rep's child boundaries
    // are cuts: every prefix of the junk-eating run is a reading the
    // possessive loop never offered. Each site carries the span of its
    // nearest enclosing rep, and the ring level is that rep's end --
    // so an over-eater that carried the parse to its failure is
    // re-asked first, and all its cuts arrive in one ring.
    // A commit is only re-askable when it CARRIED the parse to its
    // failure: some enclosing match must end exactly at the run's
    // failure frontier (`touch`). Everything else committed and the
    // parse moved past it -- re-asking those floods the free band.
    void vetoSites(MatchResult m, int rs, int re, bool touch, int frontier,
        List<(Clause, int, int, int)> out) {
      final c = m.clause;
      final t = touch || (m is! Mismatch && m.pos + m.len == frontier);
      var nrs = rs, nre = re;
      if (m is! Mismatch && c is Repetition && m.subClauseMatches.isNotEmpty) {
        nrs = m.pos;
        nre = m.pos + m.len;
        if (t && c.subClause is Terminal) {
          for (final g in m.subClauseMatches) {
            if (g is! SyntaxError) out.add((c.subClause, g.pos, nre, nrs));
          }
        }
      }
      if (t && m is! Mismatch && c is First && m.subClauseMatches.length == 1) {
        final w = m.subClauseMatches.first.clause;
        final arms = c.subClauses;
        for (var i = 0; i < arms.length - 1; i++) {
          if (identical(w, arms[i])) {
            out.add((arms[i], m.pos, re >= 0 ? re : m.pos + m.len, rs));
            break;
          }
        }
      }
      for (final ch in m.subClauseMatches) {
        vetoSites(ch, nrs, nre, t, frontier, out);
      }
    }

    // A veto site whose exclusion span already holds one of the
    // state's vetoes is dead before it runs: cuts of one rep are
    // alternatives, not composables -- the earlier cut stops the rep,
    // so the later one can never fire.
    bool vetoDead(_State st, (Clause, int, int, int) s) =>
        s.$4 >= 0 &&
        st.ds.any((d) =>
            d.kind == _veto &&
            identical(d.clause, s.$1) &&
            d.pos >= s.$4 &&
            d.pos <= s.$3);

    // Admit the rings: every state run so far re-proposes all of its
    // shadow and veto sites. One bulk admission -- level-by-level
    // draining starves whichever family needs the far ring (the site
    // count is bounded, the runs a ring-per-round schedule burns are
    // not). Re-arms itself when later runs surface deeper levels.
    bool widen() {
      if (ringLevels.isEmpty || ringLevels.first >= floor) return false;
      floor = ringLevels.first;
      for (final (st, sh, vs, pf) in ran) {
        expand(st, pf, [
          for (final s in sh)
            if (s.$3 >= floor) (s.$1, s.$2)
        ]);
        expand(st, pf, [
          for (final s in vs)
            if (s.$3 >= floor && !vetoDead(st, s)) (s.$1, s.$2)
        ], veto: true);
      }
      return true;
    }

    while (runs < _maxRuns) {
      final greedy = candidates.isEmpty;
      int? cost;
      if (greedy) {
        cost = pending.isEmpty ? null : pending.firstKey();
      } else {
        while (fifo.isNotEmpty) {
          final k = fifo.firstKey()!;
          final q = fifo[k]!;
          while (q.isNotEmpty && popped.contains(q.first)) {
            q.removeFirst();
          }
          if (q.isEmpty) {
            fifo.remove(k);
            continue;
          }
          cost = k;
          break;
        }
      }
      if (cost == null) {
        if (widen()) continue;
        break;
      }
      if (cost > bestCharge) {
        // Post-switch cost IS the charge, so the search has settled --
        // but a committed reading the parse never questioned may hide
        // an equal-charge rival. Drain the rings before concluding.
        if (widen()) continue;
        break;
      }
      // While no reading has completed, admit the rings of rejected
      // readings before spending on deeper directive chains: a wrong
      // successful commit is cheaper to re-ask than to junk-eat around.
      if (greedy && cost > 1 && widen()) continue;
      _State st;
      if (greedy) {
        final band = pending[cost]!;
        final key = band.firstKey()!;
        final bucket = band[key]!;
        st = bucket.removeFirst();
        popped.add(st);
        if (bucket.isEmpty) {
          band.remove(key);
          if (band.isEmpty) pending.remove(cost);
        }
      } else {
        st = fifo[cost]!.removeFirst();
      }
      runs++;
      final dirsByPos = <int, List<_Directive>>{};
      for (final d in st.ds) {
        (dirsByPos[d.pos] ??= []).add(d);
      }
      final run = _Run(this, p, dirsByPos, sharedPredMemo, pureMemo);
      final r = run.consult(_topWrap, 0);
      if (run.isPure) pureMemo = run.memo;
      if (!r.isMismatch) {
        // A directive that never fired means this state's parse is its
        // parent's; the candidate is only real if every patch was used.
        if (run.fired.length == st.ds.length) {
          final cand = _judge(r, st, input, p, seq++);
          if (cand.charge < bestCharge) bestCharge = cand.charge;
          candidates.add(cand);
          final bm = bestMissingByClass[st.classKey];
          if (bm == null || cand.missingAtEnd < bm) {
            bestMissingByClass[st.classKey] = cand.missingAtEnd;
          }
        }
        continue;
      }
      if (st.ds.isNotEmpty && !run.fired.contains(st.ds.last)) {
        continue; // the new patch was never consulted: a dead state
      }
      if (st.ds.isNotEmpty &&
          st.ds.last.kind == _veto &&
          run.failFrontier == st.parentFrontier) {
        continue; // the free re-ask changed nothing: same question
      }
      final bm = bestMissingByClass[st.classKey];
      if (bm != null && st.eofOwes >= bm) {
        continue; // truncation dominance: it needs > bm boundary owes
      }

      // Branch: one more directive at each site the run failed at, plus
      // any shadow sites already admitted by the widening floor.
      expand(st, run.failFrontier, run.failSites);
      final shadows = _shadowSites(r, run);
      final allV = <(Clause, int, int, int)>[];
      vetoSites(r, -1, -1, false, run.failFrontier, allV);
      for (final d in run.discarded) {
        vetoSites(d, -1, -1, false, run.failFrontier, allV);
      }
      final vsites = <(Clause, int, int, int)>[];
      final vseen = <int>{};
      for (final v in allV) {
        final ci = _cid.putIfAbsent(v.$1, () => _cid.length);
        if (vseen.add(ci * 200003 + v.$2)) vsites.add(v);
      }
      for (final s in shadows) {
        ringLevels.add(s.$3);
      }
      for (final s in vsites) {
        ringLevels.add(s.$3);
      }
      ran.add((st, shadows, vsites, run.failFrontier));
      if (floor != 1 << 30) {
        expand(st, run.failFrontier, [
          for (final s in shadows)
            if (s.$3 >= floor) (s.$1, s.$2)
        ]);
        expand(st, run.failFrontier, [
          for (final s in vsites)
            if (s.$3 >= floor && !vetoDead(st, s)) (s.$1, s.$2)
        ], veto: true);
      }
    }

    lastRuns = runs;
    lastCandidates = candidates.length;
    if (candidates.isEmpty) {
      lastCharge = n; // the whole document stands as one error span
      lastPieces = n;
      return Match(null, 0, 0,
          subClauseMatches: [SyntaxError(pos: 0, len: n)]);
    }
    candidates.sort(_rank);
    lastCharge = candidates.first.charge;
    lastPieces = candidates.first.pieces;
    return _stripTop(candidates.first.tree);
  }

  /// The library's parse() root is the top rule's BODY, unlabeled; the
  /// engine's own wrapper Ref must not add a label the pure parser
  /// would not have. Splice it out wherever it sits in the winner.
  MatchResult _stripTop(MatchResult m) {
    if (identical(m.clause, _topRef) && m.subClauseMatches.length == 1) {
      return _stripTop(m.subClauseMatches.first);
    }
    if (m.subClauseMatches.isEmpty) return m;
    var changed = false;
    final subs = <MatchResult>[];
    for (final s in m.subClauseMatches) {
      final t = _stripTop(s);
      if (!identical(t, s)) changed = true;
      subs.add(t);
    }
    if (!changed) return m;
    return m.isMismatch
        ? Mismatch(m.clause!, m.pos, m.len, subClauseMatches: subs)
        : Match(m.clause, m.pos, m.len, subClauseMatches: subs);
  }

  /// Charge and rank keys for a finished tree (the c-line's judgment,
  /// applied whole-document: charge = cost + the root absorb penalty).
  _Candidate _judge(
      MatchResult tree, _State st, String input, Parser p, int seq) {
    final n = input.length;
    var evidence = 0, deleted = 0, names = 0;
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        deleted += m.len;
        return;
      }
      if (m.clause is Ref) names++;
      if (m.subClauseMatches.isEmpty) {
        final c = m.clause;
        if (c != null && _picky(c)) evidence += m.len;
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(tree);
    final cost = _costOf(st.ds, input);
    final absorbed = n - deleted - evidence;
    // The c-line's penalty rule (c10): a reading that stands still and
    // declares a slot missing -- while a deletion at that spot would
    // have let the slot read real input -- pays one point. The slot is
    // the MAXIMAL zero-width construct wrapping the owed piece (owing
    // "null" is owing the whole Value), so the test lives on the tree,
    // not on the directive's terminal. Two exemptions, as in c10: a
    // slot with only one possible shape (its absence is unambiguous),
    // and the left-recursive seed (a zero-width piece whose parent
    // starts at the same position yet has width IS a grown LR cell;
    // its seed anchors the growth and may not be priced away).
    final penalties = _penalties(tree, st, input, p);
    // The absorb penalty punishes a READING'S junk-eating, so it needs
    // a mid-document directive to blame: a span the pure parser
    // absorbed by the grammar's own choice, cut short only by
    // truncation, owes no explanation for its characters (the
    // _freespan control: W <- . . . . reading "xxab" for free must not
    // lose to a reading that deletes the x to make E's literals fit).
    final hasMid = st.ds.any((d) {
      final at = _owedAt(d, input);
      return at < 0 || at < n; // any non-owe, or an owe before EOF
    });
    final charge =
        cost + penalties + (hasMid && absorbed > evidence ? 1 : 0);
    var firstDoubt = 1 << 30;
    var missingAtEnd = 0;
    for (final d in st.ds) {
      if (d.pos < firstDoubt) firstDoubt = d.pos;
      if (_owedAt(d, input) >= n) missingAtEnd++;
    }
    return _Candidate(tree, charge,
        st.ds.where((d) => d.kind != _veto).length, evidence, names,
        firstDoubt, missingAtEnd, seq);
  }

  /// One penalty per distinct maximal zero-width construct that wraps
  /// a piece an owe directive invented, has more than one possible
  /// shape, is not a left-recursive seed, and would have read real
  /// input had the character at its position been deleted instead.
  int _penalties(MatchResult tree, _State st, String input, Parser p) {
    final n = input.length;
    var penalties = 0;
    final counted = Set<MatchResult>.identity();
    _Run? probe;
    final stack = <MatchResult>[];
    void walk(MatchResult m) {
      // A zero-width SyntaxError before EOF IS an owed piece: only the
      // owe patches produce one (skips delete real width, and boundary
      // owes sit at pos n, where absence is the truncation itself).
      if (m is SyntaxError && m.len == 0 && m.pos < n) {
        // Climb to the widest ancestor that is still zero-width here:
        // owing "null" is owing the whole Value slot around it.
        MatchResult z = m;
        var pi = stack.length - 1;
        while (pi >= 0 && stack[pi].pos == m.pos && stack[pi].len == 0) {
          z = stack[pi--];
        }
        // The left-recursive seed: z refers to rule R and a WIDER
        // ancestor at the same position is R again -- the grown cell
        // wrapping its own seed. A seq that merely starts with the
        // owed slot has no such self-reference above it.
        final zc = z.clause;
        var lrSeed = false;
        if (zc is Ref) {
          for (var j = pi; j >= 0 && stack[j].pos == z.pos; j--) {
            final ac = stack[j].clause;
            if (ac is Ref && ac.ruleName == zc.ruleName) {
              lrSeed = true;
              break;
            }
          }
        }
        if (z.len == 0 &&
            zc != null &&
            counted.add(z) &&
            !lrSeed &&
            !_oneShape(zc)) {
          probe ??= _Run(this, p, const <int, List<_Directive>>{},
              <Clause, Map<int, _Cell>>{}, null);
          if (z.pos + 1 <= n &&
              !probe!.consult(zc, z.pos + 1).isMismatch) {
            penalties++;
          }
        }
      }
      stack.add(m);
      for (final s in m.subClauseMatches) {
        walk(s);
      }
      stack.removeLast();
    }

    walk(tree);
    return penalties;
  }

  /// Does this clause accept exactly one string? A literal, a single
  /// character, a sequence of such -- the constructs whose absence is
  /// unambiguous and therefore exempt from the penalty rule.
  bool _oneShape(Clause c) {
    final visiting = Set<Clause>.identity();
    bool go(Clause c) {
      if (!visiting.add(c)) return false; // recursion: unbounded shapes
      final bool r;
      if (c is Str || c is Char || c is NotFollowedBy) {
        r = true;
      } else if (c is CharSet) {
        var count = 0;
        for (final (lo, hi) in c.ranges) {
          count += hi - lo + 1;
        }
        r = !c.inverted && count == 1;
      } else if (c is Seq) {
        r = c.subClauses.every(go);
      } else if (c is First) {
        r = c.subClauses.length == 1 && go(c.subClauses.first);
      } else if (c is Ref) {
        final b = _raw[c.ruleName];
        r = b != null && go(b);
      } else {
        r = false; // Repetition, Optional, AnyChar: many shapes
      }
      visiting.remove(c);
      return r;
    }

    return go(c);
  }

  static bool _picky(Clause c) =>
      c is Str || c is Char || (c is CharSet && !c.inverted);

  /// The rank keys, whole-document: lower charge; more evidence; more
  /// names (names are evidence, I96 -- this is what prefers the deep
  /// verdict patch, whose ancestors run their real wrapping code, over
  /// the flat one); later first doubt; fewer pieces stranded at the
  /// cut; ties to the latest.
  static int _rank(_Candidate a, _Candidate b) {
    if (a.charge != b.charge) return a.charge - b.charge;
    if (a.evidence != b.evidence) return b.evidence - a.evidence;
    if (a.names != b.names) return b.names - a.names;
    if (a.firstDoubt != b.firstDoubt) return b.firstDoubt - a.firstDoubt;
    if (a.missingAtEnd != b.missingAtEnd) {
      return a.missingAtEnd - b.missingAtEnd;
    }
    return b.seq - a.seq; // the c-line's tie law: the latest rival holds
  }
}
