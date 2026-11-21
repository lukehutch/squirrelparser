<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk8z3 - round 41: a `+` costs its body's shortest non-empty input; invalid fuzzer trees 131 -> 113, worse cases 20 -> 8 against sk8y (2026-10-08)

The reference parser stops a repetition on an empty body match without
keeping it (`combinators.dart:115-129`), so `'b'*+` fails on input with
no `b`. sk8y priced a `+` at its body's shortest input, which is 0 for a
nullable body, so it skipped `X*+` and `X?+` for free and wrote trees
the parser rejects. sk8z3 keeps two numbers per rule: the shortest input
and the shortest non-empty input. A `+` costs the second, and when an
insertion spells a `+` it spells a non-empty body (`_spell(..., some)`).
On a sequence the non-empty spelling makes the element whose non-empty
spelling adds the least non-empty. Examples: `accb` -> `bccb`, `babb` ->
`cabb`, `ba` -> `bba`, all cost 1 and all valid now.

Refuted first (same round):

- sk8z: reject an offer when the repetition before it would read the
  deleted-to text or the first inserted literal. Invalid 131 -> 135,
  worse 23 -> 28. Rejecting an offer only moves the search to other
  offers that are invalid or cost more.
- sk8z2: the same check over every repetition that can end the previous
  element. Invalid 143, worse 68 vs 40. `bbaaba` costs 22 and is still
  invalid. Local guards against a greedy repetition reading an
  insertion are refuted twice; validity by construction would need a
  parse of the repaired text (D1), as in the pd/u line at about 1000 LOC.

Bug found by the fuzzer: the first sk8z3 updated the fixed point with
`!=`. On a recursive rule the two values could swap back and forth and
never settle, and 201 fuzzer cases timed out (`('c'+* 'b'*+)` on
`ccbc`). The fixed point now only lowers each value (`min`), so it ends.

The elegance review (Opus agent) found that a choice computed each
alternative's lengths twice (a lazy `map` read twice), doubling at each
level of nested choices: fixed with a list. It found that an empty
literal `''` could be spelled as a non-empty input: fixed. It also noted
a limitation the engine already had: shortest lengths ignore ordered
choice, so `('' / 'b')+` is priced 1 though it never matches. Not fixed.
The battery and gates were re-run after both fixes (same numbers); the
fuzzer ran before them (inferred: the list fix keeps behavior, and the
fuzzer grammars have no empty literals).

**Results (confirmed).** Rungs are costs; ms for the 64/1 rung.

| Engine | Battery | ms | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 64/1 ms | Invalid | Worse vs sk8y | LOC |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sk8y | 0.9647/69.9 | 1551 | 6 | 8 | 16 | 38 | 70 | 12122 | 131 | - | 498 |
| sk8z | - | - | - | - | - | - | - | - | 135 | 28 vs 23 | - |
| sk8z2 | - | - | - | - | - | - | - | - | 143 | 68 vs 40 | - |
| sk8z3 | 0.9647/69.9 | 1498 | 6 | 8 | 16 | 38 | 70 | 12134 | 113 | 8 vs 20 | 525 |

- Battery: treeDiff 0 against sk8y (inferred cause: no battery repair
  needs a `+` over a nullable body).
- Fuzzer (8 seeds x 400): worse 8 vs 20, levWorse 3 vs 20, invalid 113
  vs 131, timeouts 0, treeDiff 40.
- Gates as sk8y: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit
  16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0. 256/4/7 costs 4.
- `deep.sh`: as sk8y. Depth 800 overflows the stack; x(ab)*1600 6.6 s.
- Open: invalid trees where an inserted literal is read by a greedy
  repetition before it; left-recursive grammars (76 of the 131 sk8y
  cases had a valid witness and a left-recursive grammar).

LOC: sk8y 498 -> sk8z3 525 (+27, +5.4%).
