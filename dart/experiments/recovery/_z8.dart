import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _clean = 1 << 30, _preferred = _clean + 1, _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

class _Way {
  const _Way(this.end, this.deleted, this.spent, this.evidence, this.first,
      this.piece, this.owed, this.used, this.incomplete, this.cut, this.prev, this.last);
  const _Way.clean(int end, [int ev = 0, Object? piece, int f = _preferred])
      : this(end, 0, 0, ev, f, piece, 0, 0, false, _never, null, -1);
  _Way.skip(int a, int b)
      : this(b, b - a, b - a, 0, a, peg.SyntaxError(pos: a, len: b - a), 0, b - a, false, _never, null, b);
  final int end, deleted, spent, owed, used, evidence, first, cut, last;
  final bool incomplete; final Object? piece; final _Way? prev;
  bool get clean => first >= _clean;
  bool get preferred => first > _clean;
  int get cost => spent + (owed == 0 ? 0 : 1);
  int absorbed(int a) => end - a - deleted - evidence;
  int get charge => cost + (!clean && absorbed(0) > evidence ? 1 : 0);
  bool pureSub(int a) => deleted > 0 && cost == deleted && absorbed(a) == 0;
  bool synced(int a, [int g = 1]) => spent > 0 && end > last + g && evidence > absorbed(a) + 1;
  _Way? then(_Way r, [bool s = false]) {
    final on = cut < _never && (r.clean || r.first >= cut);
    if (on && r.end >= cut || cut < _never && r.first == end && r.deleted > 0) return null;
    final d = deleted + r.deleted, p = spent + r.spent, o = owed + r.owed;
    final e = evidence + r.evidence, f = _min(first, r.first), u = (s ? 0 : used) + r.used;
    final inc = r.incomplete || r.end == end && incomplete;
    final c = on ? _min(cut, r.cut) : r.cut, l = last > r.last ? last : r.last;
    return _Way(r.end, d, p, e, f, r.piece, o, u, inc, c, this, l);
  }
  _Way label(peg.Clause c, int pos) =>
      _Way(end, deleted, spent, evidence, first, (c, pos, this), owed, used, incomplete, cut, null, last);
  _Way demote([int c = _never]) {
    final f = _min(first, _clean), k = _min(cut, c);
    return _Way(end, deleted, spent, evidence, f, piece, owed, used, incomplete, k, prev, last);
  }
  _Way trim(int f) => preferred && f >= 0 && end != f ? demote(clean ? f : _never) : this;
  int cmp(_Way b) {
    var d = charge - b.charge; d = d != 0 ? d : (b.preferred ? 1 : 0) - (preferred ? 1 : 0);
    d = d != 0 ? d : b.evidence - evidence; d = d != 0 ? d : spent + owed - b.spent - b.owed;
    d = d != 0 ? d : b.first - first; d = d != 0 ? d : last - b.last; return d != 0 ? d : owed - b.owed;
  }
}

class _Cell {
  int mark = -1; final ends = <(int, bool, int), _Way>{};
  bool add(_Way? r) {
    final k = r == null ? const (0, false, 0) : (r.end, r.incomplete, r.used);
    final c = r == null ? -1 : ends[k]?.cmp(r) ?? 1; if (c >= 0) ends[k] = r!;
    return c > 0;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _versions = <int, int>{}, _shapes = <peg.Clause, bool>{};
  int _depth = 1, _seedDepth = _never, _budget = 0, lastCost = 0;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;
  _Way? _plain(peg.Clause c, int pos) {
    final m = parser.match(c, pos); return m.isMismatch ? null : _Way.clean(pos + m.len, _ev(m), m);
  }

  int _ev(peg.MatchResult m) {
    for (final q = [if (_evidence[m] == null) m]; q.isNotEmpty;) {
      final n = q.last, c = n.clause;
      final skip = c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet;
      final k = skip ? const <peg.MatchResult>[] : n.subClauseMatches;
      var s = 0; for (final x in k) { _evidence[x] != null ? s += _evidence[x]! : q.add(x); }
      if (q.last != n) continue;
      q.removeLast(); final leaf = c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted;
      _evidence[n] = k.isEmpty && leaf ? n.len : s;
    }
    return _evidence[m]!;
  }

  bool _oneLit(peg.Clause c) => c is peg.Char || c is peg.Str && c.text.length == 1;
  bool _oneShape(peg.Clause c) => _shapes[c] ?? ((_shapes[c] = false) || (_shapes[c] = switch (c) {
    peg.Seq() => c.subClauses.every(_oneShape),
    peg.Repetition() => c.requireOne && _oneShape(c.subClause),
    peg.Ref() => _oneShape(parser.rules[c.ruleName]!),
    peg.Terminal() || peg.FollowedBy() || peg.NotFollowedBy() => true,
    _ => false,
  }));

  int _minChars(peg.Clause c, [Set<peg.Clause> p = const {}]) {
    if (p.contains(c)) return _never;
    final q = {...p, c};
    return switch (c) {
      peg.Seq() => c.subClauses.fold(0, (a, b) => _min(_never, a + _minChars(b, q))),
      peg.First() => c.subClauses.fold(_never, (a, b) => _min(a, _minChars(b, q))),
      peg.Ref() => _minChars(parser.rules[c.ruleName]!, q),
      peg.Repetition() when c.requireOne => _minChars(c.subClause, q),
      peg.Str() => c.text.length,
      peg.Char() || peg.CharSet() || peg.AnyChar() => 1,
      _ => 0,
    };
  }

  List<_Way> _read(peg.Clause c, int pos) {
    if (pos > _len || _budget < 0) return const [];
    final plain = _plain(c, pos), look = c is peg.FollowedBy || c is peg.NotFollowedBy;
    if (look || _budget == 0 && pos < _len) return plain == null ? const [] : [plain];
    if (c is peg.Terminal) {
      if (plain != null) return [plain];
      if (c is peg.Str && c.text.length > 1) {
        final sub = [for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])];
        return [for (final r in _seq(sub, pos)) if (r.evidence > 0 || r.used + r.owed <= _budget) r.label(c, pos)];
      }
      final eof = pos == _len ? 1 : 0, err = [peg.SyntaxError(pos: pos, len: 0)];
      final m = peg.Match(c, pos, 0, subClauseMatches: err);
      return [_Way(pos, 0, 1 - eof, 0, pos, m, eof, 1 - eof, true, _never, null, pos)];
    }
    if (c is peg.Ref) {
      final sub = _read(parser.rules[c.ruleName]!, pos), one = _oneShape(c);
      bool ok(_Way r) => r.evidence > 0 || r.clean || r.end == pos || one || r.pureSub(pos);
      return [for (final r in sub) if (ok(r)) r.label(c, pos)];
    }
    if (c is peg.Repetition && c.subClause is peg.CharSet && plain != null) {
      final k = (plain.piece as peg.MatchResult).subClauseMatches;
      var w = _Way.clean(pos).demote(plain.end); final out = [if (!c.requireOne && k.isNotEmpty) w.label(c, pos)];
      for (var i = 0; i < k.length - 1; i++) {
        final m = k[i]; final s = _Way.clean(m.pos + 1, c.requireOne ? _ev(m) : 0, m, _clean);
        out.add((w = w.then(s)!.demote(plain.end)).label(c, pos));
      }
      return [...out, plain];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell();
    final b = pos == _len && _budget == 0 ? 1 : _budget, mark = (b << 20) + (_versions[pos] ?? 0);
    if (cell.mark < -1) {
      cell.mark |= 1; _seedDepth = _min(_seedDepth, (1 - cell.mark) >> 1);
    } else if (cell.mark < mark) {
      final d = ++_depth, outer = _seedDepth, pe = plain?.end ?? _never; var ms = _never; cell.mark = -2 * d;
      do {
        _seedDepth = _never; var ok = false;
        for (final r in _propose(c, pos)) {
          if ((r.clean && r.cut >= pe || pe != r.end) && cell.add(r)) ok = true;
        }
        ms = _min(ms, _seedDepth); if (!ok || cell.mark.isEven || _seedDepth > d) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1;
      } while (true);
      _depth--; _seedDepth = _min(outer, ms < d ? ms : _never);
      cell.mark = (mark & ~0xFFFFF) + (ms < d ? _versions[pos] ?? 0 : 0xFFFFF);
    }
    final raw = cell.ends.values, f = _farthest(raw), out = <_Way>[];
    for (final r in raw) {
      if (r.used > _budget) continue;
      final w = (cell.mark < 0 ? r : r.trim(f)).label(c, pos);
      out.add(r.preferred && r.end == f && plain?.end == r.end ? plain! : w);
    }
    return out;
  }

  bool _active(peg.Clause c, int at) => c is peg.Ref &&
      (_cells[parser.getMemoEntry(parser.rules[c.ruleName]!, at)]?.mark ?? 0) < -1;
  static int _farthest(Iterable<_Way> rs) => rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);

  List<_Way> _propose(peg.Clause c, int p) {
    if (c is peg.Seq) return _seq(c.subClauses, p);
    if (c is peg.Repetition) return _repeat(c, p);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, p), f = _farthest(rs);
      final m = rs.fold(f, (m, r) => r.clean && r.end > p ? _min(m, r.end) : m);
      return [if (f != p) _Way.clean(p).trim(m), ...rs];
    }
    final out = <_Way>[]; var cut = _never, sd = _seedDepth;
    for (final sub in (c as peg.First).subClauses) {
      final act = _active(sub is peg.Repetition && sub.requireOne ? sub.subClause : sub, p);
      if (out.isNotEmpty && act) continue;
      final rs = _read(sub, p), f = act ? -1 : _farthest(rs);
      for (final r in rs) {
        if (cut < _never && (r.clean || r.first >= cut || r.absorbed(p) >= r.evidence)) continue;
        if (_seedDepth < _never && r.end > p) sd = _min(sd, _seedDepth);
        out.add(cut < _never ? r.demote() : r);
      }
      if (f >= 0) cut = _min(cut, f);
      if (!act && rs.any((r) => r.preferred && r.end == p)) break;
    }
    if (out.isNotEmpty) _seedDepth = sd;
    return out;
  }

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Ref() => (_plain(c, at)?.end ?? at) > at || _startsClean(parser.rules[c.ruleName]!, at, s),
    peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
    peg.Seq() => c.subClauses.isNotEmpty && (_plain(c.subClauses[0], at)?.end ?? at) > at,
    _ => false,
  };

  List<_Way> _seq(List<peg.Clause> slots, int pos) {
    var cur = [_Way.clean(pos)];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1;
      for (final r in cur) {
        if (r.used > _budget) continue;
        final rSub = r.pureSub(pos) && s is peg.Repetition;
        final canS = r.used > 0 && (s is peg.Repetition && r.synced(pos) || rSub || r.end == pos && _startsClean(s, r.end));
        final b0 = _budget; _budget = canS ? b0 : b0 - r.used; final options = _read(s, r.end); _budget = b0; var del = -1;
        if (!_active(s, r.end) && !options.any((o) => o.clean && o.end > r.end)) {
          final sync = r.used > 0 && last && slots.length > 2 && r.synced(pos);
          final limit = _min(_len, r.end + _budget - (sync ? 0 : r.cost));
          for (var j = r.end + 1; j <= limit; j++) {
            final clean = _plain(s, j);
            if (clean == null || clean.end == j && (sync || options.any((o) => o.clean))) continue;
            next.add(r.then(_Way.skip(r.end, j), sync)?.then(clean)); del = j - r.end; break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(s)) next.add(r.then(_Way.skip(r.end, r.end + 1)));
        }
        final pen = del > 0 && !last && !_active(s, r.end) && !_oneShape(s);
        bool settle(_Way o) => canS && o.first > r.end &&
            (rSub ? o.pureSub(r.end) && o.evidence > 0 : o.synced(r.end, 0) && (o.used == o.spent || o.first > r.last + 1));
        final adv = r.evidence == 0 && s is peg.Repetition &&
            (r.incomplete && !_oneShape(s.subClause) || rSub && options.any(settle));
        for (final o in options) {
          if (o.end == r.end && (adv || pen && !o.clean && del <= o.spent)) continue;
          final ex = i == 1 && r.owed > 1 && o.owed > 0 ? r.owed : 0; final w = r.then(o, settle(o));
          if (w != null && w.used + ex <= b0) next.add(w);
        }
      }
      cur = next.ends.values.toList(); if (cur.isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int p) {
    final sub = c.subClause, sub0 = _minChars(sub) == 0, zero = _Way.clean(p); final best = _Cell(), q = {p: _Cell()..add(zero)};
    void push(_Way? w) { if (best.add(w)) (q[w!.end] ??= _Cell()).add(w); }
    while (q.isNotEmpty) {
      for (var r in q.remove(q.keys.reduce(_min))!.ends.values) {
        final e0 = r.end;
        for (var m1 = _plain(sub, r.end); m1 != null && m1.end > r.end && m1.evidence > 0;) {
          final first = (m1.piece as peg.MatchResult).subClauseMatches.firstOrNull;
          if (_active(first?.clause ?? sub, r.end)) break;
          final m2 = _plain(sub, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null;
          if (next == null) break;
          if (r.end > p && sub is peg.Terminal) best.add(r);
          r = next; m1 = m2!;
        }
        if (r.end > e0) { push(r); continue; }
        if (r.used > _budget) continue;
        var d = r; while (d.prev != null && d.spent == d.prev!.spent) { d = d.prev!; }
        final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0); final rSub = sub is peg.Ref && r.pureSub(p) && dEv > 0;
        final canS = r.used > 0 && (rSub || (cleanTail || r.end > r.last + 1) && dEv > 1 && r.evidence > r.absorbed(p) + 1);
        final b0 = _budget; _budget = canS ? b0 : b0 - r.used; final steps = _read(sub, r.end); _budget = b0;
        if (sub is! peg.CharSet && !_active(sub, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
          for (var j = r.end + 1; j <= _min(_len, r.end + _budget - r.cost); j++) {
            final clean = _plain(sub, j);
            if (clean == null || clean.end == j || clean.evidence == 0) continue;
            push(r.then(_Way.skip(r.end, j))?.then(clean)); break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(sub)) push(r.then(_Way.skip(r.end, r.end + 1)));
        }
        bool syncs(_Way s) => (_plain(sub, s.end)?.end ?? 0) > s.end;
        final anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
        for (final s in steps) {
          final pDel = s.end - r.end == s.deleted && (sub0 || !s.pureSub(r.end));
          final badT = r.end > p && sub is peg.Terminal && s.owed >= s.evidence;
          if (s.end <= r.end || pDel || s.clean && s.cut < _never || badT) continue;
          final syncOk = syncs(s) ? cleanTail || s.first > r.end : cleanTail && !anySync && s.evidence > s.absorbed(r.end);
          final settle = canS && !s.clean && (!s.incomplete || s.first == s.end) &&
              (!anySync && rSub && s.pureSub(r.end) && s.evidence > 0 || s.evidence > 1 && syncOk);
          if (r.then(s, settle) case final w? when w.used <= b0) push(w);
        }
      }
    }
    if (best.ends.isEmpty) {
      for (final r in _read(sub, p)) { if (r.end == p && !r.clean) best.add(zero.then(r)?.demote()); }
    }
    if (!c.requireOne) best.add(zero);
    final ways = best.ends.values, f = _farthest(ways);
    return [for (final r in ways) switch (_plain(sub, r.end)?.end ?? r.end) {
      final sc when sc > r.end && !(r.end == p && _seedDepth < _never) => r.demote(sc),
      _ => !r.preferred || r.end == f ? r : r.demote(),
    }];
  }

  peg.MatchResult _tree(Object root) {
    if (root is peg.MatchResult) return root;
    final built = Map<Object, peg.MatchResult>.identity();
    for (final todo = [root]; todo.isNotEmpty;) {
      final piece = todo.last, kids = <peg.MatchResult>[]; final (label, pos, inner) = piece as (peg.Clause?, int, _Way);
      for (_Way? r = inner; r != null; r = r.prev) {
        final p = r.piece, m = p is peg.MatchResult ? p : built[p];
        if (p != null) m != null ? kids.add(m) : todo.add(p);
      }
      if (todo.last != piece) continue;
      todo.removeLast(); final c = inner.end == pos && pos == _len ? null : label;
      built[piece] = kids.isEmpty ? peg.Match(c, pos, inner.end - pos) : peg.Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
    }
    return built[root]!;
  }

  peg.MatchResult recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    _cells.clear(); _evidence.clear(); _versions.clear(); final top = parser.rules[topRuleName]!;
    void sweep(void Function(peg.Clause, int) fn) {
      for (var p = _len; p >= 0; p--) { for (final r in parser.rules.values) { if (r is! peg.Ref) fn(r, p); } }
    }
    var deep = false; late peg.MatchResult verdict;
    try { verdict = parser.match(top, 0); } on StackOverflowError {
      deep = true; parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
      sweep(parser.match); verdict = parser.match(top, 0);
    }
    if (!verdict.isMismatch && verdict.len == _len) { lastCost = 0; return verdict; }
    final shortest = _minChars(top), ceiling = shortest == _never ? -1 : _len + shortest; _Way? best, fallback;
    for (var rung = 1; rung <= ceiling; rung++) {
      _budget = rung; final inc = <_Way>[]; List<_Way> ways;
      try { if (deep) sweep(_read); ways = _read(top, 0); } on StackOverflowError {
        deep = true; _depth = 1; _seedDepth = _never; _budget = rung;
        _cells.clear(); _versions.clear(); sweep(parser.match); sweep(_read); ways = _read(top, 0);
      }
      for (final r in ways) {
        final tail = _len - r.end, w = tail == 0 ? r : r.then(_Way.skip(r.end, _len));
        if (w == null || w.charge - w.spent + w.used > _budget || w.clean) continue;
        if (tail > 0 && r.incomplete) { inc.add(w); continue; }
        if (best == null || w.cmp(best) < 0) best = w;
      }
      if (best != null) {
        for (final r in inc) { if (r.charge <= best!.charge && r.evidence > best.evidence) best = r; }
        break;
      }
      if (fallback == null && inc.isNotEmpty) fallback = inc.reduce((a, b) => a.cmp(b) <= 0 ? a : b);
    }
    best ??= fallback; lastCost = best == null ? (_len == 0 ? 1 : _len) : best.spent + best.owed;
    return best == null ? peg.SyntaxError(pos: 0, len: _len)
        : _tree(best.prev == null && best.piece != null ? best.piece! : (null, 0, best));
  }
}
