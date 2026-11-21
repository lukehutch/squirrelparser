<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.21 Round 74: z17's cost bound is quadratic; exact rungs up to 2, then z16's local budget (z18)

**z17 regressed on scaling.** 12.20 measured z17 on the battery and the price fuzzers only. On
long inputs it is far slower than z16 (times in ms; dense costs in parentheses):

| Input | z16 | z17 | z18 |
|---|---|---|---|
| `S <- A; A <- 'x' ('a' A)*;`, input `x` + `ab`×160 | 4 | n = 50 already times out (60 s) | 10 |
| same, `ab`×640 / ×1600 | 40 / - | timeout | 76 / 162 |
| `S <- E*; E <- 'c' ' ';`, `c`×256 / ×1024 | 19 / 104 | 2,200 / - | 6 / 29 |
| `S <- E*; E <- 'c'? ' ';`, `c`×256 / ×1024 | 30 / 144 | 4,400 / - | 14 / 59 |
| `S <- E*; E <- 'c'? 'c' 'a'? ' ';`, `c`×256 / ×1024 | 10 (86) / 48 (342) | - | 23 (87) / 82 (343) |

`deep.sh` agrees: z17 times out on `x (ab)*n` at every n from 50 to 1600; z18 and z17 are equal
on the depth and `x (ax)*n b` families.

Two causes, both confirmed by per-rung traces (one stderr line per rung: rung, time, cells,
ways):

1. The root test `w.cost > rung` makes the rung climb to the answer's total cost. z16's test
   bounded `used`, which resets at each settled repair, so z16 stops at rung 1 on these inputs.
   Under a cost bound a cell must keep every way whose cost fits the rung. On `x (ab)*n` the
   flat and the nested readings all have the optimal cost, so no admissible lower bound can
   prune them, and a cell at position p holds about p ways: about n² in all.
2. The deletion before the top rule (z17d) reads `_read(top, p)` for every p up to the rung.
   Each read holds about rung ways, so it is quadratic once the rung climbs.

**Ways that cannot win.** A cell can drop a way when another way with the same key spends,
uses and owes no more. Comparing on `cost` instead is unsound, because the price is not
additive in `owed` (an owed run of up to M characters costs 1): z18k did so and changed 398
battery trees. Even with the three-part test, about 390 trees changed (z18n to z18q), and the
cause was the tie rule, not which ways were dropped: of two ways equal on all three counts,
keeping the newer one unless the older is better (z16's own rule) brings treeDiff to 7 (z18r).

**Two modes.** The first rungs bound the answer's cost, with a cell prune `r.cost <= rung` and
dominance as above. Past the cap, the search restarts from rung 1 in z16's mode: the rung
bounds `used`, a cell keeps one way per `(used, owed)` with no dominance, and there is no
deletion before the top rule. Each of the three local-mode rules was needed:

| Variant | Local mode differs by | Result |
|---|---|---|
| z18t | dominance kept | dense probe 3 at k = 64 hangs: dominance kept only a PEG-invalid way (`cc cc cc cc cc c `), so the exponential exact fallback ran |
| z18v | leading deletion kept | dense probes quadratic |
| z18w | neither | all probes linear |

The cap (rungs 1, 2, 4, ... up to the cap run in cost mode):

| Cap | Battery vs z17 | `ab`×640 | dense probe 3, k = 1024 | dl / lf priceWorse | dl / lf levWorse |
|---|---|---|---|---|---|
| 0 (z18d) | 0.9883 / 85.7, costDiff 19 | 43 ms | 13 ms | - | - |
| 1 | 0.9883 / 85.8, costDiff 18 | 56 ms | 32 ms | - | - |
| 2 (z18) | 0.9904 / 86.5, treeDiff 6, costDiff 0 | 76 ms | 82-105 ms | 1 / 2 | 68 / 40 |
| 4 | same as 2 | 273 ms | 176-193 ms | 3 / 2 | 60 / 36 |
| 8 | same as 2 | 2.4 s | - | 3 / 2 | 60 / 36 (run with cap 4) |

Cap 2 is chosen: no worse on price, 3.6 times faster than cap 4. The gap to z16 on `ab`×640
(76 against 40 ms) is the cost-mode rungs; local mode alone takes 43 ms. Local mode is not
exact: on dense probe 3 z18 costs 87 at k = 256, where z16 and z17 cost 86.

**Ablations** (on z18w, cap 4; battery against z18w, fuzzers with xrefmz):

| Removed | Battery | `ab`×640 | dl / lf priceWorse | Kept? |
|---|---|---|---|---|
| nothing (z18w) | - | 275 ms | 3 / 2 | - |
| cell prune `r.cost <= rung` (z18a1) | treeDiff 1 | times out | - | yes |
| `_budget < 0` return (z18a2) | treeDiff 0 | 266-324 ms in 3 runs, as with it | 3 / 2 | no (z17 has no such test) |
| `Exact.complete` (z18a3) | treeDiff 0 | 272 ms | 3 / 2 | no |

`Exact.complete` (z18h) searched for a shorter end completion when a candidate failed the
check. It fixed the hand-reduced input `ca` but no fuzzer case, and it is exponential in the
inserted length. Deleted.

**Also tried:** z18x, z18w with z16's cell code (one way per key, no dominance) in both modes:
battery treeDiff 2 vs z17 but 5.4-6.8 s, `ab`×640 670 ms, priceWorse 1 / 2. Not adopted.

**What remains from the z18a to z18g steps**, each found by reducing one of 12.20's five misses:
the cell filter keeps any way that still owes characters (`|| r.owed > 0`, fixes `bbba`); the
repetition queue also keeps the earliest of the cheapest ways per end, and a `done` set stops
re-expansion (fixes `babcbcabccbabc`); a repetition no longer skips a Terminal iteration that
owes at least its evidence; and in the tree mapping, a substitution directly under the root or a
Ref is wrapped in a one-arm choice naming the literal.

**z18 against z17** (same-session runs; LOC by `awk 'NF && $1 !~ /^\/\//'`):

| | z17 | z18 |
|---|---|---|
| LOC | 565 | 573 (+8, +1.4%) |
| Fields per reading / cell / engine | 13 + one static / 7 / 17 | 13 + one static / 7 + one static (`_local`) / 18 (`_rung`), constant `_cap` |
| Battery | 0.9905 / 86.5, 4.6 s | 0.9904 / 86.5, 4.1 s, treeDiff 6, costDiff 0 |
| Gates | all pass | all pass |
| dl / lf priceWorse (vs xrefmz) | 2 / 3 | 1 / 2 |
| dl / lf levWorse | 49 / 29 | 68 / 40 |
| dl / lf invalid, timeouts | 0, 0 | 0, 0 |
| `x (ab)*n`, n = 50 to 1600 | all time out | 3 to 162 ms |

The binary search between the last failing and first succeeding rung is gone: removing it
(z18l, from z18k) left the battery unchanged and made it faster.

**Flaw named.** `_Cell._local` is static mutable state shared by every engine instance; it is
correct only because one recovery runs at a time. Passing it to each cell would cost a field.

**Conclusion.** z18 replaces z17. It keeps z17's price quality (3 misses of 12,800 against 5)
and battery, and restores linear time on the long inputs where z17 timed out. levWorse rose
(68 / 40 against 49 / 29); 12.20 showed that count is mostly the choice among repairs of equal
price. Still open: local mode is not price-exact (dense probe 3: 87 against 86), and the
cost-mode rungs make z18 about twice as slow as z16 on `ab`×640.
