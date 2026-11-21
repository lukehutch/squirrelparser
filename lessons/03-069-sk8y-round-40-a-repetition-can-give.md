<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk8y - round 40: a repetition can give back its last iteration; long-document rung 64/1 151 -> 70, fuzzer worse cases 49 -> 13 against sk8g (2026-10-08)

The user's question for this round: by the Levenshtein argument, deleting
characters and skipping grammar elements (inserting their shortest input)
are the two moves, so what is missing? One move was missing: undoing a
match. A repetition that read an iteration into the error (the array
`[1,"k9"` in `{"k8":[1,"k9":2}`) could only be repaired after that
iteration, so the missing `]` cost 3 deletions. sk8y lets the repetition
close before such an iteration (a "give-back", the fix (0, 1) at the
iteration start, which `_Rep.match` obeys by stopping). A give-back reads
nothing by itself, so it is measured together with the fix that then
follows (`_follow`: parse with the give-back, run one inner `_repair`,
read how far the two reach). `{"k8":[1,"k9":2}` now costs 1.

Rules, each forced by a measured failure:

- Give-backs are not candidates inside the position-ordered search
  (sk8h, 0.9514, b1 accept fails): there a give-back plus a deletion of
  the whole remaining document won. They are measured after the search.
- A give-back is kept if it and its follow-up read as far as the kept
  offer for fewer edits, or farther for as many, or, if none was kept,
  past the frontier. "Fewer only" (sk8j 0.9498, sk8m 0.9544) and
  "as many and as far" (sk8k 0.9527) lose on the battery.
- The close at the end of input must set the read distance to n + 1
  (sk8o -> sk8p). Without it a give-back reading to n + 1 at the same
  price counted as farther, and 155 truncated stmt inputs (`if (a) { b=`)
  got worse trees.
- The fix that follows must be at the give-back's own position (sk8w).
  A later fix leaves the iteration's text in front of a greedy
  repetition, which reads it again: `bcacc` on
  `R0 <- ('b' R1? R1) 'c'` gave the invalid witness `bcc`. Requiring the
  fix to also delete nothing (sk8x) loses the stmt `i f` gains.
- Speed. `x (ax)*n b` has n nested iterations ending at the error, and
  following each was near-cubic (sk8p: n=800 8.5 s; sk8g 8 ms). Three
  changes: the follow-up search stops at s > cap, since an offer that
  deletes s characters costs at least s (sk8s, 1.5 s); the measuring parse
  re-parses only from the follow-up fix (sk8q); and of iterations that
  end at the same place only the one that starts last is followed (sk8u,
  16 ms). Following the one that starts first (sk8t) loses 8 json cases.
- The inner cap must be clamped below the "no finite input" price
  (sk8y). Otherwise a close at the end of input inside `_follow` could
  insert an element with no finite shortest input (a rule cycle), and
  `bcaa` cost 2^30 + 3.

The elegance review (Opus agent) found the clamp bug, a wrong comment
("innermost": `cs` order keeps the one that starts last, the shallower on
a tie), an unused price sum in the return value, an always-constant
parameter and a double `_price`; all fixed in sk8v (trees unchanged).
Its suggestion to share code between `_follow` and `cheaper` is not done.

**Results (confirmed).** Rungs are costs; ms for the 64/1 rung.

| Engine | Battery | ms | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 64/1 ms | Invalid | Worse vs sk8g | LOC |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sk8g | 0.9636/69.0 | 987 | 6 | 8 | 16 | 38 | 151 | 7960 | 134 | - | 453 |
| sk8p | 0.9647/69.9 | 3023 | 6 | 8 | 16 | 38 | 70 | 19911 | 124 | 16 vs 65 | 498 |
| sk8u | 0.9647/69.9 | 1570 | 6 | 8 | 16 | 38 | 70 | 11542 | 131 | 19 vs 72 | 506 |
| sk8y | 0.9647/69.9 | 1551 | 6 | 8 | 16 | 38 | 70 | 12122 | 131 | 13 vs 49 | 498 |

- Battery against sk8g (sk8p, same trees as sk8y): 25 better (19 json,
  6 stmt), 5 worse (stmt `{ =b2; }` shapes, about -0.015 each).
- Fuzzer (8 seeds x 400): sk8y is the worse of the two in 13 cases, sk8g
  in 49; invalid 131 vs 134; levWorse 12 vs 41; timeouts 0. sk8p's 124
  invalid trees are lost by following one give-back per end (sk8u).
- Gates as sk8g: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit
  16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0. 256/4/7 costs 4.
- Slower: battery 987 -> 1551 ms, 64/1 8.0 -> 12.1 s, x(ab)*1600
  4.3 -> 6.4 s. `x (ax)*800 b` 8 -> 16 ms.
- Pre-existing, unchanged: nesting depth 800 overflows the stack, in
  sk8g as in sk8y (`deep.sh`).
- Open: sk8y still picks invalid trees where an inserted literal is read
  by a greedy repetition before it (`bbbbababa`: `'b'+` would eat the
  inserted `b`); this class is not specific to give-backs.

LOC: sk8g 453 -> sk8y 498 (+45, +9.9%).
