// m57 -- recovery is the parser over a wider value, SCHEDULED BY DELTA: the
// worklist pops work in order of increasing repair cost, so every fact settles
// once, at its own price, and the deepening ladder, the budget, and the search
// ceiling are DELETED rather than tuned.
//
// Read this file next to `lib/src/parser/memo_entry.dart` and m53.dart. The
// value, the pricing, the obligation channel, the veto, the witness and the
// verification are m53's, unchanged; what changes is WHEN things run. The full
// derivations of I1-I11 are m53's header and LESSONS_LEARNED §5k-§5r; one line
// each here:
//
//   I1  THE VALUE: a match is "the cheapest repair to each end"; the parser's
//       fixed-point test becomes "no end is new and no price is lower".
//   I2  A TERMINAL MAY LIE: SUB and FAB, price one each; deletion is SUB on
//       `Nothing`, repeated (`_junk`); there is no third edit.
//   I3  THE ORACLE IS AUTHORITATIVE AS FAR AS THE EDIT-FREE WINDOW REACHES:
//       a Delta=0 candidate ending past the oracle's committed end is vetoed.
//   I4  A one-character lookahead in front of a one-character reader IS the
//       class the two compose; fused in the builder; an optimization only.
//   I5  THE WITNESS IS A PROOF, SO CHECK IT: emit s', parse it, report
//       `lastVerified`.
//   I6  A lookahead is a constraint on the next character EMITTED, carried
//       DOWN as the memo dimension `c`.
//   I7  AN OBLIGATION IS PART OF THE VALUE: every end is paired with the class
//       it still owes -- (end, owed) is the key. DOWN THE TREE IS THE ARGUMENT,
//       ACROSS THE TREE IS THE VALUE, UP THE TREE IS THE MEMO.
//   I9  THE FIXED POINT TEST IS THE WRITE: the value is a flat (key, Delta)
//       pair list, relaxed in place; `_keepBest` already knows whether anything
//       improved.
//   I11 A DEPENDENCY IS AN EDGE OF THE GRAMMAR, NOT AN ADDRESS: a cell holds
//       the cells it reads, by slot, and the reverse edge is the forward edge's
//       transpose, declared once where the forward edge is.
//
//   I8, REVISED BY I14. I8 said POSITION is the stratification variable; the
//       fourteenth occasion measured that position was only ever a proxy for
//       Delta (LESSONS §5j). m50-m53 kept iterative deepening as an outer loop
//       -- raise every cell's budget, re-drain, repeat -- and the two
//       refutations recorded there corner it: the rounds cannot be skipped
//       (I12: the values genuinely grow every round) and cannot be taken in
//       larger steps (I13: work explodes past the true cost, 6x on the
//       measured case). The only move left is to make the step infinitesimal.
//
//   I14 DELTA IS THE SCHEDULE. The budget was the watermark, read backwards.
//
//       Order the queue by TOTAL price -- the Delta a piece of work cannot
//       come in under -- and pop in that order. Then:
//
//       * THE LADDER IS GONE. There is no round, no budget field, no budget
//         argument, and none of the four budget cut sites. The first goal fact
//         to SETTLE (pop at its own priority) is the minimum, by the same
//         invariant that makes Dijkstra correct: every push carries a priority
//         no smaller than the watermark it was pushed at, because Delta is
//         additive and non-negative (Knuth's superiority condition), so
//         nothing pending can undercut what has already popped.
//
//       * THE CEILING IS GONE AS A SEARCH BOUND. The ladder needed `n + F` to
//         know when to stop deepening an unrepairable input; here the queue
//         simply drains -- the fact space is finite and every push is a strict
//         improvement of some (cell, key) pair. `_goalFromNothing` survives
//         with its other two jobs: it prices A3's cost unit (the regret field
//         must fit under one edit), and it answers an EMPTY LANGUAGE in O(|G|)
//         with no search at all.
//
//       * A CELL IS STAMPED WITH ITS CONTEXT PRICE, ONCE. `g` is the total
//         Delta already spent when the cell is first demanded. Demands are
//         issued only by settled facts, and settled facts arrive in watermark
//         order, so the FIRST demand is the cheapest and `g` is final -- the
//         min-cost analogue of "the budget only ever rises", with the rise
//         deleted. A fact's priority is `g + Delta(local)`, a true lower bound
//         on any repair through it.
//
//       * WHAT THE BUDGET'S SECOND JOB BECOMES (LESSONS §5d: the budget also
//         BOUNDS THE DESCENT). A created cell does not expand: its first
//         relaxation is queued at priority `g` and runs only if the watermark
//         reaches it. A cell demanded at the frontier -- `g` just under the
//         answer -- contributes its seed and nothing else, exactly the leaf
//         that `budget == 0` used to make. Locality is the pop order itself.
//
//       * WHAT THE ORACLE SHORT-CIRCUIT BECOMES (the 2x the fourteenth
//         occasion could not place). At creation a cell is SEEDED with the
//         pure parser's own match -- one memoized call answering a whole
//         subtree, the same singleton the `budget == 0` walk produced. The
//         seed is SOUND BECAUSE IT IS REDUNDANT: on a subtree with no
//         unfused lookahead, the oracle's match is itself one of the
//         derivations the structural rules would find (PEG's own choice, at
//         cost 0), so seeding adds a shortcut, never a new answer. A subtree
//         CONTAINING a lookahead is not seeded -- its facts must carry `owed`
//         debts the whole-clause match cannot see (`Kw <- "if" !Alpha` would
//         discharge !Alpha against the input) -- and settles structurally,
//         exactly as every fact did in m53. `_noLook` is that one static bit.
//
//       * THE LEFT-RECURSION RULE IS UNTOUCHED. A zero-progress cycle lives
//         inside one priority class and iterates there until nothing improves
//         -- the fourteenth occasion's "(Delta, pos) with fixpoint iteration
//         inside each class", emergent rather than coded. `foundLeftRec`,
//         `inRecPath`, ranks and rounds all remain deleted, as in m50-m53.
//
//       THE LINE CLOSES A CIRCLE. `dot`, the first engine, was already a
//       best-first agenda over (cost, regret) -- Dijkstra without the parser:
//       eager axioms at every position, no oracle, no demand, 12.9x the
//       baseline. The m-line replaced the schedule with budgets and won 25x.
//       m57 is the schedule again, with everything the budget era learned
//       inside it: the oracle seed, demand-driven cells, the obligation
//       channel, the in-place value. The first idea was right; it was the
//       machinery around it that was wrong.
//
// PARAMETERS AND HEURISTICS -- the complete list:
//
//   PARAMETERS: NONE. No number a caller may set, no deepening ceiling, no
//   budget. The public entry points take an input string and nothing else.
//
//   HEURISTIC AFFECTING OUTPUT (one): "prefer the shortest head", the witness
//   tie-break in `_row`, unchanged from m41-m53. It cannot change a cost.
//
//   HEURISTICS AFFECTING WORK ONLY (one): I4's static fusion (+7.3% `_compute`
//   calls without it). The pop order is NOT a heuristic here: it is the
//   correctness argument (first settlement is minimal), the way the budget
//   filter was A3's correctness argument before it.
//
//   HEURISTIC AFFECTING PRESENTATION ONLY (one): a failed witness descent
//   reports the whole input as a single error rather than failing.
//
//   EVERYTHING ELSE IS DERIVED: `_costUnit`/`_costShift` are A3's bound,
//   `_widestClass` and `_lastCodeUnit` are the alphabet's, `_goalFromNothing`
//   is A1's trivial repair priced from the grammar alone.
// ---------------------------------------------------------------------------
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

// ERROR RECOVERY START

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

  /// I14: no unfused lookahead anywhere in this subtree, so the oracle's own
  /// match of `orig` is one of the derivations the structural rules would find
  /// -- PEG's choice, at cost 0, owing nothing -- and a cell may be SEEDED with
  /// it at creation. A subtree containing a lookahead may not: its facts carry
  /// `owed` debts a whole-clause match cannot see. Set once by `_looksMarked`.
  bool noLook = true;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable, this.demands);

  /// Whether I2 applies. False for `Nothing` and for both predicates: they
  /// consume no input, so substituting or fabricating them would edit the
  /// derivation rather than the string, and only the string is being repaired.
  final bool editable;

  /// I6: the class this leaf demands of the next character anyone emits, if it is
  /// a lookahead at one character. `_free` for every other leaf, which is every
  /// leaf in a grammar without lookahead.
  final int demands;
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

/// I8: ONE CELL OF THE MEMO, AND IT IS THE UNIT OF WORK. `_Entry` in m49 was
/// `MemoEntry` field for field: a value, a budget, and FOUR fields of left
/// recursion machinery (`inRecPath`, `foundLeftRec`, `memoVersion`, and the loop
/// that read them). Those four are gone, and what replaces them is the two fields
/// below that any worklist has -- am I scheduled, and who reads me.
class _Cell {
  _Cell(this.node, this.pos, this.c, this.g);

  /// The cell's own coordinates. m49's frame carried these as ARGUMENTS, which is
  /// why m49 needed a frame; a cell that knows where it is can be relaxed by
  /// anybody.
  final _Node node;
  final int pos;
  final int c;

  /// I14: the total Delta already settled when this cell was FIRST demanded --
  /// the price of the cheapest context that needs it. Demands are issued only by
  /// settled facts, and settled facts arrive in watermark order, so the first
  /// demand is the cheapest and `g` is final. A fact's queue priority is then
  /// `g + Delta(local)`: a true lower bound on any repair through it. This field
  /// is what remains of the BUDGET -- the budget was `k - g`, recomputed every
  /// round; the `k` is gone and the `g` never changes.
  final int g;

  /// I1: `MemoEntry.result`, widened from the best match to the best Delta for
  /// every reachable end -- and by I7 every end is an end AND THE OBLIGATION
  /// STILL OWED THERE, packed into one key. Null until first relaxed, which is
  /// also I1's left recursive seed: a cell nobody has settled yet reads as the
  /// empty set, exactly what m49's `inRecPath` branch returned.
  ///
  /// I9: A FLAT LIST OF PAIRS -- `value[2i]` is a key and `value[2i + 1]` its
  /// Delta -- and the SAME list for the cell's whole life, written into by every
  /// relaxation. Mean width 1.63, so a scan beats a hash; and 2.43 relaxations per
  /// cell, so what m50 allocated it allocated 2.43 times over.
  List<int>? value;

  /// I3's oracle verdict for an alternation cell: where PEG itself stops at this
  /// position, or -1 for "nowhere". A fact about the input, so it is computed
  /// once at expansion and read by every later combine. (m54 measured this cache
  /// worthless when the probe ran ~2 times per cell; the semi-naive combine asks
  /// per DELIVERED FACT, which is what makes it worth a field now.)
  int committed = -2;

  /// THE REVERSE EDGES, and the whole of what m49 spent four fields guessing at.
  /// `foundLeftRec` was one bit of "somebody below me will need me again"; this is
  /// the exact set of edges that read this cell -- and under I14 the edge carries
  /// its SLOT, because a settling fact is not a request to recompute the reader
  /// from scratch: it is ONE new operand for ONE edge, and the slot says which.
  /// `readers[i]` reads this cell at its `readerSlots[i]`-th edge.
  final List<_Cell> readers = [];
  final List<int> readerSlots = [];

  /// I11: THE FORWARD EDGES, in the order this cell reads them -- slot 0 is an
  /// alternation's first branch or a sequence's head, and slot `1 + i/2` is the tail
  /// under the head's i-th answer. Grown on demand, and never revised: the cell at a
  /// slot is fixed for the life of the search, because a value's key at a given index
  /// is fixed once written (I9 appends and lowers, and does nothing else).
  ///
  /// `readers` above is this list's transpose, and the two are kept for opposite
  /// reasons: the reverse edges are CONSUMED by a wake (I10) because a woken cell
  /// re-declares them, and the forward edges are KEPT for the same relaxation,
  /// because re-declaring them is the hash lookup this insertion exists to remove.
  List<_Cell?>? deps;
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

  _Node _term(Clause clause, bool editable, int demands) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable, demands);
  }

  /// The empty match: the last alternative of every Optional, the node a
  /// `Nothing` in the grammar denotes, and the END OF EVERY CONS CHAIN. It is a
  /// terminal, so it needs no case.
  ///
  /// I7: IT NEITHER ENFORCES A PENDING OBLIGATION NOR DISCHARGES ONE. It PASSES
  /// it, exactly like every other move that emits nothing, and needs no words of
  /// its own to do so -- the `Nothing` rule already says it. m47 discharged here
  /// and UNDER-REPORTED (`_leak47`: 0 where the truth is 1); m48 enforced here and
  /// over-reported wherever the reader was in the caller (`_leak48` block D). Both
  /// were guesses about a continuation the value could not see, and it sees it.
  late final _Node _eps = _term(const Nothing(), false, _free);

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
      _selfLoop(_term(const Nothing(), true, _free), const Nothing());

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

  // ---- I6/I7: the obligation lattice ---------------------------------------
  //
  // An obligation is a class of code units and it means "the next character
  // emitted from here on is one of these". `_free` -- nothing owed -- is the top,
  // and the only value a grammar without lookahead ever uses. The EMPTY class is
  // the bottom and is not a special case anywhere: it says no character may be
  // emitted and the string may not end either, which is a dead derivation, and
  // that is exactly what `&'x' !'x'` is. m47 and m48 gave the empty class a name
  // (`_silent`) and a meaning of its own -- "this derivation emits nothing" --
  // which I7 does not need, because emitting nothing does not satisfy an
  // obligation, it passes it on.
  //
  // END OF INPUT IS A MEMBER OF THE ALPHABET, and that is the whole difference
  // between the two predicates. `codeUnitAt` never returns -1, so -1 is free to
  // mean "no character follows at all": `!C` is the complement of C WITH -1 in
  // it, `&C` is C without, and a negative lookahead therefore succeeds at the end
  // of the string where a positive one fails, without a line anywhere saying so.
  // Interning merges (-1,-1) into an adjacent (0,k) as (-1,k), which preserves
  // the set, so nothing downstream has to know it is there.
  //
  // Meet is intersection. Classes are interned so an obligation is an integer,
  // and so the lattice is finite: it is the closure under intersection of the
  // grammar's one-character lookahead classes, a property of the grammar alone.

  /// No obligation: an INDEX INTO `_classes` that is not one, the top of the
  /// lattice. It shares the number -1 with `_endMark` and nothing else: one
  /// indexes classes and the other is a code unit, and no expression below mixes
  /// them.
  static const int _free = -1;

  /// The end of the string, as a member of the alphabet. See above.
  static const int _endMark = -1;

  /// Interned classes. Nothing is seeded: m47 and m48 had to put the empty class
  /// at index 0 because index 0 meant `_silent`, and getting that seeding wrong
  /// is a bug that reports repairs which do not exist. There is no index 0 to get
  /// wrong here.
  final List<List<(int, int)>> _classes = [];
  final Map<String, int> _classIndex = {};

  /// Intern a class, normalised so that equal classes intern equal: sorted, with
  /// touching and overlapping ranges merged.
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

  /// Both constraints at once. `_free` is the identity, so a cell with no
  /// lookahead in it passes what it was given straight through.
  int _meet(int a, int b) => a == _free
      ? b
      : b == _free
          ? a
          : _intern(_intersect(_classes[a], _classes[b]));

  /// May a move that EMITS a character from `emits` happen while `c` is owed?
  /// Emission is the only thing an obligation constrains: a move that emits
  /// nothing does not ask this question, it passes the obligation on.
  bool _permits(int c, List<(int, int)>? emits) =>
      c == _free || (emits != null && _intersect(emits, _classes[c]).isNotEmpty);

  /// Is one code unit a member of class `c`?
  bool _has(int c, int ch) {
    for (final (lo, hi) in _classes[c]) {
      if (ch >= lo && ch <= hi) return true;
    }
    return false;
  }

  /// The same question for a MATCH, which emits the input it consumed -- so the
  /// character in question is the one already there.
  bool _permitsFirst(int c, int pos) =>
      c == _free || _has(c, _input.codeUnitAt(pos));

  /// May the string END here? The one discharge that is not an emission, and the
  /// only place in the engine that asks it is the top level -- which is what makes
  /// it correct to ask nowhere else, since every other position has a next
  /// character or hands the debt to someone who does.
  bool _permitsEnd(int c) => c == _free || _has(c, _endMark);

  /// The class a lookahead demands of the next character, or null when the clause
  /// is not a lookahead or looks at more than one character. I4 fuses it into the
  /// reader beside it when there is one; I6 carries it as an obligation when there
  /// is not, and the two read the same clause the same way.
  ///
  /// `!C` ALSO HOLDS WHERE NOTHING FOLLOWS, so its class contains `_endMark` and
  /// `&C`'s does not. That one member is the whole of "a negative lookahead
  /// succeeds at the end of the input". It cannot disturb I4, whose intersection
  /// is against a class of real characters, all of them non-negative.
  List<(int, int)>? _looks(Clause clause) => switch (clause) {
        FollowedBy(:final subClause) => _oneCharClass(subClause),
        NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
            final looked? => [..._complement(looked), (_endMark, _endMark)],
            null => null,
          },
        _ => null,
      };

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
  ///
  /// I7 DEMOTED THIS TO AN OPTIMIZATION, and that is worth stating plainly. In
  /// m48 the fusion was load bearing: it was the only way a lookahead's class ever
  /// reached the character it constrained. Under I7 the channel carries the same
  /// class at run time, and it reaches the witness too -- `_build` narrows a lying
  /// leaf by whatever is owed, so the emitted character is legal without the
  /// rewrite.
  ///
  /// MEASURED, with this one line commented out and nothing else changed
  /// (`_m49nofuse.dart`): NO ANSWER MOVES. `_bfpred` still 45/45 and 14/14 with
  /// all four spelling blocks agreeing, `_leak` still 71/71. What moves is WORK:
  /// 383 -> 411 `_compute` calls (`_steps49` / `_steps_nofuse`, +7.3%), and all
  /// of it on the spellings I4 fuses --
  ///
  ///     (!'"' .)* on "x" / "\"x" / ""   41 / 36 / 24  ->  49 / 45 / 28
  ///     [^"]*     on the same, control   38 / 34 / 23  ->  38 / 34 / 23
  ///     (&[a-z] !'q' .)* on "q"                  16  ->  23
  ///     `!'x' A` and `Kw <- "if" !Alpha`, not fusable: identical
  ///
  /// So I4 brings the predicate spelling within 8% of the class spelling of the
  /// same language, and without it the same language costs ~30% more to repair
  /// when written with a predicate. It stays for the constant factor, and because
  /// SPELLING INVARIANCE OF THE WORK is worth having once invariance of the answer
  /// is free -- but nothing depends on it being correct any more.
  Clause? _fuse(Clause lookahead, Clause reader) {
    if (reader is! Terminal) return null;
    final reads = _oneCharClass(reader);
    if (reads == null) return null;
    final looks = _looks(lookahead);
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
  ///
  /// I7 TOOK THE REST OF THIS FUNCTION AWAY. m48 had to decide HERE, statically,
  /// whether a lookahead had a reader after it inside the same sequence -- posting
  /// its class on the cell when it did (and deleting the leaf) and leaving it to
  /// the oracle when it did not -- because a class that reached the end of a chain
  /// had nowhere to go. It has somewhere now: it goes in the value, and a
  /// lookahead is a leaf again like anything else. The nullability fixed point
  /// that gate needed went with it.
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
      //
      // I6/I7: a one-character lookahead I4 could not fuse carries its class as an
      // OBLIGATION instead of reading the input through the oracle -- which would
      // answer about s, the original input, at a position whose character the
      // repair may be about to change. It is the one leaf that decides nothing
      // about where it stands and everything about what comes next.
      final accepts = _oneCharClass(clause);
      final looks = _looks(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks == null ? _free : _intern(looks));
      // AND A GAP ATTACHES IN FRONT OF A READER, which under I7 a one-character
      // lookahead is not: it looks at s', through the obligation, and at no
      // position of the input at all. So there is nothing for a gap in front of it
      // to be in front of -- skipping before it and skipping in front of the next
      // real reader are the same repair, and wrapping it only derives that repair
      // twice. Measured (`_steps49`): 411 -> 383 `_compute` calls over the same
      // battery, with every cost, witness and brute-force verdict unchanged. A
      // lookahead I7 cannot model still asks the oracle WHERE IT STANDS, so it is
      // a reader like any other and keeps its wrapper.
      node = looks == null ? _wrap(leaf, clause) : leaf;
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

  /// I14's one static bit: which subtrees contain NO unfused lookahead, so the
  /// oracle's whole-clause match is one of their own structural derivations and
  /// may seed a cell (see `_cellAt`). `noLook` only ever falls, so this is the
  /// simplest fixed point in the file: sweep until nothing falls. Computed once
  /// per grammar, forced by `recoverCost`.
  late final bool _looksMarked = () {
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
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in all) {
        if (!node.noLook) continue;
        final looks = switch (node) {
          _Term(:final demands) => demands != _free,
          _Cons() => !node.head.noLook || !node.tail.noLook,
          _Alt(:final alts) => alts.any((a) => !a.noLook),
        };
        if (looks) {
          node.noLook = false;
          changed = true;
        }
      }
    }
    return true;
  }();

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
      // THE SAME RECURRENCE WITH THE INPUT TAKEN AWAY, over the same value I7
      // gave the search: what a fabrication costs, per obligation it still OWES
      // when it is done. A number will not do, and neither will pricing the
      // obligations away: one can close the cheap branch of a choice and force a
      // dearer one, so a price computed without them is not an upper bound at all.
      // `S <- !'x' A; A <- 'x' / "yy";` on the empty input is the whole argument
      // -- one fabrication unconstrained, two under `!'x'`, and a ceiling of one
      // would make the engine DECLINE an input it can repair. Rows are allocated
      // when something asks for one, so a grammar without lookahead has exactly
      // one row with one key in every map: m44's table, value for value.
      final cost = <int, List<List<int>>>{};
      var improved = true;
      List<List<int>> row(int c) => cost.putIfAbsent(c, () {
            improved = true;
            return List.generate(_nodeCount, (_) => <int>[]);
          });
      // A cons cell is `_chain` with the input taken away: price the head under
      // the cell's obligation, then the tail under whatever the head still owes.
      List<int> chain(_Cons node, int c) {
        final out = <int>[];
        // A cons whose tail is itself is a repetition: zero iterations, which emit
        // nothing and so still owe what they were given.
        if (identical(node.tail, node)) _keepBest(out, c, 0);
        final heads = row(c)[node.head.id];
        for (var i = 0; i < heads.length; i += 2) {
          final tails = row(heads[i])[node.tail.id];
          for (var j = 0; j < tails.length; j += 2) {
            _keepBest(out, tails[j], heads[i + 1] + tails[j + 1]);
          }
        }
        return out;
      }

      // One rule per leaf, and it is `_compute`'s `_Term` with the input gone:
      // emitting discharges the obligation and costs a fabrication, emitting
      // nothing passes it on and costs nothing.
      List<int> leaf(_Term node, int c) {
        // A lookahead is already there whatever is owed: it emits nothing, and
        // all it does is add its own class to the debt.
        if (node.demands != _free) return [_meet(c, node.demands), 0];
        final emits = node.editable ? _oneCharClass(node.orig) : null;
        // I2's FAB, price 1 -- if what it accepts is something the obligation
        // still allows it to emit. Emitting is what discharges the debt.
        if (emits != null && emits.isNotEmpty) {
          return _permits(c, emits) ? [_free, 1] : const [];
        }
        // Everything else emits nothing and the debt passes through it: the empty
        // match, a `Nothing` allowed to lie (a discarded run, at zero length), and
        // -- in the second pass only -- a predicate this file cannot read. A
        // terminal that accepts NO character is none of these: it is I4's empty
        // class, and pricing it 0 would hide an empty language behind a ceiling.
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
              // A choice is the cheapest branch, per obligation owed -- so it is
              // a MERGE and not a spread, which would keep the last branch's
              // price for a debt two of them can leave.
              _Alt(:final alts) => () {
                  final out = <int>[];
                  for (final alt in alts) {
                    final from = row(c)[alt.id];
                    for (var i = 0; i < from.length; i += 2) {
                      _keepBest(out, from[i], from[i + 1]);
                    }
                  }
                  return out;
                }(),
            };
            // `_keepBest`'s bit is this loop's condition too, which is why there is
            // one of it in the file.
            final known = row(c)[node.id];
            for (var i = 0; i < now.length; i += 2) {
              if (_keepBest(known, now[i], now[i + 1])) improved = true;
            }
          }
        }
      }
      // THE TRIVIAL REPAIR IS THE WHOLE STRING, so whatever it still owes when it
      // ends is discharged by the end of the string and by nothing else.
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
  /// I7: the goal's answer is a (end, owed) key, not a position, so the witness
  /// walk has to be handed the same key the search accepted -- see `recoverCost`.
  int _steps = 0, _bestGoalDelta = -1, _bestGoalKey = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;

  /// I5: whether the witness `recover` last returned was CHECKED to be a repair --
  /// applied to the input and parsed. See `_verify`.
  bool lastVerified = false;

  /// MEASUREMENT ONLY. Distinct memo cells `(node, pos, c)` the last call
  /// demanded, against the size of the whole cell space -- the ratio that refuted
  /// a bottom-up agenda (7-9%, flat in n: seeding the whole space costs an order).
  int get lastCells => _cells.length;
  int get lastSpace =>
      (_nodeCount + 1) * (_inputLen + 2) * (_classes.length + 1);

  /// MEASUREMENT ONLY. Reverse-edge slots currently held, which I10 bounds by the
  /// number of LIVE readers -- without it the store grows with the number of
  /// relaxations instead, since a re-relaxed cell re-declares every edge it had.
  int get lastEdges =>
      _cells.values.fold(0, (sum, cell) => sum + cell.readers.length);

  /// MEASUREMENT ONLY. I11's forward-edge slots, which is what it costs in space to
  /// stop looking those edges up. One per read the engine will ever repeat.
  int get lastForward =>
      _cells.values.fold(0, (sum, cell) => sum + (cell.deps?.length ?? 0));

  /// MEASUREMENT ONLY. Relaxations per cell -- I8's whole cost model. m49's
  /// descent settled a cell in 1.13 `_compute` calls; anything near that means the
  /// worklist bought the stack ceiling for nothing.
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

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

  /// I9. Record `delta` for `key` unless a better one is already there, and SAY
  /// WHETHER IT IMPROVED THE VALUE. That bit is I1's fixed-point test, decided here
  /// where the decision is already being made rather than recomputed afterwards by
  /// comparing two maps -- which is the whole of what m50's `_relax` did with the
  /// map it allocated to compare.
  ///
  /// The scan is the representation's price and its point: at width 1.63 the loop
  /// body runs less than once on average, and there is no hash, no mask, no probe
  /// and no `MapEntry`.
  static bool _keepBest(List<int> out, int key, int delta) {
    for (var i = 0; i < out.length; i += 2) {
      if (out[i] != key) continue;
      if (out[i + 1] <= delta) return false;
      out[i + 1] = delta;
      return true;
    }
    out
      ..add(key)
      ..add(delta);
    return true;
  }

  /// The same, into the cell being relaxed. `_out` is that cell's own value and
  /// `_cur` the cell itself; both are fields rather than arguments because
  /// `_compute` is reached from `_relax` and from nowhere else -- `_dep` never
  /// relaxes, so no relaxation is ever nested inside another.
  ///
  /// I14: A WRITE THAT IMPROVES IS PUSHED AT ITS OWN PRIORITY. This is I9's "the
  /// fixed point test is the write" completing itself: the write already knows
  /// whether it improved, and now the improvement is also the schedule. There is
  /// no separate wake pass -- the fact announces itself when the watermark
  /// reaches it, and nothing announces twice.
  late List<int> _out;
  late _Cell _cur;

  void _put(int key, int delta) {
    if (_keepBest(_out, key, delta)) _push(_cur.g + delta, _cur, 0);
  }

  /// The same, into any cell -- the write half of a semi-naive combine, which
  /// runs outside any relaxation.
  void _putInto(_Cell cell, int key, int delta) {
    if (_keepBest(cell.value ??= <int>[], key, delta)) {
      _push(cell.g + delta, cell, 0);
    }
  }

  /// I14, SEMI-NAIVE: ONE SETTLED FACT IS ONE NEW OPERAND FOR ONE EDGE. The
  /// fact at pair-index `i` of `dep`'s value has just settled, and `reader`
  /// reads `dep` at `slot`; combine exactly that, and touch nothing else.
  /// Recomputing the whole reader per settling fact -- the first draft -- is
  /// O(width^2) per cell and measured catastrophic (the 519-mutant battery ran
  /// for hours on the `"`-insertion mutants, whose absorber cells hold wide
  /// values). Here an alternation edge costs O(1) and a sequence edge costs the
  /// width of the opposite side, once, which is the recurrence's own cost.
  void _combine(_Cell reader, int slot, _Cell dep, int i) {
    _steps++;
    final v = dep.value!;
    final key = v[i], delta = v[i + 1];
    final node = reader.node;
    if (node is _Alt) {
      // Ordered choice: I3's veto, exactly as `_compute` states it, then the
      // merge. A rule reference (a choice among one) has no rival to commit to.
      if (delta < _costUnit && node.alts.length > 1) {
        final committed = reader.committed;
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          return;
        }
      }
      _putInto(reader, key, delta);
      return;
    }
    final cons = node as _Cons;
    final loops = identical(cons.tail, cons);
    if (slot == 0) {
      // A new head fact: it is settled by definition of an announcement, so it
      // may spawn its tail (the demand-locality gate `_chain` applies at
      // expansion), and it combines against every tail fact already known.
      final headEnd = _endOf(key);
      if (loops && headEnd == reader.pos) return;
      final tail = _dep(reader, 1 + (i >> 1), cons.tail, headEnd, _oweOf(key),
          reader.g + delta);
      final rest = tail?.value;
      if (rest == null) return;
      for (var j = 0; j < rest.length; j += 2) {
        _putInto(reader, rest[j], delta + rest[j + 1]);
      }
    } else {
      // A new tail fact: the slot names the one head fact it belongs under
      // (slot `1 + i/2` was assigned from the head's pair-index, and I9 keys
      // never move once written). The head's Delta is read live, so a head
      // that has since improved combines at its improved price.
      final heads = reader.deps![0]!.value!;
      _putInto(reader, key, heads[((slot - 1) << 1) + 1] + delta);
    }
  }

  /// Every pair of another cell's value, at its own price. A choice IS this, and so
  /// is a rule reference, which is the choice among one.
  void _merge(List<int> from) {
    for (var i = 0; i < from.length; i += 2) {
      _put(from[i], from[i + 1]);
    }
  }

  /// The Delta recorded for `key`, or null. The counterpart of `_put`, and the only
  /// other thing anybody asks of a value.
  static int? _deltaOf(List<int> value, int key) {
    for (var i = 0; i < value.length; i += 2) {
      if (value[i] == key) return value[i + 1];
    }
    return null;
  }

  /// I7'S VALUE KEY: where a derivation ended, and what it still OWES there.
  /// Packed into one integer for the same reason the memo key is -- a map of ints
  /// rather than a map of records -- and unpacked at the three places that care:
  /// the veto in `_Alt`, the tie-break in `_row`, and the top level.
  ///
  /// `_free` is -1, so the debt is shifted by one and the stride is the span of a
  /// position, which the memo uses too.
  ///
  /// THE SPAN IS ROUNDED UP TO A POWER OF TWO, for the same reason `_costUnit` is
  /// (A3) and by the same line: a packed integer that is unpacked in the innermost
  /// loop should not be unpacked by an integer DIVISION. `_endOf` is called once per
  /// head in `_chain` and once per candidate in `_Alt`, which is the hottest pair of
  /// loops in the engine. The address space is sparser and nothing pays for that,
  /// the memo being a hash map over it.
  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  /// I1's memo: one cell per `(node, pos, c)`, and by I8 the memo is also the
  /// work queue's address space -- there is no second table anywhere.
  final Map<int, _Cell> _cells = {};

  /// The span of a position, a power of two, and the shift and mask that go with it.
  /// Everything packed into an integer below -- a value's key and a cell's address
  /// -- is packed with these, so nothing divides.
  ///
  /// NOT `late`: a `late` field carries an initialisation guard on EVERY READ, and
  /// these are read in the innermost loop. Measured, medians of five: 452ms of
  /// battery behind the guard against 432 without it, for the same arithmetic.
  int _posShift = 0, _span = 0;

  // ---- I14: the schedule ----------------------------------------------------
  //
  // DELTA IS THE SCHEDULE. The queue is a min-heap of (priority, cell) entries,
  // priority = `cell.g + Delta(local)` -- the cheapest any repair through that
  // fact can possibly be. The watermark `_w` is the last priority popped, and it
  // never has to go back: every push made while processing a pop carries a
  // priority no smaller than the pop that caused it, because Delta is additive
  // and non-negative. So the FIRST goal fact to settle is the minimum, which is
  // Dijkstra's invariant (Knuth's, over a grammar), and the ladder, the budget
  // and the round structure have nothing left to do.
  //
  // A cell has two kinds of queue entry and one pop handler serves both. Its
  // EXPANSION entry, pushed at creation with priority `g`, runs its first
  // relaxation -- so a cell demanded at the frontier never expands at all, which
  // is the demand-bounding half of what the budget used to do. Its ANNOUNCE
  // entries, pushed by `_put` at `g + Delta`, deliver each newly settled fact to
  // the readers exactly once -- which is the waking half of what the reverse
  // edges did in m50-m53, with the re-wake storm scheduled away: a fact that has
  // not settled yet cannot wake anybody.
  //
  // Cycles need no case. A zero-progress cycle (left recursion) circulates at
  // one priority until `_keepBest` stops improving -- the fourteenth occasion's
  // "fixpoint iteration inside each (Delta, pos) class", emergent -- and every
  // improvement that escapes the cycle carries a higher priority and waits its
  // turn.

  /// The min-heap, as two parallel arrays: no entry objects, no comparator.
  ///
  /// AN ENTRY HAS A KIND, carried in the key's low bit, and the kind is what
  /// makes the schedule terminate. An ANNOUNCE entry (kind 0) is pushed for one
  /// strict improvement of one fact, priced at `g + Delta`; popping it is that
  /// fact settling, so it wakes the readers (and is where the goal is read).
  /// A RELAX entry (kind 1) only runs the cell's relaxation and announces
  /// nothing: a woken cell that fails to improve pushes nothing, which is what
  /// stops a zero-progress cycle from waking itself forever. Improvements are
  /// strictly finite, so pops are too. Announce sorts before relax at one
  /// priority, so a woken reader sees everything its class has settled.
  final List<int> _qp = [];
  final List<_Cell> _qc = [];

  /// The watermark: the priority of the last entry popped. Facts at
  /// `g + Delta <= _w` are settled; everything else is still speculative.
  int _w = 0;

  /// The kind of the entry `_popMin` last returned.
  int _popKind = 0;

  void _push(int prio, _Cell cell, int kind) {
    final key = (prio << 1) | kind;
    var i = _qp.length;
    _qp.add(key);
    _qc.add(cell);
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_qp[parent] <= key) break;
      _qp[i] = _qp[parent];
      _qc[i] = _qc[parent];
      i = parent;
    }
    _qp[i] = key;
    _qc[i] = cell;
  }

  /// Pop the cheapest entry, advancing the watermark to its priority.
  _Cell _popMin() {
    final top = _qc[0];
    _w = _qp[0] >> 1;
    _popKind = _qp[0] & 1;
    final lastP = _qp.removeLast();
    final lastC = _qc.removeLast();
    if (_qp.isNotEmpty) {
      var i = 0;
      while (true) {
        var child = 2 * i + 1;
        if (child >= _qp.length) break;
        if (child + 1 < _qp.length && _qp[child + 1] < _qp[child]) child++;
        if (_qp[child] >= lastP) break;
        _qp[i] = _qp[child];
        _qc[i] = _qc[child];
        i = child;
      }
      _qp[i] = lastP;
      _qc[i] = lastC;
    }
    return top;
  }

  /// `(c, node, pos)` as one integer, which is what makes I6's constraint a memo
  /// DIMENSION rather than a second map. A grammar with no lookahead only ever asks
  /// under `_free`, so it uses one slab of the address space and the memo is m46's,
  /// entry for entry.
  int _addr(_Node node, int pos, int c) =>
      (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos;

  /// Create-or-find a cell. Creation does three things and relaxes nothing:
  ///
  /// * STAMP `g`, once -- see `_Cell.g`.
  /// * SEED THE ORACLE'S ANSWER (I14): one memoized parser call that settles a
  ///   whole clean subtree, exactly what the `budget == 0` short circuit bought
  ///   the ladder, worth 2x on its own. Sound because on a `noLook` subtree it is
  ///   REDUNDANT -- the match is PEG's own derivation, one of the facts the
  ///   structural rules would find anyway -- so it is a shortcut, never a new
  ///   answer. Emitting nothing passes the obligation on; emitting discharges it
  ///   on the character already there (the seed emits the input).
  /// * QUEUE THE EXPANSION at priority `g`. A cell the watermark never reaches
  ///   stays a seed-only leaf: locality is the pop order itself.
  _Cell _cellAt(_Node node, int pos, int c, int g) =>
      _cells.putIfAbsent(_addr(node, pos, c), () {
        final cell = _Cell(node, pos, c, g);
        if (node.noLook) {
          final m = node.orig.match(_parser, pos);
          if (!m.isMismatch) {
            final v = cell.value = <int>[];
            if (m.len == 0) {
              v
                ..add(_key(pos, c))
                ..add(_cleanRegret(m));
            } else if (_permitsFirst(c, pos)) {
              v
                ..add(_key(pos + m.len, _free))
                ..add(_cleanRegret(m));
            }
            if (v.isNotEmpty) _push(g + v[1], cell, 0);
          }
        }
        _push(g, cell, 1);
        return cell;
      });

  /// One relaxation: recompute the cell from its dependencies, writing into the
  /// value already there (I9). Wakes are not issued here -- `_put` queued every
  /// improvement at its own priority, and the announce side of the pop loop
  /// delivers it when it settles.
  void _relax(_Cell cell) {
    _steps++;
    _out = cell.value ??= <int>[];
    _cur = cell;
    _compute(cell);
  }

  /// A dependency read, from inside a relaxation (I11): resolve the edge once,
  /// keep the cell object on the slot, declare the transpose edge where the
  /// forward edge is declared. `g` prices the context this demand arrives from
  /// and is used only if the cell does not exist yet.
  _Cell? _dep(_Cell from, int slot, _Node node, int pos, int c, int g) {
    if (pos > _inputLen) return null;
    final deps = from.deps ??= <_Cell?>[];
    while (deps.length <= slot) {
      deps.add(null);
    }
    var cell = deps[slot];
    if (cell == null) {
      deps[slot] = cell = _cellAt(node, pos, c, g);
      cell.readers.add(from);
      cell.readerSlots.add(slot);
    }
    return cell;
  }

  /// A lookup for the witness descent: no demand, no drain, no snapshot -- the
  /// search is over and nothing mutates. Every fact a minimal decomposition needs
  /// was derived before the goal fact was written, so it is already here; a
  /// missing cell just means "not part of any repair this cheap".
  List<int> _peek(_Node node, int pos, int c) => pos > _inputLen
      ? const []
      : _cells[_addr(node, pos, c)]?.value ?? const [];

  /// The three cases. Compare `combinators.dart`: this is `match` for each clause
  /// kind, evaluated over I1's value instead of a single result. The arguments m49
  /// passed down the stack are the cell's own fields now (I8).
  void _compute(_Cell cell) {
    final node = cell.node;
    final pos = cell.pos;
    final c = cell.c;
    // The `budget == 0` case is gone: the oracle's walk became the creation-time
    // seed in `_cellAt`, and there is no budget for it to test. Everything below
    // is the structural recurrence, undiluted.
    switch (node) {
      case _Cons():
        _chain(cell, node);
      case _Alt(:final alts):
        // ORDERED choice, over a value that is a set -- and a rule reference is
        // the choice among one. Nothing about recovery appears here, because a
        // gap before a chosen alternative is a gap before that alternative's
        // first element, which attaches further up.
        //
        // Branch facts are merged whether or not they have settled: an unsettled
        // fact is still the price of a real derivation, and the push it causes
        // carries `g + Delta`, which cannot undercut the watermark.
        if (alts.length == 1) {
          final only = _dep(cell, 0, alts[0], pos, c, cell.g);
          if (only?.value case final v?) _merge(v);
          return;
        }
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
        final committed = cell.committed =
            oracle.isMismatch ? -1 : pos + oracle.len;
        for (var slot = 0; slot < alts.length; slot++) {
          final branch = _dep(cell, slot, alts[slot], pos, c, cell.g);
          final ends = branch?.value;
          if (ends == null) continue;
          for (var i = 0; i < ends.length; i += 2) {
            final key = ends[i], delta = ends[i + 1];
            // I3: a candidate that spends nothing over [pos, end) leaves s'
            // equal to the input there, so if it reaches PAST where the oracle
            // stopped, the alternative the oracle took still matches s' and PEG
            // commits to that one instead. The candidate is unreachable however
            // cheap it looks. Ends SHORT of the oracle's are kept: s' may differ
            // beyond them, and then an earlier alternative may fail there.
            //
            // I6 NEEDS NO CASE HERE, and that is worth stating. The veto fires
            // only on a candidate that spends nothing, and such a candidate emits
            // the input from `pos` -- so its first emitted character is `s[pos]`,
            // which is also the first character of whatever the oracle matched
            // here. An obligation therefore permits both or neither, and when it
            // permits both, the alternative the oracle took is still the one PEG
            // commits to on s'.
            //
            // I7 needs two. THE END HAS TO BE DECODED OUT OF THE KEY: two
            // candidates that end together owing different classes are different
            // candidates, each vetoed on its own, and comparing raw keys would
            // compare a debt with a position.
            //
            // AND A DEBT IS A READ PAST THE END. The paragraph above turns on
            // "spends nothing over [pos, end)", which bounds where the candidate
            // LOOKED as well as where it wrote -- and a candidate that owes has
            // looked past its own end, at the one place s' is not the input. So
            // when the oracle MISMATCHED, its "no alternative matches" is a fact
            // about the input that says nothing about such a candidate, and
            // vetoing it is what costs `Kw <- "if" !Alpha` its exactness. When the
            // oracle MATCHED, the veto still stands whatever is owed: the
            // alternative it took reads inside [pos, committed) c [pos, end),
            // where s' IS the input, so that alternative still matches and PEG
            // still commits to it. The debt-free case is unchanged either way --
            // and it has to be, because it is the only thing standing between the
            // search and a non-greedy repetition PEG would never take.
            if (delta < _costUnit &&
                _endOf(key) > committed &&
                (committed >= 0 || _oweOf(key) == _free)) continue;
            _put(key, delta);
          }
        }
      case _Term(:final editable, :final demands):
        // I7: A LOOKAHEAD IS A NODE, and the plainest one in the engine. It
        // consumes nothing, emits nothing and costs nothing; all it does is add
        // its class to what is owed. NO ORACLE CALL: what it looks at is s', which
        // the obligation decides and the input does not.
        if (demands != _free) {
          _put(_key(pos, _meet(c, demands)), 0);
          return;
        }
        final m = node.orig.match(_parser, pos);
        // MATCH -- and matching emits the input it consumed, so a match that
        // consumes nothing passes the obligation on, and one that consumes
        // discharges it on the character already there.
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(_key(pos, c), _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(_key(pos + m.len, _free), _cleanRegret(m));
          }
        }
        if (!editable) return;
        // I2 MEETS I7: BOTH LIES EMIT WHAT THE TERMINAL ACCEPTS -- SUB in place of
        // the character it consumed, FAB in place of nothing -- so one class
        // decides both, and emitting is what discharges the debt. A terminal that
        // accepts no character at all emits nothing when it lies (`Nothing`, which
        // is deletion), and then the debt passes through it like any other
        // silence, with nothing to ask.
        final emits = _oneCharClass(node.orig);
        final silent = emits == null || emits.isEmpty;
        if (!silent && !_permits(c, emits)) return;
        final owed = silent ? c : _free;
        // I2. Each edit costs exactly one `_costUnit`; only the regret riding in
        // the low bits varies.
        if (pos < _inputLen) {
          // SUB: the character in front of the terminal is consumed and what the
          // terminal accepts is emitted instead, so the character's own evidence
          // is discarded -- twice h, by A2. No case asks whether the terminal
          // already matches: if it does, and it took that character, it is
          // already here at a lower price and the min keeps that one.
          _put(_key(pos + 1, owed),
              _costUnit + 2 * _skipRegret(pos, pos + 1));
        }
        // FAB: the text the terminal stands for is invented outright, which
        // commits a full alphabet's worth of information -- the most any single
        // move can commit, and the price is forced by A2.
        _put(_key(pos, owed), _costUnit + _widestClass);
    }
  }

  /// Sequencing. This is `Seq.match` over I1's value and NOTHING ELSE -- there is
  /// no recovery logic in it, nor in any other combinator. Compare the parser: it
  /// matches the head, then matches the tail from where the head ended, and a
  /// repetition is the case where the tail is the node itself.
  void _chain(_Cell cell, _Cons node) {
    final pos = cell.pos;
    final c = cell.c;
    // A repetition is a cons whose tail is itself. That is the whole of "this
    // item may stop here", and the whole of the parser's zero-width repetition
    // cut -- a zero-width iteration re-enters the identical state. Stopping here
    // emits nothing, so whatever was owed on the way in is still owed.
    final loops = identical(node.tail, node);
    if (loops) _put(_key(pos, c), 0);
    // I7, AND THE WHOLE OF IT: ONE CALL, THEN THE NEXT. The head is asked under
    // the cell's obligation and answers with whatever it still owes; the tail is
    // asked under that. m47 and m48 had to try BOTH readings of every cell -- the
    // head emits the constrained character, or the head is silent and the tail
    // owes it -- because the value could not say which had happened, and which one
    // does is a run-time fact (`_nullseq45`: no static placement of the constraint
    // is the right language). The value says now, so the union is gone and this is
    // `Seq.match` with an accumulator.
    final head = _dep(cell, 0, node.head, pos, c, cell.g);
    final heads = head?.value;
    if (heads == null) return;
    for (var i = 0; i < heads.length; i += 2) {
      final headKey = heads[i], headDelta = heads[i + 1];
      final headEnd = _endOf(headKey);
      // MEASURED: deleting this line changes NO reported cost, tree or span --
      // re-entering the identical state is left recursion, and I1's fixed point
      // absorbs it, which is why the parser's own cut and this one are the same
      // observation. It is kept because without it latency doubles (300ms vs
      // 148ms on the battery). The cut is an optimization, not a rule.
      if (loops && headEnd == pos) continue;
      // I14: ONLY A SETTLED HEAD FACT SPAWNS A TAIL. This is the whole of demand
      // locality -- the budget used to refuse a tail whose context had overspent;
      // the watermark refuses a tail whose context has not yet been paid for. An
      // unsettled head fact announces itself later and wakes this cell then.
      if (head!.g + headDelta > _w) continue;
      // Slot `1 + i/2`: the head's i-th answer, and slot 0 is the head itself.
      // The tail's context price through THIS cons is the cell's own plus what
      // the head spent.
      final tail = _dep(cell, 1 + (i >> 1), node.tail, headEnd, _oweOf(headKey),
          cell.g + headDelta);
      final rest = tail?.value;
      if (rest == null) continue;
      for (var j = 0; j < rest.length; j += 2) {
        _put(rest[j], headDelta + rest[j + 1]);
      }
    }
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
  final Set<(_Alt, int, int, int, int)> _path = {};

  MatchResult? _build(_Node node, int pos, int key, int delta, int c) {
    final end = _endOf(key);
    final orig = node.orig;
    final pure = pos > _inputLen ? mismatch : orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        _cleanRegret(pure) == delta &&
        // The clean walk is `_cellAt`'s seed, so it has to arrive at the same
        // key: silence passes the obligation on, consumption discharges it on
        // the character already there. This fast path is also what lets the
        // descent walk INTO a seed-only cell whose children were never demanded.
        (pure.len == 0
            ? key == _key(pos, c)
            : key == _key(end, _free) && _permitsFirst(c, pos))) {
      return pure;
    }
    switch (node) {
      case _Term():
        // Reached here the leaf is lying, and under I6 it may not lie freely: the
        // character it invents has to be one the obligation allows. The class it
        // accepts, narrowed to that obligation, is a class the parser understands,
        // so the narrowing is expressible in the witness itself -- and `_spelling`
        // then picks a member that verifies instead of one that does not. A
        // LOOKAHEAD LANDS HERE TOO, whenever the oracle disagrees with the
        // obligation about the string; `_oneCharClass` reads it as no class at
        // all, so it comes back as the zero-width match it is, emitting nothing.
        final accepts = c == _free ? null : _oneCharClass(orig);
        return Match(
            accepts == null
                ? orig
                : CharSet(_intersect(accepts, _classes[c])),
            pos,
            end - pos);
      case _Alt(:final alts):
        final state = (node, pos, key, delta, c);
        if (!_path.add(state)) return null;
        for (final alternative in alts) {
          if (_deltaOf(_peek(alternative, pos, c), key) != delta) {
            continue;
          }
          final m = _child(alternative, pos, key, delta, c);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, key, delta, c);
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
  List<MatchResult>? _child(_Node node, int pos, int key, int delta, int c) {
    if (identical(node, _junk)) {
      final end = _endOf(key);
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, key, delta, c);
    }
    final m = _build(node, pos, key, delta, c);
    return m == null ? null : [m];
  }

  /// Walk a cons chain, emitting the children of ONE row: one per element, or one
  /// per iteration when the tail is the node itself, so the child list comes out
  /// flat either way.
  List<MatchResult>? _row(_Node node, int pos, int key, int delta, int c) {
    if (node is! _Cons) {
      // The empty match closes every chain and contributes no child of its own.
      // It passes the obligation, so the key it closes at is the one it was
      // given. Any OTHER terminal reached here is one a discarded run was wrapped
      // around, and it is a child like any other.
      return identical(node, _eps)
          ? (key == _key(pos, c) && delta == 0 ? const [] : null)
          : _child(node, pos, key, delta, c);
    }
    // THE SEED'S FAST PATH, ROW-SHAPED. A fact written by `_cellAt`'s seed has no
    // structural decomposition behind it -- the cell may never have expanded --
    // but it IS the pure parser's match, so its children are the parser's own:
    // the suffix match's sub-matches are exactly this row, flattened, and a
    // `_wrap` row (head is `_junk`, nothing discarded) is the bare terminal.
    final pure = pos > _inputLen ? mismatch : node.orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == _endOf(key) &&
        _cleanRegret(pure) == delta &&
        (pure.len == 0
            ? key == _key(pos, c)
            : key == _key(_endOf(key), _free) && _permitsFirst(c, pos))) {
      return identical(node.head, _junk) && pure.len > 0
          ? [pure]
          : pure.subClauseMatches;
    }
    final loops = identical(node.tail, node);
    final heads = _peek(node.head, pos, c);
    // The one output-affecting heuristic: shortest head first. See above. The
    // ORDER IS OVER ENDS, not over keys: a key packs the debt above the position,
    // so sorting it raw would rank a debt ahead of a span. Ties are broken by the
    // key itself, only so that the descent is deterministic.
    final order = [for (var i = 0; i < heads.length; i += 2) i]
      ..sort((a, b) {
        final byEnd = _endOf(heads[a]) - _endOf(heads[b]);
        return byEnd != 0 ? byEnd : heads[a] - heads[b];
      });
    for (final i in order) {
      final headKey = heads[i];
      final headEnd = _endOf(headKey);
      if (loops && headEnd == pos) continue;
      final headDelta = heads[i + 1];
      // The remainder's Delta is non-negative, so a head already past the
      // target cannot belong to any decomposition summing to it.
      if (headDelta > delta) continue;
      // I7, replayed exactly as `_chain` decided it: the tail is asked under
      // whatever the head still owes.
      final headOwed = _oweOf(headKey);
      final rest = _deltaOf(_peek(node.tail, headEnd, headOwed), key);
      if (rest == null || headDelta + rest != delta) continue;
      final head = _child(node.head, pos, headKey, headDelta, c);
      if (head == null) continue;
      final tail = _row(node.tail, headEnd, key, rest, headOwed);
      if (tail != null) return [...head, ...tail];
    }
    // A repetition may stop wherever it stands, owing what it was given.
    return loops && key == _key(pos, c) && delta == 0 ? const [] : null;
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
        cost < 0 ? null : _build(_goal, 0, _bestGoalKey, _bestGoalDelta, _free);
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
    // AFTER the ceiling, not before: `_goalFromNothing` walks `_end`, which a
    // grammar containing no sequence at all would not otherwise have built, and
    // a node created after the stride was fixed would alias another node's block.
    _posShift = (_inputLen + 2).bitLength;
    _span = 1 << _posShift;
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
    // two and the division becomes `_costShift`. `maxCost` bounds the regret a
    // RETAINED fact can carry (no minimum-cost repair exceeds the trivial one),
    // which is the ceiling's surviving job: it prices the unit, it no longer
    // stops the search.
    _costShift = ((2 * _inputLen + maxCost + 2) * (_widestClass + 1)).bitLength;
    _costUnit = 1 << _costShift;
    _cells.clear();
    _qp.clear();
    _qc.clear();
    _cleanRegrets.clear();
    _steps = 0;
    _w = 0;
    // An empty language cannot be repaired toward at any price; say so from the
    // grammar, with no search (`_goalFromNothing`, tier 3).
    if (maxCost < 0) {
      lastCost = -1;
      lastSteps = _steps;
      return -1;
    }
    _looksMarked; // the one static pass I14 needs, once per grammar
    // I14: THE DRIVE. Create the goal cell -- context price zero -- and pop in
    // Delta order until a fact settles that consumes the whole input and owes
    // nothing the end of the string cannot pay (I7's `_permitsEnd`; "what
    // follows the input" is the member -1 of the alphabet). The FIRST such fact
    // is the minimum: nothing pending has a smaller priority and no future push
    // can undercut the watermark. If the queue drains first, no repair exists at
    // any price -- termination needs no ceiling, because the fact space is
    // finite and every push is a strict improvement of some (cell, key) pair.
    final goalCell = _cellAt(goal, 0, _free, 0);
    var best = _impossible;
    while (_qp.isNotEmpty) {
      // FINISH THE CLASS BEFORE ANSWERING. The first satisfying goal fact to
      // settle is the minimum, but a Delta-TIED rival derivation may still be
      // mid-flight in the same priority class, and the witness descent prefers
      // its ties the way a fully settled table breaks them. Facts above the
      // answer's priority can never enter a minimal witness, so the class
      // boundary is exactly where popping stops mattering.
      if (best < _impossible && (_qp.first >> 1) > best) break;
      final cell = _popMin();
      // An EXPANSION entry (kind 1, one per cell, priority `g`) runs the cell's
      // single full relaxation: structure is wired, current settled facts are
      // combined, and everything after arrives incrementally. A cell the
      // watermark never reaches this far stays a seed-only leaf.
      if (_popKind == 1) {
        _relax(cell);
        continue;
      }
      // An ANNOUNCE entry is one strict improvement of one fact, priced at
      // exactly this priority: popping it is that fact settling. The goal's own
      // settlements are read here for the answer, and every other fact is
      // delivered along each reader edge by one semi-naive `_combine` -- no
      // cell is ever recomputed because a neighbour moved.
      final v = cell.value;
      if (v == null) continue;
      if (identical(cell, goalCell)) {
        for (var i = 0; i < v.length; i += 2) {
          if (cell.g + v[i + 1] <= _w &&
              _endOf(v[i]) == _inputLen &&
              _permitsEnd(_oweOf(v[i])) &&
              v[i + 1] < best) {
            best = v[i + 1];
            _bestGoalKey = v[i];
          }
        }
      }
      for (var i = 0; i < v.length; i += 2) {
        if (cell.g + v[i + 1] != _w) continue;
        for (var r = 0; r < cell.readers.length; r++) {
          _combine(cell.readers[r], cell.readerSlots[r], cell, i);
        }
      }
    }
    if (best < _impossible) {
      _bestGoalDelta = best;
      lastCost = _editCount(best);
      lastRegret = best - lastCost * _costUnit - _skipRegret(0, _inputLen);
      lastSteps = _steps;
      return lastCost;
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}
// ERROR RECOVERY END
