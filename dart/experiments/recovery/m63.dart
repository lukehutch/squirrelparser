// m63 -- THE TAPE: true-PEG-exact repair as a shortest path over (input
// cursor, emitted text), with the frozen parser deciding every question about
// the emitted prefix. The first engine in the line whose ordered choice and
// possessive repetition mean what PEG says they mean.
//
//   I20 MEMBERSHIP, DEADNESS, AND THE USEFUL ALPHABET ARE ONE PROBED PARSE.
//       Wrap every terminal of the grammar in a probe that records when it
//       consults the open end of the emitted text y. One parse of y then
//       answers three questions at once: y is in L (a clean full parse of
//       exactly y is authoritative membership); y is DEAD (a parse that
//       failed without ever consulting the frontier fails identically on
//       every extension -- PEG's answers depend only on positions it read);
//       and which characters could matter next (the touching terminals'
//       next-needed characters -- the atoms). Dijkstra over states (i, y)
//       with MATCH / SUB / FAB / SKIP edges weighted (cost, regret) is then
//       exact under TRUE PEG semantics, because every decision -- ordered
//       choice commitment, possessive stopping, lookahead -- is made by the
//       frozen parser on the actual repaired text, never by a relaxation.
//       The suspended residual the tape design called for is not built; it
//       is re-derived from y by the parser on demand, memoized by y.
//
// The m62 relaxation supplies the derived bounds: its answer is a cost FLOOR
// (the CFG-union reading is a superset language), its 0 is exact (a clean
// pure parse), its -1 is exact (CFG-empty implies PEG-empty), and its answer
// on the empty input is the CFG fabrication floor, giving the search cap
// n + fab. A -1 from m63 means "no repair within the cap": for PEG-empty
// languages with a nonempty CFG reading (the possessive-star conformance
// cases) that is the honest, terminating answer; a true repair costing more
// than the cap is the one documented approximation at the -1 boundary.
//
// PARAMETERS: NONE. All bounds derived; atoms are canonical class
// representatives (lowest member, the line's _spelling convention).
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

  // ---- the probed grammar ---------------------------------------------------

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

  // ---- one probed parse: membership, deadness, atoms ------------------------

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

  // ---- regret: the narrowest reading of a character (m62's analogue) --------

  final Map<Clause, int> _widths = {};
  final Map<int, int> _charRegret = {};

  int _h(int ch) => _charRegret.putIfAbsent(ch, () {
        final probe = Parser(
            rules: rules,
            topRuleName: topRuleName,
            input: String.fromCharCode(ch));
        var best = _widestClass;
        for (final t in _terminals) {
          if (t.match(probe, 0).len != 1) continue;
          best = math.min(best, _widths.putIfAbsent(t, () => _width(t)));
          if (best == 0) break;
        }
        return best;
      });

  // ---- the search -----------------------------------------------------------

  late String _input;
  late int _n;
  int lastCost = -1, lastSteps = -1;
  bool lastVerified = false;
  int get lastCells => _clsMemo.length;

  // Dijkstra state store: parallel lists, ids interned by '$i|$y'.
  final Map<String, int> _ids = {};
  final List<int> _si = [], _sg = [], _sr = [], _sp = [], _sop = [], _sch = [];
  final List<String> _sy = [];
  // Binary heap over (key, id) pairs; key = g * 2^28 + regret, well inside
  // 63 bits for every derived bound in play.
  final List<int> _heapK = [], _heapV = [];

  static const int _opStart = 0, _opMatch = 1, _opSub = 2, _opFab = 3, _opSkip = 4;
  static const int _regSpan = 1 << 28;

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

  void _push(int i, String y, int g, int reg, int parent, int op, int ch) {
    final cls = _classify(y);
    if (!cls.member && !cls.open) return; // dead: no extension can revive it
    final key = '$i|$y';
    final known = _ids[key];
    if (known != null) {
      if (_sg[known] < g || (_sg[known] == g && _sr[known] <= reg)) return;
      _sg[known] = g;
      _sr[known] = reg;
      _sp[known] = parent;
      _sop[known] = op;
      _sch[known] = ch;
      _hpush(g * _regSpan + reg, known);
      return;
    }
    final id = _si.length;
    _ids[key] = id;
    _si.add(i);
    _sy.add(y);
    _sg.add(g);
    _sr.add(reg);
    _sp.add(parent);
    _sop.add(op);
    _sch.add(ch);
    _hpush(g * _regSpan + reg, id);
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
    // is NOT a membership certificate -- a rung-0 CFG-union parse also
    // returns 0, which is exactly what the conformance cases exhibit.
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
    _sr.clear();
    _sp.clear();
    _sop.clear();
    _sch.clear();
    _heapK.clear();
    _heapV.clear();
    _clsMemo.clear();
    _classifies = 0;
    final settled = <int>{};
    _push(0, '', 0, 0, -1, _opStart, -1);
    while (_heapK.isNotEmpty) {
      final (pri, id) = _hpop();
      final g = pri ~/ _regSpan, reg = pri % _regSpan;
      if (g != _sg[id] || reg != _sr[id]) continue; // stale heap entry
      if (!settled.add(id)) continue;
      if (g > cap) break;
      final i = _si[id];
      final y = _sy[id];
      final cls = _classify(y);
      if (cls.member && i == _n) {
        _accepted = id;
        lastCost = g;
        lastSteps = _classifies;
        return g;
      }
      final expandable = !cls.member || cls.open;
      if (i < _n) {
        final cu = _input.codeUnitAt(i);
        if (expandable) {
          _push(i + 1, y + _input[i], g, reg, id, _opMatch, cu);
        }
        _push(i + 1, y, g + 1, reg + 2 * _h(cu), id, _opSkip, cu);
        if (expandable) {
          for (final a in cls.atoms) {
            if (a != cu) {
              _push(i + 1, y + String.fromCharCode(a), g + 1, reg + 2 * _h(cu),
                  id, _opSub, a);
            }
          }
        }
      }
      if (expandable) {
        for (final a in cls.atoms) {
          _push(i, y + String.fromCharCode(a), g + 1, reg + _widestClass, id,
              _opFab, a);
        }
      }
    }
    lastCost = -1;
    lastSteps = _classifies;
    return -1; // no repair within the derived cap
  }

  // ---- witness: the path IS the alignment -----------------------------------

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
    // Reconstruct the edit script root-ward, then replay it forward.
    final ops = <(int, int)>[]; // (op, char)
    for (var id = _accepted; _sp[id] >= 0; id = _sp[id]) {
      ops.add((_sop[id], _sch[id]));
    }
    final script = ops.reversed.toList();
    final y = _sy[_accepted];
    // bnd[j] = the input position where emitted char j begins, with skipped
    // input attributed to the preceding span: bnd[0] = 0, bnd[|y|] = n, so
    // the remapped leaves tile the input with no gaps.
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
