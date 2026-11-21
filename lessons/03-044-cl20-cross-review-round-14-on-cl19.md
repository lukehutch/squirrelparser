<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl20 - cross-review round 14 on cl19: 12 lines of rewrites, and three shorter conditions refused, 769 -> 757 LOC (2026-09-25)

Round 14 ran a Claude subagent (Opus 5.5, high effort) on BRIEF14, which again
put size first (Q1 the same trees with fewer lines; Q2 fewer lines with answers at
least as good, a function-by-function comparison with cdx1 and a knockout count
per guard; Q3 invalid groups C and D; Q4 the left-recursion fixed cost; Q5 review
of round 13). Codex and Gemini had no quota. The seat's final engine was 750
lines; cl20 is that engine with three of its rewrites reverted (below) and one
comment corrected. It is untracked `_cl20.dart` (kit name r14c20p).

**What cl20 changes (confirmed from the diff against cl19).**
- `_Relation`'s fields move into `_Front` and the class is deleted. The `log`
  list is `late final`, so a temporary front (in `_seq` and `_first`) never
  allocates it; with an eager list the seat measured errors 4096 22% slower in
  AOT.
- `default: throw` removed from `_Bound._build`: the switch covers every clause
  class the library defines. `Clause` is abstract, not sealed, so a clause class
  added later would get no edges without a compile error.
- `_read`'s `Optional` arm becomes the default arm (a cast).
- Declarations merged (`lastCost`, `width`), `atEnd` inlined, and `_first`'s
  lead check written as one positive condition.
- `r.end > pos` dropped from the seed sealing in `_seq` (a tree change, below).

**Refused: three rewrites that change no measured answer but drop a stated
condition (7 lines).**
- `if (r.spent > budget) continue;` in `_view`. Budgets differ within a rung
  (`_read(slot, r.end, budget - r.spent)`), and a cell grown at a larger budget
  is viewed at a smaller one (`cell.budget >= budget`). Without the filter, a
  read returns readings above its budget, and `_first` computes `reach` from
  them.
- `r.spent < budget` on the substitution in `_seq`: without it an over-budget
  reading enters later slots, spends `_allowance` and can set `_rejected`.
- `stop == r.end` in `_resume`'s guard: without it the guard fires where the
  reading has moved past the stop. The seat counted the condition false 55 times
  over the battery and both fuzzers.
The seat measured all three together: 4 over-budget bad readings reach
`_Front.add` and no answer changes. My check: the 750-line engine (r14c20) and
cl20 give identical trees on the battery and both fuzzers, seeds 1-8. They are
refused because an equivalence that holds only on the test sets makes the code
state less than it does; "a read returns readings within its budget" is an
invariant the callers use.

**The one tree change (confirmed).** Corrected fuzzer s1 `bbbcb`, grammar
`R0 <- (R1? / ('b' 'b'* R0?)); R1 <- (R0 (R0? 'c'? 'b'))`: both engines insert `b`
at 5 (cost 1); only the tree shape differs, and both are valid (the seat's
`_samedqv` classification; the two-way run gives this as the only TREEDIFF).

**Measured (confirmed), kit r9/verify.** LOC 769 -> 757 normalized (-12, -1.6%;
raw 771 -> 760). Battery 0.9900/84.4, treeDiff 0 and costDiff 0 against cl19
(r14c20 1,866 ms). Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0
2 3, cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0 (run on
r14c20, whose trees equal cl20's). Old fuzzer treeDiff 0 against cl19 on seeds
1-8. Corrected fuzzer, three-way with cl19 and cdx1: invalid, worse, levWorse
and levSum equal to cl19's on every seed (50, 17, 10). No-repair 0. `det11.sh`:
only `aabb`. All 46 families finish with cl19's costs (family 43 at 16,384:
40,481 ms, cl19 41,415). Rungs equal (8000/4/7 5,836 against 6,122 ms).

**AOT timing (confirmed, `aot.sh`: `_stress.dart` compiled with `dart compile
exe`, 11 interleaved runs, medians in ms).**

| row | cl19 | r14c20 (750) | cl20 |
|---|---|---|---|
| errors 256 | 3 | 3 | 3 |
| errors 1024 | 12 | 13 | 11 |
| errors 4096 | 50 | 50 | 50 |
| lr 2048 | 34 | 35 | 35 |
| lr 8192 | 146 | 147 | 149 |

The spread within each cell is larger than the differences between engines.

**Findings from the seat (its measurements; the ones I reran are marked).**
- **JIT timing hides slowdowns of 20-35%.** The seat's 749-line candidate passed
  `stress.sh` in JIT and was 17% slower on errors 4096 in AOT; the cause was the
  eager `log` list and dropping the `c is peg.Terminal ? null :` guard in
  `_plain`. The left-recursion gap of round 13 (18 ms at 2,048 terms in JIT) is
  about 1 ms in AOT (medians 31 and 32 ms for cl18 and cl19): warm-up, not work.
  Timing claims now need `aot.sh`.
- **The seed sealing in `_seq` changes no tree but is needed for speed.**
  Deleting it and folding `_run` into `_sealed` gives a 733-line engine with the
  same trees, but lr 8192 takes 169 against 124 ms in AOT.
- **Knockouts (about 80 variants, one part disabled each).** No guard's cases
  are all fixed by another guard: every knockout either changes nothing (these
  became the rewrites), makes at least one answer worse, or fails another
  target. The largest effects: substitution in `_seq` (581 worse answers, the
  seat's BAD count), `_resume` in `_seq` (422), V1's plain witness (166, battery 0.9577), the
  `_first` reach rule (invalid 50 -> 114). cdx1's 153 fewer lines are these
  coherence rules, which keep cl19 at 50 invalid fuzzer trees against cdx1's 389.
- **noavoid** (the avoidable key and its demotion deleted, 728 lines): battery
  0.9904/84.9 (better), invalid 50, worse 16, but s4 levWorse 3 against 2 on
  `bab` (an evidence tie-break). One case short of the targets.
- **Group C `cbccbcb`**: a `Seq` of literals gets its whole text as its lead
  (bounded by the grammar), 757 lines on the 749 line: invalid 49, worse 16, but
  old s6 `ccacbc` goes 3 -> 4. A longer lead lets through a reading the shorter
  one blocked, so the search is not monotone in the lead's length.
- **Group D `bbcc`**: cl19's cost-1 answer (delete `b` at 0, giving `bcc`) is
  invalid under plain PEG, and a valid cost-1 answer exists (insert `c` at 0,
  giving `cbbcc`). cl19, w5 and cdx1 all miss it because `_repeat` seals the
  first occurrence of `("cb" / R0)`. Unsealing the first occurrence finds it but
  makes 21 other answers worse.
- **Q5, round 13's Q4 argument is wrong.** In 59 of 61 retries the least cost of
  a dropped bad reading is above the found cost: `_rung` sets `_rejected` before
  its cost filter, and the end skip can make the cost anything. The filter is
  still unsafe (14 answers worse), so the decision stands for a different
  reason. w11, w5 and w12 reproduce.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cl20 = r14c20p | 8 rewrites + seal_pos + comment | 757 LOC; one equal-cost valid tree change | 9 | every target; no condition dropped on test evidence alone |
| r14c20 (seat's final) | cl20 + 3 dropped conditions | 750 LOC; trees = cl20 | 7 | equal on every test, but a read may return readings over its budget |
| k13 (seat) | seed sealing deleted, `_run` folded | 733 LOC; same trees; AOT lr 8192 +36% | 4 | fails the speed target |
| noavoid (seat) | avoidable key deleted | 728 LOC; battery better; s4 levWorse +1 | 6 | one case short |
| k1, Q3 C (seat) | joined lead of a literal `Seq` | invalid 49; old s6 3 -> 4 | 4 | worse answer |
| k7, Q3 D (seat) | first occurrence unsealed | finds `bbcc` at 1; 21 answers worse | 1 | net loss |
| k10 (seat) | eager `log`, `_plain` guard dropped | 749 LOC; AOT errors 4096 +17% | 5 | JIT hid it |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| final: 750 LOC, battery treeDiff 0, all checks = cl19 | Claude | check20.sh r14c20 | confirmed |
| final: corrected counts = cl19 per seed; old treeDiff 0 on 8 seeds | Claude | the same run | confirmed |
| final: no-repair 0; det only `aabb` | Claude | norepair.sh, det11.sh on r14c20 and r14c20p | confirmed |
| one tree change, `bbbcb`, equal cost | Claude | two-way `_samedq` r13c19 r14c20p, seeds 1-8: one TREEDIFF | confirmed |
| subst_budget, view_spent, res_stop change no answer | Claude | r14c20 against r14c20p: treeDiff 0 on battery, both fuzzers, seeds 1-8 | confirmed on the tests; not proved (refused) |
| AOT times within noise | Claude | aot.sh, table above | confirmed |
| 46 families = cl19 costs | Claude | sweep3.py r13c19 r14c20p | confirmed |
| JIT hides a 17% AOT slowdown in k10 | Claude | not rerun | unsupported by my check |
| k13 same trees, AOT lr 8192 +36% | Claude | not rerun | unsupported by my check |
| knockout matrix, noavoid, Q3 C and D, Q5 | Claude | not rerun | unsupported by my check |

**Open items.**
- Size: 757 against cdx1's 616. The knockouts say the difference is coherence
  rules; a smaller engine needs a rule that implies several of them, which three
  rounds have not found.
- noavoid is one case (`bab`) from a 29-line saving with a better battery.
- Group D: a way to try the first occurrence's insertions at `pos` without
  unsealing it (conjectured, not built). Group C: a lead that is monotone.
- The seed sealing in `_seq` is kept for speed only (33 lines' worth with
  `_run`); a cheaper way to get the same sharing would be a real saving.
- `_Front` now carries growth fields that temporary fronts never use.

**Process lessons.**
- Time with AOT (`aot.sh`), not JIT, when deciding a speed target: JIT warm-up
  both hides real slowdowns and invents fixed costs.
- A rewrite that drops a condition is accepted only with an argument that the
  condition is implied; "no test changes" is not enough when the condition
  states an invariant other code reads.
