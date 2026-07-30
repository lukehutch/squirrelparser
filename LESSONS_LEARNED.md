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
- **Every new engine gets a row in §5j and a registration in `final_table.dart`,
  in the same commit.** The table is the project's only complete record of what
  each variant costs and what is wrong with it; a variant measured but never
  tabulated gets re-invented later.
- **APPEND to §5j; do not regenerate it.** The old engines are not changing, so
  re-running all 32 rows costs ~12 minutes and rewrites settled numbers with the
  day's drift. Run the new engine *plus `m26` as a reference*
  (`final_table.dart m41,m26`) and append both rows; the reference row is what
  makes the new one comparable to what is already there, because absolute
  milliseconds are not portable across occasions (§5j, m39 vs m40).
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

### m15 vs m16: where the 54 lines went

The two were equal-accuracy siblings (517/519, identical cost histogram), so the
difference is entirely in *how regret is priced*, and every other divergence follows
from that one choice.

m15 charges regret **relative to the input**: a kept character costs
`w(class) − h(char)`, the bits the grammar asserts minus the bits the input already
supplied. That is defensible in isolation — it reads as "how much did we assume that
the input did not tell us" — but it is a *per-character* quantity, so `_regretOf`
must loop over `[pos, pos+len)` character by character (`m15.dart:206`), and it needs
`_h[]` for the point value alongside `_hSum[]` for spans (`m15.dart:102,185`).

m16 charges the **absolute** `w(class)`, and pays for the input's information once,
in `_lost`, where text is discarded. A clean leaf is then `_w(clause) * m.len`
(`m16.dart:110`) — one multiply, a closed form, no loop. The `_h[]` array disappears
entirely; only the prefix sum `_H` survives (`m16.dart:67`), consulted solely via
`_lost` for text the repair throws away. The factor 2 in A2 is exactly the
bookkeeping this shift moves to the skip edge.

Everything else is downstream. Because `_score` is closed-form it memoises on the
`MatchResult` with no per-character work; because there is one array instead of two,
initialisation shrinks; because the regret of a subtree no longer depends on where in
the input it sits, the value is *positional-invariant* and the memo is sound without
carrying `h` through it.

| axis | m15 | m16 | verdict |
|---|---|---|---|
| pricing | relative, `w − h(p)` per char | absolute `w`, `h` paid once at the skip | m16: one concept, not two |
| regret of a clean leaf | loop over the span | `_w(c) * len` | m16 |
| info arrays | `_h[]` + `_hSum[]` | `_H` only | m16 |
| code | 406 | 352 | m16 |
| battery | 533 ms | 439 ms | m16 |
| latency vs v6 | ~1.00× | 1.06× | m15, marginally |
| accuracy | 517/519, `{1:503, 2:16}` | identical | tie |

**The lesson that generalises past both:** m15's relative pricing was not *wrong*,
it was *non-local* — it entangled a subtree's value with its position in the input.
Making the objective positional-invariant is what let regret be a closed form, which
is what made it memoisable, which is what made the budget a filter rather than a memo
key. m16 was not a cheaper m15; it was the first version whose value function
factored. Both were then superseded wholesale, because neither had A4 (the recursion
is the dot) or A5 (left recursion is the parser's, already solved) — see §3.

## 5a. Complexity

**Regular parsing is unaffected, by construction rather than by measurement.**
`dart/lib/src/parser/` is byte-identical across every engine (`git status` on
`dart/lib/` shows only untracked *recovery* files), and no engine subclasses,
reimplements, or reaches into the parser: m26 touches it through exactly
`Parser(rules:...)`, `.parse()`, and `Clause.match(parser, pos)`. Nothing can change
the parser's asymptotics without changing the parser. Recovery is only *invoked*
after `parse()` reports a syntax error, so a document in L(G) never enters it.

The stronger operational claim is also true and is visible at `m26.dart:310-313`:
when `b == 0 && dot == 0` the answer is exactly the pure parser's, so a clean
subtree costs **one memoised oracle call**. On valid input recovery is one pure
parse plus O(1).

**Recovery's own worst case.** Let `n` be the input length, `|G|` the number of
dotted items in the grammar (`sum over clauses of arity+1`), and `K` the cost of
the repair finally returned.

- The memo is keyed by `(item, pos)`, so it holds `O(|G| * n)` entries
  (`m26.dart:301`).
- Each entry's value is a map from end position to minimum Delta, so `O(n)` wide.
- `_chain` computes an entry by pairing every head end with every tail end --
  `for h in _ends(sub,...) { for t in _ends(c, to, h.key, ...) }` -- which is
  `O(n^2)` per entry.

So one budget round is **O(|G| * n^3)**, and iterative deepening over `k = 0..K`
gives **O(K * |G| * n^3)**.

**The span loop was worth a factor of K, not a factor of n.** m15/m16/m17 enumerate
discarded spans with `for (var j = 0; j <= b && ...)` -- bounded by the *budget*,
not by the input, because each skipped character costs one edit. So the j-loop adds
`O(K)`, giving `O(K^2 * |G| * n^3)`, and A1's unit skip edge removes that factor.
Guessing "an extra factor of n" would have been wrong; the bound is `j <= b`.
Note also that m17 replaced the loop only in the *forward* pass -- its `_descend`
(`m17.dart:321`) still enumerates spans -- whereas m26 has no span enumeration at
all.

**Measured exponents** (`complexity.dart`, log-log slope over doubling JSON
documents, n = 253..4027; Theta(n) damage ladder n = 79..498 with every 64th
character corrupted):

| engine | clean^p | 1err^p | nerr^p | nerr@498 ms |
|---|---|---|---|---|
| m26 | 0.97 | 0.34 | 3.42 | 325 |
| m25 | 0.93 | 0.46 | 3.49 | 318 |
| m22 | 1.04 | 0.52 | 3.30 | 284 |
| m19 / m18 | 0.98 / 0.89 | 0.47 / 0.45 | 3.29 / 3.33 | 297 / 305 |
| m16 / m15 | 1.07 / 0.98 | 0.87 / 0.78 | 3.62 / 3.57 | 456 / 435 |
| m21 / m20 | 0.96 / 0.93 | 0.41 / 0.28 | 2.91 / 2.90 | 329 / 387 |
| v6 | 0.86 | 0.15 | 3.58 | 332 |
| dot | 0.75 | 0.24 | 3.90 | **62860** |

Three readings, one of which corrects §5:

- **Clean input is linear.** Every engine sits at ~1.0, which is what a packrat
  core should give. The `clean/pure` ratio came out at 0.48-0.72x -- *below* 1.0,
  which is impossible on the merits and is an artifact of measurement order: the
  pure reference runs first, JIT-cold, so its milliseconds are inflated. The
  defensible claim is "no asymptotic penalty on valid input," which the `b == 0`
  fast path establishes at the source level anyway; the ratio column should not be
  quoted as evidence recovery beats parsing.
- **THE EXPONENT IS SET BY THE GRAMMAR, NOT BY THE DAMAGE.** A single typo on JSON
  gives an exponent of 0.15-0.87, i.e. essentially free -- but the same single typo
  on the left-recursive arithmetic spine measured ~2.1 (§5). So the earlier claim
  "recovery cost tracks the amount of damage, not the document size" is right for a
  grammar whose structure localises damage and WRONG for a left-leaning spine, where
  every position is reachable from every other. Both statements need the grammar
  shape attached to be meaningful.
- **Theta(n) damage measures ~n^3.3, under the analytic n^4.** With K growing
  proportional to n, `O(K * |G| * n^3)` predicts n^4; measured 2.9-3.9. The bound is
  not tight but it is not violated. Note m20/m21 have the *best* exponents here
  (2.90, 2.91) while being the slowest in absolute terms -- an exponent and a
  constant are different things, and rejecting them was still correct.

**The honest gap: the left-recursion fixed point has no tight polynomial bound in
this derivation.** `_Entry.ends` re-runs `_compute` while `_improves` holds, and
`_improves` returns true either when an end is *new* or when a Delta merely *gets
smaller*. New-ends-only would bound iterations at `O(n)`. Delta decreases are
bounded only by the Delta range, `O(n * K * M)`, which is far too loose to be worth
quoting. Measurement says the real behaviour is a small constant: the left- versus
right-recursive ratio for the same language grew only from ~2.6x to ~4.8x across
n = 256..4096 (§5), which is inconsistent with `n` iterations. **Closing this is the
main open theoretical question for the paper** -- either prove that a Delta-only
improvement cannot occur at a re-entered item, or bound the number that can.

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
recursion costs a 2.6-3.1x multiplier over the right-recursive form at these sizes.

**That "stable multiplier" reading was then falsified by going 10x further out**
(`lr_scale2.dart`, `lr_depth.dart`, `lr_depth2.dart`). Three corrections, one of
which is a hard limit:

1. **The multiplier grows.** Direct left recursion is 4.2-4.8x, not 2.6-3.1x, once
   n reaches 512-1024. Slowly growing, not flat.
2. **A cycle spanning more rules is CHEAPER, not dearer.** The suspect claim was
   that a 3-rule cycle (`E <- A; A <- B '+' F; B <- E`) would expand more per
   position than a 1-rule self-loop. It expands *less*: 1.65-1.91x versus direct
   left recursion's 4.2-4.8x. The fixed point iterates per *position*, not per rule
   in the cycle, so extra rules add a constant factor to one expansion rather than
   multiplying the number of them.
3. **Costs still agree with the equivalent right-recursive grammar at every size
   both complete**, out to n=4096 -- 16x further than the original check. A5's
   minimality claim holds.

**The hard limit: recursion depth, and right recursion is the binding constraint.**
Every engine -- m16, m22, m26 alike -- dies with `StackOverflowError` on a
*right*-recursive grammar at n=2048, while surviving left recursion to n≈4096.
This is the opposite of the intuition, and it is inherited from the core, not
introduced by recovery: the pure parser shows the same asymmetry (clean
right-recursive input overflows at n=8191; clean left-recursive input survives
n=16383). Left recursion is expanded *iteratively* by the memo fixed point, so it
costs memo entries; right recursion nests one native frame per character, so it
costs stack. Recovery inherits the asymmetry and worsens the threshold ~4x, because
its descent adds frames per position. **This is pre-existing and shared, NOT caused
by A5** -- but it is a real ceiling and belongs in the paper, not in a footnote.
The fix, if wanted, is an explicit worklist in place of native recursion; it would
cost lines and is not built.

**Latency is quadratic in n for a fixed single error**: 13 / 32 / 129 / 565 /
2467 ms at n = 256 / 512 / 1024 / 2048 / 4096, i.e. ~4.3x per doubling. Clean input
stays flat (0.2-1.5 ms at every size) because cost-0 subtrees are O(1). So the cost
tracks *damage x document length*, not damage alone as §5 claims for the n=2114
one-typo case -- that case is cheap because the damage is local, and this one is
expensive because a left-leaning spine makes every position reachable.

**A5's absence is worse at scale than §8 reports.** m16 and m22 do not merely return
a non-minimal cost on left-recursive grammars; from n≥512 they return **-1, no repair
found within maxCost=40**. The pre-A5 defect is total failure at scale, not mild
suboptimality.

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

## 5b. The objective was wrong: every engine repairs toward the CFG, not the PEG

`experiments/recovery/peg_conformance.dart`. A1 defines the objective as the
minimum edit distance to the nearest member of L(G). For a PEG, L(G) is defined
by DETERMINISTIC parsing: `*` is greedy and possessive, and `/` commits to the
first alternative that succeeds. A string that a CFG reading of the grammar would
derive is frequently not in the PEG language at all.

Measured, with brute-force distance-to-L(G) as truth (membership decided by the
pure parser, so the truth column cannot be wrong about PEG semantics):

| case | grammar | input | truth | dot | v6 | m15 | m16 | m22 | m26 |
|---|---|---|---|---|---|---|---|---|---|
| possessive star | `S <- 'a'* "ab";` | `aab` | >3 | 0 | 0 | 0 | 0 | 0 | 0 |
| possessive star+ | `S <- 'a'* "ab";` | `aaaab` | >3 | 0 | 0 | 0 | 0 | 0 | 0 |
| committed choice | `S <- ('a' / "ab") 'b';` | `abb` | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| committed nested | `S <- A 'c'; A <- 'a' / "ab";` | `abc` | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| greedy optional | `S <- 'a'? "ab";` | `aab` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

4/5 wrong, identically, in every engine back to the `dot` baseline. This is not a
regression introduced anywhere in the m-line; it is inherited. `bf_check` never
caught it because none of its five grammars exercise possessiveness -- JSON-like
grammars are prefix-disjoint at every choice point, so the CFG and PEG readings
coincide.

Two places produce it:

  * `_chain` offers a free stop at every iteration boundary (`if (_done(c, dot))
    out[pos] = 0`). Under PEG semantics a repetition may stop only where its body
    FAILS, so stopping short of the greedy point should cost at least one edit.
  * `First` unions all alternatives. Under PEG semantics alternative i is
    available only if alternatives 1..i-1 all fail on the REPAIRED string.

The same flaw is visible in lookahead: `FollowedBy`/`NotFollowedBy` are evaluated
by asking the oracle about the ORIGINAL input, but the repair changes what the
lookahead would see.

### Why this is also the complexity story

The free stop is what makes the end-maps O(n) wide at cost 0, and the width of the
end-map is the entire source of the cubic: the memo holds O(|G|*n) entries, each a
map of width W, and `_chain` pairs head ends against tail ends for W^2 work per
entry, giving O(|G|*n*W^2). W = O(n) gives the measured ~n^3.3.

Ignoring determinism makes the effective grammar AMBIGUOUS -- many distinct
derivations of the same repaired string. That is precisely the axis along which
Earley-style parsing costs O(n^3) for ambiguous grammars and O(n^2) for
unambiguous ones. So the correctness bug and the complexity target have a single
root cause, and the same fix is the candidate for both.

## 5c. The deepening schedule is not the problem (m28, refuted)

The damage exponent is 2.4-2.6 while a single search round looked like it should
cost only about K^1.4, so the obvious suspect was iterative deepening: budgets
0, 1, ... K are all searched to learn an answer only the last one produces, which
looks like a whole factor of K of repeated work. m28 replaces unit deepening with
DOUBLING (0, 1, 2, 4, 8, ...), which cannot change the answer -- A3 makes the
budget a filter on Delta, so the minimum over {cost <= b} is the same integer for
every b at or above the true optimum.

The answer was indeed identical: shape 517/519, cover 519/519, cost histogram
{1:503, 2:16}, valid 7/7, truth 44/44, tree 44/44, all equal to m26.

The complexity was identical too, and that is the finding:

| engine | exp in n, c=1 | c=2 | c=4 | c=8 | exp in K, n=253 | n=498 |
|---|---|---|---|---|---|---|
| m26 | 1.03 | 1.32 | 1.34 | 1.84 | 2.40 | 2.52 |
| m28 | 1.20 | 1.27 | 1.36 | 1.85 | 2.39 | 2.54 |

At cost 8 the doubling schedule searches five budgets where unit deepening
searches nine, and the two take the same time. So the rounds below K contribute
almost nothing:

    sum over b <= K of T(b)  ~=  T(K)

The cost is dominated by the final round ALONE. Iterative deepening was never
costing a factor of K, the arithmetic that predicted it was wrong, and the whole
K^2.4 lives INSIDE a single search round.

m28 is strictly worse in practice despite matching here, because the damage ladder
uses K in {1,2,4,8,16} -- all powers of two, where doubling never overshoots. On
the latency suite, whose costs are not powers of two, m28 runs budget 2K instead
of K and pays 2^2.4 ~= 5.3x for it: 1148 ms against m26's 242 ms. Doubling saves
nothing and adds overshoot.

DO NOT revisit the deepening schedule. The remaining levers are both intra-round:
the head-times-tail product in `_chain`, and the O(K) width of the end-maps.


## 5d. The budget is two mechanisms wearing one name (m29, m30)

A3 says the budget is "a FILTER on Delta, NOT a memo key". m26 violates this: `_chain`
recurses with `b - _cost(h.value)` and `b - 1`, and `_Entry.ends` recomputes whenever
the stored budget differs from the requested one, so one (item, pos) is recomputed once
per distinct budget it is asked with.

`where_is_k.dart` measured the violation rather than assuming it. m26's `_compute` count
grows 2.87x / 3.26x / 2.63x / 2.41x per doubling of K -- steps ~ K^1.47 -- while time
grows K^2.4, leaving ~K^0.93 in work per computation (map width). BOTH mechanisms are
real and they split the exponent roughly evenly.

m30 = m26 with the budget held constant down the recursion, and nothing else. Result:

  * Computation count becomes EXACTLY Theta(|G| * n * K). "x prev" is 2.02-2.04 at every
    rung and at both document sizes, and steps/K is flat (~82k at n=253, ~157k at n=498,
    ratio 1.9 ~ n). This is the banded-Levenshtein bound, and it is a real win: the
    K-exponent in the computation count drops 1.47 -> 1.00.
  * Answers are unchanged: hist {1:503, 2:16}, truth 44/44, tree 44/44, valid 7/7,
    shape 516/519 vs 517. So constant-budget is semantically equivalent, as A3 implies.
  * And it is 14x slower on the battery (4891 ms vs 345), 8.5x on latency, and its stack
    ceiling collapses from >=4096 to <512.

The reason is the finding, and it is worth more than the engine: THE BUDGET IS DOING TWO
UNRELATED JOBS.

  (1) It filters Delta. This is the job A3 names, and the job that must not key the memo.
  (2) It BOUNDS THE DESCENT. `_compute`'s `b == 0 && dot == 0` fast path answers straight
      from the oracle with no recursion at all, so a budget that decreases as cost
      accumulates is what collapses the search back into a single pure parse once the
      budget runs out. That is what localizes recovery to the damage neighbourhood
      (5726 computations at K=1 where |G|*n is ~79000) and what terminates the descent.

Removing the budget arithmetic fixes job (1) and destroys job (2). The two must be
separated, not merged and not deleted.

The design this points at: `_ends(c, dot, pos, 0)` IS the pure parser. So the budget is
not a bound at all -- it is the DEGREE of a lift, level 0 being the parser and level k
being "the parser plus one edit, over level k-1". An entry then stores a value indexed by
degree and ACCUMULATES: degree 0 stays O(1) via the oracle (job 2 preserved), and no
degree is ever recomputed when a higher one is requested (job 1 fixed). Iterative
deepening stops being an outer loop and becomes the structure itself.

## 5e. m29: the PEG fix, and what it costs

PEG commits in three places that look like three features:

    e1 / e2   is  e1 / (!e1 e2)        ordered choice
    e?        is  e  / (!e)            greedy option
    e*        stops exactly where !e   possessive repetition

All three say the same thing -- the LATER option is reachable only where the EARLIER one
fails -- so all three are negative lookahead and need ONE predicate, not three rules.
m29's `_mayFall` is that predicate, and `First`, `Optional` and `Repetition` become one
loop with the empty branch of `?` reached by falling off its end.

It fixes 3 of the 5 conformance cases (committed choice, committed nested, greedy
optional; the two star cases have an EMPTY PEG language, so no finite answer is correct).
It costs what m27 cost: shape 492/519, hist {1:474, 2:45}, truth 42/44.

The cause is the same as m27's and is NOT fixable by a better predicate: `_mayFall`
consults the ORIGINAL input, but PEG semantics quantify over the REPAIRED string. A
correct guard must ask whether the body fails on s', which depends on edits the
continuation has not chosen yet. DO NOT retry this as a local predicate.


## 5f. m26's A3 violation is load-bearing (m31)

m26 stores two different quantities in the single integer `b`:

  * the cost to REACH an item -- top-down, left-to-right, path-dependent. This is
    what bounds the descent and keeps the search local to the damage.
  * the cost to COMPLETE an item -- bottom-up. This is the end-map, and A3 is
    exactly the claim that it must not be keyed on any budget.

m31 split them: reach counts UP and is passed only to the fast path, while every
entry is computed at the round budget and therefore exactly once. It is WRONG --
JSON repairs come back at cost 4 where the truth is 1. Toggling only the shortcut
(`_shortcut`, left in the file for exactly this purpose) restores agreement with
m26 on every case tried, which localises the fault to the shortcut alone.

The cause: m26's `b == 0 && dot == 0` fast path returns `c.match(_parser, pos)`, the
SINGLE GREEDY end. But the budget-free cost-0 value of a Repetition has an end at
EVERY iteration boundary, and that of a First has one per alternative. m26 memoises
that impoverished answer under budget 0, and then recomputes the entry when it is
later asked at a larger budget -- and THE RECOMPUTATION IS WHAT RESTORES THE MISSING
COST-0 ENDS.

So the A3 violation is not an accident to be deleted. It is the mechanism that masks
an incomplete base case. That explains both failures at once:

  * m30 deleted the recomputation and paid 14x and the stack.
  * m26 keeps the recomputation and pays K^0.47 in the computation count.

Both are symptoms of ONE unsound base case, not two independent problems.

THE FIX THIS IDENTIFIES: make level 0 a real, memoised, budget-free evaluation --
`_ends0(c, dot, pos)`, the same `_compute` with every edit move disabled -- instead of
a single oracle call. It is then complete at ANY dot (m26's is valid only at dot 0),
so the shortcut becomes sound, the recomputation becomes unnecessary, and the count
drops to the Theta(|G|*n*K) that m30 already demonstrated is reachable. This is the
next engine to build, and it is a DELETION: no budget parameter, no `_filter`, no
`_Entry.budget`.


## 5g. The budget is NOT the lever (m33, m34 refuted)

m32 made level 0 complete, which removes the unsoundness of 5f and makes coarsening
the budget legal. Passing a LARGER budget down is always sound -- the caller filters
every combination against its own `total < limit` -- so the budget an entry is asked
with need only be an upper bound. That predicted a clean win: round the budget up and
an entry is recomputed O(log K) or O(1) times instead of O(K).

Both were built and both are much WORSE. JSON, n=253, best-of-4 ms:

     K    m26     m33 (powers of 2)   m34 (0 or full)
     1    4.2       3.6                  3.5
     2    6.5       8.2                 90.2
     4   35.4     177.0                404.0
     8  213.1    1608.3               2143.1
    16 1703.5   11359.2               8975.1

The exact budget is not bookkeeping overhead -- it is the DOMINANT PRUNING MECHANISM,
and the K^0.47 recomputation it costs buys a far larger reduction in per-entry
exploration. This also retro-explains m30 (14x) and m31: all three failures are the
same mistake, which was treating budget-keyed recomputation as waste.

CONCLUSION, and it closes a line of attack that consumed m28, m30, m31, m33 and m34:
THE BUDGET IS NOT THE LEVER. Do not attack the deepening schedule, the budget
arithmetic, or the memo key again. The remaining lever is per-entry work -- the
head-times-tail product in `_chain` and the O(K) width of the end-maps.

## 5h. m32 / m35: a complete level 0

m32 deletes m26's `b == 0` oracle fast path and instead guards SUB and FAB with
`b >= 1`, so level 0 is the ordinary computation with the edit moves switched off:
complete at ANY dot, memoised in the same entries, carrying the same LR fixpoint.
Net change is a deletion plus two guards. m35 adds one field: the budget-0 value is
budget-free, so it is cached for the whole run instead of being overwritten by the
first larger-budget request and recomputed every round.

Measured against m26 (final_table, same run):

  metric        m26     m32     m35
  shape         517     517     517
  cover         519     519     519
  cost hist   {1:503,2:16} identical on all three
  valid         7/7     7/7     7/7
  cost        44/44   44/44   44/44
  tree        44/44   44/44   44/44
  battms        349     421     420
  latms       248.6   218.8   212.6
  LRmax      >=4096  >=4096  >=4096
  RRmax         512     512     512

So: every correctness metric ties, latency is 14% better, large-n/high-K time is
10-17% better (scale2d: at n=4027, K=8, m32 31746 ms vs m26 36519; K=4, m35 1232 vs
1490), and battery throughput is 20% WORSE because the complete level-0 traversal
replaces an O(1) oracle call and the battery is all K=1.

m35 does NOT beat m26 on all metrics. It buys robustness -- m26's greedy level 0 is
incomplete, and it is only correct in practice because recomputation happens to cover
it -- and it pays 20% on the cheapest workload for that. The n- and K-exponents are
unchanged (exponent in n at K=8: m26 1.86, m32 1.88, m35 not completed).

### 5i. Budget 0 is not a cheap case of the search -- it is not a search at all (m36-m40)

The synthesis of m26, m35 and m27 turned on one reading: **the budget measures how
much of the input is still unknown.** At budget 0 no edit is affordable, so the
repaired string IS the input, PEG is deterministic on it, and the pure parser
decides the item outright. Above budget 0 the input is unknown and the CFG
relaxation is the correct sound over-approximation.

Two consequences, one of which was wrong.

**Wrong: enforcing PEG semantics at budget 0 fixes conformance.** m36 guards the
Repetition stop and the ordered choice with `!earlier` evaluated on the input, but
only where `b == 0`. Round 0 then rejects the non-PEG parses, as intended -- with
`maxCost: 0`, m26 and m36 both return -1 on `('a' / "ab") 'b'` against `abb`, while
m35 returns 0. But the full run still returns 0, because the illegal parse costs
ZERO edits and simply surfaces at round 1, where the guard is off. A guard keyed on
the round's remaining budget cannot fix this; the predicate would have to be "no
edit anywhere in this derivation", which is not local. m36 also bought nothing:
434 battms against m26's 349 in the same run.

**Right, and it corrects §5h: m26's greedy level 0 was never incomplete.** It is the
PEG-EXACT level 0, and it is narrow and O(1) for the same reason. m32/m35
"completed" it toward the CFG language -- toward the very bug peg_conformance
reports -- and that is where their 20% battery cost came from. What m26 got wrong is
narrower: its fast path fires only at `dot == 0`, because the oracle can match a
clause but not a clause's tail, so every TAIL item still ran the full DP at budget 0.

A tail at budget 0 is just that same oracle call repeated over what remains, and
where the walk stops is a question `_done` already answers: failing mid-Seq leaves
the tail with no value, while failing where the item may already stop IS where a
Repetition stops. That is `_walk` -- one loop, no case split -- plus m35's one
cached field, since the budget-0 value is budget-free. The result is a SINGLETON
map, which is also the narrowest possible operand for every head-by-tail product in
`_chain`.

Measured per-process so each engine runs first (the harness warms the heap as it
goes: the SAME engine costs 377 battms registered first and 314 registered last, so
every in-run A/B before this was biased by up to 12%). Three runs each:

  metric      m26              m38              m40
  LOC         382              407              399
  shape       517/519          517/519          517/519
  cover/crsh  519/519, 0       identical        identical
  cost hist   {1:503,2:16}     identical        identical
  valid/cost/tree  7/7 44/44 44/44   identical  identical
  battms      383 406 365      318 287 312      299 304 304
  latms       259 270 255      235 248 235      247 235 254
  LRmax/RRmax >=4096 / 512     identical        identical

m38 and m40 differ only in how `_walk` is written (explicit Seq/Repetition split vs
the collapsed `_done` form) and are within noise of each other. Both beat m26 on
battery by ~21% and on latency by ~7%, with NON-OVERLAPPING ranges on both axes, and
tie every correctness and depth metric.

This still does not "beat m26 on all metrics": LOC regresses 382 -> 399, and shape
(517/519), cost hist, truth, LRmax and RRmax are TIES, not wins. Beating those needs
new capability, not a faster level 0.

## 5j. The full comparison table (every engine ever built)

**Maintenance rule: this table and `final_table.dart`'s registry are one artifact.
Every new engine gets registered there AND gets a row here, in the same commit.**

`dart --packages=... experiments/recovery/final_table.dart`, one process, 2026-07-25.
`bugs` names defects specific to that engine; four defects are shared by every row
and are listed once below rather than repeated 32 times.

| engine | LOC | shape | cover | crsh | cost hist | valid | cost | tree | bugs | battms | latms | /v6 | LRmax | RRmax |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dot | 797 | 515/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | slow, shape | 7876 | 5879.9 | 12.39x | >=4096 | >=4096 |
| sd3 | 499 | 512/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 32/44 | 39/44 | LR, empty | 434 | 772.2 | 1.63x | >=4096 | 2048 |
| sd5 | 513 | 512/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 32/44 | 39/44 | LR, empty | 482 | 1040.5 | 2.19x | >=4096 | 2048 |
| v6 | 526 | 512/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 511 | 474.6 | 1.00x | >=4096 | 2048 |
| m12 | 396 | 516/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 33/44 | 39/44 | LR, shape | 491 | 494.0 | 1.04x | >=4096 | 2048 |
| m15 | 406 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 494 | 487.4 | 1.03x | >=4096 | 2048 |
| m16 | 352 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 404 | 484.3 | 1.02x | >=4096 | 1024 |
| m17 | 357 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 442 | 272.7 | 0.57x | >=4096 | 1024 |
| m18 | 373 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 439 | 240.2 | 0.51x | >=4096 | 1024 |
| m19 | 362 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 429 | 243.4 | 0.51x | >=4096 | 1024 |
| m20 | 350 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR, slow | 959 | 315.2 | 0.66x | >=4096 | 1024 |
| m21 | 361 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR, slow | 959 | 288.3 | 0.61x | >=4096 | 1024 |
| m22 | 337 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 38/44 | 44/44 | LR | 430 | 241.4 | 0.51x | >=4096 | 1024 |
| m23 | 371 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 42/44 | null | 539 | 288.4 | 0.61x | >=4096 | 512 |
| m24 | 393 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | — | 537 | 305.7 | 0.64x | >=4096 | 512 |
| m25 | 394 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | — | 376 | 258.8 | 0.55x | >=4096 | 512 |
| **m26** | **382** | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **—** | 355 | 269.0 | 0.57x | >=4096 | 512 |
| m27 | 387 | 494/519 | 519/519 | 0 | {1:478, 2:41} | 7/7 | 44/44 | 44/44 | pegfix | 415 | 216.2 | 0.46x | >=4096 | 512 |
| m28 | 384 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | over | 366 | 1152.0 | 2.43x | >=4096 | 512 |
| m29 | 390 | 492/519 | 519/519 | 0 | {1:474, 2:45} | 7/7 | 42/44 | 44/44 | pegfix, slow, stack | 4978 | 1598.9 | 3.37x | 512 | 512 |
| m30 | 382 | 516/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | slow, stack, shape | 5164 | 2088.0 | 4.40x | <512 | <512 |
| m31 | 388 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | slow, stack, latent | 5303 | 2681.6 | 5.65x | <512 | <512 |
| m32 | 378 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | batt | 441 | 243.3 | 0.51x | >=4096 | 512 |
| m33 | 389 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | slow | 458 | 856.2 | 1.80x | >=4096 | 512 |
| m34 | 381 | 516/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | slow, shape | 651 | 1718.9 | 3.62x | >=4096 | 512 |
| m35 | 381 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | batt | 447 | 238.0 | 0.50x | >=4096 | 512 |
| m36 | 390 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | noop | 426 | 251.9 | 0.53x | >=4096 | 512 |
| m37 | 385 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | — | 350 | 255.5 | 0.54x | >=4096 | 512 |
| m38 | 407 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | LOC | 280 | 252.2 | 0.53x | >=4096 | 512 |
| m39 | 396 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | LOC | 283 | 255.5 | 0.54x | >=4096 | 512 |
| **m40** | 429 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | LOC | 309 | 259.6 | 0.55x | >=4096 | 512 |
| m26b | 382 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 360 | 267.1 | 0.56x | >=4096 | 1024 |
| m26c | 382 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 378 | 255.0 | — | >=4096 | 512 |
| **m41** | **379** | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **—** | **243** | **153.9** | — | >=4096 | 1024 |
| **m42** | 381 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **—** | 280 | 174.5 | — | >=4096 | 1024 |
| m26d | 382 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 379 | 255.3 | — | >=4096 | 512 |
| **m43** | 385 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **—** | 293 | 178.5 | — | >=4096 | 1024 |
| m42e | 381 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 287 | 181.6 | — | >=4096 | 1024 |
| **m44** | 428 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 303 | 181.0 | — | >=4096 | 1024 |
| m43f | 385 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 306 | 182.9 | — | >=4096 | 1024 |
| **m45** | 497 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 290 | 179.4 | — | >=4096 | 1024 |
| m44g | 428 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 291 | 182.1 | — | >=4096 | 1024 |
| **m46** | 539 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 321 | 186.7 | — | >=4096 | 1024 |
| m45h | 497 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 300 | 180.4 | — | >=4096 | 1024 |
| m47 | 629 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **leak, LOC** | 324 | 186.2 | — | >=4096 | **512** |
| **m48** | 656 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 350 | 180.0 | — | >=4096 | **512** |
| **m49** | 668 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 320 | 189.0 | — | >=4096 | **512** |
| m46i | 539 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 319 | 176.5 | — | >=4096 | 1024 |
| **m50** | 716 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC, batt, lat** | 681 | 774.5 | — | >=4096 | **>=4096** |
| m49j | 668 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 342 | 193.5 | — | >=4096 | **512** |
| **m51** | 739 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC, batt, lat** | 432 | 413.5 | — | >=4096 | **>=4096** |
| m50k | 716 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 655 | 746.9 | — | >=4096 | **>=4096** |
| **m52** | 749 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 374 | 361.8 | — | >=4096 | **>=4096** |
| m51k | 739 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 407 | 410.1 | — | >=4096 | **>=4096** |
| **m53** | 751 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 372 | 313.1 | — | >=4096 | **>=4096** |
| m52k | 749 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 374 | 361.8 | — | >=4096 | **>=4096** |
| **m57** | 814 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC, batt** | 1173 | 332.1 | — | >=4096 | **>=4096** |
| m53l | 751 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 415 | 327.1 | — | >=4096 | **>=4096** |
| **m58** | 854 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC, batt, lat** | 1082 | 632.6 | — | >=4096 | **>=4096** |
| m53m | 751 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 406 | 338.1 | — | >=4096 | **>=4096** |
| **m59** | **614** | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **slow** | 6172 | >6e5 | — | n/m | >=1024* |
| m53n | 751 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 387 | — | — | n/m | n/m |

(m59's timing and depth cells are non-standard by necessity: `battms` is the
`_batt59.dart` same-process pair (m53n beside it), `latms` is `>6e5` because
latency case 8 exceeds ~10 minutes per call and the min-of-5 protocol was
aborted at 58 CPU-minutes, and `RRmax >=1024*` is a direct no-overflow probe
(21s / 286s at k=512/1024 — time-bound, not stack-bound), not the ladder.
Quality columns are from `_score59.dart`, which imports `final_table`'s own
scoring functions. See the sixteenth occasion.)

| **m60** | 780 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 358 | 203.9 | — | >=4096 | **>=4096** |
| m53o | 751 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 427 | 296.4 | — | >=4096 | **>=4096** |
| **m61** | 715 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **LOC** | 391 | 274.6 | — | >=4096 | **1024** |
| m60p | 780 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 310 | 202.5 | — | >=4096 | **>=4096** |

(m61/m60p are one later `final_table.dart m61,m60p` process, appended per the
maintenance rule. m61's reference is m60 — the standing engine — not m53. The
nested-`E` bisected ceilings for m61, measured with `_ceil50b.dart`, are cost
k=649,649,649 and full k=590,590,590: the native stack returns with the direct
style. See the nineteenth occasion.)

| **m62** | 787 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **—** | 343 | **199.2** | — | >=4096 | **>=4096** |
| m60q | 780 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 329 | 215.2 | — | >=4096 | **>=4096** |
| **m63** | **344** | 467/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **conf 5/5, slow** | 27447 | n/m | — | n/m | n/m |
| m64 | 915 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | inc | 316 | 214.2 | — | >=4096 | >=4096 |
| m62r | 787 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 361 | 213.9 | — | >=4096 | **>=4096** |

| **m65** | **425** | **514/519** | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **conf 5/5, slow** | **7194** | n/m | — | n/m | n/m |
| **m66** | **53** | **517/519** | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | **conf 5/5** | **367** | **223.8** | — | 1024 | 2048 |
| m62s | 787 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 325 | 207.9 | — | >=4096 | >=4096 |

(m66/m62s are one `final_table.dart m66,m62s` process. m66 = the verified
router (occasion 24): m62's answer verbatim wherever its witness verifies,
the m65 tape exactly where the relaxation lied. Its LR/RRmax sit at the
FULL-pipeline ceiling because a cost query must build and verify the
witness — that is the certificate; m62s's >=4096 is its search-only path.
m66 is bit-identical to m53/m62 on all 252 smoke inputs and is the first
true-PEG-exact engine to complete the latency protocol.)

(m63's quality columns are `_score63.dart`; its battms is the `_batt63.dart`
same-process pair beside m62 at 316 — 87x, the price of true-PEG exactness by
candidate-space search. Its latms and ceilings are not measurable under the
protocol: latency case 8 is a cost-10 Dijkstra and the nested-`E` bisect is
time-bound (m59 precedent). `conf 5/5` retires the PEG tag for m63 ALONE —
the first engine back to `dot` exact on all five conformance cases; its -1
means "no repair within the derived cap n + CFG-fabrication floor". m64/m62r
are one `final_table.dart m64,m62r` process; m64's batch path is m62's code,
so its row is a second m62 measurement plus the incremental machinery's LOC.)

(m62/m60q are MEDIANS OF THREE `final_table.dart m62,m60q` pair processes:
m62 battms 329/346/343, latms 198.2/222.7/199.2; m60q battms 327/329/339,
latms 213.4/229.6/215.2. m62's latency beat m60's in all three runs; battery
is a near-tie with m60 ~3% ahead. Bisected nested-`E` ceilings for m62:
cost k=2160,2160,2160 / full k=1161,1161,1161 — m60's exactly. See the
twentieth occasion.)

The last two rows are a later, separate run (`final_table.dart m41,m26`, appended
per the maintenance rule rather than regenerating 32 settled rows). `m26c` is the
m26 reference measured in that same process, so m41 is comparable to `m26c` and
not to the older rows; `/v6` is blank because v6 was not in the run. m41 was
registered second, so its timings there carry the warming-heap bias — the isolated
paired measurement below is the one to quote.

`m42` and `m26d` are a third, later occasion, one engine per process, three runs
each; the number quoted is the median (m42 battms 270/305/280, latms
174.5/173.2/176.0; m26d battms 383/379/377, latms 255.3/253.3/259.2). `m26d` is
the same engine as `m26`/`m26b`/`m26c` again, so it is both the reference for m42
and a fourth confirmation that RRmax moves with registry position and nothing
else. m41 measured on that same occasion: battms 297/282/276, latms
142.1/144.6/152.3 — see §5l for the comparison that matters.

`m43` and `m42e` are a fourth occasion, again one engine per process, three runs
each, medians quoted (m43 battms 293/298/273, latms 182.5/177.9/178.5; m42e
battms 292/274/287, latms 181.6/177.7/184.8). `m42e` is m42 re-measured in that
same session and is the ONLY m42 number comparable to m43 — the machine was
~4% slower that day than when the m42 row above was taken, which is exactly why
the rule is one engine per process AND a same-session reference row. Read
together: **m43 costs nothing.** Its extra oracle call per alternation is a memo
hit, and the candidates it removes pay for it; `_steps43.dart` reports identical
state counts (7802 / 27431 / 101916 / 289734 at K=1/2/4/8, ratio 1.00), and the
K-sweep is flat (m43 4.8 / 12.4 / 66.2 / 389.5 ms against m42 5.4 / 11.6 / 63.9 /
386.1). What it buys is in §5m.

`m44` and `m43f` are a fifth occasion, one engine per process, three runs each,
medians quoted (m44 battms 303/309/286, latms 182.6/181.0/172.0; m43f battms
306/283/306, latms 182.9/194.8/181.8). `m43f` is m43 re-measured in that session
— the letter continues the global sequence `b, c, d, e` used for reference
re-measurements, and it is the ONLY m43 number comparable to m44. Read together:
**m44 costs nothing on this battery either.** Every quality column is identical
and the two timings differ by 1%, which is inside the run-to-run spread of each
engine. The `LOC` tag is real and is the whole price: 385 → 428 for the derived
ceiling. What that buys — the deletion of the last tuning parameter in the
m-line, and completeness — is §5n.

`m45` and `m44g` are a sixth occasion, one engine per process, three runs each,
medians quoted (m45 battms 270/290/296, latms 177.8/179.4/195.1; m44g battms
295/291/291, latms 179.0/194.0/182.1). Read together: **I4 costs nothing where
there is no lookahead to fuse**, which is the whole of JSON — 290 against 291 ms
on the battery and 179.4 against 182.1 ms of latency, both inside the spread, and
`_steps45.dart` reports the state counts BIT-IDENTICAL to m44's (7802 / 27431 /
101916 / 289734 at K=1/2/4/8). That is the strongest form of "free": the rewrite
is a no-op on a grammar it does not apply to, so the two engines do the same work
step for step. The `LOC` tag is again the whole price: 428 → 497. What that buys
— predicates that are priced by the language rather than by the spelling, and
12 repairs that m44 got wrong — is §5p.

`m46` and `m45h` are a seventh occasion, one engine per process, three runs each,
medians quoted (m46 battms 321/302/341, latms 186.7/191.2/179.1; m45h battms
300/290/304, latms 180.4/177.3/188.1). `m45h` is m45 re-measured in that session
and is the ONLY m45 number comparable to m46. Read together: **checking the
witness costs 7% of the battery and 3.5% of latency** — 321 against 300 ms over
519 recoveries, i.e. **~0.04 ms per repair**, which is one pure parse of a
48-character document. Every quality column is identical, because verification
changes no answer; it only reports whether the answer was a repair. The `LOC` tag
is again the whole other half of the price: 497 → 539. Note that this table calls
`recover` once per mutant, so the 7% is the *always-on* figure; an engine that
verified only when a caller asked would pay 0. What the check buys — the first
gate that can catch a repair that does not repair — is §5q.

`m47`, `m48`, `m49` and `m46i` are an eighth occasion, one engine per process,
**three rounds interleaved in engine order** so no row sits at a systematically
warmer heap than another. Medians quoted; every run is below.

| engine | battms (3 runs) | median | latms (3 runs) | median | RRmax |
|---|---|---|---|---|---|
| m46i | 320 / 319 / 313 | **319** | 175.5 / 182.5 / 176.5 | **176.5** | **1024** |
| m47 | 319 / 324 / 324 | **324** | 186.2 / 175.8 / 187.2 | **186.2** | **512** |
| m48 | 355 / 350 / 328 | **350** | 176.6 / 180.0 / 187.6 | **180.0** | **512** |
| m49 | 320 / 319 / 352 | **320** | 175.2 / 189.0 / 200.5 | **189.0** | **512** |

Read together, and stated the way the numbers actually support:

**On time, these four engines are not separable on this battery.** m49's own
spread is 320–352 (a 10% swing between its own rounds) and m46i's is 313–320, so
the 320-vs-319 median gap is noise, not a result; m48's 350 median sits inside
m49's range and above its own third round. An earlier, non-interleaved set of
runs in the same session read m49 at 349 against m46 at 314 and I took that for
an ~11% regression — **the interleaved occasion refutes it**, and the reason it
was wrong is exactly what §5j's rule exists for: unpaired rounds measure the
machine, not the engine. Latency is the same story (176.5 / 186.2 / 180.0 /
189.0 with per-engine spreads of 7–25 ms). JSON has no lookahead anywhere, so
nothing I6 or I7 added can *do* anything on this battery — the honest claim is
the null one: **carrying a constraint costs nothing measurable where there is no
constraint to carry.** `_smoke49.dart` makes that exact, comparing m49 to m46 on
156 JSON mutants: 0 cost diffs, 0 shape diffs, 0 span diffs, and `stepDiff = 0`
— *bit-identical `_compute` counts*, the same "free" that §5j records for m45
over m44.

**CORRECTED, 2026-07-26 — read the bisected numbers below before this paragraph.
The regression is real in DIRECTION but 6x overstated in MAGNITUDE: bisected, the
threshold is m46 524, m47 483, m49 537 — i.e. 8.4% at m47, and m49 is ABOVE m46,
so by the bisected measure there is no surviving regression at all.** The
`RRmax` column reports powers of two, so a threshold sitting 8% below a rung
reads as a halving. Everything below about the direction stands; the "halves"
claim does not, and the metric itself is the defect (`_ceil50b.dart` bisects; the
column still ladders). The paragraph as written:

**The one column that does move is `RRmax`, and it is a real regression: 1024 →
512, entering at m47 and holding through m49.** Confirmed across nine
single-engine processes (m46 ×3 at 1024, m47 ×6 at 512, m48 ×3, m49 ×3), so it
is *not* the registry-position artifact that `m26b`/`m26c`/`m26d` were registered
to expose — every one of these rows was the only engine in its process. Measured
fact: the largest right-recursive one-error input that completes without
`StackOverflowError` halves at I6. Inferred mechanism, not confirmed: the memo
dimension `c` means a position can be entered under several distinct pending
constraints, so the descent no longer terminates at the first memo hit per
position and the native recursion runs deeper per character. The `RR` tag's fix
(an explicit worklist, §8a) would remove the whole column, and it is still not
built.

The `LOC` tag is the rest of the price and it is the largest in the m-line:
539 → **629** (m47, I6) → **656** (m48, the enforcement fix) → **668** (m49, I7).
That is +129 lines over m46 and +286 over m26's 382. What it buys — repairs that
are exact where every previous engine was safe-but-high, and the closure of the
§5p/§5q residual that §5q could only *report* — is §5r. `m47` is in the table for
the record and **must not be used**: see the `leak` tag.

`m50` and `m49j` are a **ninth** occasion, one engine per process, three runs each,
medians quoted (m50 battms 642/681/689, latms 753.9/779.8/774.5; m49j battms
346/336/342, latms 189.8/194.0/193.5). `m49j` is m49 re-measured in that session
and is the ONLY m49 number comparable to m50. A tenth, all-engines-in-one-process
run of the whole table taken the same day agrees: m50 653 / 704.1, m49j 278 /
172.5, m49 300 / 181.8.

Read together, and this is the one occasion in the m-line where the trade is
**large in both directions**:

* **`RRmax` goes 512 → `>=4096`, and the `RR` tag — a bug shared by every engine
  in this table back to `dot` — is gone.** Bisected on the same grammar
  (`_ceil50b.dart`, 3 repeats, stable to the unit within a process): the SEARCH's
  ceiling is **k=2160 against m49's 541, a 4.0x gain**, which lands it at the PURE
  PARSER's own measured ceiling of k≈2100. The search therefore no longer
  contributes to the ceiling at all; the oracle does, and nothing in the recovery
  file can lift that. End-to-end `recover` is k=1281 (m49: 541) and is now bound by
  the witness descent `_build`, a recursion over the OUTPUT TREE, which is O(n)
  deep for a right-recursive grammar however the search is evaluated. m49's `cost`
  and `full` ceilings are both 541, which is the proof that the search dominated
  there and no longer does.
* **Every quality column is unchanged, and that is checked exactly, not inferred.**
  `_smoke50.dart` compares m50 to m49 on 252 inputs — 196 JSON mutants
  (delete/substitute/insert/transpose at all 49 positions), 8 grammars with
  lookahead so I7's obligation channel is live, and 5 recursive grammars (LR, RR,
  `S <- S 'a'`, `S <- 'a'* 'b' 'a'`, `A <- A 'x' / 'y'`) — on cost, canonical tree
  shape, recovery spans, chars skipped, and `lastVerified`. **All four diff
  counters are 0 in all 14 blocks.** I8 changes the ORDER a fixed point is reached
  in and a fixed point does not depend on that order, so this is the result the
  design predicts; it is recorded because the smoke gate is what makes it a fact.
* **It costs 2.10x the relaxations, and the cause is structural.** 2.43 per cell
  against the descent's measured 1.13 — about 3 for a cons, 2 for an alternation,
  1 for a terminal. The DAG argument (every dependency edge points at a position
  ≥ its source) is tight for *reading* but not for *discovery*: a cons cell cannot
  know WHICH tail cell it needs until its head has an answer, so a tail at a
  further position is created after its own stratum has gone by, and the cons is
  woken to read it. Measured flat in the budget — `_k50.dart` sweeps 64-character
  inserts and deletes at k=1..64 and the ratio is 1.92x at every k — so **this is
  not the deepening fold; deepening is free, as designed.**
* **And it costs 2.0x `battms` and 4.0x `latms`, which is MORE than 2.10x, so the
  per-relaxation constant roughly doubled too.** That is the worklist's own
  bookkeeping: a `_cells` map lookup per `_read` where the descent passed a value
  back on the stack, plus a queue insert per wake. Steps are not time in either
  direction — m49's step carried four native frames and m50's carries none.

Two scheduling variants were measured and **both rejected**, recorded so they are
not re-litigated:

| variant | relax/cell | latms | verdict |
|---|---|---|---|
| position buckets, arrival order inside a position | 2.63 | — | rejected; a parent relaxed before its child pays one relaxation per child |
| `(pos, node.id)` max-heap (**kept**) | 2.43 | 774.5 | `_node` numbers children higher, so both orders point the same way and pack into one integer |
| defer a cell that read a higher-ranked unsettled cell | 2.41 | — | rejected: 1% of relaxations for ~25 lines, and it needs its own liveness argument — **a dependency re-relaxed at a raised budget may settle on the value it already had, and a cell that does not improve tells nobody, so the deferred reader is never woken.** Requeueing explicitly fixes that and gives back the 1% |
| `SplayTreeSet` keyed by the same rank, replacing the heap | 2.43 | 889.0 | rejected: −24 LOC and bit-identical, but 17% slower. A set cannot hold a cell twice, so it needs no `queued` bit — and discovering the duplicate costs a walk down the tree where a bit costs nothing, and waking an already-queued cell is the common case |

One micro-measurement in the same family: `_Cell.readers` as a `List` rather than a
`Set` is 650 ms against 713 on the battery with identical step counts, because
`_dirty` is already idempotent, so deduplicating the reverse edges buys nothing.

The `LOC` tag is 668 → **716**, +48, and the design note's prediction of 560–590
was wrong — the worklist's machinery (`_Cell`, the heap, `_dirty`/`_pop`/`_read`/
`_run`/`_relax`) costs 109 code lines where m49's four LR fields and their loop
cost 77. **I8 does not make the file smaller. It makes one mechanism out of
three, and it removes a bug.** The reverse claim in the m50 design note — that I4
would go too, for −69 LOC — was also wrong: I4 is 19 CODE lines (the 69 counted
its comment block), and at 19 lines against +7.3% `_compute` calls it stays.

### The twelfth occasion: m51, where the fixed point test IS the write

`m51` and `m50k` are a **twelfth** occasion, one engine per process, three runs
each, medians quoted (m51 battms 428/432/441, latms 409.9/413.5/418.0; m50k
battms 649/655/661, latms 741.2/746.9/752.1). `m50k` is m50 re-measured in that
session and is the ONLY m50 number comparable to m51; `m49j` above was
re-measured on the same occasion at 334 / 189.8 and is comparable to both.

m51 = m50's recurrence with the VALUE REPRESENTATION changed and nothing else.
Two insertions:

**I9. A CELL IS RELAXED MANY TIMES, SO THE VALUE MUST BE WRITTEN INTO AND NOT
BUILT — AND THEN THE FIXED POINT TEST IS THE WRITE.** m50 built a fresh
`Map<int,int>` per relaxation and compared it to the stored one. Two numbers
already in this file meet and condemn that: the mean end-map width is **1.63
(JSON), 1.66 (LR), 6.04 (RR)**, and a cell is relaxed **2.43** times. *A hash
table of 1.63 entries is a hash table that will never be searched, allocated 2.43
times per cell in order to be compared once.* m51 keeps the value as a flat
`List<int>` of `(key, delta)` pairs and relaxes **into** it. The comparison then
disappears: `_keepBest` already knows whether it lowered anything, so the improved
bit is a by-product of writing, not a second pass. **I1's fixed point test does
not need to be computed, only remembered.** One representation serves the whole
file — the `_goalFromNothing` ceiling table uses the same pairs and the same
`_keepBest`, and there is no `Map<int,int>` left in the engine.

Soundness of relaxing in place: every Δ ever recorded prices a derivation that
really exists, budgets only rise (`_read` raises; nothing lowers), and the
recurrence is monotone — so this is chaotic iteration over a monotone operator on
a finite lattice and reaches the same least fixed point from any partial start.
m50 was not *safer* for rebuilding; it was recomputing answers it already held.

**I10. THE REVERSE EDGE IS CONSUMED BY THE WAKE.** After `_relax` wakes a cell's
readers it clears the list, because the invariant is that a cell is EITHER queued
OR listed by every cell it last read — and clearing preserves that, since clearing
is what queueing does. **This is a SPACE win only: 244855 edge slots → 133069, a
1.84x reduction, at 86849 relaxations either way and no measurable wall clock.**
I predicted it would fix latency and *that prediction is refuted*, though **the
reason I gave for the refutation was itself wrong and is corrected here**: I wrote
that no latency case in `final_table` exceeds cost 2, so there are never many
deepening rounds. That conflated the latency cases with the BATTERY's `{1:503,
2:16}` histogram. Measured per case (`_lat53.dart`), the 12 latency cases cost 2, 2,
1, 1, 2, **4**, 2, 2, **10**, 1, 1, 0 — and the cost-10 case is **90% of the whole
`latms` column** (308.6 ms of m53's 341.1 ms, 11 deepening rounds). So the rounds
were there and the prediction still failed; what is refuted is the mechanism, not
the count. A `Set<_Cell>` gets further (54742 edges) and costs 14% — rejected, same
reason as m50's list-vs-set micro-measurement.

**Why no case exceeds cost 2, measured — and it is not A1 (`_a1cost.dart`).** I
first wrote that a contiguous junk run of any length is ONE skip by A1's unit edge.
That is wrong: A1 charges a run of j characters **j** unit steps (`m51.dart:614`),
and the measurement is that the minimum-cost repair *does not use a long skip*.
Inserting j junk characters between two JSON members costs **1, 2, 3, 3, 3, 3 for
j = 1, 2, 3, 4, 8, 16** — it saturates. The witness says why: at j≥3 the repair is
two one-character skips (`[47+1, 57+1]` at j=8) plus one missing `','`, and the run
itself is never skipped. It is **ABSORBED** — `String <- '"' Character* '"'` with
`Character <- [^"\\]` accepts `@` freely, so re-bracketing which `"` opens the
string swallows an arbitrary run for a constant 3 events.

**That generalises past JSON and past this engine, and it is the honest form of "cost
tracks damage, not document size" (§5a).** Cost tracks *the cheapest re-bracketing*.
A grammar containing an **absorber** — a repetition over a near-universal character
class, which every string, comment and raw-text rule is — bounds the cost of ANY
contiguous damage by a grammar constant, independent of how much damage there is.
So K is small for real grammars for a structural reason, not a fortunate one; and
the corollary is that the battery cannot exercise the K axis no matter how much
damage it inflicts contiguously. Scattering is what raises K, because each site
outside an absorber needs its own repair: `_kscale51.dart` reaches cost 5, and there
m51/m49 steps go 1.69x → 1.93x over cost 1→5 — the gap grows slowly with cost, not
with n. (A scattered `@` that lands *inside* a JSON string is legal and free, which
is why cost is not monotone in the number of sites scattered.)

The result, one engine per process:

| | m49j | m50k | m51 |
|---|---|---|---|
| battms | **334** | 655 | 432 |
| latms | **189.8** | 746.9 | 413.5 |
| relaxations / cell | 1.13 (descent) | 2.43 | **1.97** |
| LOC | 668 | 716 | 739 |
| bisected `cost` ceiling (k) | 541 | 2160 | 2160 |
| bisected `full` ceiling (k) | 541 | 1281 | 1281 |

**0.66x m50's battery, 0.55x its latency, 0.83x its relaxations, bit-identical on
all 252 `_smoke51.dart` inputs, same bisected ceilings, +23 LOC.** The latency win
is larger than the step win, which is the point: the saved work was per-relaxation
constant (an allocation and a comparison), not relaxations.

**The residual 1.74x relaxation gap to the descent is a floor, not a defect.**
1.97 ≈ the structural 2 for a stack-free worklist — *once to discover the tail,
once to combine it* — because a cons cannot know WHICH tail cell it needs until
its head answers. Reaching 1.13 requires recursing on the position-advancing edge,
which is exactly what reintroduces the native stack and the `RR` bug. Rejected:
a depth threshold (a tuning parameter, forbidden), recursing only on same-position
edges (does not touch the costly tail edge), splitting the cons into two cells, and
a bottom-up agenda (refuted at 14x, §5j ninth occasion).

Three refutations were **re-run against the new core recurrence**, per §6's rule
that a refutation is only valid against the engine it was measured on:

| variant | measured | verdict |
|---|---|---|
| LIFO stack instead of the position heap | 2.58 relax/cell (1.32x) | **refuted** — position order is not incidental |
| `Set<_Cell> readers` | 14% slower, 54742 edges | refutation **stands** (`_dirty` is idempotent) |
| delete I4 (`&C T` ≡ `C∩T` fusion) | 1.21–1.64x steps on PRED grammars, **and 4 witness shapes change** | **keep I4** — and the shape change is new information: I4 is not purely an optimisation |

One process note worth keeping. **`late int` fields cost real time in an inner
loop:** `late int _posShift, _span` measured 452 ms battery against 432 with plain
`int _posShift = 0` — a `late` field carries an initialisation guard on every read,
and these are read in the innermost loop.

### The thirteenth occasion: m52 and m53, where the dependency stops being an address

**I11: A DEPENDENCY IS AN EDGE OF THE GRAMMAR, NOT AN ADDRESS TO BE LOOKED UP.**

I9 removed the per-relaxation *allocation*. What it left untouched was the
per-relaxation **lookup**. Every read in m51 goes `_cell(node, pos, c)` — build a
key, hash it, probe `_cells` — and the worklist reads a cell ~2 times for every
cell in the memo, so this is the hottest line in the engine. But a cell's reads are
determined by the *grammar*, not by the search: an `_Alt` at `(node, pos, c)` always
reads its i-th branch at the same `(alts[i], pos, c)`, and a `_Cons` always reads
its tail at `(node.tail, headEnd, budget', owed')` where `headEnd` and `owed` come
out of the head's value at index i. **THE EDGES DO NOT MOVE**, because `_keepBest`
appends and lowers *in place*: the key stored at index i of a value never changes
once written, only its Δ falls. So the address computed on the first relaxation is
the address on every later one, and it can be *stored on the edge*.

The invariant was **measured before it was built** (`_depprobe.dart`): across
JSON/LR/RR/PRED, 58–71% of reads ask for an address the cell has already resolved
(88226/2026/535/149 reads, of which 62397/1257/348/86 hit a stable slot), and
**zero** reads resolved to a *different* cell than the slot already held. So m52
gives `_Cell` a `List<_Cell?> deps` indexed by *slot* — slot 0 is an alternation's
first branch or a sequence's head, slot `1 + i/2` is the tail under the head's
i-th answer — and `_read` takes the slot as an argument. This is m25's **entry
object** lesson, which this line has already learned once: *resolve an address once
and keep the object, never the key.* The four outside entry points pass slot `-1`
and `from == null`, and take the old hashed path, which is correct because they are
the only reads not implied by a grammar edge.

**m52 vs m51: 374/361.8 against 407/410.1 — 0.94x battery, 0.87x latency, +10 LOC**,
bit-identical on all 252 smoke inputs (14/14 blocks, all four diff counters 0),
**identical step count (86849)**, identical quality row and identical ceilings. The
step count being *exactly* equal is the point: I11 changes no decision, only the
cost of asking.

**I11's second half: THE REVERSE EDGE IS THE FORWARD EDGE'S TRANSPOSE.** Once the
forward edge is an object slot, the reverse edge (`cell.readers`, which the wake
walks) is not separate information — it is the same edge read backwards. So m53
declares it **where the forward edge is declared**, once, on the relaxation that
first fills the slot, and never again. This **DELETES I10** rather than improving
it. I10's invariant was "a cell is either queued or listed by every cell that last
read it", maintained by hand with a `cell.readers.clear()` at the end of each wake;
the transpose invariant is "a forward edge is permanent, therefore the reverse edge
it implies is permanent", which is strictly stronger and needs no clearing at all.
The `clear()` line is gone and nothing replaces it.

**m53 vs m52: 372/313.1 against 374/361.8 — battery a wash, 0.87x latency, and
edge slots 133069 → 54742.** That second figure is the sharpest result of the
occasion: **54742 is exactly what the rejected `Set<_Cell> readers` variant reached
at a 14% run-time cost** (§5j twelfth occasion), and here it comes out for nothing,
because *the transpose is already deduplicated* — one slot per grammar edge, so a
duplicate reverse edge is not something to filter, it is something that can no
longer be constructed. Bit-identical and step-identical to m52; same quality row,
same ceilings. Cumulatively **m53 vs m51: 0.91x battery, 0.76x latency, +12 LOC**,
and against m49j (327/185.8, same occasion) 1.14x battery and 1.68x latency, down
from m51's 2.21x, with the `RR` bug fixed and a 4x higher search ceiling.

**I11 does not lower 1.97 relaxations per cell, and was not expected to** — the
floor argument of the twelfth occasion is about *how many times* a cell must be
relaxed, and I11 is about *what one relaxation costs*. Both engines sit at 1.97.

Two candidates were killed on this occasion and are recorded so they are not
re-litigated:

| candidate | verdict |
|---|---|
| **m54: cache the oracle verdict (`committed`) on the cell** behind a `-2` "not asked yet" sentinel — I11 generalised from "an address" to "anything a cell asks that cannot change" | **refuted by measurement.** 382/298.6 against m53k's 378/308.3 over three paired rounds, with m53k's latency itself spread 306–347: a ~3% latency edge inside the noise, battery a wash, for +4 LOC and a field. The reason it cannot win is that the pure parser **already memoises** `match(clause, pos)`, so caching swaps a hash lookup for a field load; unlike I11 there was no repeated *work* underneath, only a repeated *question with a cached answer*. Bit-identical to m53, so nothing is lost by dropping it. |
| **collapse `_goalFromNothing` into a read of the goal cell at `pos = _inputLen`** — it is a ~60-line second copy of the same recurrence, and the file admits it (`m51.dart:1033`) | **refuted by reasoning, not built.** Unsound: predicates asked at pos n get real answers, but by A4/m45 a lookahead gets no junk prefix, so a *leading* predicate is asked at pos 0 and the derived ceiling can fall **below** the true minimum cost — the `S <- !'x' A` failure the code's own comment names. A ceiling that is too low silently truncates the search, which is the one error class this design cannot tolerate. |

### The fourteenth occasion: two refutations that between them corner the ladder

This occasion produced no engine. It produced a profile, and then two refutations
that are worth more than the engine would have been, because together they prove
the deepening ladder cannot be improved *as a ladder*.

**The profile (`_lat53.dart`), and it reframes the whole `latms` column.** Per case,
m53 against m49j in the same processes:

| | m49 | m53 | ratio |
|---|---|---|---|
| steps, 12 cases | 174358 | 355792 | 2.04x |
| µs, 12 cases | 182884 | 341097 | 1.87x |
| **µs per step** | **1.049** | **0.959** | **0.91x** |

So **a worklist relaxation is now CHEAPER than a descent step**, and the entire
residual latency gap is the step COUNT — the 1.97-against-1.13 relaxations per cell
that the twelfth occasion argued is a floor. After I9 and I11 there is nothing left
to win in the per-step constant; the axis is exhausted. And the count itself is
concentrated: **case 8 alone (a 64-character shuffle, cost 10, eleven rounds) is 90%
of the column**, 308.6 ms of 341.1. On the 519-document battery, where damage costs
1 or 2, m53 is within 14% of the descent. The `latms` column is not a latency
measurement, it is a K-axis measurement wearing a latency costume.

Round by round on that case, the ladder looked like pure waste — 256919 relaxations
of which the final round, the only one that answered, was 44229, and the memo grew
only 951 → 18479 cells. **83% of the work looked redundant. Both ways of collecting
it fail, and they fail in opposite directions.**

**I12, REFUTED: a cell never cut by the budget is complete at every budget, so the
ladder must not re-ask it (`_m55.dart`).** Budget prunes at exactly four sites — the
`budget == 0` oracle short circuit, a read refused for `budget < 0`, and the two
`delta >= limit` tests — so "was anything dropped for want of budget, here or below"
is one bit every relaxation already has, and it is published state, so I9's fixed
point test covers it verbatim. It is bit-identical to m53 on all 252 smoke inputs.
**It saves nothing: JSON steps 424823 → 424818, and six of fourteen blocks are
1.02–1.05x WORSE** from the flag-flip wakes. The reason is the finding: cut site 0
marks nearly every cell, because `_chain` hands the tail `budget − cost(head)` and
so almost every cell is eventually asked at budget 0. **The ladder's rounds are
genuinely productive — the values really do grow every round — so the 83% is not
redundancy and no incremental patch can skip it.** (Finding cut site 0 cost the
gate: without it every cell was pronounced complete at k=0, the ladder never ran,
and all 166 damaged inputs came back −1. A settling criterion that misses one cut
site does not degrade, it silently returns "unrepairable".)

**I13, REFUTED, AND MORE SHARPLY: the budget is a bound, not a target, so the ladder
doubles (`_m56.dart`).** The exactness argument is sound and is worth keeping: a
cell's value at budget k is the minimum over every repair costing at most k, so the
goal's best entry is the exact answer at EVERY k that reaches it, not only the
smallest — a Delta-tied rival costs the same and so was admissible at the same k.
Bit-identical AND step-identical on the smoke set, where every case costs ≤ 2 and
`0,1,2` is the same ladder either way. **On case 8 it is a catastrophe: 256919 →
600791 steps, 308 ms → 1847 ms, 6x WORSE.** The single round at k=16 costs ~534000
relaxations against k=10's 44229. **W(k) grows STEEPLY in k once the budget exceeds
the true cost**, because a loose budget admits a flood of over-priced entries — my
linear extrapolation from rounds 1–10 was wrong by an order of magnitude. So
`Σ_{k≤Δ*} W(k) ≈ 5.8·W(Δ*)` is close to optimal for a budget-filtered search, and
`k++` is not a naive choice: **the tightest round is not marginally cheaper than a
loose one, it is exponentially cheaper.** (One consolation prize is real and
recorded: on case 5, cost 4, doubling skips round 3 and lands exactly on 4, for
35409 → 33901 steps. It wins only when it does not overshoot, and the overshoot
dominates.)

**What the two refutations corner.** You cannot skip rounds (I12: the values grow).
You cannot take bigger rounds (I13: overshooting is exponential). The only move left
is to make the step *infinitesimal* — to stop stratifying on position with the
budget as an outer loop, and stratify on **Delta itself**, popping work in order of
increasing cost so that every entry is computed once, at its own Delta, and the
bound tightens continuously instead of in integer steps. That is Knuth's lightest
derivation over the hypergraph (Dijkstra generalised to a monotone superior
recurrence: Delta is additive and non-negative, `min` at an alternation is superior,
so the precondition holds), and it would DELETE the ladder and the budget parameter
together. It also revises I8: **position is not the stratification variable, Delta
is, and position was only ever a proxy for it** — with the caveat that a zero-Delta
left-recursive cycle advances neither, so the true key is the pair `(Delta, pos)`
with fixpoint iteration inside each class, exactly as now. NOT BUILT: it is a
redesign of the search order rather than an insertion, the heap key grows from a
position rank to a pair, and the `budget == 0` oracle short circuit — which answers
a whole node with one memo hit and is worth 2x on its own — has no obvious analogue
once the budget is gone. It is the next engine, not a patch to this one.

### The fifteenth occasion: the Delta schedule is built, and it corners itself

The fourteenth occasion ended with one candidate on the board: stratify on Delta
itself (Knuth's lightest derivation), deleting the ladder and the budget, with two
open problems — no analogue of the `budget == 0` oracle short circuit, and nothing
obvious doing the budget's second job (§5d: bounding the descent). This occasion
built it, twice, found the answers to both open problems, and then measured the
whole program against the thing it was supposed to beat. Every number below is
from this session, one engine per process for the isolated runs, `m53l`/`m53m`
reference rows in the same process as the rows they anchor.

**m57 — I14: DELTA IS THE SCHEDULE.** A fact is `(cell, key, Delta)`; its priority
is `g + Delta`, where `g` — the one field that remains of the budget — is the
total Delta already settled when the cell was first demanded. Demands are issued
only by settled facts and settled facts arrive in watermark order, so the first
demand is the cheapest and `g` is final: min-cost context, stamped once, never
raised. The two open problems close cleanly:

* **The oracle short circuit survives as a creation-time SEED**: one memoized
  parser call answering a whole clean subtree, exactly the singleton the
  `budget == 0` walk produced. It is sound BECAUSE IT IS REDUNDANT — on a
  subtree with no unfused lookahead (`_noLook`, one static bit), the oracle's
  match is PEG's own derivation, one of the facts the structural rules would
  find anyway — so it is a shortcut, never a new answer. A subtree containing a
  lookahead is not seeded: its facts must carry `owed` debts a whole-clause
  match cannot see (`Kw <- "if" !Alpha` discharged against the input is the
  under-report the leak gate exists for).
* **The budget's second job becomes the pop order itself**: a created cell does
  not expand — its first relaxation is queued at priority `g`, so a frontier
  cell contributes its seed and nothing else, which is the leaf `budget == 0`
  used to make.

The ladder, the budget field, all four budget cut sites, and the ceiling AS A
SEARCH BOUND are deleted. Termination needs no ceiling: the fact space is finite
and every push is a strict improvement, so an unrepairable input drains the
queue. (`_goalFromNothing` survives with its other two jobs — pricing A3's cost
unit and answering an EMPTY LANGUAGE in O(|G|) with no search.) The first
satisfying goal fact to settle is the minimum, by Knuth's invariant: Delta is
additive and non-negative, so no push can undercut the watermark that caused it.

**Three scheduler bugs, each found by a gate, each a lesson in what the ladder
had been doing silently:**

1. **A per-cell "delivered" watermark silences same-priority facts.** A cell that
   relaxed to an empty value advanced its delivered mark; a fact arriving one pop
   later at exactly that priority failed the `> delivered` test and was never
   announced — `Kw <- "if" !Alpha` on "i" returned −1 with the repair sitting
   unread in the table. Chaotic iteration inside a priority class means facts
   legitimately arrive AFTER the class began; a watermark per cell is the wrong
   granularity for announcements.
2. **Announce-by-value-scan ping-pongs forever in a zero-weight cycle.** Waking
   readers whenever any fact sits at the popped priority lets two cells of a
   left-recursive cycle re-wake each other unboundedly (both hold facts at the
   class priority). Fixed by TYPING the queue entries: an ANNOUNCE entry is one
   strict improvement of one fact and wakes readers when popped; a RELAX entry
   only recomputes and announces nothing — a woken cell that fails to improve
   pushes nothing, and that silence is what drains a cycle. Improvements are
   finite, so pops are.
3. **Accepting at the first satisfying settlement races the Delta-tied rival.**
   The witness descent prefers ties the way a fully settled table breaks them,
   and a tied derivation can still be mid-flight in the same priority class when
   the goal fact pops. Fix: FINISH THE CLASS before answering. (First seen as 8
   witness-shape diffs on the smoke gate, all verified repairs at the same cost.)

**And one catastrophe that is the whole finding in miniature.** The first draft
delivered a settling fact by re-relaxing every reader in full. A hub cell whose
value holds W facts is then rescanned once per arriving fact: O(W²) per cell.
Latency case 8 (64-char shuffle, cost 10) ran 688,767 relaxations in 10.3
SECONDS — 33x m53 — and a `final_table` run sat at 99% CPU for 3.5 hours without
finishing the 519-mutant battery, stuck on the `"`-insertion mutants, whose
re-bracketing makes the absorber cells' values wide. It terminates (finite
improvements), but the constant is hours. The fix is textbook semi-naive
evaluation: the reverse edge carries its SLOT, and a settling fact is combined
against exactly the edge it arrives on — O(1) per alternation edge, O(opposite
width) per sequence edge, one full relaxation per cell ever, at expansion. Case
8 fell to 253ms (0.23µs per event, against m53's 0.96µs per relaxation — the
per-event constant is now the cheapest in the line).

**m57's row: every quality column perfect, and the price in one place.**
517/519, 519/519, 0 crashes, {1:503, 2:16}, 7/7, 44/44, 44/44, **69/69 pred, 0
unsnd**, `_bf57` 44/44, `_leak57` 71/71 with block D 14/14, the ceiling gate
correct on all six cases (60/46/30 without any ceiling, empty language −1 with
no search), bit-identical to m53 on all 252 smoke inputs, LRmax AND RRmax
>=4096. It is the first engine in the table with no ladder, no budget, no
tuning ceiling, and a perfect quality row. The price: **battms 1173 vs m53l's
415 in the same process (2.8x), latms 332.1 vs 327.1 (parity)** — the K-axis win
(case 8: 253 vs 294) cancels against small-K losses (case 10, n=530 one typo:
31.9ms vs 4.5ms), because fact-grain scheduling pays a heap entry, an
announcement, and an edge-fanout of combines for every fact, on every clean
cell of a document the ladder would have walked twice.

**m58 — I15: THE CLASS IS THE ROUND, RUN ONCE.** Exactness only needs cost
classes ordered (A3: cost rides above regret); within a class the order is
free, and m53's batched chaotic relaxation has the smaller constant. One heap
key, `(costClass << rankBits) | (rankMask − rank)`: Dijkstra across strata,
furthest-position-first inside them. The goal is read only at a stratum
boundary, where every Delta-tied rival has settled too, so tie-breaks reproduce
by construction. Two rediscoveries, both of them things the budget had been
doing under its own name:

* **The production cut.** Without `total < limit`, nothing stops a junk chain
  from manufacturing the whole O(n²) skip triangle that no pop will ever
  consume: measured 78,234,046 combinations on case 8 (3.65s) against 249,693
  relaxations. What remains of the budget's filter is one line: a combination
  priced beyond the current stratum is DEFERRED, and the cell re-dirties itself
  at the nearest deferred stratum, so production resumes exactly when the price
  becomes payable and stops at the answer the way popping does. Case 8: 587ms.
* **The walk-only leaf, and where it stops.** m53's `budget == 0` cell is a
  one-call leaf; the stratified analogue is "a seeded cell first demanded at
  class c may serve stratum c with its seed alone and expand at c+1" — sound by
  §5i's own edit-free-continuation argument. MEASURED: it collapses the small-K
  cone to m53's (case 10: 23.6ms → 6.5ms; cases 0–4 at or below m53) and
  changes NO reported cost — but the routes it suppresses are exactly the
  Delta-tied witnesses a fully settled table prefers, and 9 of 252 smoke
  WITNESS SHAPES diverge. Shape parity is this line's proof standard, so the
  defer is recorded, not shipped. (With it, case 8 regressed 587→1407ms —
  measured, mechanism not established; without it, m58 is bit-identical to m53
  on all 252 inputs and passes `_bf58` 44/44 and `_leak58` 71/71.)

**The verdict table, same session, `_lat53` per-case (µs, min-of-5):**

| | m49 | m53 | m57 | m58 |
|---|---|---|---|---|
| case 8 (cost 10, the K axis) | **161141** | 294495 | 252929 | 586738 |
| case 10 (n=530, one typo) | 3039 | **4524** | 31891 | 23572 |
| latms, 12 cases | **189.8** | 327.3 | 343.9 | 671.7 |
| battms / latms (official rows vs same-process m53) | ~306 | — | 1173 / 332.1 vs 415 / 327.1 | 1082 / 632.6 vs 406 / 338.1 |
| relaxations per cell (JSON) | 1.13 | 1.97 | — | **1.27** |

**What the occasion proves, and it is the mirror of the fourteenth.** I12/I13
cornered the ladder: its rounds cannot be skipped and cannot be widened. I14/I15
corner the schedule from the other side: **the budget was never one mechanism —
it was three amortizations sharing one integer.** (a) Its arithmetic was a
production cut; (b) its zero was a walk-only leaf; (c) its round was a batch
grain for wakes. Delete the integer and each economy must be rebuilt by hand:
m57 rebuilt (b) as the seed and paid for the missing (a) and (c) with a
3.5-hour battery; m58 rebuilt (a) as the deferred cut and (c) as strata, and
its version of (b) is exact on every cost and breaks witness-tie parity. With
all three rebuilt, the Delta engines reproduce the ladder's cone — while paying
heap and event constants the single integer comparison never charged. **The
deepening ladder's 5.8x redundancy (I13) is not waste; it is rent, and it buys
all three economies in one comparison per candidate.** m49 keeps the latency
crown it has held since the eighth occasion; m53 keeps the structural one
(stack safety); m57 now holds the conceptual one: the existence proof that
recovery runs with NO ladder, NO budget, and NO ceiling, at a 2.8x battery
premium, exact on every gate this project has.

The circle this closes is worth one sentence: `dot`, the very first engine, was
already a best-first agenda over (cost, regret) — Dijkstra without the parser
inside it — at 12.9x the baseline. m57 is that same schedule with everything
the budget era learned (the oracle seed, demand-driven cells, the obligation
channel, the in-place value): 2.8x. The remaining 2.8x is the un-amortized
grain of the schedule itself, and I12/I13/I14/I15 together say you do not get
to delete it and keep the ladder's constants too.

### The sixteenth occasion: m59 — the minimal manifestation, and the floor it measures

The fifteenth occasion ended with three engines standing and a directive still
open: the purest possible realization, by collapsing everything the record has
demoted to an optimization. m59 is that collapse, written from the principles
down rather than edited out of a predecessor, and it holds every hard
requirement of the line: sound and exact under lookahead, minimal repairs with
the derived tie-break, a rebuilt and verified witness, stack-safe both
directions, zero parameters. **614 lines against m53's 751 (0.82x), m57's 814
(0.75x), m49's 668 (0.92x)** — and bit-identical to m53 on all 252 smoke inputs
on its first run, 44/44 brute force, 71/71 leak, all six ceiling-gate cases.

**I15, in its minimal form: THE BUCKET QUEUE IS THE DEEPENING LADDER WITH EVERY
ROUND RUN ONCE.** `_buckets[k]` is a plain list; bucket k is drained to its
fixed point (chaotic, LIFO, the memo entry as the message channel exactly as
m51 left it), the goal is read at the boundary, then k+1. That one structure
replaces, simultaneously: the deepening loop (a bucket never re-runs), the
budget argument and all four cut sites (a combination priced past the current
bucket defers itself to where it becomes payable — six lines), the priority
heap and its rank packing (cost classes are all that exactness needs ordered;
inside a class, order is free), and the ceiling with its `_goalFromNothing`
fixed point and predicate tiers (~55 lines): keys are finite and prices only
fall, so every bucket empties, and **an unrepairable input simply runs out of
buckets**. Delta itself is unpacked: the pair `(cost, regret)`, compared
lexicographically — A3 stated instead of encoded — which deletes `_costUnit`,
`_costShift`, `maxCost`, and the overflow reasoning that sized them.

**Checked before building, because it looked like a fourth deletion:** a
quiet-ROUND saturation stop ("no value improved at budget k, so stop") is
UNSOUND — `S <- A A; A <- "xxxxx";` on the empty input is quiet at rounds 6–9
(both fabrication halves finished at round 5) and answers 10 at round 10. The
bucket drain does not have this bug *by shape*: it has no quiet rounds, only
empty buckets, and an empty bucket between two full ones is just skipped.
Recorded so nobody builds the quiet-round stop into a ladder engine again.

**What was deliberately dropped, and its measured price** (each one answer-
neutral by an earlier occasion's gate): the creation-time oracle seed and its
`noLook` pass (the `budget == 0` short circuit, worth ~2x), the I11 edge slots
(~1.1x), the position-rank order (~1.3x steps), the empty-language grammar
analysis (instant −1 becomes a 41-step drain), demand gating by context (the
big one: JSON smoke steps are 10.8x m53's, cells 2.4x, because every
CFG-reachable cell relaxes). m59 is the SLOWEST sound engine since the
combinator era on throughput, and that is the honest shape of the trade — see
its row. What was deliberately KEPT although optional: I4's fusion (19 lines),
so witness trees and work stay spelling-invariant and the smoke gate stays
bit-identical.

**The floor, per section, each answering a named requirement:** builder and
normal form ~85 (the language itself), class algebra ~45 (shared by I4, I6/I7,
the witness narrowing, and `_spelling`), obligation lattice ~45 (soundness —
`unsnd` disqualifies), regret ~40 (A2; deleting it costs 32 shape points, §6),
values and keys ~40 (I1/I9), buckets and relaxation ~45 (termination + stack
safety), the recurrence ~70 (the three node kinds), reconstruction ~95 (the
tree IS the deliverable, and the shortest-head tie-break is output-affecting),
verification ~35 (I5, the proof), entry points and pricing ~90. Nothing in
that list is machinery a future insertion is expected to delete: every earlier
deletion candidate (heap, budget, ceiling, seed, slots, packing) is already
gone. **A quarter-length engine (~190 lines) is not reachable while soundness,
the regret objective, the witness, and the proof are all requirements; ~600 is
where this feature set bottoms out in this formulation, and m59 is the
measured witness to that floor.**

**The price, measured after the row was first drafted, and it is the sharpest
statement of the fifteenth occasion's finding.** m59's §5j quality columns were
scored with `final_table`'s own imported functions (`_score59.dart`: 517/519,
519/519, 0, {1:503, 2:16}, 7/7, 69/69, 0) — the perfect row. Its timing could
NOT be scored by the standard protocol: the official run sat at 58 CPU-minutes
without completing latency case 8 (cost 10 — each call exceeds ~10 minutes;
min-of-5 made the column unmeasurable) and was killed; the row records `>6e5`.
The battery pair, measured alone (`_batt59.dart`, same process, m59 first):
**6172 ms against m53's 387 — 16x.** The stack ceilings could not be laddered or bisected (both harnesses time out
under m59's ungated demand); a direct probe (`_rr59.dart`) confirms **no
overflow at k=512 and k=1024 on the right-recursive 1-error input (cost 1,
correct)** — in 21 and 286 SECONDS respectively, so m59 is stack-safe by
construction and TIME-bound long before it could be stack-bound; k=2048 did
not complete inside a 9-minute window. So
the sixteenth occasion prices the fifteenth's three amortizations exactly:
delete the walk-leaf, the width gating, and the rank order all at once and the
same perfect answers cost 16x on throughput and two orders on the deep-K axis.
Compactness was bought with the clock, one for one.

### The seventeenth occasion: the external review (Codex), checked claim by claim

At the user's direction the full problem — constraints, discoveries, refuted
list, open questions — was briefed to Codex (session
019fb1c5-b512-73e1-9bec-d757cc58dc7a; full output in the session scratchpad),
which read this file and the engines before answering. Nothing below was
accepted on its say-so; each item is marked with what checking it consisted of.
Nothing from this occasion has been BUILT or MEASURED.

**1. Exact minimal repair for arbitrary PEGs is NP-hard (VERIFIED by hand —
the construction is correct, and it re-scopes the complexity claim for the
paper).** Reduce 3-SAT: for a formula with m variables and r clauses,

    Top      <- '@' (Sat / Fallback);
    Sat      <- &C1 &C2 ... &Cr Bit^m !.;      Bit <- '0' / '1';
    Cj       <- Lit(j,1) / Lit(j,2) / Lit(j,3);
    Lit(+xi) <- .^(i-1) '1';   Lit(-xi) <- .^(i-1) '0';
    Fallback <- '#'^(m+1) !.;

on input `"@"`. Every accepted string starts with '@', so the repair keeps it
and fabricates the rest: an m-bit satisfying assignment (distance m) iff the
formula is satisfiable, else the fallback (distance m+1). The grammar is
polynomial (r*3 lookaheads of width <= m), so an exact engine running in
O(|G| n K) on ARBITRARY PEGs would decide 3-SAT in polynomial time. **The
one-character obligation envelope (I6/I7's finite lattice L) is therefore not
an implementation compromise — it is where the tractability boundary actually
lies.** The paper's O(|G| n K) claim must be stated for that envelope (or for
any fixed grammar whose decision states close finitely), with wider lookaheads
sound-but-approximate, exactly as m49+ already behave. This turns §5r's "where
it stops" from an apology into a theorem-shaped boundary.

**2. Why the PEG tag cannot be fixed in the current value domain (CHECKED
against the record — consistent with §5b/§5e/m29/m36's measured failures).**
Ordered choice needs "the earlier branch FAILS on the repaired suffix" and a
possessive stop needs "the body fails there"; those are failure facts about
s', and `V(N,i,c) : (end,owed) -> Delta` carries only success endpoints. No
schedule change can supply them; only a value carrying suspended DECISION
state can.

**3. The suspended-decision alignment tape (design, unbuilt — the strongest
candidate this project has ever had on paper for TRUE PEG exactness).** Run an
exact incremental PEG parser over a lazily-extended repaired string whose open
end SUSPENDS the parse; a suspended state q partitions the alphabet into
transition atoms; recovery is Dijkstra over vertices (input cursor i, state q)
with one SKIP/MATCH/SUB/FAB edge set per atom, priced by A1/A2. **The LR trick
re-applied to a new fact, exactly the shape the project was hunting: a
descendant that reaches the open tape cell marks its memo entry
`waitingForTape` and yields; binding the cell flips one bit and resumes the
ancestral frame that owns the unresolved PEG decision** — ordered choice
commits only after real failure, stops only after real body failure,
predicates read the same future tape, left recursion widens as today. A
memoized `Clean(i,q)` suffix probe replaces the budget-0 walk. Witness = the
settled path itself (predecessor per settled vertex — escapes the record's
parent-pointer refutation because writes are once-per-settled-vertex on a
simple graph, not per memo update; and reparse-of-s' escapes the §6 refutation
because the path IS the alignment the old attempt lacked). Weak points flagged
in review: the shortest-head tie-break becomes a canonical trace in the
priority (hand-wavy, likely expensive); state count Q_K is exponential for
arbitrary PEGs (consistent with item 1 — bounded exactly on the one-char
envelope); empty-language termination needs an emptiness analysis back.
Codex's own honest LOC estimate: 330–445 standalone, 150–265 recovery-specific
if the suspended machine becomes the SHARED parser core.

**4. The memo-resident coroutine (design, unbuilt — the low-risk experiment,
and the elegant completion of an idea this session discarded).** Keep m49's
value, recurrence, ladder, budget, ceiling, and budget-0 walk — all three
measured amortizations — but delete BOTH native recursion and m53's
reader-graph/heap: each memo entry carries `phase, headIndex, tailIndex,
parent, running, ready, foundCycle`, i.e. **the continuation lives in the memo
entry, so the coroutine IS the memo**. A request to an unsettled child parks
the parent (one pointer suffices — exactly one chain runs) and yields; the
child settling sets `parent.ready` — the descendant-to-ancestor memo message
again; a request reaching a RUNNING entry is by construction an ancestor,
hence a cycle: `foundCycle`, provisional value, widen — `inRecPath` /
`foundLeftRec` generalized verbatim from cycles to all waits. Resuming at the
saved cursor over I9's append-only values is what dodges m57's measured
O(width^2) rescan catastrophe. Expected (NOT measured): bit-identical answers,
~1.13-ish relaxations per cell with m53's stack safety, ~500–590 LOC. Checked
against the record: the order-independence claim matches m50–m53's experience;
the cursor-resume interacts correctly with in-place Delta lowering only via
the ancestral re-widen — the detail most likely to bite in a build.

**5. Corrections this review made to this session's own conclusions (ACCEPTED
after checking).** (a) A plain "parser over a generic semiring" is
insufficient — generic `plus` at choice reproduces the CFG-union bug; the
minimal correct functor needs TWO domains, Decision (post/advance/finish/meet
— suspended commitment state) and Value, with ordered choice compiled to
guarded disjoint operations over Decision. (b) The 150–350-line target is
confirmed not credible in the current formulation by an independent section
count of m59 (its split matches §sixteenth's within noise); the minimal
relaxation that unlocks ~150–250 recovery-specific lines is sharing the
suspended-parser core with ordinary parsing — i.e. the freeze on `dart/lib` is
now the binding constraint on compactness. (c) A verified-k-best enumerator
over a relaxed superset (lazy sorted streams, verify candidates in order,
first verified = true minimum) is exponential as an engine but is the right
FULL-PEG ground-truth oracle — strictly stronger than `bf_check`'s
depth-3 BFS — and worth building as gate tooling.

### The eighteenth occasion: m60 — the coroutine measured, and the trade dissolved

The seventeenth occasion's low-risk design was built the same day, and it did
what the review predicted. **m60 (I16: THE CONTINUATION IS A MEMO FIELD)**
keeps m49's recurrence, ladder, budget, budget-zero walk and derived ceiling —
all three of the budget's amortizations — and deletes only the native
recursion: an entry that needs an unsettled child parks (stores itself as the
child's one `parent`, since exactly one chain of computation exists) and the
iterative driver runs the child; on settlement control returns and **the
parent needs no resume record — its step re-derives the awaited child from its
own cursor, finds it settled, consumes it, and advances.** A request that
reaches a RUNNING entry can only be reaching an ancestor of the single chain —
which is what `inRecPath` detected — so it marks `foundCycle`, takes the
provisional value, and the owner's completed pass widens with a version bump
until nothing improves: `MemoEntry.match`'s loop with the frame replaced by a
cursor reset. `running`/`parent`/`foundCycle` are `inRecPath`/`foundLeftRec`
generalized from cycles to ALL waits — the same O(1) descendant-to-ancestor
message through the memo, now carrying "your operand is ready" as well as "you
are a cycle". Resuming at a cursor over I9's append-only values is what
m57's fact-grain wakes lacked; a pass that must see lowered prices re-runs
whole, which is the widening loop's job.

**Measured, official protocol (m53o same process):**

| | m60 | m53o | m49 (same-session `_lat53`/pair context) |
|---|---|---|---|
| battms | **358** | 427 | ~311–340 |
| latms | **203.9** | 296.4 | 189.8 |
| latency case 8 (cost 10) | **176.8ms** | ~294 | 161.1 |
| bisected `cost` ceiling | **k=2160** (the pure parser's own; 3/3 stable) | 2160 | 541 |
| bisected `full` ceiling | **k=1161** | ~1281 | 541 |
| LOC | 780 | 751 | 668 |

Every quality column perfect (`_score60`: 517/519, 519/519, 0, {1:503, 2:16},
7/7, 69/69, 0 — the harness's own scoring functions), bit-identical to m53 on
all 252 smoke inputs ON THE FIRST RUN, `_bf60` 44/44, `_leak60` 71/71, the
ceiling gate 6/6 (and 23ms vs m53's 31ms on the 60-edit case). Demand is the
descent's again: 1557 cells on the smoke battery where the worklist touched
~4400 — the budget-decay cone restored.

**What this settles.** The m49-vs-m53 trade — latency against stack safety,
open since the ninth occasion — is dissolved: m60 is within ~8% of m49 on
latency and ~1.15x on the battery while holding m50–m53's stack ceilings
exactly (the search is oracle-bound at k≈2160; the residual `full` bound is
the witness descent's O(n) walk over the output tree, as it has been since
m50). m53's own reference rows have never beaten 415/327 in this protocol;
m60 beats both columns while carrying the identical perfect quality row. The
external review's prediction (relaxations nearer the descent's grain than the
worklist's) is consistent with the measured step counts. m60 is the standing
engine of the line as of this occasion; m49 keeps a ~8% latency edge for
callers who accept a k≈540 stack ceiling, and nothing else keeps anything.

### Bugs shared by EVERY row, so not repeated per engine (K40 excepts m44 onward)

| tag | defect |
|---|---|
| **PEG** | Repairs toward the **CFG** reading of the grammar, not the PEG one: a possessive `*` and a committed `/` are treated as if any stop or alternative were available. 4 of 5 conformance cases wrong, identically, in every engine back to `dot` (§5b). The `cost` column cannot see it — its grammars are prefix-disjoint, so the two readings coincide there. |
| **RR** | Right-recursive grammars overflow the native stack (the `RRmax` column). Inherited from the pure parser, which shows the same asymmetry; recovery worsens the threshold ~4x because its descent adds frames per position (§8a). Fix is an explicit worklist. **BUILT, m50 — the tag excepts m50, m51, m52, m53 (and their `k` reference rows), the only rows in the table besides `dot` at `>=4096`.** The residual ceiling there is the pure parser's own (k≈2100), which no recovery restructuring can lift, plus the witness descent's O(n)-deep walk over the output tree. |
| **d13** | `del@13` and `swap@13` are never recovered to the original shape. That is exactly the 517/519 ceiling. |
| **K40** | `maxCost` is a hard search ceiling (default 40): a costlier repair is not found at all (cost -1, whole input as one error span). It was the last tuning parameter in the m-line, and **every row from m44 on is without it** (m44, m45, m46, m47, m48, m49, and the `m45h`/`m46i` reference re-measurements) — there the ceiling is DERIVED as `n + fabricate(goal)`, a repair that always exists, so the search cannot stop short of a real minimum (§5n). Every row BEFORE m44 still has the knob and still gives up above 40. |

### Per-engine bug tags

| tag | defect |
|---|---|
| **LR** | Non-minimal repairs on left-recursive grammars — the memo cached its own in-progress placeholder as a final answer, so the left-recursive alternative contributed nothing. Cost 2–3 where truth is 1; from n>=512, no repair at all. Visible as `cost` 32–38/44. Fixed by A5 in m23. |
| **null** | Reconstruction diverges on nullable left recursion (§8). Visible as `tree` 42/44 while `cost` is 44/44 — the cost is right and the witness cannot be built. Fixed by the Ref re-entry guard in m24. |
| **empty** | `RangeError` on empty input; the leading-span loop ran to the budget without bounding by input length (§8). |
| **shape** | Loses shape points against the 517/519 line — see the `shape` column. |
| **slow** | Far off the pace on `battms` and/or `latms`; a recorded negative, not a candidate. |
| **batt** | 20–35% slower on the battery (all K=1) because a complete CFG level 0 replaces m26's O(1) oracle call; buys latency and large-K time back (§5h). |
| **stack** | Stack ceiling collapses — `LRmax`/`RRmax`. m30/m31 fail below 512 in **both** recursion directions. |
| **latent** | A wrong-cost defect behind a flag: m31 with `debugShortcut(true)` reports cost 4 where truth is 1 (§5f). Committed with the shortcut off, which is why its row scores 44/44 and is 15x slower than m26. |
| **pegfix** | Attempts the PEG fix and pays for it: the guard consults the **original** input while PEG semantics quantify over the **repaired** string (§5e). m27 494/519 {1:478, 2:41}; m29 492/519 {1:474, 2:45}, cost 42/44. |
| **over** | Doubling deepening overshoots when K is not a power of two — `latms` 1152 against m26's 269 (§5c). |
| **noop** | Does not do what it was built for: m36's budget-0 PEG guard leaves conformance unchanged, because the illegal parse costs zero edits and resurfaces at round 1 (§5i). |
| **leak** | **UNSOUND — m47 must not be used.** It discharges a pending lookahead at the END of a cons chain, so a chain all of whose elements emit nothing satisfies a *non-empty* constraint vacuously, and the engine names repairs that do not exist: `_leak49.dart` block A, cost 0 where brute force says 1. Every column of its row is clean only because JSON has no lookahead to get wrong. Fixed twice over — m48 enforces at the terminator (sound but blind), m49 hands the obligation out through the value (sound and exact) — §5r. |
| **LOC** | Not a defect — a line-count regression against m26's 382. |
| **dup** | Not an engine: m26 registered a second time, last, to measure the warming-heap bias. |

**Unproven, and not in the table because it is not a measured bug:** the
left-recursion fixed point in every A5 engine (m23 onward) re-runs until no Delta
improves, and that iteration count has no tight polynomial bound in this
derivation — only the measurement that it behaves like a small constant (§5a).

### Every column, defined — and the three that are not what they look like

Definitions below are the harness's own (`final_table.dart:1120-1145` for the legend,
`993-1032` for the scoring loop, `880-905` for the battery), not a reconstruction
from memory. Written down here because the table is now 58 rows wide and a column
misread is a design decision made on a number that does not mean what it says.

- **`engine`** — the row's identifier. Bold rows are engines; a row tagged `dup` is
  **not an engine**, it is an earlier engine re-registered *last* in the same process
  so the pair can be compared without the warming bias (below).
- **`LOC`** — non-blank, non-comment lines of the engine file. The convention
  subtracts instrumentation-only getters (6 lines for m51, 8 for m52/m53), so the
  number is the algorithm, not the probe harness around it.
- **The battery group (`shape`, `cover`, `crsh`, `cost hist`)** — one corpus, built
  at `final_table.dart:880-905`: take the base document
  `{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}`, apply every single-character
  deletion, every adjacent swap, and insertion/substitution of each of
  `Q z } " , 5` at every position, then keep only the mutants that **fail to
  parse** — 519 of them.
  - **`shape`** — the witness tree has the same shape as the *unmutated base
    document's* tree. The strictest quality bar in the table: it asks whether the
    engine reconstructed what the author meant, not merely something legal.
  - **`cover`** — the witness spans the whole input, leaving no region unclaimed.
  - **`crsh`** — mutants on which the engine threw. Any nonzero value is a hard
    defect.
  - **`cost hist`** — histogram of reported repair cost. `{1:503, 2:16}` is 503
    mutants repaired at cost 1 and 16 at cost 2. A single-character mutation
    *should* cost 1, so mass at 2 is over-charging, and the histogram is where a
    minimality regression shows up before `cost` catches it.
- **`valid`** — 7 well-formed documents, which must come back cost 0 with no error
  spans and no missing nodes. "Does recovery stay out of the way when nothing is
  wrong."
- **`cost` and `tree`** — 44 cases across 5 grammars, scored against a brute-force
  minimum edit distance by BFS to depth 3 (`trueDistance`, `684-693`). Two separate
  claims, deliberately not merged: `cost` is only that the **price** is minimal;
  `tree` is that the witness can actually be **rebuilt and covers the input**. The
  scoring loop names why — "m23 passes the first and diverges on the second."
- **`pred`** — exact agreement with brute force on the **lookahead** corner cases.
  The denominator counts only the cases brute force settled outright; the four
  empty-language cases are excluded here and score only in `unsnd`. It exists
  because JSON has no lookahead, so the whole battery is blind to a class of defect.
- **`unsnd`** — how many cases the engine priced **below** the true minimum: repairs
  it claims exist that **do not exist**. The one number in the table that
  disqualifies outright, and the reason `pred`/`unsnd` were added at all — m47 was
  unsound and *every other column of its row was clean*.
- **`eleg`** — 0–10, and the legend flags it in capitals: a **judgment, not a
  measurement**, the only such column. It scores mechanism count,
  derived-vs-chosen constants, adopted-from-the-parser vs invented machinery,
  compactness, and "can it be stated in one true sentence".
- **`bugs`** — defect tags. The shared ones (`PEG`, `RR`, `d13`, `K40`) are inherited
  flaws, not per-engine choices; `LOC` in this column is explicitly **not** a defect,
  only a line-count regression against m26's 382; `dup` marks a reference row.
- **`battms` / `latms` / `/v6`** — wall clock. `battms` is the 519-mutant battery;
  `latms` the sum over 12 latency cases, min-of-5, interleaved; `/v6` normalises
  latency against v6.
- **`LRmax` / `RRmax`** — the largest 1-error input length that completes without
  `StackOverflowError`, left- and right-recursive. `>=4096` means it never overflowed
  at the tested ceiling.

**The three columns that are not what they look like.**

1. **`eleg` is a judgment**, by its own legend. It is not data and must not be
   averaged with the columns that are.
2. **`latms` is a K-axis metric wearing a latency costume.** Measured on the
   fourteenth occasion (`_lat53.dart`): the 12 cases cost
   `2,2,1,1,2,4,2,2,10,1,1,0`, and **case 8 alone — the 64-char shuffle, cost 10,
   11 deepening rounds — is 308.6 ms of m53's 341.1 ms, 90% of the column.** So
   `latms` mostly measures behaviour at *large repair cost*, not on a *large
   document*. On the battery, where damage costs 1–2, m53 is within 14% of the
   descent engines. Any argument of the form "engine X is 1.7x slower" that leans on
   `latms` is an argument about the ladder, not about the per-step constant.
3. **`RRmax` overstates and moves.** It is itself a ladder artifact (~6x
   overstated) and depends on registry position, not only on the engine — see the
   `m26`/`m26b` result three sections down. Open item: bisect, do not ladder.

**And the reading rule that governs every timing in the table:** a single process
warms as it runs, so **timings are only comparable within an adjacent
engine/`dup` pair.** Measured directly: the *same* m26 scored 377 and 314 `battms`
depending on where it sat in the registry. A cross-era timing comparison is not
valid unless a `dup` row bridges it.

### The trade-off, era by era: what each generation bought and what it paid

- **`dot` (797 LOC, 12.39x v6).** The reference: exact (44/44 truth), and the only
  pre-m50 row at `>=4096` on `RRmax`. It pays in size and an order of magnitude of
  latency. Everything after it is an attempt to keep `dot`'s answers at a fraction
  of `dot`'s price.
- **The combinator generation (sd3 / sd5 / v6).** Fast, and the origin of the speed
  baseline. They pay in exactness: `cost` only 32–38/44, carrying `LR` — the memo
  cached its own in-progress placeholder as a final answer, so the left-recursive
  alternative contributed nothing (cost 2–3 where truth is 1; above n=512, no repair
  at all) — plus `empty`. **Traded latency for correctness, and lost the
  correctness.**
- **The simplification arc, m12 → m26 (and m41).** The table's high-water mark on
  compactness: **m26 at 382 LOC, m41 at 379**, with clean `bugs`. A5 fixed `LR` at
  m23; the Ref re-entry guard fixed `null` at m24. This era is still the winner on
  the `LOC` axis and is what everything since is measured against.
- **The dead ends, m27 → m40 — in the table precisely because they are negatives.**
  m27/m29 (`pegfix`) attempted the PEG fix and paid: 494/519 `{1:478, 2:41}` and
  492/519 `{1:474, 2:45}` with `cost` 42/44 — **battery quality traded for a
  conformance fix that did not work**, because the guard consults the *original*
  input while PEG semantics quantify over the *repaired* string. m36 (`noop`) does
  not do what it was built for at all. m30/m31 (`stack`) collapse below 512 in
  **both** recursion directions, and m31 also carries `latent`: with
  `debugShortcut(true)` it reports cost 4 where truth is 1, so its clean 44/44 row
  is clean only because the shortcut ships off — and it is 15x slower than m26 for
  it. The `over` tag records doubling-deepening overshoot, `latms` 1152 against
  m26's 269. **Note that one: it is the same shape as the I13 refutation on the
  fourteenth occasion, found twice by two different routes.**
- **The exactness-under-lookahead arc, m42 → m49.** Where the last tuning parameter
  went (`K40`: from m44 the ceiling is derived as `n + fabricate(goal)`, a repair
  that always exists, so the search cannot stop short of a real minimum), and where
  `pred`/`unsnd` were added *because m47 was unsound while every other column stayed
  clean*. The price was size: LOC 385 → 668. m49 ends the arc sound and exact — the
  obligation travels across inside the value's key `(end, owed)` — at 327 `battms` /
  185.8 `latms`. **~280 lines for exactness on a class of grammar the battery cannot
  see.** Since `unsnd` disqualifies outright, this is the one place in the table
  where paying that much LOC is unambiguously correct.
- **The worklist arc, m50 → m53.** The problem is `RR`: descent overflows the native
  stack on right recursion, and recovery worsens the pure parser's own threshold ~4x.
  An explicit worklist fixes it *structurally*. m50 bought `RRmax` **512 →
  `>=4096`** — m50–m53 are, with `dot`, the only rows at that ceiling — at roughly
  **2.1x m49's battery and 3.9x its latency**. Everything after is repayment with
  every quality column held constant (517/519, 519/519, 0, `{1:503, 2:16}`, 7/7,
  44/44, 44/44, 69/69, 0 unsound): **I9** → m51 (739 LOC, 407/410.1); **I11** → m52
  (374/361.8 vs m51k's 407/410.1, **step-identical at 86849** — same decisions,
  cheaper per decision); **I11's transpose half** → m53 (372/313.1 vs m52k's
  374/361.8, edge slots 133069 → 54742, and it **deletes I10**). Cumulative: m53 is
  **0.91x / 0.76x vs m51 for +12 LOC**, and **1.14x battery / 1.68x latency vs
  m49** — down from 2.21x — with `RR` fixed and a 4x stack ceiling.

**Where the trade-off now binds.** The per-step axis is *measured exhausted*: m49
runs at 1.049 µs/step, m53 at **0.959 µs/step** — a worklist relaxation is now
*cheaper* than a descent step. The entire residual gap is step **count** (1.97
relaxations per cell against the descent's 1.13), and the fourteenth occasion
refuted both ways of attacking it: I12 (cannot skip rounds — the values grow) and
I13 (cannot take bigger rounds — overshooting is exponential). What is left is
making the step infinitesimal, i.e. stratifying on Delta. See that section; it is
not re-argued here.

**The debt, stated plainly.** Every row from m44 onward carries the `LOC` tag, and it
is honest: **nothing since m41 has made the file smaller.** m53 is 751 lines against
m41's 379 — a 2x size regression, bought with exactness under lookahead (m42–m49,
non-negotiable, since `unsnd` disqualifies) and stack-safety on right recursion
(m50–m53, structural and unobtainable any other way). Both purchases are defensible
individually; **neither has yet been collapsed**, so the standing objective — one
unified elegant algorithm — is not met on the compactness axis. Delta-stratification
is the only candidate on the board that removes machinery rather than adding it.
Also still open across *every* row back to `dot`: `PEG` (4 of 5 conformance cases
wrong, and `cost` cannot see it because its grammars are prefix-disjoint), `d13`
(`del@13`/`swap@13` are the entire 517/519 ceiling), and the unproven
left-recursion fixed-point iteration bound — behaves like a small constant, has no
proof.

- **The Delta-schedule arc, m57 → m58 (the fifteenth occasion), added after the
  above was written.** Delta-stratification was built, twice, and it did remove
  the machinery — the ladder, the budget, and the ceiling-as-bound are gone, with
  every quality column held perfect and both stack ceilings at `>=4096` — but it
  did not remove the LINES (814 and 854 against m53's 751) and it did not win the
  clock (battms 1173 vs 415 paired; latms parity). The occasion's finding
  replaces the fourteenth's hope: the budget was three amortizations sharing one
  integer, and a schedule that deletes the integer buys each one back at event
  granularity. See the fifteenth occasion; the compactness objective now has NO
  candidate on the board that is expected to shrink the file, which is itself a
  measured fact about where this design space bottoms out.

### m40 over m39 does not survive a paired measurement

m39 is m40 without the one cached field (`_Entry.zero`, the budget-0 walk held for
the whole run). m40 was picked over it on the strength of "the cache is worth
~10%" -- and that comparison was **between measurement occasions**, m39's numbers
taken on one and m40's on another. The full table above already contradicts it:
m39 is registered EARLIER than m40, so on a colder heap, and still reports 283
battms against 309.

Paired, one engine per process, three runs each, same session:

| | battms | latms | LOC |
|---|---|---|---|
| m39 | 302 / 304 / 312 | 258.8 / 249.8 / 234.1 | 396 |
| m40 | 336 / 337 / 316 | 250.4 / 240.6 / 229.8 | 429 |

So m39 wins the battery by ~8% with nearly non-overlapping ranges, m40 wins
latency by ~3% with ranges that overlap heavily, and m39 wins LOC -- though only
partly on merit: m40's 429 includes the comment-and-rename pass and m39's 396 does
not, which is worth roughly +30 lines.

The obvious defence of the cache is that the battery is K=1, where it can only
cost a field, and that it must earn its keep when iterative deepening runs many
rounds. That was tested and it does not (`_k39.dart`, n=498, min-of-5, isolated,
two runs each):

| engine | K=1 | K=2 | K=4 | K=8 |
|---|---|---|---|---|
| m26 | 8.6 / 8.2 | 16.2 / 18.0 | 86.4 / 80.7 | 560.9 / 499.8 |
| m39 | 6.4 / 8.0 | 12.1 / 14.0 | 77.9 / 73.1 | 539.3 / 494.3 |
| m40 | 6.8 / 6.8 | 12.7 / 15.4 | 76.2 / 74.6 | 492.1 / 495.1 |

m39 and m40 are inside each other's spread at every K; both beat m26 everywhere.
**The cache is not measurable on any workload tried.** Verdict: m39 is the better
engine of the two on present evidence, and the `-` in m39's bugs column was itself
an error -- 396 is a LOC regression against m26's 382 exactly as m40's 429 is, and
the tag was missing. Corrected above.

**Lesson, and it is the same one as the position bias:** a comparison assembled
from two occasions is not a comparison. Both engines must be measured in the same
session, one per process, before a winner is declared.

### Three things this table says that no single row does

1. **`dot` is not LR-broken.** It scores 44/44 on truth, like m23 onward and unlike
   every sd/m engine before m23. Its defects are speed (12.4x v6) and two shape
   points. A tag asserting otherwise was written from the §8 narrative and removed
   when the measurement contradicted it — the §8 claim "every engine up to and
   including m22" covers the sd/m line, not the shipped `dot`.
2. **The `dot` row also has the best stack ceiling in the table** (RRmax >=4096,
   where the whole m-line is 512–2048). Depth and speed trade against each other
   here, and no engine yet wins both.
3. **`RRmax` depends on process state, not only on the engine.** `m26` and `m26b`
   are the SAME ENGINE at two registry positions, and the last one measures
   `RRmax` 1024 against the first one's 512 — **reproducibly, in both runs of this
   table**. So this is a position effect like the ~12% timing bias, not run-to-run
   noise, and a depth number is only comparable between engines measured at the
   same position. Correctness columns (shape/cover/hist/valid/cost/tree) were
   identical across both runs and are order-independent.

### The eleventh occasion: three columns the table was missing (`pred`, `unsnd`, `eleg`)

§5r's complaint about m47 was that its unsoundness was **invisible in every column
of this table**, because the JSON battery and all five `cost`-column grammars have
no lookahead anywhere. A defect the table cannot see is a defect the table will
let through, so the corner cases found while building m45–m49 are now *in* the
table, and the disqualifying direction has a column of its own.

- **`pred`** — exact agreement with brute force over `predCases`: 15 grammars /
  73 inputs at K≤2, in eight labelled blocks (A the m47 leak; B a reader behind a
  name; C a trailing lookahead whose reader is in the *parent*; D the keyword
  boundary `"if" !Alpha`; E PEG commitment; F spelling invariance `(!'"' .)*` vs
  `[^"]*`; G an empty language `&'x' 'y'`; H a lookahead wider than one character,
  where every engine including m49 is approximate and only soundness is required).
- **`unsnd`** — of those, how many the engine priced **below** the true minimum,
  i.e. how many repairs it names that **do not exist**. The one column here that
  disqualifies outright. Over-reporting is safe and lands in a lower `pred`.
- **`eleg`** — 0–10, **and it is a judgment, not a measurement** — the only such
  column. It scores five equally-weighted criteria of the code and the concepts
  (how many mechanisms; derived or chosen; the parser's own idea or invented for
  recovery; compactness as LOC; can it be stated in one true sentence) and says
  nothing about the answers, which have five columns already. It is map-backed in
  `final_table.dart` (`elegNotes`, a `(score, reason)` per engine, reached by a
  getter) so that a score and its justification cannot drift apart, and the
  reasons print under the table so a reader can disagree with a specific score
  instead of with a ranking.

**A process scar first, because it invalidated the first full run.** `pTot` was
incremented as `if (v != 'unk') pTot++;` — counting *verdicts*. But an
under-report on an unrepairable input is *decidable* while a correct decline is
not, so an engine that under-reported more got a **larger denominator**: `dot`
read 57/73 and m49 69/69 off the same 73 cases. Fixed to `if (want != null)
pTot++;` — the denominator counts *truth*, is identical (69) on every row, and the
4 empty-language cases score only in `unsnd`, where naming an impossible repair
belongs. **A per-row denominator is not a metric, it is a ranking of how wrong
each row is.** The whole 44-engine table was re-run.

| engine | LOC | shape | cover | cost | tree | **pred** | **unsnd** | **eleg** | battms | latms | RRmax |
|---|---|---|---|---|---|---|---|---|---|---|---|
| dot | 797 | 515/519 | 519/519 | 44/44 | 44/44 | 57/69 | **8** | 2 | 7609 | 5778.1 | >=4096 |
| sd3 | 499 | 512/519 | 519/519 | 32/44 | 39/44 | 45/69 | 4 | 3 | 437 | 647.9 | 2048 |
| sd5 | 513 | 512/519 | 519/519 | 32/44 | 39/44 | 45/69 | 4 | 3 | 474 | 1018.8 | 2048 |
| v6 | 526 | 512/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 3 | 538 | 480.5 | 2048 |
| m12 | 396 | 516/519 | 519/519 | 33/44 | 39/44 | 45/69 | 4 | 4 | 518 | 463.8 | 2048 |
| m15 | 406 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 4 | 546 | 457.0 | 2048 |
| m16 | 352 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 401 | 466.2 | 1024 |
| m17 | 357 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 415 | 279.4 | 1024 |
| m18 | 373 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 417 | 245.4 | 1024 |
| m19 | 362 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 426 | 255.2 | 1024 |
| m20 | 350 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 1009 | 298.7 | 1024 |
| m21 | 361 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 951 | 276.5 | 1024 |
| m22 | 337 | 517/519 | 519/519 | 38/44 | 44/44 | 55/69 | 5 | 5 | 420 | 246.0 | 1024 |
| m23 | 371 | 517/519 | 519/519 | 44/44 | 42/44 | 55/69 | 5 | 6 | 535 | 291.9 | 512 |
| m24 | 393 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 546 | 275.0 | 512 |
| m25 | 394 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 336 | 251.9 | 512 |
| m26 | 382 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 7 | 362 | 251.9 | 512 |
| m27 | 387 | 494/519 | 519/519 | 44/44 | 44/44 | 52/69 | 5 | 4 | 402 | 213.5 | 512 |
| m28 | 384 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 340 | 1065.1 | 512 |
| m29 | 390 | 492/519 | 519/519 | 42/44 | 44/44 | 53/69 | 4 | 4 | 5098 | 1482.0 | 512 |
| m30 | 382 | 516/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 3 | 5354 | 2059.8 | <512 |
| m31 | 388 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 3 | 5559 | 2576.1 | <512 |
| m32 | 378 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 435 | 247.0 | 512 |
| m33 | 389 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 5 | 414 | 839.4 | 512 |
| m34 | 381 | 516/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 5 | 655 | 1717.3 | 512 |
| m35 | 381 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 468 | 235.7 | 512 |
| m36 | 390 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 4 | 384 | 224.0 | 512 |
| m37 | 385 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 387 | 239.4 | 512 |
| m38 | 407 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 274 | 241.3 | 512 |
| m39 | 396 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 286 | 232.1 | 512 |
| m40 | 429 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 6 | 277 | 229.0 | 512 |
| **m41** | 379 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | **9** | 271 | **136.5** | 1024 |
| **m42** | 381 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | **10** | 276 | 175.4 | 1024 |
| **m43** | 385 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 4 | **10** | 291 | 181.6 | 1024 |
| m44 | 428 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 4 | 9 | 306 | 178.4 | 1024 |
| m45 | 497 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 2 | 7 | 290 | 173.6 | 1024 |
| m44g | 428 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 4 | 9 | 280 | 166.7 | 1024 |
| m46 | 539 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 2 | 8 | 288 | 168.7 | 1024 |
| m45h | 497 | 517/519 | 519/519 | 44/44 | 44/44 | 56/69 | 2 | 7 | 261 | 166.8 | 1024 |
| m26b | 382 | 517/519 | 519/519 | 44/44 | 44/44 | 55/69 | 5 | 7 | 339 | 235.5 | 1024 |
| m47 | 629 | 517/519 | 519/519 | 44/44 | 44/44 | 65/69 | 2 | 4 | 321 | 178.9 | 512 |
| m48 | 656 | 517/519 | 519/519 | 44/44 | 44/44 | 63/69 | **0** | 5 | 349 | 178.1 | 512 |
| **m49** | 668 | 517/519 | 519/519 | 44/44 | 44/44 | **69/69** | **0** | 8 | 352 | 189.4 | 512 |

(`crsh` 0, `valid` 7/7 and `cost hist` `{1:503, 2:16}` on every row except m27
`{1:478, 2:41}` and m29 `{1:474, 2:45}`; omitted here for width.)

**`m49` is the first and only row that is exact on every settled case (69/69) and
sound (`unsnd` 0).** m48 is sound and blind; every engine before m45 names between
4 and 8 repairs that do not exist, and `dot` — the shipped engine, best in the
table on `RRmax` and perfect on the `cost` column — is the **worst** row here at 8.

### Every under-report, with the insertion that killed it (`_predtab.dart`)

A count is not traceable, so `_predtab.dart` prints the per-case verdict grid
behind these two columns, importing `predCases`/`predMaxK`/`truth`/`verdictOf`
from `final_table.dart` so there is no second copy of the battery to drift. Over
the 71 cases *it* settles (its `tot` counts a case if any engine's verdict is
decidable, so its denominator is 71, not the table's 69):

| engine | exact | over | **UNDER** |
|---|---|---|---|
| m41 | 55 | 11 | **5** |
| m44 | 56 | 11 | **4** |
| m45 | 56 | 11 | **2** |
| m46 | 56 | 11 | **2** |
| m47 | 65 | 2 | **2** |
| m48 | 63 | 6 | **0** |
| **m49** | **69** | **0** | **0** |

Each under-report, and what removed it — **every one is a claim §5k–§5r made in
prose, now measured**:

- `S <- A 'b'; A <- 'a' / 'a' 'a' 'a' &'b';` on `"aaab"`: **m41 says 0, truth 2.**
  The free-riding alternative that walks past a PEG commitment. Killed by **I3**
  (m43). §5m argued the veto was necessary; this is the input that shows it.
- `S <- &'x' 'y';` on `"x"` and `"xy"`: **m41 and m44 say 1, truth >2.** The
  grammar's language is **empty**, so no finite repair exists and any number is an
  under-report. Killed by **I4**'s empty class (m45) — §5p's "the empty class is
  the empty language, not a cheap edit", measured.
- `S <- !'x' A; A <- 'x' / "yy";` on `"q"` and `""`: **m41/m44/m45/m46 say 1,
  truth 2.** A reader behind a name; the constraint has to reach a leaf a rewrite
  cannot see. Killed by **I6** (m47/m48).
- `S <- !'x' A D; A <- 'a'? 'c'?; D <- 'd' / 'x';` on `"x"` (and its
  two-rules-deep variant): **m47 says 0, truth 1.** The leak — a chain that emits
  nothing discharging a non-empty obligation vacuously. Killed by **I7** (m49),
  and by m48's strict `_eps` rule at the cost of 6 over-reports.

So the sequence 5 → 4 → 2 → 2 → 2 → 0 is not a smooth curve of polish; it is four
independent defects with four independent insertions, and **each insertion's value
is now a row in a table rather than an argument in a paragraph.**

## 5k. m41: recovery is the parser over a wider value, plus three insertions

**m41 is the first engine that beats m26 on every metric.** LOC 379 against 382,
and it is faster on both timing columns by a wide margin. Every correctness column
ties, and PEG conformance is identical to m26 on all five cases (`_peg41.dart`:
0 differences), so the shared **PEG** flaw is neither fixed nor worsened.

Isolated, one engine per process, three runs each, interleaved, same session:

| engine | LOC | battms | latms |
|---|---|---|---|
| **m41** | **379** | **276 / 275 / 270** | **146.7 / 146.5 / 151.1** |
| m26 | 382 | 391 / 365 / 368 | 255.3 / 252.7 / 253.7 |
| m39 | 396 | 343 / 302 / 309 | 260.3 / 247.7 / 247.3 |

Ranges do not overlap on either column. m41 is ~1.35x faster than m26 on the
battery and **~1.7x faster on latency**, against the whole m-line's 240–270ms
plateau that no engine from m17 to m40 moved.

### The framing: THREE INSERTIONS into the pure parser

Every earlier engine was described as a recovery algorithm that borrows from the
parser. m41 is described the other way round, and the description is the reason it
is smaller:

- **I1 THE VALUE.** A match becomes "the cheapest repair to each end position"; a
  mismatch becomes the empty set. The parser's fixed-point test — *the match did
  not get longer* — becomes *no end is new and no price is lower*. **Every other
  line of `MemoEntry` is copied verbatim**, so left recursion is solved for
  recovery by the observation that solved it for parsing, and no cycle reasoning
  appears anywhere else in the engine.
- **I2 A TERMINAL MAY LIE.** One that does not match may consume a character
  anyway (SUB) or consume nothing (FAB). Price 1 each.
- **I3 A SEQUENCE MAY DISCARD.** Before any element, one character may be consumed
  by no terminal (SKIP, price 1) and the same element retried. Only a sequence has
  a "between", so this is the only combinator carrying any recovery logic.

### Currying is what makes I3 free — the dot was a symptom, not a mechanism

I3 needs a memo entry per element boundary; the parser memoizes whole clauses.
Every engine from `dot` to m40 bought that with an explicit dot: `_memoBase`
blocks, `_nextDot`, `_hasElement`, `_canFinish`, `_elementAt`, `_alternatives`,
and per-clause dot arithmetic. **Curry the sequence into binary `Cons(head, tail)`
cells and every element boundary already IS a clause**, so the memo key goes back
to the parser's own `(clause, position)` and all of that machinery is deleted.

Three further unifications fall out, each deleting a concept rather than lines:

1. **A REPETITION IS A CONS WHOSE TAIL IS ITSELF** (`identical(node.tail, node)`).
   That single identity replaces `requireOne` (one Cons in front of the loop),
   "may this item stop here", "does an element still follow", and the parser's
   zero-width repetition cut.
2. **There is no node kind for a rule reference.** In the parser a `Ref` is
   distinguished by being the only clause that consults the memo; here every node
   consults it, so a Ref is left being an alternation among one. Three node kinds
   remain: terminal, cons, alternation.
3. **Every node denotes a clause** — the cons cell at element *i* denotes the
   sequence's suffix from *i*, which is a clause in its own right. So `orig` is
   total, and A4's budget-0 walk is ONE oracle call for any node, not a hand-rolled
   chain walk.

Acceptance is also asked of the oracle now: `h(c)` matches each terminal against a
one-character input and accepts iff it consumes it, so the engine no longer
re-implements what a `CharSet`, `Char`, `Str` or `AnyChar` means (`_accepts`,
deleted). That is both shorter and strictly more correct — the old ternary chain
crashed on a zero-length `Str` and answered `true` for any terminal kind it did
not enumerate.

### `_withinBudget` was dead weight, and it was expensive

Filtering a memoized map down to a smaller budget on every reuse is unnecessary:
every consumer already rejects over-budget values (`_chain` guards `total < limit`
and gets `{}` from a negative budget; the alternation union now applies the same
limit; reconstruction compares Δ exactly). Deleting it changes no answer and is a
large part of the latency win — the m-line had been re-filtering and re-allocating
maps on every memo hit since m23.

### The zero-width cut is an optimization, not a rule (measured)

Deleting `if (loops && head.key == pos) continue;` from the forward pass changes
**no reported cost, tree or span** — 517/519, 519/519, 0 crashes, {1:503, 2:16},
7/7, 44/44, 44/44, all identical. A zero-width iteration re-enters the identical
state, which is exactly left recursion, and I1's fixed point absorbs it: the
re-composed candidate is never cheaper, so no Δ improves and the iteration
converges. **The parser's own zero-width cut and this one are therefore the same
observation as the left-recursion cycle check, not a separate rule.** It is kept
only because latency doubles without it (300ms against 148ms). Reconstruction, by
contrast, genuinely needs it: a zero-width iteration there does not decrease Δ or
advance the position, so a Δ-exact descent would recurse forever.

### Refuted: an exactness bit cannot make the budget a memo-free dimension

The left-recursion trick communicates an arbitrary distance up the recursion tree
in O(1) by setting a bit on an ancestral memo entry. The obvious analogue for
recovery is a **budget-exactness bit**: mark an entry exact iff nothing below it
was discarded for exceeding the budget, propagated by a monotone global counter
exactly as `memoVersion` propagates — an exact entry could then be reused at every
budget instead of only at budgets it was computed at or above. Its stronger form
stores the minimum dropped cost `d`, making the entry valid at every budget `< d`.

**Both degenerate to nothing, by construction.** FAB is available at price 1 at
every position, so candidates exist at *every* cost: at budget `b`, a head costing
1 composed with a tail costing `b` always produces a dropped candidate at cost
`b+1`, giving `d = b+1` and validity only up to `b` — which is what the entry
already records. **No entry is ever budget-exact.** This also explains m30, which
computed a complete level 0 to avoid exactly this recomputation and measured 14x
slower. The budget stays a filter on Δ (A3), not a memo key, and iterative
deepening keeps re-descending. Do not re-litigate.

## 5l. m42: there is no third edit

m41 was stated as **three insertions** into the pure parser: I1 the value, I2 a
terminal may lie (SUB/FAB), I3 a sequence may discard (SKIP). m42 deletes I3.
**Deletion is not a primitive and needs no rule of its own** — it is I2's SUB,
applied to `Nothing`:

> To substitute a terminal is to consume the character in front of it and emit
> what the terminal accepts instead. What `Nothing` accepts is the empty string.
> So *its* substitution consumes a character and emits nothing — which is
> deletion, exactly, at the same price of one.

Repeat that move — a cons whose tail is itself, which is all a repetition is —
and a run of characters has been discarded, one unit each. That two-node object
is `_junk`, and `_compute` gains **no case** for it.

The tell that this is the right decomposition: **m41 already contained the
exclusion that forbids it.** m41 built terminals with
`_term(clause, clause is Terminal && clause is! Nothing)` — every terminal may
lie *except* `Nothing` — and then hand-wrote I3 to supply what that clause had
just been forbidden to do. m42 deletes the exclusion and the insertion together.

A first attempt used `CharSet([])`, the empty character class, on the argument
that a class accepting nothing can only ever consume a character it does not
accept. It measured identically and it is **wrong on the semantics**: SUB emits
some character the terminal accepts, and the empty class accepts none, so there
is nothing for it to emit and the repaired string is not defined. `Nothing`
accepts exactly one thing, the empty string, which is what a discarded character
must leave behind. Prefer the derivation that survives being read.

### SUB stopped being conditional, and that is what made it work

m41 (and every engine before it) guarded SUB with `if (m.isMismatch && ...)`: only
a terminal that fails may substitute. That guard is a **dominance argument in
disguise**, and it is only valid for terminals that match exactly one character —
if the terminal already consumes `input[pos]` for free, SUB reaching the same end
at price 1 is pointless. `Nothing` matches with length 0, so its SUB reaches a
*different* end and the guard silently deleted it.

The fix is to state the dominance where dominance already lives — the min:

```dart
if (pos < _inputLen) {
  _keepBest(out, pos + 1, _costUnit + 2 * _skipRegret(pos, pos + 1));
}
```

**One fewer condition, and correct for terminals of any width.** No case asks
whether the terminal matches; if it does, and it took that character, it is
already in the map at a lower price and the min keeps that one.

### A4 corrected: a gap attaches in front of a READER, not in front of a terminal

m41's A4 was "only a sequence has a *between*". m42's first draft over-corrected
to "the canonical point is the terminal that follows the gap", with the argument
that everything between the gap and that terminal consumes nothing, so nothing is
lost by pushing the gap all the way down. **That argument is false, and the
counterexample is the syntactic predicate.** A predicate consumes nothing, but
what it decides depends on *where it is asked*; pushing a gap past it silently
loses every repair the predicate blocks. Measured, on `_pred42.dart` (4 predicate
grammars, 19 inputs, brute-force truth): the draft was **wrong on 11 of 19**,
returning −1 (unrecoverable) where m41 returned 1.

The rule that survives:

> **A gap attaches in front of whatever READS the input next** — a terminal that
> consumes a character, or a predicate that only looks at one. `Nothing` is the
> one leaf whose value does not depend on position, so it is the one leaf a gap
> can never attach to.

Only *consuming* terminals may lie, though: a predicate consumes nothing, so
substituting or fabricating one would edit the derivation rather than the string,
and only the string is being repaired. So the wrapper is built for both, and the
editable flag is set for one. After the fix, m42 is wrong on **3 of 19**, which is
exactly m41's 3 of 19 — see the new **PRED** tag below.

### What the collapse buys

1. **One fewer edit primitive**, and the one that remains is derived rather than
   inserted. `_chain` is now `Seq.match` verbatim over I1's value — *no combinator
   in the engine contains any recovery logic at all.*
2. **One fewer ambiguity.** m41 attached a gap at every enclosing sequence whose
   current element began there, so one repair had as many derivations as the
   grammar had nesting. In m42 a gap has exactly one attachment point.
3. **One fewer heuristic.** m41 merged consecutive unit SKIPs into one reported
   span. A discarded run is ONE node here — the self loop is one node — so it
   arrives as one leaf already, and the merge pass is deleted.
4. **One shared memo column for the whole grammar.** There is exactly one `_junk`,
   so every terminal in the grammar shares its column; m41 re-derived the same
   skip at every sequence cell.

Reconstruction needed one new idea to keep the tree flat: `_child` returns a
*list* — a sub-derivation's contribution to the row it sits in — because two
things are not levels of the tree. A discarded run is one leaf and not a parent
of the terminal after it, and the wrapper that carries it is an artifact of I2,
not a clause. A clean parse therefore still reconstructs to exactly the pure
parser's tree (measured: `shapeDiff=0`, `spanDiff=0` against m41 on 156 mutants).

### The price: making the gap a clause costs 30% more states

This is the honest cost, and it is a constant factor, not an order.

| | K=1 | K=2 | K=4 | K=8 |
|---|---|---|---|---|
| m26 | 8.2 | 15.4 | 78.8 | 531.2 |
| m41 | 9.7 / 9.3 | 7.5 / 7.7 | 54.4 / 53.8 | 304.0 / 313.3 |
| m42 | 5.3 / 6.6 | 11.5 / 12.5 | 67.6 / 64.2 | 400.3 / 393.8 |

(`_k42.dart`, n=498 JSON, min-of-5, one engine per process, two runs each.)

`lastSteps` — the number of `_compute` calls — localizes it exactly
(`_steps42.dart`):

| K | m41 | m42 | ratio |
|---|---|---|---|
| 1 | 5945 | 7802 | 1.31 |
| 2 | 20922 | 27431 | 1.31 |
| 4 | 78242 | 101916 | 1.30 |
| 8 | 222678 | 289734 | 1.30 |

**The ratio is 1.30 at every K: m42 does not do more work per state, it has more
states.** The reason is structural and unavoidable in this design — a gap that is
a clause needs a node, so every terminal clause gains one wrapper cell, and
terminals are about half the nodes in a curried grammar. The alternative that
would recover it is to fold the gap into `_Term._compute` as a fixed point over
positions (`E(t,pos) = base ∪ skip1 ⊗ E(t,pos+1)`), which costs no node at all —
and which is a hand-written third insertion again. **That trade was refused: the
whole point of m42 is that no combinator contains recovery logic.**

Against the champion it replaces, m42 wins every column (m26d: 382 LOC, 379
battms, 255.3 latms, RRmax 512 — m42: 381, 280, 174.5, RRmax 1024). Against m41
it is a wash on the battery (280 vs 282), 1.2x slower on latency, 1.5x *faster* at
K=1 on the K-sweep, and +2 LOC. **m41 remains the faster engine at K≥2 and m42 the
simpler one.** Do not report m42 as a speed win; report it as the design where
deletion stopped being an axiom.

### New shared bug tag: PRED

| tag | defect |
|---|---|
| **PRED** | Syntactic predicates are evaluated by the ORACLE, on the ORIGINAL input, never on the repaired string. A repair that changes what a predicate reads is therefore invisible. **This tag understated the damage for three engines; see §5o for the brute-force measurement that corrected it.** It is NOT confined to "reports a cost that is too high" (3 of 19 in `_pred42.dart`): against ground truth it also **loses repairs entirely** (`-1` on a repairable input) and **under-reports with a repair that cannot parse**. Same root cause as **PEG**: negation in a repair semiring is ill-defined, because FAB makes every clause matchable somewhere. **Shared by m41 through m44 identically** — not an m42 regression. **m45 is the first row where it is partly fixed**: a lookahead at ONE character in front of a terminal is rewritten into the class the two compose, which is exact, and against ground truth m45 scores 42/45 where m44 scores 30/45 (§5p). What remains under this tag there is the lookahead whose reader is behind a rule reference, one wider than a character, or one last in its sequence. |

## 5m. m43: the oracle is authoritative as far as the edit-free window reaches

m42's `_Alt` was described in its own header as `First.match` over I1's value.
That was **false**, and the falsehood was a plain union:

```dart
for (final alternative in alts) {
  for (final e in _ends(alternative, pos, budget).entries) {
    if (e.value < limit) _keepBest(out, e.key, e.value);   // m42: the CFG's union
  }
}
```

A union is a CFG's choice, not a PEG's. PEG takes the FIRST alternative that
matches, and every engine from m12 to m42 threw that away — §5b records it as the
line's central flaw ("every engine repairs toward the CFG, not the PEG"), and
§5e records the one attempt to fix it locally (m29) costing 2 shape points and 2
ground-truth points for nothing.

**I3 fixes it in four lines, for free, and the principle generalises far past the
one site:**

> A sub-derivation that spends no edits over `[pos, end)` is a claim that the
> repaired string s' EQUALS the input there. Over that window the oracle — the
> pure parser, on the original input — is not an approximation of PEG on s': it
> **is** PEG on s'. So wherever PEG makes a decision the window already
> determines, the oracle's answer is the only legal one.

```dart
final oracle = _parser.match(node.orig, pos);
final committed = oracle.isMismatch ? -1 : pos + oracle.len;
...
if (e.value < _costUnit && e.key > committed) continue;    // m43
```

### This is the budget-0 rule, applied to a part instead of the whole

`_compute` already contained the same idea at full scale (§5i):

```dart
if (budget == 0) { final m = node.orig.match(_parser, pos); ... }   // window = everything
```

At budget 0 the window is the entire input and the oracle decides *everything*.
At budget k the window is whatever each candidate paid nothing for, and the
oracle decides exactly that much. **One rule, interpolating between the two ends
that were already in the file.** m42 wrote one end and not the other.

### The complete enumeration: where PEG decides, and what I3 does there

This list is the reason to believe I3 is finished rather than a first instalment.

| PEG decision | I3's verdict | why |
|---|---|---|
| **ordered choice** (`First`) | **vetoed** | the decision is made by the first alternative that MATCHES, and a match is CONSUMPTION: if it ends inside the window it still holds in s'. |
| **optional** (`a?`) | **vetoed, same code** | `_node` builds it as an `_Alt` of `[a, eps]`, so it needs no separate rule. |
| **repetition stop** (`a*`) | **must not be vetoed** | the decision is made by the first item that FAILS, and a failure consumes nothing — it is witnessed AT the far edge of the window, where s' is unconstrained. |
| **predicate** (`&a`, `!a`) | this is the **PRED** flaw, exactly | a predicate is evaluated by the oracle as if the window were infinite. I3 does not fix it, but it explains it: the missing check is "does the window cover what the predicate read". |
| **left-recursive growth** | already the oracle's | A5/I1; and see the bug below, which is the growth loop being skipped. |
| **whole input consumed** | the goal node | no decision left. |

### Why the repetition may not be vetoed — the counterexample

`S <- 'a'* 'b' 'a'` on `"aa"`. Truth 1: the repair is `"aba"`. That repair needs
the star to STOP at position 1, where the input still offers `'a'` and the oracle
would have continued to 2. Vetoing "stop where the item still matches" would
delete the only minimum-cost repair. **A choice is witnessed by consumption
inside the window; a stop is witnessed by a failure at its edge.**

There is a second, independent reason, and it is the more important one for a
recovery engine: a sound repetition veto would push the engine toward reporting
*unrepairable* for grammars like `S <- 'a'* "ab"`, whose PEG language is EMPTY
(conformance cases 1 and 2, truth `>3`). Reporting "no repair exists" is
PEG-correct and useless. Repairing toward the CFG reading there is the better
answer, and §5b's flaw is, in that one respect, a feature. **I3 takes the PEG
side of the trade only where it costs nothing.**

### The bug found on the way: `Clause.match` is not `Parser.match`

The first build of the veto REGRESSED ground truth (43/44): `E <- E '+' T / T`
on `"1+2++3"`, truth 1, reported 2. Measured, not guessed (`_probe43.dart`):

| at pos 0 of `"1+2++3"` | result |
|---|---|
| `ref.match(parser, 0)` | len 3 |
| `body.match(parser, 0)` (raw combinator) | **len 1** |
| `parser.match(body, 0)` (memoized entry) | len 3 |

`Clause.match` is the raw combinator. **The loop that expands a left-recursive
cycle lives in `MemoEntry.match`, and is only reached through `Parser.match`** —
which is exactly why `Ref.match` delegates to it (`combinators.dart:168`). Asked
at a rule BODY, the raw call returns the left-recursive SEED, so `committed` came
back as 1, and the veto killed the legitimate cost-0 sub-derivation `E(0,3)`.

Every other oracle call in the engine is asked at a `Ref`, a terminal, or a
sequence of them, where the raw call already routes through the memo — which is
why this never bit before, and why the m42 hole hypothesised from this discovery
**does not exist**: `_compute`'s budget-0 fast path can only reach a rule body
through a Ref node, and the Ref's own fast path returns first. That was checked
(`_probe43.dart` part 2: `S <- 'z' E` with the budget spent before `E`, m26/m41/m42
all report truth). Fixed by asking the memo: `_parser.match(node.orig, pos)`,
keyed by the body clause, which is the very entry the parser itself uses for that
rule — so it costs a memo hit and nothing else.

**Lesson, general:** in this codebase `x.match(parser, pos)` and
`parser.match(x, pos)` are different functions. The first is a combinator; the
second is the algorithm.

### The one unproved step

A match may CONSULT input it does not consume — a lookahead, or a longer
alternative that failed inside it. If the oracle's alternative read past the
vetoed candidate's own end, s' could break it there and the candidate was legal
after all. Bounding this needs a per-match high-water mark of consulted
positions; `Parser` does not record one (`syntaxErrorPosition()` is a global scan
over mismatches, not a per-match extent), and recovery may not add one. So the
veto is **exact for any alternation whose alternatives read no further than they
consume, and conservative in the safe direction otherwise: it can only make a
reported cost too HIGH, never too low** — and a vetoed cost-0 candidate is always
replaced by a cost-≥1 one, so it can never make a repairable input unrepairable.
`_bf43.dart` checks it against brute-force PEG truth: 44/44.

### Measured

| gate | m42 | m43 |
|---|---|---|
| PEG conformance (`_peg43.dart`) | 0 / 5 | **2 / 5** — `committed choice` and `committed nested` now report the true cost 1 |
| ground truth (`_bf43.dart`, 5 grammars, 44 inputs) | 44/44 | 44/44 |
| predicates (`_pred43.dart`, 19 inputs) | 3 wrong | 3 wrong (unchanged, all PRED) |
| JSON mutants (`_smoke43.dart`, 156) | — | costDiff 0, shapeDiff 0, spanDiff 0, coverBad 0 |
| battery / latency (§5j) | 287 / 181.6 | 293 / 178.5 |
| `_compute` states at K=1/2/4/8 | 7802 / 27431 / 101916 / 289734 | identical |

**Two conformance cases go from wrong to right for the first time in the whole
m-line, and every other number is unchanged.** The state counts being identical
is not luck: JSON's alternations are prefix-disjoint, so the veto removes nothing
there and only costs the oracle call, which is a memo hit.

+4 LOC (381 → 385), all four of them in one case of `_compute`.

## 5n. m44: the ceiling is derived, not chosen

`maxCost = 40` was the last tuning parameter in the m-line, and it was never a
trade-off — it was the K40 defect in §5j, on every row: **a repair costing more
than 40 is not reported at all.** The caller gets `-1` and the whole input as one
error span, which is indistinguishable from "this input cannot be repaired". A
long broken document and a long missing literal both hit it, and neither is
exotic (`_ceil44.dart`).

The fix is not a bigger number. It is noticing that the number was always
derivable:

> **The trivial repair always exists.** Fabricate the goal consuming nothing, and
> discard the entire input as junk — `[0, p)` in front of the fabrication and
> `[p, n)` behind it. By A1 the junk costs `n`, one unit per character, wherever
> it is split. So no minimum-cost repair can exceed `n + F`, where `F` is the
> cheapest fabrication of the goal from nothing, and **deepening past `n + F` can
> only fail.**

That is a ceiling in the same sense `_costUnit` is a bound: forced, not set. The
parameter is gone, and with it K40 — m44 is the first row in §5j that always
reports the true minimum.

### F is a least fixed point, one rule per node kind

`F` is a property of the grammar alone, so it is computed once per engine
(`late final _goalFromNothing`) and never per input:

| node | price from nothing | why |
|---|---|---|
| consuming terminal | 1 | it is not there; fabricate it — I2's FAB |
| `Nothing` | 0 | the empty match is already there |
| cons cell | head + tail | a sequence pays for all of its elements |
| cons cell whose tail is ITSELF | 0 | that is a repetition: stop at zero iterations |
| alternation | min over branches | take the cheapest branch |

Relax until nothing improves, over the nodes reachable from the goal. The rules
are their own seeds — a terminal's price depends on nothing — so no separate
initialisation pass exists, which is what makes it the same shape as every other
fixed point in the file.

`F` can be exponential in `|G|` (`S <- A A; A <- B B; B <- C C; C <- 'x'` prices
8 from 4 rules), which is why the ceiling is computed and not bounded by a node
count, and why deepening-by-doubling is not a substitute (below).

### The predicate is the one leaf that may not be counted

The first version of this priced a predicate at 0 — "assume it passes" — and that
lost repairs m43 still found. `_pceil44.dart`, case 1:

```
S <- &'x' 'x' / 'y' 'y' 'y' 'y';      input ""      predicate-free ceiling 4
```

The cheap branch is blocked by a predicate that cannot pass at any position, so
the trivial repair m44 may build a ceiling from is the 4-fabrication branch; the
ceiling was priced at 1 from the branch that does not exist; the search stopped
at 1 and reported `-1`. **That is K40 again, re-introduced by the thing that was
deleting it.**

**Correction to an earlier version of this line, which called 4 the "truth":
the true edit distance here is 1** — `"x"` is in the language, one fabrication
away — and m44 answers 4, because the only derivation that reaches `"x"` crosses
a predicate and m44 cannot price one. 4 is the cheapest repair whose derivation
contains NO predicate, which is the only kind of repair a ceiling may be built
from, and that distinction is the whole content of the three tiers below. m45
answers 1: §5p fuses `&'x' 'x'` into the class `[x]`, and a class is not a
predicate, so tier 1 prices it at 1 and the search finds it.

The correction is a fact about position, and it is the sharpest statement of what
a predicate is in this whole design:

> The derivation being priced **has no position of its own** — junk absorbs the
> input on either side of it at the same total either way. A predicate **does**
> have one: it is the one leaf whose answer depends on where it is asked, and no
> edit can change that answer, because I2 lets a leaf lie about the STRING and a
> predicate consumes none of it. So the only derivation guaranteed to exist
> wherever it is placed is one that contains **no predicate at all**.

Three tiers, in order, each falling through only when the one above is
impossible:

1. **Price predicates as impossible.** What survives is a derivation that holds
   at every position; its cost is a true ceiling.
2. **Trust them.** Reached only when EVERY derivation of the goal needs a
   predicate. This is the PRED envelope (§5l) and the only assumption in the
   file — the ceiling may now be too low, which can cost a repair, but the
   alternative is an infinite ceiling and no answer at all.
3. **Neither works ⇒ the goal has no finite derivation.** The grammar's language
   is empty (`S <- S 'a'` and its kind), so no input is repairable at any price,
   and the caller is told `-1` **without a search**.

Tier 3 is a small bonus that fell out for free: an empty language used to be
found by exhausting the budget, and is now answered from the grammar.

### Why the I3 veto can never block the trivial repair

m43's veto drops a cost-0 candidate that ends past `committed`. The ceiling is
only a ceiling if the repair it prices is one the search can actually reach, so
the veto must never touch it. It cannot, and the argument is structural rather
than measured:

* If a node has a cost-0 fabrication at `p`, every leaf in it is a predicate, a
  `Nothing`, or a zero-iteration repetition — none of which consume input. So the
  pure parser also matches that node at `p` (possibly longer), hence
  `committed >= pos`, and the empty candidate `end == pos` is kept.
* Junk is a `_Cons` self-loop, not an `_Alt`, so the veto — which lives in the
  alternation — never sees it; and its candidates cost >= 1, which the veto does
  not consider at all.

### Measured

| gate | m43 | m44 |
|---|---|---|
| ground truth (`_bf44.dart`, 5 grammars, 44 inputs) | 44/44 | 44/44 |
| PEG conformance (`_peg44.dart`) | 2/5 | 2/5 |
| predicates (`_pred44.dart`, 19 inputs) | 3 wrong | 3 wrong (identical) |
| JSON mutants (`_smoke44.dart`, 156) | — | costDiff 0, shapeDiff 0, spanDiff 0, coverBad 0; shapeOk 144 both |
| ceiling (`_ceil44.dart`, truths 60 / 46 / 30) | -1 / -1 / 30 | **60 / 46 / 30** |
| predicate ceiling (`_pceil44.dart`, 6 cases) | 4 4 0 -1 1 -1 | identical |
| battery / latency (§5j) | 306 / 182.9 | 303 / 181.0 |
| `_compute` states at K=1/2/4/8 | 7802 / 27431 / 101916 / 289734 | identical |

**Nothing on a normal workload moves.** The ceiling is a grammar computation in a
`late final`; on inputs whose repair is affordable, it is never the binding limit
and the search is the same search.

### What completeness costs where it bites (`_env44.dart`)

| grammar | n | m43 | ms | m44 | ms |
|---|---|---|---|---|---|
| `S <- 'x';` on junk (cost = n) | 30 | 30 | 18 | 30 | 11 |
| | 60 | **-1** | 8 | **60** | 21 |
| | 120 | **-1** | 4 | **120** | 72 |
| | 240 | **-1** | 3 | **240** | 541 |
| | 480 | **-1** | 3 | **480** | 4410 |
| | 640 | **-1** | 3 | **640** | 11326 |
| JSON on a run of quotes | 16 | 6 | 7 | 6 | 9 |
| | 48 | 17 | 115 | 17 | 118 |
| | 100 | 34 | 1463 | 34 | 1426 |
| | 150 | **-1** | 2553 | **51** | 6085 |
| | 200 | **-1** | 2551 | **68** | 17258 |

Two honest readings:

* Below the old ceiling the engines are the same engine, to within noise.
* Above it, m43 does not answer *quickly* — it burns 2.5 s on JSON at n=150 and
  then says `-1`. Completeness costs ~2.4x there, not infinity.

The growth is ~8x per doubling of n once the repair cost grows with n
(541 -> 4410 from n=240 to 480), i.e. **cubic**, and that is the predicted shape,
not a surprise: iterative deepening runs rounds 1..K and a round is O(|G|.n.k),
so the sum is O(|G|.n.K^2), which is n^3 when K grows like n. The re-expansion
factor is inherent to deepening from scratch; carrying a memo across rounds is
not available, because an entry computed under a smaller budget is not valid at a
larger one (A3: the budget is a filter, not a key). **Open lever, not a bug.**

### The price, stated plainly

+43 LOC (385 -> 428): the reachable-node walk, the two-tier fixed point, and its
derivation. That earns the `LOC` tag in §5j — m44 is the second-largest engine in
the line — and it is the whole cost. What it buys is the deletion of the last
tuning parameter and the deletion of the last shared bug that produces a WRONG
ANSWER on ordinary input.

### Refuted on the way

| alternative | why it lost |
|---|---|
| keep `maxCost`, raise the default | The knob is the defect; a bigger number moves the input that breaks it, and zero tuning parameters is a hard requirement. |
| deepen by doubling until a repair is found | Never terminates on an unrepairable input, and the "is it repairable at all" test is the same fixed point anyway. It also overshoots the true minimum by up to 2x, which at ~K^3 is ~8x the work on exactly the hard inputs that motivated this. |
| stop when a round drops nothing for exceeding the budget (IDA*) | FAB makes candidates exist at EVERY cost, so something is always dropped and the test never fires. Same reason §5k refuted the exactness bit. |
| price predicates as passing, no fallback tier | Loses repairs, measured: `_pceil44.dart` case 1, `-1` where the truth is 4. |
| price predicates as impossible, no fallback tier | Ceiling becomes infinite whenever every derivation needs a predicate, so the search never terminates on unrepairable input. |
| exact per-position `F(p)`, minimised over p | Tighter, but O(n.|G|) per input rather than once per grammar, needs the same predicate fallback anyway, and would put work in the path of the sub-millisecond one-typo case for no gain — the ceiling is not the binding limit there. |

## 5o. PRED measured against ground truth: the tag was wrong in both directions

The **PRED** tag has said the same thing since m41: predicates are answered by
the oracle on the original input, so "the engine reports a cost that is too
high". That claim was never tested. It came from `_pred4x.dart`, which compares
against truths **I wrote down by hand**, and the brute-force gate that could have
checked it — `_bf4x.dart`, BFS over single-character edits with the pure parser
deciding membership — **has no predicate in any of its five grammars.**

`_bfpred44.dart` is that gate pointed at predicate grammars. **18 of 28.**

| grammar | input | truth | m43 | m44 | |
|---|---|---|---|---|---|
| `S <- &'x' 'x' &'y' 'y';` | `zz` | 2 | **-1** | **-1** | LOST |
| | `z` | 2 | **-1** | **-1** | LOST |
| | `` (empty) | 2 | **-1** | **-1** | LOST |
| | `xz` | 1 | **-1** | **-1** | LOST |
| | `zy` | 1 | **-1** | **-1** | LOST |
| `S <- !'x' A;  A <- 'x' / "yy";` | `q` | 2 | **1** | **1** | UNDER-REPORT |
| | `` (empty) | 2 | **1** | **1** | UNDER-REPORT |
| | `xy` | 1 | 2 | 2 | too high |
| `S <- !'x' 'b';` | `x` | 1 | 2 | 2 | too high |
| `S <- 'a' !'x' 'b';` | `ax` | 1 | 2 | 2 | too high |

Two failure modes the tag denied:

* **LOST — a repairable input reported unrepairable.** `L(S) = {"xy"}` for the
  first grammar, so `"zz"` is two substitutions away. The oracle is asked `&'x'`
  at every position of `"zz"`, where it can never pass, so no budget ever admits
  the repair and the engine answers `-1`. **This is the same severity class as
  K40, the defect §5n just deleted** — and it is not a ceiling artifact: m44's
  derived ceiling for `""` is exactly 2, the true cost, and the search still
  finds nothing.
* **UNDER-REPORT — a reported cost lower than any repair that parses.** For
  `S <- !'x' A; A <- 'x' / "yy"` on `"q"`, the oracle says `!'x'` passes (the
  input has `q` there), so the engine takes the cheap branch and SUBs `q -> x`
  for a cost of 1. On the REPAIRED string `"x"` the predicate is false. Brute
  force enumerates every 1-edit string and none is in `L(S)`; the truth is 2
  (`"yy"`). **The engine returns a cost for a repair that does not exist.**

### The diagnosis, in one sentence

A predicate is a constraint on a CHARACTER OF THE REPAIRED STRING, and the
engine answers it from the input, because the character's value is not decided
where the predicate is asked — it is decided by whichever reader emits it, which
is somewhere in the CONTINUATION.

That is the same shape as I3 (§5m) and its exact mirror image. I3 says the
oracle is authoritative as far as the edit-free window reaches, and uses it to
DROP candidates. A predicate asks about a position the window may not cover, and
there the oracle's answer is not conservative in either direction: `false` on the
input where a repair would make it true loses repairs, and `true` on the input
where a repair makes it false invents them.

### Why the obvious repairs do not work

| candidate | why it fails |
|---|---|
| assume every predicate passes | Loses nothing, invents everything: the `&'x' 'x'` grammar would report 1 for `"zz"` via a derivation whose predicate is false. Under-reporting is the worse direction — it hands back a repair that does not parse. |
| assume every predicate fails | Sound, and useless: any grammar whose derivations all cross a predicate becomes universally unrepairable. |
| make the predicate editable (pay to satisfy it) | Double-charges. `&'x' 'x'` on `"zz"` would pay 1 for the predicate and 1 for the terminal to change the SAME character — 4 where the truth is 2. |
| evaluate the predicate on the repaired string | That is the right answer and it needs the repaired string, which is exactly what the value abstracts away. Full generality is an intersection of two PEG derivations over the same positions — a product construction, not O(|G|.n.K). |

### The tractable core: a one-character predicate belongs to the reader after it

`&C T` and `!C T`, where C and T both match a single character, are EXACTLY a
single terminal accepting `C ∩ T` (or `T \ C`) — for the pure parser as much as
for recovery, since both clauses read the same position and only T consumes it.
Fusing the pair makes the constraint part of the decision that determines the
character, which is exactly where it belongs, and it is exact rather than
approximate. The prices do not change: SUB's regret is about the character
DISCARDED (`2 * _skipRegret`), FAB's is the constant `_widestClass`, and neither
mentions the class emitted — so fusion needs only an EMPTINESS test (`can any
character satisfy both`), never width arithmetic.

That covers 7 of the 10 failures above. What it does not cover, and why, is the
honest boundary:

* **The predicate's reader is behind a rule reference** (`!'x' A`). The
  constraint must cross a rule boundary, which needs either a specialised copy of
  the rule per constraint or the constraint carried down the descent as a memo
  dimension. This is the family that contains the UNDER-REPORTS.
* **The predicate reads more than one character** (`!"*/"`, the comment idiom).
  Then it constrains a window, each character of which is decided by a different
  reader.
* **The predicate is last in its sequence** (`Kw <- "if" !Alpha`, the keyword
  idiom). The constraint escapes into the parent's continuation, which the curried
  value does not carry.

The last two are the common real-world idioms, so **single-character fusion is a
correctness fix for a real family, not a general solution to PRED**, and this
section is the place that says so rather than a row that claims a clean gate.

### Footnote: the metagrammar takes a single-quoted literal as ONE character

`A <- 'x' / 'yy';` does not parse — it fails with "17 characters of unexpected
input", pointing at the NEXT rule, which reads like a bug in the rule after the
real one. Multi-character literals need double quotes: `A <- 'x' / "yy";`.
Confirmed directly against `MetaGrammar.parseGrammar`; both `_bfpred44.dart`
grammars had to be rewritten.

## 5p. m45: a reader owns the characters it decides, and a lookahead decides none

§5o ends by naming the tractable core of PRED and leaving it unbuilt. m45 is that
build, and it is one insertion, I4, stated as a fact about ownership:

> Every character of the repaired string is decided by exactly one leaf — the
> reader that consumes it. I2 lets that leaf lie about which character it is, and
> I3 says where the input still stands unedited. **A lookahead consumes nothing,
> so it decides nothing**, and the character it asks about belongs to somebody
> else. Asking the oracle asks about `s`; the derivation is about `s'`.

That is not an approximation of the right question, it is a different question,
which is why §5o measured it failing in both directions at once. The repair is
not to answer it better but to give the constraint to its owner:

```
&C T   is the class   C & T          !C T   is the class   T \ C
```

exactly, for the pure parser as much as for recovery, whenever C looks at one
character and T consumes exactly that one. Both clauses are evaluated at the same
position and only T advances it, so the pair matches at `p` iff `s'[p]` is in the
class — there is no third behaviour to preserve.

### It is a grammar rewrite, which is why it is free

The fusion happens in `_cons`, in CLAUSE space, before any node is built: one
line at the top of the function, and a sequence with no fusable pair comes out
unchanged. It produces a real `CharSet`, not a new node kind, not a field, not a
`_compute` case. That representation is the whole trick — everything downstream
keeps working with no knowledge that a predicate was ever there:

| consumer | why it needs no change |
|---|---|
| `_collect` | still sees a Terminal leaf, so error spans and diagnostics are unchanged |
| `_terminals` / `_width` | measure the fused class correctly, because it IS a class |
| `_build` | labels the witness node with a clause that exists in the grammar |
| `_goalFromNothing` | prices it as editable at 1, like any other class |
| `_compute` | has no case for it, and needs none |

It joins the two normalisations the builder already did — a multi-character `Str`
becomes a cons chain of one-character `Str`s, a `requireOne` repetition becomes
one cons in front of a self-loop — and it is the same kind of act: **say the same
language in the vocabulary the engine is already complete for.**

### The empty class is the empty language, not a cheap edit

`&'x' 'y'` fuses to `CharSet([])`, and this is where the rewrite would have gone
wrong if the leaf rule had stayed `clause is Terminal`. A lie is about WHICH
character is present; a class with no members has nothing to be wrong about. Two
lines carry it:

* `_node` marks a leaf editable only if it accepts at least one character, so an
  empty class cannot be substituted or fabricated, and the branch is dead rather
  than cheap.
* `_goalFromNothing`'s tier 2 ("trust the predicates") now trusts the
  PREDICATES — `trustPredicates && orig is! Terminal` — so an empty class stays
  impossible in both tiers, tier 3 fires, and an empty language is answered `-1`
  from the grammar with no search at all.

The gate shows both directions of that mattering: on `S <- &'x' 'y';`, where
L(S) is empty, **m44 reports 1** — a repair, in a language with no strings —
and m45 reports `-1`.

### A name is not a language, and neither is an ordered choice

The lookahead side is measured through both, because refusing to would leave I4
pricing the spelling in exactly the forms real grammars use — including this
project's own metagrammar, which writes the body of a string literal as
`!('"' / '\\') .` where `[^"\\]` would do. An ordered choice among one-character
readers is their union (order cannot matter when every branch consumes one
character and only membership is asked); a `Ref` is resolved with a `seen` guard,
since a rule that refers to itself is not a class.

**The reader side is deliberately NOT read that generously: it must be a
Terminal.** The rewrite puts a leaf where a leaf was; fusing across `A` in
`!'x' A` would delete A's node from every witness tree, and the tree is the
deliverable. A lookahead has no node to lose — it consumes nothing and appears in
no tree — so the asymmetry is not an omission, it is the reason the rewrite is
invisible everywhere else.

### Measured against brute force: 30/45 → 42/45

`_bfpred45.dart`, nine grammars, 45 inputs, truth by BFS over single-character
SKIP/FAB/SUB with the pure parser deciding membership. **Zero regressions.**

| grammar | input | truth | m44 | m45 | |
|---|---|---|---|---|---|
| `S <- &'x' 'x' &'y' 'y';` | `zz` | 2 | **-1** | 2 | LOST → fixed |
| | `z` | 2 | **-1** | 2 | LOST → fixed |
| | `` (empty) | 2 | **-1** | 2 | LOST → fixed |
| | `xz` | 1 | **-1** | 1 | LOST → fixed |
| | `zy` | 1 | **-1** | 1 | LOST → fixed |
| `S <- !'x' 'b';` | `x` | 1 | 2 | 1 | too high → fixed |
| `S <- 'a' !'x' 'b';` | `ax` | 1 | 2 | 1 | too high → fixed |
| `S <- &'x' 'y';` (L empty) | `x` | none | **1** | -1 | UNDER-REPORT → fixed |
| | `xy` | none | **1** | -1 | UNDER-REPORT → fixed |
| `S <- (&'x' 'y') / 'a' 'a';` | `x` | 2 | **1** | 2 | UNDER-REPORT → fixed |
| `S <- &'x' &[a-y] 'x';` | `z` | 1 | **-1** | 1 | LOST → fixed |
| | `` (empty) | 1 | **-1** | 1 | LOST → fixed |
| `S <- !'x' A;  A <- 'x' / "yy";` | `q` | 2 | 1 | **1** | residual |
| | `` (empty) | 2 | 1 | **1** | residual |
| | `xy` | 1 | 2 | **2** | residual |

**All three residuals are one grammar, and it is the family §5o predicted:** the
lookahead's reader is behind a rule reference. The prediction was made before the
gate was written and the gate confirms it exactly — no other family survives.

A convention the gate needed, and it is a real distinction rather than
bookkeeping: brute force stops at 3 edits, so "no repair within reach" is agreed
with by `-1` AND by any cost above the horizon — neither contradicts it. A cost
WITHIN reach where brute force found none is an under-report, and is counted
wrong. Without that rule the gate mis-flagged four correct m45 answers.

### Spelling invariance is the tell

The same language written two ways must cost the same. Three pairs, each with a
FIXED COUNT of characters between the brackets — which is what makes the two
spellings separable at all, since where the content is a repetition a discard and
a substitution both cost 1 and the difference cancels:

| pair | input | truth | m44 class | m44 predicate | m45 both |
|---|---|---|---|---|---|
| `C <- [^)]` vs `C <- !')' .` | `()x` | 2 | 2 | **3** | 2 |
| `C <- [^)]` vs `R <- ')'; C <- !R .` | `()x` | 2 | 2 | **3** | 2 |
| `C <- [^)#]` vs `C <- !(')' / '#') .` | `(#)` | 2 | 2 | **3** | 2 |
| | `()x` | 2 | 2 | **3** | 2 |

m44 prices the SPELLING; m45 prices the language, and agrees with brute force on
every row of all three pairs. The second and third pairs are the direct gate for
looking through a name and through a choice — the two paths that exist only
because the metagrammar itself writes lookaheads that way.

### What it costs: nothing, except lines

| gate | m44 | m45 |
|---|---|---|
| battery (median of 3, one engine per process) | 291 ms | 290 ms |
| latency | 182.1 ms | 179.4 ms |
| `_steps45` `_compute` states, K=1/2/4/8 | 7802 / 27431 / 101916 / 289734 | **identical** |
| `_k45` K-sweep on JSON | 5.9 / 12.0 / 68.2 / 402.1 ms | 5.5 / 12.2 / 66.0 / 393.3 ms |
| `_smoke45` 156 mutants | costDiff 0, shapeDiff 0, spanDiff 0, coverBad 0 | |
| `_bf45` / `_peg45` / `_ceil45` | 44/44 / 2 differ from m26 / all correct | unchanged |
| `_pred45` wrong | 3/19 | **1/19** |
| every quality column of §5j | identical | identical |
| LOC | 428 | **497** |

The state counts being bit-identical is the strongest available form of "free":
JSON contains no lookahead, so the rewrite is a no-op there and the two engines
do the same work step for step. **+69 lines is the entire price**, and it is one
self-contained block: an interval complement, an interval intersection, a
one-character-class reader, and the right-to-left sweep that collapses a run of
lookaheads (`&C &D T`) one pair at a time.

### The alternatives, scored

| candidate | result | score | why |
|---|---|---|---|
| **fuse the pair into a class in the builder (I4, built)** | 42/45, +69 LOC, 0 runtime cost | **9** | Exact where it applies, invisible where it does not, no new node kind or memo dimension. Loses a point only for not reaching the Ref/multi-char/trailing families. |
| carry a pending constraint DOWN the descent as a memo dimension | not built | 5 | Would reach `!'x' A`, and it is a per-candidate EMISSION bit, not I1's value — a wider memo, so O(\|G\|·n·K) is no longer obvious. The right next experiment if the residual family ever matters. |
| static specialisation: a copy of the rule per constraint | ~85 LOC sketched, abandoned | 3 | Reaches the same family, multiplies the grammar by the number of distinct constraints, and needs a carriability walk to know where to stop. Large, and the blow-up is grammar-dependent. |
| first-character-class carried UP through the value | not built | 2 | The value stops being a small lattice; every memo cell grows a class. Blows up the domain to fix a leaf. |
| oracle-probe emptiness test (ask the parser at class endpoints) | rejected on inspection | 2 | Forces the fused node's `orig` to be a `Seq`, which loses `_collect`'s diagnostics, `_width`'s measurement, and `_node`'s leaf handling. The `CharSet` representation is precisely what makes the rewrite free. |
| CEGAR: search, check the repair, re-search on failure | not built | 2 | Unbounded iterations, and the check needs the repaired string — the thing the value abstracts away. |
| make the predicate editable (pay to satisfy it) | refuted in §5o | 1 | Double-charges the same character: 4 where the truth is 2. |
| assume every predicate passes / fails | refuted in §5o | 0 | Invents repairs that do not parse / makes half of all real grammars unrepairable. |

### The boundary, stated so it is not re-litigated

I4 stops where the window does, and the three families it does not reach all have
the same shape: **the constraint spans characters that no single reader decides.**

* **Reader behind a rule reference** (`!'x' A`) — crossing a rule boundary needs
  the constraint carried down the descent, or the rule specialised.
* **Lookahead wider than one character** (`!"*/"`, the comment idiom) — each
  character of the window is decided by a different reader.
* **Lookahead last in its sequence** (`Kw <- "if" !Alpha`, the keyword idiom) —
  the constraint escapes into the PARENT's continuation, which the curried value
  does not carry.

Fusing any of them needs a channel from a reader BACK to the leaf in front of it
— an emission bit rather than a consumption — and that is a wider value than
I1's, not a rewrite. The last two are the common real-world idioms, so **I4 is a
correctness fix for a real family and not a general solution to PRED**, and the
tag stays on the row for that reason.

## 5q. m46: the witness is a proof, so check it

Every gate in this file up to §5p compares a NUMBER to another number — the
engine's cost against brute force's, or against another engine's. That can only
be run where brute force can run, which is a handful of toy grammars at three
edits, and it says nothing at all about the tree. §5p's residual was found by a
cost oracle and was reported as three wrong costs. It is worse than that, and the
thing that says so is not a better oracle:

> **A repair is a claim with a proof attached.** The witness tree says which
> characters were kept, which were discarded, and what a lying leaf put in their
> place — so it determines a string `s'`, and the claim is exactly `s' ∈ L(G)`.
> That claim is CHECKABLE, by the thing that decides membership: the parser.

I5 is that check, and it is 42 lines: `_emit` walks the witness once and writes
`s'`; `_verify` hands `s'` to a fresh `Parser` and asks whether it parses to the
end; `recover` sets `lastVerified` before returning. One parse, `O(|G|·n)`,
against a search that is `O(|G|·n·K)` — so the proof costs asymptotically less
than the thing it proves, which is the only reason it can be always-on.

### What `lastVerified` claims, and what it does not

**It claims the answer is A repair. It does not claim the answer is THE minimum.**
The two error directions are not symmetric, and the check sees exactly one of them:

| direction | what it means | does re-parse catch it? |
|---|---|---|
| **under-report** | reported cost is below any real repair; the witness cannot be made to parse | **yes** — `s'` fails, `lastVerified` is false |
| **over-report** | a cheaper repair exists that the search missed | **no** — the expensive witness still parses |

That asymmetry is the whole design. Under-reporting is the strictly worse defect
(§5o: "the engine returns a cost for a repair that does not exist"), it is the one
a caller cannot detect for itself, and it is the one the check is total on.
Over-reporting needs a lower bound, which is a second search, not a parse.

**`forced` and `!lastVerified` are different answers and both are needed.**
`SkipResult.forced` means the engine declined — no repair exists within the
derived ceiling, so it returns the whole input as one error span for presentation.
There is no claim to check and `lastVerified` stays false. `!lastVerified` without
`forced` is the real signal: **the engine made a claim and its own proof refutes
it.** A caller that wants only sound answers reads both fields; a caller that
wants a tree regardless ignores them, exactly as before.

### Measured: two implementations of the same claim, and they never differ

`_verify46.dart` runs the check twice — once inside the engine, once from outside
with an independently written walk that deliberately picks a DIFFERENT member of a
fused character class (the first printable character, not the first code unit), so
agreement is not agreement-by-shared-code.

| gate | result |
|---|---|
| JSON battery, 519 mutants | **519/519 verified, 0 disagreements** inside vs outside |
| predicate grammars, 10 grammars / 45 inputs | **36/45 verified, 0 disagreements** |
| of the 9 unverified | 5 genuinely defective witnesses, 4 `forced` on `S <- &'x' 'y';` where `L(S)` is empty and declining is correct |
| `_bfpred46` against brute force | 42/45 — identical to m45; verification changes no answer |
| `_smoke46`, 156 mutants against m43 | costDiff 0, shapeDiff 0, spanDiff 0, coverBad 0 |

**The finding that only re-parse could produce:** all five defective witnesses are
the §5p residual grammar `S <- !'x' A; A <- 'x' / "yy";`, all five emit `"x"` —
and the cost gate flags only THREE of them.

| input | truth | m45/m46 cost | witness | cost gate | re-parse |
|---|---|---|---|---|---|
| `q` | 2 | 1 | `x` | wrong (under-report) | fails |
| `` (empty) | 2 | 1 | `x` | wrong (under-report) | fails |
| `xy` | 1 | 2 | `x` | wrong (too high) | fails |
| `x` | 2 | **2 — correct** | `x` | **passes** | **fails** |
| `y` | 1 | **1 — correct** | `x` | **passes** | **fails** |

The last two rows are the point of the whole insertion: **the cost is right and
the tree is wrong**, and no oracle that compares integers can see it. `L(S)` is
`{"yy"}` — the `'x'` branch of `A` is dead, because reaching it requires the first
character to be `x`, which `!'x'` forbids — so a witness that emits `"x"` is
never a derivation, whatever it costs. Re-parse detects a strict superset of what
brute force detects, on grammars where brute force can run at all, and it also
runs on the 519-mutant JSON battery where brute force cannot.

### The residual is not a bug in I4's implementation — it is a limit of rewriting

`_nullseq45.dart` settles this with the pure parser alone, no engine involved. The
obvious generalisation of I4 is to PUSH a lookahead's constraint down the grammar
until it reaches a terminal. Take `G0: S <- !'x' A B;  A <- 'a'?;  B <- 'b' / 'x';`
— `A` is nullable, so WHICH clause reads the constrained character is not decided
until run time. Both static placements are the wrong language, by membership:

| string | `G0` | `G1: (!'x' 'a')? B` | `G2: (!'x' 'a')? (!'x' B)` | |
|---|---|---|---|---|
| `x` | false | **true** | false | G1 ACCEPTS WHAT G0 REJECTS — under-reports |
| `ax` | **true** | true | **false** | G2 REJECTS WHAT G0 ACCEPTS — loses a repair |

Constrain only the first reader and you admit strings the grammar rejects;
constrain both and you reject strings it accepts. **No static placement is exact,
so the emission is a run-time fact**, and a correct fix needs a pending constraint
carried as a memo dimension plus one bit saying whether anything has been emitted
yet — an *emission* channel, which is wider than I1's value. m46 on G0 reports 2
for `"x"` (truth 1) and 3 for `"xx"` (truth 1): conservative, over-reporting, and
now *marked as unverified* rather than silently believed.

### What it costs

| gate | m45h | m46 |
|---|---|---|
| battery (median of 3, one engine per process) | 300 ms | 321 ms (**+7%**, ~0.04 ms per repair) |
| latency | 180.4 ms | 186.7 ms (+3.5%) |
| every quality column of §5j | identical | identical |
| LOC | 497 | **539** (+42) |

The 7% is the always-on figure, because `final_table.dart` calls `recover` once per
mutant and m46 verifies inside `recover`. It is one pure parse of a 48-character
document per repair, and it is the *entire* runtime cost: `cost == 0` returns
`lastVerified = true` without parsing anything, since the input already parsed.

### The alternatives, scored

| candidate | result | score | why |
|---|---|---|---|
| **re-parse the emitted witness inside `recover` (I5, built)** | 519/519 JSON, 36/45 predicate, 0 disagreements, +42 LOC, +7% battery | **9** | Total on the direction that matters, uses the parser that already exists, no new state anywhere, and the price is one linear parse against a `K`-round search. Loses a point for being silent on over-reporting. |
| verify only when the caller asks (`bool verify()` on demand) | not built | 8 | Same code, 0% cost on callers that do not ask — but then the default is the unchecked answer, and the whole finding above came from checking by default. A caller-facing flag is the right SHIPPING form; always-on is the right form while the engine is under development. |
| pending-constraint memo dimension + emission bit | not built | 6 | The only candidate that FIXES the residual instead of reporting it. Needs a per-candidate "has anything been emitted" bit travelling back up, which I1's value does not carry; memo widens by the set of pending constraints, so `O(\|G\|·n·K)` is no longer obvious. |
| derivative/product construction (carry each pending lookahead's Brzozowski derivative as state) | not built | 5 | Theoretically complete — `O(\|G\|)` extra states, `O(\|G\|²·n·K)` — and it roughly DOUBLES the engine. Correct, and it contradicts the "simplest, most compact" half of the objective. |
| CEGAR: search, check, re-search with the failure excluded | not built | 3 | I5 is exactly its first half, so the check is free — but the second half needs "exclude this derivation" as a search constraint, which is a new memo dimension per counterexample and has no iteration bound. |
| compare against brute force at run time | rejected | 1 | Exponential, and only defined for tiny grammars and tiny K. It is a development gate, not a mechanism. |
| trust the cost and skip the check | status quo ante | 0 | Measurably wrong: two of the five defective witnesses have CORRECT costs, so trusting the cost is trusting the wrong invariant. |

### The lesson that generalises

**Differential testing between your own variants proves agreement (§8a); an oracle
that compares one number proves that number.** The witness is a richer object than
the cost, so it admits a richer check — and the check for a claim of the form
"`x` is in the language" is always the decision procedure for that language, which
a parsing project has lying around by definition. Any search that returns a
CERTIFICATE rather than a score should verify the certificate, because the
certificate is where the errors the score cannot see are hiding.

---

## 5r. m47/m48/m49: an obligation is part of the value

§5q ends by *reporting* a flaw: `_nullseq45.dart` shows, with the pure parser and
no engine involved, that no static placement of a lookahead's constraint is the
right language, so I4's rewrite cannot be completed and I5 can only mark the
result unverified. §5q scored the fix — "pending-constraint memo dimension +
emission bit" — at **6**, with the note "the only candidate that FIXES the
residual instead of reporting it". This section is that candidate, built three
times. **The 6 was too low, and the reason it was too low is the whole content of
this section: the emission bit was imagined as a SECOND channel, and it is not a
second channel — it is the same one, read backwards.**

### I6: a lookahead is a constraint on the next character EMITTED

Everything in the engine is about `s'`, the repaired string. I2 lets a terminal
say what stands at a position; I3 says where `s'` still equals the input. A
predicate does neither — it reads a character it does not consume, so nothing in
its own derivation decides what is there, and asking the oracle answers about `s`
instead of `s'` (§5o). I4's answer was to FUSE the predicate into the reader
beside it where the builder could see who that reader was. Whom it cannot see is
a run-time fact, so the answer cannot be a better rewrite. It has to be a
**channel**: the predicate posts its class, and whatever derivation emits the
next character honours it.

That gives the memo a third dimension, `c` — the class the frame's first emitted
character must lie in — carried DOWN as an argument:

```
_ends(node, pos, budget, c)  :  end -> Delta
```

**The class is the whole of a predicate's meaning**, and one addition to the
alphabet makes the two predicates one rule:

> **⊣ IS A MEMBER OF THE ALPHABET.** `&C` says the next emitted character is in
> `C`; `!C` says it is not — *and `!C` also holds where no character follows at
> all.* `codeUnitAt` never returns −1, so −1 is free to mean "nothing follows":
> `!C` interns as `complement(C) ∪ {−1}`, `&C` as `C`. A negative lookahead then
> succeeds at the end of the string and a positive one fails there, **with no
> line anywhere saying so.**

Discharge has exactly two forms and there is no third: an **emission** (the
character emitted must lie in the class; the mover then owes nothing) or the
**end of the string** (`_permitsEnd`, asked once, at the top). A move that emits
nothing neither discharges nor enforces — it PASSES the obligation on.

### The leak: m47 guessed at the end of a chain, and under-reported

m47 discharged a pending obligation at the terminator of a cons chain. A chain
all of whose elements emit nothing then satisfied a *non-empty* constraint
**vacuously**, and the engine named repairs that do not exist — `_leak48.dart`
block A, cost **0** where brute force says **1**, on input `"x"` under both
`S <- !'x' A D; A <- 'a'? 'c'?; D <- 'd' / 'x';` and its two-rules-deep variant
`A <- B C; B <- 'b'?; C <- 'c'?`. This is the worst class of
defect in the whole project (§5o: "the engine returns a cost for a repair that
does not exist"), it is the direction I5 exists to catch, and **it is invisible
in every column of §5j** because JSON has no lookahead. m47 is registered in
`final_table.dart` with the `leak` tag and must not be used.

m48 fixed it by enforcing at the terminator instead — sound, and *blind*: a
constraint that reaches the end of a rule body has nowhere left to go, so m48
falls back on fabricating the whole continuation. On the keyword-boundary idiom
`Kw <- "if" !Alpha` with its reader at the CALL SITE — the commonest real use of
a lookahead there is — m48 reports **3** on `"ifa"` where the truth is **1**.

Both engines were guessing, at build time, about a continuation the value could
not see. **Both guesses are wrong because the question is not the builder's.**

### I7: the constraint travels back out, inside the value

The fix deletes the guess rather than improving it. A constraint enters a frame
as an argument and **leaves it inside the value**: every end a derivation reaches
is paired with the class it still OWES.

```
_ends(node, pos, budget, c)  :  (end, owed) -> Delta

_key(end, owed) = (owed + 1) * (n + 2) + end        // one int, no allocation
```

**The parser already does this, in the other direction**, which is the argument
that this is the right shape rather than a clever one:

> `MemoEntry.foundLeftRec` is **one bit from a descendant frame to an ancestor** —
> "you are a cycle, iterate" — and it is the whole of left recursion (A5, I1).
> An obligation is **one integer from a frame to its right sibling** — "the next
> character you emit is one of these" — and it is the whole of lookahead. Neither
> fact can be computed by one frame alone; both are O(1); neither needs a rule of
> its own once something carries it.
>
> **DOWN THE TREE IS THE ARGUMENT. ACROSS THE TREE IS THE VALUE. UP THE TREE IS
> THE MEMO.**

That is the generalisation the O(1)-bit idea was reaching for. It is not "a hint
for lookahead". It is: *any fact a frame cannot compute alone, but a neighbour
can, belongs in whichever of those three channels connects them* — and a parser
that memoizes already owns all three.

### What I7 deleted

Stated honestly first, because the line count does not flatter the story: **m48
656 → m49 668, so I7 is +12 code lines net.** Six mechanisms go away and the
`(end, owed)` key packing, the threading of `key` through reconstruction, and
`_permitsEnd`/`_permitsFirst` cost slightly more than all six were worth. What
I7 buys is not brevity, it is the removal of a *guess*; the deletions are worth
listing anyway, because each one was a piece of machinery for predicting at build
time what the value can now simply carry:

| deleted | what it was for |
|---|---|
| `_split`, and the two-reading union at its three call sites | `_split(c)` returned `[(c, _free), (_silent, c)]`: m47/m48 tried every cons cell BOTH ways — "the head emits the constrained character" vs "the head is silent and the tail owes it" — in `_chain`, in `_compute` and again in reconstruction, because the value could not say which had happened. The value says now, so a sequence is `head @ c`, then `tail @ owed(head)`: **`Seq.match` with an accumulator**, one call again. |
| `_silent`, the empty class as a special value | m47/m48 wrote "this derivation emits nothing" as the EMPTY CLASS and made every silent move ask permission of it. Emitting nothing is not a way of *satisfying* an obligation, it is a way of *passing it on*. The empty class stops being special: it is simply an unsatisfiable debt, which is exactly what `&'x' !'x'` ought to be. |
| `_classes[0]` seeding | index 0 had to *be* the empty class because 0 meant `_silent`. Getting that seeding wrong is a bug that reports repairs which do not exist. There is no index 0 to get wrong now. |
| `_nullable` / `_nullableRules` / `_emitsNothing` — a least fixed point over the grammar | m48's `_cons` posted a constraint only in front of a rest that HAD to read, which needs nullability. Nothing asks. |
| `_Cons.post` | the field the static gate wrote its guess into. |
| `_permitsMatch` | folded into `_permitsFirst`. |

And **a lookahead is a node again**, the plainest one in the engine: consumes
nothing, emits nothing, costs nothing, exports `meet(c, its class)`, takes no
oracle call. m48 could only post a class onto a cons cell standing in front of a
reader, so a lookahead that was a whole rule body, or the last element of one,
had nowhere to live. **Position does not enter**: what a predicate reads in `s'`
IS the next character emitted after it, wherever that is emitted from and however
far away.

### Where I3 and I7 collide, and the guard that settles it (measured both ways)

This is the subtlest line in the engine and it was got wrong twice before it was
got right. I3 (§5m) vetoes a Δ=0 alternative that ends past where the oracle
committed. The argument for it is "spends nothing over `[pos, end)`, so `s'`
EQUALS the input there" — which bounds where the candidate **looked** as well as
where it wrote. **A candidate that OWES has looked past its own end**, at the one
place `s'` is not the input. So the veto has to split on what the oracle did:

```dart
if (e.value < _costUnit &&
    _endOf(e.key) > committed &&
    (committed >= 0 || _oweOf(e.key) == _free)) continue;
```

- **Oracle MISMATCHED (`committed < 0`)** — "no alternative matches" is a fact
  about the *input*, and it says nothing about a candidate whose satisfaction
  depends on a character `s'` has not committed to yet. An owing candidate must
  be spared.
- **Oracle MATCHED** — the veto stands *whatever* is owed: the alternative the
  oracle took reads inside `[pos, committed) ⊆ [pos, end)`, where `s'` IS the
  input, so that alternative still matches `s'` and PEG still commits to it.
- **Debt-free** — unchanged in both cases, because it is the only thing standing
  between the search and a non-greedy repetition PEG would never take (§5m).

Both halves are load-bearing, and `_veto49.dart` measures it by ablating each
half of the third conjunct against brute force over 62 cases (the four `_leak49`
blocks plus three PEG-commitment grammars):

| variant | the veto condition | exact | what breaks |
|---|---|---|---|
| **m49** | `end > committed && (committed >= 0 \|\| owed == free)` | **62/62** | — |
| `va` | `end > committed` (the pre-I7 reading of I3) | 60/62 | **too high, ×2**: `S <- A 'b'; A <- 'a' &'b' / 'c';` costs **2** on `"a"` and `"ax"` where the truth is **1** — *which is m46's and m48's answer on those exact two rows*. Ablating this half of the conjunct reproduces the predecessor engines' block-D residual, so this one line is what buys it. |
| `vb` | `end > committed && owed == free` | 61/62 | **UNSOUND**: `S <- A 'b'; A <- 'a' / 'a' 'a' 'a' &'b';` on `"aaab"` reports **0** where the truth is **2**. |

`vb`'s failure is worth reading, because it is the free-riding alternative that
I3 exists to kill, wearing a debt as a disguise. PEG takes `A`'s first
alternative `'a'` at 0, so `'b'` is asked at 1, finds `a`, and the parse fails —
truth 2. The engine's second alternative `'a' 'a' 'a' &'b'` matches `[0,3)`
owing `{b}` at Δ=0; the parent's `'b'` then discharges the debt at 3, and the
whole input costs **nothing**. But PEG never reaches that alternative: the oracle
committed to `'a'` at position 1, inside the candidate's own edit-free window,
so `s'` cannot rescue it. **A debt excuses a candidate from the veto only when
the oracle had no verdict to give.**

### Measured

Every gate re-run in one session against the shipped engine, m46 and m48 beside it:

| gate | m46 | m48 | **m49** |
|---|---|---|---|
| `_leak49` block A — the leak grammars (soundness) | 18/22 | 22/22 | **22/22** |
| `_leak49` block B — reader behind a name (what I6 is for) | 10/16 | 16/16 | **16/16** |
| `_leak49` block C — no reader for the constraint (what I7 is for) | 16/19 | 16/19 | **19/19** |
| `_leak49` block D — the residual on grammars people write | 11/14 | 11/14 | **14/14** |
| **`_leak49` overall** | 55/71 | 65/71 | **71/71** |
| `_bfpred49`, the nine §5p grammars | 42/45 | 45/45 | **45/45** |
| `_bfpred49`, the nullable-sequence family | 9/14 | 14/14 | **14/14** |
| `_bfpred49`, four spelling-invariance blocks | — | — | **all agree, and agree with brute force** |
| `_bf49`, the general brute-force battery | 44/44 | — | **44/44** |
| `_verify49`, JSON 519 mutants | 519/519 | — | **519/519 verified, 0 disagreements** inside vs outside |
| `_verify49`, predicate grammars, 49 inputs | 40/49 | — | **45/49 verified, 0 disagreements**; the 4 are `<forced>` on `S <- &'x' 'y';`, an empty language where declining is correct |
| `_smoke49`, 156 JSON mutants vs m46 | — | — | costDiff 0, shapeDiff 0, spanDiff 0, coverBad 0, **stepDiff 0** |

**There are zero UNDER verdicts anywhere.** That is the column that matters: m47
had them, and the whole of m48 and m49 is the removal of them without paying
m48's price in exactness.

Two of these deserve to be read out loud. **On the identical 49 inputs, m46
verifies 40 and m49 verifies 45** (`_verify_m46.dart` is `_verify49.dart` with
one import rebound, so the input set is the same object). The five that moved are
exactly §5q's five defective witnesses — every one of them
`S <- !'x' A; A <- 'x' / "yy";` emitting `"x"`, the family where "the cost is
right and the tree is wrong" and no oracle that compares integers could see it.
They are gone because the obligation reaches `_build` too: a lying leaf is
narrowed by whatever is owed before it emits. Both engines are left with the same
4, and those 4 are `<forced>` on an empty language, where declining is the
correct answer. And
`_smoke49`'s **stepDiff = 0** is the strongest available form of "free": on a
grammar with no lookahead, `c` never leaves `_free`, so m49 does not merely
return m46's answers — it makes **bit-identical `_compute` calls** to reach them.

### I4 is now an optimization, and only that

Under m48, I4's static fusion was load-bearing: it was the only way a lookahead's
class ever reached the character it constrained. Under I7 the channel carries the
same class at run time, *and it reaches the witness too*. Measured by commenting
out the single line `parts = _fuseLookaheads(parts);` and changing nothing else
(`_m49nofuse.dart`):

| | I4 live | I4 deleted |
|---|---|---|
| `_bfpred` nine grammars / nullable family | 45/45, 14/14 | **45/45, 14/14** |
| four spelling-invariance blocks | all agree | **all agree** |
| `_leak49` overall | 71/71 | **71/71** |
| `_compute` calls, `_steps49` total | **383** | **411** (+7.3%) |
| `(!'"' .)*` on `x` / `"x` / `` (empty) | 41 / 36 / 24 | 49 / 45 / 28 |
| `[^"]*` on the same — control, already a class | 38 / 34 / 23 | 38 / 34 / 23 |
| `(&[a-z] !'q' .)*` on `q` | 16 | 23 |
| `!'x' A`, `Kw <- "if" !Alpha` — not fusable | 20/24, 39/44/44 | identical |

**No answer moves. Only work moves**, and all of it on the spellings I4 fuses.
So the rewrite survives on a different justification than the one it was built
with: it brings the predicate spelling to within 8% of the class spelling of the
same language, where deleting it costs ~30% more work to repair `!'"' .` than
`[^"]`. **Spelling invariance of the ANSWER became free, so I4 is retained for
spelling invariance of the WORK.** Nothing depends on it being correct any more —
which is the safest state a rewrite can be in.

### Where it stops, stated so it is not re-litigated

**A lookahead WIDER than one character**, for the reason it always stopped. The
derivative of `!"*/"` after one emitted character is `!"/"` — an obligation that
CHANGES as it is discharged. This channel carries a **set**, not a state machine.
Those stay on the oracle, stay approximate, and stay *reported* by I5. Making
them exact means carrying a Brzozowski derivative as the obligation, which is
§5q's row scored 5: correct, `O(|G|²·n·K)`, and roughly doubles the engine.

What pays for what was gained: the value is keyed by `(end, owed)` instead of
`end`, so a map that was `n` wide is `n × L`, where **L is the intersection
lattice of the grammar's one-character lookahead classes** — a property of the
grammar alone, not of the input, so the bound stays `O(|G|·n·K)` with `|G|`
absorbing `L`. A grammar without lookahead has `L = 1`, which is why the JSON
battery does not move by a single tree or a single `_compute` call.

The measured price is in §5j's eighth occasion: **LOC 539 → 629 → 656 → 668**,
and `RRmax` **1024 → 512**, entering at m47 and holding — the one real regression
in the line, confirmed across nine single-engine processes.

**CORRECTED, 2026-07-26.** The `RRmax` half of that is a metric artifact of the
ladder: bisected, m46 is 524 and m47 483 (−8.4%, not −50%) and m49 is 537, i.e.
*above* m46. There is no surviving I7 regression to explain. m50 then lifts the
same measure to k=2160 by scheduling, at which point the search is no longer the
binding constraint at all. See §5j's ninth occasion.

### The alternatives, scored

| candidate | measured result | score | why |
|---|---|---|---|
| **obligation in the value, keyed `(end, owed)` (I7, m49)** | 71/71 leak, 45/45 + 14/14 bfpred, 44/44 bf, 519/519 + 45/49 verify, stepDiff 0 vs m46, 62/62 veto | **10** | Exact on every family any gate can reach; deletes more machinery than it adds (`_split`, `_silent`, nullability fixed point, `_Cons.post`, the index-0 seeding); reuses the parser's own three channels; free where there is no lookahead, bit-for-bit. The `RRmax` halving is its only measured cost. |
| **constraint as a memo dimension carried DOWN (I6, m47/m48)** | m48 65/71 leak, 45/45 bfpred | **7** | Necessary and not sufficient. It is the right dimension, and *half* the channel: a constraint can reach a reader below, never a reader in the caller. On its own it forces a guess at the chain terminator, and both available guesses are wrong (m47 unsound, m48 over-reports). |
| static fusion, I4 alone (m45/m46) | 42/45 bfpred, 55/71 leak | 6 | Exact where the builder can see the reader, and free. Cannot be completed: `_nullseq45` shows no static placement is the right language. Now demoted to an optimization and *kept* on that basis. |
| **optimistic discharge at the chain terminator (m47)** | block A: 0 where truth is 1 | **0** | UNSOUND. Names repairs that do not exist — the one defect class this project treats as disqualifying. Recorded, tagged `leak`, kept only so the mistake is not made a third time. |
| strict `_eps`-only discharge (m48) | block D 11/14 | 5 | Sound, and blind. Trades m47's under-reports for over-reports wherever the reader is at the call site — i.e. on the single commonest real use of a lookahead. |
| a SECOND memo dimension for "has anything been emitted yet" (§5q's guess) | not built | 4 | This is what §5q predicted the fix would need, and it is the wrong shape: it is a fact about a derivation's PAST, so it belongs in the value, not in a second argument. Two dimensions multiply the memo where one already carries it. |
| static export sets — precompute, per node, the obligations it can leave with | not built | 4 | Sound, and it is the obligation lattice computed at build time instead of interned on demand. Buys a smaller constant; costs a whole-grammar fixed point of exactly the kind I7 just deleted. |
| a scalar "ceiling" instead of a class (widest permitted code unit) | not built | 2 | Cheaper key, wrong lattice: `!'q'` is not an interval. It would silently accept characters a negative lookahead forbids — an under-report, which is the disqualifying direction. |
| first-class-in-key: pack the class *object* rather than an interned index | rejected | 2 | Same semantics, but the memo key stops being an int and the dense `id*(n+2)+pos` addressing goes with it. Interning is what keeps the lattice finite AND the key an integer. |
| the pure one-conjunct veto, `end > committed` (`va`) | 60/62 | 3 | Safe — it can only report too high — but it gives back exactly the exactness I7 was built for, on the grammars people actually write. |
| the index-based veto, `end > committed && owed == free` (`vb`) | 61/62, one UNDER | 0 | UNSOUND, and by the exact mechanism I3 exists to prevent: a debt lets a longer alternative free-ride past a commitment the oracle already made. |

### The lesson that generalises

**A fact that one frame cannot compute alone does not need a new mechanism; it
needs the right one of the three channels a memoizing recursive descent already
has.** Down is the argument, across is the value, up is the memo. m47 and m48
each had the right dimension and the wrong channel, and both paid for it in the
only currency that counts — one by naming repairs that do not exist, the other by
refusing repairs that do.

The corollary is a rule for reading this file's own history: **when a static
analysis of a grammar is being written to predict what a derivation will do, the
prediction is in the wrong place.** `_nullable`, `_Cons.post`, `_silent`, the
`_classes[0]` seeding and the two-reading union were all machinery for GUESSING
AT BUILD TIME what the value can simply carry. Every one of them is gone, and the
engine got *more* exact for their removal.

## The nineteenth occasion: m61 — the parser is the host, and what it measured

The directive: m60 is the baseline; find a realization of its semantics (or
something more general) in dramatically less code, **with fewer memo table
additions** — and put Codex (gpt-5.6-sol, max effort) on the same question in
parallel.

**A refutation first, found on paper before any build.** The purest candidate —
compile a budget-indexed *repair grammar* (`Repair_b(C)` rules: terminal edits
as alternatives, Seq budget splits, deletion self-loops) and let the frozen
parser BE the engine by just parsing with it — fails structurally. The frozen
combinators are deterministic: one MatchResult per (rule, pos). The m-line's
cell value is a SET of (end, owed) keys, and the set is not a luxury: with
`head@i` returning its one first-successful repair, a head that commits to the
wrong span starves the tail, the rung fails although a repair at that cost
exists, and the ladder answers high — the bf gate catches it. No static
alternative ordering fixes this, because the failure is single-valuedness, not
preference. Position is the only parameter a packrat key carries, and fuel
cannot be encoded into position (contiguity). **The deterministic memo cannot
hold the union; the set-valued cell is the irreducible content of the m-line.**

**I17 — A MEMO ENTRY IS A FIXPOINT ENGINE.** What CAN be delegated is
everything around the set. `MemoEntry.match` (40 lines, frozen) is a
bottom-seeded Kleene iteration with cycle detection (`inRecPath`), a seed
(`result = mismatch`), a widening loop (grow while `len` increases), and
per-position invalidation (`memoVersion`) — m60's `_Entry` machinery, verbatim,
already in the library. m61 wraps the cell (node, obligation, budget) as a
`Clause` subclass whose `match()` computes one pass of the recurrence in
direct recursive style and returns a `Match` subclass carrying the stride-3
list, with `len` as a growth counter (strictly larger iff the set improved, so
the host's fixed-point test drives set growth; MISMATCH — the seed — reads as
the empty set). The budget becomes the KEY's third coordinate, so settling at
a budget IS the memo hit and the `settledBudget` protocol dissolves; soundness
of per-position invalidation is I8's argument (reads never move backward, so a
provisional value is only ever consumed at the position that widens); the
sticky `foundLeftRec` bit makes re-widening correct across passes. Ten `_Entry`
fields → zero recovery-side memo machinery. Bit-identical to m53 on all 252
smoke inputs ON THE FIRST RUN; bf 44/44, bfpred all blocks, leak 71/71,
score row perfect, ceiling gate 6/6.

**The price, measured (official pair):** m61 715 LOC, battms 391, latms 274.6
vs m60p 310 / 202.5 in the same process (+26% battery, +36% latency), RRmax
1024 vs >=4096; bisected nested-`E` ceilings cost k=649 / full k=590 (3/3)
vs m60's 2160/1161. Two mechanisms, both structural: (1) waits return to the
native stack — parking was I16's whole content, and the host cannot park;
(2) the host's generality is paid per read — nested map hops, a fresh list and
a growth comparison per pass — where m60 pays one flat-int lookup. Note the
steps count HALVED vs m53 (smoke ratios 0.51–0.63x: per-budget keys reuse
lower rungs across the ladder perfectly) and the wall-clock still lost: the
per-step constant of the generic path is ~2.7x. The memo's generality is rent
paid per read.

**The finding that reframes the directive: the driver was never the mass.**
m60's driver (entry + step + finish) is ~230 raw lines; hosting it saved ~65
net, because the guest apparatus (cell class, match subclass, seal/grew) costs
~150 back. What every engine since m53 carries verbatim is the OTHER ~550:
builder/normal form (~130), obligation lattice + fusion (~120), goalFromNothing
tiers (~85), witness build + emit + verify (~150), regret prefix (~50). Three
independent formulations have now measured the same bottom for the SAME
contract: m59 614 (no driver, 16x battery), m61 715 (hosted driver, +26/+36%,
stack ceiling returns), m60 780 (hand driver, fastest and deepest). The ~600
floor of the sixteenth occasion strengthens from a decomposition argument to a
three-way measurement. Dramatic shrinkage, if it exists, is not in the driver;
it is behind one of two named forks, neither takeable under the current rules:
(a) CHANGE THE OUTPUT CONTRACT — emit the repaired string + edit list and take
the AST from the I5 verify parse (already paid), deleting the input-aligned
witness builder (~150; est. ~560 LOC) at the cost of the SkipResult
input-tree shape every gate compares; (b) UNFREEZE dart/lib and share a
suspended-execution core with the parser (Codex's seventeenth-occasion
estimate: ~150–250 LOC recovery).

**Where m61 leaves the line:** m60 remains the standing engine — it dominates
m61 on battery, latency, and every stack column at +65 LOC. m61 is the
measured corner "zero recovery-side memo machinery": the proof that the
parser's own table can host the recurrence bit-identically, the cleanest
statement of the LR-trick reuse (the user's original hunch, realized
literally), and the engine whose direct-style `_eval` is the shortest faithful
transcription of the recurrence in the line. Registered m61 + m60p; harnesses
`_smoke61/_bf61/_bfpred61/_leak61/_score61/_ceil61/_batt61`, `_lat53` and
`_ceil50b` extended.

## The twentieth occasion: Codex round two, m62, and the standing engine moves

The same smaller-realization question was put to Codex (gpt-5.6-sol, max
effort, resumed thread) in parallel with the m61 build. Its reply,
claim-by-claim, with verification marks:

- **Its refutation of the naive budget-indexed repair grammar: CONFIRMED,
  independently.** Its `S <- 'a' 'b'` FAB/SUB flip is the same argument as the
  head@i starvation found here on paper before building (nineteenth occasion):
  the frozen combinators' determinism cannot hold the set-valued cell, and the
  correction is continuation-passing, whose specialization is unbounded — the
  offline shadow of the suspended tape.
- **Its proof that no static alternative order encodes additive regret:
  ACCEPTED and worth keeping.** PEG order is lexicographic by first differing
  decision; regret is a sum. Two call sites with immediate regrets a<b and
  suffix regrets swapped (M,0)/(0,M) demand opposite orders. Also the input
  dependence: SUB regret 2h(s[i]) vs FAB W, no static order. This retires the
  "encode regret by ordering" idea permanently.
- **Its lookahead analysis: CONFIRMS m61's lattice shape.** Raw-input
  predicates are disqualified (the two named underreports on `S <- !'x' A`);
  obligation specialization needs BOTH directions, incoming and outgoing —
  which the m-line has carried since I6/I7 (incoming as the cell coordinate,
  outgoing in the value key). Its warning that an ordinary MatchResult cannot
  RETURN a trailing obligation is exactly why m61's Match subclass carries the
  whole triple list.
- **What it missed: m61 itself.** Its strongest zero-field candidate (the
  max-plus fact grammar: one generated Clause per fixed target (end, cost,
  win, wout), regret encoded order-reversed in MatchResult.len so MemoEntry
  does max-plus widening unchanged) assumes the value must be a native
  length, and pays O(|G| n^2 K L^2) states / O(n^3)-class work for it. A
  Match SUBCLASS carrying the stride-3 list with len as a growth counter
  keeps the m60 state count and was already built and measured (m61,
  715 LOC, +26%/+36%, ceilings 649/590) before its reply landed. Its own
  forecast for a corrected grammar construction ("several times m60, worse at
  large K, m49-like stack") brackets m61 correctly from the pessimistic side.
- **Its trilemma: RECORDED as the floor's second leg.** The set-valued cell's
  information must live in a richer memo value (m60/m61/m62), duplicated rule
  identities (fact grammar), or suspended continuation state (the tape).
  "Under the freeze, no credible 150-350-line implementation satisfying all
  gates and the performance target." This matches the three-way measured
  floor of the nineteenth occasion from an information argument.

**m62 — its ranked-first practical candidate, built here and measured: THE
ENTRY IS A FACT; THE PASS IS A FRAME (I18).** Of m60's ten entry fields, six
describe the pass in flight (budget, pc, headEntry, foundCycle, improved,
parent). m62 moves them onto one explicit DFS stack of pooled frames: stack
adjacency is the parent pointer, `running` derives from membership
(activeDepth >= 0), and a descendant reaching an active entry sets the
ancestral FRAME's foundCycle bit by index — the same O(1)
descendant-to-ancestor message. The durable memo shrinks to
value/settledBudget/version (+activeDepth); the recurrence, ladder, walk,
veto, ceiling and witness are m60 verbatim. Bit-identical smoke on the first
run; every gate perfect; bisected ceilings 2160/1161 = m60's exactly.

**Measured (medians of three pair processes):** m62 787 LOC, battms 343,
latms 199.2 vs m60q 329 / 215.2 — the latency beat held in all three runs
(198.2/222.7/199.2 vs 213.4/229.6/215.2), battery a ~3% deficit inside the
pair scatter, RRmax/LRmax >=4096 both. Smaller entries appear to pay for
themselves in cache behavior: the first engine of the line to beat m60's
latency without giving up any column.

**The standing engine of the line is now m62.** m60 remains I16's statement —
the discovery that the continuation can live with the memo — and m62 is its
completion: the transient half of the coroutine belongs to the pass, not the
table. m49's latency crown (~190 same-session context) is now within ~5% at
full stack safety, 4 durable fields, and zero parameters. The occasion's
directive — "fewer memo table additions" — is answered with six fewer.

Harnesses: `_smoke62/_bf62/_bfpred62/_leak62/_score62/_ceil62`, `_lat53` and
`_ceil50b` extended; registered `m62` + `m60q` (medians noted inline in 5j).

## The twenty-first occasion: the axiomatization, run twice — my pass vs Codex round three

The user's directive raised the bar: not a smaller transcription but a
fundamental breakthrough, obtained by axiomatizing what recovery IS and
rebuilding from purer abstractions — run by me AND by Codex (gpt-5.6-sol,
max effort) independently, then compared. My answers were written to a file
BEFORE reading Codex's reply (clean-room; scratchpad `my_axioms_round3.md`);
Codex ran no experiments (its own disclosure); I ran two.

**The axiomatization (convergent, both passes):** repair = weighted
recognition of s under the product G (x) E (E the edit transducer), over the
tropical-lexicographic semiring on (cost, regret) — Aho–Peterson 1972's
covering grammar is this product compiled, Lyon 1974 its online form, and
Considine 2025 (arXiv 2507.11873, "Syntax Repair as Language Intersection",
found in my arXiv sweep, missed by Codex) its modern CFG statement. The
m-line dictionary: obligations = E-states (one-symbol output constraints);
the ladder = iterative deepening of the tropical fixpoint; the budget-0 walk
= the product's Boolean slice; I3 = the PEG-commitment correction; gfn = the
termination certificate d(empty -> L); regret = MAP decoding under a
two-level noise model. What is OURS against that literature: the PEG
envelope + NP boundary, obligations-as-E-states, the verified witness, and
(unclaimed anywhere in the sweep) exact-minimal INCREMENTAL repair.

**Task 1, the main event — Codex corrected my theorem, my experiments ground
its.** I proposed: any exact repairer restricted to Boolean oracle queries
plus o(frontier) state per cell must fail. FALSE AS STATED — Codex's
counterexample is the exponential enumerator: enumerate edit scripts by
(cost, regret, canonical tie), re-parse each candidate with the frozen
parser; first accept is exact, EVEN UNDER TRUE PEG SEMANTICS, with O(1)
recovery state — it violates only time. (It also needs an upper bound to
terminate on unrepairable inputs.) So the trilemma is a QUADRILEMMA —
materialize the frontier / specialize by context (fact grammar) / suspend
the continuation (tape, coroutine) / RECOMPUTE — and the true theorem is a
time-space statement: **any evaluator that summarizes a clause before seeing
its continuation, and must answer every continuation query without
re-entering or re-reading it, carries Omega(frontier) bits** — a one-way
communication / INDEX bound. Codex's adversary: branches Pp <- x^(2p-1) a
[/ b] encode a subset S; continuation Kt <- x^(2m-2t) !. reads bit t
(distance <= 1 iff t in S); Boolean transcripts on the original input are
S-independent; 2^m summaries forced; scope honestly limited to
opaque/compositional summaries (a whole-program algorithm may re-read the
grammar or input — that is the recompute corner again). My independent
construction, MEASURED on m62 (`_fool62.dart`): tails 'y'^j read off head
frontier entries exactly (7/7 agreement between full-input costs and
head-prefix frontier values), and 16 adversary corruption patterns yield 12
distinct frontier vectors — the fooling set realized on the real engine.
Frontier sizes (`_frontier62.dart`): battery max 39, mean 1.65 per cell
(why the line is fast — real inputs barely pay for the generality);
adversarial many-ends grammar max 21/42/62 at n=22/42/62 — Theta(n) at one
cell. VERDICT: the floor is now a THEOREM for every compositional engine —
the only "dramatically smaller" implementations are exponentially slow
(the enumerator corner, ~150-300 LOC, true-PEG, useful as a gate oracle,
never a production engine). Belongs in the paper beside NP-hardness:
hardness bounds time in the lookahead dimension; this bounds state in the
frontier dimension.

**Task 2 (axiom audit) — convergent table, three Codex additions, one of
mine survives its critique.** Codex grounded (b) with m48 as the measured
conservative point (656 LOC, 63/69 pred) and priced (a) at 45-70 LOC /
(e) at 40-85. On (f) incrementality it found the real obstacles my sketch
missed: RETRACTION (m62's values only improve; an edit can delete the best
derivation, so fine-grained reuse needs support counts / provenance), the
frozen parser cannot be an incremental oracle (each Parser owns a private
memo over a final input — parser.dart:12), and a worst-case Omega(n) output
example (a^n x -> a^n y flips a depth-n tree), so the honest bound is
O(affected * log), never O(edit * log). My conservative variant survives:
invalidate damaged cells WHOLE and recompute (no retraction machinery),
suffix addressing (key cells by distance-from-END: cells right of an edit
keep their keys — checked arithmetic), and the Lipschitz lemma
|d(s,L) - d(s',L)| <= d(s,s') seeds the ladder at k-1. Honest per-keystroke
cost: O(fresh pure parse + damaged-region relaxation).

**Task 3 (literature) — union stronger than either.** Codex added two
constructions: (i) REGULAR-DERIVATIVE OBLIGATIONS — replace the one-char
class omega by interned Brzozowski residuals of regular lookaheads;
emission differentiates, conjunction intersects, nullability discharges —
extends I6/I7 exactness from single-character to all REGULAR lookaheads
(finite residuals for a fixed automaton), parameter-free, leaving only
recursive predicates approximated; (ii) GLR* as deletion-only
frontier-in-the-GSS. I added: Considine 2025 (above), Dubroy-Warth 2017
incremental packrat (the invalidation mechanism), tree-sitter as the
system-level neighbor (incremental + error-tolerant, cost-tuned, NOT
exact-minimal — the m63 slot is open). Both: Valiant-tropical no real win
(frontier = matrix row; APSP-hard), semiring/ADP relocate the interpreter
rather than delete it, Knuth = m57 already measured, provenance semirings =
the incremental foundation.

**Task 4 (tape) — both say BUILD; Codex re-scoped it honestly.** LOC revised
UP: 495-715 full contract (380-470 for a prototype without exact tertiary
ties), battery prediction 1.5-3.5x m62, latency 300-750ms, search ceiling
>=4096 if the VM descent is explicit, full ~1800-2200 (verification-bound).
Its VM spec is buildable: compile the Clause DAG to a suspended VM
(TERM/CALL/RETURN/FIRST/STAR/AND/NOT/END); immutable hash-consed residuals;
atoms(q) = character classes inducing the same next residual; Dijkstra over
(cursor, residual) with MATCH/SUB/FAB/SKIP; Clean(i,q) macro replaces the
walk and MUST use the suspended VM, not the raw parser. Traps beyond my
three: persistent-state isolation (COW residuals; structural equality after
hash), Need-vs-failure under decisions and LR (suspension is not mismatch),
and — its best catch — the PRODUCTIVITY CERTIFICATE: goalFromNothing is
CFG-shaped and cannot be assumed exact for true-PEG termination.
DISAGREEMENT ON ORDER, surfaced rather than smoothed: Codex builds the tape
next and demotes incrementality to a separate provenance project; I ranked
incremental first for IDE utility. Post-comparison position: the tape is
now the better-specified and more de-risked build, and it is the only
EXACTNESS-CLASS upgrade (kills the PEG tag's 4/5); incremental-conservative
is the utility play. The user picks; the tape is the recommendation if the
criterion is "fundamental breakthrough".

**Task 5 — Codex's genuinely new object: the weighted continuation
quotient.** A grammar-relative Myhill-Nerode: states (cursor, obligation)
equivalent iff every reachable defunctionalized continuation assigns them
the same (cost, regret, canonical-witness) signature; memoize over quotient
IDs. The mathematically minimal state an exact engine could retain.
Its own adversarial assessment is honest: the task-1 adversary keeps all m
classes, input-dependent regret usually separates states, and naive
signature computation costs more than the frontier — so: try structural
hash-consing in the tape first, treat the semantic quotient as an
empirical question. CLOSURE (two-model consensus): under the unchanged
axioms the answer space is complete — materialize / specialize / suspend /
recompute / quotient-compress; m59/m61/m62 measure the efficient corner,
the enumerator is the tiny-but-exponential corner, the tape is the
semantic upgrade, provenance/DDG the incremental corner. No credible
150-350 LOC batch engine at m62 performance under the freeze. The
remaining breakthrough is the tape's change of semantic object: from
frontiers of successful subparses to shortest paths through residual PEG
decisions.

Artifacts: `_frontier62.dart`, `_fool62.dart`, `_m62p.dart` (scratch,
untracked); scratchpad `my_axioms_round3.md` (clean-room answers),
`codex_result3.txt` (verbatim reply); arXiv sweep s_eb86c9cf.

## The twenty-second occasion: both breakthrough candidates built — one lands, one measures honest zero

The directive: build the tape AND the incremental engine, and update the paper.

**m64 (I19: THE SUFFIX IS THE INVARIANT; THE EDIT ONLY MOVES THE ORIGIN) —
exact, and economically empty.** m62 plus an incremental entry point: a
cell's value is a pure function of (node, obligation, budget, input[pos..]),
so a single edit keeps every cell to its right verbatim at a shifted address
(values re-packed, ends moved); d(s,L) is 1-Lipschitz under single edits, so
the ladder restarts at prev-1 — never more than three rungs, VERIFIED (max 3
over 300 steps). Correctness: a 300-step random single-edit walk plus 100
break/fix cycles against fresh m62 batch runs — ZERO cost differences, ZERO
witness-shape differences (30 checked). Economics, measured three ways:
1.11x (random walk, fair shared reference), 0.96x (IDE break/fix cycle),
0.98x (same cycle at n=4071). THE MECHANISM: the budget-zero oracle walk
already collapses clean regions to memo hits, so batch m62 was secretly
incremental in the only dimension that pays; suffix keying preserves the
CHEAP cells (clean right suffix) and drops the EXPENSIVE ones (the cells at
the edit, where the error is); an append — the common typing action — keeps
nothing at all. Codex's round-three prediction ("adds machinery, not a
reduction; O(affected) at best") is CONFIRMED by measurement; my Lipschitz
window and cell-carry mechanics are confirmed exact. The real incremental
frontier is bidirectional/balanced decomposition (meet-in-the-middle or
Rytter-style balanced product trees) — recorded as future work, not built.

**m63 (I20: MEMBERSHIP, DEADNESS, AND THE USEFUL ALPHABET ARE ONE PROBED
PARSE) — the tape, landed, at 344 LOC.** The suspended-residual VM of the
Codex spec turned out to be unnecessary: the emitted text y IS the state,
and the frozen parser re-derives everything about it on demand, memoized by
y. Wrap every terminal in a probe recording when it consults the open end of
y (pos + need > |y|); one probed parse of y then yields: MEMBERSHIP (a clean
full parse of exactly y is authoritative), DEADNESS (a parse that failed
without touching the frontier consulted only bound positions, hence fails
identically on every extension — append-only extension is what makes the
lemma sound), and the ATOMS (the touching terminals' next-needed characters,
canonical lowest representative; SUB with a class containing s[i] is
dominated by MATCH and skipped). Dijkstra over (input cursor i, y) with
MATCH(0)/SUB(1)/FAB(1)/SKIP(1) edges and (cost, regret) priorities is then
exact under TRUE PEG semantics — ordered choice, possessive repetition, and
lookahead all decided by the frozen parser on the actual repaired text.
Derived bounds from the m62 relaxation: its -1 is exact (CFG-empty implies
PEG-empty); its empty-input answer is the CFG fabrication floor, giving the
termination cap n + fab; and — A TRAP THE CONFORMANCE GATE CAUGHT — its 0 is
NOT a membership certificate (a rung-0 CFG-union parse also returns 0, which
is precisely the possessive-star failure mode); membership must be checked
by a direct pure parse. -1 from m63 means "no repair within the cap": for
PEG-empty-but-CFG-nonempty grammars (the possessive-star cases) that is the
honest terminating answer; a true repair dearer than the cap is the one
documented approximation at the -1 boundary.

**m63's record:** bf 44/44 (true-PEG truth), bfpred 71/71 overall, leak
71/71, valid 7/7, cover 519/519, cost-exact hist {1:503, 2:16}, unsnd 0,
**conformance 5/5 — the first engine in the line, back to `dot`**: the
possessive-star cases answer "none" while every other engine reports the
CFG's 0. Shape 467/519 (52 misses: the witness is the repaired-string parse
projected through the edit alignment, boundary-attributed to the preceding
span — different tie conventions than the m-line's shortest-head order).
Battery 27447 ms vs m62's 316 in the same process: 87x, the price of
candidate-space search, squarely the "research engine" Codex forecast
(its central battery prediction 1.5-3.5x was optimistic; the state space
pays for having no residual quotient — structurally equal y's from
different edit paths merge, semantically equal ones do not). 344 LOC —
under HALF of m62 — because three of the four heavy sections dissolved:
no builder/normal form (the probe transform is 15 lines), no obligation
lattice (lookaheads are decided by the parser on the tape — I6/I7's whole
apparatus is subsumed), no goalFromNothing (the cap is one m62 call on the
empty string). What remains: probe + classify (90), Dijkstra (110), regret
analogue (25), witness projection (80), bounds/api (40).

**The quadrilemma's corners are now all measured** (twenty-first occasion's
closure, completed): materialize = m62 (787 LOC, 316-361 battms),
specialize = the fact grammar (priced, unbuilt), suspend/recompute = m63
(344 LOC, 87x, exactness-class upgrade), incremental-provenance = m64
(economically empty at gate scales). The line's standing engines: m62 for
production batch, m63 for true-PEG semantics and as the reference oracle
the gates never had.

Artifacts: `m63.dart`, `m64.dart` (registered, with `_bf63/_bfpred63/
_leak63/_score63/_conf63/_batt63/_inc64` and `_ceil50b` extended);
final_table rows m63/m64/m62r appended per the maintenance rule.

## The twenty-third occasion: the tape, paced — 87x to 21x, shape 467 to 514

The user's challenge, on target twice: 87x battery is terrible (does A* help?),
and shape 467/519 is a robustness regression the previous report undersold.
Conceded on both; m65 answers both without touching exactness.

**Why A* itself does not apply.** An admissible heuristic must lower-bound
the TRUE-PEG remaining cost from a tape state (i, y). The available floors
are CFG-side and cannot be evaluated per-state without mapping y back into
grammar coordinates — the very representation the tape exists to avoid — so
h degenerates to 0 and A* collapses to Dijkstra. The workable levers are
Dijkstra-compatible pacing rules, each answer-neutral (I21: THE LAYER IS THE
ANSWER; THE TIE IS A RANKING, NOT A SCHEDULE — with MATCH free and edits
unit-cost the search is 0/1 Dijkstra, settling in strict cost layers
whatever the tie order):

1. Classify on POP, not push: the stranded frontier (the entire next layer
   when the answer lands) is never parsed at all. 27447 -> ~13s.
2. The clean-tail shortcut: after every edit, ONE probed parse tests the
   whole remaining input as a free completion — the budget-zero walk
   transplanted to the tape. Kills the quadratic post-edit match chains.
3. Within-layer order by closeness-to-done (n - i): shortcut candidates pop
   at the HEAD of their layer, so the accept is detected before the layer
   expands, and the drain then suppresses stepwise expansion entirely
   (within a layer, stepwise MATCH edges can only re-derive clean-tail
   accepts the shortcuts already pushed; edit children belong to layers
   that will never pop). ~13s -> 7.2s.
4. Path-independent exact ties: the whole minimal layer is drained, every
   accept collected, and candidates are ranked AFTER the search by the
   m-line's real prices — cleanRegret from the candidate's own parse
   (actual consuming terminals, not a per-char floor) plus a lexicographic
   (edits, regret) alignment DP at m-line edit rates. The DP traceback is
   also the witness script, removing search-path artifacts from the tree.
   Shape 467 -> 499 (in-search h-regret) -> 514 with the DP (m62 sits at
   517, two of which are the d13-inherent pair). The residual 3 are tie
   residue between equal-(cost, regret-model) candidates.

**Measured (same-process pair beside m62):** battery 7194 vs 337 — 21x,
from m63's 87x; every exactness gate unchanged and perfect (bf 44/44,
bfpred 71/71, leak 71/71, conformance 5/5, hist {1:503, 2:16}, cover
519/519, valid 7/7, unsnd 0); 425 LOC. Latency case 8 (cost 10) remains
protocol-infeasible: the suppression helps only the final layer; layers
1..9 still expand. The remaining structural lever for the tape's speed is
the residual QUOTIENT — merging textually distinct but semantically equal
emitted prefixes — which is exactly Codex's continuation-quotient object;
hash-consing of touched-state fingerprints is the cheap first probe.

The line now reads: m62 the production batch engine; m65 the true-PEG
reference engine (m63 its unpaced baseline, kept for the record); m64 the
measured null of suffix-carry incrementality.

## The twenty-fourth occasion: the router — true-PEG exactness at relaxed speed

The user's verdict on m65: still not a good tradeoff — review every
available improvement again (Codex running the same review in parallel).
The review found that the tradeoff dissolves entirely, and the instrument
was in hand the whole time.

**I22: A VERIFIED WITNESS IS A CERTIFICATE OF EQUALITY.** The CFG-union
reading accepts a superset of the true PEG language, so the relaxed cost
c62 is a floor on the true cost for EVERY input. When the relaxed witness
string survives I5 verification — the clean pure parse of the repaired
text that m62 already performs — the squeeze closes: trueCost <=
d(s, witness) = c62 <= trueCost. Equality, and the witness in hand is a
legitimate minimum-cost true repair. The relaxation's one failure mode
(repairing toward a parse the committed grammar would never take) is
precisely the case its own verification detects. So the router is total:
m62's result VERBATIM when verified; the tape (m65) exactly where the
relaxation lied. 53 LOC over the two imports.

**Measured, full official protocol (the first tape-family engine that can
run it), same-process pair:** m66 367 battms / 223.8 latms vs m62s
325 / 207.9 — within 13%/8% of the standing engine — with shape 517/519
(the line's best; the two misses are the d13-inherent pair), cover
519/519, hist exact, bf 44/44, bfpred 71/71, leak 71/71, unsnd 0,
**conformance 5/5**, and BIT-IDENTICAL smoke against m53/m62 on all 252
inputs. LRmax/RRmax 1024/2048: the cost query must build and verify the
witness (that IS the certificate), so m66 carries m62's full-pipeline
stack ceiling, not its search-only one.

**A pre-existing flaw fixed on the way:** m62.recover() had a latent
null-dereference on relaxed-0 inputs whose pure parse fails (exactly the
possessive-star conformance shape) — a path no gate had ever exercised.
Guarded to return an unverified whole-span result; m62's smoke re-run
bit-identical (14/14 blocks), rows unaffected.

**Where this leaves the tradeoff:** m62 remains the fastest relaxed
engine; m65 remains the self-contained true-PEG reference (425 LOC, 21x,
no dependence on the relaxation); m66 is the engine to USE — true-PEG
exactness, relaxed speed and shape, and the fallback price is paid only
on inputs where the relaxation actually lies, which the certificate
detects at zero marginal cost. The PEG tag is retired at production
speed. What the router does NOT fix: the residual tie discrepancy class
(m62's relaxed-regret choice among equal-cost verified candidates vs a
hypothetical true-regret order — bounded by the same 3-case residue m65
measured) and m65's own 21x, whose next lever remains the residual
quotient.

## The twenty-fifth occasion: my own sweep broke my own router, and the fixes are structural

Continuing the round-four review (Codex running the same in parallel), a
2261-case adversarial sweep was built before trusting the router: twelve
lookahead- and commitment-heavy grammars, all strings to length 5,
brute-force true-PEG truth (horizon 3) against c62, m65, and m66
(`_floor66.dart`). It found two real holes — both mine, both now fixed and
re-verified.

**Hole 1: the floor claim fails outside the envelope.** All 41 floor
violations concentrate in the one wide-lookahead grammar
(`S <- &(A 'b') A 'b' 'x'`): m62 evaluates wide predicates against the
ORIGINAL text (the PRED tag's known content), so it can LOSE repairs —
c62=5 with a verifying witness while a true cost-3 repair exists. The
squeeze's certificate direction survives (verified => upper bound); the
floor direction does not, so "verified => equality" is only sound inside
the single-character envelope. Worse, m62's -1 is no emptiness proof
there either, and m65's own -1 shortcut inherited the lie (both engines
returned -1 on five inputs with true cost <= 3). FIX: the envelope is
STATICALLY detectable (any lookahead whose subclause lacks a
single-character class — the same test I4's fusion uses). m65 exposes
`wide`; the router trusts the relaxation only when !wide, and routes
everything to the tape otherwise; the tape's own answers on the wide
grammar were verified exact (c65=3 where c66 said 5).

**Hole 2: the termination cap was computed from the wrong side.** cap =
n + relaxed-fabrication-floor, but the relaxed floor LOWER-bounds the true
one (superset language => shorter members), so the cap can sit below
n + fabTrue — `S <- 'a'? "ab"` on "" has relaxed floor 2 ("ab" is a
relaxed member) but true floor 3 ("aab": the optional steals the
literal's first character), and the search gave up one rung short:
a false -1 that had been latent in m63/m65 since birth, never triggered
by any gate. FIX: the horizon gains the grammar's fabrication mass
(the summed emission size of its terminal occurrences, a derived
constant): horizon = n + (envelope ? relaxed floor : 0) + massG, exposed
as `lastHorizon`; -1 means "no repair within lastHorizon". The mass term
covers forced-duplication gaps; the undecidability of full-PEG emptiness
(twenty-first occasion) forbids an unconditional horizon, so SOME derived
horizon is forced — this one never binds on any gate, keeps every
empty-language case terminating, and closes the sweep.

**After both fixes, re-verified end to end:** the sweep is CLEAN
(routerWrong 0/2261; the 41 floor violations remain as documentation of
what is no longer trusted); m65: bf 44/44, conf 5/5, bfpred 71/71, leak
71/71, shape 514, battery 7151 vs 308 (pair scatter of the same ~21-23x);
m66: bf 44/44, conf 5/5, bfpred 71/71, leak 71/71, shape 517/519, smoke
bit-identical 14/14, and the official pair re-confirmed at 343/218.4 vs
m62s 288/220.6 — LATENCY NOW TIED with the standing engine. LOC after
fixes: m66 61, m65 477.

The lesson for the record: the router's soundness is not one theorem but
three, with three different scopes — the certificate (verified witness =>
upper bound: unconditional), the floor (relaxed cost <= true cost:
single-character envelope only), and the horizon (-1 within
n + floor + massG: forced by undecidability). An engine that conflates
their scopes is wrong precisely where the PRED tag always said the
relaxation lies.

## The twenty-sixth occasion: the seams removed — one engine (m67)

The user's directive: routing between two black boxes is not an algorithm;
hoist both into one and simplify algebraically. m67 (I23: THE ROUTER WAS A
SEAM, NOT A DESIGN) is the m62 core and the m65 tape in ONE class over ONE
substrate, with the duplicates dissolved rather than delegated:

- ONE relaxed core serves the fast path, the envelope floor, and the
  fabrication floor (m66's system carried TWO m62 instances — its own and
  the tape's — plus three pure parses of the same input; m67 has one of
  each).
- ONE `_oneCharClass`/`_looks` analysis is simultaneously I4's fusion test
  and the envelope boundary: a wide lookahead IS, definitionally, a clause
  `_looks` cannot read. The 40-line duplicate detector is deleted; the
  boundary and the optimization are the same object.
- ONE width/regret table (`_h` extracted from the regret-prefix builder)
  prices the relaxed lattice, the tape's edit weights, the alignment DP,
  and the post-search ranking. The fabrication mass reads the builder's
  own lowered terminal list.
- ONE set of result fields (lastCost/lastVerified/lastSteps) written
  directly by whichever search answers; the driver is eleven lines.

Measured, full official protocol, same-process pair: m67 1208 LOC,
**338 battms / 222.8 latms vs m62t 365 / 220.4** — battery FASTER than the
standing engine in this pairing, latency tied — shape 517/519, conformance
5/5, bf 44/44, bfpred 71/71, leak 71/71, unsnd 0, smoke bit-identical
14/14 blocks, sweep 0/2261, LR/RRmax 1024/2048 (verification mandatory:
the certificate requires the witness). 1208 LOC standalone replaces the
1325-LOC three-file composition; m62 remains inside it verbatim as the
relaxed half, m65 remains registered as the self-contained tape reference.

**m67 is the standing engine**: the first single-file engine in the line
that is true-PEG exact (conformance 5/5, sweep-clean) at the relaxed
line's speed.

## The twenty-seventh occasion: the certificate retires the lattice (m68)

The directive: every 517/519 engine on one board, every tradeoff priced,
state of the art extracted. The board (same-process eras): m42 381 LOC /
174.5 latms (relaxed, pred-inexact, maxCost knob, RR 1024); m44 428
(+47: parameter-freedom); m49 668 (+240: the obligation lattice = predicate
exactness); m53 751 (+83: stack, costing latency until m62 recovered it at
787/199.2); m67 1208 (+421: true PEG). The analysis found that one of those
purchases is obsolete under the certificate architecture:

**I24: UNDER A CERTIFICATE, THE FAST ENGINE ONLY NEEDS TO BE A FLOOR.**
The I6/I7 lattice made the RELAXED engine predicate-exact, back when it was
the final authority. It is not the final authority anymore: an
under-report can never verify (its witness would realize a cost below its
own claim), so every predicate mistake fails verification and routes to
the tape, which is exact. On lookahead-free grammars the union relaxation
is trivially a floor — and the entire performance corpus (JSON) is
lookahead-free, so the lattice was inert on every measured input. m68
deletes the lattice, the fusion pass, and the demands machinery from the
core; the router condition blunts to "any lookahead routes to the tape."

**Measured, full official protocol:** m68 1117 LOC, 344 battms /
214.6 latms vs m62u 340 / 222.5 — battery tied with the bare relaxed
engine, LATENCY FASTER THAN IT — shape 517/519, conformance 5/5, bf
44/44, bfpred 71/71 (via tape), leak 71/71 (via tape), unsnd 0, sweep
0/2261, and smoke FULLY bit-identical on all 14 blocks including the
tape-routed predicate blocks (the DP ranking prices ties at m-line
rates, so the tape picks the same witnesses). Ceilings 1024/2048
(verification mandatory, unchanged).

**The remaining priced trades, none taken:** unifying the two witness
machineries (-150 LOC, costs 3 shape points and smoke identity);
swapping the frame driver for m49's recursive one (-60 LOC, RRmax
2048 -> 512); flattening the now-inert obligation threading out of keys
and signatures (-40 LOC, pure mechanics, no behavior change — the one
worth doing on a quiet day); the ~200-LOC shared-core dream (needs the
lib unfreeze). **m68 is the standing engine**: the smallest and fastest
fully-exact true-PEG configuration the line has produced.
