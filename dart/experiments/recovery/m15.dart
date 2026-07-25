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
import 'dart:typed_data';

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

  // NO minimum-length function. Fabricating a whole subtree is not a move: it is
  // what the ordinary recursion DOES when each terminal along the way fabricates
  // its own single character. A 39-line minLen computation over Seq/First/
  // Repetition was only ever consulted at the terminal site, where after Str
  // desugaring the answer is always 1.

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
      // FAB: assert this terminal's one character with no evidence at all. It
      // advances nothing, so a composite clause fabricates a whole subtree by
      // fabricating each terminal in it -- no separate move, no minLen.
      _relax(out, pos, _M + _floor);
      return out;
    }

    // EVERY composite clause is the same machine (see _arcs).
    if (c is Seq || c is First || c is Optional || c is Repetition) {
      return _machine(c, pos, b);
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
  // THE GRAND SIMPLIFICATION: there is only ONE composite clause.
  //
  // Seq, First, Optional and Repetition differ only in the shape of a tiny
  // machine over "dot" states, and `_arcs` is that difference -- four lines of
  // topology instead of four relaxation loops. An arc is (subclause, nextDot);
  // a null subclause means ACCEPT here.
  //
  //   Seq        dot i -> [(sub_i, i+1)],  dot k = ACCEPT     (a chain)
  //   First      dot 0 -> [(alt, 1) ...],  dot 1 = ACCEPT     (parallel arcs)
  //   Optional   dot 0 -> [(sub, 1), ACCEPT]                  (skippable arc)
  //   Repetition dot 0/1 -> [(sub, 1)] + ACCEPT               (a self-loop)
  //
  // And the payoff is not just in the search: THE PATH TAKEN THROUGH THIS
  // MACHINE IS THE CHILD LIST OF THE RESULTING NODE. Seq's k children, First's
  // one chosen alternative, Optional's zero-or-one, Repetition's n iterations
  // are all just "the sub-matches along the accepting path", so a single walk
  // back over `pred` reconstructs all four. Both per-clause-type switches --
  // one in the search, one in the reconstruction -- collapse into this.
  /// Arcs depend on nothing but (clause, dot), so they are built once per clause.
  final Map<Clause, List<List<(Clause?, int)>>> _arcCache = {};

  List<(Clause?, int)> _arcs(Clause c, int dot) => _arcCache.putIfAbsent(
      c, () => [for (var d = 0; d < _dots(c); d++) _arcsOf(c, d)])[dot];

  List<(Clause?, int)> _arcsOf(Clause c, int dot) {
    if (c is Seq) {
      return dot < c.subClauses.length
          ? [(c.subClauses[dot], dot + 1)]
          : [(null, 0)];
    }
    if (c is First) {
      return dot == 0 ? [for (final a in c.subClauses) (a, 1)] : [(null, 0)];
    }
    if (c is Optional) {
      return dot == 0 ? [(c.subClause, 1), (null, 0)] : [(null, 0)];
    }
    c as Repetition;
    // A `+` may not accept before its first iteration; that is the whole of the
    // difference between `*` and `+`.
    if (dot == 0 && c.requireOne) return [(c.subClause, 1)];
    return [(c.subClause, 1), (null, 0)];
  }

  int _dots(Clause c) => c is Seq ? c.subClauses.length + 1 : 2;

  /// Does state `dot` do nothing but accept?
  bool _sink(Clause c, int dot) {
    final a = _arcs(c, dot);
    return a.length == 1 && a[0].$1 == null;
  }

  /// Relax the (dot, pos) states of `c`'s machine, starting at (0, `pos`) with
  /// Delta 0; returns min-Delta per accepting end.
  ///
  /// THE STATE KEY IS ITS OWN TOPOLOGICAL ORDER. Every arc either advances the
  /// dot or advances the position and never moves either backwards, so
  /// `dot * (_n + 2) + pos` strictly increases along every arc. Draining states
  /// in key order therefore finalises each one on its single expansion: no
  /// priority by cost, no fixpoint iteration, no round cap, and no
  /// no-progress guard -- a zero-width self-loop lands on the key just popped,
  /// where it can no longer improve anything, so it dies on the `cur <= tot`
  /// test that is already there.
  Map<int, int> _machine(Clause c, int pos, int b, [int dot0 = 0]) {
    // The state array is indexed by `dot * width + (p - pos)`, and THAT INDEX IS
    // ITS OWN TOPOLOGICAL ORDER: every arc advances the dot or the position and
    // never moves either backwards, so a single ascending sweep finalises each
    // state before it is read. No queue, no priority, no fixpoint iteration, no
    // round cap, no no-progress guard -- one `for` loop over an array.
    final width = _n - pos + 1;
    // Int64List, holding Delta + 1 so that the native zero fill means "unset".
    // A List<int?> here is a pointer array that must be null-filled on every
    // call, and this is the most-allocated object in the engine -- one per
    // composite clause per position -- so the typed array is worth the +1.
    final val = Int64List(_dots(c) * width);
    final out = <int, int>{};
    final limit = (b + 1) * _M; // regret is always < _M, so cost = d ~/ _M
    val[dot0 * width] = 1; // (dot0, pos) at Delta 0
    for (var st = dot0 * width; st < val.length; st++) {
      if (val[st] == 0) continue;
      final d = val[st] - 1;
      final dot = st ~/ width, p = pos + st % width;
      final rem = b - _cost(d);
      for (final (sub, to) in _arcs(c, dot)) {
        if (sub == null) {
          _relax(out, p, d);
          continue;
        }
        // Every arc may be preceded by a SPAN of j discarded characters. That
        // is the only place SPAN appears anywhere in the engine.
        for (var j = 0; j <= rem && p + j <= _n; j++) {
          final sp = j * _M + _lost(p, p + j);
          for (final f in _ends(sub, p + j, rem - j).entries) {
            final tot = d + sp + f.value;
            if (tot >= limit) continue; // == _cost(tot) > b, without the divide
            final k2 = to * width + f.key - pos;
            final cur = val[k2];
            if (cur != 0 && cur - 1 <= tot) continue;
            val[k2] = tot + 1;
          }
        }
      }
    }
    return out;
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
    if (c is FollowedBy || c is NotFollowedBy) return Match(c, pos, 0);

    // ONE walk back over the machine's predecessors reconstructs ALL FOUR
    // composite clause types, because the path through the machine is the child
    // list: Seq's k children, First's chosen alternative, Optional's
    // zero-or-one, Repetition's n iterations.
    final kids = _buildItem(c, 0, pos, end, cost, b);
    return kids.isEmpty
        ? Match(c, pos, 0)
        : Match(c, pos, end - pos, subClauseMatches: kids);
  }

  /// Walk the machine FORWARDS from (`c`, `dot`) at `pos`, choosing at each arc a
  /// head whose Delta plus the rest's Delta is exactly `cost`. The path taken is
  /// the child list, so this one descent reconstructs all four composite types.
  ///
  /// PREFER THE SHORTEST HEAD. Among decompositions that TIE on Delta, take the
  /// one whose head ends earliest (`..sort()`, ascending). That is the same
  /// smallest-extent principle the top-level lead/end split already uses -- text
  /// being discarded anyway should not be swallowed by a subtree -- and it is
  /// worth 6 shape points on its own. Anchoring the preference at the head is
  /// what a backward predecessor walk cannot express: walking back from the
  /// accepting state fixes the TAIL first, and by then the head's tie is already
  /// decided by whichever relaxation happened to land first.
  List<MatchResult> _buildItem(
      Clause c, int dot, int pos, int end, int cost, int b) {
    for (final (sub, to) in _arcs(c, dot)) {
      if (sub == null) {
        if (pos == end && cost == 0) return const [];
        continue;
      }
      for (var j = 0; j <= b && pos + j <= _n; j++) {
        final sp = j * _M + _lost(pos, pos + j);
        final cand = _ends(sub, pos + j, b - j);
        final ks = cand.keys.toList()..sort();
        for (final fk in ks) {
          final hv = cand[fk]!;
          final head = sp + hv;
          // The remainder's Delta is non-negative, so a head already past the
          // target cannot be part of any decomposition summing to it. This one
          // test skips the machine sweep below for most candidates.
          if (head > cost) continue;
          final restB = b - _cost(head);
          final rest = _sink(c, to)
              ? (fk == end ? 0 : null)
              : _machine(c, fk, restB, to)[end];
          if (rest == null || head + rest != cost) continue;
          final kids = <MatchResult>[];
          if (j > 0) {
            _span(pos, j);
            kids.add(SyntaxError(pos: pos, len: j));
          }
          kids.add(_build(sub, pos + j, fk, hv, b - j));
          if (!_sink(c, to)) {
            kids.addAll(_buildItem(c, to, fk, end, rest, restB));
          }
          return kids;
        }
      }
    }
    throw StateError('no arc of $c@$dot reaches $end at $cost');
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
    // `_floor` whether kept, discarded or substituted, and no repair fabricates
    // more than `maxCost` characters, so this bound is generous.
    _M = (2 * _n + maxCost + 2) * (_floor + 1);
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
