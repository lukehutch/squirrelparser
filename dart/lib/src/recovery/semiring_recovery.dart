// Semiring recovery: the "transcendent principle" of ERROR_RECOVERY_DESIGN.md
// Sec. 14.4, implemented literally and standalone (none of the skip-driver or
// frontier machinery is used):
//
//     "There is no error recovery -- there is only parsing, evaluated in a
//      larger semiring."
//
// The grammar is closed with two weighted productions per clause C:
//
//     C -> <span-char> C     (cost 1: one input char inside C's extent is a
//                             syntax-error span)
//     C -> epsilon           (cost 1: C's obligation is skipped as missing)
//
// and the closed grammar is interpreted over a tropical-style semiring:
//
//     chart[C, p] = { end -> Pareto set of weighted matches of C over
//                     [p, end) }
//
// No search, no events, no frames, no heuristics: the chart is computed by
// direct dynamic programming and a repair is read back out of it. The span
// production makes cell (C, p) depend on cell (C, p+1), which forces the
// pika parser's evaluation order -- positions right-to-left, clauses
// bottom-up, with a fixpoint iteration within each position. (The same
// within-position fixpoint is how pika supports left recursion, and it
// handles left recursion here too, with no special casing.)
//
// THE WEIGHTS. Two weightings are supported, selected by [compactness]:
//
//  - compactness: false -- the pure (min,+) cost semiring, values in N.
//    Measured result: plain cost is DEGENERATE at equal cost (a
//    substitution's honest span+missing ties with an absorber that
//    re-roles distant anchors, e.g. two quote spans that swallow an
//    array as string content), and extraction picks arbitrarily.
//  - compactness: true (default) -- values are tuples
//    (cost, spanChars, editLo, editHi), combined by (+, +, min, max) and
//    compared lexicographically by (cost, editHi-editLo, spanChars): the
//    frontier's "single-point damage => point repair" prior expressed as
//    a semiring enrichment rather than a search heuristic. Because the
//    edit interval combines by union (not addition), a cell must keep the
//    PARETO SET of incomparable tuples per end (dominance: <= on cost and
//    spanChars, superset-free on interval); an exchange argument shows
//    Pareto sets suffice for lexicographic optimality.
//
// Design decisions -- the only places the pure principle needs interpreting:
//
//  - Ordered choice under min is per-end MIN over the alternatives: PEG's
//    commitment to the first matching alternative is not a semiring
//    operation. On the zero-cost slice this can in principle admit parses
//    the pure PEG would reject (a CFG-like reading); tree extraction
//    restores PEG tie-breaks (first alternative, greedy/longest items,
//    Optional-taken-first) among equal-weight witnesses. The divergence is
//    empirically measurable: a PEG-invalid input recovered at total cost 0.
//  - Predicates (& / !) consult the ZERO slice, via the pure Parser as an
//    unmodified oracle: negation is not monotone under min, so a lookahead
//    judges the real text, not repairable text. Both closure productions
//    still apply to predicate clauses themselves (span = the test
//    re-anchored past garbage; epsilon = waive the lookahead for 1).
//  - Repetition items must strictly advance (end > start), matching the
//    pure parser's zero-length-item rule; a zero-width item is admitted
//    only as a single take at cost >= 1 (a repaired "missing item"), never
//    at cost 0 -- the pure parser mismatches OneOrMore whose first item
//    matches empty, and the zero slice must agree.
//  - A multi-char Str is its character sequence under the closure, so its
//    normal production IS banded edit distance between literal and input
//    (match 0 / missing-char 1 / span-char 1) -- the Sec. 13 "banded DP"
//    idea is not a feature here, it falls out of the closure.
//  - Trailing garbage after the top match is charged 1 per char at
//    selection time (the top-level wrapper's span production, applied
//    outside the chart).
//
// Optimality: costs are non-negative, so every subderivation of a
// total-cost-T derivation itself costs <= T; a chart capped at cost k
// therefore represents ALL solutions of total cost <= k. If the best total
// found is <= k it is globally minimal (certificate); otherwise the cap
// doubles and the chart is rebuilt (iterative deepening).
//
// Complexity (the honest price of eagerness): cells = positions x clauses,
// and a cell's entry count grows with the input (e.g. a Repetition cell
// holds a cost-0 stop per item boundary), so the chart is O(n^2)-ish in
// both space and time with pika's "every clause at every position"
// constant on top. This is the eager extreme of the design plane; the
// frontier is the lazy best-first extreme of the same object.

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';
import 'skip_recovery.dart' show SkipResult, MissingObligation;

/// Weighted value: (cost, spanChars, editLo, editHi). editLo > editHi means
/// "no edits" (the identity interval for union).
typedef _V = (int, int, int, int);

const int _inf = 1 << 24;
const _V _zero = (0, 0, _inf, -1);

_V _vAdd(_V a, _V b) => (
      a.$1 + b.$1,
      a.$2 + b.$2,
      a.$3 < b.$3 ? a.$3 : b.$3,
      a.$4 > b.$4 ? a.$4 : b.$4
    );

bool _vEq(_V a, _V b) =>
    a.$1 == b.$1 && a.$2 == b.$2 && a.$3 == b.$3 && a.$4 == b.$4;

int _vDiam(_V a) => a.$4 >= a.$3 ? a.$4 - a.$3 : 0;

class SemiringRecovery {
  /// Grammar as given (may contain '~'-prefixed transparent rule names).
  final Map<String, Clause> rules;
  final String topRuleName;

  /// Initial cost cap for iterative deepening (doubles until certified).
  final int initialCostCap;

  /// If true (default), weights carry span-chars and the edit interval, and
  /// ordering is lexicographic (cost, diameter, spanChars) -- the
  /// compactness prior as a semiring enrichment. If false, the pure cost
  /// semiring (measurably degenerate at equal cost).
  final bool compactness;

  /// Ablation of the value tuple (only meaningful with compactness=true):
  /// 'full'    = dominance and selection use (cost, spanChars, lo, hi),
  ///             selection lex (cost, diameter, lo desc, spanChars);
  /// 'costLo'  = only (cost, lo) considered: dominance cost<= && lo>=,
  ///             selection lex (cost, lo desc);
  /// 'costOnly'= scalar cost (equivalent to compactness=false plus
  ///             structural epsilon).
  final String weightMode;
  final bool debug;

  SemiringRecovery(
      {required this.rules,
      required this.topRuleName,
      this.initialCostCap = 4,
      this.compactness = true,
      this.weightMode = 'full',
      this.debug = false});

  /// Rule map with '~' prefixes stripped (Ref uses stripped names).
  late final Map<String, Clause> _rules = () {
    final m = <String, Clause>{};
    rules.forEach((k, v) => m[k.startsWith('~') ? k.substring(1) : k] = v);
    return m;
  }();

  /// Every clause node reachable from the top rule, children before
  /// parents (post-order; cycles cut arbitrarily -- the fixpoint corrects
  /// any imperfect ordering, it only costs extra rounds).
  late final List<Clause> _universe = () {
    final seen = <Clause>{};
    final out = <Clause>[];
    void collect(Clause c) {
      if (!seen.add(c)) return;
      if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t == null) throw ArgumentError('rule "${c.ruleName}" not found');
        collect(t);
      } else if (c is HasOneSubClause) {
        collect(c.subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(collect);
      }
      out.add(c);
    }

    final top = _rules[topRuleName];
    if (top == null) throw ArgumentError('top rule "$topRuleName" not found');
    collect(top);
    return out;
  }();

  late final Map<Clause, int> _cid = () {
    final m = <Clause, int>{};
    for (var i = 0; i < _universe.length; i++) {
      m[_universe[i]] = i;
    }
    return m;
  }();

  // ---- per-recover() state ----
  late String input;
  late int n;
  Parser? _oracle; // zero-slice oracle, used only by predicate clauses
  late List<List<Map<int, List<_V>>?>> _cells; // [pos][cid] -> {end: Pareto}
  late int _k; // current cost cap
  late List<MissingObligation> _missing;
  int _depth = 0;

  // Introspection (last recover() call).
  int lastTotalCost = -1;
  int lastCostCap = -1;
  int lastChartEntries = -1;
  int lastFixpointRounds = -1;

  static const Map<int, List<_V>> _emptyCell = {};

  Map<int, List<_V>> _cellC(Clause c, int q) {
    if (q < 0 || q > n) return _emptyCell;
    return _cells[q][_cid[c]!] ?? _emptyCell;
  }

  /// a dominates b: at least as good for every possible continuation and
  /// for the final lexicographic order.
  bool _dom(_V a, _V b) {
    if (!compactness) return a.$1 <= b.$1;
    return a.$1 <= b.$1 && a.$2 <= b.$2 && a.$3 >= b.$3 && a.$4 <= b.$4;
  }

  /// Weight constructor. Values always carry the full tuple (dominance and
  /// witness extraction stay exact); weightMode ablates only the SELECTION
  /// order, which is sound: a full-tuple dominator is also at least as good
  /// under every ablated order.
  _V _mk(int cost, int sp, int lo, int hi) => (cost, sp, lo, hi);

  /// Insert v into the Pareto list for end. Returns true if kept.
  bool _insert(Map<int, List<_V>> cell, int end, _V v) {
    if (v.$1 > _k) return false;
    final list = cell[end];
    if (list == null) {
      cell[end] = [v];
      return true;
    }
    for (final e in list) {
      if (_dom(e, v)) return false;
    }
    list.removeWhere((e) => _dom(v, e));
    list.add(v);
    return true;
  }

  SkipResult recover(String input) {
    this.input = input;
    n = input.length;
    _oracle = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final topClause = _rules[topRuleName]!;

    var k = initialCostCap;
    var bestTotal = 1 << 30;
    var bestEnd = -1;
    _V bestV = _zero;
    while (true) {
      _k = k;
      _buildChart(k);
      bestTotal = 1 << 30;
      bestEnd = -1;
      var bestDiam = 1 << 30;
      var bestLo = -1;
      var bestSp = 1 << 30;
      _cellC(topClause, 0).forEach((e, list) {
        for (final v in list) {
          // Trailing garbage charged 1/char as top-level spans.
          final t = e < n ? _vAdd(v, _mk(n - e, n - e, e, n - 1)) : v;
          final tot = t.$1;
          final diam = _vDiam(t);
          final sp = t.$2;
          // First edit as late as possible (P5, the leading-edge rule as a
          // selection order): honest repairs edit where matching stopped;
          // absorbers must start re-roling real material earlier.
          final lo = t.$3 > t.$4 ? 1 << 24 : t.$3;
          final bool better;
          if (!compactness || weightMode == 'costOnly') {
            better = tot < bestTotal || (tot == bestTotal && e > bestEnd);
          } else if (weightMode == 'costLo') {
            better = tot < bestTotal ||
                (tot == bestTotal &&
                    (lo > bestLo || (lo == bestLo && e > bestEnd)));
          } else {
            better = tot < bestTotal ||
                (tot == bestTotal &&
                    (diam < bestDiam ||
                        (diam == bestDiam &&
                            (lo > bestLo ||
                                (lo == bestLo &&
                                    (sp < bestSp ||
                                        (sp == bestSp && e > bestEnd)))))));
          }
          if (better) {
            bestTotal = tot;
            bestDiam = diam;
            bestLo = lo;
            bestSp = sp;
            bestEnd = e;
            bestV = v;
          }
        }
      });
      if (bestTotal <= k || k > n + 2) break; // certificate or exhausted
      k *= 2;
    }
    lastTotalCost = bestTotal;
    lastCostCap = k;
    if (debug) {
      print('SEMIRING cost=$bestTotal end=$bestEnd/(n=$n) cap=$k '
          'entries=$lastChartEntries rounds<=$lastFixpointRounds');
    }

    _missing = [];
    _depth = 0;
    final topNode = _derive(topClause, 0, bestEnd, bestV);
    final rootKids = <MatchResult>[topNode];
    if (bestEnd < n) rootKids.add(SyntaxError(pos: bestEnd, len: n - bestEnd));
    final root = Match(null, 0, 0, subClauseMatches: rootKids);

    // Collect span leaves in position order; merge adjacent units.
    final raw = <SyntaxError>[];
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        raw.add(m);
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(root);
    raw.sort((a, b) => a.pos.compareTo(b.pos));
    final spans = <SyntaxError>[];
    for (final s in raw) {
      if (spans.isNotEmpty && spans.last.pos + spans.last.len == s.pos) {
        final last = spans.removeLast();
        spans.add(SyntaxError(pos: last.pos, len: last.len + s.len));
      } else {
        spans.add(s);
      }
    }
    _missing.sort((a, b) => a.pos.compareTo(b.pos));

    final clean = bestTotal == 0;
    return SkipResult(root, spans, _missing, clean ? 0 : 1, false);
  }

  // ---- chart construction ----

  void _buildChart(int k) {
    final u = _universe.length;
    _cells = List.generate(
        n + 1, (_) => List<Map<int, List<_V>>?>.filled(u, null));
    var maxRounds = 0;
    for (var pos = n; pos >= 0; pos--) {
      var rounds = 0;
      bool changed;
      do {
        changed = false;
        for (var ci = 0; ci < u; ci++) {
          final neu = _compute(_universe[ci], pos, k);
          final old = _cells[pos][ci];
          if (!_cellEq(old, neu)) {
            _cells[pos][ci] = neu;
            changed = true;
          }
        }
        if (++rounds > 500) throw StateError('no fixpoint at pos $pos');
      } while (changed);
      if (rounds > maxRounds) maxRounds = rounds;
    }
    var entries = 0;
    for (final row in _cells) {
      for (final m in row) {
        if (m != null) {
          for (final l in m.values) {
            entries += l.length;
          }
        }
      }
    }
    lastFixpointRounds = maxRounds;
    lastChartEntries = entries;
  }

  bool _cellEq(Map<int, List<_V>>? a, Map<int, List<_V>> b) {
    if (a == null || a.length != b.length) return false;
    for (final e in b.entries) {
      final la = a[e.key];
      if (la == null || la.length != e.value.length) return false;
      // Order-insensitive small-set comparison.
      for (final v in e.value) {
        var found = false;
        for (final w in la) {
          if (_vEq(v, w)) {
            found = true;
            break;
          }
        }
        if (!found) return false;
      }
    }
    return true;
  }

  Map<int, List<_V>> _compute(Clause c, int pos, int k) {
    final out = <int, List<_V>>{};
    void add(int end, _V v) => _insert(out, end, v);

    // ---- normal (weighted-PEG) production ----
    if (c is Char) {
      if (pos < n && input.codeUnitAt(pos) == c.char.codeUnitAt(0)) {
        add(pos + 1, _zero);
      }
    } else if (c is CharSet) {
      if (pos < n && _csMatch(c, input.codeUnitAt(pos))) add(pos + 1, _zero);
    } else if (c is Str) {
      _strLayers(c, pos).last.forEach((e, list) {
        for (final v in list) {
          add(e, v);
        }
      });
    } else if (c is AnyChar) {
      if (pos < n) add(pos + 1, _zero);
    } else if (c is Nothing) {
      add(pos, _zero);
    } else if (c is Seq) {
      var cur = <int, List<_V>>{
        pos: [_zero]
      };
      for (final sub in c.subClauses) {
        final next = <int, List<_V>>{};
        cur.forEach((q, lv) {
          _cellC(sub, q).forEach((e, lw) {
            for (final v in lv) {
              for (final w in lw) {
                _insert(next, e, _vAdd(v, w));
              }
            }
          });
        });
        cur = next;
        if (cur.isEmpty) break;
      }
      cur.forEach((e, lv) {
        for (final v in lv) {
          add(e, v);
        }
      });
    } else if (c is First) {
      for (final alt in c.subClauses) {
        _cellC(alt, pos).forEach((e, lv) {
          for (final v in lv) {
            add(e, v);
          }
        });
      }
    } else if (c is Repetition) {
      final item = c.subClause;
      final reached = <int, List<_V>>{
        pos: [_zero]
      };
      var frontier = <int, List<_V>>{
        pos: [_zero]
      };
      while (frontier.isNotEmpty) {
        final nf = <int, List<_V>>{};
        frontier.forEach((q, lv) {
          _cellC(item, q).forEach((e, lw) {
            if (e <= q) return; // items must advance
            for (final v in lv) {
              for (final w in lw) {
                final t = _vAdd(v, w);
                if (_insert(reached, e, t)) _insert(nf, e, t);
              }
            }
          });
        });
        frontier = nf;
      }
      reached.forEach((q, lv) {
        if (q > pos) {
          for (final v in lv) {
            add(q, v);
          }
        }
      });
      if (c.requireOne) {
        // Single zero-width item only as a REPAIR (cost >= 1): the pure
        // parser mismatches OneOrMore on a zero-width first item.
        for (final v in _cellC(item, pos)[pos] ?? const <_V>[]) {
          if (v.$1 >= 1) add(pos, v);
        }
      } else {
        add(pos, _zero);
      }
    } else if (c is Optional) {
      _cellC(c.subClause, pos).forEach((e, lv) {
        for (final v in lv) {
          add(e, v);
        }
      });
      add(pos, _zero);
    } else if (c is Ref) {
      _cellC(_rules[c.ruleName]!, pos).forEach((e, lv) {
        for (final v in lv) {
          add(e, v);
        }
      });
    } else if (c is NotFollowedBy) {
      if (c.subClause.match(_oracle!, pos).isMismatch) add(pos, _zero);
    } else if (c is FollowedBy) {
      if (!c.subClause.match(_oracle!, pos).isMismatch) add(pos, _zero);
    } else {
      throw UnsupportedError('clause type ${c.runtimeType}');
    }

    // ---- closure productions (uniform, every clause) ----
    if (pos < n) {
      _cellC(c, pos + 1).forEach((e, lv) {
        for (final v in lv) {
          add(e, _vAdd(v, _mk(1, 1, pos, pos))); // C -> <span-char> C
        }
      });
    }
    add(pos, _mk(_epsCost(c), 0, pos, pos)); // C -> epsilon ("missing")

    return out;
  }

  /// Cost of the epsilon production for [c]: a missing terminal is one
  /// missing char (1); a missing composite fabricates a whole structure out
  /// of nothing, which P8 ("zero-width cost incoherence") showed must cost
  /// more than a corroborated leaf repair -- otherwise "missing Member"
  /// ties with an honest one-char span and extraction cannot tell them
  /// apart. Waiving a predicate fabricates nothing (1).
  int _epsCost(Clause c) =>
      (c is Terminal || c is NotFollowedBy || c is FollowedBy) ? 1 : 2;

  bool _csMatch(CharSet cs, int ch) {
    var inSet = false;
    for (final (lo, hi) in cs.ranges) {
      if (ch >= lo && ch <= hi) {
        inSet = true;
        break;
      }
    }
    return cs.inverted ? !inSet : inSet;
  }

  /// Banded edit-distance layers for a Str literal starting at [pos]:
  /// layers[j] = { inputPos -> Pareto } after consuming j literal chars.
  /// Within-layer relaxation = span-char; layer step = match / missing-char.
  /// No relaxation on the final layer (a Str's extent ends at its last
  /// matched or spanned char; trailing garbage belongs to what follows).
  List<Map<int, List<_V>>> _strLayers(Str c, int pos) {
    final text = c.text;
    final m = text.length;
    final layers =
        List<Map<int, List<_V>>>.generate(m + 1, (_) => <int, List<_V>>{});
    var qMax = pos + m + _k;
    if (qMax > n) qMax = n;
    void relax(Map<int, List<_V>> layer) {
      for (var q = pos; q < qMax; q++) {
        final lv = layer[q];
        if (lv == null) continue;
        for (final v in List<_V>.of(lv)) {
          _insert(layer, q + 1, _vAdd(v, _mk(1, 1, q, q)));
        }
      }
    }

    layers[0][pos] = [_zero];
    relax(layers[0]);
    for (var j = 0; j < m; j++) {
      final cu = layers[j];
      final nx = layers[j + 1];
      final tc = text.codeUnitAt(j);
      cu.forEach((q, lv) {
        for (final v in lv) {
          if (q < n && input.codeUnitAt(q) == tc) {
            _insert(nx, q + 1, v); // match
          }
          _insert(nx, q, _vAdd(v, _mk(1, 0, q, q))); // missing literal char
        }
      });
      if (j + 1 < m) relax(nx);
    }
    return layers;
  }

  // ---- witness extraction ----
  //
  // _derive is only ever called with v a member of the Pareto cell for
  // (c, p, end), so a witness must exist; the throws below are bug
  // detectors, not reachable states. Production preference at equal
  // weight: normal, then span, then epsilon (prefer real material over
  // fabrication). PEG tie-breaks inside normal productions: first
  // alternative, largest feasible child extent (greedy), Optional taken
  // before empty.

  bool _contains(List<_V>? list, _V v) {
    if (list == null) return false;
    for (final w in list) {
      if (_vEq(w, v)) return true;
    }
    return false;
  }

  MatchResult _derive(Clause c, int p, int end, _V v) {
    if (++_depth > 200000) throw StateError('derive recursion depth');
    try {
      final m = _deriveNormal(c, p, end, v);
      if (m != null) return m;
      // span production: C -> <char> C
      if (p < n && v.$1 >= 1) {
        final unit = _mk(1, 1, p, p);
        for (final w in _cellC(c, p + 1)[end] ?? const <_V>[]) {
          if (_vEq(_vAdd(w, unit), v)) {
            final rest = _derive(c, p + 1, end, w);
            final kids = <MatchResult>[SyntaxError(pos: p, len: 1)];
            if (rest.subClauseMatches.isNotEmpty) {
              // rest is a node for the same clause c: splice, don't
              // double-wrap
              kids.addAll(rest.subClauseMatches);
            } else if (rest.len > 0) {
              kids.add(rest);
            }
            return Match(c, 0, 0, subClauseMatches: kids);
          }
        }
      }
      // epsilon production: C -> ()
      if (end == p && _vEq(v, _mk(_epsCost(c), 0, p, p))) {
        _missing.add(MissingObligation(c, p));
        return Match(c, p, 0);
      }
      throw StateError('no derivation witness: $c @$p end=$end v=$v');
    } finally {
      _depth--;
    }
  }

  MatchResult? _deriveNormal(Clause c, int p, int end, _V v) {
    if (c is Char) {
      if (end == p + 1 &&
          _vEq(v, _zero) &&
          p < n &&
          input.codeUnitAt(p) == c.char.codeUnitAt(0)) {
        return Match(c, p, 1);
      }
      return null;
    }
    if (c is CharSet) {
      if (end == p + 1 &&
          _vEq(v, _zero) &&
          p < n &&
          _csMatch(c, input.codeUnitAt(p))) {
        return Match(c, p, 1);
      }
      return null;
    }
    if (c is AnyChar) {
      if (end == p + 1 && _vEq(v, _zero) && p < n) return Match(c, p, 1);
      return null;
    }
    if (c is Nothing) {
      if (end == p && _vEq(v, _zero)) return Match(c, p, 0);
      return null;
    }
    if (c is Str) return _deriveStr(c, p, end, v);
    if (c is Seq) return _deriveSeq(c, p, end, v);
    if (c is First) {
      for (final alt in c.subClauses) {
        if (_contains(_cellC(alt, p)[end], v)) {
          return Match(c, 0, 0, subClauseMatches: [_derive(alt, p, end, v)]);
        }
      }
      return null;
    }
    if (c is Repetition) return _deriveRep(c, p, end, v);
    if (c is Optional) {
      if (_contains(_cellC(c.subClause, p)[end], v)) {
        return Match(c, 0, 0,
            subClauseMatches: [_derive(c.subClause, p, end, v)]);
      }
      if (end == p && _vEq(v, _zero)) return Match(c, p, 0);
      return null;
    }
    if (c is Ref) {
      final t = _rules[c.ruleName]!;
      if (_contains(_cellC(t, p)[end], v)) {
        return Match(c, 0, 0, subClauseMatches: [_derive(t, p, end, v)]);
      }
      return null;
    }
    if (c is NotFollowedBy) {
      if (end == p &&
          _vEq(v, _zero) &&
          c.subClause.match(_oracle!, p).isMismatch) {
        return Match(c, p, 0);
      }
      return null;
    }
    if (c is FollowedBy) {
      if (end == p &&
          _vEq(v, _zero) &&
          !c.subClause.match(_oracle!, p).isMismatch) {
        return Match(c, p, 0);
      }
      return null;
    }
    throw UnsupportedError('clause type ${c.runtimeType}');
  }

  MatchResult? _deriveStr(Str c, int p, int end, _V v) {
    final m = c.text.length;
    if (_vEq(v, _zero)) {
      if (end != p + m) return null;
      return Match(c, p, m); // exact literal
    }
    final layers = _strLayers(c, p);
    if (!_contains(layers[m][end], v)) return null;
    // Backtrack, preferring match > missing > span.
    var j = m;
    var q = end;
    var cv = v;
    final ops = <(String, int, int)>[]; // (op, inputPos, literalIdx)
    var guard = 0;
    while (j > 0 || q > p || !_vEq(cv, _zero)) {
      if (++guard > 100000) throw StateError('str backtrace loop');
      if (j > 0 &&
          q > p &&
          q - 1 < n &&
          input.codeUnitAt(q - 1) == c.text.codeUnitAt(j - 1) &&
          _contains(layers[j - 1][q - 1], cv)) {
        ops.add(('m', q - 1, j - 1));
        j--;
        q--;
        continue;
      }
      var stepped = false;
      if (j > 0) {
        final unit = _mk(1, 0, q, q); // missing literal char at q
        for (final w in layers[j - 1][q] ?? const <_V>[]) {
          if (_vEq(_vAdd(w, unit), cv)) {
            ops.add(('x', q, j - 1));
            j--;
            cv = w;
            stepped = true;
            break;
          }
        }
      }
      if (stepped) continue;
      if (j < m && q > p) {
        final unit = (1, 1, q - 1, q - 1); // span char at q-1
        for (final w in layers[j][q - 1] ?? const <_V>[]) {
          if (_vEq(_vAdd(w, unit), cv)) {
            ops.add(('s', q - 1, -1));
            q--;
            cv = w;
            stepped = true;
            break;
          }
        }
      }
      if (stepped) continue;
      throw StateError('str backtrace stuck: $c @$p end=$end v=$v');
    }
    final kids = <MatchResult>[];
    for (final (op, qq, tj) in ops.reversed) {
      if (op == 'm') {
        kids.add(Match(c, qq, 1));
      } else if (op == 's') {
        kids.add(SyntaxError(pos: qq, len: 1));
      } else {
        _missing.add(MissingObligation(Char(c.text[tj]), qq));
      }
    }
    if (kids.isEmpty) return Match(c, p, 0);
    return Match(c, 0, 0, subClauseMatches: kids);
  }

  MatchResult? _deriveSeq(Seq c, int p, int end, _V v) {
    final subs = c.subClauses;
    final kk = subs.length;
    // suff[i][q] = Pareto set of ways to run children i..kk-1 from q to
    // exactly end.
    final suff =
        List<Map<int, List<_V>>>.generate(kk + 1, (_) => <int, List<_V>>{});
    suff[kk][end] = [_zero];
    for (var i = kk - 1; i >= 0; i--) {
      for (var q = p; q <= end; q++) {
        _cellC(subs[i], q).forEach((e, lw) {
          if (e > end) return;
          final ls = suff[i + 1][e];
          if (ls == null) return;
          for (final w in lw) {
            for (final s in ls) {
              _insert(suff[i], q, _vAdd(w, s));
            }
          }
        });
      }
    }
    if (!_contains(suff[0][p], v)) return null;
    final kids = <MatchResult>[];
    var q = p;
    // The remainder after committing a child is the chosen SUFFIX value
    // (its interval is the union of the remaining children's edits);
    // interval union has no subtraction.
    var rem = v;
    for (var i = 0; i < kk; i++) {
      int? cbE;
      _V? cbW;
      _V? cbS;
      _cellC(subs[i], q).forEach((e, lw) {
        if (e > end) return;
        final ls = suff[i + 1][e];
        if (ls == null) return;
        for (final w in lw) {
          for (final s in ls) {
            if (_vEq(_vAdd(w, s), rem) && (cbE == null || e > cbE!)) {
              cbE = e;
              cbW = w;
              cbS = s;
            }
          }
        }
      });
      if (cbE == null) throw StateError('seq walk stuck: $c @$p');
      kids.add(_derive(subs[i], q, cbE!, cbW!));
      rem = cbS!;
      q = cbE!;
    }
    return Match(c, 0, 0, subClauseMatches: kids);
  }

  MatchResult? _deriveRep(Repetition c, int p, int end, _V v) {
    final item = c.subClause;
    if (end == p) {
      if (!c.requireOne && _vEq(v, _zero)) return Match(c, p, 0);
      if (c.requireOne) {
        if (v.$1 >= 1 && _contains(_cellC(item, p)[p], v)) {
          return Match(c, 0, 0, subClauseMatches: [_derive(item, p, p, v)]);
        }
      }
      return null;
    }
    // g[q] = Pareto set of ways to reach exactly end from q via advancing
    // items.
    final g = <int, List<_V>>{
      end: [_zero]
    };
    for (var q = end - 1; q >= p; q--) {
      _cellC(item, q).forEach((e, lw) {
        if (e <= q || e > end) return;
        final ls = g[e];
        if (ls == null) return;
        for (final w in lw) {
          for (final s in ls) {
            _insert(g, q, _vAdd(w, s));
          }
        }
      });
    }
    if (!_contains(g[p], v)) return null;
    final items = <MatchResult>[];
    var q = p;
    var rem = v;
    var guard = 0;
    while (q < end) {
      if (++guard > n + 8) throw StateError('rep walk stuck');
      int? cbE;
      _V? cbW;
      _V? cbS;
      _cellC(item, q).forEach((e, lw) {
        if (e <= q || e > end) return;
        final ls = g[e];
        if (ls == null) return;
        for (final w in lw) {
          for (final s in ls) {
            if (_vEq(_vAdd(w, s), rem) && (cbE == null || e > cbE!)) {
              cbE = e;
              cbW = w;
              cbS = s;
            }
          }
        }
      });
      if (cbE == null) throw StateError('rep walk no candidate');
      items.add(_derive(item, q, cbE!, cbW!));
      rem = cbS!;
      q = cbE!;
    }
    return Match(c, 0, 0, subClauseMatches: items);
  }
}
