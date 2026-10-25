import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

class _Way {
  const _Way(this.end, this.edits, this.used, this.evidence, [this.piece, this.cut = _never, this.prev]);
  const _Way.clean(int end, [int ev = 0, Object? piece]) : this(end, 0, 0, ev, piece);
  _Way.skip(int a, int b, [bool sub = false]) : this(b, b - a, b - a, 0, sub ? peg.Match(null, a, 1) : peg.SyntaxError(pos: a, len: b - a));
  final int end, edits, used, evidence, cut;
  final Object? piece; final _Way? prev;
  static bool _isSub(Object? p) => p is peg.Match && p.clause == null && p is! peg.SyntaxError;
  (Object?, int, _Way)? get _p => piece is (Object?, int, _Way) ? piece as (Object?, int, _Way) : null;
  _Way? get _in => _p?.$3;
  peg.MatchResult get _m => piece as peg.MatchResult;
  bool get clean => edits == 0;
  bool get _dirty => edits > (prev?.edits ?? 0);
  bool get preferred => clean && cut == _never;
  int _sum(int Function(_Way) f, [bool endOnly = false]) {
    var s = 0;
    for (_Way? x = this; x != null && !x.clean && (!endOnly || x.end == end);) {
      if (!x._dirty) { x = x.prev; continue; }
      if (x._in == null) { s += f(x); x = x.prev; continue; }
      final p = x.prev != null && !x.prev!.clean && (!endOnly || x.prev!.end == end) ? x.prev : null;
      final q = !endOnly && x._p!.$2 + x._in!.evidence == x.end ? null : x._in;
      if (p != null && q != null) { s += (p.edits <= q.edits ? p : q)._sum(f, endOnly); x = p.edits <= q.edits ? q : p; }
      else { x = p ?? q; }
    }
    return s;
  }
  _Way get _core {
    var x = this;
    while (!x.clean) {
      if (!x._dirty) { x = x.prev!; }
      else if ((x.prev?.clean ?? true) && x._in != null) { x = x._in!; }
      else { break; }
    }
    return x;
  }
  bool get incomplete => _sum((x) => x._m.len == 0 ? 1 : 0, true) > 0;
  int get owed => used == edits ? 0 : _sum((x) => x._m.len == 0 && x.used == (x.prev?.used ?? 0) ? 1 : 0, true);
  int get spent => edits - owed;
  int get deleted => _sum((x) => x._m.len);
  int get subs => _sum((x) => _isSub(x.piece) ? 1 : 0);
  int get cost => edits - used < 2 ? edits : _min(edits, spent + 1);
  int get first {
    if (clean) return _never;
    for (var x = this;; x = !(x.prev?.clean ?? true) ? x.prev! : x._in!) {
      if ((x.prev?.clean ?? true) && x._in == null) return x._m.pos;
    }
  }
  bool _firstAtMost(int lim) {
    if (clean) return false;
    for (var x = this;; x = !(x.prev?.clean ?? true) ? x.prev! : x._in!) {
      if (!(x.prev?.clean ?? true)) { if (x.prev!.end <= lim) return true; }
      else if (x._p != null) { if (x._p!.$2 > lim) return false; }
      else { return x._m.pos <= lim; }
    }
  }
  bool _lastBefore(int lim) {
    for (var x = this; !x.clean; x = x._dirty ? x._in! : x.prev!) {
      if (x.end <= lim) return true;
      if (x._dirty && x._in == null) return false;
    }
    return true;
  }
  int get _maxDel => switch (_core) {
    final c when c._p != null => (c.prev?.edits ?? 0) + _min(c._in!.edits, c.end - c._p!.$2 - c._in!.evidence),
    final c => c.edits,
  };
  int _tailCmp(_Way b) {
    var x = _core, y = b._core, da = 0, db = 0;
    while (!identical(x, y) && (x._in != null || y._in != null)) {
      if (x._in != null && (y._in == null || x.edits >= y.edits)) { da += x.prev!.deleted; x = x._in!._core; }
      else { db += y.prev!.deleted; y = y._in!._core; }
    }
    var d = identical(x, y) ? 0 : x.end - y.end; d = d != 0 ? d : owed - b.owed;
    if (d != 0 || identical(x, y) && da == db) return d;
    if (identical(x, y) && 2 * ((da > db ? da : db) + x._maxDel) <= edits) return da - db;
    final ad = da + x.deleted, bd = db + (identical(x, y) ? ad - da : y.deleted);
    return _min(ad, edits - ad) - _min(bd, b.edits - bd);
  }
  int absorbed(int a) => end - a - deleted - evidence;
  bool _evGt(int a, [int k = 0]) => 2 * evidence > end - a + k || 2 * evidence + _maxDel > end - a + k && evidence > absorbed(a) + k;
  int get charge => cost + (!clean && !_evGt(0, -1) ? 1 : 0);
  bool pureSub(int a) => !clean && end - a - edits == evidence && subs == edits;
  bool synced(int a, [int g = 1]) => !clean && evidence > 1 && _evGt(a, 1) && _lastBefore(end - g - 1);
  _Way? then(_Way r, [bool s = false]) {
    final on = cut < _never && !r._firstAtMost(cut - 1);
    return on && r.end >= cut ? null
        : _Way(r.end, edits + r.edits, (s ? 0 : used) + r.used, evidence + r.evidence, r.piece, on ? _min(cut, r.cut) : r.cut, this);
  }
  _Way label(peg.Clause c, int pos) => _Way(end, edits, used, evidence, (c, pos, this), cut);
  _Way demote([int c = _never - 1]) => _Way(end, edits, used, evidence, piece, _min(cut, c), prev);
  _Way trim(int f) => preferred && f >= 0 && end != f ? demote(f) : this;
  int cmp(_Way b) {
    var d = charge - b.charge; d = d != 0 ? d : (b.preferred ? 1 : 0) - (preferred ? 1 : 0);
    d = d != 0 ? d : b.evidence - evidence; d = d != 0 ? d : edits - b.edits;
    if (d != 0 || clean || identical(_core, b._core)) return d;
    d = b.first - first; return d != 0 ? d : _tailCmp(b);
  }
}

class _Cell {
  int mark = -1, ver = -1, dep = 0, arm = 0;
  final ends = <_Way>[];
  bool add(_Way? r) {
    if (r == null) return false;
    for (var i = 0; i < ends.length; i++) {
      if (ends[i] case final e when e.end == r.end && e.used == r.used && e.incomplete == r.incomplete) {
        final c = e.cmp(r); if (c > (ver < _never || r.used > mark ? -1 : 0)) ends[i] = r; return c > 0;
      }
    }
    ends.add(r); return true;
  }
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser;
  final _cells = Map<Object, _Cell>.identity(), _evidence = Map<peg.MatchResult, int>.identity();
  final _shapes = <peg.Clause, bool>{}, _tot = <peg.Clause, bool>{}, _mins = <peg.Clause, int>{}, _chars = <peg.Str, List<peg.Clause>>{};
  final _str = <peg.Clause, String>{}, _one = <(peg.Clause, String), bool>{}, _ver = <int, int>{};
  int _depth = 0, _seedDepth = _never, _budget = 0, lastCost = 0;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) {
    var pref = true;
    if ((c is peg.FollowedBy || c is peg.NotFollowedBy) && _depth > 0) {
      final saved = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e?) (r, e, e.result, (_cells[e]?.dep ?? 0) != 0)];
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
      final s = pos < _len ? 1 : 0, m = peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]);
      return [_Way(pos, 1, s, 0, m, _never - 1)];
    }
    if (c is peg.Ref) {
      return [for (final r in _read(parser.rules[c.ruleName]!, pos))
        if (_depth == 0 || r.clean || r.evidence > 0 || r.end == pos || _oneShape(c) || r.subs == r.cost) r.label(c, pos)];
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
    final b = pos == _len && _budget == 0 ? 1 : _budget;
    if (cell.dep != 0) {
      _seedDepth = _min(_seedDepth, cell.dep = cell.dep.abs());
    } else if (cell.mark < b || cell.mark == b && cell.ver < (_ver[pos] ?? 0)) {
      final d = ++_depth, outer = _seedDepth, pe = plain?.end ?? _never; var ms = _never; cell.dep = -d;
      do {
        _seedDepth = _never; var ok = false;
        for (final r in _propose(c, pos)) {
          if ((r.clean ? r.cut >= pe || pe != r.end : pe != r.end || r.end == pos) && cell.add(r)) ok = true;
        }
        ms = _min(ms, _seedDepth); if (!ok || cell.dep < 0 || _seedDepth > d) break;
        _ver[pos] = (_ver[pos] ?? 0) + 1;
      } while (true);
      _depth--; cell.dep = 0; _seedDepth = _min(outer, ms < d ? ms : _never);
      cell..mark = b..ver = ms < d ? _ver[pos] ?? 0 : _never;
    }
    bool ok(_Way r) => r.used <= _budget && (cell.dep == 0 || c is! peg.First || !c.subClauses.take(cell.arm).contains(_clauseOf(r.piece)));
    final raw = cell.ends.where(ok), f = _farthest(raw);
    return [for (final r in raw)
      r.preferred && r.end == f && plain?.end == r.end ? plain! : (cell.dep != 0 ? r : r.trim(f)).label(c, pos)];
  }

  static peg.Clause? _clauseOf(Object? p) => p is (peg.Clause?, int, _Way) ? p.$1 : p is peg.MatchResult ? p.clause : null;
  static peg.Clause? _arm(Object? p) => p is peg.MatchResult ? p.subClauseMatches.firstOrNull?.clause : null;
  bool _active(peg.Clause? c, int at, [bool? empty]) {
    if (c is peg.Repetition && c.requireOne) return _active(c.subClause, at, empty);
    final x = c is peg.Ref ? _cells[parser.getMemoEntry(parser.rules[c.ruleName]!, at)] : null;
    return x != null && x.dep != 0 && (empty == null || x.ends.isEmpty == empty);
  }
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
  String _head(peg.Clause c) => c is peg.Repetition && c.requireOne ? _head(c.subClause)
      : c is peg.Seq && c.subClauses.isNotEmpty ? _head(c.subClauses[0]) : c is peg.Str && c.text.isNotEmpty ? _key(peg.Char(c.text[0])) : _key(c);

  void _covers(peg.Clause c, Set<String> s, List<peg.Clause> p, int at) {
    s.add(_key(c));
    if (_active(c, at)) return;
    if (c is peg.First) { for (final x in c.subClauses) { _covers(x, s, p, at); } } else { p.add(c); }
    if (c is peg.Repetition && c.requireOne && _min0(c.subClause) > 0) _covers(c.subClause, s, p, at);
  }

  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(c.subClauses, pos);
    if (c is peg.Repetition) return _repeat(c, pos);
    if (c is peg.Optional) {
      final rs = _read(c.subClause, pos), f = _farthest(rs);
      return [if (f != pos) _Way.clean(pos).trim(rs.fold(f, (m, r) => r.clean && r.end > pos && r.end < m ? r.end : m)), ...rs];
    }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[], seen = <String>{}, priors = <peg.Clause>[];
    var cut = _never, sd = _seedDepth, nul = false;
    for (var i = 0; i < (c as peg.First).subClauses.length; i++) {
      final sub = c.subClauses[i];
      if (seen.contains(_key(sub)) || seen.contains(_head(sub))) continue;
      cell.arm = i;
      final act = _active(sub, pos);
      if (out.isNotEmpty && act) continue;
      final rs = _read(sub, pos), f = act ? -1 : _farthest(rs);
      if (act) sd = _min(sd, _seedDepth);
      for (final r in rs) {
        if (nul && !r._firstAtMost(pos) || cut < _never && (!r._firstAtMost(cut - 1) || !r._evGt(pos))) continue;
        if (!r.clean && priors.isNotEmpty && _steals(priors, r, pos)) continue;
        if (_seedDepth < _never && r.end > pos) sd = _min(sd, _seedDepth);
        out.add(cut < _never || nul ? r.demote() : r);
      }
      if (f > pos) cut = _min(cut, f);
      if (!act && (_total(sub, pos) || rs.any((r) => r.preferred && r.end == pos) && !(nul = true))) break;
      if (!act && i + 1 < c.subClauses.length) _covers(sub, seen, priors, pos);
    }
    if (out.isNotEmpty) _seedDepth = sd;
    if (cut == _never && _budget > 0 && pos < _len && c.subClauses.where(_oneLit).map(_key).toSet().length == 1) out.add(_Way.skip(pos, pos + 1, true));
    return out;
  }

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) {
    peg.Ref() => (_plain(c, at)?.end ?? at) > at || _startsClean(parser.rules[c.ruleName]!, at, s),
    peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)),
    peg.Seq() => c.subClauses.isNotEmpty && (_plain(c.subClauses[0], at)?.end ?? at) > at,
    _ => false,
  };

  List<peg.Clause> _tails(Object? p, int end, [List<peg.Clause>? out]) {
    out ??= [];
    void add(peg.Clause c) {
      if (!_active(c, end, true)) out!.add(c);
      if (c is peg.First) c.subClauses.forEach(add);
      if (c is peg.Optional || c is peg.Repetition && c.requireOne) add((c as peg.HasOneSubClause).subClause);
    }
    void prior(peg.Clause? c, bool zero, peg.Clause? taken) {
      if (c is peg.Repetition || zero && c is peg.Optional) add((c as peg.HasOneSubClause).subClause);
      if (zero && c is peg.First) c.subClauses.takeWhile((x) => x != taken).forEach(add);
    }
    if (p is (peg.Clause?, int, _Way)) {
      prior(p.$1, p.$2 == end && p.$3.clean, _clauseOf(p.$3.piece));
      for (_Way? x = p.$3; x != null && x.end == end; x = x.prev) {
        _tails(x.piece, end, out);
        if (!x.clean || (x.prev?.end ?? p.$2) < end) break;
      }
    } else if (p is peg.MatchResult && !p.isMismatch && p.clause is! peg.Terminal && !_active(p.clause, p.pos)) {
      prior(p.clause, p.len == 0, _arm(p));
      for (final k in p.subClauseMatches.reversed) {
        if (k.pos + k.len == end) _tails(k, end, out);
        if (k.len > 0 || k.clause is peg.Terminal) break;
      }
    }
    return out;
  }

  bool _matchesOne(peg.Clause c, String ch) => _one[(c, ch)] ??= _m1(c, ch, {});
  bool _m1(peg.Clause c, String ch, Set<peg.Clause> s) => _min0(c) < _never && s.add(c) && switch (c) {
    peg.Char() => c.char == ch,
    peg.Str() => c.text == ch,
    peg.CharSet() => c.inverted != c.ranges.any((r) => ch.codeUnitAt(0) >= r.$1 && ch.codeUnitAt(0) <= r.$2),
    peg.AnyChar() => true,
    peg.Ref() => _m1(parser.rules[c.ruleName]!, ch, s),
    peg.First(:final subClauses) => switch (subClauses.where((x) => _m1(x, ch, {...s}) || _total(x, 0)).firstOrNull) { final x? => _m1(x, ch, s), _ => false },
    peg.Repetition(:final subClause) || peg.Optional(:final subClause) => _m1(subClause, ch, s),
    peg.Seq(:final subClauses) => switch ([for (final x in subClauses) if (_min0(x) > 0) x]) {
      [] => subClauses.any((x) => _m1(x, ch, {...s})),
      [final x] => _m1(x, ch, s),
      _ => false,
    },
    _ => false,
  };

  bool _eq(peg.Clause a, peg.Clause b) => identical(a, b) || a.runtimeType == b.runtimeType && _key(a) == _key(b);

  bool _steals(Iterable<peg.Clause> us, _Way o, int at) {
    if (us.isEmpty) return false;
    final ne = o.end - at > o.edits || o.end - at + o.edits - 2 * o.deleted + o.subs > 0;
    if (!ne && !o._firstAtMost(at)) return false;
    var p = o.piece;
    for (Object? n; p is (peg.Clause?, int, _Way); p = n, n = null) {
      final c = p.$1;
      if (ne && c != null && us.any((u) => _eq(u, c))) return true;
      _Way? hit; var j = 0;
      for (_Way? x = p.$3; x != null; x = x.prev) {
        if (x.piece != null) x.clean && x.end == at ? j++ : (hit = x, j = 0);
      }
      n = _Way._isSub(hit?.piece)
          ? switch (c) { peg.Repetition(:final subClause) => subClause, peg.First(:final subClauses) => subClauses.firstWhere(_oneLit), peg.Seq(:final subClauses) => subClauses[j], _ => c }
          : hit?.piece;
    }
    if (ne && p is peg.MatchResult) {
      for (peg.MatchResult? m = p; m != null && m.len > 0; m = m.subClauseMatches.where((k) => k.pos == at && k.len > 0).firstOrNull) {
        if (m.clause case final c? when us.any((u) => _eq(u, c))) return true;
      }
    }
    return o._firstAtMost(at) && switch (p is peg.MatchResult ? p.clause ?? p : p) {
      peg.Char(:final char) || peg.Str(text: final char) => us.any((u) => _matchesOne(u, char[0])),
      peg.Match(:final len) when len > 0 => us.any((u) => (_plain(u, at + len)?.end ?? 0) > at + len),
      _ => false,
    };
  }

  List<_Way> _seq(List<peg.Clause> slots, int pos) {
    var cur = [_Way.clean(pos)];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1;
      for (final r in cur) {
        if (r.used > _budget) continue;
        final rSub = s is peg.Repetition && r.pureSub(pos);
        final canS = r.used > 0 && (s is peg.Repetition && r.synced(pos) || rSub || r.end == pos && _startsClean(s, r.end));
        final b0 = _budget, prevSeed = _seedDepth; _budget = canS ? b0 : b0 - r.used; _seedDepth = _never;
        final options = _read(s, r.end); _budget = b0;
        final lrNullRep = !last && r.end == pos && _seedDepth < _never &&
            (s is peg.Repetition || s is peg.Optional && s.subClause is peg.Repetition) && options.any((o) => o.clean && o.end == pos);
        _seedDepth = _min(prevSeed, _seedDepth);
        List<peg.Clause>? tails;
        List<peg.Clause> getTails() => tails ??= _tails(i == 0 ? null : (null, pos, r), r.end);
        var del = -1;
        if (!lrNullRep && !_active(s, r.end) && !options.any((o) => o.clean && o.end > r.end)) {
          final sync = r.used > 0 && last && slots.length > 2 && r.synced(pos);
          final limit = _min(_len, r.end + _budget - (sync ? 0 : r.cost));
          for (var j = r.end + 1; j <= limit; j++) {
            final clean = _plain(s, j);
            if (clean == null || clean.end == j && (sync || options.any((o) => o.clean))) continue;
            if (!getTails().any((u) => (_plain(u, j)?.end ?? j) > j)) next.add(r.then(_Way.skip(r.end, j), sync)?.then(clean));
            del = j - r.end; break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(s) &&
              !getTails().any((u) => _matchesOne(u, s is peg.Char ? s.char : (s as peg.Str).text))) {
            next.add(r.then(_Way.skip(r.end, r.end + 1, true)));
          }
        }
        final pen = del > 0 && !last && !_active(s, r.end) && !(s is peg.First && s.subClauses.any((x) => _active(x, r.end))) && !_oneShape(s);
        bool settle(_Way o) => canS && (rSub ? o.evidence > 0 && o.pureSub(r.end) : o.synced(r.end, 0) && (o.used == o.spent || r._lastBefore(o.first - 2))) && !o._firstAtMost(r.end);
        final adv = r.evidence == 0 && s is peg.Repetition && (r.incomplete && !_oneShape(s.subClause) || rSub && options.any(settle)) &&
            (r.end < _len || slots.skip(i + 1).any((x) => _min0(x) > 0));
        for (final o in options) {
          if (o.end == r.end && (adv || pen && !o.clean && del <= o.spent) || lrNullRep && o.end > pos || i > 0 && !o.clean && _steals(getTails(), o, r.end)) continue;
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
        var d = r; while (d.prev != null && d.edits == d.prev!.edits) { d = d.prev!; }
        final cleanTail = d != r, dEv = d.evidence - (d.prev?.evidence ?? 0), rSub = r.used > 0 && dEv > 0 && sub is peg.Ref && r.pureSub(p);
        final canS = r.used > 0 && (rSub || dEv > 1 && (cleanTail || r._lastBefore(r.end - 2)) && r._evGt(p, 1));
        final b0 = _budget; _budget = canS ? b0 : b0 - r.used; final steps = _read(sub, r.end); _budget = b0;
        List<peg.Clause>? tails;
        List<peg.Clause> getTails() => tails ??= _tails(r.end == p ? null : (null, p, r), r.end);
        if (sub is! peg.CharSet && !_active(sub, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
          for (var j = r.end + 1; j <= _min(_len, r.end + _budget - r.cost); j++) {
            final clean = _plain(sub, j);
            if (clean == null || clean.end == j || clean.evidence == 0) continue;
            if (!getTails().any((u) => (_plain(u, j)?.end ?? j) > j)) push(r.then(_Way.skip(r.end, j))?.then(clean));
            break;
          }
          if (r.used < _budget && r.end < _len && _oneLit(sub)) push(r.then(_Way.skip(r.end, r.end + 1, true)));
        }
        bool syncs(_Way s) => (_plain(sub, s.end)?.end ?? 0) > s.end;
        final anySync = canS && steps.any((s) => s.end > r.end && syncs(s));
        for (final s in steps) {
          if (s.end <= r.end || s.evidence == 0 && s.end - r.end == s.deleted && s.subs == 0 && s.spent == s.deleted || s.clean && s.cut < _never - 1 ||
              r.end > p && (sub is peg.Terminal && s.owed >= s.evidence || !s.clean && _steals(getTails(), s, r.end))) { continue; }
          final settle = canS && !s.clean && (!s.incomplete || !s._firstAtMost(s.end - 1)) && (!anySync && rSub && s.evidence > 0 && s.pureSub(r.end) ||
              s.evidence > 1 && (syncs(s) ? cleanTail || !s._firstAtMost(r.end) : cleanTail && !anySync && s._evGt(r.end)));
          if (r.then(s, settle) case final w? when w.used <= b0) push(w);
        }
      }
    }
    if (best.ends.isEmpty) {
      for (final r in _read(sub, p)) { if (r.end == p && !r.clean) best.add(zero.then(r)?.demote()); }
    }
    if (!c.requireOne) best.add(zero);
    final ways = best.ends, f = _farthest(ways);
    return [for (final r in ways) if (_plain(sub, r.end)?.end ?? r.end case final sc)
      sc > r.end && !(r.end == p && _seedDepth < _never) ? r.demote(sc) : !r.preferred || r.end == f ? r : r.demote()];
  }

  peg.MatchResult _tree(Object root) {
    peg.MatchResult leaf(peg.MatchResult m) => _Way._isSub(m) ? peg.SyntaxError(pos: m.pos, len: 1) : m;
    if (root is peg.MatchResult) return leaf(root);
    final built = Map<Object, peg.MatchResult>.identity();
    for (final todo = [root]; todo.isNotEmpty;) {
      final piece = todo.last as (peg.Clause?, int, _Way), pos = piece.$2, inner = piece.$3, kids = <peg.MatchResult>[];
      for (_Way? r = inner; r != null; r = r.prev) {
        if (r.piece case final p?) p is peg.MatchResult ? kids.add(leaf(p)) : built[p] != null ? kids.add(built[p]!) : todo.add(p);
      }
      if (todo.last == piece) {
        todo.removeLast(); final c = inner.end == pos && pos == _len ? null : piece.$1;
        built[piece] = kids.isEmpty ? peg.Match(c, pos, inner.end - pos) : peg.Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
      }
    }
    return built[root]!;
  }

  peg.MatchResult recover(String input) {
    parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
    _cells.clear(); _evidence.clear(); _ver.clear(); final top = parser.rules[topRuleName]!;
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
        _cells.clear(); _ver.clear(); sweep(parser.match); sweep(_read); ways = _read(top, 0);
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
    best ??= fallback; lastCost = best == null ? (_len == 0 ? 1 : _len) : best.edits;
    return best == null ? peg.SyntaxError(pos: 0, len: _len)
        : _tree(best.prev == null && best.piece != null ? best.piece! : (null, 0, best));
  }
}
