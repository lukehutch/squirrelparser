<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.65 Round X2 (Claude Fable 5.2, high effort): z61, one fitted constant removed

**Result.** z61 = vfx2h, taken unchanged: z60 with the recheck bound `_len * c < (l ? 2048 : 1024)` written as
`_len * c < 2048`. Fields 8 -> 8, bookkeeping lines (bkl.sh) 13 -> 13, 480 -> 480 formatted LOC (0, 0%). Every check.sh
row equals z60's except tfam and both rule-naming T rows, 3/24 -> 1/14 (a new record within the bands). Fresh f3a and
held-out equal to z60 (Fable's two extra fresh seeds: one g1 input fixed, none added); LR fuzzer 3,800 lines
byte-identical. Cost: T-family instructions +22% (7.50e9 -> 9.15e9, still 0.70x vm13b). big.sh failed 1 of 10 rows,
`L (1+` k = 16384, where z61 and z60 both run about 2x vm13b's instructions (z60's own check failed 4 of 10 rows).

| Engine | Change from z60 | Fields | bkl | floc | Result | Verdict |
|---|---|---|---|---|---|---|
| **vfx2h = z61** | **one recheck bound, 2048** | **8** | **13** | **480** | **tfam 1/14, all else equal** | **chosen** |
| vfx2g1 | one search mode (global cost), no `used`, no settling | 7 | 11 | 413 | tfam 0/0; cbc 2/18/29/40; no dense row in 150 s | rejected |
| vfx2l0 | one search mode (local), no recheck | 8 | 13 | 472 | battery 0.9801/82.6 | rejected |
| vfx2d1 | global recheck only | 8 | 13 | - | fresh 0 above z37a; cbc 10-40x slower | rejected |
| vfx2h0 / vfx2h2 | single bound 1024 / 4096 | 8 | 13 | 480 | f3a 19 inputs above / no answer gained | rejected |

**What taught something.**
1. **One search mode fails because cheap ways that PEG would not parse displace the valid ways in the cells.** The
   one-mode engine is the simplest design in reach of the author's request for minimal logic (2026-10-31): in global cost mode `used` equals
   `spent + _ex(owed)` (N5-4), so with one mode the field, the settle tests and the mode switch all go (7 fields,
   bkl 11, floc 413). It fails on cbc, and the trace shows why. A repetition that stops one character early gives a
   repair that is cheaper than the valid one, but when the repaired string is parsed again, the greedy repetition
   takes that character and the repair no longer parses. Each cell keeps one way per (end, owed), so the cheaper invalid
   way replaces the valid one and the valid repair is found only rungs later. Each doubling of the rung then refills every cell, which is why the
   same engine is also too slow. The local modes avoid this without being designed for it: their budget counts
   edits per error region, so the final parse rejects the invalid candidates while the rung is still small. The
   second mode, and with it `used`, is in the engine to keep the search inside PEG semantics, not to make it fast.
   A one-mode engine needs a cell that refuses a way whose stopped repetition could take the next character (the
   `_takes` test of N5-2, applied where a way enters a cell). This has not been built.
2. **A constant can be a time limit disguised as a semantic switch.** The halved bound 1024 applied only to grammars
   with short completions, which looked like a property of the grammar. Varying it on both sides showed it bought
   no answer anywhere. It only kept the recheck from running. Under the ranking, the answers it cost outweigh the time
   it saved (+22% instructions on tfam, inside every band). Constants that guard the cost of a recheck should be
   tested by removing them before anyone argues for them.
3. **Each remaining constant is needed on both sides, which means it is fitted, not derived.** The rung cap, the 3 in
   `synced`, 8, 4, 2048 and the fallback's 12 each fail some family when moved up or down by one step. A derived
   quantity would have a range where the answers do not change. These constants are tuned to the families. The
   global recheck that would replace them is exact but 10 to 40 times slower on dense damage, so the trade between
   the recheck's exactness and its cost is still decided by fitted numbers (N1-2's open question).
4. **The agent built the redesign the brief asked for and explained its failure; the measured gain is small.** X2
   tested the main question directly, varied every constant on both sides, and gave each check a negative control.
   It removed no field and no line. Together with X1, this suggests the z59-z61 design is near a local minimum:
   single-condition and single-constant changes are exhausted, and the next step is the cell-level `_takes` test
   that would make the one-mode engine valid.
