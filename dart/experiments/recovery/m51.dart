// m51 -- recovery is the parser over a wider value, and terminals that may lie,
// relaxed IN PLACE by a worklist over the memo instead of a recursive descent
// through it.
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
//   I6  A LOOKAHEAD IS A CONSTRAINT ON THE NEXT CHARACTER EMITTED. This is the
//       flaw I5 reports, repaired.
//
//       I4 said the predicate must be decided by whatever decides the characters
//       it looks at, and fused the pair where the builder could SEE who that was.
//       Whom it cannot see is a run-time fact -- `_nullseq45.dart` proves it, with
//       the pure parser and no engine involved -- so the answer is not a better
//       rewrite but a CHANNEL: the predicate posts its class, and the derivation
//       that emits the character honours it. For `S <- !'x' A B; A <- 'a'?;
//       B <- 'b' / 'x';` the constraint belongs to A's character when A emits one
//       and to B's when it does not, and no static placement is the right
//       language: placing it on A alone accepts "x", which the grammar rejects,
//       and placing it on both rejects "ax", which the grammar accepts.
//
//       THE CLASS IS THE WHOLE OF A PREDICATE'S MEANING. `&C` says the next
//       character emitted is in C; `!C` says it is not -- and `!C` also holds
//       where NO character follows at all, so END OF INPUT IS A MEMBER OF THE
//       ALPHABET, written -1 because `codeUnitAt` never returns it. With that one
//       addition the two predicates are one rule with a complement between them,
//       and nothing below has a case for either.
//
//   I7  AN OBLIGATION IS PART OF THE VALUE. That is what makes the channel a
//       channel and not a one-way hint, and it is where the last of the recovery
//       machinery goes away.
//
//       A constraint enters a frame as an ARGUMENT -- the class the frame's first
//       emitted character must lie in -- and leaves it INSIDE THE VALUE: every end
//       a derivation reaches is paired with the class it still OWES, the
//       obligation its own trailing lookaheads impose on whoever emits next.
//
//           _ends(node, pos, budget, c)  :  (end, owed) -> Delta
//
//       THE PARSER ALREADY DOES THIS, in the other direction, which is the
//       argument that this is the right shape rather than a clever one.
//       `MemoEntry.foundLeftRec` is ONE BIT from a descendant frame to an ancestor
//       -- "you are a cycle, iterate" -- and it is the whole of left recursion (A5,
//       I1). An obligation is one integer from a frame to its right sibling --
//       "the next character you emit is one of these" -- and it is the whole of
//       lookahead. Neither fact can be computed by one frame alone; both are O(1);
//       neither needs a rule of its own once something carries it. DOWN THE TREE
//       IS THE ARGUMENT, ACROSS THE TREE IS THE VALUE, UP THE TREE IS THE MEMO.
//
//       Everything else follows, and mostly by DELETION:
//
//       A SEQUENCE IS ONE CALL AGAIN. m47 and m48 split every cons cell in two --
//       "the head emits the constrained character" against "the head is silent and
//       the tail owes it" -- because the value could not say which had happened.
//       Now it says. The head is asked under `c` and answers with what it owes;
//       the tail is asked under that. `Cons(h, t) @ c = h @ c, then t @ owed(h)`,
//       which is `Seq.match` with an accumulator, not a union over two readings.
//
//       SILENCE IS NOT A CONSTRAINT. m47 and m48 wrote "this derivation emits
//       nothing" as the EMPTY CLASS and made every silent move ask permission of
//       it. But emitting nothing is not a way of satisfying an obligation, it is a
//       way of PASSING IT ON -- which is what the value now does. The empty class
//       stops being special (it is simply an unsatisfiable debt, which is what
//       `&'x' !'x'` ought to be), `silent` disappears, and the question a silent
//       move used to ask is nobody's.
//
//       AN OBLIGATION IS DISCHARGED BY AN EMISSION OR BY THE END OF THE STRING,
//       and there is no third way. A move that emits a character must emit one the
//       obligation allows, and then owes nothing; a move that emits nothing owes
//       what it was given. The only other check is at the top, where the goal's
//       residual must permit -1. Those two lines replace, between them: m47's
//       optimistic `_end` (which UNDER-REPORTED -- 0 where the truth is 1,
//       `_leak47`), m48's strict `_eps` in its place, m48's nullability least
//       fixed point, and the reader gate built on it (`_cons` posted a constraint
//       only in front of a rest that had to read). All of that was machinery for
//       GUESSING AT BUILD TIME what the value can now simply carry.
//
//       A LOOKAHEAD IS A NODE AGAIN, and the plainest one in the engine: it emits
//       nothing, consumes nothing, costs nothing, and exports `meet(c, its
//       class)`. m48 could only post a class on a cons cell standing in front of a
//       reader, so a lookahead that was a whole rule body, or the last element of
//       one, had nowhere to live. POSITION DOES NOT ENTER: what a predicate reads
//       in s' IS the next character emitted after it, wherever that is emitted
//       from and however far away.
//
//       WHAT IT BUYS, measured in `_leak49`: the keyword-boundary idiom
//       `Kw <- "if" !Alpha` with its reader at the CALL SITE -- the commonest real
//       use of a lookahead there is -- costs 1 on "ifa", which is the truth, where
//       m48 says 3. So does `A <- 'a' &'b' / 'c'` under `S <- A 'b'`. Both are
//       §5p's third family, "the constraint escapes into the parent's
//       continuation, which the curried value does not carry": it carries it now.
//
//       WHAT PAYS FOR IT: the value is keyed by (end, owed) instead of end, so a
//       map that was n wide is n x L, where L is the intersection lattice of the
//       grammar's one-character lookaheads. A grammar without lookahead has L = 1
//       and every key below is m46's, bit for bit -- which is why the JSON battery
//       does not move by a single tree OR A SINGLE `_compute` CALL.
//
//       WHERE IT STOPS: a lookahead WIDER than one character, for the reason it
//       always stopped. The derivative of `!"*/"` after one emitted character is
//       `!"/"`, an obligation that CHANGES as it is discharged, and this channel
//       carries a set, not a state machine. Those stay on the oracle, stay
//       approximate, and stay reported by I5.
//
//   I8  POSITION IS THE STRATIFICATION VARIABLE, AND LEFT RECURSION IS THE ONLY
//       CYCLE THAT DOES NOT ADVANCE IT. I1 through I7 fix WHAT each cell is worth;
//       I8 is the observation that fixes the ORDER, and it deletes the last three
//       mechanisms by making them one.
//
//       Read the dependencies off the three node kinds. `_Alt` at `pos` reads its
//       alternatives AT `pos`. `_Cons` at `pos` reads its head at `pos` and its
//       tail at wherever the head ENDED, which is never less. So EVERY EDGE OF THE
//       DEPENDENCY GRAPH POINTS AT A POSITION >= ITS SOURCE: collapse positions and
//       the graph is a DAG, and every cycle lives inside a single position.
//
//       m49 paid for cycles twice. It paid for LEFT recursion with a fixed point
//       loop inside `_Entry.ends`, and for RIGHT recursion with the NATIVE STACK --
//       measured at ~2.5 `_compute` nestings per element, LINEAR in n, against a
//       flat 18 nestings for left recursion at every n. Two mechanisms for one
//       requirement: A CELL MUST WAIT FOR THE CELLS IT DEPENDS ON. Relax cells
//       highest-position-first and both waits become the same wait. A cell at a
//       greater position is settled before its readers are asked again -- that is
//       the right recursion, with no frame. A cycle inside one position keeps
//       re-entering that position's slice of the queue until nothing improves --
//       that is `_Entry.ends`'s loop, with no frame either.
//
//       ITERATIVE DEEPENING IS THE THIRD, and it folds in for free: raising a
//       cell's budget is just another way to DIRTY it, so round k+1 is not a fresh
//       traversal, it is a few cells re-entering the queue they never left.
//
//       WHAT REPLACES THEM is the reverse edge -- who reads me -- and it is what
//       m49's four fields (`inRecPath`, `foundLeftRec`, `memoVersion`, and
//       `_versionAtPos`) were each approximating with one bit or one counter. A
//       cell that improves wakes its readers; a cell that does not tell nobody, and
//       that is why the queue drains. `_Entry` was 74 lines and `_Cell` is 30.
//
//       WHAT IT BUYS, bisected in `_ceil50b.dart` on a right-recursive grammar:
//       the SEARCH's stack ceiling goes from k=541 to k=2160, a 4.0x gain, which
//       lands it at or above the PURE PARSER's own measured ceiling of k~2100. The
//       search therefore no longer contributes to the ceiling at all -- the oracle
//       does, and nothing in this file can lift that. End to end `recover` goes 541
//       -> 1281 and is now bound by `_build`, a recursion over the OUTPUT TREE,
//       which for a right-recursive grammar is O(n) deep whatever the search does.
//
//       WHAT IT COSTS: 2.10x the relaxations, 2.43 per cell against the descent's
//       1.13. The cause is structural and is the one place the DAG argument is not
//       tight: a cons cell cannot know WHICH tail cell it needs until its head has
//       an answer, so a tail at a further position is discovered AFTER its own
//       stratum has gone by, and the cons cell is woken to read it. About three
//       relaxations for a cons, two for an alternation, one for a terminal. Steps
//       are not time -- m49's step carried four stack frames and this one carries
//       none -- so what this trade actually bought is in the table, not here.
//
//   I9  A CELL IS RELAXED MANY TIMES, SO THE VALUE MUST BE WRITTEN INTO AND NOT
//       BUILT. This is the one insight I8 needs and did not have, and m50 paid 2.0x
//       the battery time for the omission.
//
//       Two measurements meet here. THE VALUE IS NARROW: mean end-map width 1.63 on
//       the JSON battery, 1.66 left recursive, 6.04 right recursive (`_width50`). AND
//       A CELL IS RELAXED 2.43 TIMES, by I8's own accounting. m50 answered the second
//       by ALLOCATING A FRESH MAP per relaxation, comparing it entry by entry against
//       the one already there, and throwing it away when nothing improved -- which is
//       exactly the shape this line refuted twice already (§6: a record allocated per
//       memo write, 2.0x slower; a record as memo key, 2.4x slower). A hash table of
//       1.63 entries is a hash table that will never be searched, allocated 2.43
//       times per cell to be compared once.
//
//       So the value is a FLAT LIST OF (key, Delta) PAIRS, owned by the cell,
//       written into by every relaxation and never replaced. At width 1.63 a linear
//       scan finds a key in under one comparison on average, where a map hashes,
//       masks, probes and allocates a `MapEntry` per entry iterated.
//
//       AND THEN THE FIXED POINT TEST IS THE WRITE. m50's test was a second pass
//       over the fresh map asking "is any entry new or lower" -- which is precisely
//       what `_keepBest` had just decided, one key at a time, and discarded. Keep
//       that bit and the pass is gone: A CELL IMPROVED IFF SOME WRITE IMPROVED IT.
//       I1's fixed point test does not need to be computed, only remembered.
//
//       ACCUMULATING IN PLACE IS SOUND, and needs no argument beyond the one I1
//       already made. Every Delta ever recorded is the price of a derivation that
//       really exists, budgets only ever RISE (`_read` raises, nothing lowers), and
//       the recurrence is monotone in its operands -- so the entries a lower budget
//       found are entries the higher budget would find again, and keeping them is
//       chaotic iteration over a monotone operator on a finite lattice. Same least
//       fixed point, in any order, from any partial start. m50 REPLACED the value on
//       every relaxation and so was recomputing an answer it already had.
//
//       ONE REPRESENTATION FOR THE WHOLE FILE: `_goalFromNothing`'s ceiling table is
//       the same recurrence with the input taken away, so it is the same list of
//       pairs, and `_keepBest`'s return value is that table's outer loop condition
//       too. There is no `Map<int, int>` left in the engine.
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
//   HEURISTICS AFFECTING WORK ONLY (two), and neither can move an answer, because
//   a fixed point does not depend on the order it is reached in -- both are checked
//   that way, bit for bit, in `_smoke50.dart`: I8's relax-highest-rank-first (the
//   tie-break inside a position is measured, 2.43 relaxations per cell against
//   2.63 for position alone), and I4's static fusion of a one-character lookahead
//   into the reader behind it (+7.3% `_compute` calls without it).
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
  _Cell(this.node, this.pos, this.c, this.rank);

  /// The cell's own coordinates. m49's frame carried these as ARGUMENTS, which is
  /// why m49 needed a frame; a cell that knows where it is can be relaxed by
  /// anybody.
  final _Node node;
  final int pos;
  final int c;

  /// I8's queue order, `(pos, node.id)` as one integer so that one comparison
  /// orders both. Computed once here rather than in every heap comparison.
  final int rank;

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

  /// The largest edit budget anyone has demanded. Raising it is the ONLY reason a
  /// settled cell is dirtied from outside its own dependencies, which is what
  /// collapses iterative deepening into the same mechanism as everything else.
  int budget = -1;

  /// On the worklist already, so do not schedule twice. Measured to be worth its
  /// field; see `_heap`.
  bool queued = false;

  /// THE REVERSE EDGES, and the whole of what m49 spent four fields guessing at.
  /// `foundLeftRec` was one bit of "somebody below me will need me again"; this is
  /// the exact set of cells that read this one, so "again" is not a guess.
  ///
  /// A LIST, NOT A SET: waking a cell twice is waking it once (the queue is a set,
  /// so `_dirty` is idempotent), and deduplicating costs a hash per edge traversed.
  /// Measured on the battery: 713ms as a Set, 650ms as a list, identical step
  /// counts. By I10 the list is also SHORT -- a wake empties it -- so what a set
  /// would have deduplicated does not accumulate in the first place.
  final List<_Cell> readers = [];
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
  /// `_improved` its fixed-point bit; both are fields rather than arguments because
  /// `_compute` is reached from `_relax` and from nowhere else -- `_read` never
  /// relaxes, so no relaxation is ever nested inside another.
  late List<int> _out;
  bool _improved = false;

  void _put(int key, int delta) {
    if (_keepBest(_out, key, delta)) _improved = true;
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

  // ---- I8: the worklist ----------------------------------------------------
  //
  // POSITION IS THE STRATIFICATION VARIABLE, AND LEFT RECURSION IS THE ONLY CYCLE
  // THAT DOES NOT ADVANCE IT. Read the three cases below for their dependencies:
  // an `_Alt` at `pos` reads its alternatives AT `pos`; a `_Cons` at `pos` reads
  // its head at `pos` and its tail at wherever the head ended, WHICH IS NEVER
  // LESS. So every edge of the dependency graph points at a position >= its
  // source, and the graph is a DAG once positions are collapsed: the only cycles
  // live inside a single position.
  //
  // That one fact is what merges m49's two mechanisms into this one. m49 paid for
  // left recursion with a fixed point loop in `_Entry.ends` and for right
  // recursion with the NATIVE STACK -- measured at ~2.5 nestings per element,
  // linear in n, against a flat 18 for left recursion at every n. Two mechanisms,
  // one requirement: A CELL MUST WAIT FOR THE CELLS IT DEPENDS ON. Relax cells
  // highest-position-first and both waits are the same wait -- a cell at a greater
  // position is settled before its readers are asked again, and a cycle inside one
  // position simply keeps re-entering that position's bucket until it stops
  // improving, which IS `_Entry.ends`'s loop with the frame taken away.
  //
  // Iterative deepening folds in too, and that is the third mechanism gone:
  // raising a cell's budget is just another way to dirty it, so round k+1 is not a
  // fresh traversal but a few cells re-entering the same queue.
  //
  // RELAX THE CELL FURTHEST FROM THE GOAL FIRST: furthest in POSITION, and then
  // furthest from the ROOT OF THE GRAMMAR. Position is the stratification variable
  // above; node id is the tie-break inside a position, and it is a stratification
  // too, because `_node` assigns ids top-down -- a cell's head and its
  // alternatives are built after it and so number higher. Both orders point the
  // same way, which is why they pack into ONE integer and the queue is one heap.
  //
  // MEASURED, and this is why the tie-break is here rather than left to arrival
  // order: within a position, relaxing a parent before its child costs the parent
  // one relaxation per child that settles after it. Bucketed by position alone the
  // engine paid 2.63 relaxations per cell against the descent's 1.13; ordered by
  // both it pays what is reported in `lastPerCell`.
  //
  // A cell discovered at a GREATER position than the one being relaxed is simply
  // pushed and comes out next, and the cell that discovered it is re-dirtied
  // through the reverse edge when it settles -- so no order is computed in
  // advance, which is the point: WHICH cells exist is a run-time fact (only 7-9%
  // of the space is ever demanded, flat in n, which is why a bottom-up agenda over
  // all of it costs an order more).

  /// A binary max-heap of cells, keyed by `_rank`. An array of cells and the two
  /// sift loops: no comparator, no second structure, no node per element.
  ///
  /// A `SplayTreeSet` ordered by the same rank says this in eight lines instead of
  /// thirty and needs no `queued` bit, a set being unable to hold a cell twice --
  /// and it was measured, answer for answer and step for step identical, and then
  /// REJECTED: 889ms latency against 759. The `queued` bit is why. Waking an
  /// already-queued cell is the common case (a settling cell wakes every reader it
  /// has, repeatedly), and a bit answers that in O(1) where a tree has to walk down
  /// to find the duplicate it will not insert.
  final List<_Cell> _heap = [];

  void _dirty(_Cell cell) {
    if (cell.queued) return;
    cell.queued = true;
    final rank = cell.rank;
    var i = _heap.length;
    _heap.add(cell);
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_heap[parent].rank >= rank) break;
      _heap[i] = _heap[parent];
      i = parent;
    }
    _heap[i] = cell;
  }

  _Cell _pop() {
    final top = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      final rank = last.rank;
      var i = 0;
      while (true) {
        var child = 2 * i + 1;
        if (child >= _heap.length) break;
        if (child + 1 < _heap.length &&
            _heap[child + 1].rank > _heap[child].rank) child++;
        if (_heap[child].rank <= rank) break;
        _heap[i] = _heap[child];
        i = child;
      }
      _heap[i] = last;
    }
    top.queued = false;
    return top;
  }

  /// `(c, node, pos)` as one integer, which is what makes I6's constraint a memo
  /// DIMENSION rather than a second map. A grammar with no lookahead only ever asks
  /// under `_free`, so it uses one slab of the address space and the memo is m46's,
  /// entry for entry.
  _Cell _cell(_Node node, int pos, int c) => _cells.putIfAbsent(
      (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos,
      () => _Cell(node, pos, c, pos * (_nodeCount + 1) + node.id));

  /// Drain the queue. This is the engine's ONLY loop over work, and it replaces
  /// every recursive frame m49 had: `_relax` is called from here and from nowhere
  /// else, so the native stack depth is a constant of the grammar rather than a
  /// function of n.
  void _run() {
    while (_heap.isNotEmpty) {
      _relax(_pop());
    }
  }

  /// One relaxation. I1'S FIXED-POINT TEST, VERBATIM FROM `MemoEntry`: the
  /// parser's is "the match did not get longer", and over a map of ends it is "no
  /// end is new and no Delta got smaller". A cell that did not improve tells
  /// nobody, which is what makes the queue empty out. Ends lie in [0, n],
  /// obligations in a finite lattice and Deltas are bounded non-negative integers,
  /// so a cell improves only finitely often; this is m49's termination argument
  /// with the frame removed, not a new one.
  void _relax(_Cell cell) {
    _steps++;
    // A CELL READ BEFORE IT IS SETTLED ANSWERS WITH THE EMPTY SET, and that is the
    // one place I1's left recursive seed lives -- m49 spelled it `inRecPath` and
    // reached it only on a genuine cycle; here it also covers a dependency
    // DISCOVERED LATE, because a cons cell cannot know WHICH tail cell it needs
    // until its head has an answer, so a tail at a further position is found after
    // its own stratum has gone by. Both cases are the same case: relax with what is
    // known, publish, and be woken through the reverse edge when it is not enough.
    //
    // Distinguishing them by rank and DEFERRING the late-discovered one was
    // measured and abandoned: it wins 1% of relaxations (2.41 per cell against
    // 2.43), needs its own liveness argument -- a dependency re-relaxed at a raised
    // budget may settle on the value it already had, and a cell that does not
    // improve tells nobody, so a waiter must re-queue itself rather than wait to be
    // woken -- and the retry costs the relaxation the deferral saved.
    //
    // I9: RELAX INTO THE VALUE ALREADY THERE. What m50 wrote here -- allocate a
    // fresh map, compare it against the old one entry by entry, publish or discard
    // -- is three passes over the same information, and `_keepBest` was already
    // deciding all of it one key at a time. The cell's list IS the accumulator now,
    // so there is nothing to publish and nothing to compare: a write that lowered a
    // Delta or added a key set `_improved`, and that is the fixed point test.
    _out = cell.value ??= <int>[];
    _improved = false;
    _compute(cell);
    if (!_improved) return;
    // I10: THE REVERSE EDGE IS CONSUMED BY THE WAKE. A woken reader is going to be
    // relaxed, and relaxing it re-reads whatever it still depends on -- so it will
    // re-declare this edge itself, and only if the dependency is still real. The
    // invariant is that a cell is EITHER queued OR listed by every cell it last
    // read, and clearing here preserves it because clearing is what queueing does.
    //
    // m50 never cleared, so a cell relaxed r times appeared in its dependency's
    // list r times. MEASURED, and it is a SPACE win and not a time one: on a
    // 5-repair document, 244855 edge slots held without this and 133069 with, at
    // 86849 relaxations either way and no difference in wall clock. A `Set` gets it
    // to 54742 and costs 14% (57ms -> 65ms), so the earlier refutation of the set
    // stands against this engine too. The bound is what matters -- edges held goes
    // from "one per read ever performed" to "one per live reader" -- and it is
    // free, which is the only reason four lines are spent on it.
    for (final reader in cell.readers) {
      _dirty(reader);
    }
    cell.readers.clear();
  }

  /// READ A CELL, from inside another cell's relaxation. This is m49's `_ends`
  /// with the recursion taken out: it registers the reverse edge, raises the
  /// budget if this reader needs a bigger one, and answers with whatever is known
  /// NOW -- the empty set if that is nothing, which is I1's left recursive seed
  /// arriving by the same door as everything else.
  /// ONE READ, INSIDE OR OUT: `from` is the cell doing the reading, or null for the
  /// deepening loop and the witness descent, which read from outside any relaxation
  /// and therefore have to DRAIN before they may believe the answer. m50 wrote this
  /// function twice.
  List<int> _read(_Cell? from, _Node node, int pos, int budget, int c) {
    if (pos > _inputLen || budget < 0) return const [];
    final cell = _cell(node, pos, c);
    if (from != null) cell.readers.add(from);
    if (cell.budget < budget || cell.value == null) {
      if (cell.budget < budget) cell.budget = budget;
      _dirty(cell);
    }
    if (from == null) _run();
    return cell.value ?? const [];
  }

  /// A settled read, from outside. A SNAPSHOT, because the caller is the witness
  /// descent: it reads a value and then asks for another, and that second read
  /// drains the queue, which may relax the cell it is still looping over -- and
  /// under I9 relaxing a cell writes into the very list it handed out.
  List<int> _ends(_Node node, int pos, int budget, int c) =>
      List<int>.of(_read(null, node, pos, budget, c));

  /// The three cases. Compare `combinators.dart`: this is `match` for each clause
  /// kind, evaluated over I1's value instead of a single result. The arguments m49
  /// passed down the stack are the cell's own fields now (I8).
  void _compute(_Cell cell) {
    final node = cell.node;
    final pos = cell.pos;
    final budget = cell.budget;
    final c = cell.c;
    // With no edits to spend the repaired string IS the input, PEG is
    // deterministic on it, and the node is settled outright -- there is nothing to
    // search, only a walk, and the walk is the oracle's own. It applies to every
    // node because every node denotes a clause: a sequence's suffix as much as the
    // sequence itself. The singleton it returns is also the narrowest possible
    // operand for every product in `_chain`.
    //
    // IT IS EXACT UNDER AN OBLIGATION, INCLUDING THE ONES INSIDE IT, and the
    // reason is a property of the BUDGET rather than of this node. `_chain` hands
    // the tail `budget - cost(head)`, so everything to the right of a node -- at
    // every level, not only its own -- is asked at a budget no larger than the
    // node's minus what the node spent. A node at budget 0 therefore has an
    // EDIT-FREE CONTINUATION, which emits the input verbatim to the end of it. So
    // a lookahead inside this clause reads exactly the characters the oracle has
    // just read it against, however far past this clause's own end it looks: the
    // oracle's verdict on it is not an approximation but the answer. That is also
    // why nothing can be owed out of here -- what this node would export has
    // already been checked against what will actually follow.
    if (budget == 0) {
      final m = node.orig.match(_parser, pos);
      if (m.isMismatch) return;
      // Emitting nothing passes the obligation on; emitting discharges it, and
      // what is emitted is the input, so the character in question is the one
      // already there.
      if (m.len == 0) {
        _put(_key(pos, c), _cleanRegret(m));
      } else if (_permitsFirst(c, pos)) {
        _put(_key(pos + m.len, _free), _cleanRegret(m));
      }
      return;
    }
    switch (node) {
      case _Cons():
        _chain(cell, node);
      case _Alt(:final alts):
        // ORDERED choice, over a value that is a set -- and a rule reference is
        // the choice among one. Nothing about recovery appears here, because a
        // gap before a chosen alternative is a gap before that alternative's
        // first element, which attaches further up.
        if (alts.length == 1) {
          return _merge(_read(cell, alts[0], pos, budget, c));
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
        final committed = oracle.isMismatch ? -1 : pos + oracle.len;
        final limit = (budget + 1) * _costUnit;
        for (final alternative in alts) {
          final ends = _read(cell, alternative, pos, budget, c);
          for (var i = 0; i < ends.length; i += 2) {
            final key = ends[i], delta = ends[i + 1];
            if (delta >= limit) continue;
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
    final budget = cell.budget;
    final c = cell.c;
    final limit = (budget + 1) * _costUnit;
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
    // The head's list is READ WHILE THE CELL'S OWN IS WRITTEN, and under I9 that is
    // a fact to check rather than assume. It is safe because the head of a cons is
    // never the cons itself, and `_read` below only SCHEDULES the tail -- nothing
    // between here and the end of this loop relaxes anything, so no value in sight
    // can change while it runs. (`_ends`, which does drain, is the descent's read
    // and takes a snapshot for exactly this reason.)
    final heads = _read(cell, node.head, pos, budget, c);
    for (var i = 0; i < heads.length; i += 2) {
      final headKey = heads[i], headDelta = heads[i + 1];
      final headEnd = _endOf(headKey);
      // MEASURED: deleting this line changes NO reported cost, tree or span --
      // re-entering the identical state is left recursion, and I1's fixed point
      // absorbs it, which is why the parser's own cut and this one are the same
      // observation. It is kept because without it latency doubles (300ms vs
      // 148ms on the battery). The cut is an optimization, not a rule.
      if (loops && headEnd == pos) continue;
      final rest = _read(cell, node.tail, headEnd,
          budget - _editCount(headDelta), _oweOf(headKey));
      for (var j = 0; j < rest.length; j += 2) {
        final total = headDelta + rest[j + 1];
        if (total < limit) _put(rest[j], total);
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

  MatchResult? _build(
      _Node node, int pos, int key, int delta, int budget, int c) {
    final end = _endOf(key);
    final orig = node.orig;
    final pure = pos > _inputLen ? mismatch : orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        _cleanRegret(pure) == delta &&
        // The clean walk is `_compute`'s budget-0 case, so it has to arrive at
        // the same key: silence passes the obligation on, consumption discharges
        // it on the character already there.
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
          // A LOOKUP NEEDS NO SNAPSHOT: the value is used before anything else can
          // drain the queue, so `_read` is asked directly and nothing is copied.
          if (_deltaOf(_read(null, alternative, pos, budget, c), key) != delta) {
            continue;
          }
          final m = _child(alternative, pos, key, delta, budget, c);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, key, delta, budget, c);
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
  List<MatchResult>? _child(
      _Node node, int pos, int key, int delta, int budget, int c) {
    if (identical(node, _junk)) {
      final end = _endOf(key);
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, key, delta, budget, c);
    }
    final m = _build(node, pos, key, delta, budget, c);
    return m == null ? null : [m];
  }

  /// Walk a cons chain, emitting the children of ONE row: one per element, or one
  /// per iteration when the tail is the node itself, so the child list comes out
  /// flat either way.
  List<MatchResult>? _row(
      _Node node, int pos, int key, int delta, int budget, int c) {
    if (node is! _Cons) {
      // The empty match closes every chain and contributes no child of its own.
      // It passes the obligation, so the key it closes at is the one it was
      // given. Any OTHER terminal reached here is one a discarded run was wrapped
      // around, and it is a child like any other.
      return identical(node, _eps)
          ? (key == _key(pos, c) && delta == 0 ? const [] : null)
          : _child(node, pos, key, delta, budget, c);
    }
    final loops = identical(node.tail, node);
    final heads = _ends(node.head, pos, budget, c);
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
      final restBudget = budget - _editCount(headDelta);
      final rest =
          _deltaOf(_read(null, node.tail, headEnd, restBudget, headOwed), key);
      if (rest == null || headDelta + rest != delta) continue;
      final head = _child(node.head, pos, headKey, headDelta, budget, c);
      if (head == null) continue;
      final tail = _row(node.tail, headEnd, key, rest, restBudget, headOwed);
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
    final root = cost < 0
        ? null
        : _build(_goal, 0, _bestGoalKey, _bestGoalDelta, cost, _free);
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
    // two and the division becomes `_costShift`.
    _costShift = ((2 * _inputLen + maxCost + 2) * (_widestClass + 1)).bitLength;
    _costUnit = 1 << _costShift;
    _cells.clear();
    _heap.clear();
    _cleanRegrets.clear();
    _steps = 0;
    // Iterative deepening on the budget. A3 makes each round reuse the previous
    // round's memo, and the goal node makes the whole query a single lookup:
    // "consume the entire input".
    for (var k = 0; k <= maxCost; k++) {
      // I7: the query is still "consume the entire input", but a derivation may
      // hand an obligation back out of the goal, and the only thing left to
      // discharge it is the end of the string. `_permitsEnd` is that check --
      // the whole of "what follows the input" is the member -1 of the alphabet.
      var best = _impossible;
      final ends = _read(null, goal, 0, k, _free);
      for (var i = 0; i < ends.length; i += 2) {
        if (_endOf(ends[i]) == _inputLen &&
            _permitsEnd(_oweOf(ends[i])) &&
            ends[i + 1] < best) {
          best = ends[i + 1];
          _bestGoalKey = ends[i];
        }
      }
      if (best < _impossible) {
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
