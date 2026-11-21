<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl23 - cross-review round 18 on cl22: a stop this body already guards needs no new guard, 845 -> 841 LOC (2026-09-25)

Round 18 ran a Claude subagent (Opus 5.5, high effort) on BRIEF18 (Q1 size; Q2
the four quadratic shapes; Q3 cl22's 12% on `x (ab)*n`; Q4 the diverse-retry
trigger; Q5 review of round 17). Codex and Gemini had no quota (until about
Sep 29). The engine is untracked `_cl23.dart` (kit name r18e): the seat's `cand`
(m2) plus one helper from the elegance review.

**What cl23 changes (confirmed from the diff against cl22).**
- **`_stop` returns the reading unchanged when its guard already has this stop
  and this body** (the seat's s1). Proof: a guard's body is set only in `_stop`,
  and every later meet (in `_stop` or `_Way.then`) only lowers the cut (the meet
  is a minimum with no cut as infinity) or adds alternatives to `opens`. So a
  guard with stop `w.end` and body `body` already contains the cut
  `_plain(body, w.end)` and the test `_starts(body, _)` a new meet would add, and
  the met guard equals it in every value read later (`distinction` reads only
  the stop and the cut). The skipped `_plain` call is a cache hit, so the order
  of plain-parser queries is unchanged.
- `_optional`, `_first` and `_seq` read `_got` directly instead of a copy, and
  `_repeat` uses `p.exposed` instead of a local. Nothing writes `_got` between
  the old copy and its use (`_got` is written only by `_asks`, `_drive` and the
  construct ends, and `_starts`, `_finishes`, `_plain` and `_usedSeed` call none
  of them).
- **Elegance review (orchestrator).** Rule 1 in `_repeat` and the new early
  return test the same fact, that a reading ends at a stop its own body made.
  It is now one helper, `_stopped(w, body)`, used in both places, and the early
  return joins the used-seed return in `_stop` (842 -> 841).

**Why cl22 was slower on `x (ab)*n` (the seat's counters, not rerun).** At n =
200 `_stop` makes 20,310 meets, 19,872 of them of the same body at the same
stop; each builds an OR closure and a new guard record, and the readings that
hold them stay alive (about 50 MB more old generation). Dropping only the OR
(probe s0t1) saves about 70 ms of 1,045 at n = 800; skipping the meet saves
about 150 ms.

**Measured (confirmed), kit r9/verify.**
- LOC 845 -> 841 normalized (-4, -0.5%); the seat's m2 842.
- Battery 0.9900/84.4, treeDiff 0 and costDiff 0 against cl22 (r18m2 and r18e).
  Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
  cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0.
- Old fuzzer treeDiff 0 on seeds 1-8. Corrected fuzzer three-way with cdx1:
  every count equal to cl22 on every seed (invalid 50, worse 17).
- r18m2: no-repair 0; determinism only seed 3 `aabb`; all 46 families finish with
  cl22's costs. The sweep total was 1.058x cl22, all of it family 43 on a loaded
  machine; family 43 alone at 4,096, 5 interleaved AOT runs: medians cl22
  12,407, r18m2 12,395 ms.
- `deep.sh` (AOT, n = 1,600): `x (ab)*n` cl21 4,361, cl22 5,121, r18m2 4,236
  ms; `x (ax)*n b` 4,541 / 4,579 / 4,040 ms. Depth equal to cl22 (the plain
  parser's limit).
- AOT stress, 11 interleaved runs, medians (cl20 / cl22 / r18m2 / r18e): errors
  1,024 11/12/12/12, errors 4,096 53/52/55/55, lr 2,048 37/37/38/37, lr 8,192
  132/132/137/134 (machine load about 2.5-4.5). Errors 4,096 again with 31
  interleaved runs: cl22 52, r18e 53. Within noise.
- Rungs (cl22 / r18e, ms, costs equal): 1000/1/1 266 / 263, 1000/32/1 1,528 /
  1,492, 1000/128/1 5,324 / 5,241, 8000/4/7 5,857 / 5,822, 8000/32/7 6,110 /
  6,245.

**The quadratic shapes: the cause is found (confirmed).** The seat's probe p2
(r18p2) leaves the readings that rule 1 closed out of `_repeat`'s output. On
list-rr (AOT, n = 100 ... 1,600) r18e takes 21/64/230/886/3,843 ms and p2
5/10/19/38/83 ms, both cost 1: the closed ends that `_repeat` still exports are
the whole quadratic term. p2 is not admissible: `n,n,n,n,m,m` under
`S <- L ';' M; L <- 'n' (',' L)*; M <- 'n' (',' 'm')*;` costs 1 in r18e and 2 in
p2 (confirmed with `_tree.dart`). So round 17's "n/2 ends per cell are needed"
holds only for flat cells; a cell that keeps its closed ends apart (the tail) is
the open construction.

**Negative results (the seat's measurements, not rerun).**
- **Restart instead of resume is quadratic**: errors 4,096 would replay
  8,390,656 reads (a pass asks once per error). It would also replay
  `_allowance` decrements and could loop on a used seed.
- `_Grow extends _Pass` (m1) is 847 lines; the `_opener` Expando deleted (m3,
  841) is slower on stress errors 4,096 in all 5 runs (52-55 against 44-47 ms).
- **Rung-only retry triggers again**: with `_resume`'s skip made exact for guards
  that carry a body (q4a, +3 lines, 4 fuzzer trees change at equal cost), retry
  only if nothing was found (q4b) or only on a top-level bad reading (q4c) halve
  family 43 (41.6 -> 23.7 / 24.1 s at 16,384) but are costlier than cl22 on 7 / 5
  corrected-fuzzer and 10 old-fuzzer cases. On `caab` the cheaper answer the retry
  buys is valid only because the fuzzer's witness reads a one-character
  deletion as a possible substitution (argued by the seat).

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r18e = cl23 | m2 + `_stopped` helper | 841 LOC; trees = cl22; speed = cl22, `x (ab)*n` -17% | 9 | every target; smallest since cl20 |
| m2 (Claude) | s1 + `_got` read directly + `p.exposed` | 842 LOC; = r18e | 8 | one line more |
| s1 (Claude) | cl22 + early return in `_stop` | 846 LOC; trees = cl22 | 7 | the speed fix alone |
| m3 (Claude) | m2 without `_opener` | 841 LOC; stress 52-55 against 44-47 ms | 4 | slower |
| q4a (Claude) | exact `_resume` skip for bodied guards | 845 LOC; 4 trees at equal cost | 4 | +3 lines, no gain |
| m1 (Claude) | `_Grow extends _Pass` | 847 LOC | 2 | longer |
| s0t1 (Claude) | `_meet` keeps `a.$3` | probe | 2 | drops a condition |
| p2 (Claude) | closed ends not exported | four shapes linear; `n,n,n,n,m,m` 1 -> 2 | 1 | not admissible |
| q4b, q4c (Claude) | rung-only retry triggers | costlier on 5-10 cases per fuzzer | 1 | fail target 3 |
| restart (Claude) | rerun a pass from its start | not built; quadratic replay | 0 | slower |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| m2: every check, both fuzzers = cl22 | Claude | check23.sh r18m2 | confirmed |
| m2: no-repair 0, det only `aabb` | Claude | norepair.sh, det11.sh | confirmed |
| m2: 46 families, costs = cl22 | Claude | sweep3.py r17c22 r18m2 | confirmed |
| early return and `_got` rewrites keep every answer | Claude | read the code: the proofs above | confirmed (proved) |
| `x (ab)*n` fixed | Claude | deep.sh: 5,121 -> 4,236 ms at 1,600 | confirmed |
| stress within noise of cl20 and cl22 | Claude | aot.sh twice, 31-run errors 4,096 | confirmed |
| p2: four shapes linear, `n,n,n,n,m,m` 1 -> 2 | Claude | list-rr deep2 and `_tree.dart` | confirmed (one shape rerun) |
| the cause is the per-meet allocation (counters, GC) | Claude | not rerun; the fix's effect confirmed | consistent, counts not rerun |
| restart replays 8.4M reads | Claude | not rerun | unsupported by my check |
| q4b, q4c lose cases | Claude | not rerun | unsupported by my check |
| round 17's `_tail` chain conjecture wrong (`_tail` called 0 times) | Claude | agrees with round 17's refutation by r17q19L | confirmed in effect |

**Open items.**
- Size: 841 lines against cl20's 757 and cdx1's 616; the frames still cost
  about 37 lines.
- The four quadratic shapes: the tail (a cell's closed ends kept apart from its
  exported ends, read only by callers other than the enclosing repetition) is
  now the whole remaining quadratic term, and is not built.
- The diverse retry: no rung-only trigger keeps the answers; `caab` depends on
  the fuzzer's reading of a one-character deletion.
- The plain parser's order-dependent trees.
