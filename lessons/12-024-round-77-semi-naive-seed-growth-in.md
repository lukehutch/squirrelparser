<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.24 Round 77: semi-naive seed growth in every mode (z22); settling sooner is fast but costs price

**What was slow.** Recompute counters (instrumented copies z21p, z21kp, z21lp) split the local
mode work. On `1+)` (E <- T ('+' T)*) cells are re-read at every budget below the rung, since
`_seq` passes `b0 - r.used`: 9,597 recomputes at k = 32, 6,126 of them for a higher budget. On
LR `(1+` (E <- E '+' T / T) only rung 1 runs, but recomputes after a seed version change grow
quadratically (2,031 / 7,093 / 26,453 at k = 32 / 64 / 128): each growth pass re-proposed the
whole rule and so re-extended every way already in the cell, and a local-mode LR cell holds
about one way per later end (19,211 ways in all cells at k = 128).

**z22 = z21 + semi-naive seed growth.** Each growth pass records the ways it added
(`_Cell.fresh`), and a read of the growing cell returns only those; older ways were extended by
an earlier pass. cl12 did the same in the cl line. 605 -> 605 LOC (0, 0%); one cell field added
(`fresh`).

| | z21 | z22 |
|---|---|---|
| LOC | 605 | 605 (+0, 0%) |
| Cell fields | mark, ver, dep, arm, seeded, ends, _at | + fresh |
| Battery | 0.9904 / 86.5, 6,110 ms | same trees (treeDiff 0, costDiff 0), 5,258 ms |
| Gates | all pass | all pass |
| dl / lf invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive misses (41,524) | 0 | 0 |
| Long sets g1 / g3 / g5, worse than the other | 0 / 0 / 0 | 0 / 0 / 0 |
| Long sets ms | 2,677 / 3,145 / 830 | 2,564 / 2,992 / 813 |
| LR `(1+`, k = 128 / 256 | 1.05 s / 8.1 s | 0.16 s / 0.75 s, same costs |
| LR `1+)`, k = 128 | 50 ms | 22 ms, same costs |
| `(1+`, k = 64 / 256 | 2.5 s / 9.4 s | 2.5 s / 8.9 s, same costs |
| `1+)`, k = 64 | 37.3 s | 34.1 s |
| `bbbbcb` x4 | 0.8 s, cost 8 | 0.8 s, cost 8 |
| depth, `x (ax)*n b`, `x (ab)*n` | linear | linear |

**Refuted this round.**
- z21g: local cells computed once per rung at the rung's full budget, filtered by `used` on read.
  Costs rise on `(1+` (17 / 36 / 70 / 139 against 13 / 29 / 60 at k = 16 / 32 / 64), since the
  budget also steers pruning inside a cell, and LR `1+)` goes from 50 ms to 5.8 s at k = 128.
  z21h (the same with dominance on `used` and `last`) is no better.
- z21i / z21k / z21l: in local mode a repetition may settle after one clean character after
  the last edit instead of two. Very fast (`1+)` k = 256 in 1.1-1.4 s, `(1+` k = 256 in 0.5 s),
  battery, gates, fuzzers and exhaustive unchanged, but prices rise: `(1+` 16 / 32 / 64 against
  13 / 29 / 60, and 4 of 600 g3 long inputs one edit worse (shrinks no further than 35 chars,
  since local mode starts only past the work limit).
- z21n: settle when a step's first edit is at least two characters after the prefix's last edit
  (the gap measured across the step boundary, which is where `1+)` hides it). Same speed and the
  same price losses as z21k.
  Settling sooner lets a low local rung answer, and the first rung with an answer wins; the
  cheaper answers need one region with many edits, which only a high rung admits. Speed on these
  probes needs a mechanism other than settling.

**Open.**
- `cbcaccbccab` x k (S <- R0; R0 <- ((R0 / R1)* ('c'? "bcc"+ 'a'*) 'b'*); R1 <- (R1 / 'b')):
  the exhaustive reference gives 2 / 5 for k = 1 / 2; z22 gives 2 / 17 / 39 / 83 for
  k = 1 / 2 / 4 / 8 (90 s at k = 8), z20x 2 / 11 / 17 / 29. Trace at k = 2: the work limit
  (about 4,400) stops cost mode inside rung 2; local rungs 2-16 find ways costing 3 that the
  library parser rejects, the first accepted one comes at rung 25 for 17, and the bounded exact
  search does not finish.
- Non-LR `(1+` and `1+)` stay superlinear in local mode (budget-driven recomputes).
