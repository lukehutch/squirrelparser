// m45 -- recovery is the parser over a wider value, and terminals that may lie.
//
// Read this file next to `lib/src/parser/memo_entry.dart` and
// `lib/src/parser/combinators.dart`. Every combinator below is those files'
// `match`, transliterated over a different value. Exactly one leaf rule differs.
//
//   I1  THE VALUE.  A match becomes "the cheapest repair to each end position";
//       a mismatch becomes the empty set. The parser's fixed-point test -- "the
//       match did not get longer" -- becomes "no end is new and no price is
//       lower". Every other line of `MemoEntry` is copied verbatim, so LEFT
//       RECURSION IS SOLVED FOR RECOVERY BY THE OBSERVATION THAT SOLVED IT FOR
//       PARSING, and there is no cycle reasoning anywhere below. See `_Entry`.
//       This is a change of SEMIRING, not a change of algorithm.
//
//   I2  A TERMINAL MAY LIE, in exactly two ways, at a price of one each. It may
//       consume a character it does not accept (SUB), or consume nothing and
//       claim it did (FAB). A terminal is where both belong, because a terminal
//       is the only thing in a grammar that reads the input.
//
//   I3  THE ORACLE IS AUTHORITATIVE AS FAR AS THE EDIT-FREE WINDOW REACHES.
//       A sub-derivation that spends no edits over [pos, end) is a claim that
//       the repaired string s' EQUALS the input there. Over that window the
//       oracle -- the pure parser, on the original input -- is not an
//       approximation of PEG on s': it IS PEG on s'. So wherever PEG makes a
//       decision that the window already determines, the oracle's answer is the
//       only legal one, and every candidate that contradicts it is dropped.
//
//       Exactly one decision qualifies, and that is why I3 is four lines in
//       `_compute` and nothing else. An ORDERED CHOICE is decided by the first
//       alternative that MATCHES, and a match is consumption: if it ends inside
//       the window, it still holds in s'. A REPETITION is decided by the first
//       item that FAILS, and a failure consumes nothing -- it is witnessed at
//       the position where the repetition stopped, which is the far edge of the
//       window, where s' is unconstrained. So a choice may be vetoed and a stop
//       may not. `S <- 'a'* 'b' 'a'` on "aa" is the counterexample that settles
//       it: the one-edit repair "aba" needs the star to stop at a position where
//       the input still offers 'a', and no window forbids that.
//
//       This is the same rule that makes budget 0 a single oracle call, applied
//       to a sub-derivation instead of the whole query: at budget 0 the window
//       is the entire input and the oracle decides everything; at budget k the
//       window is whatever each candidate paid nothing for. m42 wrote the first
//       and not the second, so its `_Alt` was the CFG's union wearing PEG's
//       name. This one is `First.match`.
//
//       ONE CAVEAT, stated because it is the only unproved step in this file.
//       A match may CONSULT input it does not consume -- a lookahead, or a
//       longer alternative that failed inside it. If the oracle's alternative
//       read past the candidate's own end, s' could break it there, and then the
//       vetoed candidate was legal after all. Bounding that would need a
//       per-match high water mark of consulted positions, which the parser does
//       not record and this engine may not add. The veto is therefore exact for
//       any alternation whose alternatives read no further than they consume,
//       and conservative-in-the-wrong-direction otherwise: it can only make a
//       reported cost too HIGH, never too low. `_bf43.dart` checks that
//       empirically against brute-force PEG truth.
//
//       The number I3 was m41's, for a hand-written third insertion; m42 derived
//       that away (see below) and vacated it.
//
//   I4  A READER OWNS THE CHARACTERS IT DECIDES, and a LOOKAHEAD DECIDES NONE.
//       Everything else in this file is about s', the repaired string: I2 lets a
//       terminal say what stands at a position, and I3 says where the input still
//       stands unedited. A predicate is the one leaf that does neither -- it reads
//       a character it does not consume, so nothing in its own derivation decides
//       what is there, and asking the oracle answers about s instead of s'. That
//       is not an approximation, it is a different question, and it fails in BOTH
//       directions: a lookahead the input refuses can be satisfiable in s' (a
//       repair is lost), and a lookahead the input grants can be broken by the
//       very edit that follows it (a repair is reported that will not parse).
//
//       So the predicate must be decided by whatever DOES decide the characters
//       it looks at. Where its window is one character and the next reader
//       consumes exactly that character, the two are ONE READER, and their
//       composition is a class:
//
//           &C T  is the class  C & T          !C T  is the class  T - C
//
//       exactly, for the pure parser as much as for this engine -- so the pair is
//       rewritten to that class in the builder, and every rule below applies to it
//       unchanged. MATCH consults the class, SUB emits a character from it, FAB
//       invents one, and the lookahead can no longer disagree with the edit beside
//       it because it IS the edit beside it. An empty class is not a cheap repair
//       but the empty language, and `_node` declines to let it lie.
//
//       This also removes a spelling dependence, which is the tell that the
//       rewrite is the right one: `[^"]` and `!'"' .` are the same language, and
//       before I4 they were priced differently -- the first exactly, the second by
//       asking a lookahead about the wrong string. A name is not a language either,
//       nor is an ordered choice among single characters, so the window is measured
//       through both: `!Q .` with `Q <- '"'`, and this project's own metagrammar
//       writing `!('"' / '\\') .` where `[^"\\]` would do, are the same fusion.
//       Only the LOOKAHEAD side is read that generously -- the reader must be a
//       terminal, because the rewrite puts a leaf where a leaf was and a name on
//       that side would be a node deleted from every witness tree.
//
//       I4 STOPS WHERE THE WINDOW DOES. A lookahead at two characters (`!"*/"`),
//       or one whose reader is behind a rule reference (`!'x' A`), or one with no
//       reader after it at all (`Kw <- "if" !Alpha`), spans a window that no single
//       reader decides; those stay on the oracle and stay approximate, and A4 below
//       still keeps a gap from being pushed past them. Fusing those needs a channel
//       from a reader back to the leaf in front of it -- an emission, not a
//       consumption -- and that is a wider value than I1's, not a rewrite.
//
//       MEASURED, not argued: pushing the constraint down the grammar instead --
//       the obvious static fix, no new state -- cannot be correct. For
//       `S <- !'x' A B; A <- 'a'?; B <- 'b' / 'x';` the constraint belongs to A's
//       character when A emits one and to B's when it does not, and that is not
//       known until run time. Placing it on A alone accepts "x", which the grammar
//       rejects; placing it on both rejects "ax", which the grammar accepts. Both
//       checked with the pure parser, no recovery involved (`_nullseq45.dart`).
//
//   I5  THE WITNESS IS A PROOF, SO CHECK IT. Everything above computes over the
//       input and reports a cost for a string it never builds. The tree says
//       exactly what to write at every position, so build that string and give it
//       to the parser. This is the only place where s' exists, and it is exact
//       where the search is not -- the parser decides predicates on the actual
//       characters -- so the family I4 cannot reach stops being SILENTLY wrong and
//       becomes REPORTED wrong, in `lastVerified`. One parse, O(|G|.n), against a
//       search that is O(|G|.n.K).
//
//       An engine that can be wrong and knows when is strictly better than one
//       that can be wrong and cannot tell, and the difference costs a walk of the
//       tree it already built. It is not a repair of the flaw and does not pretend
//       to be: what it removes is the SILENCE.
//
// THERE IS NO THIRD EDIT. Deletion is not a primitive here and needs no rule: it
// is I2's SUB, applied to `Nothing`. To substitute a terminal is to consume the
// character in front of it and emit what the terminal accepts instead; what
// `Nothing` accepts is the empty string, so ITS substitution consumes a character
// and emits nothing -- which is deletion, exactly, at the same price of one.
// Repeat it -- a cons whose tail is itself, which is all a repetition is -- and a
// run of characters has been discarded, one unit each. `_junk` below is that
// clause in full, and `_compute` gains no case for it. m41 spelled the exclusion
// out, `clause is Terminal && clause is! Nothing`, and then hand-wrote a third
// insertion to replace what it had just forbidden.
//
// m41 needed a third insertion for this, stated as a rule of SEQUENCING -- "only
// a sequence has a between" -- and that was one abstraction too high. A gap is
// not between two elements; it is IN FRONT OF THE NEXT CHARACTER ANYONE READS.
// Moving it there deletes the last line of recovery logic in any combinator:
// `_chain` below is now `Seq.match`, verbatim, over I1's value, and `_Alt` is
// `First.match`. Recovery has stopped being an algorithm that borrows from the
// parser and become a value the parser computes.
//
// It also deletes an AMBIGUITY, which is the through-line of this whole engine
// (see the note above `_junk`): m41 could attach one gap at every enclosing
// sequence whose current element began there, so the same repair had as many
// derivations as the grammar had nesting. Here a gap has exactly one attachment
// point -- the terminal that follows it -- so it has exactly one derivation.
//
// The dot is still gone, and for m41's reason. A memo entry per element boundary
// is what a sequence needs, and the parser memoizes whole clauses. CURRYING
// SUPPLIES IT FOR FREE: a sequence is a chain of binary cells `Cons(head, tail)`,
// so every element boundary already IS a clause and the memo key is
// (clause, position), exactly the parser's. No dot, no dot-indexed memo blocks,
// no per-clause dot arithmetic.
//
// Currying pays twice more.
//
//   A REPETITION IS A CONS WHOSE TAIL IS ITSELF -- `identical(tail, this)`. That
//   single identity replaces `requireOne` (one Cons in front of the loop), "may
//   this item stop here", "does an element still follow", and the parser's
//   zero-width repetition cut, which is just `identical(tail, this) && end == pos`.
//
//   THE GRAMMAR COLLAPSES TO THREE NODE KINDS: terminal, cons, alternation.
//   `_compute` therefore has three cases. Optional is an alternation ending in
//   the empty match; the empty match and both predicates are terminals that are
//   not allowed to lie; a multi-character string literal is a cons chain of single
//   character ones; a one-character lookahead in front of a one-character reader
//   is neither of those two, but the one class they compose (I4). Every one of
//   these is a rewrite in the builder, and none of them is a case in `_compute`.
//   THERE IS NO KIND FOR A RULE REFERENCE: in the parser a Ref is
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
// A4  EVERY GAP HAS ONE CANONICAL ATTACHMENT POINT, so that one repair has one
//     derivation. LESSONS_LEARNED states this as "only a sequence has a
//     between"; that was the right principle read at the wrong node. A gap
//     attaches IN FRONT OF WHATEVER READS THE INPUT NEXT -- a terminal that
//     consumes a character, or a predicate that only looks at one. Both are
//     readers, and a gap may not be pushed past a predicate to the terminal
//     beyond it: a predicate consumes nothing, but what it decides depends on
//     where it is asked, so moving the gap past it silently loses every repair
//     the predicate blocks (measured: 11 of 19 cases in `_pred42.dart`).
//     `Nothing` is the one leaf whose value does not depend on position, so it is
//     the one leaf a gap can never attach to.
//
// A5  Left recursion is the parser's problem and the parser has solved it, so
//     adopt `MemoEntry` field for field rather than reasoning about cycles here.
//     That is what I1 above is; there is no second cycle argument in this file.
//
// One consequence of A5 is worth naming because it is where the speed is: at
// budget 0 the entry is settled by ONE ORACLE CALL, for every node, because
// every node stands for a clause -- a sequence's suffix as much as the sequence.
//
// ---------------------------------------------------------------------------
// PARAMETERS AND HEURISTICS -- the complete list, because "parameter-free" is a
// claim this engine makes and a reader should be able to check it.
//
//   PARAMETERS: NONE. There is no number in this file that a caller may set or
//   that anyone chose by measurement. The last one was `maxCost`, the deepening
//   ceiling, defaulted to 40; it is now DERIVED, because A1 always leaves one
//   repair available -- discard the whole input, fabricate the goal -- and no
//   minimum-cost repair can cost more than that one does. See
//   `_goalFromNothing`. The public entry points take an input string and
//   nothing else.
//
//   HEURISTIC AFFECTING OUTPUT (one): "prefer the shortest head", the tie-break
//   in `_row`. Chosen because it measures better, not derived. It cannot
//   change any reported cost -- every candidate it ranks is Delta-tied -- only
//   which witness tree comes back.
//
//   HEURISTIC AFFECTING PRESENTATION ONLY (one): a failed witness descent reports
//   the whole input as a single error rather than failing outright. m41 needed a
//   second -- merge consecutive unit SKIPs into one span -- and it is gone: a
//   discarded run is ONE node here, so it arrives as one span already.
//
//   EVERYTHING ELSE IS DERIVED. `_costUnit` and `_costShift` are bounds forced by
//   A3, not settings: any sufficiently large value gives identical answers.
//   `_lastCodeUnit`, which I4 complements a character class over, is the range of
//   `codeUnitAt` -- the alphabet the parser itself compares over, and so the only
//   one an emptiness test may be asked in.
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

  /// A cons whose tail is itself: `head`, repeated. This shape is the ONLY thing
  /// in the engine that means "repetition" -- see `_node` and `_chain`.
  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  /// THE ONE NODE THAT IS NOT IN THE GRAMMAR, and every piece of it is: it is
  /// `Nothing`, allowed to lie, repeated. SUB consumes the character in front of
  /// a terminal and emits what that terminal accepts instead; what `Nothing`
  /// accepts is the empty string, so its substitution consumes a character and
  /// emits nothing -- which is deletion, exactly, at I2's price of one. The self
  /// loop repeats it, making a run of j characters j unit steps (A1), with no
  /// loop over span lengths anywhere and no case in `_compute`.
  ///
  /// m41 wrote `clause is Terminal && clause is! Nothing` to stop precisely this,
  /// and needed a hand-written third insertion in its place. This is that one
  /// forbidden clause, and it is the whole of deletion.
  ///
  /// There is exactly ONE of it for the whole grammar, so every terminal shares
  /// its memo column -- m41 re-derived the same skip at every sequence cell --
  /// and `identical` recognises it, the same idiom as `identical(tail, this)`.
  /// Being one node, a run of any length is also ONE leaf of the witness tree,
  /// which is why nothing below merges adjacent gaps back together.
  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true), const Nothing());

  /// A terminal, preceded by whatever had to be discarded to reach it (A4). This
  /// wrapper is the entire mechanism of deletion: there is no other.
  _Node _wrap(_Node terminal, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = terminal;

  /// The last code unit. `CharSet.match` compares `codeUnitAt`, so the code units
  /// ARE the alphabet the parser decides over, and complementing a class over them
  /// is exact rather than approximate. (`_widestClass` above measures information,
  /// not membership, which is why it counts code points instead.)
  static const int _lastCodeUnit = 0xFFFF;

  /// The code units a clause accepts as EXACTLY ONE character, or null if it is
  /// not a one-character reader -- which is where I4 stops.
  ///
  /// A NAME IS NOT A LANGUAGE AND NEITHER IS A CHOICE. `!Q .` with `Q <- '"'`,
  /// and this project's own metagrammar writing `!('"' / '\\') .` where `[^"\\]`
  /// would do, look at exactly one character each; refusing them would leave I4
  /// pricing the spelling in precisely the cases real grammars are written in.
  /// An ordered choice among one-character readers is their union -- order
  /// cannot matter when every branch consumes one character and only membership
  /// is asked. `seen` is the guard a name needs: a rule that refers to itself is
  /// not a class.
  List<(int, int)>? _oneCharClass(Clause clause,
          [Set<String> seen = const {}]) =>
      switch (clause) {
        AnyChar() => const [(0, _lastCodeUnit)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 =>
          [(text.codeUnitAt(0), text.codeUnitAt(0))],
        CharSet(:final ranges, :final inverted) =>
          inverted ? _complement(ranges) : ranges,
        First(:final subClauses) => _union(subClauses, seen),
        Ref(:final ruleName) when !seen.contains(ruleName) =>
          _oneCharClass(_rules[ruleName]!, {...seen, ruleName}),
        _ => null,
      };

  /// The union of one-character readers, or null if any of them is not one.
  List<(int, int)>? _union(List<Clause> parts, Set<String> seen) {
    final out = <(int, int)>[];
    for (final part in parts) {
      final ranges = _oneCharClass(part, seen);
      if (ranges == null) return null;
      out.addAll(ranges);
    }
    return out;
  }

  /// The code units NOT in `ranges`. Sorting first is what makes one sweep
  /// correct for ranges given in any order, overlapping or not -- the metagrammar
  /// promises neither.
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

  /// The code units in both. Ranges stay unsorted and that is fine: membership is
  /// a disjunction, and EMPTINESS is the only property anything below asks for.
  static List<(int, int)> _intersect(List<(int, int)> a, List<(int, int)> b) => [
        for (final (alo, ahi) in a)
          for (final (blo, bhi) in b)
            if (alo <= bhi && blo <= ahi)
              (math.max(alo, blo), math.min(ahi, bhi)),
      ];

  /// I4, as a rewrite: a lookahead at one character in front of a reader that
  /// consumes one IS a reader, and this is the class it reads. Null when either
  /// half is anything else, and then the pair is built as it always was.
  ///
  /// THE READER MUST BE A TERMINAL, though `_oneCharClass` would happily see
  /// through a name or a choice on that side too. The rewrite replaces a LEAF
  /// with a LEAF; fusing across `A` in `!'x' A` would delete A's node from every
  /// witness tree, and the tree is the deliverable. A lookahead has no such node
  /// to lose -- it consumes nothing and appears in no tree -- which is why the
  /// two sides are not symmetric.
  Clause? _fuse(Clause lookahead, Clause reader) {
    if (reader is! Terminal) return null;
    final reads = _oneCharClass(reader);
    if (reads == null) return null;
    final looks = switch (lookahead) {
      FollowedBy(:final subClause) => _oneCharClass(subClause),
      NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
          final looked? => _complement(looked),
          null => null,
        },
      _ => null,
    };
    return looks == null ? null : CharSet(_intersect(looks, reads));
  }

  /// Rewrite a sequence's parts, right to left so that a RUN of lookaheads
  /// (`&C &D T`) collapses one pair at a time into the class of all of them.
  List<Clause> _fuseLookaheads(List<Clause> parts) {
    final out = <Clause>[];
    for (var i = parts.length - 1; i >= 0; i--) {
      final fused = out.isEmpty ? null : _fuse(parts[i], out.first);
      if (fused == null) {
        out.insert(0, parts[i]);
      } else {
        out[0] = fused;
      }
    }
    return out;
  }

  /// Right-nest `parts` into cons cells. The cell at element i denotes the
  /// sequence's suffix from i, which IS a clause -- that is why `orig` is total.
  /// A sequence with no fusable pair in it comes out of I4's rewrite unchanged,
  /// so a grammar without lookahead is built exactly as m44 built it.
  _Node _cons(List<Clause> parts, Clause orig) {
    parts = _fuseLookaheads(parts);
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
      // A LEAF, and a gap attaches in front of whatever READS the input next:
      // a terminal that consumes a character, or a predicate that only looks at
      // one. Both depend on WHERE they are evaluated, which is why the gap
      // cannot be pushed past a predicate to the terminal after it -- doing so
      // silently loses every repair that a predicate blocks. `Nothing` above is
      // the one leaf whose value does not depend on position, so it is the one
      // leaf a gap can never attach to.
      //
      // Only a consuming terminal may LIE (I2): a predicate consumes nothing, so
      // substituting or fabricating it would edit the derivation rather than the
      // string, and only the string is being repaired. And only a terminal that
      // accepts at least one CHARACTER consumes one -- a lie is about which
      // character is there, so a class with no members has nothing to be wrong
      // about. That is where an impossible lookahead lands (`&'x' 'y'` fuses to
      // the empty class), and it leaves the branch dead rather than cheap.
      final accepts = _oneCharClass(clause);
      node = _wrap(
          _term(clause, accepts?.isNotEmpty ?? clause is Terminal), clause);
    }
    return _nodes[clause] = node;
  }

  /// THE GOAL: the top rule, then whatever is left over. Leading garbage needs no
  /// mention -- it is discarded in front of the first terminal anyone reaches,
  /// like any other gap. Trailing garbage is the one gap with no terminal after
  /// it, so the goal supplies one: the empty match, wrapped exactly as every
  /// terminal is. There is no lead/trail arithmetic anywhere in this engine.
  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  /// A1'S TRIVIAL REPAIR, PRICED -- and with it the deepening ceiling, which is
  /// the last number in this engine that used to be chosen rather than derived.
  ///
  /// Whatever the input, ONE REPAIR IS ALWAYS AVAILABLE: fabricate the goal
  /// consuming nothing, and discard the whole input as junk behind it. By A1
  /// that costs `n`, one unit per character discarded, plus the count below. No
  /// minimum-cost repair can exceed that sum, so deepening past it can only
  /// fail, and `n + this` is a ceiling in the same sense `_costUnit` is a bound:
  /// forced, not set.
  ///
  /// The count is the minimum number of fabrications that derive a node while
  /// consuming nothing. A consuming terminal must be fabricated; the empty match
  /// and the predicates are already there; a repetition stops at zero
  /// iterations; a choice takes its cheapest branch; a sequence pays for all of
  /// its elements. That is a least fixed point over the node graph -- start at
  /// "impossible" and relax until nothing improves, the same shape as every
  /// other fixed point here -- and, being a property of the grammar alone, it is
  /// computed once and never per input.
  ///
  /// A PREDICATE IS THE ONE LEAF THAT MAY NOT BE COUNTED. The trivial repair can
  /// fabricate at ANY position -- junk discards `[0, p)` in front of it and
  /// `[p, n)` behind it, at the same total of n either way -- so the derivation
  /// being priced has no position of its own, and a predicate does: it is the one
  /// leaf whose answer depends on where it is asked, and no edit can change that
  /// answer (I2 lets a leaf lie about the STRING, and a predicate consumes none of
  /// it). So the only derivation guaranteed to exist wherever it is placed is one
  /// that contains **no predicate at all**, and that is what the first pass prices.
  ///
  /// If every derivation of the goal needs one, there is nothing to be sure of,
  /// and the second pass trusts them -- the same envelope PRED describes, and the
  /// only assumption in this file. I4 shrank what reaches it: a lookahead fused
  /// into the class beside it is a plain terminal here and is PRICED, not
  /// assumed, so only a lookahead I4 could not reach (`!"ab" 'y'`, two characters
  /// wide) still forces the second pass. `S <- &'x' 'x' / 'y' 'y' 'y' 'y'` used
  /// to be the example, and is now the demonstration: the first branch fuses to
  /// `[x]`, the first pass prices the goal at 1, and the engine reports 1 for the
  /// empty input -- which is the truth, and what m44 reported 4 for.
  ///
  /// If even that is impossible the goal has NO finite derivation -- the
  /// grammar's language is empty, `S <- S 'a'` and its kind -- so no input is
  /// repairable at any cost, and the caller is told so without a search.
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
    // One rule per node kind, relaxed until nothing improves. The rules ARE the
    // seeds -- a terminal's price does not depend on anything else, so the first
    // sweep initialises the leaves and every later sweep propagates them.
    int cheapest(bool trustPredicates) {
      final cost = List.filled(_nodeCount, _impossible);
      for (var improved = true; improved;) {
        improved = false;
        for (final node in all) {
          final now = switch (node) {
            // Trusting the predicates means the PREDICATES. A terminal that
            // accepts no character is not one -- it is I4's empty class -- and
            // pricing it 0 would hide an empty language behind a ceiling.
            _Term(:final editable, :final orig) => editable
                ? 1 // fabricate it: I2's FAB, price 1
                : orig is Nothing || (trustPredicates && orig is! Terminal)
                    ? 0 // already there, or assumed to be
                    : _impossible,
            // A cons cell whose tail is itself is a repetition: zero iterations.
            _Cons() => identical(node.tail, node)
                ? 0
                : cost[node.head.id] + cost[node.tail.id],
            _Alt() => node.alts
                .fold(_impossible, (best, alt) => math.min(best, cost[alt.id])),
          };
          if (now < cost[node.id]) {
            cost[node.id] = now;
            improved = true;
          }
        }
      }
      return cost[_goal.id];
    }

    final sure = cheapest(false);
    return sure < _impossible ? sure : cheapest(true);
  }();

  /// Not a bound anyone chose: a node this expensive to fabricate cannot be
  /// fabricated at all, and every arithmetic below keeps it saturated.
  static const int _impossible = 1 << 30;

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

  /// I5: whether the witness `recover` last returned was CHECKED to be a repair --
  /// applied to the input and parsed. See `_verify`.
  bool lastVerified = false;

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
    // With no edits to spend the repaired string IS the input, PEG is
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
        // ORDERED choice, over a value that is a set -- and a rule reference is
        // the choice among one. Nothing about recovery appears here, because a
        // gap before a chosen alternative is a gap before that alternative's
        // first element, which attaches further up.
        if (alts.length == 1) return _ends(alts[0], pos, budget);
        // I3, and this is the whole of it. `committed` is the one integer the
        // oracle knows here that the union above does not: where PEG itself
        // stops at this position, or -1 for "nowhere", which is below every end.
        //
        // ASK THE MEMO, NOT THE CLAUSE. `Clause.match` is the raw combinator;
        // the grow loop that expands a left recursive cycle lives in `MemoEntry`
        // and is only reached through `Parser.match` -- which is why `Ref.match`
        // delegates to it. Everywhere else in this file the oracle is asked at a
        // Ref, a terminal or a sequence of them, so the raw call is already the
        // memoized one. This is the one place that asks at a RULE BODY, where
        // the raw call returns the left recursive seed and not the grown match:
        // measured, `E <- E '+' T / T` on "1+2++3" answers 1 raw and 3 memoized,
        // and the seed vetoes the correct one-edit repair. Keyed by the body
        // clause, this is the very entry the parser itself uses for that rule,
        // so it costs a memo hit and nothing else.
        final oracle = _parser.match(node.orig, pos);
        final committed = oracle.isMismatch ? -1 : pos + oracle.len;
        final out = <int, int>{};
        final limit = (budget + 1) * _costUnit;
        for (final alternative in alts) {
          for (final e in _ends(alternative, pos, budget).entries) {
            if (e.value >= limit) continue;
            // I3: a candidate that spends nothing over [pos, end) leaves s'
            // equal to the input there, so if it reaches PAST where the oracle
            // stopped, the alternative the oracle took still matches s' and PEG
            // commits to that one instead. The candidate is unreachable however
            // cheap it looks. Ends SHORT of the oracle's are kept: s' may differ
            // beyond them, and then an earlier alternative may fail there.
            if (e.value < _costUnit && e.key > committed) continue;
            _keepBest(out, e.key, e.value);
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
        if (pos < _inputLen) {
          // SUB: the character in front of the terminal is consumed and what the
          // terminal accepts is emitted instead, so the character's own evidence
          // is discarded -- twice h, by A2. No case asks whether the terminal
          // already matches: if it does, and it took that character, it is
          // already here at a lower price and the min keeps that one.
          _keepBest(out, pos + 1, _costUnit + 2 * _skipRegret(pos, pos + 1));
        }
        // FAB: the text the terminal stands for is invented outright, which
        // commits a full alphabet's worth of information -- the most any single
        // move can commit, and the price is forced by A2.
        _keepBest(out, pos, _costUnit + _widestClass);
        return out;
    }
  }

  /// Sequencing. This is `Seq.match` over I1's value and NOTHING ELSE -- there is
  /// no recovery logic in it, nor in any other combinator. Compare the parser: it
  /// matches the head, then matches the tail from where the head ended, and a
  /// repetition is the case where the tail is the node itself.
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
          final m = _child(alternative, pos, end, delta, budget);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, end, delta, budget);
        return children == null
            ? null
            : Match(orig, pos, end - pos, subClauseMatches: children);
    }
  }

  /// One sub-derivation's contribution to the row it sits in -- normally itself,
  /// as one child. TWO THINGS ARE NOT LEVELS OF THE TREE, and both are `_junk`.
  /// A discarded run is the one leaf not built from a clause, and it is ONE leaf
  /// however long the run is -- the self loop is one node -- so nothing below
  /// merges adjacent gaps, and discarding nothing leaves no trace at all. The
  /// wrapper `_junk` sits in is an artifact of I2, not a clause, so it is
  /// spliced: the gap arrives as a sibling of whatever it interrupted rather than
  /// as a parent of the terminal that followed it, and terminals stay leaves. A
  /// clean parse therefore reconstructs to exactly the pure parser's tree.
  List<MatchResult>? _child(_Node node, int pos, int end, int delta, int budget) {
    if (identical(node, _junk)) {
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, end, delta, budget);
    }
    final m = _build(node, pos, end, delta, budget);
    return m == null ? null : [m];
  }

  /// Walk a cons chain, emitting the children of ONE row: one per element, or one
  /// per iteration when the tail is the node itself, so the child list comes out
  /// flat either way.
  List<MatchResult>? _row(_Node node, int pos, int end, int delta, int budget) {
    if (node is! _Cons) {
      // The empty match closes every chain and contributes no child of its own.
      // Any OTHER terminal reached here is one a discarded run was wrapped
      // around, and it is a child like any other.
      return identical(node, _eps)
          ? (pos == end && delta == 0 ? const [] : null)
          : _child(node, pos, end, delta, budget);
    }
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
      final head = _child(node.head, pos, headEnd, headDelta, budget);
      if (head == null) continue;
      final tail = _row(node.tail, headEnd, end, rest, restBudget);
      if (tail != null) return [...head, ...tail];
    }
    // A repetition may stop wherever it stands.
    return loops && pos == end && delta == 0 ? const [] : null;
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

  /// I5: THE WITNESS IS A PROOF, SO CHECK IT. Everything above computes over the
  /// input; the answer is a claim about a string that was never built. Build it --
  /// the tree says exactly what to write at every position -- and give it to the
  /// parser. A tree that parses is a repair, demonstrated rather than argued.
  ///
  /// This is the only place in the engine where s' EXISTS, and it is exact where
  /// the search is not: predicates are decided by the parser on the actual string,
  /// so the one family I4 cannot reach (§5o: a lookahead whose reader is behind a
  /// rule reference, wider than a character, or trailing) is not silently wrong
  /// here -- it is REPORTED wrong, in `lastVerified`. One parse, O(|G|.n), against
  /// a search that is O(|G|.n.K): the honesty is free.
  ///
  /// The walk is `_collect` again, emitting instead of recording, with one extra
  /// case: children need not tile their parent, and text they leave uncovered is
  /// input passing through unedited -- which is what a hidden rule (`~WS`) looks
  /// like from here.
  void _emit(MatchResult m, StringBuffer out) {
    if (m is SyntaxError) return; // SKIP emits nothing, by construction
    final clause = m.clause;
    if (m.subClauseMatches.isEmpty) {
      // A leaf that lies emits what it accepts; one that does not emits the
      // input it matched. `_widest` is a member of the class, and membership is
      // the only thing the parser will ask of it.
      out.write(clause is Terminal &&
              clause is! Nothing &&
              (m.len == 0 || clause.match(_parser, m.pos).isMismatch)
          ? _spelling(clause)
          : _input.substring(m.pos, m.pos + m.len));
      return;
    }
    var cursor = m.pos;
    for (final child in m.subClauseMatches) {
      if (child.pos > cursor) out.write(_input.substring(cursor, child.pos));
      _emit(child, out);
      cursor = child.pos + child.len;
    }
    if (cursor < m.pos + m.len) {
      out.write(_input.substring(cursor, m.pos + m.len));
    }
  }

  /// Some string the terminal accepts. A class is represented by a member of it,
  /// which is all a lie needs to be: I2 prices WHICH character is there, never
  /// which member was picked.
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

  SkipResult recover(String input) {
    final cost = recoverCost(input);
    _spans.clear();
    _missing.clear();
    _path.clear();
    lastVerified = false;
    if (cost == 0) {
      // The input itself parsed. That IS the check, already run.
      lastVerified = true;
      return SkipResult(_clean!, const [], const [], 0, false);
    }
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
    lastVerified = _verify(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  int recoverCost(String input) {
    _input = input;
    _inputLen = input.length;
    _clean = null;
    final goal = _goal; // force the normal form, and with it `_terminals`
    // THE CEILING, DERIVED: discard the whole input and fabricate the goal.
    // That repair really exists, so no minimum-cost repair costs more, and
    // deepening past it can only fail. A goal that cannot be fabricated at all
    // cannot be derived at any price, which is a `-1` nobody has to search for.
    // See `_goalFromNothing`.
    final maxCost =
        _goalFromNothing < _impossible ? _inputLen + _goalFromNothing : -1;
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
