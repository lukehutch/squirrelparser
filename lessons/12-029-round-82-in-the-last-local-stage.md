<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.29 Round 82: in the last local stage a repetition does not stop where its next iteration starts cleanly (z27)

**Diagnosis.** On dense non-LR `(1+` (grammar `E <- T ('+' T)*`) nearly all the time goes to the
unbounded local stage (`_rung` -1). A tracer copy of z26 (kit `zt3`) counted, at k = 1024, 633k
cell reads returning 15.1M ways, against 17k recomputations. The reads of `('+' T)*` alone
returned 5.8M ways: a local repetition cell keeps one way per iteration end, so it holds O(n)
ends, and every parent read walks all of them.

**Change.** When `_rung < 0`, `_repeat` drops a way that ends where its sub-clause starts
cleanly (`_startsClean`). In that position a PEG repetition would try one more iteration, so such
a stop is the least likely to be part of the cheapest repair. Stage 0 and cost mode are
unchanged. At k = 1024 the stage -1 reads fall from 15.1M ways to 5.1M.

| Candidate | `(1+` k = 1024 | Dense prices against z26 | Other checks | Score | Verdict |
|---|---|---|---|---|---|
| zs15: the change above | 8,475 -> 3,163 ms | +1 on `(1+` from k = 32 | all equal to z26 | 7 | adopted (z27) |
| zs16: zs15 + a choice skips arms that start with an edit where another arm starts cleanly | 3,142 ms | as zs15 | all equal to z26 | 5 | no gain for 4 more lines |
| zs17a: z26's stage -1 under 16x the limit, then the zs16 rules | 3,970 ms | z26 prices to k = 128, +1 from k = 512 | not run | 5 | an extra stage for a small gain |
| zs17b: as zs17a at 64x | 6,846 ms | as zs17a | not run | 3 | slower |
| zs18: stage -1 settles after one clean character (`dEv > 0`) | 8,309 ms | same as z26 | not run | 2 | little gain |

**Harness note.** `_g2.dart` reports price 1000 when no witness string parses, and
`_witnesses` cannot name the fill of an inserted CharSet (here `T` matching `[0-9]` at the end of
the input), so a valid tree that inserts a digit also reads as 1000. The `1+)` and `(1+` rows of
g2 at k >= 32 are this, not invalid trees.

**z27 = z26 + the stop rule.** Repo `dart/experiments/recovery/_z27.dart`, kit `zs15`.
602 -> 602 LOC (+0, 0%). Fields: `_Way` 10, `_Cell` 4, engine fields unchanged.

| | z26 | z27 |
|---|---|---|
| Battery | 0.9909 / 87.1, 4,921 ms | 0.9909 / 87.1, 4,913 ms; same trees and costs |
| Gates | all pass | all pass |
| dl / lf worse, invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive (g1-g5, 61,204 cases) worse | 0 | 0 |
| Long sets g1 / g3 / g5 against z26 | | 0 dearer, 0 cheaper, 0 timeouts |
| Dyck(2), dearer than exact (of 1,932) | 1 | 1 |
| Non-LR `(1+`, cost k = 16 / 32 / 64 / 128 | 13 / 32 / 64 / 128 | 13 / 33 / 65 / 129 |
| Non-LR `(1+`, k = 256 / 512 / 1024 | 915 / 2,436 / 8,475 ms | 582 / 1,229 / 3,163 ms, cost k + 1 |
| Other three dense families | | same costs and times |

**Elegance review.** The first version also tested `r.end == _len`; `_startsClean` is false at
the end of the input for every clause (a Seq needs a non-empty plain match, and Ref and First
reduce to Seqs), so the test was deleted; the battery and dense runs are unchanged.

**Open.** Non-LR `(1+` is still superlinear (x2.6 from k = 512 to 1024): each local iteration
of `T <- '(' E ')'` still ends at O(n) places because the inner `E` does. Non-LR `1+)` (4.9 s at
k = 1024) spends its time in stage 0 doubling b to 32 and stage -1 needing b = 2: the settle test
`dEv > 1` never holds on `+)1` iterations, whose clean tail is one character, so nothing settles
and the budget must reach k. Saha m >= 32; local prices on dense LR `(1+`; `cbcaccbccab` x k.

**Addendum: z27 also settles `cbcaccbccab` x k.** Measured after the commit with `_g2.dart`
(witness price, the edit distance of a repaired string that parses), grammar
`S <- R0; R0 <- ((R0 / R1)* ('c'? "bcc"+ 'a'*) 'b'*); R1 <- (R1 / 'b')`:

| k | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 |
|---|---|---|---|---|---|---|---|---|
| z26 price | 2 | 16 | 38 | 82 | | | | |
| z26 ms | 65 | 587 | 4,292 | 55,476 | | | | |
| z27 price | 2 | 5 | 11 | 23 | 47 | 95 | 191 | 383 |
| z27 ms | 44 | 273 | 282 | 434 | 1,535 | 10,769 | 121,002 | 277,322 |

The exhaustive reference gives 5 at k = 2, so z27 is exact there; its prices are 3k - 1 at every
k. Time is still superlinear from k = 16. A z27 trace at k = 32: the last run (stage -1, b = 2)
reads 44.0M ways, 39.6M of them from the choice `(R0 / R1)` inside `(R0 / R1)*`; that
repetition is recomputed about 2,558 times as `R0` grows, and each recomputation rereads the
whole choice cell at every position.

**Refuted after z27.**

| Candidate | Result | Verdict |
|---|---|---|
| zs19a: the settle test counts a next iteration that starts cleanly (`dEv > (startsClean ? 0 : 1)`), all modes | battery same; non-LR `1+)` k = 1024 4.9 -> 3.4 s, `(1+` 3.2 -> 4.0 s | no net gain |
| zs19b: as zs19a, local mode only | as zs19a | no net gain |
| zs20: a repetition recomputed at the same budget reads its sub-clause at its start as a delta (only the ways just added) | battery same; `cbcaccbccab` back to z26 prices (16 / 38 / 82) and 49.7 s at k = 8 | refuted: the old first iterations are needed again after growth |

Also measured: LR `(1+` k = 1024 is about 11 s in z25, z26 and z27 (unchanged since round 80).
