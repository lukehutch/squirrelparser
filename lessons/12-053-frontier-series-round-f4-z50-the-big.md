<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.53 Frontier series, round F4: z50, the `big` slowdown found and removed, a start-rule crash fixed

**Result.** z50 = vmf4b: z49 with three changes from the three agents. Claude: `_Cell.add` finds the insertion point by binary
search on `end` instead of a backward linear scan. Gemini: `_read` no longer re-adds a memoized cell's old ways during a delta
pass (`cell.fresh ?? (delta ? all ?? const [] : cell.ends)`). Codex: the start-rule minimum is read from `parser.rules`, so a
start rule with a transparent name (`~S`) no longer crashes with a null check. Beside z49: fields 12 -> 12, bookkeeping lines
35 -> 35, 463 -> 462 formatted LOC (-1, -0.2%); every accuracy number equal (priceWorse 10/6, battery 0.9900/86.3,
exhaustive 0, fresh 0/2/62, held-out 0/2/58, the same price on all 2,880 fresh inputs); `big` `L 1+)` k=16384 from 1.9x vm13b
to about 1.0x (1170-1306 ms against 1208-1449, alternated), and `big` passes on all 10 inputs.

| Engine | Change from z49 | priceWorse | Big | Fresh | Verdict |
|---|---|---|---|---|---|
| z49 (vgf3b20) | | 10/6 | fails `L 1+)` 16384 (2065 vs 885) | 0/2/62 | base |
| vmf4a | delta fix only | | fails 7 of 10 | | rejected |
| vcf4w3 (Claude) | binary search | 10/6 | 1181-1332 vs 1208-1449 | 0/2/62 | crashes on `~S` |
| vxf4k (Codex) | binary search, no g == 1 reordering, `parser.rules` | 11/8 | passes | 0/2/62 | loses 10/6 |
| vgf4 (Gemini) | delta fix, reordering at every g, derived limits | | no answer 10 of 10 | | dense > 120 s, Dyck 146 |
| **vmf4b = z50** | **all three fixes** | **10/6** | **passes** | **0/2/62** | **chosen** |

**What taught something.**
1. The cause of the `big` slowdown that z47 to z49 shared (12.52 item 3) is the backward linear scan in `_Cell.add`, which
   vm13b avoided with its `_at` index and z47 removed. A binary search on the sorted `ends` list restores the speed with no
   field. Gemini's explanation (re-adds in `_read`) was tested by applying only that fix: it does not cure the slowdown.
   Test a claimed cause by applying that fix alone.
2. Two checks were missing from the kit: a start rule with a transparent name, and `big` under the F3 load. Codex's `_f4api`
   driver now covers the first.
3. The g == 1 reordering, the recheck bound and the fallback limit `* 16` are each needed for the 10/6 record or the fresh
   numbers, but by measurement only (without the reordering 11/8; without `* 16` 12/8; reordering at every g puts 271 g3
   fresh inputs above z37a). No derivation was found.
4. 0/0/47 on fresh inputs within 1.25x time is still not reached: bound 2048 costs 2.0x on g5, a local g = 0 recheck gives
   0/0/0 at 1.4-2x.
