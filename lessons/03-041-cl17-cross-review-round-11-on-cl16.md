<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl17 - cross-review round 11 on cl16: an edit-count key above cost 1, 796 -> 792 LOC (2026-09-24)

Round 11 ran a Claude subagent (Opus 5.5, high effort) on BRIEF11 (Q1 the 23
fuzzer cases where cdx1 is cheaper, Q2 bound independence on `acaca` and `aabb`,
Q3 invalid trees, Q4 family 43, Q5 what each part of cl16 buys against cdx1, Q6
review of round 10). Codex and Gemini had no quota (Gemini: "Individual quota
reached", Pro and Flash, until about Sep 29). The engine is untracked
`_cl17.dart` (kit name r11c17e): the seat's `cand` plus the orchestrator's
elegance review.

**What cl17 changes (confirmed from the diff against cl16).**
- **A new ranking key after the avoidable key**, applied only above cost 1:
  `if (a.cost > 1 && a.edits != b.edits) return a.edits - b.edits;` with
  `edits = spent + owed`. It compares within one cost class, so the ranking is
  still a lexicographic order and transitive. At cost 1 it does nothing, so a
  lone completion still pays one unit for everything it owes, which the battery
  needs (JSON and `stmt` truncations).
- **Three changes that change no result**: the `r.clean ||` part of the reach
  skip in `_first` was redundant (a clean reading never starts before `reach`
  once decided); the early `_evidence[m]` lookup in `_ev` duplicated the loop's
  `continue`; `_oneShape` is one memoized expression whose entry is `false`
  while the body is examined, so a clause that reaches itself has more than one
  shape.
- `lastCost = best.edits`; the header comment now lists the keys as the code
  has them (round 10's comment said "fewest completions", but the key counts
  owed characters).

**Measured (confirmed), kit r9/verify.** LOC 796 -> 792 normalized (-4,
-0.5%). Battery 0.9900/84.4, treeDiff 0 and costDiff 0 against cl16, 1,820-1,925
ms. Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0. Old fuzzer
invalid 2/2/4/6 (cl16 3/2/4/6), worse 0. No-repair 0. All 46 families finish
with cl16's costs (family 43 at 16,384: 40,842 ms, cl16 40,308). Stress and
rungs equal to cl16 within noise (errors 4,096 150 / 152 ms, left recursion
8,192 319 / 344 ms, 8000/4/7 5,817 / 5,946 ms, 1000/128/1 4,559 / 4,657 ms).

**Corrected fuzzer with cdx1 (confirmed).** "Worse" counts cases above the least
cost of the engines in the run, so each engine is compared in its own run:

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl16 (run with cdx1) | 8/6/8/4/7/7/8/10 = 58 | 2/1/6/2/0/6/4/2 = 23 | 2/1/4/2/0/1/3/2 = 15 |
| cl17 (run with cl16 and cdx1) | 8/5/7/4/7/7/6/9 = 53 | 1/1/5/2/0/5/3/2 = 19 | 1/1/3/2/0/1/2/2 = 12 |

cl17 is never costlier than cl16 on these 3,200 cases; all 19 remaining worse
cases are against cdx1. levSum is lower or equal on seeds 1-7 and one higher on
seed 8 (528 against 527). The five invalid trees fixed (s2 `acbcabca`, s3
`cabcca`, s7 `acaca`, s7 `bbacccab`, s8 `cacbbca`) are all an owing reading that
read farther and outranked a plain repair. cl17 has no invalid tree that cl16
lacks.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0; fuzzer seeds 1-8
differ only on seed 3 `aabb`. `acaca` is bound-independent: its owing reading
has edits 5 and the deleting reading edits 2, both at cost 2. `aabb` is an
exact tie on every key between two valid cost-1 trees (substitute `a -> b`, or
insert `b`), so `_Front.add` keeps whichever arrives first, and the bound
decides the order. Three tie-breaks were measured and each changes battery
trees: prefer deletion (treeDiff 8, the stray-`}` cases), prefer insertion
(treeDiff 85, JSON `{a":1`), first edit kind (treeDiff 611).
(2026-09-25: the deletion and insertion labels here are swapped, and
`_Front.add` does not keep the first of two equal readings; see the cl18
section.)

**The 23 cdx1-cheaper cases, traced by the seat (not all rechecked).**
- Fixed by the new key: 2 `bccab`, 5 `ccac`, 15 `cabaab`, 19 `acba` (confirmed:
  fuzzer counts above).
- Cost-1 lone completion against one deletion: 10, 11. Charging it (WR) loses
  the battery (0.9893).
- The reach skip in `_first` (8, 17); the opener guard, the avoidable demotion
  or the bound (3); the bound suppressing the diverse retry (14); an
  unexplained search gap (18). Each guard's knockout fixes its case and loses
  on other seeds.
- Case 6 is not a defect: cl16's rank cost is 3 against cdx1's 4; the fuzzer
  compares `lastCost`, which holds edits (7), not rank cost.
- Cases 1, 4, 7, 9, 12, 13, 16, 20-23: cl16's tree is invalid (the invalid-tree
  problem, not a ranking one).

**What each part of cl16 buys against cdx1 (the seat's knockouts, measured
there).** Every guard and policy that cdx1 lacks decides at least one seed of the
three-way fuzzer, or the battery, or speed: the cut guard, the opener guard, the
reach skip, the earlier-arm lead, keepFirst in ordered choice (without it the
battery rises to 0.9902/86.4 but 303 trees change and seeds 1, 2, 5, 8 lose),
the `_total` break, native plain reach, the departed filter in `_seq`, the
avoidable demotion (the `bab` case), the guard skip in `_resume`, `_stop`,
`_tail`, `later`, the sealed body in `_repeat`, resuming past unreadable
characters (worse 35-54 per seed without it), the requireOne block (0.9694
without it), the bound floor (40% slower battery), sealed-atom sharing (family
38 718 -> 1,927 ms without it), and each ranking key. The only knockouts inside
every target are the clean skip in `_view` (V1, 4 lines) and the exposed
filter (P3, changes 4 battery trees).

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r11c17e = cl17 | cand + comment fixes | trees = cand; 792 LOC | 9 | every target met; comments now describe the code |
| cand (Claude) | cl16 + edit key above cost 1 + three redundant parts removed | as above | 9 | 4 of the 23 cases and 5 invalid trees fixed, `acaca` bound-independent |
| cand + V1 (Claude) | the `_view` clean skip deleted | about 788 LOC; invalid 54, worse 1/1/5/2/0/4/4/2; battery treeDiff 0 | 8 | within every target, 4 lines fewer, but one more invalid tree than cand on s7; the case it gains (12) stays invalid |
| cand + P3 (Claude) | exposed filter deleted | 4 battery trees change; s3 and s7 gains lost | 6 | no line saving worth the loss |
| cand + S3 (Claude) | avoidable demotion deleted | 0.9904/84.9, treeDiff 51, fixes case 3; s4 levWorse 3 | 6 | fails levWorse (`bab`) |
| Y=M (Claude) | return-site bound from the start | trees and family costs equal; battery 4,080 against 2,288 ms, 1000/1/1 2.4x slower | 4 | bound-independent by construction, too slow on small inputs |
| DS2 (Claude) | `_Front.add` keeps no equal diverse readings | family 43 -18%; `bcba` becomes invalid | 3 | changes trees |
| OE, OE2, OE4, OE5, OE7 (Claude) | other edit-count keys, including at cost 1 | 0.9726-0.9899 | 0-3 | battery loss; the key must skip cost 1 |
| KD, KI, TK (Claude) | tie-breaks for `aabb` | treeDiff 8 / 85 / 611 | 1-2 | battery trees change |
| WR (Claude) | truncation against deletion | fixes 10, 11; 0.9893 | 1 | battery loss |
| EV = round 10's q1e | no evidence from resumed scans | 0.9899/84.3, treeDiff 15 | 2 | 8 battery cases lose |
| SB, SF, ST (Claude) | bound tests in `_seq` and `_first` | family 43 unchanged | 2 | no gain |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery 0.9900/84.4, treeDiff 0 vs cl16 | Claude | `bench.sh battery` BASE=r10c16e | confirmed |
| cand: every check equal to cl16, no-repair 0 | Claude | check.sh, norepair.sh | confirmed |
| cand: invalid 53, worse 19, levWorse 12 (three-way) | Claude | `_samedq` r10c16e cdx1 r11c17, seeds 1-8 | confirmed |
| cl16 baseline worse 2/1/6/2/0/6/4/2, levWorse 2/1/4/2/0/1/3/2 | Claude | `_samedq` r10c16e cdx1, seeds 1-8 | confirmed |
| cand: never costlier than cl16 | Claude | the same runs | confirmed |
| cand: `acaca` bound-independent, `aabb` not | Claude | det.sh | confirmed |
| cand: families, rungs, stress equal to cl16 | Claude | sweep3.py, rungs.sh, stress.sh | confirmed |
| `aabb` ties on every key | Claude | read the two readings in the report | consistent, not rerun |
| round 10: `acaca` needs a cost model the battery rejects | Claude (r10) | the new key fixes it at treeDiff 0 | wrong |
| round 10: q1e loses the stray-`}` cases | Claude (r10) | seat reran it: treeDiff 15, also i=734, 756 | confirmed (was unsupported) |
| round 10: 58 invalid split 26/18/10 + 4 | Claude (r10) | seat reran it: 26/18/10/3/1 | confirmed (was unsupported) |
| cl16 section: a guard discards the cheaper reading | orchestrator | seat's trace | partly wrong: 4 cases come from the ranking, 1 is not a defect |
| the knockout table in Q5 | Claude | not rerun, except that cand's numbers match | unsupported by my check |

**Open items.**
- 19 fuzzer cases where cdx1 is still cheaper; 11 of them are invalid trees in
  cl17.
- `aabb`: an exact tie decided by arrival order. A tie-break that keeps the
  battery has not been found.
- Family 43 (41 s at 16,384). `_rejected` is one global flag: any bad or
  departed reading in any rung sends `recover()` into the whole diverse ladder.
  A flag that records whether the rejected reading could have beaten the found
  one is the likeliest tree-preserving speedup (inferred, not built).
- `lastCost` holds edits, not the rank cost; the name misleads (case 6).
- Size: 792 lines against cdx1's 616; V1 is the only measured deletion inside
  every target.

**Process lessons.**
- A cost model that failed when applied everywhere can pass when applied in
  one cost class. Round 10 rejected "charge owed characters" because it was
  tested at cost 1 too, where the battery's truncations live.
- An agent's orphaned process skews later timings: Gemini's round-9 run left a
  Dart VM running family 43 on cl14 for 4 h 55 min after the agent exited. Check
  `ps` after every agent exits.
