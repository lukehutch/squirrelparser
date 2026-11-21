<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.2 Round 62: z10 with all of z9's validity checks

| Measure | z9 (round 60) | z10 | f25 |
|---|---|---|---|
| battery score / perfect | 0.9904 / 86.6% | 0.9904 / 86.6% (costDiff 0) | 0.9899 / 84.5% |
| gates cx2 b1 b2, recommit, conformance | pass, 16/16, 0 1 1 0 2 3 | same | b2 fails |
| dl seeds 1-16: worse / invalid / levWorse | 143 / 40 / 119 | 103 / 0 / 80 | 122 / 0 / 115 |
| lf seeds 1-16: worse / invalid / levWorse | 161 / 49 / 111 | 112 / 0 / 62 | 93 / 0 / 84 |
| rungs 8/16/32/64 errors, AOT, ms | 201 / 167 / 280 / 337 | 375 / 349 / 437 / 468 | 856 / 1,640 / 6,733 / 12,478 |
| LOC | 448 | 483 (+ 727 `_f25k`) | 719 |

Paths taken: battery 13,241 of 13,241 raw cases checked; dl 6,355 checked and 45 by f25's
search; lf 6,348 checked and 52 by f25's search.

The first z10 run had 126 (dl) and 145 (lf) invalid trees. Cause: f25's `_tree` decided that a
character was substituted by its input position, so an insertion at the same input position as
a substitution was labeled as the substitution. `_f25k` decides by the repaired position
(`_eAt`). This defect is in `_f25.dart` too. f25's own search can produce an insertion and a
substitution at one position, but the fuzzers showed f25 with 0 invalid trees, so the defect is
latent there (inferred: not observed on f25's own answers). `_f25.dart` is not changed.

Correction to 10.9 and 11: under AOT, `deep.sh` shows f25 overflowing the stack at nesting
depth 800 and at n = 1,600 on the cubic family, not at 1,600 (measured 2026-10-25, round 62).

The sources of u28, pd57 and pd23 are lost (the /tmp kit was wiped); only their numbers remain.
