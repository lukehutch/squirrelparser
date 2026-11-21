<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.27 Round 80: a growing choice reads only what its arms added (z25)

**Diagnosis.** On dense LR `(1+` in stage -1, a tracer (kit `zt1`) showed that each growth pass
of `E`'s choice re-read the whole cell of its arm `E '+' T`, which holds about k ways. The work
is positions x passes x ways, about k^3. The semi-naive reads of 12.24 covered only a seed
reading itself, not a choice reading an arm cell that the seed's growth had recomputed.

**Change.** When an arm cell is recomputed during a choice's second or later pass, its read
returns only the ways that recomputation produced (`fresh` is kept after the compute), not the
whole cell. One engine field (`_delta`) carries the flag from the choice to the arm read. No
cell field was added.

**Candidates.**

| Candidate | Result | Verdict |
|---|---|---|
| zs4: arm read returns the recomputation's ways | LR `(1+` k = 1024 52.8 -> 10.8 s, same prices; whole suite passes | adopted as z25 |
| zs3: tick log and `far` per cell, read ways after the pass start | same speed; whole suite passes, 7 trees differ | three cell fields more than zs4 |
| zs2: a birth stamp per way, filter every arm read | k = 512 8.0 -> 4.5 s | still scans the whole cell |
| zs1: filter only arms that `_active` marks | no change | `_active` never marks a Seq arm |
| zg4, zg16, zg64: cap the ends kept per cell | LR `(1+` price 381 against 129 at k = 128, slower | refuted |

**z25 = z24 + the arm read.** Repo `dart/experiments/recovery/_z25.dart`, kit `zs4`.
594 -> 597 LOC (+3, +0.5%). Fields: `_Way` 10, `_Cell` 4 (unchanged); one engine field more
(`_delta`). The elegance review deleted a dead local (`f` in the repetition, present since z24).

| | z24 | z25 |
|---|---|---|
| Battery | 0.9908 / 87.1, 4,830 ms | 0.9909 / 87.1, 4,867 ms; 8 trees differ at equal cost |
| Gates | all pass | all pass |
| dl / lf worse, invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive misses (41,524) | 0 | 0 |
| Long sets g1 / g3 / g5 against z24 | | 0 dearer, 0 cheaper, 0 timeouts |
| LR `(1+`, k = 512 / 1024 | 8.0 s / 52.8 s | 3.0 s / 10.8 s, same costs |
| LR `1+)`, k = 512 / 1024 | 145 / 397 ms | 55 / 97 ms, same costs |
| non-LR `(1+`, k = 512 / 1024 | 2.6 s / 8.4 s | 2.5 s / 9.0 s |
| non-LR `1+)`, k = 512 / 1024 | 1.8 s / 4.7 s | 1.76 s / 4.7 s |
| depth, `x (ax)*n b`, `x (ab)*n` at n = 1600 | linear | linear, 106 / 153 ms |

LR `(1+` is now about n^1.85 from 512 to 1024, against n^2.7 before. The rest is inferred to be
the O(n) ends each local cell keeps (12.25).

**Open.** Non-LR `(1+` and `1+)` are unchanged by this change, still about n^1.7; a tracer run
at k = 128 / 256 shows stage -1 doing most of the work (work 233,088 / 547,776), with the
`First` of `T` recomputed for a new version about k times, each recompute reading about k ways.
Also open: local prices on dense LR `(1+`, and `cbcaccbccab` x k.
