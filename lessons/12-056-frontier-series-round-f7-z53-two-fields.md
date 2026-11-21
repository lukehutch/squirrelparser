<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.56 Frontier series, round F7: z53, two fields fewer and a guard that only lost answers

**Result.** z53 = vmf7a: z52 with Gemini's removal of the per-position key kind of `_cells` and of the stamp packed into
`mark`, Claude's removal of the `_never >> 18` guard in `_Cell.add`, and Codex's one-line terminal test. Beside z52:
fields 12 -> 10, bookkeeping lines 33 -> 32, 447 -> 438 formatted LOC (-9, -2.0%); priceWorse 10/6, battery
0.9900/86.3, exhaustive 0, tfam 3/30, fresh f3a 0/0/0 and the held-out set all equal; bat 0.74x vm13b, big within the
limits on three interleaved repeats. On Claude's T stress set (200 random inputs on `S <- T+; T <- '(' T* 'a' 'b' 'c' ')'
/ 'z';`) inputs above the exact optimum 25 -> 7, none more expensive.

| Engine | Change from z52 | floc | fields | bkl | Checks | Verdict |
|---|---|---|---|---|---|---|
| vmf6e = z52 | | 447 | 12 | 33 | | base |
| vcf7t (Claude) | `_never >> 18` guard removed | 444 | 12 | 33 | equal; T stress 25 -> 7 | kept |
| vxf7o (Codex) | terminal test as `indexed.every` | 447 | 12 | 33 | equal | kept |
| vgf7 (Gemini) | `int p` key kind and stamp removed, cells of a pass reset by list | 439 | 10 | 32 | equal | kept |
| vgf7a (Gemini) | one key kind (MemoEntry) for `_cells` | 444 | 10 | 34 | equal where finished | rejected |
| **vmf7a = z53** | **vgf7 + vcf7t + vxf7o** | **438** | **10** | **32** | **equal** | **chosen** |

**What taught something.**
1. A field that records *when* a cell was written (a stamp per position) can be replaced by resetting the cells the pass
   touched, which the pass already knows. The stamp was bookkeeping for a question the control flow answers.
2. A size guard that throws is a hidden price rule: it ran only on wide cells and only ever threw away cheaper answers.
   The suite and the fresh sets did not show it; a stress set built to make wide cells did. Build the input that makes a
   guard fire before deciding it is harmless.
3. Merging key kinds into one map does not reduce fields when a stored value then needs two meanings (vgf7a) or new
   fields to tell the kinds apart (vxf7n).
4. Every engine in the round gave the same counts on the fresh and held-out sets; the T stress set was the only test that
   separated them. The fresh sets no longer measure the remaining differences.
