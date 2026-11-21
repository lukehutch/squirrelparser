<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk7 - round 36: deletion and insertion recovery, where skipping a sequence element inserts its shortest input, scores 0.953 and cuts the long-document rungs to 9-104 edits (2026-10-08)

Terminology, corrected at the user's request. These engines were called
"skip-only" in rounds 33-35, which is wrong. A fix deletes input (skips
characters) and skips grammar elements, and skipping an element is the
same as inserting the shortest text that element matches. This is the
covering grammar of Aho and Peterson (1972): deleting characters is
matching an error production, and inserting an element's shortest text is
skipping that element. A fix that deletes s characters and inserts m is
priced as a substitution, max(s, m) edits.

sk7q is sk6 with these changes, each measured on the battery, the six
long-document rungs, the gates and the fuzzer.

1. **Element 0 may be skipped** (sk7a), so a missing opener is inserted
   instead of costing the rest of the document. Rungs 26-415 -> 8-107.
2. **A fix is priced max(s, inserted length)** (sk7c), not s plus the
   inserted length (sk7b, 0.9387), so a wrong character before an element
   is a substitution, not a deletion and an insertion.
3. **The window grows by price plus gain** (sk7e), not by characters
   deleted, so a substitution such as `z` for `,` is reached.
4. **The candidate loop stops once a parse reads to the end** (sk7h).
5. **Skipped elements are written into the tree** as the literal leaves
   of their shortest input (sk7m), so the tree is a parse of a repaired
   string. A class character cannot be invented (D7); it stays a
   zero-length syntax error. sk7k wrote the inserted rule nodes too, and
   the battery penalizes them as invented structure (0.9337).
6. **The writing is deferred to one pass over the final tree** (sk7o). A
   fix leaves a marker; the pass replaces it and sums the prices. sk7m did
   this on every measuring parse, and x(ab)*1600 took 9.4 s; sk7o 2.8 s.
7. **Multi-character literals are matched one character at a time** (sk7p),
   so a fix can complete a partial literal: `tru]` costs 1 (insert `e`),
   not 3 (delete `tru`, insert `{}`). A literal matched with no fix inside
   it returns its own leaf and prints as itself (sk7q), so the clean-input
   trees equal the plain parser's (sk7p had cleanTreeDiff 9).
8. **Review fixes** (Opus agent, sk7q): the header now states the price; a
   fix whose price is the no-finite-string sentinel (2^30) is never kept;
   the end-of-input close goes through the same exit as other fixes; the
   First sort computes each length once. Same trees and costs.

**Results (confirmed; costs, u28 in brackets).**

| Engine | Battery | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 256/4/7 | Invalid | LOC |
|---|---|---|---|---|---|---|---|---|---|
| sk6 | 0.9380/59.9 | 26 | 58 | 86 | 164 | 415 | 39 | 1,458 | 337 |
| sk7a | 0.9357/57.6 | 8 | 16 | 25 | 50 | 107 | 4 | | |
| sk7b | 0.9387/58.7 | 9 | 17 | 26 | 50 | 106 | 4 | | |
| sk7c | 0.9429/59.5 | 9 | 17 | 26 | 50 | 106 | 4 | | |
| sk7e | 0.9485/61.1 | 9 | 17 | 26 | 50 | 106 | 4 | | |
| sk7h | 0.9496/62.5 | 9 | 17 | 26 | 50 | 106 | 4 | 1,543 | 360 |
| sk7m | as sk7h, same trees | same | same | same | same | same | same | 441 | 407 |
| sk7o | as sk7m, treeDiff 0 | same | same | same | same | same | same | 441 | 422 |
| sk7p | 0.9528/65.8 | 9 | 17 | 26 | 50 | 104 | 4 | 159 | 424 |
| sk7q | as sk7p, costDiff 0 | same | same | same | same | same | same | 159 | 428 |
| u28 | 0.9896 | 6 | 8 | 11 | 29 | 57 | 4 | | 998 |

- Invalid counts are fuzzer trees (8 seeds x 400) whose repaired string
  does not parse; sk7h and sk6 leave skipped elements out of the tree.
- Gates, sk7q: accept cx2=true b1=true b2=true, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0. sk6 failed
  cx2 and freespan (1 1 1 1 1).
- Time, sk7q: battery 623-653 ms (sk6 740), 1000/64/1 5.7 s (sk6 7.8),
  x(ab)*1600 2.85 s (sk6 2.5). Depth: overflow at 800, as sk6.
- Fuzzer, sk7p against sk7o: worse 200 vs 1,433, levWorse 182 vs 1,054,
  invalid 159 vs 441, timeouts 0. sk7q against sk7p: worse 1 vs 3.
- Battery, sk7p against sk7o: 72 better, 1 worse.

**Refuted this round (confirmed by runs).**
- sk7d: set the window only from an offer that gains. 0.9191; truncated
  inputs lose their end-of-input close.
- sk7f: price an end-of-input insertion by what it deletes only. 0.9485,
  no change from sk7e.
- sk7g: allow a close offer at the end of input. 0.9480.
- sk7i: take the frontier from the start of the longest match ending at
  the last token. 0.9474, and the target case is a First choice, not a
  sequence element.
- sk7k: write inserted rule nodes into the tree. 0.9337.
- sk7n (sk7j's change on sk7m): let a First's earlier alternatives that
  failed at its start be candidates when a later one matched. Rungs 6-105
  (from 9-106), but 0.9486, with 30 json cases worse: on `[2,33,tru]` it
  inserts a string's opening quote before `33`, and the quote cascades
  (3 -> 6).

**Open items, with proposed fixes.**
- A `+` over a body that can match empty (`'b'*+`) needs at least one
  character, since a repetition stops at a zero-length body match. `_min`
  gives it 0 and nothing is written, so 12 of seed 1's 26 invalid trees
  have this shape. Fix: price and spell a `+` by its body's shortest
  non-empty input.
- Shortest inputs written element by element can be invalid under PEG's
  greedy repetition: `R0 R0 R0` with `R0 <- ... / 'a'++` writes `aaa`,
  and the first R0 takes all three. Only parsing the written text would
  catch this.
- Battery 0.953 against u28's 0.990; rungs 1.5-2x u28's costs. Quadratic
  in the error count and depth 800, as sk6.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| sk7q | 0.9528/65.8, rungs 9-104, invalid 159, all gates, 428 LOC | 8 | best of the line; completes partial literals; trees are parses of a repaired string |
| sk7p | same costs, cleanTreeDiff 9 | 6 | superseded by sk7q |
| sk7o | 0.9496, invalid 441, 422 LOC | 6 | superseded by sk7p |
| sk7m | as sk7o, x(ab)*1600 9.4 s | 4 | per-parse writing is slow |
| sk7n | 0.9486, rungs 6-105 | 4 | First candidates cascade quotes |
| sk7h | 0.9496, invalid 1,543, 360 LOC | 4 | trees omit inserted elements |
| sk7k | 0.9337 | 2 | inserted rule nodes penalized |
| sk6 | 0.9380, rungs 26-415, 337 LOC | 3 | superseded |
| u28 | 0.9896, 998 LOC | 8 | still the best on every cost, 2.3x the size |

LOC: sk6 337 -> sk7h 360 (+23, +6.8%) -> sk7q 428 (+68, +18.9%); sk6 ->
sk7q +91, +27.0%.
