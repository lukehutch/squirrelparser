<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk7 - round 37: a choice that reads makes its failed openers candidates, and position order lets the opener win; 0.953 -> 0.962, rungs 9-104 -> 6-151 (2026-10-08)

sk7y is sk7q with these changes, each measured on the battery, the six
long-document rungs, the gates and the fuzzer.

1. **Failed openers become candidates** (sk7r). When a choice reads to f,
   every sequence or repetition that failed on its first element without
   reading at the choice's position becomes a candidate at f, so a fix
   can insert the opener the choice could not take. On `"a":1}` the old
   engine inserted `\` before a quote and a closing quote (cost 2); the
   opener `{` (cost 1) was never offered, because the Object sequence
   failed at position 0, behind the frontier. sk7r alone: 0.9533.
2. **Candidates are tried by position, then deepest first** (sk7s). With
   depth order the deeper escape fix at position 2 gained first, and the
   rule that later offers start no earlier than a gaining one then blocked
   the opener at position 0. Position order alone (sk7t) gives 0.9529;
   both together 0.9621. This is the change that rescues last round's
   refuted sk7n, which had item 1 without item 2.
3. **Candidates are de-duplicated by (clause, element, position)** (sk7v)
   and **failed openers are indexed by position** (sk7x), so the choice
   does not scan the candidate list. Same score; battery 1150 -> 909 ms.
4. **Review fixes** (Opus agent, sk7y): the choice calls the library's
   own First and adds candidates after it; a typedef for the candidate
   record; the loop test reads the first candidate, since they are sorted
   by position; the header states the new rule and the order. Same trees
   and costs on the battery and the fuzzer (treeDiff 0).

**Results (confirmed; costs).**

| Engine | Battery | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 256/4/7 | Invalid | LOC |
|---|---|---|---|---|---|---|---|---|---|
| sk7q | 0.9528/65.8 | 9 | 17 | 26 | 50 | 104 | 4 | 159 | 428 |
| sk7r | 0.9533/66.2 | | | | | | | | |
| sk7t | 0.9529/66.0 | | | | | | | | |
| sk7s | 0.9621/67.5 | | | | | | | | |
| sk7x | 0.9621/67.6 | 6 | 8 | 16 | 38 | 151 | 4 | 165 | 461 |
| sk7y | as sk7x, treeDiff 0 | 6 | same | same | same | 151 | same | 165 | 453 |
| u28 | 0.9896 | 6 | 8 | 11 | 29 | 57 | 4 | | 998 |

- Battery sk7s against sk7q: 85 better, 39 worse, +19.5 summed score.
  The largest gains are json documents missing their leading `{`
  (cost 10-12 -> 1).
- Gates, sk7y: accept cx2=true b1=true b2=true, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0.
- Time, sk7x/sk7y: battery 886-909 ms on a loaded machine (sk7q 716 ms
  in the same session), x(ab)*1600 2.7 s, depth overflow at 800, as sk7q.
  `x (ax)*n b` costs 2 (sk6 1; sk7q not measured).
- Fuzzer, sk7x against sk7q (8 seeds x 400): worse 51 vs 22, levWorse 45
  vs 21, invalid 165 vs 159, timeouts 0. Twelve of sk7x's worse cases cost
  1000 or more (inferred: the fuzzer's invalid-tree penalty) against
  sk7q's six; the ones read are
  openers of a recursive alternative inserted again and again, as in
  `R0 <- 'a' (R0 / 'b'+) ...` on `abca`.
- The 64-error rung got worse (104 -> 151) while the others improved.
  Cause not examined.

**Refuted this round (confirmed by runs).**
- sk7u: on equal reach less price, keep the later position. 0.9612
  against sk7s's 0.9621; it fixes `[1,[2[3,[4]],5]` (4 -> 2) but loses
  more json cases.
- sk7w: collect a choice's failed openers only from the candidates added
  while its earlier alternatives ran. 0.9612; candidates added at the
  same position by other paths matter.
- sk7z: record failed openers even behind the frontier (review item).
  Same trees as sk7y on the battery; not kept.

**Open items, with proposed fixes.**
- A quote inserted before a token still swallows the rest of the line
  when that reads farthest (`if ()a {...}` costs 5, u28 2). Section 6b
  records why no totals-based detector separates this from honest
  repairs.
- Recursive openers inserted repeatedly on the fuzzer: a fix that
  inserts the opener of a rule already open at the same position could
  be refused. Not tried.
- The nullable `+` and PEG-greed items of round 36 are still open.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| sk7y | 0.9621/67.6, rungs 6-151, invalid 165, all gates, 453 LOC | 8 | best of the line; missing openers inserted |
| sk7x | same trees, 461 LOC | 7 | superseded by sk7y |
| sk7s | 0.9621, battery 1150 ms | 6 | scans the candidate list per choice |
| sk7u | 0.9612 | 5 | tie-break loses more than it gains |
| sk7w | 0.9612 | 5 | misses openers added by other paths |
| sk7r | 0.9533 | 4 | openers blocked by depth order |
| sk7t | 0.9529 | 4 | order alone has nothing to rescue |
| sk7q | 0.9528, rungs 9-104, invalid 159, 428 LOC | 6 | fewer fuzzer regressions, worse on documents |
| u28 | 0.9896, 998 LOC | 8 | still the best on every cost, 2.2x the size |

LOC: sk7q 428 -> sk7y 453 (+25, +5.8%).
