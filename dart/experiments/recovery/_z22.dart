import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30;
// The cut of a way that passed a lookahead without consuming input.
const _pred = _never - 2;
int _min(int a, int b) => a < b ? a : b;

class _Stop {}

class _Way {
  static int maxOwed = _never;
  static int _ex(int o) => o > maxOwed ? o - maxOwed : 0;
  const _Way(this.end, this.deleted, this.spent, this.owed, this.used, this.subs,
      this.evidence, this.first, this.last, [this.piece, this.cut = _never, this.prev, this.incomplete = false]);
  const _Way.clean(int end, [int ev = 0, Object? piece]) : this(end, 0, 0, 0, 0, 0, ev, _never, -1, piece);
  _Way.skip(int a, int b, [int s = 0])
      : this(b, b - a, b - a, 0, b - a, s, 0, a, b, peg.SyntaxError(pos: a, len: b - a));
  final int end, deleted, spent, owed, used, subs, evidence, first, last, cut;
  final bool incomplete; final Object? piece; final _Way? prev;
  bool get clean => cost == 0;
  bool get preferred => clean && cut == _never;
  int get cost => spent + (owed == 0 ? 0 : owed <= maxOwed ? 1 : owed - maxOwed + (maxOwed == 0 ? 0 : 1));
  int absorbed(int a) => end - a - deleted - evidence;
  bool pureSub(int a) => subs > 0 && cost == subs && absorbed(a) == 0;
  bool synced(int a, [int g = 1]) => spent > 0 && end > last + g && evidence > absorbed(a) + 1;
  _Way? then(_Way r, [bool s = false]) {
    final on = cut < _never && (r.clean || r.first >= cut);
    if (on && r.end >= cut) return null;
    final d = deleted + r.deleted, p = spent + r.spent, o = owed + r.owed;
    final over = _ex(o) - (s ? 0 : _ex(owed)) - _ex(r.owed), u = (s ? 0 : used) + r.used + over;
    final sb = subs + r.subs, ev = evidence + r.evidence, f = _min(first, r.first), l = last > r.last ? last : r.last;
    final c = on ? _min(cut, r.cut) : r.cut < _never ? r.cut : cut == _pred ? _pred : _never, inc = r.incomplete || r.end == end && incomplete;
    return _Way(r.end, d, p, o, u, sb, ev, f, l, r.piece, c, this, inc);
  }
  _Way label(peg.Clause c, int pos) =>
      _Way(end, deleted, spent, owed, used, subs, evidence, first, last, (c, pos, this), cut, null, incomplete);
  _Way demote([int c = _never - 1]) =>
      _Way(end, deleted, spent, owed, used, subs, evidence, first, last, piece, _min(cut, c), prev, incomplete);
  int cmp(_Way b) {
    var d = cost - b.cost; d = d != 0 ? d : (b.preferred ? 1 : 0) - (preferred ? 1 : 0);
    final ie = spent > 0 && owed > 1 ? evidence - 1 : evidence, bie = b.spent > 0 && b.owed > 1 ? b.evidence - 1 : b.evidence;
    d = d != 0 ? d : bie - ie; d = d != 0 ? d : spent + owed - b.spent - b.owed; d = d != 0 ? d : b.evidence - evidence;
    d = d != 0 ? d : b.first - first; d = d != 0 ? d : last - b.last; return d != 0 ? d : owed - b.owed;
  }
}

class _Cell {
  int mark = -1, ver = -1, dep = 0, arm = 0; bool seeded = false;
  final ends = <_Way>[]; Map<int, List<int>>? _at; List<_Way>? fresh;
  static int _key(_Way r, bool local) => r.end << 23 | ((local ? r.last : r.first > r.end ? r.end + 1 : r.first) & 0xfffff) << 3 | (r.incomplete ? 4 : 0) | (r.clean && r.cut < _never ? 2 : 0) | (r.cut == _pred ? 1 : 0);
  static bool _covers(_Way a, _Way b, bool local) => a.owed == b.owed && (local || a.spent <= b.spent && a.used <= b.used);
  // A way is kept unless one with the same end and owed count spends and
  // uses no more; of two equal on all three, the later unless the earlier is
  // better. In local mode a cell keeps one way per end, last edit and owed count.
  bool add(_Way? r, bool local) {
    if (r == null) return false;
    final at = ends.isEmpty ? null : _at ??= {_key(ends[0], local): [0]}, k = _key(r, local), l = at?[k];
    if (l != null) {
      for (final i in l) {
        if (!_covers(ends[i], r, local)) continue;
        if (!_covers(r, ends[i], local)) return false;
        final c = ends[i].cmp(r); if (c > 0 || c == 0 && (r.owed == 0 || r.piece is peg.MatchResult)) ends[i] = r; return c > 0;
      }
      for (final i in l) { if (_covers(r, ends[i], local)) { ends[i] = r; return true; } }
      l.add(ends.length);
    } else {
      at?[k] = [ends.length];
    }
    ends.add(r); return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName}) : _exact = Exact(rules, topRuleName);
  final Exact _exact; String path = ''; final _subOf = Map<Object, peg.Clause>.identity();
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _nexts = <(peg.Clause, int), List<int>>{}, _versions = <int, int>{}, _shapes = <peg.Clause, bool>{}, _mins = <peg.Clause, int>{}, _chars = <peg.Str, List<peg.Clause>>{};
  bool get _local => _rung == 0;
  int _depth = 0, _seedDepth = _never, _budget = 0, _rung = 0, lastCost = 0, _work = 0, _limit = _never;
  static const _cap = 2, _per = 4, _floor = 4096, _exactPer = 16;
  (_Way, peg.MatchResult?, List<(int, int)>)? _checked; bool _doubt = false;
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
        if (!m.isMismatch) {
          for (final x in saved) { if (x.$4 && x.$2.foundLeftRec) { final c = _cells[x.$2]!; c.seeded = true; _seedDepth = _min(_seedDepth, c.dep); } }
          if (saved.any((x) => x.$4 && x.$2.foundLeftRec) && probe(true).isMismatch) pref = false;
        }
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
    if (_min0(c) == _never) return const [];
    final plain = _plain(c, pos);
    if (_budget == 0 && pos < _len) return plain == null ? const [] : [plain];
    if (c is peg.FollowedBy || c is peg.NotFollowedBy) {
      return [plain ?? _Way.clean(pos, 0, c).demote(_pred)];
    }
    if (c is peg.Terminal) {
      if (plain != null) return [plain];
      if (c is peg.Str && c.text.length > 1) {
        final sub = _chars[c] ??= [for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])];
        return [for (final r in _seq(sub, pos)) if (r.evidence > 0 || r.cost <= _budget) r.label(c, pos)];
      }
      final eof = pos == _len ? 1 : 0, s = 1 - eof, m = peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]);
      return [_Way(pos, 0, s, eof, s + _Way._ex(eof), 0, 0, pos, pos, m, _never - 1, null, true), if (s > 0 && _oneLit(c)) _subst(pos, c)];
    }
    if (c is peg.Ref) {
      return [for (final r in _read(parser.rules[c.ruleName]!, pos))
        if (_depth == 0 || r.evidence > 0 || r.subs == r.spent || r.clean || r.end == pos || _oneShape(c)) r.label(c, pos)];
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
    final b = _budget, v = _versions[pos] ?? 0;
    if (cell.dep > 0) {
      cell.seeded = true; _seedDepth = _min(_seedDepth, cell.dep);
    } else if (cell.mark < b || cell.mark == b && cell.ver < v) {
      final d = cell.dep = ++_depth, outer = _seedDepth, pe = plain?.end ?? -1; var ms = _never;
      cell..seeded = false..fresh = null;
      do {
        _seedDepth = _never; final fresh = <_Way>[];
        for (final r in _propose(c, pos)) {
          if (++_work > _limit && _rung > _cap) throw _Stop();
          if ((_local || r.cost <= _rung) && (r.clean ? (cell.seeded || _seedDepth < _never || r.end <= pe) && (r.cut >= pe || pe != r.end) : pe != r.end || r.end == pos || r.first == pos || r.owed > 0) && cell.add(r, _local)) fresh.add(r);
        }
        ms = _min(ms, _seedDepth); if (fresh.isEmpty || !cell.seeded || _seedDepth > d) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1; cell.fresh = fresh;
      } while (true);
      if (cell.seeded && c is peg.First) _versions[pos] = (_versions[pos] ?? 0) + 1;
      _depth--; cell..dep = 0..fresh = null; _seedDepth = _min(outer, ms < d ? ms : _never);
      cell..mark = b..ver = ms < d ? (_versions[pos] ?? 0) : _never;
    }
    bool ok(_Way r) => r.used <= _budget && (cell.dep == 0 || c is! peg.First ||
        switch (_clauseOf(r.piece)) { final s? => c.subClauses.indexOf(s) >= cell.arm, _ => true });
    // A read inside a growing seed sees only the ways the last pass added:
    // the older ones were extended by an earlier pass.
    final raw = (cell.fresh ?? cell.ends).where(ok);
    return [for (final r in raw)
      r.preferred && plain?.end == r.end ? plain! : r.label(c, pos)];
  }

  static peg.Clause? _clauseOf(Object? p) => switch (p) { (final peg.Clause s, _, _) || peg.MatchResult(clause: final s?) => s, _ => null };

  static peg.Clause? _arm(Object? p) => p is peg.MatchResult ? p.subClauseMatches.firstOrNull?.clause : null;
  bool _active(peg.Clause? c, int at) => switch (c) {
    peg.Repetition(:final subClause) => _active(subClause, at),
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
      return [if (f != pos) f > pos ? _Way.clean(pos).demote(f) : _Way.clean(pos), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[];
    var cut = _never, sd = _seedDepth;
    for (var i = 0; i < (c as peg.First).subClauses.length; i++) {
      final sub = c.subClauses[i];
      cell.arm = i;
      final act = _active(sub, pos);
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      if (act || rs.isEmpty) sd = _min(sd, _seedDepth);
      for (final r in rs) {
        if (cut < _never && (r.clean ? r.end >= cut : r.first >= cut || r.absorbed(pos) > 0 && r.absorbed(pos) >= r.evidence)) continue;
        if (_seedDepth < _never && (r.end > pos || r.cut == _never - 1)) sd = _min(sd, _seedDepth);
        out.add(cut < _never ? (r.clean ? r.demote(cut) : r.demote()) : r);
      }
      // A recursive seed can grow after this arm was read; its end is not a final cut.
      if (f > pos && _seedDepth == _never) cut = _min(cut, f);
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
        final rSub = r.pureSub(pos) && r.evidence != 1 && s is peg.Repetition;
        final canS = r.used > 0 && (s is peg.Repetition && r.synced(pos) || rSub || r.deleted == 0 && r.end == pos && _startsClean(s, r.end));
        final b0 = _budget, prevSeed = _seedDepth; _budget = canS ? b0 : b0 - r.used; _seedDepth = _never;
        final options = _read(s, r.end); _budget = b0;
        _seedDepth = _min(prevSeed, _seedDepth);
        var del = -1;
        if (!_active(s, r.end) && !options.any((o) => o.clean && o.end > r.end)) {
          final sync = r.used > 0 && last && slots.length > 2 && r.synced(pos);
          final j = _next(s, r.end + 1, r.end + _budget - (sync ? 0 : r.used), sync || options.any((o) => o.preferred) ? 1 : 0);
          if (j < _never) {
            final m = _plain(s, j)!; next.add(r.then(_Way.skip(r.end, j), sync)?.then(m), _local);
            if (!last && (_plain(slots[i + 1], m.end)?.end ?? -1) >= (_plain(slots[i + 1], r.end)?.end ?? 0)) del = j - r.end;
          }
        }
        final pen = del > 0 && !last && !_active(s, r.end) && !_oneShape(s);
        bool settle(_Way o) => canS && o.first > r.end &&
            (rSub ? o.pureSub(r.end) && o.evidence > 0 : o.synced(r.end, 0) && (o.used == o.spent || o.first > r.last + 1));
        final adv = _seedDepth == _never && r.evidence == 0 && s is peg.Repetition && (r.incomplete && !_oneShape(s.subClause) || rSub && options.any(settle)) &&
            (r.end < _len || slots.skip(i + 1).any((x) => _min0(x) > 0));
        final g = i > 0 ? _greedy(slots[i - 1], r) : null;
        for (final o in options) {
          if (o.end == r.end && (adv || pen && !o.clean && del <= o.spent)) continue;
          if (g != null && o.first == r.end && _takes(g, _head(o, r.end))) continue;
          final w = r.then(o, settle(o));
          if (w != null && w.used <= b0) next.add(w, _local);
        }
      }
      cur = next.ends; if (cur.isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int p) {
    // A way waiting to be extended is replaced by a better one with the same
    // end: extending the worse one cannot give a cheaper repair.
    final sub = c.subClause, zero = _Way.clean(p); final best = _Cell(), q = {p << 3: zero}, done = <_Way>{};
    void push(_Way? w) {
      if (!best.add(w, _local)) return;
      final k = w!.end << 3 | (w.incomplete ? 2 : 0) | (w.clean && w.cut < _never ? 1 : 0), e = q[k | 4];
      if (q[k] == null || q[k]!.cmp(w) >= 0) q[k] = w;
      // The parent's choice may keep only ways whose first edit comes early
      // enough, so the earliest of the cheapest ways is kept too.
      if (e == null || w.cost < e.cost || w.cost == e.cost && w.first < e.first) q[k | 4] = w;
    }
    while (q.isNotEmpty) {
      var r = q.remove(q.keys.reduce(_min))!;
      if (!done.add(r)) continue;
      final e0 = r.end;
      for (var m1 = _active(sub, r.end) ? null : _plain(sub, r.end);
          m1 != null && m1.end > r.end && m1.evidence > 0 && !_active(_arm(m1.piece) ?? sub, r.end);) {
        final m2 = _plain(sub, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null;
        if (next == null) break;
        if (r.end > p && (sub is peg.Terminal || sub is peg.First)) best.add(r, _local);
        r = next; m1 = m2!;
      }
      if (r.end > e0) { push(r); continue; }
      if (r.used > _budget) continue;
      var d = r; while (d.prev != null && d.spent == d.prev!.spent) { d = d.prev!; }
      final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0); final rSub = sub is peg.Ref && r.pureSub(p) && dEv > 1;
      final canS = r.used > 0 && (rSub || (cleanTail || r.end > r.last + 1) && dEv > 1 && r.evidence > r.absorbed(p) + 1);
      final b0 = _budget; _budget = canS ? b0 : b0 - r.used; final steps = _read(sub, r.end); _budget = b0;
      if (sub is! peg.CharSet && !_active(sub, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
        final j = _next(sub, r.end + 1, r.end + _budget - r.used, 1);
        if (j < _never) push(r.then(_Way.skip(r.end, j))?.then(_plain(sub, j)!));
      }
      bool syncs(_Way s) => (_plain(sub, s.end)?.end ?? 0) > s.end;
      final anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
      for (final s in steps) {
        if (s.end <= r.end || sub is! peg.Repetition && s.clean && s.cut < _pred) continue;
        final syncOk = syncs(s) ? cleanTail || s.first > r.end : (cleanTail || s.first > r.end) && !anySync && s.evidence > s.absorbed(r.end);
        final settle = canS && !s.clean && (!s.incomplete || s.first == s.end) &&
            (!anySync && rSub && s.pureSub(r.end) && s.evidence > 0 || s.evidence > 1 && syncOk);
        if (r.then(s, settle) case final w? when w.used <= b0) push(w);
      }
    }
    for (final r in _read(sub, p)) { if (r.end == p && !r.clean) best.add(zero.then(r)?.demote(), _local); }
    if (!c.requireOne) best.add(zero, _local);
    final ways = best.ends, f = _farthest(ways);
    return [for (final r in ways) switch (_plain(sub, r.end)?.end ?? r.end) {
      final sc when sc > r.end && !(r.end == p && _seedDepth < _never) => r.demote(sc),
      _ => !r.preferred || r.end == f ? r : r.demote(),
    }];
  }

  // The first position from j to `to` where c reads cleanly: at all (test
  // 0) or non-empty (1); _never if none. Each
  // position scanned records the answer (q + 1) or that none comes before q
  // (-q), so scanning junk costs one read per position overall.
  int _next(peg.Clause c, int j, int to, int test) {
    final memo = _nexts[(c, test)] ??= List.filled(_len + 2, 0), seen = <int>[];
    var r = _never;
    for (to = _min(to, _len); j <= to;) {
      final v = memo[j];
      if (v > 0) { r = v - 1; break; }
      if (v < 0) { j = -v; continue; }
      seen.add(j); final m = _plain(c, j);
      if (m != null && (test == 0 || m.end > j)) { r = j; break; }
      j++;
    }
    for (final x in seen) { memo[x] = r < _never ? r + 1 : -j; }
    return r > to ? _never : r;
  }

  // The one-character body of a greedy slot that stopped at r.end: an
  // optional that read nothing or a repetition; null otherwise. The slot
  // would take the next character of the repaired string if its body matched it.
  static peg.Terminal? _greedy(peg.Clause s, _Way r) {
    final b = switch (s) { peg.Optional(:final subClause) || peg.Repetition(:final subClause) => subClause, _ => null };
    if (b is! peg.Char && b is! peg.CharSet && !(b is peg.Str && b.text.length == 1)) return null;
    final p = r.prev;
    return s is peg.Repetition || p != null && p.end == r.end && p.spent == r.spent && p.owed == r.owed ? b as peg.Terminal : null;
  }
  static bool _takes(peg.Terminal t, int ch) => ch >= 0 && !t.match(peg.Parser(rules: {}, topRuleName: '', input: String.fromCharCode(ch)), 0).isMismatch;
  // The first character of the repaired string at `at`, under o's edits; -1 at the end.
  int _head(_Way o, int at) {
    final es = _edits((null, 0, o)).$1;
    for (var q = at;; q++) {
      int? sub; var del = false;
      for (final (op, p, ch) in es) {
        if (p != q) continue;
        if (op == 1) return ch.abs();
        if (op == 0) del = true; else sub = ch.abs();
      }
      if (sub != null) return sub;
      if (!del) return q < _len ? parser.input.codeUnitAt(q) : -1;
    }
  }

  _Way _subst(int at, peg.Clause lit) { final w = _Way.skip(at, at + 1, 1); _subOf[w.piece!] = lit; return w; }

  // The edits a repair makes (op 0 delete, 1 insert, 2 substitute), read
  // off its pieces in input order; null if a piece is not one this engine
  // builds.
  (List<(int, int, int)>, bool) _edits(Object root) {
    final out = <(int, int, int)>[]; var fake = false;
    for (final todo = [root]; todo.isNotEmpty;) {
      switch (todo.removeLast()) {
        case (_, _, final _Way w):
          for (_Way? r = w; r != null; r = r.prev) { if (r.piece case final p?) todo.add(p); }
        case final peg.SyntaxError m:
          if (_subOf[m] case final l?) { out.add((2, m.pos, Exact.code(l as peg.Terminal, 0))); } else { for (var q = m.pos; q < m.pos + m.len; q++) { out.add((0, q, 0)); } }
        case peg.MatchResult(:final peg.Terminal clause, :final pos, subClauseMatches: [peg.SyntaxError(len: 0)]):
          out.add((1, pos, Exact.code(clause, 0)));
        case peg.Clause(): fake = true;
      }
    }
    return (out, fake);
  }

  // The tree of the cheapest repair found, checked by parsing the repaired
  // string; when the check fails, the exact search over repaired strings.
  peg.MatchResult recover(String input) {
    try {
      final r = _recover(input);
      if (r is peg.MatchResult) return (path = 'plain', r).$2;
      if (r case (final peg.MatchResult m, final List<(int, int)> s)) {
        return (path = 'checked', _exact._map(m, s, input)).$2;
      }
      // A checked repair the loose search doubted: the exact search looks for
      // a cheaper one, within a linear amount of work.
      final b = _checked, x = _exact.recover(input, b == null ? _never : b.$1.spent + b.$1.owed, _exactPer * (_floor + _per * rules.length * (input.length + 1)));
      if (x != null) { lastCost = _exact.lastCost; return (path = 'exact', x).$2; }
      lastCost = b!.$1.spent + b.$1.owed; return (path = 'proved', _exact._map(b.$2!, b.$3, input)).$2;
    } on _Stop {
      if (_checked case final b?) { lastCost = b.$1.spent + b.$1.owed; return (path = 'bounded', _exact._map(b.$2!, b.$3, input)).$2; }
      return (path = 'none', peg.SyntaxError(pos: 0, len: input.length)).$2;
    } on StackOverflowError { return (path = 'unchecked', peg.SyntaxError(pos: 0, len: input.length)).$2; }
  }

  // The parse when the input is valid, else the cheapest repair found (null
  // if none).
  Object? _recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    _cells.clear(); _evidence.clear(); _versions.clear(); _nexts.clear(); _checked = null; _doubt = false; final top = parser.rules[topRuleName]!;
    _Way.maxOwed = rules.values.fold(0, (a, r) => a + (_min0(r) < _never ? _min0(r) : 0));
    void sweep(void Function(peg.Clause, int) fn) {
      for (var p = _len; p >= 0; p--) { for (final r in parser.rules.values) { if (r is! peg.Ref) fn(r, p); } }
    }
    var deep = false; late peg.MatchResult verdict;
    try { verdict = parser.match(top, 0); } on StackOverflowError {
      deep = true; parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
      sweep(parser.match); verdict = parser.match(top, 0);
    }
    if (!verdict.isMismatch && verdict.len == _len) { lastCost = 0; return verdict; }
    final shortest = _min0(top), ceiling = shortest == _never ? -1 : _len + shortest;
    (_Way, peg.MatchResult?, List<(int, int)>)? best;
    // Budgets double until one finds an answer, each rung bounding the
    // answer's cost. Past _cap, once the work passes _floor proposals plus
    // _per per rule and input position (a cost bound keeps every reading of
    // equal cost, cubic on `x (ab)*`), the search starts again from rung 1 with
    // the rung bounding only `used`, cells keeping one way per end, last edit and owed,
    // and no deletion before the top rule.
    (_Way, peg.MatchResult?, List<(int, int)>)? run(int rung) {
      (_Way, peg.MatchResult?, List<(int, int)>)? b, u;
      _budget = rung; if (!_local) _rung = rung; List<_Way> ways;
      try { if (deep) sweep(_read); ways = _read(top, 0); } on StackOverflowError {
        // The overflow can stop the library parser mid-match, so its memo is rebuilt.
        deep = true; _depth = 0; _seedDepth = _never; _budget = rung;
        parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
        _cells.clear(); _versions.clear(); sweep(parser.match); sweep(_read); ways = _read(top, 0);
      }
      // A deletion before the top rule: the top rule read after each prefix
      // the rung can pay for, after the ways from 0.
      Iterable<(_Way?, _Way)> all() sync* {
        for (final r in ways) { yield (null, r); }
        if (rung == 0 || _len == 0 || _local) return;
        for (var p = 1; p <= _min(rung, _len); p++) { for (final r in _read(top, p)) { yield (_Way.skip(0, p), r); } }
      }
      for (final (lead, r0) in all()) {
        final r = lead == null ? r0 : lead.then(r0); if (r == null) continue;
        final tail = _len - r.end, w = tail == 0 ? r : r.then(_Way.skip(r.end, _len));
        if (w == null || (_local ? w.used : w.cost) > rung || w.clean) continue;
        if (b != null && w.cmp(b.$1) >= 0) continue;
        final (es, fake) = _edits((null, 0, w));
        final s = Exact.apply(input, es), str = String.fromCharCodes(s.map((x) => x.$2)), m = _exact.parse(str);
        if (!m.isMismatch && m.len == str.length) {
          b = (w, m, s);
        } else if (!fake && w.owed <= 1 && (u == null || w.cmp(u.$1) < 0)) {
          u = (w, null, s);
        }
      }
      if (b != null && (_checked == null || b.$1.cmp(_checked!.$1) < 0)) _checked = b;
      if (u != null && (b == null || u.$1.cost < b.$1.cost)) _doubt = true;
      return b;
    }
    var lo = 0; _rung = 1; _work = 0; _limit = _floor + _per * parser.rules.length * (_len + 1);
    for (var b = 1; best == null && lo < ceiling;) {
      try {
        if ((best = run(_min(b, ceiling))) == null) lo = _min(b, ceiling);
        b *= 2;
      } on _Stop {
        _rung = 0; b = 1; lo = 0; _limit = _never; _depth = 0; _seedDepth = _never; _cells.clear(); _versions.clear();
      }
    }
    lastCost = best == null ? (_len == 0 ? 1 : _len) : best.$1.spent + best.$1.owed;
    return best == null || _doubt ? null : (best.$2!, best.$3);
  }
}

// The exact search: repaired strings in order of cost, each parsed by the
// library parser over a copy of the grammar whose terminals record the last
// position the parse examined. An edit after that position cannot change the
// parse, so the next edit goes between the last one and it.

// A terminal that records what it examines, and the characters it compares
// against the unknown character at `_Exact.sym`.
class _Probe extends peg.Terminal {
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
  int far = -1, sym = -1, lastCost = 0; Set<int> seen = {};

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
    far = -1;
    var p = peg.Parser(rules: _rules, topRuleName: top, input: w);
    try { return p.matchRule(top, 0); } on StackOverflowError {
      p = peg.Parser(rules: _rules, topRuleName: top, input: w);
      for (var q = w.length; q >= 0; q--) { for (final r in p.rules.values) { p.match(r, q); } }
      return p.matchRule(top, 0);
    }
  }

  // The cheapest repair of fewer than `edits` edits (null if none), `work`
  // bounding the characters parsed; past it, _Stop.
  peg.MatchResult? recover(String input, int edits, int work) {
    final seenStates = <String, (List<List<(int, int, int)>>, int)>{};
    var level = [<(int, int, int)>[]];
    for (var cost = 0;; cost++) {
      if (cost >= edits) return null;
      final next = <List<(int, int, int)>>[]; List<(int, int, int)>? best; peg.MatchResult? bestTree; List<(int, int)>? bestS;
      for (final es in level) {
        final s = apply(input, es), w = String.fromCharCodes([for (final x in s) x.$2]);
        if ((work -= w.length + 1) < 0) throw _Stop();
        final m = parse(w);
        if (!m.isMismatch && m.len == w.length) {
          if (best == null || _cmp(es, best) < 0) { best = es; bestTree = m; bestS = s; }
          continue;
        }
        if (best != null) continue;
        final f = !m.isMismatch && m.len > far ? m.len : far;
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
            if ((work -= cs.length + 1) < 0) throw _Stop();
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
        lastCost = best.length;
        return _map(bestTree!, bestS!, input);
      }
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

  // The parse tree of the repaired string `s`, mapped back onto the input.
  peg.MatchResult _map(peg.MatchResult root, List<(int, int)> s, String input) {
    int at(int q) => s[q].$1 >= 0 ? s[q].$1 : s[q].$1 <= -2 ? -2 - s[q].$1 : -1;
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
    // A substitution under a root or a Ref names its literal in a one-arm
    // choice; elsewhere the parent names it.
    peg.MatchResult letter(peg.Clause l, int q, [bool own = false]) {
      final o = orig[q];
      if (s[q].$1 >= 0) { next = o + 1; return peg.Match(l, o, 1); }
      if (s[q].$1 <= -2) { next = o + 1; final e = peg.SyntaxError(pos: o, len: 1); return own ? peg.Match(peg.First([l]), o, 1, subClauseMatches: [e]) : e; }
      return peg.Match(l, o, 0, subClauseMatches: [peg.SyntaxError(pos: o, len: 0)]);
    }
    // The nodes standing for `m` over the input, added to `into`: input
    // deleted before it, then `m` itself. A node is finished after its
    // children, so each pushes its own completion before them.
    final todo = <void Function()>[];
    void walk(peg.MatchResult m, List<peg.MatchResult> into, [peg.Clause? up]) {
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
          if (m.len == 1) { into.add(letter(c!, m.pos, up == null || up is peg.Ref)); return; }
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
      for (final k in m.subClauseMatches.reversed) { todo.add(() => walk(k, kids, c)); }
    }
    final ts = <peg.MatchResult>[];
    for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) { todo.removeLast()(); }
    ts.addAll(gap(input.length));
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }
}
