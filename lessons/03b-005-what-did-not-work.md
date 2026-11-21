<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### What did not work

- **e9's expected-input rule:** finds the cases the progress rule
  missed in one pass, but 1 error takes 2.2 s and 4 errors give up.
- **e10's farthest-failure rule and e11's merge:** both fast on 4 errors
  (18.6 s, 46 s), both lose repairs (0.9798, 0.9596). A state that fails
  earlier is not dominated by one that fails later.
- **e12 and e13's cost dominance:** exact on the battery, no faster on
  4 errors.
- **Other windows (e14 variants, battery then 4-error rung):**

  | Window | Battery | treeDiff / costDiff | 4 errors |
  |---|---|---|---|
  | calls in the changed memo only, K = 1 | 0.9898 | 4 / 0 | 80 s |
  | calls in the changed memo only, K >= 2 | 0.9899 | 0 / 0 | >300 s |
  | changed memo + input memo, extent past the failure, K = 1 | 0.9886 | 60 / 20 | 61 s |
  | extent at or past the failure, K = 1 | 0.9739 | 208 / 122 | 1.3 s, cost 7 (wrong) |
  | extent at or past the failure, K = 2 | 0.9899 / 84.3 | 61 / 9 | 0.46 s, cost 4 |
  | extent at or past the failure, K = 3 | 0.9898 | 23 / 0 | >300 s |
  | failed calls only, K = 1 | 0.9782 | 122 / 76 | 21.7 s, cost 7, 2.7 GB |
  | **failed calls only, K = 2 (kept)** | **0.9900 / 84.5** | **2 / 2** | **61 s** |
  | failed calls, successful calls if fewer than K | 0.9889 | 72 / 15 | 61 s |

  The extent K = 2 variant is the only one fast on 4 errors with the
  right cost, but it raises the cost of six battery cases with a
  missing `]` (176, 211, 220, 229, 541, 647): no rule starts at the `,`,
  so the array is the third-nearest call and the window cuts it off.
