<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl26 - cross-review round 22 on cl25: after an edit, owed characters are edits, 871 -> 889 LOC (2026-09-26)

Round 22 ran a Claude subagent (Opus 5.5, high effort) on BRIEF22 (Q1 the
owed-completion price; Q2 the families cl25 made slower; Q3 kind D; Q4 size;
Q5 review of round 21). Codex and Gemini had no quota. The engine is untracked
`_cl26.dart` (kit name r22k): the seat's `cand` (j8) with one comparator line
deleted and the cost getter rewritten by the orchestrator.

**What cl26 changes (confirmed from the diff against cl25).**
- Price. cl25 charged `spent + (owed == 0 ? 0 : 1)`: characters owed at the
  end of input cost 1 together, whatever else the reading did. cl26 charges
  `spent > 0 ? edits : owed.sign`: a reading whose only edits are owed
  characters costs 1, and any other reading pays 1 per edited or owed
  character. The lone-completion price stays because the battery needs it: the
  seat's j1 (`spent + owed` everywhere) scores 0.9699/75.8 with 220 costs
  changed, all JSON and `stmt` truncations (seat's figure, not rerun).
- Guard. The stop guard in `_Way.then` tested only a reading's `lead`, the
  first inserted literal. For a reading that only owes characters it now tests
  `owing`, all the text the reading inserts, collected from its zero-width
  terminal matches.
- Seed exemption. `_stop` no longer exempts a stop that used a seed when it is
  at the end of input (`pos < _len`).
- Deleted line (proved dead). `_compare` had
  `if (a.cost > 1 && a.edits != b.edits) return a.edits - b.edits;`. Under the
  new price, a cost above 1 means `spent > 0`, so cost equals edits for both
  readings; equal costs above 1 therefore mean equal edits, and the line never
  decides. Deleting it changes no tree in the battery or any of the 24 fuzzer
  runs (confirmed: r22k against j8, treeDiff 0 everywhere).

**Measured (confirmed), kit r9/verify.**
- LOC 871 -> 889 normalized (+18, +2.1%); j8 890.
- Battery 0.9900/84.5, treeDiff 0, costDiff 0 against cl25. Every other check
  as cl25: accept, freespan, recommit 16/16, conformance, props, window, pred.
  No-repair 0; determinism: only `aabb` depends on the bound.
- `_samedw`, seeds 1-8: invalid 7/5/5/4/7/6/5/10 = 49 against cl25's 50 (seed 3
  6 -> 5); worse 9 against cl25's 19 in the same three-way run; levSum lower or
  equal on every seed.
- `_samew`: invalid 38 against 39 (seed 3 6 -> 7, seed 6 3 -> 2, seed 7
  7 -> 6); worse 1 against 5. `_same`: worse 0 on every seed against 6.
- The new invalid tree is `cbbb` under
  `S <- R0; R0 <- ((R0 / 'b')? R2 R2); R1 <- (R0+* / R0*?); R2 <- ('b' / (R2 / 'b')+);`
  (seed-3 change confirmed; the mechanism is the seat's). Under cl25's price a
  valid reading (delete `c`, owe 2) and an invalid one (delete `c`, owe 1) both
  cost 2 and the ranking takes the valid one. Under cl26's price the valid one
  costs 3. The invalid tree leaves `(R0 / 'b')?` empty before the deleted `c`
  although `b` follows it: kind D, which the price exposes rather than causes.
- Families: all 46 costs equal cl25's. Two families differed by more than 12%
  in one sweep run (11 and 22); family 11 re-timed three times is 655 vs 644 ms
  (noise). Families 16, 18, 19, 28, 31 and 2 at 16,384, three-run medians
  (cl24 / cl25 / j8, ms): 1,619/1,836/1,891, 1,975/2,249/2,283,
  1,641/1,853/1,869, 1,724/1,989/1,906, 1,743/2,053/1,978, 855/734/757.
- AOT stress, medians (cl24 / cl25 / cl26): errors 4,096 48/49/49, lr 2,048
  35/35/34, lr 8,192 130/130/133. Rungs 0-5% slower than cl25 (8000/4/7
  5,675 -> 5,871 ms), costs equal. The deep and multi-error shapes (k = 2, 8):
  within noise of cl25, same depth.

**Negative results (the seat's, not rerun).**
- The guard alone (j5) leaves `aba` invalid with a different tree; the price
  alone (j7) leaves it invalid and exposes `cbbb`. Both parts are needed.
- Without the price (j6: guard and exemption only), `ccacbc` under a seed-6
  `_same` grammar costs 4 where cl25 and cl26 cost 3 with a valid tree
  (confirmed: j6 worse on one `_same` seed-6 case).
- Q2: the extra work in families 16, 18, 19, 28 and 31 is the second front
  entry per position that the `~pos` key keeps (counters identical for v2, cl25
  and j8; rungs unchanged). In family 2 the collision trigger costs one diverse
  rung. j17 (key apart only where a `+` can take the insertion) restores cl24's
  times on 16, 19, 28 and 31 but adds the invalid tree `bbc` (`_samew` seed 4)
  and 43 lines.
- Q3, kind D: a test at the deletion ("the stopped body reads the text after
  the deleted span", j19) fixes one of the four cases and adds seven invalid or
  costlier trees. For cases 5 and 18 no test at the deletion can be exact: the
  body's match in the repaired string runs across a later edit that does not
  exist when the stop and the deletion are joined (the seat's proof from the
  trees). An exact test must wait until the body's match region is decided.
- Q4: one key (`repaired > pos`) cannot replace the `~pos` key and the
  collision trigger: without the trigger (j13) and with it (j14), `cab` returns
  on `_samedw` seed 2 and `cbbb` and `aca` appear on `_samew` seed 3.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r22k = cl26 | j8, dead comparator line deleted | 889 LOC; trees = j8 everywhere | 8 | j8's gains, one line shorter |
| j8 = cand (Claude) | owing guard + `pos < _len` + per-character price after an edit | 890 LOC; `_samedw` 49, worse 9; `cbbb` invalid | 7 | same trees as cl26 |
| j6 (Claude) | guard and exemption, cl25's price | `_samedw` 49; `ccacbc` 3 -> 4 | 6 | loses a case |
| cl25 unchanged | none | 871 LOC; `aba` invalid | 6 | more invalid and worse trees |
| j5, j17 (Claude) | guard only; `~pos` only under `+` | `aba` invalid; `bbc` invalid (seat's figures) | 4 | each loses a case |
| j7 (Claude) | price only | `aba` invalid, `cbbb` invalid (seat's figures) | 3 | exposes kind D, fixes nothing |
| j10, j15, j16, j18, j19 (Claude) | resume-check and deletion-test variants | no kind-D tree fixed, or new invalid trees (seat's figures) | 2 | lose cases |
| j2, j3, j4, j9, j13, j14 (Claude) | size and single-key variants | invalid trees return (seat's figures) | 1 | lose cases |
| j1, j11 (Claude) | `spent + owed` everywhere; others | battery 0.9699/75.8 for j1 (seat's figure) | 0 | fails the battery |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| j8: battery treeDiff 0, every check = cl25 | Claude | check26.sh r22j8 | confirmed |
| j8: `_samedw` 49, `_samew` 38, `cbbb` new on seed 3 | Claude | check26.sh r22j8 | confirmed |
| j6: `_same` seed 6 worse by one case | Claude | check26.sh r22j6 | confirmed |
| family 18 slower in cl25 than cl24 | Claude | fam5.py, three runs | confirmed |
| j8 timing = cl25 | Claude | fam5.py, sweep3.py, aot.sh, rungs.sh | confirmed |
| counters: v2 = cl25 = j8 on the slow families | Claude | not rerun | unsupported by my check |
| j1 battery 0.9699/75.8 | Claude | not rerun | unsupported by my check |
| j17 fixes Q2 speed, adds `bbc` | Claude | not rerun | unsupported by my check |
| no test at the deletion can be exact (cases 5, 18) | Claude | argument read against the quoted trees, not rerun | plausible |
| j13, j14 bring back `cab` | Claude | not rerun | unsupported by my check |

**Open items.**
- Kind D (5 invalid trees with `cbbb`): an exact test needs the body's match
  region in the repaired string, which is decided only after later edits.
- The second front entry per position that `~pos` keeps (families 16, 18, 19,
  28, 31 10-18% slower than cl24).
- Whether `owing`'s walk is linear per call; it walks the whole reading.
- Substitution only before the first edit (`bbbb` costs 4, 3 is valid).
- The quadratic term with two or more errors in the four shapes.
- Size: 889 against cl20's 757.

**Elegance review of cl26 (after round 22; confirmed with `_wone.dart`, kit
r9/verify).** The owing guard did not see owed text split across slots.

| Grammar | Input | cl25 | cl26 |
|---|---|---|---|
| `S <- "ab"* 'a' B; B <- 'b' / 'c' 'c';` | `ab` | invalid (owes `ab`, edits 2) | same |
| `S <- "ab"* 'a' ('b' / 'c' 'c');` | `ab` | invalid (owes `ab`, edits 2) | same |
| `S <- "ab"* A; A <- 'a' B; B <- 'b' / 'c' 'c';` | `ab` | invalid (owes `ab`, edits 2) | invalid, cost 2: deletes `a`, `"ab"*` empty, `A` inserts `a` |

The valid answer in all three owes `acc` at cost 1. A Seq joins its slots one
at a time, and the stop's guard was dropped after the first join, so it tested
only `a`. In the third case the guard saw `ab`, but `acc` had already been
displaced by `ab` under one diverse key (both leads `a`); the seat traced both
mechanisms in round 23. `owing` also joined the text on both sides of an owed
class character as if adjacent (`_text(clause) ?? ''`).
