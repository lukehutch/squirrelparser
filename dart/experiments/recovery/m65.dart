// m65 -- THE TAPE, PACED: m63's true-PEG search with the three costs paid
// only where they buy exactness.
//
//   I21 THE LAYER IS THE ANSWER; THE TIE IS A RANKING, NOT A SCHEDULE.
//       With MATCH free and every edit costing one, the search is 0/1
//       Dijkstra: states settle in strict cost layers whatever the tie
//       order. So the in-search priority carries COST ONLY, the whole
//       minimal-cost layer is drained, every accepting candidate in it is
//       collected, and the m-line's exact regret -- the actual consuming
//       terminals' widths from the candidate's own parse, plus the edit
//       prices -- ranks the finished candidates AFTER the search. Exactness
//       of the tie-break no longer depends on anything the search can see.
//
//       Three pacing rules, each answer-neutral:
//       - classify on POP, not on push: the never-popped frontier (the whole
//         next layer when the answer lands) is never parsed at all;
//       - the clean-tail shortcut: after every edit, one probed parse tests
//         the entire remaining input as a free completion (the budget-zero
//         walk, transplanted to the tape) -- the accept arrives in one parse
//         instead of a quadratic chain of them;
//       - once the current layer holds an accept, stepwise expansion is
//         suppressed: within a layer, stepwise MATCH edges can only re-derive
//         clean-tail accepts the shortcuts already pushed, and edit children
//         belong to layers that will never pop.
//
// Everything else is m63 verbatim: the probed grammar (I20 -- membership,
// deadness, and the atoms are one parse), the derived bounds from the m62
// relaxation (-1 exact; cap = n + CFG fabrication floor; membership checked
// by a direct pure parse, never by the relaxation's 0), and the witness as
// the repaired string's own parse projected through the edit alignment.
//
// PARAMETERS: NONE.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;
import 'm62.dart' as relaxed;

/// log2 of the code-point alphabet, in millibits: what a FAB asserts.
const _widestClass = 20087;

int _width(Clause? clause) {
  if (clause is AnyChar) return _widestClass;
  if (clause is! CharSet) return 0;
  var size = 0;
  for (final (lo, hi) in clause.ranges) {
    size += hi - lo + 1;
  }
  size = clause.inverted ? 0x110000 - size : size;
  return size <= 1 ? 0 : (math.log(size) / math.ln2 * 1000).round();
}

/// A terminal that reports when its answer depends on the open end of the
/// emitted text, and which next character would matter there.
class _Probe extends Terminal {
  _Probe(this.owner, this.inner)
      : need = switch (inner) {
          Str(:final text) => text.length,
          Nothing() => 0,
          _ => 1,
        };
  final SuperDot3 owner;
  final Terminal inner;
  final int need;

  @override
  MatchResult match(Parser parser, int pos) {
    if (need > 0 && pos + need > parser.input.length) {
      owner._touched = true;
      owner._noteAtoms(this, parser.input, pos);
    }
    return inner.match(parser, pos);
  }
}

class _Cls {
  _Cls(this.member, this.open, this.atoms);
  final bool member;
  final bool open;
  final List<int> atoms;
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final relaxed.SuperDot3 _base =
      relaxed.SuperDot3(rules: rules, topRuleName: topRuleName);

  // ---- the probed grammar (m63 verbatim) ------------------------------------

  final List<Terminal> _terminals = [];

  late final Map<String, Clause> _probed = {
    for (final e in rules.entries) e.key: _px(e.value),
  };

  Clause _px(Clause c) {
    if (c is Seq) return Seq([for (final x in c.subClauses) _px(x)]);
    if (c is First) return First([for (final x in c.subClauses) _px(x)]);
    if (c is OneOrMore) return OneOrMore(_px(c.subClause));
    if (c is ZeroOrMore) return ZeroOrMore(_px(c.subClause));
    if (c is Optional) return Optional(_px(c.subClause));
    if (c is FollowedBy) return FollowedBy(_px(c.subClause));
    if (c is NotFollowedBy) return NotFollowedBy(_px(c.subClause));
    if (c is Repetition) {
      return Repetition(_px(c.subClause), requireOne: c.requireOne);
    }
    if (c is Ref) return c;
    final t = c as Terminal;
    if (t is! Nothing) _terminals.add(t);
    return _Probe(this, t);
  }

  bool _touched = false;
  Set<int> _atomSet = {};
  final Map<String, _Cls> _clsMemo = {};
  int _classifies = 0;

  void _noteAtoms(_Probe p, String y, int pos) {
    final inner = p.inner;
    if (inner is Str) {
      final off = y.length - pos;
      for (var i = 0; i < off; i++) {
        if (y.codeUnitAt(pos + i) != inner.text.codeUnitAt(i)) return;
      }
      _atomSet.add(inner.text.codeUnitAt(off));
    } else if (inner is Char) {
      _atomSet.add(inner.char.codeUnitAt(0));
    } else if (inner is CharSet) {
      _atomSet.add(_lowestOf(inner));
    } else if (inner is AnyChar) {
      _atomSet.add(0);
    }
  }

  static int _lowestOf(CharSet cs) {
    if (!cs.inverted) {
      var lo = 0x10000;
      for (final (a, _) in cs.ranges) {
        lo = math.min(lo, a);
      }
      return lo;
    }
    for (var c = 0; c < 0x10000; c++) {
      var inSet = false;
      for (final (a, b) in cs.ranges) {
        if (c >= a && c <= b) {
          inSet = true;
          break;
        }
      }
      if (!inSet) return c;
    }
    return 0;
  }

  _Cls _classify(String y) => _clsMemo[y] ??= () {
        _classifies++;
        _touched = false;
        _atomSet = <int>{};
        final r =
            Parser(rules: _probed, topRuleName: topRuleName, input: y).parse();
        return _Cls(!r.hasSyntaxErrors, _touched, _atomSet.toList()..sort());
      }();

  // ---- the m-line prices, for the post-search ranking -----------------------

  final Map<Clause, int> _widths = {};
  final Map<int, int> _charRegret = {};

  int _widthOf(Clause c) => _widths.putIfAbsent(c, () => _width(c));

  int _h(int ch) => _charRegret.putIfAbsent(ch, () {
        final probe = Parser(
            rules: rules,
            topRuleName: topRuleName,
            input: String.fromCharCode(ch));
        var best = _widestClass;
        for (final t in _terminals) {
          if (t.match(probe, 0).len != 1) continue;
          best = math.min(best, _widthOf(t));
          if (best == 0) break;
        }
        return best;
      });

  int _cleanReg(MatchResult m) => m.subClauseMatches.isEmpty
      ? (m.clause is Terminal && m.clause is! Nothing
          ? _widthOf(m.clause!) * m.len
          : 0)
      : m.subClauseMatches.fold(0, (a, c) => a + _cleanReg(c));

  // ---- the search -----------------------------------------------------------

  late String _input;
  late int _n;
  int lastCost = -1, lastSteps = -1;
  bool lastVerified = false;
  int get lastCells => _clsMemo.length;

  final Map<String, int> _ids = {};
  final List<int> _si = [], _sg = [], _sp = [], _sop = [], _sch = [];
  final List<String> _sy = [];
  final List<int> _heapK = [], _heapV = [];

  static const int _opStart = 0, _opMatch = 1, _opSub = 2, _opFab = 3,
      _opSkip = 4, _opTail = 5;

  void _hpush(int key, int id) {
    _heapK.add(key);
    _heapV.add(id);
    var i = _heapK.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_heapK[p] <= _heapK[i]) break;
      final tk = _heapK[p], tv = _heapV[p];
      _heapK[p] = _heapK[i];
      _heapV[p] = _heapV[i];
      _heapK[i] = tk;
      _heapV[i] = tv;
      i = p;
    }
  }

  (int, int) _hpop() {
    final top = (_heapK.first, _heapV.first);
    final lk = _heapK.removeLast(), lv = _heapV.removeLast();
    if (_heapK.isNotEmpty) {
      _heapK[0] = lk;
      _heapV[0] = lv;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _heapK.length && _heapK[l] < _heapK[m]) m = l;
        if (r < _heapK.length && _heapK[r] < _heapK[m]) m = r;
        if (m == i) break;
        final tk = _heapK[m], tv = _heapV[m];
        _heapK[m] = _heapK[i];
        _heapV[m] = _heapV[i];
        _heapK[i] = tk;
        _heapV[i] = tv;
        i = m;
      }
    }
    return top;
  }

  /// Push WITHOUT classifying: the parse is paid at pop, so the frontier a
  /// found answer strands is never parsed at all. Within a layer, states
  /// closer to completion pop first, so the clean-tail accepts surface at the
  /// head of their layer and everything behind them is drained cheaply.
  void _push(int i, String y, int g, int parent, int op, int ch) {
    final key = '$i|$y';
    final pri = g * (1 << 32) + (_n - i);
    final known = _ids[key];
    if (known != null) {
      if (_sg[known] <= g) return;
      _sg[known] = g;
      _sp[known] = parent;
      _sop[known] = op;
      _sch[known] = ch;
      _hpush(pri, known);
      return;
    }
    final id = _si.length;
    _ids[key] = id;
    _si.add(i);
    _sy.add(y);
    _sg.add(g);
    _sp.add(parent);
    _sop.add(op);
    _sch.add(ch);
    _hpush(pri, id);
  }

  int _accepted = -1;

  int recoverCost(String input) {
    _input = input;
    _n = input.length;
    lastVerified = false;
    _accepted = -1;
    final pure =
        Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      lastSteps = 0;
      lastVerified = true;
      return 0; // a clean pure parse is true-PEG membership
    }
    // The relaxed engine's -1 is exact (CFG-empty implies PEG-empty); its 0
    // is NOT a membership certificate (a rung-0 CFG-union parse also returns
    // 0 -- the possessive-star cases). The empty-input answer is the CFG
    // fabrication floor, hence the termination cap.
    if (_base.recoverCost(input) == -1) {
      lastCost = -1;
      lastSteps = 0;
      return -1;
    }
    final fab = _base.recoverCost('');
    final cap = _n + (fab < 0 ? 0 : fab);
    _ids.clear();
    _si.clear();
    _sy.clear();
    _sg.clear();
    _sp.clear();
    _sop.clear();
    _sch.clear();
    _heapK.clear();
    _heapV.clear();
    _clsMemo.clear();
    _classifies = 0;
    final settled = <int>{};
    final accepts = <int>[];
    var acceptCost = -1;
    _push(0, '', 0, -1, _opStart, -1);
    while (_heapK.isNotEmpty) {
      final (pri, id) = _hpop();
      final g = pri >> 32;
      if (g != _sg[id]) continue; // stale
      if (acceptCost >= 0 && g > acceptCost) break; // the layer is drained
      if (g > cap) break;
      if (!settled.add(id)) continue;
      final i = _si[id];
      final layerDone = acceptCost >= 0; // == g by the break above
      // Once the layer holds an accept, only two kinds of pop still matter:
      // completed candidates (more accepts for the ranking) and edit states
      // (their clean-tail shortcuts can still complete). Stepwise chain
      // states are discarded without even parsing them.
      if (layerDone && i < _n && (_sop[id] == _opMatch || _sop[id] == _opStart)) {
        continue;
      }
      final y = _sy[id];
      final cls = _classify(y);
      if (!cls.member && !cls.open) continue; // dead
      if (cls.member && i == _n) {
        acceptCost = g;
        accepts.add(id);
        continue;
      }
      final expandable = !cls.member || cls.open;
      // The clean-tail shortcut: after an edit, one parse tests the whole
      // remaining input as a free completion.
      if (i < _n &&
          expandable &&
          (_sop[id] == _opSub ||
              _sop[id] == _opFab ||
              _sop[id] == _opSkip)) {
        _push(_n, y + _input.substring(i), g, id, _opTail, -1);
      }
      if (layerDone) continue; // shortcuts above are the only same-layer news
      if (i < _n) {
        final cu = _input.codeUnitAt(i);
        if (expandable) {
          _push(i + 1, y + _input[i], g, id, _opMatch, cu);
        }
        _push(i + 1, y, g + 1, id, _opSkip, cu);
        if (expandable) {
          for (final a in cls.atoms) {
            if (a != cu) {
              _push(i + 1, y + String.fromCharCode(a), g + 1, id, _opSub, a);
            }
          }
        }
      }
      if (expandable) {
        for (final a in cls.atoms) {
          _push(i, y + String.fromCharCode(a), g + 1, id, _opFab, a);
        }
      }
    }
    lastSteps = _classifies;
    if (accepts.isEmpty) {
      lastCost = -1;
      return -1; // no repair within the derived cap
    }
    // The exact tie-break, after the fact and path-independent: the
    // candidate's own parse prices the kept text by its ACTUAL consuming
    // terminals, and a lexicographic (edits, regret) alignment DP prices the
    // edits at their m-line rates -- the settled search path plays no role.
    var bestRank = 1 << 60;
    for (final id in accepts) {
      final (packed, _) = _align(_sy[id]);
      final rank = packed % _alignBig +
          _cleanReg(
              Parser(rules: rules, topRuleName: topRuleName, input: _sy[id])
                  .parse()
                  .root);
      if (rank < bestRank) {
        bestRank = rank;
        _accepted = id;
      }
    }
    lastCost = acceptCost;
    return acceptCost;
  }

  // ---- the alignment DP: minimal (edits, regret), then its traceback -------

  static const int _alignBig = 1 << 40;

  (int, List<(int, int)>) _align(String y) {
    final m = y.length;
    final dp = List.generate(_n + 1, (_) => List<int>.filled(m + 1, 0));
    final bk = List.generate(_n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= _n; i++) {
      dp[i][0] = dp[i - 1][0] + _alignBig + 2 * _h(_input.codeUnitAt(i - 1));
      bk[i][0] = _opSkip;
    }
    for (var j = 1; j <= m; j++) {
      dp[0][j] = dp[0][j - 1] + _alignBig + _widestClass;
      bk[0][j] = _opFab;
    }
    for (var i = 1; i <= _n; i++) {
      final hc = 2 * _h(_input.codeUnitAt(i - 1));
      for (var j = 1; j <= m; j++) {
        final eq = _input.codeUnitAt(i - 1) == y.codeUnitAt(j - 1);
        var best = dp[i - 1][j - 1] + (eq ? 0 : _alignBig + hc);
        var op = eq ? _opMatch : _opSub;
        final skip = dp[i - 1][j] + _alignBig + hc;
        if (skip < best) {
          best = skip;
          op = _opSkip;
        }
        final fab = dp[i][j - 1] + _alignBig + _widestClass;
        if (fab < best) {
          best = fab;
          op = _opFab;
        }
        dp[i][j] = best;
        bk[i][j] = op;
      }
    }
    final script = <(int, int)>[];
    var i = _n, j = m;
    while (i > 0 || j > 0) {
      final op = i == 0
          ? _opFab
          : j == 0
              ? _opSkip
              : bk[i][j];
      script.add((op, op == _opFab ? y.codeUnitAt(j - 1) : -1));
      if (op == _opMatch || op == _opSub) {
        i--;
        j--;
      } else if (op == _opSkip) {
        i--;
      } else {
        j--;
      }
    }
    return (dp[_n][m], script.reversed.toList());
  }

  // ---- witness: the path IS the alignment (m63 verbatim) --------------------

  MatchResult _remap(MatchResult m, List<int> bnd) {
    final pos = bnd[m.pos], end = bnd[m.pos + m.len];
    if (m.subClauseMatches.isEmpty) {
      return Match(m.clause, pos, end - pos);
    }
    return Match(m.clause, pos, end - pos,
        subClauseMatches: [for (final c in m.subClauseMatches) _remap(c, bnd)]);
  }

  SkipResult recover(String input) {
    final cost = recoverCost(input);
    if (cost == 0) {
      final clean =
          Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
      return SkipResult(clean.root, const [], const [], 0, false);
    }
    if (cost < 0 || _accepted < 0) {
      final error = SyntaxError(pos: 0, len: input.length);
      return SkipResult(error, [error], const [], 1, true);
    }
    final y = _sy[_accepted];
    final (_, script) = _align(y);
    final bnd = List<int>.filled(y.length + 1, 0);
    final spans = <SyntaxError>[];
    final missing = <MissingObligation>[];
    var si = 0, j = 0, skipFrom = -1;
    void closeSkip() {
      if (skipFrom >= 0) {
        spans.add(SyntaxError(pos: skipFrom, len: si - skipFrom));
        skipFrom = -1;
      }
    }

    for (final (op, ch) in script) {
      switch (op) {
        case _opMatch || _opSub:
          closeSkip();
          if (j > 0) bnd[j] = si;
          j++;
          si++;
        case _opFab:
          closeSkip();
          if (j > 0) bnd[j] = si;
          j++;
          missing.add(MissingObligation(CharSet([(ch, ch)]), si));
        case _opSkip:
          if (skipFrom < 0) skipFrom = si;
          si++;
      }
    }
    closeSkip();
    bnd[y.length] = _n;
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: y).parse();
    lastVerified = !check.hasSyntaxErrors && check.root.len == y.length;
    final root = _remap(check.root, bnd);
    spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(spans), List.of(missing),
        spans.length + missing.length, false);
  }
}
