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
| m39 | 396 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | — | 283 | 255.5 | 0.54x | >=4096 | 512 |
| **m40** | 429 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | LOC | 309 | 259.6 | 0.55x | >=4096 | 512 |
| m26b | 382 | 517/519 | 519/519 | 0 | {1:503, 2:16} | 7/7 | 44/44 | 44/44 | dup | 360 | 267.1 | 0.56x | >=4096 | 1024 |

### Bugs shared by EVERY row, so not repeated per engine

| tag | defect |
|---|---|
| **PEG** | Repairs toward the **CFG** reading of the grammar, not the PEG one: a possessive `*` and a committed `/` are treated as if any stop or alternative were available. 4 of 5 conformance cases wrong, identically, in every engine back to `dot` (§5b). The `cost` column cannot see it — its grammars are prefix-disjoint, so the two readings coincide there. |
| **RR** | Right-recursive grammars overflow the native stack (the `RRmax` column). Inherited from the pure parser, which shows the same asymmetry; recovery worsens the threshold ~4x because its descent adds frames per position (§8a). Fix is an explicit worklist; not built. |
| **d13** | `del@13` and `swap@13` are never recovered to the original shape. That is exactly the 517/519 ceiling. |
| **K40** | `maxCost` is a hard search ceiling (default 40): a costlier repair is not found at all (cost -1, whole input as one error span). The only tuning parameter left in the m-line. |

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
