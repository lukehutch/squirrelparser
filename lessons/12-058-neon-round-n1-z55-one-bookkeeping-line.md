<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.58 Neon round N1: z55, one bookkeeping line fewer and a faster fallback

**Result.** z55 = vmn1b, the orchestrator's merge of three changes from Gemini's round-N1 engine vgn1 (model
gemini-4-neon-high) onto z54: the recheck's dead branch removed (`b <= r` always holds, so the recheck is `run(b)`); a
fallback search that starts within the parse frontier of the input, skips the frontier scan and the queue at the last
depth, and generates neighbors lazily with an early exit; and `_repeat`'s settle test written as `(syncs(w) || !any) &&
w.synced(r.end, -1)`. Beside z54: fields 9 -> 9, bookkeeping lines (bkl.sh) 33 -> 32, 454 -> 450 formatted LOC (-4,
-0.9%); battery 0.9901/86.3, pdls4/plfs4 priceWorse 0/0, tfam 3/30, pfam 252/264, every other accuracy row equal;
fresh f3a 0/0/0; Dyck three interleaved repeats 23.4 s -> 19.0 s (0.81x; z37a 25.5 s), 0 more expensive.

| Engine | Change from v4b | Fields | bkl | floc | Answers vs v4b | Dyck (v4b 23.4 s) | Verdict |
|---|---|---|---|---|---|---|---|
| vgn1 (Gemini) | `dep` -> `ac` + box `cy`; `_mins` -> depth-2 `_sub`; N1-3/4/5 | 8 (claimed 7) | - | 498 | LR fuzzer 1 worse | 0.71x (Gemini's run) | rejected: box is a field, depth 2 inexact |
| vgn1a (Gemini) | `dep` -> `ac` + box `cy`, `_mins` kept | 9 (claimed 8) | - | 469 | equal | - | no gain |
| vmn1a | N1-3, N1-4 | 9 | 33 | 450 | equal | 19.1 s | runner-up |
| **vmn1b = z55** | **vmn1a + settle via `synced`** | **9** | **32** | **450** | **one f_n1 input 15 vs 14; held-out one cheaper** | **19.0 s** | **chosen** |

**What taught something.**
1. A one-element list passed by parameter through every recursive call is a field in a box: it has one value per run,
   written in one call and read in another. Removing a field means the information flows through return values or the
   call stack, not through a shared mutable cell.
2. A check limited to depth 2 of a tree replaces an exact walk only when a proof says nothing deeper can matter. Gemini
   proved the opposite (a deletion under two substitutions passes falsely) and submitted the engine anyway; a fuzzer
   built for that shape found the input within 2,300 cases.
3. The fallback's frontier start is exact by a short argument: the parser never reads past the farthest position it
   inspected, so a minimal repair has an edit at or before it. Exact pruning of this kind cut a fifth of Dyck time with
   no answer changed.
4. A single run's time failures under load mean nothing unless the reference engine passes in the same run: v4b failed
   all three big repeats that once looked like a vgn1 regression.
