<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.62 Neon round N5: z59, `synced` without `evidence` and one visit order

**Result.** z59 = vgn5, Gemini's round-N5 engine (model gemini-4-neon-high), taken unchanged. Beside z58: `synced` no
longer reads `evidence` (on grammars without wildcards, `2 * evidence > end - a - spent + 1` equals `(end - a - spent) +
2 * I > 1` with I the insertions before the end, and vgn5 counts those insertions in `piece` only when `end - a - spent <
2`); `_seq`'s skip-ahead now tests `_takes` on the previous slot, which lets `_seq` visit its prefixes in reverse on every
rung (the `g > 0 && g <= 2` condition and its constant are gone); `canS` is written with one shared term; three
conditions are shortened by proved identities. Fields 8 -> 8, bookkeeping lines (bkl.sh) 14 -> 13, 483 -> 492 formatted
LOC (+9, +1.9%); battery 0.9902/86.5, priceWorse 0/0, pdls4/plfs4 worse 121/81 and every other accuracy row equal to
z58; fresh f3a 0/0/0; held-out one g5 input 1 above z37a (z58 0); LR fuzzer 0 worse of 2,300; Dyck 0.89x z58 on three
interleaved repeats. A SLOW FAIL in the first suite run (dense cbc k = 6-8, semi3 #30, rg2 #14) did not reproduce when
re-run interleaved with z58 and vm13b.

| Engine | Change from z58 | Fields | bkl | floc | Answers vs z58 | Verdict |
|---|---|---|---|---|---|---|
| **vgn5 = z59** | **`synced` without `evidence`, `_takes` on skip-ahead, reverse order on every rung, shorter conditions** | **8** | **13** | **492** | **equal; held-out g5 +1** | **chosen** |
| vgn5t3 | skip-ahead `_takes` and one visit order only | 8 | 14 | 485 | equal | ranked below vgn5 (bkl) |
| vgn5u11 | no `used` (derived from `piece` in local modes) | 7 | 13 | 524 | T (1+ times out at k >= 256 | rejected |
| vgn5u9 | no `used`, no gap-0 pure-substitution settle | 7 | 12 | 519 | T (1+ 65/257/1025 vs 49/193/769 | rejected |
| vgn5m2 | mark set at convergence, no `x.mark = -1` | 8 | 13 | 483 | battery JSON and tfam time out | rejected |
| vgn5s1 | `synced` as `end - a - spent > 1` | 8 | 13 | 485 | fresh f3a 2/4/0 above | rejected |
| vgn5h1, vgn5h2 | vgn5 with z58's visit order (orchestrator) | 8 | 13 | 492 | equal prices; tfam witness check > 120 s | rejected (time) |

**What taught something.**
1. The visit-order constant of N4 (`g <= 2`) was hiding a validity bug: a skip-ahead way that a previous optional slot
   would steal from. Order only decided whether the invalid way won a tie. Fixing the way removed the need for two
   orders.
2. `used` equals `spent + _ex(owed)` throughout global cost mode (proved by induction), but not in local modes: one
   pure-substitution fragment needs two different values on `L (1+` and `T (1+`, so no function of the way's other
   fields can replace it while `_repeat` has no continuation tails.
3. The witness checker in _wit91.dart enumerates subsets of one-character error children to assign substitutions; its
   time is exponential in the error count and depends on the tree's grouping, so two engines with equal prices can
   differ by 100x in check time. This is a checker defect; dynamic programming over the slots would fix it.
