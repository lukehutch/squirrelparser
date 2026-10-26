import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

class _Way {
  const _Way(this.end, this.deleted, this.spent, this.owed, this.used, this.subs,
      this.evidence, this.first, this.last, [this.piece, this.cut = _never, this.prev, this.incomplete = false]);
  const _Way.clean(int end, [int ev = 0, Object? piece]) : this(end, 0, 0, 0, 0, 0, ev, _never, -1, piece);
  _Way.skip(int a, int b, [int s = 0])
      : this(b, b - a, b - a, 0, b - a, s, 0, a, b, peg.SyntaxError(pos: a, len: b - a));
  final int end, deleted, spent, owed, used, subs, evidence, first, last, cut;
  final bool incomplete; final Object? piece; final _Way? prev;
  bool get clean => cost == 0;
  bool get preferred => clean && cut == _never;
  int get cost => spent + (owed == 0 ? 0 : 1);
  int absorbed(int a) => end - a - deleted - evidence;
  int get charge => cost + (!clean && absorbed(0) > evidence ? 1 : 0);
  bool pureSub(int a) => subs > 0 && cost == subs && absorbed(a) == 0;
  bool synced(int a, [int g = 1]) => spent > 0 && end > last + g && evidence > absorbed(a) + 1;
  _Way? then(_Way r, [bool s = false]) {
    final on = cut < _never && (r.clean || r.first >= cut);
    if (on && r.end >= cut) return null;
    final d = deleted + r.deleted, p = spent + r.spent, o = owed + r.owed, u = (s ? 0 : used) + r.used;
    final sb = subs + r.subs, ev = evidence + r.evidence, f = _min(first, r.first), l = last > r.last ? last : r.last;
    final c = on ? _min(cut, r.cut) : r.cut, inc = r.incomplete || r.end == end && incomplete;
    return _Way(r.end, d, p, o, u, sb, ev, f, l, r.piece, c, this, inc);
  }
  _Way label(peg.Clause c, int pos) =>
      _Way(end, deleted, spent, owed, used, subs, evidence, first, last, (c, pos, this), cut, null, incomplete);
  _Way demote([int c = _never - 1]) =>
      _Way(end, deleted, spent, owed, used, subs, evidence, first, last, piece, _min(cut, c), prev, incomplete);
  _Way trim(int f) => preferred && f >= 0 && end != f ? demote(f) : this;
  int cmp(_Way b) {
    var d = charge - b.charge; d = d != 0 ? d : (b.preferred ? 1 : 0) - (preferred ? 1 : 0);
    d = d != 0 ? d : b.evidence - evidence; d = d != 0 ? d : spent + owed - b.spent - b.owed;
    d = d != 0 ? d : b.first - first; d = d != 0 ? d : last - b.last; return d != 0 ? d : owed - b.owed;
  }
}

class _Cell {
  int mark = -1, ver = -1, dep = 0, arm = 0; bool seeded = false;
  final ends = <_Way>[]; Map<int, int>? _at;
  static int _key(_Way r) => r.end << 32 | r.used << 1 | (r.incomplete ? 1 : 0);
  bool add(_Way? r) {
    if (r == null) return false;
    final at = ends.isEmpty ? null : _at ??= {_key(ends[0]): 0}, k = _key(r);
    if (at?[k] case final i?) {
      final c = ends[i].cmp(r); if (c >= 0) ends[i] = r; return c > 0;
    }
    at?[k] = ends.length; ends.add(r); return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName}) : _exact = Exact(rules, topRuleName);
  final Exact _exact; String path = ''; final _subOf = Map<Object, peg.Clause>.identity();
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _versions = <int, int>{}, _shapes = <peg.Clause, bool>{}, _mins = <peg.Clause, int>{}, _chars = <peg.Str, List<peg.Clause>>{};
  final _str = <peg.Clause, String>{};
  int _depth = 0, _seedDepth = _never, _budget = 0, lastCost = 0;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) {
    var pref = true;
    if ((c is peg.FollowedBy || c is peg.NotFollowedBy) && _depth > 0) {
      final saved = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e?) (r, e, e.result, (_cells[e]?.dep ?? 0) > 0)];
      if (saved.any((x) => x.$4)) {
        peg.MatchResult probe(bool s) {
          for (final (r, e, _, a) in saved) { e..inRecPath = a && !s..foundLeftRec = false..result = a && s ? peg.Match(r, pos, 0) : null; }
          ++parser.memoVersion[pos]; return c.match(parser, pos);
        }
        final m = probe(false);
        if (!m.isMismatch && saved.any((x) => x.$4 && x.$2.foundLeftRec) && probe(true).isMismatch) pref = false;
        for (final (_, e, s, _) in saved) { e..inRecPath = false..result = s; }
        ++parser.memoVersion[pos];
        final w = m.isMismatch ? null : _Way.clean(pos + m.len, _ev(m), m);
        return pref ? w : w?.demote();
      }
    }
    final m = parser.match(c, pos); return m.isMismatch ? null : _Way.clean(pos + m.len, _ev(m), m);
  }

  int _ev(peg.MatchResult m) {
    for (final q = [if (_evidence[m] == null) m]; q.isNotEmpty;) {
      final n = q.last, c = n.clause, k = c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet ? const <peg.MatchResult>[] : n.subClauseMatches;
      var s = 0; for (final x in k) { _evidence[x] != null ? s += _evidence[x]! : q.add(x); }
      if (q.last == n) { q.removeLast(); _evidence[n] = k.isEmpty && (c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted) ? n.len : s; }
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

  int _min0(peg.Clause c) => _mins[c] ??= _minChars(c, {});
  int _minChars(peg.Clause c, Set<(peg.Clause, bool)> p, [bool req = false]) {
    if (!p.add((c, req))) return _never;
    final n = switch (c) {
      peg.Seq() => switch (c.subClauses.fold(0, (a, b) => _min(_never, a + _minChars(b, p)))) {
        0 when req => c.subClauses.fold(_never, (a, b) => _min(a, _minChars(b, p, true))),
        final v => v,
      },
      peg.First() => c.subClauses.fold(_never, (a, b) => _min(a, _minChars(b, p, req))),
      peg.Ref() => _minChars(parser.rules[c.ruleName]!, p, req),
      peg.Repetition() when c.requireOne || req => _minChars(c.subClause, p, true),
      peg.Optional() when req => _minChars(c.subClause, p, true),
      peg.Str() => c.text.length,
      peg.Char() || peg.CharSet() || peg.AnyChar() => 1,
      peg.FollowedBy() => !req && _minChars(c.subClause, p) < _never ? 0 : _never,
      _ => req ? _never : 0,
    };
    p.remove((c, req)); return n;
  }

  List<_Way> _read(peg.Clause c, int pos) {
    if (pos > _len || _budget < 0 || _min0(c) == _never) return const [];
    final plain = _plain(c, pos);
    if (c is peg.FollowedBy || c is peg.NotFollowedBy || _budget == 0 && pos < _len) return plain == null ? const [] : [plain];
    if (c is peg.Terminal) {
      if (plain != null) return [plain];
      if (c is peg.Str && c.text.length > 1) {
        final sub = _chars[c] ??= [for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])];
        return [for (final r in _seq(sub, pos)) if (r.evidence > 0 || r.used + r.owed <= _budget) r.label(c, pos)];
      }
      final eof = pos == _len ? 1 : 0, s = 1 - eof, m = peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]);
      return [_Way(pos, 0, s, eof, s, 0, 0, pos, pos, m, _never - 1, null, true)];
    }
    if (c is peg.Ref) {
      return [for (final r in _read(parser.rules[c.ruleName]!, pos))
        if (_depth == 0 || r.evidence > 0 || r.subs == r.cost || r.clean || r.end == pos || _oneShape(c)) r.label(c, pos)];
    }
    if (c is peg.Repetition && c.subClause is peg.CharSet && plain != null) {
      final k = (plain.piece as peg.MatchResult).subClauseMatches;
      var w = _Way.clean(pos).demote(plain.end);
      return [
        if (!c.requireOne && k.isNotEmpty) w.label(c, pos),
        for (var i = 0; i < k.length - 1; i++)
          (w = w.then(_Way.clean(k[i].pos + 1, c.requireOne ? _ev(k[i]) : 0, k[i]))!.demote(plain.end)).label(c, pos),
        plain,
      ];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell();
    final b = pos == _len && _budget == 0 ? 1 : _budget, v = _versions[pos] ?? 0;
    if (cell.dep > 0) {
      cell.seeded = true; _seedDepth = _min(_seedDepth, cell.dep);
    } else if (cell.mark < b || cell.mark == b && cell.ver < v) {
      final d = cell.dep = ++_depth, outer = _seedDepth, pe = plain?.end ?? _never; var ms = _never;
      cell.seeded = false;
      do {
        _seedDepth = _never; var ok = false;
        for (final r in _propose(c, pos)) {
          if ((r.clean ? r.cut >= pe || pe != r.end : pe != r.end || r.end == pos) && cell.add(r)) ok = true;
        }
        ms = _min(ms, _seedDepth); if (!ok || !cell.seeded || _seedDepth > d) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1;
      } while (true);
      _depth--; cell.dep = 0; _seedDepth = _min(outer, ms < d ? ms : _never);
      cell..mark = b..ver = ms < d ? (_versions[pos] ?? 0) : _never;
    }
    bool ok(_Way r) => r.used <= _budget && (cell.dep == 0 || c is! peg.First ||
        switch (_clauseOf(r.piece)) { final s? => c.subClauses.indexOf(s) >= cell.arm, _ => true });
    final raw = cell.ends.where(ok), f = _farthest(raw);
    return [for (final r in raw)
      r.preferred && r.end == f && plain?.end == r.end ? plain! : (cell.dep > 0 ? r : r.trim(f)).label(c, pos)];
  }

  static peg.Clause? _clauseOf(Object? p) => switch (p) { (final peg.Clause s, _, _) || peg.MatchResult(clause: final s?) => s, _ => null };
  static peg.Clause? _arm(Object? p) => p is peg.MatchResult ? p.subClauseMatches.firstOrNull?.clause : null;
  bool _active(peg.Clause? c, int at) => switch (c) {
    peg.Repetition(:final subClause, requireOne: true) => _active(subClause, at),
    peg.Ref(:final ruleName) => switch (_cells[parser.getMemoEntry(parser.rules[ruleName]!, at)]) {
      final x? => x.dep > 0, _ => false
    },
    _ => false,
  };
  static int _farthest(Iterable<_Way> rs) => rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) _Way.clean(pos), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[];
    var cut = _never, sd = _seedDepth;
    for (var i = 0; i < (c as peg.First).subClauses.length; i++) {
      final sub = c.subClauses[i];
      cell.arm = i;
      final act = _active(sub, pos);
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      if (act) sd = _min(sd, _seedDepth);
      for (final r in rs) {
        if (cut < _never && (r.clean || r.first >= cut || r.absorbed(pos) >= r.evidence)) continue;
        if (_seedDepth < _never && r.end > pos) sd = _min(sd, _seedDepth);
        out.add(cut < _never ? r.demote() : r);
      }
      if (f > pos) cut = _min(cut, f);
    }
    if (out.isNotEmpty) _seedDepth = sd;
    if (cut == _never && _budget > 0 && pos < _len && c.subClauses.where(_oneLit).map(_key).toSet().length == 1) out.add(_subst(pos, c.subClauses.firstWhere(_oneLit)));
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
        final canS = r.used > 0 && (s is peg.Repetition && r.synced(pos) || rSub || r.deleted == 0 && r.end == pos && _startsClean(s, r.end));
        final b0 = _budget, prevSeed = _seedDepth; _budget = canS ? b0 : b0 - r.used; _seedDepth = _never;
        final options = _read(s, r.end); _budget = b0;
        _seedDepth = _min(prevSeed, _seedDepth);
        var del = -1;
        if (!_active(s, r.end) && !options.any((o) => o.clean && o.end > r.end)) {
          final sync = r.used > 0 && last && slots.length > 2 && r.synced(pos);
          final limit = _min(_len, r.end + _budget - (sync ? 0 : r.cost));
          for (var j = r.end + 1; j <= limit; j++) {
            final clean = _plain(s, j);
            if (clean == null || clean.end == j && (sync || options.any((o) => o.clean))) continue;
            next.add(r.then(_Way.skip(r.end, j), sync)?.then(clean)); del = j - r.end; break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(s)) next.add(r.then(_subst(r.end, s)));
        }
        final pen = del > 0 && !last && !_active(s, r.end) && !(s is peg.First && s.subClauses.any((x) => _active(x, r.end))) && !_oneShape(s);
        bool settle(_Way o) => canS && o.first > r.end &&
            (rSub ? o.pureSub(r.end) && o.evidence > 0 : o.synced(r.end, 0) && (o.used == o.spent || o.first > r.last + 1));
        final adv = r.evidence == 0 && s is peg.Repetition && (r.incomplete && !_oneShape(s.subClause) || rSub && options.any(settle)) &&
            (r.end < _len || slots.skip(i + 1).any((x) => _min0(x) > 0));
        for (final o in options) {
          if (o.end == r.end && (adv || pen && !o.clean && del <= o.spent)) continue;
          final ex = i == 1 && r.owed > 1 && o.owed > 0 ? r.owed : 0; final w = r.then(o, settle(o));
          if (w != null && w.used + ex <= b0) next.add(w);
        }
      }
      cur = next.ends; if (cur.isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int p) {
    final sub = c.subClause, zero = _Way.clean(p); final best = _Cell(), q = {p: _Cell()..add(zero)};
    void push(_Way? w) { if (best.add(w)) (q[w!.end] ??= _Cell()).add(w); }
    while (q.isNotEmpty) {
      for (var r in q.remove(q.keys.reduce(_min))!.ends) {
        final e0 = r.end;
        for (var m1 = _active(sub, r.end) ? null : _plain(sub, r.end);
            m1 != null && m1.end > r.end && m1.evidence > 0 && !_active(_arm(m1.piece) ?? sub, r.end);) {
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
          if (r.used < _budget && r.end < _len && _oneLit(sub)) push(r.then(_subst(r.end, sub)));
        }
        bool syncs(_Way s) => (_plain(sub, s.end)?.end ?? 0) > s.end;
        final anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
        for (final s in steps) {
          if (s.end <= r.end || s.clean && s.cut < _never - 1 ||
              r.end > p && sub is peg.Terminal && s.owed >= s.evidence) { continue; }
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
    final ways = best.ends, f = _farthest(ways);
    return [for (final r in ways) switch (_plain(sub, r.end)?.end ?? r.end) {
      final sc when sc > r.end && !(r.end == p && _seedDepth < _never) => r.demote(sc),
      _ => !r.preferred || r.end == f ? r : r.demote(),
    }];
  }

  _Way _subst(int at, peg.Clause lit) { final w = _Way.skip(at, at + 1, 1); _subOf[w.piece!] = lit; return w; }

  String _key(peg.Clause c) => _str[c] ??= '${c is peg.Str && c.text.length == 1 ? peg.Char(c.text) : c}';

  // The edits a repair makes (op 0 delete, 1 insert, 2 substitute), read
  // off its pieces in input order; null if a piece is not one this engine
  // builds.
  List<(int, int, int)>? _edits(Object root) {
    final out = <(int, int, int)>[];
    for (final todo = [root]; todo.isNotEmpty;) {
      switch (todo.removeLast()) {
        case (_, _, final _Way w):
          for (_Way? r = w; r != null; r = r.prev) { if (r.piece case final p?) todo.add(p); }
        case final peg.SyntaxError m:
          if (_subOf[m] case final l?) { out.add((2, m.pos, Exact.code(l as peg.Terminal, 0))); } else { for (var q = m.pos; q < m.pos + m.len; q++) { out.add((0, q, 0)); } }
        case peg.MatchResult(:final clause, :final pos, subClauseMatches: [peg.SyntaxError(len: 0)]):
          if (clause is! peg.Terminal) return null;
          out.add((1, pos, Exact.code(clause, 0)));
      }
    }
    return out;
  }

  // The tree of the cheapest repair found, checked by parsing the repaired
  // string; when the check fails, the exact search over repaired strings.
  peg.MatchResult recover(String input) {
    final r = _recover(input);
    if (r is peg.MatchResult) return (path = 'plain', r).$2;
    try {
      if ((r == null ? null : _edits(r)) case final es?) {
        final s = Exact.apply(input, es), w = String.fromCharCodes(s.map((x) => x.$2)), m = _exact.parse(w);
        if (!m.isMismatch && m.len == w.length) return (path = 'checked', _exact._map(m, s, input)).$2;
      }
      final x = _exact.recover(input); lastCost = _exact.lastCost; return (path = 'exact', x).$2;
    } on StackOverflowError { return (path = 'unchecked', peg.SyntaxError(pos: 0, len: input.length)).$2; }
  }

  // The parse when the input is valid, else the cheapest repair found (null
  // if none).
  Object? _recover(String input) {
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
    final shortest = _min0(top), ceiling = shortest == _never ? -1 : _len + shortest; _Way? best;
    // The answer at the cheapest budget that finds one: budgets double until
    // one does, then a binary search finds the first. Cells filled at a
    // higher budget change what a lower one finds, so a step down starts
    // from empty cells.
    _Way? run(int rung) {
      _budget = rung; _Way? best; List<_Way> ways;
      try { if (deep) sweep(_read); ways = _read(top, 0); } on StackOverflowError {
        deep = true; _depth = 0; _seedDepth = _never; _budget = rung;
        _cells.clear(); _versions.clear(); sweep(parser.match); sweep(_read); ways = _read(top, 0);
      }
      for (final r in ways) {
        final tail = _len - r.end, w = tail == 0 ? r : r.then(_Way.skip(r.end, _len));
        if (w == null || w.charge - w.spent + w.used > _budget || w.clean) continue;
        if (best == null || w.cmp(best) < 0) best = w;
      }
      return best;
    }
    var lo = 0, hi = 0;
    for (var b = 1; best == null && lo < ceiling; b *= 2) {
      if ((best = run(hi = _min(b, ceiling))) == null) lo = hi;
    }
    while (best != null && hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      _cells.clear(); _versions.clear();
      if (run(mid) case final w?) { best = w; hi = mid; } else { lo = mid; }
    }
    lastCost = best == null ? (_len == 0 ? 1 : _len) : best.spent + best.owed;
    return best == null ? null : (null, 0, best);
  }
}

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
    // The nodes standing for `m` over the input, added to `into`: input
    // deleted before it, then `m` itself. A node is finished after its
    // children, so each pushes its own completion before them.
    final todo = <void Function()>[];
    void walk(peg.MatchResult m, List<peg.MatchResult> into) {
      final c = _old[m.clause] ?? m.clause, kids = <peg.MatchResult>[];
      if (m.len == 0) {
        final o = orig[m.pos] < next ? orig[m.pos] : next;
        todo.add(() => into.add(peg.Match(c, o, 0, subClauseMatches: kids)));
      } else {
        into.addAll(gap(orig[m.pos]));
        final o = orig[m.pos];
        if (m.subClauseMatches.isEmpty) {
          var clean = true;
          for (var q = m.pos; q < m.pos + m.len; q++) { if (s[q].$1 < 0 || orig[q] != o + q - m.pos) clean = false; }
          if (clean) { next = o + m.len; into.add(peg.Match(c, o, m.len)); return; }
          if (m.len == 1) { into.add(letter(c!, m.pos)); return; }
          // A literal of several letters with an edit in it is spelled letter
          // by letter, so each edit stands in the place of one letter.
          final t = (c as peg.Str).text;
          for (var q = m.pos; q < m.pos + m.len; q++) { kids.addAll(gap(orig[q])); kids.add(letter(peg.Char(t[q - m.pos]), q)); }
          into.add(peg.Match(c, o, next - o, subClauseMatches: kids)); return;
        }
        // A node that starts past the end of the input completes it: it covers
        // nothing a reader wrote, so it carries no rule's name.
        todo.add(() => into.add(peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)));
      }
      for (final k in m.subClauseMatches.reversed) { todo.add(() => walk(k, kids)); }
    }
    final ts = <peg.MatchResult>[];
    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) { todo.removeLast()(); }
    ts.addAll(gap(input.length));
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }
}
