import 'dart:math' as math;
import 'dart:typed_data';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

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
  final Map<Clause, int> _ids = {};
  final Map<int, Map<int, int>> _memo = {};
  final Map<int, int> _memoBudget = {};
  MatchResult? _clean;
  int _steps = 0, _bestLead = -1, _bestEnd = -1, _bestInner = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;

  int _id(Clause c) => _ids.putIfAbsent(c, () => _ids.length);
  int _cost(int d) => d >> _shift;
  int _lost(int a, int z) => _H[z] - _H[a];
  int _w(Clause c) => _widths.putIfAbsent(c, () => _width(c));

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

  int _score(MatchResult m) {
    final old = _scores[m];
    if (old != null) return old;
    final score = m.subClauseMatches.isEmpty
        ? _w(m.clause!) * m.len
        : m.subClauseMatches.fold(0, (v, x) => v + _score(x));
    return _scores[m] = score;
  }

  static bool _put(Map<int, int> out, int key, int value) {
    final old = out[key];
    if (old == null || value < old) {
      out[key] = value;
      return true;
    }
    return false;
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

  Map<int, int> _ends(Clause c, int pos, int b) {
    if (pos > _n || b < 0) return const {};
    final key = _id(c) * (_n + 2) + pos;
    final have = _memoBudget[key];
    if (have == b) return _memo[key]!;
    if (have != null && have > b) return _filter(_memo[key]!, b);
    _memoBudget[key] = b;
    _memo[key] = const {};
    final answer = _compute(c, pos, b);
    _memoBudget[key] = b;
    return _memo[key] = answer;
  }

  Map<int, int> _compute(Clause c, int pos, int b) {
    _steps++;
    if (b == 0) {
      final m = pos > _n ? mismatch : c.match(_parser, pos);
      return m.isMismatch ? const {} : {pos + m.len: _score(m)};
    }
    if (c is Ref) return _ends(_rules[c.ruleName]!, pos, b);
    if (c is Str && c.text.length > 1) return _ends(_desugar(c), pos, b);
    if (c is Terminal) {
      final out = <int, int>{};
      final m = c.match(_parser, pos);
      if (!m.isMismatch) out[pos + m.len] = _score(m);
      if (m.isMismatch && pos < _n) {
        out[pos + 1] = _M + 2 * _lost(pos, pos + 1);
      }
      if (c is! Nothing) _put(out, pos, _M + _floor);
      return out;
    }
    if (c is Seq || c is First || c is Optional || c is Repetition) {
      return _machine(c, pos, b);
    }
    final yes = c is FollowedBy
        ? !c.subClause.match(_parser, pos).isMismatch
        : c is NotFollowedBy && c.subClause.match(_parser, pos).isMismatch;
    return yes ? {pos: 0} : const {};
  }

  int _dots(Clause c) => c is Seq ? c.subClauses.length + 1 : 2;

  bool _accepts(Clause c, int dot) => c is Seq
      ? dot == c.subClauses.length
      : c is First
          ? dot == 1
          : c is Optional || dot == 1 || !(c as Repetition).requireOne;

  /// THE ARCS LEAVING (c, dot): every subclause that may be matched next. An
  /// empty list means the state can only ACCEPT. This one table is the whole
  /// reason all four composite clause types share a single engine -- Seq is a
  /// chain, First is parallel arcs out of dot 0, Optional is one arc plus
  /// ACCEPT, Repetition is a self-loop -- and both the forward sweep and the
  /// reconstruction descent read it, so the topology is stated exactly once.
  final Map<Clause, List<List<Clause>>> _arcCache = {};
  List<Clause> _arcs(Clause c, int dot) =>
      (_arcCache[c] ?? (_arcCache[c] = [
        for (var d = 0; d < _dots(c); d++)
          c is Seq
              ? (d < c.subClauses.length ? [c.subClauses[d]] : const <Clause>[])
              : c is First
                  ? (d == 0 ? c.subClauses : const <Clause>[])
                  : (c is Optional && d == 1)
                      ? const <Clause>[]
                      : [(c as HasOneSubClause).subClause],
      ]))[dot];

  /// The dot an arc lands on: Seq walks its chain, everything else loops or
  /// finishes at dot 1.
  int _to(Clause c, int dot) => c is Seq ? dot + 1 : 1;

  /// A state that can only ACCEPT, so nothing follows it. Repetition is never
  /// one: its accepting states also carry the self-loop.
  bool _sink(Clause c, int dot) => c is! Repetition && _accepts(c, dot);

  Map<int, int> _machine(Clause c, int pos, int b, [int dot0 = 0]) {
    // The state index is `dot * width + (p - pos)`, and THAT INDEX IS ITS OWN
    // TOPOLOGICAL ORDER: every arc advances the dot or the position and never
    // moves either backwards, so one ascending sweep finalises each state before
    // it is read. No queue, no priority, no fixpoint iteration, no round cap and
    // no no-progress guard -- a single `for` over an array.
    //
    // Int64List holding Delta + 1, so the native zero fill means "unset". This
    // array is the most-allocated object in the engine (one per composite clause
    // per position); a List<int?> is a pointer array that must be null-filled on
    // every call, and paying the +1 instead was worth 6% wall clock.
    final width = _n - pos + 1;
    final val = Int64List(_dots(c) * width);
    final out = <int, int>{};
    final limit = (b + 1) * _M;
    val[dot0 * width] = 1; // (dot0, pos) at Delta 0
    for (var state = dot0 * width; state < val.length; state++) {
      if (val[state] == 0) continue;
      final d = val[state] - 1;
      final dot = state ~/ width, p = pos + state % width;
      final rem = b - _cost(d);
      if (_accepts(c, dot)) _put(out, p, d);
      final to = _to(c, dot);
      final arcs = _arcs(c, dot);
      // SKIP: discard ONE character, dot unchanged. A span of j characters costs
      // j * _M + 2 * _lost(p, p+j), which is exactly the sum of j of these unit
      // steps -- the span cost is additive in the characters it covers -- so the
      // j-loop that used to sit here was a hand-unrolled path through a self-loop
      // that the sweep already traverses for free. Guarded on `arcs` so a state
      // that can only ACCEPT still cannot absorb text, which keeps the witness
      // set identical to the j-loop version rather than merely equal-cost.
      if (rem >= 1 && p < _n && arcs.isNotEmpty) {
        final total = d + _M + 2 * _lost(p, p + 1);
        final next = state + 1;
        if (total < limit && (val[next] == 0 || val[next] - 1 > total)) {
          val[next] = total + 1;
        }
      }
      for (final sub in arcs) {
        for (final e in _ends(sub, p, rem).entries) {
          final total = d + e.value;
          if (total >= limit) continue;
          final next = to * width + e.key - pos;
          final old = val[next];
          if (old != 0 && old - 1 <= total) continue;
          assert(next > state);
          val[next] = total + 1;
        }
      }
    }
    return out;
  }

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  void _span(int pos, int len) {
    if (len > 0) _spans.add(SyntaxError(pos: pos, len: len));
  }

  MatchResult _build(Clause c, int pos, int end, int d, int b) {
    final pure = pos > _n ? mismatch : c.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        _score(pure) == d) {
      return pure;
    }
    if (c is Ref) {
      final child = _build(_rules[c.ruleName]!, pos, end, d, b);
      return Match(c, pos, end - pos, subClauseMatches: [child]);
    }
    if (c is Str && c.text.length > 1) {
      return _build(_desugar(c), pos, end, d, b);
    }
    if (c is Terminal) {
      if (end == pos && _cost(d) > 0) {
        _missing.add(MissingObligation(c, pos));
      } else if (_cost(d) > 0) {
        _span(pos, end - pos);
      }
      return Match(c, pos, end - pos);
    }
    if (c is FollowedBy || c is NotFollowedBy) return Match(c, pos, 0);
    final children = _descend(c, 0, pos, end, d, b);
    return children.isEmpty
        ? Match(c, pos, 0)
        : Match(c, pos, end - pos, subClauseMatches: children);
  }

  /// Walk the machine FORWARDS from (`c`, `dot`) at `pos`, taking any arc whose
  /// head Delta plus the remainder's Delta is exactly `d`. The path through the
  /// machine IS the child list, so this single descent reconstructs all four
  /// composite types: Seq's k children, First's chosen alternative, Optional's
  /// zero-or-one, Repetition's n iterations.
  ///
  /// PREFER THE SHORTEST HEAD. Among decompositions that TIE on Delta, take the
  /// one whose head ends earliest. That is the same smallest-extent principle the
  /// top-level lead/end split already uses -- text being discarded anyway should
  /// stay outside a subtree rather than stretch a rule node over it -- and it is
  /// worth 6 shape points on its own. A backward predecessor walk cannot express
  /// it: walking back from the accepting state fixes the TAIL first, so by the
  /// time the head is reached its tie has already been settled by whichever
  /// relaxation happened to land first. Ordering the sweep's ties the other way
  /// was measured instead of assumed, and scores 511.
  List<MatchResult> _descend(
      Clause c, int dot, int pos, int end, int d, int b) {
    final to = _to(c, dot);
    final sink = _sink(c, to);
    for (final sub in _arcs(c, dot)) {
      for (var j = 0; j <= b && pos + j <= _n; j++) {
        final span = j * _M + 2 * _lost(pos, pos + j);
        final heads = _ends(sub, pos + j, b - j);
        final ends = heads.keys.toList()..sort();
        for (final he in ends) {
          final head = span + heads[he]!;
          // The remainder's Delta is non-negative, so a head already past the
          // target cannot belong to any decomposition summing to it. This skips
          // the sweep below for most candidates.
          if (head > d) continue;
          final rest = sink
              ? (he == end ? 0 : null)
              : _machine(c, he, b - _cost(head), to)[end];
          if (rest == null || head + rest != d) continue;
          final kids = <MatchResult>[];
          if (j > 0) {
            _span(pos, j);
            kids.add(SyntaxError(pos: pos, len: j));
          }
          kids.add(_build(sub, pos + j, he, heads[he]!, b - j));
          if (!sink) {
            kids.addAll(_descend(c, to, he, end, rest, b - _cost(head)));
          }
          return kids;
        }
      }
    }
    if (_accepts(c, dot) && pos == end && d == 0) return const [];
    throw StateError('no witness for $c at dot $dot');
  }

  SkipResult recover(String input, {int maxCost = 40}) {
    final cost = recoverCost(input, maxCost: maxCost);
    _spans.clear();
    _missing.clear();
    if (cost == 0) return SkipResult(_clean!, const [], const [], 0, false);
    if (cost < 0) {
      final error = SyntaxError(pos: 0, len: _n);
      return SkipResult(error, [error], const [], 1, true);
    }
    final top = _rules[topRuleName]!;
    final children = <MatchResult>[];
    if (_bestLead > 0) {
      _span(0, _bestLead);
      children.add(SyntaxError(pos: 0, len: _bestLead));
    }
    children.add(_build(
        top, _bestLead, _bestEnd, _bestInner, cost - _bestLead));
    if (_bestEnd < _n) {
      _span(_bestEnd, _n - _bestEnd);
      children.add(SyntaxError(pos: _bestEnd, len: _n - _bestEnd));
    }
    _spans.sort((a, b) => a.pos - b.pos);
    final root = children.length == 1
        ? children.first
        : Match(null, 0, _n, subClauseMatches: children);
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
    _scores.clear();
    _steps = 0;
    final top = _rules[topRuleName]!;
    for (var k = 0; k <= maxCost; k++) {
      var best = -1;
      _bestEnd = -1;
      for (var lead = 0; lead <= k && lead <= _n; lead++) {
        final prefix = lead * _M + 2 * _lost(0, lead);
        for (final e in _ends(top, lead, k - lead).entries) {
          if (e.key > _n) continue;
          final total =
              prefix + e.value + (_n - e.key) * _M + 2 * _lost(e.key, _n);
          if (total < (k + 1) * _M &&
              (best < 0 || total < best || total == best && e.key < _bestEnd)) {
            best = total;
            _bestLead = lead;
            _bestEnd = e.key;
            _bestInner = e.value;
          }
        }
      }
      if (best >= 0) {
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
