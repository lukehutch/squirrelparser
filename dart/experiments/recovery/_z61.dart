import 'package:squirrel_parser/squirrel_parser.dart';

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

// Dirty pieces are real Match trees of edit leaves. Their native spans locate edits.
// prev is the actual EOF-only edit suffix, absent when the whole fragment is EOF-only.
class _Way {
  static int maxOwed = _never;
  static int _ex(int o) => o > maxOwed ? o - maxOwed : 0;
  const _Way(this.end, [this.edits = 0, this.used = 0, this.evidence = 0, this.piece, this.prev]);
  _Way.skip(int a, int b) : this(b, b - a, b - a, 0, SyntaxError(pos: a, len: b - a));
  final int end, edits, used, evidence;
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
    var p = r.clean && !preferred || !clean ? piece : r.piece, t = clean ? r.prev : prev;
    if (!clean && !r.clean) {
      p = Match(null, 0, 0, subClauseMatches: [piece as Match, r.piece as Match]);
      t = o2 == 0 ? null : prev?.then(r.prev!) ?? r.prev!;
    }
    return _Way(r.end, edits + r.edits, u, evidence + r.evidence, p, t);
  }

  int cmp(_Way b) {
    if (cost != b.cost) return cost - b.cost;
    if (evidence != b.evidence) return b.evidence - evidence;
    if (edits != b.edits) return edits - b.edits;
    return first != b.first ? b.first - first : last - b.last;
  }
}

class _Cell {
  var mark = -1, ends = <_Way>[];
  bool add(_Way r, int rung, [int b = _never]) {
    if (r.rem(b) < 0 || rung > 0 && r.cost > rung) return false;
    var i = 0;
    for (var hi = ends.length, mid = 0; i < hi;) ends[mid = (i + hi) >> 1].end > r.end ? hi = mid : i = mid + 1;
    for (var j = i; j > 0 && ends[j - 1].end == r.end; j--) {
      final a = ends[j - 1];
      if (a.owed == r.owed && (rung <= 0 ? a.last == r.last : a.first == r.first)) {
        final c = a.cmp(r);
        if (c > 0 || c == 0 && r.owed == 0) ends[j - 1] = r;
        return c > 0;
      }
    }
    ends.insert(i, r);
    return true;
  }
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
  _Way _plain(Clause c, int p) => switch (parser.match(c, p)) { final m => _Way(p + m.len, 0, 0, _ev(m)) };
  int _end(Clause c, int p) => switch (parser.match(c, p)) { final m when !m.isMismatch => p + m.len, _ => -1 };
  int _ev(MatchResult m) => _mins[m] ??= m.subClauseMatches.isEmpty
      ? (m.clause is Str || m.clause is Char || m.clause is CharSet && !(m.clause as CharSet).inverted ? m.len : 0)
      : m.subClauseMatches.fold(0, (a, x) => a + _ev(x));

  bool _oneShape(Clause c, [Set<Clause>? s]) =>
      (s ??= {}).add(c) &&
      switch (c) {
        Seq() => c.subClauses.every((x) => _oneShape(x, s)),
        Repetition() => c.requireOne && _oneShape(c.subClause, s),
        Ref() => _oneShape(_rule(c), s),
        Terminal() || FollowedBy() || NotFollowedBy() => true,
        _ => false
      };

  int _min0(Clause c, [Set<(Clause, bool)>? p, bool req = false]) {
    if (!(p ??= {}).add((c, req))) return _never;
    final n = switch (c) {
      Seq() => c.subClauses.fold(0, (a, b) => _min(_never, a + _min0(b, p))),
      First() => c.subClauses.fold(_never, (a, b) => _min(a, _min0(b, p, req))),
      Ref() => _min0(_rule(c), p, req),
      Repetition() when c.requireOne || req => _min0(c.subClause, p, true),
      Optional() when req => _min0(c.subClause, p, true),
      Str() => c.text.length,
      Char() || CharSet() || AnyChar() => 1,
      _ => req ? _never : 0
    };
    p.remove((c, req));
    return n;
  }

  _Res _read(Clause c, int p, int b, List<Clause>? ac, int g, [List<_Cell>? k, bool delta = false]) {
    if (c is Ref) return _read(_rule(c), p, b, ac, g, k, delta);
    final e0 = _end(c, p), pe = e0 < 0 ? p : e0;
    var ms = _never, cd = _never, minJ = pe + 1, all = null as List<_Way>?;
    if (b == 0 && p < _len) return (e0 < 0 ? const [] : [_plain(c, p)], _never);
    if (c is FollowedBy || c is NotFollowedBy) return ([e0 < 0 ? _Way(p, 0, 0, 0, c) : _plain(c, p)], _never);
    if (c is Terminal) {
      if (e0 >= 0) return ([_plain(c, p)], _never);
      if (c is Str && c.text.length > 1) return _seq([for (final ch in c.text.split('')) Char(ch)], p, b, ac, g, k);
      final o = p < _len ? null : _Way(0, 1, 0, 0, Match(c, p, 0)), u = p < _len ? 1 : _Way._ex(1);
      return ([for (var d = 0; d <= (p < _len ? 1 : 0); d++) _Way(p + d, 1, u, 0, Match(c, p, d), o)], _never);
    }
    final cell = _cells[parser.getMemoEntry(c, p)!] ??= _Cell(), idx = ac?.indexOf(c) ?? -1;
    if (idx >= 0) {
      cd = idx + 1;
    } else if (cell.mark < b) {
      final a = ac ?? <Clause>[], d = a.length + 1;
      var inner = <_Cell>[];
      a.add(c);
      all = [];
      for (var step = <_Way>[], ns = <_Way>[];; step = [], ns = []) {
        for (final x in inner) x.mark = -1;
        final (props, cm) = _propose(c, p, b, a, g, all.isNotEmpty, inner = []);
        for (final r in props)
          if ((!r.clean || r.end <= pe || r.preferred && cm < _never) && cell.add(r, g)) step.add(r);
        for (final r in step) {
          final ts = g <= 0 && cm == d && (r.synced(p, 0) || _pureSub(r)) ? _cells[(c, r.end)]?.ends : null;
          if (ts == null || ts.isEmpty) ns.add(r);
          for (final s in ts ?? const <_Way>[])
            if (r.then(s, true) case final w when cell.add(w, 0, b)) {
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
      if (g <= 0 && ms == d && pe > p) {
        final ev0 = _ev(parser.match(c, p));
        (_cells[(c, pe)] ??= _Cell()).ends = [
          for (final w in cell.ends)
            if (w.end >= minJ && w.first > pe) _Way(pe, 0, 0, -ev0).then(w, true)
        ];
      }
      cell.mark = b;
      if (ms < d) {
        k?.addAll([cell, ...inner]);
        cd = ms;
      }
    }
    return ((_cells[(c, p)]?.ends ?? (delta ? all ?? const [] : cell.ends)).where((r) => r.rem(b) >= 0).toList(), cd);
  }

  bool _active(Clause? c, List<Clause>? ac) =>
      ac != null && (c is Ref ? ac.contains(_rule(c)) : c is First && c.subClauses.any((x) => _active(x, ac)));

  List<Clause> _flat(List<Clause> s) => s.any((x) => x is Seq) && !s.any((x) => x is HasOneSubClause)
      ? s.expand((x) => x is Seq ? _flat(x.subClauses) : [x]).toList()
      : s;

  _Res _propose(Clause c, int p, int b, List<Clause>? ac, int g, bool d, List<_Cell> k) {
    if (c is Seq) return _seq(_flat(c.subClauses), p, b, ac, g, k);
    if (c is Repetition) return _repeat(c, p, b, ac, g, k);
    if (c is Optional) {
      final (rs, cd) = _read(c.subClause, p, b, ac, g, k);
      return ([_Way(p, 0, 0, 0, rs.any((r) => r.preferred && r.end > p) ? c : null), ...rs], cd);
    }
    var out = <_Way>[], m = _never;
    for (final s in (c as First).subClauses) {
      final (w, cd) = _read(s, p, b, ac, g, k, d);
      m = _min(m, cd);
      out.addAll(w);
      if (_total(s)) break;
    }
    return (out, m);
  }

  bool _total(Clause c) => switch (c) {
        Repetition(requireOne: false) || Optional() || Str(text: '') => true,
        Seq() => c.subClauses.every(_total),
        First() => c.subClauses.any(_total),
        Ref() => _acyclic(c) && _total(_rule(c)),
        _ => false
      };

  bool _acyclic(Clause c, [Map<Clause, bool>? seen]) {
    if ((seen ??= {})[c] case final known?) return known;
    seen[c] = false;
    return seen[c] = switch (c) {
      Ref() => _acyclic(_rule(c), seen),
      HasOneSubClause() => _acyclic(c.subClause, seen),
      HasMultipleSubClauses() => c.subClauses.every((x) => _acyclic(x, seen)),
      _ => true
    };
  }

  bool _startsClean(Clause c, int at, [Set<Clause>? s]) =>
      (s ??= {}).add(c) &&
      switch (c) {
        Ref() => _startsClean(_rule(c), at, s),
        First() => c.subClauses.any((x) => _startsClean(x, at, s)),
        Seq() => _flat(c.subClauses).take(1).any((x) => _end(x, at) > at),
        Terminal() => _end(c, at) > at,
        _ => false
      };

  _Res _seq(List<Clause> slots, int p, int b, List<Clause>? ac, int g, [List<_Cell>? k]) {
    var cur = [_Way(p)], opt = <_Way>{}, cd = _never;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1, l = g <= 0;
      for (final r in cur.reversed) {
        final same = r.end == p,
            a = same ? ac : null,
            sub = l && _pureSub(r),
            ev = r.end - p - r.spent,
            ps = sub && r.first > p && ev > r.spent,
            sync = l && (last ? r.synced(p) || sub && (ev > 0 || r.spent == 1 && _startsClean(s, r.end)) : ps),
            canS = s is! Terminal ? sync : ps && (!last || r.spent <= i + _min0(_top));
        final (options, rcd) = _read(s, r.end, r.rem(b, canS), a, g, same ? k : null);
        if (same) cd = _min(cd, rcd);
        var del = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final sk = last && sync;
          var j = r.end + 1, to = _min(r.end + r.rem(b, sk), _len);
          while (j <= to && _end(s, j) <= j) j++;
          if (j <= to && (i == 0 || !_takes(slots[i - 1], opt.contains(r), r.end, null, j))) {
            final m = _plain(s, j);
            next.add(r.then(_Way.skip(r.end, j), sk).then(m), g);
            if (!last && _end(slots[i + 1], m.end) >= 0) del = j - r.end;
          }
        }
        final pen = del > 0 && !_active(s, a) && !_oneShape(s);
        for (final o in options) {
          if (o.end == r.end && pen && del <= o.spent ||
              i > 0 &&
                  (!o.clean || r.piece is Optional && o.end > r.end) &&
                  _takes(slots[i - 1], opt.contains(r), r.end, o)) continue;
          final st = canS &&
              (sub && _pureSub(o) || o.synced(r.end, o.owed > 0 ? -1 : 0));
          final w = r.then(o, st);
          if (o.end == r.end && o.clean) opt.add(w);
          next.add(w, g, b);
        }
      }
      if ((cur = next.ends).isEmpty) break;
    }
    return (cur, cd);
  }

  _Res _repeat(Repetition c, int p, int b, List<Clause>? ac, int g, [List<_Cell>? k]) {
    final s = c.subClause, best = _Cell(), q = {p: _Way(p)}, u = !_active(s, ac) && _min0(s) == 1;
    var cd = _never;
    bool syncs(_Way w) => _end(s, w.end) > w.end;
    while (q.isNotEmpty) {
      final r = q.remove(q.keys.reduce(_min))!, same = r.end == p;
      final sub = g <= 0 && u && _pureSub(r), cs = g <= 0 && (sub || r.synced(p, g < 0 || u ? 0 : 1));
      final (ss, rcd) = _read(s, r.end, r.rem(b, cs), same ? ac : null, g, same ? k : null);
      if (same) cd = _min(cd, rcd);
      final any = cs && ss.any((w) => w.end > r.end && syncs(w));
      for (final w in ss) {
        if (w.end <= r.end) {
          if (same && !w.clean) best.add(w, g);
          continue;
        }
        final st = cs &&
            !w.clean &&
            (g < 0 && u && r.synced(p, 0) ||
                (syncs(w) || !any) && w.synced(r.end, -1));
        if (r.then(w, st) case final x when best.add(x, g, b)) if ((q[x.end]?.cmp(x) ?? 0) >= 0) q[x.end] = x;
      }
    }
    if (!c.requireOne) best.add(_Way(p), g);
    return (best.ends.where((r) => g > 0 || _end(s, r.end) <= r.end).toList(), cd);
  }

  bool _takes(Clause s, bool opt, int at, _Way? o, [int j = -1]) {
    final b = s is Repetition || opt && s is Optional ? (s as HasOneSubClause).subClause : null;
    if (b is! Terminal || b is Str && b.text.length != 1) return false;
    final q = j >= 0 ? j : (o!.first > at ? at : -1),
        ch = q >= 0 ? (q < _len ? parser.input.codeUnitAt(q) : -1) : _apply(parser.input, _edits(o!)).elementAtOrNull(at)?.$2 ?? -1;
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

  bool _pureSub(_Way w) => w.owed == 0 && !w.clean && _ev(w.piece as Match) == w.spent;
  List<(int, int, int)> _edits(_Way w) {
    final todo = <MatchResult>[if (!w.clean) w.piece as Match], out = <(int, int, int)>[];
    while (todo.isNotEmpty)
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
    var g = 1, deep = false, best = null as (_Way, MatchResult, List<(int, int)>)?;
    bool sweep(void Function(Clause, int) fn, [int m = -1]) {
      for (var n = m < 0 ? _len : m, p = n; p >= 0; p -= (n + 1).bitLength)
        for (final r in parser.rules.values) if (r is! Ref) fn(r, p);
      return true;
    }

    (Parser, MatchResult) parse(String w, [bool s = false]) {
      final p = Parser(rules: parser.rules, topRuleName: parser.topRuleName, input: w);
      if (s) deep = sweep(p.match, w.length);
      try {
        return (p, p.matchRule(parser.topRuleName, 0));
      } on StackOverflowError {
        return parse(w, true);
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
        if (deep) sweep((r, p) => _read(r, p, rung, null, g));
        for (final r in _read(_top, 0, rung, null, g).$1) {
          final w = _len == r.end ? r : r.then(_Way.skip(r.end, _len));
          if ((g <= 0 ? w.rem(rung) < 0 : w.cost > rung) || best != null && w.cmp(best!.$1) >= 0) continue;
          final s = _apply(input, _edits(w)), str = String.fromCharCodes(s.map((x) => x.$2)), m = parse(str, deep).$2;
          if (!m.isMismatch && m.len == str.length) best = (w, m, s);
        }
      } on StackOverflowError {
        parser = parse(input, true).$1;
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
    if (best?.$1.cost case final c? when c > 1) {
      final r = c - 1, l = _Way.maxOwed > 2 || c * 3 < _len * 2, m = r > 8 && l, b = m && g == 0 ? 4 : r;
      if (_len * c < 2048) {
        g = g > 0 || m ? 0 : r;
        _cells.clear();
        run(b);
      }
    }
    late final cs = {
          ...parser.rules.values.expand(_spans).expand((r) => [r.$1, if (r.$2 != r.$1 && r.$2 < 0xffff) r.$2]),
          ...input.codeUnits
        },
        fbCap = (_len + cs.length) * (cs.length + 1) * (cs.length + 1);
    int marks(List<(int, int)> t) => _len - t.where((x) => x.$1 >= 0).length + t.where((x) => x.$1 == -1).length;
    var fb = best == null ? null : (best!.$1.cost, best!.$2, best!.$3);
    Iterable<(List<(int, int)>, int)> next(List<(int, int)> s, int k, int u) sync* {
      for (var i = k; i < s.length && i <= u; i++) yield ([...s.sublist(0, i), ...s.sublist(i + 1)], i);
      for (var i = k; i < s.length && i <= u; i++)
        for (final c in cs)
          if (c != s[i].$2) yield ([...s.sublist(0, i), (-2 - s[i].$1, c), ...s.sublist(i + 1)], i + 1);
      for (var i = k; i <= s.length && i <= u; i++)
        for (final c in cs) yield ([...s.sublist(0, i), (-1, c), ...s.sublist(i)], i + 1);
    }

    final seen = {input},
        q = [if (best == null || _len <= 12 && fb!.$1 > 1) (_apply(input, const []), 0, 0, _far(verdict, parser, {}))];
    for (var qi = 0; qi < q.length && (fb == null || q[qi].$2 + 1 < fb.$1 && seen.length < fbCap); qi++) {
      final (s, d, k, u) = q[qi];
      for (final (n, j) in next(s, k, u)) {
        if (fb != null && (d + 1 >= fb.$1 || seen.length >= fbCap)) break;
        final str = String.fromCharCodes(n.map((x) => x.$2));
        if (!seen.add(str)) continue;
        final (p, m) = parse(str);
        final t = m.isMismatch ? n : n.sublist(0, m.len), e = marks(t);
        if (!m.isMismatch && (fb == null || e < fb.$1)) if ((m.len == n.length ? m : parse(str.substring(0, m.len)).$2)
            case final w when !w.isMismatch && w.len == t.length) fb = (e, w, t);
        if (seen.length < fbCap && (fb == null || d + 2 < fb.$1)) q.add((n, d + 1, j, _far(m, p, {})));
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

  static int _code(Terminal t) => switch (t) {
        Str(:final text) || Char(char: final text) => text.codeUnitAt(0),
        CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => ranges[0].$1,
        _ => 32
      };

  static List<(int, int)> _apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[];
    for (var i = 0, j = 0; i <= input.length; i++) {
      var ch = i < input.length ? input.codeUnitAt(i) : -1, k = i;
      for (; j < es.length && es[j].$2 == i; j++)
        if (es[j].$1 == 1)
          out.add((-1, es[j].$3));
        else if (es[j].$1 == 0)
          ch = -1;
        else {
          ch = es[j].$3;
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
      if (t >= 0) return Match(l, o, 1);
      final e = SyntaxError(pos: o, len: 1);
      return own ? Match(First([l]), o, 1, subClauseMatches: [e]) : e;
    }

    void walk(MatchResult m, List<MatchResult> into, [Clause? up]) {
      final c = m.clause, kids = <MatchResult>[], o = orig[m.pos];
      if (m.len == 0)
        todo.add(() => into.add(Match(c, _min(o, next), 0, subClauseMatches: kids)));
      else {
        gap(o, into);
        if (m.subClauseMatches.isEmpty) {
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
        todo.add(() => into.add(Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)));
      }
      todo.addAll([for (final k in m.subClauseMatches.reversed) () => walk(k, kids, c)]);
    }

    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) todo.removeLast()();
    gap(input.length, ts);
    return ts.length == 1 ? ts.single : Match(null, 0, 0, subClauseMatches: ts);
  }
}
