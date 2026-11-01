import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30, _cap = 2, _floor = 4096;
int _min(int a, int b) => a < b ? a : b;

class _Stop {}

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
  int absorbed(int a) => end - a - evidence - spent;
  bool synced(int a, [int g = 1]) => spent > 0 && evidence > absorbed(a) + 1 && end > last + g;
  _Way then(_Way r, [bool s = false]) {
    final o1 = owed, o2 = r.owed, u = (s ? 0 : used) + r.used + _ex(o1 + o2) - (s ? 0 : _ex(o1)) - _ex(o2);
    if (clean) return _Way(r.end, r.edits, u, evidence + r.evidence, r.clean && !preferred ? piece : r.piece, r.prev);
    if (r.clean) return _Way(r.end, edits, u, evidence + r.evidence, piece, prev);
    final tail = o2 == 0 || first == len ? null : prev?.then(r.prev ?? r) ?? r.prev ?? r;
    return _Way(r.end, edits + r.edits, u, evidence + r.evidence,
        peg.Match(null, 0, 0, subClauseMatches: [piece as peg.Match, r.piece as peg.Match]), tail);
  }

  int cmp(_Way b) => cost != b.cost ? cost - b.cost : (b.evidence - evidence) * _never + edits - b.edits;
}

class _Cell {
  int mark = -1, dep = 0;
  final ends = <_Way>[], _at = <int, List<int>>{};
  List<_Way>? fresh;
  bool add(_Way r, bool local) {
    bool cov(_Way a, _Way b) => a.owed == b.owed && (local || a.spent <= b.spent && a.used <= b.used);
    final l = _at[r.end << 31 | (local ? r.last : r.first) & 0x3fffffff] ??= [];
    for (final i in l)
      if (cov(ends[i], r)) {
        if (!cov(r, ends[i])) return false;
        final c = ends[i].cmp(r);
        if (c > 0 || c == 0 && (r.owed == 0 || r.prev == null)) ends[i] = r;
        return c > 0;
      }
    for (final i in l)
      if (cov(r, ends[i])) {
        ends[i] = r;
        return true;
      }
    l.add(ends.length);
    ends.add(r);
    return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules;
  final String topRuleName;
  late peg.Parser parser;
  final _cells = <Object, _Cell>{}, _mins = <Object, int>{};
  bool get _local => _rung <= 0;
  String get path => lastCost == 0 ? 'plain' : 'checked';
  int _depth = 0, _seedDepth = _never, _budget = 0, _rung = 0, lastCost = 0, _work = _never;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) =>
      switch (parser.match(c, pos)) { final m when !m.isMismatch => _Way.clean(pos + m.len, _ev(m), m), _ => null };

  int _end(peg.Clause c, int pos) => _plain(c, pos)?.end ?? -1;
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
  int _min0(peg.Clause c) => _mins[c] ??= _minChars(c, {});
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

  List<_Way> _read(peg.Clause c, int pos, [bool delta = false]) {
    var computed = false;
    final pl = _plain(c, pos);
    if (_budget == 0 && pos < _len) return pl == null ? const [] : [pl];
    if (c is peg.FollowedBy || c is peg.NotFollowedBy) return [pl ?? _Way.clean(pos, 0, c)];
    if (c is peg.Terminal) {
      if (pl != null) return [pl];
      if (c is peg.Str && c.text.length > 1)
        return _seq([for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])], pos);
      return [
        _Way(pos, 1, pos == _len ? _Way._ex(1) : 1, 0, peg.Match(c, pos, 0)),
        if (pos < _len && (c is peg.Char || c is peg.Str)) _Way(pos + 1, 1, 1, 0, peg.Match(c, pos, 1))
      ];
    }
    if (c is peg.Ref) return _read(parser.rules[c.ruleName]!, pos, delta);
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell(), b = _budget;
    if (cell.dep != 0) {
      _seedDepth = _min(_seedDepth, -(cell.dep = -cell.dep.abs()));
    } else if (cell.mark < (b << 31 | _never) && cell.mark < (b << 31 | ((_cells[pos]?.mark ?? -1) + 1))) {
      final d = cell.dep = ++_depth, outer = _seedDepth, pe = pl?.end ?? -1, all = <_Way>[];
      var ms = _never, minJ = pe + 1;
      cell.fresh = null;
      do {
        _seedDepth = _never;
        final fresh = <_Way>[];
        for (final r in _propose(c, pos)) {
          if (--_work < 0 && _budget > _cap && _rung >= 0) throw _Stop();
          if ((_local || r.cost <= _rung) &&
              (!r.clean || r.end <= pe || r.preferred && (cell.dep < 0 || _seedDepth < _never)) &&
              cell.add(r, _local)) {
            final ts =
                _local && cell.dep < 0 && (r.synced(pos, 0) || _pureSub(r, pos)) ? _cells[(c, r.end)]?.fresh : null;
            if (ts == null || ts.isEmpty) fresh.add(r);
            for (final s in ts ?? const <_Way>[])
              if (r.then(s, true) case final w when w.used <= b && cell.add(w, _local)) {
                all.add(w);
                minJ = minJ == pe + 1 ? w.end : _min(minJ, w.end);
              }
          }
        }
        ms = _min(ms, _seedDepth);
        all.addAll(fresh);
        if (fresh.isEmpty || cell.dep > 0 || _seedDepth > d) break;
        (_cells[pos] ??= _Cell()).mark++;
        cell.fresh = fresh;
      } while (true);
      if (_local && cell.dep < 0 && pe > pos)
        (_cells[(c, pe)] ??= _Cell()).fresh = [
          for (final w in cell.ends)
            if (w.end >= minJ && w.first > pe) _Way(w.end, w.edits, w.used, w.evidence - pl!.evidence, w.piece, w.prev)
        ];
      _depth--;
      cell.dep = 0;
      cell.fresh = all;
      cell.mark = b << 31 | (ms < d ? (_cells[pos]?.mark ?? -1) + 1 : _never);
      computed = true;
      _seedDepth = _min(outer, ms < d ? ms : _never);
    }
    final raw = cell.dep != 0 && cell.fresh != null || delta && computed ? cell.fresh! : cell.ends;
    return [
      for (final r in raw)
        if (r.used <= b) r.preferred && pl?.end == r.end ? pl! : r
    ];
  }

  bool _active(peg.Clause? c, int at) => switch (c) {
        peg.Repetition(:final subClause) => _active(subClause, at),
        peg.First(:final subClauses) => subClauses.any((x) => _active(x, at)),
        peg.Ref(:final ruleName) => (_cells[parser.getMemoEntry(parser.rules[ruleName]!, at)]?.dep ?? 0) != 0,
        _ => false
      };
  List<peg.Clause> _flat(List<peg.Clause> s) => !s.any((x) => x is peg.Seq) || s.any((x) => x is peg.HasOneSubClause)
      ? s
      : [
          for (final x in s)
            if (x is peg.Seq && !_flat(x.subClauses).any((y) => y is peg.HasOneSubClause)) ..._flat(x.subClauses) else x
        ];
  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(_flat(c.subClauses), pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos);
      return [_Way.clean(pos, 0, rs.any((r) => r.preferred && r.end > pos) ? c : null), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[];
    var sd = _seedDepth;
    for (final sub in (c as peg.First).subClauses) {
      final rs = _read(sub, pos, cell.fresh != null);
      if (rs.isNotEmpty) sd = _min(sd, _seedDepth);
      out.addAll(rs);
    }
    _seedDepth = sd;
    return out;
  }

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) =>
      (s ??= {}).add(c) &&
      switch (c) {
        peg.Ref() => _startsClean(parser.rules[c.ruleName]!, at, s),
        peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
        peg.Seq(:final subClauses) =>
          subClauses.isNotEmpty && switch (_flat(subClauses)[0]) { final x => !_active(x, at) && _end(x, at) > at },
        peg.Terminal() => _end(c, at) > at,
        _ => false
      };

  List<_Way> _seq(List<peg.Clause> slots, int p) {
    var cur = [_Way.clean(p)], opt = <_Way>{};
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1;
      for (final r in cur) {
        final sub = (_local || s is peg.Repetition) && _pureSub(r, p),
            sync = last && r.synced(p) ||
                _local &&
                    sub &&
                    (last
                        ? r.evidence > 0 || r.edits == 1 && _startsClean(s, r.end)
                        : r.evidence > r.edits && r.first > p),
            rSub = sub &&
                (s is! peg.Terminal
                    ? !_local || sync
                    : last
                        ? r.edits <= i + _min0(rules[topRuleName]!) && r.evidence > r.edits && r.first == p + r.evidence
                        : r.evidence * 2 >= r.edits && r.first > p),
            canS = _local && s is! peg.Terminal && sync || rSub;
        final b0 = _budget, prevSeed = _seedDepth;
        _budget = canS ? b0 : b0 - r.used;
        _seedDepth = _never;
        final options = _read(s, r.end);
        _budget = b0;
        _seedDepth = _min(prevSeed, _seedDepth);
        var del = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final sk = last && sync && !_startsClean(s, r.end),
              j = _next(s, r.end + 1, r.end + _budget - (sk ? 0 : r.used), options.any((o) => o.preferred) ? 1 : 0);
          if (j < _never) {
            final m = _plain(s, j)!;
            next.add(r.then(_Way.skip(r.end, j), sk).then(m), _local);
            if (!last && _end(slots[i + 1], m.end) >= 0 && _end(slots[i + 1], m.end) >= _end(slots[i + 1], r.end))
              del = j - r.end;
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
                  (_local && sync && r.end > r.last || o.first > r.end) &&
                      (o.synced(r.end, 0) ||
                          _local && o.owed > 0 && o.evidence > o.cost && o.evidence > o.absorbed(r.end) + 1));
          if (r.then(o, st) case final w when w.used <= b0 && (_local || w.cost <= _rung))
            next.add(o.end == r.end && o.clean ? (opt..add(w)).last : w, _local);
        }
      }
      cur = next.ends;
      if (cur.isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int p) {
    final sub = c.subClause, best = _Cell(), q = {p << 3: _Way.clean(p)};
    final unit = _min0(sub) == 1 && !_oneShape(sub) && !_active(sub, p);
    void push(_Way w) {
      if (!_local && w.cost > _rung || !best.add(w, _local)) return;
      final k = w.end << 3;
      if (q[k] == null || q[k]!.cmp(w) >= 0) q[k] = w;
    }

    while (q.isNotEmpty) {
      var r = q.remove(q.keys.reduce(_min))!;
      final rSub = unit && _pureSub(r, p),
          canS = rSub || r.synced(p, _rung < 0 || unit && _startsClean(sub, r.end) ? 0 : 1);
      final b0 = _budget;
      _budget = canS ? b0 : b0 - r.used;
      final steps = _read(sub, r.end);
      _budget = b0;
      bool syncs(_Way s) => _end(sub, s.end) > s.end;
      final anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
      for (final s in steps) {
        if (s.end <= r.end) continue;
        final settle = canS &&
            !s.clean &&
            (!anySync && rSub && s.evidence > 0 && _pureSub(s, r.end) ||
                s.evidence > 1 &&
                    (r.end > r.last || s.first > r.end) &&
                    (syncs(s) || !anySync && s.evidence > s.absorbed(r.end)));
        if (r.then(s, settle) case final w when w.used <= b0) push(w);
      }
    }
    for (final r in _read(sub, p)) if (r.end == p && !r.clean) best.add(r, _local);
    if (!c.requireOne) best.add(_Way.clean(p), _local);
    return best.ends.where((r) => !_local || _rung == -2 || _end(sub, r.end) <= r.end).toList();
  }

  int _next(peg.Clause c, int j, int to, int test) {
    for (to = _min(to, _len); j <= to; j++) if (_end(c, j) case final e when e >= 0 && (test == 0 || e > j)) return j;
    return _never;
  }

  bool _takes(peg.Clause s, bool opt, _Way o, int at) {
    final b = s is peg.Repetition || opt && s is peg.Optional ? (s as peg.HasOneSubClause).subClause : null;
    if (b is! peg.Char && b is! peg.CharSet && (b is! peg.Str || b.text.length != 1)) return false;
    final u = _apply(parser.input, o.first > at ? const [] : _edits(o)), ch = at < u.length ? u[at].$2 : -1;
    return ch >= 0 &&
        switch (b) {
          peg.Char(:final char) || peg.Str(text: final char) => char.codeUnitAt(0) == ch,
          peg.CharSet(:final ranges, :final inverted) => inverted != ranges.any((r) => ch >= r.$1 && ch <= r.$2),
          _ => false
        };
  }

  // _ev on a dirty piece counts its substitutions: insertions have length zero, deletions no terminal.
  bool _pureSub(_Way w, int a) =>
      w.end - a == w.edits + w.evidence && !w.clean && _ev(w.piece as peg.Match) == w.edits;
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

  void _reset() {
    for (final m in [_cells, _mins]) m.clear();
    _depth = 0;
    _seedDepth = _never;
  }

  peg.MatchResult recover(String input) {
    try {
      parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
      _reset();
      var deep = false, lo = 0, sure = 0, reach = 0;
      final top = parser.rules[topRuleName]!, ceiling = _min0(top) == _never ? -1 : _len + 1;
      _Way.len = _len;
      _Way.maxOwed = rules.values.fold(0, (a, r) => a + (_min0(r) < _never ? _min0(r) : 0));
      void sweep(void Function(peg.Clause, int) fn) {
        for (var p = _len; p >= 0; p -= (_len + 1).bitLength)
          for (final r in parser.rules.values) if (r is! peg.Ref) fn(r, p);
      }

      late peg.MatchResult verdict;
      try {
        verdict = parser.match(top, 0);
      } on StackOverflowError {
        deep = true;
        parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
        sweep(parser.match);
        verdict = parser.match(top, 0);
      }
      if (!verdict.isMismatch && verdict.len == _len) {
        lastCost = 0;
        return verdict;
      }
      (_Way, peg.MatchResult, List<(int, int)>)? best;
      (_Way, peg.MatchResult, List<(int, int)>)? run(int rung) {
        (_Way, peg.MatchResult, List<(int, int)>)? b;
        _budget = rung;
        if (!_local) _rung = rung;
        List<_Way> ways;
        try {
          if (deep) sweep(_read);
          ways = _read(top, 0);
        } on StackOverflowError {
          deep = true;
          _reset();
          _budget = rung;
          sweep(_read);
          ways = _read(top, 0);
        }
        for (var p = 0; p <= (_local ? 0 : _min(rung, _len)); p++)
          for (final r0 in p == 0 ? ways : _read(top, p)) {
            final r = p == 0 ? r0 : _Way.skip(0, p).then(r0), w = _len == r.end ? r : r.then(_Way.skip(r.end, _len));
            if ((_local ? w.used : w.cost) > rung || w.clean || b != null && w.cmp(b.$1) >= 0) continue;
            final s = _apply(input, _edits(w)), str = String.fromCharCodes(s.map((x) => x.$2)), m = _parse(str);
            if (!m.isMismatch && m.len == str.length) b = (w, m, s);
          }
        return b;
      }

      _rung = 1;
      _work = _floor;
      for (var b = 1; best == null && (lo < ceiling || _rung > -2);) {
        if (lo >= ceiling) {
          _rung = -2;
          b = 1;
          lo = 0;
          _cells.clear();
        }
        try {
          if ((best = run(_min(b, ceiling))) == null) lo = _min(b, ceiling);
          b *= 2;
        } on _Stop {
          if (_rung > 0) {
            sure = lo;
            reach = 2 * _min(b, ceiling);
          }
          _rung = _rung > 0 ? 0 : -1;
          b = 1;
          lo = 0;
          _work = _rung == 0 ? _floor : _never;
          _reset();
        }
      }
      if (best != null && _rung <= 0 && best.$1.cost > sure + 1 && best.$1.cost <= reach + 1) {
        _rung = best.$1.cost - 1;
        _work = _floor << 6;
        _reset();
        try {
          best = run(_rung) ?? best;
        } on _Stop {/* keep local */}
      }
      Iterable<(int, int)> spans(peg.Clause c) => switch (c) {
            peg.Str(:final text) || peg.Char(char: final text) => text.codeUnits.map((x) => (x, x)),
            peg.CharSet(:final ranges, :final inverted) => [...ranges, if (inverted) (0, 0xffff)],
            peg.AnyChar() => [(0, 0xffff)],
            peg.HasOneSubClause() => spans(c.subClause),
            peg.HasMultipleSubClauses() => c.subClauses.expand(spans),
            _ => const []
          };
      final rs = rules.values.expand(spans).toSet(), seen = {input}, q = [(_apply(input, const []), 0, 0)];
      final cs = {
        for (final x in rs.expand((r) => [r.$1, r.$2 + 1]))
          if (rs.any((r) => x >= r.$1 && x <= r.$2)) '${[for (final r in rs) x >= r.$1 && x <= r.$2]}': x
      }.values;
      int marks(List<(int, int)> t) => _len - t.where((x) => x.$1 >= 0).length + t.where((x) => x.$1 == -1).length;
      (int, peg.MatchResult, List<(int, int)>)? fb = best == null ? null : (0, best.$2, best.$3);
      for (var qi = 0; qi < q.length && (fb == null || q[qi].$2 + 1 < fb.$1 && seen.length < _floor); qi++) {
        final (s, d, k) = q[qi];
        for (final (n, j) in [
          for (var i = k; i < s.length; i++) ([...s.sublist(0, i), ...s.sublist(i + 1)], i),
          for (var i = k; i <= s.length; i++)
            for (final c in cs) ([...s.sublist(0, i), (-1, c), ...s.sublist(i)], i + 1)
        ]) {
          final str = String.fromCharCodes(n.map((x) => x.$2));
          if (!seen.add(str)) continue;
          final m = _parse(str), t = m.isMismatch ? n : n.sublist(0, m.len);
          final w = m.isMismatch || m.len == n.length ? m : _parse(String.fromCharCodes(t.map((x) => x.$2)));
          final e = marks(t);
          if (!w.isMismatch && w.len == t.length && (fb == null || e < fb.$1)) fb = (e, w, t);
          if (seen.length < _floor) q.add((n, d + 1, j));
        }
      }
      if (fb case (_, final w, final t)?) {
        lastCost = marks(t);
        return _map(w, t, input);
      }
      lastCost = _len == 0 ? 1 : _len;
    } on StackOverflowError {}
    return peg.SyntaxError(pos: 0, len: input.length);
  }

  static int _code(peg.Terminal t) => switch (t) {
        peg.Str(:final text) || peg.Char(char: final text) => text.codeUnitAt(0),
        peg.CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => ranges[0].$1,
        peg.CharSet(:final ranges) => [for (var x = 0; x < 0x10000; x++) (x + 32) & 0xffff]
            .firstWhere((x) => !ranges.any((r) => x >= r.$1 && x <= r.$2)),
        _ => 32
      };
  static List<(int, int)> _apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[];
    for (var i = 0, j = 0; i <= input.length; i++) {
      var del = false;
      int? sub;
      for (; j < es.length && es[j].$2 == i; j++) {
        final (op, _, ch) = es[j];
        if (op == 0) del = true;
        if (op == 1) out.add((-1, ch));
        if (op == 2) sub = ch;
      }
      if (i < input.length && !del) out.add((sub == null ? i : -2 - i, sub ?? input.codeUnitAt(i)));
    }
    return out;
  }

  peg.MatchResult _parse(String w) =>
      peg.Parser(rules: rules, topRuleName: topRuleName, input: w).matchRule(topRuleName, 0);

  peg.MatchResult _map(peg.MatchResult root, List<(int, int)> s, String input) {
    int at(int q) => s[q].$1 >= -1 ? s[q].$1 : -2 - s[q].$1;
    final orig = List.filled(s.length + 1, input.length), todo = <void Function()>[], ts = <peg.MatchResult>[];
    var next = 0;
    for (var q = s.length - 1; q >= 0; q--) orig[q] = at(q) >= 0 ? at(q) : orig[q + 1];
    List<peg.MatchResult> gap(int o) {
      if (o <= next) return const [];
      final g = peg.SyntaxError(pos: next, len: o - next);
      next = o;
      return [g];
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
        into.addAll(gap(o));
        if (m.subClauseMatches.isEmpty) {
          if ([for (var q = m.pos; q < m.pos + m.len; q++) q].every((q) => s[q].$1 >= 0 && orig[q] == o + q - m.pos)) {
            next = o + m.len;
            return into.add(peg.Match(c, o, m.len));
          }
          if (m.len == 1) return into.add(letter(c!, m.pos, up == null || up is peg.Ref));
          for (var q = m.pos; q < m.pos + m.len; q++) {
            kids.addAll(gap(orig[q]));
            kids.add(letter(peg.Char((c as peg.Str).text[q - m.pos]), q));
          }
          return into.add(peg.Match(c, o, next - o, subClauseMatches: kids));
        }
        todo.add(() => into.add(peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)));
      }
      todo.addAll([for (final k in m.subClauseMatches.reversed) () => walk(k, kids, c)]);
    }

    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) todo.removeLast()();
    ts.addAll(gap(input.length));
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }
}
