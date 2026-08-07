// c6.dart -- THE STANDING ENGINE (I109): c5's judgment with the way collapsed
// to A CONS CELL THAT KNOWS ITS SUMS. c5 carried fifteen fields: five judgment
// scalars, and then a second, parallel account of the same reading -- six
// fields encoding the winner's tree (leaf/cap/from/link/prev/mark, walked by a
// bespoke builder), a stored marks count, a stored eof flag, and a root
// protocol that re-derived del+gap by WALKING THE FINISHED TREE, which is the
// confession: the scalars were always folds of the chain.
//
// The collapse: a way is one payload (a denied/owed mark, a finished subtree,
// or a named cap over an inner chain) and one tail. Every quantity is either
// an additive cache of that list (del, gap, net, fees, oweN) or derived at the
// point of use (edits, marks, eof, spend, the swallow of I108):
//   - eof IS an owe at the end of the input (positional, not a flag); its
//     once-only charge is (oweN > 0 ? 1 : 0) -- I94's collapse made structural;
//   - the tree IS a fold over the chain, and the cost of the final tree is
//     del + gap + oweN by construction, so the root's audit walk is gone;
//   - a frozen read IS a way (one constructor for the parser's own answers);
//   - the unread tail at the root IS one more skip, not a protocol.
//
// Everything else is c5: the derived swallow, the five-key judgment, the tie
// law, the seed exemption on the D8 fee, eof-is-not-spend, the literal replace
// edit, the way-front as the memo cell, Warth's involved set, budget-zero
// parsing.
import 'dart:collection';

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
/// Warth's involved set names the rules that read this front's seed while
/// it grew -- the only cells growth may invalidate.
class _Front {
  _Front(this.pos);
  final int pos;
  final Map<int, _Way> _by = {};
  bool inPath = false, foundLR = false;
  int at = -1, tick = 0;
  Set<Clause>? involved;

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

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      this.rules[e.key.startsWith('~') ? e.key.substring(1) : e.key] = e.value;
    }
  }

  final Map<String, Clause> rules = {};
  final String topRuleName;

  String _in = '';
  int _n = 0;
  late Parser _ref; // input carrier: terminals are the library's own
  final Map<Clause, List<_Front?>> _memo = {};
  final List<(Clause, _Front)> _stack = [];
  final Map<int, Set<Clause>> _heads = {};
  int _tick = 0;
  final Map<Clause, bool> _det = {};
  final Map<Str, List<Clause>> _chars = {};
  int _round = 0, _budget = 0;
  int? _fill;
  final Map<MatchResult, int> _nets = HashMap.identity();
  int lastCost = 0;

  // -- ordering: fewest claims (the swallow derived, never stored); PEG's
  // reading; most explained; latest doubt; fewest obligations stranded at
  // the cut. The last key refines EXACTLY what the first collapsed: mid
  // owes are fully priced in the claim count, so recounting them here was
  // double-representation (measured inert; oweN alone scores the same +1
  // tie); the boundary claim is priced once however many slots it strands
  // (I94), so its lost cardinality is restored here (I105, re-confirmed:
  // collapsing it to a bit costs 2.6 perfect) --
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

  /// A FROZEN READ IS A WAY: the parser's own finished subtree, priced as
  /// what its constraining terminals pinned. [net] lets the Ref path cache
  /// the sum on the library's memoized match, whose identity is stable.
  _Way _read(MatchResult m, int end, [int? net]) =>
      _Way(end, 0, 0, net ?? _netOf(m), _peg, what: m);

  // -- the one loop (the LR trick, serving repair unchanged) -----------------
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const [];
    if (c is Ref) {
      // PARSING MODE IS BUDGET ZERO -- the whole of the mode split. With no
      // edits left the way-descent IS the pure parser (PEG choice, greedy
      // repetition, left recursion and all), so the frozen memo's answer is
      // exactly equivalent, unconditionally: every continuation that has
      // spent its edits is O(1) from here to the end of the input. The
      // budget itself marks where repair can no longer reach.
      if (_budget == 0 && pos < _n) {
        final m = _frozen(c, pos);
        if (m == null) return const [];
        final r = m.subClauseMatches.first;
        return [_read(m, pos + r.len, _nets[r] ??= _netOf(r))];
      }
      return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    }
    if (c is! HasOneSubClause && c is! HasMultipleSubClauses) {
      if (c is Str && c.text.length > 1) {
        final m = (c as Terminal).match(_ref, pos);
        if (!m.isMismatch) return [_read(m, pos + m.len)];
        if (_budget < 1 && pos < _in.length) return const [];
        // A LITERAL IS A SEQUENCE: the fold gives it denial, partial
        // prefixes, completion and the replace edit with no alignment table
        // of its own. (Routing literals through the memo cell was measured:
        // judgment-identical, +25% latency -- the front ceremony on every
        // MATCHING literal costs more than caching failing folds saves.)
        return _prune(
            _fold(
                _chars[c] ??= [
                  for (final u in c.text.codeUnits) Char(String.fromCharCode(u))
                ],
                c,
                pos,
                lit: true),
            pos);
      }
      return _prune(_term(c as Terminal, pos), pos);
    }
    final row = _memo[c] ??= List<_Front?>.filled(_in.length + 2, null);
    final e = row[pos] ??= _Front(pos);
    if (e.inPath) {
      // a seed was read: everyone above this cell on the path is involved
      // in its growth, and no one else ever goes stale (Warth)
      for (var i = _stack.length - 1; !identical(_stack[i].$2, e); i--) {
        (e.involved ??= HashSet.identity()).add(_stack[i].$1);
      }
      // re-entry IS left recursion; the seed is read RAW -- a budget filter
      // here would hide the seed's repair-carrying ways from the very
      // growth that must build on them
      e.foundLR = true;
      return e.ways();
    }
    if (e.at >= _budget) {
      final h = _heads[pos];
      if (h == null || !h.contains(c) || e.tick == _tick) {
        return e.ways(_budget);
      }
    }
    if (_budget == 0 && e.at < 0 && pos < _n) {
      // parsing mode for composites too: at budget zero the descent is the
      // pure parser for ANY clause, so the library answers -- cached in the
      // cell, since the library memoizes only rules
      e.at = 0;
      final m = c.match(_ref, pos);
      if (!m.isMismatch) e.add(_read(m, pos + m.len));
      return e.ways();
    }
    e.inPath = true;
    _stack.add((c, e));
    final saved = _heads[pos];
    while (true) {
      var changed = false;
      for (final w in _expand(c, pos)) {
        if (e.add(w)) changed = true;
      }
      e.at = _budget;
      e.tick = _tick;
      if (!changed || !e.foundLR) break;
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
    return e.ways(_budget);
  }

  List<_Way> _expand(Clause c, int pos) {
    if (c is Seq) return _fold(c.subClauses, c, pos);
    if (c is First) return _first(c, pos);
    if (c is Repetition) return _rep(c, pos);
    if (c is Optional) return _opt(c, pos);
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

  /// Put the rule's node on and refuse inventions that explain nothing; a
  /// zero-width way is a FILL and passes (its node's fate is decided at
  /// build, I81/I96). No judgment happens here: the swallow is derived at
  /// every comparison instead (I108).
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) => [
        for (final w in ways)
          if (w.net > 0 || w.free || w.end == pos || _determined(c))
            w.capped(c, pos)
      ];

  /// THE FOLD -- the whole of sequencing and the whole of repair. Each slot
  /// contributes its ways (fills included, since a failing clause's ways ARE
  /// its obligations); where a slot cannot be read as it stands, input may be
  /// denied up to the first place it reads freely; an unspellable fill pays
  /// D8's fee where that denial was no dearer (I72 scoped by I36).
  List<_Way> _fold(List<Clause> subs, Clause cap, int pos, {bool lit = false}) {
    var cur = <_Way>[_Way.unit(pos)];
    for (final sub in subs) {
      final next = <_Way>[];
      for (final w in cur) {
        // continue, not break: front views are insertion-ordered
        if (w.spend > _budget) continue;
        final full = _budget;
        _budget = full - w.spend;
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
            next.add(w.then(_Way.skip(w.end, j)).then(_read(m, j + m.len)));
            k = j - w.end;
            break;
          }
        }
        // a slot that is a back-edge into a cell being grown is an LR
        // seed: its give-up anchors the spine the growth exists to build,
        // and feeing it kills the growth -- the seed is exempt
        final seed = sub is Ref &&
            (_memo[rules[sub.ruleName]!]?[w.end]?.inPath ?? false);
        final fee = k > 0 && !seed && !_determined(sub);
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
          for (final v in _ways(sub, w.end + 1)) {
            next.add(sk.then(v));
          }
        }
      }
      if (next.isEmpty) return const [];
      cur = _prune(next, pos);
    }
    return [for (final w in _prune(cur, pos)) w.capped(cap, pos)];
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
  /// arm's repair may outbid it only by explaining STRICTLY more than it
  /// assumes -- hence >=, one notch harder than the swallow's own >.
  List<_Way> _first(First c, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in c.subClauses) {
      final ws = _ways(s, pos);
      for (final w in ws) {
        if (settled && !w.free && w.absorbed(pos) >= w.net) continue;
        out.add(w.capped(c, pos, settled ? _far : _peg));
      }
      settled = settled || ws.any((w) => w.peg);
    }
    return out;
  }

  /// A repetition as reachability: the same fixpoint the grow-loop closes
  /// for left recursion, computed by a one-pass closure because the general
  /// loop re-expands the whole rule per growth step (measured: growing the
  /// repetition through its own cell, 2,440 ms battery vs 1,535 for this
  /// pass, no accuracy change -- and the c2 rewrite paid the same way). A
  /// `+` with nothing at all owes exactly one occurrence, which the body's
  /// own fill supplies.
  List<_Way> _rep(Repetition c, int pos) {
    final zero = _Way.unit(pos);
    final best = <int, _Way>{if (!c.requireOne) pos: zero};
    var frontier = <_Way>[zero];
    while (frontier.isNotEmpty) {
      final moved = <int>{};
      for (final w in frontier) {
        for (final v in _ways(c.subClause, w.end)) {
          if (v.end <= w.end) continue;
          final x = w.then(v);
          final b = best[x.end];
          if (b != null && _rank(x, b, pos) >= 0) continue;
          best[x.end] = x;
          moved.add(x.end);
        }
      }
      frontier = [for (final e in moved) best[e]!];
    }
    final all = best.values.toList();
    if (all.isEmpty) {
      for (final v in _ways(c.subClause, pos)) {
        if (v.end != pos) continue;
        all.add(zero.then(v).demoted);
      }
    }
    return [for (final w in _prune(all, pos)) w.capped(c, pos)];
  }

  List<_Way> _opt(Optional c, int pos) {
    final ws = _ways(c.subClause, pos);
    return [
      _Way.unit(pos).over(Match(c, pos, 0), ws.any((w) => w.peg) ? _far : _peg),
      for (final w in ws) w.capped(c, pos)
    ];
  }

  /// A terminal reads the input, or is recorded as one obligation the input
  /// never supplied. Nothing is spelled, so no character of an absent class
  /// is invented; a multi-character literal never reaches here failing.
  List<_Way> _term(Terminal c, int pos) {
    final m = c.match(_ref, pos);
    if (!m.isMismatch) return [_read(m, pos + m.len)];
    // an owe at the end of the input is offered even with no budget left:
    // it joins the one standing "the document stopped" claim (I94), and
    // the afford filters price the single eof edit -- without this, a
    // truncation's spine dies at its second obligation
    if (_budget < 1 && pos < _in.length) return const [];
    final atEof = pos == _in.length;
    return [
      _Way(pos, 0, atEof ? 0 : 1, 0, pos,
          oweN: atEof ? 1 : 0,
          owing: true,
          what: Match(c, pos, 0,
              subClauseMatches: [SyntaxError(pos: pos, len: 0)]))
    ];
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

  /// Whether every string [c] derives yields the same tree shape (I36).
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
                    : false;
  }

  /// The fewest characters any derivation of [c] consumes -- the ceiling's
  /// only client. One recursion, a cycle reading as unreachable, computed
  /// once for the top rule.
  int _minFill(Clause c, [Set<Clause>? path]) {
    final p = path ?? <Clause>{};
    if (!p.add(c)) return _never;
    int v;
    if (c is Ref) {
      v = _minFill(rules[c.ruleName]!, p);
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
    } else if (c is Repetition) {
      v = c.requireOne ? _minFill(c.subClause, p) : 0;
    } else if (c is Optional ||
        c is FollowedBy ||
        c is NotFollowedBy ||
        c is Nothing) {
      v = 0;
    } else if (c is Str) {
      v = c.text.length;
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
    _ref = Parser(rules: rules, topRuleName: topRuleName, input: s);
    final pure = _ref.parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      return pure.root;
    }
    _memo.clear();
    final fill = _fill ??= _minFill(rules[topRuleName]!);
    final ceiling = fill >= _never ? -1 : s.length + fill;
    _Way? best, fall;
    for (_round = 1; _round <= ceiling; _round++) {
      _budget = _round;
      final owed = <_Way>[];
      for (final w in _ways(rules[topRuleName]!, 0)) {
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
