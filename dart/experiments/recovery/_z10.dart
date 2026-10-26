import 'package:squirrel_parser/squirrel_parser.dart' as peg;
import '_f25k.dart' as exact;

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
  int get paired => _min(deleted, spent - deleted + owed);
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
    d = d != 0 ? d : b.first - first; d = d != 0 ? d : last - b.last; d = d != 0 ? d : owed - b.owed;
    return d != 0 ? d : paired - b.paired;
  }
}

class _Cell {
  int mark = -1, ver = -1, dep = 0, arm = 0; bool seeded = false;
  final ends = <_Way>[];
  bool add(_Way? r) {
    if (r == null) return false;
    for (var i = 0; i < ends.length; i++) {
      if (ends[i] case final e when e.end == r.end && e.used == r.used && e.incomplete == r.incomplete) {
        final c = e.cmp(r); if (c >= 0) ends[i] = r; return c > 0;
      }
    }
    ends.add(r); return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName}) : _exact = exact.Squirrel(rules: rules, topRuleName: topRuleName);
  final exact.Squirrel _exact; String path = ''; final _subOf = Map<Object, peg.Clause>.identity();
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _versions = <int, int>{}, _shapes = <peg.Clause, bool>{}, _tot = <peg.Clause, bool>{}, _mins = <peg.Clause, int>{}, _chars = <peg.Str, List<peg.Clause>>{};
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

  bool _total(peg.Clause c, int at, [Set<peg.Clause> p = const {}]) => (at < 0 || (_tot[c] ??= _total(c, -1))) && !p.contains(c) && (at < 0 || !_active(c, at)) && switch (c) {
    peg.Optional() || peg.ZeroOrMore() || peg.Nothing() => true,
    peg.FollowedBy() => _total(c.subClause, at, {...p, c}),
    peg.NotFollowedBy() => _min0(c.subClause) == _never,
    peg.Seq() => c.subClauses.every((s) => _total(s, at, {...p, c})),
    peg.First() => c.subClauses.any((s) => _total(s, at, {...p, c})),
    peg.Ref() => _total(parser.rules[c.ruleName]!, at, {...p, c}),
    _ => false,
  };

  String _key(peg.Clause c) => _str[c] ??= '${c is peg.Str && c.text.length == 1 ? peg.Char(c.text) : c}';

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) _Way.clean(pos).trim(rs.fold(f, (m, r) => r.clean && r.end > pos && r.end < m ? r.end : m)), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[];
    var cut = _never, sd = _seedDepth, nul = false;
    for (var i = 0; i < (c as peg.First).subClauses.length; i++) {
      final sub = c.subClauses[i];
      cell.arm = i;
      final act = _active(sub, pos);
      if (out.isNotEmpty && act) continue;
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      if (act) sd = _min(sd, _seedDepth);
      for (final r in rs) {
        if (nul && r.first > pos || cut < _never && (r.clean || r.first >= cut || r.absorbed(pos) >= r.evidence)) continue;
        if (_seedDepth < _never && r.end > pos) sd = _min(sd, _seedDepth);
        out.add(cut < _never || nul ? r.demote() : r);
      }
      if (f > pos) cut = _min(cut, f);
      if (!act && (_total(sub, pos) || rs.any((r) => r.preferred && r.end == pos) && !(nul = true))) break;
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
          if (s.end <= r.end || s.end - r.end == s.deleted && s.subs == 0 && s.spent == s.deleted || s.clean && s.cut < _never - 1 ||
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

  // The edits a tree makes (op 0 delete, 1 insert, 2 substitute), in input
  // order; null if a node is not one this engine builds. A character of an
  // open class is a negative placeholder (D7).
  List<(int, int, int)>? _edits(peg.MatchResult t) {
    int? code(peg.Clause? c) => switch (c) {
      peg.Char(:final char) => char.codeUnitAt(0),
      peg.Str(:final text) when text.length == 1 => text.codeUnitAt(0),
      peg.CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => -ranges[0].$1,
      peg.CharSet(:final ranges, inverted: true) => -[for (var x = 32; x < 0x10000; x++) x].firstWhere((x) => !ranges.any((r) => x >= r.$1 && x <= r.$2)),
      peg.AnyChar() => -32,
      _ => null,
    };
    final out = <(int, int, int)>[];
    for (final todo = [t]; todo.isNotEmpty;) {
      final m = todo.removeLast(), ks = m.subClauseMatches;
      if (m is peg.SyntaxError) {
        if (_subOf[m] case final l?) { out.add((2, m.pos, code(l)!)); } else { for (var q = m.pos; q < m.pos + m.len; q++) { out.add((0, q, 0)); } }
      } else if (ks.length == 1 && ks[0] is peg.SyntaxError && ks[0].len == 0) {
        final ch = code(m.clause); if (ch == null) return null; out.add((1, m.pos, ch));
      } else {
        todo.addAll(ks.reversed);
      }
    }
    return out..sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : (a.$1 == 1 ? 0 : 1) - (b.$1 == 1 ? 0 : 1));
  }

  peg.MatchResult _tree(Object root) {
    if (root is peg.MatchResult) return root;
    final built = Map<Object, peg.MatchResult>.identity();
    for (final todo = [root]; todo.isNotEmpty;) {
      final piece = todo.last as (peg.Clause?, int, _Way), pos = piece.$2, inner = piece.$3, kids = <peg.MatchResult>[];
      for (_Way? r = inner; r != null; r = r.prev) {
        if (r.piece case final p?) p is peg.MatchResult ? kids.add(p) : built[p] != null ? kids.add(built[p]!) : todo.add(p);
      }
      if (todo.last == piece) {
        todo.removeLast(); final c = inner.end == pos && pos == _len ? null : piece.$1;
        built[piece] = kids.isEmpty ? peg.Match(c, pos, inner.end - pos) : peg.Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
      }
    }
    return built[root]!;
  }

  // The tree of the cheapest repair found, checked by parsing the repaired
  // string; when the check fails, the exact search over repaired strings.
  peg.MatchResult recover(String input) {
    final t = _recover(input);
    if (lastCost == 0) return (path = 'plain', t).$2;
    final es = t is peg.SyntaxError ? null : _edits(t);
    try {
      _exact.begin(input);
      if (es != null) { if (_exact.check(input, es) case final x?) return (path = 'checked', x).$2; }
      final x = _exact.recover(input); lastCost = _exact.lastCost; return (path = 'exact', x).$2;
    } on StackOverflowError { return (path = 'unchecked', t).$2; }
  }

  peg.MatchResult _recover(String input) {
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
    final shortest = _min0(top), ceiling = shortest == _never ? -1 : _len + shortest; _Way? best, fallback;
    for (var rung = 1; rung <= ceiling; rung++) {
      _budget = rung; final inc = <_Way>[]; List<_Way> ways;
      try { if (deep) sweep(_read); ways = _read(top, 0); } on StackOverflowError {
        deep = true; _depth = 0; _seedDepth = _never; _budget = rung;
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
