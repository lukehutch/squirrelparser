import 'package:squirrel_parser/squirrel_parser.dart' as peg;

const _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
class _Stop {}

class _Way {
  static int maxOwed = _never, len = _never;
  static int _ex(int o) => o > maxOwed ? o - maxOwed : 0;
  const _Way(this.end, this.edits, this.used, this.evidence, [this.piece, this.prev]);
  const _Way.clean(int end, [int ev = 0, Object? piece]) : this(end, 0, 0, ev, piece);
  _Way.skip(int a, int b) : this(b, b - a, b - a, 0, peg.SyntaxError(pos: a, len: b - a));
  final int end, edits, used, evidence; final Object? piece; final _Way? prev;
  bool get clean => edits == 0;
  bool get preferred => clean && piece is! peg.Clause;
  int get owed => !clean && end == len && prev != null && prev!.end == len ? edits - prev!.edits : 0;
  int get spent => edits - owed;
  int get cost => spent + (owed == 0 ? 0 : _ex(owed) + (maxOwed == 0 ? 0 : 1));
  int get first { if (clean || spent == 0) return clean ? _never : len; for (_Way? x = this; x != null && !x.clean;) {
      if (x.prev != null && !x.prev!.clean) { x = x.prev; } else if (x.piece case (_, final _Way w)) { x = w; }
      else { return switch (x.piece) { (_, final int p) => p, final peg.MatchResult m => m.pos, _ => _never }; } } return _never; }
  bool firstAfter(int lim) { if (clean || lim < 0 || spent == 0 && len > lim) return true; for (_Way? x = this; x != null && !x.clean;) {
      if (x.prev != null && !x.prev!.clean) { if (x.prev!.end <= lim) return false; x = x.prev; } else if (x.piece case (final int p, final _Way w)) { if (p > lim) return true; x = w; }
      else { return (x.piece is peg.MatchResult ? (x.piece as peg.MatchResult).pos : x.end - 1) > lim; } } return true; }
  int get last { if (owed > 0) return len;
    for (_Way? x = this; x != null && !x.clean;) { if (x.prev != null && x.edits == x.prev!.edits) { x = x.prev; } else if (x.piece case (_, final _Way w)) { x = w; } else { return x.end; } } return -1; }
  int absorbed(int a) => _max(0, end - a - evidence - spent);
  bool get _allSub { for (_Way? x = this; x != null && !x.clean;) { if (x.prev != null && x.edits == x.prev!.edits) { x = x.prev; } else if (x.piece case (_, final _Way w)) { if (!w._allSub) return false; x = x.prev; } else if (x.piece is (peg.Clause, int)) { x = x.prev; } else { return false; } } return true; }
  bool pureSub(int a) => edits > 0 && end - a == edits + evidence && owed == 0 && _allSub;
  bool synced(int a, [int g = 1]) => spent > 0 && evidence > absorbed(a) + 1 && end > last + g;
  _Way _addEv(int e) => e == 0 || clean ? this : _Way(end, edits, used, evidence + e, piece, prev?._addEv(e));
  _Way? then(_Way r, [bool s = false]) { if (!clean && r.clean && r.end == end && r.piece is peg.MatchResult) return this;
    final o1 = owed, o2 = r.owed, o = o1 + o2, u = (s ? 0 : used) + r.used + _ex(o) - (s ? 0 : _ex(o1)) - _ex(o2);
    if (o1 > 0) return _Way(len, edits + r.edits, u, evidence + r.evidence, (len, _Way(len, o, 0, 0, r.piece, _Way(len, o1, 0, 0, piece))), prev);
    if (clean && r.clean) return _Way(r.end, 0, 0, evidence + r.evidence, piece is peg.Clause ? piece : r.piece, this);
    if (clean && piece is peg.MatchResult && r.end > end && o2 == 0) return switch (r.piece) { (_, final _Way w) => _Way(r.end, r.edits, u, evidence + r.evidence, w.piece, w.prev?._addEv(evidence)), _ => _Way(r.end, r.edits, u, evidence + r.evidence, r.piece, r.prev?._addEv(evidence)) };
    if (!clean && r.clean && r.end > end) return _Way(r.end, edits, u, evidence + r.evidence, r.piece, prev != null && edits == prev!.edits ? prev : prev == null && piece is (int, _Way) ? switch ((piece as (int, _Way)).$2) { final w => w.prev != null && w.edits == w.prev!.edits ? w.prev : w } : this);
    final p = prev, pp = p?.prev, self = !clean && !r.clean && end < len && p != null && !p.clean && edits > p.edits && pp != null && !pp.clean ? _Way(end, edits, used, evidence, (pp.end, _Way(end, edits - pp.edits, 0, evidence - pp.evidence, piece, _Way(p.end, p.edits - pp.edits, 0, p.evidence - pp.evidence, p.piece))), pp) : this;
    if (o2 > 0) { final rp = r.prev!, wp = end < len ? _Way(len, edits + rp.edits, 0, evidence + rp.evidence, (end, rp), self) : _Way(len, edits + rp.edits, 0, evidence + rp.evidence, (len, _Way(len, edits + rp.edits, 0, 0, rp.piece, self))); return _Way(len, edits + r.edits, u, evidence + r.evidence, r.piece, wp); }
    if (r.piece case (final int p0, final _Way w) when s && !clean && w.prev != null && !w.prev!.clean && w.edits > w.prev!.edits) return _Way(r.end, edits + r.edits, u, evidence + r.evidence, w.piece, _Way(w.prev!.end, edits + w.prev!.edits, 0, evidence + w.prev!.evidence, (p0, w.prev!), self));
    return _Way(r.end, edits + r.edits, u, evidence + r.evidence, r.piece, clean && r.end > end ? null : self); }
  _Way label(int pos) { if (owed > 0) return _Way(len, edits, used, evidence, (len, _Way(len, owed, 0, 0, piece)), _Way(len, prev!.edits, prev!.used, prev!.evidence, (pos, prev!)));
    if (clean) return this;
    final x = piece == null && prev != null ? prev! : this; return x.prev == null ? x : _Way(end, edits, used, evidence, x.prev!.clean ? x.piece : (pos, x)); }
  _Way tail(int pos, int pev) => _Way(end, edits, used, evidence - pev, piece, owed > 0 ? _Way(len, prev!.edits, prev!.used, prev!.evidence - pev, prev!.piece, prev!.prev) : prev).label(pos);
  int cmp(_Way b) {
    final ie = spent > 0 && owed > 1 ? evidence - 1 : evidence, bie = b.spent > 0 && b.owed > 1 ? b.evidence - 1 : b.evidence;
    var d = cost - b.cost; d = d != 0 ? d : bie - ie; d = d != 0 ? d : edits - b.edits; d = d != 0 ? d : b.first - first; return d != 0 ? d : last - b.last; } }

class _Cell {
  int mark = -1, dep = 0; final ends = <_Way>[]; Map<int, List<int>>? _at; List<_Way>? fresh;
  static int _key(_Way r, bool local) { final f = local ? r.last : r.first; return r.end << 31 | ((!local && f > r.end ? r.end + 1 : f) & 0x3fffffff); }
  static bool _covers(_Way a, _Way b, bool local) => a.owed == b.owed && (local || a.spent <= b.spent && a.used <= b.used);
  bool add(_Way? r, bool local) { if (r == null) return false; if (ends.isEmpty) { ends.add(r); return true; }
    final at = _at ??= {_key(ends[0], local): [0]}, k = _key(r, local), l = at[k]; if (l != null) { for (final i in l) { if (!_covers(ends[i], r, local)) continue;
        if (!_covers(r, ends[i], local)) return false;
        final c = ends[i].cmp(r); if (c > 0 || c == 0 && (r.owed == 0 || r.piece is peg.MatchResult)) ends[i] = r; return c > 0; }
      for (final i in l) { if (_covers(r, ends[i], local)) { ends[i] = r; return true; } } l.add(ends.length); } else { at[k] = [ends.length]; } ends.add(r); return true; } }

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName});
  final Map<String, peg.Clause> rules; final String topRuleName; late peg.Parser parser; String path = '';
  final _cells = <Object, _Cell>{}, _evidence = Map<peg.MatchResult, int>.identity(), _nexts = <(peg.Clause, int), List<int>>{}, _mins = <Object, int>{};
  bool _delta = false; bool get _local => _rung <= 0;
  int _depth = 0, _seedDepth = _never, _budget = 0, _rung = 0, lastCost = 0, _work = _never;
  static const _cap = 2, _per = 4, _floor = 4096, _exactPer = 16;
  int get _len => parser.input.length;
  int recoverCost(String input) => (this..recover(input)).lastCost;

  _Way? _plain(peg.Clause c, int pos) { if ((c is peg.FollowedBy || c is peg.NotFollowedBy) && _depth > 0) {
      final saved = [for (final r in parser.rules.values) if (parser.getMemoEntry(r, pos) case final e?) (r, e, e.result, (_cells[e]?.dep ?? 0) != 0)]; if (saved.any((x) => x.$4)) {
        for (final (_, e, _, a) in saved) { e..inRecPath = a..foundLeftRec = false..result = null; } ++parser.memoVersion[pos]; final m = c.match(parser, pos);
        for (final x in saved) { if (!m.isMismatch && x.$4 && x.$2.foundLeftRec) { final c = _cells[x.$2]!; _seedDepth = _min(_seedDepth, -(c.dep = -c.dep.abs())); } }
        for (final (_, e, s, _) in saved) { e..inRecPath = false..result = s; } ++parser.memoVersion[pos]; return m.isMismatch ? null : _Way.clean(pos + m.len, _ev(m), m); } }
    final m = parser.match(c, pos); return m.isMismatch ? null : _Way.clean(pos + m.len, _ev(m), m); }
  int _end(peg.Clause c, int pos) => c is peg.FollowedBy || c is peg.NotFollowedBy ? _plain(c, pos)?.end ?? -1 : switch (parser.match(c, pos)) { final m when !m.isMismatch => pos + m.len, _ => -1 };
  int _ev(peg.MatchResult m) { for (final q = _evidence[m] == null ? [m] : const <peg.MatchResult>[]; q.isNotEmpty;) {
      final n = q.last, c = n.clause, k = c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet ? const <peg.MatchResult>[] : n.subClauseMatches;
      var s = 0; for (final x in k) { _evidence[x] != null ? s += _evidence[x]! : q.add(x); }
      if (q.last == n) { q.removeLast(); _evidence[n] = k.isEmpty && (c is peg.Str || c is peg.Char || c is peg.CharSet && !c.inverted) ? n.len : s; } } return _evidence[m]!; }
  bool _oneShape(peg.Clause c, [Set<peg.Clause>? s]) => (_mins[(c, 0)] ??= (s ??= {}).add(c) && switch (c) { peg.Seq() => c.subClauses.every((x) => _oneShape(x, s)), peg.Repetition() => c.requireOne && _oneShape(c.subClause, s), peg.Ref() => _oneShape(parser.rules[c.ruleName]!, s), peg.Terminal() || peg.FollowedBy() || peg.NotFollowedBy() => true, _ => false } ? 1 : 0) > 0;
  int _min0(peg.Clause c) => _mins[c] ??= _minChars(c, {});
  int _minChars(peg.Clause c, Set<(peg.Clause, bool)> p, [bool req = false]) { if (!p.add((c, req))) return _never;
    final n = switch (c) { peg.Seq() => c.subClauses.fold(0, (a, b) => _min(_never, a + _minChars(b, p))), peg.First() => c.subClauses.fold(_never, (a, b) => _min(a, _minChars(b, p, req))), peg.Ref() => _minChars(parser.rules[c.ruleName]!, p, req), peg.Repetition() when c.requireOne || req => _minChars(c.subClause, p, true), peg.Optional() when req => _minChars(c.subClause, p, true), peg.Str() => c.text.length, peg.Char() || peg.CharSet() || peg.AnyChar() => 1, peg.FollowedBy() => !req && _minChars(c.subClause, p) < _never ? 0 : _never, _ => req ? _never : 0 };
    p.remove((c, req)); return n; }

  List<_Way> _read(peg.Clause c, int pos) {
    final delta = _delta; _delta = false; var computed = false; if (_min0(c) == _never) return const [];
    final plain = _plain(c, pos); if (_budget == 0 && pos < _len) return plain == null ? const [] : [plain]; if (c is peg.FollowedBy || c is peg.NotFollowedBy) return [plain ?? _Way.clean(pos, 0, c)];
    if (c is peg.Terminal) { if (plain != null) return [plain];
      if (c is peg.Str && c.text.length > 1) return [for (final r in _seq([for (var i = 0; i < c.text.length; i++) peg.Char(c.text[i])], pos)) r.label(pos)];
      final eof = pos == _len ? 1 : 0, s = 1 - eof, m = peg.Match(c, pos, 0, subClauseMatches: [peg.SyntaxError(pos: pos, len: 0)]);
      return [_Way(pos, 1, s + _Way._ex(eof), 0, m, eof > 0 ? _Way.clean(pos) : null), if (s > 0 && (c is peg.Char || c is peg.Str)) _Way(pos + 1, 1, 1, 0, (c, pos))]; }
    if (c is peg.Ref) { _delta = delta; return [for (final r in _read(parser.rules[c.ruleName]!, pos)) if (r.clean || r.evidence > 0 || r.end == pos || r.owed == 0 && r._allSub) r]; }
    final cell = _cells[parser.getMemoEntry(c, pos)!] ??= _Cell(), b = _budget; if (cell.dep != 0) { _seedDepth = _min(_seedDepth, -(cell.dep = -cell.dep.abs()));
    } else if (cell.mark < (b << 31 | _never) && cell.mark < (b << 31 | ((_cells[pos]?.mark ?? -1) + 1))) {
      final d = cell.dep = ++_depth, outer = _seedDepth, pe = plain?.end ?? -1, all = <_Way>[]; var ms = _never, minJ = pe + 1; cell.fresh = null; do { _seedDepth = _never; final fresh = <_Way>[];
        for (final r in _propose(c, pos)) { if (--_work < 0 && (_rung > _cap || _rung == 0)) throw _Stop();
          if ((_local || r.cost <= _rung) && (!r.clean || cell.dep < 0 || _seedDepth < _never || r.end <= pe) && cell.add(r, _local)) {
            final ts = _local && cell.dep < 0 && (r.synced(pos, 0) || r.pureSub(pos)) ? _cells[(c, r.end)]?.fresh : null;
            if (ts != null && ts.isNotEmpty) { for (final s in ts) { if (r.then(s, true) case final w? when w.used <= b && cell.add(w, _local)) { all.add(w); minJ = minJ == pe + 1 ? w.end : _min(minJ, w.end); } } } else { fresh.add(r); }
          } } ms = _min(ms, _seedDepth); all.addAll(fresh); if (fresh.isEmpty || cell.dep > 0 || _seedDepth > d) break; (_cells[pos] ??= _Cell()).mark++; cell.fresh = fresh; } while (true);
      if (_local && cell.dep < 0 && pe > pos) (_cells[(c, pe)] ??= _Cell()).fresh = [for (final w in cell.ends) if (w.end >= minJ && w.firstAfter(pe)) w.tail(pe, plain!.evidence)];
      _depth--; cell..dep = 0..fresh = all..mark = b << 31 | (ms < d ? (_cells[pos]?.mark ?? -1) + 1 : _never); computed = true; _seedDepth = _min(outer, ms < d ? ms : _never); }
    final raw = cell.dep != 0 && cell.fresh != null || delta && computed ? cell.fresh! : cell.ends;
    return [for (final r in raw) if (r.used <= b) r.preferred && plain?.end == r.end ? plain! : r.label(pos)]; }

  bool _active(peg.Clause? c, int at) => switch (c) { peg.Repetition(:final subClause) => _active(subClause, at), peg.First(:final subClauses) => subClauses.any((x) => _active(x, at)), peg.Ref(:final ruleName) => (_cells[parser.getMemoEntry(parser.rules[ruleName]!, at)]?.dep ?? 0) != 0, _ => false };
  List<peg.Clause> _flat(List<peg.Clause> s) => !s.any((x) => x is peg.Seq) || s.any((x) => x is peg.HasOneSubClause) ? s : [for (final x in s) if (x is peg.Seq && !_flat(x.subClauses).any((y) => y is peg.HasOneSubClause)) ..._flat(x.subClauses) else x];
  List<_Way> _propose(peg.Clause c, int pos) {
    if (c is peg.Seq) return _seq(_flat(c.subClauses), pos); if (c is peg.Repetition) return _repeat(c, pos); if (c is peg.Optional) { final rs = _read(c.subClause, pos); return [_Way.clean(pos, 0, rs.any((r) => r.preferred && r.end > pos) ? c : null), ...rs]; }
    final cell = _cells[parser.getMemoEntry(c, pos)!]!, out = <_Way>[]; var cut = _never, sd = _seedDepth; for (final sub in (c as peg.First).subClauses) {
      final act = _active(sub, pos); _delta = cell.fresh != null; final rs = _read(sub, pos), f = act ? -1 : rs.fold(-1, (m, r) => r.preferred && r.end > m ? r.end : m);
      if (act || rs.isEmpty) sd = _min(sd, _seedDepth); for (final r in rs) { if (cut < _never && (r.clean ? r.end >= cut : r.firstAfter(cut - 1) || r.absorbed(pos) > 0 && r.absorbed(pos) >= r.evidence)) continue;
        if (_seedDepth < _never && (r.end > pos || !r.clean)) sd = _min(sd, _seedDepth); out.add(cut < _never && r.clean ? _Way.clean(r.end, r.evidence, c) : r); } if (f > pos && _seedDepth == _never) cut = _min(cut, f); } _seedDepth = sd; return out; }

  bool _startsClean(peg.Clause c, int at, [Set<peg.Clause>? s]) => (s ??= {}).add(c) && switch (c) { peg.Ref() => _startsClean(parser.rules[c.ruleName]!, at, s), peg.First() => c.subClauses.any((x) => _startsClean(x, at, s)), peg.Seq(:final subClauses) => subClauses.isNotEmpty && switch (_flat(subClauses)[0]) { final x => !_active(x, at) && _end(x, at) > at }, peg.Terminal() => _end(c, at) > at, _ => false };

  List<_Way> _seq(List<peg.Clause> slots, int pos) { var cur = [_Way.clean(pos)]; for (var i = 0; i < slots.length; i++) {
      final s = slots[i], next = _Cell(), last = i == slots.length - 1; for (final r in cur) {
        final sub = (_local || s is peg.Repetition) && r.pureSub(pos), sync = r.used > 0 && (last && r.synced(pos) || _local && sub && (last ? r.evidence > 0 || r.edits == 1 && _startsClean(s, r.end) : r.evidence > r.edits && r.firstAfter(pos)));
        final rSub = sub && (!_local || (s is! peg.Terminal ? sync : last ? r.edits <= i + _min0(parser.rules[topRuleName]!) && r.evidence > r.edits && (r.edits == 1 ? r.last == r.end : r.end - r.first == r.edits) : r.evidence * 2 >= r.edits && r.firstAfter(pos)));
        final canS = r.used > 0 && (!_local && s is peg.Repetition && r.synced(pos) || _local && s is! peg.Terminal && sync || rSub || r.end == pos && _startsClean(s, r.end));
        final b0 = _budget, prevSeed = _seedDepth; _budget = canS ? b0 : b0 - r.used; _seedDepth = _never; final options = _read(s, r.end); _budget = b0; _seedDepth = _min(prevSeed, _seedDepth); var del = -1;
        if (!options.any((o) => o.clean && o.end > r.end)) {
          final sk = last && sync && !_startsClean(s, r.end), j = _next(s, r.end + 1, r.end + _budget - (sk ? 0 : r.used), options.any((o) => o.preferred) ? 1 : 0);
          if (j < _never) { final m = _plain(s, j)!; next.add(r.then(_Way.skip(r.end, j), sk)?.then(m), _local); if (!last && (_plain(slots[i + 1], m.end)?.end ?? -1) >= (_plain(slots[i + 1], r.end)?.end ?? 0)) del = j - r.end; }
        }
        final adv = _seedDepth == _never && s is peg.Repetition && r.end == pos && pos < _len && !r.clean && !_oneShape(s.subClause), pen = del > 0 && !_active(s, r.end) && !_oneShape(s), g = i > 0 ? _greedy(slots[i - 1], r) : null;
        for (final o in options) { if (o.end == r.end && (adv || pen && !o.clean && del <= o.spent) || g != null && (!o.clean || r.piece is peg.Optional && o.end > r.end) && _takes(g, _head(o, r.end))) continue;
          final ofa = canS && o.firstAfter(r.end), st = canS && (rSub && o.pureSub(r.end) && (s is peg.Terminal || (ofa ? o.evidence > 0 : s is peg.Seq && o.evidence > o.edits)) || (_local && sync && r.end > r.last || ofa) && (o.synced(r.end, 0) || _local && o.owed > 0 && o.evidence > o.cost && o.evidence > o.absorbed(r.end) + 1));
          if (r.then(o, st) case final w? when w.used <= b0 && (_local || w.cost <= _rung)) next.add(w, _local); } } cur = next.ends; if (cur.isEmpty) break; } return cur; }

  List<_Way> _repeat(peg.Repetition c, int p) {
    final sub = c.subClause, zero = _Way.clean(p), best = _Cell(), q = {p << 3: zero}, done = <_Way>{}, unit = _min0(sub) == 1 && !_oneShape(sub) && !_active(sub, p); void push(_Way? w) { if (w != null && !_local && w.cost > _rung || !best.add(w, _local)) return;
      final k = w!.end << 3, e = q[k | 4]; if (q[k] == null || q[k]!.cmp(w) >= 0) q[k] = w; if (e == null || w.cost < e.cost || w.cost == e.cost && w.first < e.first) q[k | 4] = w; }
    while (q.isNotEmpty) { var r = q.remove(q.keys.reduce(_min))!; if (!done.add(r)) continue; final e0 = r.end;
      for (var m1 = _active(sub, r.end) ? null : _plain(sub, r.end); m1 != null && m1.end > r.end && m1.evidence > 0;) {
        final m2 = _plain(sub, m1.end), next = m2 != null && m2.end > m1.end ? r.then(m1) : null; if (next == null) break; r = next; m1 = m2!; } if (r.end > e0) { push(r); continue; }
      final cleanTail = r.prev != null && r.edits == r.prev!.edits, rSub = r.used > 0 && unit && r.pureSub(p), canS = r.used > 0 && (rSub || r.evidence > r.absorbed(p) + 1 && (cleanTail || r.end > r.last + (_rung < 0 || unit && _startsClean(sub, r.end) ? 0 : 1)));
      final b0 = _budget; _budget = canS ? b0 : b0 - r.used; final steps = _read(sub, r.end); _budget = b0; if (sub is! peg.CharSet && !_active(sub, r.end) && !steps.any((s) => s.clean && s.end > r.end)) {
        final j = _next(sub, r.end + 1, r.end + _budget - r.used, 1); if (j < _never) push(r.then(_Way.skip(r.end, j))?.then(_plain(sub, j)!)); }
      bool syncs(_Way s) => _end(sub, s.end) > s.end; final anySync = canS && steps.any((s) => s.end > r.end && syncs(s)); for (final s in steps) { if (s.end <= r.end) continue;
        final settle = canS && !s.clean && (!anySync && rSub && s.evidence > 0 && s.pureSub(r.end) || s.evidence > 1 && (cleanTail || s.firstAfter(r.end)) && (syncs(s) || !anySync && s.evidence > s.absorbed(r.end)));
        if (r.then(s, settle) case final w? when w.used <= b0) push(w); } } for (final r in _read(sub, p)) { if (r.end == p && !r.clean) best.add(zero.then(r), _local); }
    if (!c.requireOne) best.add(zero, _local); return [for (final r in best.ends) if (!_local || _rung == -2 || _end(sub, r.end) <= r.end || r.end == p && _seedDepth < _never) r]; }

  int _next(peg.Clause c, int j, int to, int test) {
    final memo = _nexts[(c, test)] ??= List.filled(_len + 2, 0), seen = <int>[]; var r = _never; for (to = _min(to, _len); j <= to; j++) {
      final v = memo[j]; if (v > 0) { r = v - 1; break; } if (v < 0) { j = -v - 1; continue; } seen.add(j); final end = _end(c, j); if (end >= 0 && (test == 0 || end > j)) { r = j; break; } }
    for (final x in seen) { memo[x] = r < _never ? r + 1 : -j; } return r > to ? _never : r; }

  static peg.Terminal? _greedy(peg.Clause s, _Way r) {
    final b = switch (s) { peg.Optional(:final subClause) || peg.Repetition(:final subClause) => subClause, _ => null }, p = r.prev;
    return (b is peg.Char || b is peg.CharSet || b is peg.Str && b.text.length == 1) && (s is peg.Repetition || p != null && p.end == r.end && p.edits == r.edits) ? b as peg.Terminal : null; }
  static bool _takes(peg.Terminal t, int ch) => ch >= 0 && switch (t) { peg.Char(:final char) || peg.Str(text: final char) => char.codeUnitAt(0) == ch, peg.CharSet(:final ranges, :final inverted) => inverted != ranges.any((r) => ch >= r.$1 && ch <= r.$2), _ => false };
  int _head(_Way o, int at) { if (o.firstAfter(at)) return at < _len ? parser.input.codeUnitAt(at) : -1;
    final es = _edits((0, o)); for (var q = at;; q++) {
      int? sub; var del = false; for (final (op, p, ch) in es) { if (p == q) { if (op == 1) return ch.abs(); if (op == 0) { del = true; } else { sub = ch.abs(); } } }
      if (sub != null) return sub; if (!del) return q < _len ? parser.input.codeUnitAt(q) : -1; } }
  List<(int, int, int)> _edits(Object root) {
    final out = <(int, int, int)>[]; for (final todo = [root]; todo.isNotEmpty;) { switch (todo.removeLast()) {
        case (_, final _Way w): for (_Way? r = w; r != null && !r.clean; r = r.prev) { if (r.edits > (r.prev?.edits ?? 0)) todo.add(r.piece!); } case (final peg.Terminal t, final int at): out.add((2, at, _code(t, 0)));
        case final peg.SyntaxError m: for (var q = m.pos; q < m.pos + m.len; q++) { out.add((0, q, 0)); }
        case peg.MatchResult(:final peg.Terminal clause, :final pos, subClauseMatches: [peg.SyntaxError(len: 0)]): out.add((1, pos, _code(clause, 0))); } } return out; }

  peg.MatchResult recover(String input) { (_Way, peg.MatchResult, List<(int, int)>)? checked; try { parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input);
      _cells.clear(); _evidence.clear(); _nexts.clear(); _depth = 0; _seedDepth = _never; var deep = false; final top = parser.rules[topRuleName]!;
      _Way.len = _len; _Way.maxOwed = rules.values.fold(0, (a, r) => a + (_min0(r) < _never ? _min0(r) : 0));
      void sweep(void Function(peg.Clause, int) fn) { for (var p = _len; p >= 0; p--) { for (final r in parser.rules.values) { if (r is! peg.Ref) fn(r, p); } } } late peg.MatchResult verdict;
      try { verdict = parser.match(top, 0); } on StackOverflowError { deep = true; parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input); sweep(parser.match); verdict = parser.match(top, 0); }
      if (!verdict.isMismatch && verdict.len == _len) { lastCost = 0; return (path = 'plain', verdict).$2; }
      final shortest = _min0(top), limit = _floor + _per * parser.rules.length * (_len + 1); var ceiling = shortest == _never ? -1 : _len + shortest; (_Way, peg.MatchResult, List<(int, int)>)? best;
      (_Way, peg.MatchResult, List<(int, int)>)? run(int rung) { (_Way, peg.MatchResult, List<(int, int)>)? b; _budget = rung; if (!_local) _rung = rung; List<_Way> ways;
        try { if (deep) sweep(_read); ways = _read(top, 0); } on StackOverflowError {
          deep = true; _depth = 0; _seedDepth = _never; _budget = rung; parser = peg.Parser(rules: rules, topRuleName: topRuleName, input: input); _cells.clear(); sweep(parser.match); sweep(_read); ways = _read(top, 0);
        } Iterable<(_Way?, _Way)> all() sync* { for (final r in ways) { yield (null, r); }
          if (rung > 0 && _len > 0 && !_local) { for (var p = 1; p <= _min(rung, _len); p++) { for (final r in _read(top, p)) { yield (_Way.skip(0, p), r); } } } } for (final (lead, r0) in all()) {
          final r = lead == null ? r0 : lead.then(r0); if (r == null) continue;
          final w = _len == r.end ? r : r.then(_Way.skip(r.end, _len)); if (w == null || (_local ? w.used : w.cost) > rung || w.clean || b != null && w.cmp(b.$1) >= 0) continue;
          final s = _apply(input, _edits((0, w))), str = String.fromCharCodes(s.map((x) => x.$2)), m = _parse(str); if (!m.isMismatch && m.len == str.length) b = (w, m, s); }
        if (b != null && (checked == null || b.$1.cmp(checked!.$1) < 0)) checked = b; return b; } var lo = 0, sure = 0, reach = 0; _rung = 1; _work = limit;
      for (var b = 1; best == null && (lo < ceiling || _rung != -2);) { if (lo >= ceiling) { if (checked == null && ceiling < _len + _Way.maxOwed + 5) { ceiling = _len + _Way.maxOwed + 5; _rung = 1; b = 1; lo = 0; _work = limit; _cells.clear(); continue; } if (_rung != -1) break; _rung = -2; b = 1; lo = 0; _cells.clear(); }
        try { if ((best = run(_min(b, ceiling))) == null) lo = _min(b, ceiling); b *= 2; } on _Stop { if (_rung > 0) { sure = lo; reach = 2 * _min(b, ceiling); }
          _rung = _rung > 0 ? 0 : -1; b = 1; lo = 0; _work = _rung == 0 ? _exactPer * limit : _never; _depth = 0; _seedDepth = _never; _cells.clear(); } }
      if (best != null && _rung <= 0 && best.$1.cost > sure + 1 && best.$1.cost <= reach + 1) { _rung = best.$1.cost - 1; _work = 4 * _exactPer * limit; _depth = 0; _seedDepth = _never; _cells.clear();
        try { best = run(_rung) ?? best; } on _Stop { /* keep local */ } } if (best ?? checked case final x?) { lastCost = x.$1.edits; return (path = 'checked', _map(x.$2, x.$3, input)).$2; }
      final cs = <int>{}; void collect(peg.Clause c) { if (c is peg.Terminal) { for (var j = 0; j < (c is peg.Str ? c.text.length : 1); j++) { cs.add(_code(c, j).abs()); } } else if (c is peg.HasOneSubClause) { collect(c.subClause); } else if (c is peg.HasMultipleSubClauses) { c.subClauses.forEach(collect); } }
      rules.values.forEach(collect); final seen = {input}, q = [([for (var i = 0; i < _len; i++) (i, input.codeUnitAt(i))], 0)];
      for (var qi = 0; qi < q.length && seen.length < 4096; qi++) { final (s, d) = q[qi];
        for (final n in [for (var i = 0; i < s.length; i++) [...s.sublist(0, i), ...s.sublist(i + 1)], for (var i = 0; i < s.length; i++) if (s[i].$1 >= 0) for (final c in cs) [...s.sublist(0, i), (-2 - s[i].$1, c), ...s.sublist(i + 1)], for (var i = 0; i <= s.length; i++) for (final c in cs) [...s.sublist(0, i), (-1, c), ...s.sublist(i)]]) {
          final str = String.fromCharCodes(n.map((x) => x.$2)); if (!seen.add(str)) continue;
          final m = _parse(str); if (!m.isMismatch && m.len == str.length) { lastCost = d + 1; return (path = 'exact', _map(m, n, input)).$2; }
          if (seen.length < 4096) q.add((n, d + 1)); } }
      lastCost = _len == 0 ? 1 : _len; return (path = 'none', peg.SyntaxError(pos: 0, len: input.length)).$2; } on _Stop {
      if (checked case final b?) { lastCost = b.$1.edits; return (path = 'bounded', _map(b.$2, b.$3, input)).$2; } return (path = 'none', peg.SyntaxError(pos: 0, len: input.length)).$2;
    } on StackOverflowError { return (path = 'unchecked', peg.SyntaxError(pos: 0, len: input.length)).$2; } }

  static int _code(peg.Terminal t, int j) => switch (t) { peg.Str(:final text) => text.codeUnitAt(j), peg.Char(:final char) => char.codeUnitAt(0), peg.CharSet(:final ranges, inverted: false) when ranges.isNotEmpty => -ranges[0].$1, peg.CharSet(:final ranges) => -[for (var x = 32; x < 0x10000; x++) x].firstWhere((x) => !ranges.any((r) => x >= r.$1 && x <= r.$2)), _ => -32 };
  static List<(int, int)> _apply(String input, List<(int, int, int)> es) {
    final out = <(int, int)>[]; var j = 0; for (var i = 0; i <= input.length; i++) { var del = false; int? sub;
      for (; j < es.length && es[j].$2 == i; j++) { final (op, _, ch) = es[j]; if (op == 1) { out.add((-1, ch.abs())); } else if (op == 0) { del = true; } else { sub = ch.abs(); } }
      if (i < input.length && !del) out.add((sub == null ? i : -2 - i, sub ?? input.codeUnitAt(i))); } return out; }
  peg.MatchResult _parse(String w) { var p = peg.Parser(rules: rules, topRuleName: topRuleName, input: w); try { return p.matchRule(topRuleName, 0); } on StackOverflowError {
      p = peg.Parser(rules: rules, topRuleName: topRuleName, input: w); for (var q = w.length; q >= 0; q--) { for (final r in p.rules.values) { p.match(r, q); } } return p.matchRule(topRuleName, 0); } }
  peg.MatchResult _map(peg.MatchResult root, List<(int, int)> s, String input) {
    int at(int q) => s[q].$1 >= 0 ? s[q].$1 : s[q].$1 <= -2 ? -2 - s[q].$1 : -1;
    final orig = List.filled(s.length + 1, input.length), todo = <void Function()>[], ts = <peg.MatchResult>[]; var next = 0;
    for (var q = s.length - 1; q >= 0; q--) { orig[q] = at(q) >= 0 ? at(q) : orig[q + 1]; }
    List<peg.MatchResult> gap(int o) { if (o <= next) return const []; final g = peg.SyntaxError(pos: next, len: o - next); next = o; return [g]; }
    peg.MatchResult letter(peg.Clause l, int q, [bool own = false]) {
      final o = orig[q]; if (s[q].$1 >= 0) { next = o + 1; return peg.Match(l, o, 1); }
      if (s[q].$1 <= -2) { next = o + 1; final e = peg.SyntaxError(pos: o, len: 1); return own ? peg.Match(peg.First([l]), o, 1, subClauseMatches: [e]) : e; }
      return peg.Match(l, o, 0, subClauseMatches: [peg.SyntaxError(pos: o, len: 0)]); } void walk(peg.MatchResult m, List<peg.MatchResult> into, [peg.Clause? up]) {
      final c = m.clause, kids = <peg.MatchResult>[], o = orig[m.pos]; if (m.len == 0) { todo.add(() => into.add(peg.Match(c, o < next ? o : next, 0, subClauseMatches: kids))); } else { into.addAll(gap(o));
        if (m.subClauseMatches.isEmpty) { var clean = true; for (var q = m.pos; q < m.pos + m.len; q++) { if (s[q].$1 < 0 || orig[q] != o + q - m.pos) clean = false; }
          if (clean) { next = o + m.len; into.add(peg.Match(c, o, m.len)); return; } if (m.len == 1) { into.add(letter(c!, m.pos, up == null || up is peg.Ref)); return; }
          for (var q = m.pos; q < m.pos + m.len; q++) { kids.addAll(gap(orig[q])); kids.add(letter(peg.Char((c as peg.Str).text[q - m.pos]), q)); }
          into.add(peg.Match(c, o, next - o, subClauseMatches: kids)); return; } todo.add(() => into.add(peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids))); }
      for (final k in m.subClauseMatches.reversed) { todo.add(() => walk(k, kids, c)); } } for (todo.add(() => walk(root, ts)); todo.isNotEmpty;) { todo.removeLast()(); }
    ts.addAll(gap(input.length)); return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts); } }
