<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.25 Round 78: a cost prune, a bounded local stage, and a doubted answer goes to local mode (z23)

**What was slow.** Rung tracers (copies of the engine that print each rung's work) split z22's
time. Cost-mode rungs up to `_cap` are quadratic on dense errors, because repetitions build ways
whose cost is already over the rung. Local mode with budget b costs about n b^2 on `(1+`: `T`
can insert `(` and wrap any span. On LR `(1+` the cost rungs are linear (work 3,096 / 6,168 at
k = 128 / 256 for rung 1) and all the extra work is the local rungs.

**z23 = z22 + four changes.** Repo `dart/experiments/recovery/_z23.dart`.
- Cost prune: in cost mode `_repeat` and `_seq` drop a way whose cost is over the rung as soon
  as it is built.
- Local mode runs in two stages. Stage `_rung == 0` is z22's local mode, stopped after
  `_exactPer` (16) times the work limit. Stage `_rung == -1` is unbounded and settles a repair
  once one character follows its last edit (`r.end > r.last` instead of `r.last + 1`).
- A doubted answer from cost mode (an unchecked way cheaper than the checked one) is treated
  like a work stop: the search goes on in local mode, keeps the better checked repair of the
  two, and the exact search then runs under that price.
605 -> 606 LOC (+1, +0.2%). No fields added or removed.

**The doubted-answer flaw was already in z22.** The fuzzer case
`S <- R0; R0 <- (R2 ('b'? / 'b'+) (('c' / 'b') R0? ("bab" 'c'))); R1 <- (('a' / R0)+ / 'b'+);
R2 <- ('a'* "bb"*+ 'b'*)` on `aacbbbbcbbabca`: an exact cost-mode rung 4 (with or without the
prune, measured with the work limit raised 1000x) returns a way of cost 4 and price 9 and marks
it doubted. The exact search needs more than its limit to find the price-3 repair, so the
engine returned price 9. z22 and z22o return 3 only because cost mode hits its work limit
before rung 4 finishes and local mode finds 3. z22r (z23 without the last change) finishes rung
4 under the limit, because of the prune, and returns 9: dl seed 15, `worse` 1.

**The fuzzer summary hid the `worse` count.** `pf.sh` added up invalid, timeouts, levWorse,
priceWorse and k1Worse but not `worse` (price worse than the other engine). It now adds it up.
Older runs had nonzero `worse` counts that no summary showed: z21d 1 against z20x (dl seeds 7, 9,
15), z20e and z19w 1 to 8 per seed against xrefmz. The records for z21m and z22 (`worse` 0
against z21d) hold.

| | z22 | z23 |
|---|---|---|
| LOC | 605 | 606 (+1, +0.2%) |
| Battery | 0.9904 / 86.5, 5,258 ms | same trees (treeDiff 0, costDiff 0), 4,983 ms |
| Gates | all pass | all pass |
| dl / lf worse, invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive misses (41,524) | 0 | 0 |
| Long sets g1 / g3 / g5, worse than z22 | | 0 / 0 / 0 |
| Long sets ms (same run) | 2,763 / 3,251 / 825 | 2,619 / 2,816 / 801 |
| `(1+`, k = 8 / 16 / 32 / 64 | cost 7 / 13 / 29 / 60, 2.5 s at 64 | 7 / 13 / 32 / 64, 0.23 s at 64 |
| `(1+`, k = 512 | | 512, 2.7 s |
| `1+)`, k = 64 | 34.8 s | 0.36 s, same cost |
| `1+)`, k = 512 | | 6.5-7.2 s |
| LR `(1+`, k = 64 / 512 | 44 ms at 64 | same costs, 45 ms / 5.0 s |
| LR `1+)`, k = 64 / 512 | 14 ms at 64 | same costs, 14 ms / 86-105 ms |
| depth, `x (ax)*n b`, `x (ab)*n` at n = 1600 | linear, 110 / 144 ms | linear, 108 / 159 ms |
| `cbcaccbccab` x 1 / 2 / 4 | 2 / 17 / 39 | 2 / 17 / 39 |

The price cost: on `(1+` from k = 32 the answers are 3-4 characters dearer than z22's, since
stage 0 stops before z22's unbounded local mode would have found them. The other three dense
probes give the same costs.

**Refuted this round.**
- z22h: the cost prune alone. Same prices, no speedup; `(1+` k = 256 costs 281.
- z22j / z22k: Pareto dominance in local cells (cost, last and used all no worse). `(1+` k = 64
  7.5 s.
- z22n / z22p: local cells keyed by end only. z22n changes nothing; z22p gives LR `(1+` 19
  against 17 at k = 16.
- z22o: z22 + eager settling in every mode + the cost prune. Fast on non-LR (`(1+` 1.7 s and
  `1+)` 5.5 s at k = 512) but LR `(1+` 4.6 s at 512 and `(1+` costs 16 at k = 16.
- z22q: z23's stages with stage 0 limited to the plain work limit. `(1+` costs 16 at k = 16.
- z22w: local cells keyed by min(end - last, 2) instead of last. Every use of `last` other than
  the `cmp` tie-break reads only that distance, so prices cannot change, but speed did not change
  either: the local cells do not multiply by last edit. Instrumented counts on LR `(1+` at k = 128
  (stage -1, rung 1): 19,211 ways in 774 cells, up to 131 distinct ends in one cell and at most 5
  distinct owed counts. Cells hold O(n) ends: with `used` reset at each settle, `T` at a `(` can
  close with an inserted `)` before any later `+`.
- z22x: z22w + a local read passes on only ways ending at the end of input or costing at most the
  cell's cheapest plus the budget. LR `(1+` costs 52 against 65 at k = 64 and 406 against 513 at
  512, so z23's local answers there are far from the best price, but it takes 83 s at k = 512 and
  LR `1+)` 1.6 s at 64.

**Open.**
- LR `(1+` and non-LR `1+)` are still quadratic in the local stage (O(n) ends per cell).
- Local answers on dense LR `(1+` are at least 20% over the best price (z22x).
- `cbcaccbccab` x k unchanged (12.24).
