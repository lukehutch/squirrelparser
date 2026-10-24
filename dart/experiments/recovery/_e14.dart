import 'dart:math';
import 'dart:typed_data';
import 'package:squirrel_parser/squirrel_parser.dart' as peg;

// Prototype: repair as a search over repaired strings. Each candidate is a
// real PEG parse of its repaired string, so every tree is valid. The next
// edit of a failed parse is placed no later than the last position that
// parse examined: a later edit cannot change what the parse saw.

const _seq = 0, _first = 1, _rep = 2, _opt = 3, _ref = 4, _not = 5, _and = 6;
const _char = 7, _str = 8, _set = 9, _any = 10, _nothing = 11;

// One edit of the input: delete the character at `at`, insert `ch` before
// it, or substitute `ch` for it. A negative `ch` is a placeholder for a
// character of an open class (D7): it stands in for -ch in character-class
// tests and matches no literal.
class _Edit {
  const _Edit(this.op, this.at, this.ch);
  final int op, at, ch; // op: _del, _ins, _sub
}

const _del = 0, _ins = 1, _sub = 2;
const _sym = -0x7fffffff; // the unknown character of a symbolic evaluation

class _Node {
  _Node(this.edits, [this.parentFar = -1, this.parentSig = 0, this.parentAlpha = 0]);
  final List<_Edit> edits;
  final int parentFar, parentSig, parentAlpha;
  int end = -1, far = 0, lastV = 0, n = 0, farIn = 0, sig = 0, encl = 0;
  peg.MatchResult? tree;
  int ev = -1;
}

class Squirrel {
  Squirrel({required this.rules, required this.topRuleName}) {
    final p = peg.Parser(rules: rules, topRuleName: topRuleName, input: '');
    final ids = Map<peg.Clause, int>.identity();
    int id(peg.Clause c) {
      final have = ids[c];
      if (have != null) return have;
      final i = ids[c] = _kind.length;
      _kind.add(-1); _kids.add(const []); _code.add(0); _text.add(const []); _ranges.add(const []); _inv.add(false);
      _clause.add(c);
      switch (c) {
        case peg.Seq(): _kind[i] = _seq; _kids[i] = [for (final s in c.subClauses) id(s)];
        case peg.First(): _kind[i] = _first; _kids[i] = [for (final s in c.subClauses) id(s)];
        case peg.Repetition(): _kind[i] = _rep; _code[i] = c.requireOne ? 1 : 0; _kids[i] = [id(c.subClause)];
        case peg.Optional(): _kind[i] = _opt; _kids[i] = [id(c.subClause)];
        case peg.Ref(): _kind[i] = _ref; _kids[i] = [id(p.rules[c.ruleName]!)];
        case peg.NotFollowedBy(): _kind[i] = _not; _kids[i] = [id(c.subClause)];
        case peg.FollowedBy(): _kind[i] = _and; _kids[i] = [id(c.subClause)];
        case peg.Char(): _kind[i] = _char; _code[i] = c.char.codeUnitAt(0);
        case peg.Str(): _kind[i] = _str; _text[i] = c.text.codeUnits;
        case peg.CharSet(): _kind[i] = _set; _ranges[i] = c.ranges; _inv[i] = c.inverted;
        case peg.AnyChar(): _kind[i] = _any;
        case peg.Nothing(): _kind[i] = _nothing;
        default: throw ArgumentError('clause $c');
      }
      return i;
    }
    _top = id(p.rules[topRuleName]!);
    for (final r in p.rules.values) { id(r); }
    _rules = {for (final r in p.rules.values) ids[r]!}.toList();
    _ruleIndex = {for (final (i, r) in _rules.indexed) r: i};
    _riOf = [for (var c = 0; c < _kind.length; c++) _ruleIndex[c] ?? -1];
  }

  final Map<String, peg.Clause> rules;
  final String topRuleName;
  final _kind = <int>[], _code = <int>[], _kids = <List<int>>[], _text = <List<int>>[];
  final _ranges = <List<(int, int)>>[], _inv = <bool>[], _clause = <peg.Clause>[];
  late final int _top;
  late final List<int> _rules;
  late final Map<int, int> _ruleIndex;
  int lastCost = 0;
  int recoverCost(String s) => (this..recover(s)).lastCost;


  int evals = 0;
  static const _back = int.fromEnvironment('BACK', defaultValue: 2);

  // ---- the evaluator, over one repaired string ----
  // The repaired string is a list of pieces: a run of input characters, or
  // the one character of an edit. Piece i starts at _pv[i]; _pv ends with _n.
  late List<int> _in;
  List<_Edit> _e = const [];
  final _pv = <int>[], _po = <int>[], _pch = <int>[];
  final _pr = <bool>[];
  int _cur = 0, _n = 0, _ext = 0, _depth = 0, _taint = 0, work = 0;
  // The memo of one parse, in arrays stamped with the parse's number; an
  // entry with an older stamp is empty. Flags: 1 in recursion, 2 found left
  // recursion, 4 fixed.
  var _st = Int32List(0), _mEnd = Int32List(0), _mVer = Int32List(0), _mExt = Int32List(0), _mDep = Int32List(0), _mFl = Int32List(0);
  var _vSt = Int32List(0), _vVal = Int32List(0);
  final _touched = <int>[];
  int _gen = 0, _w = 0;
  late List<int> _riOf;
  // Results of the input with no edit in the window they examined, in input
  // coordinates: valid for every repaired string that leaves that window alone.
  var _bSt = Int32List(0), _bEnd = Int32List(0), _bExt = Int32List(0);
  int _bGen = 0;
  Set<int>? _seen; // characters compared against the unknown character
  final _why = <int>{}; // the literals, and offsets in them, that compared it

  bool _inSet(int i, int ch) => _inv[i] != _ranges[i].any((r) => ch >= r.$1 && ch <= r.$2);

  int _rep0(int i) {
    if (!_inv[i]) return _ranges[i].first.$1;
    for (final ch in 'x0Q'.codeUnits) { if (_inSet(i, ch)) return ch; }
    return 'x'.codeUnitAt(0);
  }

  int _piece(int pos) {
    var i = _cur;
    if (pos >= _pv[i] && pos < _pv[i + 1]) return i;
    var lo = 0, hi = _pv.length - 2;
    while (lo < hi) {
      final m = (lo + hi + 1) >> 1;
      if (_pv[m] <= pos) { lo = m; } else { hi = m - 1; }
    }
    return _cur = lo;
  }

  int _charAt(int pos) {
    final i = _piece(pos);
    return _pr[i] ? _in[_po[i] + pos - _pv[i]] : _pch[i];
  }

  // The input position of repaired position `pos`, or -1 if `pos` holds an
  // edit's character.
  int _origAt(int pos) {
    if (pos >= _n) return _in.length;
    final i = _piece(pos);
    return _pr[i] ? _po[i] + pos - _pv[i] : -1;
  }

  int _origOf(int pos) {
    if (pos >= _n) return _in.length;
    final i = _piece(pos);
    return _pr[i] ? _po[i] + pos - _pv[i] : _po[i];
  }

  bool _clear(int o, int len) {
    for (final e in _e) { if (e.at > o && e.at < o + len) return false; }
    return true;
  }

  // Whether the character at `pos` is the literal `ch`.
  bool _is(int pos, int ch) {
    if (pos >= _n) return false;
    final c = _charAt(pos);
    if (c == _sym) { _seen!.add(ch); return false; }
    return c == ch;
  }

  int _match(int c, int pos) {
    switch (_kind[c]) {
      case _seq:
        var p = pos;
        for (final k in _kids[c]) { p = _match(k, p); if (p < 0) return -1; }
        return p;
      case _first:
        for (final k in _kids[c]) { final r = _match(k, pos); if (r >= 0) return r; }
        return -1;
      case _rep:
        var p = pos, count = 0;
        while (true) {
          final r = _match(_kids[c][0], p);
          if (r < 0 || r == p) break;
          p = r; count++;
        }
        return _code[c] == 1 && count == 0 ? -1 : p;
      case _opt:
        final r = _match(_kids[c][0], pos);
        return r < 0 ? pos : r;
      case _ref:
        return _rule(_kids[c][0], pos);
      case _not:
        return _match(_kids[c][0], pos) < 0 ? pos : -1;
      case _and:
        return _match(_kids[c][0], pos) < 0 ? -1 : pos;
      case _char:
        if (pos + 1 > _ext) _ext = pos + 1;
        if (_seen != null && pos < _n && _charAt(pos) == _sym) _why.add(c * 64);
        return _is(pos, _code[c]) ? pos + 1 : -1;
      case _str:
        final t = _text[c];
        var j = 0;
        while (j < t.length && _is(pos + j, t[j])) { j++; }
        if (_seen != null && j < t.length && pos + j < _n && _charAt(pos + j) == _sym) _why.add(c * 64 + j);
        if (pos + j + (j < t.length ? 1 : 0) > _ext) _ext = pos + j + (j < t.length ? 1 : 0);
        return j == t.length ? pos + j : -1;
      case _set:
      case _any:
        if (pos + 1 > _ext) _ext = pos + 1;
        if (pos >= _n) return -1;
        var ch = _charAt(pos);
        if (ch == _sym) { _seen!.add(_kind[c] == _any ? -'x'.codeUnitAt(0) : -_rep0(c)); return -1; }
        if (_kind[c] == _any) return pos + 1;
        if (ch < 0) ch = -ch;
        return _inSet(c, ch) ? pos + 1 : -1;
      default:
        return pos;
    }
  }

  // The library's memo entry, with the extent each result examined. A result
  // read from the base table is fixed: left-recursion growth cannot change it.
  int _rule(int c, int pos) {
    final ri = _riOf[c], k = ri * _w + pos;
    if (_st[k] != _gen) {
      _st[k] = _gen; _mEnd[k] = -2; _mVer[k] = 0; _mExt[k] = 0; _mDep[k] = 0; _mFl[k] = 0;
      _touched.add(k);
    }
    final ver = _vSt[pos] == _gen ? _vVal[pos] : 0;
    if (_mEnd[k] != -2 && (_mFl[k] & 5 != 0 || _mVer[k] == ver)) {
      if (_mFl[k] & 1 != 0 && _mDep[k] < _taint) _taint = _mDep[k];
      if (_mExt[k] > _ext) _ext = _mExt[k];
      return _mEnd[k];
    } else if (_mFl[k] & 1 != 0) {
      _mFl[k] |= 2; _mEnd[k] = -1;
      if (_mDep[k] < _taint) _taint = _mDep[k];
      return -1;
    }
    final o = _origAt(pos), bk = ri * (_in.length + 2) + o;
    if (o >= 0 && _mEnd[k] == -2 && _bSt[bk] == _bGen && _clear(o, _bExt[bk] - o)) {
      final b = _bEnd[bk];
      _mEnd[k] = b < 0 ? -1 : pos + b - o; _mExt[k] = pos + _bExt[bk] - o; _mFl[k] |= 4;
      if (_mExt[k] > _ext) _ext = _mExt[k];
      return _mEnd[k];
    }
    work++;
    _mFl[k] |= 1; _mDep[k] = ++_depth;
    final saved = _ext, savedTaint = _taint;
    _taint = 1 << 30;
    do {
      _ext = pos;
      final r = _match(c, pos);
      if (_ext > _mExt[k]) _mExt[k] = _ext;
      final e = _mEnd[k];
      if (e != -2 && (r < 0 || e >= 0 && r <= e)) break;
      _mEnd[k] = r;
      if (_mFl[k] & 2 == 0) break;
      final v = (_vSt[pos] == _gen ? _vVal[pos] : 0) + 1;
      _vSt[pos] = _gen; _vVal[pos] = v; _mVer[k] = v;
    } while (true);
    _depth--;
    _mFl[k] &= ~1; _mVer[k] = _vSt[pos] == _gen ? _vVal[pos] : 0;
    if (o >= 0 && _taint >= _mDep[k] && _clear(o, _mExt[k] - pos)) {
      _bSt[bk] = _bGen; _bEnd[bk] = _mEnd[k] < 0 ? -1 : o + _mEnd[k] - pos; _bExt[bk] = o + _mExt[k] - pos;
    }
    _taint = savedTaint < _taint ? savedTaint : _taint;
    _ext = saved > _mExt[k] ? saved : _mExt[k];
    return _mEnd[k];
  }

  // Lays out the repaired string of `edits`, with the unknown character
  // inserted before or substituted at input position `symAt` if given.
  void _layout(List<_Edit> edits, String input, [int symOp = -1, int symAt = -1]) {
    final es = symOp < 0 ? edits : [...edits, _Edit(symOp, symAt, _sym)];
    _e = es;
    _pv.clear(); _po.clear(); _pch.clear(); _pr.clear();
    var v = 0, o = 0;
    void run(int to) {
      if (to > o) { _pv.add(v); _po.add(o); _pch.add(0); _pr.add(true); v += to - o; o = to; }
    }
    for (final e in es) {
      run(e.at);
      if (e.op != _del) { _pv.add(v); _po.add(e.at); _pch.add(e.ch); _pr.add(false); v++; }
      if (e.op != _ins) o = e.at + 1;
    }
    run(_in.length);
    _pv.add(v); _po.add(_in.length); _pch.add(0); _pr.add(true);
    _pv.add(v + 1);
    _n = v; _cur = 0;
  }

  // Parses the laid-out string; returns the end of the top rule.
  int _parse() {
    evals++;
    _ext = 0; _depth = 0; _taint = 1 << 30;
    _w = _n + 2;
    final size = _rules.length * _w;
    if (_st.length < size) {
      final cap = size * 2;
      _st = Int32List(cap); _mEnd = Int32List(cap); _mVer = Int32List(cap); _mExt = Int32List(cap); _mDep = Int32List(cap); _mFl = Int32List(cap);
    }
    if (_vSt.length < _w) { _vSt = Int32List(_w * 2); _vVal = Int32List(_w * 2); }
    _gen++; _touched.clear();
    return _rule(_top, 0);
  }

  void _evaluate(_Node node, String input) {
    _layout(node.edits, input);
    node.end = _parse();
    node.n = _n;
    var far = _ext - 1;
    if (node.end >= 0 && node.end < _n && node.end > far) far = node.end;
    node.far = far > _n ? _n : far;
    node.farIn = _origOf(node.far);
    // the rule results that read the end of the string
    final t = _n - node.edits.where((e) => e.at == input.length).length;
    if (node.far >= t) {
      final keys = <int>[
        for (final k in _touched)
          if (k % _w < t && _mExt[k] > t) (k ~/ _w) * 4 * (t + 1) + (k % _w) * 4 + (_mEnd[k] < 0 ? 1 : _mEnd[k] < t ? 2 : 3)
      ]..sort();
      node.sig = Object.hashAll(keys);
    }
    // the first place the next edit may go
    if (node.edits.isEmpty) { node.lastV = 0; return; }
    final last = node.edits.last;
    var ins = 0, del = 0;
    for (final e in node.edits) { if (e.op == _ins) ins++; else if (e.op == _del) del++; }
    node.lastV = last.at + ins - del + (last.op == _ins ? 0 : last.op == _del ? 1 : 1);
  }

  // The characters the parse of the string with an unknown character at
  // `at` compares against it: no other character can change the parse.
  Set<int> _alphabet(List<_Edit> edits, String input, int op, int at) {
    _layout(edits, input, op, at);
    _seen = <int>{};
    _why.clear();
    _parse();
    final s = _seen!;
    _seen = null;
    return s;
  }

  // The start of the `_back`-th nearest rule call, before the failure, that
  // examined it: a repair further back is not tried.
  int _left(_Node node) {
    final far = node.farIn, starts = <int>{};
    for (final k in _touched) {
      final o = _origOf(k % _w);
      if (_mEnd[k] < 0 && _mExt[k] >= node.far && k % _w < node.far && o >= 0) starts.add(o);
    }
    for (var o = far - 1; o >= 0 && starts.where((s) => s > o).length < _back; o--) {
      for (var ri = 0; ri < _rules.length; ri++) {
        final bk = ri * (_in.length + 2) + o;
        if (_bSt[bk] == _bGen && _bEnd[bk] < 0 && _bExt[bk] >= far) { starts.add(o); break; }
      }
    }
    final s = starts.toList()..sort((a, b) => b - a);
    return s.length < _back ? 0 : s[_back - 1];
  }

  // Children: one more edit, after the last one and no later than the last
  // position the failed parse examined.
  final _eofSeen = <int>{};
  List<_Node> _children(_Node node, String input) {
    final out = <_Node>[];
    final last = node.edits.isEmpty ? null : node.edits.last;
    final todo = <(int, bool)>[];
    // the rule calls that examined the failure, nearest start first
    final left = _left(node);
    _layout(node.edits, input);
    for (var q = node.lastV; q <= node.far; q++) {
      if (_origOf(q) < left) continue; todo.add((_origOf(q), q < _n && _origAt(q) >= 0)); }
    for (final (o, real) in todo) {
      if (last == null || o > last.at || o == last.at && last.op == _ins) {
        final a = _alphabet(node.edits, input, _ins, o);
        final ah = Object.hash(Object.hashAllUnordered(a), Object.hashAllUnordered(_why));
        // Characters appended at the end that return the parse to a state it
        // was in before, in what it expects there and in every result before
        // it, brought no completion nearer.
        if (o == input.length && !_eofSeen.add(Object.hash(Object.hashAll([for (final e in node.edits) if (e.at < o) Object.hash(e.op, e.at, e.ch)]), node.sig, ah))) continue;
        for (final ch in a) {
          out.add(_Node([...node.edits, _Edit(_ins, o, ch)], node.farIn, node.sig, ah));
        }
      }
      if (real && (last == null || o > last.at)) {
        out.add(_Node([...node.edits, _Edit(_del, o, 0)], node.farIn, node.sig));
        for (final ch in _alphabet(node.edits, input, _sub, o)) {
          if (ch != input.codeUnitAt(o)) out.add(_Node([...node.edits, _Edit(_sub, o, ch)], node.farIn, node.sig));
        }
      }
    }
    return out;
  }

  int _evidence(peg.MatchResult m) {
    final c = m.clause;
    if (c is peg.Repetition && !c.requireOne && c.subClause is peg.CharSet) return 0;
    if (m.subClauseMatches.isEmpty) {
      return c is peg.Char || c is peg.Str || c is peg.CharSet && !c.inverted ? m.len : 0;
    }
    return m.subClauseMatches.fold(0, (a, k) => a + _evidence(k));
  }

  // The library's tree of the repaired string, mapped back onto the input.
  peg.MatchResult _tree(_Node node, String input) {
    _layout(node.edits, input);
    final orig = [for (var q = 0; q <= _n; q++) _origOf(q)];
    final real = [for (var q = 0; q < _n; q++) _origAt(q) >= 0];
    final s = String.fromCharCodes([for (var q = 0; q < _n; q++) _charAt(q) < 0 ? -_charAt(q) : _charAt(q)]);
    final root = peg.Parser(rules: rules, topRuleName: topRuleName, input: s).parse().root;
    final pre = List<int>.filled(_n + 1, 0);
    for (var q = 0; q < _n; q++) { pre[q + 1] = pre[q] + (real[q] ? 1 : 0); }
    // How much real input the constructs holding an edit's character span.
    node.encl = 0;
    void encl(peg.MatchResult m) {
      for (final k in m.subClauseMatches) {
        if (k.subClauseMatches.isEmpty) {
          if (pre[k.pos + k.len] - pre[k.pos] < k.len) node.encl += pre[m.pos + m.len] - pre[m.pos];
        } else { encl(k); }
      }
    }
    encl(root);
    var next = 0;
    List<peg.MatchResult> gap(int o) {
      if (o <= next) return const [];
      final g = peg.SyntaxError(pos: next, len: o - next);
      next = o;
      return [g];
    }
    bool isSub(int o) => node.edits.any((e) => e.at == o && e.op == _sub);
    // One character of a leaf: read, inserted (a gap the clause fills), or
    // substituted (an error in the clause's place).
    peg.MatchResult letter(peg.Clause l, int q) {
      final o = orig[q];
      if (real[q]) { next = o + 1; return peg.Match(l, o, 1); }
      if (isSub(o)) { next = o + 1; return peg.SyntaxError(pos: o, len: 1); }
      return peg.Match(l, o, 0, subClauseMatches: [peg.SyntaxError(pos: o, len: 0)]);
    }
    // The nodes standing for `m` over the input: input deleted before it, then
    // `m` itself.
    List<peg.MatchResult> walk(peg.MatchResult m) {
      // An empty node stands where the walk is, before any input deleted
      // after it.
      if (m.len == 0) return [peg.Match(m.clause, min(orig[m.pos], next), 0, subClauseMatches: [for (final k in m.subClauseMatches) ...walk(k)])];
      final out = [...gap(orig[m.pos])];
      final c = m.clause;
      if (m.subClauseMatches.isEmpty) {
        final clean = [for (var q = m.pos; q < m.pos + m.len; q++) q].every((q) => real[q] && orig[q] == orig[m.pos] + q - m.pos);
        if (clean) { next = orig[m.pos] + m.len; return [...out, peg.Match(c, orig[m.pos], m.len)]; }
        if (m.len == 1) return [...out, letter(c!, m.pos)];
        // A literal of several letters with an edit in it is spelled letter
        // by letter, so each edit stands in the place of one letter.
        final t = (c as peg.Str).text;
        final kids = <peg.MatchResult>[];
        for (var q = m.pos; q < m.pos + m.len; q++) { kids.addAll(gap(orig[q])); kids.add(letter(peg.Char(t[q - m.pos]), q)); }
        return [...out, peg.Match(c, orig[m.pos], next - orig[m.pos], subClauseMatches: kids)];
      }
      // A node that starts past the end of the input completes it: it covers
      // nothing a reader wrote, so it carries no rule's name.
      final o = orig[m.pos], kids = [for (final k in m.subClauseMatches) ...walk(k)];
      return [...out, peg.Match(o >= input.length ? null : c, o, next - o, subClauseMatches: kids)];
    }
    final ts = [...walk(root), ...gap(input.length)];
    return ts.length == 1 ? ts.single : peg.Match(null, 0, 0, subClauseMatches: ts);
  }

  // Among repairs of equal cost: more matched literal text, then edits as
  // late as possible, then insert before substitute before delete.
  // A node is grown only if its last edit moved the parse on: it reads
  // further into the input, it is read where the parent's parse failed, or
  // it appends at the end of the input.
  bool _progress(_Node x, String input) {
    final last = x.edits.last;
    return x.farIn > x.parentFar || last.at == input.length || last.op == _ins && last.at == x.parentFar;
  }

  int _cmp(_Node a, int ea, _Node b, int eb) {
    if (ea != eb) return eb - ea;
    if (a.encl != b.encl) return b.encl - a.encl;
    for (var i = 1; i <= a.edits.length && i <= b.edits.length; i++) {
      final x = a.edits[a.edits.length - i], y = b.edits[b.edits.length - i];
      if (x.at != y.at) return y.at - x.at;
    }
    const order = [2, 0, 1]; // _del, _ins, _sub
    return order[a.edits.last.op] - order[b.edits.last.op];
  }

  peg.MatchResult recover(String input) {
    evals = 0; work = 0; _eofSeen.clear();
    _in = input.codeUnits;
    final bs = _rules.length * (_in.length + 2);
    if (_bSt.length < bs) { _bSt = Int32List(bs * 2); _bEnd = Int32List(bs * 2); _bExt = Int32List(bs * 2); }
    _bGen++;
    final root = _Node(const []);
    _evaluate(root, input);
    if (root.end == input.length) { lastCost = 0; return _tree(root, input); }
    // Characters appended at the end of the input are one repair however
    // many there are: inserting there costs only the first time.
    bool atEof(_Edit e) => e.op == _ins && e.at == input.length;
    int costOf(_Node x) => x.edits.where((e) => !atEof(e)).length + (x.edits.any(atEof) ? 1 : 0);
    int eofChars(_Node x) => x.edits.where(atEof).length;
    // One cost level holds sub-buckets by the number of characters appended
    // at the end: the level stops at the first count above zero that succeeds.
    // No repair at a level can read more input with literals than the input
    // it keeps: once one finishes, a node that cannot beat it is not grown.
    int bound(_Node x) => input.length - x.edits.where((e) => e.op != _ins).length;
    // Searches level by level up to maxCost from the seeds, each grown at
    // its own cost. With held set, a node the progress rule refuses is kept
    // there instead of grown.
    final fronts = <int, int>{};
    _Node? search(List<_Node> seeds, int maxCost, List<_Node>? held) {
      _eofSeen.clear();
      var level = <int, List<_Node>>{}, waiting = <_Node>[];
      void expand(_Node node, int cost) {
        for (final child in _children(node, input)) {
          if (costOf(child) == cost) { (level[eofChars(child)] ??= []).add(child); } else { waiting.add(child); }
        }
      }
      for (var cost = seeds.map(costOf).fold(maxCost, min); cost <= maxCost; cost++) {
        level = {};
        final lower = fronts.entries.where((f) => f.key < cost).fold(0, (a, f) => max(a, f.value));
        for (final x in waiting.where((x) => costOf(x) == cost)) { (level[eofChars(x)] ??= []).add(x); }
        waiting = waiting.where((x) => costOf(x) > cost).toList();
        for (final x in seeds.where((x) => costOf(x) == cost && x.farIn >= lower)) { _evaluate(x, input); expand(x, cost); }
        if (level.isEmpty && waiting.isEmpty && seeds.every((x) => costOf(x) <= cost)) return null;
        final done = <_Node>[];
        var bestEv = -1;
        for (var e = 0; level.keys.any((k) => k >= e); e++) {
          var ok = false;
          final b = level[e] ?? const <_Node>[];
          for (final x in b) {
            _evaluate(x, input);
            if (x.end == x.n) {
              x.tree = _tree(x, input); x.ev = _evidence(x.tree!);
              done.add(x); ok = true; bestEv = max(bestEv, x.ev);
            } else {
              fronts[cost] = max(fronts[cost] ?? 0, x.farIn);
            }
          }
          for (var i = 0; i < b.length; i++) {
            final x = b[i];
            if (x.end == x.n) {
            } else if ((cost < maxCost || eofChars(x) > 0) && bound(x) > bestEv && x.far >= x.lastV && x.farIn >= lower && evals < 400000) {
              _evaluate(x, input);
              if (held == null || _progress(x, input)) { expand(x, cost); } else { held.add(x); }
            }
          }
          if (ok && e > 0) break;
        }
        if (done.isNotEmpty) return done.reduce((a, b) => _cmp(b, b.ev, a, a.ev) < 0 ? b : a);
      }
      return null;
    }
    final held = <_Node>[];
    var best = search([root], input.length + 1, held);
    final cap = best == null ? input.length + 1 : costOf(best) - 1;
    best = search(held.where((x) => costOf(x) < cap || costOf(x) == cap && eofChars(x) > 0).toList(), cap, null) ?? best;
    if (best != null) { lastCost = best.edits.length; return best.tree!; }
    lastCost = input.isEmpty ? 1 : input.length;
    return peg.SyntaxError(pos: 0, len: input.length);
  }
}
