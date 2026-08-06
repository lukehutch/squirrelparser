// m78 -- I34: an obligation you cannot write down constrains nothing.
//
// m76 built exact regular PEG obligations and threw on the two shapes that are
// not regular: a rule reference reached while left-expanding, and zero-width
// repetition.  Left recursion is not exotic -- every ordinary expression grammar
// has it -- so m76 answered no damaged input under one, losing 18 of the
// table's 113 ground-truth cases to an exception.  The throw was also the wrong
// response on its own terms: refusing to answer is itself a claim, and a
// stronger one than the evidence supports.
//
// `_settle` is the only place a residual meets its polarity, and the vacuous
// residual is polarity-dependent: `fail` discharges a negative obligation but
// kills a positive one, and an eps-accepting residual does the reverse.  So the
// inexpressible case cannot be spelled with any existing constant.  It gets its
// own element, `_opaque`, which absorbs through every constructor and is
// discharged -- imposing nothing -- exactly where the polarity is known.  The
// engine may not enforce a requirement it cannot check, in either direction.
//
// Measured against m76: the 18 exceptions become 15 correct answers and 1 wrong
// one, and 0 of 6461 strings on the 23-grammar gate change their answer.
//
// Inherited from m76: exact regular PEG obligations; one parser and one memo.
//
// A committed choice, a possessive stop, or a lookahead creates a predicate
// over the repaired suffix.  The predicate is normalized to a regular PEG and
// carried as a canonical parsing-expression derivative.  A memo key therefore
// contains the product-DFA state of every live success/failure obligation, not
// m75's one-character FIRST approximation.  Terminals partition their output
// class by DFA transition; EOF is a real transition too.
//
// The cheap pass omits guards, then chases its own back-pointers while replaying
// every PEG action through the exact DFA product.  A successful replay is a
// membership proof.  On damage, the same memo entries are invalidated in place
// and refilled with DFA-keyed facts.  No repaired string is built and no second
// Parser is started.  `_Oracle` below is this engine's sole packrat parser and
// reads only the original input.
//
// Trees retain m75's input-coordinate contract: unused input is a wide
// SyntaxError; unfilled grammar is a zero-width SyntaxError; invented symbols
// never become AST nodes.  There are no tuning parameters.
//
// Known limit, measured: an obligation is discharged only when the window its
// lookahead reads is free of edits.  `"xab"` (edit before the window) is priced
// correctly; `"axb"` (edit inside it) is not.  The chase then ends with
// `_edits.length == cost` but `_atEnd(proof)` false and the answer fails closed
// to -1.  This costs 12 of 6461 on the 23-grammar gate and 3 of 113 in the
// table -- m43's rule (the oracle is authoritative as far as the edit-free
// window reaches) reappearing in the obligation replay rather than the oracle.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart' hide Parser;
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;


// The parser consumes UTF-16 code units.  Millibits are the unit requested by
// the experiment, not a weight: all comparisons remain lexicographic.
const _alphabetBits = 16;
const _alphabetSize = 1 << _alphabetBits;
const _milli = 1000;
const _widestClass = _alphabetBits * _milli;

// Equal edit counts use (invention, description) lexicographically.  A
// fabricated character from grammar class C adds log2|C| invention bits.  An
// input character used by C adds log2|C| description bits; an unused one adds
// log2|Sigma|.  A final zero-bit canonical tie prefers fewer fabricated
// symbols; it only decides exact ties in both specified measures.

int _widthSize(int size) =>
    size <= 1 ? 0 : (math.log(size) / math.ln2 * _milli).round();

enum _Gk { fail, term, eps, not, seq, choice, star, ref }

class _G {
  _G(this.k, {this.a = -1, this.b = -1, this.ranges = const []});
  _Gk k;
  int a, b;
  List<(int, int)> ranges;
}

enum _Pk { fail, term, accept, not, seq, choice, opaque }

class _P {
  _P(this.k,
      {this.a = -1,
      this.b = -1,
      this.mark = -1,
      this.beta = -1,
      this.followers = const {}});
  final _Pk k;
  final int a, b, mark, beta;
  final Map<int, int> followers;
}

class _OMemo {
  MatchResult? result;
  bool active = false, cycle = false;
  int version = 0;
}

/// The engine's own packrat oracle.  It reads only the original input and its
/// memo table is retained for the whole recovery pass.
class _Oracle {
  _Oracle(this.rules, this.top, this.input)
      : version = List.filled(input.length + 1, 0);
  final Map<String, Clause> rules;
  final String top, input;
  final List<int> version;
  final Map<(Clause, int), _OMemo> memo = {};
  final Map<(Clause, int), MatchResult> reads = {};

  MatchResult _memo(Clause c, int pos) {
    if (pos > input.length) return mismatch;
    final e = memo.putIfAbsent((c, pos), _OMemo.new);
    if (e.result != null && (e.active || e.version == version[pos])) {
      return e.result!;
    }
    if (e.active) {
      e.cycle = true;
      return e.result = mismatch;
    }
    e.active = true;
    do {
      final n = _raw(c, pos);
      if (e.result != null && n.len <= e.result!.len) break;
      e.result = n;
      if (!e.cycle) break;
      e.version = ++version[pos];
    } while (true);
    e.active = false;
    e.version = version[pos];
    return e.result!;
  }

  MatchResult read(Clause c, int pos) =>
      reads[(c, pos)] ??= _raw(c, pos);

  MatchResult _raw(Clause c, int pos) {
    if (pos > input.length) return mismatch;
    if (c is Str) {
      if (pos + c.text.length > input.length) return mismatch;
      for (var i = 0; i < c.text.length; i++) {
        if (input.codeUnitAt(pos + i) != c.text.codeUnitAt(i)) return mismatch;
      }
      return Match(c, pos, c.text.length);
    }
    if (c is Char) {
      return pos < input.length && input.codeUnitAt(pos) == c.char.codeUnitAt(0)
          ? Match(c, pos, 1)
          : mismatch;
    }
    if (c is CharSet) {
      if (pos >= input.length) return mismatch;
      final x = input.codeUnitAt(pos);
      final inside = c.ranges.any((r) => x >= r.$1 && x <= r.$2);
      return inside != c.inverted ? Match(c, pos, 1) : mismatch;
    }
    if (c is AnyChar) {
      return pos < input.length ? Match(c, pos, 1) : mismatch;
    }
    if (c is Nothing) return Match(c, pos, 0);
    if (c is Ref) {
      final r = rules[c.ruleName];
      if (r == null) throw ArgumentError('Rule "${c.ruleName}" not found');
      final m = _memo(r, pos);
      return m.isMismatch ? mismatch : Match(c, 0, 0, subClauseMatches: [m]);
    }
    if (c is Seq) {
      final kids = <MatchResult>[];
      var at = pos;
      for (final q in c.subClauses) {
        final m = _raw(q, at);
        if (m.isMismatch) return mismatch;
        kids.add(m);
        at += m.len;
      }
      return kids.isEmpty
          ? Match(c, pos, 0)
          : Match(c, 0, 0, subClauseMatches: kids);
    }
    if (c is First) {
      for (final q in c.subClauses) {
        final m = _raw(q, pos);
        if (!m.isMismatch) return Match(c, 0, 0, subClauseMatches: [m]);
      }
      return mismatch;
    }
    if (c is Optional) {
      final m = _raw(c.subClause, pos);
      return m.isMismatch
          ? Match(c, pos, 0)
          : Match(c, 0, 0, subClauseMatches: [m]);
    }
    if (c is Repetition) {
      final kids = <MatchResult>[];
      var at = pos;
      while (at <= input.length) {
        final m = _raw(c.subClause, at);
        if (m.isMismatch || m.len == 0) break;
        kids.add(m);
        at += m.len;
      }
      if (c.requireOne && kids.isEmpty) return mismatch;
      return kids.isEmpty
          ? Match(c, pos, 0)
          : Match(c, 0, 0, subClauseMatches: kids);
    }
    if (c is NotFollowedBy) {
      return _raw(c.subClause, pos).isMismatch ? Match(c, pos, 0) : mismatch;
    }
    if (c is FollowedBy) {
      return _raw(c.subClause, pos).isMismatch ? mismatch : Match(c, pos, 0);
    }
    throw UnsupportedError('oracle clause ${c.runtimeType}');
  }

  MatchResult topMatch() => _memo(rules[top]!, 0);
}

// ---- the normal form: three node kinds, built once per grammar -------------

sealed class _Node {
  _Node(this.id, this.orig);
  final int id;
  final Clause orig;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable, this.demands);
  final bool editable;
  final int demands;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);
  late final List<_Node> alts;

  /// I27. `guards[i]` is what the character at this position owes because
  /// branches `0..i-1` had to fail here for branch `i` to be reached. Filled
  /// on first use, once desugaring has finished writing `alts`.
  List<int>? guards;
}

/// A memo entry holds only durable knowledge: the value, the largest budget
/// it has been settled at, and the left-recursion staleness stamp. Membership
/// in the live chain is an index into the frame stack (-1 when parked out).
class _Entry {
  _Entry(this.node, this.pos, this.c);
  final _Node node;
  final int pos;
  final int c;

  /// Flat quintuples `[key, cost, score, fabricationCount, reason, ...]`.
  /// Null is the left-recursion seed.
  List<int>? value;

  /// A3: the largest budget this entry has been settled at. A bigger request
  /// recomputes (accumulating); a smaller one filters.
  int settledBudget = -1;

  /// `MemoEntry.memoVersion`: stale after a left-recursive widening at this
  /// position bumped the counter.
  int version = 0;

  /// The index of this entry's frame on the live stack, or -1: `inRecPath`
  /// and the parent pointer in one integer.
  int activeDepth = -1;
}

/// The transient half of m60's coroutine: everything about the pass in
/// flight, pooled by depth and reused.
class _Frame {
  late _Entry entry;
  int budget = -1;

  /// The program counter: which child request comes next. For an alternation,
  /// the branch index; for a sequence, 0 is the head and 1+i is the tail under
  /// the head's i-th answer; for a terminal and for the budget-zero walk, 0.
  int pc = 0;

  /// The resolved head entry of a cons, kept from pc 0 so tail requests read
  /// its answers without a lookup.
  _Entry? headEntry;

  /// `foundLeftRec`: a descendant re-entered this frame's entry, so the
  /// completed pass must widen until nothing improves.
  bool foundCycle = false;

  /// Did the current pass improve the value (I9's write-is-the-test)?
  bool improved = false;

  /// How long the head list was when this frame last read it. Ordering costs
  /// one thing appending never could: a split can land BEHIND a parked
  /// cursor, where an appended one was always ahead of it.
  int headLen = -1;
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form (m59's, verbatim) --------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable, int demands) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable, demands);
  }

  late final _Node _eps = _term(const Nothing(), false, _free);

  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true, _free), const Nothing());

  _Node _wrap(_Node reader, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = reader;

  static List<(int, int)> _normalRanges(List<(int, int)> ranges) {
    final out = <(int, int)>[];
    for (final r in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      final lo = math.max(0, r.$1), hi = math.min(_alphabetSize - 1, r.$2);
      if (lo > hi) continue;
      if (out.isNotEmpty && lo <= out.last.$2 + 1) {
        if (hi > out.last.$2) out[out.length - 1] = (out.last.$1, hi);
      } else {
        out.add((lo, hi));
      }
    }
    return out;
  }

  static List<(int, int)> _complement(List<(int, int)> ranges) {
    final out = <(int, int)>[];
    var next = 0;
    for (final (lo, hi) in _normalRanges(ranges)) {
      if (lo > next) out.add((next, lo - 1));
      next = math.max(next, hi + 1);
    }
    if (next < _alphabetSize) out.add((next, _alphabetSize - 1));
    return out;
  }

  // ---- exact regular-PEG residuals -----------------------------------------

  static const int _free = 0, _dead = -1;
  final Map<Clause, int> _gOf = Map.identity();
  final List<_G> _gs = [];
  List<bool>? _lambda, _nu;

  int _newG(_G g) => (_gs..add(g)).length - 1;
  int _grammar(Clause c) {
    final old = _gOf[c];
    if (old != null) return old;
    final id = _newG(_G(_Gk.fail));
    _gOf[c] = id;
    _G g;
    if (c is Nothing || c is Str && c.text.isEmpty) {
      g = _G(_Gk.eps);
    } else if (c is Char) {
      final x = c.char.codeUnitAt(0);
      g = _G(_Gk.term, ranges: [(x, x)]);
    } else if (c is Str) {
      var tail = _newG(_G(_Gk.eps));
      for (var i = c.text.length - 1; i >= 0; i--) {
        final x = c.text.codeUnitAt(i);
        final t = _newG(_G(_Gk.term, ranges: [(x, x)]));
        tail = _newG(_G(_Gk.seq, a: t, b: tail));
      }
      g = _G(_Gk.ref, a: tail);
    } else if (c is CharSet) {
      g = _G(_Gk.term,
          ranges: c.inverted ? _complement(c.ranges) : _normalRanges(c.ranges));
    } else if (c is AnyChar) {
      g = _G(_Gk.term, ranges: [(0, _alphabetSize - 1)]);
    } else if (c is Ref) {
      final body = _rules[c.ruleName];
      if (body == null) throw ArgumentError('Rule "${c.ruleName}" not found');
      g = _G(_Gk.ref, a: _grammar(body));
    } else if (c is Seq) {
      var tail = _newG(_G(_Gk.eps));
      for (var i = c.subClauses.length - 1; i >= 0; i--) {
        tail = _newG(_G(_Gk.seq, a: _grammar(c.subClauses[i]), b: tail));
      }
      g = _G(_Gk.ref, a: tail);
    } else if (c is First) {
      var tail = _newG(_G(_Gk.fail));
      for (var i = c.subClauses.length - 1; i >= 0; i--) {
        tail = _newG(_G(_Gk.choice, a: _grammar(c.subClauses[i]), b: tail));
      }
      g = _G(_Gk.ref, a: tail);
    } else if (c is Optional) {
      g = _G(_Gk.choice,
          a: _grammar(c.subClause), b: _newG(_G(_Gk.eps)));
    } else if (c is Repetition) {
      final body = _grammar(c.subClause);
      final star = c.requireOne ? _newG(_G(_Gk.star, a: body)) : id;
      g = c.requireOne ? _G(_Gk.seq, a: body, b: star) : _G(_Gk.star, a: body);
    } else if (c is NotFollowedBy) {
      g = _G(_Gk.not, a: _grammar(c.subClause));
    } else if (c is FollowedBy) {
      final inner = _newG(_G(_Gk.not, a: _grammar(c.subClause)));
      g = _G(_Gk.not, a: inner);
    } else {
      throw UnsupportedError('obligation clause ${c.runtimeType}');
    }
    return (_gs[id] = g, id).$2;
  }

  void _nullability() {
    if (_lambda != null) return;
    _grammar(_rules[topRuleName]!);
    final la = List.filled(_gs.length, false), nu = List.filled(_gs.length, false);
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < _gs.length; i++) {
        final g = _gs[i];
        final l = switch (g.k) {
          _Gk.eps || _Gk.not || _Gk.star => true,
          _Gk.ref => la[g.a],
          _Gk.seq => la[g.a] && la[g.b],
          _Gk.choice => la[g.a] || la[g.b],
          _ => false,
        };
        final n = switch (g.k) {
          _Gk.eps || _Gk.star => true,
          _Gk.ref => nu[g.a],
          _Gk.seq => nu[g.a] && nu[g.b],
          _Gk.choice => nu[g.a] || nu[g.b],
          _ => false,
        };
        if (l != la[i]) { la[i] = l; changed = true; }
        if (n != nu[i]) { nu[i] = n; changed = true; }
      }
    }
    _lambda = la;
    _nu = nu;
  }

  // `_opaque` is the obligation we cannot write down: not regular, so neither
  // satisfied nor refuted by any string we could test.  It absorbs through every
  // constructor and is discharged, vacuously, where its polarity is known.
  static const int _opaque = 1;
  final List<_P> _ps = [_P(_Pk.fail), _P(_Pk.opaque)];
  final Map<String, int> _pIndex = {'z': 0, 'w': _opaque};
  final Map<int, Set<int>> _matches = {}, _backs = {};
  final Map<int, int> _maxMarks = {};
  final Map<(int, int), int> _derivatives = {};

  int _internP(String key, _P Function() make) =>
      _pIndex[key] ??= (_ps..add(make())).length - 1;
  int _pe(int mark) => _internP('e$mark', () => _P(_Pk.accept, mark: mark));
  int _pt(int g) => _internP('t$g', () => _P(_Pk.term, a: g));
  int _pn(int mark, int a) {
    if (a == 0) return _pe(mark);
    if (_match(a).isNotEmpty) return 0;
    if (a == _opaque) return _opaque;
    return _internP('n$mark:$a', () => _P(_Pk.not, a: a, mark: mark));
  }
  int _po(int a, int b) {
    if (a == 0) return b;
    if (b == 0 || _match(a).isNotEmpty) return a;
    if (a == _opaque || b == _opaque) return _opaque;
    return _internP('o$a:$b', () => _P(_Pk.choice, a: a, b: b));
  }
  int _pseq(int a, int beta, Map<int, int> fs) {
    if (a == 0) return 0;
    if (a == _opaque || fs.values.contains(_opaque)) return _opaque;
    final es = fs.entries.toList()..sort((x, y) => x.key - y.key);
    final key = 's$a:$beta:${es.map((e) => '${e.key}=${e.value}').join(',')}';
    return _internP(key,
        () => _P(_Pk.seq, a: a, beta: beta, followers: Map.unmodifiable(fs)));
  }

  int _norm(int g, int mark, [Set<int>? left]) {
    _nullability();
    final q = _gs[g], path = left ?? <int>{};
    switch (q.k) {
      case _Gk.fail: return 0;
      case _Gk.term: return _pt(g);
      case _Gk.eps: return _pe(mark);
      case _Gk.ref:
        if (!path.add(g)) return _opaque;
        return _norm(q.a, mark, path);
      case _Gk.not: return _pn(mark, _norm(q.a, mark, {...path}));
      case _Gk.choice:
        final a = _norm(q.a, mark, {...path});
        if (_nu![q.a]) return a;
        return _po(a, _norm(q.b, mark, {...path}));
      case _Gk.seq:
        final a = _norm(q.a, mark, path);
        if (_ps[a].k == _Pk.accept) return _norm(q.b, mark);
        final fs = <int, int>{};
        if (_lambda![q.a]) fs[mark] = _norm(q.b, mark);
        return _pseq(a, q.b, fs);
      case _Gk.star:
        if (_lambda![q.a]) return _opaque;
        final a = _norm(q.a, mark, path);
        return _po(_pseq(a, g, const {}), _pe(mark));
    }
  }

  Set<int> _match(int p) => _matches[p] ??= switch (_ps[p]) {
        _P(k: _Pk.accept, :final mark) => {mark},
        _P(k: _Pk.seq, :final a, :final followers) => {
            for (final j in _match(a)) ..._match(followers[j]!)
          },
        _P(k: _Pk.choice, :final b) => {..._match(b)},
        _ => <int>{},
      };
  Set<int> _back(int p) => _backs[p] ??= switch (_ps[p]) {
        _P(k: _Pk.accept || _Pk.not, :final mark) => {mark},
        _P(k: _Pk.seq, :final followers) => {
            for (final q in followers.values) ..._back(q)
          },
        _P(k: _Pk.choice, :final a, :final b) => {..._back(a), ..._back(b)},
        _ => <int>{},
      };
  int _maxMark(int p) => _maxMarks[p] ??= switch (_ps[p]) {
        _P(k: _Pk.accept || _Pk.not, :final mark, :final a) =>
          math.max(mark, a < 0 ? -1 : _maxMark(a)),
        _P(k: _Pk.seq, :final a, :final followers) => followers.values.fold(
            _maxMark(a), (m, q) => math.max(m, _maxMark(q))),
        _P(k: _Pk.choice, :final a, :final b) =>
          math.max(_maxMark(a), _maxMark(b)),
        _ => -1,
      };

  bool _terminalHas(int g, int ch) =>
      _gs[g].ranges.any((r) => ch >= r.$1 && ch <= r.$2);
  int _derive(int p, int ch, int mark, Map<int, int> memo) {
    final known = memo[p];
    if (known != null) return known;
    final x = _ps[p];
    late int out;
    switch (x.k) {
      case _Pk.fail: out = 0;
      case _Pk.opaque: out = _opaque;
      case _Pk.accept: out = p;
      case _Pk.term: out = ch < 0 || !_terminalHas(x.a, ch) ? 0 : _pe(mark);
      case _Pk.not:
        final a = _derive(x.a, ch, mark, memo);
        out = _match(a).isNotEmpty ? 0 : a == 0 ? _pe(x.mark) : _pn(x.mark, a);
      case _Pk.choice:
        final a = _derive(x.a, ch, mark, memo);
        final b = _derive(x.b, ch, mark, memo);
        out = a == 0 ? b : b == 0 || _match(a).isNotEmpty ? a : _po(a, b);
      case _Pk.seq:
        final a = _derive(x.a, ch, mark, memo);
        if (a == 0) {
          out = 0;
        } else if (_ps[a].k == _Pk.accept) {
          final j = _ps[a].mark;
          if (j == mark) {
            final b = _norm(x.beta, mark);
            out = ch < 0 ? _derive(b, ch, mark, memo) : b;
          } else {
            out = _derive(x.followers[j]!, ch, mark, memo);
          }
        } else {
          final fs = <int, int>{};
          for (final j in _back(a)) {
            fs[j] = j == mark
                ? _norm(x.beta, mark)
                : _derive(x.followers[j]!, ch, mark, memo);
          }
          out = _pseq(a, x.beta, fs);
        }
    }
    memo[p] = out;
    return out;
  }

  int _deriveOne(int p, int ch) {
    final key = (p, ch);
    return _derivatives[key] ??= _canonical(
        _derive(p, ch, _maxMark(p) + 1, <int, int>{}));
  }

  int _canonical(int root) {
    final marks = <int>{}, seen = <int>{};
    void collect(int p) {
      if (!seen.add(p)) return;
      final x = _ps[p];
      if (x.k == _Pk.accept || x.k == _Pk.not) marks.add(x.mark);
      if (x.a >= 0 && x.k != _Pk.term) collect(x.a);
      if (x.b >= 0) collect(x.b);
      if (x.k == _Pk.seq) {
        marks.addAll(x.followers.keys);
        x.followers.values.forEach(collect);
      }
    }
    collect(root);
    final ordered = marks.toList()..sort();
    final rename = {for (final x in ordered.indexed) x.$2: x.$1};
    final memo = <int, int>{};
    int rebuild(int p) => memo[p] ??= switch (_ps[p]) {
          _P(k: _Pk.fail || _Pk.term || _Pk.opaque) => p,
          _P(k: _Pk.accept, :final mark) => _pe(rename[mark]!),
          _P(k: _Pk.not, :final mark, :final a) =>
            _pn(rename[mark]!, rebuild(a)),
          _P(k: _Pk.choice, :final a, :final b) => _po(rebuild(a), rebuild(b)),
          _P(k: _Pk.seq, :final a, :final beta, :final followers) => _pseq(
              rebuild(a),
              beta,
              {for (final e in followers.entries) rename[e.key]!: rebuild(e.value)}),
        };
    return rebuild(root);
  }

  final List<List<(int, bool)>> _obligations = [const []];
  final Map<String, int> _obIndex = {'': _free};
  int _internOb(List<(int, bool)> xs) {
    xs.sort((a, b) => a.$1 != b.$1
        ? a.$1 - b.$1
        : (a.$2 == b.$2 ? 0 : a.$2 ? 1 : -1));
    final out = <(int, bool)>[];
    for (final x in xs) {
      if (out.isNotEmpty && out.last.$1 == x.$1) {
        if (out.last.$2 != x.$2) return _dead;
        continue;
      }
      out.add(x);
    }
    final key = out.map((x) => '${x.$1}${x.$2 ? '+' : '-'}').join(',');
    return _obIndex[key] ??= (_obligations..add(List.unmodifiable(out))).length - 1;
  }
  int _settle(int carried, int p, bool yes) {
    if (carried == _dead) return _dead;
    // Not expressible as a regular obligation, so it constrains nothing: the
    // engine may not invent a requirement it cannot check, in either polarity.
    if (p == _opaque) return carried;
    if (_match(p).isNotEmpty) return yes ? carried : _dead;
    if (p == 0) return yes ? _dead : carried;
    return _internOb([..._obligations[carried], (p, yes)]);
  }
  int _meet(int a, int b) => a == _dead || b == _dead
      ? _dead
      : _internOb([..._obligations[a], ..._obligations[b]]);
  int _constraint(Clause c, bool yes, int carried) =>
      _settle(carried, _norm(_grammar(c), 0), yes);
  int _advance(int c, int ch) {
    if (c <= _dead || c == _free) return c;
    var out = _free;
    for (final (p, yes) in _obligations[c]) {
      out = _settle(out, _deriveOne(p, ch), yes);
      if (out == _dead) break;
    }
    return out;
  }
  bool _atEnd(int c) => _advance(c, -1) == _free;
  bool _unmeetable(int c) => c == _dead;

  final Map<Clause, int> _notFirstOf = Map.identity();
  int _notFirst(Clause branch, int carried) =>
      _meet(carried, _notFirstOf[branch] ??= _constraint(branch, false, _free));

  List<int> _guardsOf(_Alt node) {
    final known = node.guards;
    if (known != null) return known;
    final g = <int>[];
    var acc = _free;
    for (final a in node.alts) {
      g.add(acc);
      acc = _notFirst(a.orig, acc);
    }
    return node.guards = g;
  }

  int? _look(Clause c) => switch (c) {
        FollowedBy(:final subClause) => _constraint(subClause, true, _free),
        NotFollowedBy(:final subClause) => _constraint(subClause, false, _free),
        _ => null,
      };

  List<(int, int)>? _rangesOf(Clause c) => switch (c) {
        AnyChar() => [(0, _alphabetSize - 1)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 =>
          [(text.codeUnitAt(0), text.codeUnitAt(0))],
        CharSet(:final ranges, :final inverted) =>
          inverted ? _complement(ranges) : _normalRanges(ranges),
        _ => null,
      };

  List<(int, int)>? _atoms;
  List<(int, int)> get _alphabetAtoms {
    final old = _atoms;
    if (old != null) return old;
    _nullability();
    final cuts = <int>[0, _alphabetSize];
    for (final g in _gs.where((g) => g.k == _Gk.term)) {
      for (final (lo, hi) in g.ranges) {
        cuts..add(lo)..add(hi + 1);
      }
    }
    cuts.sort();
    final unique = <int>[];
    for (final x in cuts) {
      if (unique.isEmpty || unique.last != x) unique.add(x);
    }
    return _atoms = [
      for (var i = 0; i + 1 < unique.length; i++)
        if (unique[i] < unique[i + 1]) (unique[i], unique[i + 1] - 1)
    ];
  }

  List<(int, int, int)> _emissions(int c, List<(int, int)> ranges) {
    if (c == _free) {
      final size = _rangeSize(ranges);
      return size == 0 ? const [] : [(_free, size, ranges.first.$1)];
    }
    final grouped = <int, (int, int)>{};
    for (final atom in _alphabetAtoms) {
      for (final r in ranges) {
        final lo = math.max(atom.$1, r.$1), hi = math.min(atom.$2, r.$2);
        if (lo > hi) continue;
        final next = _advance(c, lo);
        if (next != _dead) {
          final old = grouped[next];
          grouped[next] = ((old?.$1 ?? 0) + hi - lo + 1, old?.$2 ?? lo);
        }
      }
    }
    return [for (final e in grouped.entries) (e.key, e.value.$1, e.value.$2)];
  }

  int? _chosenEmission(int c, List<(int, int)> ranges, int target) {
    for (final x in _emissions(c, ranges)) {
      if (x.$1 == target) return x.$3;
    }
    return null;
  }

  _Node _cons(List<Clause> parts, Clause orig) {
    var node = _eps;
    for (var i = parts.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(parts.sublist(i)))
        ..head = _node(parts[i])
        ..tail = node;
    }
    return node;
  }

  /// The clauses the GRAMMAR contains, by identity. Desugaring invents spine
  /// nodes -- `Seq(sublist)` at each fusion step, `_junk`, `_eps`, the goal
  /// wrapper -- and those are plumbing, not structure. A tree node is opened
  /// exactly when the clause behind it is one the grammar author wrote, which
  /// is precisely the set that reaches `_node`.
  final Set<Clause> _real = Set<Clause>.identity();

  _Node _node(Clause clause) {
    _real.add(clause);
    final known = _nodes[clause];
    if (known != null) return known;
    if (clause is Ref) {
      final node = _Alt(_nodeCount++, clause);
      _nodes[clause] = node;
      node.alts = [_node(_rules[clause.ruleName]!)];
      return node;
    }
    late _Node node;
    if (clause is Seq) {
      node = _cons(clause.subClauses, clause);
    } else if (clause is Str && clause.text.length > 1) {
      node = _cons([for (final c in clause.text.split('')) Str(c)], clause);
    } else if (clause is First) {
      node = _Alt(_nodeCount++, clause)
        ..alts = [for (final s in clause.subClauses) _node(s)];
    } else if (clause is Optional) {
      node = _Alt(_nodeCount++, clause)..alts = [_node(clause.subClause), _eps];
    } else if (clause is Repetition) {
      final loop = _selfLoop(
          _node(clause.subClause),
          clause.requireOne
              ? Repetition(clause.subClause, requireOne: false)
              : clause);
      node = clause.requireOne
          ? (_Cons(_nodeCount++, clause)
            ..head = loop.head
            ..tail = loop)
          : loop;
    } else if (clause is Nothing) {
      node = _eps;
    } else {
      final accepts = _rangesOf(clause);
      final looks = _look(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks ?? _free);
      node = looks == null ? _wrap(leaf, clause) : leaf;
    }
    return _nodes[clause] = node;
  }

  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  // ---- constructive fabrication ceiling for nonrecursive grammars ----------
  // The fixed point carries exact residual products.  Its first complete word
  // is an upper bound, not a tuned search cap; a settled empty row proves the
  // acyclic grammar empty.  Recursive grammars use unbounded deepening, since
  // deciding their emptiness is outside the supported obligation fragment.

  static bool _kb2(List<int> out, int key, int v) {
    for (var i = 0; i < out.length; i += 2) {
      if (out[i] != key) continue;
      if (out[i + 1] <= v) return false;
      out[i + 1] = v;
      return true;
    }
    out
      ..add(key)
      ..add(v);
    return true;
  }

  late final int? _goalFromNothing = () {
    final all = <_Node>{};
    void visit(_Node node) {
      if (!all.add(node)) return;
      if (node is _Cons) {
        visit(node.head);
        visit(node.tail);
      } else if (node is _Alt) {
        node.alts.forEach(visit);
      }
    }

    visit(_goal);
    int? cheapest() {
      final cost = <int, List<List<int>>>{};
      var improved = true;
      List<List<int>> row(int c) => cost.putIfAbsent(c, () {
            improved = true;
            return List.generate(_nodeCount, (_) => <int>[]);
          });
      List<int> chain(_Cons node, int c) {
        final out = <int>[];
        if (identical(node.tail, node)) {
          final stop = identical(node, _junk) ? c : _notFirst(node.head.orig, c);
          if (stop != _dead) _kb2(out, stop, 0);
        }
        final heads = row(c)[node.head.id];
        for (var i = 0; i < heads.length; i += 2) {
          final tails = row(heads[i])[node.tail.id];
          for (var j = 0; j < tails.length; j += 2) {
            _kb2(out, tails[j], heads[i + 1] + tails[j + 1]);
          }
        }
        return out;
      }

      List<int> leaf(_Term node, int c) {
        if (node.demands != _free) {
          final next = _meet(c, node.demands);
          return next == _dead ? const [] : [next, 0];
        }
        final emits = node.editable ? _rangesOf(node.orig) : null;
        if (emits != null && emits.isNotEmpty) {
          final out = <int>[];
          for (final emission in _emissions(c, emits)) {
            _kb2(out, emission.$1, 1);
          }
          return out;
        }
        return node.orig is Nothing ? [c, 0] : const [];
      }

      row(_free);
      while (improved) {
        improved = false;
        for (final c in cost.keys.toList()) {
          for (final node in all) {
            final now = switch (node) {
              _Term() => leaf(node, c),
              _Cons() => chain(node, c),
              _Alt(:final alts) => () {
                  final out = <int>[];
                  final guards = _guardsOf(node);
                  for (var a = 0; a < alts.length; a++) {
                    final start = _meet(c, guards[a]);
                    if (start == _dead) continue;
                    final from = row(start)[alts[a].id];
                    for (var i = 0; i < from.length; i += 2) {
                      _kb2(out, from[i], from[i + 1]);
                    }
                  }
                  return out;
                }(),
            };
            final known = row(c)[node.id];
            for (var i = 0; i < now.length; i += 2) {
              if (_kb2(known, now[i], now[i + 1])) improved = true;
            }
          }
        }
        int? witness;
        final top = row(_free)[_goal.id];
        for (var i = 0; i < top.length; i += 2) {
          if (_atEnd(top[i]) && (witness == null || top[i + 1] < witness)) {
            witness = top[i + 1];
          }
        }
        // This is a ceiling, not an optimization result: the first complete
        // fabricated word is already a constructive upper bound.
        if (witness != null) return witness;
      }
      return null;
    }
    return cheapest();
  }();

  late final bool _recursiveRules = () {
    final done = <String>{};
    bool clause(Clause c, Set<String> path) {
      if (c is Ref) {
        if (path.contains(c.ruleName)) return true;
        if (done.contains(c.ruleName)) return false;
        final body = _rules[c.ruleName];
        if (body == null) throw ArgumentError('Rule "${c.ruleName}" not found');
        if (clause(body, {...path, c.ruleName})) return true;
        done.add(c.ruleName);
        return false;
      }
      if (c is HasOneSubClause) return clause(c.subClause, path);
      if (c is HasMultipleSubClauses) {
        return c.subClauses.any((q) => clause(q, path));
      }
      return false;
    }
    return clause(_rules[topRuleName]!, {topRuleName});
  }();

  // ---- per-input state -----------------------------------------------------

  late _Oracle _parser;
  late String _input;
  late int _inputLen;
  late List<int> _versionAtPos;
  final Map<Clause, int> _widths = Map.identity();
  final Map<int, int> _descriptionCache = {};
  MatchResult? _clean;
  // The goal needs only its key: the cell stores its score and back-pointer.
  int _steps = 0, _goalKey = -1;
  int lastCost = -1, lastRegret = -1, lastFabrications = -1, lastSteps = -1;
  bool lastVerified = false;
  bool _relaxed = false;

  int get lastCells => _cells.length;
  int? get fabricationBound => _recursiveRules ? null : _goalFromNothing;
  int get lastInvention => lastRegret < 0 ? -1 : lastRegret ~/ _descriptionSpan;
  int get lastDescription => lastRegret < 0 ? -1 : lastRegret % _descriptionSpan;
  List<int> emissionSizes(Clause c) =>
      [for (final x in _emissions(_free, _rangesOf(c) ?? const [])) x.$2];
  int get dfaResiduals => _ps.length;
  int get obligationStates => _obligations.length;
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

  int _rangeSize(List<(int, int)> rs) =>
      rs.fold(0, (n, r) => n + r.$2 - r.$1 + 1);
  int _widthOf(Clause clause) => _widths[clause] ??=
      _widthSize(_rangeSize(_rangesOf(clause) ?? const []));

  /// Description is bounded by one whole-alphabet symbol per input code unit.
  int get _descriptionSpan => _inputLen * _widestClass + 1;
  int _score(int invention, int description) =>
      invention * _descriptionSpan + description;

  int _advanceSpan(int c, int pos, int len) {
    if (c == _free || c == _dead || len == 0) return c;
    var out = c;
    for (var i = 0; i < len && out != _dead; i++) {
      out = _advance(out, _input.codeUnitAt(pos + i));
    }
    return out;
  }

  int _description(MatchResult root, int nodeId) {
    final cacheKey = (nodeId << _posShift) | root.pos;
    final known = _descriptionCache[cacheKey];
    if (known != null) return known;
    var bits = 0;
    final todo = <MatchResult>[root];
    while (todo.isNotEmpty) {
      final m = todo.removeLast();
      if (m.subClauseMatches.isNotEmpty) {
        todo.addAll(m.subClauseMatches);
      } else if (m.len > 0) {
        final c = m.clause;
        bits += c == null ? _widestClass * m.len : _widthOf(c) * m.len;
      }
    }
    _descriptionCache[cacheKey] = bits;
    return bits;
  }


  // ---- memo values and back-pointers ---------------------------------------

  /// Every value is written by this funnel, and only on a strict improvement
  /// in `(cost, invention, description, fabricationCount)`. At that instant
  /// the thing that produced the value is a local variable, so keep it: one
  /// more int, and the witness stops having to be searched for. Acyclicity is
  /// then a proof rather than a check -- every edge adds a non-negative
  /// increment, so a cycle in the back-pointers would force every increment to
  /// zero and every value equal, which contradicts the strict drop that the
  /// cell written LAST on that cycle must have made.
  /// I30, and I31 is what forces it here. A new answer goes in at its place in
  /// SPLIT order -- by end, then by obligation -- and not at the back, because
  /// the list is what a `_Cons` offers as head candidates and PEG takes the
  /// reading a recursive-descent parser reaches first: the SHORTEST head, not
  /// the cheapest. m73 could leave the list in arrival order because `_build`
  /// re-sorted the candidates when it reconstructed; the chase has no
  /// reconstruction to sort in, so the order the search wrote IS the answer,
  /// and shape reads 513 instead of 517 if it is wrong. Split order is a TOTAL
  /// order computable from the key alone, so the walk that looks for the key
  /// bisects, and a search that misses has stopped exactly where the new key
  /// belongs -- the ordering pays for its own lookup.
  bool _keepBest(List<int> out, int key, int cost, int reg, int fab, int why) {
    final end = _endOf(key);
    var lo = 0, hi = out.length ~/ 5;
    while (lo < hi) {
      final mid = (lo + hi) >> 1, k = out[mid * 5], e = _endOf(k);
      if (e < end || (e == end && k < key)) {
        lo = mid + 1;
      } else if (k == key) {
        final i = mid * 5;
        if (out[i + 1] < cost ||
            out[i + 1] == cost &&
                (out[i + 2] < reg ||
                    out[i + 2] == reg && out[i + 3] <= fab)) {
          return false;
        }
        out[i + 1] = cost;
        out[i + 2] = reg;
        out[i + 3] = fab;
        out[i + 4] = why;
        return true;
      } else {
        hi = mid;
      }
    }
    out.insertAll(lo * 5, [key, cost, reg, fab, why]);
    return true;
  }

  // I29's alphabet of reasons. A NEGATIVE reason is a leaf shape; a
  // non-negative one is data -- an alternation's winning branch index, or the
  // head key that fixed a sequence's split -- and which of the two it is the
  // node decides, not the number. In order: the oracle's own match settles this
  // cell; a lookahead obligation, no text at all; spend the characters under
  // `key` on this leaf; write this leaf's spelling, reading nothing; the
  // repetition declined to go round again; never written, so the chase has
  // walked off the table.
  static const int _wPure = -1, _wDemand = -2, _wSub = -3;
  static const int _wFab = -4, _wStop = -5, _wNone = -6;

  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Entry> _cells = {};
  int _posShift = 0, _span = 0;

  _Entry _entryAt(_Node node, int pos, int c) {
    final k = (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos;
    return _cells[k] ?? (_cells[k] = _Entry(node, pos, c));
  }

  // ---- I18: the driver -----------------------------------------------------

  /// Is `e` usable at `budget` as it stands? (A3's filter direction, plus the
  /// left-recursion staleness rule, `MemoEntry` verbatim.)
  bool _settled(_Entry e, int budget) =>
      e.activeDepth < 0 &&
      e.value != null &&
      e.settledBudget >= budget &&
      e.version == _versionAtPos[e.pos];

  final List<_Frame> _stack = [];
  int _depth = -1;

  _Frame _push(_Entry e, int budget) {
    final d = ++_depth;
    if (_stack.length <= d) _stack.add(_Frame());
    e.activeDepth = d;
    e.value ??= <int>[];
    return _stack[d]
      ..entry = e
      ..budget = budget
      ..pc = 0
      ..headEntry = null
      ..foundCycle = false
      ..improved = false;
  }

  /// Ask for `e` at `budget`, which is the only thing any of the three child
  /// requests ever does: an entry already on the chain is a left-recursive
  /// cycle, so tell that frame and take whatever it has so far rather than
  /// wait; an unsettled one parks this frame behind it and answers `true`.
  bool _demand(_Entry e, int budget) {
    if (e.activeDepth >= 0) {
      _stack[e.activeDepth].foundCycle = true; // the LR seed
    } else if (!_settled(e, budget)) {
      _push(e, budget);
      return true; // park: the loop steps the new top next
    }
    return false;
  }

  /// Run `e` to settlement at `budget`: one explicit DFS. The chain of parked
  /// parents IS the stack below the top, and the native stack never deepens.
  void _run(_Entry e, int budget) {
    if (budget < 0 || _settled(e, budget)) return;
    _push(e, budget);
    while (_depth >= 0) {
      _step(_stack[_depth]);
    }
  }

  /// Advance the top frame until it parks on a child (pushed; the loop steps
  /// it next) or settles (popped; the parent below is the new top, and its
  /// next step re-derives the awaited child from `pc`, finds it settled,
  /// consumes it, and moves on).
  void _step(_Frame f) {
    _steps++;
    final entry = f.entry;
    final node = entry.node;
    final pos = entry.pos;
    final budget = f.budget;
    final c = entry.c;
    // At budget zero this subtree is an original-input span.  Advance every
    // incoming residual across the whole span; the proof replay later exposes
    // the subtree's internal PEG choices and possessive stops too.
    if (budget == 0) {
      if (f.pc == 0) {
        f.pc = 1;
        final m = _parser.read(node.orig, pos);
        if (!m.isMismatch) {
          var owed = _advanceSpan(c, pos, m.len);
          if (!_relaxed &&
              owed != _dead &&
              node is _Cons &&
              identical(node.tail, node) &&
              !identical(node, _junk)) {
            owed = _notFirst(node.head.orig, owed);
          }
          if (owed != _dead) {
            _put(f, _key(pos + m.len, owed), 0,
                _score(0, _description(m, node.id)), 0, _wPure);
          }
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          final owed = _relaxed ? c : _meet(c, demands);
          if (owed != _dead) _put(f, _key(pos, owed), 0, 0, 0, _wDemand);
          return _finish(f);
        }
        final m = _parser.read(node.orig, pos);
        if (!m.isMismatch) {
          final owed = _advanceSpan(c, pos, m.len);
          if (owed != _dead) {
            _put(f, _key(pos + m.len, owed), 0,
                _score(0, _description(m, node.id)), 0, _wPure);
          }
        }
        if (!editable) return _finish(f);
        final emits = _rangesOf(node.orig);
        final silent = emits == null || emits.isEmpty;
        if (silent) {
          if (pos < _inputLen) {
            _put(f, _key(pos + 1, c), 1, _score(0, _widestClass), 0, _wSub);
          }
        } else {
          for (final emission in _emissions(c, emits)) {
            final owed = emission.$1;
            // The grammar named `node.orig`; a guard narrows legality but does
            // not turn that authored class into a more informative symbol.
            final invention = _widthOf(node.orig);
            if (pos < _inputLen) {
              _put(f, _key(pos + 1, owed), 1,
                  _score(invention, _widestClass), 1, _wSub);
            }
            _put(f, _key(pos, owed), 1, _score(invention, 0), 1, _wFab);
          }
        }
        return _finish(f);
      case _Alt(:final alts):
        final guards = _relaxed ? null : _guardsOf(node);
        while (f.pc < alts.length) {
          final owe = guards == null ? c : _meet(c, guards[f.pc]);
          if (_unmeetable(owe)) {
            f.pc++; // no repaired character reaches this branch
            continue;
          }
          final child = _entryAt(alts[f.pc], pos, owe);
          if (_demand(child, budget)) return;
          _mergeAlt(f, alts.length, child, f.pc);
          f.pc++;
        }
        return _finish(f);
      case _Cons():
        final loops = identical(node.tail, node);
        if (f.pc == 0) {
          if (loops) {
            final owed = _relaxed || identical(node, _junk)
                ? c
                : _notFirst(node.head.orig, c);
            if (!_unmeetable(owed)) {
              _put(f, _key(pos, owed), 0, 0, 0, _wStop);
            }
          }
          final head = _entryAt(node.head, pos, c);
          if (_demand(head, budget)) return;
          f.headEntry = head;
          f.pc = 1;
          f.headLen = -1;
        }
        final heads = f.headEntry!.value ?? const <int>[];
        // The list grew while this frame was parked, so a split may have
        // landed behind the cursor. Re-offering one is free -- `_put` is
        // idempotent -- and growth is bounded by the number of splits.
        if (heads.length != f.headLen) {
          f.headLen = heads.length;
          f.pc = 1;
        }
        while ((f.pc - 1) * 5 < heads.length) {
          final i = (f.pc - 1) * 5;
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final hFab = heads[i + 3];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (_demand(tail, rest)) return;
          final rv = tail.value;
          if (rv != null) {
            for (var j = 0; j < rv.length; j += 5) {
              final total = hCost + rv[j + 1];
              if (total <= budget) {
                _put(f, rv[j], total, hReg + rv[j + 2],
                    hFab + rv[j + 3], headKey);
              }
            }
          }
          f.pc++;
        }
        return _finish(f);
    }
  }

  void _put(_Frame f, int key, int cost, int reg, int fab, int why) {
    if (_keepBest(f.entry.value!, key, cost, reg, fab, why)) f.improved = true;
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(_Frame f, int altCount, _Entry branch, int which) {
    final v = branch.value;
    if (v == null) return;
    final budget = f.budget;
    var committed = -2;
    for (var i = 0; i < v.length; i += 5) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.read(f.entry.node.orig, f.entry.pos);
          committed = oracle.isMismatch ? -1 : f.entry.pos + oracle.len;
        }
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          continue;
        }
      }
      _put(f, key, cost, v[i + 2], v[i + 3], which);
    }
  }

  /// A pass ended. `MemoEntry.match`'s widening loop: if a descendant closed a
  /// cycle here and the pass improved the value, invalidate this position's
  /// memos and run another pass; otherwise settle and pop -- the parent below
  /// is the new top.
  void _finish(_Frame f) {
    final entry = f.entry;
    if (f.foundCycle && f.improved && f.budget > 0) {
      _versionAtPos[entry.pos]++;
      f.pc = 0;
      f.headEntry = null;
      f.improved = false;
      return; // another widening pass of the same frame
    }
    entry.settledBudget = f.budget;
    entry.version = _versionAtPos[entry.pos];
    entry.activeDepth = -1;
    f.headEntry = null;
    _depth--;
  }

  // ---- witness chase, input-coordinate tree, and exact proof replay --------

  /// `(pos, drop, what)`: input unused here, and grammar obligation unfilled.
  final List<(int, int, Clause)> _edits = [];

  int _reasonAt(_Node node, int pos, int c, int key) {
    final v = _entryAt(node, pos, c).value ?? const <int>[];
    for (var i = 0; i < v.length; i += 5) {
      if (v[i] == key) return v[i + 4];
    }
    return _wNone;
  }

  /// Walk the reasons from the goal down to the leaves, left to right, so the
  /// edits come out in ascending input position. Iterative, so the witness
  /// costs no VM stack: the depth
  /// that used to sink `_row` into the input's length now lives in `st`.
  /// Open a tree node for `node`, or pass the sink through. Two clauses are
  /// the same structure when they are the same object, so a self-loop (a
  /// repetition's cons chained to itself) and a wrapped reader (`_wrap` puts
  /// the skip loop and the leaf under one clause) each enter their clause ONCE,
  /// however many times the chase steps through them.
  ///
  /// The span is written now and the children poured in later, which `Match`
  /// permits: it re-derives its span from its children only when they are
  /// already there (match_result.dart:40) and it keeps the list it was handed.
  List<MatchResult> _open(
      List<MatchResult> sink, Clause orig, Clause? owner, int pos, int end) {
    if (identical(orig, owner) || !_real.contains(orig)) return sink;
    final kids = <MatchResult>[];
    sink.add(Match(orig, pos, end - pos, subClauseMatches: kids));
    return kids;
  }

  /// Replay an oracle match as PEG actions.  Unlike a re-parse, this consumes
  /// the existing memoized tree: choices add failure residuals, lookaheads add
  /// success/failure residuals, repetitions add their possessive stop, and
  /// terminals advance the resulting DFA product.
  int _proveMatch(MatchResult m, int state) {
    if (state == _dead) return state;
    final c = m.clause;
    if (c is FollowedBy) return _constraint(c.subClause, true, state);
    if (c is NotFollowedBy) return _constraint(c.subClause, false, state);
    if (c is First) {
      if (m.subClauseMatches.isEmpty) return _dead;
      final child = m.subClauseMatches.first;
      final which = c.subClauses.indexWhere((q) => identical(q, child.clause));
      if (which < 0) return _dead;
      for (var i = 0; i < which; i++) {
        state = _constraint(c.subClauses[i], false, state);
      }
      return _proveMatch(child, state);
    }
    if (c is Optional) {
      return m.subClauseMatches.isEmpty
          ? _constraint(c.subClause, false, state)
          : _proveMatch(m.subClauseMatches.first, state);
    }
    if (c is Repetition) {
      for (final child in m.subClauseMatches) {
        state = _proveMatch(child, state);
        if (state == _dead) return state;
      }
      return _constraint(c.subClause, false, state);
    }
    if (m.subClauseMatches.isNotEmpty) {
      for (final child in m.subClauseMatches) {
        state = _proveMatch(child, state);
        if (state == _dead) return state;
      }
      return state;
    }
    return _advanceSpan(state, m.pos, m.len);
  }

  /// Walk the reasons from the goal down to the leaves, left to right, BUILDING
  /// as it goes. Iterative, so the witness costs no VM stack.
  ///
  /// This is also the whole soundness check, and it is a lookup rather than a
  /// parse: an edit-free step claims the oracle reads that stretch, so ask the
  /// oracle. If the clean match is absent or the wrong length, the witness has
  /// contradicted a fact the parser already established, and the derivation is
  /// rejected -- I5's rule (the witness is a proof, so check it) and m43's
  /// (the oracle is authoritative as far as the edit-free window reaches),
  /// applied without re-parsing anything.
  bool _chase(int cost, List<MatchResult> out) {
    var proof = _free;
    final st = <(_Node, int, int, int, List<MatchResult>, Clause?)>[
      (_goal, 0, _free, _goalKey, out, null)
    ];
    while (st.isNotEmpty) {
      final (node, pos, c, key, sink, owner) = st.removeLast();
      final why = _reasonAt(node, pos, c, key);
      final end = _endOf(key);
      switch (why) {
        case _wNone:
          return false;
        case _wSub:
          // Input the grammar cannot use. It stays exactly where it is, in the
          // tree, at the structural position that failed -- and the clause that
          // wanted something else records that it went unfilled. The character
          // is NOT replaced by the one the grammar wanted: that would put a
          // symbol in the tree that nothing in the document supports.
          sink.add(SyntaxError(pos: pos, len: end - pos));
          _edits.add((pos, end - pos, node.orig));
          final emits = _rangesOf(node.orig);
          if (emits != null && emits.isNotEmpty) {
            final ch = _chosenEmission(c, emits, _oweOf(key));
            if (ch == null) return false;
            proof = _advance(proof, ch);
          }
        case _wFab:
          // Grammar the input cannot fill. The demanded symbol is NOT written
          // into the tree -- nothing in the document supports it, and a wide
          // class could not say which symbol anyway. What is real, and is
          // recorded, is the POSITION at which the descent needed something and
          // found nothing: a zero-width error span, sitting between the
          // characters that do exist.
          sink.add(SyntaxError(pos: pos, len: 0));
          _edits.add((pos, 0, node.orig));
          final emits = _rangesOf(node.orig);
          if (emits != null && emits.isNotEmpty) {
            final ch = _chosenEmission(c, emits, _oweOf(key));
            if (ch == null) return false;
            proof = _advance(proof, ch);
          }
        case _wPure:
          final m = _parser.read(node.orig, pos);
          if (m.isMismatch || m.len != end - pos) return false;
          proof = _proveMatch(m, proof);
          if (end > pos) sink.add(m);
        case _wDemand:
          final demand = _look(node.orig);
          if (demand == null) return false;
          proof = _meet(proof, demand);
        case _wStop:
          if (node is _Cons && !identical(node, _junk)) {
            proof = _notFirst(node.head.orig, proof);
          }
        default:
          final into = _open(sink, node.orig, owner, pos, end);
          final own = identical(into, sink) ? owner : node.orig;
          switch (node) {
            case _Alt(:final alts):
              final guards = _guardsOf(node);
              proof = _meet(proof, guards[why]);
              st.add((
                alts[why],
                pos,
                _relaxed ? c : _meet(c, guards[why]),
                key,
                into,
                own
              ));
            case _Cons():
              // Tail first so the head pops first: left to right.
              st.add((node.tail, _endOf(why), _oweOf(why), key, into, own));
              st.add((node.head, pos, c, why, into, own));
            case _Term():
              return false; // a leaf never writes a structural reason
          }
      }
      if (proof == _dead) return false;
    }
    // Every edit costs exactly one, so the chase reaching a different total
    // means it did not walk the derivation the goal was priced from.
    return _edits.length == cost && _atEnd(proof);
  }

  // ---- entry points --------------------------------------------------------

  MatchResult? _root;

  /// A finite answer is certified only when its back-pointer chase has the
  /// advertised edit count and its exact residual product accepts at EOF.
  bool _certified(int cost) {
    _edits.clear();
    _root = null;
    lastVerified = false;
    if (cost < 0) return true;
    if (cost == 0) return lastVerified = (_root = _clean) != null;
    final out = <MatchResult>[];
    if (!_chase(cost, out)) return false;
    _root = out.length == 1 && out.first.len == _inputLen
        ? out.first
        : Match(null, 0, _inputLen, subClauseMatches: out);
    return lastVerified = true;
  }

  SkipResult recover(String input) {
    recoverCost(input);
    final root = _root;
    if (root == null) {
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    // The edits are the report, and now they are two facts rather than one.
    // Input the grammar could not use is a span over exactly those characters;
    // the clause that wanted something there went unfilled either way, so every
    // edit also names an obligation. m74 reported a substitution as a bare
    // deletion and dropped what it wrote -- the write is gone, so the
    // obligation is the only honest half left, and it is now always recorded.
    final spans = <SyntaxError>[];
    final missing = <MissingObligation>[];
    for (final (pos, drop, what) in _edits) {
      if (drop > 0) spans.add(SyntaxError(pos: pos, len: drop));
      missing.add(MissingObligation(what, pos));
    }
    return SkipResult(
        root, spans, missing, spans.length + missing.length, false);
  }

  int recoverCost(String input) {
    _relaxed = true;
    final cheap = _pass(input);
    if (_certified(cheap)) return cheap;
    _relaxed = false;
    final tight = _pass(input, reuse: true);
    if (_certified(tight)) return tight;
    // Exact search and exact replay are intended to be the same proof.  If an
    // implementation defect ever separates them, fail closed: no finite answer
    // leaves this engine without an accepting residual at EOF.
    lastCost = lastRegret = lastFabrications = -1;
    return -1;
  }

  int _pass(String input, {bool reuse = false}) {
    if (!reuse) {
      _input = input;
      _inputLen = input.length;
      _clean = null;
      _descriptionCache.clear();
      _parser = _Oracle(_rules, topRuleName, input);
      final result = _parser.topMatch();
      if (!result.isMismatch && result.len == input.length) {
        _clean = result;
        lastCost = lastRegret = lastFabrications = lastSteps = 0;
        return 0;
      }
      _cells.clear();
    } else {
      // Damage was found in the relaxed derivation.  Keep the current table
      // and its cells, invalidate their facts in place, and refill them with
      // exact DFA-keyed facts; no parser or repaired input is constructed.
      for (final e in _cells.values) {
        e.value = null;
        e.settledBudget = -1;
        e.version = 0;
        e.activeDepth = -1;
      }
    }
    final goal = _goal;
    final int? maxCost = _recursiveRules
        ? null
        : _goalFromNothing == null
            ? -1
            : _inputLen + _goalFromNothing!;
    _posShift = (_inputLen + 2).bitLength;
    _span = 1 << _posShift;
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _stack.clear();
    _depth = -1;
    _steps = 0;
    // The ladder, with A3's filter: one memo serves every round.
    for (var k = 0; maxCost == null || k <= maxCost; k++) {
      final goalEntry = _entryAt(goal, 0, _free);
      _run(goalEntry, k);
      final v = goalEntry.value;
      if (v == null) continue;
      int? bestC, bestR, bestF;
      for (var i = 0; i < v.length; i += 5) {
        final key = v[i];
        if (_endOf(key) != _inputLen || !_atEnd(_oweOf(key))) continue;
        if (bestC == null ||
            v[i + 1] < bestC ||
            v[i + 1] == bestC &&
                (v[i + 2] < bestR! ||
                    v[i + 2] == bestR && v[i + 3] < bestF!)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          bestF = v[i + 3];
          _goalKey = key;
        }
      }
      if (bestC != null) {
        lastCost = bestC;
        lastRegret = bestR!;
        lastFabrications = bestF!;
        lastSteps = _steps;
        return bestC;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}
