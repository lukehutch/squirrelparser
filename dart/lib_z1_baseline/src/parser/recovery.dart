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
  bool synced(int from) => spent > 0 && !incomplete && end > last + 1 && evidence > absorbed(from) + 1;
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
  _Way copy({int? ev, int? rk, int? fee, int? cr, int? cut, Object? p}) => _Way(
      end, deleted, missing, ev ?? evidence, rk ?? first, p ?? piece, owed,
      incomplete, subs, fee ?? this.fee, cr ?? credit, cut ?? this.cut,
      p == null ? prev : null, last);
  _Way label(peg.Clause c, int pos) => copy(rk: _min(first, _preferred), p: (c, pos, this));
  _Way demote([int sc = _never]) => copy(rk: _min(first, _clean), cut: clean ? _min(cut, sc) : cut);
  int cmp(_Way b) {
    if (charge != b.charge) return charge - b.charge;
    if (preferred != b.preferred) return preferred ? -1 : 1;
    if (evidence != b.evidence) return b.evidence - evidence;
    if (first != b.first) return b.first - first;
    if (last != b.last) return last - b.last;
    if (owed != b.owed) return owed - b.owed;
    return _min(deleted, missing + owed) - _min(b.deleted, b.missing + b.owed);
  }
}

class _Cell {
  int budget = -1, version = -1;
  bool active = false, recursive = false, usedSeed = false;
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
  Map<Object, _Cell> _cells = Map.identity();
  Map<peg.MatchResult, _Way> _zeroWays = Map.identity();
  Map<peg.MatchResult, int> _evidence = Map.identity();
  final _versions = <int, int>{}, _shapes = <peg.Clause, bool>{}, _letters = <peg.Str, List<peg.Clause>>{};
  bool _seedRead = false;
  int _budget = 0, lastCost = 0;
  int get _len => parser.input.length;

  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) {
    final m = parser.match(c, pos);
    return m.isMismatch ? null : _zeroWays[m] ??= _Way(pos + m.len, 0, 0, _ev(m), _preferred, m);
  }

  int _ev(peg.MatchResult m) {
    if (_evidence[m] case final v?) return v;
    var s = 0;
    for (final q = [m]; q.isNotEmpty;) {
      final n = q.removeLast(), c = n.clause, k = n.subClauseMatches;
      if (c is peg.Repetition && !c.requireOne && c.subClause is peg.Terminal) continue;
      if (k.isEmpty && (c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted)) s += n.len;
      for (final ch in k) { _evidence[ch] != null ? s += _evidence[ch]! : q.add(ch); }
    }
    return _evidence[m] = s;
  }

  bool _oneShape(peg.Clause c) => _shapes[c] ??= switch (c) {
    peg.Seq() => (_shapes[c] = false) || c.subClauses.every(_oneShape),
    peg.Repetition() => (_shapes[c] = false) || c.requireOne && _oneShape(c.subClause),
    peg.Ref() => (_shapes[c] = false) || _oneShape(parser.rules[c.ruleName]!),
    peg.Terminal() || peg.FollowedBy() || peg.NotFollowedBy() => true,
    _ => false,
  };

  int _minChars(peg.Clause c, [Set<peg.Clause> p = const {}]) => p.contains(c) ? _never : switch (c) {
    peg.Seq() => c.subClauses.fold(0, (int a, b) => _min(_never, a + _minChars(b, {...p, c}))),
    peg.First() => c.subClauses.fold(_never, (int a, b) => _min(a, _minChars(b, {...p, c}))),
    peg.Ref() => _minChars(parser.rules[c.ruleName]!, {...p, c}),
    peg.Repetition() when c.requireOne => _minChars(c.subClause, {...p, c}),
    peg.Str() => c.text.length,
    peg.Char() || peg.CharSet() || peg.AnyChar() => 1,
    _ => 0,
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
        return [for (final r in _seq(letters, pos)) r.label(c, pos)];
      }
      final eof = pos == _len ? 1 : 0;
      return [_Way(pos, 0, 1 - eof, 0, pos,
          peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]), eof, true)];
    }
    if (c is peg.Ref) {
      return [for (final r in _read(parser.rules[c.ruleName]!, pos))
        if (r.evidence > 0 || r.subs == r.cost || r.clean || r.end == pos || _oneShape(c)) r.label(c, pos)];
    }
    if (c is peg.Repetition && c.subClause is peg.Terminal && plain != null) {
      final k = (plain.piece as peg.MatchResult).subClauseMatches;
      if (plain.end - pos == k.length) {
        var w = _Way.empty(pos).demote(plain.end);
        return [
          if (!c.requireOne && k.isNotEmpty) w.label(c, pos),
          for (var i = 0; i < k.length - 1; i++)
            (w = w.then(_Way(k[i].pos + 1, 0, 0, c.requireOne ? _ev(k[i]) : 0, _clean, k[i]))!.demote(plain.end)).label(c, pos),
          plain,
        ];
      }
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell();
    if (cell.active) {
      cell.recursive = _seedRead = true;
    } else if (cell.budget < _budget || cell.usedSeed && cell.version != (_versions[pos] ?? 0)) {
      cell.active = true;
      final outer = _seedRead;
      _seedRead = false;
      do {
        var improved = false;
        for (final r in _propose(c, pos)) {
          if ((r.clean && r.cut >= (plain?.end ?? _never) || plain?.end != r.end) && cell.add(r)) improved = true;
        }
        if (!improved || !cell.recursive) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1;
      } while (true);
      cell.usedSeed = _seedRead;
      _seedRead = outer || _seedRead;
      cell.active = false;
      cell.budget = _budget;
      cell.version = _versions[pos] ?? 0;
    }
    final raw = cell.ends.values, farthest = _farthest(raw);
    return [for (final r in raw)
      if (r.used <= _budget && (r.clean && r.cut >= (plain?.end ?? _never) || plain?.end != r.end))
        r.preferred && r.end == farthest && plain?.end == r.end ? plain!
            : (r.preferred && r.end != farthest ? r.demote(farthest) : r).label(c, pos)];
  }

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) f > pos ? _Way.empty(pos).demote(f) : _Way.empty(pos), ...rs];
    }
    final out = <_Way>[];
    var cut = _never, settled = false;
    for (final sub in (c as peg.First).subClauses) {
      final rs = _read(sub, pos), f = _farthest(rs);
      for (final r in rs) {
        if (settled && (r.clean && cut < _never || r.first >= cut || !r.clean && r.absorbed(pos) >= r.evidence)) continue;
        out.add(settled ? r.demote(cut) : r);
      }
      if (f >= 0) { settled = true; if (f > pos) cut = _min(cut, f); }
    }
    return out;
  }

  static int _farthest(Iterable<_Way> rs) =>
      rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Ref() => (_plain(c, at)?.end ?? at) > at || _startsClean(parser.rules[c.ruleName]!, at, s),
    peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
    peg.Seq() => c.subClauses.isNotEmpty && (_plain(c.subClauses[0], at)?.end ?? at) > at,
    _ => false,
  };

  List<_Way> _seq(List<peg.Clause> slots, int pos) {
    Iterable<_Way> cur = [_Way.empty(pos)];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i], next = _Cell(), farthest = _farthest(cur);
      for (final v in cur) {
        final r = v.preferred && v.end != farthest ? v.demote(farthest) : v;
        if (r.used > _budget) continue;
        final rSub = !r.incomplete && r.missing == 0 && r.subs == r.deleted && r.absorbed(pos) == 0 && slot is peg.Repetition;
        final canSettle = r.used > 0 && (slot is peg.Repetition && r.synced(pos) || rSub ||
            r.deleted == 0 && r.end == pos && _startsClean(slot, r.end));
        final whole = _budget;
        _budget = canSettle ? whole : whole - r.used;
        final options = _read(slot, r.end);
        _budget = whole;
        var deletedAhead = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final syncSkip = r.used > 0 && i == slots.length - 1 && slots.length > 2 && r.synced(pos);
          final base = syncSkip ? r.copy(cr: r.spent) : r;
          final room = _budget - (syncSkip ? 0 : r.cost);
          for (var j = r.end + 1; j <= r.end + room && j <= _len; j++) {
            final clean = _plain(slot, j);
            if (clean == null || clean.end == j && (syncSkip || options.any((o) => o.clean))) continue;
            next.add(base.then(_Way.skip(r.end, j))?.then(clean));
            deletedAhead = j - r.end;
            break;
          }
          if (r.used < _budget && r.end < _len &&
              (slot is peg.Char || slot is peg.Str && slot.text.length == 1 && (!r.preferred || _resumes(slots, i, r.end + 1)))) {
            next.add(r.then(_Way.skip(r.end, r.end + 1, 1)));
          }
        }
        final seed = slot is peg.Ref && (_cells[parser.getMemoEntry(parser.rules[slot.ruleName]!, r.end)]?.active ?? false);
        final penalize = deletedAhead > 0 && i != slots.length - 1 && !seed && !_oneShape(slot);
        bool settles(_Way o) => canSettle && !o.clean && !o.incomplete && o.first > r.end &&
            (rSub ? o.missing == 0 && o.subs == o.deleted && o.absorbed(r.end) == 0 && o.evidence > 0
                  : o.end > o.last && o.evidence > o.absorbed(r.end) + 1 && (o.credit == 0 || o.first > r.last + 1));
        final subSettled = rSub && r.evidence == 0 && options.any(settles);
        for (final o in options) {
          if (subSettled && o.end == r.end) continue;
          final base = settles(o) ? r.copy(cr: r.spent) : r;
          final w = base.then(penalize && o.end == r.end && !o.clean && deletedAhead <= o.missing
              ? o.copy(fee: o.fee + 1) : o);
          if (w != null && w.used <= whole) next.add(w);
        }
      }
      cur = next.ends.values;
      if (cur.isEmpty) break;
    }
    final farthest = _farthest(cur);
    return [for (final r in cur) r.preferred && r.end != farthest ? r.demote(farthest) : r];
  }

  bool _resumes(List<peg.Clause> s, int i, int at) => i + 1 >= s.length || switch (_plain(s[i + 1], at)) {
    final r? => r.end > at || _resumes(s, i + 1, at), _ => false
  };

  List<_Way> _repeat(peg.Repetition c, int pos) {
    final zero = _Way.empty(pos), best = _Cell(), q = <int, _Cell>{pos: _Cell()..add(zero)};
    if (!c.requireOne) best.add(zero);
    while (q.isNotEmpty) {
      for (var r in q.remove(q.keys.reduce(_min))!.ends.values) {
        final startEnd = r.end;
        for (var m1 = _plain(c.subClause, r.end); m1 != null && m1.end > r.end && m1.evidence > 0;) {
          final m2 = _plain(c.subClause, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null;
          if (next == null) break;
          r = next;
          m1 = m2!;
        }
        if (r.end > startEnd) {
          if (best.add(r)) (q[r.end] ??= _Cell()).add(r);
          continue;
        }
        if (r.used > _budget) continue;
        var d = r;
        while (d.prev != null && d.spent == d.prev!.spent) { d = d.prev!; }
        final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0);
        final rSub = c.subClause is peg.Ref && r.used > 0 && !r.incomplete && r.missing == 0 && r.subs == r.deleted && r.absorbed(pos) == 0 && dEv > 0;
        final canSettle = r.used > 0 && !r.incomplete && (cleanTail || r.end > r.last + 1 || rSub) && (rSub || dEv > 1 && r.evidence > r.absorbed(pos) + 1);
        final whole = _budget;
        _budget = canSettle ? whole : whole - r.used;
        final steps = _read(c.subClause, r.end);
        _budget = whole;
        bool syncs(_Way s) => (_plain(c.subClause, s.end)?.end ?? 0) > s.end;
        final anySync = canSettle && steps.any((s) => s.end > r.end && syncs(s));
        for (var step in steps) {
          if (step.end <= r.end || step.end - r.end == step.deleted && step.subs == 0 && step.missing == 0 || step.clean && step.cut < _never) continue;
          if (!c.requireOne && c.subClause is peg.Terminal) step = step.copy(ev: 0);
          var longer = r.then(step);
          if (longer == null) continue;
          final sSub = rSub && !anySync && !step.incomplete && step.missing == 0 && step.subs == step.deleted && step.absorbed(r.end) == 0 && step.evidence > 0;
          if (canSettle && !step.clean && (!step.incomplete || step.first == step.end) &&
              (sSub || step.evidence > 1 && (syncs(step) ? cleanTail || step.first > r.end : cleanTail && !anySync && step.evidence > step.absorbed(r.end)))) {
            longer = longer.copy(cr: r.spent + step.credit);
          }
          if (longer.used <= whole && best.add(longer)) (q[longer.end] ??= _Cell()).add(longer);
        }
      }
    }
    if (best.ends.isEmpty) {
      for (final r in _read(c.subClause, pos)) { if (r.end == pos) best.add(zero.then(r)?.demote()); }
    }
    final ways = best.ends.values, f = _farthest(ways);
    return [for (final r in ways) !r.preferred || r.end == f ? r : r.demote(_plain(c.subClause, r.end)?.end ?? _never)];
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
    _cells = Map.identity();
    _zeroWays = Map.identity();
    _evidence = Map.identity();
    _versions.clear();
    final top = parser.rules[topRuleName]!;
    late peg.MatchResult verdict;
    try {
      verdict = parser.match(top, 0);
    } on StackOverflowError {
      for (var p = _len; p >= 0; p--) {
        for (final r in parser.rules.values) {
          final e = parser.getMemoEntry(r, p);
          if (e != null && e.inRecPath) e..inRecPath = false..foundLeftRec = false..result = null;
        }
      }
      for (var p = _len; p >= 0; p--) {
        for (final r in parser.rules.values) { parser.match(r, p); }
      }
      verdict = parser.match(top, 0);
    }
    if (!verdict.isMismatch && verdict.len == _len) {
      lastCost = 0;
      return verdict;
    }
    final shortest = _minChars(top), ceiling = shortest == _never ? -1 : _len + shortest;
    _Way? best, fallback;
    for (_budget = 1; _budget <= ceiling; _budget++) {
      final inc = <_Way>[];
      List<_Way> ways;
      try {
        ways = _read(top, 0);
      } on StackOverflowError {
        for (final c in _cells.values) {
          if (c.active) c..active = false..ends.clear()..budget = -1;
        }
        _seedRead = false;
        for (var p = _len; p >= 0; p--) {
          for (final r in parser.rules.values) { _read(r, p); }
        }
        ways = _read(top, 0);
      }
      for (final r in ways) {
        final tail = _len - r.end, w = tail == 0 ? r : r.then(_Way.skip(r.end, _len));
        if (w == null) continue;
        var p = r;
        while (p.prev != null && p.owed > 0) { p = p.prev!; }
        final owedCredit = w.credit > 0 && w.owed > 0 && _len > (p.owed > 0 ? -1 : p.last) + 1 ? 1 : 0;
        if (w.charge - w.credit - owedCredit > _budget || w.first == _clean) continue;
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
    lastCost = best == null ? (_len == 0 ? 1 : _len) : best.deleted + best.missing + best.owed;
    return best == null ? peg.SyntaxError(pos: 0, len: _len)
        : _tree(best.prev == null && best.piece != null ? best.piece! : (null, 0, best), best.end);
  }
}
