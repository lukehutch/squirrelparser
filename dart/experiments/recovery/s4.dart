// s4.dart -- s3 with the frozen parse consulted where its work is reusable,
// and the fill solver collapsed to a single recursion. Same cost model, same
// gates.
//
// THE REUSE: the resync's question -- "where does this slot next read
// cleanly?" -- is one the FROZEN parser already answers, memoized, with the
// finished subtree attached. s3 answered it by running its own chart at
// budget 0 down the scan; s4 asks the library and reuses the subtree as a
// leaf way. Valid work is never repeated (the steer's directive), and the
// scan is the pure parser's speed.
//
// THE REFUTATION THAT SHAPED THIS FILE: deleting the budget outright -- one
// unbudgeted descent, cells computed once and never re-derived, termination
// by prune-per-end and the cycle seeds -- was built first and is REFUTED for
// latency: ~100x per case (144 ms on one delim-delete case, battery
// timeout). A3's truth stands re-confirmed: the budget is the HORIZON that
// keeps nearly-correct input cheap; without it every cell explores every
// repair at every depth. The real waste the tombstone-analogy names is the
// clean spine's re-expansion per round (prefix-edits 0 means full-budget
// sub-calls miss their lower-budget cells), and the no-repeat form that
// removes it without removing the horizon -- cells that GROW to a new budget
// instead of recomputing, the m-line's budget families done in one table --
// is specified for the next round, not smuggled into this one.
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
      this.eof = 0,
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
            mark: SyntaxError(pos: p, len: 0),
            owing: true,
            eof: atEof ? 1 : 0);

  final int end, del, gap, net, key, toll, eof, vouch, from;
  final bool owing;
  final MatchResult? leaf;
  final Clause? cap;
  final _Way? link, prev;
  final SyntaxError? mark;

  int get edits => del + gap + (eof > 0 ? 1 : 0);
  bool get peg => key > _far;
  bool get free => key >= _far;
  bool get nodes => leaf != null || cap != null;

  _Way then(_Way v) =>
      _Way(v.end, del + v.del, gap + v.gap, net + v.net, _min(key, v.key),
          toll: toll + v.toll,
          eof: eof + v.eof,
          vouch: vouch + v.vouch,
          owing: v.owing || (v.end == end && owing),
          link: v,
          prev: this,
          mark: v.mark);

  _Way over(MatchResult n, [int k = _peg]) => _Way(end, del, gap, net,
      _min(key, k),
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

  _Way fee() => _Way(end, del, gap, net, key,
      toll: toll + 1,
      eof: eof,
      vouch: vouch,
      owing: owing,
      leaf: leaf,
      cap: cap,
      from: from,
      link: link,
      prev: prev,
      mark: mark);

  _Way get demoted => _Way(end, del, gap, net, _min(key, _far),
      toll: toll,
      eof: eof,
      vouch: vouch,
      owing: owing,
      leaf: leaf,
      cap: cap,
      from: from,
      link: link,
      prev: prev,
      mark: mark);
}

/// The frozen parser's memo entry, with ways for a result and the budget the
/// ways were computed under.
class _Cell {
  List<_Way>? ways;
  bool inPath = false, foundLR = false;
  int gen = -1, at = -1;
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
  final Map<Clause, List<_Cell?>> _memo = {};
  late List<int> _version;
  final Map<Clause, bool> _det = {};
  final Map<Str, List<Clause>> _chars = {};
  int _round = 0, _budget = 0;
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
      ..sort(_rank);
  }

  // -- the one loop (the LR trick, serving repair unchanged) -----------------
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const [];
    if (c is Ref) return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    if (c is! HasOneSubClause && c is! HasMultipleSubClauses) {
      if (c is Str && c.text.length > 1) {
        final m = (c as Terminal).match(_ref, pos);
        if (!m.isMismatch) return [_Way(pos + m.len, 0, 0, m.len, _peg, leaf: m)];
        if (_budget < 1) return const [];
        // A LITERAL IS A SEQUENCE: the fold gives it denial, partial
        // prefixes and completion with no alignment table of its own.
        return _prune(_fold(
            _chars[c] ??= [for (final u in c.text.codeUnits) Char(String.fromCharCode(u))],
            c,
            pos));
      }
      return _prune(_term(c as Terminal, pos));
    }
    final row = _memo[c] ??= List<_Cell?>.filled(_in.length + 2, null);
    final e = row[pos] ??= _Cell();
    if (e.inPath) {
      if (e.ways != null) return e.ways!;
      e.foundLR = true;
      return e.ways = const [];
    }
    if (e.ways != null && e.gen == _version[pos] && e.at >= _budget) {
      return e.at == _budget ? e.ways! : _afford(e.ways!);
    }
    e.inPath = true;
    while (true) {
      final got = _prune([..._expand(c, pos), ..._afford(e.ways ?? const [])]);
      final done = e.ways != null && !_improved(got, e.ways!);
      e.ways = got;
      e.at = _budget;
      if (done || !e.foundLR) break;
      e.gen = ++_version[pos];
    }
    e.inPath = false;
    e.gen = _version[pos];
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
    if (c is Repetition) return _rep(c, pos);
    if (c is Optional) return _opt(c, pos);
    if (c is FollowedBy || c is NotFollowedBy) {
      final sub = c is FollowedBy ? c.subClause : (c as NotFollowedBy).subClause;
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
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) => [
        for (final w in ways)
          if (w.net > 0 || w.free || w.end == pos || _determined(c))
            _judge(c, pos, w)
      ];

  _Way _judge(Ref c, int pos, _Way w) {
    final absorbed = (w.end - pos) - w.del - w.net;
    final fresh = absorbed - w.vouch;
    final ate = !w.free && fresh > w.net ? 1 : 0;
    return w.capped(c, pos, _peg, ate,
        w.free || ate > 0 ? (absorbed > w.vouch ? absorbed : w.vouch) : w.vouch);
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

  /// A repetition as reachability; a `+` with nothing at all owes exactly one
  /// occurrence, which the body's own fill supplies.
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
          if (b != null && _rank(x, b) >= 0) continue;
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
    return [for (final w in _prune(all)) w.capped(c, pos)];
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
    if (!m.isMismatch) {
      final n =
          c is Str || c is Char || (c is CharSet && !c.inverted) ? m.len : 0;
      return [_Way(pos + m.len, 0, 0, n, _peg, leaf: m)];
    }
    if (_budget < 1) return const [];
    final atEof = pos == _in.length;
    return [
      _Way(pos, 0, atEof ? 0 : 1, 0, pos,
          eof: atEof ? 1 : 0,
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
    _version = List.filled(s.length + 2, 0);
    final fill = _minFill(rules[topRuleName]!);
    final ceiling = fill >= _never ? -1 : s.length + fill;
    _Way? best, fall;
    for (_round = 1; _round <= ceiling; _round++) {
      _budget = _round;
      final owed = <_Way>[];
      for (final w in _ways(rules[topRuleName]!, 0)) {
        // A way that stops short is charged for the tail it never reached,
        // loses its PEG claim with it, and pays once if it absorbed more of
        // the document than it pinned (the swallow, charged where it cannot
        // be dodged).
        final tail = s.length - w.end;
        final loose = s.length - w.del - tail - w.net;
        final swallowed = !w.free && loose > w.net ? 1 : 0;
        if (w.edits + tail + swallowed > _budget) continue;
        final incoherent = tail > 0 && w.owing;
        final a = _Way(w.end, w.del + tail, w.gap + swallowed, w.net,
            tail == 0 ? w.key : _min(w.key, w.end),
            toll: w.toll,
            eof: w.eof,
            owing: w.owing,
            leaf: w.leaf,
            cap: w.cap,
            from: w.from,
            link: w.link);
        if (a.key == _far) continue;
        if (incoherent) {
          owed.add(a);
          continue;
        }
        if (best == null || _rank(a, best) < 0) best = a;
      }
      // An incoherent reading (it owes, with input still in front of it) is
      // admitted only where it explains more and costs no more.
      if (best != null) {
        final c = best;
        var b = c;
        for (final f in owed) {
          if (f.edits + f.toll <= c.edits + c.toll && f.net > b.net) b = f;
        }
        best = b;
        break;
      }
      if (fall == null && owed.isNotEmpty) {
        var f = owed.first;
        for (final g in owed) {
          if (_rank(g, f) < 0) f = g;
        }
        fall = f;
      }
    }
    best ??= fall;
    final root = best == null
        ? SyntaxError(pos: 0, len: s.length)
        : best.end == s.length
            ? _build(best)
            : Match(null, 0, 0, subClauseMatches: [
                _build(best),
                SyntaxError(pos: best.end, len: s.length - best.end)
              ]);
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
