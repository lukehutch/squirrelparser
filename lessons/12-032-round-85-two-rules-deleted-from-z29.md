<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.32 Round 85: two rules deleted from z29 (z30)

**Method.** Twelve variants of z29 (kit `yk1` to `yk15`) each delete one rule. Each was run on the
battery against z29; those with no cost change went on to the long sets, Dyck, both fuzzers and
the exhaustive check. The survivors were merged and the merge ran the whole suite again.

**z30 = z29 minus two rules.** Repo `dart/experiments/recovery/_z30.dart`, kit `ym2`.
- yk4: the special case for a repetition of a CharSet, which listed every prefix of the plain
  match as a way. The general repetition code gives the same prices.
- yk6: the final step of `_repeat` that demoted a way when the body could still match cleanly
  past its end.
603 -> 590 LOC (-13, -2.2%). Fields unchanged (`_Way` 10, `_Cell` 4).

**Checks, z30 against z29.** Battery 0.9909 / 87.1 -> 0.9911 / 87.3, costDiff 0, costLower 0
(36 trees differ, all at equal cost); gates the same (freespan 3 3 4 4 1, recommit 16/16,
conformance 0 1 1 0 2 3, cleanTreeDiff 0); pdl run with both engines: z29 dearer on 1 case, z30 on
0; plf: 0 and 0; invalid, timeouts and priceWorse 0 for both; exhaustive 0 worse of 61,204; long
sets 0 dearer, 0 cheaper; Dyck 0 dearer, 0 cheaper of 1,932 (6.7 s for both). Dense k = 1024, same
prices: non-LR `(1+` 3.39 -> 3.25 s, non-LR `1+)` 3.19 -> 3.12 s, LR `(1+` 10.7 -> 10.4 s, LR `1+)`
120 -> 117 ms (within noise).

**A fuzzer run with one engine cannot show a dearer case.** The fuzzers count `worse` against the
cheapest engine in the same run. Every round since z24 ran each candidate alone, so `worse` was 0
by construction. The merge ym1 (yk4 + yk6 + yk13 + yk14) passed every single-engine check and had
battery 0.9919, but run beside z29 on plf it was dearer on 2 cases. Candidates must be fuzzed
beside the current best.

**Refuted this round.**

| Candidate | Result | Verdict |
|---|---|---|
| yk13: drop the queue slot that keeps the earliest of the cheapest ways | plf `babcbcabccbabc` cost 2 against 1 | refuted |
| yk14: drop the fast-forward over clean plain matches in `_repeat` | plf `bbbbbc` cost 4 against 1 (completes `("bbcba" 'c' 'a')+` by insertion instead of deleting the `c`); cheaper on `ccab` (1 against 3) | refuted: changes answers both ways |
| yk7: Optional returns the empty way first | 128 long g3 inputs dearer | refuted |
| yk2, yk15: drop the `o.end == r.end && adv` skip; drop `incomplete` from settle and adv | battery costDiff 9 each | refuted |
| yk9: `cmp` uses evidence directly | battery costDiff 1 | refuted |
| yk3, yk10: Ref read keeps all ways; `_Cell.add` keeps any cheaper way | battery 0.9908 and 0.9904 | refuted |
| yk5: drop zero-width non-clean ways from the repetition's best | battery 0.9590, costDiff 215 | refuted |

**Two cost rules.** On plf, 107 of 6,400 cases (the same 107 for z29 and z30) report a `lastCost`
different from the price `g2` gives the tree's repaired string. `g2`'s `_price` charges a run of
insertions no longer than the reference cap as 1; the engine charges one per inserted character.
Example: `ccab` with `R0 <- (R1?+ / "bcab")`: z29 inserts `cab`, reports 3, `g2` prices 1. This
is a difference between the two rules, not an engine error. The exhaustive and long-set checks use
`g2`'s rule, so they cannot see a case like yk14's `bbbbbc`, where only `lastCost` rises.

**Elegance review.** `dart analyze` on z30 reports no unused code; the deletions leave no orphaned
helper.

**Open.** Unchanged from 12.31: non-LR `(1+` and `1+)` about 3.2 s and LR `(1+` about 10.4 s at
k = 1024 (LR quadratic); `cbcaccbccab` superlinear.

**Addendum: z23, z24 and z30 fuzzed side by side.** To check that running candidates alone since
round 79 hid no regression, z23 (z22v), z24 (zf3) and z30 (ym2) ran in one fuzzer run. pdl: worse
4 / 1 / 0, levWorse 3 / 1 / 0; plf: worse 1 / 0 / 0; invalid, timeouts and priceWorse 0 for all
three. z30 is dearer than neither older engine on any of the 12,800 cases.
