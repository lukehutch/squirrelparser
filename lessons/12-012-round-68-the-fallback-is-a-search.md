<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.12 Round 68: the fallback is a search over repaired strings (adopted)

z11 (`_z11.dart`) is z10 with f25's search replaced by `_exact.dart`. z9's search runs first, and
its repaired string is checked by the library parser; only when the check fails does the
fallback run. The fallback searches repaired strings in order of edit count. Each string is
parsed by the library parser over a copy of the grammar whose terminals record the farthest
position the parse examined, so the next edit goes between the last edit and that position.
Two rules keep the search small:

- Two repairs with the same string and the same last edit have the same continuations (a PEG
  match at p depends only on the string from p on), so only the cheaper one is kept, and of
  equal cost the first by the tie-break order.
- After the search has parsed 64 strings per input character, a repair is not grown when a
  cheaper repair, whose last edit is no earlier, failed at least as far in the input. This
  rule is not sound (see 12.13 item 1); below the threshold the search is exact.

| | z10 (round 67) | z11 |
|---|---|---|
| LOC, raw | 402 + 666 = 1,068 | 404 + 170 = 574 (-494, -46%) |
| fallback fields | 91 (`Squirrel` 63, `_Node` 16, `_Trail` 7, `_Edit` 3, `_T` 2) | 10 (`Exact` 8, `_Probe` 2) |
| battery | 0.9904 / 86.6% | same trees and costs (treeDiff 0, costDiff 0) |
| gates | cx2 b1 b2, recommit 16/16, conformance 0 1 1 0 2 3 | same |
| dl seeds 1-16, worse / invalid / timeouts | 11 / 0 / 0 | 0 / 0 / 0 |
| lf seeds 1-16, worse / invalid / timeouts | 4 / 0 / 0 | 0 / 0 / 0 |
| rungs 8/16/32/64, ms | 216 / 209 / 257 / 327 | 186 / 155 / 252 / 303 |
| deep.sh | all finish | same costs, same times |
| `E <- 'c' ' '` on `bc `*k, k = 64 / 128 / 256, ms | 174 / 1,045 / 5,062 | 175 / 978 / 4,818 |
| `E <- 'c'? ' '` on `bb `*k, k = 64 / 128 / 256, ms | 107 / 509 / 2,429 | 108 / 492 / 2,407 |
| `E <- 'c'? 'c' 'a'? ' '` on `bc `*k, k = 64 / 128 / 256, ms | 754 / 4,326 / 30,902 | 914 / 5,494 / 33,948 |

Seeds 17-24 (z11 against the same search without the prune): 0 worse, 0 invalid, 0 timeouts
for both. On the last dense probe the fallback alone takes 315 ms / 1.1 s / 4.2 s / 15.4 s at
k = 64 / 128 / 256 / 512 (about k^2); the rest of z11's time is z9's search, as in round 67.

Candidates, scored:

| Candidate | result | score | reason |
|---|---|---|---|
| z11j: z9 + exact search + same-string merge + dominance prune past 64(n+1) parses (adopted) | above | 9 | half the code, a tenth of the fallback fields, no worse answer on any fuzzer case |
| z11f: z9 + exact search + same-string merge | dense k = 16 2.9 s, k = 32 over 120 s | 6 | exact, but exponential on dense errors |
| z11k: z11j with the prune always on | dl/lf seeds 1-16: 3 worse, 3 timeouts | 3 | the prune drops optimal repairs on short inputs |
| z11b: z9 + exact search, no merge | dense k = 16 over 120 s | 3 | exponential |
| z11c / z11g: keep only the repair that failed farthest per front | 2 fuzzer timeouts each; z11g dense 256 85 s | 3 | slower than z11j and loses answers |
| z11i: z11g with inserted characters mapped to the next input position | dense 256 87 s; fuzzers not run | 3 | no faster than z11g |
| z11d: order by how far a repair parses | 16 fuzzer timeouts | 1 | refuted item 1 |
| z11h: an end-of-input run costs one edit in the search | 9 fuzzer timeouts | 1 | refuted item 2 |
| z12a: the exact search alone, no z9 | every rung (8-64 errors, 23 KB) over 120 s | 1 | each repair re-parses the whole input |

Refuted this round:

1. Ordering repairs by how far they parse (x3): an unbounded run of insertions at the end of the
   input always parses farthest, so the search never stops.
2. Counting a run of end-of-input insertions as one edit inside the search (x7): the same
   unbounded runs, now free.
3. The plain search over repaired strings (x1) is exact in edit count, not under the cost that
   counts an end-of-input run once.
4. The exact search without z9 (z12a): see the table.
