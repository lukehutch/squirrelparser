<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.22 Round 75: cross-review round 4, an exhaustive price check, and a work limit on cost mode (z19)

**The price, not `lastCost`.** `lastCost` is `spent + owed`, an edit count. The price that the
fuzzers compare is the minimum `_price(input, witness, cap)` over the valid witnesses of the
tree (`_pdl.dart`). A first harness that printed `lastCost` reported false misses; every number
below uses `_price`.

**Exhaustive check.** Every input up to a fixed length, priced by z19's candidates and by the
exact search xrefmz. Grammars: g1 `S <- A; A <- 'x' ('a' A)*;`, g2 `S <- 'x' ('a' 'b')*;`,
g3 `S <- E*; E <- 'x'? 'x' 'a'? 'b';`, g4 `S <- ('x' 'a')* / 'b'+ 'x';` (all strings over
{x, a, b} of length 1 to 8, 9,840 inputs each), and g5
`S <- A 'q' / 'x' "zzz" ('a' / 'b')* 'q'; A <- 'x' ('a' A)*;` (all strings over {x, a, b, q}
of length 1 to 7, 21,844 inputs). Inputs priced above xrefmz:

| Engine | g1 | g2 | g3 | g4 | g5 |
|---|---|---|---|---|---|
| z19a (Codex sol10 + sol7's cut line) | 53 | 0 | 13 | 0 | 955 |
| z19b (z19a + fixes A, B, D, F, I, J below) | 53 | 0 | 22 | 0 | 955 |
| z19bnc (z19b, cost mode only, no cap) | 0 | - | 0 | - | 0 |
| z19e (z19b + leading deletion in local mode) | 44 | - | 48 | - | 904 |
| z19w, limit 64·rules·(n+1), no floor | 27 | 0 | 0 | 0 | 698 |
| z19 (z19w, limit 4,096 + 4·rules·(n+1), rungs up to 2 exempt) | 0 | 0 | 0 | 0 | 0 |

Every miss comes from local mode: cost mode alone (z19bnc) is exact on all 41,524 inputs. The
fuzzers do not show this: z19b has priceWorse 0 / 0 on dl / lf, against 1,030 exhaustive
misses. Example: g5 `aqaa` costs 3 by xrefmz and 4 by z19b. The family
`x (ab)^k q` on g5 costs 3 by xrefmz and k by z19a, z19b and c4arg7 (computed for k = 6 and 10).

**Cost mode is O(n·f(k)), not linear.** Measured on z19bnc, which is cost mode alone:

| Input | n or k = 10 | 20 | 40 | 50 | 100 |
|---|---|---|---|---|---|
| `x (ab)^k` (k errors), ms | 38 | 369 | 6,599 | 11,301 | about 200,000 |

With 3 errors and growing length (`x (ax)^n bbab`), it is linear: 273 / 1,008 / 4,457 ms at
n = 1,000 / 4,000 / 16,000. A per-rung trace (cells, ways, reads) on `x (ab)^k` shows the cause:
the rung climbs to k, a cell keeps about 2·rung ways (one per end and owed count), and reads
per rung grow as k·rung, so the total is about k³ or more. Moving `first` from the cell key
into the dominance test (z19c) changed nothing.

This matches what is known for context-free languages: language edit distance is not linear
when the error count grows with n (Dyck edit distance, which a PEG can express, has subcubic
but superlinear algorithms). So no engine is both exact for every error count and linear.
Linear time with exactness while the exact search is cheap is what remains.

**z19: cost mode under a work limit.** Rungs double as before. Rungs up to `_cap = 2` always
run in cost mode. Past them, each proposal into a cell counts one unit of work, and once the
count passes `_floor + _per · rules · (n + 1)` the rung throws `_Stop`; the search then
restarts in z18's local mode. The floor keeps every small input exact; the per-position term
keeps the wasted work linear. Without the exemption for rungs up to 2, the limit cut rung 2
short on JSON battery cases and local mode answered at cost 5 where z19b found 2 (treeDiff 20,
costDiff 12).

| `_per`, `_floor` | exhaustive misses | `x (ab)^1600` | dense probe 1, k = 1024 / 4096 |
|---|---|---|---|
| 64, 0 | 27 / 0 / 0 / 0 / 698 | 976 ms | 341 / 1,548 ms |
| 64, 131,072 | 0 | 1,645 ms | 732 / 2,307 ms |
| 16, 131,072 | 0 | 472 ms | 433 / 812 ms |
| 4, 131,072 | 0 | 363 ms | 371 / 614 ms |
| 4, 16,384 | 0 | 151 ms | 89 / 273 ms |
| 4, 4,096 (z19) | 0 | 139-157 ms | 59-73 / 254-264 ms |

**z19 against z19b and z18** (same-session runs; times under load from another session's
benchmark, so battery times are within noise of each other):

| | z18 | z19b | z19 |
|---|---|---|---|
| LOC | 573 | 566 | 572 (+6 vs z19b, +1.1%; -1 vs z18) |
| Engine fields | 18 | 18 | 20 (`_work`, `_limit`), constants `_cap`, `_per`, `_floor` |
| Battery | 0.9904 / 86.5 | 0.9904 / 86.5, treeDiff 117 vs z18 (fix B) | same trees as z19b, 6.7-8.0 s vs 6.5-7.0 s |
| Gates | all pass | all pass | all pass |
| dl / lf priceWorse | 1 / 2 | 0 / 0 | 0 / 0 |
| dl / lf levWorse | 68 / 40 | 69 / 41 | 64 / 37 |
| Exhaustive misses (41,524 inputs) | - | 1,030 | 0 |
| `x (ab)^1600` | 162 ms | 118 ms | 146 ms |
| dense probes 1-3, k = 1024 | 29 / 59 / 82 ms | 25 / 55 / 58 ms | 59 / 72 / 58 ms |
| `x (ax)^n bbab`, n = 16,000 | - | 3,538 ms | 3,678 ms |
| depth and `x (ax)*n b` (`deep.sh`) | linear | linear | linear |

**z19b's fixes** (each ablated on the battery and on `cabb`, which xrefmz prices 1 and z19a 2):
A, cost-mode dominance requires equal `owed`; B, the tie rule keeps the newer way when equal and
either it owes nothing or its piece is a library match (the only source of the 117 changed
battery trees); D, a seeded First bumps the position's version on exit; F, `_propose` returns a
demoted clean way at `pos` instead of dropping it; I, `_repeat` asks for non-empty iterations;
J, `_Probe` extends `peg.Terminal`, `Exact._at` is inlined. The `cabb` fix needs A, B, D and F
together. F costs local-mode misses on g3 (z19bf without it: `xaaxabb` 3, as xrefmz), but z19's
cost mode covers g3 fully.

**Cross-review round 4 claims checked here:** Claude's proof that keeping every admitted way in
(clause, start) cells is quadratic on `x (ab)^n` is consistent with the trace above. Its opu10i
(work limit sized `size(G)·(M+1)·(n+1)`, cost rungs up to M) is the same idea as z19's limit; z19
differs by an additive floor, a small per-position constant and exempt early rungs. The claim
that c4arg7 / arg7 is exact is wrong (`x (ab)^6 q` on g5: 6 against 3). Codex's sol9 figures
(580 LOC, 5.2 s, 0 / 1) were not rechecked.

**Open.** The work limit is two tuned constants: any input whose exact search needs more work
than the limit falls to local mode, which is not price-exact. A local mode that is exact, or a
lower bound on the remaining cost that prunes cost-mode ways, would remove the limit.
