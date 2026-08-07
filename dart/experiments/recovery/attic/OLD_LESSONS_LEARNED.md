> ARCHIVED 2026-08-06 (era-2 record, verbatim). These scores were measured
> on the era-2 battery (ten character-role categories, no curation) and are
> NOT re-run on the era-3 battery; they are not comparable to numbers in the
> living LESSONS_LEARNED.md at the repo root. The engines referenced here
> live in this directory. The living file distills what still matters.

# Lessons Learned — Squirrel Parser Error Recovery

**What this file is.** The standing record of the error-recovery line of work: the
task as given, every instruction that shaped it, the parser it is built on, how
things are measured, what each engine generation bought and paid, every numbered
insight, and everything refuted. Read it before proposing anything — most obvious
ideas here have already been built and measured, and several of them lost.

**How to read it.** Everything numeric was measured on the machine, not
estimated. A claim marked *refuted* was **built and measured**, not reasoned
away. A refutation is only valid against the engine it was measured on (§6.0) —
when a primitive changes, the refuted list is back on the table.

**Where things stand, in four lines (2026-08-05).** Two engines lead: **s1**
(0.9841 AST-diff, 77.0% perfect, 697 lines — §4.9) has the best score, and
**s4** (0.9823, **79.1% perfect — the study's best**, **480 lines**, §4.9) is
the collapsed pure core — s3 plus frozen-work reuse — that **dominates r9 on
all four axes** and breaks the size cliff (nothing under 562 lines had
exceeded 0.9551). **m143** stays the standing `m`-engine; the budget-deletion
experiment is refuted (§4.9, s4) and the growing-cell form is the specified
next step. Of ~160 engines, **ten are still worth considering** (Appendix) — the tenth,
t1 (§4.9, attempt two), is the study's latency record at 1,035 ms and the
engine that settled the ★TODO's claim.
**s1 and r9 pass every gate** — all re-run 2026-08-05: acceptance 3/3, free-span,
recommit 16/16, conformance `0 1 1 0 2 3` with zero free passes, core gate pass,
library suite 320/320 — **and m143 does not**, failing one recommit case (§3.3).
On clean input s1's latency IS the library parser's own parse (round 0 is the
library, §4.9); on the battery it is 1,686 ms against m132's 1,098. "Under 400
lines" has still never been met at the same time as the accuracy goal — twenty
engines under 400 lines all sit at 0.9551, and the score now jumps at 562 (r9)
and again at 697 (s1) (Part VII, items 2–3).

**The largest unexplored lever, and the priority for the next rounds of engines.**
The parser core now hands back, for every failure, a mismatch node carrying **the
maximum length it validly consumed, an exact frontier, and its subclause matches
and mismatches as children** — so the frontier is a place in the tree rather than a
number scanned out of the memo table. **No `m`-series engine had this**, and every
one of them re-derives the frontier instead. Nothing built so far consumes it: the
one engine that ran on an exact frontier (r13) sits on a separate experiment core
and was aimed at a different question. **Its other half — the steer given on
six occasions since 2026-07-25 (reuse the O(1) memo signal that solves left
recursion to collapse recovery into a tiny core) — is ANSWERED: I100, ★ the
pivotal insight of the recovery line, owner-confirmed** (§1.8's close, §4.9).
A mismatch and a left-recursion seed are the same object — a suspended
reading — and the memo entry's grow-loop is already the whole recovery
engine; made structural in s3, that identity halved the mechanism, broke the
size cliff, and dominated r9. **Start here** — §1.7 and §1.8 for the
instructions verbatim, §4.9 for I100 and the engines it produced, §2.5 for
the mismatch-tree half and the still-open `reach` fork.

**Provenance.** This is a pointed rewrite (2026-08-02) of a 13,903-line
accumulated record. Nothing here is new work; it is the same findings, compacted
by roughly 10x, restructured so the instructions come first and the findings are
indexed. The full unabridged history — every occasion narrative, every
intermediate table, every dead end at full length — is preserved in git and
readable with:

```
git show e98e3e8:LESSONS_LEARNED.md
```

Line references of the form `(old L1234)` below point into that file.

---

# PART I — THE TASK, AND EVERY INSTRUCTION THAT SHAPED IT

## 1.1 The task

Build error recovery for the Squirrel PEG parser: given input the grammar
rejects, produce the AST the author most likely meant, with syntax-error spans
marking the damage. Recovery must be principled (no tuning knobs, no arbitrary
heuristics), must not degrade the parser, and must be small and fast.

## 1.2 The standing directives, verbatim

These are the owner's words. They outrank every design decision in this file,
including ones that were measured and won at the time. They are numbered D1–D8
for citation; the numbering is mine, the text is not.

**D1 — Never start a second parse.**

> You should not need to create a new Parser engine, ever! ... respond to damage
> by updating the CURRENT memo-table, in-place, as the damage is found and
> repaired. Don't ever start a new parse.

**D2 — The tie-break must be a principle, not a heuristic.**

> try to abstract a higher-order principle that will better-explain human
> intuition -- nothing in the algorithm should use arbitrary heuristics.

**D3 — The lookahead relaxation (an endorsed premise, not an assumption).**

A predicate body built from terminals, `Seq`, and `*`/`+` is choice-free and
possessive, so it has no backtracking and exactly one run — it is already
deterministic. Humans write `&`/`!` over exactly such bodies; nested predicates
and `First` inside a predicate body may be **documented as unsupported** rather
than handled.

**D4 — Recover the deterministic part; spend the special handling on `First`.**

> lean in on recovering the deterministic part of the tree, applying special
> handling only to do the best job possible across First clauses (which are
> important, but are really at the core of the difficulty of recovering from
> errors with PEG).

**D5 — The AST is primal.**

> the AST is primal; the input sequence is just the evidence used to optimally
> build the right AST, either in parsing or in recovery mode, and the input
> should not be modified or fixed in-place, ever.

> the repairs are ONLY used to implicitly reconstruct the correct AST in-place by
> reshaping the recursive call tree; the repaired string should not insert nodes
> into the AST that aren't actually supported by the input -- instead, syntax
> error spans should be inserted into the actual AST nodes in the memo table. So
> the goal of recovery is to FIX THE SHAPE OF RECURSIVE DESCENT only.

**D6 — One memo table, no eviction, and LR must report upward.**

> you should not launch whole new parser instances; you should keep working with
> and updating the same memo table, which contains the AST nodes

> you should probably not be trying to evict nodes from the memo table (if you
> have to do that to prevent the parser stopping at a memoized wrong value in
> some future re-parse of the same clause at the same position, then your
> algorithm is wrong, you shouldn't have written that memo entry in the first
> place -- similarly, LR handling in the squirrel parser has to communicate back
> up the parse tree so that the recursion frame that ENTERED the left recursion
> does iterative expansion, not the stack frame that closed the LR cycle,
> otherwise the memo table 'blocks itself' and the LR semantics are wrong)

**D7 — Never invent a terminal of a class that is not there.**

> you should never invent terminals of a class that aren't there (e.g. inserting
> a zero to complete a list), although STRUCTURALLY if the only way of fixing the
> parse is to 'insert' a paren or brace, to optimally fix the STRUCTURE of the
> AST, you can in fact fix the AST structure as if that missing character were
> present

**D8 — The two acceptance cases, which are requirements about *reasons*.**

`,3true` must repair to `,3,true` and not `,true`. `[,2,` must repair to `[2,`,
because:

> simply inventing a character to insert is a bit ridiculous (it could be
> anything, so why pick `0` or anything else?), and deleting the initial comma
> immediately yields a valid list.

These are enforced by `_accept.dart` as cases `cx2`, `b1`, `b2`.

## 1.3 Other hard constraints

- **Recovery lives OUTSIDE the pure parser** — the parser is an *oracle only*,
  reached via `Parser.match(Clause, int pos)` and `Parser.parse()`. No recovery
  concept (spans, budgets, costs) may leak into the parsing core. (One deliberate
  exception was later granted: §2.5.)
- **Zero tuning parameters.** A recovery method with a knob is a regression, not a
  trade-off. Every constant in a winning design must be *derived*.
- **Dart is the reference implementation.** The Java, Python and TypeScript trees
  are contaminated by an earlier attempt and are deliberately left uncommitted
  until the Dart core is settled and ported.
- **Line count**: "under 400 LOC, without losing true-PEG conformance or
  sub-250ms latency." Recovery-only LOC, excluding the borrowed parser (§3.5).
- **Every new engine gets a row in the comparison table and a registration in
  `final_table.dart`, in the same commit.** A variant measured but never
  tabulated gets re-invented later.
- **APPEND to the table; do not regenerate it.** Re-running all rows costs ~12
  minutes and rewrites settled numbers with the day's drift. Run the new engine
  *plus a reference row* and append both; absolute milliseconds are not portable
  across occasions.
- Run Dart from `dart/`:
  `dart --packages=<repo>/dart/.dart_tool/package_config.json <file>.dart`.
  `dart analyze` is useless on scratch experiment files (package URIs
  unresolvable) — the only way to check them is to run them.

## 1.4 The `r`-series brief, verbatim

Recorded 2026-08-01 at the owner's explicit instruction ("for now add this to
LESSONS_LEARNED so you don't lose these instructions if you compact"). It
supersedes the `m` series as the active line of work.

> ok, for the next round I want you to try something new. now we're going to try
> an entirely new method: start a new series of algorithms starting with r rather
> than m, i.e. start from r1. The algorithm should do the following: (1) Start
> with a PURE squirrel parser implementation, as detailed in the paper. (2)
> Modify it so that on incomplete parse, the parser switches from parse mode into
> "frontier-finding" mode. In frontier-finding mode, the partial AST is traversed
> to the first mismatch point (recursively traversing through memoized mismatch
> nodes, and skipping forwards past any subclause syntax errors that have already
> been identified for a given clause matching at a given position). Maintain a
> frontier <clause, pos> list for the recovery process; add the nodes that you
> encounter that are the *leaf mismatches* (i.e. mismatches that were reached
> through recursing deeper into the AST, not nodes that were marked as mismatches
> because their subclause matches were marked as one or more mismatches), in
> postorder (bottom-up) order. For Seq nodes, add ALL mismatching subclauses
> after the last matching subclause to the list (in increasing order), each with
> the same start position at the end of the last subclause match (don't recurse
> into matching subclauses); for OneOrMore/ZeroOrMore clauses, add the position
> after the last match; First clauses don't serve as frontier clauses if all
> clauses mismatch, just traverse through all their subclauses (if all
> mismatched) to add fronteir nodes reachable through any subclause. Then once
> you have found all the fronteir nodes and recursed all the way back up to the
> root, you should have a list of positions where skipping a span of characters
> could cause another match to be found, advancing the parse. (3) Now enter
> syntax error spanning mode: for a syntax error span length l starting at 1,
> iterate through each of the <clause, pos> pairs in your
> postorder-traversal-obtained list, and try matching the clause at position p+l,
> skipping any for which p+l > (input.length). The *first time* you find a new
> match of a specific clause C at position p+l, you have identified a syntax
> error span from p to p+l. Then stop iteratively expanding the syntax error
> span, and enter stage (4), advancement: Fully recurse again into the parse
> tree, ignoring mismatch nodes, until you reach the same clause C being matched
> at the same position p, and insert a syntax error node of length l, then
> memoize a match of C at position p+l, and add both the syntax error match and
> the matching subclause as subclause matches. (Actually the AST nodes should
> possibly have separate lists for subclause matches and syntax error matches, to
> keep the subclause match index lined up with the grammar subclause index). (5)
> From there, continue parsing in the normal way, using the standard squirrel
> parser. So basically, this algorithm uses just the squirrel parser, with
> iterative widening of syntax error spans for all frontier nodes, in
> deepest/earliest-visitable order, so that repair is as localized as possible
> (higher nodes in the AST typically span larger ranges of the input string, so
> that's why we look for iteratively-widened matches at the depeest part of the
> tree first). This should be O(|G|n^2) for recovery, I think: one order for
> iteratively widening the syntax error span s, and one order for the max depth
> of the parse tree, which is O(|G|n). Note that the recovery mechanism itself
> effectively skips input characters (handles deletions) in a greedy,
> depth-first, bottom-up order, but a recovery that is found deeper in the tree
> but that cannot continue much further after recovery can be superceded by a
> recovery higher in the tree that prunes the entire part of the AST that was not
> able to fully recovery (which hadles insertion under the Levenshtein model,
> figuratively speaking). Make sure you think very carefully about how all the
> parts of this algorithm interact with all the other parts, so that the syntax
> error tombstones added by one successful recovery attempt are correctly taken
> into account if another recovery parse is attempted, and so that they are
> handled properly when the parser returns to standard squirrel parsing after a
> recovery span is obtained. Think in particular very carefully about when to
> ignore the memoization of mismatches, and when to go back to using mismatch
> memos to avoid duplicating work again, and think very carefully about whether
> to parse state through the call stack, vs. adding state to the parser object
> (e.g. the frontier node list should probably be added to the parser object).
> Also carefully manage all the bookkeeping for recovery (e.g. clearing the
> frontier node list when it is no longer needed). Carefully design all aspects
> of this algorithm first, writing your planned design into LESSONS_LEARNED.md
> for lack of a better place, then implement it, then check your implementation
> is complete and correct, then test it for robustness and efficiency and
> elegance. This design should in theory get you well below the 400-line limit
> that I keep stipulating.

Addendum:

> Also have Codex check your s1 implementation against my prompt, when you have
> finished implementing it, to make sure that the implementation is complete,
> correct, elegant, minimal, and efficient.

("s1" = r1.) **Required order of work, restated by the brief itself:** design
first and write the design down; implement; check completeness and correctness;
test robustness, efficiency and elegance; then hand it plus the brief to Codex
for an independent check.

**What carries over to `r`:** D1, D5, D6, D7, D8, the gate set, "the AST is
primal". **What does not:** the `m`-series cost/net/`_better` key vector,
cost-stratified deepening, the `_Way` Pareto lists, `Filled` insertion marks. The
`r` design is a *deletion-only* recovery with insertion handled implicitly by a
higher recovery pruning a subtree that could not continue — a different objective
function, so `m`-series scores are a reference point, not a line-for-line target.

## 1.5 Later steering, in order

Each of these is a real pivot: it invalidated work that was correct under the
previous framing. They are listed so a future session does not re-derive a
superseded target.

**One standing instruction is deliberately not in this table: §1.8, "reuse the
O(1) signal for recovery."** It belongs to no single pivot — it was repeated on
six occasions from 2026-07-25 and was **ANSWERED on 2026-08-05 by I100, the
pivotal insight of the recovery line** (§1.8's close, §4.9, s3): the LR loop IS
the recovery loop, and left recursion is recovery at cost zero.

| # | The steer | What it invalidated |
|---|---|---|
| 1 | *"87x battery is terrible (does A* help?), and shape 467/519 is a robustness regression the previous report undersold."* | The tape (m65) as shipped. Conceded on both. A* itself does not apply: an admissible heuristic must lower-bound true-PEG remaining cost from a tape state, the available floors are CFG-side and cannot be evaluated per-state without mapping back into grammar coordinates — the representation the tape exists to avoid — so `h` degenerates to 0 and A* collapses to Dijkstra. |
| 2 | *"still not a good tradeoff — review every available improvement again"* | Forced the review that found I22, the certificate, which dissolved the speed/exactness tradeoff entirely. |
| 3 | *"routing between two black boxes is not an algorithm; hoist both into one and simplify algebraically"* | The m66 router. Produced I23 (m67): one class over one substrate. Every later engine keeps the seamless form. |
| 4 | *"OK so m70 is almost twice the size of m62, and has higher latency? I asked you to build something better than all the versions that came before."* | m70's +542 lines over m62. Set the standard that a successor must dominate, not trade. |
| 5 | Fold a copy of the parser into every engine so each file is standalone; mark the recovery region; count LOC between the markers. | The LOC column, which had been comparing two different programs (§3.5). |
| 6 | D5/D6/D7 (the four sentences of §1.2) | m74–m78 wholesale: they apply edits, hand the repaired string to the pure parser, and re-index. That is a *sequence* answer with a tree recovered from it — it modifies the input **and** launches a second parse, and the two are the same defect. |
| 7 | *"this should NOT have resulted in higher latency or more lines of code, at all"* | Any successor that buys quality with latency. (The specific 3.9x this was aimed at turned out not to exist — it was a cross-battery comparison; see §3.6.) |
| 8 | Two modes: standard top-down squirrel parsing in O(n); on incomplete parse switch to bottom-up Earley-like parsing in O(n³), replicate PEG semantics exactly, choose SPPF or DAG over the malformed stream, expand with a DP wavefront from the failure point until the previous partial span bridges to the next. | Nothing — it was built faithfully as m141 and **lost by 17.8x**, then lost again at equal latency (§4.6). The refutation is structural, not an implementation failure. |
| 9 | Anticipate *"probable human intent in how insertions/deletions/mutations are relatively prioritized."* | Cost-minimality as the sole objective. Sharpest statement the project produced: **cost-minimality is not human intent.** |
| 10 | *"right now a mismatch object is stored in a memo entry, and it could even be the same undifferentiated mismatch object for all mismatches, because it's just a tombstone, and it has no length information... Instead, make a new mismatch object for each new mismatch, and inside the mismatch object, encode the length that was consumed by subclause matches (or subclause mismatches) before this clause was found to not match -- and also store the subclause match or mismatch nodes inside the mismatch object."* | The "the parser core is frozen" assumption held for the entire project up to that point. This is the **first change to `dart/lib/src/parser`** in the whole line of work. **Verbatim in §1.7**; what was built in §2.5; what it is still worth in the starred TODO at the head of Part VII. |
| 11 | *"Does this help unify the Levenshtein model in the r series?"* — the observation that the brief already described deletion at two depths: skipping input characters deep in the AST, and skipping an entire grammar subtree shallower. | The framing of insertion and deletion as separate mechanisms. Answered in §4.8. |

## 1.6 How to work here (process rules paid for in wrong numbers)

- **Never edit source by blind index-slicing.** Use the editing tool. When
  scripting an edit, assert the match count *before* writing.
- **A partial `sed` is a silently wrong experiment.** A factor-2 ablation via
  `sed` matched 2 of 5 sites and produced 514/519 — a *mixed pricing*, not an
  ablation. Always verify the substitution count equals the site count.
- **A `sed`-derived gate can measure the wrong engine.** Copying a harness with
  `sed 's/m16/m22/'` did not rebind the import alias, so the output still
  reported m16 while claiming to be m22. Write the new harness fresh, or assert
  the substitution count.
- **Sanity-check the harness output you grep.** Several gate files print a
  reference row *before* the row under test; grepping the first line silently
  reports the baseline for every variant. Caught because six *different* files
  reported byte-identical numbers.
- **A parallel agent will delete and rewrite its own files mid-flight.** Copy
  anything you depend on to a name the other process is told not to touch.
- **Scratchpad directories are ephemeral.** Work that matters must be committed
  or copied into the repo.
- **Measure the optimisation you assume is free.** Two "obvious" cleanups (record
  as memo key, record as memo value) were 2.4x and 2.0x *slower*; the ugly-looking
  int-keyed form is genuinely the fast one. Conversely, consolidating four
  parallel tables into one entry object was assumed to be a wash and paid back 16%.
- **Report the axis you did not win.** Battery wall time and per-case latency
  measure different things — a method can win one and lose the other.
- **Never let a tracked gate file import an untracked scratch file.** Scratch
  `_*.dart` probes stay untracked; gates and controls are tracked.
- **Always name the entry point being measured**, and **never subtract arms that
  never shared a clock**. Both rules were bought by four-layer measurement
  failures (§3.6).
- **Use n ≥ 21 for latency medians.** Smaller samples produced "regressions" that
  were noise.
- **A refutation of one form of an idea is not a refutation of the idea.** Check
  which form you disproved before you close the file on it — one idea was written
  off on its strong form while the short-circuit form was still sound.
- **One symptom can be two bugs.** m77's wrong answers split cleanly: a possessive
  star whose follower begins with the star's body accounted for **all 390** too-low
  answers and nothing else, while a multi-character lookahead body (either
  polarity) accounted for **321** too-high-or-false-`-1` answers and contributed no
  unsound answer at all. Two mechanisms, one symptom. Partition the failures by
  cause before fixing any of them.
- **One run can close a hypothesis, so run it.** "Some damage is undetectable —
  deleting the comma from `[1,2]` gives `[12]`, a perfectly good array" would have
  meant the table was measuring an impossibility. `_undetect.dart` counted them:
  **0 of 1,824**, because the generator already keeps only mutants that fail to
  parse. One run, hypothesis closed, no code changed.
- **Always run the Codex check** on a new engine against the verbatim brief. It
  has found real defects (§4.10) and it has also been wrong; treat its findings as
  hypotheses until confirmed by an own probe.

## 1.7 Steer #10, verbatim — the richer mismatch node

The only instruction in the project that changed the parser core, and the only one
still substantially unimplemented. Quoted in full because §2.5 is an account of how
much of it was built, and the TODO at the head of Part VII is an account of what
was not.

> When you have finished, I had a new idea for the next generation -- put this on
> your TODO list: right now a mismatch object is stored in a memo entry, and it
> could even be the same undifferentiated mismatch object for all mismatches,
> because it's just a tombstone, and it has no length information, other than -1
> that is used to indicate that it is a mismatch (be careful, the -1 sentinel value
> is used as a sentinel somewhere in the squirrel parser algorithm, so if you need
> to start encoding the actual length of consumed input before the span was found
> to not match, as described below, then you need to find where this sentinel is
> used and manually check for mismatch objects, not just check against length).
> Instead, make a new mismatch object for each new mismatch, and inside the
> mismatch object, encode the length that was consumed by subclause matches (or
> subclause mismatches) before this clause was found to not match -- and also store
> the subclause match or mismatch nodes inside the mismatch object (currently
> mismatch nodes do not store the clause's subclause matches at this position as
> children, which is much more memory efficient, but it probably creates
> duplication of work if we need to recurse through mismatch nodes, and anyway, the
> subclause matches are probably separately memoized, at least if new rules are
> reached). Now these mismatch objects that actually contain length information can
> be used to determine the exact position of the frontier (the end of valid parsed
> input) for any AST subtree (although check for special-case handling across
> FollowedBy and NotFollowedBy nodes). Now the iterative widening that I asked for
> in my r-series original request can work with a much more precise frontier, and
> the frontier is more fully connected as an AST. At the end of parsing, however,
> you should not have any mismatch nodes in the returned AST, you should have only
> valid parse nodes and syntax error nodes -- so when the recovery process is able
> to find some new rule match beyond the end of a garbage span, you should replace
> any mismatch nodes with a syntax error node, and continue the parsing from there.

## 1.8 The standing steer, given on six occasions: reuse the O(1) signal for recovery

**This is the most-repeated instruction in the project and it does not appear in
the steer table above, because it never invalidated work — it is a standing
direction that has been open since 2026-07-25.** The mechanism is §2.2; what was
built on it is §2.3; the assessment of how far it has actually been carried is
§2.3's "The third channel". All quotes verbatim, including typos.

**2026-07-25 22:34** (sent three times, the last with `in O(1)` added):

> The left recursion innovation is also described in paper/squirrel_parser.tex
> (although the recovery algorithm described there is old)
> And in fact a similar trick to the LR innovation (communicating an arbitrary
> distance back up the recursion tree in O(1) by setting a bit in the memotable
> entry corresponding to a higher recursion frame) may also aid in collapsing down
> the recovery algorithm into a tiny pure core

**2026-07-25 23:24** — the scope correction, and the sharpest statement of it:

> Also generalize the O(1)-bit hint futher, to frame it as a communication
> mechanism between recursion frames, or equivalently between different parts of
> the parse tree -- **you interpreted my suggestion too narrowly**, and I don't
> think you have found every possible way to use this O(1) communication hack to
> dramatically simplify and optimize a wide range of structural parsing rules and
> heuristics. There is still far more that could collapse down into a simpler
> design.

**2026-07-29 22:40**, naming what the signal would decide:

> Probably the LR parsing trick can be re-applied in a completely different way for
> error recovery, enabling O(1) communication between different recursion frames
> (equivalently, between different parts of the parse tree) via the memo table, **to
> decide how different grammar clauses affect each other's application during error
> recovery** -- but this may not help, and you must simply brainstorm extremely
> deeply and thoroughly and cleverly to discover the true essence of the problem to
> be solved, and to find the most creative, beautiful, and elegant solution
> possible.

**2026-08-02 08:24**, aimed at r3:

> You may also be able to apply the squirrel parser trick somewhere, of
> communicating an arbitrary distance withing the parse pree in O(1) by signalling
> through the memo table. I really feel that this trick can be used somewhere to
> dramatically simplify the parser and end up with a much more elegant solution,
> just like how the squirrel parser handles left recursion elegantly with this
> trick.

**2026-08-03 05:25** — the instruction that produced §2.2 and §2.3:

> make sure you document the squirrel parsing algorithm (signaling an arbitrary
> distance back up the parse tree in O(1) by communicating through a memo entry
> when LR cycles are closed) and how you reused that idea in any later engines.

**2026-08-03 23:53** — the instruction that produced this section:

> I have repeatedly said (see the chat history) that I think that the same
> signaling mechanism could be used to find a powerful way to optimize the error
> recovery algorithm, and to make the code much smaller. I think you said you used
> it somewhere during recovery for "horizontal signalling" in the memo table. This
> needs to be fully documented along with the TODO that you just added.

**On "horizontal signalling."** *Confirmed by searching the whole surviving
transcript:* the word "horizontal" appears **nowhere before the message above** —
the phrase is the owner's, not mine, and I had never used it. The concept it
names is real, and is **I6/I7's third channel, "ACROSS THE TREE IS THE
VALUE"** (§2.3): where the LR bit runs
*vertically*, descendant to ancestor, an **obligation** was to run *horizontally*,
frame to right sibling. It was built, measured, and deleted; §2.3's "The third
channel" is the full account, and it is the honest answer to the steer — **the
vertical channel was reused everywhere, and the horizontal one has failed twice.**

**THE STEER IS ANSWERED (2026-08-05), and the answer is I100 — the pivotal
insight of the recovery line (§4.9).** The collapse the steer predicted
("may also aid in collapsing down the recovery algorithm into a tiny pure
core") arrived exactly where the steer said to look, once the reading was no
longer too narrow: not a second signal shaped like `foundLeftRec`, but the
identity that **a mismatch and a left-recursion seed are the same object — a
suspended reading — and the memo entry's grow-loop is already the whole
recovery engine; left recursion is recovery at cost zero.** Made structural
in s3, that identity deleted half of s2's mechanism (706 → 484 lines at
0.9819 / 78.8% perfect, every gate green) and produced the first engine ever
to dominate r9 on all four axes. Owner's confirmation, verbatim: *"finally --
this is the biggest breakthrough you have made so far in the recovery
algorithm."* The chain, for the record: the six steers above → I100 stated
(commit `9057a96`) → made structural in s3 (`8a6d0d9`).

---

# PART II — THE PARSER

## 2.1 What the pure parser is

A top-down recursive-descent PEG parser with memoization. `Parser.match(clause,
pos)` returns a `MatchResult`. **Memoization is at RULE granularity only** — only
`Ref` nodes get memo entries; interior clauses are re-derived. The clause types
are `Seq`, `First`, `OneOrMore`, `ZeroOrMore`, `Optional`, `FollowedBy`,
`NotFollowedBy`, `Ref`, and terminals (`Char`, `CharSet`, `CharRange`, `Str`,
`Nothing`).

Source of truth: `dart/lib/src/parser/{parser,memo_entry,combinators,terminals,
match_result,clause,tree}.dart` — 4,706 lines including the tree utilities;
`memo_entry.dart` is 95 lines.

## 2.2 The left-recursion mechanism — the whole trick, and the thing recovery inherits

This is the mechanism the owner asked to be written down, because it is what the
entire recovery line is built on. It lives in `MemoEntry.match`
(`dart/lib/src/parser/memo_entry.dart`).

**State it first, because everything else in this file is a consequence of it.**

> A frame at arbitrary depth tells an arbitrarily distant ancestor *"you are the
> frame that entered this cycle — expand it"* by **writing one field into the memo
> entry that ancestor already owns**. The message crosses the whole parse tree in
> **O(1)**, because the destination is addressable **by content** — `(rule, pos)` —
> rather than by walking to it. Not one intermediate combinator learns the message
> exists.

The two frames are not exchanging a value. They are looking at **the same
`MemoEntry` object**: the ancestor obtained it by `(rule, pos)`, the descendant
re-derived the identical key and got the identical object back from the table.
Closing a cycle is therefore one field write (`foundLeftRec = true`,
`memo_entry.dart:43`), which the entering frame reads at the bottom of its own
loop (`memo_entry.dart:82`). **No stack unwinding, no exception, no sentinel
threaded back through N returns, no visited set, and no cost that grows with the
distance between the two frames.** Depth 3 and depth 300 cost the same.

That is the property the rest of the project kept re-using (§2.3), and it is
*also* the property that failed when the project tried to invent a second signal
of the same shape (end of §2.3).

A memo entry holds four fields beyond the result:

- `result` — the best match found so far for this `(rule, pos)`.
- `inRecPath` — true while this `(rule, pos)` is on the current recursion path.
  **This is how left-recursive cycles are detected without a separate visited
  set.**
- `foundLeftRec` — set by a *descendant* frame when it re-enters this `(rule,
  pos)`, signalling to this ancestral frame that it must iteratively expand the
  cycle.
- `memoVersion` — the value of `parser.memoVersion[pos]` when this entry was last
  updated. It ensures memos from a previous expansion round do not prevent
  re-matching after the cycle has been expanded, **without duplicating work**.

The algorithm:

1. **Memo hit** if `result != null` and either `inRecPath` (a cycle back to a
   `(rule, pos)` already on the path, with a known result) or `memoVersion ==
   parser.memoVersion[pos]` (no expansion work has happened at this position
   since). Return it.
2. **Cycle detected** if `inRecPath` and no result yet: this is the fixed point of
   a left-recursive cycle. Set `foundLeftRec = true`, seed the cycle with a
   mismatch, return it. The seed is *positioned* (`Mismatch(clause, pos, 0)`), so
   a seed that escapes into a tree still reports the right frontier: the cycle has
   read nothing here.
3. **Otherwise** set `inRecPath`, then loop: match the clause; if the result did
   not improve, the fixed point is reached, break; otherwise store it, and if
   `foundLeftRec` was set below, bump `memoVersion[pos]` and go round again.

**The direction is the point, and it is D6 in mechanism form.** The frame that
*entered* the left recursion does the iterative expansion; the frame that *closed*
the cycle only reports upward via `foundLeftRec`. Doing it the other way makes the
memo table block itself and the LR semantics are wrong.

**The version bump is per-position, not global.** `memoVersion[pos]` invalidates
stale memos at that position only, which is why expansion is cheap.

Two properties measured, not assumed:

- **A cycle spanning more rules is CHEAPER, not dearer.** A 3-rule cycle (`E <- A;
  A <- B '+' F; B <- E`) expands 1.65–1.91x, against direct left recursion's
  4.2–4.8x. The fixed point iterates per *position*, not per rule in the cycle, so
  extra rules add a constant factor to one expansion rather than multiplying the
  number of them.
- **The multiplier grows slowly.** Direct left recursion is 2.6–3.1x at n ≤ 256
  and 4.2–4.8x at n = 512–1024. Not flat, but not explosive.

## 2.3 The same trick, reused — every engine that inherited it

The O(1) upward message was never re-derived for recovery. **Every standing engine
in this project carries the frozen parser's three fields, renamed at most**, and
each new engine found the message could carry one more meaning. This is the single
strongest continuity in the record.

| Where | The fields | What the one write came to mean |
|---|---|---|
| Frozen parser | `inRecPath` / `foundLeftRec` / `memoVersion[pos]` | "You are a cycle — iterate." |
| **A5** (m41 →) | adopted **verbatim, field for field**, over a wider value | Same message, over "a map from end position to minimum Δ" instead of one match |
| **m60 / I16** | `running` / `parent` / `foundCycle` | *"…generalized from cycles to **all waits**"* — also carries "your operand is ready" |
| **m61 / I17** | the library's own `MemoEntry`, hosting the recurrence | The **sticky** bit is what makes re-widening correct *across passes* |
| **m62 / I18** | bit moves to the ancestral **frame**, addressed by stack index | *"the same O(1) descendant-to-ancestor message"* — content-addressing by index rather than object |
| **m121 / m132 / m143** | `_Cell.inPath` / `foundLR` / `gen` | Third consumer: the bit is the only record that the cell *was* left-recursive |
| **r3 → r9** (standing) | `_Cell.inPath` / `foundLR` / `gen`, **unchanged** | The loop the trick drives serves **repair** as well as left recursion |

Confirmed present in live source, not just in the record: `m143.dart:385, 744–785`;
`r9.dart:613–618, 806–833`; `m62.dart:112–114, 604`; `m121.dart:359, 666–707`.

**A5 — recovery inherits left recursion instead of re-solving it.** The fixed-point
test *"the match did not get longer"* becomes *"no end is new and no Δ got
smaller"*; the seed `mismatch` becomes the empty ends map. There is no second
mechanism and no recovery-specific reasoning about cycles anywhere in the project.
A5 was **not optional politeness**: without it, engines at n ≥ 512 return `-1, no
repair found` — total failure at scale, and a correctness bug the entire JSON
battery was structurally unable to see (§4.1).

**m60 — the generalization that made the coroutine possible.** A request reaching a
RUNNING entry can only be reaching an ancestor of the single running chain — which
is exactly what `inRecPath` detects — so the same bit that says "you are a cycle"
can equally say "the child you parked on has settled". The continuation lives in
the memo entry, so **the coroutine *is* the memo**. m62 then split it: the pass in
flight is a frame, the entry keeps only facts, and the bit is set on the ancestral
frame *by stack index*. m62 is still the LATENCY reference (1,312 ms).

**m121/m132/m143 — the bit acquired a third job.** Left recursion **is** a
repetition (`E <- E op T / T` ≡ `T (op T)*`), so I41 applies to it unchanged: PEG
resolves a repetition possessively. `foundLR` is the only surviving record that
this cell was left-recursive, and that is what licenses the collapse —
`if (cell.foundLR && _budget == 0) cell.ways = _possessive(cell.ways);`
(`m143.dart:781`). **That one line is what keeps round 0 exactly the frozen
parser.**

**r3 → r9 — the loop, not just the signal.** The reuse that mattered most was not
the message but the *loop it drives*: "re-run this cell while the answer improves,
retiring the memo at this position with one integer bump." That loop does not care
*why* the answer improved — a left-recursive expansion and a repair the first pass
could not afford are the same monotone improvement. So one mechanism serves both,
and `_version[pos]++` retires every stale cell at that position **without touching
any of them**.

What that bought, beyond the score: **there is no second parse.** No `_forget`, no
`_repairs` side table, no frontier walk, no widening loop, no advancement test, no
salvage pass, no re-parse to find out what a repair did — r2 needed all of it to
ask "what would happen if", and r3 computes the answer where the question arises.
This is also how the line satisfies **D1** ("never start a new parse").

**The one thing that had to change** was the improvement test. r1's `_improved`
compared **reach alone**, so an iteration that improved *cost* at the same reach
was discarded — and clean `expr` came back at cost 8. **Reach OR rank** fixes it,
and accumulating across iterations makes termination monotone.

### The generalization the trick was reaching for (I6/I7)

> `MemoEntry.foundLeftRec` is **one bit from a descendant frame to an ancestor** —
> "you are a cycle, iterate" — and it is the whole of left recursion. An obligation
> is **one integer from a frame to its right sibling** — "the next character you
> emit is one of these" — and it is the whole of lookahead. Neither fact can be
> computed by one frame alone; both are O(1); neither needs a rule of its own once
> something carries it.
>
> **DOWN THE TREE IS THE ARGUMENT. ACROSS THE TREE IS THE VALUE. UP THE TREE IS THE
> MEMO.**

*Any fact a frame cannot compute alone, but a neighbour can, belongs in whichever
of those three channels connects them.*

### The third channel — across the tree, and what happened to it

This is the honest answer to the standing steer of §1.8, and it needs stating
plainly because the record scatters it across five places.

**The LR bit is VERTICAL: descendant → ancestor, addressed by `(rule, pos)`.**
Every reuse in the table above is vertical. That channel has been an unbroken
success — it is in every standing engine, unchanged, and it is what lets r9 have
no second parse at all.

**The HORIZONTAL channel — frame → right sibling — is the one the owner keeps
asking about, and it has been attempted twice and failed twice.**

| | what it was | verdict |
|---|---|---|
| **I6/I7 (m47–m49)** | an **obligation**: one integer saying "the next character you emit is one of these", travelling out inside the value. Proposed as the exact analogue of `foundLeftRec` — "neither fact can be computed by one frame alone; both are O(1)" | **Measured inert on every real input**, and deleted by I24 (m68): under a certificate the fast engine need only be a floor, so the bookkeeping bought nothing |
| **I34 (m78)** | the second attempt, with the lattice gone | **"An obligation you cannot write down constrains nothing."** A constraint that cannot be represented in the value cannot be propagated in it either |
| **the budget-exactness bit** | not sibling-to-sibling but the same instinct — one more monotone bit riding the memo table | **Refuted by construction** (below). Listed here because it is the third failure of "add another bit like `foundLeftRec`" |

**Why the vertical channel works and the horizontal one has not, stated as one
rule.** `foundLeftRec` reports a fact that is **monotone and terminal**: a cycle
either was closed or was not, the answer never changes once the pass ends, and the
recipient is uniquely identified by content — `(rule, pos)` names exactly one
entry. An obligation has neither property. It is a claim about what a *sibling
that has not run yet* will do, so it is not terminal; and "the right sibling" is
not a content address — there is no key that names it, which is precisely what
I34 says when it says you cannot write it down.

**What survives, and it is not nothing.** Two live mechanisms are horizontal in
effect while staying vertical in address:

- **The per-position generation bump.** One integer bump **retires every stale
  cell at that position without touching any of them** — a broadcast to an
  unbounded set of siblings, in O(1), addressed by position. Live as
  `_version[pos]` in r9 (`r9.dart:830, 833`) and as `gen[pos]` in m143
  (`m143.dart:776`, one array per memo family, `_pg` / `_rg[_budget]`). This is
  the closest thing in the project to the horizontal channel actually working, and
  it is doing real work in the standing engine.
- **I92 (r9)**: *an obligation and a trailing discard are two claims about one
  position.* The obligation idea survives here, but **collapsed into the value at a
  position** rather than sent to a sibling — which is the shape I34 predicted was
  the only viable one.

**So the steer is not answered, and it is not refuted either.** What is refuted is
one specific reading: *adding a second `foundLeftRec`-shaped bit for a
sibling-to-sibling fact.* What has never been tried is the reading the owner
actually gave on 2026-07-25 — *"a communication mechanism between recursion
frames, or equivalently between different parts of the parse tree… to decide how
different grammar clauses affect each other's application during error recovery"*
— with a **content address that exists**. The richer mismatch node (§2.5) supplies
exactly that missing address for the first time, which is why the two topics are
now one TODO (Part VII, head).

### REFUTED: the trick does not generalize to the budget — do not re-litigate

The obvious analogue was a **budget-exactness bit**: mark an entry exact iff
nothing below it was discarded for exceeding the budget, propagated by a monotone
global counter *exactly as `memoVersion` propagates*. An exact entry could then be
reused at every budget instead of only at budgets it was computed at or above. Its
stronger form stores the minimum dropped cost `d`, making the entry valid at every
budget `< d`.

**Both degenerate to nothing, by construction.** FAB is available at price 1 at
every position, so candidates exist at *every* cost: at budget `b`, a head costing
1 composed with a tail costing `b` always produces a dropped candidate at cost
`b+1`, giving `d = b+1` and validity only up to `b` — which is exactly what the
entry already records. **No entry is ever budget-exact.** This also explains m30,
which computed a complete level 0 to avoid precisely this recomputation and
measured **14x slower**. The budget stays a filter on Δ (A3), not a memo key.

The distinction that makes the difference: `foundLeftRec` reports a fact that is
**monotone and terminal** — a cycle either was closed or was not, and the answer
never changes once the pass ends. Budget-exactness is a claim about *everything
that did not happen below*, and under an always-available repair primitive, that
claim is never true.

## 2.4 The fixed-point test, and the two places it is subtle

The loop's termination condition used to read `newResult.len <= result!.len`.
That was correct **only because a mismatch was a shared tombstone with `len ==
-1`**: no match could lose to one, and a mismatch could never replace a match.
Once a mismatch carries the input it consumed (§2.5), its `len` is `>= 0` and that
arithmetic would let a far-reading mismatch overwrite a short match. Both
directions are now stated outright:

```dart
if (result != null && (newResult.isMismatch ||
    (!result!.isMismatch && newResult.len <= result!.len))) { ... break; }
```

And **when both are mismatches, keep the one that read furthest.** The fixed point
is reached either way, but *which* failure is stored is still free — nothing in
the parse reads a mismatch's shape, only whether it is one. The stored value is
usually the seed: zero length, no children. Keeping it made every left-recursive
rule's failure structureless, which is not a small effect: on `E <- E '+' N / N`
the whole tree collapsed to a single node, while the same grammar written without
left recursion reported six.

**And a third place, found only when the test was lifted to a set.** m143 merges
the re-derived result into the cell instead of replacing it. The frozen parser can
replace, because it keeps a re-derived left-recursive result only while it is
strictly *longer*, so the seed is monotone by construction. Lifted to a **list of
endings**, monotone means *merge*: replacing lets the cell **shrink**, and then the
growth test fires forever on an ending the cell already had. Measured symptom:
`1+2` against `Expr <- Expr WS AddOp WS Term / Term` oscillated between `{1}` and
`{3}` and **never returned** (`m143.dart:758–765`). Merging also supplies the
termination proof — every pass either lowers a cost or raises a count at some
ending, and both are bounded.

## 2.5 What a `Mismatch` now carries (the one core change, 2026-08)

Steer #10, quoted in full in §1.7. This is the **first and only change to
`dart/lib/src/parser` in the whole line of work** — the core had been frozen until
here — and it is the richest piece of unexploited information the project has.
**No `m`-series engine had any of it.** The TODO at the head of Part VII is the
open question of what a recovery engine built on it could do.

### Where it was built, in order

| commit | when | what | where |
|---|---|---|---|
| `38422a3` | 2026-08-02 17:50 | prototype: mismatch-as-node **plus `reach`** | `_core2.dart` (a standalone core), gated by `_core2gate.dart` |
| `46026dd` | 2026-08-02 18:38 | the first engines to consume it: **r10, r11, r12, r13** | `r10.dart`–`r13.dart`, all built on `_core2.dart` |
| `46bd136` | 2026-08-02 22:22 | **ported into the shipped core** — the mismatch tree only, without `reach` | six files in `dart/lib/src/parser`, + 12 tests |
| `6b81302` | 2026-08-02 22:34 | a left-recursive failure keeps its evidence, not the seed | `memo_entry.dart` |

So "which engine" has two answers, and they are different things. **r13 is the
engine that ran on an exact frontier and measured what it is worth** (§4.8: 0.9008
/ 51.9% / 327 lines — the smallest engine in the project that works at all), and it
runs on `_core2.dart`, *not* on the library. **The library port is what every
future engine inherits for free**, and nothing has consumed it yet.

### What is stored

`Mismatch` (`dart/lib/src/parser/match_result.dart:91`) is no longer a shared
tombstone. Each failure allocates its own node:

- **`len` is the maximum length of input this clause validly consumed before it
  was found not to match** — the longest valid matching prefix at this site. It is
  **not** a match length, and nothing may compare it against one without testing
  `isMismatch` first. That is exactly the `-1` sentinel trap the instruction
  warned about, and it bit at two sites (below).
- **`frontier` (`match_result.dart:104`) is `pos + len`** — the exact end of the
  input this subtree read and accepted.
- **`subClauseMatches` holds the results the clause had accumulated when it
  failed — matches and mismatches alike.** This is what makes the frontier
  *connected*: it is reached by descending from the root, not by searching a table.

Per clause type, which is the whole of the mechanism:

| clause | its `len` is | its children are |
|---|---|---|
| `Str` (`terminals.dart:42`) | **`i`** — how many characters of the literal the input did supply before the first disagreement; `fun` of `function` puts the error three characters in, not at the keyword's start | none (a terminal) |
| `Char` / `CharSet` / `AnyChar` | 0 | none |
| `Seq` (`combinators.dart:51`) | `curr - pos` — the span of the slots that **did** match | the matched prefix **plus the failing slot's own mismatch node**, always last: PEG stops at the first failing slot, so there is exactly one |
| `First` (`combinators.dart:93`) | the **max over the arms** of each arm's own `len` — the furthest any arm read | **every** failed arm, because a choice whose arms all failed is not itself a place to repair, and which arm is cannot be known from there |
| `OneOrMore` (`combinators.dart:130`) | 0 — nothing repeated even once, so nothing was read | the body's own mismatch, the whole account of why |
| `Ref` (`combinators.dart:201`) | the referenced rule's own mismatch, **passed through unwrapped** | none of its own: a failed reference is not a second failure, and the rule's mismatch already carries the position, the length and the memo key. Wrapping it cost 15% of parse time, because it allocated on every memo **hit** for a failing rule |
| `FollowedBy` / `NotFollowedBy` (`combinators.dart:252`, `:231`) | **0, and the body's extent is discarded** | **none** — see below |

**The lookahead case is a deliberate answer to the instruction's own question**
("although check for special-case handling across FollowedBy and NotFollowedBy
nodes"). A predicate reads nothing, so its frontier is its own position; reporting
the body's length would claim a frontier past input the enclosing sequence never
consumed, and a repair placed inside a zero-width assertion would consume input the
assertion does not. It is a decision, not an oversight — **but it is still evidence
thrown away**, and it is one of the open threads in the TODO.

**What the `m` series had instead: nothing.** *Confirmed:* before this change a
mismatch was a shared tombstone with `len == -1`, so there was **nothing in the
tree to read a frontier off**; the only frontier the library offered was
`Parser.syntaxErrorPosition()` (`parser.dart:67`), which scans the whole memo table
for the largest position at which anything failed and returns a **bare integer,
with no clause and no path**. Anything more precise had to be re-derived by
re-matching candidate clauses at candidate positions and seeing how far each got —
which is what the brief's iterative widening is, and what §4.8 measures the price
of. *Confirmed:* `m143.dart`, the standing `m`-engine, contains **zero**
occurrences of `Mismatch` and never asks for a frontier under any name; it searches
repairs directly instead. So the `m` line did not solve this problem cheaply — it
worked around not having the information at all.

**Two sentinel sites bit during the change**, both because `-1` had been doing
double duty as "no match" and as "shorter than everything":

1. The fixed-point comparison above.
2. The left-recursive seed, which was still an undifferentiated tombstone.

### The three parts of the instruction that are NOT implemented

1. **The `reach` half.** The library keeps only what *failing* clauses learned. A
   clause that **succeeds** still discards the attempts it made along the way:
   `Repetition` drops `stoppedBy` at `combinators.dart:135` whenever it matched at
   least once, and `Optional` drops its failed body at `combinators.dart:165`.
   Those discards are frequently the only record of where the input really
   stopped — measured below at a 27.9% fidelity gap.
2. **Lookahead evidence**, as above.
3. **"…you should replace any mismatch nodes with a syntax error node, and
   continue the parsing from there."** The *invariant* the instruction asked for
   holds — `buildAST` drops mismatches (`tree.dart:158`), so a finished tree
   carries only matches and `SyntaxError`s — but it holds by **discarding**, not by
   **substituting**. Nothing converts a mismatch node into a syntax-error node and
   resumes the parse from it. That conversion is the mechanism the instruction
   actually described, and it is not built.

### What the change cost and what it has bought, measured

**Scope.** `dart/lib/src/parser` is byte-identical between `6a8a173` and
`1c88415`, and `1c88415..HEAD` over `dart/lib` + `dart/test` is *exactly* this
change: six parser files (153 insertions, 32 deletions) plus the 160-line
`test/parser/frontier_test.dart` (12 tests). So a lib swap between those two
revisions isolates it perfectly.

**Cost: it is paid per mismatch, and only there.** Pure parser, no recovery
imported, JIT-warmed, min of 25 rounds, three alternating process pairs. Two
grammars over the same 32,000-character input, one in which nothing ever
mismatches and one in which every token is reached through nine failing `First`
arms:

| grammar | before | after | ratio |
|---|--:|--:|--:|
| nothing mismatches | 1.263 ms | 1.287 ms | **1.019** |
| everything mismatches | 5.895 ms | 6.742 ms | **1.144** |

On four realistic mixed cases (clean JSON, broken JSON, left-recursive
arithmetic, miss-heavy `First`) it is **5.6–8.8% slower** on min. Peak RSS is flat
to ~1.3%, so the cost is the *frequency* of short-lived allocations — one fresh
object and one child list per failure where there used to be one shared tombstone
— not heap growth.

**Benefit so far: zero on every scored column.** r1–r9, m132 and m143 each score
bit-identically against the old and the new lib. The tracked gate is unmoved:
519/519 cost-1 and 490/519 (94.4%) shape at *both* revisions; the suite goes 308 →
320 tests and the delta is exactly the 12 new frontier tests.

**Nothing consumes the new information yet.** `.frontier` appears only in
`frontier_test.dart` and one scratch gate. `m143` never names `Mismatch` at all.
r9's only contact with it is the one-line repair the change *forced* — the
`m.len >= 0` → `!m.isMismatch` fix in `_terminal` (§4.7). And r13, the engine that
actually measured what an exact frontier is worth, runs on its own `_core2.dart`,
not on `dart/lib`.

**And as shipped, the tree's frontier is numerically *behind* the scan it was
meant to replace.** On four broken JSON documents, walking the returned mismatch
tree gives 6 / 6 / 4 / 1 where the pre-existing `Parser.syntaxErrorPosition()`
gives 16 / 11 / 5 / 1. The new tree gives a frontier that is **located** — a
clause, reachable in 23–48 nodes, instead of a bare integer — but on 3 of 4 it is
a *shallower* number. That is the same 27.9% fidelity gap the port check reports
below, seen from the user's side, and it is the whole content of the open `reach`
fork.

**What it did fix is real, and it is a correctness bug, not a metric.** Before
`6b81302` a left-recursive rule's failure kept the *seed* — childless,
zero-length — so every such failure was structureless. `E <- E '+' N / N` on `+1`
collapsed to one node while the same language written without left recursion
reported six. FRONT-11 pins it.

**Port fidelity, measured** (`_portcheck.dart`, tracked). The experiment
`_core2.dart` also carried `reach`: a watermark on **every** node including
matched ones, so it keeps what a *successful* clause tried and threw away (an `X?`
that matched empty still learned how far `X` agreed). The library port took only
the part the instruction named. Result: the library's mismatch tree alone
reproduces `_core2`'s `reach` on **27.9%** of battery cases; adopting `reach`
would give 100% frontier fidelity for about **1.5x pure-parse time**.

**This is a real fork, still open** (§7, item 1): the instruction's mechanism and
`reach` are different mechanisms, and only the first was requested.

**None of this is a reason to discount the change — it is the reason to
investigate it.** Everything measured above is the cost of *producing* the
information; the benefit column is zero because **nothing has been built that
consumes it**. See the TODO at the head of Part VII.

---

# PART III — HOW THINGS ARE MEASURED

There are **two benchmark eras**. Numbers do not cross between them, and a number
quoted without its era is meaningless.

## 3.1 Era 1 — the 519-mutant JSON battery (m1–m78)

Every single-edit mutant (delete, insert, substitute, transpose at every position;
insertions drawn from `Q z } " , 5`) of

```
{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}
```

that the pure parser rejects. **The columns, always reported together** (a row is
only meaningful whole — a good `shape` bought with a bad `cost` is not progress):

| column | meaning | why it matters |
|---|---|---|
| **shape** | recovered tree's nesting of structural `Ref` nodes equals the *unmutated base document's* | the real accuracy score; "it produced a tree" is not success |
| **cover** | terminals + error spans tile `[0, len)` exactly | catches trees that silently drop input |
| **crsh** | mutants on which the engine threw | any nonzero value is a hard defect |
| **cost hist** | histogram of reported repair cost; must be `{1: 503, 2: 16}` | a single-character mutation *should* cost 1, so mass at 2 is over-charging — a minimality regression shows here before `cost` catches it |
| **valid** | the 7 well-formed documents returned untouched, cost 0, no error spans | recovery must be inert on correct input |
| **cost** / **tree** | 44 cases over 5 grammars vs brute-force minimum. **Deliberately two columns**: `cost` is only that the *price* is minimal, `tree` that the witness can be *rebuilt and covers the input* | "m23 passes the first and diverges on the second" |
| **pred** | exact agreement with brute force on **lookahead** corner cases | JSON has no lookahead, so the whole battery is otherwise blind to this class of defect |
| **unsnd** | cases priced **below** the true minimum — repairs claimed that *do not exist* | **the one number that disqualifies outright** |
| **eleg** | 0–10 | **a judgment, not a measurement** — see §3.6 |
| **bugs** | defect tags | `PEG`, `RR`, `d13`, `K40` are *inherited* flaws, not per-engine choices |
| **LRmax** / **RRmax** | largest 1-error input completing without `StackOverflowError`, left/right-recursive | `>=4096` means it never overflowed at the tested ceiling |
| **battms** / **latms** / **/v6** | wall clock: 519-mutant battery; sum over 12 latency cases; latency normalised against v6 | see §3.6 — `latms` is not what it looks like |

**Why `pred` and `unsnd` exist at all is the lesson.** They were added because
**m47 was unsound while every other column of its row was clean.** A battery
cannot report a defect in a class its corpus does not contain. This is §3.4's
lesson from the other direction: there, self-consistent engines shared an error;
here, a complete-looking table had no column that could hold one.

Latency measured separately on 12 synthetic cases (DEL/INS/SCRAM at 4/16/64 chars,
plus one typo at n=145/530/2114), min-of-N, **all engines alternating in a single
process** so none gets a systematically colder heap.

## 3.2 Era 2 — the AST-diff battery (m79 onwards, and all of `r`)

`buildBattery()` in `dart/experiments/recovery/astdiff.dart`. Multiple grammars
and corpora, mutated systematically; membership is decided by the **library**
parser's `Parser(...).parse().hasSyntaxErrors`. Current size: **13,605 cases /
1,824 weighted**, stable across the 2026-08 core change (measured, not assumed —
a library change *can* move the case set, so re-measure it before trusting any
cross-run comparison).

The score is an AST-diff against the known-correct tree. **The critical property:
the expected tree is derived from the original document, which the engine never
sees.** It is not the engine's own output re-examined, and no engine can be tuned
toward it without actually recovering the shape a human would expect. `_score1.dart`
prints:

```
name  score  perfect%  crashed  uncovered  ms  cat=mean...
```

Ten categories: `delim-delete` 3.0, `truncate` 3.0, `quote-delete` 2.5,
`junk-insert` 2.0, `delim-insert` 2.0, `literal-damage` 1.5, `quote-insert` 1.5,
`multi-damage` 1.5, `transpose` 1.0, `content-damage` 1.0.

**WEIGHTS ARE COVERAGE, NOT MULTIPLIERS.** A category's weight is how many cases it
*contributes*, not a factor applied to its mean; the aggregate is a plain
**unweighted mean over cases**. A multiplier would let a well-supplied easy
category buy points; coverage makes an important category *be tested more*.

**And that has a consequence that went unnoticed until it was audited.** The
per-category case count is `weight * u`, where the unit is derived from supply:

    u = min over categories of floor(n_raw / weight)

So **the scarcest category sets the resolution of the entire battery**, and every
other category is truncated to match it. Measured: `u = 37`, set by `delim-delete`
— 113 raw cases at weight 3.0. **The most important category was starving the
battery.** The waste was severe and invisible: **705 weighted cases out of 5,610
generated, discarding 4,906**, with per-category utilisation from `delim-delete`
98.2% down to `delim-insert` **3.9%**. A category could be 96% unused and nothing
in the output said so. The fix was the one the code's own comment prescribed — *if
a category is short, GENERATE MORE OF IT*:

| | before | after |
|---|---|---|
| documents | 11 | **23** |
| raw cases | 5,610 | **13,605** |
| weighted cases | 705 | **1,824** |
| unit `u` | 37 | **96** |
| grammars spanned by `quote-delete` | 1 | **2** |

**The general lesson, for any weighted-sampling gate: when the sample size per
stratum is derived from supply, the least-supplied stratum silently caps every
other one. Audit utilisation per stratum, not just the totals.**

### `truncate` was not the weak category — the column was broken

For a generation of engines `truncate` read as the weakest area and the obvious
place to improve. **It was not.** A truncate case is `doc.substring(0, k)`, and it
was scored against the skeleton of the **undamaged whole document** — so every
named node lying entirely past `k` covers characters that are *not in the input*.
Producing them means inventing content, which D7 forbids in as many words; not
producing them was charged as a structural error. **Every engine was being
penalised for obeying the rule.** `_ceilcat.dart` priced the real ceiling:

| truncate cases | 288 |
|---|---|
| mean reachable ceiling | **0.5662** |
| mean m92 score | 0.5614 |
| cases already at or above the ceiling | **216 (75.0%)** |
| real headroom | **0.0047** |

**43% of the column's range was unreachable by construction**, in the category
carrying the heaviest weight. The fix was in the brief the whole time — the
evaluator is specified to build the correct repaired AST **for the expected
damage**, and truncation is the one category where the tail is *absent* rather
than corrupted. `expectedFor` in `astdiff.dart` now owns that distinction and
every scorer calls it: keep named nodes with `pos < k`, **including the one
straddling the cut** (that node is precisely the unterminated construct a reader
does expect reported). No named node in any corpus is zero-width (**0 of 667**,
checked), so `pos < k` needs no boundary argument.

**Verified surgical.** m62's nine other columns were byte-identical before and
after; only truncate moved, 0.490 → 0.816. Because only 288 of 1,824 cases change,
the correction is predictable in closed form —
`new = old + (new_truncate − old_truncate) × 288/1824` — which is what made the
re-run auditable: any engine not satisfying it had something *else* change.
Predicted/measured: m62 0.9550/**0.9550**, m92 0.9558/**0.9559**.

It also changed a ranking. m92's entire aggregate lead over m62 had been truncate;
corrected, m62 wins 7 of 10 categories and produces more exactly-correct trees.
**The defective column had been flattering m92.**

**Current position (r9): `truncate` is 0.947 — mid-pack, not the floor.** The real
weak cluster is `truncate` 0.947 / `multi-damage` 0.949 / `literal-damage` 0.957 /
`transpose` 0.968, against `content-damage` 1.000 and `quote-delete` 0.999.

At the other end, `content-damage` was audited
separately because **a flat 1.000 is normally the signature of a vacuous test**. It
is not vacuous and not tunable: the insert alphabet is `z Q " , } 5 ; ) \`, and
inside a JSON string every one except `\` matches `[^"\\]` and still parses, so the
`!parses` filter drops them all. Every case is a stray backslash *by construction*,
and all 96 were inspected individually. Solved, and genuinely narrow.

## 3.3 The gate set

Every one of these must pass before an engine is a candidate:

| gate | what it proves |
|---|---|
| `_accept.dart` | the three acceptance cases `cx2`, `b1`, `b2` (D8) |
| `_conf1.dart` | true-PEG conformance — a possessive `*` and a committed `/` are answered the PEG way, not the CFG way |
| `_freespan.dart` | no free spans: the engine is not deleting input it has no reason to delete |
| `_recommit.dart` | the descent-phrased guards actually bind (this is the gate that showed I77 never worked) |
| `_score1.dart` | the battery score |
| `_coregate.dart` | the pure core is unchanged where it must be |
| `dart test` | the library suite — **320 passing**, re-confirmed 2026-08-03 |

**Measured gate state, re-run 2026-08-03 — and the standing `m`-engine does not
pass all of them.**

| gate | s1 | r9 | m143 | m132 |
|---|---|---|---|---|
| `_accept` | **PASS** `cx2=1 b1=1 b2=1` | **PASS** `cx2=1 b1=1 b2=1` | **PASS** `cx2=1 b1=1 b2=1` | **PASS** `cx2=1 b1=1 b2=1` |
| `_freespan` | **PASS** | **PASS** | **PASS** | **PASS** |
| `_recommit` | **PASS** 16/16 | **PASS** 16/16 | **FAIL** 15/16 | **FAIL** 15/16 |
| `_conf1` free passes | **0** (`0 1 1 0 2 3`) | **0** | **0** | **0** |

(s1 column measured 2026-08-05 on the tracked gate files, same session as its
battery row.)

The single failing case is the same one for m143 and m132: `[1,[2,[3,[4]]],5"` is
answered as a **String** where the committed construct is an **Array** — the
healthy prefix `[1,[2,[3,[4]]],5` establishes an array, and the trailing quote is
allowed to retype the whole thing. Of the nine engines the gate covers, six fail:
m121 and m126 pass 16/16, m132/m136/m143 fail this one case, and m127/m141/m145
fail four cases each. r9 is the only `r` engine in the gate and it is clean.
**So the `m`-line acquired this at m127, partly repaired it, and m143 still
carries one instance.** It is not recorded anywhere else in this document, and it
qualifies the whole `m`-column: on the gate that exists specifically to catch a
guard that does not bind, the standing `m`-engine binds 15 times out of 16. It
does not change which engine is the standard — r9 already is — but any future work
starting from m143 inherits a known open failure, and **"every one of these must
pass before an engine is a candidate" is a rule the `m`-line has been violating
since m127.**

The two gates that are not per-engine both pass on the same re-run: `_coregate` is
**PASS** (2,996/2,996 frozen-lib equivalence, 3,252/3,252 reuse == fresh parse, no
core drift, no engine importing another) and `dart test` is **320/320**.

For `_freespan` the same re-run puts m121, m126, m127, m132, m136, m141, m143 and
all of r1–r9 clean — **10 of the 26 engines it covers still repair what was not
broken**: m129, m130, m131, m133, m134, m135 and m137–m140 each delete real input
from an already-matched span on 4 of 5 probes. Those ten interleave with the
passing engines by number, so the failing set is a branch and not a stretch of the
lineage; do not read `m129–m140` as an interval.

**What `_conf1` actually gates is the free-pass column, not the cost row.** A pass
is **0 free passes** — no engine reporting cost 0 for a string the frozen parser
rejects. The cost row `0 1 1 0 2 3` was once written down as the pass signature,
and that is too strong: re-run 2026-08-03, **every engine from m112 to m143 reads
`0 1 1 0 2 2`, the standing `m`-engine included**, while r1–r6, r8 and r9 read
`0 1 1 0 2 3`. All of them take 0 free passes. Two families, two answers, both
gated as passes for their whole lifetimes. (r7 is the one true outlier at
`0 1 1 0 3 6`.)

**What the gate does catch, it catches emphatically.** The thirty-one engines
m79–m111 all read `4/4  0 0 0 0 0 0` — cost 0 on every probe, including the four
strings the frozen parser *rejects*. That is not a near miss; it is the whole
free-pass hole I68 closed at m112, and it is why the free-pass column, not the
cost row, is the pass criterion.

**And the digit they differ on is a pricing choice, not a conformance failure.**
Only probe 6 splits them: `Top <- Item+; Item <- &Kw Word WS; Kw <- "if"` on input
`ab if`. `_conf6.dart` asks the frozen parser which repairs are in the language,
and **cost 2 is genuinely reachable** — both `ifab if` (insert `if`) and `if if`
(substitute `ab` → `if`) are accepted, and **both invent the characters `i` and
`f`**. The cheapest repair that invents nothing is `if`, by deleting `ab `, at
cost 3. So the `m`-line pays 2 and the `r`-line pays 3 because **D7 and I72 forbid
inventing a terminal the input never offered** — the r-line is deliberately
overcharging by one against pure edit distance. That the two numbers were being
compared as if one were a conformance defect is the mistake; the r-line is obeying
a directive the m-line predates. *(The reachability of cost 2 and the invention
content of each repair are measured; that r9 reaches 3 specifically by refusing
the invention is inferred from I72, not read off its trace.)*

**But conformance is a trade, and the record settles which way it goes.** For a
grammar like `S <- 'a'* "ab"` the **PEG language is empty**, so a fully sound
possessive-repetition veto would make the engine report *unrepairable*. **Reporting
"no repair exists" is PEG-correct and useless.** Repairing toward the CFG reading
is the better answer there. The rule the line actually follows: **take the PEG side
of the trade only where it costs nothing** (this is what I3 does). Do not chase
total conformance into the empty-language cases.

## 3.4 Ground truth: the only gate that can catch a *shared* error

Every engine had been checked against every *other* engine, which cannot catch an
error they share — and the left-recursion reentrancy bug was exactly such an
error. `bf_check.dart` computes the true minimum edit distance by breadth-first
search over single-character edits, asking the pure parser whether each candidate
is in L(G). Slow and stupid, and therefore trustworthy.

Its grammars are chosen to vary the *structural feature* the engines
special-case, not just the inputs:

| grammar | inputs | m16 | m22 | m26 |
|---|---|---|---|---|
| directly left-recursive expr | 10 | 6/10 | 6/10 | **10/10** |
| right-recursive expr (same language) | 10 | 10/10 | 10/10 | **10/10** |
| indirectly left-recursive (`E→A→B→E`) | 8 | 6/8 | 6/8 | **8/8** |
| nullable left recursion | 6 | 6/6 | 6/6 | **6/6** |
| tiny JSON | 10 | 10/10 | 10/10 | **10/10** |

**Lesson: differential testing between your own variants proves agreement, not
correctness.** Build one oracle that shares no code with any of them, however
slow.

## 3.5 The LOC convention, and why the column was broken

LOC means **recovery-only lines**, excluding the borrowed parser. This was not
always true, and the column silently compared two different programs: the
instruction was to fold a copy of the parser into *every* engine and count between
markers, and a scan for a top-level `class Parser` found **only m69 and m70 carry
one** — every other engine, the standing engine included, reaches the parser by
`import 'package:squirrel_parser/squirrel_parser.dart'`. `_core.dart` is 490 lines
and is a *constant*, so folding it changes no engine-vs-engine comparison; but a
row that includes it is not comparable to a row that does not.

Current recovery-only counts: **m143 = 628** (of 1,320 total file lines), **r9 =
536** (of 1,597), **r13 = 327** (of 591).

**`wc -l` is not this column, and cannot be converted into it.** Three different
numbers exist per engine: total file lines (`wc -l`), the committed count of
non-blank non-`//` lines, and that same count after `dart format
--language-version=3.0`. Only the third is the LOC column. The ratio between the
first and the third is **not** a constant — 1,597 → 536 for r9 but 1,320 → 628 for
m143 — so a raw count cannot be scaled into a comparable one, and a table mixing
the two silently ranks by comment density.

**The measure is implemented, not remembered.** `dart/experiments/recovery/loc.py`
is the authority: it copies every engine to a scratch directory, formats the
copies at language version 3.0, counts, and caches `{name: (committed,
normalised)}` to `loc.json` — **the second element of that pair is the number this
document quotes.** It sweeps every non-`_` file in the directory in one run, so
the cache is complete for all ~200 engines; there is no reason to hand-count one.
Two engines are not files in that directory and are aliased: **`dot` →
`dart/lib/src/recovery/dot_recovery.dart`** and **`v6` → `sd6.dart`**. Formatting
happens on copies, so the repository is never touched — but note that a copy alone
does not reproduce the figure, because the language version resolves through
`.dart_tool/package_config.json`, which a copy cannot reach; the explicit
`--language-version=3.0` is what makes it exact (`loc.py`'s own docstring records
the m113 = 682-vs-579 case that proved it).

## 3.6 Measurement rules, each bought with a wrong number

- **Absolute milliseconds are not portable across occasions.** Always run a
  reference engine alongside the new one.
- **The `ms` column is not deterministic** — spread is about 7% within a session,
  and it is **not comparable across sessions at all**. Battery score and swallow
  counts *are* deterministic.
- **Never subtract arms that never shared a clock.** A 3.9x latency "regression"
  that drove a whole occasion's marching orders did not exist: it was a
  cross-battery comparison. Measured like-for-like, the engine was *faster*.
- **Always name the entry point being measured.** Several columns were measuring
  the carried parser rather than the engine (the `RRmax` ladder column in
  particular).
- **A count of cells is not a measure of time.**
- **Warm the JIT before timing individual cases.** A cold run put one case in the
  slowest 20 at 11.3 ms with only 1,493 expansions — 17x the median's time per
  expansion, and it looked like a real anomaly contradicting the cost model. Warm,
  it is 2.4 ms and not in the list at all. **The aggregate was unaffected** (2,606
  ms cold vs 2,581 warm); only the *per-case tail* was fiction.
- **A metric no engine can saturate is partly measuring its own construction, so
  price the best possible answer before you trust the column.** Build the best
  skeleton the rules permit and score *that*. Run it on every column of a new
  evaluator *before* the evaluator ranks anything. Doing it once here turned the
  weakest-looking category into an almost-solved one and moved every aggregate in
  the table by about **+0.05** (§3.2).
- **The battery contains duplicate strings** — deleting either of two identical
  adjacent characters yields the same mutant — so `battery.indexOf(s)` labels the
  second occurrence with the first one's edit. Carry the mutation record
  alongside the string; never look it up by value.
- **Dart resolves a relative path against the process CWD**, and the run pattern
  fixes that at `dart/`, not at the script's directory. `'../../x.md'` wrote
  outside the repository entirely.
- **A "regression" reported by a ladder can be a 6x-overstated artifact.** One
  RRmax regression was exactly that.
- **Timings are only comparable within an adjacent engine/`dup` pair.** A single
  process warms as it runs. Measured directly: **the *same* m26 scored 377 and 314
  `battms` depending on where it sat in the registry.** A cross-era timing
  comparison is invalid unless a `dup` row bridges it. (A `dup` is not an engine —
  it is an earlier engine re-registered *last* in the same process, so the pair can
  be compared without the warming bias.)
- **One strong column is not a reason to keep an engine. Check domination on every
  axis, and compute it — do not read it off the table.** This rule cost two wrong
  recommendations in a single occasion, both of the same shape. m78 was put forward
  because its 68.4 perfect% was the only number above the plateau; m132 beats it on
  score, perfect%, latency *and* size simultaneously. Then a frontier built by eye
  placed m112 and m121 on it; r9 dominates both — it is smaller than either, and
  nobody had compared 536 against 578. **Both errors survived exactly as long as the
  comparison was done by looking.** A twenty-line script over the four columns
  found them immediately, and cut a hand-built "worth considering" list from a
  vaguely-bounded set to eight engines of 52. Where the axes are all recorded,
  domination is arithmetic; treating it as judgment is how a superseded engine keeps
  its reputation.
- **State the tie tolerance before ranking, or the frontier is fiction.** 0.0001 of
  AST-diff score is 0.18 of one case out of 1,824, and the `ms` column carries ~7%
  spread — so three engines join or leave the frontier depending only on which
  decimal place is trusted. Rank with the tolerance stated and the borderline
  members named (Appendix), not with raw floats.

**Three era-1 columns are not what their names say**, and each one misled a
decision before it was pinned down:

1. **`eleg` is a judgment, by its own legend** — mechanism count, derived-vs-chosen
   constants, adopted-vs-invented machinery, compactness, "can it be stated in one
   true sentence". It is not data and **must not be averaged with the columns that
   are.**
2. **`latms` is a K-axis metric wearing a latency costume.** The 12 cases cost
   `2,2,1,1,2,4,2,2,10,1,1,0`, and **case 8 alone — the 64-char shuffle, cost 10, 11
   deepening rounds — is 308.6 ms of m53's 341.1 ms, 90% of the column.** So `latms`
   mostly measures behaviour at *large repair cost*, not on a *large document*; on
   the battery, where damage costs 1–2, m53 is within 14% of the descent engines.
   **Any "engine X is 1.7x slower" claim resting on `latms` is an argument about the
   ladder, not about the per-step constant** — which matters directly to §7's open
   latency item.
3. **`RRmax` overstates and moves** — a ~6x-overstated ladder artifact that depends
   on registry position, not only on the engine. Bisect, do not ladder.

## 3.7 Complexity, measured

- Recovery is **O(K·|G|·n³)** in the general form; measured exponents on real
  workloads are lower.
- **Latency is quadratic in n for a fixed single error**: 13 / 32 / 129 / 565 /
  2467 ms at n = 256 / 512 / 1024 / 2048 / 4096 (~4.3x per doubling). Clean input
  stays flat (0.2–1.5 ms at every size) because cost-0 subtrees are O(1). Cost
  tracks *damage × document length*, not damage alone.
- **The hard limit is recursion depth, and RIGHT recursion is the binding
  constraint.** Every engine dies with `StackOverflowError` on a *right*-recursive
  grammar at n=2048 while surviving left recursion to n≈4096. This is the opposite
  of the intuition and it is **inherited from the core, not introduced by
  recovery**: the pure parser shows the same asymmetry (clean right-recursive
  input overflows at n=8191; clean left-recursive input survives n=16383). Left
  recursion is expanded *iteratively* by the memo fixed point, so it costs memo
  entries; right recursion nests one native frame per character, so it costs
  stack. Recovery worsens the threshold ~4x because its descent adds frames per
  position. The fix, if wanted, is an explicit worklist in place of native
  recursion; it costs lines and is not built.

---

# PART IV — THE ENGINE LINE

Roughly 160 engines were built. What follows is one paragraph per turning point,
not one per engine. The full per-engine table with every intermediate row is in
the git history (`old L934–L2298` for m1–m40, `old L4780` for m50–m70).

## 4.1 m1–m40 — the dot era, and the objective that was wrong

The first generation modelled recovery as a machine over "dot" states: one table
`_arcs(c, dot)` where `Seq` is a chain, `First` is parallel arcs from dot 0,
`Optional` is one arc plus accept, `Repetition` is a self-loop. The *path through
the machine is the child list*, so one descent reconstructs all four types, and
both per-clause-type switches — search **and** reconstruction — disappear.

**The load-bearing performance insight of that era: the state index is its own
topological order.** `dot*width + (p − pos)` strictly increases along every arc,
so a single ascending sweep over a dense `Int64List` finalizes each state on one
expansion. No queue, no priority structure, no fixpoint iteration, no round cap,
no no-progress guard. (The array holds `Δ+1` so the native zero-fill means
"unset" — worth ~6% over a `List<int?>`.)

**Five axioms were extracted, and each deletes a category of code:**

- **A1 — A repair is a string in the language plus an alignment.** Three edit
  primitives lifted from Levenshtein: **SUB** (a terminal consumes a character it
  does not accept), **FAB** (a terminal consumes nothing — an insertion into the
  input), **SKIP** (a character consumed by no terminal — a deletion), each cost
  1, plus **MATCH** at cost 0. Consequence: min-cost repair = Levenshtein distance
  from the input to the nearest member of L(G) — independently checkable, and
  that is what `bf_check` checks.
- **A1 also makes SKIP a unit edge.** A j-character span costs `j·M + 2·Σh` which
  is exactly `Σ_{i<j}(M + 2h(p+i))` — perfectly additive — so a span is j
  traversals of a *unit self-loop on the dot*. Deleting the span loop is a
  **complexity reduction, not a micro-optimisation**: the j-loop re-enumerated
  every span length from every state, whereas unit edges let the memo share the
  skip prefix. Measured: SCRAM-64 halved, 487 ms → 251 ms.
- **A2 — Among min-cost repairs, prefer the least unjustified information.**
  `regret = Σ_kept w(class) + 2·Σ_skipped h(char)`.
- **A3 — Order by one integer.** `Δ = cost·M + regret` with `M` above any
  achievable regret, so min-Δ-per-end *is* min-cost, and **the budget is a filter
  on that integer, not a memo key** — one memo serves every iterative-deepening
  round. `b == 0` is then exactly one memoized pure-parser oracle call, so clean
  subtrees are O(1). This is why the method is fast on nearly-correct input.
- **A4 — Only a sequence has a "between".** A gap is by definition text *between*
  two consumed regions; the region separating two adjacent consuming leaves
  attaches at their lowest common ancestor, which is always a `Seq` or a
  `Repetition` — a `First` has no two consecutive children. So every gap has a
  **unique canonical attachment point**, and `First`/`Optional`/`Ref`/predicates
  need no recovery logic whatsoever. **The recursion is the dot.**
- **A5 — Left recursion is not a recovery problem; the parser already solved it.**
  Recovery is *the same recurrence over a wider value* — a map from end position
  to minimum Δ instead of a single match — so it inherits left recursion by
  adopting `MemoEntry`'s rule **verbatim, field for field**. There is no second
  mechanism and no recovery-specific reasoning about cycles anywhere.

**The factor 2 in A2 is derived, not a knob.** Two regret formulations are the
same objective up to an additive constant: deviation form `Σ_K (w − h) + Σ_D h`,
absolute form `Σ_K w + 2·Σ_D h`, difference `Σ_all h` — a constant independent of
the split. Charging `w` instead of `w − h` pre-charges every character one `h`, so
a discarded character must pay its `h` twice. Empirically confirmed on all 519
inputs: 0 cost disagreements, 0 regret disagreements. Removing the 2 while keeping
absolute width costs 9 shape points (517 → 508) — what a genuinely mis-set
constant looks like.

**The largest bug in the project was found here.** Non-minimal repairs on
left-recursive grammars, in every engine up to m22: the memo's reentrancy guard
cached the in-progress placeholder as a final answer, so the left-recursive
alternative contributed *nothing*. Serious for three reasons: (i) left recursion
is the parser's headline feature; (ii) clean input hid it completely, because `b
== 0` routes to one pure-parser call and *the parser is correct* — only the
engine's own recursion at `b ≥ 1` was broken; (iii) **the entire 519-mutant
battery was structurally unable to see it**, because the JSON grammar is not
left-recursive. At n ≥ 512 the pre-A5 engines return `-1, no repair found` —
total failure at scale, not mild suboptimality. **Fixed by A5 in m23**, and the
Ref re-entry guard fixed the related `null` at m24.

**The shipped `dot` is not affected, and "every engine up to m22" means the
sd/m line only.** `dot` scores 44/44 on the brute-force truth column, like m23
onward and unlike every sd/m engine before m23. A tag asserting otherwise was
once written from this narrative and removed when the measurement contradicted
it. The bug was introduced *after* `dot` and lived exactly from sd3 to m22.

**Re-confirmed in 2026-08 on the other battery, by a different instrument.** The
era-2 AST-diff battery has a left-recursive corpus (`astdiff.dart:228` —
`Expr <- Expr WS AddOp WS Term / Term`), which is precisely what the 519-mutant
JSON battery lacked, so it can see this bug where the era-1 gate could not. Run
cold over that battery, the engine either returns `null`/throws or it does not,
and the boundary lands in exactly the same place:

| engine | dot | sd3 | sd5 | v6 | m12 | m15/16 | m17–m21 | m22 | **m23 →** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| crashed cases (of 1,824) | **0** | 4 | 90 | 55 | 113 | 66 | 61 | 63 | **0** |

Two independent gates, over different corpora and scoring by different rules,
both put `dot` clean, sd3–m22 broken, and m23 onward clean.

**Split by corpus, the bug is perfectly contained and the aggregate is a lie.**
`_crashwho.dart` attributes each case, and **all 63 of m22's crashes are in
`expr`; none in `json`, none in `stmt`**:

| mean score by corpus | `dot` | m22 | m23 |
|---|---:|---:|---:|
| json (896 weighted cases) | 0.9633 | 0.9632 | 0.9637 |
| stmt (676) | 0.9630 | 0.9629 | 0.9629 |
| **expr (252, left-recursive)** | **0.9038** | **0.4766** | **0.9037** |
| expr, *non-crashed cases only* | 0.9038 | **0.6355** | 0.9037 |

Three things follow, all measured rather than argued. **(i)** Outside the
left-recursive corpus m22 and m23 are the same engine to within 5e-4 — the
whole 0.8959 → 0.9551 step is `expr` and nothing else. **(ii)** `dot` at 0.9038
and m23 at 0.9037 agree to 1e-4, which is the "`dot` is not LR-broken" claim
restated as a number. **(iii)** The last row is the important one: **restricting
to cases that returned a tree at all, m22 still scores 0.6355 against 0.9037.**
So the crashes are not the whole damage — the milder form, non-minimal repairs
at cost 2–3 where truth is 1, is real and costs another 0.27 on that corpus.
"Total failure at scale" understates it: below the scale where the engine gives
up outright, it quietly answers worse, and only a left-recursive corpus can see
either half.

**Two smaller results worth keeping.** *Witness tie-break: prefer the shortest
head.* Among Δ-tied decompositions, take the smallest head end. Worth +6 shape
points (511 → 517), and it is **not expressible in a backward predecessor walk**,
which fixes the tail first and caps at 516 — the reason reconstruction is a
forward descent. And the `threshold` identity: `_cost(total) > b` ⟺ `total ≥
(b+1)·M` (valid because regret < M), which hoists an integer division out of the
hottest line.

**And the framing that was wrong the whole era: every engine repairs toward the
CFG, not the PEG.** The objective ignored PEG's ordered choice and possessive
repetition. That is what the entire second half of the project is about.

## 4.2 m41–m49 — recovery is the parser over a wider value, plus three insertions

The reframing that made the engine small. Every earlier engine was described as a
recovery algorithm that borrows from the parser; **m41 is described the other way
round**, and the description is the reason it is smaller:

- **I1 THE VALUE.** A match becomes "the cheapest repair to each end position"; a
  mismatch becomes the empty set. The parser's fixed-point test — *the match did
  not get longer* — becomes *no end is new and no price is lower*. **Every other
  line of `MemoEntry` is copied verbatim.**
- **I2 A TERMINAL MAY LIE.** One that does not match may consume a character
  anyway (SUB) or consume nothing (FAB). Price 1 each.
- **I3 A SEQUENCE MAY DISCARD.** Before any element, one character may be consumed
  by no terminal (SKIP, price 1) and the element retried.

**Currying is what makes I3 free — the dot was a symptom, not a mechanism.** I3
needs a memo entry per element boundary; the parser memoizes whole clauses. Every
engine from `dot` to m40 bought that with an explicit dot (`_memoBase`,
`_nextDot`, `_hasElement`, `_canFinish`, `_elementAt`, `_alternatives`, per-clause
dot arithmetic). **Curry the sequence into binary `Cons(head, tail)` cells and
every element boundary already IS a clause**, so the memo key goes back to the
parser's own `(clause, position)` and all of that machinery is deleted.

**Deletion is not a primitive and needs no rule of its own** — it is I2's SUB
composed with the sequence's structure (m42: *there is no third edit*).

Then four more, each deleting a concept:

- **m43 / I (the oracle window)**: the oracle is authoritative as far as the
  edit-free window reaches.
- **m44**: the deepening ceiling is *derived*, deleting the last tuning parameter.
- **m45 / I4**: a reader owns the characters it decides, and a lookahead decides
  none — `&C T` ≡ `C∩T` fusion. Measured worth keeping: deleting it costs
  1.21–1.64x steps on PRED grammars **and changes 4 witness shapes**, so it is not
  purely an optimisation.
- **m46 / I5**: the witness is a proof, so check it. 42 lines: `_emit` walks the
  witness once and re-parses it with the pure parser. 519/519 JSON, 36/45
  predicate, 0 disagreements, +7% battery.
- **m47–m49 / I6, I7**: an obligation is part of the value. A lookahead is a
  constraint on the next character EMITTED (I6), and the constraint travels back
  out inside the value (I7). *Later measured inert on every real input* and
  deleted by I24.

## 4.3 m50–m70 — the relocation series

The most productive stretch, and it has a single shape: **each step takes
something implicit and relocates it into a structure that already exists.** Stated
as a table, because the pattern also predicts where the next step is:

| insight | what was implicit | what it became |
|---|---|---|
| I8 (m50) | the deepening loop, the LR fixed point and the RR native stack — three schedules | one worklist over cells |
| I9 (m51) | the value, rebuilt per relaxation | a cell written into; the fixed-point test IS the write |
| I11 (m52/m53) | a dependency, as an address to hash | an edge of the grammar; the reverse edge is its transpose |
| I14 (m57) | the deepening ladder, the budget, the ceiling | Δ, the total repair price, IS the schedule |
| I16 (m60) | the continuation, on the native stack | a memo field |
| I18 (m62) | the pass in flight, inside the memo entry | an explicit frame; the entry keeps only facts |
| I19 (m64) | the suffix, re-derived after an edit | the invariant; the edit only moves the origin |
| I20/I21 (m63/m65) | membership, deadness and the useful alphabet | one probed parse; the layer is the answer |
| I22 (m66) | the relation between the fast answer and the truth | a verified witness: a certificate of equality |
| I23 (m67) | the router, as a seam between two engines | one class over one substrate |
| I24 (m68) | the obligation lattice, doing predicate bookkeeping | deleted; under a certificate the fast engine need only be a floor |
| I25 (m69) | the proposal alphabet, one representative per terminal | the Boolean interval partition of the code-unit line |
| I26 (m70) | the reconstruction, as a separate descent | a pass too — I18 applied one level out |

**I8 removed the right-recursion stack ceiling for the whole line** by replacing
native recursion with a worklist. **I22 is the load-bearing idea for everything
after it**: the CFG-union reading accepts a superset of the true PEG language, so
the relaxed cost is a floor on the true cost for *every* input; when the relaxed
witness survives I5 verification, the squeeze closes (`trueCost ≤ d(s, witness) =
c62 ≤ trueCost`) and the witness in hand is a legitimate minimum-cost true repair.
The relaxation's one failure mode — repairing toward a parse the committed grammar
would never take — is precisely the case its own verification detects.

**The era's engine table** (all rows 517/519 shape except m65 at 514, all 519/519
cover, 0 crashes, 7/7 valid, 44/44 cost, 44/44 tree, 69/69 `pred`):

| engine | LOC | conf | isect | battms | latms | /v6 | LRmax | RRmax | verdict |
|---|---|---|---|---|---|---|---|---|---|
| m70 | 1331 | 5/5 | 4/4 | 477 | 220.6 | 0.46x | ≥4096 | 2048* | only engine with true-PEG conformance AND ≥4096 LR; largest file in the study |
| m62 | 789 | 3/5 | 4/4 | 400 | 208.1 | 0.45x | ≥4096 | ≥4096 | best size/speed/depth anywhere; **answers the CFG reading** of possessive `*` and committed `/` |
| m64 | 913 | 3/5 | 4/4 | 379 | 195.1 | 0.42x | ≥4096 | ≥4096 | fastest latency; +124 LOC over m62 for no measured gain |
| m60 | 778 | 3/5 | 4/4 | 358 | 196.7 | 0.42x | ≥4096 | ≥4096 | m62 is the same engine said properly, for 11 lines |
| m69 | 1156 | 5/5 | 4/4 | 475 | 230.0 | 0.49x | 1024 | 2048 | I25, the interval alphabet |
| m68 | 1134 | 5/5 | **1/4** | 391 | 219.1 | 0.47x | 1024 | 2048 | smallest conformant; loses every intersection |
| m67 | 1204 | 5/5 | 4/4 | 408 | 234.9 | 0.50x | 1024 | 2048 | I23 dissolves the router seam |
| m66 | 1307 | 5/5 | 4/4 | 397 | 238.6 | 0.51x | 1024 | 2048 | I22, the certificate |
| m53 | 755 | 3/5 | 4/4 | 405 | 335.9 | 0.72x | ≥4096 | ≥4096 | completes I11 by deleting I10 |
| m57 | 858 | 3/5 | 4/4 | 1154 | 308.0 | 0.66x | ≥4096 | ≥4096 | best insight, worst battery of any healthy engine |
| m50 | 716 | 3/5 | 4/4 | 636 | 772.7 | 1.66x | ≥4096 | ≥4096 | smallest engine in the study; source of I8; slower than the baseline it replaces |
| m65 | 1251 | 5/5 | **1/4** | 7425 | SLOW | — | 2048 | 2048 | origin of the tape and I21; not viable — 18.5x m62's battery |

**There is no single winner**, which is what the brief anticipated: m62 owns size,
speed and the ladders; m66–m69 own conformance; m68 owns the routing rule; m69
owns the alphabet; **and none of them owned the reconstruction** — which is what
I26 then fixed.

## 4.4 m71–m78 — the witness era, and the disqualification

The line that scored highest and was then **disqualified in full** by D1.

- **m71 / I27, I28**: conformance without a tape. A greedy construct is a
  commitment, and so is every branch after the first (I27); a proof is worth more
  than a tighter search (I28). 5/5 conformance at 1028 LOC.
- **m72 / I29, I30**: the write knows its own reason, and a reason recorded at a
  strict improvement cannot close a cycle (I29). **When the comparison refuses a
  tie, the enumeration order IS the tie-break rule** (I30) — a D2 problem stated
  precisely.
- **m73**: m62 verbatim plus the two insights and nothing else. The control that
  showed the battery gap was never in the search — it is the certificate, and the
  certificate was checking the wrong thing.
- **m74 / I31**: the repaired string is the witness, and its parse is the tree.
- **m75 / I32**: **the repair is scaffolding; the tree is over the input.**
  `_tree75.dart` machine-checks it. m75 wins **both** acceptance cases where m74
  wins one.
- **m77 / I33**: destruction is the widest description. Charge every input
  character the width of the class that gave it a role (`log2|C|` bits), and a
  character that got no role the widest any class can be — so **destruction stops
  being a separate axis and becomes the extreme case of description; an axis is
  deleted rather than added**. Ranked #1 on the table.
- **m78 / I34**: an obligation you cannot write down constrains nothing.

**Then D1 landed and m74–m78 were disqualified wholesale.** They apply edits, hand
the repaired string to the pure parser, and re-index the tree back onto the input.
That is the wrong shape twice over — it modifies the input *and* launches a second
parse — and the two are the same defect, because the second parse exists only to
interpret the modified input.

**The lesson that outlived them**, from the D-C exhibit: on
`{"a":1,"bc":2[,33,true],...}` m75 inserts **two quotes** and reads `2[,33,true]`
as a JSON `String` at cost 2, regret 0, verified true. Invention is 0 because a
quote is a singleton class; loss is 0 because nothing was destroyed. **(0, 0) is
the best score the secondary key can give**, so this is not the tie-break failing
to prevent the reading — it is the tie-break *preferring* it. Eleven characters
with tight structural roles become string content: the exact opposite of "fix the
shape of recursive descent". That exhibit is why I33 exists, and why the
whole-document swallow keeps reappearing as a failure mode.

**I31, I32 and I33 are all still live** — they were carried into the post-D1 line.
m75 and m77 are not.

## 4.5 m79–m132 — the tree era

Recovery as a claim about the tree (I35), with the search over "ways" — Pareto
lists of readings per cell.

**I35 and I36 are the frame:** a repair is a claim about the tree, not an edit to
the evidence (I35); **synthesis is legal exactly when the witness is unique**
(I36) — which is D7 stated as a rule the engine can check, and it is why a brace
may be filled and a digit may not.

**Eight insights make it affordable and correct:**

| # | Insight | What it decides |
|---|---|---|
| I37 | THE BUDGET IS A PRUNE, NOT PART OF THE KEY | Iterative deepening without fragmenting the memo |
| I38 | THE CONTINUATION NEED NOT BE PUSHED DOWN IF THE ENDINGS ARE PULLED UP | Every clause returns **all** reachable endings, so a sequence is a fold and no continuation is threaded |
| I39 | A PEG DECISION COMMITS TO A CHOICE, NOT TO AN ENDING | The pure table decides *which* alternative; that alternative is re-run at full budget |
| I41 | POSSESSIVENESS IS HOW PEG RESOLVES A REPETITION WHEN NOTHING IS BROKEN | Collapse a repetition possessively **at budget 0 only**; above 0 the parse has already failed and possessiveness has no authority over a reading it never produced |
| I43 | A REPAIR MAY NOT MAKE THE CHOICE | An alternative reached only *because* a repair was spent is not the alternative PEG would have taken. **This is what keeps round 0 exactly the frozen parser** |
| I46 | A LEADING SKIP ALSO MAKES THE CHOICE, AND IS REDUNDANT | The corollary of I43 that closes the obvious hole in it |
| I47 | THE ANSWER IS A LIST, NOT A MAP | The endings of a clause at a position are a short ordered list; a `Map<int,_Way>` prices a hash for a handful of entries |
| I48 | A TERMINAL IS NOT WORTH A MEMO CELL | Re-deriving a character-class match is cheaper than the cell that would remember it |

And **A4 upgraded from assumed to proved: a lookahead reads the ORIGINAL input at
cost 0.** A lookahead is a predicate over the evidence; the evidence is never
modified (I35), so there is nothing for a repair to change under it. Under D3 the
predicate body is deterministic, so this is exact and not an approximation.

**I50 — the memo table blocked itself, exactly as D6 said it would.** This is the
brief's own sentence arrived at from the other direction, and it is the reason the
occasion leads with the quote rather than with the engine.

**The objective, refined over ~15 occasions:**

- **I44 — the objective is unexplained characters, and a terminal that constrains
  nothing explains nothing.** `.` matches any character and therefore constrains
  nothing, so a `.` match adds nothing to `net`: a grammar that can absorb
  arbitrary text through `.` must not be paid for doing so.
- **I51 — reaching a later alternative claims the earlier ones failed, and failing
  on the evidence is not failing.**
- **I52 — a fill is measured in characters, not clauses.**
- **I53 — a repair may make the choice only when nothing else can.**
- **I54 — a guess is a cost you cannot see.** Later absorbed: I54 is I72 with the
  fee set to infinity.
- **I61 — cost says how much you doubted, it cannot say when.**
- **I62 — a fill you cannot spell is a wider claim than one you can.**
- **I64/I65 — where the doubt ends; the damage has a width, and that is what
  locality meant.**
- **I68 — a fill of no characters is not a repair.** 31 engines (m79–m111) all
  paid for pretending otherwise. This is a free pass they all shared.
- **I69 — the only prefix-optimal shadow of "the damage is confined" is `doubt
  ↑`.** Every other confinement measure collapses back to `doubt`.
- **I72 — a repair pays for inventing only where the input offered something to
  read instead.** The unification: I54 is I72 with the fee at infinity, I70 is I72
  with the fee at zero. Closes the D-C exhibit at **zero cost on every scored
  column**.
- **I76/I78 — I43's evidence test belongs at the ENDING, not at the alternative
  (I76); invention may COMPLETE a shape the input witnesses, it may not CONJURE
  one (I78).**

**Search-engineering insights of the era:** I55 (the search does not need the
tree), I56 (a way that is already new does not need to be copied), I57 (a tie the
engine cannot break is broken by the linked list — a *stated* D2 violation, later
fixed), I58 (a free way is already the proof, so do not go and fetch it), I59 (a
cell that never consulted the cap cannot change when it rises), I60 (a repetition
only moves forward, so position order IS topological order), I73 (the fold already
knows the answer cannot cost anything), I74 (the memo belongs to the budget, not
to the round), I75 (round the residual to the ladder that is already there).

**Two failure modes found by controls, not by the score:**

1. **`_Way.synth` records only how a way OPENS**, so any rule gated on it is blind
   to invention made INSIDE a way — and the swallows that matter are exactly
   those.
2. **The battery rewarded an engine for deleting input it had no reason to
   delete** (occasion 57). I77 (*an unexplained character costs what a deleted one
   costs*) scored *higher* and was **withdrawn anyway**; `_freespan.dart` is the
   control that proves why. m132 is the engine that resulted.

## 4.6 m133–m143 — the two-mode refutation, and the standing `m`-engine

**m143 is the standing `m`-engine: 0.9693 / 72.1% / 1,171 ms / 628 LOC.** It is
also the first engine to make D1 free — it dominates both re-parsing engines,
m75 and m77, on all four scored axes (Appendix). **It does not pass the whole gate
set**: `_recommit` is 15/16, an open defect inherited from m127 (§3.3, Part VII
item 13).

The requested two-mode architecture (steer #8) was built faithfully as **m141**:
m132 with the memo replaced by a real chart — every clause node × every position,
relaxed to a within-position fixpoint right-to-left, per budget. That is the
bottom-up dual of packrat, i.e. Pika parsing. It is a faithful build and that is
*measured*, not asserted: m141 passes acceptance, passes free-span, and reads the
same conformance row as m132 with identical costs on all six probes. **It is not
slower because it is broken.** It lost by **17.8x**.

**m145** then separated the two changes the first table had confounded: holding
I81 constant, adding the chart **costs** 0.0025 AST-diff and 1.5 perfect points at
18x the latency. So the chart's extra reach is negative **at zero latency**, not
merely unprofitable at 18x. **m144** is a probe that asks the same question from
the other side — m143 plus a seeded right-to-left re-relaxation of exactly the
cells the top-down pass demanded.

**The refutation is structural, and this is the sharpest thing the project
produced about the objective:**

> **Cost-minimality is not human intent.** No human reads `[1,[2,` as a broken
> string. A recovery that searches the whole input for the globally cheapest
> reading will eventually find one that throws away structure the input already
> established, and the cheaper it gets the worse it reads. Local commitment is not
> an approximation of global search that we tolerate for speed — on this workload
> it is the more correct objective.

The chart is unbiased and global, and is punished precisely for that.

**I82 — a guard on the descent cannot bind a chart.** This is the key structural
constraint, and it is why the `r` design honours it *by construction*: every
recovery decision is taken during a descent, from a frontier node discovered by
traversing the partial AST, so PEG priority and the descent-phrased guards remain
enforceable. Nothing materialises a cell whose derivation is unknown.

**I79 and I80 were both refuted; I81 is the engine.** I80 (*a node that explains
no character and asserts none is not a node*) was refuted, and I81 is its
survivable form: **drop a hollow node only where no evidence could ever have
reached it.**

## 4.7 r1–r9 — the `r` series, and the standing engine

The brief's five stages, built and then progressively re-derived. **r9 is the
standing `r`-engine and the best engine in the project: 0.9748 / 74.0% / 536 LOC.**

All rows below were **re-measured in one session** against the current `dart/lib`,
with `astdiff.dart` and `final_table.dart` confirmed byte-identical to the
revisions the original numbers were taken at. Three rows had drifted from what was
previously recorded here (r3 0.9588 → 0.9642, r4 perfect 73.6 → 73.2, r9 0.9721 →
0.9748) and the measured values are the ones kept.

| engine | score | perfect% | ms | LOC | what it added |
|---|---:|---:|---:|---:|---|
| r1 | 0.8018 | 23.3 | 647 | 410 | pure parser + frontier widening |
| r2 | 0.8822 | 46.3 | 2,037 | 454 | the fill |
| r3 | 0.9642 | 71.2 | 2,510 | — | the cell holds every reading; the frontier disappears |
| r4 | 0.9683 | 73.2 | 2,575 | 476 | `_Way.fix`; a repair may not buy a reading the input never offered |
| r5 | 0.9683 | 73.6 | 2,288 | 483 | the merged key: `peg` and `fix` were never two questions |
| r6 | 0.9683 | 73.6 | 1,666 | 520 | — (round 0 was building a chart it could not spend) |
| r7 | 0.8970 | 51.4 | 6,959 | 492 | re-derived frontier, cold re-parse per candidate |
| r8 | 0.9711 | 73.2 | 1,638 | 530 | one mark not `fill` |
| **r9** | **0.9748** | **74.0** | **2,038** | **536** | the whole-document swallow, priced twice |

**The 0.9721 → 0.9748 step was NOT the 2026-08 core change, and an earlier note
here said it was.** That note claimed the score moved "because r9 imports the
library parser and the left-recursive seed fix reached it". A controlled
comparison refutes it. Holding the scorer and battery pinned, r9 reads **0.9748 /
74.0** in every measurable cell:

| | old lib (`1c88415`) | new lib (`HEAD`) |
|---|---|---|
| **old r9** | 0.9748 / 74.0 / 2,025 ms | not a valid build — see below |
| **new r9** | 0.9748 / 74.0 / 2,026 ms | 0.9748 / 74.0 / 2,056 ms |

The core change moves r9 by **zero**. The +0.0027 came from `1c88415` itself,
which rewrote 144 lines of `r9.dart`. The fourth cell does not exist as a correct
configuration: old r9 tested `m.len >= 0` for "did it match", which was only sound
while a mismatch carried `len == -1`, so on the new lib it would read `fun` as a
match of `"function"`. The seven-line repair to `!m.isMismatch` ships *inside*
commit `46bd136` for exactly that reason (§2.5).

**The same control run across the whole series**: r1–r8, m132 and m143 each score
bit-identically on both libs. **No recovery engine's accuracy moved at all.**

**What each step actually taught:**

- **r1**: the brief's own `First` rule beat the heuristic I invented for it. I had
  ranked `First` arms by how much each could salvage and walked only the best; the
  brief says walk them all. The brief's rule is better on every axis at once
  (0.8018 vs worse, 23.3 vs worse, fewer ms, fewer lines). **When the brief
  specifies a rule, use it** — D2 forbids arbitrary heuristics and a specified
  rule is not one.
- **r1**: **the brief's `Seq` rule is unsound**, and a control measures it. The
  brief says add ALL mismatching subclauses after the last matching one. A `Seq`
  slot that has not been reached has no evidence behind it.
- **r2**: both honesty guards (`_invents`, the `held` fill guard) score *higher*
  when ablated — and both are kept, because the score is not the constraint. The
  `held` guard ablation fails 4 acceptance cases outright.
- **r3**: 78 fill sites all resolving to `Name`, 0 wrong — the cell holding every
  reading is what makes the frontier list unnecessary.
- **r4 / I72-analogue**: `_Way.fix` plus levers `f` and `H`. The **inert-field
  control** is what makes attribution trustworthy: add a field that cannot
  possibly change behaviour, confirm the score does not move, *then* believe the
  fields that do.
- **r5 / I83–I87**: the merged key makes conformance one line. **"Budget 0 IS the
  frozen parser" was FALSE and is now true.** −10.5% latency; invariants total over
  5.68M ways. I84 (what is left is a monoid, and repairs are elements of it), I85
  (a claim nothing refuses is not a claim), I86 (a ceiling that cannot be reached
  is not a ceiling), I87 (a clause that cannot call itself needs no cell).
- **r6**: 94% of the trees were never looked at.
- **r7/r8 / I88, I89**: **the brief's two OPERATIONS were right and its
  ARCHITECTURE was the ceiling.** I88 — a way says what its node WOULD be, not
  what it is. I89 — the first round is the frozen parser, so it should hand out
  what a frozen parser's memo entry holds.
- **r7 refuted the brief's own stopping rule.** The brief says *"the FIRST time
  you find a new match…, stop iteratively expanding."* Measured: it costs, and the
  loop already has a sound alternative — score every candidate and commit the
  best. The brief's rule is a heuristic where a principled rule exists (D2).
- **r9 / I90–I92**: **the budget buys the round, the ranking keeps the rival.** The
  whole-document swallow needed *two* prices doing different jobs: one the
  deepening budget can see, one the pruning can see (`_Way.toll`). A price the
  pruning cannot see is not a price. **"Reachability" as the cause was refuted** —
  the swallow was losing inside `_prune`. I92: an obligation and a trailing
  discard are two claims about one position.
- **r9's `resync` IS the engine.** Deep input deletion — the brief's own "skipping
  input characters" — is `resync` under a filter.

**I90/I91, which is where #18 lands:** *denying input and giving up grammar are
the same skip at two depths*, so *a production may give up one slot and carry on*.
The brief predicted exactly this shape: *"the first case is deletion of input
characters, the second case is deletion of grammar clauses."*

## 4.8 r10–r13 — the brief's architecture on an exact frontier, and the answer to #18

r10 exists to answer one question the owner asked directly: **does an exact
frontier make the brief's iterative widening work?** It requires one core change
(`matchSub`) because the brief says to memoize a match of C at position p+l and
memoization is at RULE granularity.

**These four are the only engines that have ever run on an exact frontier**, and
they run on `_core2.dart` — the prototype of the richer mismatch node (§2.5),
which the shipped library later took half of. They test the *brief's* architecture
on it, not the best architecture for it; see the starred TODO at the head of
Part VII for what that leaves open.

| engine | score | perfect% | LOC | what it is |
|---|---:|---:|---:|---|
| r10 | 0.6440 | 9.7 | 176 | the brief taken literally: exact frontier, **deletion only**, first match wins |
| r11 | 0.3218 | 4.7 | ~200 | + the grammar side, chosen by depth, still first-match-wins — **refuted** |
| r12 | 0.8661 | 44.1 | 290 | + a scored commit instead of first-match-wins |
| **r13** | **0.9008** | **51.9** | **327** | + the shallow side of the frontier, + three cost fixes |
| r7 | 0.8970 | 51.4 | 492 | same architecture, re-derived frontier, cold re-parse per candidate |
| r9 | 0.9748 | 74.0 | 536 | chart + deepening budget — **still the standing engine** |

**The core asymmetry, which is one fact showing up twice.** r13 offers two
operations per frontier site:

- **give-up** (the grammar side) — offered when `_minFill(c) == l`, **no
  pre-filter possible**.
- **denial** (the input side) — gated by `matchSub(c, p+l)` succeeding and being
  non-zero-length.

A deletion is *self-selecting*: it counts only if a real match follows, so it can
be pre-filtered. A give-up *cannot fail*: it needs no input, so nothing can filter
it. That single asymmetry (a) breaks first-match-wins, which is why r11 collapses
to 0.32, and (b) makes the give-up side unfilterable, which is the entire latency
bill.

**`_minFill(c)`** is the least fixed point over the grammar of "cheapest way to
satisfy this clause with no input at all" — the price that makes both operations
comparable in one unit.

**r13's 4-key lexicographic cost** `(whole, del, gap + _owed, _owed)`:
derives-the-whole-input first, then characters denied, then obligations open, then
— at equal price — prefer the tree that has DECIDED more.

**Measured, per case (`_r13p.dart`, instrumented copy):**

| | per case |
|---|--:|
| widening rounds | 6.0 |
| `matchSub` pre-filter calls | 73.6 |
| …of which pass | 12.5% |
| trials — give-up | **119.3** |
| trials — denial | 9.2 |
| trials — total | 128.4 |

**93% of trials are give-ups, which have no pre-filter.** 62.8% of all trials are
redundant *by outcome* (147,034 of 234,292). Keyed on the pre-computable `(kind,
position, price)`, redundancy collapses to 59,282 groups = 25.3% of trials — but
only **62.9% of those groups are unanimous**. Collapsing anyway:

| | AST-diff | perfect % | ms | trials/case |
|---|--:|--:|--:|--:|
| r13 as shipped | **0.9008** | **51.9** | 7115 | 128.4 |
| + collapse give-ups | 0.8196 | 23.5 | 3140 | 51.0 |

**So: the candidate count is not the enumeration's cost, it is the enumeration's
information.** Halving the trials halves the time and costs 28 perfect points.

**The one unbuilt lever**: a parent link on frontier entries would let a give-up be
pre-filtered by "can the parent advance?". Ceiling ≈24 trials/case if it matched
the denial filter's 12.5% pass rate. Not built.

**Verdict on #18.** Yes, the two-sided reading unifies the model — I90/I91 are
exactly it, and r13 implements it directly. But it does **not** produce a simpler,
faster, conforming engine: r13 is 327 lines against r9's 536 on the brief's own
architecture, and it is 0.9008 against 0.9748 at 4x the latency, and it fails
acceptance case b2. **What r13 settles is that the brief's architecture, given an
exact frontier, is worth 0.90 and 327 lines** — and what it costs is the candidate
enumeration the architecture is built on. No amount of frontier precision removes
that; only not enumerating does, which is what r9 does.

## 4.9 The s1 engine — the residual read at last, and what it was worth

**s1 is the standing engine: 0.9841 / 77.0% perfect / 1,686 ms / 697 lines,
every gate green — the first engine above the r9+m143 ensemble ceiling.** It is
r9's architecture and ranking, changed in exactly four places, and every change
was found the same way: **itemize the imperfect cases and read them.** The
residual dump (`_res1.dart`-style, r9 vs m143 per case) took half an hour and
immediately yielded three failure classes nobody had named; no engine from m79
to r9 was designed from a case list. The ensemble number bounded the reachable
gain before any code was written: max(r9, m143) per case = 0.9805, so at least
+0.0057 was known to be engine-reachable, and s1 lands +0.0093.

**The principle the four changes share (I93–I97):** a failing parse already
writes the honest description of the damage into the mismatch tree — a `Str`
records how much of its literal the input supplied, a `Seq` records the slot
that broke, a `First` records every arm — and recovery's job is to **price that
description (I33) and never trade it for a cheaper reading that says less.**
Each change is one place r9 could not afford, or could not express, the
description the failure had already written down.

| change | class it fixes | mechanism | measured |
|---|---|---|---|
| **I94 — "the document stopped" is one claim** | short truncations: `{"a`, `if (`, both r9 and m143 at 0.500 | obligations at `input.length` charge the budget ONCE however many marks they stand for (`_Way.eof`); per-character charges made "keep the construct and owe its tail" lose to "close it empty and deny what the writer wrote" | truncate 0.954 → 0.986; truncations answer in round 1; ranking the mark count REFUTED both directions (0.9762 / 0.9760 vs 0.9770) |
| **I95 — a literal's interior can be denied** | damaged keywords: `fa"se`, `falzse`, `i,f`, `unll` | `_align` is a full three-op alignment (match / owe / deny) via one edit-distance table per failing `Str`; D7-safe because the literal is determined (I36/I78) | junk-insert 0.978 → 0.987, delim-insert → 0.986, transpose → 0.979; conformance signature unchanged |
| **I96 — an owed slot is still a place in the tree** | deleted constructs: `if ()`, `[1,[,` — m143 scored 1.000 here and r9 could not | a mid-document give-up emits the named spine the grammar FORCES: through Refs, `+` bodies, a Seq's single nonzero-fill slot, and a `First` only where a UNIQUE arm is cheapest (one step further is choosing — I36's line); withheld at end of input (I81) | literal-damage 0.957 → 0.977, multi-damage → 0.958; prices unchanged, so every ranking decision is r9's |
| **I97 — a span is judged once** | honest completions tolled to death: `{"alpha"` lost to deny-`{` | r9's swallow toll re-judged the same absorbed span at every Ref above it; `_Way.vouch` records absorption already accounted for — by a FREE subtree (the frozen parser's own reading) or by a toll below — and a cap judges only what is fresh | quote-delete back to 0.999, truncate 0.983 → 0.986; the swallow still tolls once, recommit 16/16 stands |

**And round 0 is the library.** `recover` first runs the frozen parser's own
`parse()`; a clean document is answered by the library's memo table and the
chart never opens (I89 by construction, and D1's "the CURRENT memo table"
satisfied literally). The chart's rounds start at 1 — round 0 finds nothing on
damaged input by definition — and `_prune`'s round-0 branch is deleted. On the
all-damaged battery this costs ~200 ms (the extra pure parse); on clean input,
which is what the per-parse latency goal is about, s1's latency IS the
library's.

**Refuted while building it, so nobody retries them (§6.2/§6.3):** budget
doubling on this chart (1.39x SLOWER — the accumulate-and-merge cells make unit
rounds cheap, unlike the m-line's budget-indexed tables, so "doubling is
fastest" does not transfer); the earliest-first-repair key flip (0.9799/73.7 —
r4's later-wins rule holds); I59's finality bit imported to the r-line (bought
2%, leaked a staleness bug through a missed cut site — the recomputation it
deletes was never the cost); deleting the markless stop (−0.0002 — with I96
emitting spine nodes, the stop is the only way left to say "it just ended").

### Attempt two: t1, the engine built AROUND the tree — and the verdict

**The starred TODO's engine was then actually built (t1, same session): one
squirrel core whose memo table IS the repair channel.** A repair is a fact
written at `(clause, pos)` — content-addressed exactly like `foundLeftRec` —
and retired by exactly the entries whose derivation read its position
(`readEnd`, the per-position version bump generalised to a span). Candidates
are read off the mismatch tree, never enumerated by position: deny (skip to
where the failing clause reads), owe (minFill, with I72's fee where a no-dearer
denial exists), align (I95), and retraction — cutting an already-matched
subtree at a point where the enclosing context resumes, the cut READ OFF the
match tree with no re-parse. The First-arm evidence gate — an arm whose
mismatch read nothing may not invent (I43/I78 as a tree property, I53 as its
fallback) — passes `_recommit`'s swallow probes with no toll, no net-vs-
absorption machinery and no whole-document charge: one structural rule where
the chart engines need three pricing mechanisms.

**Measured: 0.9326 / 57.7% / ~1,020 ms / 861 lines — every gate green
(recommit 16/16, conformance `0 1 1 0 2 3`, 0 free passes), the fastest engine
in the study, and the claim fails on both halves.** The first reading of that
result was I98 below; the corrected reading is I100 after it:

> **(I98, now SUPERSEDED in direction by I100.)** The mismatch tree as
> shipped does not hold what the chart re-derives: it keeps the FIRST failure
> of each committed reading, while recovery's information is every reading the
> parse REJECTED — the repetition that stopped, the arm that lost after
> reading further, the left-recursive pass the fixed point discarded, the
> optional that matched empty over a broken body. t1 had to rebuild each as a
> side map beside the node (`_stopped`, `_lost`, the salvage splice), and
> every point of score it gained came from recovering one more species:
> 0.825 blind → 0.912 with the rejected passes kept → 0.933 with the lost
> arms and splices.

**I100 — the reversal, and the unifying principle the whole line was circling.**
I98 read that species-by-species rebuild as "converging on the chart." It is
the opposite. **Every one of those rejected readings was computed BY THE ONE
FAILED PARSE and discarded on a combinator's success path — and the discard
sites are a closed, finite list: a `First` that succeeds drops its failed
prior arms; a repetition drops the iteration that stopped it; an optional
that matches empty drops its broken body; a predicate drops its body; the LR
fixed point drops its rejected final pass. Five sites. Keeping them is
`reach` — steer #10's unbuilt half — and t1's side maps ARE that port, not a
chart reconstruction.** The chart never held more than the parse computed: it
RE-derives the same rejections at every budget round (which is its latency
bill — s1 spends 1,686 ms re-deriving what t1 keeps from one parse in
1,020). And underneath sits the identity the six-times-repeated steer was
pointing at: **a mismatch and a left-recursion seed are the same object — a
suspended reading, addressed by `(clause, pos)` in the memo — and the memo
entry's grow-loop ("re-descend while the reading improves") is already the
whole recovery engine. Left recursion is recovery at cost zero: its repair is
the previous pass's own result, free. The chart is that loop's history
materialized eagerly; the tree is its address book; the parser already
contains the machine.**

**★ THE PIVOTAL INSIGHT OF THE RECOVERY LINE — OWNER-CONFIRMED.** I100
stopped being an interpretation and became STRUCTURE in s3 (below): **the LR
loop is the recovery loop verbatim — one grow-loop in one memo entry serves
left recursion and repair, and there is no second mechanism anywhere in the
engine.** The cell is the frozen parser's entry (ways / inPath / foundLR /
gen) plus one field, the budget; "re-descend while the reading improves" is
the whole of both jobs; and the collapse that followed (s3: 484 lines, r9
dominated on all four axes, the size cliff broken) is what the six-occasion
steer of §1.8 predicted that identity would buy. The owner's confirmation,
verbatim (2026-08-05):

> finally -- this is the biggest breakthrough you have made so far in the
> recovery algorithm

Every earlier reading of the steer implemented the signal and missed the
identity: A5 copied the memo's fields, m60 generalized the bit to all waits,
r3–r9 reused the loop per cell — each kept recovery as a second thing built
BESIDE left recursion. I100's content is that there was never a second
thing. §1.8's standing steer is answered by this insight and closed there.

**What the reversal does NOT yet deliver, measured honestly.** If t1's gap
were information, completing reach should close it; three schedule/gate ports
of the chart's local rules were then tried and ALL LOST in the iterated
architecture — a strict cheapest-first ladder (0.9258, cx2 broken; 0.9223
with the I36 gate), the I36 determined-gate on owes (0.9287), and r9's
give-up-only-where-nothing-reached exclusion (0.8997, b1 broken) — because
the whole-document trial already sees what those rules encode locally, and
suppressing candidates only removes information. What the chart still has
that the iterated form does not is **simultaneity of rivals**: readings whose
value appears only in pairs (a deny and an owe that must land together), and
trial scores contaminated by a second damage the round has not yet repaired.
That — not information — is the remaining 0.04, and it is the precise open
question for attempt three.

### s3 — the collapse: half the mechanism, and the cliff broken

**s3 is the pure core the six-times-repeated steer predicted: 0.9819 / 78.8%
perfect / ~1,800 ms / 484 normalised lines, every gate green — the first
engine in the project's history to DOMINATE r9 on all four axes at once
(nothing under 562 lines had ever exceeded 0.9551; s3 is +0.0268 above that
boundary at 78 lines below it), and the highest perfect% in the study.** It
is s2's cost model with the mechanism list collapsed, because everything the
engine used to special-case is generated by machinery it already had:

- **A fill is not a mechanism.** A failing terminal already returns its
  obligation as a way; the fold composes slot obligations; an ordered choice
  offers its cheapest arm by the rank it already has; a Ref cap names the
  spine. What kept the explicit give-up branch, its minFill pricing, the
  telescoped stop and the whole I96 spine builder alive in r9/s1/s2 was one
  refusal: `_lift` dropped zero-width ways. One added disjunct admits them,
  and one build-time rule replaces the spine machinery — a zero-width cap at
  the end of the input loses its NAME (I81), and keeps it mid-document (I96).
- **A literal is a sequence** (m41's currying, applied at last): a mismatched
  `Str` folds over its characters through the same slot fold as every Seq,
  and the 60-line alignment table (I95) emerges from it.
- **A move is a resync at slot zero.** One skip rule: where a slot cannot be
  read as it stands, deny up to the first place it reads freely. r4's
  must-fit-entire guard turned out to be subsumed by the judge and the fee —
  recommit stays 16/16 without it.
- **One memo entry.** ways / inPath / foundLR / gen — the frozen parser's
  fields — plus `at`, the budget, the single recovery-specific fact. The LR
  loop is the recovery loop, verbatim (I100).

Deleted outright against s2: `_align` (~60), the give-up branch and fee
plumbing scattered through `_seq` (~40, the fee now lives at one line in the
fold), the stop branch and `_owed` (~35), `_owedNode` (~45), the move probe
(~30), the `Repaired` class (~20, the library `Match` recomputes spans from
children marks included), the prune fast paths and constructor duplication.
What it concedes to s1: −0.0022 of score (truncate 0.978 vs 0.986, literal
0.972 vs 0.977 — the emergent fills price an unwritten literal at its length
where the stop priced it at one, and choose tied `First` arms by PEG order),
against −213 lines and +1.8 perfect points. On the frontier s1 survives on
score alone; s3 owns perfect%, the under-500 class, and dominates twelve
engines including r9.

### s4 — the frozen work reused, and the budget-deletion refuted

**s4 is the standing small engine: 0.9823 / 79.1% perfect (the study's best) /
~1,900 ms / 480 lines, every gate green — a strict improvement on s3.** Two
changes, one refutation:

- **The resync reuses the frozen parse.** Its question — "where does this
  slot next read cleanly?" — is one the frozen parser already answered,
  memoized, with the finished subtree attached. s3 answered it by running its
  own chart at budget 0 down the scan; s4 asks the library and reuses the
  subtree as a leaf way (re-wrapped in its Ref node, which the direct
  `Parser.match` path skips — losing the wrap cost 10 perfect points and b2
  until caught). Valid work already done is never repeated.
- **The fill solver collapsed** to a single recursion with cycles reading as
  unreachable, computed once for the ceiling — its only remaining client.

**REFUTED on the way (do not re-litigate without new structure): deleting the
budget outright.** The tombstone reading of the steer — a cell computed at
budget b inhibits what b+1 needs, so delete the budget and compute each cell
once, completely — was built first: one unbudgeted descent, termination by
prune-per-end and the cycle seeds (a zero-width fill recursion IS left
recursion and closes through the same seed). It is CORRECT and it is
**~100x too slow** (144 ms on one ordinary delim-delete case; battery
timeout): A3's old truth re-confirmed — the budget is the HORIZON that keeps
nearly-correct input cheap, because without it every cell explores every
repair at every depth. The waste the tombstone analogy truly names is
narrower: the CLEAN SPINE re-expands each round (prefix-edits 0 means
full-budget sub-calls miss their lower-budget cells), while repaired-prefix
sub-calls already reuse across rounds via `at >= budget`. The no-repeat form
that keeps the horizon — cells that GROW to a new budget instead of
recomputing, the m-line's budget families (I74/I75) folded into one table —
is the specified next step, expected to buy m143-class latency and further
lines, and it is not smuggled into this file unmeasured.

### b1 — the two-mode engine, built faithfully, measurements begun

**The owner's architecture, stated precisely and built as `b1.dart`:** parsing
mode runs until stuck; the enriched tree hands over the ENTIRE frontier at
that instant (successful subclause work reused through mismatch nodes, never
recomputed); repair mode is a breadth-first widening over that frontier —
price l = 1, 2, ..., sites deepest-to-shallowest — whose commit criterion is
the parser's own: a new match moves the position forward (completion first;
at the end of the input, where nothing can move forward, a fill that
discharges its site CHANGES THE FRONTIER'S SHAPE, which is the criterion's
own wording); the first committing candidate returns the engine to parsing
mode on the same memo table. No chart, no way-algebra, no budget over the
document. This is the r-series brief plus everything since: the sideways
repair channel and readEnd invalidation from t1, the reach side maps, the
evidence gate (I99) as the only guard.

**Second session (2026-08-06 cont.): 0.8435 / 42.9%, and the remaining gap
has a name.** Three truth-violations found by trace and fixed: extent must
include the side maps (the parse's real frontier is everything it attempted);
the EOI descent-cut was wrong — the deepest sites carry SHARED grammar
clauses whose one zero-width fact closes every enclosing level through the
memo (`(']', 11)` closes four arrays in one class-2 commit); and held
shape-changers need the per-site denial/completion interleave. Confirmed:
junk fills self-filter — a repair that does not survive its own re-parse
classifies as nothing, so the memo is the honesty gate for fills. **The one
open discriminator is b1's form of the `net` question**: a denial at a reach
site is either the honest junk-deletion (a repetition's stopped site) or a
disguised universal delete (deny anything so optional whitespace can
"match"); banning reach-denials scores 13/16 recommit at 0.68, allowing them
0.84 at 10/16 — the distinguishing fact is what the denial BUYS, and a
one-character read inside a clause that needed nothing is no purchase.

**First session's standing account: 0.8375 /
41.5% / ~6 s; acceptance 3/3, freespan PASS, conf1 exact, recommit 9–12/16
depending on a live fork.** The architecture is complete as specified — the
EOI descent-stop, completions that reuse matched children, extent measured
through the side maps (the parse's real frontier includes what success
threw away), per-site denial-then-completion interleave, and the class
order complete > advance > shape-change with shape-changers committing only
when nothing can move forward. **One result already worth the file: the
class system decides BOTH of D8's acceptance cases with zero pricing
machinery** — b2's denial completes and wins by being attempted first;
cx2's fill completes where its denial merely advances; the fee, the net
rank and the toll were all compensations for judging repairs by score
instead of by the parser's own progress. The live fork is the
First-completion arm chooser (furthest-read arm: 0.8375/9-16; cheapest:
0.8325/12-16 — each flips different committed-construct cases; the
commitment should be measured through the side maps, the next session's
first move), and deep truncations still commit at the wrong spine level.
The header carries the exact state, traces and both fork numbers.

### b2 — the design synthesis, and where greedy commitment hits its wall

**The instruction: compare the DESIGNS and combine their strengths.** b2 =
b1's two-mode architecture + the chart engines' rival judgment applied where
the classes tie: `net` (evidence explained by constraining terminals, read
off the root tree `_attempt` already materializes for free) and the I72∩I36
fee rank rivals WITHIN a class; the classes still rank between themselves.
Each piece measured as it landed: fee+net within a class 0.8435 → 0.8528
(recommit 14/16 — the whitespace-hijack dies because the honest `'}'`
completion nets one more than the denial that pins nothing); the
across-rung arbiter — **a dear advancer may not delete more explained
evidence than a cheaper held shape-change explains** — 0.8528 → 0.8816 and
recommit 15/16, the first rule that served BOTH regimes (it was found by
tracing a 28-character denial at rung 28 that classified "complete" and
preempted the l=1 fill chain whose total price was 6); the I95 literal
alignment as a candidate species (`_strAt`: owe inside the literal, then
consume real input — the one shape neither suffix-completion nor
prefix-denial can express) 0.8816 → **0.8826 / 48.2% / recommit 15/16, the
b-line's standing best**. Two refutations paid for en route: crediting bare
`Match(null)` evidence spans in `net` re-weights every completion's matched
prefix and costs three recommit cases; banning completions at ALL reach
sites (the I68 reading) kills the honest closers too — 0.7266, acceptance
gate broken — because a Seq's failing later slot is also "reach."

**Why the b-line stalls at 0.88: greedy sequential commitment.** Every
rung-rule measured (class-first with held shape-changers, price-first with
class-within-rung, the net arbiter) fixes the regime it was traced on and
breaks the other, because the correct choice between a cheap fill and a
dear denial depends on the repairs that come AFTER it — which no
commit-one-then-reparse order can see. The s-engines never face the
question: the way-algebra prices every rival repair for the whole document
simultaneously. That diagnosis, not another rung-rule, is what c1 acts on.

### c1 — the unification: two modes made per-clause, at SOTA accuracy

**Judge globally, search locally, never re-derive.** c1 = s4 with the
two-mode architecture installed at the head of the descent: every Ref's
`_ways` first asks the frozen parser's memo (parsing mode); a clean span
that ends before the damage IS the answer — one peg way carrying the
finished subtree, cost zero, no enumeration; repair's search (the
way-algebra, unchanged) opens only where a span touches damage. s4's
resync consult was this idea confined to one call site; c1 makes it the
first line. The LR grow-loop stays the recovery loop (I100) — and the
freeze honors it by exemption: **a left-recursive rule is never frozen**,
because each spine extent is a distinct reading the repair judgment must
keep, and the memo's one answer would collapse them (found as a −8.89
crater confined entirely to the expr corpus; leftmost-reachability closure
computed once per rule). Three more freeze conditions, each traced to a
failing case: the window is `pos + len + budget < clean` (a repair of
price b may rewrite up to b characters upstream of where damage was
noticed); spans of ≤ 1 character never freeze (nothing to re-derive — the
freeze exists solely to save derivation, and freezing a nullable rule's
empty answer suppresses the alternative stopping points repairs thread
through); and `clean` is the FIRST error node's position **capped at where
the pure parse stopped consuming** — the library's failed root can carry
no error node at all (`x="ab"; y="cz; ...` stops at 8 with a clean
partial root), and believing the whole document clean froze the swallow
itself (cost 4 where s4 pays 1).

**Result: 0.9823 / 79.1% / 2022 ms / 545 LOC — every gate green, recommit
16/16, and case-wise ≥ s4 on all 2000 documents (strictly better on one,
+0.037).** Identical judgment to the standing SOTA, reproduced inside the
owner's architecture; in pareto's frame s4 still holds the frontier point
(smaller and a hair faster), so the c-line's contribution is structural:
the two modes are real, they interleave per clause rather than per round,
and the memo is the substrate both share. The latency the substrate
promises was then claimed in the same session (below): the clean-suffix
problem needed no boundary at all.

**PARSING MODE IS BUDGET ZERO (the latency completion, same session).**
Profiling first (per-case ms, winning round, cell-recompute counters):
no case tail — the top 25 cases are 8% of the time (the 12.9 ms outlier
was JIT warmup: median 961 µs when run alone); rounds 1+2 are 87%; and
only 32.7% of cell recomputations are identical, which caps growing
cells/semi-naive evaluation well under the target and matches the
r-chart's refuted 29%. The profile's real finding: damage at position 0
means `clean = 0` and NOTHING freezes — the pristine 46 of 47 characters
re-enumerate every round. The suffix boundary problem then solves itself:
**with no edits left, the way-descent IS the pure parser** — PEG choice,
greedy repetition, left recursion, all of it — so at `_budget == 0` the
frozen memo's answer is exactly equivalent, unconditionally: no LR
exemption, no length condition, no `clean` window. Every fold
continuation that has spent its edits collapses to O(1) from there to the
end of the document; the budget itself marks where repair can no longer
reach, which is the damage boundary the design was missing. One
equivalence hole found by the battery (quote-delete 0.999 → 0.971) and
closed: **a frozen way must CARRY ITS VOUCH** — a pure reading vouches
what it absorbed (`span − net`, identical at every lift of the same
span), or outer judgments re-charge already-vouched string content; the
prefix freeze had the same latent bug. Result: **0.9823 / 79.1% / 1566 ms
— −20% latency at identical score, every gate green, still case-wise ≥ s4
on all 2000 documents** — c1 joins the frontier in its own right (beats
s4 and s1 on ms; s4 keeps LOC; neither dominates), dominating 16 engines,
the most on the table. Remaining and accepted: rounds 1–2 are now the
whole cost, and it is the way-algebra's rival multiplicity — the judgment
itself, not waste; the m-line's ~1,100 ms remains cheaper by exactly the
readings it does not weigh.

**THE COMPACTION (owner's instruction: roll the benefits into a form
closer to s4; audit fields for overlap).** Measured first: with budget-zero
in place, the conditioned prefix-freeze (non-LR, span > 1, window, `clean`)
bought ~6% median — and deleting it outright ran FASTER than keeping it
(~1580 vs ~1598), because its per-visit library-memo consult cost roughly
what its freezing saved. Deleted with it: the `_lr` leftmost-reachability
closure, the `clean` boundary walk, the mismatch sentinel, and all four
conditions — the mode split is now the single unconditional rule. The one
case where c1 beat s4 came from the freeze, so the final form is **bit-
identical to s4 on all 2,000 documents** (net +0.000) at **0.9823 / 79.1%
/ ~1,580 ms / 493 LOC — 13 lines over s4, 16% faster**. The field audit's
findings: `eof` was an int whose magnitude no consumer read — now a bool,
which makes I94's charge-once STRUCTURAL (a bool cannot charge twice).
The three cost fields that LOOK mergeable are three distinct meanings and
must stay: `del` is span-arithmetic (read alone by the absorb/swallow
computations), `gap` alone gates the D8 fee in the fold, and `toll` is a
judgment penalty that deliberately never consumes budget (`_afford` and
the fold's break filter on bare `edits`) — spend and penalty are different
things, and merging them would change which ways a round can afford.

### c2 — the axiom: four forms, one fixpoint, no root (I102)

**The instruction: ablate, collapse, unify — find the pure core.** c2 answers
with a normalization instead of an engine change: X* IS left recursion
(`X* ← X* X / ε`), X? IS choice (`X / ε`), a literal IS a sequence of
characters, and the end of input IS a grammar slot (`#T ← B ¬any`). The
grammar is rewritten at load until only Terminal / Seq / First / Ref (plus
predicates) remain; rules coined by the rewrite are anonymous (`#`) and cap
without judgment. What remains in the engine: ONE fixpoint — the grow-loop
that already served left recursion and budget-zero parsing — and no root
protocol at all (the tail charge is an ordinary denial at the ¬any slot;
the root swallow is a named boundary rule's judgment; truncation's
obligations are ordinary owes). `_rep`, `_opt`, the Str fast path, the
char-fold cache, and recover's 40-line root block stop existing.
**0.9818 / 78.7% / ~1,950 ms / 454 LOC — the smallest engine ever above
0.98 (s3 held it at 484) — every gate green, recommit 16/16.**

**What ubiquitous growth forced, each found by a failing case.**
(1) **Warth's involved-set replaces the per-position version bump**: with
repetition growing at every position, the blunt bump cold-started whole
positions' memos and the battery TIMED OUT; the precise rule — only rules
that read a growing seed, at that position, during that growth, are ever
recomputed — deletes `_version`, `gen`, and the bump for a transient heads
map. (2) **The prune needs a TOTAL order**: the grow-loop's improvement
test compares sorted lists position-wise, Dart's sort is unstable, and
rank-ties swapping order read as improvement forever — one stmt transpose
hung the battery; tiebreak by end. (3) **The boundary law**: the top body
is a named rule B — the FINAL judgment: admit every reading (the lift's
net-gate would drop the correct free-span reading), judge every reading,
VOUCH-BLIND (nothing shields absorption from the last judge) — and levy it
BEFORE the end-of-input fold, because the prune's per-end selection
assumes no claim is pending when ways meet: with the charge deferred to
the root, a 1-edit whole-document String swallow beat the 2-edit honest
Array at the fold prune and recommit broke. (4) **Vouch symmetry**: a
frozen span vouches exactly what its enumerated form would have
(span − net — the named judges inside it, one per Character). Stripping
vouch from anonymous frozen spans tolled the HONEST reading's frozen
content while the escape-conjure's enumerated content stayed shielded, and
price decided against honesty — 25 json quote-delete cases fell to the
recorded third resistant class through that asymmetry alone; symmetry
restored, they came back.

**Paid for and kept out**: the owing-skip fee ("a denial while owing pays
one") was invented on theory and killed the owe-then-deny truncation
pattern recommit needs (c1 prices it zero and lets net decide);
provisional-cells-during-growth (staleness theory, wrong: same tree, +50%
latency); the round admits by TOTAL price (edits+toll) — kept, a claim is
a claim. **Residual vs c1**: −0.0005 score over 19 scattered cases (mostly
expr, the true-LR grammar under rep-as-LR), +25% latency — the grow-loop
per repetition costs real iterations; c1 keeps the speed point (1,576),
c2 takes the size point (454). Both on the frontier.

### c3 — the rewrite hoisted, the sort deleted, the best of both lines (I103)

**The instruction: hoist the rewriting into behavior (trees must follow the
grammar); unify the sort order and the improvement comparison into one
structure; find the c2 regression; compact.** c3 is c1's proven behavioral
forms (repetition closure, option, literal char-fold, root protocol — no
grammar rewriting, every tree under the original clause) carrying the two
laws c2 PROVED (Warth's involved-set; frozen-span vouch symmetry), plus THE
WAY-FRONT: one champion per ending, decided by rank at insertion. An
accepted insert IS the improvement signal the grow-loop waits on; ties
replace silently (the freshest reading holds the bucket, but a tie must
never read as improvement or rank-equal rivals spin forever); farthest-PEG
demotion and the budget filter are read-time views. The sort — and the
unstable-tie livelock class it carried — ceases to exist; iteration order
is the map's own, deterministic by construction. **0.9826 / 81.7% /
~1,470 ms / 515 LOC — every gate green, recommit 16/16 — the best perfect
rate ever recorded, frontier #2, dominating 18 engines, case-wise net
+0.68 over c1 (105 better / 65 worse).**

**Two porting truths the battery taught (the port scored 0.9766 until
both were found):** (1) **the seed is read RAW** — applying the budget
filter at the seed-hit hides the seed's repair-carrying ways from the very
growth that must build on them (LR spines stopped growing repairs;
`1*` lost its MulOp level); (2) **re-entry IS left recursion** — any
inPath hit sets foundLR; c1 gated the flag on a null ways-list, and once
fronts are pre-created that first-hit signal silently vanishes, turning
growth off entirely (all-expr collapse, −0.0057). Also measured and kept
out AGAIN, now isolated from the rewrite: growing the repetition through
its own cell (the I102 pure form) costs 2,440 ms vs 1,535 for the one-pass
closure at no accuracy change — the general grow-loop re-expands the whole
rule per growth step; the closure keeps its specialized scheduler, stated
as such. And budget-zero parsing extends to EVERY memoized clause (the
library answers composites too, cached in the cell), worth −6% latency.

**The c2 regression, resolved**: the 19 lost cases were the desugar's
semantic drift (the rep's advance-only guard and empty-`+` fallback,
`_opt`'s peg-aware empty way, c1's root owed-admission) — all restored
here by construction, and the expr classes flipped from c2's biggest loss
to c3's biggest gain (+12 truncate, +11 delim-insert, +10 junk-insert).

### c4 — the size floor, measured (the halving that refused)

**The instruction: match or exceed c3 on every metric at approximately half
the size.** c4 is c3's semantics exactly — bit-identical on all 2,000
battery documents, every gate green — carrying the only two changes that
survived measurement: the grammar-static `minFill` computed once per
engine instead of once per recover (it had been recomputed 2,000 times per
battery), and the memo cell merged INTO the way-front (one class, one
identity). **0.9826 / 81.7% / ~1,480 ms (bands overlapping c3's) /
511 LOC.**

**The halving is measured-infeasible at these bars, and the proof is the
ledger.** Nine collapses attempted, each killed by a number: (1) eager
tree-building — ways AS materialized trees, six lazy fields and `_build`
deleted, −45 lines — costs +20–31% latency at the tie-refresh volume
(every grow iteration re-materializes rank-equal freshness), I88 confirmed
a third time; (2) a scalar `takes()` veto before materializing — no help,
because the volume is ACCEPTED ties, (3) whose freshness the perfect rate
needs: ties-stale scored 81.7 → 79.8; (4) repetition through its own memo
cell — 2,440 vs 1,535 ms, twice measured; (5) grammar rewriting — c2's
whole story, −0.0008 and trees that no longer follow the grammar; (6) root
simplification (drop the owed-admission) — recommit 15/16: the incoherent
honest Array MUST be able to displace the coherent String swallow; (7)
Ref-cells to cache the lift — +100–180 ms of read-side view allocation;
(8) cached front views — pays only against Ref-cells' read volume, +12
lines otherwise; (9) merging `_determined` and `_minFill` — memoizing
under a cycle-cut poisons minFill for nodes first computed inside a
left-recursion path; their different recursion protocols are correct, not
redundant. Comment-dieting is a non-move: normalised LOC never counted
comments. **What remains at ~511 lines is what the gates and the battery
pin in place**; the recorded seam below it is c2 at 454, paid for with
−0.0008 score and foreign trees.

### c4, second act — past s1 (I105): the tie autopsy that became four keys

**The instruction: explain why tie-freshness was load-bearing, fix it, and
close the score to s1.** Instrumenting the half-million rank-ties per
battery answered the first question: 97% were identity churn, and of the
3% that differed materially, virtually every one was the same reading
carrying MORE vouch — rank-invisible, but vouch decides future swallow
tolls, so freshness was a proxy for a missing rank key. **Vouch is now the
fifth key.** The residual freshness effect is a real, deterministic
preference — THE TIE LAW: the latest same-price rival holds the bucket
(first-keeps loses 2.6 perfect; PEG-first-within/refresh-across loses
3.0) — not fragility: expansion order is deterministic.

**Closing to s1 became passing s1, by itemized residual (I93 again):**
(1) THE REPLACE EDIT inside a literal — I95's third op: `i"` reads as `if`
by denying the `"` AND owing the `f`; the deny-scan cannot express it
(its skip must READ), and a whole quote-insert family fell to a String
swallow without it. (2) THE EOF EDIT IS NOT SPEND — I94 completed: the
eof bit is the root's one "document stopped" claim, so it must neither
block a fold's continuation nor fail an afford filter; it took three
buried gates (the terminal's budget refusal, the Ref branch's frozen
short-circuit, the fold's affordability break — itself wrong since the
Front made views insertion-ordered) plus the read-side filter to find,
and since eof-ways exist only at the end of the input the exclusion is
intrinsically EOF-scoped, no special cases. Without it a truncation's
spine died at its SECOND obligation and `{"` read as a String. (3)
FEWEST MARKS is the sixth rank key: the eof claim charges once however
many slots it strands, so a five-mark spine tied a two-mark one and the
tie law picked the deepest — expr truncates paid until the mark count
entered the rank. **c4 final: 0.9850 / 82.7% / ~1,520 ms / 559 LOC —
first engine past s1 (0.9841) on score, best perfect rate ever, every
gate green, case-wise 184 better / 84 worse against s1, frontier #1
dominating 18.** The eager-tree question also closed honestly: the
tie-refresh volume that priced it is the tie law itself — semantic, not
waste.

### c4, third act — the seed exemption (I106): 84 losses become 54

**The instruction: compare the cases where c4 loses to s1 and eliminate
them.** The dominant family was the deleted operand (`2+*`, `(+c)`,
`(-5)`): the honest repair owes the missing Factor as the seed of a
left-recursive spine, keeping the operator read. The spine formed, out-
netted the denial — and was poisoned by the D8 fee, charged to the seed-owe
inside the growing arm's own fold where the deny-scan found the rival
denial. **The resolution is scope, not rank: a slot that is a back-edge
into a cell being grown is an LR SEED — its give-up anchors the spine the
growth exists to build, and feeing it kills the growth. The seed is
exempt** (detectable exactly: the slot's rule-body cell at that position
is in-path). Moving the fee below net instead was measured seductive and
wrong: 0.9878/84.5 but the fee's own gate broke (accept b2 — the list
fill out-nets the deny there and must still lose; b2's fill and the
operand's seed carry IDENTICAL local scalars, and only the in-path test
tells them apart). The tie law was re-measured with the full six-key rank:
first-keeps still loses 3.1 perfect — latest-wins stands, four
measurements deep. **c4: 0.9870 / 83.3% (both records) / ~1,560 ms / 566
LOC, every gate green; vs s1 case-wise: 54 worse (sum −3.71, from 84 and
−6.66), ~190 better.**

**The remaining 54, classified**: tiny stmt truncations (`i` → Assign
where the corpus's original was If: a full six-key tie decided by marks
toward the shorter completion, where s1 wins by PEG arm order — the one
family where the corpus's priors beat the algebra's parsimony);
junk-before-operand inserts (`3*;4`); the json negative-number family
(`0-7`, `0,-,7`); small expr truncate/transpose tails. Each needs a
per-family mechanism; none is a bug of the six keys.

### The 54, read as a human (I107): most of what remains is not a defect

**The instruction: for the remaining c4-vs-s1 losses, judge what a human
would optimally expect; correct expectations or tweak heuristics.** All 54
were dumped with mutant, original, expected skeleton, and both engines'
trees, then classified:

**(a) Operator-choice ties, ~20 cases (expr delim-delete/insert/transpose/
multi).** `2;3`, `3(4-5)`, `(a*b)(c*d)`: the repair is a same-cost owe of
EITHER AddOp or MulOp, and the original's operator is unrecoverable from
the mutant — the two engines differ only in tie order, and they are
anti-correlated with the corpus in both directions (c4 picks Add where the
original had Mul at i=133 and Mul where it had Add at i=139 and i=1179).
s1's wins here are tie-luck, not knowledge. **Verdict:
expectation-limited: epistemically 50/50, no correct heuristic exists.**
Widening the replace edit to all slots (universal, then as a
deny-failed fallback) was measured against this family: ZERO of the 54
fixed, two new losses, double latency — reverted; the literal-scoped
replace stands.

**(b) Truncation nesting depth, ~12 cases.** `a+b*2-(` expects
`Term(Term(Factor()))` because the original's `(3+c)*4` wrapped the paren
in an outer Term whose only pre-cut character is the `(` itself:
`expectedFor` keeps every node whose START precedes the cut, so the
expectation encodes structure that lives entirely beyond the truncation
(the `*4` nobody can see). c4's minimal completion is what a human would
write. **Verdict: the expectation over-reaches; a fairer truncation rule
would keep only nodes with real content before the cut — recommended as a
DOCUMENTED secondary lens, not a rewrite, since the recorded scores of
sixty engines rest on the current yardstick.**

**(c) Keyword-prefix ties, 4 cases.** `i` alone: If (battery, from the
original) vs Assign(Name) (c4, via the marks key's shorter completion) is
a full six-key tie between a half-matched keyword and a complete name
prefix. A human is genuinely split; the corpus favors If. Buying these
with first-wins ties costs 3.1 perfect globally — not taken. **Verdict:
ambiguous; the battery's answer is corpus prior, not ground truth.**

**(d) Genuine residue, ~5 cases** (json `0-7`/`0,-,7` family, a transpose
tail): small, mechanism-specific, each needing its own trace; none moved
by the tweaks above.

c4 stands at **0.9870 / 83.3 / ~1,550 ms, all gates** — unchanged by this
round, which is itself the finding: of the 54, roughly forty are cases
where the battery scores knowledge of a coin flip or of text beyond the
truncation, and s1's edge there is luck of tie order, not a better
algorithm.

### s2 — the exclusion closed, and what a wash teaches

**s2 is s1 with the give-up exclusion deleted and D8's reason made arithmetic:
0.9841 / 77.0 / ~1,600 ms / 706 lines, every gate green, and DOMINATED by s1
(+9 lines at a tied score) — landed because the defect class it closes is real
even though the battery prices it at a wash (+0.18 / −0.24 case-equivalents).**
r9 and s1 offer a slot's give-up only where move and resync REACHED nothing,
and "reached" is not "useful": on `...2e],t":...` the resync probe finds the
quote after `t`, goes nowhere downstream, and the suppressed fill — owe the
OPENING quote, a determined character — was the honest reading. s2 lets fills
always compete, guarded by **I72 scoped by I36 — m143's fee formula ported to
the r-line at last**: a fill the grammar SPELLS invents no content and rides
free; only an UNSPELLABLE fill pays one rank-visible toll where a no-dearer
denial offered to read instead. b2 then passes by pricing, not by suppression.

**All three forms of D8's reason are now measured, and the scoped price is
the only one that is both principled and undamaging.** b2's protection must
live at the cost tier, because the owe-reading beats the denial on `net`
(it pins the extra comma), so no rule below `net` can reach it: (1) s1's
EXCLUSION (give up only where nothing reached) — 0.9841, but a scheduling
rule that decides which candidates exist, the hidden-enumeration form of
I30's sin, and it carries the "reached is not useful" hole; (2) s2's SCOPED
PRICE (I72∩I36, m143's fee) — 0.9841, everything competes and the ordering
decides; (3) the UNSCOPED CLAIM-WIDTH KEY (I62's `blind` ranked before
`net`, no constant, no scope — the aesthetically cleanest form) — **0.9776,
refuted**: it decides b2 correctly and then bleeds into every
honest-completion tie, flipping the `[1,[,` class that I54 records as b2's
same-evidence opposite-truth twin (literal-damage 0.977 → 0.955, multi
0.958 → 0.944). The scoping is not a blemish on the fee; it IS I72's
content — *a repair pays for inventing only where the input offered
something to read instead* — and the elegance ranking inverts the naive
aesthetic.

**The escape-conjure swallow is the named resistant class** (~2.5 c-e, e.g.
`{"n":[0,-7,1.5,2e],t":[...]}` at cost 1): an owed `\` reclassifies a real
quote as string content through `Chr <- [^"\] / ('\' Esc)`. Three principled
attacks were measured against it in one session and all refuted: the I72∩I36
fee (the fill is *determined*, so it rides free), the I97 refinement "only a
judged cap vouches" (−0.67 — it un-shielded `{"alpha"`'s honest completion; no
expressible rule separates a free CONSTITUENT from free leaf caps inside a
swallow's own run), and the I43-style prohibition (m143 carries it and fails
the same case through I53's fallback). m143, r9, s1 and s2 all answer it
identically wrongly. It joins the opener-placement class (item 14) and the
EOF-stack truncations as the third measured-resistant residual class.

**Still open, found by the same residual read and deliberately not knobbed: the
deleted-opener placement class**, ~7 case-equivalents across expr and stmt
delim-delete and multi-damage. Both readings are pure-gap cost-1 with equal
net, and `key` (longest trusted prefix) places the owed opener as late as
possible: `a+b*2-3+c)*4` gets `(c)*4` where the document meant `(3+c)*4`, and
`if (a)  if (b) { c=1; } }` gets a trailing empty Block where the document
meant the brace wrapped the statements. The evidence genuinely cannot decide
placement; the global key flip loses more than it wins; a scoped rule needs a
discriminator nobody has found. Probes: `_s0probe.dart`-style on those two
inputs. Part VII, item 14.

## 4.10 What the Codex checks found

Run at the owner's standing instruction. Codex has been genuinely useful and
genuinely wrong, in that order of frequency:

- Round two produced m62 and moved the standing engine.
- Round four landed two real holes and one named residue, and forced the claims to
  be re-scoped.
- Given r1 plus the verbatim brief, it corrected two stale numbers in the brief I
  had sent it — a check on my own transcription, not on the code.
- It independently reached **411 conventionally-formatted lines** as its floor for
  the era-1 engine and independently refuted the same alternatives. Its 83-line
  file was disclosed by its own author as "token-preserving whitespace
  compaction"; verified by token diff: 3850 vs 3856 tokens, first difference at
  token 3634 — the 83-line file *is* the 411-line program with newlines removed
  plus a 6-token bug fix.

**Lesson: an `awk` line count is gameable by joining lines; concept count is not.**
Report the concept reduction, not the character count.

---

# PART V — THE INSIGHT INDEX (I1–I92)

One line each. **Status** is: LIVE (in the standing engine or its lineage),
ABSORBED (true, but no longer a separate idea), SUPERSEDED (replaced by a later
insight), REFUTED/WITHDRAWN (measured and rejected — see Part VI).

**There is no I71.** The number was skipped.

| # | Statement | Origin | Status |
|---|---|---|---|
| I1 | THE VALUE — a match is "the cheapest repair to each end position"; the LR fixed-point test becomes "no end is new and no price is lower" | m41 | LIVE |
| I2 | A TERMINAL MAY LIE — SUB (consume a character it does not accept) or FAB (consume nothing), price 1 each | m41 | LIVE |
| I3 | A SEQUENCE MAY DISCARD — before any element, one character consumed by no terminal (SKIP), and the element retried. Only a `Seq` has a "between" | m41 | LIVE |
| I4 | `&C T` ≡ `C∩T` fusion — a reader owns the characters it decides, and a lookahead decides none | m45 | LIVE (not purely an optimisation: 4 witness shapes change) |
| I5 | THE WITNESS IS A PROOF, SO CHECK IT — re-parse the emitted witness with the pure parser | m46 | LIVE (42 lines) |
| I6 | A lookahead is a constraint on the next character EMITTED | m47 | SUPERSEDED by I24 |
| I7 | The constraint travels back out, inside the value | m48 | SUPERSEDED by I24 |
| I8 | ONE WORKLIST OVER CELLS — the deepening loop, the LR fixed point and the RR native stack were three schedules | m50 | LIVE (removed the RR ceiling for the whole line) |
| I9 | A cell is relaxed many times, so the value must be WRITTEN INTO, not rebuilt; the fixed-point test IS the write | m51 | LIVE |
| I10 | The reverse edge is consumed by the wake | m51 | DELETED by I11 |
| I11 | A DEPENDENCY IS AN EDGE OF THE GRAMMAR, NOT AN ADDRESS TO LOOK UP; the reverse edge is the forward edge's transpose | m52/m53 | LIVE |
| I12 | A cell never cut by the budget is complete at every budget | m5x | **REFUTED** |
| I13 | The budget is a bound, not a target, so the ladder can be skipped | m5x | **REFUTED** |
| I14 | Δ IS THE SCHEDULE — the total repair price deletes the ladder, the budget and the ceiling | m57 | LIVE |
| I15 | The bucket queue is the deepening ladder with every round | m57 | ABSORBED |
| I16 | THE CONTINUATION IS A MEMO FIELD (not the native stack) | m60 | SUPERSEDED by I18 |
| I17 | A MEMO ENTRY IS A FIXPOINT ENGINE | m61 | LIVE (framing) |
| I18 | THE ENTRY IS A FACT; THE PASS IS A FRAME — the entry keeps only facts | m62 | LIVE |
| I19 | The suffix is the invariant; the edit only moves the origin | m64 | LIVE as theory; its incremental entry point measured **economically empty** (0.96–1.11x) |
| I20 | Membership, deadness and the useful alphabet are ONE probed parse | m63 | LIVE |
| I21 | THE LAYER IS THE ANSWER | m65 | LIVE |
| I22 | A VERIFIED WITNESS IS A CERTIFICATE OF EQUALITY | m66 | LIVE — load-bearing for everything after it |
| I23 | THE ROUTER WAS A SEAM, NOT A DESIGN — one class over one substrate | m67 | LIVE |
| I24 | UNDER A CERTIFICATE, THE FAST ENGINE ONLY NEEDS TO BE A FLOOR — deletes the obligation lattice | m68 | LIVE |
| I25 | A REPRESENTATIVE CHOSEN ALONE CANNOT MEET A CONSTRAINT IMPOSED BY ANOTHER — the Boolean interval partition of the code-unit line | m69 | LIVE (it repaired a regression; it did not add a capability) |
| I26 | THE RECONSTRUCTION IS A PASS TOO — I18 applied one level out | m70 | LIVE |
| I27 | A greedy construct is a commitment, and so is every branch after the first | m71 | LIVE |
| I28 | A proof is worth more than a tighter search | m71 | LIVE |
| I29 | The write knows its own reason, and a reason recorded at a strict improvement cannot close a cycle | m72 | LIVE |
| I30 | When the comparison refuses a tie, the ENUMERATION ORDER IS the tie-break rule | m72 | LIVE (a D2 problem stated precisely) |
| I31 | The repaired string is the witness, and its parse is the tree | m74 | LIVE as an idea; its **implementation violates D1** |
| I32 | THE REPAIR IS SCAFFOLDING; THE TREE IS OVER THE INPUT | m75 | LIVE |
| I33 | DESTRUCTION IS THE WIDEST DESCRIPTION — charge `log2\|C\|` per character; destruction becomes the extreme case of description, deleting an axis | m77 | LIVE (reaches m121+) |
| I34 | An obligation you cannot write down constrains nothing | m78 | LIVE |
| I35 | A REPAIR IS A CLAIM ABOUT THE TREE, NOT AN EDIT TO THE EVIDENCE | post-D5 | LIVE — the frame for everything after |
| I36 | SYNTHESIS IS LEGAL EXACTLY WHEN THE WITNESS IS UNIQUE | post-D5 | LIVE — D7 as a checkable rule |
| I37 | THE BUDGET IS A PRUNE, NOT PART OF THE KEY | m79+ | LIVE |
| I38 | THE CONTINUATION NEED NOT BE PUSHED DOWN IF THE ENDINGS ARE PULLED UP | m79+ | LIVE |
| I39 | A PEG DECISION COMMITS TO A CHOICE, NOT TO AN ENDING | m79+ | LIVE |
| I40 | — | — | **number never used**: assigned to what became I44, twice restated, then renumbered when its final form changed what it measures |
| I41 | POSSESSIVENESS IS HOW PEG RESOLVES A REPETITION WHEN NOTHING IS BROKEN — collapse possessively **at budget 0 only** | m79+ | LIVE |
| I42 | Deepen on the objective, not on one term of it | m79+ | ABSORBED into the cap `2*len + witness(top).length + 1` and the doubling schedule |
| I43 | A REPAIR MAY NOT MAKE THE CHOICE — this is what keeps round 0 exactly the frozen parser | m79+ | LIVE (relocated to the ending by I76) |
| I44 | THE OBJECTIVE IS UNEXPLAINED CHARACTERS, AND A TERMINAL THAT CONSTRAINS NOTHING EXPLAINS NOTHING (`.` explains nothing) | m79+ | LIVE |
| I45 | FILL says WHAT is missing; HOLE says only THAT something is | m79+ | **DROPPED** — a node representing a forbidden claim re-admits the invented terminal wearing a different label. No `HOLE` exists in any built engine |
| I46 | A LEADING SKIP ALSO MAKES THE CHOICE, AND IS REDUNDANT | m79+ | LIVE |
| I47 | THE ANSWER IS A LIST, NOT A MAP | m79+ | LIVE (one `Map` survives, in `_rep`) |
| I48 | A TERMINAL IS NOT WORTH A MEMO CELL | m79+ | LIVE |
| I49 | A ref is a name for its body, not a second parse of it | m82 | **REFUTED BY MEASUREMENT — 907 → 1351 ms, 1.49x worse.** Kept in the source as a warning |
| I50 | THE MEMO TABLE BLOCKED ITSELF, EXACTLY AS D6 SAID IT WOULD | m8x | LIVE (a bug class, permanently) |
| I51 | REACHING A LATER ALTERNATIVE CLAIMS THE EARLIER ONES FAILED, AND FAILING ON THE EVIDENCE IS NOT FAILING | m8x | LIVE |
| I52 | A FILL IS MEASURED IN CHARACTERS, NOT CLAUSES | m8x | LIVE |
| I53 | A REPAIR MAY MAKE THE CHOICE ONLY WHEN NOTHING ELSE CAN | m8x | LIVE |
| I54 | A GUESS IS A COST YOU CANNOT SEE | m8x | ABSORBED — I54 is I72 with the fee at infinity |
| I55 | THE SEARCH DOES NOT NEED THE TREE | m8x | LIVE |
| I56 | A WAY THAT IS ALREADY NEW DOES NOT NEED TO BE COPIED | m8x | LIVE |
| I57 | A tie the engine cannot break is broken by the linked list | m8x | LIVE, and **a stated D2 violation** — later resolved by I67 |
| I58 | A free way is already the proof, so do not go and fetch it | m8x | LIVE |
| I59 | A CELL THAT NEVER CONSULTED THE CAP CANNOT CHANGE WHEN IT RISES | m8x | LIVE |
| I60 | A repetition only moves forward, so POSITION ORDER IS TOPOLOGICAL ORDER | m8x | LIVE |
| I61 | Cost says how much you doubted, it cannot say when | m8x | LIVE |
| I62 | A fill you cannot spell is a wider claim than one you can | m8x | LIVE |
| I63 | A key that is not additive cannot be a cost — `site`-as-maximal-runs was the defect | m9x | LIVE (as the rule); the `site` key it fixed is gone |
| I64 | WHERE THE DOUBT ENDS | m9x | SUPERSEDED by I69 |
| I65 | THE DAMAGE HAS A WIDTH, AND THAT IS WHAT LOCALITY MEANT | m9x | LIVE |
| I66 | A FILL IS A REPAIR EVENT WHEREVER IT IS WRITTEN | m105 | LIVE |
| I67 | A TIE IS THE ONLY THING THE BRIEF DECIDED | m105 | LIVE — resolves I57's D2 problem |
| I68 | A FILL OF NO CHARACTERS IS NOT A REPAIR — 31 engines (m79–m111) paid for pretending otherwise | m112 | LIVE |
| I69 | The only prefix-optimal shadow of "the damage is confined" is `doubt ↑` — every other confinement measure collapses back to it | m113 | LIVE |
| I70 | (a pricing rule for invention) | m11x | ABSORBED — I70 is I72 with the fee at zero |
| I72 | A REPAIR PAYS FOR INVENTING ONLY WHERE THE INPUT OFFERED SOMETHING TO READ INSTEAD | m121 | LIVE — closes the D-C exhibit at zero cost on every scored column |
| I73 | THE FOLD ALREADY KNOWS THE ANSWER CANNOT COST ANYTHING | m12x | LIVE |
| I74 | THE MEMO BELONGS TO THE BUDGET, NOT TO THE ROUND | m12x | LIVE |
| I75 | ROUND THE RESIDUAL TO THE LADDER THAT IS ALREADY THERE | m12x | LIVE |
| I76 | I43's evidence test belongs at the ENDING, not at the alternative | m13x | LIVE |
| I77 | An unexplained character costs what a deleted one costs | m13x | **WITHDRAWN** despite scoring higher — `_freespan.dart` shows why |
| I78 | Invention may COMPLETE a shape the input witnesses; it may not CONJURE one | m132 | LIVE |
| I79 | `net > cost` as the gate | m137–m140 | **REFUTED** |
| I80 | A node that explains no character and asserts none is not a node | m14x | **REFUTED** |
| I81 | Drop a hollow node only where NO EVIDENCE COULD EVER HAVE REACHED IT | m143 | LIVE — the standing `m`-engine |
| I82 | A GUARD ON THE DESCENT CANNOT BIND A CHART | m141/m145 | LIVE — **the key structural constraint** |
| I83 | `peg` and `fix` were never two questions — the merged key | r5 | LIVE |
| I84 | What is left is a monoid, and repairs are elements of it | r5 | LIVE |
| I85 | A claim nothing refuses is not a claim | r5 | LIVE |
| I86 | A ceiling that cannot be reached is not a ceiling | r5 | LIVE |
| I87 | A clause that cannot call itself needs no cell | r5 | LIVE |
| I88 | A way says what its node WOULD be, not what it is | r7/r8 | LIVE |
| I89 | The first round is the frozen parser, so it should hand out what a frozen parser's memo entry holds | r8 | LIVE |
| I90 | DENYING INPUT AND GIVING UP GRAMMAR ARE THE SAME SKIP AT TWO DEPTHS | r9 | LIVE — this is the answer to #18 |
| I91 | SO A PRODUCTION MAY GIVE UP ONE SLOT AND CARRY ON | r9 | LIVE |
| I92 | An obligation and a trailing discard are two claims about one position | r9 | LIVE |
| I93 | THE RESIDUAL IS THE DESIGN INPUT — itemize the imperfect cases and read them; every s1 change came from the case list, none from a proposed mechanism | s1 | LIVE — the method that broke the plateau |
| I94 | "THE DOCUMENT STOPPED" IS ONE CLAIM — obligations at end of input charge once, however many marks they stand for; ranking the mark count refuted both ways | s1 | LIVE |
| I95 | A LITERAL'S INTERIOR CAN BE DENIED — the alignment is match/owe/deny, and D7-safe because the literal is determined | s1 | LIVE |
| I96 | AN OWED SLOT IS STILL A PLACE IN THE TREE — emit the spine the grammar forces, descend a choice only on a unique cheapest arm, withhold at end of input | s1 | LIVE |
| I97 | A SPAN IS JUDGED ONCE — absorption vouched by a free subtree or a toll below is not re-judged above | s1 | LIVE |
| I98 | THE TREE HOLDS THE FIRST FAILURE; THE CHART HOLDS EVERY REJECTED READING — an engine walking the tree rebuilds them sideways, one species at a time | t1 | **SUPERSEDED by I100**: true of the half-ported tree, wrong in direction — the species are the FIVE discard sites of `reach`, not the chart |
| I107 | THE RESIDUAL IS MOSTLY THE YARDSTICK — dumping all 54 c4-vs-s1 losses with expectations: ~20 are operator-choice coin flips (the original's char is unrecoverable; the engines' tie orders are anti-correlated with the corpus BOTH ways), ~12 are truncation expectations that keep nodes whose content lies wholly beyond the cut, 4 are keyword-prefix ties; ~5 genuine. The universal replace edit was measured against them: zero fixed, two regressions, double latency | c4 | recorded — c4 unchanged at 0.9870/83.3; fairer truncation lens documented, yardstick not rewritten |
| I106 | THE SEED IS EXEMPT — a slot that is a back-edge into a growing cell anchors the spine the growth exists to build; D8's fee may not charge it (in-path test), and may not rank below net (accept-b2's fill out-nets its denial and must still lose — scope discriminates what no scalar can) | c4 | **LIVE** — 0.9870/83.3, all gates; c4-vs-s1 losses 84 → 54 |
| I105 | A LOAD-BEARING ACCIDENT IS A MISSING KEY — instrument the ties: freshness mattered because vouch was rank-invisible (fifth key), spine depth tied because the collapsed eof claim hid the mark count (sixth key), and the remainder is the TIE LAW (latest same-price rival wins, deterministically). With the eof edit recognized as the root's claim rather than local spend (I94 completed) and the literal replace edit (I95's third op), c4 passes s1: 0.9850/82.7/all gates | c4 | **LIVE** — the standing engine; rank is now (edits+toll, peg, net, key, vouch, marks) |
| I104 | THE SIZE FLOOR IS A MEASUREMENT, NOT A TASTE — at (0.9826/81.7/~1,480/all gates) the engine's floor is ~511 lines: nine attempted collapses each broke a bar by a recorded number, and the two real finds (grammar-static minFill cached per engine; the cell IS the front) are worth −4 lines and the latency of 2,000 spared recursions | c4 | **LIVE** — c4 bit-identical to c3 case-wise; the seam below the floor is c2's 454 at −0.0008 |
| I103 | INSERTION IS THE IMPROVEMENT TEST — the way-front (champion per ending, rank at insert, ties replace silently but never signal, demotion and affordability as read-time views) unifies the prune, the sort, and the grow-loop's convergence test in one structure; the seed is read raw, and re-entry IS left recursion | c3 | **LIVE** — 0.9826/**81.7**/~1,470 ms/515 LOC, all gates, frontier #2 dominating 18; the sort and its unstable-tie livelock class deleted by construction; rep-through-own-cell measured out once more (2,440 vs 1,535 ms) — the closure is the same fixpoint on a specialized scheduler |
| I102 | ITERATION, LEFT RECURSION, AND REPAIR ARE ONE MECHANISM — a memo entry growing to its fixed point. Normalize the grammar (X* ← X* X / ε; X? ← X / ε; literal ← char sequence; EOI ← a slot) until the engine speaks four forms and one fixpoint; anonymous rules cap without judgment; the boundary rule B is the final judgment (admit all, vouch-blind, before the EOI fold); a frozen span vouches span − net (the enumerated equivalence) | c2 | **LIVE** — 0.9818/78.7/454 LOC, all gates, smallest ≥0.98 engine; needs Warth's involved-set (the version bump cold-starts everything once growth is ubiquitous) and a total prune order (unstable sort ties read as improvement forever) |
| I101 | JUDGE GLOBALLY, SEARCH LOCALLY, NEVER RE-DERIVE — the two modes are per-clause, not per-round, and the whole mode split is ONE RULE: parsing mode IS budget zero (with no edits left the way-descent is definitionally the pure parser, so the frozen memo answers unconditionally — the budget itself is the damage boundary, and the clean suffix is free); greedy commit-one-then-reparse is refuted as a judgment (its correct choice depends on repairs it has not made yet) | b2 → c1 | **LIVE** — c1 0.9823/79.1/**~1,580 ms**/**493 LOC**/16-16, bit-identical to s4 on all 2,000 docs at 16% less latency, 13 lines over s4; the conditioned prefix-freeze was DELETED (its consult cost ≈ its savings); frozen ways carry `vouch = span − net` or swallow pricing breaks; `eof` is a bool, making I94's charge-once structural |
| I100 | A MISMATCH IS A SUSPENDED READING, AND LEFT RECURSION IS RECOVERY AT COST ZERO — the memo entry's grow-loop is already the whole recovery engine; the parse computes every reading recovery needs exactly once, success discards them at five combinator sites (`reach` completes the record), the chart re-derives that record every round, and the tree indexes it | t1 → s3 | **LIVE — ★ THE PIVOTAL INSIGHT OF THE RECOVERY LINE, owner-confirmed 2026-08-05** ("the biggest breakthrough you have made so far"). Made STRUCTURAL in s3: one grow-loop, one entry, no second mechanism — the collapse that broke the size cliff and dominated r9. Answers §1.8's six-occasion steer |
| I99 | AN ARM THAT READ NOTHING MAY NOT INVENT — I43/I78 as a property of the mismatch tree, with I53 as its fallback pass; one structural rule standing in for toll, net-rank and the whole-document charge | t1 | LIVE |

---

# PART VI — REFUTED, DO NOT RE-LITIGATE

## 6.0 The rule that governs this list

**A refutation is only valid against the engine it was measured on.** When a
primitive changes, every idea previously rejected *because of* that primitive is
back on the table. Re-run this list after any change to the core recurrence.

The worked example: `Seq([top, Nothing])` as the goal clause measured 510/519 and
1.15x slower **against the j-loop engine**, and was recorded as refuted. With SKIP
as a unit edge (A1) the same wrapper holds 517/519 *and* deletes 25 lines — skip at
dot 0 is the leading garbage, skip at dot 1 is the trailing garbage, both from the
universal rule. The refutation was withdrawn.

## 6.1 Objective and pricing

| idea | result |
|---|---|
| drop regret entirely | −32 shape points |
| cost-only regret | 465/519 |
| keep-loss-only regret | 472/519 |
| factor-1 with absolute width | 508/519 |
| descending-head witness tie-break | 511/519 |
| latest-predecessor sweep tie (`cur < tot`) | 511/519 |
| hoisting SPAN out of `Seq` position 0 | breaks minimality |
| full-width span pricing | worse |
| I77 — an unexplained character costs what a deleted one costs | scored **higher**, withdrawn anyway: `_freespan` shows the engine deleting input it has no reason to delete |
| I79 — `net > cost` gating, in four forms | 0.9662 / 0.9634 / 0.9621 / 0.9485 against m134's 0.9668; every regression is a value damaged or deleted where the grammar expects one |
| I80 — a node that explains no character and asserts none is not a node | refuted; I81 is the survivable form |
| I45 — a `HOLE` primitive weaker than `FILL` | dropped: a node representing a forbidden claim re-admits the invented terminal wearing a different label |
| letting the cost choose without gating | fixes one deadlock and immediately gives up `Stmt+` at 0 — the entire program for the price of the cheapest statement, scoring the whole stmt corpus **0.000**. At every price SOMETHING is always on offer; the gate is what stops the recovery buying it |
| r7's flat terminal pricing (`_fillOf` charges every terminal 1) | prices giving up `"false"` the same as one comma. r11–r13 charge `Str` its own length |
| charging absorption **per slot** | **refuted — a price charged at a slot is evadable by moving the slot** (re-pairing dodges it); per *node* charges the same span again at every `Ref` above it — and that re-charging was itself the I97 defect, fixed by vouching in s1 |
| ranking the end-of-input mark count (either direction) | fewer-marks-first 0.9762, sign-only 0.9760, unranked 0.9770 — how much a stopped reading says was under way is a bet on a continuation the evidence cannot decide (s1) |
| the earliest-first-repair key flip | 0.9799 / 73.7 against 0.9841 / 77.0 — r4's later-wins rule holds; the deleted-opener class it was aimed at needs a scoped discriminator nobody has found (Part VII item 14) |

**Where a charge goes is a correctness question, not a bookkeeping one.**
Absorption is priced at the **whole document**, because that is the only place the
charge cannot be dodged, and it needs no new field: `absorbed = len − del − net`.
Every character is either denied (`del`), pinned by a terminal that constrains what
it accepts (`net`), or absorbed by one that does not.

## 6.2 Architecture

| idea | result |
|---|---|
| **the two-mode design** (top-down O(n), then bottom-up Earley/Pika O(n³) with a DP wavefront) | built faithfully as m141, passes every conformance probe, **lost by 17.8x**; m145 then showed the chart costs 0.0025 AST-diff and 1.5 perfect points **at equal latency**. Refuted structurally, not by implementation |
| A* over the tape | an admissible heuristic must lower-bound true-PEG remaining cost per tape state; the available floors are CFG-side and cannot be evaluated without mapping back into grammar coordinates, so `h` degenerates to 0 and A* collapses to Dijkstra |
| reparse-the-repaired-text (delete tree reconstruction) | cover 398/519 naive; deduped version 466 lines and 1.14x slower — the traceback just moves, it does not vanish |
| one shared budget across subtrees | catastrophic: 3/519 |
| the router as a design (m66) | dissolved by I23 — routing between two black boxes is not an algorithm |
| the obligation lattice (I6/I7) | measured inert on every real input; deleted by I24 |
| cgfr1 / cgfr2 / cgfr5 | dead ends. cgfr5's own note: once the tape is actually present it is LARGER than the m68 it was offered to undercut |
| the frontier list as a separate structure | disappears in r3 once the cell holds every reading |
| net credits bare evidence spans (`Match(null, len>0)` counted as pinned) | b2: re-weights every completion's matched-prefix wrapper; recommit 15/16 → 12/16, −0.03 battery |
| completions banned at reach sites (the blunt I68 reading) | b2: 0.8826 → 0.7266, acceptance b1 case broken — a Seq's failing later slot is also "reach", so the honest closers die with the mark-stuffers |
| any single rung-rule for greedy commit (class-first 0.8528 / price-first 0.8230 / net-arbiter 0.8816) | the b-line's ceiling: each fixes the regime it was traced on and breaks the other; the choice needs the repairs AFTER it, which only simultaneous judgment (c1) sees |
| freezing LR rules' clean spans (c1) | −8.89 confined to expr: each spine extent is a distinct reading; the memo's one answer collapses them |
| freeze window from the REMAINING budget (c1) | the fold spends it to zero mid-descent and the window closes against the damage, freezing the swallow at the frontier; the entry budget is the honest horizon |
| growing cells / semi-naive rounds as c1's major latency lever | profiled: only 32.7% of cell recomputations are identical (the r-chart's refuted 29% again); the round-over-round waste is real but capped far under the 2x target — the budget-0 collapse (−20%) was the honest lever |
| frozen ways with vouch 0 | quote-delete 0.999 → 0.971: outer judgments re-charge already-vouched string content; a pure reading vouches span − net at every lift |
| the conditioned prefix-freeze, kept alongside budget-zero | deleting it ran FASTER than keeping it (~1580 vs ~1598 median): its per-visit memo consult cost what its freezing saved, and its four conditions (non-LR, span > 1, window, clean-boundary) each carried a trap already paid for once |
| the owing-skip fee (c2: "a denial issued while owing pays one") | invented on theory, never measured on its own; it prices the owe-]-then-deny-" truncation pattern to 3 where the honest rank (net at the tie) wants it at 2 — recommit broke; c1 charges the pattern zero |
| vouch 0 for anonymous frozen spans (c2) | asymmetric: the honest reading's frozen content got tolled while the rival's enumerated content stayed vouch-shielded; the escape-conjure swallow took 25 quote-delete cases; a frozen span vouches span − net, period |
| the per-position version bump once growth is everywhere (c2) | rep-as-LR makes every position a grow site; the bump cold-starts whole positions and the battery times out; Warth's involved-set is the precise staleness rule |
| provisional cells during growth (c2) | staleness-during-growth theory: same wrong tree, +50% latency — the stale-cell mechanism was not the cause (the missing toll was) |
| "the mismatch tree plus one sideways signal is strictly smaller than r9 at no worse than 0.9748" (the ★TODO claim) | **refuted by its own two-attempt protocol**: s1 0.9841/697, t1 0.9326/861 vs the bar 0.9748/562. The signal is sound (t1's gates); what failed is stated by I100 — the SHIPPED tree lacks `reach`'s five discard sites, and the iterated form still lacks rival simultaneity |
| the chart's local guards ported into the iterated engine | all three lost: strict cheapest-first ladder 0.9258 (cx2 broke) and 0.9223; I36 determined-gate on owes 0.9287; r9's reached-exclusion 0.8997 (b1 broke) — the whole-document trial subsumes them, and suppression only removes information (t1) |
| I62's `blind` as an unscoped rank key before `net` (the "cleanest" form of D8's reason) | **0.9776 vs 0.9841** — decides b2 and then flips its same-evidence opposite-truth twin (`[1,[,`, I54) plus every honest-completion tie; the fee's scoping is I72's content, not a wart (s2) |
| **first-match-wins** (the brief's stopping rule) | r10 → r11 collapses 0.6440 → 0.3218 the moment the grammar side is added, because a give-up cannot fail. Replaced by a scored commit (r12: 0.8661) |
| I49 — collapsing ref-cell and body-cell | 907 → 1351 ms, **1.49x worse**. A cell that looks like a duplicate of another cell may be the only cache on a different path |

## 6.3 Data structures and micro-decisions

| idea | result |
|---|---|
| record as memo key (`Map<(Clause,int,int), …>`) | 445 → 1086 ms, 2.4x slower |
| record as memo value (`Map<int, (int, Map<int,int>)>`) | 898 ms, 2.0x slower — a record allocated per memo write |
| position-ordered chart | superseded by index-as-topological-order |
| `SplayTreeMap` vs list queue | slower |
| CPS bounded DFS | slower |
| v5 filter-without-reuse | slower |
| eager axioms | slower |
| frontier sweep without key ordering | wrong |
| the floor short-circuit (`_paid + l` as a lower bound) | **not** a lower bound: a committed repair landing inside a subtree the parse later discards never appears in the emitted tree, so a candidate can read as cheaper than everything paid for it and break the scan on a false optimum. 0.8571 → 0.8541 for 13% of the latency |
| stepping the budget by 1, or to 4 before doubling | 1049 / 880 ms vs doubling's 895 — the simplest schedule is already the fastest measured **in the m-line's budget-indexed tables. It does NOT transfer**: on the r-chart's accumulate-and-merge cells, doubling is 1.39x SLOWER (2,831 vs 2,037 ms), because a doubled round explores several cost frontiers fresh at every cell while unit rounds re-derive only the new frontier (s1) |
| I59's finality bit imported to the r-line | a cell that never consulted the cap skips higher rounds: bought 2% latency and moved the score 0.9841 → 0.9839 through a missed cut site — the recomputation it deletes was never the cost (s1) |
| I12 / I13 (budget-completeness shortcuts) | both refuted; the ladder's rounds cannot be skipped and cannot be widened |

## 6.4 Hypotheses about where the time goes — five refuted at once

The battery gap was hypothesised, in five different sessions, to be in the search.
It is not: **m62 never re-parses**, and 39.1 of its 65.5 ms are in the certificate.
Separately, **the semi-naive chart that two independent analyses converged on is
refuted** — re-derivation is only 29% of the time. The time is in budget-1 and a
25-case tail.

## 6.5 Claims about size

- `<100` LOC with accuracy intact: not achievable. The regret machinery alone is
  ~92 lines and deleting it costs 32 shape points; a real tree root is required, so
  reconstruction cannot simply be dropped. The independently-derived structural
  floor for the era-1 engine was 411 lines; the honest result was 352 at *higher*
  accuracy.
- **The frozen lib is NOT the size floor.** The escape was built at m63 and no
  engine uses it; the reuse it buys is worth 1.18x. Read this before any new
  under-400-LOC attempt.

---

# PART VII — OPEN ITEMS

## ★ THE TODO FOR THE NEXT ROUNDS OF ENGINES — the richer mismatch node, and the O(1) signal carried sideways

**This is the single largest unexplored lever in the project, and it is the one
item here that is a research direction rather than a defect.** It has two halves
that turn out to be one thing: **the richer mismatch node** (steer #10, §1.7,
2026-08-02) and **reusing the O(1) memo signal for recovery** (§1.8, asked six
times since 2026-07-25). Read §1.7, §1.8, §2.2, §2.3 and §2.5 first — the second
block below is the argument that they are the same TODO.

**What exists.** Since `46bd136`/`6b81302` the shipped parser core returns, for
every failure, a **fresh mismatch node carrying the maximum length of input it
validly consumed before failing (`len`), an exact frontier (`pos + len`), and the
subclause matches *and* subclause mismatches underneath it**. The frontier is
therefore a **place in the tree** — a clause, with a path to it — and not the bare
integer that `Parser.syntaxErrorPosition()` scans the memo table for. The failing
`Seq` slot is the last child of its parent; every failed `First` arm is kept
because which arm holds the repair cannot be known locally; a `Str` reports how
much of the literal the input did supply.

**Why this matters more than any number currently in this document.** No engine
before `46bd136` could read a frontier off the tree, because there was nothing in
the tree to read: a mismatch was a shared tombstone. The only alternatives were a
memo-table scan returning a bare integer, or re-matching candidate clauses at
candidate positions to find out how far each got — and that re-derivation is what
the brief's iterative widening *is*, priced at 128.4 trials per case in §4.8. The
information is now computed by the parse itself, on the path it already walks, and
handed back.

**Why it is not yet a result.** Nothing consumes it. The measured benefit is
**zero on every scored column**, because the only engine that ever ran on an exact
frontier — **r13** — runs on `_core2.dart`, a separate experiment core, and r13
was aimed at the brief's *enumeration* architecture, where the frontier is not the
bottleneck (§4.8: 93% of its trials are give-ups, which no frontier precision can
pre-filter). **r13 answers "what is the brief's architecture worth on an exact
frontier?" — it does not answer "what is the best architecture given an exact
frontier?", and nobody has asked that question yet.** That is the whole of this
TODO.

**And do not oversell it while investigating.** As shipped — without `reach` —
walking the mismatch tree on four broken JSON documents gives a frontier of
6 / 6 / 4 / 1 where the old memo-table scan gives 16 / 11 / 5 / 1 (§2.5). The tree
gives a frontier that is *located*; on 3 of those 4 it is also a *shallower
number*. Thread 2 is what closes that, and any engine built on thread 1 before
thread 2 should be measured against the scan, not assumed to beat it.

**Concrete threads, in the order they look most promising:**

1. **A recovery engine whose widening walks the mismatch tree** instead of
   re-probing positions. The sites arrive in grammar order, each already carrying
   the clause that failed there — and a top-down walk knows every site's ancestors
   by construction, so the unbuilt give-up pre-filter of item 5 below ("can the
   parent advance?") needs no parent field added: the walk already holds the
   parent. Note the nodes carry children, not parent pointers, so this is a
   property of walking down from the root, not of an isolated node.
2. **Adopt `reach`** (item 1 below) — the same idea extended to clauses that
   *succeed* while discarding evidence. 27.9% → 100% frontier fidelity for about
   1.5x pure-parse time. The trade is measured; the call has not been made.
3. **Implement the substitution the instruction actually described** — convert a
   mismatch node into a `SyntaxError` node and *continue the parse from there*,
   rather than discarding mismatches at AST-build time (§2.5). This is in-place
   repair of the existing tree, which is what D1 has demanded all along, and the
   mismatch tree is the first structure that makes it expressible.
4. **Decide the lookahead question with a measurement** rather than by argument.
   The zero-width reasoning for dropping a predicate's body is sound for *where a
   repair may be placed*; it does not follow that the body's extent is worthless as
   *evidence about where the input stopped*. Those are two different uses of the
   same number, and only the first was considered.
5. **The one the owner has asked for on six occasions: carry the O(1) memo signal
   sideways** — see the next block, which is the same TODO from the other end.

**Status: not fully explored, and probably holds a great deal of promise.** The
cost is paid and the plumbing is in the shipped core; what is missing is an engine
designed around it from the start, instead of an engine designed without it and
then handed it.

### …and the half of this TODO that is six months older: the O(1) signal, sideways

**The steer (§1.8, quoted verbatim there, repeated on six occasions since
2026-07-25):** the same trick that makes left recursion work — *communicating an
arbitrary distance through the parse tree in O(1) by writing one field into a memo
entry addressed by content* — should be able to **collapse the recovery algorithm
into a tiny pure core**, deciding *"how different grammar clauses affect each
other's application during error recovery."* The owner has said explicitly that
earlier readings of it were **too narrow**.

**Where that stands, precisely (§2.2, §2.3).** The *vertical* channel —
descendant to ancestor, keyed `(rule, pos)` — was never re-derived and is in every
standing engine unchanged; r9 inherits `inPath` / `foundLR` / `gen` field for
field, and the loop it drives is why r9 needs no second parse. The *horizontal*
channel — frame to right sibling — was attempted twice, as the I6/I7 obligation
and again at m78, and **failed both times for one reason: there is no content
address that names a sibling.** I34 states it exactly — *an obligation you cannot
write down constrains nothing.*

**Why the two halves of this TODO are one TODO.** A signal needs three things: a
fact that is monotone and terminal, a recipient named by content, and a place to
write it. The horizontal channel always had the first and the third — a memo entry
— and never the second. **The mismatch tree is the first structure in the project
that supplies it.** A failing `Seq` node holds its matched prefix *and* the failing
slot, in order, in one object; a failing `First` holds every arm that lost. So
"the slot to my left", "the arm that got furthest", "the sibling that would have
had to supply what I am missing" are, for the first time, **things a frontier walk
can name and address** rather than things a frame would have to shout at.

**Two concrete shapes to try, in order:**

1. **Sibling repair obligations on the mismatch node.** When a `Seq` fails at slot
   *j*, the repair that fixes slot *j* changes what slots *j+1…J* may do. Today
   every engine rediscovers that by re-running them. The mismatch node already
   holds slots `0…j` and the failure at `j`; writing what the repair owes into the
   node the walk is standing on is the horizontal message with an address that
   exists.
2. **Generalise `_version[pos]++`, which already works.** It is the one live
   mechanism that is horizontal in effect — one integer retiring every stale cell
   at a position, unbounded siblings, O(1), addressed by *position*. The
   unexamined question is whether the same broadcast keyed on a **frontier site**
   rather than a raw position would let a repair invalidate exactly the cells it
   affects. That is the "much smaller code" the steer predicts: it deletes
   bookkeeping rather than adding a table.

**And the falsifiable version, so this cannot run forever.** The claim to test is
*"a recovery engine with the mismatch tree plus one sideways memo signal is
strictly smaller than r9's 536 lines at no worse than 0.9748."* r9 is the bar on
both axes at once. If two honest attempts land above 536 lines or below 0.9748,
that is a result worth recording as such — §6.0's rule applies, and a refutation
of one form of this idea is not a refutation of the idea.

**Both attempts are now recorded (2026-08-05, §4.9), and by this claim's own
protocol it is SETTLED: refuted as stated.** Attempt one (s1) exceeded the
score half (0.9841) and failed the size half (697 > 562). Attempt two (t1) —
the engine genuinely built around the tree, memo-as-repair-channel, candidates
read off the failure — failed both halves (0.9326 at 861 lines) while passing
every honesty gate and setting the study's latency record. The premise that
fails is precisely the sentence this TODO was built on: *the tree does NOT
already hold what the chart re-derives* — it holds each committed reading's
first failure, while recovery's information is every reading the parse
rejected, which the chart's cells hold natively and t1 had to rebuild species
by species (I98). **What survives:** the sideways memo signal itself is sound
and gate-proven (a content-addressed fact plus readEnd invalidation — t1's
channel works; it is the SMALLNESS that was wrong), and the evidence gate (an
arm that read nothing may not invent) does with one structural rule what the
chart engines do with three pricing mechanisms. A third attempt should start
from the other end: keep the chart, and use the tree as its *index* — §6.0's
rule applies to that form, not this one.

---

1. **The `reach` fork (from steer #10).** `dart/lib` currently keeps the cheap
   half of the mismatch-frontier change: its mismatch tree reproduces `_core2`'s
   `reach` on **27.9%** of battery cases. Adopting `reach` — a watermark on every
   node, including matched ones — gives **100% frontier fidelity for about 1.5x
   pure-parse time**. This is a genuine trade, not an oversight, and it is the
   owner's call. Measured by `_portcheck.dart` (tracked).
2. **Latency.** On clean input the question is now closed by construction: s1's
   round 0 IS the library parse, so a clean document costs exactly what the pure
   parser costs (§4.9). On damaged input the battery instrument puts s1 at 1,686
   ms against m132's 1,098 — the m-line's budget-indexed tables (I74/I75) are
   still the faster substrate, and importing their schedule (doubling) or their
   finality shortcut (I59) into the r-chart is REFUTED, not unexplored (§6.3).
   **The two instruments have still never been bridged**: the `ms` column is
   *whole-battery* time for 1,824 weighted cases, while the "sub-250 ms" goal is
   *per-parse* latency on one document; no arithmetic converts one into the
   other. Any claim that an engine "meets" or "misses" 250 ms has to come from a
   per-parse harness, and for damaged documents none is attempted here.
3. **The `<400` LOC question, now with a measured boundary.** Twenty engines are
   under 400 normalised lines and **none exceeds 0.9551**; nothing between 407 and
   535 lines beats it either; the best score jumps to r9's 0.9748 exactly at 536.
   So the open question is worth **0.0197 of score for 136 lines**, and it is a
   cliff, not a slope — 51 swept engines do not narrow it. r13 is 327 lines at
   0.9008; r9 is 536 at 0.9748. No engine has been both. Read §6.5 first.
4. **The Codex check on the current `r` engine** — blocked on account usage limit,
   retry after 2026-08-07.
5. **The give-up pre-filter (from #18).** A parent link on frontier entries would
   let a give-up be filtered by "can the parent advance?", ceiling ≈24 trials/case
   against r13's 128.4. Not built.
6. **Four unresolved pricing exhibits**, each a real disagreement rather than a
   bug to patch:
   - the `stop` deletion call in r9;
   - lever `f`'s 7-vs-2 overcharge on `S <- 'a'+ 'z'` with input `xazaaaaaz`;
   - the named-top `First` tree-shape inconsistency;
   - the `S <- A 'c'` overcharge.
   - and from the `m` line: `1++2` costs 2, not the optimal 1, because the cost-1
     reading requires exploring the recursive alternative WITH a repair, which I43
     forbids. **I43 and the cost objective disagree on this input, and one of them
     is wrong.**
7. **The weak-category cluster is `truncate` 0.947 / `multi-damage` 0.949 /
   `literal-damage` 0.957** (r9). *Do not restate the old "truncate is the biggest
   opportunity" claim* — that reading came from a column that was broken by
   construction and has been fixed (§3.2). Before treating any of these as
   headroom, **price the reachable ceiling first**; the last time that was skipped,
   the "weakest" category turned out to be 99.2% saturated.
8. **Ports.** Java, Python, TypeScript are contaminated by an earlier attempt and
   deliberately uncommitted. Port the pure core plus the chosen recovery module
   once the Dart core is settled.
9. **Incremental re-parse**: reuse memo entries whose spans precede the first edit
   (`ERROR_RECOVERY_DESIGN.md` §8.1). I19 says the suffix is the invariant and the
   edit only moves the origin; its measured value at current scales was
   0.96–1.11x, i.e. nothing.
10. **`del@13` / `swap@13`** remain unrecovered by every engine — the only known
    accuracy ceiling on the era-1 battery.
11. **Right-recursion depth** (§3.7) is a real ceiling inherited from the core, not
    from recovery. The fix is an explicit worklist in place of native recursion; it
    costs lines and is not built.
12. **The conformance gate does not cover the engines the size question depends
    on.** `_conf1.dart` has a fixed import list covering **m78–m143 and r1–r9**,
    so m23, m26, m32, m41 and r13 — **five of the eight engines on the frontier,
    and every one of the twenty engines under 400 lines** — have **no true-PEG
    conformance measurement at all** (nor does `dot`). The
    stated goal is "under 400 LOC *without losing* true-PEG conformance", so the
    open `<400` question (item 3) is currently being argued on three of its four
    terms: those engines' score, latency and size are known and their conformance
    is not. It is entirely possible they are small partly *because* they are not
    conformant, and nothing in the record decides it. Adding five imports to
    `_conf1.dart` would settle it; the engines are old enough that their build
    signature may need adapting, which is why it has not been done.
13. **m143 fails `_recommit` on one case, and has since m127** (§3.3). Input
    `[1,[2,[3,[4]]],5"` is answered as a String although the healthy prefix has
    already committed an Array. m121 and m126 pass 16/16, so the regression is
    locatable — it entered with m127, was mostly repaired by m132/m136/m143, and
    one instance survives. s1 and r9 both pass 16/16, so this does not touch the
    standing engines; it is an open defect in the `m`-line that anyone building
    on m143 inherits, and it was not in the record before 2026-08-03.
14. **The deleted-opener placement class** (~7 case-equivalents; found by the
    s1 residual read, §4.9). Both readings of a deleted `(` or `{` are pure-gap
    cost-1 with equal net, and `key` (longest trusted prefix) places the owed
    opener as late as possible: `a+b*2-3+c)*4` gets `(c)*4` where the document
    meant `(3+c)*4`; `if (a)  if (b) { c=1; } }` gets a trailing empty Block
    where the document meant the brace wrapped the statements. The global key
    flip is refuted (§6.1); what is missing is a principled discriminator for
    owed OPENERS specifically, and m143 fails these cases identically, so no
    existing mechanism holds the answer.

---

# APPENDIX — WHERE THINGS STAND

| | engine | score | perfect% | ms | LOC (recovery) | notes |
|---|---|---:|---:|---:|---:|---|
| standing engine, and best overall | **s1** | 0.9841 | 77.0 | 1,686 | 697 | §4.9 — the residual-driven generation |
| best under 600 lines | **r9** | 0.9748 | 74.0 | 2,038 | 562 | unchanged by the 2026-08 core change |
| standing `m`-engine | **m143** | 0.9693 | 72.1 | 1,131 | 628 | I81 + I82; fails one recommit case |
| smallest engine that works | **r13** | 0.9008 | 51.9 | 6,692 | 327 | the brief's own architecture, exact frontier |

### The standing-engine lineage, all on one battery

Every engine that was at some point the standard, **re-measured in one session on
the era-2 AST-diff battery** — including the era-1 engines, which `_score1.dart`
adapts losslessly (§3.2). This is the only table in the record where `dot` and r9
are directly comparable, and it is worth reading for one reason: **fourteen
engines from `dot` to m74 are a single accuracy plateau.**

| engine | score | perfect% | ms | what moved |
|---|---:|---:|---:|---|
| dot | 0.9549 | 67.3 | 15,705 | the origin — and already LR-correct |
| sd3 | 0.9247 | 63.0 | 2,446 | **6.4x of the 10.6x, in one step**; but LR now broken |
| m22 | 0.8959 | 63.2 | 1,977 | the end of the broken run — `expr` at 0.4766 |
| m23 | 0.9551 | 67.2 | 2,142 | **A5. LR fixed, and the plateau starts here** |
| m26 | 0.9551 | 67.2 | 1,479 | the plateau at 382 LOC — size, not accuracy |
| m41 | 0.9550 | 67.2 | 1,144 | the parser plus three insertions |
| m50 | 0.9550 | 67.2 | 3,061 | worklist over cells |
| m51 | 0.9550 | 67.2 | 1,837 | the fixed point is the write |
| m53 | 0.9550 | 67.2 | 1,664 | the reverse edge is the transpose |
| m62 | 0.9550 | 67.2 | 1,354 | entry = fact, pass = frame |
| m69 | — | — | >700,000 | did not complete |
| m70 | — | — | >240,000 | did not complete |
| m71 | 0.9550 | 67.2 | 1,472 | conformance without a tape |
| m72 | 0.9548 | 67.1 | 1,518 | the write knows its own reason |
| m74 | 0.9548 | 67.1 | 1,356 | the repaired string is the witness |
| m75 | 0.9528 | 70.8 | 1,275 | **DISQUALIFIED (re-parses, D1)** |
| m77 | 0.9609 | 71.5 | 1,389 | **DISQUALIFIED (re-parses, D1)** |
| m112 | 0.9575 | 67.2 | 4,395 | a fill of no characters is not a repair |
| m113 | 0.9573 | 67.0 | 4,439 | a prefix carries only where doubt started |
| m121 | 0.9573 | 67.0 | 4,743 | I72, the invention fee |
| m132 | 0.9648 | 69.2 | 1,098 | I76 + I78 |
| m143 | 0.9693 | 72.1 | 1,131 | I81 + I82 — standing `m`-engine |
| r13 | 0.9008 | 51.9 | 6,692 | the brief's architecture, 327 LOC |
| r9 | 0.9748 | 74.0 | 2,038 | the r-line's peak: swallow priced twice |
| **s1** | **0.9841** | **77.0** | **1,686** | **standing engine — the residual read (I93–I97)** |

**What this table says that no era-1 table could.** From m23 to m74 the AST-diff
score never leaves 0.9548–0.9551 and perfect% never leaves 67.1–67.2. Twelve
engines, an enormous amount of re-derivation, and **the accuracy is a straight
line** — what those engines bought was latency (15,705 → 1,144 ms, **13.7x**),
code size, conformance, and the deletion of tuning parameters. The whole of the
project's accuracy gain, 0.9550 → 0.9748, arrives after the objective was
re-framed from the CFG to the PEG (§4.1's closing note), and it is worth **+0.0198
AST-diff and +6.8 perfect points**.

**The `dot` → m26 latency drop is a cliff, not a slope, and an earlier version of
this table mis-attributed it.** sd3, the engine immediately after `dot`, is
already at 2,446 ms: **6.4x of the 10.6x arrives in a single step**, and twenty
engines then share the remaining 1.65x. m26's own contribution was size — 382 LOC,
the era's high-water mark on compactness — not speed and not accuracy. Every one
of m23, m24, m25, m26, m28 and m30 scores an identical 0.9551 / 67.2.

**And the dip between them is not a weaker repair strategy — it is the LR bug.**
sd3 through m22 all crash on part of the left-recursive corpus (§4.1), which is
what drags 0.9247 down to 0.8810 and back. m23 is A5. Reading the table without
that, the project looks like it lost accuracy for twenty engines and then
recovered it; what actually happened is that `dot` was right, a regression was
introduced immediately after it, and m23 undid the regression. **The plateau is
therefore `dot` → m74 in value and m23 → m74 in continuous membership**, and the
lesson is the same one §4.1 draws: the only gate that could see any of this is a
corpus with left recursion in it.

The two blanks are not noise. m69 and m70 are precisely the two engines that fold
their own copy of the parser rather than importing it (§3.5); neither finishes the
era-2 battery, m69 at >700 s and m70 at >240 s, where the engine on either side of
them runs in ~1.5 s.

Note also that m75 and m77 — both **disqualified for re-parsing** — are the first
engines to break the perfect% plateau (70.8 and 71.5 against 67.2). Their ranking
is exactly why D1 has to be a stated constraint rather than something the score is
trusted to enforce. **That constraint is no longer expensive: m143 now beats both
of them on score, perfect%, latency and size simultaneously** — see the frontier
section below. For most of the project's life, obeying D1 cost real accuracy; as
of m143 it costs nothing.

### The 51 engines that were never the standard, swept onto the same battery

The lineage table only lists engines that were at some point the standard, which
invites the obvious question: is the frontier hiding in one that never was? So 51
of them were run on the era-2 battery, one process each, in the same session:
sd3, sd5, v6, m12, m15–m25, m27–m40, m42–m49, m52, m57–m61, m63, m64, m66–m68,
m73, m76, m78. (Not swept: m65, which era-1 already recorded as non-viable; the
`cgfr` line; and the `m26c`/`m42e`-style ablation rows, which are re-measurements
of an engine already listed, not engines.) **The answer is no on both axes, and
the sweep is worth keeping precisely because it is a negative result.**

**Latency.** The three fastest engines in the whole study are m132 (1,098 ms),
m143 (1,131) and m41 (1,144) — all three already in the lineage table. The
fastest engine that was never the standard is m42 at 1,264, a further 10.5%
behind m41, and m42/m44/m43/m73/m38 then fill 1,264–1,296 with nothing new in
them. **The lineage table already contains the latency frontier of every era.**

**A cross-battery disagreement worth recording.** Era-1's fastest engine was m64
(195.1 latms, 0.42x v6, tagged "fastest latency"). On the era-2 battery m64 is
1,359 ms — *behind* m62's 1,354 and 19% behind m41. Its era-1 advantage does not
survive a wider corpus, which retroactively strengthens the era-1 note that m64
cost "+124 LOC over m62 for no measured gain": on this battery it is +124 LOC for
no gain at all.

**The whole tape line fails to finish.** m63, m66, m67 and m68 each exceed a 180 s
cap — verified as *slow, not erroring*: all four are still running at 20 s — and
m69/m70 are at >700 s and >240 s. m65 was not re-run, but era-1 already had it at
18.5x m62's battery with latency killed at that era's 120 s cap, so the whole
contiguous run m63–m70 is out. That is >130x the ~1.3 s their neighbours take on
either side. The tape/interval substrate is not a constant-factor
cost, and no era-1 column priced it, because era-1 measured a single-edit JSON
battery a tenth the size.

**One engine in the sweep has a genuinely distinct profile: m78.** It is the only
engine before m132 that breaks the perfect% ceiling *without* being disqualified —
68.4% against the plateau's 67.2 — while scoring **below** the plateau in
aggregate, 0.9444 vs 0.9551. Split by corpus that resolves cleanly:

| mean score by corpus | plateau (m23–m26) | **m78** | m132 |
|---|---:|---:|---:|
| json | 0.9637 | **0.9741** | 0.9754 |
| expr | 0.9037 | 0.8561 | 0.9309 |
| stmt | 0.9629 | 0.9381 | 0.9635 |

**m78 already had almost all of m132's json gain, 54 engines early, and paid for
it out of the other two corpora.** m132's json is only +0.0013 over m78's; what
m132 adds is that it stops paying — it is above the plateau on all three. The
record files m78 as a negative result (I34, "an obligation you cannot write down
constrains nothing"), and as an *engine* that verdict stands. But the json column
says the mechanism was doing something real, and 30-odd engines went by before
anything banked it. An aggregate score hid that for the whole interval.

**And one engine is simply dead: m76 crashes on 252 of 252 `expr` cases** — the
entire left-recursive corpus, mean score 0.0000 — while its json (0.9741) and
stmt (0.9381) are identical to m78's. Same engine, left recursion removed. It is
the cleanest illustration in the record of why the aggregate needs a corpus split:
m76 still scores 0.8262, which reads like a mediocre engine rather than one that
cannot parse a whole grammar class.

**The sweep, in full.** `crash` is cases where the engine threw or returned null.
Rows in the LR-broken run sd3–m22 are marked ✗; those scores are not comparable
with the rest.

| engine | score | perfect% | crash | ms | | engine | score | perfect% | crash | ms |
|---|---:|---:|---:|---:|---|---|---:|---:|---:|---:|
| sd3 ✗ | 0.9247 | 63.0 | 4 | 2,446 | | m35 | 0.8948 | 64.9 | 0 | 1,776 |
| sd5 ✗ | 0.8906 | 62.9 | 90 | 2,782 | | m36 | 0.8948 | 64.9 | 0 | 1,628 |
| v6 ✗ | 0.9023 | 62.9 | 55 | 2,271 | | m37 | 0.9551 | 67.2 | 0 | 1,426 |
| m12 ✗ | 0.8810 | 62.9 | 113 | 2,192 | | m38 | 0.9551 | 67.2 | 0 | 1,296 |
| m15 ✗ | 0.8958 | 63.2 | 66 | 2,460 | | m39 | 0.9551 | 67.2 | 0 | 1,332 |
| m16 ✗ | 0.8958 | 63.2 | 66 | 2,167 | | m40 | 0.9551 | 67.2 | 0 | 1,390 |
| m17 ✗ | 0.8974 | 63.2 | 61 | 1,963 | | m42 | 0.9550 | 67.2 | 0 | **1,264** |
| m18 ✗ | 0.8962 | 63.2 | 61 | 1,801 | | m43 | 0.9550 | 67.2 | 0 | 1,290 |
| m19 ✗ | 0.8962 | 63.2 | 61 | 1,863 | | m44 | 0.9550 | 67.2 | 0 | 1,271 |
| m20 ✗ | 0.8962 | 63.2 | 61 | 3,778 | | m45 | 0.9550 | 67.2 | 0 | 1,317 |
| m21 ✗ | 0.8962 | 63.2 | 61 | 3,456 | | m46 | 0.9550 | 67.2 | 0 | 1,312 |
| m22 ✗ | 0.8959 | 63.2 | 63 | 1,977 | | m47 | 0.9550 | 67.2 | 0 | 1,440 |
| m23 | 0.9551 | 67.2 | 0 | 2,142 | | m48 | 0.9550 | 67.2 | 0 | 1,394 |
| m24 | 0.9551 | 67.2 | 0 | 2,129 | | m49 | 0.9550 | 67.2 | 0 | 1,362 |
| m25 | 0.9551 | 67.2 | 0 | 1,576 | | m52 | 0.9550 | 67.2 | 0 | 1,760 |
| m27 | 0.9475 | 62.3 | 0 | 1,721 | | m57 | 0.9548 | 67.1 | 0 | 3,370 |
| m28 | 0.9551 | 67.2 | 0 | 1,634 | | m58 | 0.9549 | 67.2 | 0 | 3,602 |
| m29 | 0.9484 | 62.2 | 0 | 9,964 | | m59 | 0.9550 | 67.2 | 0 | 13,602 |
| m30 | 0.9551 | 67.2 | 0 | 10,690 | | m60 | 0.9550 | 67.2 | 0 | 1,338 |
| m31 | 0.9550 | 67.2 | 0 | 12,006 | | m61 | 0.9550 | 67.2 | 0 | 1,729 |
| m32 | 0.9550 | 67.2 | 0 | 1,721 | | m64 | 0.9550 | 67.2 | 0 | 1,359 |
| m33 | 0.9550 | 67.2 | 0 | 1,694 | | m73 | 0.9550 | 67.2 | 0 | 1,293 |
| m34 | 0.9551 | 67.1 | 0 | 2,911 | | m76 | 0.8262 | 66.8 | **252** | 2,137 |
| m63/66/67/68 | — | — | — | **>180,000** | | **m78** | 0.9444 | **68.4** | 0 | 2,135 |

Three shapes in that data besides the ones already named. The `pegfix` pair m27
(0.9475 / 62.3) and m29 (0.9484 / 62.2) are the only *accuracy* regressions in the
m23–m78 range, which reproduces era-1's "dead ends, m27 → m40" classification on a
corpus it was never tuned against. The `stack` engines m30 and m31 (10,690 and
12,006 ms) plus m59 (13,602) are the latency outliers, at 8–10x their neighbours.
And m35/m36 at 0.8948 are the deepest non-LR accuracy hole in the study — m36 is
the engine era-1 recorded as not doing what it was built for at all.

### The frontier: which engines are still worth considering

With the lineage and the sweep on one battery, and normalised LOC for all of them
(§3.5), the question "which engines are worth keeping in mind" stops being a
judgment and becomes arithmetic. Four axes, all scored: **AST-diff score** (up),
**perfect%** (up), **era-2 battery ms** (down), **normalised recovery LOC**
(down). An engine is worth considering if nothing beats it on every axis at once.

**Tie tolerance matters, so it is stated.** 0.0001 of AST-diff score over 1,824
weighted cases is **0.18 of one case** — 0.9550 and 0.9551 cannot separate two
engines, so score is compared at 3 decimals. And the `ms` column has ~7% spread
within a session (§3.6), so a sub-7% latency gap is not a real difference either;
no domination listed below rests on one. Engines in the LR-broken run sd3–m22 are
excluded (they are broken, not slower), as are the six tape engines that never
finished. m75 and m77 are held out because D1 disqualifies them, and reported
separately.

**Ten engines survive, of 54 compared** (re-computed 2026-08-05 with s1's and
t1's rows; the LOC cache was regenerated in the same run, which moved r9's
normalised count from 536 to 562 — every number below is from that one cache).
t1 survives on latency alone (1,035 ms, the study's record) and dominates
nothing; r13 survives on size alone. **s2 (0.9841 / 77.0 / ~1,600 / 706) is
dominated by s1 at a tied score and is on the record for the defect class it
closes, not for a column** (§4.9).

| engine | score | perfect% | ms | LOC | dominates | why it is on the frontier |
|---|---:|---:|---:|---:|---:|---|
| **s1** | 0.9841 | 77.0 | 1,686 | 697 | 9 | best score and best perfect% in the study; §4.9 |
| **r9** | 0.9748 | 74.0 | 2,038 | 562 | 10 | best score under 600 lines |
| t1 | 0.9326 | 57.7 | **1,035** | 861 | 0 | the latency record; attempt two of the ★TODO claim, §4.9 |
| **m143** | 0.9693 | 72.1 | 1,131 | 628 | 20 | second-best accuracy at near-best latency |
| **m132** | 0.9648 | 69.2 | **1,098** | 612 | 21 | **fastest engine in the study** |
| m26 | 0.9551 | 67.2 | 1,479 | 381 | 19 | survives on one line under m41 |
| m23 | 0.9551 | 67.2 | 2,142 | **370** | 8 | **smallest engine at plateau accuracy** |
| m32 | 0.9550 | 67.2 | 1,721 | 377 | 15 | survives on 4 lines under m26 |
| m41 | 0.9550 | 67.2 | 1,144 | 382 | **36** | plateau accuracy at near-best latency, in 382 lines |
| r13 | 0.9008 | 51.9 | 6,692 | **327** | 0 | **smallest engine that works at all** |

`dominates` is how many of the other 51 that engine beats on all four axes at
once. The whole table is reproduced by `dart/experiments/recovery/pareto.py`,
which takes LOC from `loc.py` rather than restating it; `--exact` switches the
tolerance.

**Forty-four are dominated outright** — beaten on all four axes simultaneously by
at least one of the nine: `dot`, m24, m25, m27, m28, m29, m30, m31, m33, m34,
m35, m36, m37, m38, m39, m40, m42, m43, m44, m45, m46, m47, m48, m49, m50, m51,
m52, m53, m57, m58, m59, m60, m61, m62, m64, m71, m72, m73, m74, m76, m78, m112,
m113, m121. **Eleven of those were once the standard** — `dot`, m50, m51, m53,
m62, m71, m72, m74, m112, m113, m121 — which is half the lineage table.

Four things follow, and three of them are new to the record.

1. **m41 dominates 36 of the other engines** — more than any other engine in
   the study, including the standing ones (m132 dominates 21, m143 20, r9 10,
   s1 9 — a later engine dominates fewer because the survivors it would have to
   beat are on the frontier with it).
   **Twenty-three of them are the contiguous run m42 → m74** — the entire
   relocation series and most of the witness era, beaten on all four axes at once
   by a 382-line engine that predates every one of them. Those engines were bought
   with *conformance* and *derivation*, which this table does not score; on the
   four axes it does score, they are a straight loss.
2. **The 0.957 band is gone, and one engine took all of it.** m112, m113 and m121
   (0.9573–0.9575, 578–582 LOC) are each dominated **by r9 alone** — nothing else
   on the frontier beats any of them. r9 is higher on both accuracy axes,
   2.2–2.3x faster, *and* 42–46 lines smaller. The whole
   `m112 → m121` tree-era refinement is superseded by a single later engine, on
   every axis at the same time.
3. **Obeying D1 now costs nothing, and this is the first time that has been
   true.** m75 (0.9528 / 70.8 / 1,275 / 746) and m77 (0.9609 / 71.5 / 1,389 /
   763) were disqualified for re-parsing, and for a long stretch they were the
   only engines above the perfect% plateau — the disqualification was expensive
   and had to be enforced by a rule rather than by the score. **m143 now dominates
   both on all four axes**: better score, better perfect%, faster, smaller. The
   constraint is no longer a trade-off; the best legal engine simply beats the
   best illegal ones.
4. **The `<400` LOC goal and the accuracy goal have still never been met
   together, and the boundary is sharp.** Twenty engines come in under 400 lines
   and **not one of them exceeds 0.9551**; nothing between 407 and 535 lines does
   either. The best score jumps to 0.9748 exactly at r9's 536. So the gap is
   **0.0197 of AST-diff score for 136 lines**, it is a cliff rather than a slope,
   and 51 swept engines do not narrow it. Anything trying to close it should start
   from what r9 spends its 536 lines on, not from a smaller engine's structure.

**Sensitivity.** Comparing score at 4 decimals instead of 3 admits m37, m38 and
m39 to the frontier — all at 0.9551, surviving only on 0.0001 over m41 and m32,
i.e. on 0.18 of a case. The 3-decimal frontier is the honest one; the 4-decimal
one is recorded here so nobody re-derives it and thinks the table is wrong.

**This table was wrong twice before it was computed rather than read.** The first
version recommended m78 on its perfect% alone; m132 beats it on all four axes. The
second put m112 and m121 on the frontier and described m121 as "surviving by 4
LOC over m112" — both are dominated by r9, whose 536 lines nobody had compared
against their 578–582. Both errors are the same error, and §3.6 records the rule
that came out of it.

**Files.** Engines live in `dart/experiments/recovery/<name>.dart`. Tracked gates
and controls are the `_*.dart` files listed by `git ls-files`; untracked `_*.dart`
are session scratch and may vanish. `final_table.dart` and `_score1.dart` hold the
engine registries. The pure parser is `dart/lib/src/parser/`. Two measurement
scripts are Python rather than Dart and are easy to miss: **`loc.py`** (the LOC
authority, §3.5) and **`pareto.py`** (the frontier, above).

**Controls worth knowing about**, because each one exists to catch a specific
class of self-deception:

| file | what it can see that the score cannot |
|---|---|
| `bf_check.dart` | an error every engine shares (§3.4) |
| `_freespan.dart` | an engine rewarded for deleting input it has no reason to delete |
| `_recommit.dart` | a descent-phrased guard that never actually binds |
| `_portcheck.dart` | how much of an experiment a library port actually got |
| `_tree75.dart` | whether the tree really is over the input (**untracked scratch** — it machine-checked I32 on the now-disqualified m75; rebuild it if needed) |
| `_cmp.dart` | which category a regression lives in, on real failing cases |
| `_crashwho.dart` | an aggregate score hiding a **whole-corpus** failure — it splits score and crash count per grammar. This is what showed m22's deficit is entirely `expr` and that m76 scores 0.0000 on it while still aggregating to 0.8262 |
| `_conf6.dart` | a *pricing* disagreement being read as a *conformance* defect — it asks the frozen parser which repairs of `_conf1`'s only contested probe are in the language, and shows the m-line's cost 2 is reachable only by inventing characters (§3.3) |
| m144 / m145 | the chart's contribution, separated from I81's |

---

# Era-3 archive (appended 2026-08-06, second attic move)

On 2026-08-06 the non-c engines — s1, s4, r9, m132, m143, t1 — were moved
into attic/ as well, and LESSONS_LEARNED.md was condensed to the c-series
record. This section preserves, verbatim, the era-3 material that no longer
lives there: the last full twelve-engine table, the archived lines' detailed
accounts, and the per-engine deltas. These numbers are ERA-3 (fair battery)
and are comparable to the current LESSONS table.

## The last full era-3 table (2026-08-06, one machine, one sweep)

| Engine | Score | Perfect% | ms | LOC | Gates | truncation | deletion | insertion | substitution | misc |
|---|---|---|---|---|---|---|---|---|---|---|
| c6 | 0.9879 | 84.0 | 1490 | 461 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c5 | 0.9878 | 83.9 | 1620 | 535 | all | 0.997 | 0.984 | 0.993 | 0.987 | 0.967 |
| c4 | 0.9878 | 83.9 | 1687 | 566 | all | 0.997 | 0.984 | 0.993 | 0.987 | 0.967 |
| c3 | 0.9829 | 81.2 | 1713 | 515 | all | 0.985 | 0.979 | 0.994 | 0.987 | 0.964 |
| s1 | 0.9825 | 75.2 | 1773 | 697 | all | 0.987 | 0.980 | 0.994 | 0.981 | 0.963 |
| c1 | 0.9818 | 78.6 | 1785 | 493 | all | 0.982 | 0.979 | 0.994 | 0.985 | 0.962 |
| s4 | 0.9818 | 78.6 | 2068 | 480 | all | 0.982 | 0.979 | 0.994 | 0.985 | 0.962 |
| c2 | 0.9812 | 78.5 | 2354 | 454 | all | 0.981 | 0.979 | 0.994 | 0.985 | 0.961 |
| r9 | 0.9704 | 72.9 | 2552 | 562 | all | 0.959 | 0.973 | 0.988 | 0.972 | 0.955 |
| m143 | 0.9658 | 70.5 | 1669 | 628 | recommit 15/16 | 0.932 | 0.978 | 0.988 | 0.981 | 0.953 |
| m132 | 0.9600 | 65.8 | 1597 | 612 | recommit 15/16 | 0.908 | 0.978 | 0.988 | 0.981 | 0.953 |
| t1 | 0.9287 | 55.9 | 1170 | 899 | all | 0.946 | 0.946 | 0.976 | 0.870 | 0.860 |

All twelve rows were verified against the RESTORED freespan probes (the
era-3 curation commit had accidentally emptied `_freespan`'s probe list, so
freespan "passes" recorded between that commit and the restoration were
vacuous; on restoration every kept engine passed with the exact costs
3 3 4 4 1). m143/m132 fail `_recommit` 15/16 on the escape-conjure case.

## The archived lines, in detail (moved verbatim from LESSONS §3)

**dot / m-line (m1–m145; m132, m143 archived with era-3 numbers).** Budgeted
iterative-deepening repair over the memo table. Taught: the budget is the
HORIZON — deleting it is ~100x latency (A3, re-proven in the c-line); the
worklist over cells; per-position generation stamps; and dozens of scoring
laws. Its ceiling: repairs judged per-round without whole-document rivalry,
and truncation (0.91–0.93) — it cannot afford deep completion spines.
m143 still fails `_recommit` on the escape-conjure swallow.

**r-line (r1–r13; r9 archived with era-3 numbers).** The chart engine:
whole-document rival readings priced simultaneously. Taught: judgment must
be simultaneous (greedy per-commit repair provably cannot order a cheap fill
against a dear denial — its correct choice depends on repairs not yet
made); the give-up exclusion; the swallow toll. Its ceiling: the chart
re-derives per round what the parse already computed once.

**t/b-lines (t1 archived with era-3 numbers).** t1: recovery walking the
enriched mismatch tree, memo as repair channel — the latency record
(1,170 ms) and proof the tree's sideways signal is sound; but the tree
holds each committed reading's FIRST failure, while recovery's information
is every REJECTED reading (I98). b1/b2: the explicit two-mode architecture
(parse until stuck, breadth-first widening, commit, resume) — proved
classes can decide D8 with no pricing at all, and hit the greedy-commit
wall at 0.88.

**s-line (s1–s4; s1, s4 archived with era-3 numbers).** The way-algebra:
one costed descent, every clause returns rival priced readings, a budget
ladder, a six-part global judgment. s1 = the explicit four-mechanism form
(I94–I97); s3/s4 = the collapse (fills emerge from the descent; a literal
is a sequence; a move is a resync at slot 0) at 480 lines. The c-line is
this algebra rebuilt on better substrate.

## Archived-engine deltas (moved verbatim from LESSONS §5)

- **c1 vs s4**: identical judgment, near-identical results; c1 adds the
  budget-zero collapse (17% faster at era-2) and the fill-cache. s4 is the
  smallest s-form; c1 the faster restatement.
- **s1**: the explicit-mechanism reference (alignment table, spine
  emitter, owed-slot machinery as separate code). On the fair battery it
  holds nothing the c-line lacks; its era-2 edge was tie-luck plus
  over-demanding truncation expectations.
- **m143/m132**: the budgeted-deepening reference points — fast, sturdy,
  and structurally unable to afford deep completion spines (truncation
  0.91–0.93); both fail `_recommit` by one case (the escape-conjure).
- **t1**: the latency record and the proof of the mismatch-tree channel;
  concedes ~0.06 score.

## Ledger rows about mechanisms that no longer exist

| Claim | Verdict |
|---|---|
| Vouch 0 for anonymous frozen spans | tolls the honest reading, shields the swallow: −25 quote-delete cases (vouch itself was deleted by c5/I108; the general lesson — judge frozen and enumerated spans symmetrically — lives on in the derived swallow) |
