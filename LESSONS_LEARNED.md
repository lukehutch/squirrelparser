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

### Bugs shared by EVERY row, so not repeated per engine (K40 excepts m44, m45)

| tag | defect |
|---|---|
| **PEG** | Repairs toward the **CFG** reading of the grammar, not the PEG one: a possessive `*` and a committed `/` are treated as if any stop or alternative were available. 4 of 5 conformance cases wrong, identically, in every engine back to `dot` (§5b). The `cost` column cannot see it — its grammars are prefix-disjoint, so the two readings coincide there. |
| **RR** | Right-recursive grammars overflow the native stack (the `RRmax` column). Inherited from the pure parser, which shows the same asymmetry; recovery worsens the threshold ~4x because its descent adds frames per position (§8a). Fix is an explicit worklist; not built. |
| **d13** | `del@13` and `swap@13` are never recovered to the original shape. That is exactly the 517/519 ceiling. |
| **K40** | `maxCost` is a hard search ceiling (default 40): a costlier repair is not found at all (cost -1, whole input as one error span). It was the last tuning parameter in the m-line, and **m44 and m45 are the only rows without it** — there the ceiling is DERIVED as `n + fabricate(goal)`, a repair that always exists, so the search cannot stop short of a real minimum (§5n). Every other row still has the knob and still gives up above 40. |

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
| **LOC** | Not a defect — a line-count regression against m26's 382. |
| **dup** | Not an engine: m26 registered a second time, last, to measure the warming-heap bias. |

**Unproven, and not in the table because it is not a measured bug:** the
left-recursion fixed point in every A5 engine (m23 onward) re-runs until no Delta
improves, and that iteration count has no tight polynomial bound in this
derivation — only the measurement that it behaves like a small constant (§5a).

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
