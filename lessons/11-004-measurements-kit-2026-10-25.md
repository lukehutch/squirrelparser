<!-- Part of LESSONS_LEARNED.md, section: 11. Round 60: z9 — Zero Bit-Packing Anywhere, Exact z6/z7 Battery Trees, Fastest Battery & Rungs, and Best D1 Fuzzer Validity/Costs (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 11.4 Measurements (kit, 2026-10-25)

| Check | z6 (`zd`) | z7 (r58) | z8 (r59) | f25 (§10.9) | **z9 (r60)** |
|---|---|---|---|---|---|
| LOC (normalized / raw) | 716 / 413 | 806 / 451 | 500 / 315 | 1,132 / 719 | **792 / 448** |
| Bit-packing anywhere (`_Way`, `_Cell`, `mark`, `first`) | Yes (all 4) | Yes (all 4) | Yes (`mark`, `first`) | No | **None (0 bitfields, 0 packed sentinels)** |
| Directives D1 / D2 / D7 / D8 | Pass | Violates D1 in `_matchesOne` | Pass | Violates D1, D2 (`400k`), D8 (`b2`) | **Pass (100% compliant)** |
| Battery accuracy (2,101 cases) | 0.9904 / 86.6% | 0.9904 / 86.6% (`treeDiff 0`) | 0.9904 / 86.6% (`treeDiff 18`) | 0.9899 / 84.5% | **0.9904 / 86.6% (`treeDiff 0, costDiff 0` vs `z6`/`z7`)** |
| Battery AOT (`x3.exe bench 5 zd z7 z8 z9`, min / med) | 2,463 / 2,634 ms | 2,787 / 2,879 ms | 2,680 / 2,730 ms | — | **2,444–2,522 / 2,510–2,560 ms (fastest)** |
| Battery JIT standalone (`bench.sh battery X`) | 2,707–2,767 ms | 3,076 ms | 2,830 ms | ~2,700 ms | **2,641–2,665 ms (fastest)** |
| Gates (`cx2/b1/b2`, `freespan`, `recommit`, `conf1`, `clean`) | all pass | all pass | all pass | **FAILS `b2` & `conf1` (`0 1 1 0 2 2`)** | **all pass (`true/true/true`, `3 3 4 4 1`, `16/16`, `0 1 1 0 2 3`, `0`)** |
| `props` (2,728) / `pred` / `window` (n=1..4096) | 0 / 0 / P=true | 0 / 0 / P=true | 0 / 0 / P=true | — | **0 violations / falseAssertions=0 / P=true** |
| `_bits.dart` (`owed` n=250..300, `arms` n=100..200) | FAILS (>255) | PASSES (cost 7) | PASSES (cost 4, invalid) | PASSES (cost 7) | **PASSES (cost 250..300 in 2 ms; arms cost 7 in 16 ms)** |
| `_bits2.dart` (true valid PEG costs: 7 and 8) | 4 and 8 (invalid) | 7 and 8 | 6 and 2 (invalid) | 7 and 8 | **7 and 8 (valid)** |
| Rungs `1000/1/1`, `16/1`, `32/1`, `64/1` AOT (`x3.exe`) | 63 / 118 / 180 / 251 ms | 65 / 125 / 190 / 235 ms | 62 / 118 / 186 / 231 ms | — | **53 / 100 / 152 / 186 ms (costs 1, 14, 29, 59)** |
| Rungs `1000/1/1`, `16/1`, `32/1`, `64/1` JIT (`bench.sh scale`) | 150 / 289 / — / 672 ms | 151 / 367 / — / 533 ms | 116 / 330 / 393 / 470 ms | — / 1,380 / 5,100 / 9,900 ms | **136 / 283 / 390 / 438 ms (costs 1, 14, 29, 59)** |
| `deep.sh` (depth 3,200 missing 0 / 1; `x(ax)*1600b`; `x(ab)*1600`) | — / 272 ms | 44 / 316 ms | 39 / 293 ms | **STACK OVERFLOW at 1,600** | **38 / 314 ms; 1,276 ms (cost 1); 72 ms (cost 1,600)** |
| `_tilde.dart` (909 transparent-rule cases) | 0 crashes | 0 crashes | 0 crashes (14,848) | — | **0 crashes (cost 14,686)** |
