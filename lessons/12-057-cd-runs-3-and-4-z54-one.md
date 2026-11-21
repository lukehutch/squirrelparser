<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.57 CD runs 3 and 4: z54, one field fewer, and a counter the search learned to fool

**Result.** z54 = v4b, built from CD (computational discovery) runs 3 and 4 by hand merging and ablation. The run-3 merge
v3m1 (never committed): vcd44 (z53 minus static `_Way.len`) + c5 (`_Cell.fresh` gone, the fresh list kept in the ends of
the `(c, p)` cell) + c36 (recheck `c > 1`, bound `(l ? 2048 : 1024) + _len * 4`, cost-mode rerun) + c79 (fallback seeds the
empty-edit start). z54 adds three changes from run 4's top candidate c377: the empty-edit start at `_len <= 12` (was 4),
a fallback alphabet of the span ends plus the input's own characters (was one past each span end), and no substitution of
a character by itself. Beside z53: fields 10 -> 9, bookkeeping lines (hand) 32 -> 30, 438 -> 454 formatted LOC (+16,
+3.7%; v3m1 450); priceWorse 10/6 -> 0/0, worse 132/93 (v3m1) -> 122/83, battery 0.9901/86.3, tfam 3/30, every checkF7
part passes under the same load as v3m1; fresh f3a and held-out f3c answers equal to v3m1. Cost: Dyck 4.4 s (v3m1) ->
8.3 s, below z37a's 11.1 s.

**Runs 1 and 2 (before run 3).** Run 1 (2026-11-12, started from z53 = vmf7a, stopped after about 7.5 h, 172
candidates) found nothing better than z53. Its top candidates either deleted the `_mins` cache (one field fewer, `big`
inputs 5-14x slower than vm13b, confirmed locally) or packed several fields into one int with shifts and masks, which
lowers the field count without removing any state; others did not compile. Its score gave partial credit (0.01 times the
fraction of hard checks passed) to engines that failed a hard check, and that credit rewarded the `_mins` deletion. Run 2
scored any hard failure 0 and added a check against bit packing (no shift of 16 or more, no mask of 20 or more one bits
outside a constant), with a field counter that counts a getter unpacking bits as a field. It ran 4 h (77 candidates, 72
finished); 60 of its 70 zero scores deleted `_mins` again (25 over the deadline, 26 failed checks, 19 compile errors),
although the brief said the cache is needed. Its only gain, c44 (vcd44), removed the static `_Way.len` (the end-of-input
mismatch way gets a `prev`, and `owed` is `prev?.edits ?? 0`) and moved `rules` and `topRuleName` into `parser`, a
rename the CD counter rewarded. By hand: fields 10 = 10, bookkeeping lines 32 = 32, floc 438 -> 439, priceWorse 10/6 ->
9/6, battery 0.9900/86.3, fresh f3a 0/0/0, 5-14% faster than vmf7a. vcd44 was the start of run 3.

| Engine | Change from v3m1 | floc | priceWorse | pfam 14/15 | tfam | Dyck ms (v3m1) | checkF7 | Verdict |
|---|---|---|---|---|---|---|---|---|
| v3m1 | | 450 | 3/4 | 275/271 | 3/30 | 4.6 k | pass | base |
| v4a | c377's four changes | 454 | 0/0 | 252/264 | 0/0 | 10-15 k | SLOW tfam, rg1, rg2; big | rejected |
| v4d | v4b + recheck `_len <= 100` | 454 | 0/0 | 252/264 | 0/0 | 8.5 k | SLOW tfam, rg1, rg2 | rejected |
| **v4b = z54** | **start `_len <= 12`, alphabet, no self-substitution** | **454** | **0/0** | **252/264** | **3/30** | **8.7 k** | **pass** | **chosen** |

**What taught something.**
1. A search scored by a field counter optimizes the counter. All of run 4's field and line reductions (top candidate:
   fields 8, bookkeeping lines 8, against 9 and 35) were hiding, not removal: getters and setters wrapping each field so
   that call sites stop naming it, `maxOwed` moved to the class the counter skips, and the two key kinds of `_cells`
   merged into one by negating the position (`(c, -1 - p)`, `(c, ~p)`). The counter must count accessor bodies as uses,
   count statics moved out of `_Way`, and treat a negated key as a second key kind before any further run.
2. The logic changes inside the gamed candidate were real, and only ablation found which mattered: the recheck on short
   inputs gives the whole tfam gain and fails the time limits; the empty-edit start gives the fuzzer and price-family
   gains (fuzzer at threshold 12 or more, price families from 8), with Dyck time rising steeply with the threshold
   (6: 1.1-1.2x, 8: 1.3-1.7x, 12: 2.7-3.3x, 15: 4-5x v3m1 in one interleaved run); the alphabet change alters no answer
   but halves Dyck time at the higher threshold; the self-substitution skip alters no answer.
3. Partial credit for an engine that fails a hard check is rewarded and repeated (run 1); the score must be 0 on any
   hard failure. A sentence in the brief saying a part is needed did not stop the search from deleting it (run 2): only
   the score did.
4. A slowdown seen in a suite is real only when the reference engine run under the same load passes: v3m1 passed every
   part of checkF7 at load 60 while v4a failed SLOW by up to 4.7x.
