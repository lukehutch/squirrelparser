<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### What worked

- **The incremental memo (e4).** A rule result that examined no edit is
  valid for every repaired string that leaves its window alone, so it
  is stored once in input coordinates. Same answers as e3, about 18
  rule computations per parse instead of a full parse.
- **The enclosure tie-break.** Among equal-cost repairs, prefer the one
  whose named constructs keep more real input. It took e5 from 0.9894
  to 0.9898 / 84.5.
- **Writing deletions and substitutions into the tree as the library
  parse saw them (e6).** Uncovered cases 24 to 0 with the score kept.
- **The progress rule (e7)**, then **the second pass (e7s)**: a state
  grows only if its last edit read further, was read where the parent
  failed, or appends at the end. Without it, inserting anywhere the
  parse reads multiplied the cost-2 states by about 100 (battery 43.8 s
  against 4.6 s); the second pass, run only when needed and capped below the first answer,
  restores the cheapest repair in the cases the rule cut.
- **The failed-call window, K = 2 (e14).** Edits only at or after the
  second-nearest start of a rule call that failed and examined the
  failure point. Battery unchanged in score (two costs higher), 1 and
  2 errors on 23.5k characters in about 0.2 s instead of 0.8-1.5 s.
