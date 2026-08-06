// m72 -- THE WRITE KNOWS ITS OWN REASON: m71 verbatim, with the one integer
// the relaxation already held at the moment it committed a value kept instead
// of thrown away, which deletes the search that was re-deriving it.
//
//   I29 THE WRITE KNOWS ITS OWN REASON, AND A REASON RECORDED AT A STRICT
//       IMPROVEMENT CANNOT CLOSE A CYCLE. Every value in the memo is written
//       by exactly one funnel, `_put` -> `_keepBest`, and `_keepBest` writes
//       ONLY on a strict improvement in `(cost, regret)`: an equal entry is
//       refused. At that instant the predecessor that produced the value is a
//       local variable -- the spine's `headKey`, the alternation's branch
//       index, or one of five leaf shapes. m71 discards it and `_reconstruct`
//       spends 217 lines getting it back: it re-runs `_ends` for every
//       alternative and every head candidate, sorts them, checks whether the
//       arithmetic reproduces `(cost, regret)`, and backtracks when it does
//       not. That is a search for something that was in hand.
//
//       Keeping it costs one int per memo entry. What that buys is not just
//       the deletion of the search but the deletion of the DOUBT: the chain
//       cannot cycle, so there is nothing to guard against. Suppose at the
//       fixed point the back-pointers formed a cycle. Each edge adds a
//       non-negative increment, so summing around the cycle forces every
//       increment to zero and every value on it equal. Take the cell on the
//       cycle written LAST, at time t. That write was a strict improvement,
//       so the cell's value strictly dropped at t. But some cell on the cycle
//       consumed this one's value BEFORE t, hence a strictly larger one, so
//       that cell's value is strictly greater than the cycle's common value
//       -- contradicting equality. A back-pointer closes a cycle only if the
//       cycle has strictly negative weight, and every weight here is >= 0.
//
//       So `_path`, the candidate sort, the two backtrack arms, `_deltaOf`
//       and `_ends` all exist only because the reason was thrown away. The
//       reconstruction becomes a pointer chase, and `_build` can no longer
//       fail to find a witness for a cost the search reported -- the witness
//       is constructed by the same writes that produced the cost. `_verify`
//       stays, because I5 checks the witness against the REAL parser, which
//       is a different question from whether the search was self-consistent.
//
// Below is m71's header, verbatim, since everything else is m71's.
//
// m71 -- REACHING A BRANCH IS A CLAIM THAT THE ONES BEFORE IT FAILED, AND A
// CLAIM COSTS NOTHING UNTIL SOMEBODY DOUBTS IT: m62 verbatim, with the
// constructs that were skipping PEG's commitment put back under it, and the
// price of doing so charged only where it buys something.
//
//   I27 A GREEDY CONSTRUCT IS A COMMITMENT, AND SO IS EVERY BRANCH AFTER THE
//       FIRST. PEG has three greedy constructs and m62 desugars them into two
//       node types: `First` and `Optional` become `_Alt`, and `Repetition`
//       becomes a `_Cons` self-loop. `_Alt` results go through `_mergeAlt`,
//       which holds I3's veto -- at cost 0 the input is unrepaired, so the
//       ORACLE is authoritative about where PEG commits. The self-loop's stop
//       went through `_put` directly and never met that veto. So conformance
//       was never about the star at all: it was about which of two desugarings
//       a construct happened to land in.
//
//       The law under both is one law. Ordered choice is possessive, so branch
//       `i` is legal exactly where branches `0..i-1` all fail; and `A*` is
//       `X <- A X / eps`, which makes the star's stop that law's degenerate
//       case -- the eps branch after one loop body. `!A`, for a one-character
//       `A`, is a condition the obligation channel already states: the
//       complement of the branch's class, plus the end mark, which is
//       literally what `_looks` computes for `NotFollowedBy`. Meeting it into
//       the obligation makes the branch carry its own proof, and an empty meet
//       means no repaired character can satisfy both, so the branch does not
//       exist. Aggregation is what found the generalisation: after the star
//       was fixed, 138 of the 264 surviving failures were on a grammar with no
//       star in it.
//
//       This is why the whole conformant family needed a tape. The relaxed
//       core OVER-accepts: `'a'* "ab"` has an EMPTY language (any `ab` the
//       star could stop before, it would have eaten), so the true answer is
//       "no repair at any cost" and a CFG star answers 0. m65-m70 recover the
//       difference AFTERWARDS, by enumerating repaired strings until the
//       oracle certifies one -- exact, but it costs ~350 lines and two rungs
//       of stack depth. Under I27 the core does not over-accept in the first
//       place, and the contradiction falls out of one class intersection.
//
//   I28 A PROOF IS WORTH MORE THAN A TIGHTER SEARCH, SO ASK FOR THE PROOF
//       FIRST AND PAY FOR THE TIGHTENING ONLY WHEN IT DOES NOT ARRIVE. I27 is
//       not free: the obligation is part of the memo key, so narrowing it
//       fragments the memo -- measured at 1.35x cells and 1.58x time on the
//       worst latency case. But the guards only ever DELETE repairs, so the
//       guarded search can only price the same as the unguarded one or HIGHER.
//       With I5 already saying the witness is a proof, a cheap answer whose
//       witness verifies is a repair that genuinely exists at a price the
//       guards could not have beaten -- so there is nothing left for them to
//       win. Run relaxed, demand the certificate, re-run tight exactly when it
//       fails to come. Not a router between two engines: one engine asked
//       twice. On a grammar that never fakes a commitment the second pass
//       never runs, and I27 costs nothing -- 343.7 latms back to 198.5, with
//       every answer unchanged on 2387 brute-force-truth inputs.
//
//   I26 THE RECONSTRUCTION IS A PASS TOO (m70's, and I28 is what makes m71
//       need it). Demanding the certificate on the COST path means
//       `recoverCost` reconstructs, and a native witness descent is as deep as
//       the input: LRmax fell 4096 -> 1024 the moment I28 landed, with the
//       overflow inside `_build <- _child <- _row`. So `_build`/`_child`/`_row`
//       become one `_RFrame` driver and `_cleanRegret`/`_collect`/`_emit`
//       become explicit walks, exactly as in m70. A reader that ended in a
//       tail call re-labels its frame instead of pushing one.
//
//       And it buys more than it was called in for, because the LRmax/RRmax
//       column was measuring half an answer: `final_table`'s ladder calls
//       `recoverCost`, and m62 returns a number there WITHOUT reconstructing.
//       Ask each engine for the whole answer instead -- `recover`, the entry
//       point a caller uses -- and m62 tops out at 1024 on BOTH ladders while
//       m71 reaches >=4096 on both (`_witdepth71.dart`). m62's depth advantage
//       over the conformant line was the column declining to ask it for the
//       thing that breaks it; I26 is a 4x ceiling on the call that matters.
//
// Measured against m62 on the conformance gate: 3/5 -> 5/5, and the two cases
// it turns are the two the entire m65-m70 tape line exists to answer. On
// `_floor`'s 2387 brute-force-truth inputs over 14 adversarial grammars, m62
// is wrong on 324 and m71 on 98: 226 fixed, ZERO regressed.
//
// THE HONEST LIMIT, and it is where all 98 live. `_oneCharClass` returns null
// for a multi-character branch, and a one-character obligation cannot state
// `!A` for those, so they stay free -- m62's behaviour, unchanged and still
// wrong there. Over-stating it (demanding `char not in first(A)`) would be
// SUFFICIENT for `A` to fail but not NECESSARY, and would forbid legal parses.
//
// `_starwide71.dart` pins that down with a named grammar instead of a caveat.
// `("ab")* "abc"` is the exact multi-character analogue of the conformance
// case, and its language is empty for the same reason -- the star is
// possessive, so wherever "abc" could match, the star has already eaten its
// "ab" -- so the truth is -1 on EVERY input. m71 answers 3, 2, 0, 0, 1 there:
// identical to m62, wrong on all five, where m70 returns -1. Two things the
// probe settles that assertion could not. `('a')* "ab"` -- a one-character body
// wearing a group -- IS fixed, so it is true WIDTH that decides and not
// syntactic shape. And `("ab")* "cd"`, whose language is non-empty, keeps
// answering finite verified costs, so dropping the obligation on wide bodies
// costs nothing where the follower is disjoint from the body. The two wide star
// bodies already in `_floor`'s corpus are of exactly that harmless kind, which
// is why both engines were always exact on them.
//
// 97 of the 98 are one grammar whose lookahead is multi-character, which is a
// DIFFERENT hole: a non-fusable lookahead is an oracle call against the RAW
// input, so it cannot see the repair. `_resid71.dart` classifies all 98 and
// every one is OVER-priced or rejected, never under-priced -- so no further
// ladder rung can reach them, and only a tape that re-judges the lookahead
// against the repaired string can. That is the 473 lines m70 spends and m71
// does not.
//
// Below is m62's header, verbatim, since everything else is m62's.
//
// m62 -- THE MEMO HOLDS FACTS; THE STACK HOLDS THE PASS: m60's recurrence,
// ladder, budget and walk, with the continuation lifted OUT of the memo entry
// onto one explicit frame stack. (Codex's ranked-first candidate of the
// twentieth occasion, built and measured here.)
//
//   I18 THE ENTRY IS A FACT; THE PASS IS A FRAME. Of m60's ten entry fields,
//       six describe the pass in flight (budget, pc, headEntry, foundCycle,
//       improved, parent) and only three describe durable knowledge (value,
//       settledBudget, version). Move the pass onto an explicit DFS stack:
//       the stack's adjacency IS the parent pointer, `running` derives from
//       membership (activeDepth >= 0), and a descendant that reaches an
//       active entry finds the ancestral FRAME by index and sets ITS
//       foundCycle bit -- the same O(1) descendant-to-ancestor message, with
//       the transient half of the coroutine no longer stored per cell. The
//       memo table keeps facts; the chain keeps state; neither pays for the
//       other.
//
// Everything else is m60 verbatim: the curried normal form; I2's lies with
// deletion as SUB on Nothing; I3's oracle veto; I6/I7's obligation channel;
// I5's verified witness; Delta as the pair (cost, regret) lexicographic; the
// budget as A3's filter, the deepening ladder, the budget-zero oracle walk,
// and the derived ceiling `n + fabricate(goal)` with its predicate tiers.
//
// PARAMETERS: NONE. HEURISTICS: shortest-head witness tie-break (output),
// I4's fusion (work), whole-input span on witness failure (presentation).
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;


/// log2 of the code-point alphabet, in millibits: what a FAB asserts.
const _widestClass = 20087;

int _width(Clause? clause) {
  if (clause is AnyChar) return _widestClass;
  if (clause is! CharSet) return 0;
  var size = 0;
  for (final (lo, hi) in clause.ranges) {
    size += hi - lo + 1;
  }
  size = clause.inverted ? 0x110000 - size : size;
  return size <= 1 ? 0 : (math.log(size) / math.ln2 * 1000).round();
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

  /// I1/I9: flat triples `[key, cost, regret, ...]`, written in place for the
  /// entry's whole life. Null = never computed (the left-recursion seed).
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
}

/// I26, and I28 is what makes m71 need it: the certificate is demanded on the
/// COST path now, so `recoverCost` reconstructs, and a native witness descent
/// is as deep as the input. `_Frame` above carries a pass of the SEARCH over
/// the fact table; this carries a pass of the RECONSTRUCTION over the same
/// table. `kind` picks which of the three mutually recursive readers the frame
/// runs -- 0 a node to one match (`_build`), 1 a node to the child list its
/// parent splices in (`_child`), 2 a `_Cons` spine to its children (`_row`) --
/// and `pc` is where it resumes when a frame it pushed returns. Every field
/// below is a local of the recursive original that had to outlive a call.
class _RFrame {
  _RFrame(this.kind, this.node, this.pos, this.key, this.cost, this.reg, this.c);

  /// Not final: where a reader ended in a TAIL call to another -- `_child` on
  /// a junk-headed spine, `_row` on a node that is not a spine -- the frame is
  /// re-labelled and reused rather than pushed, because a tail call adds no
  /// pending work and so deserves no frame of its own.
  int kind;
  final _Node node;
  final int pos, key, cost, reg, c;
  int pc = 0;

  /// I29: there is no `budget` and no cursor, because there is nothing to try.
  /// A spine reads where it split out of its own cell and keeps the head's
  /// answers only long enough to splice the tail's on.
  int headEnd = 0, headOwed = 0, headCost = 0, headReg = 0;
  List<MatchResult>? head;
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

  static const int _lastCodeUnit = 0xFFFF;

  List<(int, int)>? _oneCharClass(Clause clause,
          [Set<String> seen = const {}]) =>
      switch (clause) {
        AnyChar() => const [(0, _lastCodeUnit)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 =>
          [(text.codeUnitAt(0), text.codeUnitAt(0))],
        CharSet(:final ranges, :final inverted) =>
          inverted ? _complement(ranges) : ranges,
        First(:final subClauses) => () {
            final out = <(int, int)>[];
            for (final part in subClauses) {
              final ranges = _oneCharClass(part, seen);
              if (ranges == null) return null;
              out.addAll(ranges);
            }
            return out;
          }(),
        Ref(:final ruleName) when !seen.contains(ruleName) =>
          _oneCharClass(_rules[ruleName]!, {...seen, ruleName}),
        _ => null,
      };

  static List<(int, int)> _complement(List<(int, int)> ranges) {
    final out = <(int, int)>[];
    var next = 0;
    for (final (lo, hi) in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (lo > next) out.add((next, lo - 1));
      next = math.max(next, hi + 1);
    }
    if (next <= _lastCodeUnit) out.add((next, _lastCodeUnit));
    return out;
  }

  static List<(int, int)> _intersect(List<(int, int)> a, List<(int, int)> b) => [
        for (final (alo, ahi) in a)
          for (final (blo, bhi) in b)
            if (alo <= bhi && blo <= ahi)
              (math.max(alo, blo), math.min(ahi, bhi)),
      ];

  // ---- I6/I7: the obligation lattice (m59's, verbatim) ---------------------

  static const int _free = -1;
  static const int _endMark = -1;
  final List<List<(int, int)>> _classes = [];
  final Map<String, int> _classIndex = {};

  int _intern(List<(int, int)> ranges) {
    final norm = <(int, int)>[];
    for (final r in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (r.$2 < r.$1) continue;
      if (norm.isNotEmpty && r.$1 <= norm.last.$2 + 1) {
        if (r.$2 > norm.last.$2) norm[norm.length - 1] = (norm.last.$1, r.$2);
      } else {
        norm.add(r);
      }
    }
    final key = norm.map((r) => '${r.$1}-${r.$2}').join(',');
    return _classIndex[key] ??= (_classes..add(norm)).length - 1;
  }

  /// I27 made the obligation channel busy: a meet used to be rare, and is now
  /// on the path of every branch at every position. `_intern` costs a list
  /// intersection and a joined string key, so the pair of class ids -- both
  /// small integers -- is cached instead.
  final Map<int, int> _meetOf = {};

  int _meet(int a, int b) => a == _free
      ? b
      : b == _free || a == b
          ? a
          : _meetOf[(a << 20) | b] ??=
              _intern(_intersect(_classes[a], _classes[b]));

  /// An obligation no character can discharge. `_free` is a sentinel, not an
  /// index, so it can never be the empty class.
  bool _unmeetable(int c) => c != _free && _classes[c].isEmpty;

  bool _permits(int c, List<(int, int)>? emits) =>
      c == _free || (emits != null && _intersect(emits, _classes[c]).isNotEmpty);

  bool _has(int c, int ch) {
    for (final (lo, hi) in _classes[c]) {
      if (ch >= lo && ch <= hi) return true;
    }
    return false;
  }

  bool _permitsFirst(int c, int pos) =>
      c == _free || _has(c, _input.codeUnitAt(pos));

  bool _permitsEnd(int c) => c == _free || _has(c, _endMark);

  List<(int, int)>? _looks(Clause clause) => switch (clause) {
        FollowedBy(:final subClause) => _oneCharClass(subClause),
        NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
            final looked? => [..._complement(looked), (_endMark, _endMark)],
            null => null,
          },
        _ => null,
      };

  Clause? _fuse(Clause lookahead, Clause reader) {
    if (reader is! Terminal) return null;
    final reads = _oneCharClass(reader);
    if (reads == null) return null;
    final looks = _looks(lookahead);
    return looks == null ? null : CharSet(_intersect(looks, reads));
  }

  _Node _cons(List<Clause> parts, Clause orig) {
    final fused = <Clause>[];
    for (var i = parts.length - 1; i >= 0; i--) {
      final f = fused.isEmpty ? null : _fuse(parts[i], fused.first);
      if (f == null) {
        fused.insert(0, parts[i]);
      } else {
        fused[0] = f;
      }
    }
    var node = _eps;
    for (var i = fused.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(fused.sublist(i)))
        ..head = _node(fused[i])
        ..tail = node;
    }
    return node;
  }

  _Node _node(Clause clause) {
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
      final accepts = _oneCharClass(clause);
      final looks = _looks(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks == null ? _free : _intern(looks));
      node = looks == null ? _wrap(leaf, clause) : leaf;
    }
    return _nodes[clause] = node;
  }

  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  // ---- the derived ceiling (m53's `_goalFromNothing`, over 2-stride pairs) --
  //
  // A1's trivial repair always exists: discard the whole input, fabricate the
  // goal. Its fabrication count is a property of the grammar, priced per
  // obligation owed; a predicate is the one leaf that may not be counted
  // (tier 1), trusted only when every derivation needs one (tier 2), and if
  // even that fails the language is empty and the caller learns it with no
  // search (tier 3). See LESSONS 5n.

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

  late final int _goalFromNothing = () {
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
    int cheapest(bool trustPredicates) {
      final cost = <int, List<List<int>>>{};
      var improved = true;
      List<List<int>> row(int c) => cost.putIfAbsent(c, () {
            improved = true;
            return List.generate(_nodeCount, (_) => <int>[]);
          });
      List<int> chain(_Cons node, int c) {
        final out = <int>[];
        if (identical(node.tail, node)) _kb2(out, c, 0);
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
        if (node.demands != _free) return [_meet(c, node.demands), 0];
        final emits = node.editable ? _oneCharClass(node.orig) : null;
        if (emits != null && emits.isNotEmpty) {
          return _permits(c, emits) ? [_free, 1] : const [];
        }
        return node.editable ||
                node.orig is Nothing ||
                (trustPredicates && node.orig is! Terminal)
            ? [c, 0]
            : const [];
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
                  for (final alt in alts) {
                    final from = row(c)[alt.id];
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
      }
      var best = _impossible;
      final top = row(_free)[_goal.id];
      for (var i = 0; i < top.length; i += 2) {
        if (_permitsEnd(top[i]) && top[i + 1] < best) best = top[i + 1];
      }
      return best;
    }

    final sure = cheapest(false);
    return sure < _impossible ? sure : cheapest(true);
  }();

  static const int _impossible = 1 << 30;

  // ---- per-input state -----------------------------------------------------

  late Parser _parser;
  late String _input;
  late int _inputLen;
  late List<int> _regretPrefix;
  late List<int> _versionAtPos;
  final Map<int, int> _charRegret = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _cleanRegrets = {};
  MatchResult? _clean;
  int _steps = 0, _goalKey = -1, _goalCost = -1, _goalRegret = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;
  bool lastVerified = false;
  int get lastCells => _cells.length;
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

  int _skipRegret(int from, int to) => _regretPrefix[to] - _regretPrefix[from];
  int _widthOf(Clause clause) =>
      _widths.putIfAbsent(clause, () => _width(clause));

  void _buildRegretPrefix() {
    _regretPrefix = [0];
    for (var pos = 0; pos < _inputLen; pos++) {
      final ch = _input.codeUnitAt(pos);
      final narrowest = _charRegret.putIfAbsent(ch, () {
        final probe = Parser(
            rules: rules,
            topRuleName: topRuleName,
            input: String.fromCharCode(ch));
        var best = _widestClass;
        for (final terminal in _terminals) {
          if (terminal.match(probe, 0).len != 1) continue;
          best = math.min(best, _widthOf(terminal));
          if (best == 0) break;
        }
        return best;
      });
      _regretPrefix.add(_regretPrefix.last + narrowest);
    }
  }

  /// I26. A post-order sum over the match tree, on an explicit stack: the tree
  /// is as deep as the input, and this is called from inside the witness
  /// descent, so a native post-order here costs two depths at once. Pre-order
  /// into a list, then fold it backwards -- a parent precedes its children in
  /// pre-order, so the reverse reaches every child before its parent, which is
  /// all a post-order sum needs and costs one list rather than a flag per node.
  int _cleanRegret(MatchResult root) {
    final hit = _cleanRegrets[root];
    if (hit != null) return hit;
    // `_build` asks this of every node it visits, and the overwhelming majority
    // are leaves, so the walk's two lists would be allocated for nothing.
    if (root.subClauseMatches.isEmpty) {
      return _cleanRegrets[root] = _widthOf(root.clause!) * root.len;
    }
    final order = <MatchResult>[];
    final stack = <MatchResult>[root];
    while (stack.isNotEmpty) {
      final m = stack.removeLast();
      if (_cleanRegrets.containsKey(m)) continue;
      order.add(m);
      stack.addAll(m.subClauseMatches);
    }
    for (var i = order.length - 1; i >= 0; i--) {
      final m = order[i];
      final subs = m.subClauseMatches;
      var sum = 0;
      if (subs.isEmpty) {
        sum = _widthOf(m.clause!) * m.len;
      } else {
        for (final sub in subs) {
          sum += _cleanRegrets[sub]!;
        }
      }
      _cleanRegrets[m] = sum;
    }
    return _cleanRegrets[root]!;
  }

  // ---- the value: triples, written in place (m59's, verbatim) --------------

  /// I29. The fourth slot is the reason: whatever the relaxation had in hand
  /// when it committed this value. It is written by the same test that decides
  /// the value, so it can never describe a value that is not there.
  static bool _keepBest(List<int> out, int key, int cost, int reg, int why) {
    for (var i = 0; i < out.length; i += 4) {
      if (out[i] != key) continue;
      if (out[i + 1] < cost || (out[i + 1] == cost && out[i + 2] <= reg)) {
        return false;
      }
      out[i + 1] = cost;
      out[i + 2] = reg;
      out[i + 3] = why;
      return true;
    }
    out
      ..add(key)
      ..add(cost)
      ..add(reg)
      ..add(why);
    return true;
  }

  // I29's reason codes. A leaf is negative; a spine's reason is its head's
  // key and an alternation's is its branch index, both >= 0, and the cell's
  // own node type says which of the two to read it as.
  static const _wPure = -1; // the oracle's own match settles this cell
  static const _wTerm = -2; // a terminal: demanded, substituted or fabricated
  static const _wStop = -3; // a self-loop's zero-cost stop

  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Entry> _cells = {};
  int _posShift = 0, _span = 0;

  _Entry _entryAt(_Node node, int pos, int c) => _cells.putIfAbsent(
      (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos,
      () => _Entry(node, pos, c));

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
    // The budget-zero walk: the repaired string IS the input here and
    // everything after this entry is edit-free, so the oracle's one memoized
    // answer settles the whole subtree (LESSONS 5i/5m). No children.
    if (budget == 0) {
      if (f.pc == 0) {
        f.pc = 1;
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          // I27 again, and this is where it leaks if it is applied only to the
          // search. The walk is edit-free WITHIN this subtree, so the oracle
          // settles where the star ends -- but the TAIL is a different entry
          // with its own budget, and it can still fabricate at exactly the
          // position the star claimed to stop at. The stop's proof has to be
          // handed forward here too, or the search's obligation is discarded
          // by the very shortcut that was supposed to be exact.
          final loop = _guarded && node is _Cons && identical(node.tail, node)
              ? node
              : null;
          if (m.len == 0) {
            final owed = loop == null ? c : _notFirst(loop.head.orig, c);
            if (!_unmeetable(owed)) {
              _put(f, _key(pos, owed), 0, _cleanRegret(m), _wPure);
            }
          } else if (_permitsFirst(c, pos)) {
            final owed = loop == null ? _free : _notFirst(loop.head.orig, _free);
            if (!_unmeetable(owed)) {
              _put(f, _key(pos + m.len, owed), 0, _cleanRegret(m), _wPure);
            }
          }
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          _put(f, _key(pos, _meet(c, demands)), 0, 0, _wTerm);
          return _finish(f);
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(f, _key(pos, c), 0, _cleanRegret(m), _wPure);
          } else if (_permitsFirst(c, pos)) {
            _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m), _wPure);
          }
        }
        if (editable) {
          final emits = _oneCharClass(node.orig);
          final silent = emits == null || emits.isEmpty;
          if (silent || _permits(c, emits)) {
            final owed = silent ? c : _free;
            if (pos < _inputLen) {
              _put(f, _key(pos + 1, owed), 1, 2 * _skipRegret(pos, pos + 1),
                  _wTerm); // SUB
            }
            _put(f, _key(pos, owed), 1, _widestClass, _wTerm); // FAB
          }
        }
        return _finish(f);
      case _Alt(:final alts):
        final guards = _guarded ? _guardsOf(node) : null;
        while (f.pc < alts.length) {
          final owe = guards == null ? c : _meet(c, guards[f.pc]); // I27
          if (_unmeetable(owe)) {
            f.pc++; // no repaired character reaches this branch
            continue;
          }
          final child = _entryAt(alts[f.pc], pos, owe);
          if (child.activeDepth >= 0) {
            _stack[child.activeDepth].foundCycle = true; // the LR seed
          } else if (!_settled(child, budget)) {
            _push(child, budget);
            return; // park: the loop steps the new top next
          }
          _mergeAlt(f, alts.length, child, f.pc);
          f.pc++;
        }
        return _finish(f);
      case _Cons():
        final loops = identical(node.tail, node);
        if (f.pc == 0) {
          if (loops) {
            final owed = _guarded ? _notFirst(node.head.orig, c) : c; // I27
            if (!_unmeetable(owed)) _put(f, _key(pos, owed), 0, 0, _wStop);
          }
          final head = _entryAt(node.head, pos, c);
          if (head.activeDepth >= 0) {
            _stack[head.activeDepth].foundCycle = true;
          } else if (!_settled(head, budget)) {
            _push(head, budget);
            return; // park
          }
          f.headEntry = head;
          f.pc = 1;
        }
        final heads = f.headEntry!.value ?? const <int>[];
        while ((f.pc - 1) * 4 < heads.length) {
          final i = (f.pc - 1) * 4;
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (tail.activeDepth >= 0) {
            _stack[tail.activeDepth].foundCycle = true;
          } else if (!_settled(tail, rest)) {
            _push(tail, rest);
            return; // park
          }
          final rv = tail.value;
          if (rv != null) {
            for (var j = 0; j < rv.length; j += 4) {
              final total = hCost + rv[j + 1];
              if (total <= budget) {
                // I29: the head's key IS the reason -- it fixes where the
                // spine split, and the tail cell is then determined.
                _put(f, rv[j], total, hReg + rv[j + 2], headKey);
              }
            }
          }
          f.pc++;
        }
        return _finish(f);
    }
  }

  void _put(_Frame f, int key, int cost, int reg, int why) {
    if (_keepBest(f.entry.value!, key, cost, reg, why)) f.improved = true;
  }

  /// I28: A PROOF IS WORTH MORE THAN A TIGHTER SEARCH, SO ASK FOR THE PROOF
  /// FIRST AND PAY FOR THE TIGHTENING ONLY WHEN IT DOES NOT ARRIVE.
  ///
  /// I27's guards only ever DELETE repairs -- the ones the commitment law
  /// forbids -- so the guarded search can only ever price the same as the
  /// unguarded one or HIGHER: `costOff <= costOn`, always, with no appeal to
  /// what the true cost is. And I5 already says the witness is a proof. So if
  /// the cheap pass's witness verifies, its answer is a repair that genuinely
  /// exists, at a price the guarded pass could not have beaten -- there is
  /// nothing left for the guards to win, and running them is pure cost. The
  /// only answers they can improve are the ones arriving with no proof, which
  /// is exactly the fake commitment I27 was built to delete: a repair leaning
  /// on one cannot be re-parsed by the pure parser, so it can never certify.
  ///
  /// (Note what this deliberately does NOT claim. `costOff <= costTrue` would
  /// make a certified answer provably MINIMAL, and it is false in general --
  /// a non-fusable lookahead is an oracle call against RAW input, so both
  /// passes can over-price, which is the residual below. The argument above
  /// needs only the comparison between the two passes, so it survives that
  /// hole intact.)
  ///
  /// So this is not a heuristic router between two engines, it is one engine
  /// asked twice: relax, demand the certificate, and re-run tight exactly when
  /// the certificate fails to appear. On a grammar that never fakes a
  /// commitment -- every real one -- the second pass never runs, and I27 costs
  /// nothing at all. It is the same shape as the ladder itself, which prices a
  /// bound and stops the moment a witness attains it; I28 is that rule applied
  /// to the LAW rather than to the budget.
  bool _guarded = false;

  /// I27: reaching a branch is a claim that the branches before it failed.
  ///
  /// Ordered choice is possessive, so branch `i` is legal exactly where
  /// branches `0..i-1` all fail -- and `A*` is `X <- A X / eps`, so a star's
  /// stop is that same law's degenerate case, the eps branch after one loop
  /// body. `_mergeAlt` already enforces it at cost 0, by asking the oracle
  /// where PEG committed; above cost 0 the input is repaired and the oracle
  /// has nothing to say, so the claim has to travel forward as an obligation
  /// on the character that will sit here after repair.
  ///
  /// `!A` is statable in that channel exactly when `A` reads one character:
  /// the complement of its class plus the end mark, which is what `_looks`
  /// already builds for `NotFollowedBy`. For a longer `A` the complement is
  /// SUFFICIENT for `A` to fail but not necessary, so asserting it would
  /// forbid legal parses -- those branches are left free, which is m62's
  /// behaviour, and is also what keeps `_junk` (a self-loop over `Nothing`:
  /// the recovery mechanism, not a PEG star) entirely unconstrained.
  /// `!branch` depends only on the branch, so it is interned once per clause.
  /// `_free` caches "not statable in one character", and since meeting with
  /// `_free` is the identity that case needs no test of its own -- an
  /// inexpressible `!A` leaves the obligation exactly as m62 left it.
  final Map<Clause, int> _notFirstOf = {};

  int _notFirst(Clause branch, int carried) => _meet(
      carried,
      _notFirstOf[branch] ??= switch (_oneCharClass(branch)) {
        final looked? => _intern([..._complement(looked), (_endMark, _endMark)]),
        null => _free,
      });

  /// The running obligation down an `_Alt`'s branch list, cached per node.
  ///
  /// A branch that reads one character can never violate a guard its own class
  /// already satisfies -- `Escape <- '"' / '\\' / '/' / ...` is nine of those --
  /// and since the obligation is part of the memo key, carrying a guard that
  /// cannot fire splits every cell below it for nothing. Dropping it is not an
  /// approximation: the branch emits and reads only from its own class, so the
  /// guard is implied by taking the branch at all.
  List<int> _guardsOf(_Alt node) {
    final known = node.guards;
    if (known != null) return known;
    final g = <int>[];
    var acc = _free;
    for (final a in node.alts) {
      final emits = acc == _free ? null : _oneCharClass(a.orig);
      final e = emits == null ? _free : _intern(emits);
      g.add(e != _free && _meet(acc, e) == e ? _free : acc);
      acc = _notFirst(a.orig, acc);
    }
    return node.guards = g;
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(_Frame f, int altCount, _Entry branch, int ai) {
    final v = branch.value;
    if (v == null) return;
    final budget = f.budget;
    var committed = -2;
    for (var i = 0; i < v.length; i += 4) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.match(f.entry.node.orig, f.entry.pos);
          committed = oracle.isMismatch ? -1 : f.entry.pos + oracle.len;
        }
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          continue;
        }
      }
      _put(f, key, cost, v[i + 2], ai); // I29
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

  // ---- I29: reconstruction as a pointer chase ------------------------------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  /// The cell a reason names, read WITHOUT creating it. Reconstruction only
  /// ever revisits cells the search already wrote, so a miss is a bug, not a
  /// case: `_entryAt` would paper over it with a fresh empty entry.
  _Entry? _cellAt(_Node node, int pos, int c) =>
      _cells[(((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos];

  /// `(cost, regret, why)` at one key of one cell. This is the whole of what
  /// m71 spent `_ends`, `_deltaOf`, a sort and two backtrack arms deriving.
  (int, int, int)? _reasonAt(_Node node, int pos, int c, int key) {
    final v = _cellAt(node, pos, c)?.value;
    if (v == null) return null;
    for (var i = 0; i < v.length; i += 4) {
      if (v[i] == key) return (v[i + 1], v[i + 2], v[i + 3]);
    }
    return null;
  }

  /// I29's reason is a SUFFICIENT explanation, not a canonical one, and the
  /// difference shows in exactly one place. The budget-zero walk settles a
  /// whole subtree with a single oracle call and records `_wPure`, but a cell
  /// first reached at a HIGHER budget never meets that shortcut -- the walk
  /// returns before the decomposition, so above zero the split is the only
  /// thing that ever writes. Both descriptions cover the same span at the same
  /// cost and regret. Prefer the oracle's, because its tree is the one this
  /// parser actually produces: `"ab"` is one match, not a chain of two, and a
  /// recovered tree that shows nodes the parser never emits is a worse answer
  /// even when it is priced identically.
  ///
  /// This is a canonical form, not a search. It is one memoized oracle call
  /// with no candidates and no backtracking, and when it declines, the
  /// recorded reason answers -- so it cannot reintroduce the doubt I29
  /// removed. `cost == 0` is what makes it safe: it never CREATES a repair,
  /// it only re-describes a cell the search already priced at zero, which is
  /// why applying it above budget zero does not leak past I27's guards.
  MatchResult? _wholesale(
      _Node node, int pos, int key, int cost, int reg, int c) {
    if (cost != 0) return null;
    final pure = pos > _inputLen ? mismatch : node.orig.match(_parser, pos);
    if (pure.isMismatch ||
        pos + pure.len != _endOf(key) ||
        _cleanRegret(pure) != reg) {
      return null;
    }
    // I27: the walk hands a self-loop's stop forward with `!A` attached, so
    // the key to recognise here is the guarded one.
    final loop =
        _guarded && node is _Cons && identical(node.tail, node) ? node : null;
    if (pure.len == 0) {
      final owed = loop == null ? c : _notFirst(loop.head.orig, c);
      return _oweOf(key) == owed ? pure : null;
    }
    final owed = loop == null ? _free : _notFirst(loop.head.orig, _free);
    return _oweOf(key) == owed && _permitsFirst(c, pos) ? pure : null;
  }

  /// I26: one pass of the witness descent, off the native stack. See `_RFrame`.
  MatchResult? _build(_Node node, int pos, int key, int cost, int reg, int c) =>
      _reconstruct(0, node, pos, key, cost, reg, c) as MatchResult?;


  Object? _reconstruct(
      int kind, _Node node0, int pos0, int key0, int cost0, int reg0, int c0) {
    final st = <_RFrame>[_RFrame(kind, node0, pos0, key0, cost0, reg0, c0)];
    // What the frame that just popped returned. `null` is failure, which is
    // unambiguous: an empty child list is `const []`, and `_build` never
    // answers with a list at all.
    Object? ret;
    while (st.isNotEmpty) {
      final f = st.last;
      final node = f.node;
      if (f.kind == 0) {
        // ---- `_build`: this node, at this key, as one match ---------------
        if (f.pc == 0) {
          // The canonical form first: when the oracle explains this cell
          // whole, its match IS the answer, whatever the reason says.
          final whole =
              _wholesale(node, f.pos, f.key, f.cost, f.reg, f.c);
          if (whole != null) {
            ret = whole;
            st.removeLast();
            continue;
          }
          final r = _reasonAt(node, f.pos, f.c, f.key);
          if (r == null) {
            ret = null;
            st.removeLast();
            continue;
          }
          final why = r.$3;
          // A terminal's reason answers for any node type, because a repaired
          // character stands in for whatever the node was going to read.
          if (why == _wTerm) {
            final accepts = f.c == _free ? null : _oneCharClass(node.orig);
            ret = Match(
                accepts == null
                    ? node.orig
                    : CharSet(_intersect(accepts, _classes[f.c])),
                f.pos,
                _endOf(f.key) - f.pos);
            st.removeLast();
            continue;
          }
          if (node is _Alt) {
            // `why` is the branch that won, and `_mergeAlt` copied the key
            // straight through, so the branch answers at the SAME key.
            final guards = _guarded ? _guardsOf(node) : null; // I27, as in search
            final owe = guards == null ? f.c : _meet(f.c, guards[why]);
            f.pc = 2;
            st.add(_RFrame(1, node.alts[why], f.pos, f.key, f.cost, f.reg, owe));
            continue;
          }
          f.pc = 2; // a spine, including a self-loop that stopped
          st.add(_RFrame(2, node, f.pos, f.key, f.cost, f.reg, f.c));
          continue;
        }
        // pc 2: the child list answered, and both node kinds wrap it the same.
        ret = ret == null
            ? null
            : Match(node.orig, f.pos, _endOf(f.key) - f.pos,
                subClauseMatches: ret as List<MatchResult>);
        st.removeLast();
        continue;
      }
      if (f.kind == 1) {
        // ---- `_child`: this node as the list its parent splices in --------
        if (f.pc == 0) {
          if (identical(node, _junk)) {
            final end = _endOf(f.key);
            ret = end == f.pos
                ? const <MatchResult>[]
                : <MatchResult>[SyntaxError(pos: f.pos, len: end - f.pos)];
            st.removeLast();
            continue;
          }
          if (node is _Cons && identical(node.head, _junk)) {
            f.kind = 2; // tail call: the spine's answer IS this frame's
            continue;
          }
          f.pc = 2;
          st.add(_RFrame(0, node, f.pos, f.key, f.cost, f.reg, f.c));
          continue;
        }
        ret = ret == null ? null : <MatchResult>[ret as MatchResult];
        st.removeLast();
        continue;
      }
      // ---- `_row`: a `_Cons` spine, as the flat child list ----------------
      if (f.pc == 0) {
        if (node is! _Cons) {
          if (identical(node, _eps)) {
            ret = f.key == _key(f.pos, f.c) && f.cost == 0 && f.reg == 0
                ? const <MatchResult>[]
                : null;
            st.removeLast();
            continue;
          }
          f.kind = 1; // tail call: not a spine, so it is one child
          continue;
        }
        final r = _reasonAt(node, f.pos, f.c, f.key);
        if (r == null || r.$3 == _wStop) {
          // A self-loop that stopped contributes no children; a miss is the
          // same shape as m71's exhausted candidate list.
          ret = r == null ? null : const <MatchResult>[];
          st.removeLast();
          continue;
        }
        if (r.$3 == _wPure) {
          // A leaf reason on a SPINE: the edit-free window settled the whole
          // subtree with one oracle call, so the spine was never split. `_row`
          // is reachable without passing through `_build` -- `_child` tail-
          // calls it for a junk-headed spine -- so this dispatch has to exist
          // on the list side too. A row is the children its parent splices,
          // and the children of a wholesale match are ITS children.
          //
          // Note this asks for the RECORDED reason and not `_wholesale`, which
          // would be wrong here: `_row` walks a spine's SUFFIX nodes, and a
          // suffix shares its `orig` with the whole sequence, so asking the
          // oracle about `orig` at the suffix's position asks about a clause
          // this node does not stand for. `_wPure` is only ever written where
          // `orig` does describe the node, which is why reading it is safe
          // where re-deriving it is not.
          final pure =
              f.pos > _inputLen ? mismatch : node.orig.match(_parser, f.pos);
          ret = pure.isMismatch ? null : pure.subClauseMatches;
          st.removeLast();
          continue;
        }
        // `why` is the head's key, which fixes the split, and with it the
        // tail's cell. Neither has to be searched for.
        final headKey = r.$3;
        final head = _reasonAt(node.head, f.pos, f.c, headKey);
        if (head == null) {
          ret = null;
          st.removeLast();
          continue;
        }
        f.headEnd = _endOf(headKey);
        f.headOwed = _oweOf(headKey);
        f.headCost = head.$1;
        f.headReg = head.$2;
        f.pc = 3;
        st.add(_RFrame(
            1, node.head, f.pos, headKey, head.$1, head.$2, f.c));
        continue;
      }
      if (f.pc == 3) {
        if (ret == null) {
          st.removeLast();
          continue;
        }
        f.head = ret as List<MatchResult>;
        f.pc = 4;
        st.add(_RFrame(2, (node as _Cons).tail, f.headEnd, f.key,
            f.cost - f.headCost, f.reg - f.headReg, f.headOwed));
        continue;
      }
      // pc 4: the tail answered.
      if (ret == null) {
        st.removeLast();
        continue;
      }
      ret = <MatchResult>[...f.head!, ...(ret as List<MatchResult>)];
      st.removeLast();
    }
    return ret;
  }


  /// I26. Pre-order, left to right, on an explicit stack: `_missing` is
  /// consumed in order, so children are pushed in reverse.
  void _collect(MatchResult root) {
    final stack = <MatchResult>[root];
    while (stack.isNotEmpty) {
      final m = stack.removeLast();
      final clause = m.clause;
      if (m is SyntaxError) {
        _spans.add(m);
      } else if (m.subClauseMatches.isEmpty &&
          clause is Terminal &&
          clause is! Nothing) {
        if (m.len == 0) {
          _missing.add(MissingObligation(clause, m.pos));
        } else if (clause.match(_parser, m.pos).isMismatch) {
          _spans.add(SyntaxError(pos: m.pos, len: m.len));
        }
      } else {
        final subs = m.subClauseMatches;
        for (var i = subs.length - 1; i >= 0; i--) {
          stack.add(subs[i]);
        }
      }
    }
  }

  /// I26. Source order, on an explicit stack. The work items are a match to
  /// emit or a `(from, to)` slice of the input to copy verbatim -- the gaps a
  /// recursive `_emit` wrote between its children -- pushed in reverse so they
  /// come off in source order.
  void _emit(MatchResult root, StringBuffer out) {
    final work = <Object>[root];
    while (work.isNotEmpty) {
      final item = work.removeLast();
      if (item is (int, int)) {
        out.write(_input.substring(item.$1, item.$2));
        continue;
      }
      final m = item as MatchResult;
      if (m is SyntaxError) continue;
      final clause = m.clause;
      if (m.subClauseMatches.isEmpty) {
        out.write(clause is Terminal &&
                clause is! Nothing &&
                (m.len == 0 || clause.match(_parser, m.pos).isMismatch)
            ? _spelling(clause)
            : _input.substring(m.pos, m.pos + m.len));
        continue;
      }
      final items = <Object>[];
      var cursor = m.pos;
      for (final child in m.subClauseMatches) {
        if (child.pos > cursor) items.add((cursor, child.pos));
        items.add(child);
        cursor = child.pos + child.len;
      }
      if (cursor < m.pos + m.len) items.add((cursor, m.pos + m.len));
      for (var i = items.length - 1; i >= 0; i--) {
        work.add(items[i]);
      }
    }
  }

  String _spelling(Clause clause) {
    final accepts = _oneCharClass(clause);
    if (accepts != null && accepts.isNotEmpty) {
      return String.fromCharCode(accepts.first.$1);
    }
    return clause is Str ? clause.text : '';
  }

  bool _verify(MatchResult root) {
    final out = StringBuffer();
    _emit(root, out);
    final s = out.toString();
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: s).parse();
    return !check.hasSyntaxErrors && check.root.len == s.length;
  }

  // ---- entry points --------------------------------------------------------

  MatchResult? _root;

  /// I28's question: does this answer carry its own proof? A clean parse is one
  /// by construction, and "no repair exists" needs none -- the relaxation
  /// admits every repair the tight search does, so finding none settles it.
  /// Everything else has to produce the witness and have the pure parser accept
  /// it. A relaxed 0 on an input the pure parse rejects is the cheapest failure
  /// of all: it claims a repair that edits nothing, and there is no tree to
  /// build, so the conformance cases are caught without reconstructing at all.
  bool _certified(int cost) {
    _spans.clear();
    _missing.clear();
    _root = null;
    lastVerified = false;
    if (cost < 0) return true;
    if (cost == 0) return lastVerified = _clean != null;
    _root = _build(_goal, 0, _goalKey, _goalCost, _goalRegret, _free);
    return lastVerified = _root != null && _verify(_root!);
  }

  SkipResult recover(String input) {
    final cost = recoverCost(input);
    if (cost == 0 && _clean != null) {
      return SkipResult(_clean!, const [], const [], 0, false);
    }
    final root = _root;
    if (root == null) {
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    _collect(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  /// I28. Relax, demand the certificate, tighten exactly when it fails to come.
  int tightRuns = 0; // INSTRUMENT ONLY (see _tight72.dart)
  int recoverCost(String input) {
    _guarded = false;
    final relaxed = _pass(input);
    if (_certified(relaxed)) return relaxed;
    _guarded = true;
    tightRuns++;
    final tight = _pass(input);
    _certified(tight);
    return tight;
  }

  int _pass(String input) {
    _input = input;
    _inputLen = input.length;
    _clean = null;
    final goal = _goal;
    final maxCost =
        _goalFromNothing < _impossible ? _inputLen + _goalFromNothing : -1;
    _posShift = (_inputLen + 2).bitLength;
    _span = 1 << _posShift;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildRegretPrefix();
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cells.clear();
    _stack.clear();
    _depth = -1;
    _cleanRegrets.clear();
    _steps = 0;
    // The ladder, with A3's filter: one memo serves every round.
    for (var k = 0; k <= maxCost; k++) {
      final goalEntry = _entryAt(goal, 0, _free);
      _run(goalEntry, k);
      final v = goalEntry.value;
      if (v == null) continue;
      var bestC = _impossible, bestR = _impossible;
      for (var i = 0; i < v.length; i += 4) {
        if (_endOf(v[i]) != _inputLen || !_permitsEnd(_oweOf(v[i]))) continue;
        if (v[i + 1] < bestC || (v[i + 1] == bestC && v[i + 2] < bestR)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          _goalKey = v[i];
        }
      }
      if (bestC < _impossible) {
        _goalCost = bestC;
        _goalRegret = bestR;
        lastCost = bestC;
        lastRegret = bestR - _skipRegret(0, _inputLen);
        lastSteps = _steps;
        return bestC;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}

/// Probe hook for `_lat71.dart`: an extension in the same library can read
/// library-private state, so this costs the engine nothing and sits OUTSIDE
/// the LOC markers.
extension CellCount on SuperDot3 {
  int get cellCount => _cells.length;
}
