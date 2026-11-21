<!-- Part of LESSONS_LEARNED.md, section: 2. The standing table (era-3 battery, 2026-08-21) and the c-series comparison (2026-09-06) -->
[Back to the index](../LESSONS_LEARNED.md)

### All lines: the leading engines compared (2026-10-21)

One row per engine that led its line, with the figures recorded in its
round's section (not re-run for this table). Every score is the same
2,101-case battery under `_research18.dart` (score / perfect %). Battery
time is one engine's recorded wall time in its own session, so times
from different rows differ by load and harness by up to 2x; Ir
(callgrind instructions) is comparable only within one x3.exe build,
and is given only for the x line. "Rung k" is `1000/k/1`: a 1,000-node
JSON document with k errors. "dl" is `_samedl.dart` seeds 1-8 x 400
(3,200 cases); an invalid tree is one whose answer is not a PEG parse
of the repaired input. "-" means not measured.

| Engine | Line | Date | LOC | Battery | Battery time | Many errors | dl invalid | Deep inputs |
|---|---|---|---|---|---|---|---|---|
| s1 | r/s | 08-05 | 697 | 0.9841 / 77.0 | 1,686 ms | - | - | - |
| c14 | c | 09-02 | 807 | 0.9899 / 85.8 | 370-572 ms | 24k chars, 4 errors: 26.2 s | - | - |
| c18 | c | 09-05 | 1,194 | 0.9900 / 86.0 | 806 ms | 200k chars: 4.7 s, 1.2 GB | - | - |
| c18-envelope | c | 09-06 | - | 0.9902 / 86.2 | 1,383 ms | 5,959 chars: 861 ms | - | - |
| c19 | c | 09-05 | 470 | 0.9900 | 1,539 ms | 5,959 chars: 2.4 s | - | - |
| c20 | c | 09-07 | 742 | 0.9899 / 86.1 | 1,364-1,395 ms | rung 8: 8.9 s | - | - |
| c25 | c | 09-08 | 900 | 0.9901 / 86.0 | as c20 | rung 12: 1.7 s; rung 32 never | - | - |
| cdx10 | cdx | 09-23 | 845 | 0.9899 / 84.3 | - | rung 32: 3.2 s; rung 64: 3.0 s | 47 (older fuzzer) | - |
| cl8 | cl | 09-23 | 712 | 0.9900 / 84.3 | - | - | 30 (older fuzzer) | - |
| cl28 | cl | 10-03 | 909 | 0.9900 / 84.5 | 2.0 s | every rung finishes | 163 of 12,800 | overflow at 3,200 |
| pd23 | pd | 10-03 | 856 | 0.9900 / 84.4 | 18.6 s | - | 0 | linear, no overflow |
| pd57 | pd | 10-03 | 898 | 0.9898 / 84.4 | 2.0-2.1 s | - | 0 | - |
| u28 | u | 10-07 | 998 | 0.9896 / 84.2 | 2.27 s | rung 12: 1.3 s; rung 32: 17.4 s, 4.1 GB | 0 | - |
| sk2 | sk | 10-07 | 151 | 0.4498 / 9.3 | 182-189 ms | quadratic | 1,297 | - |
| sk7q | sk | 10-08 | 428 | 0.953 | 623-653 ms | rung 64: 5.7 s | - | - |
| sk10p | sk | 10-09 | 531 | 0.9801 | 4.2 s (loaded) | rung 64: cost 68 | 89 | overflow at 800 |
| x464a | x | 10-10 | 306 | 0.9811 / 76.4 | Ir 23.15G | rung 64: Ir 46.39G | 66 | overflow at 800 |
| x494d | x | 10-11 | 545 | 0.9811 / 76.4 | Ir 11.81G | rung 64: Ir 26.13G | 37 | all finish |
| x504i | x | 10-11 | 880 | 0.9811 / 76.4 | Ir 13.15G | rung 64: Ir 13.20G | 24 | all finish |
| x513j | x | 10-21 | 918 | 0.9811 / 76.4 | 1,191 ms; Ir 12.72G | rung 64: Ir 12.21G | 22 | all finish |
| z1 (r52) | z | 10-22 | 762 (529 raw) | 0.9898 / 86.1 | 2,845 ms | rung 64: 373 ms (cost 59) | 107 (c14: 371) | all finish |
| z1 (r53) | z | 10-22 | 613 (379 raw) | 0.9896 / 86.1 | 2,800 ms | rung 64: 695 ms (cost 59) | 107 (c14: 371) | all finish |
| z2 (r54) | z | 10-22 | 569 (347 raw) | 0.9900 / 86.3 | 2,388 ms | rung 64: 555 ms JIT / 355 ms AOT (cost 59) | 96 (5 seeds) | all finish |
| z3 (r55) | z | 10-22 | 560 (338 raw) | 0.9901 / 86.4 | 2,829-2,868 ms (round 56 review) | rung 64: 519 ms JIT (cost 59) | 116 | all finish; depth 3,200 with one missing: 3.1-3.6 s |
| z4 (r56) | z | 10-23 | 762 (443 raw) | 0.9902 / 86.4 | 3,227-3,264 ms JIT; 1,829 ms AOT median | rung 64: 446-541 ms JIT / 218 ms AOT (cost 59) | 60 | all finish; depth 3,200 with one missing: 0.3 s |
| z5 (r57) | z | 10-23 | 732 (418 raw) | 0.9904 / 86.6 | 2,778-2,859 ms JIT; 2,863 ms x3 AOT (z4: 3,133 ms) | rung 64: 584 ms JIT / 251 ms AOT (cost 59) | 35 | all finish; depth 3,200 with one missing: 282 ms |
| z6 | z | 10-23 | 716 (413 raw) | 0.9904 / 86.6 (trees = z5) | 2,812-2,899 ms JIT (z5 3,106-3,201 same session); 2,796 ms x3 AOT median (z5 2,844) | as z5 | 35 | as z5; depth 3,200 with one missing: 280 ms |
| z7 (r58) | z | 10-24 | 806 (451 raw) | 0.9904 / 86.6 (trees = z6) | 3,407 ms JIT; 3,101 ms x3 AOT median (zd: 2,802 ms) | rung 64: 535 ms JIT / 235-282 ms AOT (cost 59) | 19 (27 on 9-16) | all finish; depth 3,200 with one missing: 316 ms |
| z8 (r59) | z | 10-24 | 500 (315 raw) | 0.9904 / 86.6 (costDiff 0 vs z6/z7) | 2,560-2,755 ms JIT; 2,694 ms x3 AOT (zd: 2,754, z7: 3,087, z3: 2,711) | rung 64: 590 ms JIT / 231 ms AOT (cost 59) | 69 (64 on 9-16; z3: 116/107) | all finish; depth 3,200 with one missing: 293 ms |
| z9 (r60) | z | 10-25 | 792 (448 raw) | 0.9904 / 86.6 (trees = z6/z7) | 2,641-2,665 ms JIT (zd: 2,707-2,767, z8: 2,830, z7: 3,076); 2,444-2,560 ms x3 AOT (zd: 2,594-2,634, z8: 2,684-2,730, z7: 2,879-3,001) | rung 64: 438 ms JIT / 186 ms AOT (cost 59) | 16 (24 on 9-16; 89 of 12,800 on dl+lf seeds 1-16) | all finish; depth 3,200 with one missing: 314 ms |
| z9 (r61) | z | 10-25 | 887 (503 raw) | 0.9904 / 86.6 (trees = z6/z7/z9-r60) | 2,970 ms JIT; 2,703-2,821 ms x3 AOT (zd: 2,511-2,648, z7: 2,773-2,833, z8: 2,536-2,555) | rung 64: 231 ms AOT (cost 59); rungs 1/16/32: 56/125/188 ms | 16 (24 on 9-16; 89 of 12,800 on dl+lf seeds 1-16, identical trees to r60) | all finish; depth 3,200 missing 0/1: 37/651 ms; tilde 909 cases: 0 crashes (cost 14,686) |
| e7s | e | 10-24 | 659 (429 raw) | 0.9899 / 84.5 | 6.0 s JIT | rung 4: 86 s | 0 (0 of 12,800 on dl+lf seeds 1-16) | - (breaks D1; fails b2) |
| e14 | e | 10-24 | 709 (456 raw) | 0.9900 / 84.5 | 4.2 s JIT | rungs 1, 2: 0.20, 0.23 s; rung 4: 61 s | 12 of 12,800 (e8, same trees as e7s: 0) | - (breaks D1; fails b2) |
| f25 | f | 10-24 | 1,132 (719 raw) | 0.9899 / 84.5 | ~2.7 s JIT | rung 16/32/64: 1.38 / 5.1 / 9.9 s (cost 57) | 0 (0 of 12,800 on dl+lf seeds 1-16) | overflow at 1,600 (breaks D2; fails b2) |

The z3 and z4 rows (added 2026-10-23) were measured twice: in their own
rounds and in the round 56 review, which reproduced every figure.
`_z3.dart` holds the original round 55 z3 from commit bf0fd55,
`_z4.dart` holds round 56 z4, `_z5.dart` holds round 57 z5, `_z6.dart`
holds z6 (z5 with two parts deleted and one cache added), `_z7.dart`
holds round 58 z7, `_z8.dart` holds round 59 z8, and `_z9.dart` holds
round 60 z9 (zero bit-packing anywhere, exact `z6`/`z7` battery trees,
fastest `0.9904` battery/rung speed, and lowest D1 fuzzer `worse` and
`invalid` counts).

The x-line Ir figures are from three builds: x464a, x494d and x504i
from round 50's, x513j from round 51's; in round 51's builds x504i
measured 12.89-12.91G on the battery and 12.80-12.87G on rung 64,
2-3% below round 50's.

**Which engine is best at what, and why.**

| Measure | Best | Why it wins |
|---|---|---|
| Accuracy | z5, z6, z7, z8, z9 0.9904 / 86.6 (2026-10-25); z4 0.9902 / 86.4; c18-envelope 0.9902 / 86.2 | c13's ranking keys judge whole readings by the evidence each one has, and c12's gated substitution repairs a wrong character as one edit; z9 matches z6/z7 on all 2,101 battery trees (`treeDiff 0, costDiff 0`) with zero bit-packing anywhere |
| Valid trees | e7s, e8, f25: 0 of 12,800 (dl and lf, seeds 1-16, 2026-10-24); pd23, pd57, u28: 0 of 3,200; among fast D1-compliant engines on all 12,800 dl+lf cases (seeds 1-16), **z9: 89** (dl 16+24, lf 23+26) vs z7: 96 (dl 19+27, lf 25+25), x513j: 116 (dl 22+25, lf 26+43), z6: 160 (dl 35+46, lf 35+44), and z8: 260 (dl 69+64, lf 64+63) | e/f lines: every candidate is a real parse of its repaired string (breaks D1/D2, fails b2); pd/u: the search states are PEG derivatives of the top rule; z9: adds empty-language pruning (`_min0(c) == _never` with `FollowedBy` awareness), syntactic-vs-semantic dominance in `_covers`, `OneOrMore` tail extraction, and a D1-compliant structural `_m1` matcher |
| Size | x464a 306 lines (sk2 151 at score 0.45); among 0.9904 / 86.6 engines, z8: 500 normalized / 315 raw lines; among exact-tree D1 engines, z9: 792 normalized / 448 raw (vs z7: 806 / 451, f25: 1,132 / 719) | x464a: the repair is the ordinary memo parser run with fixes in force; z8: algebraically eliminates 4 `_Way` fields from z3; z9: eliminates all bit-packing in `_Way`, `_Cell`, `cell.mark`, and `first` via field covariance (`clean => cost == 0`, `preferred => clean && cut == _never`, `paired => _min(deleted, spent - deleted + owed)`) |
| Battery speed | c14 370-572 ms; among 0.9904 engines, **z9: 2,444-2,560 ms x3 AOT, 2,641-2,665 ms standalone JIT** (beating z6 2,594-2,634 AOT / 2,707-2,767 JIT, z8 2,684-2,730 AOT / 2,830 JIT, and z7 2,879-3,001 AOT / 3,076 JIT) | c14: one pass per case; z9: static-totality memoization (`_tot[c]`), unboxed `List<_Way>` cell frontiers (`_Cell.ends`), early-exit `_steals` guard (`!ne && o.first != at`), and cached `Str` character lists (`_chars`) |
| Many errors on one document | **z9** (rung 64 in **186 ms AOT / 438 ms JIT**, cost 59; 2026-10-25), z4-z8 (218-282 ms AOT, 0.45-0.59 s JIT); cdx10 (rung 64 in 3.0 s); f25 (rung 64 in 9.9 s); x504i and x513j | z line: credit settlement amortizes isolated repairs once followed by clean synced input; cdx10: return-site bound; x line: first-gain bound |
| Long inputs | c18 (200k characters in 4.7 s) | repairs only inside windows over the farthest failure, and memoized plain matches |
| Deep nesting | x494d onward, pd23, z4, z5, z6, z7, z8, z9 | an overflow handler that reruns the path in its recorded state (x); an explicit frame stack (pd); bottom-up memo sweep on overflow plus post-order evidence/tree evaluation (z4-z9; z9: 314 ms at depth 3,200) |
| Fuzzer costs (with the e line) | e8 / e7s: fewest worse in a 6-way run (`z9 / z8 / z7 / zd / x513j / e8`, 12,800 cases): 189 (e8) vs **324 (z9)**, 379 (z7), 402 (zd), 626 (z8), 639 (x513j) (2026-10-25) | a cost-ordered search over repaired strings finds the cheapest repair it can reach by real parses; among D1-compliant engines, **z9** has the fewest worse costs in every row |
| Fuzzer costs (D1-compliant) | **z9**: in 4-way runs across all 12,800 cases (`zd / z7 / z8 / z9`, seeds 1-8 and held-out seeds 9-16), **z9** wins every row on both `worse` (`dl 1-8`: **33** vs 45 / 51 / 83; `dl 9-16`: **27** vs 48 / 44 / 83; `lf 1-8`: **39** vs 55 / 45 / 140; `lf 9-16`: **27** vs 59 / 42 / 139; total **126** vs 182 / 207 / 445) and `invalid` (**89** vs 96 / 160 / 260) | z9: empty-language clause pruning (`_min0(c) == _never`), active-ref syntactic shadowing in `_covers`, `OneOrMore` tail extraction in `_tails`, and structural 1-character consuming matcher `_m1` (replacing z7's D1-violating `new peg.Parser`) |

No engine holds all of these. The c and cdx lines have high accuracy at
742-900 lines; the pd and u lines are the only D1-compliant engines with
no invalid trees, at 856-998 lines and about 2 s on the battery. The x
line scores 0.009 below the c and z lines. Its smallest engine, x464a,
is 306 lines; the parts added since (deep inputs, exact bounds, the
overlay climb, the validity checks) bring x513j to 918 lines, the size
of c25, with every deep and many-error input finishing and 22 invalid dl
trees. The synthesis round (below, 2026-09-11) showed why the c-line
bests do not combine. In rounds 56-58, z4-z7 reduced invalid trees to
96 across the 12,800 dl+lf fuzzer cases (`z7`), but did so by packing
six counters into bitfields of an `int` to disguise bookkeeping field
count while adding ~250 normalized lines of AST-walking filters (growing
to 806 normalized / 451 raw lines in z7 and slowing battery AOT to
3.10 s). In round 59 (2026-10-24), **z8** (500 normalized / 315 raw
lines) returns directly to z3's architecture and evolves it with genuine
algebraic field elimination and zero bit-packing: it drops four `_Way`
fields (`fee`, `subs`, `credit`, `missing`), four `_Way` methods/getters
(`copy`, `empty`, `spent`, `used`), and `_letters`, reaches the top
battery accuracy of `0.9904 / 86.6%` (`costDiff 0` vs `z6`/`z7`), runs
the battery faster than `z3`, `z6`, and `z7` (`2,694 ms` AOT vs `2,711`,
`2,754`, `3,087 ms`), passes all gates, `props`, `pred`, `window`,
`_bits.dart`, `_bits2.dart`, and deep inputs (`293 ms` at depth 3,200),
and cuts `z3`'s fuzzer `worse` costs by ~4x (`101` vs `452` on `dl` 1-8)
and invalid trees by ~40% (`260` vs `431` across all 12,800 `dl`+`lf`
cases). The e line (2026-10-24, section "e-series" below) and f line
(section 10 below) search over repaired strings and parse each one:
e7s/e8/f25 have no invalid tree in 12,800 fuzzer cases and the fewest
worse costs, and f25 brings rung 64 down to 9.9 s by caching rule
results across parses, but they break D1/D2 by construction, fail gate
b2 and conformance (`0 1 1 0 2 2`), drop battery accuracy to 0.9899 /
84.5%, overflow the stack at depth 1,600, and grow to 1,132 normalized /
719 raw lines. In round 60 (2026-10-25, section 11 below), **z9** (792
normalized / 448 raw lines) resolves every issue identified in the z8
audit and f-series rounds: it eliminates 100% of bit-packing across the
entire engine (`_Way`, `_Cell`, `cell.mark`, and `first`), matches `z6`
and `z7` on all 2,101 battery trees (`0.9904 / 86.6%`, `treeDiff 0,
costDiff 0`), runs both the battery (`2,444–2,560 ms` AOT, `2,641–2,665
ms` standalone JIT) and rung 64 (`186 ms` AOT, `438 ms` JIT) faster than
`z6`, `z7`, and `z8`, and achieves the lowest fuzzer `worse` (`126` vs
`z7`'s `182` and `z6`'s `207` in 4-way; `324` vs `379` and `402` in
6-way with `e8`) and `invalid` (`89` vs `z7`'s `96` and `z6`'s `160`)
counts of any D1-compliant engine. In round 61 (2026-10-25, §11.6 below),
**z9** further reduces `_Way` from 10 bookkeeping fields + 3 AST fields
(13 total) down to **only 4 bookkeeping fields (`edits, used, evidence,
cut`)** + 3 AST pointers (`end, piece, prev`) and `_Cell` from 5 scalar
fields to **4 scalar fields (`mark, ver, dep, arm`)** + `ends`, with zero
bit-packing anywhere, deriving `deleted, spent, owed, subs, first, last,
incomplete` directly from the `_Way` tree using algebraic conservation
laws while preserving 100% identical battery and fuzzer trees (`treeDiff
0, costDiff 0`).
