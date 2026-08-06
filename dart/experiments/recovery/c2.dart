// c2.dart -- THE AXIOM (I102): iteration, left recursion, and repair are
// one mechanism -- a memo entry growing to its fixed point. The grammar is
// NORMALIZED at load until only four forms remain (Terminal, Seq, First,
// Ref, plus predicates): X* IS left recursion (X* <- X* X / e), X? IS
// choice (X / e), a literal IS a sequence of characters, and the end of
// the input IS a grammar slot (#T <- B !any). The engine that remains has
// ONE fixpoint -- the grow-loop that already served left recursion and
// budget-zero parsing (I100/I101) -- and no root protocol at all: the tail
// charge is an ordinary denial at the !any slot, the root swallow is rule
// B's judgment, and truncation's obligations are ordinary owes.
//
// WHAT UBIQUITOUS GROWTH FORCED. (1) Warth's involved-set replaces the
// per-position version bump: only rules that read a growing seed, at that
// position, during that growth, are ever recomputed -- the blunt bump
// cold-started every position's memo once repetition grew everywhere, and
// the battery timed out. (2) A TOTAL order in the prune: the improvement
// test compares sorted lists position-wise, and Dart's sort is unstable,
// so rank-ties swapped order across iterations and read as improvement
// forever (one stmt transpose hung). (3) Boundary law: rule B (the top
// body) is the FINAL judgment -- admit every reading, judge every reading,
// vouch-blind -- and it must be levied BEFORE the end-of-input fold, since
// the prune's per-end selection assumes no claim is still pending when
// ways meet. (4) Vouch symmetry: a frozen span vouches exactly what its
// enumerated form would have (span - net; the named judges inside it).
// Stripping that from anonymous spans tolled the honest reading while its
// rival's enumerated content stayed shielded -- the escape-conjure swallow
// won 25 quote-delete cases on that asymmetry alone.
import 'dart:collection';

import 'package:squirrel_parser/squirrel_parser.dart';

const int _far = 1 << 30;
const int _peg = _far + 1;
const int _never = 1 << 30;
int _min(int a, int b) => a < b ? a : b;

/// One reading: where it ends, what it cost (deny/owe/absorb), what it
/// explained, where it first doubted, and the tree it promises (I88: built
/// only for the winner).
class _Way {
  const _Way(this.end, this.del, this.gap, this.net, this.key,
      {this.toll = 0,
      this.eof = false,
      this.vouch = 0,
      this.owing = false,
      this.leaf,
      this.cap,
      this.from = 0,
      this.link,
      this.prev,
      this.mark});

  const _Way.unit(int p) : this(p, 0, 0, 0, _peg);

  _Way.skip(int f, int t)
      : this(t, t - f, 0, 0, f, mark: SyntaxError(pos: f, len: t - f));

  /// One obligation. At the end of the input it joins the single "it
  /// stopped" claim (I94) instead of raising the price per mark.
  _Way.owe(int p, {bool atEof = false})
      : this(p, 0, atEof ? 0 : 1, 0, p,
            mark: SyntaxError(pos: p, len: 0), owing: true, eof: atEof);

  final int end, del, gap, net, key, toll, vouch, from;

  /// The document stopped: one claim however many slots it strands (I94) --
  /// a bool can only charge once, which makes the collapse structural.
  final bool owing, eof;
  final MatchResult? leaf;
  final Clause? cap;
  final _Way? link, prev;
  final SyntaxError? mark;

  int get edits => del + gap + (eof ? 1 : 0);
  bool get peg => key > _far;
  bool get free => key >= _far;
  bool get nodes => leaf != null || cap != null;

  _Way then(_Way v) =>
      _Way(v.end, del + v.del, gap + v.gap, net + v.net, _min(key, v.key),
          toll: toll + v.toll,
          eof: eof || v.eof,
          vouch: vouch + v.vouch,
          owing: v.owing || owing && (!v.nodes || v.end == end),
          link: v,
          prev: this,
          mark: v.mark);

  _Way over(MatchResult n, [int k = _peg]) =>
      _Way(end, del, gap, net, _min(key, k),
          toll: toll, eof: eof, vouch: vouch, owing: owing, leaf: n);

  _Way capped(Clause c, int pos, [int k = _peg, int ate = 0, int v = 0]) =>
      _Way(end, del, gap, net, _min(key, k),
          toll: toll + ate,
          eof: eof,
          vouch: v > vouch ? v : vouch,
          owing: owing,
          cap: c,
          from: pos,
          link: this);

  /// A field-for-field copy with one change -- the D8 fee and the PEG
  /// demotion are the same operation on different fields.
  _Way _copy({int? key, int? toll}) => _Way(end, del, gap, net, key ?? this.key,
      toll: toll ?? this.toll,
      eof: eof,
      vouch: vouch,
      owing: owing,
      leaf: leaf,
      cap: cap,
      from: from,
      link: link,
      prev: prev,
      mark: mark);

  _Way fee() => _copy(toll: toll + 1);

  _Way get demoted => _copy(key: _min(key, _far));
}

/// The frozen parser's memo entry, with ways for a result and the budget the
/// ways were computed under. [involved] is Warth's set: the rules that read
/// this cell's seed while it grew -- the only cells growth may invalidate.
class _Cell {
  List<_Way>? ways;
  bool inPath = false, foundLR = false;
  int at = -1, tick = 0;
  Set<Clause>? involved;
}

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      this.rules[e.key.startsWith('~') ? e.key.substring(1) : e.key] = e.value;
    }
    // THE NORMALIZATION: iteration IS left recursion (X* <- X* X / e), an
    // option IS a choice (X / e), a literal IS a sequence of characters,
    // and the end of the input IS a grammar slot (T <- top !any). After
    // this the engine speaks four forms -- Terminal, Seq, First, Ref (plus
    // predicates) -- and ONE fixpoint, the memo grow-loop, serves
    // repetition, left recursion and repair alike (I100/I102). Rules coined
    // here are anonymous ('#'): control flow, not constructs -- they cap
    // without judgment.
    final seen = HashMap<Clause, Clause>.identity();
    var syn = 0;
    Clause norm(Clause c) => seen[c] ??= c is Str && c.text.length > 1
        ? Seq([for (final u in c.text.codeUnits) Char(String.fromCharCode(u))])
        : c is Seq
            ? Seq([for (final k in c.subClauses) norm(k)])
            : c is First
                ? First([for (final k in c.subClauses) norm(k)])
                : c is Optional
                    ? First([norm(c.subClause), const Nothing()])
                    : c is Repetition
                        ? () {
                            final name = '#${syn++}';
                            final self = Ref(name);
                            final body = norm(c.subClause);
                            this.rules[name] = First([
                              Seq([self, body]),
                              c.requireOne ? body : const Nothing()
                            ]);
                            return self;
                          }()
                        : c is FollowedBy
                            ? FollowedBy(norm(c.subClause))
                            : c is NotFollowedBy
                                ? NotFollowedBy(norm(c.subClause))
                                : c;
    for (final k in this.rules.keys.toList()) {
      this.rules[k] = norm(this.rules[k]!);
    }
    // B is the final judgment's address: every reading of the whole body
    // is charged for its absorption THERE, before the end-of-input slot's
    // fold compares readings per end -- the prune's optimal-substructure
    // assumption requires that no claim is still pending when ways meet
    this.rules['B'] = this.rules[topRuleName]!;
    this.rules['#T'] =
        Seq([const Ref('B'), NotFollowedBy(const CharSet([], inverted: true))]);
  }

  final Map<String, Clause> rules = {};
  final String topRuleName;

  String _in = '';
  int _n = 0;
  late Parser _ref; // input carrier: terminals are the library's own
  final Map<Clause, List<_Cell?>> _memo = {};
  final List<(Clause, _Cell)> _stack = [];
  final Map<int, Set<Clause>> _heads = {};
  int _tick = 0;
  final Map<Clause, bool> _det = {};
  int _round = 0, _budget = 0;
  static const Ref _topRef = Ref('#T');
  final Map<MatchResult, int> _nets = HashMap.identity();
  int lastCost = 0;

  // -- ordering: fewest edits; PEG's reading; most explained; latest doubt --
  static int _rank(_Way a, _Way b) {
    final ea = a.edits + a.toll, eb = b.edits + b.toll;
    if (ea != eb) return ea - eb;
    if (a.peg != b.peg) return a.peg ? -1 : 1;
    if (a.net != b.net) return b.net - a.net;
    return b.key - a.key;
  }

  /// One way per end -- the best -- and the farthest PEG way keeps the claim.
  List<_Way> _prune(List<_Way> ws) {
    if (ws.length <= 1) return ws;
    final best = <int, _Way>{};
    var far = -1;
    for (final w in ws) {
      if (w.peg && w.end > far) far = w.end;
      final b = best[w.end];
      if (b == null || _rank(w, b) < 0) best[w.end] = w;
    }
    return [for (final w in best.values) w.peg && w.end != far ? w.demoted : w]
      ..sort((a, b) {
        final r = _rank(a, b);
        return r != 0 ? r : a.end - b.end; // total order: the grow-loop's
        // improvement test compares lists position-wise, and an unstable
        // sort of rank-ties would read as improvement forever
      });
  }

  // -- the one loop (the LR trick, serving repair unchanged) -----------------
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const [];
    if (c is Ref) {
      // PARSING MODE IS BUDGET ZERO -- the whole of the mode split. With no
      // edits left the way-descent IS the pure parser (PEG choice, greedy
      // repetition, left recursion and all), so the frozen memo's answer is
      // exactly equivalent, unconditionally: every continuation that has
      // spent its edits is O(1) from here to the end of the input. The
      // budget itself marks where repair can no longer reach. A pure
      // reading vouches what it absorbed (span - net, the same at every
      // lift of one span), or outer judgments re-charge vouched content.
      if (_budget == 0) {
        final m = _frozen(c, pos);
        if (m == null) return const [];
        final r = m.subClauseMatches.first;
        final net = _nets[r] ??= _netOf(r);
        // a frozen span vouches exactly what its enumerated form would have:
        // span - net, the sum of the named judges inside it (a one-char
        // Character rule vouches 1) -- stripping this from anonymous spans
        // was measured wrong BOTH ways: it tolled the honest reading's
        // frozen content while the rival's enumerated content stayed
        // shielded, and price decided against honesty
        return [
          _Way(pos + r.len, 0, 0, net, _peg, vouch: r.len - net, leaf: m)
        ];
      }
      return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    }
    if (c is! HasOneSubClause && c is! HasMultipleSubClauses) {
      return _prune(_term(c as Terminal, pos));
    }
    final row = _memo[c] ??= List<_Cell?>.filled(_in.length + 2, null);
    final e = row[pos] ??= _Cell();
    if (e.inPath) {
      // a seed was read: everyone above this cell on the path is involved
      // in its growth, and no one else ever goes stale (Warth)
      for (var i = _stack.length - 1; !identical(_stack[i].$2, e); i--) {
        (e.involved ??= HashSet.identity()).add(_stack[i].$1);
      }
      if (e.ways != null) return e.ways!;
      e.foundLR = true;
      return e.ways = const [];
    }
    if (e.ways != null && e.at >= _budget) {
      final h = _heads[pos];
      if (h == null || !h.contains(c) || e.tick == _tick) {
        return e.at == _budget ? e.ways! : _afford(e.ways!);
      }
    }
    e.inPath = true;
    _stack.add((c, e));
    final saved = _heads[pos];
    while (true) {
      final got = _prune([..._expand(c, pos), ..._afford(e.ways ?? const [])]);
      final done = e.ways != null && !_improved(got, e.ways!);
      e.ways = got;
      e.at = _budget;
      e.tick = _tick;
      if (done || !e.foundLR) break;
      _tick++;
      _heads[pos] = {...?saved, ...?e.involved};
    }
    if (saved == null) {
      _heads.remove(pos);
    } else {
      _heads[pos] = saved;
    }
    _stack.removeLast();
    e.inPath = false;
    return e.ways!;
  }

  List<_Way> _afford(List<_Way> ws) {
    if (ws.isEmpty || ws.last.edits <= _budget) return ws;
    var k = 0;
    while (ws[k].edits <= _budget) {
      k++;
    }
    return ws.sublist(0, k);
  }

  static bool _improved(List<_Way> a, List<_Way> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].end != b[i].end || _rank(a[i], b[i]) != 0) return true;
    }
    return false;
  }

  List<_Way> _expand(Clause c, int pos) {
    if (c is Seq) return _fold(c.subClauses, c, pos);
    if (c is First) return _first(c, pos);
    if (c is FollowedBy || c is NotFollowedBy) {
      final sub =
          c is FollowedBy ? c.subClause : (c as NotFollowedBy).subClause;
      final ok = _ways(sub, pos).any((w) => w.free);
      return (c is FollowedBy) == ok
          ? [_Way.unit(pos).over(Match(c, pos, 0))]
          : const [];
    }
    return _term(c as Terminal, pos);
  }

  /// Put the rule's node on, refuse inventions that explain nothing, and
  /// judge the swallow (I97: a span is judged once). A zero-width way is a
  /// FILL and passes: its node's fate is decided at build (I81/I96).
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) =>
      c.ruleName.startsWith('#')
          // anonymous rules are control flow, not constructs: cap, no judge
          ? [for (final w in ways) w.capped(c, pos)]
          : c.ruleName == 'B'
              // the final judgment: no later context redeems an invention,
              // no earlier chooser needs protecting -- admit every reading,
              // judge every reading, VOUCH-BLIND (a vouch certifies a span
              // to enclosing constructs; nothing shields absorption from
              // the last judge)
              ? [
                  for (final w in ways)
                    w.capped(
                        c,
                        pos,
                        _peg,
                        !w.free && (w.end - pos) - w.del - w.net > w.net
                            ? 1
                            : 0)
                ]
              : [
                  for (final w in ways)
                    if (w.net > 0 || w.free || w.end == pos || _determined(c))
                      _judge(c, pos, w)
                ];

  _Way _judge(Ref c, int pos, _Way w) {
    final absorbed = (w.end - pos) - w.del - w.net;
    final fresh = absorbed - w.vouch;
    final ate = !w.free && fresh > w.net ? 1 : 0;
    return w.capped(
        c,
        pos,
        _peg,
        ate,
        w.free || ate > 0
            ? (absorbed > w.vouch ? absorbed : w.vouch)
            : w.vouch);
  }

  /// THE FOLD -- the whole of sequencing and the whole of repair. Each slot
  /// contributes its ways (fills included, since a failing clause's ways ARE
  /// its obligations); where a slot cannot be read as it stands, input may be
  /// denied up to the first place it reads freely; an unspellable fill pays
  /// D8's fee where that denial was no dearer (I72 scoped by I36).
  List<_Way> _fold(List<Clause> subs, Clause cap, int pos) {
    var cur = <_Way>[_Way.unit(pos)];
    for (final sub in subs) {
      final next = <_Way>[];
      for (final w in cur) {
        if (w.edits > _budget) break;
        final full = _budget;
        _budget = full - w.edits;
        final here = _ways(sub, w.end);
        _budget = full;
        var clean = false;
        for (final v in here) {
          if (v.free) clean = true;
        }
        var k = -1;
        if (!clean) {
          // deny up to the first place the slot reads as the FROZEN parser:
          // the library's memoized match answers, and its finished subtree is
          // reused whole -- the skip is the whole price, and the valid work
          // already done is never repeated
          final room = _budget - w.edits;
          for (var j = w.end + 1; j <= w.end + room && j <= _in.length; j++) {
            final m = _frozen(sub, j);
            if (m == null) continue;
            next.add(w
                .then(_Way.skip(w.end, j))
                .then(_Way(j + m.len, 0, 0, _netOf(m), _peg, leaf: m)));
            k = j - w.end;
            break;
          }
        }
        final fee = k > 0 && !_determined(sub);
        for (final v in here) {
          next.add(w.then(
              fee && v.end == w.end && !v.free && k <= v.gap ? v.fee() : v));
        }
      }
      if (next.isEmpty) return const [];
      cur = _prune(next);
    }
    return [for (final w in _prune(cur)) w.capped(cap, pos)];
  }

  /// The frozen parser's own answer at (c, p) -- memoized by the library for
  /// rules -- with its finished subtree, or null where it does not read.
  MatchResult? _frozen(Clause c, int p) {
    if (p > _in.length) return null;
    if (c is Ref) {
      final m = _ref.match(rules[c.ruleName]!, p);
      // the library wraps a rule's success in its Ref node on the Ref.match
      // path; going through Parser.match directly, the wrap is restored here
      // or every reused subtree loses its rule label
      return m.isMismatch ? null : Match(c, 0, 0, subClauseMatches: [m]);
    }
    final m = c.match(_ref, p);
    return m.isMismatch ? null : m;
  }

  /// Characters in [m] read by a terminal that constrains what it accepts.
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

  /// An ordered choice: every arm contributes, but once an arm has read the
  /// input as it stands the choice belongs to the document, and a later
  /// arm's repair may outbid it only by explaining more than it assumes.
  List<_Way> _first(First c, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in c.subClauses) {
      final ws = _ways(s, pos);
      for (final w in ws) {
        if (settled && !w.free && (w.end - pos) - w.del - w.net >= w.net) {
          continue;
        }
        out.add(w.capped(c, pos, settled ? _far : _peg));
      }
      settled = settled || ws.any((w) => w.peg);
    }
    return out;
  }

  /// A terminal reads the input, or is recorded as one obligation the input
  /// never supplied. Nothing is spelled, so no character of an absent class
  /// is invented; a multi-character literal never reaches here failing.
  List<_Way> _term(Terminal c, int pos) {
    final m = c.match(_ref, pos);
    if (!m.isMismatch) {
      final n =
          c is Str || c is Char || (c is CharSet && !c.inverted) ? m.len : 0;
      return [_Way(pos + m.len, 0, 0, n, _peg, leaf: m)];
    }
    if (_budget < 1) return const [];
    final atEof = pos == _in.length;
    return [
      _Way(pos, 0, atEof ? 0 : 1, 0, pos,
          eof: atEof,
          owing: true,
          leaf: Match(c, pos, 0,
              subClauseMatches: [SyntaxError(pos: pos, len: 0)]))
    ];
  }

  /// THE TREE FOR THE WINNER. A zero-width cap at the end of the input loses
  /// its name: the construct was never reached (I81). Mid-document it keeps
  /// it, which is the whole of what the spine builder used to do (I96).
  MatchResult _build(_Way w) {
    if (w.leaf != null) return w.leaf!;
    final out = <MatchResult>[];
    for (_Way? p = w.link; p != null; p = p.prev) {
      if (p.mark != null) out.add(p.mark!);
      final n = p.nodes ? p : p.link;
      if (n != null && n.nodes) out.add(_build(n));
    }
    final kids = out.reversed.toList();
    final c = w.end == w.from && w.from >= _n ? null : w.cap;
    return kids.isEmpty
        ? Match(c, w.from, w.end - w.from)
        : Match(c, 0, 0, subClauseMatches: kids);
  }

  /// Whether every string [c] derives yields the same tree shape (I36).
  bool _determined(Clause c) {
    final memo = _det[c];
    if (memo != null) return memo;
    _det[c] = false;
    return _det[c] = c is Terminal || c is FollowedBy || c is NotFollowedBy
        ? true
        : c is Seq
            ? c.subClauses.every(_determined)
            : c is Ref
                ? _determined(rules[c.ruleName]!)
                : false;
  }

  /// The fewest characters any derivation of [c] consumes -- the ceiling's
  /// only client. One recursion, a cycle reading as unreachable, computed
  /// once for the top rule.
  final Map<String, int> _fill = {};
  int _minFill(Clause c, [Set<Clause>? path]) {
    final p = path ?? <Clause>{};
    if (!p.add(c)) return _never;
    int v;
    if (c is Ref) {
      v = _fill[c.ruleName] ??
          (_fill[c.ruleName] = _minFill(rules[c.ruleName]!, p));
    } else if (c is Seq) {
      v = 0;
      for (final k in c.subClauses) {
        final f = _minFill(k, p);
        v = f >= _never || v >= _never ? _never : v + f;
      }
    } else if (c is First) {
      v = _never;
      for (final k in c.subClauses) {
        final f = _minFill(k, p);
        if (f < v) v = f;
      }
    } else if (c is FollowedBy || c is NotFollowedBy || c is Nothing) {
      v = 0;
    } else {
      v = 1;
    }
    p.remove(c);
    return v;
  }

  // -- the entry point -------------------------------------------------------
  MatchResult recover(String s) {
    _in = s;
    _n = s.length;
    _ref = Parser(rules: rules, topRuleName: '#T', input: s);
    final pure = _ref.parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      return pure.root;
    }
    _memo.clear();
    final fill = _minFill(rules[topRuleName]!);
    final ceiling = fill >= _never ? -1 : s.length + fill;
    _Way? best;
    for (_round = 1; _round <= ceiling && best == null; _round++) {
      _budget = _round;
      for (final w in _ways(_topRef, 0)) {
        if (w.key == _far) continue; // lost the PEG race outright
        // a claim is a claim: a tolled reading arrives at the round its
        // TOTAL price names, so it can never outrun an honest rival that
        // costs the same -- rank decides between simultaneous arrivals
        if (w.edits + w.toll > _budget) continue;
        if (best == null || _rank(w, best) < 0) best = w;
      }
    }
    final root =
        best == null ? SyntaxError(pos: 0, len: s.length) : _build(best);
    var del = 0, gap = 0;
    void walk(MatchResult k) {
      if (k is SyntaxError) {
        if (k.len == 0) {
          gap++;
        } else {
          del += k.len;
        }
      }
      k.subClauseMatches.forEach(walk);
    }

    walk(root);
    lastCost = del + gap;
    return root;
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
