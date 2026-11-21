<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.50 Frontier series, round F1: z47, fewer fields, half the fuzzer gap to the exact engine

**Objective.** Combine the engines that hold or come close to each record, with bookkeeping and the logic using it as small as
possible (quoted in the history of the series). Directory `vf1`; three agents; checks in `checkF1.sh`.

**Result.** z47 = vmf1d: Gemini's vgf1, Claude's fix for `S <- [^ ]+;` on `" "`, Codex's stop after a First arm that always
succeeds, and four engine fields (`_depth`, `_seedDepth`, `_rung`, `_local`) turned into parameters or `up.mark`. Beside z46: fields 15 -> 10
(3 way, 3 cell, 4 engine), bookkeeping lines 54 -> 37, 477 -> 497 formatted LOC (+20, +4.2%), priceWorse 42/24 -> 21/13, exhaustive
52 -> 0. Battery 0.9896/85.1 (record 0.9907/86.6), every hard check. priceWorse is still above z37a's 0/0. Time beside vm13b in one run: dense 0.84, semi3 0.96, long sets 0.86, Dyck 0.90,
battery 0.78. Machine load was 20-23 for part of the round, so only ratios from one run mean anything.

**What taught something.**
1. A First arm that provably always succeeds makes later arms unreachable, and this alone takes exhaustive 26 -> 0 and priceWorse
   29/14 -> 21/13 for 26 lines. The proof must reject references on a cycle: `A <- A / 'x'?` returns a failing seed at the recursive
   call, so without `_acyclic` `S <- A 'y'` on `xyz` costs 2 against 1 (vmf1e, refuted).
2. Fields can become parameters at no measured cost, but this moves lines: bookkeeping lines rose 30 -> 37 from vmf1b to z47 while
   fields fell 13 -> 10.
3. The count of 10 is too low by the series' own rule, under which a bit-packed integer counts as the fields it holds: `mark` packs budget
   and stamp, so z47 is at least 11. `_cells` also has three key kinds, `_mins` two, and the sign of `dep` is a flag. Open (F1-26).
4. Two suite timeouts on z47 were the checker, not the engine: on one 100-character T input the engine takes 19 ms and witness
   enumeration over 55 s. Limits raised (T 120 -> 200 s, rule naming 240 -> 360 s). This is a flaw in the checker; fixing it is open (F1-5).
5. Gemini's reported exhaustive 7 was in no log (26).

**Engine count to date (reported to the user).** 2,332 distinct engine files on disk; 262 more only in git history;
423 named in LESSONS; 2,402 distinct engine contents on disk, 2,664 including git; 2,972-3,017 attempts counting
every agent run and the attic.
