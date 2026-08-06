// r3.dart -- r2's philosophy, with the one thing r2's memo could not say.
//
// r1 and r2 kept the frozen parser's memo exactly: ONE result per (rule, pos).
// That is what PEG means, and it is why they had to re-parse. A repair was a
// substitution installed into a side table, the whole parse was run again from
// cold to find out what it did, and the memo was cleared between every trial --
// two full parses per frontier site per widening step. 2,153 ms of it.
//
// It also set a ceiling no amount of searching could lift. Delete the closing
// quote of a JSON member and `Character*` runs greedily to the NEXT real quote,
// so `String` ends late, `Member`'s `':'` fails, and there is no mismatch at
// the position where the quote belongs -- nothing for a frontier repair to
// attach to. The repair the input wants is "String could have stopped earlier",
// and a cell holding one result cannot say it. Measured: quote-delete was r2's
// single largest deficit, 190 cases at a mean 0.163 below m143.
//
// So a cell holds a LIST of ways instead of one result. A way is one end
// position reached at one price. `String` at 1 offers both "ends at 7, free"
// and "ends at 3, one obligation unmet", the enclosing `Member` takes whichever
// lets IT finish, and the choice needs no search around the parse because it is
// made inside it.
//
// THE TRICK IS THE SAME ONE. The frozen parser's `MemoEntry` lets a frame
// arbitrarily deep tell an arbitrarily distant ancestor "you are the frame that
// entered this cycle, expand it" by writing `foundLeftRec` into the entry that
// ancestor already owns -- the message crosses the whole tree in O(1) because
// its destination is addressable by content rather than by walking, and not one
// intermediate combinator learns it exists. `_Cell` carries `inPath`, `foundLR`
// and `gen` unchanged, and the loop that grows a left-recursive match to its
// fixed point is the loop that grows a repaired one: both only ever IMPROVE, so
// "re-run while the answer improves" is one mechanism serving both, and the one
// integer bump at `_version[pos]` retires every stale cell at that position
// without touching any of them.
//
// What that buys, beyond the score: there is no second parse. No `_forget`, no
// `_repairs` side table, no frontier walk, no widening loop, no advancement
// test, no salvage pass, no re-parse to find out what a repair did. r2 needed
// all of it to ask "what would happen if"; the answer is now computed where the
// question arises.
//
// KEPT FROM r2, because measurement earned it:
//
//   * A fill supplies only what the grammar SHAPE-DETERMINES ([_determined]).
//     `'}'` and `A <- [ab]` have one tree whatever they derive; `Value` has one
//     per arm, and a zero-width `Value` would assert an object or an array or a
//     number happened, on no evidence at all.
//   * Deleting a character contradicts evidence the input supplied; a gap only
//     records evidence it never supplied. At equal total cost, fewer DELETIONS.
//   * At equal cost, the reading that EXPLAINS more of the input wins ([_Way.net]).
//
// AND ONE THING NEITHER r1 NOR r2 NEEDED. A chart admits readings PEG does not:
// `'a'* 'a'` fails in PEG because the star is possessive, and succeeds here
// because a shorter chain is on offer. That freedom is exactly what repairs the
// quote -- but on an undamaged document the answer must still be PEG's, to the
// node. So every way carries [_Way.peg], set only along the reading the frozen
// parser itself would take, and a peg way outranks every other way of the same
// cost. Conformance is then a property of the ordering rather than a special
// case in the search.
import 'package:squirrel_parser/squirrel_parser.dart';

/// A match carrying the spans a repair skipped, and the obligations it left
/// unmet, beside the grammar's own children.
///
/// It extends [MatchResult] rather than [Match] because `Match` recomputes its
/// span from its children, and so cannot represent a node that begins with a
/// skipped span or one that covers no characters at all.
class Repaired extends MatchResult {
  Repaired(super.clause, super.pos, super.len, this.children, this.errors);

  /// The grammar's own children, at the grammar's own indices.
  final List<MatchResult> children;
  final List<SyntaxError> errors;

  /// Children and marks together, in input order. Leaving the marks out would
  /// make the tree describe less than the whole input, and every consumer that
  /// walks a match would find a hole exactly where the repair is.
  @override
  List<MatchResult> get subClauseMatches =>
      [...children, ...errors]..sort((a, b) => a.pos - b.pos);

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final b = StringBuffer();
    for (final k in subClauseMatches) {
      b.write(k.toPrettyString(input, indent: indent));
    }
    return b.toString();
  }
}

/// One way of reaching one end position: what it cost, how much it explained,
/// and the tree that says so.
///
/// Inside a sequence or a repetition a way is one LINK of a chain -- [node] is
/// that step's own child and [prev] is the step before it -- so extending a
/// chain is one allocation rather than a copy of everything built so far. The
/// children are collected once, for the few chains that survive.
class _Way {
  const _Way(this.end, this.del, this.gap, this.net, this.peg, this.node,
      [this.prev, this.mark]);

  final int end;

  /// Characters DISCARDED, and obligations left UNMET. Kept apart rather than
  /// summed because they are not the same claim: see [Squirrel._rank].
  final int del, gap;

  /// Characters matched by a terminal that CONSTRAINS what it accepts.
  ///
  /// `.` and an inverted set accept anything, or all but one thing, so matching
  /// one consumes a character without explaining it. This separates two
  /// readings that cost the same and cover the same text: `[1,[2,` read as one
  /// String matches all six characters through `[^"\]`, asserting nothing about
  /// any of them, where the Array reading pins `[`, `,` and both digits. It is
  /// what stops a damaged document being re-read as one long string.
  final int net;

  /// Whether this is the reading the frozen parser itself would take.
  final bool peg;

  final MatchResult? node;
  final _Way? prev;
  final SyntaxError? mark;

  bool get free => del == 0 && gap == 0;

  _Way get demoted => _Way(end, del, gap, net, false, node, prev, mark);
}

/// One memo cell: every way its clause can be read from its position.
///
/// [inPath], [foundLR] and [gen] are the frozen `MemoEntry`'s three fields,
/// doing the frozen parser's job unchanged.
class _Cell {
  List<_Way> ways = const [];
  bool inPath = false, foundLR = false, has = false;
  int gen = -1;
}

const int _CAP = 4;

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      final n = e.key.startsWith('~') ? e.key.substring(1) : e.key;
      this.rules[n] = e.value;
    }
  }

  final Map<String, Clause> rules = {};
  final String topRuleName;

  late String _in;

  /// Every clause at every position, not just every rule: a chart's inner
  /// clauses are re-entered from as many chains as reach them.
  final Map<Clause, Map<int, _Cell>> _memo = {};

  /// The frozen parser's per-position memo version.
  late List<int> _version;

  /// Memo for [_determined]: a property of the grammar, so it outlives a parse.
  final Map<Clause, bool> _det = {};

  /// What the emitted tree leaves unaccounted for.
  int lastCost = 0;

  // -- the ordering ----------------------------------------------------------

  /// Fewest edits; PEG's own reading ahead of any other of the same cost; among
  /// equals fewest DELETIONS, because destroying a character the input supplied
  /// contradicts evidence where a gap only records its absence; among those,
  /// the reading that EXPLAINS the most.
  static int _rank(_Way a, _Way b) {
    final ea = a.del + a.gap, eb = b.del + b.gap;
    if (ea != eb) return ea - eb;
    if (a.peg != b.peg) return a.peg ? -1 : 1;
    if (a.del != b.del) return a.del - b.del;
    return b.net - a.net;
  }

  /// One way per end position -- the best -- and one PEG way in the cell.
  ///
  /// Every distinct end is kept, because which one an enclosing clause needs is
  /// not knowable here: `Character*` must offer to stop at every position for
  /// `String` to find the one where its closing quote belongs. What is dropped
  /// is only a worse way to an end some better way already reaches.
  ///
  /// A shorter PEG reading is not one: the frozen parser would have grown past
  /// it. Demoting rather than deleting keeps it available as a repair.
  static List<_Way> _prune(List<_Way> ws) {
    if (ws.length <= 1) return ws;
    final best = <int, _Way>{};
    var far = -1;
    for (final w in ws) {
      if (w.peg && w.end > far) far = w.end;
      final b = best[w.end];
      if (b == null || _rank(w, b) < 0) best[w.end] = w;
    }
    final out = [
      for (final w in best.values) w.peg && w.end != far ? w.demoted : w
    ]..sort(_rank);
    if (out.length <= _CAP) return out;
    final head = out.sublist(0, _CAP);
    var deep = out.first;
    for (final w in out) {
      if (w.end > deep.end) deep = w;
    }
    if (!head.contains(deep)) head[_CAP - 1] = deep;
    return head;
  }

  // -- the parser ------------------------------------------------------------

  /// Every way [c] can be read from [pos], memoized, with the frozen parser's
  /// left-recursion loop around it.
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const [];
    final e = (_memo[c] ??= {}).putIfAbsent(pos, _Cell.new);
    if (e.inPath) {
      if (e.has) return e.ways;
      // Re-entered on the same path with nothing yet decided: the seed of a
      // left-recursive cycle. Answer with nothing, and tell the frame that
      // owns this cell -- however far above -- to expand it.
      e.foundLR = true;
      e.has = true;
      return e.ways = const [];
    }
    if (e.has && e.gen == _version[pos]) return e.ways;
    e.inPath = true;
    while (true) {
      // Accumulate: an expansion computed from a smaller seed is still a real
      // derivation, and keeping it makes the sequence of answers monotone, so
      // "while it improves" is guaranteed to stop.
      final got = _prune([..._expand(c, pos), ...e.ways]);
      final done = e.has && !_improved(got, e.ways);
      e.ways = got;
      e.has = true;
      if (done || !e.foundLR) break;
      e.gen = ++_version[pos];
    }
    e.inPath = false;
    e.gen = _version[pos];
    return e.ways;
  }

  /// Both ways an answer can get better: reaching further, or costing less.
  static bool _improved(List<_Way> a, List<_Way> b) {
    if (b.isEmpty) return a.isNotEmpty;
    if (a.isEmpty) return false;
    var ra = -1, rb = -1;
    for (final w in a) {
      if (w.end > ra) ra = w.end;
    }
    for (final w in b) {
      if (w.end > rb) rb = w.end;
    }
    return ra > rb || _rank(a.first, b.first) < 0;
  }

  List<_Way> _expand(Clause c, int pos) {
    if (c is Ref) return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    if (c is Seq) return _seq(c, pos);
    if (c is First) return _first(c, pos);
    if (c is Repetition) return _rep(c, pos);
    if (c is Optional) return _opt(c, pos);
    // A predicate consumes nothing, so it can carry no repair anywhere the
    // enclosing parse could see it. It is asked of the input as it stands.
    if (c is FollowedBy || c is NotFollowedBy) {
      final sub = c is FollowedBy ? c.subClause : (c as NotFollowedBy).subClause;
      final ok = _ways(sub, pos).any((w) => w.free);
      return (c is FollowedBy) == ok
          ? [_Way(pos, 0, 0, 0, true, Match(c, pos, 0))]
          : const [];
    }
    return _terminal(c, pos);
  }

  /// Put the rule's own node around each of its body's ways -- and drop the
  /// ways that would make that node an invention.
  ///
  /// A repaired node that EXPLAINS NOTHING is one. r2 refused only the node
  /// covering no characters at all, which is the special case where explaining
  /// nothing is obvious: a zero-width `Value` claims an object or an array or a
  /// number happened with not one character to show for it. But `[1,[2,` read
  /// as a String claims exactly as little while covering six characters, since
  /// both of its quotes were supplied by the repair and every character between
  /// them went to `[^"\]`, which accepts anything. Neither reading is evidenced,
  /// and [_Way.net] already counts the evidence, so both are the same refusal.
  ///
  /// It is honest where the grammar FIXES what the construct would have looked
  /// like -- `'}'`, or an `A <- [ab]` that is one leaf either way -- because
  /// then the mark claims nothing the grammar had not already said.
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) => [
        for (final w in ways)
          if (w.net > 0 || w.free || _determined(c))
            _Way(w.end, w.del, w.gap, w.net, w.peg,
                _wrap(c, pos, w.end, [w.node!], const []))
      ];

  /// A sequence: carry the chains forward slot by slot, and where a slot cannot
  /// be read at the position the last one left, either discard the characters
  /// in front of it or record it as unmet.
  List<_Way> _seq(Seq c, int pos) {
    var cur = <_Way>[_Way(pos, 0, 0, 0, true, null)];
    for (final sub in c.subClauses) {
      final next = <_Way>[];
      for (final w in cur) {
        final here = _ways(sub, w.end);
        for (final v in here) {
          next.add(_Way(v.end, w.del + v.del, w.gap + v.gap, w.net + v.net,
              w.peg && v.peg, v.node, w));
        }
        // Discarding input in front of a slot is offered only where the slot
        // cannot be read where it stands. Offering it anyway would let any
        // sequence buy length by throwing the input away.
        if (here.any((v) => v.free)) continue;
        // And only as far as the FIRST position where it can be read cleanly.
        // Discarding more costs strictly more, so the nearest place the slot
        // reappears is the cheapest resynchronization there is; scanning past
        // it would price the same repair several ways over.
        for (var k = w.end + 1; k <= _in.length; k++) {
          final at = _ways(sub, k).where((v) => v.free);
          if (at.isEmpty) continue;
          for (final v in at) {
            next.add(_Way(v.end, w.del + v.del + k - w.end, w.gap + v.gap,
                w.net + v.net, false, v.node, w,
                SyntaxError(pos: w.end, len: k - w.end)));
          }
          break;
        }
      }
      if (next.isEmpty) return const [];
      cur = _prune(next);
    }
    return [
      for (final w in cur)
        _Way(w.end, w.del, w.gap, w.net, w.peg, _close(c, pos, w))
    ];
  }

  /// An ordered choice. Every arm contributes, so a later arm can carry the
  /// parse where an earlier one is damaged -- but PEG is exact where nothing is
  /// damaged: once an arm reads cleanly, no later arm's reading is PEG's.
  List<_Way> _first(First c, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in c.subClauses) {
      final ws = _ways(s, pos);
      for (final w in ws) {
        out.add(_Way(w.end, w.del, w.gap, w.net, w.peg && !settled,
            _wrap(c, pos, w.end, [w.node!], const [])));
      }
      settled = settled || ws.any((w) => w.peg);
    }
    return out;
  }

  /// A repetition as reachability: every end an iteration chain can reach.
  ///
  /// Only iterations that ADVANCE are chained, which is both what stops `()*`
  /// from looping forever and what bounds this: each step strictly increases
  /// the end position, so no chain is longer than the input.
  List<_Way> _rep(Repetition c, int pos) {
    final zero = _Way(pos, 0, 0, 0, true, null);
    var frontier = <_Way>[zero];
    final all = <_Way>[if (!c.requireOne) zero];
    while (frontier.isNotEmpty) {
      final grown = <_Way>[];
      for (final w in frontier) {
        for (final v in _ways(c.subClause, w.end)) {
          if (v.end <= w.end) continue;
          grown.add(_Way(v.end, w.del + v.del, w.gap + v.gap, w.net + v.net,
              w.peg && v.peg, v.node, w));
        }
      }
      if (grown.isEmpty) break;
      frontier = _prune(grown);
      all.addAll(frontier);
    }
    return [
      for (final w in all)
        _Way(w.end, w.del, w.gap, w.net, w.peg, _close(c, pos, w))
    ];
  }

  List<_Way> _opt(Optional c, int pos) {
    final ws = _ways(c.subClause, pos);
    return [
      _Way(pos, 0, 0, 0, !ws.any((w) => w.peg), Match(c, pos, 0)),
      for (final w in ws)
        _Way(w.end, w.del, w.gap, w.net, w.peg,
            _wrap(c, pos, w.end, [w.node!], const []))
    ];
  }

  /// A terminal reads the input, or -- where the input does not carry it -- is
  /// recorded as one obligation the input never supplied. Nothing is spelled,
  /// so no character of an absent class is ever invented.
  List<_Way> _terminal(Clause c, int pos) {
    final len = _len(c, pos);
    if (len >= 0) {
      final n = c is Str || c is Char || (c is CharSet && !c.inverted) ? len : 0;
      return [_Way(pos + len, 0, 0, n, true, Match(c, pos, len))];
    }
    return [
      _Way(pos, 0, 1, 0, false,
          Repaired(c, pos, 0, const [], [SyntaxError(pos: pos, len: 0)]))
    ];
  }

  /// How many characters [c] matches at [pos], or -1 for a mismatch.
  int _len(Clause c, int pos) {
    if (c is Str) {
      if (pos + c.text.length > _in.length) return -1;
      for (var i = 0; i < c.text.length; i++) {
        if (_in.codeUnitAt(pos + i) != c.text.codeUnitAt(i)) return -1;
      }
      return c.text.length;
    }
    if (c is Char) {
      return pos < _in.length && _in.codeUnitAt(pos) == c.char.codeUnitAt(0)
          ? 1
          : -1;
    }
    if (c is CharSet) {
      if (pos >= _in.length) return -1;
      final ch = _in.codeUnitAt(pos);
      var inSet = false;
      for (final (lo, hi) in c.ranges) {
        if (ch >= lo && ch <= hi) {
          inSet = true;
          break;
        }
      }
      return (c.inverted ? !inSet : inSet) ? 1 : -1;
    }
    if (c is AnyChar) return pos >= _in.length ? -1 : 1;
    if (c is Nothing) return 0;
    throw StateError('unknown clause type ${c.runtimeType}');
  }

  /// Collect a chain's children and marks, and put [c]'s node around them.
  static MatchResult _close(Clause c, int pos, _Way w) {
    final kids = <MatchResult>[];
    final errs = <SyntaxError>[];
    for (_Way? p = w; p != null; p = p.prev) {
      if (p.node != null) kids.add(p.node!);
      if (p.mark != null) errs.add(p.mark!);
    }
    return _wrap(c, pos, w.end, kids.reversed.toList(), errs.reversed.toList());
  }

  /// A node for [c] over `[pos, end)`: the plain match where nothing was
  /// repaired, and one that can carry the marks where something was.
  static MatchResult _wrap(Clause c, int pos, int end, List<MatchResult> kids,
      List<SyntaxError> errs) {
    if (errs.isEmpty && kids.isNotEmpty && kids.first.pos == pos) {
      return Match(c, pos, end - pos, subClauseMatches: kids);
    }
    return Repaired(c, pos, end - pos, kids, errs);
  }

  // -- honesty ---------------------------------------------------------------

  /// Whether every string [c] derives yields the same tree shape.
  ///
  /// A clause the grammar pins to one shape stands for a hole whose contents
  /// were never in question -- `'}'`, or an `A <- [ab]` that is one leaf either
  /// way -- so marking it absent claims nothing the grammar had not said. A
  /// clause with a choice in it does not. Choice is the whole of the
  /// difference, so `First`, `Repetition` and `Optional` are the whole of the
  /// exclusion; a predicate contributes no node at all.
  ///
  /// A rule that re-enters itself reads false while in progress, which refuses
  /// a fill rather than wrongly allowing one.
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

  // -- the entry point -------------------------------------------------------

  /// Parse [s], recovering from syntax errors. Always covers the whole input.
  MatchResult recover(String s) {
    _in = s;
    _memo.clear();
    _version = List.filled(s.length + 1, 0);

    // The answer is the cheapest way to the end of the input. Where none
    // reaches it, the cheapest way overall is kept and the tail it never
    // reached is charged as discarded -- a real derivation is not thrown away
    // because the input stopped before its end.
    _Way? best;
    for (final w in _ways(rules[topRuleName]!, 0)) {
      final a = _Way(w.end, w.del + (s.length - w.end), w.gap, w.net, w.peg,
          w.node);
      if (best == null || _rank(a, best) < 0) best = a;
    }
    final root = best == null
        ? Repaired(
            null, 0, s.length, const [], [SyntaxError(pos: 0, len: s.length)])
        : best.end == s.length
            ? best.node!
            : Repaired(null, 0, s.length, [best.node!],
                [SyntaxError(pos: best.end, len: s.length - best.end)]);
    // Read the cost off the tree, so what is charged is exactly what the tree
    // says and nothing the emit did not keep.
    final (del, gap) = _edits(root);
    lastCost = del + gap;
    return root;
  }

  /// Edits recorded inside [m]: a skipped span deletes its characters, and a
  /// zero-width mark is one obligation the input never supplied.
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
