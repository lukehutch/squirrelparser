<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk2 - round 33: recovery by repetitions only is 12x faster and 85% smaller, but scores 0.45, because most errors need a sequence repaired (2026-10-07)

**The design (the user's specification).** The plain packrat parser runs
on a copy of the grammar in which every `*` and `+` may skip input. If the
parse does not consume the whole input, the candidates are the repetitions
whose failed iteration read as far as any failure did (the frontier, with
failures inside lookaheads not counted). For s = 1, 2, ..., the candidates
are tried deepest first, and the first whose body matches after skipping s
characters keeps that skip; the input is then parsed again from the start.
A repetition that fails where it has a skip records the skipped span as a
syntax error and continues after it. When no candidate can skip, what the
parse did not consume is one error, and if the top rule fails, the whole
input is. Each round adds a new (repetition, position) pair, so every input
finishes. sk1 is the first version; sk2 inlines two closures and stops a
repetition whose body no longer matches after a recorded skip.

**Checks (confirmed).**
- Battery: 0.4498/9.3, 182-189 ms (three runs); u28 0.9896/84.2, 2.27 s,
  so 12x faster. treeDiff 0 against sk1. auditBad 0, uncovered 0.
- By category (sk2 / u28): deletion 0.457/0.987, insertion 0.655/0.992,
  misc 0.394/0.966, substitution 0.506/0.997, truncation 0.262/0.997. By
  grammar: expr 0.620/0.967, json 0.224/0.994, stmt 0.639/0.993.
- Gates: accept cx2/b1/b2 all false, freespan 4 4 4 4 3, recommit 1/16,
  conformance 0 1 1 0 2 3, cleanTreeDiff 0 (valid input gives the plain
  parser's tree).
- Fuzzer 8 seeds x 400 against pd57: worse 2,257, invalid 1,297, timeouts
  0. In sk1's run, 1,293 of its 1,298 invalid trees delete the whole input
  of a grammar that rejects the empty string; the other 5 are deletions
  after which a greedy repetition or a lookahead reads the text differently.

**Why the score is low (confirmed on examples).**
- No sequence is repaired, so a missing closer, a missing comma or a
  truncation makes the top rule fail, and the whole input becomes one
  error. Truncation scores 0.262.
- In json the separator is inside the repeated body, `(',' V)*`. Skipping
  input cannot supply a missing comma, so `{"a": 1 "b": 2}` (cost 15, all
  of it) and `{"a": [1, 2, 3}, "b": 2}` (cost 24) lose the whole document.
  Of the 944 json cases, 671 score below 0.1.
- Where the repeated body starts with content, as in `Stmt*`, it works as
  intended: `1+*2` in expr costs 1 and keeps the tree; stmt scores 0.639.

**Speed and scaling (sk1, which has sk2's trees on the battery).**
- One re-parse per error, so k errors cost about k full parses. Families
  with errors proportional to n are quadratic or worse: missing elements
  n=64 43 ms, n=256 2.5 s, n=1024 over 300 s; optional-a b repetition
  n=4096 2.0 s, n=16384 85 s (u28 0.35 s).
- Long stmt documents: 1000/6/1 0.42 s but cost 23,566 (the whole input,
  true cost 6); 1000/32/1 0.16 s, cost 22,792.
- Depth: the library parser overflows the stack between nesting 1600 and
  3200, and sk1/sk2 between 800 and 1600 (the extra frames are `_Ref` and
  `_Term`); u28, with its own stack, finishes 3200.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| u28 | 0.9896, 2.27 s, 998 LOC, every rung finishes | 8 | exact, standing best |
| sk2 | 0.4498, 0.18 s, 151 LOC, quadratic in error count | 4 | small and fast on few errors; no sequence repair loses whole documents |
| sk1 | as sk2, 156 LOC, depth 800 | 3 | superseded by sk2 |

LOC: u28 998 -> sk2 151, -847, -84.9%; sk1 156.

**Open items, with proposed fixes.**
- A failed top rule deletes the whole input: keep the longest prefix the
  top rule matched (a sequence repair at the root only), or add the
  insertion of one missing terminal at the frontier.
- Separator-led bodies cannot recover: also let a candidate retry the body
  with its first element skipped (a missing comma), or try the repetition's
  following clause after the skip, which ends the list.
- Quadratic in error count: keep the memo table across rounds and clear only
  the rule entries whose evaluation saw a failing body at the skipped
  position (ancestors are cleared with them, since a failure is propagated
  upward); this does not make a flat list of n errors linear.
