<!-- Part of LESSONS_LEARNED.md, section: 9. The breakthroughs, distilled (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 9.4 Corrections to earlier sections

- **z8 section (lines 9393-9407):** the description of `then` does not match the code. In
  z8.dart:25-26 `owed` and `spent` are plain sums (`o = owed + r.owed`, `p = spent + r.spent`);
  nothing settles `owed`, and no term is subtracted from `spent`. The flag `s`, which the caller
  computes with `settle(o)`, only resets the prefix's `used` to 0.
- **z8 "0% duplicate work"** holds only at rule level. `_plain` on non-rule clauses
  re-matches inner clauses.
- **z8's generality:** it contains grammar-shape special cases at z8.dart lines 19, 21, 69-86,
  108-131, 199-218, 238-259 and 317-321.
- **e4 row:** e4 matched e3's results; a tree-writing fix was made after that and before e4's
  battery run.
- **c25/c20 `wide`** (lesson 61) is a heuristic, not "a bound on the search" (lesson 65).
