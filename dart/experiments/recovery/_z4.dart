import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _clean = 1 << 30, _preferred = _clean + 1, _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

class _Way {
  const _Way(this.end, this.deleted, this.missing, this.evidence, this.first,
      [this.piece, this.owed = 0, this.incomplete = false, this.subs = 0,
      this.fee = 0, this.credit = 0, this.cut = _never, this.prev, int? last])
      : last = last ?? (first >= _clean ? -1 : first);
  const _Way.empty(int p) : this(p, 0, 0, 0, _preferred);
  _Way.skip(int a, int b, [int s = 0])
      : this(b, b - a, 0, 0, a, peg.SyntaxError(pos: a, len: b - a), 0, false, s, 0, 0, _never, null, b);
  final int end, deleted, missing, owed, subs, evidence, first, fee, credit, cut, last;
  final bool incomplete;
  final Object? piece;
  final _Way? prev;
  bool get clean => first >= _clean;
  bool get preferred => first > _clean;
  int get spent => deleted + missing;
  int get used => spent > credit ? spent - credit : 0;
  int get cost => spent + (owed == 0 ? 0 : 1);
  int absorbed(int from) => end - from - deleted - evidence;
  int get charge => cost + fee + (!clean && absorbed(0) > evidence ? 1 : 0);
  bool pureSub(int from) => subs > 0 && cost == subs && absorbed(from) == 0;
  bool synced(int from, [int gap = 1]) => spent > 0 && end > last + gap && evidence > absorbed(from) + 1;
  _Way? then(_Way r) {
    var c = r.cut;
    if (cut < _never && (r.clean || r.first >= cut)) {
      if (r.end >= cut) return null;
      c = _min(cut, c);
    }
    return _Way(r.end, deleted + r.deleted, missing + r.missing,
        evidence + r.evidence, _min(first, r.first), r.piece, owed + r.owed,
        r.incomplete || (r.end == end && incomplete), subs + r.subs, fee + r.fee,
        credit + r.credit, c, this, last > r.last ? last : r.last);
  }
  _Way copy({int? rk, int? fee, int? cr, int? cut, Object? p}) => _Way(
      end, deleted, missing, evidence, rk ?? first, p ?? piece, owed,
      incomplete, subs, fee ?? this.fee, cr ?? credit, cut ?? this.cut,
      p == null ? prev : null, last);
  _Way label(peg.Clause c, int pos) => copy(p: (c, pos, this));
  _Way demote([int sc = _never]) => copy(rk: _min(first, _clean), cut: _min(cut, sc));
  _Way trim(int f) => preferred && f >= 0 && end != f ? demote(clean ? f : _never) : this;
  int cmp(_Way b) {
    if (charge != b.charge) return charge - b.charge;
    if (preferred != b.preferred) return preferred ? -1 : 1;
    if (evidence != b.evidence) return b.evidence - evidence;
    if (spent + owed != b.spent + b.owed) return spent + owed - b.spent - b.owed;
    if (first != b.first) return b.first - first;
    if (last != b.last) return last - b.last;
    if (owed != b.owed) return owed - b.owed;
    return _min(deleted, missing + owed) - _min(b.deleted, b.missing + b.owed);
  }
}

class _Cell {
  int mark = -1;
  final ends = <(int, bool, bool, int), _Way>{};
  bool add(_Way? r) {
    if (r == null) return false;
    final k = (r.end, r.incomplete, r.missing == 0, r.used), b = ends[k];
    if (b != null && b.cmp(r) < 0) return false;
    ends[k] = r;
    return b == null || r.cmp(b) < 0;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules;
  final String topRuleName;
  late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _zeroWays = Map<peg.MatchResult, _Way>.identity();
  final _evidence = Map<peg.MatchResult, int>.identity(), _versions = <int, int>{};
  final _shapes = <peg.Clause, bool>{}, _letters = <peg.Str, List<peg.Clause>>{};
  int _depth = 0, _seedDepth = _never;
  int _budget = 0, lastCost = 0;
  int get _len => parser.input.length;

  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) {
    if ((c is peg.FollowedBy || c is peg.NotFollowedBy) && _depth > 0) {
      final act = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e? when (_cells[e]?.mark ?? 0) < -1) (r, e)];
      if (act.isNotEmpty) {
        final saved = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e?) (e, e.result)];
        for (final (e, _) in saved) { e.result = null; }
        for (final (_, e) in act) { e..inRecPath = true..foundLeftRec = false; }
        ++parser.memoVersion[pos];
        final m = c.match(parser, pos);
        var rk = _preferred;
        if (!m.isMismatch && act.any((x) => x.$2.foundLeftRec)) {
          for (final (e, _) in saved) { e.result = null; }
          for (final (r, e) in act) { e.result = peg.Match(r, pos, 0); }
          ++parser.memoVersion[pos];
          if (c.match(parser, pos).isMismatch) rk = _clean;
        }
        for (final (_, e) in act) { e.inRecPath = false; }
        for (final (e, s) in saved) { e.result = s; }
        ++parser.memoVersion[pos];
        return m.isMismatch ? null : _Way(pos + m.len, 0, 0, _ev(m), rk, m);
      }
    }
    final m = parser.match(c, pos);
    return m.isMismatch ? null : _zeroWays[m] ??= _Way(pos + m.len, 0, 0, _ev(m), _preferred, m);
  }

  int _ev(peg.MatchResult m) {
    if (_evidence[m] case final v?) return v;
    for (final q = [m]; q.isNotEmpty;) {
      final n = q.last, c = n.clause, k = n.subClauseMatches;
      if (_evidence[n] != null) { q.removeLast(); continue; }
      if (c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet) { _evidence[n] = 0; continue; }
      var s = k.isEmpty && (c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted) ? n.len : 0, ok = true;
      for (final ch in k) { if (_evidence[ch] case final v?) { s += v; } else { q.add(ch); ok = false; } }
      if (ok) _evidence[n] = s;
    }
    return _evidence[m]!;
  }

  bool _oneLit(peg.Clause c) => c is peg.Char || c is peg.Str && c.text.length == 1;
  bool _oneShape(peg.Clause c) => _shapes[c] ??= switch (c) {
    peg.Seq() => (_shapes[c] = false) || c.subClauses.every(_oneShape),
    peg.Repetition() => (_shapes[c] = false) || c.requireOne && _oneShape(c.subClause),
    peg.Ref() => (_shapes[c] = false) || _oneShape(parser.rules[c.ruleName]!),
    peg.Terminal() || peg.FollowedBy() || peg.NotFollowedBy() => true,
    _ => false,
  };

  int _minChars(peg.Clause c, [Set<peg.Clause> p = const {}, bool req = false]) => p.contains(c) ? _never : switch (c) {
    peg.Seq() => switch (c.subClauses.fold(0, (int a, b) => _min(_never, a + _minChars(b, {...p, c})))) {
      0 when req => c.subClauses.fold(_never, (int a, b) => _min(a, _minChars(b, {...p, c}, true))),
      final n => n,
    },
    peg.First() => c.subClauses.fold(_never, (int a, b) => _min(a, _minChars(b, {...p, c}, req))),
    peg.Ref() => _minChars(parser.rules[c.ruleName]!, {...p, c}, req),
    peg.Repetition() when c.requireOne || req => _minChars(c.subClause, {...p, c}, true),
    peg.Optional() when req => _minChars(c.subClause, {...p, c}, true),
    peg.Str() => c.text.length,
    peg.Char() || peg.CharSet() || peg.AnyChar() => 1,
    _ => req ? _never : 0,
  };

  List<_Way> _read(peg.Clause c, int pos) {
    if (pos > _len || _budget < 0) return const [];
    final plain = _plain(c, pos);
    if (c is peg.FollowedBy || c is peg.NotFollowedBy || _budget == 0 && pos < _len) {
      return plain == null ? const [] : [plain];
    }
    if (c is peg.Terminal) {
      if (plain != null) return [plain];
      if (c is peg.Str && c.text.length > 1) {
        final letters = _letters.putIfAbsent(c, () => [for (final s in c.text.split('')) peg.Char(s)]);
        return [for (final r in _seq(letters, pos)) if (r.evidence > 0 || r.used + r.owed <= _budget) r.label(c, pos)];
      }
      final eof = pos == _len ? 1 : 0;
      return [_Way(pos, 0, 1 - eof, 0, pos,
          peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]), eof, true)];
    }
    if (c is peg.Ref) {
      return [for (final r in _read(parser.rules[c.ruleName]!, pos))
        if (r.evidence > 0 || r.subs == r.cost || r.clean || r.end == pos || _oneShape(c)) r.label(c, pos)];
    }
    if (c is peg.Repetition && c.subClause is peg.CharSet && plain != null) {
      final k = (plain.piece as peg.MatchResult).subClauseMatches;
      var w = _Way.empty(pos).demote(plain.end);
      return [
        if (!c.requireOne && k.isNotEmpty) w.label(c, pos),
        for (var i = 0; i < k.length - 1; i++)
          (w = w.then(_Way(k[i].pos + 1, 0, 0, c.requireOne ? _ev(k[i]) : 0, _clean, k[i]))!.demote(plain.end)).label(c, pos),
        plain,
      ];
    }
    final entry = parser.getMemoEntry(c, pos)!, cell = _cells[entry] ??= _Cell(), mark = ((pos == _len && _budget == 0 ? 1 : _budget) << 20) + (_versions[pos] ?? 0);
    if (cell.mark < -1) {
      final d = -cell.mark >> 1;
      cell.mark = -2 * d - 1; _seedDepth = _min(_seedDepth, d);
    } else if (cell.mark < mark) {
      final d = ++_depth, outer = _seedDepth;
      var minSeed = _never;
      cell.mark = -2 * d;
      do {
        _seedDepth = _never;
        var improved = false;
        for (final r in _propose(c, pos)) {
          if ((r.clean && r.cut >= (plain?.end ?? _never) || plain?.end != r.end) && cell.add(r)) improved = true;
        }
        minSeed = _min(minSeed, _seedDepth);
        if (!improved || !cell.mark.isOdd || _seedDepth > d) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1;
      } while (true);
      _depth--;
      cell.mark = (mark & ~0xFFFFF) + (minSeed < d ? _versions[pos] ?? 0 : 0xFFFFF);
      _seedDepth = _min(outer, minSeed < d ? minSeed : _never);
    }
    final raw = cell.ends.values, farthest = _farthest(raw);
    return [for (final r in raw) if (r.used <= _budget)
      r.preferred && r.end == farthest && plain?.end == r.end ? plain! : (cell.mark < 0 ? r : r.trim(farthest)).label(c, pos)];
  }

  bool _active(peg.Clause c, int at) => c is peg.Ref && (_cells[parser.getMemoEntry(parser.rules[c.ruleName]!, at)]?.mark ?? 0) < -1;

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) _Way.empty(pos).trim(rs.fold(f, (m, r) => r.clean && r.end > pos && r.end < m ? r.end : m)), ...rs];
    }
    final out = <_Way>[]; var cut = _never, seeded = _seedDepth;
    for (final sub in (c as peg.First).subClauses) {
      final act = _active(sub is peg.HasOneSubClause ? sub.subClause : sub, pos);
      if (out.isNotEmpty && act) continue;
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      for (final r in rs) {
        if (cut < _never && (r.clean || r.first >= cut || r.absorbed(pos) >= r.evidence)) continue;
        if (_seedDepth < _never && r.end > pos) seeded = _min(seeded, _seedDepth);
        out.add(cut < _never ? r.demote() : r);
      }
      if (f >= 0) cut = _min(cut, f);
      if (!act && rs.any((r) => r.preferred && r.end == pos)) break;
    }
    if (out.isNotEmpty) _seedDepth = seeded;
    if (cut == _never && _budget > 0 && pos < _len && {for (final s in c.subClauses) if (_oneLit(s)) '$s'}.length == 1) {
      out.add(_Way.skip(pos, pos + 1, 1));
    }
    return out;
  }

  static int _farthest(Iterable<_Way> rs) => rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Ref() => (_plain(c, at)?.end ?? at) > at || _startsClean(parser.rules[c.ruleName]!, at, s),
    peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
    peg.Seq() => c.subClauses.isNotEmpty && (_plain(c.subClauses[0], at)?.end ?? at) > at,
    _ => false,
  };

  void _tails(Object? p, int end, List<peg.Clause> out) {
    if (p is (peg.Clause?, int, _Way)) {
      final (c, pos, r) = p;
      if (c is peg.Repetition) { out.add(c.subClause); } else if (c != null && pos == end && r.clean) { out.add(c); }
      for (_Way? x = r; x != null && x.end == end; x = x.prev) {
        _tails(x.piece, end, out);
        if (!x.clean || (x.prev?.end ?? pos) < end) break;
      }
    } else if (p is peg.MatchResult && !p.isMismatch && p.clause is! peg.Terminal) {
      if (p.clause case final c?) { if (c is peg.Repetition) { out.add(c.subClause); } else if (p.len == 0) { out.add(c); } }
      for (final k in p.subClauseMatches.reversed) {
        if (k.pos + k.len == end) _tails(k, end, out);
        if (k.len > 0 || k.clause is peg.Terminal) break;
      }
    }
  }

  bool _matchesOne(peg.Clause c, String ch, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Char() => c.char == ch,
    peg.Str() => c.text == ch,
    peg.CharSet() => c.inverted != c.ranges.any((r) => ch.codeUnitAt(0) >= r.$1 && ch.codeUnitAt(0) <= r.$2),
    peg.AnyChar() => true,
    peg.Ref() => _matchesOne(parser.rules[c.ruleName]!, ch, s),
    peg.First() => c.subClauses.any((x) => _matchesOne(x, ch, s)),
    peg.Repetition(:final subClause) || peg.Optional(:final subClause) => _matchesOne(subClause, ch, s),
    peg.Seq() => c.subClauses.isNotEmpty && _matchesOne(c.subClauses[0], ch, s) &&
        c.subClauses.skip(1).every((x) => _minChars(x) == 0),
    _ => false,
  };

  Object? _firstEdit(Object? p, int at) {
    for (Object? n; p is (peg.Clause?, int, _Way); p = n, n = null) {
      for (_Way? x = p.$3; x != null; x = x.prev) { if (x.piece != null && !(x.clean && x.end == at)) n = x.piece; }
    }
    return p;
  }

  List<_Way> _seq(List<peg.Clause> slots, int pos) {
    var cur = [_Way.empty(pos)];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i], next = _Cell();
      for (final r in cur) {
        if (r.used > _budget) continue;
        final rSub = r.pureSub(pos) && slot is peg.Repetition;
        final canSettle = r.used > 0 && (slot is peg.Repetition && r.synced(pos) || rSub ||
            r.deleted == 0 && r.end == pos && _startsClean(slot, r.end));
        final whole = _budget; _budget = canSettle ? whole : whole - r.used;
        final options = _read(slot, r.end); _budget = whole;
        List<peg.Clause>? tails;
        List<peg.Clause> getTails() { if (tails == null) _tails(i == 0 ? null : (null, pos, r), r.end, tails = []); return tails!; }
        var deletedAhead = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final syncSkip = r.used > 0 && i == slots.length - 1 && slots.length > 2 && r.synced(pos);
          final base = syncSkip ? r.copy(cr: r.spent) : r, room = _budget - (syncSkip ? 0 : r.cost);
          for (var j = r.end + 1; j <= r.end + room && j <= _len; j++) {
            final clean = _plain(slot, j);
            if (clean == null || clean.end == j && (syncSkip || options.any((o) => o.clean))) continue;
            if (!getTails().any((u) => (_plain(u, j)?.end ?? j) > j)) next.add(base.then(_Way.skip(r.end, j))?.then(clean));
            deletedAhead = j - r.end; break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(slot) && (r.used + 1 < _budget || _resumes(slots, i, r.end + 1)) &&
              !getTails().any((u) => _matchesOne(u, slot is peg.Char ? slot.char : (slot as peg.Str).text))) {
            next.add(r.then(_Way.skip(r.end, r.end + 1, 1)));
          }
        }
        final penalize = deletedAhead > 0 && i != slots.length - 1 && !_active(slot, r.end) && !_oneShape(slot);
        bool settles(_Way o) => canSettle && o.first > r.end &&
            (rSub ? o.pureSub(r.end) && o.evidence > 0 : o.synced(r.end, 0) && (o.credit == 0 || o.first > r.last + 1));
        final mustAdvance = r.evidence == 0 && slot is peg.Repetition &&
            (r.incomplete && !_oneShape(slot.subClause) || rSub && options.any(settles));
        for (final o in options) {
          if (mustAdvance && o.end == r.end) continue;
          if (i > 0 && o.first == r.end && getTails().isNotEmpty) {
            final ed = _firstEdit(o.piece, r.end);
            if (ed is peg.MatchResult && ed.clause is peg.Char && getTails().any((u) => _matchesOne(u, (ed.clause as peg.Char).char))) continue;
            if (ed is peg.SyntaxError && ed.len > 0 && o.subs == 0 && getTails().any((u) => (_plain(u, r.end + ed.len)?.end ?? 0) > r.end + ed.len)) continue;
          }
          final base = settles(o) ? r.copy(cr: r.spent) : r;
          final w = base.then(penalize && o.end == r.end && !o.clean && deletedAhead <= o.missing ? o.copy(fee: o.fee + 1) : o);
          if (w != null && w.used + (i == 1 && r.owed > 1 && o.owed > 0 ? r.owed : 0) <= whole) next.add(w);
        }
      }
      cur = next.ends.values.toList();
      if (cur.isEmpty) break;
    }
    return cur;
  }

  bool _resumes(List<peg.Clause> s, int i, int at) => i + 1 >= s.length || switch (_plain(s[i + 1], at)) {
    final r? => r.end > at || _resumes(s, i + 1, at), _ => false
  };

  List<_Way> _repeat(peg.Repetition c, int pos) {
    final zero = _Way.empty(pos), best = _Cell(), q = <int, _Cell>{pos: _Cell()..add(zero)};
    while (q.isNotEmpty) {
      for (var r in q.remove(q.keys.reduce(_min))!.ends.values) {
        final startEnd = r.end;
        for (var m1 = _plain(c.subClause, r.end); m1 != null && m1.end > r.end && m1.evidence > 0;) {
          final m2 = _plain(c.subClause, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null;
          if (next == null) break;
          if (r.end > pos && c.subClause is peg.Terminal) best.add(r);
          r = next; m1 = m2!;
        }
        if (r.end > startEnd) {
          if (best.add(r)) (q[r.end] ??= _Cell()).add(r);
          continue;
        }
        if (r.used > _budget) continue;
        var d = r;
        while (d.prev != null && d.spent == d.prev!.spent) { d = d.prev!; }
        final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0);
        final rSub = c.subClause is peg.Ref && r.pureSub(pos) && dEv > 0;
        final canSettle = r.used > 0 && (rSub || (cleanTail || r.end > r.last + 1) && dEv > 1 && r.evidence > r.absorbed(pos) + 1);
        final whole = _budget; _budget = canSettle ? whole : whole - r.used;
        final steps = _read(c.subClause, r.end); _budget = whole;
        if (c.subClause is! peg.CharSet && !_active(c.subClause, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
          for (var j = r.end + 1; j <= r.end + _budget - r.cost && j <= _len; j++) {
            final clean = _plain(c.subClause, j);
            if (clean == null || clean.end == j || clean.evidence == 0) continue;
            final w = r.then(_Way.skip(r.end, j))?.then(clean);
            if (w != null && best.add(w)) (q[w.end] ??= _Cell()).add(w);
            break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(c.subClause)) {
            final w = r.then(_Way.skip(r.end, r.end + 1, 1));
            if (w != null && best.add(w)) (q[w.end] ??= _Cell()).add(w);
          }
        }
        bool syncs(_Way s) => (_plain(c.subClause, s.end)?.end ?? 0) > s.end;
        final anySync = canSettle && steps.any((s) => s.end > r.end && syncs(s));
        for (var step in steps) {
          if (step.end <= r.end || step.end - r.end == step.deleted && step.subs == 0 && step.missing == 0 || step.clean && step.cut < _never || r.end > pos && c.subClause is peg.Terminal && step.owed >= step.evidence) continue;
          var longer = r.then(step);
          if (longer == null) continue;
          if (canSettle && !step.clean && (!step.incomplete || step.first == step.end) &&
              (!anySync && rSub && step.pureSub(r.end) && step.evidence > 0 ||
               step.evidence > 1 && (syncs(step) ? cleanTail || step.first > r.end : cleanTail && !anySync && step.evidence > step.absorbed(r.end)))) {
            longer = longer.copy(cr: r.spent + step.credit);
          }
          if (longer.used <= whole && best.add(longer)) (q[longer.end] ??= _Cell()).add(longer);
        }
      }
    }
    if (best.ends.isEmpty) {
      for (final r in _read(c.subClause, pos)) { if (r.end == pos && !r.clean) best.add(zero.then(r)?.demote()); }
    }
    if (!c.requireOne) best.add(zero);
    final ways = best.ends.values, f = _farthest(ways);
    return [for (final r in ways) switch (_plain(c.subClause, r.end)?.end ?? r.end) {
      final sc when sc > r.end && !(r.end == pos && _seedDepth < _never) => r.demote(sc),
      _ => !r.preferred || r.end == f ? r : r.demote(),
    }];
  }

  peg.MatchResult _tree(Object root, int rootEnd) {
    final built = Map<Object, peg.MatchResult>.identity();
    for (final todo = <(Object, int, bool)>[(root, rootEnd, false)]; todo.isNotEmpty;) {
      final (piece, end, ready) = todo.removeLast();
      if (piece is peg.MatchResult) { built[piece] = piece; continue; }
      if (built[piece] != null) continue;
      final (label, pos, inner) = piece as (peg.Clause?, int, _Way);
      if (!ready) {
        todo.add((piece, end, true));
        for (_Way? r = inner; r != null; r = r.prev) {
          if (r.piece != null && built[r.piece!] == null) todo.add((r.piece!, r.end, false));
        }
      } else {
        final kids = [for (_Way? r = inner; r != null; r = r.prev) if (r.piece != null) built[r.piece!]!];
        final c = end == pos && pos == _len ? null : label;
        built[piece] = kids.isEmpty ? peg.Match(c, pos, end - pos) : peg.Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
      }
    }
    return built[root]!;
  }

  peg.MatchResult recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    _cells.clear(); _zeroWays.clear(); _evidence.clear(); _versions.clear();
    final top = parser.rules[topRuleName]!;
    void sweep(void Function(peg.Clause, int) fn) {
      for (var p = _len; p >= 0; p--) { for (final r in parser.rules.values) { if (r is! peg.Ref) fn(r, p); } }
    }
    var deep = false;
    late peg.MatchResult verdict;
    try {
      verdict = parser.match(top, 0);
    } on StackOverflowError {
      deep = true;
      parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
      sweep(parser.match);
      verdict = parser.match(top, 0);
    }
    if (!verdict.isMismatch && verdict.len == _len) { lastCost = 0; return verdict; }
    final shortest = _minChars(top), ceiling = shortest == _never ? -1 : _len + shortest;
    _Way? best, fallback;
    for (var rung = 1; rung <= ceiling; rung++) {
      _budget = rung;
      final inc = <_Way>[];
      List<_Way> ways;
      try {
        if (deep) sweep(_read);
        ways = _read(top, 0);
      } on StackOverflowError {
        deep = true; _depth = 0; _seedDepth = _never; _budget = rung;
        for (final c in _cells.values) { if (c.mark < -1) c..mark = -1..ends.clear(); }
        sweep(parser.match); sweep(_read);
        ways = _read(top, 0);
      }
      for (final r in ways) {
        final tail = _len - r.end, w = tail == 0 ? r : r.then(_Way.skip(r.end, _len));
        if (w == null || w.charge - w.credit > _budget || w.first == _clean) continue;
        if (tail > 0 && r.incomplete) { inc.add(w); continue; }
        if (best == null || w.cmp(best) < 0) best = w;
      }
      if (best != null) {
        for (final r in inc) { if (r.charge <= best!.charge && r.evidence > best.evidence) best = r; }
        break;
      }
      if (fallback == null && inc.isNotEmpty) fallback = inc.reduce((a, b) => a.cmp(b) <= 0 ? a : b);
    }
    best ??= fallback;
    lastCost = best == null ? (_len == 0 ? 1 : _len) : best.spent + best.owed;
    return best == null ? peg.SyntaxError(pos: 0, len: _len)
        : _tree(best.prev == null && best.piece != null ? best.piece! : (null, 0, best), best.end);
  }
}
