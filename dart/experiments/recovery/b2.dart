// b2.dart -- the design synthesis: b1's two-mode architecture with the
// chart engines' judgment used exactly where b1's classes tie.
//
// WHAT EACH DESIGN CONTRIBUTES. The chart engines' one substantive strength
// is judgment between rival readings -- ways-lists exist so that the honest
// reading and the swallow can meet a rank where net (evidence explained) and
// the fee (I72 scoped by I36) decide; the budget rounds, prune, toll and
// vouch are scaffolding to create that rivalry inside one search. The
// two-mode engine gets the rivalry for free: every candidate's attempt
// already materializes its complete resulting tree on the shared memo. So:
//
//   THE CLASSES DECIDE BETWEEN CLASSES; NET AND THE FEE DECIDE WITHIN ONE.
//
// Rivals committing at the same pass, price and class -- exactly where depth
// order used to decide, which is where the whitespace-hijack and the
// reach-denial fork live -- are ranked by (fee, net of the resulting tree,
// site order): an unspellable completion where a no-dearer denial exists
// pays one (D8's b2 stays a denial); a denial that buys a one-character read
// inside a clause that needed nothing pins nothing and loses net to the
// completion that pins the real closer. No toll, no vouch, no budget: those
// manufactured rivals; here they are born materialized.
//
import 'dart:collection';

import 'package:squirrel_parser/squirrel_parser.dart';

/// A rule-level memo entry: the frozen parser's four fields plus the span its
/// derivation read, which is what lets a repair invalidate exactly the entries
/// that could have seen it.
class _E {
  MatchResult? r;
  bool inPath = false, foundLR = false;
  int ver = 0, readEnd = -1;
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
  late Parser _ref; // input carrier, so terminals are the library's own
  final Map<Clause, List<_E?>> _memo = HashMap.identity();
  late List<int> _version;
  int _read = -1; // watermark: the furthest input index the descent examined

  /// THE REPAIR CHANNEL: committed facts at (clause, pos), consulted before
  /// anything else. Writing one is the sideways O(1) signal; [_invalidate] is
  /// its broadcast.
  final Map<Clause, Map<int, MatchResult>> _fix = HashMap.identity();

  /// What a successful repetition or optional tried and threw away -- the
  /// reach the library discards, kept beside the node instead of inside it.
  final Map<MatchResult, MatchResult> _stopped = HashMap.identity();

  /// An ordered choice's failed PRIOR arms, kept beside the winner. Separate
  /// from [_stopped] because an arm that read nothing was never chosen by the
  /// evidence: its candidates are opened-bucket (I43/I53), consulted only
  /// when nothing evidenced improves the tree. This is what lets `"a":1...}`
  /// find the Object arm's owed `{` after String already won at position 0.
  final Map<MatchResult, MatchResult> _lost = HashMap.identity();

  int lastCost = 0;
  static bool debug = false;

  void _touch(int i) {
    if (i > _read) _read = i;
  }

  // -- the core: one squirrel parser whose memo can carry repairs ------------

  MatchResult _match(Clause c, int pos) {
    final o = _fix[c]?[pos];
    if (o != null) {
      _touch(pos + (o.len > 0 ? o.len : 0));
      return o;
    }
    if (pos > _n) {
      _touch(pos);
      return Mismatch(c, pos, 0);
    }
    if (c is Ref) {
      final r = _rule(rules[c.ruleName]!, pos);
      return r.isMismatch ? r : Match(c, 0, 0, subClauseMatches: [r]);
    }
    return _expand(c, pos);
  }

  /// The library's left-recursion algorithm, with [readEnd] recorded.
  MatchResult _rule(Clause body, int pos) {
    final o = _fix[body]?[pos];
    if (o != null) {
      _touch(pos + (o.len > 0 ? o.len : 0));
      return o;
    }
    final row = _memo[body] ??= List.filled(_n + 2, null);
    final e = row[pos] ??= _E();
    if (e.r != null && (e.inPath || e.ver == _version[pos])) {
      _touch(e.readEnd);
      return e.r!;
    }
    if (e.inPath) {
      e.foundLR = true;
      return e.r = Mismatch(body, pos, 0);
    }
    e.inPath = true;
    final saved = _read;
    _read = -1;
    while (true) {
      final m = _match(body, pos);
      if (e.r != null &&
          (m.isMismatch || (!e.r!.isMismatch && m.len <= e.r!.len))) {
        if (m.isMismatch && e.r!.isMismatch && m.len >= e.r!.len) e.r = m;
        // THE REJECTED PASS IS THE FRONTIER. A left-recursive rule that grew
        // as far as the damage and then failed keeps only the last good
        // match, and the failing expansion -- the tree that names the damaged
        // site -- was discarded. Without it, every damaged input to the expr
        // grammar collapsed to its first Term. Kept beside the result like a
        // repetition's stoppedBy; the rejected pass may itself be a match
        // (an ordered choice fell back to a shorter arm) whose own side
        // entries lead to the failure.
        if (!identical(m, e.r) && !e.r!.isMismatch) _stopped[e.r!] ??= m;
        break;
      }
      e.r = m;
      if (!e.foundLR) break;
      e.ver = ++_version[pos];
    }
    e.inPath = false;
    e.ver = _version[pos];
    e.readEnd = _read;
    _read = saved > e.readEnd ? saved : e.readEnd;
    return e.r!;
  }

  MatchResult _expand(Clause c, int pos) {
    switch (c) {
      case Seq s:
        final kids = <MatchResult>[];
        var cur = pos;
        for (final sub in s.subClauses) {
          final m = _match(sub, cur);
          if (m.isMismatch) {
            kids.add(m);
            return Mismatch(c, pos, cur - pos, subClauseMatches: kids);
          }
          kids.add(m);
          cur += m.len;
        }
        return kids.isEmpty
            ? Match(c, pos, 0)
            : Match(c, 0, 0, subClauseMatches: kids);
      case First f:
        List<MatchResult>? failed;
        var read = 0;
        for (final sub in f.subClauses) {
          final m = _match(sub, pos);
          if (!m.isMismatch) {
            final out = Match(c, 0, 0, subClauseMatches: [m]);
            // the arms that lost before this one won are frontier too --
            // `("abcd" / "ab") 'z'` on `abcX` commits to `ab` while the
            // input agreed with the longer arm through 3
            if (failed != null) {
              MatchResult? far;
              MatchResult? blind;
              for (final k in failed) {
                if (k.len > 0) {
                  if (far == null || k.len > far.len) far = k;
                } else {
                  blind ??= k;
                }
              }
              if (far != null) _stopped[out] = far;
              if (blind != null) _lost[out] = blind;
            }
            return out;
          }
          (failed ??= []).add(m);
          if (m.len > read) read = m.len;
        }
        return Mismatch(c, pos, read, subClauseMatches: failed ?? const []);
      case Repetition r:
        final kids = <MatchResult>[];
        var cur = pos;
        MatchResult? stop;
        while (cur <= _n) {
          final m = _match(r.subClause, cur);
          if (m.isMismatch) {
            stop = m;
            break;
          }
          if (m.len == 0) break;
          kids.add(m);
          cur += m.len;
        }
        if (r.requireOne && kids.isEmpty) {
          return Mismatch(c, pos, 0,
              subClauseMatches: stop == null ? const [] : [stop]);
        }
        final out = kids.isEmpty
            ? Match(c, pos, 0)
            : Match(c, 0, 0, subClauseMatches: kids);
        if (stop != null) _stopped[out] = stop;
        return out;
      case Optional o:
        final m = _match(o.subClause, pos);
        if (m.isMismatch) {
          final out = Match(c, pos, 0);
          _stopped[out] = m;
          return out;
        }
        return Match(c, 0, 0, subClauseMatches: [m]);
      case FollowedBy f:
        final m = _match(f.subClause, pos);
        return m.isMismatch ? Mismatch(c, pos, 0) : Match(c, pos, 0);
      case NotFollowedBy nf:
        final m = _match(nf.subClause, pos);
        return m.isMismatch ? Match(c, pos, 0) : Mismatch(c, pos, 0);
      default:
        final m = (c as Terminal).match(_ref, pos);
        _touch(pos + (m.isMismatch ? m.len : m.len - 1) + 1);
        return m;
    }
  }

  // -- the price of nothing (shared with every engine since m41) -------------

  static const int _never = 1 << 30;
  final Map<Clause, int> _fill = {};

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
          k.subClauses.forEach(collect);
        }
      }

      rules.values.forEach(collect);
      for (var moved = true; moved;) {
        moved = false;
        for (final k in all) {
          final v = _fillOf(k);
          if (v < _fill[k]!) {
            _fill[k] = v;
            moved = true;
          }
        }
      }
    }
    return _fill[c] ?? _never;
  }

  int _fillOf(Clause c) {
    if (c is Ref) return _fill[rules[c.ruleName]!]!;
    if (c is Seq) {
      var m = 0;
      for (final k in c.subClauses) {
        final v = _fill[k]!;
        if (v >= _never) return _never;
        m += v;
      }
      return m;
    }
    if (c is First) {
      var m = _never;
      for (final k in c.subClauses) {
        if (_fill[k]! < m) m = _fill[k]!;
      }
      return m;
    }
    if (c is Repetition) return c.requireOne ? _fill[c.subClause]! : 0;
    if (c is Optional || c is FollowedBy || c is NotFollowedBy) return 0;
    if (c is Str) return c.text.length;
    return c is Nothing ? 0 : 1;
  }

  // -- the frontier: known the instant parsing stops ------------------------

  /// Sites: the mismatch node itself, the slot clause that failed, where,
  /// how deep, and whether evidence reached it. Deepest first.
  final List<(MatchResult, Clause, int, int, bool, bool)> _front = [];
  final Set<String> _seen = {};
  final Set<MatchResult> _walked = HashSet.identity();

  void _add(MatchResult m, Clause c, int p, int d, bool ev, bool reach) {
    if (_seen.add('${identityHashCode(c)}:$p')) {
      _front.add((m, c, p, d, ev, reach));
    }
  }

  /// Walk matches and mismatches alike: successful subclause work is
  /// descended only for what it tried and threw away ([_stopped], [_lost]);
  /// mismatch nodes are recursed THROUGH -- their matched children are
  /// finished work, their failing child is the frontier -- EXCEPT where the
  /// failing child already sits at the end of the input: everything beneath
  /// it is at the end too, no widening exists down there, and the site at
  /// this level (completed as a unit, its partial work kept) says everything
  /// the deeper ones would.
  void _collect(MatchResult m, bool ev, int d, [bool reach = false]) {
    if (!_walked.add(m)) return;
    final c = m.clause;
    if (!m.isMismatch) {
      // sites under the side maps are REACH sites: the parse tried this and
      // moved past without needing it, so a denial there is a disguised
      // unconditional deletion (deny anything so optional whitespace can
      // "match") -- they offer completions only
      final st = _stopped[m];
      if (st != null) _collect(st, ev, d + 1, true);
      final lo = _lost[m];
      if (lo != null) _collect(lo, false, d + 1, true);
      for (final k in m.subClauseMatches) {
        _collect(k, ev, d + 1, reach);
      }
      return;
    }
    if (c is Seq) {
      final j = m.subClauseMatches.length - 1;
      final fc = j < c.subClauses.length ? c.subClauses[j] : c.subClauses.last;
      final fm = m.subClauseMatches.last;
      for (var i = 0; i < j; i++) {
        _collect(m.subClauseMatches[i], ev, d + 1, reach);
      }
      _add(fm, fc, fm.pos, d, ev, reach);
      // The failing child is always descended -- even at the end of the
      // input. The EOI descent-cut was measured wrong: denials are already
      // impossible at n (no widening is wasted), but the deepest sites carry
      // the SHARED grammar clauses whose one zero-width fact closes every
      // enclosing level at once through the memo ((']', 11) closes four
      // arrays), and cutting them off left only wrong-level completions.
      _collect(fm, ev, d + 1, reach);
      return;
    }
    if (c is First) {
      for (final k in m.subClauseMatches) {
        _collect(k, ev && (k.isMismatch ? k.len > 0 : true), d + 1, reach);
      }
      return;
    }
    for (final k in m.subClauseMatches) {
      _collect(k, ev, d + 1, reach);
    }
    if (m.subClauseMatches.isEmpty && c != null) {
      _add(m, c, m.pos, d, ev, reach);
    }
  }

  /// A memoised frozen probe: does [c] read at [p] as things stand?
  final Map<Clause, Map<int, MatchResult?>> _probes = HashMap.identity();
  MatchResult? _probe(Clause c, int p) {
    final row = _probes[c] ??= {};
    if (row.containsKey(p)) return row[p];
    final m = _match(c, p);
    return row[p] = m.isMismatch ? null : m;
  }

  // -- repair mode: breadth-first over the frontier --------------------------

  /// Deny exactly [l] characters so the clause reads where it stands.
  MatchResult? _denyAt(Clause c, int p, int l) {
    if (p + l > _n) return null;
    final m = _probe(c, p + l);
    if (m == null) return null;
    if (m.len == 0 && c is! FollowedBy && c is! NotFollowedBy) return null;
    final inner = identical(m.clause, c) && m.subClauseMatches.length == 1
        ? m.subClauseMatches.first
        : m;
    return Match(c, p, l + m.len, subClauseMatches: [
      SyntaxError(pos: p, len: l),
      if (m.len > 0 || m.subClauseMatches.isNotEmpty) inner
    ]);
  }

  /// I95 inside one literal: align the text against the input with match
  /// (free), owe (invent the literal's char, +1) and deny (skip an input
  /// char, +1), and emit the best alignment that costs exactly [l] AND
  /// consumes real input -- 'f (a)' owes 'i' then reads the real 'f', which
  /// neither the suffix-completion nor the prefix-denial can express.
  MatchResult? _strAt(Str c, int p, int l) {
    final t = c.text;
    for (var j = 0; j <= l && p + j < _n; j++) {
      final k = l - j;               // prefix-denied j, owed k inside
      var owed = 0, read = 0, q = p + j;
      for (var i = 0; i < t.length; i++) {
        if (q < _n && _in.codeUnitAt(q) == t.codeUnitAt(i)) {
          q++;
          read++;
        } else if (owed < k) {
          owed++;
        } else {
          read = -1;
          break;
        }
      }
      if (read > 0 && owed == k && (j > 0 || k > 0)) {
        return Match(c, p, q - p, subClauseMatches: [
          if (j > 0) SyntaxError(pos: p, len: j),
          Match(null, p + j, read),
          for (var i = 0; i < k; i++) SyntaxError(pos: q, len: 0)
        ]);
      }
    }
    return null;
  }

  /// COMPLETE the failed node: its matched children kept as they stand, the
  /// missing remainder owed as zero-width marks -- valid work is reused,
  /// never re-derived. A started construct keeps its name; one that never
  /// read a character and sits at the end of the input has none (I81). A
  /// predicate cannot be completed by fiat (I68). Returns (price, fact).
  (int, MatchResult)? _completion(MatchResult m) {
    final c = m.clause;
    if (c is FollowedBy || c is NotFollowedBy) return null;
    if (m.subClauseMatches.isEmpty) {
      int need;
      if (c is Str) {
        need = c.text.length - m.len;
      } else if (c is Terminal) {
        need = 1;
      } else {
        final f = c == null ? _never : _minFill(c);
        if (f <= 0 || f >= _never) return null;
        need = f;
      }
      final at = m.pos + m.len;
      final label = m.len > 0 || at < _n ? c : null;
      return (
        need,
        Match(label, m.pos, m.len, subClauseMatches: [
          if (m.len > 0) Match(null, m.pos, m.len),
          for (var i = 0; i < need; i++) SyntaxError(pos: at, len: 0)
        ])
      );
    }
    if (c is First) {
      // THE ARM THAT READ FURTHEST HOLDS THE COMMITMENT (I27): completing
      // the cheapest arm abandoned eleven characters of started Array for a
      // one-mark Number. Furthest evidence first; price breaks ties.
      final arms = c.subClauses;
      (int, MatchResult)? best;
      var bestRead = -1;
      for (var i = 0; i < m.subClauseMatches.length; i++) {
        final am = m.subClauseMatches[i];
        var deep = _completion(am);
        if (deep == null) continue;
        if (i < arms.length && arms[i] is Ref) {
          deep = (deep.$1, Match(arms[i], 0, 0, subClauseMatches: [deep.$2]));
        }
        if (am.len > bestRead ||
            (am.len == bestRead && (best == null || deep.$1 < best.$1))) {
          bestRead = am.len;
          best = deep;
        }
      }
      return best;
    }
    if (c is Seq) {
      final j = m.subClauseMatches.length - 1;
      final fm = m.subClauseMatches.last;
      var deep = _completion(fm);
      if (deep == null) return null;
      final fc = j < c.subClauses.length ? c.subClauses[j] : null;
      if (fc is Ref) {
        deep = (deep.$1, Match(fc, 0, 0, subClauseMatches: [deep.$2]));
      }
      var price = deep.$1;
      final at = fm.pos + fm.len;
      final marks = <MatchResult>[];
      for (var k = j + 1; k < c.subClauses.length; k++) {
        final f = _minFill(c.subClauses[k]);
        if (f >= _never) return null;
        price += f;
        for (var i = 0; i < f; i++) {
          marks.add(SyntaxError(pos: at, len: 0));
        }
      }
      return (
        price,
        Match(null, 0, 0, subClauseMatches: [
          ...m.subClauseMatches.take(j),
          deep.$2,
          ...marks
        ])
      );
    }
    if (c is Repetition) {
      final deep =
          m.subClauseMatches.isEmpty ? null : _completion(m.subClauseMatches.last);
      if (deep == null) return null;
      return (deep.$1, Match(null, 0, 0, subClauseMatches: [deep.$2]));
    }
    return null;
  }

  /// The furthest input position the parse ATTEMPTED -- side maps included,
  /// because the work a successful clause tried and threw away is part of
  /// the frontier (measuring only the tree let a destructive denial
  /// "advance" against a baseline that ignored the real exploration).
  int _extent(MatchResult m, [Set<MatchResult>? seen]) {
    final v = seen ?? HashSet.identity();
    if (!v.add(m)) return 0;
    var e = m.pos + m.len;
    final st = _stopped[m];
    if (st != null) {
      final d = _extent(st, v);
      if (d > e) e = d;
    }
    final lo = _lost[m];
    if (lo != null) {
      final d = _extent(lo, v);
      if (d > e) e = d;
    }
    for (final k in m.subClauseMatches) {
      final d = _extent(k, v);
      if (d > e) e = d;
    }
    return e;
  }

  bool _complete(MatchResult r) => !r.isMismatch && r.pos + r.len >= _n;

  /// Characters read by a terminal that constrains what it accepts -- the
  /// chart engines' `net`, computed on the materialized tree.
  int _netOf(MatchResult m) {
    if (m.subClauseMatches.isEmpty) {
      final c = m.clause;
      return !m.isMismatch &&
              m.len > 0 &&
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

  /// Whether every string [c] derives yields the same tree shape (I36).
  final Map<Clause, bool> _det = {};
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

  /// D8's fee (I72 scoped by I36): an unspellable completion pays one where
  /// a denial no dearer than it offered to read instead.
  int _fee(Clause c, int p, int price) {
    if (_determined(c)) return 0;
    for (var l = 1; l <= price && p + l <= _n; l++) {
      final m = _probe(c, p + l);
      if (m != null && m.len > 0) return 1;
    }
    return 0;
  }

  /// The frontier's SHAPE: the rightmost failing spine as a signature.
  int _sig(MatchResult m) {
    var h = 0;
    MatchResult? k = m;
    while (k != null && k.subClauseMatches.isNotEmpty) {
      h = h * 31 + identityHashCode(k.clause) + k.pos * 7 + k.len;
      k = k.subClauseMatches.last;
    }
    return h * 31 + (k == null ? 0 : identityHashCode(k.clause) + k.pos * 7);
  }

  /// Install [fact], resume parsing on the same memo, classify (2 completed,
  /// 1 advanced, 0 the frontier changed shape, -1 nothing), uninstall.
  (int, int) _attempt(
      Clause c, int p, MatchResult fact, Clause top, int was, int sig) {
    (_fix[c] ??= {})[p] = fact;
    _invalidate(p);
    final root = _rule(top, 0);
    final r = _complete(root)
        ? 2
        : _extent(root) > was
            ? 1
            : _sig(root) != sig
                ? 0
                : -1;
    final net = r >= 0 ? _netOf(root) : 0;
    _fix[c]!.remove(p);
    _invalidate(p);
    return (r, net);
  }

  // -- the two modes ---------------------------------------------------------

  MatchResult recover(String s) {
    _in = s;
    _n = s.length;
    _ref = Parser(rules: rules, topRuleName: topRuleName, input: s);
    _memo.clear();
    _fix.clear();
    _stopped.clear();
    _lost.clear();
    _probes.clear();
    _fill.clear();
    _version = List.filled(s.length + 2, 0);
    _read = -1;
    final top = rules[topRuleName]!;
    var root = _rule(top, 0);
    for (var round = 0; round <= 4 * _n + 16; round++) {
      if (_complete(root)) break;
      _front.clear();
      _seen.clear();
      _walked.clear();
      _probes.clear();
      _collect(root, true, 0);
      _front.sort((x, y) => y.$4 - x.$4); // deepest first
      final was = _extent(root);
      final sig = _sig(root);
      if (debug) {
        print('round $round was=$was sites: ' +
            [for (final (m, c, p, d, ev, rc) in _front)
              '$c@$p(d$d,${ev ? "ev" : "op"}${rc ? ",rc" : ""},r${m.pos + m.len})'].join(' '));
      }
      // REPAIR MODE. The evidenced frontier is widened to exhaustion before
      // any unevidenced arm may act (I99). Within a pass: price l ascending,
      // deepest site first, denial before completion at each site; a
      // completion beats an advancement at the same (site, l) -- which is
      // the whole of D8: b2's denial completes and wins by coming first,
      // cx2's fill completes where its denial merely advances. A repair
      // that only rearranges the frontier (class 0) is taken only when no
      // repair anywhere can move it forward.
      var committed = false;
      for (final pass in [true, false]) {
        var maxL = _n + 1;
        final comp = <int, (int, MatchResult)>{};
        for (final (m, c, p, _, ev, _) in _front) {
          if (ev != pass) continue;
          final done = _completion(m);
          if (done != null) {
            var fact = done.$2;
            if (c is Ref && !identical(fact.clause, c)) {
              fact = Match(c, 0, 0, subClauseMatches: [fact]);
            }
            if (debug) print('  comp $c@$p -> ${done.$1}');
            comp[identityHashCode(m)] = (done.$1, fact);
            if (done.$1 > maxL) maxL = done.$1;
          }
        }
        // THE OPEN RUNG RULE, both sides measured. Class-first with held
        // shape-changers (this configuration): 0.8528, recommit 14/16 --
        // mid-document advancers rightly outrank cheap wrong fills, but the
        // ladder scans on and a 28-character denial can classify complete
        // and preempt an l=1 chain (deep truncations pay). Price-first
        // (smallest repair commits, class ranks within the rung): truncate
        // 0.664 -> 0.808 and the deep chains are perfect, but mid-document
        // fills preempt dearer honest denials (0.8230 aggregate,
        // quote-delete 0.730, content 0.676). The unifying rule -- when a
        // cheap shape-change and a dear advancer both exist, which buys
        // more? -- is the last open question of this design, and net across
        // rungs is the obvious candidate nobody has measured yet.
        final held = <(int, int, int, int, Clause, int, MatchResult)>[];
        var heldN = 0;
        for (var l = 1; l <= maxL && !committed; l++) {
          var bestClass = 0;
          final rivals = <(int, int, int, Clause, int, MatchResult)>[];
          for (final (m, c, p, _, ev, _) in _front) {
            if (ev != pass) continue;
            final done = comp[identityHashCode(m)];
            for (final (isComp, fact) in [
              (false, _denyAt(c, p, l)),
              if (c is Str) (false, _strAt(c, p, l)),
              if (done != null && done.$1 == l) (true, done.$2)
            ]) {
              if (fact == null) continue;
              final (r, net) = _attempt(c, p, fact, top, was, sig);
              final fee = r >= 0 && isComp ? _fee(c, p, l) : 0;
              if (debug && r >= 0) {
                print('  try $c@$p l=$l -> class $r net=$net fee=$fee');
              }
              if (r > 0) {
                if (r > bestClass) bestClass = r;
                rivals.add((r, fee, net, c, p, fact));
              } else if (r == 0) {
                held.add((l, fee, net, heldN++, c, p, fact));
              }
            }
          }
          if (bestClass > 0) {
            (int, int, int)? bk;
            (Clause, int, MatchResult)? best;
            var i = 0;
            for (final (r, fee, net, c, p, fact) in rivals) {
              if (r != bestClass) {
                i++;
                continue;
              }
              final k = (fee, -net, i++);
              if (bk == null ||
                  k.$1 < bk.$1 ||
                  (k.$1 == bk.$1 &&
                      (k.$2 < bk.$2 || (k.$2 == bk.$2 && k.$3 < bk.$3)))) {
                bk = k;
                best = (c, p, fact);
              }
            }
            var (c, p, fact) = best!;
            // ACROSS rungs: a dear winner may not delete more explained
            // evidence than a cheaper held shape-change explains -- the
            // 28-character denial nets 1 where the l=1 fill it preempted
            // keeps the whole nested prefix pinned
            if (held.isNotEmpty && bk != null) {
              held.sort((x, y) => x.$1 != y.$1 ? x.$1 - y.$1 : y.$3 - x.$3);
              final h = held.first;
              if (h.$1 < l && h.$3 > -bk.$2) {
                c = h.$5;
                p = h.$6;
                fact = h.$7;
                if (debug) print('  held@l=${h.$1} net=${h.$3} overrides');
              }
            }
            if (debug) print('commit class=$bestClass $c@$p l=$l pass=$pass');
            (_fix[c] ??= {})[p] = fact;
            _invalidate(p);
            committed = true;
          }
        }
        if (!committed && held.isNotEmpty) {
          held.sort((a, b) {
            if (a.$1 != b.$1) return a.$1 - b.$1;
            if (a.$2 != b.$2) return a.$2 - b.$2;
            if (a.$3 != b.$3) return b.$3 - a.$3;
            return a.$4 - b.$4;
          });
          final (_, _, _, _, c, p, fact) = held.first;
          if (debug) print('commit held $c@$p pass=$pass');
          (_fix[c] ??= {})[p] = fact;
          _invalidate(p);
          committed = true;
        }
        if (committed) break;
      }
      if (!committed) break;
      root = _rule(top, 0); // BACK TO PARSING MODE, same memo table
    }
    final out = _emit(root);
    var del = 0, gap = 0;
    void walkE(MatchResult k) {
      if (k is SyntaxError) {
        if (k.len == 0) {
          gap++;
        } else {
          del += k.len;
        }
      }
      k.subClauseMatches.forEach(walkE);
    }

    walkE(out);
    lastCost = del + gap;
    return out;
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }

  /// Drop every memo entry whose derivation could have read [p] -- the
  /// per-position version bump, generalised to the span an entry actually
  /// read. Probes are positional too, so they reset wholesale.
  void _invalidate(int p) {
    for (final row in _memo.values) {
      for (var i = 0; i < row.length; i++) {
        final e = row[i];
        if (e != null && (i >= p || e.readEnd >= p)) row[i] = null;
      }
    }
    _probes.clear();
  }

  // -- emit ------------------------------------------------------------------

  MatchResult _emit(MatchResult root) {
    final t = root.isMismatch ? _salvage(root) : root;
    if (t == null) return SyntaxError(pos: 0, len: _n);
    final e = t.pos + t.len;
    if (e >= _n) return t;
    return Match(null, 0, 0,
        subClauseMatches: [t, SyntaxError(pos: e, len: _n - e)]);
  }

  /// The derivation a failure still contains: its satisfied prefix, an
  /// ordered choice salvaged by its furthest arm.
  final Map<MatchResult, MatchResult?> _salved = HashMap.identity();
  int _abandon = 0, _abandonEof = 0;

  void _charge(int v, int at) {
    if (v >= _never) v = 1;
    if (at >= _n) {
      _abandonEof += v;
    } else {
      _abandon += v;
    }
  }

  /// The derivation a failure still contains, with EVERY mismatch charging its
  /// own completion price exactly once: a terminal charges its minFill, a Seq
  /// charges the slots never reached (its broken child charges itself), a
  /// First charges only when no arm salvaged anything. Split accounting was
  /// measured double-charging the honest reading (`if ` scored 0.000).
  MatchResult? _salvage(MatchResult m) {
    if (!m.isMismatch) return m;
    if (_salved.containsKey(m)) return _salved[m];
    _salved[m] = null;
    final cl = m.clause;
    if (cl is First) {
      final before = _abandon, beforeE = _abandonEof;
      MatchResult? pick;
      var pickOwed = 0, pickOwedE = 0;
      final arms = cl.subClauses;
      for (var i = 0; i < m.subClauseMatches.length; i++) {
        _abandon = before;
        _abandonEof = beforeE;
        var d = _salvage(m.subClauseMatches[i]);
        // a failed Ref passes through unwrapped, so the arm's rule name is
        // restored here or the salvaged spine loses every label
        if (d != null && i < arms.length && arms[i] is Ref) {
          d = Match(arms[i], 0, 0, subClauseMatches: [d]);
        }
        if (d != null && (pick == null || d.len > pick.len)) {
          pick = d;
          pickOwed = _abandon;
          pickOwedE = _abandonEof;
        }
      }
      _abandon = before;
      _abandonEof = beforeE;
      if (pick == null) {
        _charge(_minFill(cl), m.pos);
        return _salved[m] = null;
      }
      _abandon = pickOwed;
      _abandonEof = pickOwedE;
      return _salved[m] = Match(cl, 0, 0, subClauseMatches: [pick]);
    }
    if (m.subClauseMatches.isEmpty) {
      _charge(cl == null ? 1 : _minFill(cl), m.pos);
      return _salved[m] = null;
    }
    final kids = <MatchResult>[];
    var broke = -1;
    for (var i = 0; i < m.subClauseMatches.length; i++) {
      final k = m.subClauseMatches[i];
      if (!k.isMismatch) {
        // A MATCHED CHILD'S STOPPED ATTEMPT IS ITS HONEST CONTINUATION. An
        // optional that matched empty over a failed member chain hides the
        // whole chain in the side map; without splicing it back, the salvage
        // of a deeply truncated document kept one brace and every trial
        // inherited the blindness -- no end-of-input owe could ever look
        // better than closing the construct empty.
        final st = _stopped[k];
        if (st != null) {
          final d = _salvage(st);
          if (d != null && d.len > 0) {
            kids.add(k.subClauseMatches.isEmpty && k.len == 0
                ? Match(k.clause, 0, 0, subClauseMatches: [d])
                : Match(k.clause, 0, 0,
                    subClauseMatches: [...k.subClauseMatches, d]));
            broke = i;
            break;
          }
        }
        kids.add(k);
        continue;
      }
      var deep = _salvage(k); // charges its own completion
      // restore the rule label the Ref passthrough dropped, whatever kind of
      // parent held the slot -- without the repetition/optional case every
      // Stmt and Value under a list vanished from the skeleton
      final slot = cl is Seq && i < cl.subClauses.length
          ? cl.subClauses[i]
          : cl is HasOneSubClause
              ? cl.subClause
              : null;
      if (deep != null && slot is Ref) {
        deep = Match(slot, 0, 0, subClauseMatches: [deep]);
      }
      if (deep != null && deep.len > 0) kids.add(deep);
      broke = i;
      break;
    }
    if (cl is Seq && broke >= 0) {
      final at = m.subClauseMatches[broke].pos;
      for (var j = broke + 1; j < cl.subClauses.length; j++) {
        _charge(_minFill(cl.subClauses[j]), at);
      }
    }
    if (kids.isEmpty) return _salved[m] = null;
    return _salved[m] = Match(cl, 0, 0, subClauseMatches: kids);
  }

}

void main() {
  final rules = MetaGrammar.parseGrammar("S <- Item+;\nItem <- 'a' 'b';\n");
  final eng = Squirrel(rules: rules, topRuleName: 'S');
  for (final s in ['abab', 'abXab', 'abaXb', 'ab', 'XXab', 'aba']) {
    final t = eng.recover(s);
    print('"$s" -> cost ${eng.lastCost} '
        '${t.toPrettyString(s).split('\n').take(3).join(' | ')}');
  }
}
