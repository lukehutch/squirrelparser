<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.7 Round 65: z9's other candidates do not replace f25's search (refuted)

Two scratch variants of z10, both in the kit (`z10c.dart`, `z11.dart`).

1. z10c: when z9's best candidate at a rung fails the check, check z9's other candidates at
   that rung in its own order, and move to the next rung only when all fail. f25's search
   remains the fallback when no rung gives an accepted candidate.
2. z11: z10c without `_f25k`. The check builds the edited string and asks the library's
   `Parser` whether the top rule matches all of it (with the round-64 sweep when the stack
   overflows); when no candidate is accepted it returns a syntax error.

Paths taken by z10c (seeds 1-16, 6,400 cases per fuzzer):

| fuzzer | first candidate accepted | a later candidate accepted (mean checks) | f25's search |
|---|---|---|---|
| dl | 6,280 | 117 (4.1) | 3 |
| lf | 6,311 | 70 (3.7) | 19 |

| Measure | z10 | z10c | z11 |
|---|---|---|---|
| battery | 0.9904 / 86.6% | same trees | same trees, 2,619 / 2,639 ms vs z10 2,526 / 2,570 |
| gates | pass | | pass, same numbers |
| dl seeds 1-16: worse / levWorse / invalid, each against the other | 12 / 12 / 0 | 48 / 27 / 0 | 51 / 30 / 3 |
| lf seeds 1-16: worse / levWorse / invalid, each against the other | 6 / 4 / 0 (vs z10c), 4 / 4 / 0 (vs z11) | 33 / 20 / 0 | 52 / 39 / 18 |

z10c is worse: a later candidate at the same rung is often costlier than f25's search's answer,
so the candidates z9 keeps are not a substitute for an exact search. In z11, the 21 invalid
answers are the syntax errors returned where no candidate is accepted. They are small cases
where z9's candidates break PEG semantics: for `R0 <- ('c'? 'c' 'a'?)` on `bc`, z9 deletes
`b`, and then `'c'?` takes the only `c` and the parse fails; the valid repair substitutes `c`
for `b`, and z9 keeps only one way per end and cost.

A fallback search on top of the library's parser cannot be bounded the way f25's is. f25 puts
the next edit no later than the farthest character the failed parse read (`_ext`). The library
does not record that: a `Mismatch`'s `frontier` is the input it accepted, not the input it
read, and a repetition that stops returns a `Match` that hides how far its body read. Without
the bound, every later position is a candidate for each edit, which is quadratic in the length
at cost 2.

Conclusion: f25's search and its interpreter stay as the fallback. The library's parser answers
the check as well as `accepts` (same trees, about 3% slower on the battery), but deleting
`accepts` alone saves nothing while the fallback needs the interpreter.
