<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk4/sk6 - round 35: skip-only recovery that measures each offer by how far its parse reads scores 0.938, and a missing opener on a long document costs 26 instead of 205 (2026-10-08)

sk6 is sk3n with four changes. Each was measured against the one before
on the battery, the six long-document rungs, the gates and the fuzzer.

1. **Offers are measured, not taken first-come.** For s = 0, 1, 2, ...,
   every candidate is offered its first element that matches at q + s, and
   a sequence that has read something is offered a close there (skip the
   rest of its elements). Each offer is measured by how far the parse
   reads with it. Only the rule entries that read to the offer's position
   are parsed again, since the others cannot see the fix. An offer gains
   what its parse reads past both the frontier and its own skip. Of the
   gaining offers, the one that reads farthest less what it skips is kept.
   Closing a sequence in mid-input targets sk3n's open missing-closer
   item: in sk3n, `[1,0}},"k":...` alone cost about 180 edits on the
   6-error rung, and the whole rung now costs 26 (that the close is what
   removed it is inferred from the totals, not traced).
2. **Candidates include failures inside the last token.** A failure that
   reads to the start of the terminal match that ends farthest counts as
   frontier, so a misplaced quote or digit can be fixed where the token
   began.
3. **Windows bound the search.** The first element offer (or the first
   close that gains) limits later skips to its skip plus its gain. Once an
   element offer gains, later offers start no earlier than it and end
   their skip before its parse fails. An element offer that gains nothing
   is kept only when nothing else is (sk4i: `{"n":[Q,-7,...` went from 10
   to 2, because a zero-gain skip of the document's `{` had set the window
   and excluded the right fix).
4. **A costlier offer must beat the chain that follows the cheapest.**
   When an offer reads farther than the first gaining fix but skips more,
   the fixes that follow the first one are found (one repair at a time)
   and the costlier offer wins only if that chain does not read as far for
   fewer edits, or farther for as many (sk4k). sk4j, which let the chain
   win ties on reach, fixed one stmt case (5 -> 2) and broke one json case
   (4 -> 14).

The elegance review (Opus agent) found nine rewrites with the same
output. I checked them as sk6: treeDiff 0 against sk5 on the battery and
the fuzzer, and the same rung costs and gates. The one that matters
tests the start window before measuring an offer rather than after. The
long rungs then run 1.4-2.3x faster.

**Results (confirmed; costs, u28 in brackets).**

| Engine | Battery | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 256/4/7 | LOC |
|---|---|---|---|---|---|---|---|---|
| sk3n | 0.9085/54.9 | 205 | 156 | 195 | 411 | 14,781 | 41 | 219 |
| sk4 | 0.9356 | 26 | 58 | 86 | 2,073 | 2,050 | 39 | |
| sk4g (chain) | 0.9360 | 26 | 58 | 86 | 164 | 419 | 39 | |
| sk4h | 0.9374 | 26 | 58 | 86 | 164 | 419 | 39 | 338 |
| sk4k = sk5 | 0.9380/59.9 | 26 | 58 | 86 | 164 | 415 | 39 | 342 |
| sk6 | as sk5, treeDiff 0 | same | same | same | same | same | same | 337 |
| u28 | 0.9896 | 6 | 8 | 11 | 29 | 57 | 4 | 998 |

- Time, sk6 (sk5): 1000/6/1 1.2 s (2.9), 1000/64/1 7.8 s (11.4), 256/4/7
  0.23 s (0.49), battery 740 ms (sk3n 343).
- Gates as sk3n: accept cx2=false b1=true b2=true, freespan 1 1 1 1 1,
  recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0.
- Depth: overflow at 800, as sk3n. x(ab)*n costs n (sk3n 2n-1), still
  quadratic in time (n = 1600 in 2.5 s).
- Fuzzer, 8 seeds x 400, sk4k/sk6 against sk3n: worse 155 vs 314,
  levWorse 106 vs 164, invalid 1,458 vs 1,428, timeouts 0.
- Battery against sk3n: 355 cases better, 85 worse.

**Refuted this round (confirmed by runs).**
- sk4l/sk4m: let only frontier candidates skip elements. Fixes
  `{"a":{"b":{"c":[1,2,"d":[3,4]}]}}` (7 -> 2) but 64/1 goes from 415 to
  13,978 (sk4l) or the battery drops to 0.9368 (sk4m).
- Closing a sequence at the end of input as an ordinary close offer
  (review, sk5c): 0.8483. The separate end-of-input close is needed.
- The review's fix for the measurement error below (also forget positions
  where left recursion grew): the mismatch count stays 1. The review's
  test of it had forgotten nearly every position, which is a fresh parse.

**Open items, with proposed fixes.**
- Measuring by partial re-parse disagrees with a fresh parse on one
  fuzzer input (left-recursive grammar, `bcab`: reads 2, fresh 5). No
  final tree changes. Cause inferred: a memo entry inside a left-recursive
  cycle depends on where the cycle was entered. Fix to try: forget every
  entry of a rule in a left-recursive cycle at positions after q.
- Missing openers and quotes cost 20-33 skipped characters each on the
  rungs (26 vs u28's 6). Skip-only recovery cannot insert; inserting one
  terminal at the frontier is the smallest addition.
- Still worse than sk3n on 85 battery cases, mostly a missing `]` before
  a member (`{"p":[1,2,3,"q":...`, one or two more edits).
- Battery time is 2.2x sk3n's; most of it is close offers that gain
  nothing (6/1: 4,422 closes, 1,912 with gain).

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| sk6 | 0.9380, rungs 26-415, 337 LOC | 7 | best skip-only engine; 8-35x cheaper than sk3n on long documents |
| sk5 | same trees, 342 LOC, slower | 5 | superseded by sk6 |
| sk3n | 0.9085, 219 LOC | 4 | smaller, but a missing closer wrecks the rest of a document |
| u28 | 0.9896, 998 LOC | 8 | still the best on every cost, 3x the size |

LOC: sk3n 219 -> sk6 337 (+118, +53.9%); sk5 342 -> sk6 337 (-5,
-1.5%).
