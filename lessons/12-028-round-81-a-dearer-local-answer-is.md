<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.28 Round 81: a dearer local answer is checked by cost mode one rung below it (z26)

**New check: exact Dyck(2) prices.** 1,932 inputs of the grammar `S <- ('(' S ')' / '[' S ']')*`:
1,920 bracket shapes plus 12 instances of Saha's hard family (m = 16 and 32). The exact price of
each is the Dyck edit distance (insertions and deletions), from a cubic dynamic program in
Python. z25 is dearer than the exact price on 92 of them, for example `[[[((((())])` priced 4
against 3, and `((((())]]]]]]` priced 6 against 5. None is cheaper. (A hand count of 6 for
`[(((((]]]]])` was wrong; the program's 5 is right.)

**Diagnosis.** On every miss, cost mode stopped at the work limit (about 4,150) when it needed
about 4,636 to finish, and local mode then returned a dearer repair. Cost mode with no limit
(kit `zs4u`) is exact on all 92, but takes about 20 s at m = 64. Exact pricing cannot be linear
in general: Dyck and language edit distance have conditional lower bounds under SETH
(Backurs and Indyk; Saha; Fried et al.), so some misses must remain under a linear work cap.

**Change.** When cost mode stops, the rung it proved empty (`sure`) and twice the rung it was
running (`reach`) are kept. If local mode then returns a repair of cost c with
sure + 1 < c <= reach + 1, cost mode runs once more at rung c - 1, within _exactPer times the
work limit, and a cheaper answer replaces the local one. If the recheck stops, or is doubted,
the local answer is kept through `_checked`. `sure`, `reach` and `limit` are locals; no field
was added.

**Candidates.**

| Candidate | Dyck dearer (of 1,932) | Other result | Verdict |
|---|---|---|---|
| zs14: recheck at c - 1 when c is within the next doubling, 16x the limit | 1 | suite passes; LR `1+)` k = 1024 108 ms (z25 111) | adopted as z26 |
| zs10: recheck at c - 1 always, 16x the limit | 1 | suite passes; LR `1+)` k = 1024 9,086 ms, non-LR k = 128 1.6-2.2x slower | the recheck always fails on dense inputs |
| zs13: as zs10, 4x the limit | 1 | LR `1+)` k = 1024 2,383 ms | too slow |
| zs12: as zs10, 1x the limit | more than zs13 (count from the faulty script, not rerun) | non-LR k = 128 up to 1.7x slower | superseded by zs14 |
| zs11: zs10 with the recheck repeated | same prices as zs10 | | no gain |
| zs4u: no work limit | 0 | about 20 s at m = 64 | not linear |
| zs5: keep doubling in local mode | | | refuted |
| zs6: deletion before the top rule in local mode | | | refuted |
| zs7: Pareto local cells | fewer than z25 | | partial |
| zs8: local cells keyed by first edit | fewer than z25 | | partial |
| zs9: doubt plus the exact string search | | | refuted |

**Measurement error found.** The first `dyck.sh` listed `dyck_part_*`, which also matched the
`.out` files of earlier runs, so later runs counted those as input lists: counts of 3,203, 1,579
and 2,257 rows instead of 1,932. Each run now uses its own new directory. The zs12 and zs13 counts
came from the faulty script; zs4, zs10 and zs14 were rerun on the fixed one.

**z26 = z25 + the recheck.** Repo `dart/experiments/recovery/_z26.dart`, kit `zs14`.
597 -> 602 LOC (+5, +0.8%). Fields: `_Way` 10, `_Cell` 4, engine fields unchanged.

| | z25 | z26 |
|---|---|---|
| Battery | 0.9909 / 87.1, 4,867 ms | 0.9909 / 87.1, 4,921 ms; same trees and costs |
| Gates | all pass | all pass |
| dl / lf worse, invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive (g1-g5, 61,204 cases) worse | 0 | 0 |
| Long sets g1 / g3 / g5 against z25 | | 0 dearer, 3 cheaper (g1), 0 timeouts |
| Dyck(2), dearer than exact (of 1,932) | 92 | 1 (Saha m = 32, 6 against 5) |
| Saha m = 64, dearer (of 6) | 2 (10 vs 9, 13 vs 11) | 2, same |
| Dyck(2) total time | 5,233 ms | 6,402 ms |
| Dense, k = 128, all four families | same costs | same costs, times within noise |
| Dense, k = 16 | | `1+)` 118 -> 251 ms, LR `1+)` 11 -> 125 ms (the recheck fires) |
| LR `1+)` k = 1024 | 111 ms | 108 ms |

**Elegance review.** The recheck repeats the four-statement cell reset of the `_Stop` handler and
the overflow path (three copies). A helper would name it but add a line; left as is. A doubted
recheck makes `_recover` return null, and `recover` then falls back to `_checked`, which holds
the cheapest checked repair of every run, so the local answer cannot be lost.

**Open.** Saha instances at m = 32 and 64 (expected under a linear cap, by the SETH bounds above);
non-LR `(1+` and `1+)` about n^1.7; local prices on dense LR `(1+`; `cbcaccbccab` x k.
