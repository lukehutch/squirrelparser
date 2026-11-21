<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.49 Coarse recovery in the library: gaps at repetition stops (idea 1), and why sync rules (idea 2) were not built

**The objective (user, 2026-11-01).** Stop full-repair search. Try (1) recovery only inside `*`/`+`: when the parse
fails, take the places where a repetition stopped at the parse frontier and widen a syntax-error gap there, one
character at a time, deepest repetition first, until a reparse gets further; or (2) recovery rules marked in the
grammar (for example a statement) and resynchronization at the next place one matches. Expectation: recovery is
coarse, but it should start as early as possible after the error, keep as much of the tree as possible, and report
the later errors too. Built in the library itself (`Parser.parse(recover: true)`), not as a separate engine.

**The algorithm (v10c, as committed).** 71 added code lines (combinators.dart +16, memo_entry.dart +8, parser.dart
+88/-2 with comments; 284/284 library tests pass, and `recover` defaults to false, so the plain parser is unchanged).
- `Repetition` records every place its body failed (`stops`). If `gaps[(rep, pos)] = g` exists, it adds a
  `SyntaxError` of `g` characters as a child and goes on after it.
- Each memo entry stores `reach`, the furthest position any repetition tried its body during the attempts that set
  the entry. After a gap at `pos` changes, only entries at or before `pos` whose reach is at least `pos` are dropped;
  everything else is reused (the memo is never rebuilt from scratch, in the spirit of the no-duplicate-work ruling).
- The frontier is the furthest position any mismatch in the result or in the recorded stops read.
- For g = 1, 2, ...: every stop whose body read up to the frontier, or that reaches it with the gap, gets a trial gap
  of g characters and a reparse. Among the trials that read past both the old frontier and the gap (or match the whole
  input), the one that reads furthest is kept (innermost on a tie). Repeat until the whole input matches.
- If no gap helps, `fillAtEnd` lets a `Seq` that is missing elements at the end of the input fill each with a
  zero-length `SyntaxError`, and the search goes on.

**Measures.** Driver `_gap1.dart`: the 2,101 inputs of the battery, scored against the reference trees; "tree" =
the result is not one whole-input error; "first error before damage" = the first `SyntaxError` begins before the
damaged position (lower is better recovery, since it means the error is reported earlier than the damage). Driver
`_gapscale.dart members/k`: a generated JSON document of `members` members with `k` random edits, timed. Driver
`_gapshow.dart`: prints each gap chosen.

**Results.**

| Variant | Battery score | Trees | Notes |
|---|---:|---:|---|
| recover=false (plain parser) | 0.1363 | 598 | 127 ms |
| gap1: first stop at the frontier only | 0.5258 | | |
| gap2: all stops at the frontier | 0.6222 | | |
| gap3: kept only if the body matches again after the gap (strict, close to sync recovery) | 0.6114 | | |
| gap4: gap2 + `fillAtEnd` | 0.8150 | | |
| gap5/8/9 (v9): gap4 + memo reuse by `reach` | 0.8193 | 2066 | 335 ms; first error before damage 544 |
| gap6: terminal repetitions excluded | 0.6719 | | |
| gap7: terminal repetitions last | 0.8061 | | |
| mode B / mode C (other acceptance rules) | 0.6134 / 0.7611 | | |
| v10b: candidates widened to stops that reach the frontier with the gap | 0.8189 | 2090 | 357 ms |
| v9 candidates + keep furthest | 0.8152 | 2068 | 342 ms |
| **v10c: widened + keep furthest** | **0.8276** | **2090** | 396 ms; first error before damage 746 |

v10c by category: deletion 0.7402, misc 0.7149, insertion 0.9813, substitution 0.8186, truncation 0.8493 (v9: 0.7364,
0.6968, 0.9776, 0.7979, 0.8458).

Scaling (one run each, nothing else running):

| members/k | v9 gaps | v9 time | v10c gaps | v10c time |
|---|---:|---:|---:|---:|
| 1600/16 | 192 | 7.3 s | 46 | 0.45 s |
| 1600/64 | 402 | 0.73 s | 184 | 2.1 s |
| 6400/16 | 656 | 132 s | 41 | 1.8 s |
| 6400/64 | 1375 | 71.6 s | 181 | 10.3 s |
| 6400/256 | 1589 | 15.0 s | 745 | 24.3 s |

No run returned a whole-input error. Memo reuse (v8 -> v9): 1600/4 3,044 -> 280 ms, 400/16 5,701 -> 212 ms,
1600/1 876 -> 84 ms.

**R-gap-1: v9's slow cases were a cascade, not a slow search (confirmed with `_gapshow` on 200/2).** A deleted `"`
before `x` was repaired by a 1-character gap at whitespace, the first stop that moved the frontier. That made a later
`}` close the top-level object early; from then on only JSON's trailing whitespace stopped at the frontier, and the
rest of the document was skipped in about 94-character gaps, each ending where one space could be read (one space
counts as progress), each needing about 94 trial reparses. The right repair was a 1-character gap at the member
repetition's stop one position before the frontier, which v9 excluded because that stop's body did not read up to the
frontier. v10c includes such stops and keeps the trial that reads furthest; 200/2 drops from 11 gaps to 5 and the
16-error inputs from minutes to seconds.

**R-gap-2: what remains coarse (confirmed on 400/4, inferred in general).** Progress is measured in characters read,
so a gap that lets the parser read one more whitespace character counts as success, and a string-parity flip (a
deleted `"`) is repaired by deleting the next quotes one at a time (400/4: 12 gaps for 4 edits). Trying every candidate
for each g costs one reparse per candidate, which is why 6400/256 is 1.6x slower than v9. Possible fixes not yet
tried: count progress in completed repetition iterations rather than characters; prefer the gap that lets its own
repetition's body match again (gap3's rule as a tie-break, not a filter).

**R-gap-3: idea (2) was not built (decision, with its reason).** gap3, which keeps a gap only when the repetition's
body matches again after it, is the nearest automatic version of resynchronizing at a marked rule, and it scored
0.6114 against gap4's 0.8150: requiring a whole new iteration skips too much. A marked recovery rule would also need
the tree between the failure and the next match rebuilt for whatever rule encloses it, which the repetition gap gets
for free because the repetition is the enclosing node. The metagrammar's `~` prefix shows where such a marker would
go if it is wanted later.
