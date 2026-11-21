<!-- Part of LESSONS_LEARNED.md, section: z8 (round 59, 2026-10-24): genuine field elimination and returning to z3's simplicity -->
[Back to the index](../LESSONS_LEARNED.md)

### Measurements (kit, 2026-10-24)

| Check | z3 (r55) | z6 (`zd`) | z7 (r58) | z8 (r59) |
|---|---|---|---|---|
| LOC (normalized / raw) | 560 / 338 | 716 / 413 | 806 / 451 | **500 / 315** |
| `_Way` fields | 14 + 2 getters | 9 + 6 bitfield getters | 9 + 6 bitfield getters | **12 plain fields, 0 bitfields, 0 getters** |
| Battery accuracy (2,101 cases) | 0.9901 / 86.4% | 0.9904 / 86.6% | 0.9904 / 86.6% | **0.9904 / 86.6% (`costDiff 0` vs `z6`/`z7`)** |
| Battery JIT (`bench.sh battery`) | 2,829–2,868 ms | 2,812–2,899 ms | 3,407 ms | **2,560–2,755 ms** |
| Battery AOT (`x3.exe bench 1 z8 zd z7 z3 x513j`) | 2,711 ms | 2,754 ms | 3,087 ms | **2,694 ms** (`x513j`: 883 ms) |
| Gates (`accept`, `freespan`, `recommit`, `conf1`, `cleanTreeDiff`) | all pass | all pass | all pass | **all pass (`true/true/true`, `3 3 4 4 1`, `16/16`, `0 1 1 0 2 3`, `0`)** |
| `props` / `pred` / `window` | 0 / 0 / P=true | 0 / 0 / P=true | 0 / 0 / P=true | **0 violations (2,728) / falseAssertions=0 / P=true at n=1..4096** |
| `_bits.dart` (`owed` n=250..300, `arms` n=100..200) | PASSES | FAILS (overflow >255) | PASSES | **PASSES (cost 250..300; arms cost 4, edits 4)** |
| `_bits2.dart` (2 LR + error cases) | FAILS | FAILS | PASSES | **PASSES (cost 6, cost 2; 0 crashes)** |
| Many errors (`1000/16/1`, `32/1`, `64/1` AOT / JIT) | rung 64: 519 ms JIT | rung 64: 251 ms AOT / 584 ms JIT | rung 64: 235 ms AOT / 535 ms JIT | **118 / 186 / 231 ms AOT; 284 / 393 / 590 ms JIT (costs 14, 29, 59)** |
| `deep.sh` (depth 3,200 missing 0 / 1) | 3,100–3,600 ms | 280 ms | 44 / 316 ms | **39 / 293 ms (`x(ax)*1600b`: 99 ms; `x(ab)*1600`: 74 ms)** |
| `_tilde.dart` (909 transparent-rule cases) | 0 crashes | 0 crashes | 0 crashes | **0 crashes (cost 14,848)** |
| `_chkscale.dart` (`n=6400` cases 0, 1, 4) | timeout on deep | case 4 overflow (156) | passes | **case 0: 439 ms (cost 2); case 1: 459 ms (cost 2); case 4: 5,795 ms (true cost 2,135)** |
