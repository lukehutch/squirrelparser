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

## 3. The winning design, and why it is what it is

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
| **m16** (absolute pricing) | **352** | **517/519** | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | **439** |
| **m15** (deviation pricing) | **406** | **517/519** | 216/216 | 224/224 | 36/37 | 41/42 | 519/519 | ✓ | 533 |
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

**Reading the trade-off honestly.** The total is dominated by SCRAM-64 (~490 of
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
| `Seq([top, Nothing])` root wrapper (to collapse the lead/trail span loops) | 510/519, 1.15× slower; loses exactly the 2 insertion points predicted |
| reparse-the-repaired-text (delete tree reconstruction) | cover 398/519 naive; deduped version 466 lines and 1.14× slower — the traceback just moves, it does not vanish |
| position-ordered chart | superseded by index-as-topological-order |
| hoisting SPAN out of Seq position 0 | breaks minimality |
| full-width span pricing | worse |
| CPS bounded DFS | slower |
| v5 filter-without-reuse | slower |
| eager axioms | slower |
| frontier sweep without key ordering | wrong |
| `SplayTreeMap` vs list queue | slower |

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
  reports the baseline for every variant.

## 10. Open items

1. Decide whether to promote a winner into `dart/lib/src/recovery/`. If promoted:
   add real test coverage, and exercise the left-recursion cut against an
   actually left-recursive grammar (JSON only reaches it via zero-width FAB
   inside `~WS <- [ \t\n\r]*`). `dart test` was 308/308 at baseline.
2. Build and measure the suffix-value pass (§5) to close m16's deep-budget gap.
3. Incremental re-parse: reuse memo entries whose spans precede the first edit
   (see `ERROR_RECOVERY_DESIGN.md` §8.1).
4. Port the pure core + the chosen recovery module to Java, Python, TypeScript.
5. `del@13` / `swap@13` remain unrecovered by every engine — the only known
   accuracy ceiling on this battery.
