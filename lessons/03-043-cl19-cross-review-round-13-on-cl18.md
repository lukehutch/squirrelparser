<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl19 - cross-review round 13 on cl18: 27 lines shorter, and the growth exemption in `_tail` narrowed, 796 -> 769 LOC (2026-09-25)

Round 13 ran a Claude subagent (Opus 5.5, high effort) on BRIEF13, which put
size first (Q1 the same trees with fewer lines; Q2 fewer lines with better
answers; Q3 invalid-tree groups C and D; Q4 family 43 without changing a tree;
Q5 review of round 12). Codex and Gemini had no quota. The engine is untracked
`_cl19.dart` (kit name r13c19), the seat's final `cand` unchanged.

**What cl19 changes (confirmed from the diff against cl18).**
- **Rewrites that change no answer**, 796 -> 768 normalized lines:
  `_Relation` extends `_Front` (the `front` field and `_Front.diverse` go;
  `key` reads the search's mode, which is safe because no front outlives a
  rung); one `exit` array in the bound build (-2 before a state's first exit,
  -1 once it has a priced exit or a second one) in place of `out` and `exit`;
  `lastCost = 0` removed (a new `Recovery` starts at 0); the ladder's loop
  condition as one expression; `_first` indexes its arms instead of keeping an
  `earlier` list, and computes `reach` with `_farthest` over the arm's readings
  and its plain reading (a plain reading is always preferred); `_resume`'s
  loop, `_next`, `_tail`, `_ev` and `_covered` shortened; `_Front.ways`
  removed.
- **The growth-counter reset in `_rung` is removed.** When `_Spent` is thrown
  mid-growth, `_depth`, `_low` and `_since` keep stale values into the next
  rung. This is safe (argued, and the 46-family sweep exercises the throw):
  every growth sets `_low` to `_never` on entry and decides `usedSeed` from
  its own reads; depths are compared only with each other, so an offset in
  `_depth` changes nothing; and the top cell is the shallowest, so the stale
  `_low` and `_since` it restores are never read.
- **`_tail` exempts a stop only if its body's cell is growing and used a seed**
  (`_active && _usedSeed`, +1 line). cl18 exempted every stop whose body's cell
  was growing when the lazy guard ran. One corrected-fuzzer tree changes, s8
  `R0 <- ((R0* 'a') / (("cb" R0) / R0?))` on `cbaa`: cl18 inserts `a` at 4
  (cost 1, invalid: plain PEG reads `cbaaa` differently), cl19 deletes `a` at
  3 (cost 1, valid).

**Measured (confirmed), kit r9/verify.** LOC 796 -> 769 normalized (-27,
-3.4%; raw 798 -> 771). Battery 0.9900/84.4, treeDiff 0 and costDiff 0
against cl18, 1,848 ms. Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16,
conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P, pred
falseAssertions 0. Old fuzzer treeDiff 0 against cl18 on seeds 1-8. Corrected
fuzzer two-way against cl18, seeds 1-8: one differing tree (`cbaa`). No-repair
0. `det11.sh`: only `aabb`. All 46 families finish with cl18's costs (family
43 at 16,384: 41,517 ms, cl18 40,813). Stress and rungs within about 10% either
way; left recursion at 2,048 terms is 18 ms slower in three reruns (195-199
against 176-182 ms) and equal at 8,192 (348-361 against 343-358 ms), so the gap
is a fixed cost, not a growing one (cause not found).

**Corrected fuzzer, three-way with cl18 and cdx1 (confirmed, one run).**

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl18 | 7/5/7/4/7/6/6/9 = 51 | 0/1/5/2/0/5/3/2 = 18 | 0/1/3/2/0/1/2/2 = 11 |
| cl19 | 7/5/7/4/7/6/6/8 = 50 | 0/1/5/2/0/5/3/1 = 17 | 0/1/3/2/0/1/2/1 = 10 |

levSum is one higher on s8 (529 against 528).

**Group C, traced by the seat (its measurements, not rerun here).**
- Round 12's conjecture for `cbaa` is wrong: deleting the `_usedSeed` line in
  `_stop` does not fix it and raises worse to 57. The cause is the `_active`
  exemption in `_tail`, fixed above. Removing that exemption outright (w11)
  also fixes `cbaa` but leaves old-fuzzer s7 `aaaaa` with no repair (cost 5
  against 3). `same.sh` screens only old seeds 1-4, so it missed this: guard
  changes need all eight old seeds.
- `cbccbcb` has a different cause: `('c' 'b')` is a `Seq` of two `Char`s, so
  its reading carries the lead `c`, not `cb`. Joining adjacent leads (w12)
  fixes it but never finishes on s1 and s6, because owed insertions at the end
  cost 1 however many there are and the lead grows without limit.

**Negative results (the seat's measurements).**
- Group D (w5, 774 LOC): a later First arm whose first edit deletes at `pos`
  stands only if no earlier arm matches the repaired text. Fixes `ccaab` and
  three more (invalid 48, worse 17), but s1 `bbcc` goes 1 -> 2, where cl18's
  cost-1 answer is valid only through the substitution fill.
- Q4: "a dropped bad reading could outrank the found answer" (cost at most the
  found cost) is always true where the flag is read, so it filters nothing
  (argued: the flag comes from the last failing rung, at budget found - 1, and
  every reading there passed `spent + bound <= budget`). A bound filter loses
  old s3 `caab` (2 -> 3). No sound condition cheaper than the diverse retry
  itself was found.
- No merge of `_starts`/`_finishes`, `_stop`/`_tail` or the two bound forms.
- On top of w11: V1 deleted (+1 invalid on s7), `_usedSeed` dropped from the
  `_first` lead check (worse 21), reach from `_plain` only (worse 122), the
  requireOne block deleted (0.9694), `_scan` zeroing deleted (0.9878).

**Elegance review.** In cl19's `_tail`, `_usedSeed` of a growing cell reads
`usedSeed` from its previous growth: on a cell's first growth in a rung the
test is `active && recursive`, on a regrowth (which happens only because
`usedSeed` was set) it is `active`. The variant that tests only `active &&
recursive` (r13c19e, a `regrowing` getter and a shared `_cell` lookup) keeps
every tree on the battery and both fuzzers, seeds 1-8, but is 771 lines. Not
adopted; the size goal decides a tie in trees.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cand = cl19 | w1 + `_tail` exemption `_active && _usedSeed` | 769 LOC; invalid 50, worse 17; one tree better | 9 | every target met; left recursion 2,048 +18 ms fixed |
| w1 | rewrites only | 768 LOC; trees = cl18 | 8 | same trees, `cbaa` still invalid |
| r13c19e (orchestrator) | exemption `active && recursive` | 771 LOC; trees = cl19 | 7 | states the rule exactly, 2 lines more |
| w5 | group D rule | 774 LOC; invalid 48; s1 `bbcc` 1 -> 2 | 5 | fails the per-seed target |
| w11 | `_active` exemption removed | 767 LOC; no-repair 1 (old s7) | 2 | fails target 1 |
| w9 | diverse retry only when nothing found | family 43 halved; 7 + 5 trees change | 2 | changes trees |
| w2, w3 | narrower `_rejected` | vacuous / old s3 loss | 1-3 | no gain |
| w12 | joined leads | hangs on s1, s6 | 0 | does not finish |
| w4 | `_usedSeed` in place of `_active` | invalid 53, worse 20 | 1 | fails target 3 |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: 769 normalized LOC | Claude | `bench.sh loc`: raw 771, normalized 769 | confirmed |
| cand: battery treeDiff 0, costDiff 0, all checks = cl18 | Claude | check19.sh r13c19 | confirmed |
| cand: one corrected-fuzzer tree differs (`cbaa`, cost 1 both, now valid) | Claude | two-way `_samedq` seeds 1-8 against cl18: one TREEDIFF | confirmed |
| cand: invalid 50, worse 17, levWorse 10 | Claude | three-way run | confirmed |
| cand: old fuzzer treeDiff 0 on seeds 1-8 | Claude | check19.sh (seeds 1-8) | confirmed |
| cand: no-repair 0; det only `aabb` | Claude | norepair.sh, det11.sh | confirmed |
| cand: 46 families, costs = cl18 | Claude | sweep3.py r12c18e r13c19 | confirmed |
| growth-counter reset not needed | Claude | code reading (above) and the sweep | confirmed by argument |
| cold left-recursion rows 5-20% slower, JIT | Claude | three reruns: +18 ms at 2,048, none at 8,192 | gap confirmed; cause unconfirmed |
| Q4 condition vacuous | Claude | read `_ladder`: `rejected` is taken from the last failing rung | confirmed by argument |
| group C `cbaa` cause, `cbccbcb` cause, w5, w12, w11 results | Claude | the `cbaa` fix confirmed through cand; the others not rerun | partly confirmed |
| round-12 claims rerun (cand_free s3/s4, family 43 timing, V1) | Claude | not rerun by me; the seat's reruns agree with round 12 | unsupported by my check |

**Open items.**
- Size: 769 against cdx1's 616.
- Invalid groups B, C (`cbccbcb`: a lead joined across a `Seq` of literals,
  bounded by the grammar, not built) and D (w5 without the `bbcc` loss).
- Family 43: about half its time in the diverse retry.
- `aabb`, an exact tie; `lastCost` holds edits, not the rank cost.
- The guard's `_active` test depends on when the lazy guard runs (pre-existing).

**Process lessons.**
- A guard change must be screened on all eight old-fuzzer seeds: w11 passed
  seeds 1-4 and lost a repair on seed 7.
- A constant timing gap that vanishes at larger n is a fixed cost; rerun at two
  sizes before calling it a slowdown.
