<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.54 Frontier series, round F5: z51, a recheck that reaches 0/0/16 on fresh inputs

**Result.** z51 = vmf5n: z50 with Gemini's recheck after the budget ladder, limited by one condition found in this round,
plus size cuts and two small changes from Claude and Codex. Beside z50: fields 12 -> 12, bookkeeping lines 35 -> 35, 462 ->
456 formatted LOC (-6, -1.3%); priceWorse 10/6, battery 0.9900/86.3 and exhaustive 0 equal; fresh inputs above z37a
(g1/g3/g5 of 480) 0/2/62 -> 0/0/16, held-out seed 0/2/58 -> 0/2/25; fresh time beside z50 0.90/0.59/1.09x and
1.00/0.57/0.99x.

The recheck (c = first-pass cost, r = c - 1, l = `_Way.maxOwed > 2 || c * 3 < _len * 2`):
```
b = r > 8 && g == 0 && l ? 4 : r;          // starting budget
if (_len * c < (l ? 1600 : 1024)) { g = r > 8 && l ? 0 : r; reset; best = run(b); }
```
z50 had bound 1024, mode g = r and start r.

| Engine | Change from z50 | Fresh f3a | Held-out f3b | Time checks | Verdict |
|---|---|---|---|---|---|
| vmf4b = z50 | | 0/2/62 | 0/2/58 | pass | base |
| vcf5f (Claude) | fallback factor `cs.length + 1`, size cuts | 0/2/62 | | pass | parts kept |
| vxf5v (Codex) | budget `rung - p` after a deleted prefix, coverage by `edits` | 0/2/62 | | pass | parts kept |
| vgf5 (Gemini) | the recheck above with mode `r > 8 ? 0 : r` | 0/0/16 | | rg2 fails | recheck kept, mode limited |
| vmf5g | mode g = r | 0/0/42 | | | rejected |
| vmf5f | bound 1024 | 0/2/61 | | | rejected |
| vmf5j | start r | 0/0/16 | 0/0/25 | dense, tfam, rg1, rg2 fail | rejected |
| vmf5k | start 4 for every r > 8 | 3/39/107 | 4/29/100 | pass | rejected |
| **vmf5n = z51** | **mode 0 only when l** | **0/0/16** | **0/2/25** | **pass** | **chosen** |

**What taught something.**
1. The fresh gain comes from the rerun mode, not the bound: rerunning in mode 0 (the `rem(rung)` mode) instead of the
   prefix-skip mode g = r turns 0/0/42 into 0/0/16 at the same bound. The bound 1600 adds the two g3 inputs.
2. A mode-0 rerun at the full budget r is slow on short inputs with dense errors and short rules (rg2 input 11, `(xyzd)` six
   times: 329 ms against vm13b 10 ms; the dense family `cbcaccbccab` 2-4 s). Starting at budget 4 fixes the dense family; the
   rg2 input needs the mode-0 rerun limited to `l` true, where it was never needed for accuracy.
3. A near-limit time check can pass once by chance. vmf5d passed rg2 on its first suite and fails it on every rerun; and the
   `big` input `L (1+` sits at 0.9-1.4x vm13b for z50 and z51 alike, so one `big` run can fail either. Rerun a near-limit
   input alone and interleaved before calling a check passed or failed.
4. The numbers 1600, 1024, 4, 8 and the ratio 3/2 in the recheck are measured, not derived. They are the main elegance debt.
