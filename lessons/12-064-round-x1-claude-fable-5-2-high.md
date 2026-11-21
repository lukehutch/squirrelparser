<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.64 Round X1 (Claude Fable 5.2, high effort): z60, eleven conditions removed

**Result.** z60 = vfx1, taken unchanged: z59 with 11 conditions or terms removed and nothing added. Fields 8 -> 8,
bookkeeping lines (bkl.sh) 13 -> 13, 492 -> 480 formatted LOC (-12, -2.4%). Every suite row without a time equals z59's
(battery 0.9902/86.5, priceWorse 0/0, tfam and rule naming 3/24, pfam 252/264, exhaustive 0); pdls4/plfs4 worse 121/81
-> 120/79; fresh f3a 0/0/0; held-out equal to z59; LR fuzzer 3,800 lines, 0 different from z59. big.sh flagged rows in
both engines under load; instruction counts on those rows are lower for z60 than for z59 (L 1+) 0.81x and 0.97x, L (1+
0.86x and 0.98x on two repeats).

| Engine | Change from z59 | Fields | bkl | floc | Answers vs z59 | Verdict |
|---|---|---|---|---|---|---|
| **vfx1 = z60** | **11 conditions removed (2 proved, 9 computed)** | **8** | **13** | **480** | **equal on every set** | **chosen** |
| vfx1 + 29d | `st` without one more conjunct | 8 | 13 | - | one input +1 on each of two fresh seeds | rejected |
| vfx1 + 02a / 07a | two speed-related conjuncts removed | 8 | 13 | - | equal; 1.54x instructions at k = 256 / faster growth | rejected |
| vfx1t2, vfx1qe | no `evidence`, other tie-breaks | 7 | - | - | battery 0.9884-0.9886 (band 0.9896) | rejected |
| vfx1p1 | `_pureSub` from the span identity | 8 | 13 | - | tfam 1/1, group4 cbc 2 16 27 38 (was 2 5 8 11) | rejected |

**What taught something.**
1. **`evidence` stores the one quantity the way's tree does not contain: how the clean characters split between
   literal and wildcard matches.** Over a span with nothing owed, end - a = C + W + S + D and spent = S + D + I, where C
   counts clean characters matched by literals and W those matched by wildcards; `evidence` is C. The edit tree gives S,
   D and I, so C + W is derivable, but the split is not, because the way keeps only its edit leaves, not its clean
   sub-matches. The split matters on unclosed strings: closing the string at once and letting `[^"]` run on can cost the
   same, and only the count of literal matches separates them. It cannot be recovered later, because `_repeat`'s queue
   keeps one way per end and drops the loser before any top-level tie-break runs (a final choice by the reparsed tree's
   evidence, vfx1t1, brings 167 differing trees down to 35, not to 0). This is 12.63 item 1 again: a field survives when two builds of the same edits need different
   values, and here they differ in their clean parts.
2. **A one-conjunct removal screen finds dead conditions that named-mechanism ablations miss, but only late tests reject
   the false ones.** Earlier rounds removed whole mechanisms. Removing each conjunct of each condition alone found 11
   that change no measured answer; the conditions were most likely made redundant by later changes (inferred: no
   round traced when each became dead). The suite also passed three removals that were wrong. Tests outside the suite
   caught them: a second fresh seed (29d), instruction counts at k = 256 (02a), and growth up to k = 512 (07a). A
   condition can be redundant on every input the suite holds and still be needed on a larger or different input, so
   a screen is only as good as its widest test.
3. **Under load, instruction counts are the right test of speed, and wall-clock times are not.** Under load averages of
   50 to 100, single big.sh runs flagged up to 4 of 10 rows for z60 and 1 of 10 for z59, on different rows each run.
   Instruction counts, which load does not change, put z60 at or below z59 on every flagged row. Fable reached the same
   conclusion and recorded against itself that it measured times first. A wall-clock failure should be followed by an
   instruction count before it is acted on.
4. **The agent removed what the screen proved removable and did not attempt a new design.** It spent the session on
   field analysis and the screen, and reported question 5 (a different design) as not attempted. The result is the
   smallest engine so far at the same field and bookkeeping counts. It also shows that z59's design is close to
   exhausted for single-condition removals; further cuts in fields or bookkeeping lines need a change to the search,
   for example reading W from the parser's memo table when two ways tie.
