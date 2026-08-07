// t1.dart -- the engine the starred TODO describes: built AROUND the mismatch
// tree, with the memo table as the repair channel. Attempt two of the claim
// "mismatch tree plus one sideways memo signal, strictly smaller than r9 at no
// worse than 0.9748" (LESSONS Part VII head; attempt one, s1, exceeded the
// score half and failed the size half).
//
// THE VERDICT, MEASURED (2026-08-05): the claim fails on both halves, and the
// reason is the finding. 0.9326 / 57.7% perfect / ~1,035 ms / 861 normalised
// lines, against r9's 0.9748 / 74.0 / ~2,040 / 562 -- yet EVERY honesty gate
// passes (accept 3/3, freespan 3 3 4 4 1, recommit 16/16 which m143 fails,
// conf1 `0 1 1 0 2 3` with 0 free passes), and it is the fastest engine above
// 0.93 in the study. The architecture is sound; the premise was wrong:
//
//   THE MISMATCH TREE DOES NOT ALREADY HOLD WHAT THE CHART RE-DERIVES. It
//   holds the FIRST failure of each committed reading. What recovery needs is
//   every reading the parse REJECTED along the way -- the repetition that
//   stopped, the choice arm that lost after reading further, the left-
//   recursive pass the fixed point discarded, the optional that matched empty
//   over a broken body. The chart's cells hold all of those natively, alive
//   at once; this engine had to rebuild each as a side map keyed beside the
//   node ([_stopped], [_lost], the salvage splice), and every point of score
//   it gained came from recovering one more species of rejected reading.
//   Grown to chart completeness it would BE the chart, with the tree as its
//   index -- which is r13's verdict ("an exact frontier makes each candidate
//   cheaper; it does not make fewer of them"), reached from the other side.
//
// What stands regardless: the sideways signal itself. A repair is one
// content-addressed fact written into the memo ([_fix]), retired by exactly
// the entries whose derivation read its position ([readEnd] -- the
// per-position version bump generalised to a span), and the gates prove the
// mechanism sound. The evidence gate (a First arm whose mismatch read nothing
// may not invent -- I43/I78 as a TREE property) passes _recommit's swallow
// probes with no toll, no net-vs-absorption machinery, and no whole-document
// charge: one structural rule where s1 needs three pricing mechanisms.
//
// THE SHAPE. One squirrel core (the LR trick verbatim), one memo table, and a
// loop that is the left-recursion loop played at the whole-parse scale:
//
//   1. parse. A failure hands back the mismatch tree: every failing Seq holds
//      its matched prefix and the failing slot, every failed First holds every
//      arm, every Str reports how much of its literal the input supplied.
//   2. READ the candidates off that tree -- nothing is enumerated by position:
//        deny    skip to the first place the failing clause reads (probe);
//        owe     satisfy the slot with nothing, at its minFill, gated by
//                "can the parent then advance?" -- the walk holds the parent,
//                so r13's unbuilt pre-filter is free;
//        align   a damaged literal's three-op alignment (I95), seeded by the
//                length the tree already carries;
//        retract cut an already-matched left sibling at a position where the
//                failing slot reads, owing the cut construct's tail -- READ
//                OFF the match tree, no re-parse (the quote-delete class);
//      plus the sites a successful repetition threw away ([_stopped], the
//      reach the library discards), which is what makes `[2,33true]` a
//      one-comma repair instead of a deletion.
//   3. score each candidate by what the whole document then says (one
//      memo-warm re-parse per trial), commit the best, WRITE IT INTO THE MEMO
//      as a fact at (clause, pos) -- the sideways signal, content-addressed
//      exactly like foundLeftRec -- and invalidate precisely the entries
//      whose descent read the repaired site (readEnd, the per-position
//      version bump generalised to a span). Repeat.
//
// WHAT CARRIES OVER FROM s1's residual read: I94 (end-of-input obligations are
// one claim -- here only in the comparator, since there is no budget), I95
// (the alignment), I96 (an owed slot emits the spine the grammar forces,
// withheld at the end of input), I93 (this file's candidate set is exactly the
// residual classes, named). What replaces the chart's guards: the First-arm
// evidence gate -- a candidate under an arm whose mismatch READ NOTHING may
// not invent (I43/I78 as a tree property); it is tried only when no evidenced
// candidate improves the tree (I53). That one gate is what passes _recommit's
// swallow probes with no toll, no net rank, and no whole-document charge.
//
// D1 is satisfied in the most literal sense in the project: there is ONE memo
// table, the parse that fails and the parse that recovers are the same parse,
// and repair is an UPDATE to that table.
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

  /// I96: the named spine the grammar forces for an owed slot, or null.
  MatchResult? _owedNode(Clause sub, int p, int fill) {
    final chain = <Clause>[];
    var c = sub;
    for (var guard = 0; guard < 64; guard++) {
      if (c is Ref) {
        chain.add(c);
        c = rules[c.ruleName]!;
        continue;
      }
      if (c is Repetition && c.requireOne) {
        c = c.subClause;
        continue;
      }
      if (c is Seq) {
        Clause? nz;
        var many = false;
        for (final k in c.subClauses) {
          if (_minFill(k) > 0) {
            if (nz != null) many = true;
            nz = k;
          }
        }
        if (nz == null || many) break;
        c = nz;
        continue;
      }
      if (c is First) {
        Clause? best;
        var min = _never;
        var many = false;
        for (final k in c.subClauses) {
          final v = _minFill(k);
          if (v < min) {
            min = v;
            best = k;
            many = false;
          } else if (v == min) {
            many = true;
          }
        }
        if (best == null || many || min >= _never) break;
        c = best;
        continue;
      }
      break;
    }
    if (chain.isEmpty) return null;
    MatchResult node = Match(chain.last, p, 0, subClauseMatches: [
      for (var j = 0; j < fill; j++) SyntaxError(pos: p, len: 0)
    ]);
    for (var i = chain.length - 2; i >= 0; i--) {
      node = Match(chain[i], p, 0, subClauseMatches: [node]);
    }
    return node;
  }

  // -- candidates: read off the tree, filtered by probes ---------------------

  /// One candidate repair: a fact to write at (clause, pos).
  final List<(Clause, int, MatchResult, bool, int)> _cand = [];
  final Set<String> _seen = {};
  final Set<MatchResult> _walked = HashSet.identity();

  void _offer(Clause c, int p, MatchResult fact, bool evidenced,
      [int fee = 0]) {
    final key = '${identityHashCode(c)}:$p:${fact.len}:${fact.runtimeType}';
    if (_seen.add(key)) _cand.add((c, p, fact, evidenced, fee));
  }

  /// What the fact itself claims: deletions, mid-document marks, and the
  /// end-of-input claim once (I94) -- the candidate's own rung on the ladder.
  int _price(MatchResult fact) {
    var del = 0, mid = 0;
    var eof = false;
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        if (m.len > 0) {
          del += m.len;
        } else if (m.pos >= _n) {
          eof = true;
        } else {
          mid++;
        }
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(fact);
    return del + mid + (eof ? 1 : 0);
  }

  /// Denial: the smallest skip after which [c] reads, and reads something.
  /// Returns that skip, the invention fee's basis (I72).
  int? _deny(Clause c, int p, bool ev) {
    for (var k = 1; p + k <= _n; k++) {
      final m = _probe(c, p + k);
      if (m == null) continue;
      if (m.len == 0 && c is! FollowedBy && c is! NotFollowedBy) return null;
      // the probe already wears [c]'s node when [c] is a Ref; splice its
      // content so the fact does not wrap the rule twice
      final inner = identical(m.clause, c) && m.subClauseMatches.length == 1
          ? m.subClauseMatches.first
          : m;
      _offer(
          c,
          p,
          Match(c, p, k + m.len, subClauseMatches: [
            SyntaxError(pos: p, len: k),
            if (m.len > 0 || m.subClauseMatches.isNotEmpty) inner
          ]),
          ev);
      return k;
    }
    return null;
  }

  /// A memoised frozen probe: does [c] read at [p] as things stand?
  final Map<Clause, Map<int, MatchResult?>> _probes = HashMap.identity();
  MatchResult? _probe(Clause c, int p) {
    final row = _probes[c] ??= {};
    if (row.containsKey(p)) return row[p];
    final m = _match(c, p);
    return row[p] = m.isMismatch ? null : m;
  }

  /// The give-up: satisfy [c] at [p] with nothing, spine-noded mid-document,
  /// priced with I72's fee where a no-dearer denial exists. The I36
  /// determined-gate and r9's reached-exclusion were both measured here and
  /// both lost (0.9223, 0.8997): the whole-document trial already sees what
  /// those rules encode locally.
  void _owe(Clause c, int p, bool ev,
      {required bool parentAdvances, int? denyK}) {
    final fill = _minFill(c);
    if (fill <= 0 || fill >= _never || !parentAdvances) return;
    final spine = p < _n ? _owedNode(c, p, fill) : null;
    // the flat fact is ANONYMOUS: at the end of the input the slot is a
    // construct the writer never reached (I81), so it may not wear the rule's
    // name -- with the Ref clause on it, every truncation completion grew a
    // spurious named node
    _offer(
        c,
        p,
        spine ??
            Match(null, p, 0, subClauseMatches: [
              for (var j = 0; j < fill; j++) SyntaxError(pos: p, len: 0)
            ]),
        ev,
        denyK != null && denyK <= fill ? 1 : 0);
  }

  /// Whether every string [c] derives yields the same tree shape (I36) --
  /// ported field for field from r9's honesty section.
  final Map<Clause, bool> _det = HashMap.identity();
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

  /// I95: a damaged literal read through, one edit table, cheapest ends only.
  void _align(Str c, int p, bool ev) {
    final t = c.text.length;
    final kMax = _n - p < t + 3 ? _n - p : t + 3;
    if (kMax < 0) return;
    final w = kMax + 1;
    final d = List<int>.filled((t + 1) * w, _never);
    d[0] = 0;
    for (var j = 1; j <= kMax; j++) {
      d[j] = j;
    }
    for (var i = 1; i <= t; i++) {
      d[i * w] = i;
      for (var j = 1; j <= kMax; j++) {
        var v = _in.codeUnitAt(p + j - 1) == c.text.codeUnitAt(i - 1)
            ? d[(i - 1) * w + j - 1]
            : _never;
        final owe = d[(i - 1) * w + j] + 1;
        if (owe < v) v = owe;
        final deny = d[i * w + j - 1] + 1;
        if (deny < v) v = deny;
        d[i * w + j] = v;
      }
    }
    var best = _never;
    for (var j = 1; j <= kMax; j++) {
      if (d[t * w + j] < best) best = d[t * w + j];
    }
    if (best >= _never || best == 0) return;
    for (var j = 1; j <= kMax; j++) {
      if (d[t * w + j] != best) continue;
      final kids = <MatchResult>[];
      var i = t, jj = j;
      while (i > 0 || jj > 0) {
        final here = d[i * w + jj];
        if (i > 0 &&
            jj > 0 &&
            _in.codeUnitAt(p + jj - 1) == c.text.codeUnitAt(i - 1) &&
            d[(i - 1) * w + jj - 1] == here) {
          kids.add(Match(null, p + jj - 1, 1));
          i--;
          jj--;
        } else if (i > 0 && d[(i - 1) * w + jj] + 1 == here) {
          kids.add(SyntaxError(pos: p + jj, len: 0));
          i--;
        } else {
          kids.add(SyntaxError(pos: p + jj - 1, len: 1));
          jj--;
        }
      }
      _offer(c, p, Match(c, p, j, subClauseMatches: kids.reversed.toList()),
          ev);
    }
  }

  /// Retraction: cut an already-matched left sibling at a position where the
  /// parse can then continue, owing the cut construct's tail -- READ OFF the
  /// match tree the parse already built. The continuation is the failing slot
  /// OR any repetition on the sibling's right spine: cutting a swallowing
  /// String at the comma is only visible to the member list INSIDE the
  /// object, not to the '}' that failed.
  void _retract(Clause mc, MatchResult m, Clause after, int e, bool ev) {
    final s = _spanStart(m);
    final conts = <Clause>[after];
    var node = m;
    var nc = mc;
    for (var guard = 0; guard < 64; guard++) {
      if (nc is Repetition) conts.add(nc.subClause);
      if (node.subClauseMatches.isEmpty) break;
      final last = node.subClauseMatches.last;
      final Clause? deeper = nc is Seq
          ? (node.subClauseMatches.length <= nc.subClauses.length
              ? nc.subClauses[node.subClauseMatches.length - 1]
              : null)
          : nc is HasOneSubClause
              ? nc.subClause
              : nc is Ref
                  ? rules[nc.ruleName]
                  : nc is First
                      ? last.clause
                      : null;
      if (deeper == null) break;
      node = last;
      nc = deeper;
    }
    for (var q = e - 1; q > s; q--) {
      var ok = false;
      for (final c in conts) {
        final r = _probe(c, q);
        if (r != null && (r.len > 0 || identical(c, after))) {
          ok = true;
          break;
        }
      }
      if (!ok) continue;
      final cut = _cut(mc, m, q);
      if (cut != null) _offer(mc, s, cut, ev);
      return; // the nearest viable cut owes the least
    }
  }

  int _spanStart(MatchResult m) =>
      m.subClauseMatches.isEmpty ? m.pos : _spanStart(m.subClauseMatches.first);

  /// [m] truncated at [q]: children before the cut kept, the child straddling
  /// it recursively cut, the slots never reached owed as zero-width marks.
  MatchResult? _cut(Clause c, MatchResult m, int q) {
    if (c is Ref) {
      final inner = _cut(rules[c.ruleName]!,
          m.subClauseMatches.isEmpty ? m : m.subClauseMatches.first, q);
      return inner == null
          ? null
          : Match(c, 0, 0, subClauseMatches: [inner]);
    }
    final s = _spanStart(m);
    if (c is Seq) {
      final kids = <MatchResult>[];
      var at = s;
      var i = 0;
      final subs = c.subClauses;
      final have = m.subClauseMatches;
      for (; i < have.length && i < subs.length; i++) {
        final k = have[i];
        final ke = _endOf(k, at);
        if (ke <= q) {
          kids.add(k);
          at = ke;
          continue;
        }
        final deep = _cut(subs[i], k, q);
        if (deep == null && at < q) return null;
        if (deep != null) kids.add(deep);
        i++;
        break;
      }
      var owed = 0;
      for (; i < subs.length; i++) {
        final v = _minFill(subs[i]);
        if (v >= _never) return null;
        owed += v;
      }
      for (var j = 0; j < owed; j++) {
        kids.add(SyntaxError(pos: q, len: 0));
      }
      return Match(c, s, q - s, subClauseMatches: kids);
    }
    if (c is First || c is Optional) {
      if (m.subClauseMatches.isEmpty) return null;
      final inner = _cut(
          c is First
              ? _armOf(c, m.subClauseMatches.first)
              : (c as Optional).subClause,
          m.subClauseMatches.first,
          q);
      return inner == null
          ? null
          : Match(c, 0, 0, subClauseMatches: [inner]);
    }
    if (c is Repetition) {
      final kids = <MatchResult>[];
      var at = s;
      for (final k in m.subClauseMatches) {
        final ke = _endOf(k, at);
        if (ke <= q) {
          kids.add(k);
          at = ke;
          continue;
        }
        final deep = _cut(c.subClause, k, q);
        if (deep != null) kids.add(deep);
        break;
      }
      if (kids.isEmpty || (c.requireOne && kids.isEmpty)) return null;
      return Match(c, s, q - s, subClauseMatches: kids);
    }
    return null; // a terminal cannot be cut
  }

  Clause _armOf(First f, MatchResult won) {
    for (final a in f.subClauses) {
      if (identical(a, won.clause)) return a;
      if (a is Ref && won.clause is Ref) {
        if ((a).ruleName == (won.clause as Ref).ruleName) return a;
      }
    }
    return won.clause ?? f.subClauses.first;
  }

  int _endOf(MatchResult m, int at) => m.subClauseMatches.isEmpty
      ? m.pos + m.len
      : m.pos + m.len; // Match recomputes pos/len from children

  /// Walk the mismatch tree, collecting candidates. [ev] is false below a
  /// First arm whose mismatch read nothing: such an arm was never chosen by
  /// the evidence, so a repair reached only through it may not invent the
  /// choice (I43/I78) -- its candidates are consulted only when no evidenced
  /// candidate improves the tree (I53).
  void _sites(MatchResult m, bool ev, [Clause? outer]) {
    if (!_walked.add(m)) return;
    final c = m.clause;
    if (!m.isMismatch) {
      final st = _stopped[m];
      if (st != null) _sites(st, ev, outer);
      final lo = _lost[m];
      if (lo != null) _sites(lo, false, outer);
      for (final k in m.subClauseMatches) {
        _sites(k, ev, outer);
      }
      return;
    }
    if (c is Seq) {
      final j = m.subClauseMatches.length - 1;
      final fc = j < c.subClauses.length ? c.subClauses[j] : c.subClauses.last;
      final fm = m.subClauseMatches.last;
      final fp = fm.pos;
      // the three repairs of the failing slot
      // Deny and owe COMPETE -- r9's mutual exclusion (give up only where
      // nothing reached the slot) was ported and measured 0.8997 with b1
      // broken: in this architecture the trials are whole-document scores and
      // the comparator is the filter, so suppressing a candidate only removes
      // information. I72's fee is what keeps the competition honest: an owe
      // where a no-dearer denial exists pays one more (b2), and past the end
      // of the input no denial exists, so completions stay free.
      final denyK = _deny(fc, fp, ev);
      final nxt = j + 1 < c.subClauses.length ? c.subClauses[j + 1] : null;
      final adv = fp >= _n ||
          nxt == null ||
          _probe(nxt, fp) != null ||
          _minFill(nxt) == 0;
      _owe(fc, fp, ev, parentAdvances: adv, denyK: denyK);
      if (fc is Str) _align(fc, fp, ev);
      // SELF-RETRACTION: cut this very production at a place the ENCLOSING
      // context resumes, owing the slots never reached there. This is the
      // whole of the swallowed-key repair: `"t:[true...` reads as the string
      // `"t` with its quote owed at the colon, because the colon is where the
      // enclosing Member resumes -- a cut no sibling-level retraction can
      // express, since the failure is inside this production, not after it.
      if (outer != null) _retractSelf(c, m, outer, ev);
      // the matched siblings still hold sites: what their repetitions and
      // optionals tried and threw away ([_stopped]), and the retraction
      // boundary of the nearest one
      var retracted = false;
      for (var i = j - 1; i >= 0; i--) {
        final sib = m.subClauseMatches[i];
        if (sib.isMismatch) continue;
        _sites(sib, ev);
        if (!retracted && sib.len > 0) {
          _retract(c.subClauses[i], sib, fc, sib.pos + sib.len, ev);
          retracted = true;
        }
      }
      // the continuation threaded inward is the first slot that CONSUMES --
      // a zero-width WS can never accept a cut point
      Clause? solid;
      for (var k = j + 1; k < c.subClauses.length; k++) {
        if (_minFill(c.subClauses[k]) > 0) {
          solid = c.subClauses[k];
          break;
        }
        if (_probe(c.subClauses[k], fp) == null) {
          solid = c.subClauses[k];
          break;
        }
      }
      _sites(fm, ev, solid ?? outer);
      return;
    }
    if (c is First) {
      for (final k in m.subClauseMatches) {
        _sites(k, ev && (k.isMismatch ? k.len > 0 : true), outer);
      }
      return;
    }
    for (final k in m.subClauseMatches) {
      _sites(k, ev, outer);
    }
    if (c is Str && m.subClauseMatches.isEmpty) _align(c, m.pos, ev);
  }

  /// Cut a FAILING sequence at [q], where [outer] -- the enclosing
  /// continuation -- reads: its matched prefix kept, the child straddling the
  /// cut recursively cut, the slots never reached owed at [q].
  void _retractSelf(Seq c, MatchResult m, Clause outer, bool ev) {
    final s0 = m.pos;
    for (var q = m.pos + m.len - 1; q > s0; q--) {
      final r = _probe(outer, q);
      if (r == null || r.len == 0) continue;
      final kids = <MatchResult>[];
      var at = s0;
      var i = 0;
      var ok = true;
      for (; i < m.subClauseMatches.length; i++) {
        final k = m.subClauseMatches[i];
        if (k.isMismatch) break;
        final ke = k.pos + k.len;
        if (ke <= q) {
          kids.add(k);
          at = ke;
          continue;
        }
        final deep = _cut(c.subClauses[i], k, q);
        if (deep == null && at < q) ok = false;
        if (deep != null) kids.add(deep);
        i++;
        break;
      }
      if (!ok || kids.isEmpty) return;
      var owed = 0;
      for (var j = i; j < c.subClauses.length; j++) {
        final v = _minFill(c.subClauses[j]);
        if (v >= _never) return;
        owed += v;
      }
      for (var j = 0; j < owed; j++) {
        kids.add(SyntaxError(pos: q, len: 0));
      }
      _offer(c, s0, Match(c, s0, q - s0, subClauseMatches: kids), ev);
      return;
    }
  }

  // -- scoring: what does the whole document then say? -----------------------

  /// (incomplete, edits, -net, -latest-first-mark): smaller is better. Edits
  /// count deletions, mid-document marks, and the end-of-input claim ONCE
  /// (I94). [net] is characters read by a terminal that constrains what it
  /// accepts -- the swallow detector every engine since I44 relies on.
  (int, int, int, int, int) _score(MatchResult root) {
    var del = 0, gapMid = 0, net = 0, first = 1 << 30;
    var eof = false;
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        if (m.len > 0) {
          del += m.len;
        } else if (m.pos >= _n) {
          eof = true;
        } else {
          gapMid++;
        }
        if (m.pos < first) first = m.pos;
        return;
      }
      final c = m.clause;
      if (m.subClauseMatches.isEmpty) {
        if (!m.isMismatch &&
            m.len > 0 &&
            c is Terminal &&
            c is! AnyChar &&
            !(c is CharSet && c.inverted)) {
          net += m.len;
        }
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    final whole = root.isMismatch ? 1 : 0;
    _salved.clear();
    _abandon = 0;
    _abandonEof = 0;
    final t = root.isMismatch ? _salvage(root) : root;
    final owed = _abandon >= _never ? 0 : _abandon;
    if (t != null) walk(t);
    final end = t == null ? 0 : _endOf(t, 0);
    if (end < _n) {
      del += _n - end;
      if (end < first) first = end;
    }
    // ABANDONING AN OBLIGATION COSTS WHAT GIVING IT UP COSTS (r13): a salvage
    // that walked away from a production's tail is charged the same minFill a
    // give-up would pay, or deciding always costs more than not deciding and
    // the loop deadlocks. And completeness is PRICED, not ranked first: with
    // the abandonment charged, an unfinished honest reading carries its own
    // completion cost, so a reading that finishes in one destructive step may
    // not outrank one that finishes honestly in two (ranking wholeness first
    // re-read `{"a":` as a String). At an equal total, the tree that has
    // DECIDED more -- smaller [owed] -- is further along; [whole] stays only
    // as the last tiebreak.
    // Abandonment AT the end of the input is part of the same "it stopped"
    // claim as the marks already there (I94), so it joins the once-charged
    // bit instead of pricing the honest partial completion out of the round:
    // without this, `if ` was answered by owing the whole program flat --
    // one claim, empty tree -- because completing the If honestly paid its
    // pending slots at full price while saying exactly as much.
    final stopped = eof || _abandonEof > 0;
    if (debug) {
      print('    score del=$del mid=$gapMid eof=$eof owedMid=$owed '
          'eofAb=$_abandonEof whole=$whole end=$end');
    }
    return (
      del + gapMid + (stopped ? 1 : 0) + owed,
      -net,
      owed + _abandonEof,
      whole,
      -first
    );
  }

  bool _better(
          (int, int, int, int, int) a, (int, int, int, int, int) b) =>
      a.$1 != b.$1
          ? a.$1 < b.$1
          : a.$2 != b.$2
              ? a.$2 < b.$2
              : a.$3 != b.$3
                  ? a.$3 < b.$3
                  : a.$4 != b.$4
                      ? a.$4 < b.$4
                      : a.$5 < b.$5;

  // -- the loop --------------------------------------------------------------

  MatchResult recover(String s) {
    _in = s;
    _n = s.length;
    _ref = Parser(rules: rules, topRuleName: topRuleName, input: s);
    _memo.clear();
    _fix.clear();
    _stopped.clear();
    _lost.clear();
    _probes.clear();
    _version = List.filled(s.length + 2, 0);
    _read = -1;
    final top = rules[topRuleName]!;
    var root = _rule(top, 0);
    for (var round = 0; round <= 4 * _n + 16; round++) {
      if (!root.isMismatch && _endOf(root, 0) >= _n) break;
      _cand.clear();
      _seen.clear();
      _walked.clear();
      _probes.clear();
      _sites(root, true);
      if (root.isMismatch == false && _endOf(root, 0) < _n) {
        // a short match: the only tree-named repair is retracting the spine
        _retract(top, root, top, _endOf(root, 0), true);
      }
      final base = _score(root);
      (Clause, int, MatchResult)? win;
      var best = base;
      var found = false;
      if (debug) {
        print('round $round base=$base cands=${_cand.length}');
      }
      // ALL CANDIDATES COMPETE AT ONCE within an evidence pass, ranked by
      // their whole-document trial score. A strict cheapest-own-price ladder
      // was measured twice and lost twice (0.9258 with the fee, 0.9223 with
      // the gate): in the chart a budget is a ceiling on whole READINGS, not
      // a schedule for greedy commits, and the trial score's first key is
      // already total edits, so cheap honest repairs win the comparisons that
      // matter without a schedule refusing to look at the rest.
      for (final pass in [true, false]) {
        for (final (c, p, fact, ev, fee) in _cand) {
          if (ev != pass) continue;
          final got = _trial(c, p, fact, top);
          final priced = (got.$1 + fee, got.$2, got.$3, got.$4, got.$5);
          if (debug) {
            print('  cand $c@$p len=${fact.len} ev=$ev fee=$fee -> $priced');
          }
          if (_better(priced, best)) {
            best = priced;
            win = (c, p, fact);
            found = true;
          }
        }
        if (found) break;
      }
      if (win == null) break;
      final (c, p, fact) = win;
      (_fix[c] ??= {})[p] = fact;
      _invalidate(p);
      root = _rule(top, 0);
    }
    final out = _emit(root);
    final (d, g) = _edits(out);
    lastCost = d + g;
    return out;
  }

  (int, int, int, int, int) _trial(
      Clause c, int p, MatchResult fact, Clause top) {
    final row = _fix[c] ??= {};
    row[p] = fact;
    _invalidate(p);
    final got = _score(_rule(top, 0));
    row.remove(p);
    _invalidate(p);
    return got;
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
    final e = _endOf(t, 0);
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

  (int, int) _edits(MatchResult m) {
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

    walk(m);
    return (del, gap);
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
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
