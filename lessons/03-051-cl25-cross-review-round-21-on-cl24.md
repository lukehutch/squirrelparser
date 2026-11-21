<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl25 - cross-review round 21 on cl24: an insertion that reads no input is not the empty reading, 861 -> 871 LOC (2026-09-26)

Round 21 ran a Claude subagent (Opus 5.5, high effort) on BRIEF21 (Q1 cl24's
slowdown on nullable repetition bodies; Q2 kind D; Q3 substitution after an
edit; Q4 size; Q5 review of round 20). Codex and Gemini had no quota. The
engine is untracked `_cl25.dart` (kit name r21u): the seat's `cand` (v2) plus
one retry trigger added by the orchestrator.

**Why cl24 is slow on nullable bodies (the seat's counters; the effect
confirmed in part).** `'a'?` at p offers the empty reading and the insertion of `a`.
Both end at p, so a front keyed by `end` keeps only the empty one, and cl24's
`+` rightly refuses an empty occurrence. The ordinary ladder then finds nothing
at any budget and the diverse ladder runs as well, so cl24 runs both ladders
where v2 runs one.

**What cl25 changes (confirmed from the diff against cl24).**
- `_Front` records its position, and its key gives a reading that inserts
  characters without reading input (`end == pos`, `missing > 0`) the key `~pos`,
  apart from the empty reading. Every front is made at its real position (the
  cell, `_first`, `_seq`, `_repeat`); growth seeds `{far, pos, ~pos}`.
- An owed completion (characters owed at the end of input) keeps key `end`: it
  costs 1 whatever its length, so keyed apart it ties a deletion and wins on
  evidence with an invalid tree (`cab`, round 20).
- **Orchestrator's trigger.** v2 alone is costlier than cl24 on two old-fuzzer
  cases, `aaaa` under `S <- (('a'+ / 'b') 'c'*+);` (1 -> 2) and `ac` (1 -> 4),
  both valid in both engines. A rung trace (confirmed) shows why: cl24's
  ordinary ladder fails at every budget up to 7 and its diverse ladder finds
  cost 1; v2's ordinary ladder finds cost 2, and its failing budget-1 rung
  rejects nothing, so the diverse ladder never runs. The owed `c` lost to the
  empty `'c'*` under key `end`. cl25 sets `_rejected` in `_Front.add` when the
  empty reading and one that adds characters without reading input meet under
  one key, in either order. Both cases are cost 1 again.

**Measured (confirmed), kit r9/verify unless stated.**
- LOC 861 -> 871 normalized (+10, +1.2%); v2 alone 866.
- Battery 0.9900/84.5 (cl24 84.4), treeDiff 3, costDiff 0. Accept t/t/t,
  freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0,
  props 2728/0, window P, pred falseAssertions 0. No-repair 0 and determinism
  only `aabb` (seat kit, on the same code without the comment edits).
- `_samedw` (three-way with cdx1, seeds 1-8): invalid equal to cl24 on every
  seed (50); worse 15 -> 12; levWorse lower or equal on every seed.
- `_samew`: invalid 39 = 39 (seed 4 10 -> 9, seed 7 6 -> 7). `_same`: worse
  2 against cl24's 2. The one regression: seed 7 `aba` under
  `S <- R0; R0 <- ((R1 / ('b' 'a' 'a')) / ('a' R1)?); R1 <- ((R0 / R0)? R0++ R0++);`,
  cl24 cost 2 valid, cl25 a 4-character owed completion, which the engine
  prices at 1 and which is invalid. The trigger lets the diverse search run
  there and it returns that reading; the owed pricing is the defect, as in `cab`.
- Families: all 46 costs equal cl24's. At 16,384 (cl24 -> cl25, ms): 2 630 ->
  520, 26 5,873 -> 3,650, 29 4,644 -> 2,885, 30 5,554 -> 3,568, 32 344 -> 231,
  34 477 -> 306, 39 2,353 -> 1,173, 40 277 -> 38. v2 alone is faster on 2
  (705 -> 308). Slower: 16 1,386 -> 1,563, 18 1,707 -> 2,007, 19 1,394 ->
  1,555, 28 1,423 -> 1,837, 31 1,523 -> 1,874 (v2 alone: 16, 19, 28 and 31
  slower, 14-20%; the seat named 18 and 28). Cause not found. Corrected in
  round 22: v2 is slower on 18 too. Three runs each at 16,384 put every cl25
  run above every cl24 run on 18 (medians 1,975 -> 2,249 ms), and the seat's
  counters are identical for v2 and cl25 there; my one-run sweep of v2 was
  noise.
- AOT stress, 11 interleaved runs, medians (cl24 / v2 / cl25): errors 4,096
  49/50/50, lr 2,048 35/35/35, lr 8,192 129/128/133. Rungs 2-5% slower than
  cl24 (8000/4/7 5,627 -> 5,899 ms), costs equal. The four quadratic shapes and
  the k = 2 and k = 8 multi-error shapes: within noise of cl24, same depth.

**Negative results (the seat's, not rerun unless stated).**
- Keeping owed completions apart too (v15, v16, v17) fixes `aaaa` and `ac` but
  brings back cost-1 owed ties (`ab` 2, `abab` 4) and is worse on `_samedw`.
- Kind D: `_revives` and three narrowings (v7-v12) leave the four kind-D trees
  invalid; v14 fixes `bcb` but does not finish `bccaccaccbaaaa` in 280 s.
- Q3: dropping `r.preferred` from substitution (v18) does not reach cost 3 on
  `bbbb` (the second substitution is inside `'a'?+`, not a Seq slot), makes
  family 39 quadratic and drops the battery to 84.0.
- Round 20's brief was wrong twice: 1005 on `cab` is an invalid answer with 5
  edits (the fuzzer scores `1000 + cost`), not a whole-input answer; and
  widening substitution does not give cost 3 on `bbbb`.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r21u = cl25 | v2 + retry on a displaced insertion | 871 LOC; battery 84.5; `_samedw` worse 15 -> 12; 7 families 1.5-7x faster; `aba` invalid | 8 | fast and no worse on the strict fuzzer |
| v2 = cand (Claude) | `~pos` key, fronts at their position | 866 LOC; `aaaa` 1 -> 2, `ac` 1 -> 4 | 6 | fastest; two cases costlier |
| cl24 unchanged | none | 861 LOC | 6 | slow on nullable bodies |
| v18 (Claude) | substitution after an edit | family 39 quadratic; battery 84.0 (seat's figures) | 3 | fails speed |
| v4, v5, v12 (Claude) | lone-literal guards | `_same` worse on several seeds (seat's figures) | 3-4 | lose cases |
| v15, v16, v17 (Claude) | owed completions apart | owed ties return (seat's figures) | 2 | lose cases |
| v14 (Claude) | kind-D `_uncovers` | one case does not finish in 280 s (seat's figures) | 0 | every input must finish |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| v2: every check = cl24, battery treeDiff 0 | Claude | check25.sh r21c | confirmed |
| v2: `_samedw` = cl24, `_samew` seed 4 10 -> 9 | Claude | check25.sh r21c | confirmed |
| v2: eight families 1.5-8x faster, costs equal | Claude | sweep3.py r20c r21c | confirmed |
| v2: only 18 and 28 slower | Claude | sweep3.py (one run): 16, 19, 28 and 31 slower, 18 not; round 22, three runs and counters: 18 slower too | incomplete (16, 19, 31 missing); my "18 not" was wrong |
| v2: AOT and rungs within noise | Claude | aot.sh, rungs.sh | confirmed |
| v2: `aaaa`, `ac` costlier, both valid | Claude | `_wit.dart` on `aaaa`; fuzzer lines | confirmed |
| slowdown is extra rungs | Claude | rung trace on `aaaa` shows the same mechanism | confirmed in effect |
| 1005 is an invalid 5-edit answer | Claude | `_samedw` scoring | confirmed |
| v18 fails speed, battery 84.0 | Claude | not rerun | unsupported by my check |
| kind D not fixed by v7-v14 | Claude | not rerun | unsupported by my check |

**Open items.**
- The owed-completion price: characters owed at the end cost 1 whatever their
  length, which makes invalid cost-1 answers (`cab`, `aba`).
- Kind D (4 invalid trees).
- Five families 13-29% slower than cl24; family 2 keeps less of v2's gain.
- Substitution only before the first edit (`bbbb` costs 4, 3 is valid).
- The quadratic term with two or more errors in the four shapes.
- Size: 871 against cl20's 757.
