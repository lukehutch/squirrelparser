<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.9 f23-f25: the memo kept across parses, 2x faster at rung 64

f22 parses every candidate from scratch except where the base table (keyed by input position)
gives a result. f23-f25 keep a rule's result across parses whenever the edits inside the
result's extent are the same edits. Engine: `dart/experiments/recovery/_f25.dart`.

#### 10.9.1 What changed

- **f23** adds a second table, keyed by rule and input position. Each entry stores the edits
  inside its extent (`_same` compares them by identity), its end, extent, tree, and its
  farthest failures relative to its start. To make the stored failures exact, each computation
  now scopes the farthest failure to itself (`_fMark`) and merges it into the caller's on
  return; a hit replays the stored failures.
- **f24** merges the base table into this table: one table, keyed the same way. A result with
  no edits in its extent is the old base-table case.
- **f25** lets a repetition's trail run across edits. A trail now records, for each iteration,
  the window it read and the count of edits up to it. A later parse jumps every iteration whose
  edits are identical to the current ones, found by binary search, and stops before the first
  edit that differs. Before f25 a trail stopped at the next edit. `_nextEdit` and `_clear`
  were deleted (unused).

#### 10.9.2 A hit must not hide a result that reads past the end of the input

The first f23 differed from f22 on 7 battery trees and 3 costs, all on `stmt` cases with
insertions at the end of input (i=1924, `if (a) { if (b`: cost 5 vs 4). Replaying the stored
failures did not fix it. The cause: `node.sig` hashes every touched memo entry that reads past
t (t = the string length minus the insertions at the end of input). A table hit returns the
outer result without touching the inner entries, so those entries vanished from `node.sig`
and the search ranked the node differently. The fix stores and hits only entries with extent
<= t. After it: treeDiff 0, costDiff 0 against f22.

The general rule: **any ranking key computed from the set of touched memo entries depends on
the cache**, because a hit hides the entries computed inside it. Section 10.9.4 lists the keys
that still do.

#### 10.9.3 Measured

All runs on the same machine; rungs timed with nothing else running.

| Check | f22 | f23 | f24 | f25 |
|---|---|---|---|---|
| battery score / perfect % | 0.9899 / 84.5 | same, trees = f22 | same; 1 tree differs from f22 (i=598 json, equal cost) | same, trees = f24 |
| gates (cx2, b1, b2, freespan, recommit, conformance, cleanTreeDiff) | true, true, false, 3 3 4 4 1, 16/16, 0 1 1 0 2 2, 0 | identical | identical | identical |
| rung 16 / 32 / 64 (costs 14 / 29 / 57) | 1.8 / 8.3 / 20.1 s | 1.53 / 5.6 / 10.9 s | 1.40 / 5.7 / 11.2 s | 1.38 / 5.1 / 9.9 s |
| peak memory rung 16 / 32 / 64 | 0.53 / 0.53 / 0.56 GB | 0.53 / 0.54 / 0.59 GB | 0.54 / 0.56 / 0.61 GB | 0.55 / 0.57 / 0.60 GB |
| strict dl, seeds 1-16: worse, invalid, timeouts, crashes | 0, 0, 0, 0 | 0, 0, 0, 0 | 0, 0, 0, 0 (treeDiff 4 vs f22) | 0, 0, 0, 0 (treeDiff 0 vs f24) |
| strict lf, seeds 1-16 | 0, 0, 0, 0 | 0, 0, 0, 0 | worse 2 vs f22, f22 worse 1 vs f24; 0 invalid | treeDiff 0 vs f24 |
| LOC (same-session count) | 701 | 748 (+47, +6.7%) | 733 (+32, +4.6%) | 719 (+18, +2.6%) |

f25 against f22: rung 64 2.0x faster, rung 32 1.6x, rung 16 1.3x, for 18 more lines.

Profile of f24 at rung 64 (Stopwatch timers and counters, one run, 11.5 s): parsing 6.2 s,
child generation 1.6 s (nearly all alphabet probes), layout 0.28 s, ranking keys 0.04 s;
135,432 parses, 19.0M rule calls, 15.5M table hits, 0.38M memo hits, 1.06M stores. Time per
parse is 46 us, against 92 us in f20b at the same rung: the table removed the growth with the
number of edits, and what remains is the 19M calls that end in a hit (about 140 per parse).

#### 10.9.4 The table still changes ties

f24 against f24 with the table off (`_f24n`): battery treeDiff 0, every fuzzer cost equal, but
1 tree differs on each fuzzer (dl seed 15, input `aacbbbbcbbabca`; lf seed 13, grammar
`S <- R0; R0 <- ('b'+* 'b'+? R2); R1 <- ('c' 'a'); R2 <- (R1 / !('a' / 'b'));`, input
`bbcbbcb`, where f24 deletes positions 2 and 6 and the table-off engine deletes 2 and 5, both
cost 2). Trails are not the cause (turning them off changes neither tree).

Cause (inferred from the code, not confirmed by an ablation): `node.open`, `_span` and `_left`
iterate the touched entries, and a hit hides the entries inside it. For the first three this
can only matter for a hidden entry whose extent equals its parent's: `far` is the parse's
maximum extent minus 1, and a hidden entry's extent is at most its parent's. The second loop of
`_left` (the last complete match before the failure point) can read any hidden match.

The output is still a deterministic function of the grammar and input, costs are unaffected,
and no tree is invalid. What is lost is that the table-off engine no longer specifies the
engine exactly. Proposed fixes, not built:
- store with each table entry the hidden entries at its own extent and its hidden complete
  matches, and add them to the touched set on a hit;
- or define `open`, `_span` and `_left` over results that every parse reaches, such as the
  entries on the path from the root to the farthest failure.

#### 10.9.5 Candidates scored

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| f25 (one table + trails across matching edits) | trees = f24, rung 64 9.9 s, 719 LOC | 9 | fastest, smallest of the three; ties depend on the cache (10.9.4) |
| f24 (one table) | rung 64 11.2 s, 733 LOC | 8 | superseded by f25 at equal trees |
| f23 (base table + edit-keyed table) | trees = f22, rung 64 10.9 s, 748 LOC | 7 | the only one exactly equal to f22, but two tables doing one job |
| f23 without the stored-failure replay (`_f23nf`) | not run | - | built; the ablation is open |
| f23 storing entries past t | 7 tree and 3 cost differences vs f22 | 0 | refuted, 10.9.2 |

#### 10.9.6 Elegance review of f25

- One table replaces the base table; the hit and the store are each one condition.
- The failure scoping (`_fMark`, the merge on return) adds 6 lines but makes a result's
  farthest failure a property of the result, which is what lets it be stored.
- The trail grew from 4 lists to 7. The extent check, the window check and the edit count are
  separate lists; one record per iteration would read more simply.
- Two `if` statements in the `lastV` loop of `_evaluate` lack braces (analyzer infos, existing
  since f18).

**Still open:**
- cache-independent ranking keys (10.9.4);
- the `_f23nf` ablation;
- alphabet probes, about 14% of the time at rung 64;
- the 400k evaluation cap (D2), b2, stack overflow at nesting 1600;
- `_dirtyIn` scans a list;
- the fuzzers should run the strict check by default.
