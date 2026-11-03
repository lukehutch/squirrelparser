import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

// Dirty pieces are real Match trees of edit leaves. Their native spans locate edits.
// prev is the actual EOF-only edit suffix, absent when the whole fragment is EOF-only.
class _Way {
  static int maxOwed = _never, len = _never;
  static int _ex(int o) => o > maxOwed ? o - maxOwed : 0;
  const _Way(this.end, this.edits, this.used, this.evidence, [this.piece, this.prev]);
  const _Way.clean(int end, [int ev = 0, Object? piece]) : this(end, 0, 0, ev, piece);
  _Way.skip(int a, int b) : this(b, b - a, b - a, 0, peg.SyntaxError(pos: a, len: b - a));
  final int end, edits, used, evidence;
  final Object? piece;
  final _Way? prev;
  bool get clean => edits == 0;
  bool get preferred => clean && piece is! peg.Clause;
  int get owed => clean ? 0 : prev?.edits ?? (first == len ? edits : 0);
  int get spent => edits - owed;
  int get cost => spent + (owed == 0 ? 0 : _ex(owed) + (maxOwed == 0 ? 0 : 1));
  int get first => clean ? _never : (piece as peg.Match).pos;
  int get last => clean ? -1 : (piece as peg.Match).pos + (piece as peg.Match).len;
  int rem(int b, [bool s = false]) => s ? b : b - used;
  int absorbed(int a) => end - a - evidence - spent;
  bool synced(int a, [int g = 1]) => (g < 0 || spent > 0 && end > last + g) && evidence > absorbed(a) + 1;
  _Way then(_Way r, [bool s = false]) {
    final o1 = owed, o2 = r.owed, u = (s ? 0 : used) + r.used + _ex(o1 + o2) - (s ? 0 : _ex(o1)) - _ex(o2);
    var p = r.clean && !preferred || !clean ? piece : r.piece, t = clean ? r.prev : prev;
    if (!clean && !r.clean) {
      p = peg.Match(null, 0, 0, subClauseMatches: [piece as peg.Match, r.piece as peg.Match]);
      t = o2 == 0 || first == len ? null : prev?.then(r.prev ?? r) ?? r.prev ?? r;
    }
    return _Way(r.end, edits + r.edits, u, evidence + r.evidence, p, t);
  }

  int cmp(_Way b) {
    if (cost != b.cost || evidence != b.evidence) return cost != b.cost ? cost - b.cost : b.evidence - evidence;
    if (edits != b.edits) return edits - b.edits;
    return first != b.first ? b.first - first : last - b.last;
  }
}

class _Cell {
  var mark = -1, dep = 0, ends = <_Way>[], fresh = null as List<_Way>?;
  bool add(_Way r, int rung, [int b = _never]) {
    if (r.rem(b) < 0 || rung > 0 && r.cost > rung) return false;
    if (rung > 8 && _Way.len * ends.length > _never >> 18) throw '';
    bool cov(_Way a, _Way b) => a.owed == b.owed && (rung <= 0 || a.spent <= b.spent && a.used <= b.used);
    var i = ends.length;
    for (var j = i; j > 0 && ends[j - 1].end >= r.end; j--) {
      final a = ends[j - 1];
      if (a.end > r.end)
        i = j - 1;
      else if (rung <= 0 ? a.last == r.last : a.first == r.first) {
        final covered = cov(a, r), covers = cov(r, a), c = covered && covers ? a.cmp(r) : 0;
        if (covers && (!covered || c > 0 || c == 0 && (r.owed == 0 || r.prev == null))) ends[j - 1] = r;
        if (covered || covers) return covers && (!covered || c > 0);
      }
    }
    ends.insert(i, r);
    return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules;
  final String topRuleName;
  late peg.Parser parser;
  final _cells = <Object, _Cell>{}, _mins = <peg.MatchResult, int>{};
  String get path => lastCost == 0 ? 'plain' : 'checked';
  int lastCost = 0;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) =>
      switch (parser.match(c, pos)) { final m when !m.isMismatch => _Way.clean(pos + m.len, _ev(m), m), _ => null };

  int _end(peg.Clause c, int p) => switch (parser.match(c, p)) { final m when !m.isMismatch => p + m.len, _ => -1 };
  int _ev(peg.MatchResult m) => _mins[m] ??= switch (m.clause) {
        peg.Str() || peg.Char() || peg.CharSet(inverted: false) when m.subClauseMatches.isEmpty => m.len,
        _ => m.subClauseMatches.fold(0, (a, x) => a + _ev(x))
      };

  bool _oneShape(peg.Clause c, [Set<peg.Clause>? s]) =>
      (s ??= {}).add(c) &&
      switch (c) {
        peg.Seq() => c.subClauses.every((x) => _oneShape(x, s)),
        peg.Repetition() => c.requireOne && _oneShape(c.subClause, s),
        peg.Ref() => _oneShape(parser.rules[c.ruleName]!, s),
        peg.Terminal() || peg.FollowedBy() || peg.NotFollowedBy() => true,
        _ => false
      };
  int _min0(peg.Clause c) => _minChars(c, {});
  int _minChars(peg.Clause c, Set<(peg.Clause, bool)> p, [bool req = false]) {
    if (!p.add((c, req))) return _never;
    final n = switch (c) {
      peg.Seq() => c.subClauses.fold(0, (a, b) => _min(_never, a + _minChars(b, p))),
      peg.First() => c.subClauses.fold(_never, (a, b) => _min(a, _minChars(b, p, req))),
      peg.Ref() => _minChars(parser.rules[c.ruleName]!, p, req),
      peg.Repetition() when c.requireOne || req => _minChars(c.subClause, p, true),
      peg.Optional() when req => _minChars(c.subClause, p, true),
      peg.Str() => c.text.length,
      peg.Char() || peg.CharSet() || peg.AnyChar() => 1,
      _ => req ? _never : 0
    };
    p.remove((c, req));
    return n;
  }

  List<_Way> _read(peg.Clause c, int pos, int b, _Cell up, int g, [bool delta = false]) {
    final pl = _plain(c, pos), pe = pl?.end ?? pos;
    var ms = _never, minJ = pe + 1, all = null as List<_Way>?;
    if (b == 0 && pos < _len) return pl == null ? const [] : [pl];
    if (c is peg.FollowedBy || c is peg.NotFollowedBy) return [pl ?? _Way.clean(pos, 0, c)];
    if (c is peg.Terminal) {
      if (pl != null) return [pl];
      if (c is peg.Str && c.text.length > 1)
        return _seq([for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])], pos, b, up, g);
      return [
        _Way(pos, 1, pos == _len ? _Way._ex(1) : 1, 0, peg.Match(c, pos, 0)),
        if (pos < _len) _Way(pos + 1, 1, 1, 0, peg.Match(c, pos, 1))
      ];
    }
    if (c is peg.Ref) return _read(parser.rules[c.ruleName]!, pos, b, up, g, delta);
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell();
    if (cell.dep != 0) {
      up.mark = _min(up.mark, cell.dep);
    } else if (cell.mark < (b << 31 | ((_cells[pos]?.mark ?? -1) + 1))) {
      final d = cell.dep = up.dep + 1;
      all = [];
      for (var step = <_Way>[], ns = <_Way>[];; (_cells[pos] ??= _Cell()).mark++, step = [], ns = []) {
        cell.mark = _never;
        for (final r in _propose(c, pos, b, cell, g, all.isNotEmpty))
          if ((!r.clean || r.end <= pe || r.preferred && cell.mark < _never) && cell.add(r, g)) step.add(r);
        for (final r in step) {
          final ts =
              g <= 0 && cell.mark == d && (r.synced(pos, 0) || _pureSub(r, pos)) ? _cells[(c, r.end)]?.fresh : null;
          if (ts == null || ts.isEmpty) ns.add(r);
          for (final s in ts ?? const <_Way>[])
            if (r.then(s, true) case final w when cell.add(w, 0, b))
              (all..add(w), minJ = minJ == pe + 1 ? w.end : _min(minJ, w.end));
        }
        (ms = _min(ms, cell.mark), all..addAll(ns));
        if ((cell.fresh = ns.isEmpty || cell.mark != d ? null : ns) == null) break;
      }
      if (g <= 0 && ms == d && pe > pos)
        (_cells[(c, pe)] ??= _Cell()).fresh = [
          for (final w in cell.ends)
            if (w.end >= minJ && w.first > pe) _Way(w.end, w.edits, w.used, w.evidence - pl!.evidence, w.piece, w.prev)
        ];
      cell.mark = b << 31 | (ms < d ? (_cells[pos]?.mark ?? -1) + 1 : _never);
      (cell.dep = 0, up.mark = _min(up.mark, ms < d ? ms : _never));
    }
    return [
      for (final r in cell.fresh ?? (delta ? all : null) ?? cell.ends)
        if (r.rem(b) >= 0) r
    ];
  }

  bool _active(peg.Clause? c, int at) => switch (c) {
        peg.First(:final subClauses) => subClauses.any((x) => _active(x, at)),
        peg.Ref(:final ruleName) => (_cells[parser.getMemoEntry(parser.rules[ruleName]!, at)]?.dep ?? 0) != 0,
        _ => false
      };
  List<peg.Clause> _flat(List<peg.Clause> s) => s.any((x) => x is peg.Seq) && !s.any((x) => x is peg.HasOneSubClause)
      ? s.expand((x) => x is peg.Seq ? _flat(x.subClauses) : [x]).toList()
      : s;
  List<_Way> _propose(peg.Clause c, int pos, int b, _Cell up, int g, bool d) {
    if (c is peg.Seq) return _seq(_flat(c.subClauses), pos, b, up, g);
    if (c is peg.Repetition) return _repeat(c, pos, b, up, g);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos, b, up, g);
      return [_Way.clean(pos, 0, rs.any((r) => r.preferred && r.end > pos) ? c : null), ...rs];
    }
    var out = <_Way>[], cut = _never, sd = up.mark;
    for (final sub in (c as peg.First).subClauses) {
      final rs = _read(sub, pos, b, up, g, d), f = rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);
      for (final r in rs)
        if (cut == _never || (r.clean ? r.end < cut : r.first < cut)) (sd = _min(sd, up.mark), out..add(r));
      if (f > pos && up.mark == _never) cut = _min(cut, f);
      if (_total(sub)) break;
    }
    return (up.mark = sd, out).$2;
  }

  bool _total(peg.Clause c) => switch (c) {
        peg.Repetition(requireOne: false) || peg.Optional() || peg.Str(text: '') => true,
        peg.Seq() => c.subClauses.every(_total),
        peg.First() => c.subClauses.any(_total),
        peg.Ref() => _acyclic(c) && _total(parser.rules[c.ruleName]!),
        _ => false
      };

  bool _acyclic(peg.Clause c, [Map<peg.Clause, bool>? seen]) {
    if ((seen ??= {})[c] case final known?) return known;
    seen[c] = false;
    return seen[c] = switch (c) {
      peg.Ref() => _acyclic(parser.rules[c.ruleName]!, seen),
      peg.HasOneSubClause() => _acyclic(c.subClause, seen),
      peg.HasMultipleSubClauses() => c.subClauses.every((x) => _acyclic(x, seen)),
      _ => true
    };
  }

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) =>
      (s ??= {}).add(c) &&
      switch (c) {
        peg.Ref() => _startsClean(parser.rules[c.ruleName]!, at, s),
        peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
        peg.Seq(:final subClauses) =>
          subClauses.isNotEmpty && !_active(_flat(subClauses)[0], at) && _end(_flat(subClauses)[0], at) > at,
        peg.Terminal() => _end(c, at) > at,
        _ => false
      };

  List<_Way> _seq(List<peg.Clause> slots, int p, int b, _Cell up, int g) {
    var cur = [_Way.clean(p)], opt = <_Way>{};
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1, l = g <= 0;
      for (final r
          in (g == 1 ? [...cur.where((x) => !x.clean).toList().reversed, ...cur.where((x) => x.clean)] : cur)) {
        final sub = (l || s is peg.Repetition) && _pureSub(r, p),
            ev = sub ? r.end - p - r.spent : 0,
            sync = last && r.synced(p) ||
                l && sub && (last ? ev > 0 || r.spent == 1 && _startsClean(s, r.end) : ev > r.spent && r.first > p),
            rSub = sub &&
                (s is! peg.Terminal
                    ? !l || sync
                    : last
                        ? r.spent <= i + _min0(rules[topRuleName]!) && ev > r.spent && r.first == p + ev
                        : ev * 2 >= r.spent && r.first > p),
            canS = l && s is! peg.Terminal && sync || rSub;
        var options = _read(s, r.end, r.rem(b, canS), up, g), del = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final sk = last && sync && !_startsClean(s, r.end),
              j = _next(s, r.end + 1, r.end + r.rem(b, sk), options.any((o) => o.preferred) ? 1 : 0);
          if (j < _never) if (_plain(s, j) case final m?) {
            next.add(r.then(_Way.skip(r.end, j), sk).then(m), g);
            if (!last && _end(slots[i + 1], m.end) >= 0) del = j - r.end;
          }
        }
        final pen = del > 0 && !_active(s, r.end) && !_oneShape(s);
        for (final o in options) {
          if (o.end == r.end && pen && !o.clean && del <= o.spent ||
              i > 0 &&
                  (!o.clean || r.piece is peg.Optional && o.end > r.end) &&
                  _takes(slots[i - 1], opt.contains(r), o, r.end)) continue;
          final st = canS &&
              (rSub && _pureSub(o, r.end) ||
                  (l && r.end > r.last || o.first > r.end) && o.synced(r.end, l && o.owed > 0 ? -1 : 0));
          if (r.then(o, st) case final w) next.add(o.end == r.end && o.clean ? (opt..add(w)).last : w, g, b);
        }
      }
      if ((cur = next.ends).isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int p, int b, _Cell up, int g) {
    final sub = c.subClause,
        best = _Cell(),
        q = {p: _Way.clean(p)},
        unit = !_oneShape(sub) && !_active(sub, p) && _min0(sub) == 1;
    bool syncs(_Way s) => _end(sub, s.end) > s.end;
    while (q.isNotEmpty) {
      final r = q.remove(q.keys.reduce(_min))!;
      final rSub = unit && _pureSub(r, p), canS = rSub || r.synced(p, g < 0 || unit ? 0 : 1);
      final steps = _read(sub, r.end, r.rem(b, canS), up, g),
          anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
      for (final s in steps) {
        if (s.end <= r.end) continue;
        final settle = canS &&
            !s.clean &&
            (!anySync && rSub && s.end > r.end + s.spent && _pureSub(s, r.end) ||
                s.evidence > 1 && (syncs(s) || !anySync && s.evidence > s.absorbed(r.end)));
        if (r.then(s, settle) case final w when best.add(w, g, b)) if ((q[w.end]?.cmp(w) ?? 0) >= 0) q[w.end] = w;
      }
    }
    for (final r in _read(sub, p, b, up, g)) if (r.end == p && !r.clean) best.add(r, g);
    if (!c.requireOne) best.add(_Way.clean(p), g);
    return best.ends.where((r) => g > 0 || _end(sub, r.end) <= r.end).toList();
  }

  int _next(peg.Clause c, int j, int to, int test) {
    for (to = _min(to, _len); j <= to; j++) if (_end(c, j) >= (test == 0 ? 0 : j + 1)) return j;
    return _never;
  }

  bool _takes(peg.Clause s, bool opt, _Way o, int at) {
    final b = s is peg.Repetition || opt && s is peg.Optional ? (s as peg.HasOneSubClause).subClause : null;
    if (b is! peg.Terminal || b is peg.Str && b.text.length != 1) return false;
    final u = _apply(parser.input, o.first > at ? const [] : _edits(o));
    return at < u.length && _spans(b).any((r) => u[at].$2 >= r.$1 && u[at].$2 <= r.$2);
  }

  Iterable<(int, int)> _spans(peg.Clause c) => switch (c) {
        peg.Str(:final text) || peg.Char(char: final text) => text.codeUnits.map((x) => (x, x)),
        peg.CharSet(:final ranges, :final inverted) => [...ranges, if (inverted) (0, 0xffff)],
        peg.AnyChar() => [(0, 0xffff)],
        peg.HasOneSubClause() => _spans(c.subClause),
        peg.HasMultipleSubClauses() => c.subClauses.expand(_spans),
        _ => const []
      };

  bool _pureSub(_Way w, int a) => w.absorbed(a) == 0 && w.owed == 0 && !w.clean && _ev(w.piece as peg.Match) == w.spent;
  List<(int, int, int)> _edits(_Way w) {
    final todo = <peg.MatchResult>[if (!w.clean) w.piece as peg.Match], out = <(int, int, int)>[];
    while (todo.isNotEmpty)
      switch (todo.removeLast()) {
        case peg.Match(subClauseMatches: [final a, final b]):
          todo.addAll([b, a]);
        case peg.Match(:final pos, :final len, clause: final peg.Terminal t):
          out.add((len + 1, pos, _code(t)));
        case peg.Match(:final pos, :final len):
          for (var q = pos; q < pos + len; q++) out.add((0, q, 0));
      }
    return out;
  }

  int _reset() => (_cells..clear()).length;

  peg.MatchResult recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    (_reset(), _mins..clear());
    final top = parser.rules[topRuleName]!, ceiling = _min0(top) == _never ? -1 : _len + 1;
    var g = 1, deep = false, best = null as (_Way, peg.MatchResult, List<(int, int)>)?;
    _Way.len = _len;
    _Way.maxOwed = rules.values.fold(0, (a, r) => a + (_min0(r) < _never ? _min0(r) : 0));
    bool sweep(void Function(peg.Clause, int) fn, [int n = -1]) {
      for (var p = n < 0 ? _len : n; p >= 0; p -= ((n < 0 ? _len : n) + 1).bitLength)
        for (final r in parser.rules.values) if (r is! peg.Ref) fn(r, p);
      return true;
    }

    (peg.Parser, peg.MatchResult) parse(String w, [bool s = false]) {
      final p = peg.Parser(rules: rules, topRuleName: topRuleName, input: w);
      if (s) deep = sweep(p.match, w.length);
      try {
        return (p, p.matchRule(topRuleName, 0));
      } on StackOverflowError {
        return parse(w, true);
      }
    }

    final (p0, verdict) = parse(input);
    parser = p0;
    if (!verdict.isMismatch && verdict.len == _len) return (lastCost = 0, verdict).$2;
    (_Way, peg.MatchResult, List<(int, int)>)? run(int rung) {
      (_Way, peg.MatchResult, List<(int, int)>)? b;
      if (g > 0) g = rung;
      List<_Way> ways;
      try {
        if (deep) sweep((r, p) => _read(r, p, rung, _Cell(), g));
        ways = _read(top, 0, rung, _Cell(), g);
      } on StackOverflowError {
        (parser = parse(input, true).$1, _reset());
        sweep((r, p) => _read(r, p, rung, _Cell(), g));
        ways = _read(top, 0, rung, _Cell(), g);
      }
      for (var p = 0; p <= (g <= 0 ? 0 : _min(rung, _len)); p++)
        for (final r0 in p == 0 ? ways : _read(top, p, rung, _Cell(), g)) {
          final r = p == 0 ? r0 : _Way.skip(0, p).then(r0), w = _len == r.end ? r : r.then(_Way.skip(r.end, _len));
          if ((g <= 0 ? w.rem(rung) < 0 : w.cost > rung) || w.clean || b != null && w.cmp(b.$1) >= 0) continue;
          final s = _apply(input, _edits(w)), str = String.fromCharCodes(s.map((x) => x.$2)), m = parse(str, deep).$2;
          if (!m.isMismatch && m.len == str.length) b = (w, m, s);
        }
      return b;
    }

    for (var b = 1; best == null && b < 2 * ceiling;)
      if (b > 2 && g >= 0)
        (_reset(), g = g > 0 ? 0 : -1, b = 1);
      else
        (best = run(_min(b, ceiling)), b *= 2);
    if (best != null && g <= 0 && best.$1.cost > 2 && _len * best.$1.cost < _never >> 20) {
      (g = best.$1.cost - 1, _reset());
      try {
        best = run(g) ?? best;
      } on String {}
    }
    late final cs = rules.values.expand(_spans).expand((r) => [r.$1, if (r.$2 < 0xffff) r.$2 + 1]).toSet(),
        fbCap = (_len + cs.length) * (cs.length + 1) * 16;
    final seen = {input}, q = [if (best == null) (_apply(input, const []), 0, 0, _never)];
    int marks(List<(int, int)> t) => _len - t.where((x) => x.$1 >= 0).length + t.where((x) => x.$1 == -1).length;
    (int, peg.MatchResult, List<(int, int)>)? fb = best == null ? null : (0, best.$2, best.$3);
    for (var qi = 0; qi < q.length && (fb == null || q[qi].$2 + 1 < fb.$1 && seen.length < fbCap); qi++) {
      final (s, d, k, u) = q[qi];
      for (final (n, j) in [
        for (var i = k; i < s.length && i <= u; i++) ([...s.sublist(0, i), ...s.sublist(i + 1)], i),
        for (var i = k; i < s.length && i <= u; i++)
          for (final c in cs) ([...s.sublist(0, i), (-2 - s[i].$1, c), ...s.sublist(i + 1)], i + 1),
        for (var i = k; i <= s.length && i <= u; i++)
          for (final c in cs) ([...s.sublist(0, i), (-1, c), ...s.sublist(i)], i + 1)
      ]) {
        final str = String.fromCharCodes(n.map((x) => x.$2));
        if (!seen.add(str)) continue;
        final (p, m) = parse(str);
        final t = m.isMismatch ? n : n.sublist(0, m.len), e = marks(t);
        if (!m.isMismatch && (fb == null || e < fb.$1)) if ((m.len == n.length ? m : parse(str.substring(0, m.len)).$2)
            case final w when !w.isMismatch && w.len == t.length) fb = (e, w, t);
        if (seen.length < fbCap) q.add((n, d + 1, j, _far(m, p, {})));
      }
    }
    if (fb case (_, final w, var t)?) {
      var d = _len - t.length, u = d < 0 ? t : [for (final (_, c) in t) (input.codeUnitAt(d) == c ? d++ : -2 - d++, c)];
      lastCost = marks(marks(u) < marks(t) ? t = u : t);
      return _map(w, t, input);
    }
    lastCost = _len == 0 ? 1 : _len;
    return peg.SyntaxError(pos: 0, len: input.length);
  }

  static int _code(peg.Terminal t) => switch (t) {
        peg.Str(:final text) || peg.Char(char: final text) => text.codeUnitAt(0),
        peg.CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => ranges[0].$1,
        _ => 32
      };
  static List<(int, int)> _apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[];
    for (var i = 0, j = 0; i <= input.length; i++) {
      var ch = i < input.length ? input.codeUnitAt(i) : -1, k = i;
      for (; j < es.length && es[j].$2 == i; j++) {
        final (op, _, c) = es[j];
        if (op == 1) out.add((-1, c));
        if (op == 0) ch = -1;
        if (op == 2) (ch = c, k = -2 - i);
      }
      if (ch >= 0) out.add((k, ch));
    }
    return out;
  }

  int _far(peg.MatchResult m, peg.Parser p, Set<(peg.Clause, int)> s) => [
        m.pos + m.len,
        for (final (c, q) in switch (m.clause) {
          final peg.HasOneSubClause h when m.subClauseMatches.isEmpty || h is peg.Repetition => [
              (h.subClause, m.pos + m.len)
            ],
          peg.First(:final subClauses) when !m.isMismatch => [
              for (final c in subClauses.takeWhile((c) => p.match(c, m.pos).isMismatch)) (c, m.pos)
            ],
          _ => const <(peg.Clause, int)>[]
        })
          if (s.add((c, q))) _far(p.match(c, q), p, s),
        for (final c in m.subClauseMatches) _far(c, p, s)
      ].reduce((a, b) => a > b ? a : b);

  peg.MatchResult _map(peg.MatchResult root, List<(int, int)> s, String input) {
    int at(int q) => s[q].$1 >= -1 ? s[q].$1 : -2 - s[q].$1;
    final orig = List.filled(s.length + 1, input.length), todo = <void Function()>[], ts = <peg.MatchResult>[];
    var next = 0;
    for (var q = s.length - 1; q >= 0; q--) orig[q] = at(q) >= 0 ? at(q) : orig[q + 1];
    void gap(int o, List<peg.MatchResult> into) {
      if (o > next) (into..add(peg.SyntaxError(pos: next, len: o - next)), next = o);
    }

    peg.MatchResult letter(peg.Clause l, int q, [bool own = false]) {
      final o = orig[q];
      if (s[q].$1 == -1) return peg.Match(l, o, 0, subClauseMatches: [peg.SyntaxError(pos: o, len: 0)]);
      next = o + 1;
      if (s[q].$1 >= 0) return peg.Match(l, o, 1);
      final e = peg.SyntaxError(pos: o, len: 1);
      return own ? peg.Match(peg.First([l]), o, 1, subClauseMatches: [e]) : e;
    }

    void walk(peg.MatchResult m, List<peg.MatchResult> into, [peg.Clause? up]) {
      final c = m.clause, kids = <peg.MatchResult>[], o = orig[m.pos];
      if (m.len == 0) {
        todo.add(() => into.add(peg.Match(c, o < next ? o : next, 0, subClauseMatches: kids)));
      } else {
        gap(o, into);
        if (m.subClauseMatches.isEmpty) {
          if ([for (var q = m.pos; q < m.pos + m.len; q++) q].every((q) => s[q].$1 >= 0 && orig[q] == o + q - m.pos)) {
            next = o + m.len;
            return into.add(peg.Match(c, o, m.len));
          }
          if (m.len == 1) return into.add(letter(c!, m.pos, up == null || up is peg.Ref));
          for (var q = m.pos; q < m.pos + m.len; q++) {
            gap(orig[q], kids);
            kids.add(letter(peg.Char((c as peg.Str).text[q - m.pos]), q));
          }
          return into.add(peg.Match(c, o, next - o, subClauseMatches: kids));
        }
        todo.add(() => into.add(peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)));
      }
      todo.addAll([for (final k in m.subClauseMatches.reversed) () => walk(k, kids, c)]);
    }

    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) todo.removeLast()();
    gap(input.length, ts);
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }
}
