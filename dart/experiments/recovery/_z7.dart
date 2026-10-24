import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _clean = 1 << 30, _preferred = _clean + 1, _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

class _Way {
  const _Way(this.end, this.deleted, this.edits, this.evidence, this.first,
      [this.piece, this.cut = _never, this.prev, int? last])
      : last = last ?? (first >= _clean ? -1 : (first << 1) | 1);
  const _Way.empty(int p) : this(p, 0, 0, 0, _preferred);
  _Way.skip(int a, int b, [int s = 0])
      : this(b, b - a, s << 26, 0, a, peg.SyntaxError(pos: a, len: b - a), _never, null, b << 1);
  final int end, deleted, edits, evidence, first, cut, last;
  final Object? piece;
  final _Way? prev;
  int get missing => edits & 0x1FFF;
  int get owed => (edits >> 13) & 0x1FFF;
  int get subs => (edits >> 26) & 0xFFF;
  int get fee => (edits >> 38) & 0xFFF;
  int get credit => edits >> 50;
  bool get incomplete => last > end << 1;
  bool get clean => first >= _clean;
  bool get preferred => first > _clean;
  int get spent => deleted + missing;
  int get used => spent > credit ? spent - credit : 0;
  int get cost => spent + (owed == 0 ? 0 : 1);
  int absorbed(int from) => end - from - deleted - evidence;
  int get charge => cost + fee + (!clean && absorbed(0) > evidence ? 1 : 0);
  bool pureSub(int from) => subs > 0 && cost == subs && absorbed(from) == 0;
  bool synced(int from, [int gap = 1]) => spent > 0 && end > (last >> 1) + gap && evidence > absorbed(from) + 1;
  _Way? then(_Way r, [int d = 0]) =>
      cut < _never && (r.clean || r.first >= cut) && r.end >= cut ? null
      : _Way(r.end, deleted + r.deleted, edits + r.edits + d, evidence + r.evidence, _min(first, r.first), r.piece,
          cut < _never && (r.clean || r.first >= cut) ? _min(cut, r.cut) : r.cut, this, last > r.last ? last : r.last);
  _Way label(peg.Clause c, int pos) => _Way(end, deleted, edits, evidence, first, (c, pos, this), cut, null, last);
  _Way demote([int c = _never]) => _Way(end, deleted, edits, evidence, _min(first, _clean), piece, _min(cut, c), prev, last);
  _Way trim(int f) => preferred && f >= 0 && end != f ? demote(clean ? f : _never) : this;
  int cmp(_Way b) => charge != b.charge ? charge - b.charge
      : preferred != b.preferred ? (preferred ? -1 : 1)
      : evidence != b.evidence ? b.evidence - evidence
      : spent + owed != b.spent + b.owed ? spent + owed - b.spent - b.owed
      : first != b.first ? b.first - first
      : last >> 1 != b.last >> 1 ? (last >> 1) - (b.last >> 1)
      : owed != b.owed ? owed - b.owed
      : _min(deleted, missing + owed) - _min(b.deleted, b.missing + b.owed);
}

class _Cell {
  int mark = -1;
  final ends = <int, _Way>{};
  bool add(_Way? r) {
    final k = r == null ? 0 : (r.end << 15) | (r.used << 1) | (r.incomplete ? 1 : 0);
    final c = r == null ? -1 : ends[k]?.cmp(r) ?? 1;
    if (c >= 0) ends[k] = r!;
    return c > 0;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules;
  final String topRuleName;
  late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _versions = <int, int>{}, _shapes = <peg.Clause, bool>{}, _letters = <peg.Str, List<peg.Clause>>{};
  final _mins = <peg.Clause, int>{}, _str = <peg.Clause, String>{}, _heads = <peg.Clause, String>{}, _one = <(peg.Clause, String), bool>{};
  int _depth = 0, _seedDepth = _never, _budget = 0, lastCost = 0;
  int get _len => parser.input.length;

  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) {
    var rk = _preferred;
    if ((c is peg.FollowedBy || c is peg.NotFollowedBy) && _depth > 0) {
      final saved = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e?) (r, e, e.result, (_cells[e]?.mark ?? 0) < -1)];
      if (saved.any((x) => x.$4)) {
        peg.MatchResult probe(bool s) {
          for (final (r, e, _, a) in saved) { e..inRecPath = a && !s..foundLeftRec = false..result = a && s ? peg.Match(r, pos, 0) : null; }
          ++parser.memoVersion[pos];
          return c.match(parser, pos);
        }
        final m = probe(false);
        if (!m.isMismatch && saved.any((x) => x.$4 && x.$2.foundLeftRec) && probe(true).isMismatch) rk = _clean;
        for (final (_, e, s, _) in saved) { e..inRecPath = false..result = s; }
        ++parser.memoVersion[pos];
        return m.isMismatch ? null : _Way(pos + m.len, 0, 0, _ev(m), rk, m);
      }
    }
    final m = parser.match(c, pos);
    return m.isMismatch ? null : _Way(pos + m.len, 0, 0, _ev(m), rk, m);
  }

  int _ev(peg.MatchResult m) {
    for (final q = [if (_evidence[m] == null) m]; q.isNotEmpty;) {
      final n = q.last, c = n.clause, k = c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet ? const <peg.MatchResult>[] : n.subClauseMatches;
      final miss = [for (final ch in k) if (_evidence[ch] == null) ch];
      if (miss.isNotEmpty) { q.addAll(miss); continue; }
      q.removeLast();
      _evidence[n] ??= k.isEmpty ? (c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted ? n.len : 0) : k.fold(0, (a, ch) => a + _evidence[ch]!);
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

  int _min0(peg.Clause c) => _mins[c] ??= _minChars(c);
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
    peg.FollowedBy() => !req && _minChars(c.subClause, {...p, c}) < _never ? 0 : _never,
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
      return [_Way(pos, 0, pos == _len ? 1 << 13 : 1, 0, pos,
          peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]))];
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
      cell.mark = ~(~cell.mark | 1); _seedDepth = _min(_seedDepth, ~cell.mark >> 16);
    } else if (cell.mark < mark) {
      final d = ++_depth, outer = _seedDepth;
      var minSeed = _never;
      cell.mark = ~(d << 16);
      do {
        _seedDepth = _never;
        var improved = false;
        for (final r in _propose(c, pos)) { if ((r.clean ? r.cut >= (plain?.end ?? _never) || plain?.end != r.end : plain?.end != r.end || r.end == pos) && cell.add(r)) improved = true; }
        minSeed = _min(minSeed, _seedDepth);
        if (!improved || (~cell.mark).isEven || _seedDepth > d) break;
        _versions[pos] = (_versions[pos] ?? 0) + 1;
      } while (true);
      _depth--;
      cell.mark = (mark & ~0xFFFFF) + (minSeed < d ? _versions[pos] ?? 0 : 0xFFFFF);
      _seedDepth = _min(outer, minSeed < d ? minSeed : _never);
    }
    final raw = [for (final r in cell.ends.values) if (r.used <= _budget && (cell.mark >= 0 || c is! peg.First ||
        switch (r.piece) { (final peg.Clause s, _, _) || peg.MatchResult(clause: final s?) => c.subClauses.indexOf(s) >= (~cell.mark >> 1) & 0x7FFF, _ => true })) r];
    final farthest = _farthest(raw);
    return [for (final r in raw)
      r.preferred && r.end == farthest && plain?.end == r.end ? plain! : (cell.mark < 0 ? r : r.trim(farthest)).label(c, pos)];
  }

  bool _active(peg.Clause c, int at) => c is peg.Ref && (_cells[parser.getMemoEntry(parser.rules[c.ruleName]!, at)]?.mark ?? 0) < -1;

  bool _total(peg.Clause c, int at, [Set<peg.Clause> p = const {}]) => !p.contains(c) && !_active(c, at) && switch (c) {
    peg.Optional() || peg.ZeroOrMore() => true,
    peg.Seq() => c.subClauses.every((s) => _total(s, at, {...p, c})),
    peg.First() => c.subClauses.any((s) => _total(s, at, {...p, c})),
    peg.Ref() => _total(parser.rules[c.ruleName]!, at, {...p, c}),
    _ => false,
  };

  String _key(peg.Clause c) => _str[c] ??= '${c is peg.Str && c.text.length == 1 ? peg.Char(c.text) : c}';
  String _head(peg.Clause c) => _heads[c] ??= c is peg.Repetition && c.requireOne ? _head(c.subClause)
      : c is peg.Seq && c.subClauses.isNotEmpty ? _head(c.subClauses[0]) : c is peg.Str && c.text.isNotEmpty ? '${peg.Char(c.text[0])}' : _key(c);

  void _covers(peg.Clause c, Set<String> s) {
    s.add(_key(c));
    if (c is peg.First) { for (final x in c.subClauses) { _covers(x, s); } }
    if (c is peg.Repetition && c.requireOne && _min0(c.subClause) > 0) _covers(c.subClause, s);
  }

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) _Way.empty(pos).trim(rs.fold(f, (m, r) => r.clean && r.end > pos && r.end < m ? r.end : m)), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[], seen = <String>{}, priors = <peg.Clause>[];
    var cut = _never, seeded = _seedDepth, nul = false;
    for (var i = 0; i < (c as peg.First).subClauses.length; i++) {
      final sub = c.subClauses[i];
      if (seen.contains(_key(sub)) || seen.contains(_head(sub))) continue;
      cell.mark = ~((~cell.mark & ~0xFFFE) | (i << 1));
      final act = _active(sub is peg.Repetition && sub.requireOne ? sub.subClause : sub, pos);
      if (out.isNotEmpty && act) continue;
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      if (act) seeded = _min(seeded, _seedDepth);
      for (final r in rs) {
        if (nul && r.first > pos || cut < _never && (r.clean || r.first >= cut || r.absorbed(pos) >= r.evidence)) continue;
        if (!r.clean && priors.isNotEmpty && _steals(priors, r, pos)) continue;
        if (_seedDepth < _never && r.end > pos) seeded = _min(seeded, _seedDepth);
        out.add(cut < _never || nul ? r.demote() : r);
      }
      if (f > pos) cut = _min(cut, f);
      if (!act && (_total(sub, pos) || rs.any((r) => r.preferred && r.end == pos) && !(nul = true))) break;
      if (!act) { _covers(sub, seen); priors.add(sub); }
    }
    if (out.isNotEmpty) _seedDepth = seeded;
    if (cut == _never && _budget > 0 && pos < _len && {for (final s in c.subClauses) if (_oneLit(s)) _key(s)}.length == 1) out.add(_Way.skip(pos, pos + 1, 1));
    return out;
  }

  static int _farthest(Iterable<_Way> rs) => rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Ref() => (_plain(c, at)?.end ?? at) > at || _startsClean(parser.rules[c.ruleName]!, at, s),
    peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
    peg.Seq() => c.subClauses.isNotEmpty && (_plain(c.subClauses[0], at)?.end ?? at) > at,
    _ => false,
  };

  List<peg.Clause> _tails(Object? p, int end, [List<peg.Clause>? out]) {
    out ??= [];
    void add(peg.Clause c) {
      if (!_active(c, end)) out!.add(c);
      if (c is peg.First) c.subClauses.forEach(add);
      if (c is peg.Optional) add(c.subClause);
    }
    if (p is (peg.Clause?, int, _Way)) {
      final (c, pos, r) = p;
      if (c is peg.Repetition || c is peg.Optional && pos == end && r.clean) add((c as peg.HasOneSubClause).subClause);
      if (c is peg.First && pos == end && r.clean) {
        for (final x in c.subClauses) { if (x == switch (r.piece) { (final peg.Clause s, _, _) || peg.MatchResult(clause: final s?) => s, _ => null }) break; add(x); }
      }
      for (_Way? x = r; x != null && x.end == end; x = x.prev) {
        _tails(x.piece, end, out);
        if (!x.clean || (x.prev?.end ?? pos) < end) break;
      }
    } else if (p is peg.MatchResult && !p.isMismatch && p.clause is! peg.Terminal) {
      final c = p.clause;
      if (c is peg.Repetition || c is peg.Optional && p.len == 0) add((c as peg.HasOneSubClause).subClause);
      if (c is peg.First && p.len == 0) { for (final x in c.subClauses) { if (x == p.subClauseMatches.firstOrNull?.clause) break; add(x); } }
      for (final k in p.subClauseMatches.reversed) {
        if (k.pos + k.len == end) _tails(k, end, out);
        if (k.len > 0 || k.clause is peg.Terminal) break;
      }
    }
    return out;
  }

  bool _matchesOne(peg.Clause c, String ch) => _one[(c, ch)] ??= switch (peg.Parser(rules: rules, topRuleName: topRuleName, input: ch).match(c, 0)) { final m => !m.isMismatch && m.len > 0 };
  bool _eq(peg.Clause a, peg.Clause b) => identical(a, b) || a.runtimeType == b.runtimeType && _key(a) == _key(b);

  bool _steals(Iterable<peg.Clause> us, _Way o, int at) {
    if (us.isEmpty) return false;
    final ne = o.end - at > o.deleted - o.missing - o.owed;
    var p = o.piece;
    for (Object? n; p is (peg.Clause?, int, _Way); p = n, n = null) {
      final c = p.$1;
      if (ne && c != null && us.any((u) => _eq(u, c))) return true;
      for (_Way? x = p.$3; x != null; x = x.prev) {
        if (x.piece != null && !(x.clean && x.end == at)) {
          n = x.piece is peg.SyntaxError && x.subs > (x.prev?.subs ?? 0)
              ? switch (c) { peg.Repetition(:final subClause) => subClause, peg.First(:final subClauses) => subClauses.firstWhere(_oneLit), _ => c }
              : x.piece;
        }
      }
    }
    if (ne && p is peg.MatchResult && p is! peg.SyntaxError) {
      for (peg.MatchResult? m = p; m != null && m.len > 0; m = m.subClauseMatches.where((k) => k.pos == at && k.len > 0).firstOrNull) {
        if (m.clause case final c? when us.any((u) => _eq(u, c))) return true;
      }
    }
    return o.first == at && switch (p is peg.MatchResult && p is! peg.SyntaxError ? p.clause : p) {
      peg.Char(:final char) || peg.Str(text: final char) => us.any((u) => _matchesOne(u, char[0])),
      peg.SyntaxError(:final len) when len > 0 => us.any((u) => (_plain(u, at + len)?.end ?? 0) > at + len),
      _ => false,
    };
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
        final whole = _budget, prevSeed = _seedDepth; _budget = canSettle ? whole : whole - r.used; _seedDepth = _never;
        final options = _read(slot, r.end); _budget = whole;
        final lrNullRep = i < slots.length - 1 && r.end == pos && _seedDepth < _never &&
            (slot is peg.Repetition || slot is peg.Optional && slot.subClause is peg.Repetition) && options.any((o) => o.clean && o.end == pos);
        _seedDepth = _min(prevSeed, _seedDepth);
        List<peg.Clause>? tails;
        List<peg.Clause> getTails() => tails ??= _tails(i == 0 ? null : (null, pos, r), r.end);
        var deletedAhead = -1;
        if (!lrNullRep && !_active(slot, r.end) && !options.any((o) => o.clean && o.end > r.end)) {
          final syncSkip = r.used > 0 && i == slots.length - 1 && slots.length > 2 && r.synced(pos);
          final room = _budget - (syncSkip ? 0 : r.cost);
          for (var j = r.end + 1; j <= r.end + room && j <= _len; j++) {
            final clean = _plain(slot, j);
            if (clean == null || clean.end == j && (syncSkip || options.any((o) => o.clean))) continue;
            if (!getTails().any((u) => (_plain(u, j)?.end ?? j) > j)) next.add(r.then(_Way.skip(r.end, j), syncSkip ? r.used << 50 : 0)?.then(clean));
            deletedAhead = j - r.end; break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(slot) && 
              !getTails().any((u) => _matchesOne(u, slot is peg.Char ? slot.char : (slot as peg.Str).text))) {
            next.add(r.then(_Way.skip(r.end, r.end + 1, 1)));
          }
        }
        final penalize = deletedAhead > 0 && i != slots.length - 1 && !_oneShape(slot);
        bool settles(_Way o) => canSettle && o.first > r.end &&
            (rSub ? o.pureSub(r.end) && o.evidence > 0 : o.synced(r.end, 0) && (o.credit == 0 || o.first > (r.last >> 1) + 1));
        final mustAdvance = r.evidence == 0 && slot is peg.Repetition && (r.incomplete && !_oneShape(slot.subClause) || rSub && options.any(settles)) &&
            (r.end < _len || slots.skip(i + 1).any((s) => _min0(s) > 0));
        for (final o in options) {
          if (mustAdvance && o.end == r.end || lrNullRep && o.end > pos || i > 0 && !o.clean && _steals(getTails(), o, r.end)) continue;
          final w = r.then(o, (settles(o) ? r.used << 50 : 0) + (penalize && o.end == r.end && !o.clean && deletedAhead <= o.missing ? 1 << 38 : 0));
          if (w != null && w.used + (i == 1 && r.owed > 1 && o.owed > 0 ? r.owed : 0) <= whole) next.add(w);
        }
      }
      cur = next.ends.values.toList();
      if (cur.isEmpty) break;
    }
    return cur;
  }

  List<_Way> _repeat(peg.Repetition c, int pos) {
    final zero = _Way.empty(pos), best = _Cell(), q = <int, _Cell>{pos: _Cell()..add(zero)};
    void push(_Way? w) { if (best.add(w)) (q[w!.end] ??= _Cell()).add(w); }
    while (q.isNotEmpty) {
      for (var r in q.remove(q.keys.reduce(_min))!.ends.values) {
        final startEnd = r.end;
        for (var m1 = _active(c.subClause, r.end) ? null : _plain(c.subClause, r.end);
            m1 != null && m1.end > r.end && m1.evidence > 0 && !_active((m1.piece as peg.MatchResult).subClauseMatches.firstOrNull?.clause ?? c.subClause, r.end);) {
          final m2 = _plain(c.subClause, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null;
          if (next == null) break;
          if (r.end > pos && c.subClause is peg.Terminal) best.add(r);
          r = next; m1 = m2!;
        }
        if (r.end > startEnd) { push(r); continue; }
        if (r.used > _budget) continue;
        var d = r;
        while (d.prev != null && d.spent == d.prev!.spent) { d = d.prev!; }
        final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0);
        final rSub = c.subClause is peg.Ref && r.pureSub(pos) && dEv > 0;
        final canSettle = r.used > 0 && (rSub || (cleanTail || r.end > (r.last >> 1) + 1) && dEv > 1 && r.evidence > r.absorbed(pos) + 1);
        final whole = _budget; _budget = canSettle ? whole : whole - r.used;
        final steps = _read(c.subClause, r.end); _budget = whole;
        List<peg.Clause>? tails;
        List<peg.Clause> getTails() => tails ??= _tails(r.end == pos ? null : (null, pos, r), r.end);
        if (c.subClause is! peg.CharSet && !_active(c.subClause, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
          for (var j = r.end + 1; j <= r.end + _budget - r.cost && j <= _len; j++) {
            final clean = _plain(c.subClause, j);
            if (clean == null || clean.end == j || clean.evidence == 0) continue;
            if (!getTails().any((u) => (_plain(u, j)?.end ?? j) > j)) push(r.then(_Way.skip(r.end, j))?.then(clean));
            break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(c.subClause)) push(r.then(_Way.skip(r.end, r.end + 1, 1)));
        }
        bool syncs(_Way s) => (_plain(c.subClause, s.end)?.end ?? 0) > s.end;
        final anySync = canSettle && steps.any((s) => s.end > r.end && syncs(s));
        for (var step in steps) {
          if (step.end <= r.end || step.end - r.end == step.deleted && step.subs == 0 && step.missing == 0 || step.clean && step.cut < _never ||
              r.end > pos && (c.subClause is peg.Terminal && step.owed >= step.evidence || !step.clean && _steals(getTails(), step, r.end))) { continue; }
          final settle = canSettle && !step.clean && (!step.incomplete || step.first == step.end) &&
              (!anySync && rSub && step.pureSub(r.end) && step.evidence > 0 ||
               step.evidence > 1 && (syncs(step) ? cleanTail || step.first > r.end : cleanTail && !anySync && step.evidence > step.absorbed(r.end)));
          if (r.then(step, settle ? r.used << 50 : 0) case final w? when w.used <= whole) push(w);
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
    if (root is peg.MatchResult) return root;
    final built = Map<Object, peg.MatchResult>.identity();
    for (final todo = [(root, rootEnd)]; todo.isNotEmpty;) {
      final (piece, end) = todo.last; final (label, pos, inner) = piece as (peg.Clause?, int, _Way);
      final miss = [for (_Way? r = inner; r != null; r = r.prev) if (r.piece case final p? when p is! peg.MatchResult && built[p] == null) (p, r.end)];
      if (miss.isNotEmpty) { todo.addAll(miss); continue; }
      todo.removeLast();
      final kids = [for (_Way? r = inner; r != null; r = r.prev) if (r.piece case final p?) p is peg.MatchResult ? p : built[p]!];
      final c = end == pos && pos == _len ? null : label;
      built[piece] ??= kids.isEmpty ? peg.Match(c, pos, end - pos) : peg.Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
    }
    return built[root]!;
  }

  peg.MatchResult recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    _cells.clear(); _evidence.clear(); _versions.clear();
    final top = parser.rules[topRuleName]!;
    void sweep(void Function(peg.Clause, int) fn) {
      for (var p = _len; p >= 0; p--) {
        for (final r in parser.rules.values) { if (r is! peg.Ref) fn(r, p); }
      }
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
    final shortest = _min0(top), ceiling = shortest == _never ? -1 : _len + shortest;
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
        if (w == null || w.charge - w.credit > _budget || w.clean) continue;
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
