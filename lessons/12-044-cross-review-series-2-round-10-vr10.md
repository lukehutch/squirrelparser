<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.44 Cross-review series 2, round 10 (vr10): a two-child join, two constants gone, and z42

**The round.** Base z41 = kit `vg9`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr10/BRIEF10.md` (settle the summary node's second meanings, try vc9r5's
deletions on vg9, attempt shared lookahead edits). Engines:
- Gemini `vg10` (522): `prev` becomes a pair `(_Way, _Way)?`, the left and right sides of a dirty join, so `owed`,
  `first` and `_allSub` are read by walking the tree and the summary node with second meanings is gone; `_per` and
  `_exactPer` deleted (every work limit is a multiple of `_floor`); the First-choice `cut`, `_repeat`'s `done` set
  and second queue slot deleted; the deep-input sweep seeds the memo every 64 positions instead of every position.
- Claude `vc10k2` (530): vg9 minus `_seq`'s terminal contiguity test and the field `sure`, keeping the summary node.
- Codex `vx10a` (535): passes, but Codex itself rejects it because it keeps summary facts in the node (R9-4); its
  honest three-field `vx10` (552) fails speed.

Logs: `squirrel-xr/vr10/kit/out/suite_o10_{vg10,vc10k2,vx10a}.txt`, `vr10/orch/la_*.txt`. Reports:
`vr10/{claude,codex,gemini}/R10_*.md`.

**Results beside vg9** (orchestrator runs, one engine at a time; every engine: no FAIL line in `suite.sh`, all gates
pass, invalid 0 on pdl, plf and dense, class fixtures 0, wild 0, exhaustive g1/g2/g3/g5 0, long sets 0 of 1,800 more
expensive than z37a):

| Check | vg9 (z41) | vg10 (Gemini) | vc10k2 (Claude) | vx10a (Codex) |
|---|---|---|---|---|
| formatted LOC | 542 | **522** | 530 | 535 |
| counted `_Way` fields | 3 | 3 | 3 | 3 (+ summary facts) |
| constants | 4 | **2** | 2 | — |
| battery score, treeDiff | 0.9896 | 0.9896, 28 | 0.9896, 0 | 0.9896, 28 |
| pdl / plf priceWorse | 27 / 15 | 36 / 21 | 36 / 20 | 36 / 21 |
| exhaustive g4 worse | 40 | 40 | 40 | 40 |
| semi / semi3 above the optimum | 0 / 0 | 0 / 0 | 1 / 2 | 1 / 3 |
| group3 above / group5 grouping, naming | 0 / 0, 0 | 0 / 0, 0 | 2 / 2, 1 | 3 / 2, 2 |
| T family above, excess | 7, 42 | **5, 39** | 5, 39 | 5, 39 |
| Dyck more expensive than z37a | 0 | 0 | 3 | 3 |
| lookahead set / class-predicate fixtures invalid | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| dense ms (engine / vg9, same run) | — | 3,533 / 10,312 | 3,355 / 6,365 | 2,812 / 6,687 |
| long sets ms (engine / vg9) | — | 9,181 / 10,413 | 5,933 / 5,691 | 4,846 / 5,698 |
| Dyck ms (engine / vg9) | — | 8,139 / 8,611 | 3,927 / 4,395 | 3,389 / 4,189 |

**R10-1: vg10 becomes z42** (`_z42.dart`, byte-identical to `vr10/kit/.../vg10.dart`). 542 -> 522 formatted LOC (-20,
-3.7%), three way fields, constants 4 -> 2 (`_cap 2`, `_floor 4096`). It is the only finalist with no accuracy loss
against vg9 on the exact-optimum families, and it improves the T family (excess 42 -> 39). The fuzzer priceWorse rises
27/15 -> 36/21 (limit 42); all three finalists show the same rise, so it comes from deleting `_exactPer`, not from the
pair. Gemini's ablations (its report, B.1) show each tree walk is needed: reading `first`, `owed` or `_allSub` from the
right-most leaf only breaks dense, semi3 or group4.

**R10-2: vg10 grows faster than linearly at k = 16,384** (orchestrator, confirmed; the suite stops at k = 1,024, so no
suite check saw it). Dense `(1+`, time at k = 4,096 and 16,384:

| Family | vg9 | vg10 | vc10k2 | vx10a |
|---|---|---|---|---|
| `E <- T ('+' T)*`, `(1+` | 3.3 s, 13.3 s | 2.5 s, **30-34 s** | 5.5 s, 21.8 s | 4.6 s, 18.3 s |
| `E <- E '+' T / T`, `(1+` | 1.6 s, 7.3 s | 1.1 s, 9.5 s | 1.6 s, 7.1 s | 1.8 s, 7.2 s |

vg10's ratio per 4x is about 12 on the first family where vg9's is 4. Ablations on vg10, each one change, first family
at k = 16,384: sweep every position instead of every 64 (`vg10p`) 55 s; every 8 or 16 positions 41-44 s; the First
`cut` restored (`vg10c`) 45 s; vg9's length-scaled work limits restored (`vg10l`, `vg10m`) 44-48 s. None of them is the
cause. Peak memory is lower than vg9's (1.0 GB against 1.5 GB), so it is not memory. Inferred, not yet tested: the
recursive getters. `first` walks the left spine of the pair tree and `_allSub` walks the whole tree until it meets a
leaf that is not a substitution, so on a long chain of joins each read costs time proportional to the chain. A test:
count getter recursion steps per input at k = 4,096 and 16,384. vg10 is also 1.9x vg9 on `E <- E '+' T / T` with
`1+)` at k = 4,096 (0.6 s against 0.32 s).

**R10-3: vg10 is the only engine that answers `1+)` at 6,000 characters and more.** On `E <- E '+' T / T` with
`1+)` at k = 6,000 and 8,192, vg9 and vc10k2 return cost 0 on the plain path in 0.2-0.6 s, which is no repair at all;
vg10 returns a checked repair of the optimal price (6,000 and 8,192) in 1.1 and 2.0 s. At k = 16,384 every engine,
vg10 included, returns cost 0 on this family and on `E <- T ('+' T)*` with `1+)`. This is a pre-existing failure,
not new. The 64-position sweep is not what lets vg10 finish: `vg10p` (sweep every position) also answers k = 8,192
(cost 8,192, 2.0 s). Which of vg10's other changes does is not yet known.

**R10-4: long-zero predicate inputs fail in every finalist.** `S <- &[a-z] [^a] . '0';` on 10 zeros: vg10, vc10k2
and vx10a all return cost 10 with valid=false (130-150 ms), as z41 did; on 40 zeros, valid=false in 1.4-1.6 s.
Codex's round-9 vx9q returns valid trees of cost 8 and 38 in 2-3 ms. The fallback's 4,096-string cap is reached
before depth 2 on these inputs (inferred from the times). This becomes a hard check in round 11.

**R10-5: other findings, checked.**
- Codex's corrections of Gemini's round-9 report: archived vx8 has no packed `int s` (grep, confirmed);
  `S <- 'a' !'a';` on `a` is cost 0, valid (vg10 run, confirmed), so it is not an empty language, and no
  `empty_lang` fixture is in `cpfix.json` (confirmed); sequence associativity holds with a predicate, option or
  repetition child, and the unary exception is this algorithm's normalization (R5-2) (Codex's reading of the
  library, not re-derived). Recorded in Gemini's error list.
- Codex: vg9's one-line `cmp` has the stated sign only when the evidence difference times 2^30 does not overflow
  (`tools/cmp_check.dart`, a counterexample at difference 2^33). Not reachable on inputs below 2^33 characters.
- Claude: the round-9 linearity check (time at k = 1,024 over time at k = 256) penalizes an engine that is fast at
  k = 256. Accepted: round 11 replaces it with times at k = 4,096 and 16,384 compared with vg9's (R10-2).
- Claude: Gemini's argument that the left-to-right fallback reaches every string within each edit distance has a
  gap at the `seen` set (a string first reached with a late first index keeps it). Claude's model of the search
  (`tools/fbcheck.py`) finds 0 misses on alphabets {a,b} up to length 5 and {a,b,c} up to length 4, with a negative
  control that does miss (68). Corroborated, not proved.

**R10-6: elegance review of z42.**
- Fixed since R9-4: no field has a second meaning; `prev` is a pair of real ways, and `cmp`, `_plain` are one
  expression each.
- New cost of that: three getters (`owed`, `first`, `_allSub`) recurse through the tree, and `then` rebuilds pairs
  in two places to keep the owed suffix on the right (`then` lines 30-33). These are the likely cause of R10-2.
- The deep-input sweep's stride 64 is a fourth unexplained constant beside `_cap`, `_floor` and the `<< 6` in the
  last refinement's limit.
- `throw StateError('')` and `on StateError` replace vg9's private `_Stop`; a `StateError` from a library bug is now
  caught as a work-limit stop. A pre-existing class of risk made wider; the private class cost 2 lines.
- `_Way.maxOwed` and `_Way.len` are still static and mutable (R9-4).

**R10-7: verdicts.** None says no further improvement is possible. Codex: no lower bound is proved for fields, size,
speed or the fallback. Claude: the fallback (36 lines) is the largest removable part; the linearity check is flawed.
Gemini: three way fields is minimal (conjectured) and vg10 is within 3-6 lines of the smallest it can see.

**Direction for round 11.** Start from z42. Hard checks added: dense `(1+` at k = 4,096 and 16,384 and `1+)` at
k = 4,096 and 8,192, each within 1.5x of vg9's time (or a checked answer where vg9 has none); long-zero predicate
inputs (10 and 40 zeros) valid. Find and fix the cause of R10-2 without adding way fields; fix R10-4 inside the
fallback's budget.
