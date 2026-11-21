<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.31 Round 84: the recheck of round 81 gets four times the work (z29)

**Change.** When local mode returns a repair dearer than what cost mode proved, z26 reruns cost mode
one rung below the local price, within `_exactPer` (16) times the work limit. z29 allows 4 x 16 = 64
times the limit. One constant changes; 603 -> 603 LOC (+0, 0%); fields unchanged (`_Way` 10,
`_Cell` 4).

**Why.** The one Dyck(2) input z28 prices above the exact distance (z28 6, exact 5, a Saha m = 32
input) needs more than 16x the work limit for the recheck to finish. At 4x it finishes and finds 5.

**Checks, z29 against z28.** Battery 0.9909 / 87.1, treeDiff 0, costDiff 0; gates the same
(freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0); pdl and plf 0
worse, 0 invalid of 6,400 each; exhaustive 0 worse of 61,204; long sets 0 dearer, 0 cheaper; Dyck
dearer 1 -> 0 of 1,932 (6.7 s vs 7.1 s total). Saha m = 32 and 64 (6 seeds each): z29 matches the
exact distance on all 12 (z28 is 1 dearer on one). Dense k = 1024 times are the same within noise
(non-LR `(1+` 3.2 s, non-LR `1+)` 3.2 s, LR `(1+` 10.5 s, LR `1+)` 0.12 s); `bccb` x 6/12 18/42 at
the same times; `cbcaccbccab` x 8/32 23/95 at the same times.

**Refuted or not adopted this round.**

| Candidate | Result | Verdict |
|---|---|---|
| zs26m16: recheck at 16 x 16 times the limit | same prices as z29; one Saha m = 64 input 0.5 -> 1.6 s | not adopted: no gain over 4x |
| zs25: in local mode a way is dropped when an earlier-last-edit way with the same key, owed, cost <= and used <= exists | `bccb` x 6/12 no repair (1000); `cbcaccbccab` x 2 priced 8 (exact 5) | refuted: the last edit is what lets a later edit settle |
| zs27w: in local mode no inserted opener wraps the rule's own seed while it grows | LR `(1+` k = 1024 10.5 -> 8.4 s, non-LR `(1+` 3.2 -> 3.8 s, same prices | not adopted: no net gain, soundness unproved |
| zt7: skip local stage 0 | non-LR `1+)` stage -1 at budget 1 fails from k = 8, budget 2 succeeds | diagnostic only |

**Diagnosis of LR `(1+` (traced with zt5).** Each growth pass of `E@p` adds one more flattened way
one level deeper, with cost one higher (k = 8: end 8 cost 1, end 11 cost 2, ..., end 24 cost 7).
Local mode keeps every one of them, so `E@p` grows k - p times. The cells `T@p`, `'(' E ')'@p` and
`E '+' T@p` read the seed of `E@p` (an inserted `(` reads it), so they are recomputed on every
pass. The work is Theta(k^2). A dominance rule over those ways that keeps the prices is still
needed.

**Elegance review.** One constant. No finding.

**Open.** Non-LR `(1+` and `1+)` about 3.2 s and LR `(1+` about 10.5 s at k = 1024 (quadratic in
the LR case, cause above); `cbcaccbccab` superlinear (k = 32 10.8 s).
