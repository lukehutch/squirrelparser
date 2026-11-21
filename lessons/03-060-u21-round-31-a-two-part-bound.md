<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### u21 - round 31: a two-part bound with one modeled insertion, every rung finishes, 898 -> 958 LOC (2026-10-04)

**The cause of pd57's many-error timeouts (confirmed by instrumentation).**
pd57's table charges an insertion as a jump to any position for one edit.
So the bound said 1 edit where 2 were needed, and about 30 tracks that made
one needless early edit parsed the clean prefix side by side with the true
track. Two more leaks: a joined state got `est = cost` (no bound), and a
state that had ended or was waiting never raised its bound when taken.

**u21 = pd57 with a new bound and the round-30 agent's deletions
(confirmed).** The parts:
- The table is over the grammar unfolded at each call site until a clause
  calls itself, with the return site remembered as a row (from cdx10).
  Each value is a pair (edits, bare characters), encoded as
  `edits * (n + 2) + bare`, which adds correctly because total bare is at
  most n. A read is bare unless the state can reach, by moves that read
  nothing, a read that is evidence for the character.
- One insertion is modeled exactly: a read at q that does not move. Two or
  more insertions cost at least two edits more than the least at q, and at
  the end of input at least one (insertions after a clean parse cost one in
  all). Without the end case the bound overestimates: grammar `S <- R0;
  R0 <- ((R1+ / ('b' 'a' 'a')) / "accba"); R1 <- (R0? / R0);` on input
  `a` gave the not-found fallback (ed 1) instead of ed 4.
- A state carries `bb`, a bound on the bare characters still owed. When a
  state is taken its bound is recomputed and the state is pushed back if
  the bound rose. A joined state inherits its frame's bound less what the
  child paid.
- Order: est; bare plus `bb`; edits plus the edits still owed; a later
  position; then pd57's keys.
- The closure step skips ends whose value is not below the baseline every
  state already holds (same values, battery 5.3 -> 4.7 s).
- Elegance review: edges stored as out-edges with call k weighted k and
  its return -k, the pair compare at take time done as one integer, and
  `lastRank` restored (u20 had stopped setting it).

**Checks (confirmed).**
- Battery: 0.9897/84.2 vs pd57 0.9898/84.4; costDiff 0 (every changed tree
  is at equal cost); treeDiff 154 against pd57 (u14, by compare; u17 to
  u21 have treeDiff 0 against u14).
- Gates equal to pd57: accept cx2/b1 true, b2 false, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 2 2, cleanTreeDiff 0.
- Fuzzer 8 seeds x 400: worse 0, invalid 0, timeouts 0 (pd57 0/0/0).
- Rungs, pd57 vs u21 (u20 for those not rerun): 1000/6/1 over 300 s vs
  1.3 s; 8/1 over 300 s vs 1.4 s; 12/1 over 300 s vs 1.7 s; 16/1 1.7 s;
  32/1 17.5 s, 4 GB; 64/1 6.6 s; 12/2 1.8 s; 12/3 1.4 s; 256/4/7 0.5 s;
  1024/4/7 1.4 s.
- Families (u20, AOT): paren n=16384 3.7 s (pd57 18.1 s); ab repetition
  0.94 s; optional-a b 0.34 s; optional x a n=8192 22 ms; ab aa a n=4096
  11 ms; depth 3200 fine; extra brackets n=32 10.6 s (pd57 8.9 s); missing
  n=1024 0.22 s.
- Latency, the cost: battery 4.7 s vs pd57 2.0 s (same session, two runs
  each). The table is about half of it; its closure loops are most of the
  table.

**Refuted or not adopted.**
- The insertion arc alone in pd57's position table (u16): 1000/6/1 148 s,
  12/1 over 300 s. The bare-character part of the bound is needed.
- No return-site rows (u18, recursion returns anywhere): 6/1 7.1 s, 12/1
  over 300 s. The rows are needed.
- No position key (u13b): 0.9898 but 32/1 86 s and 14 GB. Position key
  after the quality keys (u15): 32/1 99 s. The early position key is worth
  5x on that rung for 0.0001 of score.
- Raw edits in place of edits plus edits owed (u13c): 0.9897, no better.
- Bare marks cached per character: no time change.
- `_copied` as a set: fewer lines, but a hash lookup in `_lb`; not taken.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| u21 | all rungs finish; 0.9897; 958 LOC; battery 4.7 s | 8 | first pd engine with no timeouts; 2.3x slower on short inputs |
| u20 | as u21; 978 LOC | 7 | before the elegance rewrite |
| u13b | 0.9898; 32/1 86 s | 6 | score tie with pd57, 5x slower on 32 errors |
| pd57 | 0.9898; 6/1 times out | 5 | previous best; fails the finish goal on many errors |
| u15 | 32/1 99 s | 3 | position key late |
| u18 | 12/1 times out | 1 | rows needed |
| u16 | 6/1 148 s | 0 | bare part needed |

LOC: pd57 898 -> u21 958 (+60, +6.7%); u14 985 -> u17 976 -> u20 978 ->
u21 958; the agent's deletions alone (u5) 898 -> 842 (-56, -6.2%).

**Open items.**
- Latency on short inputs: 4.7 s vs 2.0 s. The closure over `_back` is
  dense; a closure ordered by value over the edges would visit each edge
  once per offset.
- Extra brackets n=32 about 10 s, still about n^3.
- 1000/32/1 at 4 GB.
- Gate b2=false in every pd engine.
