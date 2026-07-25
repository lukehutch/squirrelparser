// m41 -- recovery is the parser, over a wider value, plus THREE INSERTIONS.
//
// Read this file next to `lib/src/parser/memo_entry.dart` and
// `lib/src/parser/combinators.dart`. It is those two files with three things
// added and nothing else changed.
//
//   I1  THE VALUE.  A match becomes "the cheapest repair to each end position";
//       a mismatch becomes the empty set. The parser's fixed-point test -- "the
//       match did not get longer" -- becomes "no end is new and no price is
//       lower". Every other line of `MemoEntry` is copied verbatim, so LEFT
//       RECURSION IS SOLVED FOR RECOVERY BY THE OBSERVATION THAT SOLVED IT FOR
//       PARSING, and there is no cycle reasoning anywhere below. See `_Entry`.
//
//   I2  A TERMINAL MAY LIE.  One that does not match may consume a character
//       anyway (SUB), or consume nothing (FAB). Price 1 each.
//
//   I3  A SEQUENCE MAY DISCARD.  Before any element, one character may be
//       consumed by no terminal at all (SKIP, price 1), and the same element is
//       retried. Only a sequence has a "between", so this is the only combinator
//       that carries any recovery logic at all.
//
// I3 wants a memo entry per element boundary, which the parser does not have --
// it memoizes whole clauses. CURRYING SUPPLIES IT FOR FREE: a sequence is a
// chain of binary cells `Cons(head, tail)`, so every element boundary already IS
// a clause and the memo key is (clause, position), exactly the parser's. No dot,
// no dot-indexed memo blocks, no per-clause dot arithmetic. Currying is not a
// trick added to the algorithm; it is what makes the algorithm not need one.
//
// Currying pays twice more.
//
//   A REPETITION IS A CONS WHOSE TAIL IS ITSELF -- `identical(tail, this)`. That
//   single identity replaces `requireOne` (one Cons in front of the loop), "may
//   this item stop here", "does an element still follow", and the parser's
//   zero-width repetition cut, which is just `identical(tail, this) && end == pos`.
//
//   THE GRAMMAR COLLAPSES TO THREE NODE KINDS: terminal, cons, alternation.
//   `_compute` therefore has three cases. Optional is an alternation ending in the
//   empty match; the empty match, `Nothing`, and both predicates are terminals
//   that cannot lie; a multi-character string literal is a cons chain of single
//   character ones. THERE IS NO KIND FOR A RULE REFERENCE: in the parser a Ref is
//   distinguished by being the only clause that consults the memo, and here every
//   node consults it, so a Ref is left being an alternation among one.
//
// ---------------------------------------------------------------------------
// The pricing below is m40's, unchanged, and is derived rather than tuned:
//
// A1  A repair of input s under grammar G is a string s' in L(G) plus an
//     alignment of s to s'. The three edit primitives are Levenshtein's, lifted
//     from strings to a language: SUB and FAB and SKIP, each cost 1, and one
//     non-edit, MATCH, cost 0. SKIP is a UNIT edge, so a gap of j characters is j
//     unit steps and no loop over span lengths is a primitive.
//
// A2  Among minimum-cost repairs prefer the one committing the least unjustified
//     information: regret = sum over kept characters of w(class) plus twice the
//     sum over skipped characters of h(char), where w is the log2-width of the
//     accepting class and h(c) the narrowest class in G accepting c. The factor 2
//     is derived; see LESSONS_LEARNED.
//
// A3  Delta = cost * costUnit + regret, with costUnit above any achievable
//     regret, so ordering by the single integer Delta orders cost first and
//     min-Delta-per-end is exactly min-cost. The budget is then a FILTER on that
//     integer, not a memo key, so one memo serves every deepening round.
//
// A4  At budget 0 no edit is affordable, so the repaired string IS the input, PEG
//     is deterministic on it, and the pure parser decides the node outright.
//     After currying this is one oracle call for every node that stands for a
//     clause -- which, since a repetition and a sequence now both stand for one,
//     is every node but the interior of a cons chain. See `_walk`.
//
// ---------------------------------------------------------------------------
// PARAMETERS AND HEURISTICS -- the complete list, because "parameter-free" is a
// claim this engine makes and a reader should be able to check it.
//
//   PARAMETER (one): `maxCost`, the deepening ceiling, defaulted to 40. A repair
//   costing more is not found at all -- `recoverCost` returns -1 and `recover`
//   degrades to reporting the whole input as one error. Nothing else about the
//   answer depends on it.
//
//   HEURISTIC AFFECTING OUTPUT (one): "prefer the shortest head", the tie-break
//   in `_descend`. Chosen because it measures better, not derived. It cannot
//   change any reported cost -- every candidate it ranks is Delta-tied -- only
//   which witness tree comes back.
//
//   HEURISTICS AFFECTING PRESENTATION ONLY (two): consecutive unit SKIPs are
//   merged into one span, and a failed witness descent reports the whole input as
//   a single error rather than failing outright.
//
//   EVERYTHING ELSE IS DERIVED. `_costUnit` and `_costShift` are bounds forced by
//   A3, not settings: any sufficiently large value gives identical answers.
// ---------------------------------------------------------------------------
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

/// The width of the widest possible character class, in millibits: it is
/// `round(log2(0x110000) * 1000)`, the log2-width of the whole Unicode code point
/// range. Derived, not chosen -- committing to a character with no evidence for it
/// is worth exactly as much information as the alphabet is wide.
const _widestClass = 20087;

/// The log2-width of the class a terminal accepts, in millibits -- how much is
/// being claimed by letting it consume a character (A2). The x1000 is a
/// fixed-point scale so Delta stays a single int.
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

// ---------------------------------------------------------------------------
// THE NORMAL FORM. Three node kinds, built once per grammar and independent of
// the input. This is the whole of I3's machinery: after currying, an "item with a
// dot" is just a clause again, so the memo key below is the parser's own.
//
// There is no node kind for a rule reference. In the parser a Ref is special
// because it is the only clause that consults the memo; here EVERY node does, so
// a Ref has no distinguishing behaviour left -- it is a choice among one.
// ---------------------------------------------------------------------------

sealed class _Node {
  _Node(this.id, this.orig);

  /// Dense memo index: the key is `id * (n + 2) + pos`. An int field, not a hash
  /// lookup, which is the second thing currying buys.
  final int id;

  /// The clause this node denotes. EVERY node denotes one, including the interior
  /// of a cons chain: the cell at element i denotes the sequence's suffix from i,
  /// which is a clause in its own right. That totality is what makes `_walk` a
  /// single oracle call everywhere and lets `_build` label any node.
  final Clause orig;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable);

  /// Whether I2 applies. False for `Nothing` and for both predicates: they
  /// consume no input, so substituting or fabricating them would edit the
  /// derivation rather than the string, and only the string is being repaired.
  final bool editable;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;

  /// The rest of the sequence -- or THIS NODE, which is what a repetition is.
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);

  /// The alternatives, in grammar order -- or the single target of a Ref.
  late final List<_Node> alts;
}

/// A memo table entry for a (node, position) pair. Read it next to
/// `lib/src/parser/memo_entry.dart`: it is that class with `result` widened by I1
/// and ONE field added, the budget the value was computed under. Every line
/// concerning left recursion is the parser's, verbatim.
class _Entry {
  /// I1: `MemoEntry.result`, widened from the best match to the best Delta for
  /// every reachable end. Null if nothing has been computed.
  Map<int, int>? endsMap;

  /// The edit budget `endsMap` was computed under -- the one added field. A
  /// larger request must recompute; a smaller one can filter, because Delta
  /// orders cost first (A3).
  int budget = -1;

  /// `MemoEntry.inRecPath`: true while this (node, pos) is on the recursion path.
  bool inRecPath = false;

  /// `MemoEntry.foundLeftRec`: set by a descendant frame that closed a cycle
  /// here, telling this frame to iterate.
  bool foundLeftRec = false;

  /// `MemoEntry.memoVersion`.
  int memoVersion = 0;

  /// I1's fixed-point test. The parser's is "the match did not get longer"; over
  /// a map of ends the same test is "no end is new and no Delta got smaller".
  /// Ends lie in [0, n] and Deltas are bounded non-negative integers, so the
  /// chain ascends only finitely often and the loop below terminates.
  bool _improves(Map<int, int> fresh) {
    for (final entry in fresh.entries) {
      final known = endsMap![entry.key];
      if (known == null || entry.value < known) return true;
    }
    return false;
  }

  Map<int, int> ends(SuperDot3 engine, _Node node, int pos, int budgetWanted) {
    if (inRecPath) {
      // On the recursion path already. With no value yet this is the fixed point
      // of a left recursive cycle: seed it with the empty set -- I1's analogue of
      // the parser's `mismatch` -- and signal the ancestral frame to expand it.
      if (endsMap == null) {
        foundLeftRec = true;
        budget = budgetWanted;
        return endsMap = const {};
      }
      return endsMap!;
    }
    if (endsMap != null &&
        budget >= budgetWanted &&
        memoVersion == engine._versionAtPos[pos]) {
      return endsMap!;
    }
    inRecPath = true;
    var first = true;
    while (true) {
      final fresh = engine._compute(node, pos, budgetWanted);
      if (!first && !_improves(fresh)) break;
      first = false;
      endsMap = fresh;
      budget = budgetWanted;
      if (!foundLeftRec) break;
      // Expand the cycle so the value just found can become a sub-derivation of a
      // better one, invalidating memos at this position only: the parser's
      // `memoVersion = ++parser.memoVersion[pos]`, verbatim.
      memoVersion = ++engine._versionAtPos[pos];
    }
    inRecPath = false;
    memoVersion = engine._versionAtPos[pos];
    return endsMap!;
  }
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form -------------------------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable);
  }

  /// The empty match: the tail every cons chain ends in, and the last
  /// alternative of every Optional. It is a terminal, so it needs no case.
  late final _Node _eps = _term(const Nothing(), false);

  /// Right-nest `parts` into cons cells. The cell at element i denotes the
  /// sequence's suffix from i, which IS a clause -- that is why `orig` is total.
  _Node _cons(List<Clause> parts, Clause orig) {
    var node = _eps;
    for (var i = parts.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(parts.sublist(i)))
        ..head = _node(parts[i])
        ..tail = node;
    }
    return node;
  }

  /// The grammar, curried. A Ref is the only back edge in a clause graph, so it
  /// is the only kind that must be interned before its subtree is built.
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
      // A repetition is a cons whose tail is itself; `requireOne` is one more
      // cons in front of it. Nothing else in this engine knows what a repetition
      // is.
      final loop = _Cons(_nodeCount++,
          clause.requireOne ? Repetition(clause.subClause, requireOne: false) : clause)
        ..head = _node(clause.subClause);
      loop.tail = loop;
      node = clause.requireOne
          ? (_Cons(_nodeCount++, clause)
            ..head = loop.head
            ..tail = loop)
          : loop;
    } else {
      node = _term(clause, clause is Terminal && clause is! Nothing);
    }
    return _nodes[clause] = node;
  }

  /// THE GOAL: the top rule, then the empty match. A4 says SKIP is reachable
  /// wherever an element still follows, so the first cons cell absorbs leading
  /// garbage and the second trailing garbage. Both fall out of I3, which is why
  /// there is no bespoke lead/trail arithmetic anywhere in this engine.
  late final _Node _goal = _node(Seq([_rules[topRuleName]!, const Nothing()]));

  // ---- per-input state -----------------------------------------------------

  late Parser _parser;
  late String _input;
  late int _inputLen;

  /// A3's multiplier: one unit of cost, priced above any achievable regret.
  /// `_costShift` is its log2, so dividing out the cost is a shift.
  late int _costUnit, _costShift;

  /// Prefix sums of the per-character regret weight h, so the regret of skipping
  /// any span is one subtraction.
  late List<int> _regretPrefix;
  final Map<int, int> _charRegret = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _cleanRegrets = {};
  MatchResult? _clean;
  int _steps = 0, _bestGoalDelta = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;

  /// The edit count carried inside a Delta (A3).
  int _editCount(int delta) => delta >> _costShift;

  /// The regret of skipping `[from, to)`.
  int _skipRegret(int from, int to) => _regretPrefix[to] - _regretPrefix[from];

  int _widthOf(Clause clause) =>
      _widths.putIfAbsent(clause, () => _width(clause));

  /// h(c), per input position: the narrowest class in G that accepts the
  /// character there, or the full alphabet if no terminal accepts it at all.
  /// ACCEPTANCE IS ASKED OF THE ORACLE -- the candidate character is a one
  /// character input and a terminal accepts it iff it consumes it -- so nothing
  /// here re-implements what a character class means.
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

  /// Regret of a clean subtree. Absolute pricing (A2) makes this a closed form: a
  /// kept leaf costs w(class) * len, with no per-character loop.
  int _cleanRegret(MatchResult m) =>
      _cleanRegrets[m] ??= m.subClauseMatches.isEmpty
          ? _widthOf(m.clause!) * m.len
          : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));

  /// Record `delta` for `end` unless a better one is already there.
  static void _keepBest(Map<int, int> out, int end, int delta) {
    if ((out[end] ?? delta) >= delta) out[end] = delta;
  }

  /// I1's memo: one entry per (node, position), field for field with `MemoEntry`.
  final Map<int, _Entry> _entries = {};

  /// `Parser.memoVersion`: how many times a left recursive cycle has been
  /// expanded at each position.
  late List<int> _versionAtPos;

  /// Every end position reachable from `pos` by matching `node`, each mapped to
  /// its minimum Delta, given that at most `budget` edits may be spent. This is
  /// `Parser.match`: bounds check, find the entry, ask it.
  Map<int, int> _ends(_Node node, int pos, int budget) {
    if (pos > _inputLen || budget < 0) return const {};
    return _entries
        .putIfAbsent(node.id * (_inputLen + 2) + pos, _Entry.new)
        .ends(this, node, pos, budget);
  }

  /// The three cases. Compare `combinators.dart`: this is `match` for each clause
  /// kind, evaluated over I1's value instead of a single result.
  Map<int, int> _compute(_Node node, int pos, int budget) {
    _steps++;
    // A4: with no edits to spend the repaired string IS the input, PEG is
    // deterministic on it, and the node is settled outright -- there is nothing to
    // search, only a walk, and the walk is the oracle's own. It applies to every
    // node because every node denotes a clause: a sequence's suffix as much as the
    // sequence itself. The singleton it returns is also the narrowest possible
    // operand for every product in `_chain`.
    if (budget == 0) {
      final m = node.orig.match(_parser, pos);
      return m.isMismatch ? const {} : {pos + m.len: _cleanRegret(m)};
    }
    switch (node) {
      case _Cons():
        return _chain(node, pos, budget);
      case _Alt(:final alts):
        // Ordered choice, over a value that is a set: a union -- and a rule
        // reference is the union of one. Nothing about recovery appears here,
        // because a gap before a chosen alternative is a gap before that
        // alternative's first element, which attaches further up.
        if (alts.length == 1) return _ends(alts[0], pos, budget);
        final out = <int, int>{};
        final limit = (budget + 1) * _costUnit;
        for (final alternative in alts) {
          for (final e in _ends(alternative, pos, budget).entries) {
            if (e.value < limit) _keepBest(out, e.key, e.value);
          }
        }
        return out;
      case _Term(:final editable):
        final out = <int, int>{};
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) out[pos + m.len] = _cleanRegret(m); // MATCH
        if (!editable) return out;
        // I2. Each edit costs exactly one `_costUnit`; only the regret riding in
        // the low bits varies.
        if (m.isMismatch && pos < _inputLen) {
          // SUB: the character is consumed by a terminal that does not accept it,
          // so its own evidence is discarded -- twice h, by A2.
          out[pos + 1] = _costUnit + 2 * _skipRegret(pos, pos + 1);
        }
        // FAB: the text the terminal stands for is invented outright, which
        // commits a full alphabet's worth of information -- the most any single
        // move can commit, and the price is forced by A2.
        _keepBest(out, pos, _costUnit + _widestClass);
        return out;
    }
  }

  /// Sequencing, and the ONLY place recovery logic appears (I3).
  Map<int, int> _chain(_Cons node, int pos, int budget) {
    final out = <int, int>{};
    final limit = (budget + 1) * _costUnit;
    // A repetition is a cons whose tail is itself. That is the whole of "this
    // item may stop here", and the whole of the parser's zero-width repetition
    // cut -- a zero-width iteration re-enters the identical state.
    final loops = identical(node.tail, node);
    if (loops) out[pos] = 0;
    for (final head in _ends(node.head, pos, budget).entries) {
      // MEASURED: deleting this line changes NO reported cost, tree or span --
      // re-entering the identical state is left recursion, and I1's fixed point
      // absorbs it, which is why the parser's own cut and this one are the same
      // observation. It is kept because without it latency doubles (300ms vs
      // 148ms on the battery). The cut is an optimization, not a rule.
      if (loops && head.key == pos) continue;
      final rest = _ends(node.tail, head.key, budget - _editCount(head.value));
      for (final tail in rest.entries) {
        final total = head.value + tail.value;
        if (total < limit) _keepBest(out, tail.key, total);
      }
    }
    // I3, as a UNIT edge (A1): a span of j characters is j unit steps, so the
    // loop over span lengths that a dot-array formulation needs is not a
    // primitive here -- it is a hand-unrolled path. Reachable only where an
    // element still follows, which is what keeps each gap at its canonical
    // attachment point rather than merely at an equal-cost one.
    if (pos < _inputLen && budget >= 1) {
      final skipDelta = _costUnit + 2 * _skipRegret(pos, pos + 1);
      for (final tail in _ends(node, pos + 1, budget - 1).entries) {
        final total = skipDelta + tail.value;
        if (total < limit) _keepBest(out, tail.key, total);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Reconstruction: replay the same recurrence, taking any decomposition whose
  // parts sum to the Delta already known to be minimal.
  //
  // PREFER THE SHORTEST HEAD. Among Delta-tied decompositions take the one whose
  // head ends earliest: text being discarded anyway should stay outside a subtree
  // rather than stretch a rule node over it. THIS IS THE ONE HEURISTIC IN THE
  // ENGINE THAT CHANGES OUTPUT -- it is kept because it measures better, not
  // because anything above implies it. It cannot change a reported cost, since
  // every candidate it ranks carries the same Delta; it decides only which of
  // several minimal witnesses is returned. It is also the reason this is a
  // forward descent -- a backward predecessor walk fixes the tail first, so by the
  // time the head is reached its tie is already settled.
  // ---------------------------------------------------------------------------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  /// Reconstruction's own recursion path, and the exact analogue of
  /// `MemoEntry.inRecPath`. A left recursive alternative can reproduce the state
  /// being built -- the same rule over the same extent at the same Delta,
  /// whenever what follows it is nullable -- and a Delta-exact descent would take
  /// that cycle forever. Every cycle passes through a rule reference, and a rule
  /// reference is an alternation, so guarding alternations is enough.
  final Set<(_Alt, int, int, int)> _path = {};

  MatchResult? _build(_Node node, int pos, int end, int delta, int budget) {
    final orig = node.orig;
    final pure = pos > _inputLen ? mismatch : orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        _cleanRegret(pure) == delta) {
      return pure;
    }
    switch (node) {
      case _Term():
        return Match(orig, pos, end - pos);
      case _Alt(:final alts):
        final state = (node, pos, end, delta);
        if (!_path.add(state)) return null;
        for (final alternative in alts) {
          if (_ends(alternative, pos, budget)[end] != delta) continue;
          final m = _build(alternative, pos, end, delta, budget);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: [m]);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _descend(node, pos, end, delta, budget);
        return children == null
            ? null
            : Match(orig, pos, end - pos, subClauseMatches: children);
    }
  }

  /// Walk a cons chain, emitting one child per element. A repetition's tail is
  /// itself, so the same walk emits one child per iteration and the child list
  /// comes out flat.
  List<MatchResult>? _descend(
      _Node node, int pos, int end, int delta, int budget) {
    if (node is _Cons) {
      final loops = identical(node.tail, node);
      final heads = _ends(node.head, pos, budget);
      // The one output-affecting heuristic: shortest head first. See above.
      final order = heads.keys.toList()..sort();
      for (final headEnd in order) {
        if (loops && headEnd == pos) continue;
        final headDelta = heads[headEnd]!;
        // The remainder's Delta is non-negative, so a head already past the
        // target cannot belong to any decomposition summing to it.
        if (headDelta > delta) continue;
        final restBudget = budget - _editCount(headDelta);
        final rest = _ends(node.tail, headEnd, restBudget)[end];
        if (rest == null || headDelta + rest != delta) continue;
        final head = _build(node.head, pos, headEnd, headDelta, budget);
        if (head == null) continue;
        final tail = _descend(node.tail, headEnd, end, rest, restBudget);
        if (tail != null) return [head, ...tail];
      }
      // SKIP one character, then continue from the same node. PRESENTATION
      // HEURISTIC: consecutive unit skips are merged, so the tree carries one
      // span per gap rather than one per character. The cost is identical either
      // way -- only the diagnostic reads differently.
      if (pos < _inputLen && budget >= 1) {
        final skipDelta = _costUnit + 2 * _skipRegret(pos, pos + 1);
        final rest = _ends(node, pos + 1, budget - 1)[end];
        if (rest != null && skipDelta + rest == delta) {
          final tail = _descend(node, pos + 1, end, rest, budget - 1);
          if (tail == null) return null;
          var len = 1;
          var skip = 0;
          if (tail.isNotEmpty &&
              tail.first is SyntaxError &&
              tail.first.pos == pos + 1) {
            len += tail.first.len;
            skip = 1;
          }
          return [SyntaxError(pos: pos, len: len), ...tail.skip(skip)];
        }
      }
      if (!loops) return null;
    }
    // The empty match ends every chain, and a repetition may stop at any point.
    return pos == end && delta == 0 ? const [] : null;
  }

  /// EVERY DIAGNOSTIC IS READ OFF THE FINISHED TREE. The three edits are visible
  /// in the tree itself and need not be recorded as the descent decides them: a
  /// SKIP is a SyntaxError leaf, a FAB is a terminal leaf of zero width, and a SUB
  /// is a terminal leaf the parser does not actually accept there. Reading them
  /// afterwards is what lets the descent abandon a branch freely -- there is
  /// nothing to un-record -- so the cycle guard costs no bookkeeping at all.
  void _collect(MatchResult m) {
    final clause = m.clause;
    if (m is SyntaxError) {
      _spans.add(m); // SKIP
    } else if (m.subClauseMatches.isEmpty &&
        clause is Terminal &&
        clause is! Nothing) {
      if (m.len == 0) {
        _missing.add(MissingObligation(clause, m.pos)); // FAB
      } else if (clause.match(_parser, m.pos).isMismatch) {
        _spans.add(SyntaxError(pos: m.pos, len: m.len)); // SUB
      }
    } else {
      m.subClauseMatches.forEach(_collect);
    }
  }

  /// `maxCost` is THE PARAMETER (see the header): the deepening ceiling.
  SkipResult recover(String input, {int maxCost = 40}) {
    final cost = recoverCost(input, maxCost: maxCost);
    _spans.clear();
    _missing.clear();
    _path.clear();
    if (cost == 0) return SkipResult(_clean!, const [], const [], 0, false);
    final root =
        cost < 0 ? null : _build(_goal, 0, _inputLen, _bestGoalDelta, cost);
    if (root == null) {
      // PRESENTATION HEURISTIC: no repair within budget, or none whose witness
      // survives the cycle guard. Report the input as one error rather than
      // failing, so a caller always gets a tree.
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    _collect(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  int recoverCost(String input, {int maxCost = 40}) {
    _input = input;
    _inputLen = input.length;
    _clean = null;
    final goal = _goal; // force the normal form, and with it `_terminals`
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    // Clean input costs nothing and needs no search. This relies on the parser's
    // own `hasSyntaxErrors` also covering input it did not consume.
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildRegretPrefix();
    // A3's bound, not a setting: one cost unit must outweigh the largest regret
    // any repair can accumulate -- at most one weight per kept character, two per
    // skipped one, plus one per edit -- so `_costUnit` is rounded up to a power of
    // two and the division becomes `_costShift`.
    _costShift = ((2 * _inputLen + maxCost + 2) * (_widestClass + 1)).bitLength;
    _costUnit = 1 << _costShift;
    _entries.clear();
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cleanRegrets.clear();
    _steps = 0;
    // Iterative deepening on the budget. A3 makes each round reuse the previous
    // round's memo, and the goal node makes the whole query a single lookup:
    // "consume the entire input".
    for (var k = 0; k <= maxCost; k++) {
      final best = _ends(goal, 0, k)[_inputLen];
      if (best != null) {
        _bestGoalDelta = best;
        lastCost = _editCount(best);
        lastRegret = best - lastCost * _costUnit - _skipRegret(0, _inputLen);
        lastSteps = _steps;
        return lastCost;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}
