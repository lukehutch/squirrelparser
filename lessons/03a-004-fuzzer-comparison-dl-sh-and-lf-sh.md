<!-- Part of LESSONS_LEARNED.md, section: z8 (round 59, 2026-10-24): genuine field elimination and returning to z3's simplicity -->
[Back to the index](../LESSONS_LEARNED.md)

### Fuzzer comparison (`dl.sh` and `lf.sh`, 4-way `z8 / zd / z3 / x513j`, 3,200 cases per row)

| Suite & seeds | `worse` (`z8 / zd / z3 / x513j`) | `levWorse` (`z8 / zd / z3 / x513j`) | `invalid` (`z8 / zd / z3 / x513j`) | `timeouts` |
|---|---|---|---|---|
| `dl.sh` seeds 1-8 (3,200) | **101** / 64 / 452 / 150 | **85** / 51 / 385 / 128 | **69** / 35 / 116 / 22 | 0 / 0 / 0 / 0 |
| `dl.sh` seeds 9-16 (3,200, held-out) | **115** / 83 / 449 / 148 | **97** / 71 / 385 / 122 | **64** / 46 / 107 / 25 | 0 / 0 / 0 / 0 |
| `lf.sh` seeds 1-8 (3,200) | **156** / 74 / 489 / 105 | **118** / 60 / 412 / 83 | **64** / 35 / 101 / 26 | 0 / 0 / 0 / 0 |
| `lf.sh` seeds 9-16 (3,200, held-out) | **151** / 70 / 453 / 129 | **114** / 54 / 381 / 107 | **63** / 44 / 107 / 43 | 0 / 0 / 0 / 0 |
| **Total (12,800 cases)** | **523** / 291 / 1,843 / 532 | **414** / 236 / 1,563 / 440 | **260** / 160 / 431 / 116 | **0 / 0 / 0 / 0** |

Compared to `z3` (from which it directly evolved while shrinking LOC from
`560 / 338` down to `500 / 315`), `z8` cuts `worse` cases across the
12,800 fuzzer inputs by **3.5x** (`1,843 -> 523`, beating `x513j`'s `532`
and `levWorse` `414` vs `x513j`'s `440`) and cuts `z3`'s invalid trees by
**40%** (`431 -> 260`), with zero bit-packing and zero AST-walking
filters.
