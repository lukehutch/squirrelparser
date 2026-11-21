<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk3/sk3n - round 34: sequences that skip elements bring the score from 0.45 to 0.91, and skipping whole nested constructs stops a skipped opener from wrecking the rest of a long document (2026-10-07)

**The design (the user's specification, plus one addition).** sk2, with
every sequence and `?` made fixable too. A fix for element i of a sequence
at position q is (s, j): skip s characters and elements i .. j-1, then
match element j. A repetition is a sequence of one element, tried again
and again (at most once for `?`). The candidates are the sequences and
repetitions whose failed element read as far as any failure did. For
s = 0, 1, 2, ... (s = 0 tries only elements after the failed one), the
deepest candidate with an element that matches at least one character at
q + s keeps that fix, and the input is parsed again. Choices made by
measurement, not by the specification:
- An element that matches empty does not count (mode A, which counts it,
  scores 0.5957; requiring a non-empty match scores 0.6713).
- A sequence's first element is never skipped, since that would invent an
  opener (+0.0075).
- When s reaches the end of input, the shallowest candidate sequence
  skips the rest of its elements (truncation 0.995). Skipping the rest of
  a sequence anywhere (mode C) scores 0.8768, below 0.9028 for skipping it
  only at the end.
- `?` is a repetition of at most one (+0.0061).
- sk3n only: a skip may end only where a match of a recursive rule (not
  the top rule) that actually nests, i.e. contains another recursive
  rule's match, ends. So `{"a":true}` is passed as one unit, while a
  string, which `Value` also matches, is not.

**Exploration (battery score, confirmed).**

| Mode | Change | Score |
|---|---|---|
| A | specification as written | 0.5957 |
| B | element must match a character | 0.6713 |
| C | B + skip the rest of a sequence anywhere | 0.8768 |
| D | rest skipped at end of input only, deepest first | 0.8875 |
| E | D + no fix at a sequence's first element | 0.8950 |
| F | rest skipped anywhere, shallowest, after all s | 0.8538 |
| G | rest skipped at end only, shallowest, after all s | 0.9028 |
| H (sk3) | G + `?` as a repetition of at most one | 0.9089 |
| I | H + first-element fixes after all others | 0.9066 |
| sk3j | H + skips pass any non-top rule match | 0.8991 |
| sk3k | H + skips pass recursive rule matches | 0.9052 |
| sk3n | H + skips pass recursive matches that nest | 0.9085 |

**Checks (confirmed).**
- sk3: 0.9089/54.9, about 300 ms. sk3e, the same engine after the elegance
  review (one fix map keyed by clause, element and position; the jump
  target matched through the same element step, so it records candidates
  and applies fixes), has treeDiff 0 against sk3 and the same fuzzer
  result. sk3n: 0.9085/54.9, 343 ms, treeDiff 136 against sk3.
- Gates, sk3 and sk3n alike: accept cx2=false b1=true b2=true (sk2 all
  false), freespan 1 1 1 1 1 (fails xxab/xyab, which want 3 or 4),
  recommit 16/16 (sk2 1/16), conformance 0 1 1 0 2 3, cleanTreeDiff 0.
- Fuzzer 8 seeds x 400: sk3 worse 2,173 and invalid 1,421 against pd57
  (sk2 2,257/1,297); 709 of sk3's invalid trees delete the whole input.
  sk3n against sk3: sk3n worse in 40 cases, sk3 worse in 5, invalid 1,428
  vs 1,421.
- Long json documents (cost; u28 in brackets): 1000/6/1 sk3 11,002, sk3n
  205 (6); 1000/8/1 11,000 vs 156 (8); 1000/12/1 11,011 vs 195 (11);
  1000/32/1 10,435 vs 411 (29); 1000/64/1 21,917 vs 14,781 (57); 256/4/7
  4,117 vs 41 (4). Time on 1000/6/1: sk3 2.8 s, sk3n 7.3 s, u28 1.0 s.
- Depth: overflow between 800 and 1600 (as sk2). Missing elements 1024
  overflows. Optional-a b repetition n=16384 55 s (quadratic: one re-parse
  per error).

**Why sk3 cascades on long documents (confirmed on a small input).**
`{"k":1,2,{"a":true,"b":null}],...` is missing a `[`. u28 inserts it
(cost 1). sk3 cannot insert, and its cheapest skip is `2,{` (3), after
which the member list resumes at `"a":true`; the inner `}` then closes the
outer object, and every later member is at the wrong depth (cost 54 on
this input, 11,002 on the 6-error rung). Skipping by whole nested matches
makes it skip `2,{"a":true,"b":null}],` instead (23).

**Not fixed (confirmed): a missing closer.** In `[1,0}},"k":197,...` sk3n
deletes `}}`, and the array then takes every later member, paying 1 per
`:` to the end of input (about 180 errors on the 6-error rung). Closing
the array needs the rest of a sequence skipped where the input after it
fits the parent, and the general form of that (mode C) costs 0.03 on the
battery.

**Why the jump loses where it loses (confirmed on examples).** A missing
or stray quote flips which characters are inside strings, so a nested
match that starts at a misaligned brace is a wrong unit: in
`[{"x":[1,2],y":{"z":3}},...` sk3 deletes `y":{` and pays 5, sk3n skips
`{"z":3}` too and pays 30. In expr, `}((a+b)*(c-d))/...` passes a whole
parenthesized factor (sk3 5, sk3n 28).

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| sk3n | 0.9085, long-document costs 25-100x below sk3, 219 LOC | 6 | same battery as sk3, no opener cascade; closer cascade open; 2.6x slower than sk3 on long inputs |
| sk3e | 0.9089, 187 LOC, sk3's trees | 5 | smallest sequence-repair engine; a skipped opener costs the rest of the document |
| sk3 | as sk3e, 199 LOC | 4 | superseded by sk3e |
| sk3k | 0.9052, long costs as sk3j | 4 | strings passed as units |
| sk3j | 0.8991 | 3 | tokens passed as units |
| sk2 | 0.4498, 151 LOC | 2 | no sequence repair |
| u28 | 0.9896, 998 LOC, exact | 8 | still the best on every cost |

LOC: sk2 151 -> sk3 199 (+48, +31.8%) -> sk3e 187 (-12, -6.0%) -> sk3n
219 (+32, +17.1%); sk2 -> sk3n +68, +45.0%.

**Open items, with proposed fixes.**
- Missing closers: allow skipping the rest of a sequence when the parent's
  next element matches right after (the continuation, not any position).
- Openers that are missing rather than extra: no skip-only engine can
  insert one; inserting a single terminal at the frontier is the smallest
  addition.
- Quadratic in the error count and depth 800: as sk2.
