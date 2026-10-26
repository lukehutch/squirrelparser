import 'package:squirrel_parser/squirrel_parser.dart' as peg;

// The exact search: repaired strings in order of cost, each parsed by the
// library parser over a copy of the grammar whose terminals record the last
// position the parse examined. An edit after that position cannot change the
// parse, so the next edit goes between the last one and it.

// A terminal that records what it examines, and the characters it compares
// against the unknown character at `_Exact.sym`.
class _Probe extends peg.Clause {
  _Probe(this.t, this.x);
  final peg.Terminal t; final Exact x;
  @override
  peg.MatchResult match(peg.Parser p, int pos) {
    final s = p.input, n = t is peg.Str ? (t as peg.Str).text.length : t is peg.Nothing ? 0 : 1;
    for (var j = 0; j < n; j++) {
      final q = pos + j; if (q > x.far) x.far = q;
      if (q == x.sym) { x.seen.add(Exact.code(t, j)); return peg.Mismatch(t, pos, 0); }
      if (q >= s.length || t is peg.Str && s.codeUnitAt(q) != (t as peg.Str).text.codeUnitAt(j)) break;
    }
    return t.match(p, pos);
  }
  @override
  void checkRuleRefs(Map<String, peg.Clause> g) {}
}

class Exact {
  Exact(Map<String, peg.Clause> rules, this.top) {
    peg.Clause copy(peg.Clause c) {
      final n = switch (c) {
        peg.Terminal() => _Probe(c, this),
        peg.Seq() => peg.Seq([for (final s in c.subClauses) copy(s)]),
        peg.First() => peg.First([for (final s in c.subClauses) copy(s)]),
        peg.OneOrMore() => peg.OneOrMore(copy(c.subClause)),
        peg.ZeroOrMore() => peg.ZeroOrMore(copy(c.subClause)),
        peg.Optional() => peg.Optional(copy(c.subClause)),
        peg.FollowedBy() => peg.FollowedBy(copy(c.subClause)),
        peg.NotFollowedBy() => peg.NotFollowedBy(copy(c.subClause)),
        _ => c,
      };
      _old[n] = c; return n;
    }
    rules.forEach((k, v) => _rules[k] = copy(v));
  }
  final String top; final _rules = <String, peg.Clause>{}, _old = Map<peg.Clause, peg.Clause>.identity();
  int far = -1, sym = -1, lastCost = 0, parses = 0; Set<int> seen = {};

  // The character a terminal stands for at offset j; an open class is a
  // negative placeholder (D7).
  static int code(peg.Terminal t, int j) => switch (t) {
    peg.Str(:final text) => text.codeUnitAt(j),
    peg.Char(:final char) => char.codeUnitAt(0),
    peg.CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => -ranges[0].$1,
    peg.CharSet(:final ranges) => -[for (var x = 32; x < 0x10000; x++) x].firstWhere((x) => !ranges.any((r) => x >= r.$1 && x <= r.$2)),
    _ => -32,
  };

  // Each character of the repaired string: the input position it comes from
  // (-1 if inserted) and the character. Edits are (op, at, ch): op 0 delete,
  // 1 insert, 2 substitute, in input order.
  static List<(int, int)> apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[]; var j = 0;
    for (var i = 0; i <= input.length; i++) {
      var del = false; int? sub;
      for (; j < es.length && es[j].$2 == i; j++) {
        final (op, _, ch) = es[j];
        if (op == 1) { out.add((-1, ch.abs())); } else if (op == 0) { del = true; } else { sub = ch.abs(); }
      }
      if (i < input.length && !del) out.add((sub == null ? i : -2 - i, sub ?? input.codeUnitAt(i)));
    }
    return out;
  }

  // The parse of `w` over the probe grammar; on a stack overflow every rule
  // is matched from the end back first, so no call nests deeply.
  peg.MatchResult parse(String w) {
    far = -1; parses++;
    var p = peg.Parser(rules: _rules, topRuleName: top, input: w);
    try { return p.matchRule(top, 0); } on StackOverflowError {
      p = peg.Parser(rules: _rules, topRuleName: top, input: w);
      for (var q = w.length; q >= 0; q--) { for (final r in p.rules.values) { p.match(r, q); } }
      return p.matchRule(top, 0);
    }
  }

  peg.MatchResult recover(String input) {
    final seenStates = <String, (List<List<(int, int, int)>>, int)>{};
    var level = [<(int, int, int)>[]];
    // reach[l]: the farthest input position at which a repair cheaper than
    // this level, whose last edit is at l or later, failed. Once the search
    // has parsed 64 strings per input character, a repair that fails no
    // farther than one of these, with its last edit no later, is not grown.
    final reach = List.filled(input.length + 2, -1); parses = 0;
    for (var cost = 0;; cost++) {
      final failed = <(int, int)>[]; final next = <List<(int, int, int)>>[]; List<(int, int, int)>? best; peg.MatchResult? bestTree; List<(int, int)>? bestS;
      for (final es in level) {
        final s = apply(input, es), w = String.fromCharCodes([for (final x in s) x.$2]);
        final m = parse(w);
        if (!m.isMismatch && m.len == w.length) {
          if (best == null || _cmp(es, best) < 0) { best = es; bestTree = m; bestS = s; }
          continue;
        }
        if (best != null) continue;
        final f = !m.isMismatch && m.len > far ? m.len : far;
        var g = f; while (g < s.length && s[g].$1 == -1) { g++; }
        final fIn = g < s.length ? _at(s, g) : input.length, l = es.isEmpty ? 0 : es.last.$2 + 1;
        if (fIn < input.length) failed.add((l, fIn));
        if (fIn <= reach[l] && parses > 64 * (input.length + 1)) continue;
        // the first place the next edit may go: after the last edit
        var v = 0;
        if (es.isNotEmpty) { final (op, at, _) = es.last; v = s.indexWhere((x) => x.$1 >= at || x.$1 <= -2 - at); if (v < 0) v = s.length; if (op != 1) v++; if (op == 0) v--; }
        for (var q = v; q <= f && q <= s.length; q++) {
          final o = q < s.length ? s[q].$1 : input.length;
          if (o < 0) continue;
          final last = es.isEmpty ? null : es.last;
          // the characters the parse compares against an unknown one inserted at q, or put in place of s[q]
          void probe(bool ins) {
            final cs = [for (final x in s) x.$2];
            ins ? cs.insert(q, 0) : cs[q] = 0;
            sym = q; seen = {}; parse(String.fromCharCodes(cs)); sym = -1;
          }
          if (last == null || o > last.$2 || o == last.$2 && last.$1 == 1) {
            probe(true);
            for (final ch in seen) { _push(next, seenStates, input, [...es, (1, o, ch)]); }
          }
          if (q < s.length && (last == null || o > last.$2)) {
            _push(next, seenStates, input, [...es, (0, o, 0)]);
            probe(false);
            for (final ch in seen) { if (ch.abs() != input.codeUnitAt(o)) _push(next, seenStates, input, [...es, (2, o, ch)]); }
          }
        }
      }
      if (best != null) {
        var n = 0, eof = false;
        for (final (op, at, _) in best) { if (op == 1 && at == input.length) { eof = true; } else { n++; } }
        lastCost = n + (eof ? 1 : 0);
        return _map(bestTree!, bestS!, input);
      }
      for (final (l, f) in failed) { for (var i = l; i >= 0 && reach[i] < f; i--) { reach[i] = f; } }
      level = next;
    }
  }

  // Two repairs with the same string and the same last edit have the same
  // continuations, so only the cheapest, and of equal cost the first by
  // _cmp, is kept.
  static void _push(List<List<(int, int, int)>> to, Map<String, (List<List<(int, int, int)>>, int)> seen, String input, List<(int, int, int)> es) {
    final k = '${es.last.$2},${es.last.$1 == 1},${String.fromCharCodes(apply(input, es).map((x) => x.$2))}';
    switch (seen[k]) {
      case null: seen[k] = (to, to.length); to.add(es);
      case (final l, final i) when identical(l, to) && _cmp(es, l[i]) < 0: l[i] = es;
      default:
    }
  }

  // Among repairs of equal cost: edits as late as possible, then insert
  // before substitute before delete.
  static int _cmp(List<(int, int, int)> a, List<(int, int, int)> b) {
    for (var i = 1; i <= a.length && i <= b.length; i++) {
      final x = a[a.length - i], y = b[b.length - i];
      if (x.$2 != y.$2) return y.$2 - x.$2;
    }
    const order = [2, 0, 1];
    return order[a.last.$1] - order[b.last.$1];
  }

  static int _at(List<(int, int)> s, int q) => s[q].$1 >= 0 ? s[q].$1 : s[q].$1 <= -2 ? -2 - s[q].$1 : -1;

  // The parse tree of the repaired string `s`, mapped back onto the input.
  peg.MatchResult _map(peg.MatchResult root, List<(int, int)> s, String input) {
    int at(int q) => _at(s, q);
    final orig = List.filled(s.length + 1, input.length);
    for (var q = s.length - 1; q >= 0; q--) { orig[q] = at(q) >= 0 ? at(q) : orig[q + 1]; }
    var next = 0;
    List<peg.MatchResult> gap(int o) {
      if (o <= next) return const [];
      final g = peg.SyntaxError(pos: next, len: o - next);
      next = o;
      return [g];
    }
    // One character of a leaf: read, inserted (a gap the clause fills), or
    // substituted (an error in the clause's place).
    peg.MatchResult letter(peg.Clause l, int q) {
      final o = orig[q];
      if (s[q].$1 >= 0) { next = o + 1; return peg.Match(l, o, 1); }
      if (s[q].$1 <= -2) { next = o + 1; return peg.SyntaxError(pos: o, len: 1); }
      return peg.Match(l, o, 0, subClauseMatches: [peg.SyntaxError(pos: o, len: 0)]);
    }
    // The nodes standing for `m` over the input: input deleted before it, then `m` itself.
    List<peg.MatchResult> walk(peg.MatchResult m) {
      final c = _old[m.clause] ?? m.clause;
      if (m.len == 0) return [peg.Match(c, orig[m.pos] < next ? orig[m.pos] : next, 0, subClauseMatches: [for (final k in m.subClauseMatches) ...walk(k)])];
      final out = [...gap(orig[m.pos])];
      if (m.subClauseMatches.isEmpty) {
        var clean = true;
        for (var q = m.pos; q < m.pos + m.len; q++) { if (s[q].$1 < 0 || orig[q] != orig[m.pos] + q - m.pos) clean = false; }
        if (clean) { next = orig[m.pos] + m.len; return [...out, peg.Match(c, orig[m.pos], m.len)]; }
        if (m.len == 1) return [...out, letter(c!, m.pos)];
        // A literal of several letters with an edit in it is spelled letter
        // by letter, so each edit stands in the place of one letter.
        final t = (c as peg.Str).text, kids = <peg.MatchResult>[];
        for (var q = m.pos; q < m.pos + m.len; q++) { kids.addAll(gap(orig[q])); kids.add(letter(peg.Char(t[q - m.pos]), q)); }
        return [...out, peg.Match(c, orig[m.pos], next - orig[m.pos], subClauseMatches: kids)];
      }
      // A node that starts past the end of the input completes it: it covers
      // nothing a reader wrote, so it carries no rule's name.
      final o = orig[m.pos], kids = [for (final k in m.subClauseMatches) ...walk(k)];
      return [...out, peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)];
    }
    final ts = [...walk(root), ...gap(input.length)];
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }
}
