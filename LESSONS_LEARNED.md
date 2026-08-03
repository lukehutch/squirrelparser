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

**Where things stand, in four lines (2026-08-03).** The standing engine is **r9**
(0.9748 AST-diff, 74.0% perfect, 536 lines); the standing `m`-engine is **m143**.
Of ~150 engines built, **eight are still worth considering** — everything else is
beaten on every scored axis at once, including eleven engines that were the
standard in their day (Appendix, "The frontier"). **r9 passes every gate** — all
re-run 2026-08-03: acceptance 3/3, free-span, recommit 16/16, zero conformance
free passes, core gate pass, library suite 320/320 — **and m143 does not**,
failing one recommit case (§3.3). **Latency is the one unmet goal** at 2.16x
target, and "under 400 lines"
has never been met at the same time as the accuracy goal — the gap is 0.0197 of
score for 136 lines, and it is a cliff, not a slope (Part VII, items 2–3).

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
| 10 | *"right now a mismatch object is stored in a memo entry, and it could even be the same undifferentiated mismatch object for all mismatches, because it's just a tombstone, and it has no length information... Instead, make a new mismatch object for each new mismatch, and inside the mismatch object, encode the length that was consumed by subclause matches (or subclause mismatches) before this clause was found to not match -- and also store the subclause match or mismatch nodes inside the mismatch object."* | The "the parser core is frozen" assumption held for the entire project up to that point. This is the **first change to `dart/lib/src/parser`** in the whole line of work (§2.5). |
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
  has found real defects (§4.9) and it has also been wrong; treat its findings as
  hypotheses until confirmed by an own probe.

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

Steer #10 (§1.5). Every mismatch is now a fresh object carrying:

- the **length consumed** by subclause matches (or subclause mismatches) before
  this clause was found not to match, and
- the **subclause match or mismatch nodes** underneath it.

This is what makes the `r`-series brief's iterative widening implementable: an
*exact* frontier can be read off the mismatch tree instead of re-derived.

**Two sentinel sites bit during the change**, both because `-1` had been doing
double duty as "no match" and as "shorter than everything":

1. The fixed-point comparison above.
2. The left-recursive seed, which was still an undifferentiated tombstone.

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

| gate | r9 | m143 | m132 |
|---|---|---|---|
| `_accept` | **PASS** `cx2=1 b1=1 b2=1` | **PASS** `cx2=1 b1=1 b2=1` | **PASS** `cx2=1 b1=1 b2=1` |
| `_freespan` | **PASS** | **PASS** | **PASS** |
| `_recommit` | **PASS** 16/16 | **FAIL** 15/16 | **FAIL** 15/16 |
| `_conf1` free passes | **0** | **0** | **0** |

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

## 4.9 What the Codex checks found

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
| charging absorption **per slot** | **refuted — a price charged at a slot is evadable by moving the slot** (re-pairing dodges it); per *node* charges the same span again at every `Ref` above it |

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
| stepping the budget by 1, or to 4 before doubling | 1049 / 880 ms vs doubling's 895 — the simplest schedule is already the fastest measured |
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

1. **The `reach` fork (from steer #10).** `dart/lib` currently keeps the cheap
   half of the mismatch-frontier change: its mismatch tree reproduces `_core2`'s
   `reach` on **27.9%** of battery cases. Adopting `reach` — a watermark on every
   node, including matched ones — gives **100% frontier fidelity for about 1.5x
   pure-parse time**. This is a genuine trade, not an oversight, and it is the
   owner's call. Measured by `_portcheck.dart` (tracked).
2. **Latency is the only unmet goal.** 2.16x against target. The time is in
   budget-1 and a 25-case tail; the semi-naive chart both analyses proposed is
   refuted (§6.4). **And the two instruments have never been bridged**: the `ms`
   column everywhere in this document is *whole-battery* time for 1,824 weighted
   cases, while the "sub-250 ms" goal is *per-parse* latency on one document.
   Ranking engines by battery ms is sound — it is the same instrument for all of
   them — but no arithmetic converts it into the goal's units, and none is
   attempted here. Any claim that a given engine "meets" or "misses" 250 ms has to
   come from the per-parse harness, not from the tables.
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
    one instance survives. r9 is the only `r` engine the gate covers and it passes
    16/16, so this does not touch the standing engine; it is an open defect in the
    `m`-line that anyone building on m143 inherits, and it was not in the record
    before 2026-08-03.

---

# APPENDIX — WHERE THINGS STAND

| | engine | score | perfect% | ms | LOC (recovery) | notes |
|---|---|---:|---:|---:|---:|---|
| standing `r`-engine, and best overall | **r9** | 0.9748 | 74.0 | 2,038 | 536 | unchanged by the 2026-08 core change |
| standing `m`-engine | **m143** | 0.9693 | 72.1 | 1,131 | 628 | I81 + I82 |
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
| **r9** | **0.9748** | **74.0** | **2,038** | **standing engine, best overall** |

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

**Eight engines survive, of 52 compared.**

| engine | score | perfect% | ms | LOC | dominates | why it is on the frontier |
|---|---:|---:|---:|---:|---:|---|
| **r9** | 0.9748 | 74.0 | 2,038 | 536 | 10 | best score and best perfect% in the study, and the smallest engine above 0.96 |
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
at least one of the eight: `dot`, m24, m25, m27, m28, m29, m30, m31, m33, m34,
m35, m36, m37, m38, m39, m40, m42, m43, m44, m45, m46, m47, m48, m49, m50, m51,
m52, m53, m57, m58, m59, m60, m61, m62, m64, m71, m72, m73, m74, m76, m78, m112,
m113, m121. **Eleven of those were once the standard** — `dot`, m50, m51, m53,
m62, m71, m72, m74, m112, m113, m121 — which is half the lineage table.

Four things follow, and three of them are new to the record.

1. **m41 dominates 36 of the 51 other engines** — more than any other engine in
   the study, including the standing ones (m132 dominates 21, m143 20, r9 10).
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
