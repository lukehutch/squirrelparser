import 'package:squirrel_parser/squirrel_parser.dart';

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

// Dirty pieces are real Match trees of edit leaves. Their native spans locate edits.
// prev is the actual EOF-only edit suffix, absent when the whole fragment is EOF-only.
class _Way {
  static int maxOwed = _never;
  static int _ex(int o) => o > maxOwed ? o - maxOwed : 0;
  const _Way(this.end, [this.edits = 0, this.used = 0, this.piece, this.prev]);
  _Way.skip(int a, int b) : this(b, b - a, b - a, SyntaxError(pos: a, len: b - a));
  final int end, edits, used;
  final Object? piece;
  final _Way? prev;
  bool get clean => piece is! Match;
  bool get preferred => clean && piece is! Clause;
  int get owed => prev?.edits ?? 0;
  int get spent => edits - owed;
  int get cost => spent + (owed == 0 ? 0 : _ex(owed) + 1);
  int get first => clean ? _never : (piece as Match).pos;
  int get last => clean ? -1 : first + (piece as Match).len;
  int rem(int b, [bool s = false]) => s ? b : b - used;
  bool synced(int a, [int g = 1]) {
    if (g >= 0 && (spent == 0 || end <= last + g)) return false;
    var need = (3 - (end - a - spent)) >> 1;
    if (need <= 0 || clean) return need <= 0;
    for (final st = <MatchResult>[piece as Match]; st.isNotEmpty;) {
      final m = st.removeLast();
      if (m.subClauseMatches case [final l, final r])
        st.addAll([r, l]);
      else if (m.len == 0 && m.clause is Terminal && (owed == 0 || m.pos < end) && --need == 0) return true;
    }
    return false;
  }

  _Way then(_Way r, [bool s = false]) {
    final o1 = owed, o2 = r.owed, u = (s ? 0 : used) + r.used + _ex(o1 + o2) - (s ? 0 : _ex(o1)) - _ex(o2);
    final both = !clean && !r.clean;
    final p = both
        ? Match(null, 0, 0, subClauseMatches: [piece as Match, r.piece as Match])
        : (r.clean && !preferred || !clean ? piece : r.piece);
    final t = both ? (o2 == 0 ? null : prev?.then(r.prev!) ?? r.prev!) : (clean ? r.prev : prev);
    return _Way(r.end, edits + r.edits, u, p, t);
  }
}

class _Cell {
  var mark = -1, ends = <_Way>[];
}

typedef _Res = (List<_Way>, int);

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required String topRuleName})
      : parser = Parser(rules: rules, topRuleName: topRuleName, input: '');
  Parser parser;
  final _cells = <Object, _Cell>{}, _mins = <MatchResult, int>{};
  String get path => lastCost == 0 ? 'plain' : 'checked';
  int lastCost = 0;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;
  Clause get _top => parser.rules[parser.topRuleName]!;
  Clause _rule(Ref r) => parser.rules[r.ruleName]!;
  static bool _lit(Clause? c) => c is Str || c is Char || c is CharSet && !c.inverted;
  int _ev(MatchResult m) {
    if (m.len == 0) return 0;
    final s = m.subClauseMatches;
    return s.isNotEmpty
        ? (_mins[m] ??= _ev(s[0]) + _ev(s[1]))
        : (m is SyntaxError ? _len * m.len : (_lit(m.clause) ? _len + 1 : 0));
  }

  int _sc(_Way w, bool hw) {
    final m = w.piece as Match;
    if (m is SyntaxError) return w.spent;
    final s = m.subClauseMatches;
    final v = m.len == 0 ? 0 : (s.isEmpty ? _ev(m) : (_mins[m] ?? _ev(s[0]) + _ev(s[1])));
    return (v + (hw ? 0 : _len)) ~/ (_len + 1);
  }

  int _cmp(_Way a, _Way b, bool hw, [bool sc = true, int d = 0]) {
    if (a.cost != b.cost) return a.cost - b.cost;
    if (sc && a.cost > 0 && a.piece != b.piece) {
      final e = _sc(a, hw) - _sc(b, hw);
      if (e != 0) return e;
    }
    return d != 0 ? d : (a.first != b.first ? b.first - a.first : a.last - b.last);
  }

  bool _add(_Cell cell, _Way r, int rung, bool hw, [int b = _never]) {
    if (r.rem(b) < 0 || rung > 0 && r.cost > rung) return false;
    final es = cell.ends;
    final rk = rung <= 0 ? r.last : r.first, ro = r.owed;
    var lo = 0, hi = es.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1, a = es[m];
      var d = a.end - r.end;
      if (d == 0 && (d = (rung <= 0 ? a.last : a.first) - rk) == 0) d = a.owed - ro;
      if (d == 0) {
        final c = _cmp(a, r, hw);
        if (c > 0 || c == 0 && ro == 0) es[m] = r;
        return c > 0;
      }
      d < 0 ? lo = m + 1 : hi = m;
    }
    lo == es.length ? es.add(r) : es.insert(lo, r);
    return true;
  }

  bool _hit(CharSet c, int ch) {
    for (final r in c.ranges) if (ch >= r.$1 && ch <= r.$2) return true;
    return false;
  }

  int _end(Clause c, int p) => switch (c) {
        Char() => p < _len && parser.input.codeUnitAt(p) == c.char.codeUnitAt(0) ? p + 1 : -1,
        Str() => parser.input.startsWith(c.text, p) ? p + c.text.length : -1,
        CharSet() => p < _len && _hit(c, parser.input.codeUnitAt(p)) != c.inverted ? p + 1 : -1,
        _ => switch (parser.match(c, p)) { final m when !m.isMismatch => p + m.len, _ => -1 }
      };

  bool _oneShape(Clause c, [Set<Clause>? s]) => switch (c) {
        Seq() => c.subClauses.every((x) => _oneShape(x, s)),
        Repetition() => c.requireOne && _oneShape(c.subClause, s),
        Ref() => (s ??= {}).add(c) && _oneShape(_rule(c), s),
        Terminal() || FollowedBy() || NotFollowedBy() => true,
        _ => false
      };

  int _min0(Clause c, [Set<(Clause, bool)>? p, bool req = false]) {
    if (c is Ref) {
      if (!(p ??= {}).add((c, req))) return _never;
      final n = _min0(_rule(c), p, req);
      p.remove((c, req));
      return n;
    }
    if (c is Seq || c is First) {
      var n = c is Seq ? 0 : _never;
      for (final x in (c as HasMultipleSubClauses).subClauses)
        if ((n = c is Seq ? _min(_never, n + _min0(x, p)) : _min(n, _min0(x, p, req))) == (c is Seq ? _never : 0))
          break;
      return n;
    }
    return switch (c) {
      Repetition() when c.requireOne || req => _min0(c.subClause, p, true),
      Optional() when req => _min0(c.subClause, p, true),
      Str() => c.text.length,
      Char() || CharSet() || AnyChar() => 1,
      _ => req ? _never : 0
    };
  }

  _Res _read(Clause c, int p, int b, List<Clause>? ac, int g, bool hw, [List<_Cell>? k, bool delta = false]) {
    if (c is Ref) return _read(_rule(c), p, b, ac, g, hw, k, delta);
    if (b == 0 && p < _len || c is Terminal || c is FollowedBy || c is NotFollowedBy) {
      final e0 = _end(c, p);
      if (b == 0 && p < _len) return (e0 < 0 ? const [] : [_Way(e0)], _never);
      if (c is! Terminal) return ([e0 < 0 ? _Way(p, 0, 0, c) : _Way(e0)], _never);
      if (e0 >= 0) return ([_Way(e0)], _never);
      if (c is Str && c.text.length > 1) return _seq([for (final ch in c.text.split('')) Char(ch)], p, b, ac, g, hw, k);
      final o = p < _len ? null : _Way(0, 1, 0, Match(c, p, 0)), u = p < _len ? 1 : _Way._ex(1);
      return ([for (var d = 0; d <= (p < _len ? 1 : 0); d++) _Way(p + d, 1, u, Match(c, p, d), o)], _never);
    }
    final me = parser.getMemoEntry(c, p), m0 = me == null ? parser.match(c, p) : null;
    final cell = _cells[me ?? parser.getMemoEntry(c, p)!] ??= _Cell(), idx = ac?.indexOf(c) ?? -1;
    var ms = _never, cd = _never, all = null as List<_Way>?;
    if (idx >= 0)
      cd = idx + 1;
    else if (cell.mark < b) {
      final m1 = m0 ?? parser.match(c, p), pe = m1.isMismatch ? p : p + m1.len;
      var minJ = pe + 1;
      final a = ac ?? <Clause>[], d = a.length + 1;
      a.add(c);
      all = [];
      var inner = <_Cell>[];
      for (var step = <_Way>[], ns = <_Way>[];; step = [], ns = []) {
        for (final x in inner) x.mark = -1;
        final (props, cm) = _propose(c, p, b, a, g, hw, all.isNotEmpty, inner = []);
        for (final r in props)
          if ((!r.clean || r.end <= pe || r.preferred && cm < _never) && _add(cell, r, g, hw)) step.add(r);
        for (final r in step) {
          final ts = g <= 0 && cm == d && (r.synced(p, 0) || _pureSub(r)) ? _cells[(c, r.end)]?.ends : null;
          if (ts == null || ts.isEmpty) ns.add(r);
          for (final s in ts ?? const <_Way>[])
            if (r.then(s, true) case final w when _add(cell, w, 0, hw, b)) {
              all.add(w);
              minJ = minJ == pe + 1 ? w.end : _min(minJ, w.end);
            }
        }
        ms = _min(ms, cm);
        all.addAll(ns);
        if (ns.isEmpty || cm != d) {
          _cells.remove((c, p));
          break;
        }
        (_cells[(c, p)] ??= _Cell()).ends = ns;
      }
      a.removeLast();
      if (g <= 0 && ms == d && pe > p)
        (_cells[(c, pe)] ??= _Cell()).ends = cell.ends.where((w) => w.end >= minJ && w.first > pe).toList();
      cell.mark = b;
      if (ms < d) {
        k?.addAll([cell, ...inner]);
        cd = ms;
      }
    }
    final src = _cells[(c, p)]?.ends ?? (delta ? all ?? const <_Way>[] : cell.ends), out = <_Way>[];
    for (final r in src) if (r.rem(b) >= 0) out.add(r);
    return (out, cd);
  }

  bool _active(Clause? c, List<Clause>? ac) =>
      ac != null && (c is Ref ? ac.contains(_rule(c)) : c is First && c.subClauses.any((x) => _active(x, ac)));

  List<Clause> _flat(List<Clause> s) =>
      s.any((x) => x is HasOneSubClause) ? s : s.expand((x) => x is Seq ? _flat(x.subClauses) : [x]).toList();

  _Res _propose(Clause c, int p, int b, List<Clause>? ac, int g, bool hw, bool d, List<_Cell> k) {
    if (c is Seq) return _seq(_flat(c.subClauses), p, b, ac, g, hw, k);
    if (c is Repetition) return _repeat(c, p, b, ac, g, hw, k);
    if (c is Optional) {
      final (rs, cd) = _read(c.subClause, p, b, ac, g, hw, k);
      return ([_Way(p, 0, 0, rs.any((r) => r.preferred && r.end > p) ? c : null), ...rs], cd);
    }
    var out = <_Way>[], m = _never;
    final subs = (c as First).subClauses;
    for (var i = 0; i < subs.length; i++) {
      final s = subs[i];
      final (w, cd) = _read(s, p, b, ac, g, hw, k, d);
      m = _min(m, cd);
      out.addAll(w);
      if (i + 1 < subs.length && _total(s)) break;
    }
    return (out, m);
  }

  bool _total(Clause c) {
    if (c is Seq) {
      for (final x in c.subClauses) if (x is Terminal && (x is! Str || x.text.isNotEmpty) || !_total(x)) return false;
      return true;
    }
    return c is Repetition && !c.requireOne ||
        c is Optional ||
        c is Str && c.text.isEmpty ||
        c is First && c.subClauses.any(_total) ||
        c is Ref && _acyclic(c) && _total(_rule(c));
  }

  bool _acyclic(Clause c, [Map<Clause, bool>? seen]) {
    if (c is! Ref)
      return c is HasOneSubClause
          ? _acyclic(c.subClause, seen)
          : c is! HasMultipleSubClauses || c.subClauses.every((x) => _acyclic(x, seen));
    if ((seen ??= {})[c] case final known?) return known;
    seen[c] = false;
    return seen[c] = _acyclic(_rule(c), seen);
  }

  bool _startsClean(Clause c, int at, [Set<Clause>? s]) => switch (c) {
        Ref() => (s ??= {}).add(c) && _startsClean(_rule(c), at, s),
        First() => c.subClauses.any((x) => _startsClean(x, at, s)),
        Seq() => _flat(c.subClauses).take(1).any((x) => _end(x, at) > at),
        Terminal() => _end(c, at) > at,
        _ => false
      };

  _Res _seq(List<Clause> slots, int p, int b, List<Clause>? ac, int g, bool hw, [List<_Cell>? k]) {
    var cur = [_Way(p)], cd = _never;
    Set<_Way>? opt;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1, l = g <= 0;
      for (var ri = cur.length - 1; ri >= 0; ri--) {
        final r = cur[ri],
            same = r.end == p,
            a = same ? ac : null,
            po = opt?.contains(r) ?? false,
            sub = l && _pureSub(r),
            ev = r.end - p - r.spent,
            ps = sub && r.first > p && ev > r.spent,
            sync = l && (last ? r.synced(p) || sub && (ev > 0 || r.spent == 1 && _startsClean(s, r.end)) : ps),
            canS = s is! Terminal ? sync : ps && (!last && r.end > r.last || r.spent <= i + _min0(_top));
        final (options, rcd) = _read(s, r.end, r.rem(b, canS), a, g, hw, same ? k : null);
        if (same) cd = _min(cd, rcd);
        var del = -1, cleanAdv = false;
        for (final o in options) if (o.clean && o.end > r.end && (cleanAdv = true)) break;
        if (!cleanAdv) {
          final sk = last && sync;
          var j = r.end + 1, to = _min(r.end + r.rem(b, sk), _len), ej = -1;
          while (j <= to && (ej = _end(s, j)) <= j) j++;
          if (j <= to && (i == 0 || !_takes(slots[i - 1], po, r.end, null, j))) {
            _add(next, r.then(_Way.skip(r.end, j), sk).then(_Way(ej)), g, hw);
            if (!last && _end(slots[i + 1], ej) >= 0) del = j - r.end;
          }
        }
        final pen = del > 0 && !_active(s, a) && !_oneShape(s);
        for (final o in options) {
          if (o.end == r.end && pen && del <= o.spent ||
              i > 0 && (!o.clean || r.piece is Optional && o.end > r.end) && _takes(slots[i - 1], po, r.end, o))
            continue;
          final w = r.then(o, canS && (sub && _pureSub(o) || o.synced(r.end, o.owed > 0 ? -1 : 0)));
          if (s is Optional && o.end == r.end && o.clean) (opt ??= {}).add(w);
          _add(next, w, g, hw, b);
        }
      }
      if ((cur = next.ends).isEmpty) break;
    }
    return (cur, cd);
  }

  _Res _repeat(Repetition c, int p, int b, List<Clause>? ac, int g, bool hw, [List<_Cell>? k]) {
    final s = c.subClause, best = _Cell(), q = {p: _Way(p)}, q2 = hw && s is! Terminal ? <int, _Way>{} : null;
    final u = !_active(s, ac) && _min0(s) == 1;
    var cd = _never;
    bool syncs(_Way w) => _end(s, w.end) > w.end;
    void put(Map<int, _Way> m, _Way w, bool f) {
      final cur = m[w.end];
      if (cur == null || w.cost < cur.cost || w.cost == cur.cost && (f ? _cmp(cur, w, hw) >= 0 : w.first < cur.first))
        m[w.end] = w;
    }

    while (q.isNotEmpty) {
      var at = _never;
      for (final k0 in q.keys) if (k0 < at) at = k0;
      final r0 = q.remove(at)!, r1 = q2?.remove(at);
      for (final r in [r0, if (r1 != null && r1 != r0) r1]) {
        final same = r.end == p, sub = g <= 0 && u && _pureSub(r);
        final cs = g <= 0 && (sub || r.synced(p, g < 0 || u ? 0 : 1));
        final (ss, rcd) = _read(s, r.end, r.rem(b, cs), same ? ac : null, g, hw, same ? k : null);
        if (same) cd = _min(cd, rcd);
        final any = cs && ss.any((w) => w.end > r.end && syncs(w));
        for (final w in ss)
          if (w.end <= r.end) {
            if (same && !w.clean) _add(best, w, g, hw);
          } else {
            final st = cs && !w.clean && (g < 0 && u && r.synced(p, 0) || (syncs(w) || !any) && w.synced(r.end, -1));
            if (r.then(w, st) case final x when _add(best, x, g, hw, b)) {
              put(q, x, true);
              if (q2 != null) put(q2, x, false);
            }
          }
      }
    }
    if (!c.requireOne) _add(best, _Way(p), g, hw);
    return (g > 0 ? best.ends : best.ends.where((r) => !syncs(r)).toList(), cd);
  }

  bool _takes(Clause s, bool opt, int at, _Way? o, [int j = -1]) {
    final b = s is Repetition || opt && s is Optional ? (s as HasOneSubClause).subClause : null;
    if (b is! Terminal || b is Str && b.text.length != 1) return false;
    final q = j >= 0 ? j : (o!.first > at ? at : -1);
    final ch = q >= 0
        ? (q < _len ? parser.input.codeUnitAt(q) : -1)
        : _apply(parser.input, _edits(o!)).elementAtOrNull(at)?.$2 ?? -1;
    return ch >= 0 && _spans(b).any((r) => ch >= r.$1 && ch <= r.$2);
  }

  Iterable<(int, int)> _spans(Clause c) => switch (c) {
        Str(:final text) || Char(char: final text) => text.codeUnits.map((x) => (x, x)),
        CharSet(:final ranges, :final inverted) => [...ranges, if (inverted) (0, 0xffff)],
        AnyChar() => [(0, 0xffff)],
        HasOneSubClause() => _spans(c.subClause),
        HasMultipleSubClauses() => c.subClauses.expand(_spans),
        _ => const []
      };

  bool _pureSub(_Way w) => w.owed == 0 && !w.clean && w.piece is! SyntaxError && _ev(w.piece as Match) == (_len + 1) * w.spent;

  List<(int, int, int)> _edits(_Way w) {
    final out = <(int, int, int)>[];
    for (final todo = <MatchResult>[if (!w.clean) w.piece as Match]; todo.isNotEmpty;)
      switch (todo.removeLast()) {
        case Match(subClauseMatches: [final a, final b]):
          todo.addAll([b, a]);
        case Match(:final pos, :final len, clause: final Terminal t):
          out.add((len + 1, pos, _code(t)));
        case Match(:final pos, :final len):
          for (var q = pos; q < pos + len; q++) out.add((0, q, 0));
      }
    return out;
  }

  MatchResult recover(String input) {
    _cells.clear();
    _mins.clear();
    final hw = parser.rules.values.expand(_spans).any((r) => r.$2 == 0xffff);
    var g = 1, deep = false, best = null as (_Way, MatchResult, List<(int, int)>)?;
    int marks(List<(int, int)> t) => _len - t.where((x) => x.$1 >= 0).length + t.where((x) => x.$1 == -1).length;
    int ev(MatchResult root, List<(int, int)> t, _Way w) {
      var n = w.spent > 0 ? -w.owed : 0;
      if (!hw) return n + t.where((e) => e.$1 >= 0).length;
      for (final st = [root]; st.isNotEmpty;) {
        final m = st.removeLast();
        if (m.subClauseMatches.isNotEmpty)
          st.addAll(m.subClauseMatches);
        else if (_lit(m.clause)) for (var q = m.pos; q < m.pos + m.len; q++) if (t[q].$1 >= 0) n++;
      }
      return n;
    }

    bool sweep(void Function(Clause, int) fn, [int m = -1, int step = 0]) {
      for (var n = m < 0 ? _len : m, p = n; p >= 0; p -= step > 0 ? step : (n + 1).bitLength)
        for (final r in parser.rules.values) if (r is! Ref) fn(r, p);
      return true;
    }

    (Parser, MatchResult) parse(String w) {
      for (var step = (w.length + 1).bitLength, warm = false;; warm = true) {
        final p = Parser(rules: parser.rules, topRuleName: parser.topRuleName, input: w);
        try {
          if (warm) deep = sweep(p.match, w.length, step);
          return (p, p.matchRule(parser.topRuleName, 0));
        } on StackOverflowError {
          if (warm && (step >>= 1) < 1) rethrow;
        }
      }
    }

    final (p0, verdict) = parse(input);
    parser = p0;
    if (!verdict.isMismatch && verdict.len == _len) {
      lastCost = 0;
      return verdict;
    }
    _Way.maxOwed =
        parser.rules.values.fold(0, (a, r) => a + switch (_min0(r)) { final n when n < _never => n, _ => 0 });
    final ceiling = _min0(_top) == _never ? -1 : _len + 1;
    void run(int rung) {
      if (g > 0) g = rung;
      try {
        if (deep) sweep((r, p) => parser.getMemoEntry(r, p) != null ? _read(r, p, rung, null, g, hw) : null);
        for (final r in _read(_top, 0, rung, null, g, hw).$1) {
          final w = _len == r.end ? r : r.then(_Way.skip(r.end, _len));
          if ((g <= 0 ? w.rem(rung) < 0 : w.cost > rung) || best != null && w.cost > best!.$1.cost) continue;
          final s = _apply(input, _edits(w)), str = String.fromCharCodes(s.map((x) => x.$2)), m = parse(str).$2;
          if (m.isMismatch || m.len != str.length) continue;
          final d = best == null || w.cost < best!.$1.cost ? 1 : ev(m, s, w) - ev(best!.$2, best!.$3, best!.$1);
          if (d > 0 || d == 0 && _cmp(w, best!.$1, hw, false, marks(s) - marks(best!.$3)) < 0) best = (w, m, s);
        }
      } on StackOverflowError {
        if (deep) rethrow;
        deep = true;
        _cells.clear();
        run(rung);
      }
    }

    for (var b = 1; best == null && b < 2 * ceiling;)
      if (b > 2 && g >= 0) {
        _cells.clear();
        g = g > 0 ? 0 : -1;
        b = 1;
      } else {
        run(_min(b, ceiling));
        b *= 2;
      }
    if (best?.$1.cost case final c? when c > 1 && _len * c < 2048) {
      final r = c - 1, m = r > 8 && !_acyclic(_top) && c * 3 < _len * 2, b = m && g == 0 ? 4 : r;
      g = g > 0 || m ? 0 : r;
      _cells.clear();
      run(b);
    }
    late final cs = {
          ...parser.rules.values.expand(_spans).expand((r) => [r.$1, if (r.$2 != r.$1 && r.$2 < 0xffff) r.$2]),
          ...input.codeUnits
        },
        chs = [for (final c in cs) (c, String.fromCharCode(c))],
        fbCap = (_len + cs.length) * (cs.length + 1) * (cs.length + 1);
    final bw = best?.$1;
    var fb = bw == null ? null : (bw.cost + (bw.spent > 0 && marks(best!.$3) > bw.cost ? 1 : 0), best!.$2, best!.$3);
    final seen = {input}, q = <(String, List<(int, int)>, int, int, int)>[];
    if (best == null || _len <= 12 && fb!.$1 > 1)
      q.add((input, _apply(input, const []), 0, 0, _far(verdict, parser, {})));
    for (var qi = 0; qi < q.length && (fb == null || q[qi].$3 + 1 < fb!.$1 && seen.length < fbCap); qi++) {
      final (str0, s, d, k, u) = q[qi];
      bool step(String str, int j, int op, int c) {
        if (fb != null && (d + 1 >= fb!.$1 || seen.length >= fbCap)) return false;
        if (!seen.add(str)) return true;
        final (p, m) = parse(str);
        final enq = seen.length < fbCap && (fb == null || d + 2 < fb!.$1),
            hit = !m.isMismatch && (fb == null || _len - m.len < fb!.$1);
        if (!hit && !enq) return true;
        final i = op == 0 ? j : j - 1,
            n = [...s.sublist(0, i), if (op > 0) (op == 1 ? -1 : -2 - s[i].$1, c), ...s.sublist(op == 1 ? i : i + 1)];
        if (hit) {
          final t = m.len == n.length ? n : n.sublist(0, m.len), e = marks(t);
          if (fb == null || e < fb!.$1) if ((m.len == n.length ? m : parse(str.substring(0, m.len)).$2) case final w
              when !w.isMismatch && w.len == t.length) fb = (e, w, t);
        }
        if (enq) q.add((str, n, d + 1, j, _far(m, p, {})));
        return true;
      }

      var go = true;
      for (var i = k; go && i < s.length && i <= u; i++)
        go = step(str0.substring(0, i) + str0.substring(i + 1), i, 0, 0);
      for (var op = 2; go && op >= 1; op--)
        for (var i = k; go && i <= s.length - (op - 1) && i <= u; i++) {
          final pre = str0.substring(0, i), suf = str0.substring(i + op - 1);
          for (final (c, ch) in chs) if ((op == 1 || c != s[i].$2) && !(go = step('$pre$ch$suf', i + 1, op, c))) break;
        }
    }
    if (fb case (_, final w, var t)?) {
      var d = _len - t.length, u = d < 0 ? t : [for (final (_, c) in t) (input.codeUnitAt(d) == c ? d++ : -2 - d++, c)];
      lastCost = marks(marks(u) < marks(t) ? t = u : t);
      return _map(w, t, input);
    }
    lastCost = _len == 0 ? 1 : _len;
    return SyntaxError(pos: 0, len: _len);
  }

  static int _code(Terminal t) => t is Str
      ? t.text.codeUnitAt(0)
      : (t is Char ? t.char.codeUnitAt(0) : (t is CharSet && !t.inverted && t.ranges.isNotEmpty ? t.ranges[0].$1 : 32));

  static List<(int, int)> _apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[];
    for (var i = 0, j = 0; i <= input.length; i++) {
      var ch = i < input.length ? input.codeUnitAt(i) : -1, k = i;
      for (; j < es.length && es[j].$2 == i; j++)
        if (es[j].$1 == 1)
          out.add((-1, es[j].$3));
        else {
          ch = es[j].$1 == 0 ? -1 : es[j].$3;
          k = -2 - i;
        }
      if (ch >= 0) out.add((k, ch));
    }
    return out;
  }

  int _far(MatchResult m, Parser p, Set<(Clause, int)> s) => [
        m.pos + m.len,
        for (final c in switch (m.clause) {
          final HasOneSubClause h when m.subClauseMatches.isEmpty || h is Repetition => [h.subClause],
          First(:final subClauses) when !m.isMismatch => subClauses.takeWhile((c) => p.match(c, m.pos).isMismatch),
          _ => const <Clause>[]
        })
          if (m.pos + (m.clause is First ? 0 : m.len) case final q when s.add((c, q))) _far(p.match(c, q), p, s),
        for (final c in m.subClauseMatches) _far(c, p, s)
      ].reduce((a, b) => a > b ? a : b);

  MatchResult _map(MatchResult root, List<(int, int)> s, String input) {
    final orig = List.filled(s.length + 1, input.length), todo = <void Function()>[], ts = <MatchResult>[];
    var next = 0;
    for (var q = s.length - 1; q >= 0; q--)
      orig[q] = s[q].$1 == -1 ? orig[q + 1] : (s[q].$1 < 0 ? -2 - s[q].$1 : s[q].$1);
    void gap(int o, List<MatchResult> into) {
      if (o <= next) return;
      into.add(SyntaxError(pos: next, len: o - next));
      next = o;
    }

    MatchResult letter(Clause l, int q, [bool own = false]) {
      final o = orig[q], t = s[q].$1;
      if (t == -1) return Match(l, o, 0, subClauseMatches: [SyntaxError(pos: o, len: 0)]);
      next = o + 1;
      final e = SyntaxError(pos: o, len: 1);
      return t >= 0 ? Match(l, o, 1) : (own ? Match(First([l]), o, 1, subClauseMatches: [e]) : e);
    }

    void walk(MatchResult m, List<MatchResult> into, [Clause? up]) {
      final c = m.clause, kids = <MatchResult>[], o = orig[m.pos];
      if (m.len > 0) gap(o, into);
      if (m.len > 0 && m.subClauseMatches.isEmpty) {
        if (s.skip(m.pos).take(m.len).indexed.every((x) => x.$2.$1 == o + x.$1)) {
          next = o + m.len;
          return into.add(Match(c, o, m.len));
        }
        if (m.len == 1) return into.add(letter(c!, m.pos, up == null || up is Ref));
        for (var q = m.pos; q < m.pos + m.len; q++) {
          gap(orig[q], kids);
          kids.add(letter(Char((c as Str).text[q - m.pos]), q));
        }
        return into.add(Match(c, o, next - o, subClauseMatches: kids));
      }
      todo.add(() => into.add(Match(
          m.len > 0 && o >= input.length ? null : c, m.len == 0 ? _min(o, next) : o, m.len == 0 ? 0 : next - o,
          subClauseMatches: kids)));
      for (final k in m.subClauseMatches.reversed) todo.add(() => walk(k, kids, c));
    }

    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) todo.removeLast()();
    gap(input.length, ts);
    return ts.length == 1 ? ts.single : Match(null, 0, 0, subClauseMatches: ts);
  }
}
