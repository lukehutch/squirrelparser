<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.30 Round 83: the stop rule of round 82 can leave no repair; the last stage reruns without it (z28)

**The defect (z27).** In stage -1 a repetition does not stop where its next iteration starts
cleanly. When the element after the repetition starts with a character the repetition's own
sub-clause also matches, every stop the rest of the sequence needs is removed, stage -1 finds no
repair, and z27 returns path `none` (the whole input as one error). Grammar
`S <- R0; R0 <- ((R0 / R1)* ('c'? "bcc"+ 'a'*) 'b'*); R1 <- (R1 / 'b')`, input `bccb` x k,
`_g2.dart` witness price (1000 = no repaired string of the tree parses):

| k | 4 | 6 | 8 | 12 |
|---|---|---|---|---|
| z26 price / ms | 10 / 137 | 18 / 577 | 26 / 1,089 | 42 / 4,604 |
| z27 price / ms | 10 / 114 | 1000 / 508 | 1000 / 1,006 | 1000 / 3,583 |
| z28 price / ms | 10 | 18 / 814 | | 42 / 7,596 |

None of the standing checks saw it: the fuzzers, the exhaustive check and the long sets never
produce this shape, and the long sets compare against a base engine's price, not an exact one.
`bccb` x {6, 12} is now part of the suite, compared with z26.

**The fix (z28).** If stage -1 ends without a repair, the search runs once more as stage -2, in
which repetitions may stop anywhere (the z26 rule). It costs time only on inputs where stage -1
fails (z28 is 1.4-1.7x slower than z26 on `bccb` x k, since stage -1 runs to the end first).
602 -> 603 LOC (+1, +0.2%); fields unchanged (`_Way` 10, `_Cell` 4).

**Checks, z28 against z27.** Battery 0.9909 / 87.1, treeDiff 0, costDiff 0; gates as z27 (freespan
3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0); pdl and plf 0 worse, 0
invalid of 6,400 each; exhaustive 0 worse of 61,204; long sets 0 dearer, 0 cheaper; Dyck 1 dearer
(as z27); dense costs the same, times within noise; `cbcaccbccab` x {2, 8} keeps z27's prices
5 / 23.

**Refuted this round.**

| Candidate | Result | Verdict |
|---|---|---|
| zs24a: a repetition in stage -1 keeps all its ends when none survives the stop rule | `bccb` x 6 still 1000 | refuted: some ends survive in each repetition, but the sequence still fails |
| zs21: a recomputed repetition resumes from its old ways; old ways read only sub-clause ways added since (per-way birth stamps), new ways read all | `cbcaccbccab` k = 2/4/8 priced 16/38/82 (z26 prices) | refuted |
| zs21z: as zs21, but only ways the old run extended get the delta read | k = 2 still 16 (k = 4..16 exact); 2-4x slower | refuted: the repetition's settle and sync tests read the whole step set, so a delta step set changes their answers |
| zs22 (D = 2, 8, 32): local cells merge ways whose last edit is more than D before their end | battery same, `cbcaccbccab` k = 32 time unchanged (10.6-11.2 s) | no effect: last-edit diversity is not the cost |
| zs23: labeled copies of cell ways cached per way | k = 32 10.6 -> 15.3 s | refuted: allocation is not the cost |

**Diagnosis of the remaining `cbcaccbccab` time.** Valid strings of this grammar (`c` + `bcc` x m +
`ab`, m up to 2,000) parse in 0 ms, so the superlinear time comes from the dense errors (3k - 1
edits) alone. At k = 32 the reads average about 44 ways each: 39.6M choice reads over 2,558
recomputations of `(R0 / R1)*` times about 350 positions. Each recomputation walks the repetition to
the end of the input, because one iteration of `R0` can span the rest of it.

**Elegance review.** The change is one loop condition and one reset line; stage -2 reuses the
stage -1 code path, and every `_rung < 0` test treats it as stage -1. No finding.

**Open.** Unchanged from 12.29: non-LR `(1+` superlinear, non-LR `1+)` 4.9 s and LR `(1+` about
11 s at k = 1024, Saha m >= 32, `cbcaccbccab` superlinear (k = 32 10.8 s).
