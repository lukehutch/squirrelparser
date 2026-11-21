<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.20 Round 73: cross-review round 3, a price-based miss count, and a cost bound on each rung (z17)

**The metric.** levWorse (12.18, 12.19) counts cases where an engine's repaired string is
farther from the input by edit distance than the best engine's. It mixes two things: search
misses, and the choice among repairs of equal price. Even the exact search xrefmz (xrefm with
the z16 price, `squirrel-kit/dart/experiments/recovery/xrefmz.dart`) has levWorse 11 / 5. This
round's main count is priceWorse: the cases where the cheapest valid repaired string the
engine's tree admits has a higher z16 price than xrefmz's optimum. Drivers `_pdl.dart` and
`_plf.dart` (from Codex's `_r3dl` / `_r3lf`), runner `squirrel-kit/pf.sh`, 16 seeds x 400
cases, `LIMIT=30`. Invalid trees and timeouts are 0 for every engine below.

**Round 3** (brief `squirrel-xr/ur3/BRIEF3.md`). The user paused the round to save credit; the
Claude seat was stopped at about 40 minutes with a partial report, and Codex and Gemini finished.

| Engine | Source | Battery | dl / lf priceWorse | dl / lf levWorse |
|---|---|---|---|---|
| z16 | round 72 | 0.9902 / 86.4 | 33 / 26 | 100 / 76 |
| xrefp | exact, per-character price | - | 11 / 5 | 0 / 0 |
| opu9a | Claude: M raised to 1 when it is 0 | 0.9902, treeDiff 0 vs z16 | 9 / 6 | 76 / 56 |
| opu9d | Claude: opu9a + per-character cost before evidence in `cmp` | 0.9852 / 84.4 | 9 / 6 | 7 / 4 |
| sol6 | Codex | 0.9902, treeDiff 0 vs z16 | - | 100 / 76 |
| arg5 | Gemini | 0.9810 / 80.3, 11.6 s | - | - |
| arg6 | Gemini | 0.9902, treeDiff 2 vs z16 | 11 / 6 | 49 / 29 |

opu9d confirms 12.19's conflict again: ranking per-character cost first fixes most levWorse
cases and loses 54 battery cases (the reference prefers repairs that keep input, such as completing `1*(2+` at the
end rather than replacing the `+`). The levWorse count is mostly the tie-break, not the search.
arg6 changes z16's end price at M = 0 (an end run then costs nothing extra, where z16 charged
m + 1), counts the owed excess over M correctly in `then`, and adds one tie-break key; I did not
ablate these separately. Codex's two reported misses were confirmed: `S <- ("ccc" S)*` on `cc`
is the M = 0 case (arg6 fixes it), and `S <- "acaa" / 'a'` on `ca` needs a deletion before the
top rule, which no engine tried.

**From arg6 to z17.** Each step: battery against z16, all gates (accept, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0), then the price fuzzers.

| Engine | Change | Battery | dl / lf priceWorse |
|---|---|---|---|
| z17a | Seq filter on cost, not used + owed | 0.9902 | 6 / 4 |
| z17b | `charge` (cost + 1 for some absorptions) = cost | 0.9902, same trees | 6 / 4 |
| z17c | `trim` deleted | 0.9902, same trees | 6 / 4 |
| z17d | + root: the top rule read after each deleted prefix the rung can pay for | 0.9902 | 4 / 6 |
| z17e | + z16's cell acceptance test restored (arg6 had narrowed it; `cbbcc` 2 -> 1) | 0.9902 | 3 / 5 |
| z17f | z17e, leading reads lazy, cells cleared after them | 0.9902 | 6 / 10 |
| z17g | z17e, leading reads lazy, no clear | 0.9902 | 3 / 5 |
| z17h | z17c, cells cleared at the start of every rung | 0.9902 | 10 / 9 |
| z17i | z17g, a rung rejects an answer whose cost exceeds the rung | 0.9905 / 86.5 | 2 / 3 |
| z17l = z17 | z17i without the `used` part of that test | 0.9905 / 86.5, treeDiff 0 vs z17i | 2 / 3 |

**A rung could return an answer above its budget.** z16's root test was
`w.charge - w.cost + w.used + (owed term) > rung`: it bounded `used`, not cost. On
`S <- "ba" 'b'+ 'a'` with input `cbcaabbba`, z17f's rung 2 accepted a way with cost 4 and used 2,
and the doubling search stopped at rung 2 with cost 4, where rung 3 has a cost-3 repair. With
`w.cost > rung` as the test, no rung returns an answer above it, and the binary search between
the last failing rung and the first succeeding one is correct. This fixed `cbcaabbba`,
`cbcacaca` and `accabbcbc` (each 4 -> 3, = z17c), and it made the `used` part redundant: z17l
drops it with no tree change on the battery or the fuzzers.

**Cells depend on history.** Cells persist across the doubling rungs and are cleared only when
the binary search steps down, so what a rung finds depends on what earlier rungs left. Leftover
cells sometimes help: z17c found cost 3 on `cbcaabbba` that way. Clearing them before every rung
(z17h) or after the leading reads (z17f) is worse on the fuzzers (10 / 9 and 6 / 10 against 3 / 5).
So the search under a budget is not monotone in what it is given; it is a heuristic that the
rung structure happens to help.

**z17 against z16** (same-session runs; LOC by `awk 'NF && $1 !~ /^\/\//'`):

| | z16 | z17 |
|---|---|---|
| LOC | 562 | 565 (+3, +0.5%) |
| Fields per reading / cell / engine | 13 + one static / 7 / 17 | same; `charge` (getter) and `trim` (method) deleted, static helper `_ex` added |
| Battery | 0.9902 / 86.4, 3.9 s | 0.9905 / 86.5, 4.1 s |
| Gates | all pass | all pass |
| dl / lf priceWorse | 33 / 26 | 2 / 3 |
| dl / lf levWorse (against xrefp) | 100 / 76 | 58 / 32 (z17i's run) |
| dl / lf invalid, timeouts | 0, 0 | 0, 0 |

**The five remaining misses.** In each, xrefmz's repair either completes the input at the end
(an end run of at most M characters, price 1) after one interior edit, or edits the first
character:

| Grammar (after `S <- R0;`) | Input | xrefmz | z17 |
|---|---|---|---|
| `R0 <- ("cc" "acb" R0?) / R1?; R1 <- "caa"++ ('c' 'c')? ("ccca"+ 'c');` | `ccacbbcaac` | `ccacbcaacccccac` 2 | `ccacbccacb` 3 |
| `R0 <- 'a' ('b'* ('a' / R2) 'b'?) "bbaa"; ...` | `bbba` | `abbbabbbaa` 2 | `aabbbaa` 3 |
| `R0 <- ("babc"+ / R2*) / 'b'*; ...` | `babcbcabccbabc` | `cabcbcabccbabc` 1 | `abccbcabccbabc` 2 |
| `R0 <- "cbab" / ((R2 R1) (R0 R1)); ...` | `cabb` | `cabbccbab` 1 | `ccbabb` 2 |
| `R0 <- "ba"+? "acb" !(R0 / 'c');` | `cbab` | `babaacb` 2 | `baacb` 3 |

`squirrel-kit/out/wit17.exe ENGINES GRAMMAR INPUT` (from `_wit17.dart`) prints each engine's valid
repaired strings with their prices.

**Conclusion.** z17 replaces z16. Measured against the exact search under its own price, it
misses on 5 of 12,800 fuzzer cases (z16 59), with a slightly better battery and 3 more lines.
