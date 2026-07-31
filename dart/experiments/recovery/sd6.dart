// SUPERDOT PROTOTYPE 2 -- demand-driven, budget-deepening, MEMOIZED.
//
// Prototype 1 was a continuation-passing DFS: it hit dot's cost on all 519
// distance-1 mutants 64x faster, then failed outright on the high-cost tail,
// because a continuation-dependent search cannot memoize its failures and so
// re-derives the same subproblem exponentially often.
//
// The fix keeps the one property that made it fast and drops the one that made it
// explode. Instead of "try to match c at pos and call k", the primitive becomes
//
//     ends(c, pos, b) = { end -> minimum cost <= b of matching c from pos to end }
//
// which depends on nothing but its three arguments, so it memoizes. The pruning
// survives intact:
//
//     b == 0  ==>  ends is exactly one memoized PURE-PARSER call
//
// so every subtree that does not contain an edit costs O(1), and only the spine
// leading to a real edit is ever expanded. What is deliberately absent, compared
// with dot: no priority queue, no Pareto frontier, no regret component, no big-M
// scaling constant, no lexicographic value tuple, no backpointer tag dispatch.
// Minimality is not an invariant to be proved about an ordering -- it is the
// definition of the outer loop, which returns the first budget that works.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/clause.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/terminals.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;
import 'dart:math' as math;

// ERROR RECOVERY START

/// A multi-character literal desugared into a sequence of single-character
/// literals. Repair then special-cases literals nowhere: "rue" -> "true" is a
/// fabricated 't' inside an ordinary Seq, handled by the same machinery that
/// inserts, discards and substitutes everywhere else. Desugaring is also what
/// keeps regret non-negative, since a one-character literal names itself in zero
/// bits, which is by definition the narrowest the grammar can name it.
class _StrSeq extends Seq {
  final Str orig;
  _StrSeq(this.orig)
      : super([for (var i = 0; i < orig.text.length; i++) Str(orig.text[i])]);
  @override
  String toString() => orig.toString();
}

int _clsBits(int size) =>
    size <= 1 ? 0 : (math.log(size) / math.ln2 * 1000).round();

int _csSize(CharSet cs) {
  var k = 0;
  for (final (lo, hi) in cs.ranges) {
    k += hi - lo + 1;
  }
  return cs.inverted ? 0x110000 - k : k;
}

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

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;

  SuperDot3({required this.rules, required this.topRuleName});

  /// Rule names with the transparent-rule '~' prefix stripped, matching what
  /// `Parser` does to its own copy -- a `Ref` names the stripped form.
  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  final Map<Str, Clause> _strSubst = {};

  /// The engine's only grammar rewrite: multi-character literals become
  /// sequences of single-character ones.
  Clause _ds(Clause c) => (c is Str && c.text.length > 1)
      ? _strSubst.putIfAbsent(c, () => _StrSeq(c))
      : c;

  /// THE OBJECTIVE, AS ONE INTEGER: `Delta = cost * M + regret`.
  ///
  /// `cost` counts edits; `regret` is resolution regret in millibits -- how far
  /// each character's treatment deviates from the narrowest name the grammar
  /// could have given it. Regret on a finite input is bounded, so one `M` above
  /// that bound makes a single integer induce the lexicographic order
  /// `(cost, regret)` exactly: a regret difference can never outbid an edit.
  /// Because the maps in this engine already hold integers, the entire second
  /// objective dimension costs no data structure whatsoever -- no Pareto
  /// frontier, no domination test, no tuple comparator, no tie-order table.
  late int _M;
  late List<int> _h; // h(p)
  late int _floor; // width of the whole code space, in millibits

  int _cost(int d) => d ~/ _M;

  late Parser _p;
  late String _in;
  late int _n;
  final Map<Clause, int> _cid = {};
  final Map<Clause, int> _minLen = {};
  final Map<int, Map<int, int>> _memo = {};
  final Map<int, int> _memoB = {}; // budget each memo entry was computed at
  MatchResult? _clean; // set iff the input parses cleanly (cost 0)

  int lastCost = -1;
  int lastRegret = -1;
  int lastSteps = -1;
  int _lastDelta = -1;
  int _steps = 0;

  int _id(Clause c) => _cid.putIfAbsent(c, () => _cid.length);

  /// Every terminal clause reachable in the grammar, literals desugared.
  /// Used only to compute h(p).
  late final List<Clause> _terminals = () {
    final seen = <Clause>{};
    final out = <Clause>[];
    void collect(Clause raw) {
      final c = _ds(raw);
      if (!seen.add(c)) return;
      if (c is Ref) {
        collect(_rules[c.ruleName]!);
      } else if (c is HasOneSubClause) {
        collect(c.subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(collect);
      } else {
        out.add(c);
      }
    }

    collect(_rules[topRuleName]!);
    return out;
  }();

  /// h(p): the width in millibits of the narrowest class or literal in the
  /// grammar that can name input[p]. A character the grammar names exactly costs
  /// 0 bits; one reachable only through a wide class costs that class's width;
  /// one the grammar cannot name at all costs the whole code space.
  void _buildH() {
    _floor = _clsBits(0x110000);
    _h = List<int>.filled(_n, 0);
    for (var p = 0; p < _n; p++) {
      final ch = _in.codeUnitAt(p);
      var best = _floor;
      for (final c in _terminals) {
        int? w;
        if (c is Str) {
          if (c.text.codeUnitAt(0) == ch) w = 0;
        } else if (c is Char) {
          if (c.char.codeUnitAt(0) == ch) w = 0;
        } else if (c is CharSet) {
          if (_csMatch(c, ch)) w = _clsBits(_csSize(c));
        } else if (c is AnyChar) {
          w = _floor;
        }
        if (w != null && w < best) best = w;
        if (best == 0) break;
      }
      _h[p] = best;
    }
    _hSum = List<int>.filled(_n + 1, 0);
    for (var p = 0; p < _n; p++) {
      _hSum[p + 1] = _hSum[p] + _h[p];
    }
  }

  /// Regret of DISCARDING [from, to): every bit the grammar could have accounted
  /// for goes unaccounted.
  ///
  /// Charging the full code-space width here instead of h(q) was tried and is
  /// strictly worse (shape 510 vs 512): it makes all spans of equal length tie,
  /// destroying the h(q) discrimination that decides WHERE a span goes.
  int _lost(int from, int to) => _hSum[to] - _hSum[from];
  late List<int> _hSum; // prefix sums of _h: _lost is in the hottest loop

  /// Regret of the unique clean derivation the pure parser built: a kept
  /// character matched by a class of width `b` deviates by `b - h(p)`. There is
  /// no choice to make inside a clean subtree -- PEG's derivation is
  /// deterministic -- but the value still differs between two clean subtrees
  /// ending at the same position, which is exactly when it decides a tie.
  final Map<MatchResult, int> _cleanRegret = {};
  int _regretOf(MatchResult m) {
    final hit = _cleanRegret[m];
    if (hit != null) return hit;
    var r = 0;
    if (m.subClauseMatches.isEmpty) {
      final c = m.clause;
      if (m.len > 0) {
        final b = c is CharSet
            ? _clsBits(_csSize(c))
            : c is AnyChar
                ? _floor
                : 0;
        for (var q = m.pos; q < m.pos + m.len; q++) {
          r += b - _h[q];
        }
      }
    } else {
      for (final k in m.subClauseMatches) {
        r += _regretOf(k);
      }
    }
    _cleanRegret[m] = r;
    return r;
  }

  /// Shortest number of characters `c` can match: the price of fabricating it out
  /// of nothing. `-1` = cannot be fabricated at any finite cost.
  int _ml(Clause c) {
    final hit = _minLen[c];
    if (hit != null) return hit;
    _minLen[c] = 1 << 20; // cycle guard while computing
    int m;
    if (c is Str) {
      m = c.text.length;
    } else if (c is Char) {
      m = c.char.length;
    } else if (c is CharSet || c is AnyChar) {
      m = 1;
    } else if (c is Nothing) {
      m = 0;
    } else if (c is Ref) {
      m = _ml(_rules[c.ruleName]!);
    } else if (c is Seq) {
      m = 0;
      for (final s in c.subClauses) {
        final x = _ml(s);
        if (x < 0) {
          m = -1;
          break;
        }
        m += x;
      }
    } else if (c is First) {
      m = -1;
      for (final s in c.subClauses) {
        final x = _ml(s);
        if (x >= 0 && (m < 0 || x < m)) m = x;
      }
    } else if (c is Repetition) {
      m = c.requireOne ? _ml(c.subClause) : 0;
    } else {
      m = 0; // Optional, FollowedBy, NotFollowedBy all match empty
    }
    _minLen[c] = m;
    return m;
  }

  static void _relax(Map<int, int> m, int end, int cost) {
    final cur = m[end];
    if (cur == null || cost < cur) m[end] = cost;
  }

  /// Every end position reachable by matching `c` at `pos` for at most `b` edits,
  /// with the minimum cost of each. Memoized on exactly its arguments.
  Map<int, int> _ends(Clause c, int pos, int b) {
    if (pos > _n || b < 0) return const {};
    // THE BUDGET IS NOT PART OF THE KEY. A result computed at budget B >= b
    // already holds, for every end, the MINIMUM-cost derivation of that end --
    // because Delta orders cost above regret, so min-Delta implies min-cost. An
    // end whose stored Delta exceeds b is therefore unreachable at b, and one
    // whose Delta fits is reached at exactly that Delta. Filtering is exact,
    // so the budget only ever needed to be a filter on the answer.
    final key = _id(c) * (_n + 2) + pos;
    final have = _memoB[key];
    if (have == b) return _memo[key]!; // computed at exactly this budget
    if (have != null && have > b) return _filter(_memo[key]!, b);
    _memoB[key] = b; // left-recursion cut while computing: b never grows
    _memo[key] = const {}; // downwards, so a re-entrant call always hits this
    final r = _compute(c, pos, b);
    _memoB[key] = b;
    _memo[key] = r;
    return r;
  }

  Map<int, int> _filter(Map<int, int> m, int b) {
    for (final d in m.values) {
      if (_cost(d) > b) {
        final out = <int, int>{};
        m.forEach((e, d) {
          if (_cost(d) <= b) out[e] = d;
        });
        return out;
      }
    }
    return m;
  }

  Map<int, int> _ends0(Clause c, int pos) {
    // BUDGET EXHAUSTED: the whole remaining subtree is one memoized pure-parser
    // call. This single line is why the engine is fast.
    final m = pos > _n ? mismatch : c.match(_p, pos);
    return m.isMismatch ? const {} : {pos + m.len: _regretOf(m)};
  }

  Map<int, int> _compute(Clause c, int pos, int b) {
    _steps++;
    if (b == 0) return _ends0(c, pos);

    if (c is Ref) return _ends(_rules[c.ruleName]!, pos, b);
    if (c is Str && c.text.length > 1) return _ends(_ds(c), pos, b);

    if (c is Terminal) {
      final out = <int, int>{};
      final m = c.match(_p, pos);
      if (!m.isMismatch) {
        out[pos + m.len] = _regretOf(m); // MATCH: regret only, no edit
      } else if (pos < _n) {
        out[pos + 1] = _M + _h[pos]; // SUB: one edit, h(p) bits destroyed
      }
      final ml = _ml(c);
      // FAB: ml edits, and ml characters asserted with no evidence at all.
      if (ml > 0 && ml <= b) _relax(out, pos, ml * (_M + _floor));
      return out;
    }

    if (c is First) {
      final out = <int, int>{};
      for (final alt in c.subClauses) {
        for (final e in _ends(alt, pos, b).entries) {
          _relax(out, e.key, e.value);
        }
      }
      return out;
    }

    if (c is Seq) {
      var cur = <int, int>{pos: 0};
      for (final sub in c.subClauses) {
        final next = <int, int>{};
        for (final e in cur.entries) {
          final p = e.key, cost = e.value;
          final rem = b - _cost(cost);
          // SPAN j input characters as unparseable before matching `sub`.
          for (var j = 0; j <= rem && p + j <= _n; j++) {
            final sp = j * _M + _lost(p, p + j);
            for (final f in _ends(sub, p + j, rem - j).entries) {
              _relax(next, f.key, cost + sp + f.value);
            }
          }
        }
        cur = next;
        if (cur.isEmpty) return const {};
      }
      return cur;
    }

    if (c is Optional) {
      final out = <int, int>{pos: 0};
      for (final e in _ends(c.subClause, pos, b).entries) {
        _relax(out, e.key, e.value);
      }
      return out;
    }

    if (c is Repetition) {
      // Relax until fixpoint: each round appends one more iteration of the
      // subclause. Bounded because every appended iteration strictly increases
      // the end position or the cost, and both are bounded.
      final reach = <int, int>{pos: 0};
      var frontier = <int, int>{pos: 0};
      var rounds = 0;
      while (frontier.isNotEmpty) {
        if (++rounds > _n + b + 2) break;
        final nf = <int, int>{};
        for (final e in frontier.entries) {
          final p = e.key, cost = e.value;
          final rem = b - _cost(cost);
          for (var j = 0; j <= rem && p + j <= _n; j++) {
            final sp = j * _M + _lost(p, p + j);
            for (final f in _ends(c.subClause, p + j, rem - j).entries) {
              final tot = cost + sp + f.value;
              if (f.key == p && tot == cost) continue; // no progress
              if (_cost(tot) > b) continue;
              final cur = reach[f.key];
              if (cur == null || tot < cur) {
                reach[f.key] = tot;
                _relax(nf, f.key, tot);
              }
            }
          }
        }
        frontier = nf;
      }
      if (c.requireOne) reach.remove(pos);
      if (c.requireOne) {
        // An empty match is only allowed if the subclause itself matched empty
        // at zero cost, which the loop above already recorded elsewhere.
        return reach;
      }
      _relax(reach, pos, 0);
      return reach;
    }

    // Lookahead is evaluated at cost 0 only: editing the input to satisfy your
    // own assertion about the input is not a repair.
    if (c is FollowedBy) {
      return c.subClause.match(_p, pos).isMismatch ? const {} : {pos: 0};
    }
    if (c is NotFollowedBy) {
      return c.subClause.match(_p, pos).isMismatch ? {pos: 0} : const {};
    }
    throw StateError('unhandled clause ${c.runtimeType}');
  }

  // ---------------------------------------------------------------------------
  // Reconstruction.
  //
  // The search above answers only "what does the cheapest repair COST". The tree
  // is recovered by a second pass that replays the same recurrence and, at each
  // node, takes any decomposition whose parts sum to the cost already known to be
  // minimal. Splitting it this way is what removes dot's entire second objective
  // dimension: dot had to carry regret through the priority order because its
  // search and its choice of witness were the same traversal. Here they are two
  // traversals, so the witness can be chosen by plain preference order --
  // MATCH before SUB before FAB before SPAN, earlier alternative before later --
  // with no value tuple, no domination test and no tuning constant.

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  void _span(int pos, int len) {
    if (len > 0) _spans.add(SyntaxError(pos: pos, len: len));
  }

  /// Build a tree for `c` matching `pos`..`end` at exactly `cost`, given that
  /// `_ends(c, pos, b)[end] == cost`.
  MatchResult _build(Clause c, int pos, int end, int cost, int b) {
    // A clean subtree is whatever the PURE parser built -- no reconstruction, no
    // approximation, the real tree.
    if (cost == 0) {
      final m = pos > _n ? mismatch : c.match(_p, pos);
      if (!m.isMismatch && pos + m.len == end) return m;
    }
    if (c is Ref) {
      final child = _build(_rules[c.ruleName]!, pos, end, cost, b);
      return Match(c, pos, end - pos, subClauseMatches: [child]);
    }
    if (c is Str && c.text.length > 1) return _build(_ds(c), pos, end, cost, b);
    if (c is Terminal) {
      if (end == pos && _cost(cost) > 0) {
        _missing.add(MissingObligation(c, pos)); // FAB
      } else if (_cost(cost) > 0) {
        _span(pos, end - pos); // SUB: the character was overwritten
      }
      return Match(c, pos, end - pos);
    }
    if (c is First) {
      for (final alt in c.subClauses) {
        if (_ends(alt, pos, b)[end] == cost) {
          return Match(c, pos, end - pos,
              subClauseMatches: [_build(alt, pos, end, cost, b)]);
        }
      }
      throw StateError('First: no alternative achieves cost $cost');
    }
    if (c is Optional) {
      if (_ends(c.subClause, pos, b)[end] == cost) {
        return Match(c, pos, end - pos,
            subClauseMatches: [_build(c.subClause, pos, end, cost, b)]);
      }
      return Match(c, pos, 0);
    }
    if (c is FollowedBy || c is NotFollowedBy) return Match(c, pos, 0);

    if (c is Seq) {
      // Replay the forward sweep, remembering one predecessor per reached end.
      final layers = <Map<int, int>>[
        {pos: 0}
      ];
      final preds = <Map<int, (int, int, int)>>[]; // end -> (start, span, subCost)
      for (final sub in c.subClauses) {
        final next = <int, int>{};
        final pred = <int, (int, int, int)>{};
        for (final e in layers.last.entries) {
          final p = e.key, before = e.value;
          final rem = b - _cost(before);
          for (var j = 0; j <= rem && p + j <= _n; j++) {
            final sp = j * _M + _lost(p, p + j);
            for (final f in _ends(sub, p + j, rem - j).entries) {
              final tot = before + sp + f.value;
              final cur = next[f.key];
              if (cur == null || tot < cur) {
                next[f.key] = tot;
                pred[f.key] = (p, j, f.value);
              }
            }
          }
        }
        layers.add(next);
        preds.add(pred);
      }
      // Walk back from (end, cost) to recover the element boundaries.
      final parts = <MatchResult>[];
      var e = end;
      for (var i = c.subClauses.length - 1; i >= 0; i--) {
        final (start, j, subCost) = preds[i][e]!;
        final before = layers[i][start]!;
        final child =
            _build(c.subClauses[i], start + j, e, subCost, b - _cost(before) - j);
        parts.add(child);
        if (j > 0) {
          _span(start, j);
          parts.add(SyntaxError(pos: start, len: j));
        }
        e = start;
      }
      return Match(c, pos, end - pos,
          subClauseMatches: parts.reversed.toList());
    }

    if (c is Repetition) {
      // Same replay, on the repetition's relaxation loop.
      final reach = <int, int>{pos: 0};
      final pred = <int, (int, int, int)>{};
      var frontier = <int, int>{pos: 0};
      var rounds = 0;
      while (frontier.isNotEmpty) {
        if (++rounds > _n + b + 2) break;
        final nf = <int, int>{};
        for (final entry in frontier.entries) {
          final p = entry.key, before = entry.value;
          final rem = b - _cost(before);
          for (var j = 0; j <= rem && p + j <= _n; j++) {
            final sp = j * _M + _lost(p, p + j);
            for (final f in _ends(c.subClause, p + j, rem - j).entries) {
              final tot = before + sp + f.value;
              if (f.key == p && tot == before) continue;
              if (_cost(tot) > b) continue;
              final cur = reach[f.key];
              if (cur == null || tot < cur) {
                reach[f.key] = tot;
                pred[f.key] = (p, j, f.value);
                nf[f.key] = tot;
              }
            }
          }
        }
        frontier = nf;
      }
      final parts = <MatchResult>[];
      var e = end;
      while (!(e == pos && (reach[pos] ?? 0) == cost && pred[e] == null)) {
        final pr = pred[e];
        if (pr == null) break;
        final (start, j, subCost) = pr;
        final before = reach[start] ?? 0;
        parts.add(
            _build(c.subClause, start + j, e, subCost, b - _cost(before) - j));
        if (j > 0) {
          _span(start, j);
          parts.add(SyntaxError(pos: start, len: j));
        }
        if (start == e) break; // defensive: no progress
        e = start;
      }
      final kids = parts.reversed.toList();
      return kids.isEmpty
          ? Match(c, pos, 0)
          : Match(c, pos, end - pos, subClauseMatches: kids);
    }
    throw StateError('unhandled clause ${c.runtimeType}');
  }

  /// Full recovery: minimum-cost repair plus a full-coverage tree over the
  /// original input.
  SkipResult recover(String input, {int maxCost = 40}) {
    final cost = recoverCost(input, maxCost: maxCost);
    _spans.clear();
    _missing.clear();
    if (cost == 0) return SkipResult(_clean!, const [], const [], 0, false);
    if (cost < 0) {
      final e = SyntaxError(pos: 0, len: _n);
      return SkipResult(e, [e], const [], 1, true);
    }
    final top = _rules[topRuleName]!;
    // Recover the (lead, end) split that achieved the minimum.
    // Among the repairs that tie on Delta, take the one whose tree extent is
    // smallest: text we are discarding anyway should stay OUTSIDE the tree
    // rather than stretch a rule node over it. Delta is unchanged either way,
    // so this cannot move the cost -- it only decides where the span sits.
    var bestLead = -1, bestEnd = -1, bestInner = -1;
    for (var lead = 0; lead <= cost && lead <= _n; lead++) {
      final pre = lead * _M + _lost(0, lead);
      for (final e in _ends(top, lead, cost - lead).entries) {
        if (e.key > _n) continue;
        if (pre + e.value + (_n - e.key) * _M + _lost(e.key, _n) != _lastDelta) {
          continue;
        }
        if (bestEnd < 0 || e.key < bestEnd) {
          bestLead = lead;
          bestEnd = e.key;
          bestInner = e.value;
        }
      }
    }
    final kids = <MatchResult>[];
    if (bestLead > 0) {
      _span(0, bestLead);
      kids.add(SyntaxError(pos: 0, len: bestLead));
    }
    kids.add(_build(top, bestLead, bestEnd, bestInner, cost - bestLead));
    if (bestEnd < _n) {
      _span(bestEnd, _n - bestEnd);
      kids.add(SyntaxError(pos: bestEnd, len: _n - bestEnd));
    }
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(
        kids.length == 1 ? kids.first : Match(null, 0, _n, subClauseMatches: kids),
        List.of(_spans),
        List.of(_missing),
        _spans.length + _missing.length,
        false);
  }

  /// Iterative deepening on the edit budget. The first budget at which the whole
  /// input can be consumed IS the minimum cost -- there is no ordering argument
  /// to make, and no tie-breaking parameter to choose.
  int recoverCost(String input, {int maxCost = 40}) {
    _in = input;
    _n = input.length;
    // A CORRECT DOCUMENT COSTS EXACTLY ONE PARSE. At b = 0 the filter admits
    // precisely the pure parser's derivation, so if that derivation already
    // consumes the input there is nothing to search and nothing to compare:
    // no h(p) table (O(n.|G|)), no M, no memo, no regret walk. Recovery is
    // then provably free on input that does not need it.
    _clean = null;
    final pure = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final res = pure.parse();
    if (!res.hasSyntaxErrors) {
      _clean = res.root;
      _lastDelta = 0;
      lastCost = 0;
      lastRegret = 0;
      lastSteps = 0;
      return 0;
    }
    _buildH();
    // M must exceed every achievable regret. Every character contributes at most
    // `_floor` whether it is kept, discarded or substituted, and a fabrication
    // asserts at most `minLen(top)` characters, so this bound is generous.
    _M = (2 * _n + _ml(_rules[topRuleName]!).clamp(0, 1 << 16) + 2) * (_floor + 1);
    final top = _rules[topRuleName]!;
    _steps = 0;
    _lastDelta = -1;
    // ONE memo for the whole deepening, not one per round. Since the budget is
    // only a filter, a later round never invalidates an earlier round's answer:
    // it can only ask for MORE, which recomputes just that entry. Round k
    // therefore does not re-derive rounds 0..k-1.
    _p = Parser(rules: rules, topRuleName: topRuleName, input: input);
    _memo.clear();
    _memoB.clear();
    _cleanRegret.clear();
    for (var k = 0; k <= maxCost; k++) {
      var best = -1;
      // Leading span, then the top rule, then trailing span.
      for (var lead = 0; lead <= k && lead <= _n; lead++) {
        final pre = lead * _M + _lost(0, lead);
        for (final e in _ends(top, lead, k - lead).entries) {
          if (e.key > _n) continue;
          final tot = pre + e.value + (_n - e.key) * _M + _lost(e.key, _n);
          if (_cost(tot) <= k && (best < 0 || tot < best)) best = tot;
        }
      }
      if (best >= 0) {
        _lastDelta = best;
        lastCost = _cost(best);
        lastRegret = best - lastCost * _M;
        assert(lastRegret < _M, 'regret $lastRegret reached M $_M');
        lastSteps = _steps;
        return lastCost;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}
// ERROR RECOVERY END
