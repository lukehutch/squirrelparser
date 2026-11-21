<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.23 Round 76: z19 leaned on its fallback; a doubted repair and a bounded exact search (z20); local cells keyed by the last edit (z21)

**Correction to 12.22.** z19's "0 exhaustive misses" and "linear on all probes" both depended
on its fallback: when the loose search's answer failed the check, z19 ran the exact search
with no work bound, and that search is exponential in the error count. Without it z19 is not
exact on the exhaustive set; with it z19 is not linear.

**Is the check and the fallback necessary?** Measured, each part in turn:

- The check (parse the repaired string) is necessary and cheap: without it, local mode returns
  invalid trees, and it costs one parse of the repaired string.
- The fallback is necessary: z20u, with no fallback, misses on the exhaustive set (refuted).
- The fallback must be bounded: unbounded, it is exponential (above).

z20 keeps all three but changes what triggers the fallback and how far it may run. The loose
search keeps the best checked repair (`_checked`) and sets `_doubt` when an unchecked way was
cheaper than it. Only a doubted repair goes to the exact search, which is given the checked
repair's price as a ceiling and `_exactPer = 16` times the loose search's work limit. Every
answer is labeled with its path: `plain` (input valid), `checked`, `exact` (the exact search
found a cheaper one), `proved` (it ran to the ceiling and found none), `bounded` (it hit its
work limit; the checked repair is returned), `none`, `unchecked` (stack overflow).

**Expression probes break local mode.** On `S <- E; E <- T ('+' T)*; T <- '(' E ')' / [0-9];`
with the input `(1+` or `1+)` repeated k times, z20e takes 1.4 / 10.0 / 78.6 s at
k = 16 / 32 / 64 (`(1+`) and 1.2 / 75 s at k = 16 / 32 (`1+)`). Per-rung traces (instrumented
copy z20p): the blowup is all in local mode. A local cell kept one way per (key with `first`,
used, owed), so ways grow as n times the rung; and on `1+)` no way ever syncs, since `synced`
needs `end > last + 1` and evidence of more than one character past the absorbed ones, and
each repeat offers only the `1` after a deleted `)`. Loosening the sync (z20n) lets a way
delete without bound, which is n squared by construction, and made costs worse (95 vs 64).

**Variants of the local cell** (all on z20e; probe times at k = 16 / 32 / 64 / 128):

| Variant | Change | `(1+` | `1+)` | LR `E <- E '+' T / T`, `(1+` | Verdict |
|---|---|---|---|---|---|
| z20e | - | 1.4 / 10.0 / 78.6 s / - | 1.2 / 75 s | 17 / 49 / 172 / 1,210 ms, costs 17-129 | base |
| z20k | `first` out of the key, all modes | 3.6x faster, still 7x per doubling | unchanged | 4x slower | dropped |
| z20l | local dominance ignores used | - | - | - | 4,083 ways at k = 64 |
| z20m | z20l + z20k | 2.2 s at 64, 8.3 s at 256 | 32.8 s at 64 | - | dropped |
| z20n | z20m + looser sync in local mode | - | cost 95 vs 64 | - | refuted |
| z20q | z20l + `first` out of the local key | 0.12 / 0.52 / 2.97 / 15.6 s | 0.18 / 2.6 / 41.5 s | 190 / 1,360 / 10,890 / 93,782 ms, costs 13-97 | LR regression |
| z20y, z20z | z20q + dominance on used (and spent) in local mode | about z20q | about z20q | 88 / 85 s at 128 | no help |
| z21a, z21b | z20q, z20y + a clean/dirty bit in the local key | = z20q | = z20q | = z20q | no help |
| z20r | z20e + at most 8 ways per local cell | 0.1-6.6 s, costs 44-380 | costs 3x | - | refuted |
| z20w | local mode under 16x the work limit | `none` from k = 16 | `none` | `none` from 64 | refuted |
| z21c | z20q with `last` (last edit) in the local key | 0.12 / 0.50 / 2.5 / 12.4 s | 0.18 / 2.5 / 37.3 s | 14 / 44 / 157 / 1,050 ms, costs 17-129 | adopted |

Why `last` and not `first`: two ways at one end, owed count and rung have the same future
except through `synced`, which reads `last`. With `first` dropped (z20q), merging can keep a
way that never syncs: on the LR probe z20q finds no answer until rung 32, where z20e answers at
rung 1 (traces with z20p and z20pq). With `last` in the key, LR is back to z20e's time.
z20q's costs on LR were lower (97 vs 129 at k = 128) because it ran to rung 32; z21c returns
z20e's costs.

**Prune ablations.** z20t (the `_sure` break deleted: later arms of a choice after an arm
that cannot fail) gives the same answers on every check, so it was removed (z20x, 613 -> 605
LOC). z20s (also the greedy-slot prune `_greedy`/`_takes`/`_head` deleted, 583 LOC) is 117
worse and 2x slower on the g3 long set, so that prune stays.

**z21 = z21c without `_sure`**, against z20x (z20e without `_sure`):

| | z20x | z21 |
|---|---|---|
| LOC | 605 (z19 572 -> 605, +33, +5.8%) | 605 (0 vs z20x) |
| Engine fields | z19's 20 + `_checked`, `_doubt`; constant `_exactPer` | same |
| Battery | 0.9904 / 86.5 | same trees (treeDiff 0, costDiff 0) |
| Gates | all pass | all pass |
| dl / lf invalid, timeouts, priceWorse | 0 / 0 | 0 / 0 |
| dl / lf levWorse | 1 / 0 | 0 / 0 |
| Exhaustive misses (41,524) | 0 | 0 |
| Long sets g1 / g3 / g5 (600 each), worse than the better | 1 / 0 / 0 | 3 / 0 / 1 (all by 1) |
| Long sets total ms | 2,748 / 3,185 / 876 | 2,627 / 3,070 / 803 |
| `(1+`, k = 64 / 256 | 65.7 s / - | 2.5 s / 9.4 s (cost 281) |
| `1+)`, k = 32 / 64 | 62.4 s / - | 2.5 s / 37.3 s |
| LR `(1+`, k = 128 / 256 | 1.1 s / 9.8 s | 1.05 s / 10.5 s |
| `bbbbcb` x4 (bounded) | 79.6 s, cost 10 | 0.8 s, cost 8 |
| `cbcaccbccab` x4 (bounded) | 9.9 s, cost 17 | 7.4 s, cost 39 |
| depth, `x (ax)*n b`, `x (ab)*n` (`deep.sh`) | linear | linear |

**Open.**
- Local mode has no work limit of its own, so dense errors are still superlinear (`1+)` about
  15x per doubling; LR about 10x per doubling from 128 to 256). The bounded doubting cases
  spend their time in local mode, not in the exact search (trace: local rung 8, 1.58 M work,
  8.6 s on `cbcaccbccab` x4).
- `cbcaccbccab` x4 costs 39 in z21 against 17 in z20x.
- Path counts per fuzzer were not recorded for z20 or z21 this round.
- The harness now lives in /home/luke/Work/squirrel-kit (dens5, ex2, pf.sh, deep.sh); the
  engine table is `_research18.dart` there, which has duplicate z20e entries to remove.
