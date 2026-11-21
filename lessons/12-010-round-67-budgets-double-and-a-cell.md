<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.10 Round 67: budgets double, and a cell finds a way by its key (adopted)

On errors with no clean text between them, z9's search took time about k^4.5 in the number
of errors k. Two causes, each measured with read counters on `S <- E*; E <- 'c' ' ';` with
`bc `*k:

1. The budget rose by one per rung, and the first rung that finds an answer has budget k,
   because the budget is reset only where the parse synchronizes after an error. So z9 ran k
   rungs, each of about k^2 reads.
2. `_Cell.add` searched the cell's ways one by one for a way with the same end, used budget
   and `incomplete` flag. The repetition's cell holds about n k ways, so each add cost time
   proportional to n k.

Changes to `_z10.dart` (`_f25k.dart` is unchanged):

1. Budgets double (1, 2, 4, ...) until one finds an answer, then a binary search between the
   last budget that failed and the first that succeeded finds the cheapest budget that
   succeeds. On sparse errors the first budget already succeeds, so nothing changes there.
2. Before each step down in the binary search, the cells are cleared. Cells filled at a
   higher budget change what a lower budget finds: without the clear (z10g), the fuzzers
   gave 3 cases at cost 4 or 7 where z10 gave 3. Clearing the cells at every budget (z10i)
   is worse still (dl worse 26, lf worse 27): ways kept from lower budgets improve what a
   higher budget finds. So z9's answer depends on the order in which budgets are tried, not
   on the budget alone. This is a defect of z9's design, recorded here and not fixed.
3. A cell with two or more ways keeps a map from (end, used budget, `incomplete`) to the
   way's index. It is allocated at the second way, because a map in every cell made the
   battery 8-13% slower.

| Measure | z10 (round 66) | z10 (round 67) |
|---|---|---|
| `_z10.dart` LOC | 392 | 402 (+10, +2.6%) |
| battery | 0.9904 / 86.6%, 2,591-2,707 ms | same trees (treeDiff 0), 2,755-2,854 ms |
| gates | recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0 | same |
| dl seeds 1-16: worse / levWorse / invalid, each against the other | 3 / 3 / 0 | 0 / 0 / 0 |
| lf seeds 1-16: worse / levWorse / invalid, each against the other | 1 / 1 / 0 | 0 / 2 / 0 |
| rungs 8/16/32/64, ms | 204 / 190 / 253 / 281 | 203 / 188 / 261 / 285 |
| deep.sh | all finish | same costs, same times |
| `E <- 'c' ' '` on `bc `*k, k = 64 / 128 / 256, ms | 2,637 / 93,145 / over 200 s | 170 / 948 / 4,614 |
| `E <- 'c'? ' '` on `bb `*k, k = 64 / 128 / 256, ms | 1,558 / 47,878 / over 200 s | 104 / 479 / 2,100 |
| `E <- 'c'? 'c' 'a'? ' '` on `bc `*k, k = 64 / 128 / 256, ms | 4,386 / 166,508 / not run | 607 / 4,101 / 29,728 |

The last grammar takes the fallback path. Timed separately at k = 128, z9's search takes
3,849 ms and the fallback search about 150 ms, so 12.9 item 1 was wrong to put the time in
the fallback.

Candidates measured this round:

| Candidate | battery treeDiff | dl / lf worse | dense `bc `*128, ms | Score | Reason |
|---|---|---|---|---|---|
| z10o: doubling + binary search with clear + indexed cell (adopted) | 0 | 0 / 0 against z10 | 948 | 9 | fastest robust form with no loss on any check |
| z10dk: doubling only + indexed cell | 0 | 5 / 4 against z10 4 / 1 | not run (z10d, unindexed: 3,861) | 6 | smallest change, but overshooting the budget costs answers |
| z10k: indexed cell only | 0 | same trees as z10 | not run | 5 | still k rungs |
| z10g: doubling + binary search, no clear | 0 | 3 / 3 against z10n 1 / 0 | not run | 3 | cells from higher budgets change answers |
| z10i: fresh cells at every budget | 2 | 26 / 27 | 18,336 unindexed | 1 | loses the ways lower budgets found |
