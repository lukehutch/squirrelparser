<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl22 - cross-review round 17 on cl21: hand-written frames recover cl20's speed at cl21's depth, and a stop keeps the guard it replaces, 799 -> 845 LOC (2026-09-25)

Round 17 ran a Claude subagent (Opus 5.5, high effort) on BRIEF17 (Q1 speed:
cl21 without its AOT slowdown; Q2 the four quadratic shapes; Q3 `_meet` in
`_stop` and the diverse-retry trigger; Q4 size; Q5 review of round 16). Codex
and Gemini had no quota (until about Sep 29). The engine is untracked
`_cl22.dart` (kit name r17c22): the seat's `cand` (q19) with three comments
corrected in the elegance review.

**What cl22 changes (confirmed from the diffs against cl21 and q8).**
- **Frames instead of `sync*` generators (q8).** Growth is a `_Grow` frame and
  each construct is a plain method whose loop state lives in a `_Pass` object;
  after a growth the pass is run again from its loop counters. `_drive` keeps
  the explicit stack, so the depth is cl21's. q8 alone changes no tree (battery
  and both fuzzers treeDiff 0 against cl21, all 16 seeds).
- **A stop keeps the guard it replaces.** `_stop` returns
  `_meet(new guard, w.guard)` where cl21 overwrote `w.guard`. A guard carries a
  fourth field, the body that stopped; `_meet` keeps the first guard's body, and
  rule 1 in `_repeat` tests `identical(r.guard!.$4, body)` where cl21 compared
  closures. `_meet` reuses `opens` when both guards hold the same closure.
- **Elegance review (orchestrator).** Three comments were wrong after the
  change: the `_Guard` comment did not name the `body` field, the `_meet`
  comment did not say which body the met guard keeps, and the `_opener` comment
  still said the closure names the body (the `body` field does that now;
  `_opener` keeps one closure per body so the meet builds no chain). Comments
  only, so LOC and trees are q19's.

**Why the slowdown was the generators (the seat's measurements, not rerun
except where marked).** Callgrind at errors 4,096: cl20 230.0M instructions,
cl21 286.2M, q8 236.2M. Allocation at errors 4,096: cl20 38 MB, cl21 44, q8 39;
cl21 takes one scavenge more (4 against 3, 12.1 against 4.7 GC ms). Every
intermediate form that keeps a generator or a closure per growth (q1-q3, q9,
qd1-qd4, qg1-qg6) stays slow or loses the depth.

**Measured (confirmed), kit r9/verify.**
- LOC 799 -> 845 normalized (+46, +5.8%; raw 805 -> 845); q8 836.
- Battery 0.9900/84.4, treeDiff 3, costDiff 0 against cl21, 2,032 ms (JIT, one
  run). Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2
  3, cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0.
- Corrected fuzzer, three-way with cl21 and cdx1: invalid, worse, levWorse and
  levSum equal to cl21 on every seed (invalid 7/5/7/4/7/6/6/8 = 50, worse
  0/1/5/2/0/5/3/1 = 17).
- Old fuzzer: treeDiff 1/0/0/1/0/1/0/2; seed 8 invalid 5 -> 3, and cl21's worse
  count on seed 8 goes 2 -> 0 (cl21's cheaper answers there are invalid).
- No-repair 0. Determinism: only seed 3 `aabb` (unchanged).
- AOT stress, 11 interleaved runs, medians in ms (cl20 / cl21 / q8 / cl22):
  errors 256 3/3/3/3, errors 1,024 11/13/11/11, errors 4,096 48/56/49/48,
  lr 2,048 33/36/33/33, lr 8,192 127/139/127/128. cl22 is at cl20's speed;
  cl21 is 8-18% slower on the three larger rows.
- Depth (`deep.sh`, `deep2.sh`, AOT): on all 12 shapes cl21, q8 and cl22 have
  the same costs and recover up to the size where the plain parser itself
  overflows. The four quadratic shapes (two-arm-star, mutual-star, opt-in-star,
  list-rr) stay quadratic in all three.
- Cubic family at n = 1,600 (ms, cl21 / q8 / cl22, one run each): `x (ax)*n b`
  4,424 / 4,266 / 4,327; `x (ab)*n` 4,396 / 4,423 / 4,952. cl22 is 12-13%
  slower on `x (ab)*n` (a rerun gave 4,999 against q8 4,418).
- Rungs (JIT, cl21 / cl22 ms, costs equal): 1000/1/1 281 / 273, 1000/32/1
  1,604 / 1,506, 1000/128/1 5,317 / 5,440, 8000/4/7 5,815 / 5,838, 8000/32/7
  6,238 / 6,277.
- Sweep (`sweep3.py r16p9 r17c22`, JIT): all 46 families finish with cl21's
  costs; total time 0.98x cl21 (family 43 at 16,384: 43,415 against 42,556 ms).
  The seat's own sweep ran on q12, not q19.

**The tree changes (cost equal, validity equal or better).**
- Battery i = 744, 774, 785 (stmt corpus, cost 2 in both; read by the seat,
  treeDiff 3 costDiff 0 confirmed): the space after a `;` goes to the Assign's
  trailing greedy `WS*`, as PEG does on the repaired string; cl21 gave it to the
  enclosing block's `WS`.
- `S <- R0; R0 <- ('a' R0*? 'b'+);` on `caabb` (confirmed, `_tree.dart`): cl21
  cost 1 with repaired string `aabb`, which is not in the language (the inner R0
  reads `abb` greedily and the outer `'b'+` then fails at the end); cl22 cost 2,
  `abb`, valid. In cl21 the inner `'b'+` stop guard was overwritten when the
  enclosing `R0*` stop was made at the same position.
- Old fuzzer s8 `bacbb`: cl21 invalid, cl22 valid, cost 3 both (the seat's
  table). Other old-fuzzer changes (s1 `abaa`, s4 `abbb`, s6 `babb`) and the
  corrected-fuzzer changes (s4 `ccabcbcbac`, s8 `ccbacb`) are valid in both at
  equal cost (the seat's table, not reread).

**Negative results.**
- **The plain meet is not enough (q10)**: rule 1 compared closures, a met guard
  holds a new closure, so rule 1 fires less often; corrected fuzzer s8 worse
  0 -> 1. The body tag fixes it. It also fixes `_Way.then`'s meet, which broke
  the same identity test before (proved from the code by the seat).
- **Rung-only retry triggers (q13-q18)**: none keeps q12's answers. `found ==
  null` or the top-level result alone halve family 43 but lose 10 old-fuzzer
  cases (`ababa` 1 -> 4); "not proved optimal by the bound" and "a collision in
  `add`" add 1-2 invalid trees. On `caab` the retry helps by turning `_resume`'s
  opens-skip off, not by keeping readings apart.
- **Dropping rule-1-dead ends is not admissible**: in `S <- L ';' M; L <- 'n'
  (',' L)*; M <- 'n' (',' 'm')*;` the cost-1 answer replaces a middle `,` by
  `;`, so L must end at an inner stop, and which one depends on the suffix.
- **`opens` as a list of distinct tests (r17q19L, orchestrator)**: 851 LOC,
  `x (ab)*n` at 1,600 5,026 ms against cl22 4,999. The seat's conjecture that
  the closure chain is the 12% slowdown is refuted; the cause is open.
- **A pre-existing flaw of the plain parser (the seat's measurement)**: its
  trees depend on the order of queries (`qdiag.dart`: 6 differing failure trees
  on `cba` under a left-recursive grammar). An engine that calls `_resume`
  after the ask instead of before (q4) changes fuzzer trees at equal cost. Any
  restructuring must keep the order of plain-parser calls.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r17c22 = cl22 | q19 + three comments | 845 LOC; = q19 | 8 | cl20's speed, cl21's depth, 3 battery and 2 old-fuzzer trees more valid |
| q19 (Claude) | q8 + meet with body tag + shared `opens` | 845 LOC; treeDiff 3 at equal cost; AOT = cl20; `x (ab)*n` +12% | 8 | every target but size |
| q8 (Claude) | frames instead of `sync*` | 836 LOC; treeDiff 0; AOT = cl20 | 7 | pure speed fix, misses the validity gain |
| q12 (Claude) | q8 + meet with body tag | = q19 answers; about 10% slower on both cubic rows | 7 | q19 is faster |
| q11 (Claude) | q8 + meet of the cut only | 837 LOC; old s8 invalid 5 -> 4 | 6 | a partial meet |
| r17q19L (orchestrator) | q19 + `opens` as a list | 851 LOC; no speedup | 3 | refutes the chain conjecture |
| q10 (Claude) | q8 + plain meet | s8 worse 0 -> 1 | 3 | rule 1 fires less |
| q1-q3, q9 (Claude) | partial generator removal | 800-834 LOC; 40-42 MB, one scavenge too many | 3-4 | not faster |
| q13-q18 (Claude) | rung-only retry triggers | lose cases or add invalid trees | 2-4 | no admissible trigger |
| q4-q6 (Claude) | frames with `_resume` after the ask | fuzzer trees change at equal cost | 1-6 | query-order dependence |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| q19: battery treeDiff 3 costDiff 0, all gates | Claude | check22.sh r17q19 | confirmed |
| q19: corrected fuzzer counts = cl21 per seed; old s8 invalid 5 -> 3 | Claude | the same run | confirmed |
| q8: treeDiff 0 everywhere | Claude | check22.sh r17q8 | confirmed |
| q8, q19: no-repair 0, det only `aabb` | Claude | norepair.sh, det11.sh | confirmed |
| q8, q19 AOT at cl20's speed | Claude | aot.sh, 11 runs, medians above | confirmed |
| depth = plain parser on 12 shapes; four stay quadratic | Claude | deep.sh, deep2.sh | confirmed |
| `caabb`: cl21 invalid cost 1, q19 valid cost 2 | Claude | `_tree.dart`, and by hand | confirmed |
| q19 about 13% slower on `x (ab)*n` | Claude | deep.sh twice: 4,952 and 4,999 against 4,396-4,423 | confirmed |
| the slowdown is the `opens` closure chain | Claude (conjectured) | r17q19L: no speedup | wrong |
| generators are the cl21 slowdown (callgrind 286.2M against 236.2M) | Claude | AOT medians q8 = cl20; callgrind not rerun | confirmed in effect, counts not rerun |
| rung-only triggers q13-q18 lose cases | Claude | not rerun | unsupported by my check |
| plain parser trees depend on query order | Claude | not rerun | unsupported by my check |
| the three battery tree changes are the `WS` owner after `;` | Claude | treeDiff 3 costDiff 0 confirmed; trees not reread | partly confirmed |
| the seat's sweep | Claude | ran on q12, not q19; my sweep on cl22: 46 families, costs = cl21 | replaced by my run |

**Open items.**
- Size: 845 normalized lines, the largest cl engine so far (cl15 was 804).
  The frames cost 37 lines over cl21; no shorter protocol kept both the depth and
  the speed.
- The four quadratic shapes: the proposed shared tail list (a cell's rule-1-dead
  ends kept as one pointer to the inner cell's list, +40 to 60 lines) is not
  built.
- cl22's 12% on `x (ab)*n`: cause unknown after the list variant.
- The diverse-retry trigger: make `_resume`'s opens-skip admissible, then
  trigger on collisions (conjectured, not built).
- The plain parser's order-dependent trees (a fix belongs in the parser).
