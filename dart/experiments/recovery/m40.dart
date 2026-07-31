// m40 -- the axiomatic engine, with budget 0 walked rather than searched.
//
// Derived from five axioms and nothing else. A5 is stated at the memo, where it
// lives; the other four are here.
//
// A1  A repair of input s under grammar G is a string s' in L(G) together with an
//     alignment of s to s'. There are exactly three edit primitives, and they are
//     Levenshtein's, lifted from strings to a language:
//       SUB   a terminal consumes a character it does not accept   (cost 1)
//       FAB   a terminal consumes nothing                          (cost 1, an
//             insertion into s)
//       SKIP  a character is consumed by no terminal               (cost 1, a
//             deletion from s)
//     and one non-edit: MATCH, a terminal consuming what is there  (cost 0).
//
// A2  Among minimum-cost repairs, prefer the one that commits the least
//     unjustified information: regret = sum over kept characters of w(class)
//     plus twice the sum over skipped characters of h(char), where w is the
//     log2-width of the accepting class and h(c) is the narrowest class in G
//     that accepts c. The factor 2 is derived, not tuned: see LESSONS_LEARNED.
//
// A3  Delta = cost * costUnit + regret, with costUnit above any achievable
//     regret, so ordering by the single integer Delta orders cost first and
//     min-Delta-per-end is exactly min-cost. The budget is then a FILTER on that
//     integer, not a memo key, so one memo serves every deepening round.
//
// A4  A gap is by definition text BETWEEN two consumed regions, and only a
//     sequence has a "between". The region separating two adjacent consuming
//     leaves attaches at their lowest common ancestor, which is always a Seq or a
//     Repetition -- a First has no two consecutive children. So every gap has a
//     UNIQUE canonical attachment point, and First / Optional / Ref / predicates
//     need no recovery logic whatsoever: a gap before a chosen alternative is a
//     gap before that alternative's first element, which attaches further up.
//
// What A4 buys, measured against m16: the dot-state array, the ascending sweep,
// the arcs table, and _dots/_to/_accepts/_sink all disappear. What is left is one
// recurrence with a skip self-edge, and the recursion itself is the dot.
//
// What A1 buys: SKIP is a UNIT edge. A span of j characters costs
// j*costUnit + 2*sum(h), which is exactly j unit steps, so the loop over span
// lengths that both m15 and m16 carry is not a primitive -- it is a hand-unrolled
// path.
//
// A5 is that left recursion is not a recovery problem: the parser already solves
// it, and recovery is the same recurrence over a wider value, so it adopts the
// parser's memo rule verbatim. Without it this engine silently returns
// non-minimal repairs on any left-recursive grammar -- correct cost only because
// budget 0 defers to the parser -- which no JSON benchmark can detect. See _Entry.
//
// What m40 adds over m26: at budget 0 nothing can be edited, so the repaired
// string IS the input and the pure parser decides an item outright. m26 could
// only act on that at dot 0, because the oracle matches a clause and not a
// clause's tail; `_walk` supplies the tail. See LESSONS_LEARNED section 5i.
//
// ---------------------------------------------------------------------------
// PARAMETERS AND HEURISTICS -- the complete list, because "parameter-free" is a
// claim this engine makes and a reader should be able to check it.
//
//   PARAMETER (one): `maxCost`, the deepening ceiling, defaulted to 40. A repair
//   costing more than that is not found at all -- `recoverCost` returns -1 and
//   `recover` degrades to reporting the whole input as one error. Nothing else
//   about the answer depends on it.
//
//   HEURISTIC AFFECTING OUTPUT (one): "prefer the shortest head", the tie-break
//   in `_descend`. It is chosen because it measures better, not derived, and it
//   cannot change any reported cost -- every candidate it ranks is Delta-tied --
//   only which witness tree comes back. See the comment there.
//
//   HEURISTICS AFFECTING PRESENTATION ONLY (two): consecutive unit SKIPs are
//   merged into one span so a gap reads as one error rather than one per
//   character, and a failed witness descent reports the whole input as a single
//   error rather than failing outright.
//
//   EVERYTHING ELSE IS DERIVED. Every weight and constant below traces to A1-A3:
//   the three edits cost 1 and MATCH costs 0 (A1); the factor 2 on skipped
//   characters and the FAB price of a full alphabet come from A2; `_costUnit`
//   and `_costShift` are bounds forced by A3, not settings, and any sufficiently
//   large value gives identical answers.
// ---------------------------------------------------------------------------
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

// ERROR RECOVERY START

/// The width of the widest possible character class, in millibits: it is
/// `round(log2(0x110000) * 1000)`, the log2-width of the whole Unicode code
/// point range. Derived, not chosen -- committing to a character with no
/// evidence for it is worth exactly as much information as the alphabet is wide.
const _widestClass = 20087;

/// The log2-width of the class a terminal accepts, in millibits -- how much is
/// being claimed by letting it consume a character (A2).
///
/// The x1000 is a fixed-point scale, so widths are integers and Delta stays a
/// single int. It is a representation choice rather than a tuning knob, with one
/// visible consequence: two classes whose widths differ by less than a
/// thousandth of a bit tie instead of ordering.
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

bool _accepts(CharSet set, int ch) {
  var inRange = false;
  for (final (lo, hi) in set.ranges) {
    if (ch >= lo && ch <= hi) {
      inRange = true;
      break;
    }
  }
  return set.inverted ? !inRange : inRange;
}

/// A memo table entry for an (item, position) pair, where an item is a clause
/// with a dot in it. Read this next to `lib/src/parser/memo_entry.dart`: it is
/// the same class over a wider value. The parser's entry holds the best single
/// match; this one holds the best Delta for every reachable end position, plus
/// the budget that map was computed under. Nothing else differs, and in
/// particular every line concerning left recursion is the parser's.
class _Entry {
  /// The best ends map found so far, or null if nothing has been computed.
  /// `MemoEntry.result`.
  Map<int, int>? endsMap;

  /// The edit budget `endsMap` was computed under. A larger request must
  /// recompute; a smaller one can filter, because Delta orders cost first (A3).
  int budget = -1;

  /// `MemoEntry.inRecPath`: true while this (item, pos) is on the recursion path.
  bool inRecPath = false;

  /// `MemoEntry.foundLeftRec`: set by a descendant frame that closed a cycle
  /// here, telling this frame to iterate.
  bool foundLeftRec = false;

  /// `MemoEntry.memoVersion`.
  int memoVersion = 0;

  /// The budget-0 walk. No round can change it, because no round can spend an
  /// edit inside it, so it is held apart from `endsMap` -- which the first larger
  /// request overwrites -- and every later round reuses it instead of paying to
  /// recover level 0 by filtering a map that is both slower and wider.
  Map<int, int>? zero;

  /// The fixed-point test. The parser's is "the match did not get longer"; over a
  /// map of ends the same test is "no end is new and no Delta got smaller". Ends
  /// lie in [0, n] and Deltas are bounded non-negative integers, so the chain
  /// ascends only finitely often and the loop below terminates.
  bool _improves(Map<int, int> fresh) {
    for (final entry in fresh.entries) {
      final known = endsMap![entry.key];
      if (known == null || entry.value < known) return true;
    }
    return false;
  }

  Map<int, int> ends(
      SuperDot3 engine, Clause clause, int dot, int pos, int budgetWanted) {
    if (inRecPath) {
      // On the recursion path already. With no value yet this is the fixed point
      // of a left recursive cycle: seed it with the empty set -- the recovery
      // analogue of the parser's `mismatch` -- and signal the ancestral frame to
      // expand it. Either way a frame inside a cycle reports the best value known
      // and never recomputes, which is what makes the recursion finite.
      if (endsMap == null) {
        foundLeftRec = true;
        budget = budgetWanted;
        return endsMap = const {};
      }
      return budget > budgetWanted
          ? engine._withinBudget(endsMap!, budgetWanted)
          : endsMap!;
    }
    if (budgetWanted == 0 && zero != null) return zero!;
    if (endsMap != null && memoVersion == engine._versionAtPos[pos]) {
      if (budget == budgetWanted) return endsMap!;
      if (budget > budgetWanted) {
        return engine._withinBudget(endsMap!, budgetWanted);
      }
    }
    inRecPath = true;
    var first = true;
    while (true) {
      final fresh = engine._compute(clause, dot, pos, budgetWanted);
      if (!first && !_improves(fresh)) break;
      first = false;
      endsMap = fresh;
      budget = budgetWanted;
      if (budgetWanted == 0) zero = endsMap;
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
  final Map<Str, Clause> _strings = {};
  Clause _desugar(Clause clause) => clause is Str && clause.text.length > 1
      ? _strings.putIfAbsent(
          clause, () => Seq([for (final x in clause.text.split('')) Str(x)]))
      : clause;

  late final List<Clause> _terminals = () {
    final seen = <Clause>{}, out = <Clause>[];
    void visit(Clause raw) {
      final clause = _desugar(raw);
      if (!seen.add(clause)) return;
      if (clause is Ref) {
        visit(_rules[clause.ruleName]!);
      } else if (clause is HasOneSubClause) {
        visit(clause.subClause);
      } else if (clause is HasMultipleSubClauses) {
        clause.subClauses.forEach(visit);
      } else if (clause is Terminal && clause is! Nothing) {
        out.add(clause);
      }
    }

    visit(_rules[topRuleName]!);
    return out;
  }();

  late Parser _parser;
  late String _input;
  late int _inputLen;

  /// A3's multiplier: one unit of cost, priced above any achievable regret so
  /// that comparing Delta compares cost first and regret only to break ties.
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

  /// THE GOAL. `Seq([top, Nothing])` -- the top rule, then the empty match. A4
  /// says skip is reachable wherever an element still follows, so at dot 0 the
  /// skip edge is the leading garbage and at dot 1 it is the trailing garbage.
  /// Both fall out of the universal rule, which is why there is no bespoke
  /// lead/trail arithmetic anywhere in this engine; and the shortest-head
  /// preference applied to dot 0 IS the smallest-extent tie-break, because the
  /// head at dot 0 is the top rule itself.
  late final Clause _goal = Seq([_rules[topRuleName]!, const Nothing()]);

  /// The edit count carried inside a Delta (A3).
  int _editCount(int delta) => delta >> _costShift;

  /// The regret of skipping `[from, to)`.
  int _skipRegret(int from, int to) => _regretPrefix[to] - _regretPrefix[from];

  int _widthOf(Clause clause) =>
      _widths.putIfAbsent(clause, () => _width(clause));

  /// Memo identity. A Seq needs one slot per dot and a Repetition two, because
  /// the recursion carries the dot; everything else needs one. Allocating a
  /// BLOCK per clause is what lets the item (clause, dot) be a memo key without
  /// a wrapper class -- the whole cost of making the dot first-class.
  final Map<Clause, int> _memoBases = {};
  int _nextMemoBase = 0;
  int _memoBase(Clause clause) => _memoBases.putIfAbsent(clause, () {
        final base = _nextMemoBase;
        _nextMemoBase += clause is Seq
            ? clause.subClauses.length + 1
            : clause is Repetition
                ? 2
                : 1;
        return base;
      });

  /// h(c), per input position: the narrowest class in G that accepts the
  /// character there, or the full alphabet if no terminal accepts it at all.
  void _buildRegretPrefix() {
    _regretPrefix = [0];
    for (var pos = 0; pos < _inputLen; pos++) {
      final ch = _input.codeUnitAt(pos);
      final narrowest = _charRegret.putIfAbsent(ch, () {
        var best = _widestClass;
        for (final terminal in _terminals) {
          final hit = terminal is Str
              ? terminal.text.codeUnitAt(0) == ch
              : terminal is Char
                  ? terminal.char.codeUnitAt(0) == ch
                  : terminal is CharSet
                      ? _accepts(terminal, ch)
                      : true;
          if (hit) best = math.min(best, _widthOf(terminal));
          if (best == 0) break;
        }
        return best;
      });
      _regretPrefix.add(_regretPrefix.last + narrowest);
    }
  }

  /// Regret of a clean subtree. Absolute pricing (A2) makes this a closed form:
  /// a kept leaf costs w(class) * len, one multiply, with no per-character loop
  /// and no per-position array.
  int _cleanRegret(MatchResult m) {
    final known = _cleanRegrets[m];
    if (known != null) return known;
    final regret = m.subClauseMatches.isEmpty
        ? _widthOf(m.clause!) * m.len
        : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));
    return _cleanRegrets[m] = regret;
  }

  /// Record `delta` for `end` unless an equal or better one is already there.
  static void _keepBest(Map<int, int> out, int end, int delta) {
    final known = out[end];
    if (known == null || delta < known) out[end] = delta;
  }

  /// Drop the ends that cost more than `budget` edits. Sound as a memo reuse
  /// because Delta orders cost first (A3), so a smaller budget is a filter on a
  /// map computed under a larger one, never a recomputation.
  Map<int, int> _withinBudget(Map<int, int> source, int budget) {
    final limit = (budget + 1) * _costUnit;
    for (final delta in source.values) {
      if (delta >= limit) {
        return {
          for (final e in source.entries)
            if (e.value < limit) e.key: e.value,
        };
      }
    }
    return source;
  }

  /// A5  LEFT RECURSION IS NOT A RECOVERY PROBLEM. The parser already solves it,
  ///     in `MemoEntry.match`, by seeding a re-entered (rule, pos) with a mismatch
  ///     and then re-matching the ancestral frame while the result keeps growing.
  ///     Recovery is the same recurrence over a wider value -- a map from end
  ///     position to minimum Delta instead of a single match -- so it inherits
  ///     left recursion by adopting the parser's memo rule verbatim, field for
  ///     field. There is no second mechanism, and no recovery-specific reasoning
  ///     about cycles anywhere in this file.
  ///
  ///     So the state below is not four parallel tables but one entry per item,
  ///     field for field with `MemoEntry` -- which is also why it is fast: one
  ///     hash lookup per query instead of one per field.
  final Map<int, _Entry> _entries = {};

  /// `Parser.memoVersion`: how many times a left recursive cycle has been
  /// expanded at each position.
  late List<int> _versionAtPos;

  /// Every end position reachable from `pos` by matching (`clause`, `dot`), each
  /// mapped to its minimum Delta, given that at most `budget` edits may be spent.
  ///
  /// This is `Parser.match`: bounds check, find the entry, ask it.
  Map<int, int> _ends(Clause clause, int dot, int pos, int budget) {
    if (pos > _inputLen || budget < 0) return const {};
    final key = (_memoBase(clause) + dot) * (_inputLen + 2) + pos;
    return _entries
        .putIfAbsent(key, _Entry.new)
        .ends(this, clause, dot, pos, budget);
  }

  Map<int, int> _compute(Clause clause, int dot, int pos, int budget) {
    _steps++;
    // COST-0 FAST PATH. With no edits to spend, the repaired string IS the input,
    // so the pure parser decides this item outright -- at EVERY dot, not only at
    // dot 0. There is nothing to search at budget 0, only a walk.
    if (budget == 0) return _walk(clause, dot, pos);
    if (clause is Ref) return _ends(_rules[clause.ruleName]!, 0, pos, budget);
    if (clause is Str && clause.text.length > 1) {
      return _ends(_desugar(clause), 0, pos, budget);
    }
    if (clause is Terminal) {
      // The three terminal moves of A1, and the only place cost is created
      // other than SKIP. Each edit costs exactly one `_costUnit`; what varies is
      // only the regret riding along in the low bits.
      final out = <int, int>{};
      final m = clause.match(_parser, pos);
      if (!m.isMismatch) out[pos + m.len] = _cleanRegret(m); // MATCH
      if (m.isMismatch && pos < _inputLen) {
        // SUB: the character is consumed by a terminal that does not accept it,
        // so its own evidence is discarded -- twice h, by A2.
        out[pos + 1] = _costUnit + 2 * _skipRegret(pos, pos + 1);
      }
      // FAB: a terminal consumes nothing, so the text it stands for is invented
      // outright. That commits a full alphabet's worth of information, which is
      // the most any single move can commit -- the price is forced by A2.
      if (clause is! Nothing) _keepBest(out, pos, _costUnit + _widestClass);
      return out;
    }
    // A4: the pure unions. No spans, no dots, no recovery logic at all -- an
    // Optional is a First whose last alternative is the empty match.
    if (clause is First || clause is Optional) {
      final out = clause is Optional ? {pos: 0} : <int, int>{};
      for (final alternative in _alternatives(clause)) {
        for (final e in _ends(alternative, 0, pos, budget).entries) {
          _keepBest(out, e.key, e.value);
        }
      }
      return out;
    }
    if (clause is Seq || clause is Repetition) {
      return _chain(clause, dot, pos, budget);
    }
    return (clause is FollowedBy
            ? !clause.subClause.match(_parser, pos).isMismatch
            : clause is NotFollowedBy &&
                clause.subClause.match(_parser, pos).isMismatch)
        ? {pos: 0}
        : const {};
  }

  // The sequencing forms, and the ONLY forms that carry recovery logic (A4).
  // Three one-line accessors are the whole difference between a chain and a
  // loop: Seq advances its dot and finishes at the end of its element list;
  // Repetition returns to dot 1 forever and may finish immediately unless it
  // requires one iteration.
  List<Clause> _alternatives(Clause clause) => clause is First
      ? clause.subClauses
      : [(clause as HasOneSubClause).subClause];

  Clause _elementAt(Clause clause, int dot) => clause is Seq
      ? clause.subClauses[dot]
      : (clause as HasOneSubClause).subClause;
  int _nextDot(Clause clause, int dot) => clause is Seq ? dot + 1 : 1;
  bool _canFinish(Clause clause, int dot) => clause is Seq
      ? dot == clause.subClauses.length
      : dot == 1 || !(clause as Repetition).requireOne;
  bool _hasElement(Clause clause, int dot) =>
      clause is! Seq || dot < clause.subClauses.length;

  /// The budget-0 value of an item: one end, or none. The oracle can match a
  /// clause but not a clause's tail, and a tail at budget 0 is just that same
  /// call repeated over what remains -- deterministic, because no edit is
  /// affordable. Where the walk stops is the one question `_canFinish` already
  /// answers: failing mid-Seq leaves the tail with no value, while failing where
  /// the item may already stop IS where a Repetition stops. The singleton result
  /// is also the narrowest possible operand for every product in `_chain`.
  Map<int, int> _walk(Clause clause, int dot, int pos) {
    if (pos > _inputLen) return const {};
    if (dot == 0) {
      final m = clause.match(_parser, pos);
      return m.isMismatch ? const {} : {pos + m.len: _cleanRegret(m)};
    }
    var at = pos, regret = 0;
    for (var d = dot; _hasElement(clause, d); d = _nextDot(clause, d)) {
      final m = _elementAt(clause, d).match(_parser, at);
      // A zero-width match where the item may stop is the parser's own cut on a
      // zero-width repetition; taking it again would not advance.
      if (m.isMismatch || (m.len == 0 && _canFinish(clause, d))) {
        return _canFinish(clause, d) ? {at: regret} : const {};
      }
      at += m.len;
      regret += _cleanRegret(m);
    }
    return {at: regret};
  }

  Map<int, int> _chain(Clause clause, int dot, int pos, int budget) {
    final out = <int, int>{};
    final limit = (budget + 1) * _costUnit;
    if (_canFinish(clause, dot)) out[pos] = 0;
    if (!_hasElement(clause, dot)) return out;
    final nextDot = _nextDot(clause, dot);
    final element = _elementAt(clause, dot);
    for (final head in _ends(element, 0, pos, budget).entries) {
      // A zero-width iteration would re-enter the identical state: this is the
      // same cut the pure parser applies to a zero-width repetition, and it is
      // the only guard the recursion needs to terminate.
      if (head.key == pos && nextDot == dot) continue;
      final rest =
          _ends(clause, nextDot, head.key, budget - _editCount(head.value));
      for (final tail in rest.entries) {
        final total = head.value + tail.value;
        if (total < limit) _keepBest(out, tail.key, total);
      }
    }
    // SKIP, as a UNIT edge (A1). Reachable only where an element still follows,
    // so a finished state cannot absorb text -- that is what keeps each gap at
    // its canonical attachment point instead of merely at an equal-cost one.
    if (pos < _inputLen && budget >= 1) {
      final skipDelta = _costUnit + 2 * _skipRegret(pos, pos + 1);
      for (final tail in _ends(clause, dot, pos + 1, budget - 1).entries) {
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
  // ENGINE THAT CHANGES OUTPUT -- it is kept because it measures better (worth 6
  // shape points), not because anything above implies it. It cannot change a
  // reported cost, since every candidate it ranks carries the same Delta; it
  // decides only which of several minimal witnesses is returned. It is also the
  // reason this is a forward descent -- a backward predecessor walk fixes the
  // tail first, so by the time the head is reached its tie is already settled.
  // ---------------------------------------------------------------------------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];

  /// Reconstruction's own recursion path, and the exact analogue of
  /// `MemoEntry.inRecPath`. A left recursive alternative can reproduce the state
  /// being built -- the same rule over the same extent at the same Delta,
  /// whenever what follows it is nullable -- and a Delta-exact descent would take
  /// that cycle forever. The parser rejects the very same derivation with "the
  /// match did not increase in length". Every cycle in a clause graph passes
  /// through a Ref, because a clause tree is finite and a Ref is its only back
  /// edge, so guarding Refs is enough.
  final Set<(Clause, int, int, int)> _path = {};

  MatchResult? _build(Clause clause, int pos, int end, int delta, int budget) {
    final pure = pos > _inputLen ? mismatch : clause.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        _cleanRegret(pure) == delta) {
      return pure;
    }
    if (clause is Ref) {
      final state = (clause, pos, end, delta);
      if (!_path.add(state)) return null;
      final sub = _build(_rules[clause.ruleName]!, pos, end, delta, budget);
      _path.remove(state);
      return sub == null
          ? null
          : Match(clause, pos, end - pos, subClauseMatches: [sub]);
    }
    if (clause is Str && clause.text.length > 1) {
      return _build(_desugar(clause), pos, end, delta, budget);
    }
    if (clause is Terminal) return Match(clause, pos, end - pos);
    if (clause is FollowedBy || clause is NotFollowedBy) {
      return Match(clause, pos, 0);
    }
    if (clause is First || clause is Optional) {
      for (final alternative in _alternatives(clause)) {
        if (_ends(alternative, 0, pos, budget)[end] != delta) continue;
        final m = _build(alternative, pos, end, delta, budget);
        if (m != null) {
          return Match(clause, pos, end - pos, subClauseMatches: [m]);
        }
      }
      if (clause is Optional && pos == end && delta == 0) {
        return Match(clause, pos, 0);
      }
      return null;
    }
    final children = _descend(clause, 0, pos, end, delta, budget);
    if (children == null) return null;
    return children.isEmpty
        ? Match(clause, pos, 0)
        : Match(clause, pos, end - pos, subClauseMatches: children);
  }

  List<MatchResult>? _descend(
      Clause clause, int dot, int pos, int end, int delta, int budget) {
    if (_hasElement(clause, dot)) {
      final nextDot = _nextDot(clause, dot);
      final element = _elementAt(clause, dot);
      final heads = _ends(element, 0, pos, budget);
      // The one output-affecting heuristic: shortest head first. See above.
      final order = heads.keys.toList()..sort();
      for (final headEnd in order) {
        if (headEnd == pos && nextDot == dot) continue;
        final headDelta = heads[headEnd]!;
        // The remainder's Delta is non-negative, so a head already past the
        // target cannot belong to any decomposition summing to it.
        if (headDelta > delta) continue;
        final restBudget = budget - _editCount(headDelta);
        final rest = _ends(clause, nextDot, headEnd, restBudget)[end];
        if (rest == null || headDelta + rest != delta) continue;
        final head = _build(element, pos, headEnd, headDelta, budget);
        if (head == null) continue;
        final tail = _descend(clause, nextDot, headEnd, end, rest, restBudget);
        if (tail != null) return [head, ...tail];
      }
      // SKIP one character, then continue from the same dot. PRESENTATION
      // HEURISTIC: consecutive unit skips are merged, so the tree carries one
      // span per gap rather than one per character. The cost is identical either
      // way -- only the diagnostic reads differently.
      if (pos < _inputLen && budget >= 1) {
        final skipDelta = _costUnit + 2 * _skipRegret(pos, pos + 1);
        final rest = _ends(clause, dot, pos + 1, budget - 1)[end];
        if (rest != null && skipDelta + rest == delta) {
          final tail = _descend(clause, dot, pos + 1, end, rest, budget - 1);
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
    }
    if (_canFinish(clause, dot) && pos == end && delta == 0) return const [];
    return null;
  }

  /// EVERY DIAGNOSTIC IS READ OFF THE FINISHED TREE. The three edits of A1 are
  /// visible in the tree itself and need not be recorded as the descent decides
  /// them: a SKIP is a SyntaxError leaf, a FAB is a terminal leaf of zero width,
  /// and a SUB is a terminal leaf the parser does not actually accept there.
  /// Reading them afterwards is what lets the descent abandon a branch freely --
  /// there is nothing to un-record -- so the left-recursion cycle guard costs no
  /// bookkeeping at all. `Nothing` is the one terminal that legitimately matches
  /// zero width; predicates and empty repetitions are not terminals.
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
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    // Clean input costs nothing and needs no search. This relies on the parser's
    // own `hasSyntaxErrors` also covering input it did not consume -- it does on
    // every case measured here, but that is the parser's contract, not something
    // this file checks.
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildRegretPrefix();
    // A3's bound, not a setting: one cost unit must outweigh the largest regret
    // any repair can accumulate -- at most one weight per kept character, two per
    // skipped one, plus one per edit -- so `_costUnit` is rounded up to a power
    // of two and the division becomes `_costShift`.
    _costShift = ((2 * _inputLen + maxCost + 2) * (_widestClass + 1)).bitLength;
    _costUnit = 1 << _costShift;
    _entries.clear();
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cleanRegrets.clear();
    _steps = 0;
    // Iterative deepening on the budget. A3 makes each round reuse the previous
    // round's memo, and the goal clause makes the whole query a single lookup:
    // "consume the entire input". A repair costing more than `maxCost` is not
    // found at all -- that ceiling is the engine's only parameter.
    for (var k = 0; k <= maxCost; k++) {
      final best = _ends(_goal, 0, 0, k)[_inputLen];
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
// ERROR RECOVERY END
