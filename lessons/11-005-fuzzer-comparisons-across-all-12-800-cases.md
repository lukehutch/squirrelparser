<!-- Part of LESSONS_LEARNED.md, section: 11. Round 60: z9 — Zero Bit-Packing Anywhere, Exact z6/z7 Battery Trees, Fastest Battery & Rungs, and Best D1 Fuzzer Validity/Costs (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 11.5 Fuzzer Comparisons Across All 12,800 Cases (`dl.sh` and `lf.sh`, Seeds 1–8 and Held-Out Seeds 9–16)

**4-Way D1-Compliant Run (`zd / z7 / z8 / z9`, 3,200 cases per row):**

| Suite & seeds | `worse` (`zd / z7 / z8 / z9`) | `levWorse` (`zd / z7 / z8 / z9`) | `invalid` (`zd / z7 / z8 / z9`) | `timeouts` |
|---|---|---|---|---|
| `dl.sh` seeds 1–8 (3,200) | 45 / 51 / 83 / **33** | 40 / 43 / 76 / **27** | 35 / 19 / 69 / **16** | 0 / 0 / 0 / 0 |
| `dl.sh` seeds 9–16 (3,200, held-out) | 48 / 44 / 83 / **27** | 40 / 38 / 67 / **20** | 46 / 27 / 64 / **24** | 0 / 0 / 0 / 0 |
| `lf.sh` seeds 1–8 (3,200) | 55 / 45 / 140 / **39** | 51 / 36 / 110 / **28** | 35 / 25 / 64 / **23** | 0 / 0 / 0 / 0 |
| `lf.sh` seeds 9–16 (3,200, held-out) | 59 / 42 / 139 / **27** | 54 / 35 / 114 / **26** | 44 / 25 / 63 / **26** | 0 / 0 / 0 / 0 |
| **Total (12,800 cases)** | 207 / 182 / 445 / **126** | 185 / 152 / 367 / **101** | 160 / 96 / 260 / **89** | **0 / 0 / 0 / 0** |

**6-Way Run Including `x513j` and `e8` (`z9 / z8 / z7 / zd / x513j / e8`, 3,200 cases per row):**

| Suite & seeds | `worse` (`z9 / z8 / z7 / zd / x513j / e8`) | `levWorse` (`z9 / z8 / z7 / zd / x513j / e8`) | `invalid` (`z9 / z8 / z7 / zd / x513j / e8`) | `timeouts` |
|---|---|---|---|---|
| `dl.sh` seeds 1–8 (3,200) | **71** / 117 / 90 / 82 / 171 / 56 | **58** / 104 / 75 / 70 / 150 / 53 | **16** / 69 / 19 / 35 / 22 / 0 | 0 |
| `dl.sh` seeds 9–16 (3,200, held-out) | **80** / 129 / 96 / 101 / 161 / 51 | **68** / 112 / 86 / 87 / 140 / 50 | **24** / 64 / 27 / 46 / 25 / 0 | 0 |
| `lf.sh` seeds 1–8 (3,200) | **92** / 188 / 98 / 108 / 137 / 47 | **64** / 144 / 72 / 88 / 111 / 43 | **23** / 64 / 25 / 35 / 26 / 0 | 0 |
| `lf.sh` seeds 9–16 (3,200, held-out) | **81** / 192 / 95 / 111 / 170 / 35 | **60** / 147 / 69 / 87 / 141 / 34 | **26** / 63 / 25 / 44 / 43 / 0 | 0 |
| **Total (12,800 cases)** | **324** / 626 / 379 / 402 / 639 / 189 | **250** / 507 / 302 / 332 / 542 / 180 | **89** / 260 / 96 / 160 / 116 / 0 | **0** |
