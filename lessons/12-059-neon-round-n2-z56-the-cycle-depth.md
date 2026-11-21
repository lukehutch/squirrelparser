<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.59 Neon round N2: z56, the cycle depth returned by value

**Result.** z56 = vmn2a, the orchestrator's merge of Gemini's round-N2 engine vgn2 (model gemini-4-neon-high) without
its `_tails` scan: the cycle depth is returned by value (`(List<_Way>, int)` from `_read`, `_propose`, `_seq` and
`_repeat`, with a read-only clause stack carrying the semi-naive delta), which removes `_Cell.dep`; and two accuracy
changes (`_repeat` settles only at `g <= 0`; `_seq`'s substitution condition simplified). Beside z55: fields 9 -> 8,
bookkeeping lines (bkl.sh) 29 -> 18, 450 -> 508 formatted LOC (+58, +12.9%); battery 0.9901/86.3 -> 0.9902/86.4, pdls4
worse 122 -> 121, tfam excess 30 -> 24, priceWorse 0/0, every other accuracy row equal; fresh f3a 0/0/0 and held-out
equal to z55; LR fuzzer 0 worse of 2,300; Dyck three interleaved repeats 16.2 s -> 14.4 s (0.89x; z37a 24.4 s).

| Engine | Change from z55 | Fields | bkl | floc | Answers vs z55 | Long-token LR k=64 | Verdict |
|---|---|---|---|---|---|---|---|
| vgn2 (Gemini) | depth by value; `_tails` scan for the `(c, p)` key kind; settle and rSub changes | 7 | 18 | 505 | same as vmn2a | 5.7-8.5 s vs 0.8-1.4 s | rejected: quadratic LR tails |
| vgn2a (Gemini) | depth by value only | 8 | 18 | 505 | equal | 2.3 s vs 2.4 s | runner-up |
| **vmn2a = z56** | **vgn2a + settle and rSub changes** | **8** | **18** | **508** | **battery +1 perfect, tfam excess -6** | **2.1 s vs 2.4 s** | **chosen** |

**What taught something.**
1. A value that one recursive call computes and an outer call reads can travel back through the return value: the
   cycle depth needed neither a field nor a box (N1-1), only a second component in what each reading function returns.
2. Rebuilding stored state by scanning a bounded window of positions trades a key kind for a factor of the window
   width: on long tokens the window is as long as the input, and the scan turns linear work quadratic. A field removal
   must be checked on the input family that made the field necessary.
3. For the second round in a row Gemini found and reported the counterexample to its own submitted engine. Its reports
   are reliable on measured facts; its choice of what to submit is not.
