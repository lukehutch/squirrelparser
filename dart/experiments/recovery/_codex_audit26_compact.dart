import 'package:squirrel_parser/squirrel_parser.dart'; class Repaired extends MatchResult {
  Repaired(super.clause, super.pos, super.len, this.children, this.errors); final List<MatchResult> children;
  final List<SyntaxError> errors; @override
  List<MatchResult> get subClauseMatches =>
      [...children, ...errors]..sort((a, b) => a.pos - b.pos); @override
  String toPrettyString(String input, {int indent = 0}) {
    final b = StringBuffer(); for (final k in subClauseMatches) {
      b.write(k.toPrettyString(input, indent: indent)); }
    return b.toString(); } }
const int _far = 1 << 30; const int _peg = _far + 1;
int _min(int a, int b) => a < b ? a : b; class _Way {
  const _Way(
      this.end, this.del, this.gap, this.net, this.key, this.clause, this.pos,
      [this.node, this.prev, this.mark = -1]); const _Way.unit(int p) : this(p, 0, 0, 0, _peg, null, p);
  _Way.skip(int from, int to)
      : this(to, to - from, 0, 0, from, null, from, null, null, from * 2 + 1); _Way.owe(int p, int n) : this(p, 0, n, 0, p, null, p, null, null, p * 2);
  final int end; final int key;
  int get fix => key > _far ? _far : key; bool get peg => key > _far;
  final int del, gap; final int net;
  final Clause? clause; final int pos, mark;
  final _Way? node, prev; bool get free => key >= _far;
  _Way then(_Way v) => _Way(
      v.end,
      del + v.del,
      gap + v.gap,
      net + v.net,
      _min(key, v.key),
      null,
      v.pos,
      v.clause == null ? v.node : v,
      this,
      v.mark); _Way over(Clause c, int p, [int k = _peg]) =>
      _Way(end, del, gap, net, _min(key, k), c, p, this); _Way get demoted =>
      _Way(end, del, gap, net, _min(key, _far), clause, pos, node, prev, mark); }
class _Cell {
  List<_Way> ways = const []; bool inPath = false, foundLR = false, has = false;
  int gen = -1; int at = -1; }
class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      final n = e.key.startsWith('~') ? e.key.substring(1) : e.key; this.rules[n] = e.value; } }
  final Map<String, Clause> rules = {}; final String topRuleName;
  late String _in; final Map<Clause, List<_Cell?>> _memo = {};
  late List<_Way?> _atEnd; late List<int> _seenEnd;
  final List<int> _usedEnds = []; int _pruneStamp = 0;
  late List<int> _version; final Map<Clause, bool> _det = {};
  final Map<Clause, int> _fill = {}; static const int _never = 1 << 30;
  int lastCost = 0; int _budget = 0;
  static int _rank(_Way a, _Way b) {
    final ea = a.del + a.gap, eb = b.del + b.gap; if (ea != eb) return ea - eb;
    if (a.peg != b.peg) return a.peg ? -1 : 1; if (a.net != b.net) return b.net - a.net;
    return b.key - a.key; }
  List<_Way> _prune(List<_Way> ws) {
    if (ws.length <= 1) return ws; if (ws.length == 2) {
      final a = ws[0], b = ws[1]; if (a.end == b.end) return [_rank(a, b) <= 0 ? a : b];
      final both = a.peg && b.peg; final x = both && a.end < b.end ? a.demoted : a;
      final y = both && b.end < a.end ? b.demoted : b; return _rank(x, y) <= 0 ? [x, y] : [y, x]; }
    final stamp = ++_pruneStamp; _usedEnds.clear();
    var far = -1; for (final w in ws) {
      if (w.peg && w.end > far) far = w.end; if (_seenEnd[w.end] != stamp) {
        _seenEnd[w.end] = stamp; _usedEnds.add(w.end);
        _atEnd[w.end] = w; } else if (_rank(w, _atEnd[w.end]!) < 0) {
        _atEnd[w.end] = w; } }
    final out = [
      for (final end in _usedEnds)
        _atEnd[end]!.peg && end != far ? _atEnd[end]!.demoted : _atEnd[end]!
    ]..sort(_rank); return out; }
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const []; if (c is Ref) return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    if (c is! HasOneSubClause && c is! HasMultipleSubClauses) {
      return _prune(_terminal(c, pos)); }
    final row = _memo[c] ??= List<_Cell?>.filled(_in.length + 1, null); final e = row[pos] ??= _Cell();
    if (e.inPath) {
      if (e.has) return e.ways; e.foundLR = true;
      e.has = true; return e.ways = const []; }
    if (e.has && e.gen == _version[pos] && e.at >= _budget) {
      return e.at == _budget ? e.ways : _afford(e.ways); }
    e.inPath = true; while (true) {
      final fresh = _expand(c, pos), old = _afford(e.ways);
      final got = old.isEmpty ? _prune(fresh) : fresh.isEmpty ? old : _prune(fresh..addAll(old)); final done = e.has && !_improved(got, e.ways);
      e.ways = got; e.has = true;
      e.at = _budget; if (done || !e.foundLR) break;
      e.gen = ++_version[pos]; }
    e.inPath = false; e.gen = _version[pos];
    e.at = _budget; return e.ways; }
  List<_Way> _afford(List<_Way> ws) {
    if (ws.isEmpty || ws.last.del + ws.last.gap <= _budget) return ws; return [
      for (final w in ws)
        if (w.del + w.gap <= _budget) w ]; }
  static bool _improved(List<_Way> a, List<_Way> b) {
    if (a.length != b.length) return true; for (var i = 0; i < a.length; i++) {
      if (a[i].end != b[i].end || _rank(a[i], b[i]) != 0) return true; }
    return false; }
  List<_Way> _expand(Clause c, int pos) {
    if (c is Ref) return _lift(c, pos, _ways(rules[c.ruleName]!, pos)); if (c is Seq) return _seq(c, pos);
    if (c is First) return _first(c, pos); if (c is Repetition) return _rep(c, pos);
    if (c is Optional) return _opt(c, pos); if (c is FollowedBy || c is NotFollowedBy) {
      final sub =
          c is FollowedBy ? c.subClause : (c as NotFollowedBy).subClause; final ok = _ways(sub, pos).any((w) => w.free);
      return (c is FollowedBy) == ok
          ? [_Way(pos, 0, 0, 0, _peg, c, pos)]
          : const []; }
    return _terminal(c, pos); }
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) => [
        for (final w in ways)
          if (w.net > 0 || w.free || _determined(c)) w.over(c, pos) ]; List<_Way> _seq(Seq c, int pos) {
    final stops = <_Way>[]; final moved = <_Way>[];
    var cur = <_Way>[_Way.unit(pos)]; var whole = true;
    for (var i = 0; i < c.subClauses.length; i++) {
      final sub = c.subClauses[i]; final next = <_Way>[];
      for (final w in cur) {
        if (w.del + w.gap > _budget) break; final full = _budget;
        _budget = full - w.del - w.gap; final here = _ways(sub, w.end);
        _budget = full;
        for (final v in here) {
          next.add(w.then(v)); }
        if (here.any((v) => v.free)) continue;
        if (i == 0) {
          for (var k = pos + 1; k <= pos + _budget && k <= _in.length; k++) {
            final full = _budget;
            _budget = 0;
            var chain = <_Way>[w.then(_Way.skip(pos, k))];
            for (final s in c.subClauses) {
              final step = <_Way>[];
              for (final x in chain) {
                for (final v in _ways(s, x.end)) {
                  if (!v.free) continue;
                  step.add(x.then(v)); } }
              chain = _prune(step);
              if (chain.isEmpty) break; }
            _budget = full;
            if (chain.isEmpty) continue;
            moved.addAll(chain);
            break; }
          continue; }
        if (w.end == _in.length && w.end > pos) {
          final owed = _owed(c, i);
          if (owed > 0 && owed < _never && w.del + w.gap + owed <= _budget) {
            var x = w;
            for (var j = 0; j < owed; j++) {
              x = x.then(_Way.owe(w.end, 1)); }
            stops.add(x); } }
        final room = _budget - w.del - w.gap;
        for (var k = w.end + 1; k <= w.end + room && k <= _in.length; k++) {
          final full = _budget;
          _budget =
              0;
          final at = _ways(sub, k);
          _budget = full;
          if (at.isEmpty) continue;
          final past = w.then(_Way.skip(w.end, k));
          for (final v in at) {
            if (!v.free) continue;
            next.add(past.then(v)); }
          break; } }
      if (next.isEmpty) {
        whole = false;
        break; }
      cur = _prune(next); }
    return _prune([
      for (final w in [if (whole) ...cur, ...stops, ...moved]) w.over(c, pos)
    ]); }
  int _owed(Seq c, int i) {
    var n = 0;
    for (var j = i; j < c.subClauses.length; j++) {
      final v = _minFill(c.subClauses[j]);
      if (v >= _never) return _never;
      n += v; }
    return n; }
  List<_Way> _first(First c, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in c.subClauses) {
      final ws = _ways(s, pos);
      for (final w in ws) {
        if (settled && !w.free && (w.end - pos) - w.del - w.net >= w.net) {
          continue; }
        out.add(w.over(c, pos, settled ? _far : _peg)); }
      settled = settled || ws.any((w) => w.peg); }
    return out; }
  List<_Way> _rep(Repetition c, int pos) {
    final zero = _Way.unit(pos);
    final peg = <int, _Way>{if (!c.requireOne) pos: zero};
    final other = <int, _Way>{};
    var frontier = <_Way>[zero];
    while (frontier.isNotEmpty) {
      final moved = <int>{};
      for (final w in frontier) {
        for (final v in _ways(c.subClause, w.end)) {
          if (v.end <= w.end) continue;
          final x = w.then(v);
          final lane = x.peg ? peg : other;
          final b = lane[x.end];
          if (b != null && _rank(x, b) >= 0) continue;
          lane[x.end] = x;
          moved.add(x.end * 2 + (x.peg ? 1 : 0)); } }
      frontier = [for (final k in moved) (k.isOdd ? peg : other)[k ~/ 2]!]; }
    final all = [...peg.values, ...other.values];
    if (all.isEmpty) {
      for (final v in _ways(c.subClause, pos)) {
        if (v.end != pos) continue;
        all.add(zero.then(v).demoted); } }
    return [for (final w in _prune(all)) w.over(c, pos)]; }
  List<_Way> _opt(Optional c, int pos) {
    final ws = _ways(c.subClause, pos);
    return [
      _Way(pos, 0, 0, 0, ws.any((w) => w.peg) ? _far : _peg, c, pos),
      for (final w in ws) w.over(c, pos) ]; }
  List<_Way> _terminal(Clause c, int pos) {
    final len = _len(c, pos);
    if (len >= 0) {
      final n =
          c is Str || c is Char || (c is CharSet && !c.inverted) ? len : 0;
      return [_Way(pos + len, 0, 0, n, _peg, c, pos)]; }
    if (_budget < 1) return const [];
    final out = <_Way>[];
    if (c is Str) {
      for (var k = c.text.length - 1; k >= 1; k--) {
        if (pos + k > _in.length || c.text.length - k > _budget) continue;
        final key = _alignKey(c.text, pos, k);
        if (key == null) continue;
        out.add(_Way(pos + k, 0, c.text.length - k, k, key, c, pos)); } }
    out.add(_Way(pos, 0, 1, 0, pos, c, pos));
    return out; }
  int? _alignKey(String text, int pos, int k) {
    var j = 0, first = -1;
    for (var i = 0; i < text.length; i++) {
      if (j < k && _in.codeUnitAt(pos + j) == text.codeUnitAt(i)) {
        j++;
      } else if (first < 0) {
        first = pos + j; } }
    return j == k ? first : null; }
  (List<MatchResult>, List<SyntaxError>)? _align(String text, int pos, int k) {
    final kids = <MatchResult>[];
    final fills = <SyntaxError>[];
    var j = 0;
    for (var i = 0; i < text.length; i++) {
      if (j < k && _in.codeUnitAt(pos + j) == text.codeUnitAt(i)) {
        kids.add(Match(null, pos + j, 1));
        j++;
      } else {
        fills.add(SyntaxError(pos: pos + j, len: 0)); } }
    return j == k ? (kids, fills) : null; }
  int _len(Clause c, int pos) {
    if (c is Str) {
      if (pos + c.text.length > _in.length) return -1;
      for (var i = 0; i < c.text.length; i++) {
        if (_in.codeUnitAt(pos + i) != c.text.codeUnitAt(i)) return -1; }
      return c.text.length; }
    if (c is Char) {
      return pos < _in.length && _in.codeUnitAt(pos) == c.char.codeUnitAt(0)
          ? 1
          : -1; }
    if (c is CharSet) {
      if (pos >= _in.length) return -1;
      final ch = _in.codeUnitAt(pos);
      var inSet = false;
      for (final (lo, hi) in c.ranges) {
        if (ch >= lo && ch <= hi) {
          inSet = true;
          break; } }
      return (c.inverted ? !inSet : inSet) ? 1 : -1; }
    if (c is AnyChar) return pos >= _in.length ? -1 : 1;
    if (c is Nothing) return 0;
    throw StateError('unknown clause type ${c.runtimeType}'); }
  MatchResult _emit(_Way w) {
    final c = w.clause!;
    if (w.node == null) {
      if (w.gap == 0) return Match(c, w.pos, w.end - w.pos);
      if (c is Str && w.end > w.pos) {
        final parts = _align(c.text, w.pos, w.end - w.pos)!;
        return Repaired(c, w.pos, w.end - w.pos, parts.$1, parts.$2); }
      return Repaired(c, w.pos, 0, const [], [SyntaxError(pos: w.pos, len: 0)]); }
    final parts = _parts(w.node!);
    return _wrap(c, w.pos, w.end, parts.$1, parts.$2); }
  (List<MatchResult>, List<SyntaxError>) _parts(_Way w) {
    final kids = <MatchResult>[];
    final errs = <SyntaxError>[];
    for (_Way? p = w; p != null; p = p.prev) {
      final child = p.clause == null ? p.node : p;
      if (child != null) kids.add(_emit(child));
      if (p.mark >= 0) {
        final pos = p.mark ~/ 2;
        errs.add(SyntaxError(pos: pos, len: p.mark.isOdd ? p.end - pos : 0)); } }
    return (kids.reversed.toList(), errs.reversed.toList()); }
  static MatchResult _wrap(Clause c, int pos, int end, List<MatchResult> kids,
      List<SyntaxError> errs) {
    if (errs.isEmpty && kids.isNotEmpty && kids.first.pos == pos) {
      return Match(c, pos, end - pos, subClauseMatches: kids); }
    return Repaired(c, pos, end - pos, kids, errs); }
  bool _determined(Clause c) {
    final memo = _det[c];
    if (memo != null) return memo;
    _det[c] = false;
    return _det[c] = c is Terminal || c is FollowedBy || c is NotFollowedBy
        ? true
        : c is Seq
            ? c.subClauses.every(_determined)
            : c is Repetition && c.requireOne
                ? _determined(c.subClause)
                : c is Ref
                    ? _determined(rules[c.ruleName]!)
                    : false; }
  MatchResult recover(String s) {
    _in = s;
    _memo.clear();
    _version = List.filled(s.length + 1, 0);
    _atEnd = List.filled(s.length + 1, null);
    _seenEnd = List.filled(s.length + 1, 0);
    _pruneStamp = 0;
    final fill = _minFill(rules[topRuleName]!);
    final ceiling = fill >= _never ? -1 : s.length + fill;
    _Way? best;
    for (_budget = 0; _budget <= ceiling; _budget++) {
      for (final w in _ways(rules[topRuleName]!, 0)) {
        final tail = s.length - w.end;
        if (w.del + w.gap + tail > _budget) continue;
        final a = _Way(
            w.end,
            w.del + tail,
            w.gap,
            w.net,
            tail == 0 ? w.key : _min(w.key, w.end),
            w.clause,
            w.pos,
            w.node,
            w.prev,
            w.mark);
        if (a.key == _far) continue;
        if (best == null || _rank(a, best) < 0) best = a; }
      if (best != null) break; }
    final root = best == null
        ? Repaired(
            null, 0, s.length, const [], [SyntaxError(pos: 0, len: s.length)])
        : best.end == s.length
            ? _emit(best)
            : Repaired(null, 0, s.length, [_emit(best)],
                [SyntaxError(pos: best.end, len: s.length - best.end)]);
    final (del, gap) = _edits(root);
    lastCost = del + gap;
    return root; }
  int _minFill(Clause c) {
    if (_fill.isEmpty) {
      final all = <Clause>[];
      void collect(Clause k) {
        if (_fill.containsKey(k)) return;
        _fill[k] = _never;
        all.add(k);
        if (k is Ref) {
          collect(rules[k.ruleName]!);
        } else if (k is HasOneSubClause) {
          collect(k.subClause);
        } else if (k is HasMultipleSubClauses) {
          k.subClauses.forEach(collect); } }
      rules.values.forEach(collect);
      for (var moved = true; moved;) {
        moved = false;
        for (final k in all) {
          final v = _fillOf(k);
          if (v < _fill[k]!) {
            _fill[k] = v;
            moved = true; } } } }
    return _fill[c] ?? _never; }
  int _fillOf(Clause c) {
    if (c is Ref) return _fill[rules[c.ruleName]!]!;
    if (c is Seq) {
      var n = 0;
      for (final k in c.subClauses) {
        final v = _fill[k]!;
        if (v >= _never) return _never;
        n += v; }
      return n; }
    if (c is First) {
      var n = _never;
      for (final k in c.subClauses) {
        if (_fill[k]! < n) n = _fill[k]!; }
      return n; }
    if (c is Repetition) return c.requireOne ? _fill[c.subClause]! : 0;
    if (c is Optional || c is FollowedBy || c is NotFollowedBy) return 0;
    return c is Nothing ? 0 : 1; }
  (int, int) _edits(MatchResult m) {
    var del = 0, gap = 0;
    void walk(MatchResult k) {
      if (k is SyntaxError) {
        if (k.len == 0) {
          gap++;
        } else {
          del += k.len; } }
      k.subClauseMatches.forEach(walk); }
    walk(m);
    return (del, gap); }
  int recoverCost(String s) {
    recover(s);
    return lastCost; } }
