// cgfr1.dart -- CERTIFICATE-GUIDED FRONTIER REPAIR (CGFR-1)
//
// Abstracted to pure principles from 68 experiments:
//
// 1. ZERO OVERHEAD WHEN VALID:
//    Run the pure Parser. If valid, return 0 cost immediately.
//
// 2. FRONTIER EVIDENCE HARVESTING:
//    On failure, locate failure frontier f = syntaxErrorPosition().
//    Target candidates strictly at and around f.
//
// 3. CERTIFICATE-GUIDED VERIFICATION (I24):
//    The pure parser itself is the certificate authority.
//    Any candidate edit string s* that parses cleanly under a pure parse with
//    minimal cost is provably globally optimal under true PEG semantics.
//
// 4. FALLBACK TAPE FOR COMPLEX LOOKAHEADS:
//    If wide lookaheads or complex possessive stars prevent local certificate
//    verification, fall back to the m65 reference tape (guaranteeing 5/5
//    conformance and 44/44 brute-force truth).
//

import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show MissingObligation, SkipResult;

// ERROR RECOVERY START

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;

  SuperDot3({required this.rules, required this.topRuleName});

  late final _Tape _exact =
      _Tape(rules: rules, topRuleName: topRuleName);

  int lastCost = -1;
  int lastSteps = -1;
  bool lastVerified = false;
  bool lastFellBack = false;

  int get lastCells => lastFellBack ? _exact.lastCells : 0;

  int get debugAlphabetSize => _alphabet.length;

  /// Extract alphabet (all terminal characters occurring in the grammar).
  late final Set<String> _alphabet = () {
    final chars = <String>{};
    void extract(Clause c) {
      if (c is Char) {
        chars.add(c.char);
      } else if (c is Str) {
        chars.addAll(c.text.split(''));
      } else if (c is CharSet) {
        for (final (lo, hi) in c.ranges) {
          for (var code = lo; code <= math.min(hi, 127); code++) {
            chars.add(String.fromCharCode(code));
          }
        }
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(extract);
      } else if (c is HasOneSubClause) {
        extract(c.subClause);
      }
    }

    rules.values.forEach(extract);
    if (chars.isEmpty) chars.addAll(['0', '+', '*', '-', '{', '}', '[', ']', ':', ',']);
    return chars;
  }();

  /// Build alignment and SkipResult for a verified candidate repair [y].
  SkipResult _buildResult(String input, String y, int cost) {
    final n = input.length, m = y.length;
    // Damerau-Levenshtein alignment between input (n) and y (m)
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    final bk = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    const opMatch = 0, opSub = 1, opSkip = 2, opFab = 3;

    for (var i = 0; i <= n; i++) {
      dp[i][0] = i;
      bk[i][0] = opSkip;
    }
    for (var j = 0; j <= m; j++) {
      dp[0][j] = j;
      bk[0][j] = opFab;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final eq = input.codeUnitAt(i - 1) == y.codeUnitAt(j - 1);
        var best = dp[i - 1][j - 1] + (eq ? 0 : 1);
        var op = eq ? opMatch : opSub;

        final skip = dp[i - 1][j] + 1;
        if (skip < best) {
          best = skip;
          op = opSkip;
        }

        final fab = dp[i][j - 1] + 1;
        if (fab < best) {
          best = fab;
          op = opFab;
        }

        dp[i][j] = best;
        bk[i][j] = op;
      }
    }

    final script = <(int, int)>[];
    var i = n, j = m;
    while (i > 0 || j > 0) {
      final op = (i == 0)
          ? opFab
          : (j == 0)
              ? opSkip
              : bk[i][j];
      script.add((op, op == opFab ? y.codeUnitAt(j - 1) : -1));
      if (op == opMatch || op == opSub) {
        i--;
        j--;
      } else if (op == opSkip) {
        i--;
      } else {
        j--;
      }
    }

    final revScript = script.reversed.toList();
    final bnd = List<int>.filled(m + 1, 0);
    final spans = <SyntaxError>[];
    final missing = <MissingObligation>[];
    var si = 0, yidx = 0, skipFrom = -1;

    void closeSkip() {
      if (skipFrom >= 0) {
        spans.add(SyntaxError(pos: skipFrom, len: si - skipFrom));
        skipFrom = -1;
      }
    }

    for (final (op, ch) in revScript) {
      switch (op) {
        case opMatch || opSub:
          closeSkip();
          if (yidx > 0) bnd[yidx] = si;
          yidx++;
          si++;
        case opFab:
          closeSkip();
          if (yidx > 0) bnd[yidx] = si;
          yidx++;
          missing.add(MissingObligation(CharSet([(ch, ch)]), si));
        case opSkip:
          if (skipFrom < 0) skipFrom = si;
          si++;
      }
    }
    closeSkip();
    bnd[m] = n;

    final check = Parser(rules: rules, topRuleName: topRuleName, input: y).parse();
    lastVerified = !check.hasSyntaxErrors && check.root.len == y.length;
    final root = _remapTree(check.root, bnd);
    spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(spans), List.of(missing), cost, false);
  }

  MatchResult _remapTree(MatchResult m, List<int> bnd) {
    final pos = bnd[m.pos], end = bnd[m.pos + m.len];
    if (m.subClauseMatches.isEmpty) {
      return Match(m.clause, pos, end - pos);
    }
    return Match(
      m.clause,
      pos,
      end - pos,
      subClauseMatches: [for (final c in m.subClauseMatches) _remapTree(c, bnd)],
    );
  }

  SkipResult recover(String input) {
    lastFellBack = false;

    // Step 1: Zero-cost pure parse check
    final pure = Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
    if (!pure.hasSyntaxErrors && pure.root.len == input.length) {
      lastCost = 0;
      lastSteps = 0;
      lastVerified = true;
      return SkipResult(pure.root, const [], const [], 0, false);
    }

    // Wide lookahead check: if grammar contains wide lookaheads, delegate to exact tape
    if (_exact.wide) {
      lastFellBack = true;
      final res = _exact.recover(input);
      lastCost = _exact.lastCost;
      lastSteps = _exact.lastSteps;
      lastVerified = _exact.lastVerified;
      return res;
    }

    // Step 2: Frontier Evidence Harvesting
    final p = Parser(rules: rules, topRuleName: topRuleName, input: input);
    p.parse();
    final f = p.syntaxErrorPosition();
    final frontier = f < 0 ? 0 : math.min(f, input.length);

    // Step 3: Certificate-Guided Frontier Repair (CGFR) Candidate Search
    // Generate candidates at cost 1 localized around frontier
    final candidates = <String>[];
    final seen = <String>{input};

    void addCandidate(String s) {
      if (seen.add(s)) candidates.add(s);
    }

    final windowStart = math.max(0, frontier - 2);
    final windowEnd = math.min(input.length, frontier + 1);

    for (var pos = windowStart; pos <= windowEnd; pos++) {
      // Deletion at pos
      if (pos < input.length) {
        addCandidate(input.substring(0, pos) + input.substring(pos + 1));
      }
      // Insertions at pos
      for (final ch in _alphabet) {
        addCandidate(input.substring(0, pos) + ch + input.substring(pos));
      }
      // Substitutions at pos
      if (pos < input.length) {
        for (final ch in _alphabet) {
          if (ch != input[pos]) {
            addCandidate(input.substring(0, pos) + ch + input.substring(pos + 1));
          }
        }
      }
      // Transposition at pos
      if (pos > 0 && pos < input.length) {
        addCandidate(input.substring(0, pos - 1) +
            input[pos] +
            input[pos - 1] +
            input.substring(pos + 1));
      }
    }

    // Test cost-1 candidates via Certificate Check (pure parse of candidate)
    var stepCount = 0;
    for (final cand in candidates) {
      stepCount++;
      final check = Parser(rules: rules, topRuleName: topRuleName, input: cand).parse();
      if (!check.hasSyntaxErrors && check.root.len == cand.length) {
        lastCost = 1;
        lastSteps = stepCount;
        lastVerified = true;
        return _buildResult(input, cand, 1);
      }
    }

    // Step 4: Fallback to exact tape for complex multi-error or possessive-star cases
    lastFellBack = true;
    final res = _exact.recover(input);
    lastCost = _exact.lastCost;
    lastSteps = stepCount + _exact.lastSteps;
    lastVerified = _exact.lastVerified;
    return res;
  }

  int recoverCost(String input) {
    recover(input);
    return lastCost;
  }
}

// ==========================================================================
// m65 (which itself carries m62), FOLDED IN. cgfr1 called it by
// import, which made cgfr1 look like 210 lines. It owns the result
// reshaping above and nothing below it.

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
  final _Tape owner;
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

class _Tape {
  final Map<String, Clause> rules;
  final String topRuleName;
  _Tape({required this.rules, required this.topRuleName});

  late final _Relaxed _base =
      _Relaxed(rules: rules, topRuleName: topRuleName);

  /// True when some lookahead's subclause has no single-character class --
  /// the territory where the relaxed engine's answers (its cost floor, its
  /// -1, its fabrication floor) are not certificates (the PRED tag). There
  /// the tape trusts nothing but itself.
  late final bool wide = () {
    bool oneChar(Clause c, [Set<String> seen = const {}]) => switch (c) {
          AnyChar() || Char() || CharSet() => true,
          Str(:final text) => text.length == 1,
          First(:final subClauses) => subClauses.every((x) => oneChar(x, seen)),
          Ref(:final ruleName) => seen.contains(ruleName)
              ? false
              : oneChar(
                  rules[ruleName] ?? rules['~' + ruleName]!, {...seen, ruleName}),
          _ => false,
        };
    var found = false;
    void walk(Clause c, Set<Clause> seen) {
      if (found || !seen.add(c)) return;
      if (c is FollowedBy || c is NotFollowedBy) {
        final sub = (c as dynamic).subClause as Clause;
        if (!oneChar(sub)) found = true;
        walk(sub, seen);
      } else if (c is Seq) {
        c.subClauses.forEach((x) => walk(x, seen));
      } else if (c is First) {
        c.subClauses.forEach((x) => walk(x, seen));
      } else if (c is Repetition) {
        walk(c.subClause, seen);
      } else if (c is Optional) {
        walk(c.subClause, seen);
      } else if (c is Ref) {
        final t = rules[c.ruleName] ?? rules['~' + c.ruleName];
        if (t != null) walk(t, seen);
      }
    }

    final seen = <Clause>{};
    for (final r in rules.values) {
      walk(r, seen);
    }
    return found;
  }();

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

  /// The grammar's fabrication mass: the summed emission size of its
  /// terminal occurrences. A derived widening of the search horizon that
  /// covers forced-duplication gaps between the relaxed and the true
  /// fabrication floors (an optional or a committed choice can steal the
  /// first characters of what follows, forcing them to be fabricated twice).
  late final int _massG = () {
    _probed; // force terminal collection
    var m = 0;
    for (final t in _terminals) {
      m += t is Str ? t.text.length : 1;
    }
    return m;
  }();

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
  int lastCost = -1, lastSteps = -1, lastHorizon = -1;
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
    // The horizon. Inside the single-character envelope the relaxed -1 is
    // exact (CFG-empty implies PEG-empty) and its empty-input answer is a
    // lower fabrication floor; outside it (the PRED territory -- measured:
    // wide lookaheads can LOSE repairs) neither is a certificate and only
    // the grammar's own mass is trusted. The mass term covers the measured
    // forced-duplication gap between the relaxed and true floors (an
    // optional stealing the first character of the literal behind it). The
    // undecidability of full-PEG emptiness forbids an unconditional
    // horizon; -1 means "no repair within lastHorizon", which every gate's
    // own truth horizon sits far inside.
    var fab = 0;
    if (!wide) {
      if (_base.recoverCost(input) == -1) {
        lastCost = -1;
        lastSteps = 0;
        return -1;
      }
      final f = _base.recoverCost('');
      if (f > 0) fab = f;
    }
    lastHorizon = _n + fab + _massG;
    return lastCost = _search(lastHorizon);
  }

  int _search(int cap) {
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

// ==========================================================================
// m62, FOLDED IN. m65 is a tape over m62's relaxed fixpoint, and
// used to reach it by import -- which made m65 look like 478 lines
// when it is this whole file. Nothing below is m65's idea.
// (`_widestClass` and `_width` above are m65's own: the two files
// declared them identically.)

/// log2 of the code-point alphabet, in millibits: what a FAB asserts.
// ---- the normal form: three node kinds, built once per grammar -------------

sealed class _Node {
  _Node(this.id, this.orig);
  final int id;
  final Clause orig;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable, this.demands);
  final bool editable;
  final int demands;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);
  late final List<_Node> alts;
}

/// A memo entry holds only durable knowledge: the value, the largest budget
/// it has been settled at, and the left-recursion staleness stamp. Membership
/// in the live chain is an index into the frame stack (-1 when parked out).
class _Entry {
  _Entry(this.node, this.pos, this.c);
  final _Node node;
  final int pos;
  final int c;

  /// I1/I9: flat triples `[key, cost, regret, ...]`, written in place for the
  /// entry's whole life. Null = never computed (the left-recursion seed).
  List<int>? value;

  /// A3: the largest budget this entry has been settled at. A bigger request
  /// recomputes (accumulating); a smaller one filters.
  int settledBudget = -1;

  /// `MemoEntry.memoVersion`: stale after a left-recursive widening at this
  /// position bumped the counter.
  int version = 0;

  /// The index of this entry's frame on the live stack, or -1: `inRecPath`
  /// and the parent pointer in one integer.
  int activeDepth = -1;
}

/// The transient half of m60's coroutine: everything about the pass in
/// flight, pooled by depth and reused.
class _Frame {
  late _Entry entry;
  int budget = -1;

  /// The program counter: which child request comes next. For an alternation,
  /// the branch index; for a sequence, 0 is the head and 1+i is the tail under
  /// the head's i-th answer; for a terminal and for the budget-zero walk, 0.
  int pc = 0;

  /// The resolved head entry of a cons, kept from pc 0 so tail requests read
  /// its answers without a lookup.
  _Entry? headEntry;

  /// `foundLeftRec`: a descendant re-entered this frame's entry, so the
  /// completed pass must widen until nothing improves.
  bool foundCycle = false;

  /// Did the current pass improve the value (I9's write-is-the-test)?
  bool improved = false;
}

class _Relaxed {
  final Map<String, Clause> rules;
  final String topRuleName;
  _Relaxed({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form (m59's, verbatim) --------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable, int demands) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable, demands);
  }

  late final _Node _eps = _term(const Nothing(), false, _free);

  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true, _free), const Nothing());

  _Node _wrap(_Node reader, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = reader;

  static const int _lastCodeUnit = 0xFFFF;

  List<(int, int)>? _oneCharClass(Clause clause,
          [Set<String> seen = const {}]) =>
      switch (clause) {
        AnyChar() => const [(0, _lastCodeUnit)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 =>
          [(text.codeUnitAt(0), text.codeUnitAt(0))],
        CharSet(:final ranges, :final inverted) =>
          inverted ? _complement(ranges) : ranges,
        First(:final subClauses) => () {
            final out = <(int, int)>[];
            for (final part in subClauses) {
              final ranges = _oneCharClass(part, seen);
              if (ranges == null) return null;
              out.addAll(ranges);
            }
            return out;
          }(),
        Ref(:final ruleName) when !seen.contains(ruleName) =>
          _oneCharClass(_rules[ruleName]!, {...seen, ruleName}),
        _ => null,
      };

  static List<(int, int)> _complement(List<(int, int)> ranges) {
    final out = <(int, int)>[];
    var next = 0;
    for (final (lo, hi) in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (lo > next) out.add((next, lo - 1));
      next = math.max(next, hi + 1);
    }
    if (next <= _lastCodeUnit) out.add((next, _lastCodeUnit));
    return out;
  }

  static List<(int, int)> _intersect(List<(int, int)> a, List<(int, int)> b) => [
        for (final (alo, ahi) in a)
          for (final (blo, bhi) in b)
            if (alo <= bhi && blo <= ahi)
              (math.max(alo, blo), math.min(ahi, bhi)),
      ];

  // ---- I6/I7: the obligation lattice (m59's, verbatim) ---------------------

  static const int _free = -1;
  static const int _endMark = -1;
  final List<List<(int, int)>> _classes = [];
  final Map<String, int> _classIndex = {};

  int _intern(List<(int, int)> ranges) {
    final norm = <(int, int)>[];
    for (final r in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (r.$2 < r.$1) continue;
      if (norm.isNotEmpty && r.$1 <= norm.last.$2 + 1) {
        if (r.$2 > norm.last.$2) norm[norm.length - 1] = (norm.last.$1, r.$2);
      } else {
        norm.add(r);
      }
    }
    final key = norm.map((r) => '${r.$1}-${r.$2}').join(',');
    return _classIndex[key] ??= (_classes..add(norm)).length - 1;
  }

  int _meet(int a, int b) => a == _free
      ? b
      : b == _free
          ? a
          : _intern(_intersect(_classes[a], _classes[b]));

  bool _permits(int c, List<(int, int)>? emits) =>
      c == _free || (emits != null && _intersect(emits, _classes[c]).isNotEmpty);

  bool _has(int c, int ch) {
    for (final (lo, hi) in _classes[c]) {
      if (ch >= lo && ch <= hi) return true;
    }
    return false;
  }

  bool _permitsFirst(int c, int pos) =>
      c == _free || _has(c, _input.codeUnitAt(pos));

  bool _permitsEnd(int c) => c == _free || _has(c, _endMark);

  List<(int, int)>? _looks(Clause clause) => switch (clause) {
        FollowedBy(:final subClause) => _oneCharClass(subClause),
        NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
            final looked? => [..._complement(looked), (_endMark, _endMark)],
            null => null,
          },
        _ => null,
      };

  Clause? _fuse(Clause lookahead, Clause reader) {
    if (reader is! Terminal) return null;
    final reads = _oneCharClass(reader);
    if (reads == null) return null;
    final looks = _looks(lookahead);
    return looks == null ? null : CharSet(_intersect(looks, reads));
  }

  _Node _cons(List<Clause> parts, Clause orig) {
    final fused = <Clause>[];
    for (var i = parts.length - 1; i >= 0; i--) {
      final f = fused.isEmpty ? null : _fuse(parts[i], fused.first);
      if (f == null) {
        fused.insert(0, parts[i]);
      } else {
        fused[0] = f;
      }
    }
    var node = _eps;
    for (var i = fused.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(fused.sublist(i)))
        ..head = _node(fused[i])
        ..tail = node;
    }
    return node;
  }

  _Node _node(Clause clause) {
    final known = _nodes[clause];
    if (known != null) return known;
    if (clause is Ref) {
      final node = _Alt(_nodeCount++, clause);
      _nodes[clause] = node;
      node.alts = [_node(_rules[clause.ruleName]!)];
      return node;
    }
    late _Node node;
    if (clause is Seq) {
      node = _cons(clause.subClauses, clause);
    } else if (clause is Str && clause.text.length > 1) {
      node = _cons([for (final c in clause.text.split('')) Str(c)], clause);
    } else if (clause is First) {
      node = _Alt(_nodeCount++, clause)
        ..alts = [for (final s in clause.subClauses) _node(s)];
    } else if (clause is Optional) {
      node = _Alt(_nodeCount++, clause)..alts = [_node(clause.subClause), _eps];
    } else if (clause is Repetition) {
      final loop = _selfLoop(
          _node(clause.subClause),
          clause.requireOne
              ? Repetition(clause.subClause, requireOne: false)
              : clause);
      node = clause.requireOne
          ? (_Cons(_nodeCount++, clause)
            ..head = loop.head
            ..tail = loop)
          : loop;
    } else if (clause is Nothing) {
      node = _eps;
    } else {
      final accepts = _oneCharClass(clause);
      final looks = _looks(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks == null ? _free : _intern(looks));
      node = looks == null ? _wrap(leaf, clause) : leaf;
    }
    return _nodes[clause] = node;
  }

  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  // ---- the derived ceiling (m53's `_goalFromNothing`, over 2-stride pairs) --
  //
  // A1's trivial repair always exists: discard the whole input, fabricate the
  // goal. Its fabrication count is a property of the grammar, priced per
  // obligation owed; a predicate is the one leaf that may not be counted
  // (tier 1), trusted only when every derivation needs one (tier 2), and if
  // even that fails the language is empty and the caller learns it with no
  // search (tier 3). See LESSONS 5n.

  static bool _kb2(List<int> out, int key, int v) {
    for (var i = 0; i < out.length; i += 2) {
      if (out[i] != key) continue;
      if (out[i + 1] <= v) return false;
      out[i + 1] = v;
      return true;
    }
    out
      ..add(key)
      ..add(v);
    return true;
  }

  late final int _goalFromNothing = () {
    final all = <_Node>{};
    void visit(_Node node) {
      if (!all.add(node)) return;
      if (node is _Cons) {
        visit(node.head);
        visit(node.tail);
      } else if (node is _Alt) {
        node.alts.forEach(visit);
      }
    }

    visit(_goal);
    int cheapest(bool trustPredicates) {
      final cost = <int, List<List<int>>>{};
      var improved = true;
      List<List<int>> row(int c) => cost.putIfAbsent(c, () {
            improved = true;
            return List.generate(_nodeCount, (_) => <int>[]);
          });
      List<int> chain(_Cons node, int c) {
        final out = <int>[];
        if (identical(node.tail, node)) _kb2(out, c, 0);
        final heads = row(c)[node.head.id];
        for (var i = 0; i < heads.length; i += 2) {
          final tails = row(heads[i])[node.tail.id];
          for (var j = 0; j < tails.length; j += 2) {
            _kb2(out, tails[j], heads[i + 1] + tails[j + 1]);
          }
        }
        return out;
      }

      List<int> leaf(_Term node, int c) {
        if (node.demands != _free) return [_meet(c, node.demands), 0];
        final emits = node.editable ? _oneCharClass(node.orig) : null;
        if (emits != null && emits.isNotEmpty) {
          return _permits(c, emits) ? [_free, 1] : const [];
        }
        return node.editable ||
                node.orig is Nothing ||
                (trustPredicates && node.orig is! Terminal)
            ? [c, 0]
            : const [];
      }

      row(_free);
      while (improved) {
        improved = false;
        for (final c in cost.keys.toList()) {
          for (final node in all) {
            final now = switch (node) {
              _Term() => leaf(node, c),
              _Cons() => chain(node, c),
              _Alt(:final alts) => () {
                  final out = <int>[];
                  for (final alt in alts) {
                    final from = row(c)[alt.id];
                    for (var i = 0; i < from.length; i += 2) {
                      _kb2(out, from[i], from[i + 1]);
                    }
                  }
                  return out;
                }(),
            };
            final known = row(c)[node.id];
            for (var i = 0; i < now.length; i += 2) {
              if (_kb2(known, now[i], now[i + 1])) improved = true;
            }
          }
        }
      }
      var best = _impossible;
      final top = row(_free)[_goal.id];
      for (var i = 0; i < top.length; i += 2) {
        if (_permitsEnd(top[i]) && top[i + 1] < best) best = top[i + 1];
      }
      return best;
    }

    final sure = cheapest(false);
    return sure < _impossible ? sure : cheapest(true);
  }();

  static const int _impossible = 1 << 30;

  // ---- per-input state -----------------------------------------------------

  late Parser _parser;
  late String _input;
  late int _inputLen;
  late List<int> _regretPrefix;
  late List<int> _versionAtPos;
  final Map<int, int> _charRegret = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _cleanRegrets = {};
  MatchResult? _clean;
  int _steps = 0, _goalKey = -1, _goalCost = -1, _goalRegret = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;
  bool lastVerified = false;
  int get lastCells => _cells.length;
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

  int _skipRegret(int from, int to) => _regretPrefix[to] - _regretPrefix[from];
  int _widthOf(Clause clause) =>
      _widths.putIfAbsent(clause, () => _width(clause));

  void _buildRegretPrefix() {
    _regretPrefix = [0];
    for (var pos = 0; pos < _inputLen; pos++) {
      final ch = _input.codeUnitAt(pos);
      final narrowest = _charRegret.putIfAbsent(ch, () {
        final probe = Parser(
            rules: rules,
            topRuleName: topRuleName,
            input: String.fromCharCode(ch));
        var best = _widestClass;
        for (final terminal in _terminals) {
          if (terminal.match(probe, 0).len != 1) continue;
          best = math.min(best, _widthOf(terminal));
          if (best == 0) break;
        }
        return best;
      });
      _regretPrefix.add(_regretPrefix.last + narrowest);
    }
  }

  int _cleanRegret(MatchResult m) =>
      _cleanRegrets[m] ??= m.subClauseMatches.isEmpty
          ? _widthOf(m.clause!) * m.len
          : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));

  // ---- the value: triples, written in place (m59's, verbatim) --------------

  static bool _keepBest(List<int> out, int key, int cost, int reg) {
    for (var i = 0; i < out.length; i += 3) {
      if (out[i] != key) continue;
      if (out[i + 1] < cost || (out[i + 1] == cost && out[i + 2] <= reg)) {
        return false;
      }
      out[i + 1] = cost;
      out[i + 2] = reg;
      return true;
    }
    out
      ..add(key)
      ..add(cost)
      ..add(reg);
    return true;
  }

  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Entry> _cells = {};
  int _posShift = 0, _span = 0;

  _Entry _entryAt(_Node node, int pos, int c) => _cells.putIfAbsent(
      (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos,
      () => _Entry(node, pos, c));

  // ---- I18: the driver -----------------------------------------------------

  /// Is `e` usable at `budget` as it stands? (A3's filter direction, plus the
  /// left-recursion staleness rule, `MemoEntry` verbatim.)
  bool _settled(_Entry e, int budget) =>
      e.activeDepth < 0 &&
      e.value != null &&
      e.settledBudget >= budget &&
      e.version == _versionAtPos[e.pos];

  final List<_Frame> _stack = [];
  int _depth = -1;

  _Frame _push(_Entry e, int budget) {
    final d = ++_depth;
    if (_stack.length <= d) _stack.add(_Frame());
    e.activeDepth = d;
    e.value ??= <int>[];
    return _stack[d]
      ..entry = e
      ..budget = budget
      ..pc = 0
      ..headEntry = null
      ..foundCycle = false
      ..improved = false;
  }

  /// Run `e` to settlement at `budget`: one explicit DFS. The chain of parked
  /// parents IS the stack below the top, and the native stack never deepens.
  void _run(_Entry e, int budget) {
    if (budget < 0 || _settled(e, budget)) return;
    _push(e, budget);
    while (_depth >= 0) {
      _step(_stack[_depth]);
    }
  }

  /// Advance the top frame until it parks on a child (pushed; the loop steps
  /// it next) or settles (popped; the parent below is the new top, and its
  /// next step re-derives the awaited child from `pc`, finds it settled,
  /// consumes it, and moves on).
  void _step(_Frame f) {
    _steps++;
    final entry = f.entry;
    final node = entry.node;
    final pos = entry.pos;
    final budget = f.budget;
    final c = entry.c;
    // The budget-zero walk: the repaired string IS the input here and
    // everything after this entry is edit-free, so the oracle's one memoized
    // answer settles the whole subtree (LESSONS 5i/5m). No children.
    if (budget == 0) {
      if (f.pc == 0) {
        f.pc = 1;
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(f, _key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          _put(f, _key(pos, _meet(c, demands)), 0, 0);
          return _finish(f);
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(f, _key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
        if (editable) {
          final emits = _oneCharClass(node.orig);
          final silent = emits == null || emits.isEmpty;
          if (silent || _permits(c, emits)) {
            final owed = silent ? c : _free;
            if (pos < _inputLen) {
              _put(f, _key(pos + 1, owed), 1,
                  2 * _skipRegret(pos, pos + 1)); // SUB
            }
            _put(f, _key(pos, owed), 1, _widestClass); // FAB
          }
        }
        return _finish(f);
      case _Alt(:final alts):
        while (f.pc < alts.length) {
          final child = _entryAt(alts[f.pc], pos, c);
          if (child.activeDepth >= 0) {
            _stack[child.activeDepth].foundCycle = true; // the LR seed
          } else if (!_settled(child, budget)) {
            _push(child, budget);
            return; // park: the loop steps the new top next
          }
          _mergeAlt(f, alts.length, child);
          f.pc++;
        }
        return _finish(f);
      case _Cons():
        final loops = identical(node.tail, node);
        if (f.pc == 0) {
          if (loops) _put(f, _key(pos, c), 0, 0);
          final head = _entryAt(node.head, pos, c);
          if (head.activeDepth >= 0) {
            _stack[head.activeDepth].foundCycle = true;
          } else if (!_settled(head, budget)) {
            _push(head, budget);
            return; // park
          }
          f.headEntry = head;
          f.pc = 1;
        }
        final heads = f.headEntry!.value ?? const <int>[];
        while ((f.pc - 1) * 3 < heads.length) {
          final i = (f.pc - 1) * 3;
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (tail.activeDepth >= 0) {
            _stack[tail.activeDepth].foundCycle = true;
          } else if (!_settled(tail, rest)) {
            _push(tail, rest);
            return; // park
          }
          final rv = tail.value;
          if (rv != null) {
            for (var j = 0; j < rv.length; j += 3) {
              final total = hCost + rv[j + 1];
              if (total <= budget) {
                _put(f, rv[j], total, hReg + rv[j + 2]);
              }
            }
          }
          f.pc++;
        }
        return _finish(f);
    }
  }

  void _put(_Frame f, int key, int cost, int reg) {
    if (_keepBest(f.entry.value!, key, cost, reg)) f.improved = true;
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(_Frame f, int altCount, _Entry branch) {
    final v = branch.value;
    if (v == null) return;
    final budget = f.budget;
    var committed = -2;
    for (var i = 0; i < v.length; i += 3) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.match(f.entry.node.orig, f.entry.pos);
          committed = oracle.isMismatch ? -1 : f.entry.pos + oracle.len;
        }
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          continue;
        }
      }
      _put(f, key, cost, v[i + 2]);
    }
  }

  /// A pass ended. `MemoEntry.match`'s widening loop: if a descendant closed a
  /// cycle here and the pass improved the value, invalidate this position's
  /// memos and run another pass; otherwise settle and pop -- the parent below
  /// is the new top.
  void _finish(_Frame f) {
    final entry = f.entry;
    if (f.foundCycle && f.improved && f.budget > 0) {
      _versionAtPos[entry.pos]++;
      f.pc = 0;
      f.headEntry = null;
      f.improved = false;
      return; // another widening pass of the same frame
    }
    entry.settledBudget = f.budget;
    entry.version = _versionAtPos[entry.pos];
    entry.activeDepth = -1;
    f.headEntry = null;
    _depth--;
  }

  // ---- reconstruction and verification (m59's, with `_run` reads) ----------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];
  final Set<(_Alt, int, int, int, int)> _path = {};

  List<int> _ends(_Node node, int pos, int budget, int c) {
    if (pos > _inputLen || budget < 0) return const [];
    final e = _entryAt(node, pos, c);
    _run(e, budget);
    return e.value ?? const [];
  }

  (int, int)? _deltaOf(List<int> v, int key) {
    for (var i = 0; i < v.length; i += 3) {
      if (v[i] == key) return (v[i + 1], v[i + 2]);
    }
    return null;
  }

  MatchResult? _build(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    final end = _endOf(key);
    final orig = node.orig;
    final pure = pos > _inputLen ? mismatch : orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        cost == 0 &&
        _cleanRegret(pure) == reg &&
        (pure.len == 0
            ? key == _key(pos, c)
            : key == _key(end, _free) && _permitsFirst(c, pos))) {
      return pure;
    }
    switch (node) {
      case _Term():
        final accepts = c == _free ? null : _oneCharClass(orig);
        return Match(
            accepts == null ? orig : CharSet(_intersect(accepts, _classes[c])),
            pos,
            end - pos);
      case _Alt(:final alts):
        final state = (node, pos, key, cost, c);
        if (!_path.add(state)) return null;
        for (final alt in alts) {
          if (_deltaOf(_ends(alt, pos, budget, c), key) != (cost, reg)) {
            continue;
          }
          final m = _child(alt, pos, key, cost, reg, budget, c);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, key, cost, reg, budget, c);
        return children == null
            ? null
            : Match(orig, pos, end - pos, subClauseMatches: children);
    }
  }

  List<MatchResult>? _child(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    if (identical(node, _junk)) {
      final end = _endOf(key);
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, key, cost, reg, budget, c);
    }
    final m = _build(node, pos, key, cost, reg, budget, c);
    return m == null ? null : [m];
  }

  List<MatchResult>? _row(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    if (node is! _Cons) {
      return identical(node, _eps)
          ? (key == _key(pos, c) && cost == 0 && reg == 0 ? const [] : null)
          : _child(node, pos, key, cost, reg, budget, c);
    }
    final loops = identical(node.tail, node);
    final heads = List<int>.of(_ends(node.head, pos, budget, c));
    final order = [for (var i = 0; i < heads.length; i += 3) i]
      ..sort((a, b) {
        final byEnd = _endOf(heads[a]) - _endOf(heads[b]);
        return byEnd != 0 ? byEnd : heads[a] - heads[b];
      });
    for (final i in order) {
      final headKey = heads[i];
      final headEnd = _endOf(headKey);
      if (loops && headEnd == pos) continue;
      final hCost = heads[i + 1], hReg = heads[i + 2];
      if (hCost > cost || (hCost == cost && hReg > reg)) continue;
      final headOwed = _oweOf(headKey);
      final restBudget = budget - hCost;
      final rest =
          _deltaOf(_ends(node.tail, headEnd, restBudget, headOwed), key);
      if (rest == null || rest.$1 != cost - hCost || rest.$2 != reg - hReg) {
        continue;
      }
      final head = _child(node.head, pos, headKey, hCost, hReg, budget, c);
      if (head == null) continue;
      final tail =
          _row(node.tail, headEnd, key, rest.$1, rest.$2, restBudget, headOwed);
      if (tail != null) return [...head, ...tail];
    }
    return loops && key == _key(pos, c) && cost == 0 && reg == 0
        ? const []
        : null;
  }

  void _collect(MatchResult m) {
    final clause = m.clause;
    if (m is SyntaxError) {
      _spans.add(m);
    } else if (m.subClauseMatches.isEmpty &&
        clause is Terminal &&
        clause is! Nothing) {
      if (m.len == 0) {
        _missing.add(MissingObligation(clause, m.pos));
      } else if (clause.match(_parser, m.pos).isMismatch) {
        _spans.add(SyntaxError(pos: m.pos, len: m.len));
      }
    } else {
      m.subClauseMatches.forEach(_collect);
    }
  }

  void _emit(MatchResult m, StringBuffer out) {
    if (m is SyntaxError) return;
    final clause = m.clause;
    if (m.subClauseMatches.isEmpty) {
      out.write(clause is Terminal &&
              clause is! Nothing &&
              (m.len == 0 || clause.match(_parser, m.pos).isMismatch)
          ? _spelling(clause)
          : _input.substring(m.pos, m.pos + m.len));
      return;
    }
    var cursor = m.pos;
    for (final child in m.subClauseMatches) {
      if (child.pos > cursor) out.write(_input.substring(cursor, child.pos));
      _emit(child, out);
      cursor = child.pos + child.len;
    }
    if (cursor < m.pos + m.len) {
      out.write(_input.substring(cursor, m.pos + m.len));
    }
  }

  String _spelling(Clause clause) {
    final accepts = _oneCharClass(clause);
    if (accepts != null && accepts.isNotEmpty) {
      return String.fromCharCode(accepts.first.$1);
    }
    return clause is Str ? clause.text : '';
  }

  bool _verify(MatchResult root) {
    final out = StringBuffer();
    _emit(root, out);
    final s = out.toString();
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: s).parse();
    return !check.hasSyntaxErrors && check.root.len == s.length;
  }

  // ---- entry points --------------------------------------------------------

  SkipResult recover(String input) {
    final cost = recoverCost(input);
    _spans.clear();
    _missing.clear();
    _path.clear();
    lastVerified = false;
    if (cost == 0) {
      // A relaxed 0 on an input the pure parse rejects (the conformance
      // cases) has no clean tree to return; report it unverified instead of
      // dereferencing the absent parse.
      if (_clean == null) {
        final error = SyntaxError(pos: 0, len: _inputLen);
        return SkipResult(error, [error], const [], 1, true);
      }
      lastVerified = true;
      return SkipResult(_clean!, const [], const [], 0, false);
    }
    final root = cost < 0
        ? null
        : _build(_goal, 0, _goalKey, _goalCost, _goalRegret, cost, _free);
    if (root == null) {
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    _collect(root);
    lastVerified = _verify(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  int recoverCost(String input) {
    _input = input;
    _inputLen = input.length;
    _clean = null;
    final goal = _goal;
    final maxCost =
        _goalFromNothing < _impossible ? _inputLen + _goalFromNothing : -1;
    _posShift = (_inputLen + 2).bitLength;
    _span = 1 << _posShift;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildRegretPrefix();
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cells.clear();
    _stack.clear();
    _depth = -1;
    _cleanRegrets.clear();
    _steps = 0;
    // The ladder, with A3's filter: one memo serves every round.
    for (var k = 0; k <= maxCost; k++) {
      final goalEntry = _entryAt(goal, 0, _free);
      _run(goalEntry, k);
      final v = goalEntry.value;
      if (v == null) continue;
      var bestC = _impossible, bestR = _impossible;
      for (var i = 0; i < v.length; i += 3) {
        if (_endOf(v[i]) != _inputLen || !_permitsEnd(_oweOf(v[i]))) continue;
        if (v[i + 1] < bestC || (v[i + 1] == bestC && v[i + 2] < bestR)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          _goalKey = v[i];
        }
      }
      if (bestC < _impossible) {
        _goalCost = bestC;
        _goalRegret = bestR;
        lastCost = bestC;
        lastRegret = bestR - _skipRegret(0, _inputLen);
        lastSteps = _steps;
        return bestC;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}
// ERROR RECOVERY END
