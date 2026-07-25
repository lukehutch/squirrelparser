# Lessons Learned — Squirrel Parser Error Recovery

Running record of what was tried, what was measured, what was refuted, and how to
work on this codebase. Kept updated as work proceeds. Everything numeric here was
measured, not estimated; anything inferred is labelled as such.

## 1. Hard constraints (do not violate)

- **Recovery lives OUTSIDE the pure parser.** The parser is an *oracle only*,
  reached via `Parser.match(Clause, int pos)` and `Parser.parse()`. No recovery
  concept (spans, budgets, costs) may leak into the parsing core. The pure-core
  rollback that established this is the reference state of `dart/`.
- **Zero tuning parameters.** A recovery method with a knob is a regression, not
  a trade-off. Every constant in the winning design is *derived* (see §4).
- **Dart is the reference implementation.** The Java, Python and TypeScript trees
  are contaminated by an earlier attempt and are deliberately left uncommitted
  until the Dart core is settled and ported.
- Run Dart from `dart/`:
  `dart --packages=<repo>/dart/.dart_tool/package_config.json <file>.dart`.
  `dart analyze` is useless on scratch experiment files (package URIs
  unresolvable) — the only way to check them is to run them.

## 2. The benchmark

The 519-mutant battery: every single-edit mutant (delete, insert, substitute,
transpose at every position, insertions drawn from `Q z } " , 5`) of

```
{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}
```

that the pure parser rejects. Four metrics, all of which must be reported together:

| metric | meaning | why it matters |
|---|---|---|
| **shape** | recovered tree's nesting of structural `Ref` nodes equals the original's | the real accuracy score; "it produced a tree" is not success |
| **cover** | terminals + error spans tile `[0, len)` exactly | catches trees that silently drop input |
| **cost** | edit-distance histogram of the chosen repair | must be `{1: 503, 2: 16}`; a better shape score at higher cost is cheating |
| **valid** | the 7 well-formed documents must be returned untouched | recovery must be inert on correct input |

Latency is measured separately on 12 synthetic cases (DEL/INS/SCRAM at 4/16/64
chars, plus one typo at n=145/530/2114), min-of-N, **all engines alternating in a
single process** so none gets a systematically colder heap. Battery wall time and
per-case latency measure different things — a method can win one and lose the other.

## 3. The axioms

The current winner (`m26`) is derived from five axioms and nothing else. Each one
deletes a category of code rather than compressing it.

**A1 — A repair is a string in the language plus an alignment.** There are exactly
three edit primitives, and they are Levenshtein's lifted from strings to a
language: **SUB** (a terminal consumes a character it does not accept), **FAB** (a
terminal consumes nothing — an insertion into the input), **SKIP** (a character is
consumed by no terminal — a deletion), each cost 1, plus the non-edit **MATCH**,
cost 0. *Consequence:* min-cost repair = Levenshtein distance from the input to the
nearest member of L(G), which is an independently checkable claim — see §11.

**A1 also makes SKIP a unit edge.** A j-character span costs
`j·M + 2·Σh` which is exactly `Σ_{i<j}(M + 2h(p+i))` — perfectly additive — so a
span is j traversals of a *unit self-loop on the dot*. The loop over span lengths
that m15 and m16 both carry is not a primitive; it is a hand-unrolled path.
Deleting it is a **complexity reduction, not a micro-optimisation**: the j-loop
re-enumerated every span length from every state, whereas unit edges let the memo
share the skip prefix. Measured: SCRAM-64 halved, 487 ms → 251 ms.

**A2 — Among min-cost repairs, prefer the least unjustified information.**
`regret = Σ_kept w(class) + 2·Σ_skipped h(char)`. The factor 2 is derived (§4).

**A3 — Order by one integer.** `Δ = cost·M + regret` with `M` above any achievable
regret, so min-Δ-per-end *is* min-cost, and the budget is a **filter on that
integer, not a memo key** — one memo serves every iterative-deepening round.
`b == 0` is then exactly one memoized pure-parser oracle call, so clean subtrees
are O(1). This is why the method is fast on nearly-correct input.

**A4 — Only a sequence has a "between".** A gap is by definition text *between*
two consumed regions; the region separating two adjacent consuming leaves attaches
at their lowest common ancestor, which is always a `Seq` or a `Repetition` — a
`First` has no two consecutive children. So every gap has a **unique canonical
attachment point**, and `First`/`Optional`/`Ref`/predicates need no recovery logic
whatsoever. *What A4 deleted, measured against m16:* the dot-state array, the
ascending sweep, the arcs table, `_dots`/`_to`/`_accepts`/`_sink`. **The recursion
is the dot.** Making the item `(clause, dot)` a first-class memo key removes the
need for a dot-state array, a sweep, and an arcs table simultaneously.

**A5 — Left recursion is not a recovery problem; the parser already solved it.**
`MemoEntry.match` (40 lines in `lib/src/parser/memo_entry.dart`) seeds a re-entered
`(rule, pos)` with a mismatch, sets `foundLeftRec`, and re-matches the ancestral
frame while the result keeps growing, bumping `memoVersion[pos]` to invalidate
stale memos at that position only. Recovery is *the same recurrence over a wider
value* — a map from end position to minimum Δ instead of a single match — so it
inherits left recursion by adopting that memo rule **verbatim, field for field**.
The fixed-point test "the match did not get longer" becomes "no end is new and no
Δ got smaller"; the seed `mismatch` becomes the empty ends map. There is no second
mechanism and no recovery-specific reasoning about cycles anywhere.

A5 was **not** optional politeness — see §8, where its absence was a live
correctness bug that the whole JSON battery was structurally unable to see.

Two consequences of A5 worth stating separately:

- **One entry object, not four parallel tables.** Because the state is exactly
  `MemoEntry`'s, it belongs in one object per item (`_Entry`), not in four maps
  keyed by the same int. That is also why it is fast: one hash lookup per query
  instead of one per field. Measured: it paid back the entire 16% that left-recursion
  correctness had cost (m24 0.66× → m25 0.64× → m26 0.56×).
- **Every diagnostic is read off the finished tree.** A SKIP is a `SyntaxError`
  leaf, a FAB is a zero-width terminal leaf, a SUB is a terminal leaf the parser
  does not accept there. Reading them afterwards instead of recording them as the
  descent decides is what lets the descent **abandon a branch freely** — there is
  nothing to un-record — so the cycle guard costs no bookkeeping. This deleted a
  whole concept (`_try`, snapshot-and-restore of the diagnostic lists) and kept the
  cost histogram bit-identical.

### The earlier design (m15/m16), kept for the record

Three collapses, each deleting a category of code rather than compressing it:

1. **A repair is a parse whose value is one integer.** `Δ = cost·M + regret`.
   Because `M` exceeds any achievable regret, ordering by Δ orders cost first,
   so *min-Δ-per-end is exactly min-cost*. The two-key comparison, its
   tie-breaking, and its tuple plumbing all collapse to `int`.
2. **The budget is a filter, not a memo key.** A result computed at budget `B`
   filters exactly to any `b ≤ B`, so **one** memo serves every
   iterative-deepening round. `b == 0` then means exactly one memoized
   pure-parser call, making every clean subtree O(1) — this is why the method is
   fast on nearly-correct input, which is the common case.
3. **Every composite clause is the same machine over "dot" states.** One table
   `_arcs(c, dot)`: `Seq` is a chain, `First` is parallel arcs from dot 0,
   `Optional` is one arc plus accept, `Repetition` is a self-loop. The *path
   through the machine is the child list*, so one descent reconstructs all four
   types. Both per-clause-type switches — search **and** reconstruction —
   disappear. `FAB` (fabricate) is not a separate move; it is a Terminal move
   that advances zero characters, which is why the `minLen` machinery was
   deletable.

And the load-bearing performance insight: **the state index is its own
topological order.** `dot*width + (p − pos)` strictly increases along every arc,
so a single ascending sweep over a dense `Int64List` finalizes each state on one
expansion. No queue, no priority structure, no fixpoint iteration, no round cap,
no no-progress guard. (Contributed by the parallel Codex line; the array holds
`Δ+1` so the native zero-fill means "unset" — worth ~6% over a `List<int?>`,
which must be null-filled once per composite clause per position.)

Two smaller results worth keeping:

- **Witness tie-break: prefer the shortest head.** Among Δ-tied decompositions,
  take the smallest head end (ascending sort of candidate ends). Worth **+6
  shape points** (511 → 517). This is *not expressible in a backward predecessor
  walk*, which fixes the tail first and caps at 516 — the reason the final design
  reconstructs by forward descent.
- **`threshold` identity:** `_cost(total) > b` ⟺ `total ≥ (b+1)·M` (valid because
  regret < M), which hoists an integer division out of the hottest line.

## 4. The factor 2 is derived, not a knob

Two regret formulations are the *same objective up to an additive constant*.
Writing K for kept and D for discarded positions:

- deviation form: `Σ_K (w − h) + Σ_D h`
- absolute form: `Σ_K w + 2·Σ_D h`
- difference: `Σ_K h + Σ_D h = Σ_all h` — a constant, independent of the split.

Charging `w` instead of `w − h` pre-charges every character one `h`, so a
discarded character must pay its `h` twice. `FAB` consumes no character and
correctly takes no `h` in either scheme. **Empirically confirmed on all 519
inputs: 0 cost disagreements, 0 regret disagreements.** Removing the 2 while
keeping absolute width costs 9 shape points (517 → 508), which is what a genuinely
mis-set constant looks like — the identity is why this one is not one.

## 5. Measured results

All engines on the identical 519-mutant battery. Shape is the accuracy score;
battery ms is total wall time over all 519 recoveries in one process.

| engine | LOC | shape | ins | sub | del | swap | cover | cost | battery ms |
|---|---|---|---|---|---|---|---|---|---|
| **m26** (A1–A5; **left recursion correct**) | **382** | **517/519** | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | **409** |
| m25 (entry object) | 394 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 405 |
| m24 (total reconstruction) | 393 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 573 |
| m23 (A5, four parallel tables) | 371 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | — |
| m22 (goal wrapper) — **LR-broken** | 337 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 464 |
| m19 (unions unified) — LR-broken | 362 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 445 |
| m18 (axiomatic A1–A4) — LR-broken | 373 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 466 |
| m17 (m16 + unit skip edge) — LR-broken | 357 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 427 |
| **m16** (absolute pricing) — LR-broken | **352** | **517/519** | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | **439** |
| **m15** (deviation pricing) — LR-broken | **406** | **517/519** | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 533 |
| m21 (rejected: record memo value) | 361 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 898 |
| m20 (rejected: record memo key) | 350 | 517/519 | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 1086 |
| m12b (predecessor walk + typed array) | 398 | 516/519 | 216/216 | 224/224 | 35/37 | 41/42 | 519/519 | ✓ | 486 |
| m12 (predecessor walk) | 396 | 516/519 | 216/216 | 224/224 | 35/37 | 41/42 | 519/519 | ✓ | 526 |
| `dot` (shipped, `lib/src/recovery/`) | 797 | 515/519 | 216/216 | 224/224 | 35/37 | 40/42 | 519/519 | ✓ | 7522 |
| sd6 / "v6" (baseline) | 526 | 512/519 | 216/216 | 220/224 | 35/37 | 41/42 | 519/519 | ✓ | 522 |
| sd5 | 513 | 512/519 | 216/216 | 220/224 | 35/37 | 41/42 | 519/519 | ✓ | 539 |
| sd3 | 499 | 512/519 | 216/216 | 220/224 | 35/37 | 41/42 | 519/519 | ✓ | 491 |
| `search` (RepairSearch) | — | 490/519 | 211/216 | 204/224 | 34/37 | 41/42 | n/a | — | 5202 |
| `semiring` | — | 469/519 | 202/216 | 193/224 | 34/37 | 40/42 | 519/519 | — | 55742 |
| `agenda` | — | 469/519 | 202/216 | 193/224 | 34/37 | 40/42 | 519/519 | — | 5496 |
| `frontier` | — | 466/519 | 202/216 | 193/224 | 32/37 | 39/42 | 519/519 | — | 5802 |
| `skip` | — | 426/519 | 197/216 | 175/224 | 29/37 | 25/42 | 519/519 | — | 1499 |

`cover` is not applicable to `search`: its tree spans a *rewritten* string, not
the mutant, so the tiling invariant does not hold. All engines: 0 crashes,
0 declined repairs.

Per-case latency (min-of-5, alternating in one process, ms):

| case | n | cost | dot | v6 | m15 | m16 | dot/v6 | m15/v6 | m16/v6 |
|---|---|---|---|---|---|---|---|---|---|
| DEL-4 | 133 | 2 | 197.0 | 9.7 | 4.2 | 4.0 | 20.3× | 0.44× | 0.41× |
| INS-4 | 141 | 2 | 191.6 | 4.3 | 4.2 | 3.1 | 44.9× | 0.99× | 0.74× |
| SCRAM-4 | 137 | 1 | 70.1 | 1.1 | 1.7 | 0.9 | 64.9× | 1.54× | 0.85× |
| DEL-16 | 121 | 1 | 58.3 | 0.9 | 1.2 | 1.1 | 65.1× | 1.34× | 1.22× |
| INS-16 | 153 | 2 | 228.1 | 2.6 | 3.9 | 3.8 | 86.1× | 1.46× | 1.42× |
| SCRAM-16 | 137 | 4 | 946.8 | 15.8 | 20.7 | 18.0 | 60.0× | 1.31× | 1.14× |
| DEL-64 | 73 | 2 | 73.4 | 2.3 | 2.8 | 2.6 | 32.0× | 1.22× | 1.15× |
| INS-64 | 201 | 2 | 362.7 | 3.1 | 5.8 | 5.7 | 115.3× | 1.84× | 1.81× |
| SCRAM-64 | 137 | 10 | 3315.5 | 492.8 | 466.2 | 525.5 | 6.7× | 0.95× | 1.07× |
| 1typo-n145 | 145 | 1 | 70.6 | 1.6 | 2.1 | 1.6 | 44.9× | 1.35× | 1.04× |
| 1typo-n530 | 530 | 1 | 430.8 | 5.9 | 10.6 | 7.6 | 72.5× | 1.78× | 1.29× |
| 1typo-n2114 | 2114 | 0 | 0.6 | 0.6 | 0.6 | 0.6 | 1.00× | 1.00× | 0.98× |
| **TOTAL** | | | **5945.6** | **540.8** | **524.0** | **574.7** | **10.99×** | **0.97×** | **1.06×** |

Latency of the A1–A5 line, same protocol (min-of-5, alternating in one process),
ratios against the v6 baseline:

| case | n | cost | v6 | m16 | m22 | m25 | m26 | m16/v6 | m22/v6 | m25/v6 | m26/v6 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| DEL-4 | 133 | 2 | 7.5 | 3.7 | 2.3 | 2.6 | 3.0 | 0.49× | 0.31× | 0.34× | 0.40× |
| INS-4 | 141 | 2 | 2.0 | 2.6 | 2.3 | 2.0 | 2.0 | 1.31× | 1.13× | 0.98× | 0.98× |
| SCRAM-4 | 137 | 1 | 0.6 | 0.7 | 0.7 | 0.6 | 0.6 | 1.25× | 1.30× | 1.05× | 1.06× |
| DEL-16 | 121 | 1 | 0.5 | 0.7 | 0.7 | 0.6 | 0.6 | 1.23× | 1.34× | 1.06× | 1.09× |
| INS-16 | 153 | 2 | 2.1 | 2.9 | 2.5 | 2.1 | 2.1 | 1.33× | 1.16× | 0.99× | 1.00× |
| SCRAM-16 | 137 | 4 | 12.4 | 16.6 | 11.8 | 10.8 | 10.5 | 1.34× | 0.95× | 0.87× | 0.85× |
| DEL-64 | 73 | 2 | 1.9 | 2.4 | 2.2 | 1.9 | 1.9 | 1.26× | 1.18× | 1.01× | 1.03× |
| INS-64 | 201 | 2 | 2.4 | 3.4 | 3.6 | 3.1 | 3.2 | 1.40× | 1.49× | 1.28× | 1.29× |
| SCRAM-64 | 137 | 10 | 444.2 | 466.6 | 243.1 | 258.5 | 237.4 | 1.05× | 0.55× | 0.58× | **0.53×** |
| 1typo-n145 | 145 | 1 | 1.2 | 1.8 | 1.3 | 1.1 | 1.1 | 1.54× | 1.16× | 0.93× | 0.94× |
| 1typo-n530 | 530 | 1 | 3.7 | 6.7 | 6.1 | 4.2 | 5.0 | 1.84× | 1.66× | 1.15× | 1.37× |
| 1typo-n2114 | 2114 | 0 | 0.7 | 0.8 | 0.8 | 0.7 | 0.7 | 1.14× | 1.20× | 1.02× | 1.12× |
| **TOTAL** | | | **479.3** | **508.8** | **277.6** | **288.2** | **268.2** | 1.06× | 0.58× | 0.60× | **0.56×** |

**m26 dominates m15, m16 and m22 simultaneously**: fastest overall (0.56×) and on
the deep-budget worst case (0.53×), same 517/519 shape, same cost histogram, and
correct on left recursion where all three predecessors are not. The m15-vs-m16
trade-off was dissolved rather than balanced. Its one deficit is line count: 382
vs m22's 337, and those 45 lines are what left-recursion correctness and a total
(never-throwing) reconstruction cost.

**Reading the m15/m16 trade-off honestly.** The total is dominated by SCRAM-64 (~490 of
~540 ms), the one deep-budget case, so *the totals mostly report that one case*.
Across four repeated runs, m15 lands at 0.96–1.00× of v6 total and 0.93–0.98× on
SCRAM-64; m16 lands at 0.99–1.06× total, being **cheaper on 11 of 12 cases**
(0.41–1.42×) but 1.01–1.12× on SCRAM-64. m16's deep-budget gap is
**unattributed** — ruled out by ablation: the forward descent (m15 shares it and
is at parity), the typed array (m16d reverts it: 517/519, 459 ms), and the
unconditional pure-parse probe (m16e gates it on `_cost(d)==0`: still 1.04–1.08×).
The named-but-unbuilt fix is a suffix-value pass (one descending sweep so the
descent looks up the remainder instead of re-sweeping, killing an O(n²) in long
Repetition chains), estimated ~+18 lines.

The `1typo-n2114` row is the important one for real use: on a large document with
one typo, every engine including `dot` is sub-millisecond, because cost-0 subtrees
are O(1). Recovery cost tracks the *amount of damage*, not the document size.

Both 517 variants miss exactly `del@13` and `swap@13`, which `dot` also misses.

## 6. Refuted — do not re-litigate

Each of these was built and measured, not reasoned away:

| idea | result |
|---|---|
| `<100` LOC with accuracy intact | not achievable; see §7 |
| drop regret entirely | −32 shape points |
| cost-only regret | 465/519 |
| keep-loss-only regret | 472/519 |
| factor-1 with absolute width | 508/519 |
| descending-head witness tie-break | 511/519 |
| latest-predecessor sweep tie (`cur < tot`) | 511/519 |
| one shared budget across subtrees | catastrophic: 3/519 |
| record as memo key (`Map<(Clause,int,int), …>`) | 445 → 1086 ms, 2.4× slower |
| record as memo value (`Map<int, (int, Map<int,int>)>`) | 898 ms, 2.0× slower — a record allocated per memo write |
| ~~`Seq([top, Nothing])` root wrapper~~ | **REFUTATION WITHDRAWN — see below** |
| reparse-the-repaired-text (delete tree reconstruction) | cover 398/519 naive; deduped version 466 lines and 1.14× slower — the traceback just moves, it does not vanish |
| position-ordered chart | superseded by index-as-topological-order |
| hoisting SPAN out of Seq position 0 | breaks minimality |
| full-width span pricing | worse |
| CPS bounded DFS | slower |
| v5 filter-without-reuse | slower |
| eager axioms | slower |
| frontier sweep without key ordering | wrong |
| `SplayTreeMap` vs list queue | slower |

**A withdrawn refutation, and the lesson in it.** `Seq([top, Nothing])` as the goal
clause was measured at 510/519 and 1.15× slower, and was recorded here as refuted.
That verdict was **against the j-loop engine**. With SKIP as a unit edge (A1), the
same wrapper holds 517/519 *and* deletes 25 lines: skip at dot 0 is the leading
garbage, skip at dot 1 is the trailing garbage, both from the universal rule, so
no bespoke lead/trail arithmetic exists anywhere — and the shortest-head preference
at dot 0 *is* the smallest-extent tie-break, because the head at dot 0 is the top
rule itself.

**Lesson: a refutation is only valid against the engine it was measured on.** When
a primitive changes, every idea previously rejected *because of* that primitive is
back on the table. Re-run the refuted list after any change to the core recurrence.

## 7. On line-count as a target

The stated goal was "under 100 LOC". It is not honestly reachable with accuracy
intact, and the evidence is specific:

- The parallel Codex line independently reached **411 conventionally-formatted
  lines** as its floor, and independently refuted the same alternatives.
- Its 83-line file was disclosed by its own author as "token-preserving
  whitespace compaction". Verified by token diff against the 411-line file:
  **3850 vs 3856 tokens**, first difference at token 3634 — the 83-line file *is*
  the 411-line program with newlines removed plus a 6-token bug fix.
- The regret machinery alone is ~92 lines and deleting it costs 32 shape points;
  a real tree root is required, so reconstruction cannot simply be dropped.

**Lesson: an `awk` line count is gameable by joining lines; concept count is not.**
The honest result is 352 lines at *higher* accuracy (517 vs 512) — a 33% reduction
from the 526-line baseline with +5 shape and no loss on 11 of 12 latency cases —
which is below the independently-derived structural floor. Report the concept
reduction, not the character count.

## 8. Bugs found

- **Empty-input `RangeError`** in v6 and both winners: the leading-span loop ran
  to the budget without bounding by input length. Fixed at both sites in `sd6`
  and in m15/m16 with `&& lead <= _n`. All three now return cost 1 (fabricate the
  minimal document) on `""`, and agree on all 10 degenerate inputs
  (`"" " " { } [ x {"a" "" {} []`). Found only because a degenerate-input gate was
  written *separately* from the mutation battery — a battery built by mutating a
  valid document can never produce the empty string.

- **Non-minimal repairs on left-recursive grammars** (every engine up to and
  including m22). The memo's reentrancy guard cached the in-progress placeholder as
  a final answer, so the left-recursive alternative contributed *nothing* and the
  engine silently returned the best non-left-recursive repair. On `E <- E '+' T / T`
  the measured costs were 2 or 3 where the truth is 1; on the **equivalent
  right-recursive grammar the same engine is perfect**, which is the proof that the
  grammar shape and not the input was responsible.

  This is the most serious defect found in the project, for three reasons: (i) left
  recursion is the parser's headline feature, so a recovery layer that degrades on
  it would sink the paper's claim; (ii) clean input hid it completely, because
  `b == 0` routes to a single pure-parser oracle call and *the parser is correct* —
  only the engine's own recursion at `b ≥ 1` was broken; (iii) **the entire
  519-mutant battery was structurally unable to see it**, because the JSON grammar
  is not left-recursive. Fixed by A5 (§3).

- **Reconstruction diverged on nullable left recursion.** With `E <- E N` and `N`
  nullable, `E` can re-derive itself over the same extent at zero extra Δ, so the
  Δ-exact forward descent took that cycle forever (`StackOverflowError`) even though
  the *cost* was correct. Fixed by giving reconstruction the same re-entry guard the
  parser uses — which required making it total (return null, not throw) so a branch
  can be abandoned. Every cycle in a clause graph passes through a `Ref`, because a
  clause tree is finite and a `Ref` is its only back edge, so guarding `Ref`s is
  sufficient. This case was *predicted from the mechanism and then written as a
  test*, not stumbled upon.

## 8a. Ground truth: the only gate that can catch a shared error

Every engine had been checked against every *other* engine, which cannot catch an
error they share — and the reentrancy guard was exactly such an error.
`bf_check.dart` computes the true minimum edit distance by breadth-first search
over single-character edits, asking the pure parser whether each candidate is in
L(G). Slow and stupid, and therefore trustworthy. It is a direct test of A1: min
cost *should* equal Levenshtein distance to the nearest member of the language.

Current status — **m26 agrees on 44/44 across five grammars and rebuilds a covering
tree for each**:

| grammar | inputs | m16 | m22 | m26 |
|---|---|---|---|---|
| directly left-recursive expr | 10 | 6/10 | 6/10 | **10/10** |
| right-recursive expr (same language) | 10 | 10/10 | 10/10 | **10/10** |
| indirectly left-recursive (`E→A→B→E`) | 8 | 6/8 | 6/8 | **8/8** |
| nullable left recursion | 6 | 6/6 | 6/6 | **6/6** |
| tiny JSON | 10 | 10/10 | 10/10 | **10/10** |

`lr_scale.dart` then checks that the fixed point stays cheap at scale, since every
correctness case above is at most 8 characters. On a left-leaning spine with one
spurious operator, m26 costs 2.0 / 2.7 / 3.5 / 7.4 ms at n = 32 / 64 / 128 / 256,
and agrees with the equivalent right-recursive grammar on cost at every size. Left
recursion costs a **stable 2.6-3.1x multiplier** over the right-recursive form --
the price of cycle expansion, not a blowup.

**Lesson: differential testing between your own variants proves agreement, not
correctness.** Build one oracle that shares no code with any of them, however
slow — and choose its test grammars to vary the *structural feature* your engines
special-case, not just the inputs.

## 9. Process lessons

- **Never edit source by blind index-slicing.** Use the editing tool. When
  scripting an edit, assert the match count *before* writing.
- **A partial `sed` is a silently wrong experiment.** A factor-2 ablation via
  `sed` matched 2 of 5 sites and produced 514/519 — a *mixed pricing*, not an
  ablation. Caught by grepping the remaining count. Always verify the
  substitution count equals the site count before believing the number.
- **A parallel agent will delete and rewrite its own files mid-flight.** A file
  that was the parent of a merged variant vanished, destroying an A/B baseline.
  Copy anything you depend on to a name the other process is told not to touch.
- **Scratchpad directories are ephemeral.** Work that matters must be committed
  or copied into the repo; `/tmp` results that took an hour to measure are gone
  on reboot.
- **Report the axis you did not win.** Every table above states battery time and
  per-case latency separately, because a method that wins the battery can lose the
  latency case that actually matters, and vice versa.
- Sanity-check the harness output you grep: several gate files print a `dot`
  reference row *before* the row under test, and grepping the first line silently
  reports the baseline for every variant. Caught it because six *different* files
  reported byte-identical numbers.
- **A `sed`-derived gate can measure the wrong engine.** Copying a harness with
  `sed 's/m16/m22/'` did not rebind the import alias, so the output still reported
  m16 while claiming to be m22. Same failure class as the partial-`sed` ablation
  above. Write the new harness fresh, or assert the substitution count.
- **Measure the optimisation you assume is free.** Two "obvious" cleanups (record
  as memo key, record as memo value) were 2.4× and 2.0× *slower*; the ugly-looking
  int-keyed form is genuinely the fast one. Conversely, consolidating four parallel
  tables into one entry object was assumed to be a wash and paid back 16%.

## 10. Open items

1. Promote `m26` into `dart/lib/src/recovery/` and add real test coverage,
   including `bf_check`'s grammars as unit tests. `dart test` is 308/308.
   (The left-recursion half of this item is **done** — and it found the §8 bug.)
2. ~~Build the suffix-value pass to close m16's deep-budget gap.~~ Obsoleted: unit
   skip edges (A1) closed it outright — m26 is 0.53× v6 on SCRAM-64, where m16 was
   1.05×.
3. Incremental re-parse: reuse memo entries whose spans precede the first edit
   (see `ERROR_RECOVERY_DESIGN.md` §8.1).
4. Port the pure core + the chosen recovery module to Java, Python, TypeScript.
5. `del@13` / `swap@13` remain unrecovered by every engine — the only known
   accuracy ceiling on this battery.
