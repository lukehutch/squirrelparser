<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.3 Round 63: z9's validity checks deleted where the check makes them redundant

Each check was switched off alone in a copy (`ABL=` in `z10x.dart`, scratch), and measured on
the battery and on dl/lf seeds 1-8 (`worse`, and the number of answers that fell back to f25's
search, "exact"):

| Switched off | battery | dl worse / exact | lf worse / exact | other effect | verdict |
|---|---|---|---|---|---|
| none | 0.9904 | 50 / 16 | 60 / 25 | | baseline |
| `_steals` | 0.9904 | 39 / 43 | 51 / 43 | | delete |
| `_tails` | 0.9904 | 37 / 39 | 52 / 39 | x(ax)*1600b 1,253 -> 99 ms | delete |
| `_covers` | 0.9904 | 49 / 18 | 58 / 32 | | delete |
| lrNullRep | 0.9904 | 36 / 22 | 55 / 27 | | delete |
| `_startsClean` | 0.9902 | 49 / 16 | 60 / 25 | rung 16: 0.25 -> 16.9 s, 0.92 GB | keep |
| `pen` | 0.9908 | 47 / 16 | 56 / 25 | b2 fails | keep (D8) |
| probe in `_plain` | 0.9904 | 50 / 16 | 97 / 38 | | keep |
| Ref filter in `_read` | 0.9902 / 85.5% | 50 / 16 | 60 / 25 | | keep |
| `adv` | 0.9900 | 49 / 16 | 59 / 25 | | keep |

The checks that prune invalid trees cost answers (inferred from the worse counts: with the
check in place, a pruned candidate was often the best valid one). `_startsClean` is a speed check, not a validity check, and `pen`
is the b2 gate's check.

z10 after deleting `_steals`, `_tails`, `_covers`, lrNullRep and their helpers (`_m1`,
`_matchesOne`, `_head`, the `seen`/`priors` sets in `First`):

| Measure | z10 round 62 | z10 round 63 |
|---|---|---|
| battery | 0.9904 / 86.6% | same trees (treeDiff 0, costDiff 0) |
| gates | pass | pass (cx2 b1 b2, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3) |
| dl seeds 1-16: worse / invalid / levWorse | 103 / 0 / 80 | 80 / 0 / 66 |
| lf seeds 1-16: worse / invalid / levWorse | 112 / 0 / 62 | 94 / 0 / 48 |
| rungs 8/16/32/64, AOT, ms (one build, both run in round 63) | 274 / 242 / 319 / 351 | 256 / 251 / 317 / 345 |
| deep.sh depth 3,200 missing 1 | 278 ms | 247 ms |
| x(ax)*1600 b / x(ab)*1600 | 1,253 / 75 ms | 99 / 77 ms |
| LOC | 483 | 392 (-91, -18.8%) |

z10 + `_f25k` is 392 + 727 = 1,119 LOC against z9's 448.

Paths on the deep inputs: nesting 800 and 3,200 with one `]` missing and x(ax)*1600 b are
answered unchecked (f25's interpreter overflows the stack); nesting 400 and x(ax)*n b for
n <= 800 are checked.
