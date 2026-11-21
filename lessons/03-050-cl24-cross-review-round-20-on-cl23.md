<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl24 - cross-review round 20 on cl23: an iteration that adds no character is not an iteration, 841 -> 861 LOC (2026-09-26)

Round 20 ran a Claude subagent (Opus 5.5, high effort) on BRIEF20 (Q1 the kind-B
rule; Q2 the other newly invalid trees; Q3 the quadratic term with two errors;
Q4 size; Q5 review of round 19). Codex and Gemini had no quota. The engine is
untracked `_cl24.dart` (kit name r20c), the seat's `cand` unchanged.

**What cl24 changes (confirmed from the diff against cl23).**
- `_Way` gains a count `subs` (1 for a substitution) and a getter
  `repaired => end - deleted + subs + missing + owed`: where the reading
  started plus the characters it puts in the repaired string.
- `_repeat` drops a step that adds no character to the repaired string, and a
  step that reads no input unless it is the first occurrence. The plain parser
  stops a repetition at an empty match, so `'a'?+` fails on `c`: such a step is
  not an iteration of any PEG tree.
- A `+` reading that has added nothing yet (only a deletion before its first
  occurrence) waits in the queue under its own key `~w.end` and never enters
  the front; a resume that adds nothing keeps only the deletion.
- `_Way.until` records where a leading deletion ends, and `_first` rejects a
  reading when an earlier arm matches the input after that deletion (kind C).
  This adds plain-parser calls cl23 does not make; no battery or fuzzer tree
  depends on them, but no proof covers the call order.
- A lead-rule rejection sets `_rejected`, as other rejections do; a literal is
  not substituted for the same character (kind E).

**Measured (confirmed), kit r9/verify.**
- LOC 841 -> 861 normalized (+20, +2.4%).
- Battery 0.9900/84.4, treeDiff 0, costDiff 0 against cl23. Accept t/t/t,
  freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0,
  props 2728/0, window P, pred falseAssertions 0; no-repair 0; determinism only
  `aabb`.
- Strict witness, corrected fuzzer (`_samedw`, three-way with cdx1, seeds 1-8):
  invalid 7/5/6/4/7/6/5/10 = 50 against cl23's 68; worse 12 against 31;
  levWorse 8 against 27; levSum +27 in total (valid answers edit more text).
  Old fuzzer with the strict witness (`_samew`): invalid 39 against 55, worse
  lower or equal on every seed.
- Old fuzzer with the loose witness (`_same`): cl24 is worse than cl23 on seeds
  1, 2, 4 and 6. The seat reports all 9 cases are cl23 answers the strict
  witness rejects (not rechecked case by case).
- Families: all 46 finish. Seven cost +1 at every n (`'a'?+ 'c'`,
  `('a' / "ab")?+ 'c'`, `('a'? / 'b')+ 'c'`, `('a'? / 'b')?+ 'c'`, `'a'?+`,
  `'a'*+`, `"ab" "aa"*? 'a'?+`). On `'a'?+ 'c'` and `"ab" "aa"*? 'a'?+` at
  n = 4 and 6 the witness checker shows cl23's cheaper answer is invalid and
  cl24's valid. On `"ab" "aa"*? 'a'?+` cl24 is still not minimal: on `bbbb`
  cost 3 is valid (two substitutions), cl24 pays 4, because a substitution is
  offered only to a reading with no edit yet (an older limit, not new here).
- Eight families are slower by a constant factor at n = 16,384 (cl23 -> cl24
  ms): the seven above 386 -> 709, 2,374 -> 5,565, 1,988 -> 4,542,
  2,588 -> 5,579, 116 -> 343, 134 -> 438, 294 -> 2,373, and
  `'a' 'b'?+ ('a' / R0)*` 29 -> 298. Growth from 4,096 to 16,384 is unchanged.
- AOT stress, 11 interleaved runs, medians (cl20 / cl23 / cl24): errors 4,096
  47/49/49, lr 2,048 32/33/34, lr 8,192 129/127/129. Rungs within 4% of cl23.
  The four quadratic shapes and list-rr, opt-in-star with two errors: within
  noise of cl23, still quadratic.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r20c = cl24 | kind-B rule + `+` queue key + kinds C, E | 861 LOC; invalid 68 -> 50, worse 31 -> 12; 8 families slower by a constant | 7 | removes most invalid trees; costs 20 lines and family speed |
| cl23 unchanged | none | 841 LOC; 18 more invalid trees | 6 | smaller and faster, but its answers are not PEG trees |
| u8 (Claude) | no kind-C rule | 858 LOC; invalid 58, worse 17 | 5 | worse on two seeds |
| u10, u15, u19 (Claude) | `~pos` key for no-input readings | 864-867 LOC; families fast; `cab` 1 -> 1005 | 4 | loses a case |
| merged `lead`/`until` (orchestrator) | one field for the first edit | 861 LOC; type test at each use | 2 | no lines saved, less clear |
| u12 (Claude) | one-line queue | 859 LOC; families 6, 10 cost x2 | 3 | cost regression |
| u11 (Claude) | deletion lead for kind D | 860 LOC; battery treeDiff 13, worse on two seeds | 1 | fails target 3 |
| u9 (Claude) | no `requireOne` branch | 858 LOC; trees change | 1 | drops a condition |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| every check = cl23, battery treeDiff 0 | Claude | check24.sh r20c | confirmed |
| strict invalid 68 -> 50, worse 31 -> 12 | Claude | `_samedw` seeds 1-8 | confirmed |
| `_samew` invalid lower or equal per seed | Claude | check24.sh | confirmed |
| no-repair 0, det only `aabb` | Claude | norepair.sh, det11.sh | confirmed |
| seven families +1, cl23 invalid there | Claude | sweep3.py; witness checker on two families | confirmed (two checked by hand) |
| eight families slower, same growth | Claude | sweep3.py | confirmed |
| AOT and rungs within noise | Claude | aot.sh, rungs.sh | confirmed |
| loose-fuzzer losses are cl23-invalid | Claude | not rerun per case | unsupported by my check |
| `~pos` restores speed but loses `cab` | Claude | not rerun | unsupported by my check |
| `R0 <- ('b'*+ "ac")` on `ac`: 2 -> 1 | Claude | `_tree.dart` | confirmed |
| Q3: no linear construction for two errors | Claude | a search, not a proof | conjecture |

**Open items.**
- Kind D (4 invalid trees): a deletion revives an earlier stop or empty
  optional; u11 fixes them but changes 13 battery trees.
- The constant factor on nullable repetition bodies (up to 10x); why `~pos`
  both restores it and loses `cab` is not diagnosed.
- Substitution is offered only before the first edit, so `"ab" "aa"*? 'a'?+`
  on `bbbb` costs 4 where 3 is valid.
- The quadratic term with two or more errors in the four shapes.
- Size: 861 against cl20's 757.
