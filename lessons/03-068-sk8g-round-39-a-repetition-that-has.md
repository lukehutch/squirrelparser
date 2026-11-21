<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk8g - round 39: a repetition that has read something is offered a close, as a sequence is; fuzzer worse cases 28 -> 2 against sk8f (2026-10-08)

sk8g is sk8f with one test deleted: the close offer no longer requires the
candidate to be a sequence (`c is _Seq && o` -> `o`). A repetition's fix
(s, 1) already meant "delete s characters, then stop repeating"; it was
only never offered. Round 38's open case `aabc` on
`R0 <- ('c' R0 R0)+ / (R1+ / 'a'+)` now costs 2 (sk8f 4, sk7q 2): the
only candidate at the error was the repetition `'a'+`.

**Results (confirmed).**

| Engine | Battery | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 256/4/7 | Invalid | LOC |
|---|---|---|---|---|---|---|---|---|---|
| sk8f | 0.9632/68.1 | 6 | 8 | 16 | 38 | 151 | 4 | 137 | 454 |
| sk8g | 0.9636/69.0 | 6 | 8 | 16 | 38 | 151 | 4 | 134 | 453 |

- Battery against sk8f: 29 better (24 of them expr inputs with an extra
  closing parenthesis), 2 worse, +0.99 summed score.
- Fuzzer (8 seeds x 400): sk8g is the worse of the two in 2 cases, sk8f
  in 28; invalid 134 vs 137; levWorse 4 vs 29; timeouts 0.
- Gates as sk8f: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit
  16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0.
- Slower: x(ab)*800 0.76 -> 1.28 s, x(ab)*1600 2.7 -> 4.7 s, battery
  900 -> 987 ms. Inferred cause: every repetition candidate now gets a
  close offer, and each offer is a partial re-parse. Not profiled.
- auditBad rose 682 -> 779. This counter (`_research18.dart`, `edits()`)
  counts a fix that deletes s characters and inserts k as s + k, while
  the engine prices it max(s, k), so it counts trees that use a
  replacement; it is not a correctness check (confirmed from the code).
  The rise says sk8g picks more replacements (inferred).

LOC: sk8f 454 -> sk8g 453 (-1, -0.2%).
