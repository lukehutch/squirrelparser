// c7.dart -- THE STANDING ENGINE: the fused parser+recovery descent with
// ONE left-recursion law. c6's fold-in exposed a duplication the split
// architecture had hidden: the pure fiber handled left recursion with
// squirrel's own rule -- seed the cell on re-entry, grow to a fixed point,
// and one per-position VERSION invalidates whatever was computed against
// the half-grown seed -- while the recovery fiber dragged Warth's
// involved-sets around: a recursion stack, a heads map, a tick counter,
// and a save/restore dance, ~25 lines of staleness machinery and two extra
// front fields. That machinery was load-bearing once: on the c2
// architecture, where normalization made every position a growth site,
// per-position invalidation cold-started the world and timed out. In this
// engine repetitions are closures, not cells, so growth happens only at
// genuine left-recursion cycles -- exactly the sparse regime squirrel's
// rule was designed for. c7 gives the priced fiber the same rule the pure
// fiber uses (I112): re-entry seeds, growth bumps the position's version,
// and a cell is valid only at its stamped version and budget. The two
// grow-loops -- _Rule.pure over matches, Squirrel.grow over priced
// readings -- are now the same algorithm, stated twice for the two value
// domains, and the recovery loop handles left recursion exactly as the
// raw parser does.
//
// Everything else is the fused c6: the engine-owned node hierarchy with
// behavior as methods (match / go / freeze / det / fill / pin; the one
// type inspection is the conversion adapter), generation-stamped memo
// arrays on the nodes, the cons-cell way and its five additive counters
// (I109-I111), the derived swallow (I108), the five-key judgment, the tie
// law, the fee and its seed exemption, eof-is-not-spend, the literal
// replace edit, budget-zero parsing (I101), and the budget ladder.
import 'package:squirrel_parser/squirrel_parser.dart';

const int _far = 1 << 30;
const int _peg = _far + 1;
const int _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

/// A named construct over an inner chain: the one payload kind the library
/// does not already provide a node for.
class _Cap {
  const _Cap(this.c, this.from, this.inner);
  final Clause c;
  final int from;
  final _Way inner;
}

/// One reading: a cons cell -- one step payload, one tail -- with its sums
/// cached beside it. The payload is a SyntaxError (denied or owed text), a
/// MatchResult (a finished subtree), or a _Cap (a name over an inner chain);
/// the tree is a fold over the list, built only for the winner (I88).
class _Way {
  const _Way(this.end, this.del, this.gap, this.net, this.key,
      {this.oweN = 0, this.fees = 0, this.owing = false, this.what, this.tail});

  const _Way.unit(int p) : this(p, 0, 0, 0, _peg);

  _Way.skip(int f, int t)
      : this(t, t - f, 0, 0, f, what: SyntaxError(pos: f, len: t - f));

  final int end, del, gap, net, key, oweN, fees;

  /// An unpaid obligation stands at this way's end (a later read clears it).
  final bool owing;
  final Object? what;
  final _Way? tail;

  /// "The document stopped" is the root's ONE claim however many slots it
  /// strands (I94): an owe at the end of the input, charged once.
  int get edits => del + gap + (oweN > 0 ? 1 : 0);
  int get spend => del + gap;
  bool get peg => key > _far;
  bool get free => key >= _far;

  /// Characters this reading absorbed without pinning them, seen from the
  /// front doing the judging.
  int absorbed(int pos) => (end - pos) - del - net;

  /// THE SWALLOW IS DERIVED, NEVER STORED (I108): a reading that absorbed
  /// more of its span than it pinned pays one. Idempotent, so a span can
  /// never be charged twice however many levels compare it.
  int ate(int pos) => !free && absorbed(pos) > net ? 1 : 0;

  _Way then(_Way v) =>
      _Way(v.end, del + v.del, gap + v.gap, net + v.net, _min(key, v.key),
          oweN: oweN + v.oweN,
          fees: fees + v.fees,
          owing: v.owing || (v.end == end && owing),
          what: v.what,
          tail: this);

  _Way over(MatchResult n, [int k = _peg]) =>
      _Way(end, del, gap, net, _min(key, k),
          oweN: oweN, fees: fees, owing: owing, what: n);

  _Way capped(Clause c, int pos, [int k = _peg]) =>
      _Way(end, del, gap, net, _min(key, k),
          oweN: oweN, fees: fees, owing: owing, what: _Cap(c, pos, this));

  _Way _copy({int? key, int? fees}) => _Way(end, del, gap, net, key ?? this.key,
      oweN: oweN,
      fees: fees ?? this.fees,
      owing: owing,
      what: what,
      tail: tail);

  _Way fee() => _copy(fees: fees + 1);

  _Way get demoted => _copy(key: _min(key, _far));
}

/// THE WAY-FRONT, which is also the memo cell: one champion per ending,
/// decided by rank at insertion. Insertion IS the improvement test (the
/// grow-loop stops when no add improves), the order is the map's own
/// deterministic iteration (no sort, so no unstable-tie livelock), and the
/// farthest-PEG claim and the budget filter are cached read-time views.
/// [at] and [ver] stamp the budget and the position-version this front was
/// computed at -- the same validity rule the pure cells use.
class _Front {
  _Front(this.pos);
  final int pos;
  final Map<int, _Way> _by = {};
  bool inPath = false, foundLR = false, dep = false;
  int at = -1, ver = 0;

  bool add(_Way w) {
    final b = _by[w.end];
    if (b == null) {
      _by[w.end] = w;
      return true;
    }
    final r = Squirrel._rank(w, b, pos);
    if (r > 0) return false;
    // THE TIE LAW, measured four ways now: the LATEST same-price rival
    // holds the bucket (deterministic -- expansion order is). First-keeps
    // loses 3.1 perfect points even with all five keys ranked; a tie never
    // signals improvement, or rank-equal rivals spin forever.
    _by[w.end] = w;
    return r < 0;
  }

  List<_Way> ways([int budget = _far]) {
    var far = -1;
    for (final w in _by.values) {
      if (w.peg && w.end > far) far = w.end;
    }
    return [
      for (final w in _by.values)
        if (w.spend <= budget) w.peg && w.end != far ? w.demoted : w
    ];
  }
}

/// A pure memo cell: squirrel's left-recursion state plus the finished
/// subtree and its cached net. [has] distinguishes "computed, mismatch"
/// from "not yet computed" (a mismatch is stored as res == null).
class _PCell {
  MatchResult? res;
  int? net;
  bool has = false, inPath = false, foundLR = false;
  int ver = 0;
}

// ---------------------------------------------------------------------------
// The grammar, as engine-owned nodes. Each node carries its source clause
// (for the trees the harness reads), its analyses, its memo state, and its
// whole behavior -- pure match and costed ways -- as methods.
// ---------------------------------------------------------------------------

abstract class _N {
  _N(this.src);

  /// The package clause this node was converted from: the label every tree
  /// node and cap carries, so the harness sees the grammar it was given.
  final Clause src;

  /// The pure fiber: squirrel's own match at [pos], or null for a mismatch.
  MatchResult? match(Squirrel e, int pos);

  /// The recovery fiber: rival priced readings at [pos].
  List<_Way> ways(Squirrel e, int pos) => pos > e._n ? const [] : go(e, pos);

  List<_Way> go(Squirrel e, int pos);

  /// The frozen parser's answer as a single peg way, or null: one idiom
  /// for the deny-scan and budget zero alike.
  _Way? freeze(Squirrel e, int pos) {
    final m = match(e, pos);
    return m == null
        ? null
        : _Way(pos + m.len, 0, 0, e._netOf(m), _peg, what: m);
  }

  /// The recovery front at [pos] if one exists this run (never allocates).
  _Front? peek(Squirrel e, int pos) => null;

  /// Whether every string this node derives yields the same tree shape
  /// (I36) -- lazily computed once, with the cycle read as false.
  bool? _det;
  bool det() {
    if (_det != null) return _det!;
    _det = false;
    return _det = detGo();
  }

  bool detGo();

  /// The fewest characters any derivation consumes. Path-cut, NOT memoized:
  /// memoizing under a cycle-cut poisons the count inside LR paths.
  int fill(Set<_N> path) {
    if (!path.add(this)) return _never;
    final v = fillGo(path);
    path.remove(this);
    return v;
  }

  int fillGo(Set<_N> path);
}

/// A composite: its recovery answers live in a way-front per position,
/// computed by the engine's grow-loop around this node's [expand].
abstract class _Comp extends _N {
  _Comp(super.src);

  List<_Front?>? _row;
  int _run = -1;

  List<_Front?> row(Squirrel e) {
    if (_run != e._run) {
      _row = List<_Front?>.filled(e._n + 2, null);
      _run = e._run;
    }
    return _row!;
  }

  @override
  _Front? peek(Squirrel e, int pos) => _run == e._run ? _row![pos] : null;

  @override
  List<_Way> go(Squirrel e, int pos) => e.grow(this, pos);

  List<_Way> expand(Squirrel e, int pos);
}

class _Seq extends _Comp {
  _Seq(super.src, this.subs);
  final List<_N> subs;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final kids = <MatchResult>[];
    var p = pos;
    for (final s in subs) {
      final m = s.match(e, p);
      if (m == null) return null;
      kids.add(m);
      p += m.len;
    }
    return kids.isEmpty
        ? Match(src, pos, 0)
        : Match(src, 0, 0, subClauseMatches: kids);
  }

  @override
  List<_Way> expand(Squirrel e, int pos) => e.fold(subs, src, pos);

  @override
  bool detGo() => subs.every((s) => s.det());

  @override
  int fillGo(Set<_N> path) {
    var v = 0;
    for (final s in subs) {
      final f = s.fill(path);
      v = f >= _never || v >= _never ? _never : v + f;
    }
    return v;
  }
}

/// An ordered choice: every arm contributes, but once an arm has read the
/// input as it stands the choice belongs to the document, and a later
/// arm's repair may outbid it only by explaining STRICTLY more than it
/// assumes -- hence >=, one notch harder than the swallow's own >.
class _First extends _Comp {
  _First(super.src, this.subs);
  final List<_N> subs;

  @override
  MatchResult? match(Squirrel e, int pos) {
    for (final s in subs) {
      final m = s.match(e, pos);
      if (m != null) return Match(src, 0, 0, subClauseMatches: [m]);
    }
    return null;
  }

  @override
  List<_Way> expand(Squirrel e, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in subs) {
      final ws = s.ways(e, pos);
      for (final w in ws) {
        if (settled && !w.free && w.absorbed(pos) >= w.net) continue;
        out.add(w.capped(src, pos, settled ? _far : _peg));
      }
      settled = settled || ws.any((w) => w.peg);
    }
    return out;
  }

  @override
  bool detGo() => false;

  @override
  int fillGo(Set<_N> path) {
    var v = _never;
    for (final s in subs) {
      final f = s.fill(path);
      if (f < v) v = f;
    }
    return v;
  }
}

/// A repetition as reachability: the same fixpoint the grow-loop closes
/// for left recursion, computed by a one-pass closure because the general
/// loop re-expands the whole rule per growth step (measured: growing the
/// repetition through its own cell, 2,440 ms battery vs 1,535 for this
/// pass, no accuracy change). A `+` with nothing at all owes exactly one
/// occurrence, which the body's own fill supplies.
class _Rep extends _Comp {
  _Rep(super.src, this.sub, this.plus);
  final _N sub;
  final bool plus;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final kids = <MatchResult>[];
    var p = pos;
    while (p <= e._n) {
      final m = sub.match(e, p);
      if (m == null) break;
      // Never consume more than one zero-length body match (the
      // pathological `()*` would loop forever).
      if (m.len == 0) break;
      kids.add(m);
      p += m.len;
    }
    if (plus && kids.isEmpty) return null;
    return kids.isEmpty
        ? Match(src, pos, 0)
        : Match(src, 0, 0, subClauseMatches: kids);
  }

  @override
  List<_Way> expand(Squirrel e, int pos) {
    final zero = _Way.unit(pos);
    final best = <int, _Way>{if (!plus) pos: zero};
    var frontier = <_Way>[zero];
    while (frontier.isNotEmpty) {
      final moved = <int>{};
      for (final w in frontier) {
        for (final v in sub.ways(e, w.end)) {
          if (v.end <= w.end) continue;
          final x = w.then(v);
          final b = best[x.end];
          if (b != null && Squirrel._rank(x, b, pos) >= 0) continue;
          best[x.end] = x;
          moved.add(x.end);
        }
      }
      frontier = [for (final n in moved) best[n]!];
    }
    final all = best.values.toList();
    if (all.isEmpty) {
      for (final v in sub.ways(e, pos)) {
        if (v.end != pos) continue;
        all.add(zero.then(v).demoted);
      }
    }
    return [for (final w in e._prune(all, pos)) w.capped(src, pos)];
  }

  @override
  bool detGo() => plus && sub.det();

  @override
  int fillGo(Set<_N> path) => plus ? sub.fill(path) : 0;
}

class _Opt extends _Comp {
  _Opt(super.src, this.sub);
  final _N sub;

  @override
  MatchResult? match(Squirrel e, int pos) {
    final m = sub.match(e, pos);
    return m == null
        ? Match(src, pos, 0)
        : Match(src, 0, 0, subClauseMatches: [m]);
  }

  @override
  List<_Way> expand(Squirrel e, int pos) {
    final ws = sub.ways(e, pos);
    return [
      _Way.unit(pos)
          .over(Match(src, pos, 0), ws.any((w) => w.peg) ? _far : _peg),
      for (final w in ws) w.capped(src, pos)
    ];
  }

  @override
  bool detGo() => false;

  @override
  int fillGo(Set<_N> path) => 0;
}

/// Both lookaheads: zero-width, and a repair may not live inside one --
/// input it accepted would be input the assertion does not consume.
class _Look extends _Comp {
  _Look(super.src, this.sub, this.positive);
  final _N sub;
  final bool positive;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      (sub.match(e, pos) != null) == positive ? Match(src, pos, 0) : null;

  @override
  List<_Way> expand(Squirrel e, int pos) {
    final ok = sub.ways(e, pos).any((w) => w.free);
    return positive == ok
        ? [_Way.unit(pos).over(Match(src, pos, 0))]
        : const [];
  }

  @override
  bool detGo() => true;

  @override
  int fillGo(Set<_N> path) => 0;
}

/// A named rule: the body every reference shares, and the PURE memo row --
/// squirrel's left-recursion algorithm lives here. On re-entry the cell
/// seeds a mismatch and signals the ancestral frame, which grows the seed
/// to a fixed point; the per-position version keeps cells computed during
/// an unfinished growth from surviving it.
class _Rule {
  _Rule(this.name);
  final String name;
  late _N body;

  List<_PCell?>? _cells;
  int _run = -1;

  _PCell pure(Squirrel e, int pos) {
    if (_run != e._run) {
      _cells = List<_PCell?>.filled(e._n + 2, null);
      _run = e._run;
    }
    final c = _cells![pos] ??= _PCell();
    if (c.has && (c.inPath || c.ver == e._pver[pos])) return c;
    if (c.inPath) {
      c.foundLR = true;
      c.has = true;
      c.res = null;
      return c;
    }
    c.inPath = true;
    do {
      final m = body.match(e, pos);
      // A match is never replaced by a mismatch, and the fixed point is
      // reached when the new attempt did not grow.
      if (c.has && (m == null || (c.res != null && m.len <= c.res!.len))) {
        break;
      }
      c.res = m;
      c.net = null;
      c.has = true;
      if (!c.foundLR) break;
      c.ver = ++e._pver[pos];
    } while (true);
    c.inPath = false;
    c.ver = e._pver[pos];
    return c;
  }
}

/// A reference: the only node that recurses through the pure memo, and the
/// lift point where a rule's readings get their name put on. Refusal of
/// inventions that explain nothing happens here; the swallow does not (it
/// is derived at every comparison instead, I108).
class _Ref extends _N {
  _Ref(super.src, this.rule);
  final _Rule rule;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos > e._n) return null;
    final m = rule.pure(e, pos).res;
    return m == null ? null : Match(src, 0, 0, subClauseMatches: [m]);
  }

  /// The rule's finished subtree is reused WHOLE, priced at the net its
  /// cell caches -- computed once per cell however many denials read it.
  @override
  _Way? freeze(Squirrel e, int pos) {
    if (pos > e._n) return null;
    final c = rule.pure(e, pos);
    final m = c.res;
    if (m == null) return null;
    return _Way(pos + m.len, 0, 0, c.net ??= e._netOf(m), _peg,
        what: Match(src, 0, 0, subClauseMatches: [m]));
  }

  @override
  List<_Way> go(Squirrel e, int pos) {
    // PARSING MODE IS BUDGET ZERO -- the whole of the mode split. With no
    // edits left the way-descent IS the pure parser (PEG choice, greedy
    // repetition, left recursion and all), so the frozen cell's answer is
    // exactly equivalent, unconditionally: every continuation that has
    // spent its edits is O(1) from here to the end of the input. The
    // budget itself marks where repair can no longer reach.
    if (e._budget == 0 && pos < e._n) {
      final w = freeze(e, pos);
      return w == null ? const [] : [w];
    }
    // Put the rule's node on and refuse inventions that explain nothing; a
    // zero-width way is a FILL and passes (its node's fate is decided at
    // build, I81/I96).
    return [
      for (final w in rule.body.ways(e, pos))
        if (w.net > 0 || w.free || w.end == pos || det()) w.capped(src, pos)
    ];
  }

  @override
  bool detGo() => rule.body.det();

  @override
  int fillGo(Set<_N> path) => rule.body.fill(path);

  /// Whether this reference is a back-edge into a cell being grown: an LR
  /// SEED, whose give-up anchors the spine the growth exists to build.
  bool seedAt(Squirrel e, int pos) => rule.body.peek(e, pos)?.inPath ?? false;
}

/// A terminal reads the input, or is recorded as one obligation the input
/// never supplied. Nothing is spelled, so no character of an absent class
/// is invented. [pin] says whether what it reads is constrained -- the
/// characters it pins are the way's net.
abstract class _Term extends _N {
  _Term(super.src);

  bool get pin;

  @override
  List<_Way> go(Squirrel e, int pos) {
    final m = match(e, pos);
    if (m != null) {
      return [_Way(pos + m.len, 0, 0, pin ? m.len : 0, _peg, what: m)];
    }
    // an owe at the end of the input is offered even with no budget left:
    // it joins the one standing "the document stopped" claim (I94), and
    // the afford filters price the single eof edit -- without this, a
    // truncation's spine dies at its second obligation
    if (e._budget < 1 && pos < e._n) return const [];
    return owe(e, pos);
  }

  List<_Way> owe(Squirrel e, int pos) {
    final atEof = pos == e._n;
    return [
      _Way(pos, 0, atEof ? 0 : 1, 0, pos,
          oweN: atEof ? 1 : 0,
          owing: true,
          what: Match(src, pos, 0,
              subClauseMatches: [SyntaxError(pos: pos, len: 0)]))
    ];
  }

  @override
  bool detGo() => true;

  @override
  int fillGo(Set<_N> path) => 1;
}

class _StrN extends _Term {
  _StrN(super.src, this.text)
      : chars = text.length > 1
            ? [
                for (final u in text.codeUnits)
                  _CharN(Char(String.fromCharCode(u)), u)
              ]
            : const [];
  final String text;
  final List<_N> chars;

  @override
  bool get pin => true;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos + text.length > e._n) return null;
    for (var i = 0; i < text.length; i++) {
      if (e._in.codeUnitAt(pos + i) != text.codeUnitAt(i)) return null;
    }
    return Match(src, pos, text.length);
  }

  /// A LITERAL IS A SEQUENCE: on a mismatch the fold gives it denial,
  /// partial prefixes, completion and the replace edit with no alignment
  /// table of its own. (Routing literals through the memo cell was
  /// measured: judgment-identical, +25% latency -- the front ceremony on
  /// every MATCHING literal costs more than caching failing folds saves.)
  @override
  List<_Way> owe(Squirrel e, int pos) => chars.isEmpty
      ? super.owe(e, pos)
      : e._prune(e.fold(chars, src, pos, lit: true), pos);

  @override
  int fillGo(Set<_N> path) => text.length;
}

class _CharN extends _Term {
  _CharN(super.src, this.cu);
  final int cu;

  @override
  bool get pin => true;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      pos < e._n && e._in.codeUnitAt(pos) == cu ? Match(src, pos, 1) : null;
}

class _SetN extends _Term {
  _SetN(super.src, this.ranges, this.inverted);
  final List<(int, int)> ranges;
  final bool inverted;

  @override
  bool get pin => !inverted;

  @override
  MatchResult? match(Squirrel e, int pos) {
    if (pos >= e._n) return null;
    final c = e._in.codeUnitAt(pos);
    var inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }
    return (inverted ? !inSet : inSet) ? Match(src, pos, 1) : null;
  }
}

class _AnyN extends _Term {
  _AnyN(super.src);

  @override
  bool get pin => false;

  @override
  MatchResult? match(Squirrel e, int pos) =>
      pos < e._n ? Match(src, pos, 1) : null;
}

class _NothingN extends _Term {
  _NothingN(super.src);

  @override
  bool get pin => false;

  @override
  MatchResult? match(Squirrel e, int pos) => Match(src, pos, 0);

  @override
  int fillGo(Set<_N> path) => 0;
}

// ---------------------------------------------------------------------------
// The engine.
// ---------------------------------------------------------------------------

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    final defs = <String, Clause>{
      for (final e in rules.entries)
        e.key.startsWith('~') ? e.key.substring(1) : e.key: e.value
    };
    for (final name in defs.keys) {
      _rules[name] = _Rule(name);
    }
    for (final e in defs.entries) {
      _rules[e.key]!.body = _conv(e.value);
    }
    _top = _rules[topRuleName]!;
  }

  final String topRuleName;
  final Map<String, _Rule> _rules = {};
  late final _Rule _top;

  String _in = '';
  int _n = 0;
  int _run = 0;
  List<int> _pver = const [], _rver = const [];
  bool _sawSeed = false;
  int _round = 0, _budget = 0;
  int? _fill;
  int lastCost = 0;

  /// The one boundary adapter: package clauses in, engine nodes out.
  _N _conv(Clause c) {
    if (c is Ref) {
      final r = _rules[c.ruleName];
      if (r == null) throw ArgumentError('rule "${c.ruleName}" not found');
      return _Ref(c, r);
    }
    if (c is Seq) return _Seq(c, [for (final s in c.subClauses) _conv(s)]);
    if (c is First) return _First(c, [for (final s in c.subClauses) _conv(s)]);
    if (c is Repetition) return _Rep(c, _conv(c.subClause), c.requireOne);
    if (c is Optional) return _Opt(c, _conv(c.subClause));
    if (c is FollowedBy) return _Look(c, _conv(c.subClause), true);
    if (c is NotFollowedBy) return _Look(c, _conv(c.subClause), false);
    if (c is Str) return _StrN(c, c.text);
    if (c is Char) return _CharN(c, c.char.codeUnitAt(0));
    if (c is CharSet) return _SetN(c, c.ranges, c.inverted);
    if (c is AnyChar) return _AnyN(c);
    if (c is Nothing) return _NothingN(c);
    throw UnsupportedError('clause kind ${c.runtimeType}');
  }

  // -- ordering: fewest claims (the swallow derived, never stored); PEG's
  // reading; most explained; latest doubt; fewest obligations stranded at
  // the cut. The last key refines EXACTLY what the first collapsed: mid
  // owes are fully priced in the claim count, so recounting them here was
  // double-representation (measured inert); the boundary claim is priced
  // once however many slots it strands (I94), so its lost cardinality is
  // restored here (I105, re-confirmed: collapsing it to a bit costs 2.6
  // perfect) --
  static int _rank(_Way a, _Way b, int pos) {
    final ea = a.edits + a.fees + a.ate(pos),
        eb = b.edits + b.fees + b.ate(pos);
    if (ea != eb) return ea - eb;
    if (a.peg != b.peg) return a.peg ? -1 : 1;
    if (a.net != b.net) return b.net - a.net;
    if (a.key != b.key) return b.key - a.key;
    return a.oweN - b.oweN;
  }

  /// One way per end -- the transient view of the same structure the memo
  /// cells keep.
  List<_Way> _prune(List<_Way> ws, int pos) {
    if (ws.length <= 1) return ws;
    final f = _Front(pos);
    ws.forEach(f.add);
    return f.ways();
  }

  /// THE GROW-LOOP, serving left recursion and repair unchanged (I100),
  /// and handling staleness EXACTLY as the pure fiber does (I112): re-entry
  /// seeds the cell and is read raw (a budget filter here would hide the
  /// seed's repair-carrying ways from the very growth that must build on
  /// them); each growth step bumps the position's version, so whatever was
  /// computed against the half-grown seed re-answers; a front is valid only
  /// at its stamped budget and version. [_Rule.pure] is this same loop over
  /// plain matches.
  List<_Way> grow(_Comp c, int pos) {
    final f = c.row(this)[pos] ??= _Front(pos);
    if (f.inPath) {
      f.foundLR = true;
      _sawSeed = true;
      return f.ways();
    }
    // Valid at its stamped budget -- and, if its compute ever read a
    // growing seed, at the position's current version. A cell that read no
    // seed cannot go stale, whatever grows (the dep bit IS the involved
    // set, recorded by the unwind instead of a recursion stack).
    if (f.at >= _budget && (!f.dep || f.ver == _rver[pos])) {
      return f.ways(_budget);
    }
    if (_budget == 0 && f.at < 0 && pos < _n) {
      // parsing mode for composites too: at budget zero the descent is the
      // pure parser for ANY node, so the pure fiber answers -- cached in
      // the front, since pure cells exist only for rules
      f.at = 0;
      final m = c.match(this, pos);
      if (m != null) f.add(_Way(pos + m.len, 0, 0, _netOf(m), _peg, what: m));
      return f.ways();
    }
    f.inPath = true;
    final outer = _sawSeed;
    _sawSeed = false;
    do {
      var changed = false;
      for (final w in c.expand(this, pos)) {
        if (f.add(w)) changed = true;
      }
      if (!changed || !f.foundLR) break;
      f.ver = ++_rver[pos];
    } while (true);
    f.dep = _sawSeed;
    _sawSeed = outer || _sawSeed;
    f.inPath = false;
    f.at = _budget;
    f.ver = _rver[pos];
    return f.ways(_budget);
  }

  /// THE FOLD -- the whole of sequencing and the whole of repair. Each slot
  /// contributes its ways (fills included, since a failing node's ways ARE
  /// its obligations); where a slot cannot be read as it stands, input may be
  /// denied up to the first place it reads freely; an unspellable fill pays
  /// D8's fee where that denial was no dearer (I72 scoped by I36).
  List<_Way> fold(List<_N> subs, Clause cap, int pos, {bool lit = false}) {
    var cur = <_Way>[_Way.unit(pos)];
    for (final sub in subs) {
      final next = <_Way>[];
      for (final w in cur) {
        // continue, not break: front views are insertion-ordered
        if (w.spend > _budget) continue;
        final full = _budget;
        _budget = full - w.spend;
        final here = sub.ways(this, w.end);
        _budget = full;
        var clean = false;
        for (final v in here) {
          if (v.free) clean = true;
        }
        var k = -1;
        if (!clean) {
          // deny up to the first place the slot reads as the FROZEN parser:
          // the pure fiber answers, and its finished subtree is reused
          // whole -- the skip is the whole price, and the valid work
          // already done is never repeated
          final room = _budget - w.edits;
          for (var j = w.end + 1; j <= w.end + room && j <= _n; j++) {
            final f = sub.freeze(this, j);
            if (f == null) continue;
            next.add(w.then(_Way.skip(w.end, j)).then(f));
            k = j - w.end;
            break;
          }
        }
        // a slot that is a back-edge into a cell being grown is an LR
        // seed: its give-up anchors the spine the growth exists to build,
        // and feeing it kills the growth -- the seed is exempt
        final seed = sub is _Ref && sub.seedAt(this, w.end);
        final fee = k > 0 && !seed && !sub.det();
        for (final v in here) {
          next.add(w.then(
              fee && v.end == w.end && !v.free && k <= v.gap ? v.fee() : v));
        }
        // THE REPLACE EDIT, inside a literal only (I95's third op): the
        // wrong character is denied AND the right one owed, so 'i"' reads
        // as 'if' at cost two -- the plain deny-scan cannot express it
        // because its skip must READ. Widening it to every slot was
        // measured twice (universal, then deny-failed-fallback): zero of
        // the s1-residual cases fixed, two new losses, double latency --
        // that family is operator-choice coin flips, not missing machinery
        if (lit && !clean && w.end < _n) {
          final sk = w.then(_Way.skip(w.end, w.end + 1));
          for (final v in sub.ways(this, w.end + 1)) {
            next.add(sk.then(v));
          }
        }
      }
      if (next.isEmpty) return const [];
      cur = _prune(next, pos);
    }
    return [for (final w in _prune(cur, pos)) w.capped(cap, pos)];
  }

  /// Characters in [m] read by a terminal that constrains what it accepts.
  /// The one walk over package-typed trees (their leaves carry package
  /// clauses, hence the type tests at this boundary).
  int _netOf(MatchResult m) {
    if (m.subClauseMatches.isEmpty) {
      final c = m.clause;
      return !m.isMismatch &&
              (c is Str || c is Char || (c is CharSet && !c.inverted))
          ? m.len
          : 0;
    }
    var n = 0;
    for (final k in m.subClauseMatches) {
      n += _netOf(k);
    }
    return n;
  }

  /// THE TREE IS A FOLD OVER THE CHAIN (I109). A mark IS its error, a leaf
  /// IS its subtree; a cap assembles its inner chain under the construct's
  /// name -- which a zero-width cap at the end of the input loses: the
  /// construct was never reached (I81). Mid-document it keeps it (I96).
  MatchResult _node(Object s, int end) {
    if (s is MatchResult) return s;
    final k = s as _Cap;
    final kids = <MatchResult>[];
    for (_Way? p = k.inner; p != null; p = p.tail) {
      if (p.what != null) kids.add(_node(p.what!, p.end));
    }
    final c = end == k.from && k.from >= _n ? null : k.c;
    return kids.isEmpty
        ? Match(c, k.from, end - k.from)
        : Match(c, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  MatchResult _build(_Way w) {
    if (w.tail == null && w.what != null) return _node(w.what!, w.end);
    final kids = <MatchResult>[];
    for (_Way? p = w; p != null; p = p.tail) {
      if (p.what != null) kids.add(_node(p.what!, p.end));
    }
    return kids.length == 1
        ? kids.single
        : Match(null, 0, 0, subClauseMatches: kids.reversed.toList());
  }

  // -- the entry point -------------------------------------------------------
  MatchResult recover(String s) {
    _in = s;
    _n = s.length;
    _run++;
    _pver = List<int>.filled(_n + 2, 0);
    _rver = List<int>.filled(_n + 2, 0);
    final pure = _top.pure(this, 0).res;
    if (pure != null && pure.len == _n) {
      lastCost = 0;
      return pure;
    }
    final fill = _fill ??= _top.body.fill(<_N>{});
    final ceiling = fill >= _never ? -1 : s.length + fill;
    _Way? best, fall;
    for (_round = 1; _round <= ceiling; _round++) {
      _budget = _round;
      final owed = <_Way>[];
      for (final w in _top.body.ways(this, 0)) {
        // THE UNREAD TAIL IS ONE MORE SKIP (I109): a way that stops short is
        // charged for the tail exactly as the fold charges any unreadable
        // span, loses its PEG claim with it (skip's key is its position),
        // and the tail's SyntaxError reaches the tree through the ordinary
        // chain -- no separate root protocol.
        final tail = s.length - w.end;
        final a = tail == 0 ? w : w.then(_Way.skip(w.end, s.length));
        if (a.edits + a.fees + a.ate(0) > _budget) continue;
        if (a.key == _far) continue;
        if (tail > 0 && w.owing) {
          owed.add(a);
          continue;
        }
        if (best == null || _rank(a, best, 0) < 0) best = a;
      }
      // An incoherent reading (it owes, with input still in front of it) is
      // admitted only where it explains more and costs no more.
      if (best != null) {
        final c = best;
        var b = c;
        for (final f in owed) {
          if (f.edits + f.fees + f.ate(0) <= c.edits + c.fees + c.ate(0) &&
              f.net > b.net) {
            b = f;
          }
        }
        best = b;
        break;
      }
      if (fall == null && owed.isNotEmpty) {
        var f = owed.first;
        for (final g in owed) {
          if (_rank(g, f, 0) < 0) f = g;
        }
        fall = f;
      }
    }
    best ??= fall;
    // THE COST IS THE WAY'S OWN SUMS: every denied character and every owe
    // in the winner's chain reaches the tree exactly once, so the audit
    // walk over the finished tree is the same number by construction.
    lastCost = best == null ? s.length : best.del + best.gap + best.oweN;
    return best == null ? SyntaxError(pos: 0, len: s.length) : _build(best);
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
