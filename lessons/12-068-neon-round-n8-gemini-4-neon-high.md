<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.68 Neon round N8 (gemini-4-neon-high): z64, a sound overflow reset, and a speed gate fitted to two inputs

**Result.** z64 = vgn8c: z63 with Neon's overflow fix (memo version advanced instead of an in-place reset), an exact
edit count for equal-cost ways at high rungs, 32/31 score weights, a fallback bound one higher when the best way has
more marks than its cost, and a binary search in `_add`; Neon's change to the local recheck is left out. Fields 7 ->
7, bookkeeping lines (bkl.sh) 11 -> 11, 584 -> 575 formatted LOC (-9, -1.5%). Every check.sh accuracy row passes;
pdls4/plfs4 worse 120/79 -> 63/34 (priceWorse 0/0); fresh f3a 0 above; new public set f3n equal to z63; held-out
0/0/0 -> 2/0/1 above z37a (excess 1 each). Instructions equal to or below z63 on all 10 speed rows (0.88-1.02x).
Neon's own final engine, vgn8, fails group5 and scores 0.

| Engine | Change from z63 | Fields | bkl | floc | Result | Verdict |
|---|---|---|---|---|---|---|
| vgn8 | all of Neon's changes | 7 | 11 | 583 | group5 timeout (g0 35.7e9 vs 7.4e9); cbc8 0.18e9 | fails, score 0 |
| **vgn8c = z64** | **vgn8 with z63's recheck** | **7** | **11** | **575** | **every accuracy row; worse 63/34; overflow fixed** | **chosen** |
| vgn8x | vgn8c's recheck placed in vgn8 | 7 | 11 | - | group5 g0 6.70e9 | locates the timeout |
| vgn8y | vgn8x without `_cmpEx` | 7 | 11 | - | same held-out rows as vgn8c | not the cause |
| vgn8f | vgn8c without the fallback +1 | 7 | 11 | - | worse 76/41; same held-out rows | rejected |
| vgn8w | vgn8c with z63's 4/3 weights | 7 | 11 | - | f3n identical to vgn8c and z63 | weights not the cause |

**What taught something.**
1. **An untested risk named in the record was a real bug.** N7-5 said that z63's in-place memo reset could leave a
   partly grown left-recursion seed, and no check exercised an overflow inside a growing seed. It was a real bug:
   with nesting deep enough to overflow the stack inside `D` while `E` grows, z63 prices a valid input at 1 and a
   one-error input at 3, up to 17x slower. The likely cause (inferred from the code, not traced) is that the reset
   cleared the entries the overflow reached but not the seed of the enclosing growth, so the retry started from a
   seed the parser had not finished. Advancing the memo version
   discards every entry the failed attempt touched, which is what a fresh parser did before z63, but keeps the
   others (D1). Why no check found it: every deep input in the kit is either not left-recursive at the overflow point
   or not deep enough to overflow. A risk listed as "not tested" should get a test before the engine is promoted, not
   after.
2. **A speed gate fitted to the inputs that motivated it fails on the inputs that did not.** Neon's recheck change
   was built to cut cbc8 (1.14e9 -> 0.18e9) while keeping semi3, and both pass. It also added the condition "some
   rule has a repetition", which is true for nearly every real grammar, and changed the recheck budget from 4 to 2,
   and on the group5 grammars the instructions rise from 7.4e9 to 35.7e9 (g0). Which of the two conditions causes the
   rise was not separated; restoring z63's whole recheck block removes it. The
   per-change ablation located this in two runs. A change made to speed one row must be timed on every row, because
   the conditions it adds are about the grammar class, and the row that motivated it is one member of that class.
3. **A score scaled by a power of two changes ties, not costs.** Going from 4/3 to 32/31 changes no price (LR fuzzer:
   0 of 3,800 prices differ) and no f3n count. Its effect is on which of two equal-cost ways is kept, which is what
   pdls4/plfs4 measure. Removing the fallback +1 alone raises worse from 63/34 to 76/41; the share of the weights and
   of the exact count in 120/79 -> 63/34 was not measured. The cost reported in the fuzzer falls to the price on 15 lines, because the
   exact count at high rungs removes the collision N7-2 found.
4. **A difference on one sample is not a regression until a second sample shows it.** vgn8c is 1 above z37a on three
   held-out inputs, and none of the three changes tested explains them. On a new public sample of the same size and
   generator, z63 and z64 give identical counts, and z63 is itself above z37a there by up to 3. The held-out counts
   therefore show variation between samples, not a property of z64. Each ablation run on the held-out set also makes
   it less independent, so the third and later diagnoses moved to a new public sample.
5. **A model that runs out of time leaves an unchecked engine.** Neon used its five hours on a full 16-engine
   comparison (complete and correct where spot-checked) and on experiments, and wrote its report as a draft to be
   finished at the end. The final check.sh run never happened. Briefs should ask for check.sh on each candidate as
   soon as it is built, and for a report that is complete after each candidate, so a timeout loses the last idea,
   not the verification of every idea.
