<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.69 Synthesis round S1 (orchestrator): z65, an exact radix in place of fitted weights, and a fresh parser on overflow

**Result.** z65 = vs6a: z64 (vgn8c) with (1) the score's radix set to the input length + 1 instead of 32, which
removes the 32/31 weights, both `>= 32` thresholds, `_sd` and `_cmpEx`; (2) a new `Parser` for each attempt after a
stack overflow, which removes the last write to library memo state (`memoVersion`, `inRecPath`, `foundLeftRec`);
(3) three size cuts with identical output (`_mins` kept across runs inside one `recover`, a shorter `_flat`, no
append fast path in `_add`). Fields 7 -> 7, bookkeeping lines (bkl.sh) 11 -> 11, 575 -> 546 formatted LOC (-29,
-5.0%). Every check.sh accuracy row is identical to z64 (battery 0.9901/86.6, pdls4/plfs4 worse 63/34, priceWorse
0/0, pfam prices, Dyck, lz, controls, wxyz); fresh f3a 0/0/0; public f3n identical to z64; held-out identical to
z64 (2/0/1 above z37a, excess 2/0/1); overflow test costs 0/0/1, as z64; LR fuzzer 0
different. Instructions 0.94-1.05x z64 (interleaved perf stat, two passes); the check.sh SLOW FAIL rows (dense, validity, semi, tfam, rg2) are load:
instruction counts of those whole parts are 0.995-1.034x z64 with identical output.

| Engine | Change from z64 | floc | Result | Verdict |
|---|---|---|---|---|
| vs2a | radix + fresh parser | 559 | all accuracy rows equal; instructions 0.96-1.01x | base of z65 |
| **vs6a = z65** | **vs2a + mins1 + flat1 + add1** | **546** | **all rows equal; 0.94-1.05x** | **chosen** |
| vs5c | vs2a + mins1 (`_mins` not cleared per run) | - | equal; L/T equal, rg2-12 +4% | merged |
| vs5d | vs2a + flat1 (one-line `_flat`) | - | equal; L k=16384 +4.6%, T +3% | merged (size ranks above speed) |
| vs5e | vs2a + add1 (no append fast path) | - | equal; L/T +0-2% | merged |
| vs5a | `_sc` computed by the caching `_ev` | - | equal output, 3-24% slower | rejected |
| vs5b | `_end` by `parser.match` only (`_hit` removed) | - | equal output, 5-33% slower | rejected |
| vs3g | `_noIns` (inserted nothing) at the `_pureSub` sites | - | tfam excess 14 -> 1; tfam 6.5x, rg1-24 233x instructions | rejected |
| vs4b | one recheck rule, run at c - 1 always | - | cbc8 47x instructions | rejected |
| rc7c | vgn7c's recheck (no 8, 3/2, budget 4) | - | slower on the same rows as vs4b | rejected |

**What taught something.**
1. **A fitted radix is an exactness bound in disguise.** z64's score is `32 * S_c + 31 * D` rounded by `>> 5`: it
   orders by `S_c + D` and then by more deletions, but only while `D < 32`. Past that the packed value can no
   longer separate the two counts, which is why z64 needed `_cmpEx` (an exact recount) for equal-cost ways at
   rungs and costs `>= 32`. With the radix `L + 1`, where `L` is the input length, the score is
   `(L + 1) S_c + L D` and `(v + L) ~/ (L + 1) = S_c + D` exactly, because `0 <= L - D <= L` for every way (a way
   cannot delete more characters than the input has). So the comparison is exact for every way, the recount and
   both thresholds go, and the results are identical to z64 on every row: z64 never reached the region where 32
   was too small on any test, so the constants bought nothing measurable but were a defect waiting for a long
   input. (Proved for the formula; identical results measured.) The value stays far below 2^63 for any input
   that fits in memory.
2. **The cheapest sound overflow recovery is a new parser.** N8 replaced z63's unsound in-place reset with an
   advanced memo version, which is sound but writes library state from the engine. A new `Parser` per attempt
   discards everything the failed attempt touched, by construction, with no library field written. It costs a
   memo rebuild only on inputs that overflowed, which z62 already made rare (the sweep runs only after an
   overflow), so speed is unchanged on every row and the overflow test gives z64's costs 0/0/1.
3. **A memo of a pure function never needs clearing inside its domain.** `_mins[m]` is the score of match `m`, a
   function of `m`'s subtree and the input length only, both fixed during one `recover`. Clearing it before every
   rung or recheck run threw away correct entries; dropping the three clears changed no output. It is not free:
   rg2-12 costs +4% instructions (L and T unchanged), inferred to be the larger map's lookups. (Soundness proved
   from the code: `_ev` reads only `m`, its children and `_len`.)
4. **Caching every query is slower than caching the shared ones.** `_sc` reads `_mins` but does not write it;
   routing it through the caching `_ev` (vs5a) fills the map with matches queried once, 3-24% slower. Likewise
   `_end`'s direct terminal tests (`Char`, `Str`, `CharSet` with `_hit`) avoid `parser.match`'s memo lookup on
   the hottest call; removing them (vs5b) is 5-33% slower. Both are speed code, not dead code. (Measured; the
   causes are inferred from where the instructions go, not profiled.)
5. **Shorter code can allocate more.** The one-line `_flat` always builds a new list; the old one returned its
   argument unchanged when there was no `Seq` to flatten. That is the inferred cause of +4.6% (L) and +3% (T) at
   k = 16384. It saves 5 formatted lines, and size ranks above speed, so it stays; restoring the early return is
   the knob if the speed matters more.
6. **`_noIns` buys tfam accuracy only by widening the search.** Replacing "pure substitution" by "inserted
   nothing" lets lone deletions count as clean at the `_pureSub` sites, which brings tfam excess 14 -> 1, but the
   test then admits many more ways per cell: 6.5x on tfam and 233x on rg1-24. Every single-site version found
   (noins_a-d, b1-b3, g) either kept the excess or kept the blow-up. The tfam excess is a search-width problem,
   not a classification problem.
7. **The recheck constants are speed constants.** Collapsing the recheck to one rule (always cost mode at
   c - 1, vs4b) or to vgn7c's rule (rc7c) changes no accuracy row but costs up to 47x on cbc8: the `r > 8`,
   `c * 3 < 2 L` and budget-4 branch exists to skip a cost-mode run that cannot pay for itself on cyclic grammars
   with many errors. They remain fitted (12.65) and are the largest open item.
8. **Wall-clock timing checks under heavy load mislead in both directions.** Between check.sh runs, vm13b's
   own time on one input moved about 5x; z65's run flagged different rows from z64's (dense, validity, semi, tfam,
   rg2 against rg1, rg2).
   Instruction counts of the whole flagged parts (dense, val, semi, tfam) were 0.995-1.034x with identical output.
   Judge speed by interleaved instruction counts, never by one timed run.

**Open.** The recheck constants (`r > 8`, `c * 3 < 2 L`, budget 4, `_len * c < 2048`); the tfam excess (14 on
the T family); held-out 2/0/1 above z37a (unchanged since z64, cause not found, not reproduced on f3n); the
packed `_mins` score arguably counts as one more field; the overflow test is still not in kit/check.sh.
