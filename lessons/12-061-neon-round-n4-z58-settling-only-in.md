<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.61 Neon round N4: z58, settling only in local modes

**Result.** z58 = vgn4, Gemini's round-N4 engine (model gemini-4-neon-high), taken unchanged. Beside z57: a way is clean
when its piece is not a `Match`; `absorbed` is gone (`synced` is the same inequality written as `2 * evidence > end - a -
spent + 1`, and `_pureSub` no longer tests it); `_seq` settles `used` only in local modes, which removes `rSub`; `_seq`
visits its prefixes in reverse on both rungs of the global cost ladder (`g <= 2`, the ladder's own cap), not only on rung
1; and the recheck bound loses its `+ _len * 4` term. Fields 8 -> 8, bookkeeping lines (bkl.sh) 17 -> 14, 490 -> 483
formatted LOC (-7, -1.4%); battery 0.9902/86.4 -> 0.9902/86.5, priceWorse 0/1 -> 0/0 (the plfs4 case
`baacbcaabaabccaa` 5 -> 2, the optimum), pdls4/plfs4 worse 122/83 -> 121/81, every other accuracy row equal; fresh f3a
and held-out equal; LR fuzzer 0 worse of 2,300; Dyck 0.95x z57 and long tokens k=64 0.97x z57 on three interleaved
repeats.

| Engine | Change from z57 | Fields | bkl | floc | Answers vs z57 | Verdict |
|---|---|---|---|---|---|---|
| **vgn4 = z58** | **clean by piece type, no `absorbed`, local-only settle, reverse order at g <= 2, recheck without `+ _len * 4`** | **8** | **14** | **483** | **priceWorse 0/0, worse 121/81, battery 86.5** | **chosen** |
| vgn4d3 | vgn4 with `synced` as `evidence > 1` | 8 | 14 | 489 | worse 124/86 | rejected |
| vgn4e4 | reverse order in every g > 0 | 8 | 14 | 489 | fresh f3a g3 5 above | rejected |
| vgn4q2 | recheck without `g > 0 \|\|` | 8 | 14 | 489 | priceWorse 0/1 | rejected |
| vgn4b | no `inner` cell reset | 8 | 16 | 487 | battery JSON inputs time out | rejected |

**What taught something.**
1. The plfs4 case that cost z57 its coverage test was a tie between a valid and an invalid way of equal key; the order
   in which `_seq` visits its prefixes decides which one survives. Fixing the order fixed the case at no bookkeeping
   line, where the coverage test had kept both ways at one line.
2. Settling `used` in global cost mode was the source of the incomparable pairs the coverage test had to keep; with
   settling only in local modes, `used == spent + _ex(owed)` holds throughout cost mode (Gemini's argument, not proved).
3. A number that looks new can be an old one: `g <= 2` is the length of the global ladder, already fixed by `b > 2`.
