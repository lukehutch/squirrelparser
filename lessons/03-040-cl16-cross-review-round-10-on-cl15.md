<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl16 - cross-review round 10 on cl15: the last ranking key deleted, and cdx1 measured against it, 804 -> 796 LOC (2026-09-24)

Round 10 ran a Claude subagent (Opus 5.5, high effort) on BRIEF10 (Q1 a
transitive last key, Q2 bound independence on `acaca`, Q3 invalid trees, Q4
family 43, Q5 size, Q6 review of the round-9 verdicts). Codex has no quota until
Sep 29; Gemini's round-9 run was still waiting on its background tasks. The
engine is untracked `_cl16.dart` (kit name r10c16e): the seat's `cand` plus the
orchestrator's elegance review.

**What cl16 changes (confirmed from the diff against cl15).**
- **The last ranking key is deleted.** `_compare` ends at `a.owed - b.owed`.
  Every key is now an integer field of one reading, compared in a fixed order,
  so the ranking is a strict weak order (a lexicographic order on integer
  vectors). Readings equal in every key are resolved by `_Front.add` as before.
- **The `subs` field is deleted**: only the old key read it.
- **Two filters deleted that changed no result**: the diverse search's look
  through wrappers in `_active`, and the departed filter in `_repeat`.
- **Elegance review of cand**: `_Front.far` moved to the other fields;
  `_farthest` takes an `Iterable`, so `_Front.add` no longer copies the front
  into a list to find the farthest end; `lastCost = best.spent + best.owed`.
  Battery and fuzzer seeds 1-8 treeDiff 0 against cand.

**Measured (confirmed), kit r9/verify.** LOC 804 -> 796 normalized (-8, -1.0%).
Battery 0.9900/84.4, treeDiff 1 against cl15 at equal cost (json `...,"z"ta"]}`:
cl16 deletes the stray `"`, cl15 inserted `\`), 1,850 ms. Accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0, window
P, pred falseAssertions 0. Corrected fuzzer against cl15, seeds 1-8: invalid
8/6/8/4/7/7/8/10 (equal), worse 0, levWorse 0, levSum equal on every seed; trees
differ on 10/7/11/12/14/17/10/6 cases. Old fuzzer invalid 3/2/4/6. No-repair 0.
Stress and rungs equal to cl15 within noise (8000/4/7 5,931 / 5,924 ms). Families:
all 46 finish with cl15's costs; family 43 at 16,384 45,397 -> 41,162 ms.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0. Fuzzer seeds 1-8:
0/0/1/0/0/0/1/0, on `aabb` (both trees valid, equal cost and edit distance) and
`acaca` (the m copy gives the invalid tree). So cl16 gives back cl15's one gain
here: `aabb` depends on the bound again, as in cl14.

**Round 9 was wrong about the last key (confirmed).** Round 9 said "every
transitive key tried loses" and "the battery uses all three pairs of the cycle".
Having no last key at all is transitive and changes one battery tree, at equal
cost and score. Round 9's own row b2 ("b3 without the last key, battery = cl14")
already showed this. The three human choices (`{a":1` inserts `"`, a stray `}`
is deleted, `3z3` edits `z` at position 4) come out the same without the key,
measured with `_ed.dart`. The seat found that the stray-`}` choice rests on
`_resume` keeping a resumed scan's evidence (q1e, which drops that evidence,
loses the 7 stray-`}` cases). The cyclic key was only deciding offer-order ties.

**Why `acaca` depends on the bound (confirmed by the seat's analysis, read).**
With `cost = spent + (owed == 0 ? 0 : 1)`, an owing reading pays one unit for
any number of owed characters and can read more input, so on equal cost it wins
on evidence. On `acaca` the ranking itself prefers the invalid owing reading;
the regular bound only reaches the valid tree because it prunes differently.
Every cost model that charges owed characters fully loses the battery (q2a
0.9699, q2b 0.9817, q2c/q2d 0.9726), because JSON and stmt truncations need the
one-unit completion. a27's two-slot front loses for the same reason.

**cdx1 against cl15 (confirmed, same kit).** The c-table's cdx1 row (0.9899/85.9,
1,565 ms, 616 LOC) looks better than cl15 on the columns it has. On every other
check it is far behind:

| Check | cdx1 | cl15 |
|---|---|---|
| normalized LOC | 616 | 804 |
| battery score/perfect | 0.9899/85.9 | 0.9900/84.4 |
| battery time | 1,517 ms | 1,861 ms |
| battery cost vs the other engine | higher on 52, lower on 0 | |
| gates | all pass | all pass |
| fuzzer invalid, seeds 1-8 (3,200 cases) | 389 | 58 |
| fuzzer worse (cost above the other engine) | 747 | 23 |
| fuzzer levSum | 4,523 | 4,261 |
| errors 512 / 1,024 / 4,096 | 2,956 ms / 31,678 ms / did not finish in 60 s | 61 / 81 / 174 ms |
| left recursion 2,048 / 8,192 | 3,087 ms / did not finish in 60 s | 184 / 347 ms |
| rungs 1000/1/1, 1000/32/1, 1000/128/1 | 110 ms, 45,016 ms, did not finish in 300 s | 284, 1,672, 5,456 ms |
| rungs 8000/4/7, 8000/32/7 | 5,110, 10,230 ms | 6,086, 6,165 ms |
| 46 families | 26 do not finish in 120 s | all finish |
| unclosed parenthesis, 1,024 | Dart VM "evacuation failed" | 159 ms |

The higher perfect score comes from not breaking equal-cost ties by PEG's
ordered choice (cdx7 made that change; round 9's nokf measured the trade). On
`stmt x=1; } y=2;` cdx1 inserts `{` to make an empty block, where cl15 and cl16
delete the stray `}` (`_ed.dart`).

**cl15 and cl16 are not minimal against cdx1 (confirmed).** On 23 of the 3,200
fuzzer cases cdx1 finds a cheaper valid answer or a valid one where the cl line
gives an invalid tree: 8 invalid in cl16 but valid in cdx1 (for example
`R0 <- ('a' R0? 'a') / "ab"` on `aaaaa`, 1003 against 1), 12 both valid but
cl16 costlier (for example `R0 <- ('b'? 'a'? R0) / "aa"` on `acba`, 3 against
2), 3 both invalid. cl16 gives the same 23. The round-9 and round-10 fuzzer runs
compared only with cl14 and cl15, which share the guards, so `worse 0` there
did not mean minimal. Inferred, not traced: one of the coherence guards added
after cdx1 (`_stop`, `_starts`, `_tail`, `bad`, the departed filters) discards
the cheaper reading. The list is `$SP/cdx1_side/c15worse.txt`.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r10c16e = cl16 | cand + elegance review | trees = cand; 796 LOC | 9 | same results, no list copy in `_Front.add` |
| cand (Claude) | cl15 minus the last key, `subs`, x4, x9 | every check = cl15 except `aabb` bound-dependent | 8 | transitive ranking, 8 lines fewer |
| fnk2 (Claude) | a "hollow" key in place of the last key | 806 LOC; `aabb` bound-independent; 12 keyword repairs substitute `f` for a space in `i (x)` | 5 | against human expectation |
| q1n (Claude) | k6 + a hollow field | battery treeDiff 0, 825 LOC | 5 | +29 LOC for no measured gain |
| q1l, q1o (Claude) | hollow as avoidable / after evidence | 0.9904/84.6, fuzzer invalid +1 on seeds 6 and 8 | 3 | fuzzer loss |
| dx11 (Claude) | the avoidable demotion in `_seq` deleted | 0.9904/84.9, levWorse 1 (`bab`) | 4 | fails levWorse 0 |
| q2a-q2d (Claude) | owed characters charged fully | 0.9699-0.9817 | 0 | battery loss |
| x1, x3, x5-x8, x10, dx12, dx16 (Claude) | single guard deletions | invalid or worse up on the fuzzer, or battery loss | 0-1 | each guard still decides a fuzzer case |
| cdx1 as the engine | | see the table above | 0 | 26 families do not finish |
| start again from cdx1 | add fixes only where a check fails | not built | 4 | nearly every row of the table above forces a fix back in |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery 0.9900/84.4, treeDiff 1 vs cl15 at equal cost | Claude | `bench.sh battery` BASE=r9c15 | confirmed |
| cand: all gates, props, window, pred equal to cl15 | Claude | check.sh r10c16 | confirmed |
| cand: fuzzer invalid = cl15, worse 0, levWorse 0, seeds 1-8 | Claude | `_samedq` r9c15 r10c16 | confirmed |
| cand: no-repair 0 | Claude | norepair.sh r10c16 | confirmed |
| cand: 46 families finish with cl15's costs | Claude | sweep3.py, costs compared per family | confirmed |
| cand: stress and rungs equal to cl15 | Claude | stress.sh, rungs.sh | confirmed |
| cand: `aabb` and `acaca` bound-dependent | Claude | g/m copies, battery and seeds 1-8 | confirmed |
| round 9's "every transitive key loses" is wrong | Claude | the empty key: treeDiff 1 at equal cost | confirmed |
| the three human choices do not need the key | Claude | `_ed.dart` rerun on cl15, cl16, cdx1: same edits in cl15 and cl16 | confirmed |
| the stray-`}` choice rests on `_resume` evidence | Claude | not rerun (q1e) | unsupported by my check |
| `acaca`: the ranking prefers the invalid tree | Claude | read the argument; consistent with m giving the invalid tree | confirmed by reading |
| family 43 is n log n, 42-48% in the diverse rung | Claude | ratios 4.03x/4.17x in my sweep | consistent |
| 58 invalid trees split 26/18/10 + 4 mixed by kind set | Claude | not rerun | unsupported by my check |

Round 11 (2026-09-24) confirmed the q1e and 26/18/10 + 4 rows and refuted the `acaca` cost-model conclusion; see the cl17 section.

**Open items.**
- The 23 fuzzer cases where cdx1 beats the cl line: find which guard discards
  the cheaper reading. cdx1 now belongs in every fuzzer comparison.
- `acaca` and `aabb` bound independence; the owed-cost model that causes
  `acaca`.
- The invalid-tree classes; family 43's diverse rung.
- Size: 796 lines, against cdx1's 616.

**Process lessons.**
- A table's columns decide what a reader concludes. The c-table showed only
  battery score, time and size, so cdx1 looked better than cl15; the checks
  that separate them (fuzzer, stress, families) were not in it. The c-table now
  has a note under it saying so.
- A fuzzer that compares an engine only with its own ancestors cannot find a
  fault they share. Keep an independent engine (here cdx1) in the comparison.
