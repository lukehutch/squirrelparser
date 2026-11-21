<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### Engines and measurements

Battery: 2,101 cases, `_research18.dart`, score / perfect %. Times are
JIT wall times in this session. treeDiff and costDiff are against e7s
(`BASE=e7s ... compare`). Rung k is `scale X 1000/k/1`, a 23.5k
character JSON document with k errors.

| Engine | Change | Battery | Time | 1 / 2 / 4 errors |
|---|---|---|---|---|
| e1 | the search, a full parse per state | 0.9208 / 68.3, 23 uncovered | 67.9 s | - |
| e2 | substitutions and the completion found | 0.9582 / 70.5 | 133 s | - |
| e3 | alphabet from the unknown-character parse | 0.9688 / 72.9 | 154 s | - |
| e4 | incremental memo: results that examined no edit are kept in input coordinates, about 18 rule computations per parse | 0.9897 / 84.2, 24 uncovered | 193 s | - |
| e5 (variants) | state signature prune, tie-break rules | 0.8104 to 0.9900 / 84.6 | 8.5-104 s | - |
| e6 | enclosure tie-break by default, array memo; deletions and substitutions written into the tree | 0.9898 / 84.5, uncovered 0 | 5.2 s | 0.9 / 1.3 / 71.6 s |
| e7 | progress rule: grow a state only if its last edit moved the parse on | 0.9898 / 84.5 | 4.2 s | - |
| e7p | e7 plus a second pass without the progress rule | 0.9899 / 84.5 | 15.8 s | - |
| e7s | the second pass only when the first finds nothing or a cost above 1, capped at that cost minus 1 | 0.9899 / 84.5 | 6.0 s | - / - / 86 s |
| e8 | e7s with the second pass resuming from the states the first pass refused | 0.9899 / 84.5, treeDiff 0 | 4.6-5.5 s | 0.8 / 1.5 / >600 s |
| e9 | one pass, also growing a state when the input expected at its failure changes | not run | - | 2.2 / 12.3 s / gives up at 37.7 s (deletes everything) |
| e10 | grow only states that fail at the farthest position reached at the same or lower cost | 0.9798 / 82.6, treeDiff 73, costDiff 21 | 4.0 s | 0.74 / 1.1 / 18.6 s |
| e11 | merge states that fail at the same position with the same expected input | 0.9596 / 73.7, treeDiff 358 | 10.2 s | 1.3 / 2.2 / 46 s |
| e12 | drop a state only when a strictly cheaper state fails at the same position or later | 0.9899, treeDiff 0 | 5.5 s | 1.1 / 2.0 / >600 s |
| e13 | e12 with the dominating front kept per cost level, and applied to the states resumed in the second pass | 0.9899, treeDiff 0 | 7.5 s | 1.8 / 2.7 / >300 s |
| e14 | e8 with a window: edits only at or after the second-nearest start of a rule call that failed and examined the failure point | 0.9900 / 84.5, treeDiff 2, costDiff 2 (both higher) | 4.2 s | 0.20 / 0.23 / 61 s |

The best e5 variant (0.9900 / 84.6) took 104 s; e6 kept 0.9898 at a
twentieth of the time. With the farthest-reading repair committed, e6
reached cost 19 on rung 16 in 82 s; without it, it fell back to cost
23,556 (deleting the whole input).

**Fuzzer** (`dl.sh` and `lf.sh`, 8 seeds x 400 cases per row, one run
of four engines; worse is against the cheapest of the four; zd is z6):

| Row | worse z6 / x513j / e7 / e7s | invalid z6 / x513j / e7 / e7s | e7s timeouts |
|---|---|---|---|
| dl seeds 1-8 | 72 / 162 / 65 / 47 | 35 / 22 / 7 / 0 | 0 |
| lf seeds 1-8 | 99 / 129 / 61 / 39 | 35 / 26 / 18 / 0 | 0 |
| dl seeds 9-16 | 100 / 160 / 67 / 50 | 46 / 25 / 10 / 0 | 0 |
| lf seeds 9-16 | 108 / 166 / 59 / 31 | 44 / 43 / 18 / 0 | 0 |

e7s returns no invalid tree in 12,800 cases and has the fewest worse
costs in every row, held-out seeds included. e7's invalid trees are
cases where the progress rule refused every path to the cheapest
repair and the search ended on a fallback; the second pass finds them.
The last one (input `b`, which needs `cc` appended) was a cycle key that
ignored single-character literals.

e14 against e8 alone, same rows: e14 worse 5 / 4 / 1 / 8, invalid
4 / 2 / 1 / 5; e8 worse 0 and invalid 0 in every row. So the window
costs a few repairs and, through them, a few valid trees (the fallback
again); the cause of each invalid tree was not traced.

Gates: e8 and e14 pass cx2, b1, `_freespan` (3 3 4 4 1), `_recommit`
16/16 and cleanTreeDiff 0; they fail b2, and conformance prints
`0 1 1 0 2 2` (z6: `0 1 1 0 2 3`, b2 passes).
