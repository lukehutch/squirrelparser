// m18 -- the axiomatic engine.
//
// Derived from four axioms and nothing else.
//
// A1  A repair of input s under grammar G is a string s' in L(G) together with an
//     alignment of s to s'. There are exactly three edit primitives, and they are
//     Levenshtein's, lifted from strings to a language:
//       SUB   a terminal consumes a character it does not accept   (cost 1)
//       FAB   a terminal consumes nothing                          (cost 1, an
//             insertion into s)
//       SKIP  a character is consumed by no terminal               (cost 1, a
//             deletion from s)
//     and one non-edit: MATCH, a terminal consuming what is there  (cost 0).
//
// A2  Among minimum-cost repairs, prefer the one that commits the least
//     unjustified information: regret = sum over kept characters of w(class)
//     plus twice the sum over skipped characters of h(char), where w is the
//     log2-width of the accepting class and h(c) is the narrowest class in G
//     that accepts c. The factor 2 is derived, not tuned: see LESSONS_LEARNED.
//
// A3  Delta = cost * M + regret with M above any achievable regret, so ordering
//     by the single integer Delta orders cost first and min-Delta-per-end is
//     exactly min-cost. The budget is then a FILTER on that integer, not a memo
//     key, so one memo serves every iterative-deepening round.
//
// A4  A gap is by definition text BETWEEN two consumed regions, and only a
//     sequence has a "between". The region separating two adjacent consuming
//     leaves attaches at their lowest common ancestor, which is always a Seq or a
//     Repetition -- a First has no two consecutive children. So every gap has a
//     UNIQUE canonical attachment point, and First / Optional / Ref / predicates
//     need no recovery logic whatsoever: a gap before a chosen alternative is a
//     gap before that alternative's first element, which attaches further up.
//
// What A4 buys, measured against m16: the dot-state array, the ascending sweep,
// the arcs table, and _dots/_to/_accepts/_sink all disappear. What is left is one
// recurrence with a skip self-edge, and the recursion itself is the dot.
//
// What A1 buys: SKIP is a UNIT edge. A span of j characters costs
// j*M + 2*sum(h) which is exactly j unit steps, so the loop over span lengths
// that both m15 and m16 carry is not a primitive -- it is a hand-unrolled path.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

// ERROR RECOVERY START

const _floor = 20087;

int _width(Clause? c) {
  if (c is AnyChar) return _floor;
  if (c is! CharSet) return 0;
  var n = 0;
  for (final (lo, hi) in c.ranges) n += hi - lo + 1;
  n = c.inverted ? 0x110000 - n : n;
  return n <= 1 ? 0 : (math.log(n) / math.ln2 * 1000).round();
}

bool _has(CharSet c, int ch) {
  var yes = false;
  for (final (lo, hi) in c.ranges) {
    if (ch >= lo && ch <= hi) {
      yes = true;
      break;
    }
  }
  return c.inverted ? !yes : yes;
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };
  final Map<Str, Clause> _strings = {};
  Clause _desugar(Clause c) => c is Str && c.text.length > 1
      ? _strings.putIfAbsent(
          c, () => Seq([for (final x in c.text.split('')) Str(x)]))
      : c;

  late final List<Clause> _terminals = () {
    final seen = <Clause>{}, out = <Clause>[];
    void visit(Clause raw) {
      final c = _desugar(raw);
      if (!seen.add(c)) return;
      if (c is Ref) {
        visit(_rules[c.ruleName]!);
      } else if (c is HasOneSubClause) {
        visit(c.subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(visit);
      } else if (c is Terminal && c is! Nothing) {
        out.add(c);
      }
    }
    visit(_rules[topRuleName]!);
    return out;
  }();

  late Parser _parser;
  late String _input;
  late int _n, _M, _shift;
  late List<int> _H;
  final Map<int, int> _charH = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _scores = {};
  final Map<int, Map<int, int>> _memo = {};
  final Map<int, int> _memoBudget = {};
  MatchResult? _clean;
  int _steps = 0, _bestInner = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;

  /// THE GOAL. `Seq([top, Nothing])` -- the top rule, then the empty match. A4
  /// says skip is reachable wherever an element still follows, so at dot 0 the
  /// skip edge is the leading garbage and at dot 1 it is the trailing garbage.
  /// Both fall out of the universal rule, which is why there is no bespoke
  /// lead/trail arithmetic anywhere in this engine; and the shortest-head
  /// preference applied to dot 0 IS the smallest-extent tie-break, because the
  /// head at dot 0 is the top rule itself.
  late final Clause _goal = Seq([_rules[topRuleName]!, const Nothing()]);

  int _cost(int d) => d >> _shift;
  int _lost(int a, int z) => _H[z] - _H[a];
  int _w(Clause c) => _widths.putIfAbsent(c, () => _width(c));

  /// Memo identity. A Seq needs one slot per dot and a Repetition two, because
  /// the recursion carries the dot; everything else needs one. Allocating a
  /// BLOCK per clause is what lets the item (clause, dot) be a memo key without
  /// a wrapper class -- the whole cost of making the dot first-class.
  final Map<Clause, int> _bases = {};
  int _nextBase = 0;
  int _base(Clause c) => _bases.putIfAbsent(c, () {
        final b = _nextBase;
        _nextBase += c is Seq
            ? c.subClauses.length + 1
            : c is Repetition
                ? 2
                : 1;
        return b;
      });

  void _buildH() {
    _H = [0];
    for (var p = 0; p < _n; p++) {
      final ch = _input.codeUnitAt(p);
      final h = _charH.putIfAbsent(ch, () {
        var best = _floor;
        for (final c in _terminals) {
          final hit = c is Str
              ? c.text.codeUnitAt(0) == ch
              : c is Char
                  ? c.char.codeUnitAt(0) == ch
                  : c is CharSet
                      ? _has(c, ch)
                      : true;
          if (hit) best = math.min(best, _w(c));
          if (best == 0) break;
        }
        return best;
      });
      _H.add(_H.last + h);
    }
  }

  /// Regret of a clean subtree. Absolute pricing (A2) makes this a closed form:
  /// a kept leaf costs w(class) * len, one multiply, with no per-character loop
  /// and no per-position array.
  int _score(MatchResult m) {
    final old = _scores[m];
    if (old != null) return old;
    final score = m.subClauseMatches.isEmpty
        ? _w(m.clause!) * m.len
        : m.subClauseMatches.fold(0, (v, x) => v + _score(x));
    return _scores[m] = score;
  }

  static void _put(Map<int, int> out, int key, int value) {
    final old = out[key];
    if (old == null || value < old) out[key] = value;
  }

  Map<int, int> _filter(Map<int, int> source, int b) {
    final limit = (b + 1) * _M;
    for (final d in source.values) {
      if (d >= limit) {
        return {
          for (final e in source.entries)
            if (e.value < limit) e.key: e.value,
        };
      }
    }
    return source;
  }

  /// A5  LEFT RECURSION IS NOT A RECOVERY PROBLEM. The parser already solves it,
  ///     in `MemoEntry.match`, by seeding a re-entered (rule, pos) with a mismatch
  ///     and then re-matching the ancestral frame while the result keeps growing.
  ///     Recovery is the same recurrence over a wider value -- a map from end
  ///     position to minimum Delta instead of a single match -- so it inherits
  ///     left recursion by adopting the parser's memo rule verbatim, field for
  ///     field. There is no second mechanism, and no recovery-specific reasoning
  ///     about cycles anywhere in this file.
  ///
  ///     The fields below are `MemoEntry.inRecPath`, `MemoEntry.foundLeftRec` and
  ///     `MemoEntry.memoVersion`; `_verAtPos` is `Parser.memoVersion`.
  final Set<int> _inPath = {};
  final Set<int> _foundLR = {};
  final Map<int, int> _memoVer = {};
  late List<int> _verAtPos;

  /// The fixed-point test. The parser's is "the match did not get longer"; over a
  /// map of ends the same test is "no end is new and no Delta got smaller". Ends
  /// lie in [0, n] and Deltas are bounded non-negative integers, so the chain
  /// ascends only finitely often and the expansion loop terminates.
  static bool _improves(Map<int, int> fresh, Map<int, int> old) {
    for (final e in fresh.entries) {
      final o = old[e.key];
      if (o == null || e.value < o) return true;
    }
    return false;
  }

  /// Every end position reachable from `pos` by matching (`c`, `dot`), each
  /// mapped to its minimum Delta, given that at most `b` edits may be spent.
  Map<int, int> _ends(Clause c, int dot, int pos, int b) {
    if (pos > _n || b < 0) return const {};
    final key = (_base(c) + dot) * (_n + 2) + pos;
    final have = _memoBudget[key];
    if (_inPath.contains(key)) {
      // This (item, pos) is already on the recursion path. If it has no value
      // yet, this is the fixed point of a left recursive cycle: seed it with the
      // empty set -- the recovery analogue of the parser's `mismatch` -- and
      // signal the ancestral frame to expand. Either way a frame inside a cycle
      // reports the best known value and never recomputes, which is what makes
      // the recursion finite.
      if (have == null) {
        _foundLR.add(key);
        _memoBudget[key] = b;
        _memoVer[key] = _verAtPos[pos];
        return _memo[key] = const {};
      }
      return have > b ? _filter(_memo[key]!, b) : _memo[key]!;
    }
    if (have != null && _memoVer[key] == _verAtPos[pos]) {
      if (have == b) return _memo[key]!;
      if (have > b) return _filter(_memo[key]!, b);
    }
    _inPath.add(key);
    Map<int, int>? best;
    while (true) {
      final fresh = _compute(c, dot, pos, b);
      if (best != null && !_improves(fresh, best)) break;
      best = _memo[key] = fresh;
      _memoBudget[key] = b;
      if (!_foundLR.contains(key)) break;
      // Expand the cycle so the value just found can become a sub-derivation of
      // a better one, invalidating memos at this position only -- the parser's
      // `memoVersion = ++parser.memoVersion[pos]`, verbatim.
      _memoVer[key] = ++_verAtPos[pos];
    }
    _inPath.remove(key);
    _memoVer[key] = _verAtPos[pos];
    return _memo[key]!;
  }

  Map<int, int> _compute(Clause c, int dot, int pos, int b) {
    _steps++;
    // COST-0 FAST PATH. With no edits to spend the answer is exactly what the
    // pure parser says, so a clean subtree costs one memoised oracle call. Only
    // valid at dot 0: the oracle can match a clause, not a clause's tail.
    if (b == 0 && dot == 0) {
      final m = pos > _n ? mismatch : c.match(_parser, pos);
      return m.isMismatch ? const {} : {pos + m.len: _score(m)};
    }
    if (c is Ref) return _ends(_rules[c.ruleName]!, 0, pos, b);
    if (c is Str && c.text.length > 1) return _ends(_desugar(c), 0, pos, b);
    if (c is Terminal) {
      // The three terminal moves of A1, and the only place cost is created
      // other than SKIP.
      final out = <int, int>{};
      final m = c.match(_parser, pos);
      if (!m.isMismatch) out[pos + m.len] = _score(m); // MATCH
      if (m.isMismatch && pos < _n) {
        out[pos + 1] = _M + 2 * _lost(pos, pos + 1); // SUB
      }
      if (c is! Nothing) _put(out, pos, _M + _floor); // FAB
      return out;
    }
    // A4: the pure unions. No spans, no dots, no recovery logic at all -- an
    // Optional is a First whose last alternative is the empty match.
    if (c is First || c is Optional) {
      final out = c is Optional ? {pos: 0} : <int, int>{};
      for (final sub in _alts(c)) {
        for (final e in _ends(sub, 0, pos, b).entries) {
          _put(out, e.key, e.value);
        }
      }
      return out;
    }
    if (c is Seq || c is Repetition) return _chain(c, dot, pos, b);
    return (c is FollowedBy
                ? !c.subClause.match(_parser, pos).isMismatch
                : c is NotFollowedBy &&
                    c.subClause.match(_parser, pos).isMismatch)
        ? {pos: 0}
        : const {};
  }

  // The sequencing forms, and the ONLY forms that carry recovery logic (A4).
  // Three one-line accessors are the whole difference between a chain and a
  // loop: Seq advances its dot and finishes at the end of its element list;
  // Repetition returns to dot 1 forever and may finish immediately unless it
  // requires one iteration.
  List<Clause> _alts(Clause c) =>
      c is First ? c.subClauses : [(c as HasOneSubClause).subClause];

  Clause _elem(Clause c, int dot) =>
      c is Seq ? c.subClauses[dot] : (c as HasOneSubClause).subClause;
  int _after(Clause c, int dot) => c is Seq ? dot + 1 : 1;
  bool _done(Clause c, int dot) => c is Seq
      ? dot == c.subClauses.length
      : dot == 1 || !(c as Repetition).requireOne;
  bool _more(Clause c, int dot) => c is! Seq || dot < c.subClauses.length;

  Map<int, int> _chain(Clause c, int dot, int pos, int b) {
    final out = <int, int>{};
    final limit = (b + 1) * _M;
    if (_done(c, dot)) out[pos] = 0;
    if (!_more(c, dot)) return out;
    final to = _after(c, dot);
    final sub = _elem(c, dot);
    for (final h in _ends(sub, 0, pos, b).entries) {
      // A zero-width iteration would re-enter the identical state: this is the
      // same cut the pure parser applies to a zero-width repetition, and it is
      // the only guard the recursion needs to terminate.
      if (h.key == pos && to == dot) continue;
      for (final t in _ends(c, to, h.key, b - _cost(h.value)).entries) {
        final total = h.value + t.value;
        if (total < limit) _put(out, t.key, total);
      }
    }
    // SKIP, as a UNIT edge (A1). Reachable only where an element still follows,
    // so a finished state cannot absorb text -- that is what keeps each gap at
    // its canonical attachment point instead of merely at an equal-cost one.
    if (pos < _n && b >= 1) {
      final s = _M + 2 * _lost(pos, pos + 1);
      for (final t in _ends(c, dot, pos + 1, b - 1).entries) {
        final total = s + t.value;
        if (total < limit) _put(out, t.key, total);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Reconstruction: replay the same recurrence, taking any decomposition whose
  // parts sum to the Delta already known to be minimal.
  //
  // PREFER THE SHORTEST HEAD. Among Delta-tied decompositions take the one whose
  // head ends earliest: text being discarded anyway should stay outside a subtree
  // rather than stretch a rule node over it. Worth 6 shape points, and the reason
  // this is a forward descent -- a backward predecessor walk fixes the tail
  // first, so by the time the head is reached its tie is already settled.
  // ---------------------------------------------------------------------------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  /// Reconstruction's own recursion path, and the exact analogue of
  /// `MemoEntry.inRecPath`. A left recursive alternative can reproduce the state
  /// being built -- the same rule over the same extent at the same Delta,
  /// whenever what follows it is nullable -- and a Delta-exact descent would take
  /// that cycle forever. The parser rejects the very same derivation with "the
  /// match did not increase in length". Every cycle in a clause graph passes
  /// through a Ref, because a clause tree is finite and a Ref is its only back
  /// edge, so guarding Refs is enough.
  final Set<(Clause, int, int, int)> _path = {};

  /// Attempt a subtree, and if it fails leave no trace: an abandoned branch must
  /// not leave its substitutions and fabrications recorded. This is why
  /// reconstruction returns null rather than throwing -- a descent that can be
  /// abandoned is exactly what the cycle guard needs, and it makes recovery total.
  T? _try<T>(T? Function() attempt) {
    final s = _spans.length, m = _missing.length;
    final out = attempt();
    if (out == null) {
      _spans.length = s;
      _missing.length = m;
    }
    return out;
  }

  MatchResult? _build(Clause c, int pos, int end, int d, int b) {
    final pure = pos > _n ? mismatch : c.match(_parser, pos);
    if (!pure.isMismatch && pos + pure.len == end && _score(pure) == d) {
      return pure;
    }
    if (c is Ref) {
      final state = (c, pos, end, d);
      if (!_path.add(state)) return null;
      final sub = _build(_rules[c.ruleName]!, pos, end, d, b);
      _path.remove(state);
      return sub == null
          ? null
          : Match(c, pos, end - pos, subClauseMatches: [sub]);
    }
    if (c is Str && c.text.length > 1) {
      return _build(_desugar(c), pos, end, d, b);
    }
    if (c is Terminal) {
      if (end == pos && _cost(d) > 0) {
        _missing.add(MissingObligation(c, pos)); // FAB
      } else if (_cost(d) > 0) {
        _spans.add(SyntaxError(pos: pos, len: end - pos)); // SUB
      }
      return Match(c, pos, end - pos);
    }
    if (c is FollowedBy || c is NotFollowedBy) return Match(c, pos, 0);
    if (c is First || c is Optional) {
      for (final sub in _alts(c)) {
        if (_ends(sub, 0, pos, b)[end] != d) continue;
        final m = _try(() => _build(sub, pos, end, d, b));
        if (m != null) {
          return Match(c, pos, end - pos, subClauseMatches: [m]);
        }
      }
      if (c is Optional && pos == end && d == 0) return Match(c, pos, 0);
      return null;
    }
    final children = _descend(c, 0, pos, end, d, b);
    if (children == null) return null;
    return children.isEmpty
        ? Match(c, pos, 0)
        : Match(c, pos, end - pos, subClauseMatches: children);
  }

  List<MatchResult>? _descend(
      Clause c, int dot, int pos, int end, int d, int b) {
    if (_more(c, dot)) {
      final to = _after(c, dot);
      final sub = _elem(c, dot);
      final heads = _ends(sub, 0, pos, b);
      final order = heads.keys.toList()..sort(); // shortest head first
      for (final he in order) {
        if (he == pos && to == dot) continue;
        final hv = heads[he]!;
        // The remainder's Delta is non-negative, so a head already past the
        // target cannot belong to any decomposition summing to it.
        if (hv > d) continue;
        final rest = _ends(c, to, he, b - _cost(hv))[end];
        if (rest == null || hv + rest != d) continue;
        final parts = _try<List<MatchResult>>(() {
          final head = _build(sub, pos, he, hv, b);
          if (head == null) return null;
          final tail = _descend(c, to, he, end, rest, b - _cost(hv));
          return tail == null ? null : [head, ...tail];
        });
        if (parts != null) return parts;
      }
      // SKIP one character, then continue from the same dot. Consecutive unit
      // skips are merged so the tree carries one span per gap, not one per
      // character.
      if (pos < _n && b >= 1) {
        final s = _M + 2 * _lost(pos, pos + 1);
        final rest = _ends(c, dot, pos + 1, b - 1)[end];
        if (rest != null && s + rest == d) {
          final tail = _descend(c, dot, pos + 1, end, rest, b - 1);
          if (tail == null) return null;
          var len = 1;
          var i = 0;
          if (tail.isNotEmpty &&
              tail.first is SyntaxError &&
              tail.first.pos == pos + 1) {
            len += tail.first.len;
            i = 1;
          }
          return [SyntaxError(pos: pos, len: len), ...tail.skip(i)];
        }
      }
    }
    if (_done(c, dot) && pos == end && d == 0) return const [];
    return null;
  }

  void _collect(MatchResult m) {
    if (m is SyntaxError) {
      _spans.add(m);
    } else {
      m.subClauseMatches.forEach(_collect);
    }
  }

  SkipResult recover(String input, {int maxCost = 40}) {
    final cost = recoverCost(input, maxCost: maxCost);
    _spans.clear();
    _missing.clear();
    _path.clear();
    if (cost == 0) return SkipResult(_clean!, const [], const [], 0, false);
    final root = cost < 0 ? null : _build(_goal, 0, _n, _bestInner, cost);
    if (root == null) {
      // No repair within budget, or none whose witness survives the cycle guard:
      // report the input as one error rather than failing.
      final error = SyntaxError(pos: 0, len: _n);
      return SkipResult(error, [error], const [], 1, true);
    }
    // Skip spans are read back off the finished tree, so a merged gap is
    // recorded once. Substitutions and fabrications are not tree spans and are
    // recorded where they are decided, in _build.
    _collect(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  int recoverCost(String input, {int maxCost = 40}) {
    _input = input;
    _n = input.length;
    _clean = null;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildH();
    _shift = ((2 * _n + maxCost + 2) * (_floor + 1)).bitLength;
    _M = 1 << _shift;
    _memo.clear();
    _memoBudget.clear();
    _memoVer.clear();
    _inPath.clear();
    _foundLR.clear();
    _verAtPos = List.filled(_n + 2, 0);
    _scores.clear();
    _steps = 0;
    // Iterative deepening on the budget. A3 makes each round reuse the previous
    // round's memo, and the goal clause makes the whole query a single lookup:
    // "consume the entire input".
    for (var k = 0; k <= maxCost; k++) {
      final best = _ends(_goal, 0, 0, k)[_n];
      if (best != null) {
        _bestInner = best;
        lastCost = _cost(best);
        lastRegret = best - lastCost * _M - _lost(0, _n);
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
