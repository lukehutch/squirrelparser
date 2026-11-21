<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.52 Frontier series, round F3: z49, one field fewer, the fresh-input loss mostly recovered

**Result.** z49 = vgf3b20: Gemini's vgf3b (the clause key kind of `_mins` removed, `_cap` and `_floor` removed, a recheck bounded
by `_len * cost` instead of the fixed range 3..9, a fallback limit that grows with the input and the character classes, dirty
ways visited first when g == 1) with the recheck bound lowered from `_never >> 19` (2048) to `_never >> 20` (1024). Beside z48:
fields 13 -> 12, bookkeeping lines 35 -> 35, 460 -> 463 formatted LOC (+3, +0.7%), priceWorse 11/10 -> 10/6 (z37a 11/9),
exhaustive 0, battery 0.9898/86.0 -> 0.9900/86.3. Fresh inputs (480 per grammar, above z37a on g1/g3/g5): seed 20261102
3/50/108 -> 0/2/62, held-out seed 20261103 4/39/100 -> 0/2/58 (z47 0/0/92 and 2/0/82). Time, engines interleaved on a machine
at load 40-76: battery 0.95x vm13b (z48 0.77x), fresh 0.69/0.48/1.10x z47.

| Engine | Fields | priceWorse | Battery | Fresh 02 | Held-out 03 | Fresh time g5 / z47 | Verdict |
|---|---|---|---|---|---|---|---|
| z47 (vmf1d) | 15 | 21/13 | 0.9896/85.1 | 0/0/92 | 2/0/82 | 1 | |
| z48 (vmf2a) | 13 | 11/10 | 0.9898/86.0 | 3/50/108 | 4/39/100 | | base |
| vcf3z | 14 | 12/10 | 0.9898/86.0 | 0/0/92 | 2/0/82 | 0.94 | more fields |
| vgf3 | 12 | 11/8 | 0.9898/86.0 | 0/0/47 | 0/0/51 | 2.23 | too slow |
| vgf3b | 12 | 10/6 | 0.9900/86.3 | 0/0/47 | 0/0/51 | 2.17 | too slow |
| vgf3w | 13 | 11/8 | 0.9898/86.0 | 0/0/0 | 0/0/0 | | dense 80 s, rejected |
| vgf3b21 (bound 512) | 12 | | | 0/29/94 | | 0.68 | rejected |
| **vgf3b20 = z49** | **12** | **10/6** | **0.9900/86.3** | **0/2/62** | **0/2/58** | **1.10** | **chosen** |

**What taught something.**
1. The fresh-input loss of z48 and its cure are one parameter: the recheck reruns the search one cost lower, and its limit on
   `len * cost` sets both how many losses it recovers and the time. On g5, 2048 recovers 65 inputs at 2.2x z47's time, 1024
   recovers about 50 at 1.1x, 512 almost none. Every recovered input lies below `len * cost` = 1280.
2. Fresh time must be measured with the engines interleaved per input file (`kit/fresh/ftime.sh`): on a loaded machine separate
   runs differed by 1.6x for the same engine.
3. Correction to 12.50 and 12.51: z47 failed `big` on `L 1+)` k=16384 in round F1 (1161 ms against 560; the log says FAIL) and
   z48 passed by 32 ms. Both run that input at about 1.9x vm13b; under load all of z47, z48 and z49 fail it. The cause is open.
4. Removing the clause cache of `_min0` (one key kind fewer) cost no measured time on big, battery or fresh inputs.
