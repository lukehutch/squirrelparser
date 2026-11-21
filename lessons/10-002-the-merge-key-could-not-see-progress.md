<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.2 The merge key could not see progress inside a literal

`_span` hashes `farIn`, the edit count, and the memoized rule calls whose extent passes `far`.
Progress inside a multi-character literal, or inside a sequence of terminals in one rule body,
is not memoized, so two states at different places in the same literal got equal keys.
Example: `R0 <- 'c'+ "aabb"` on `cbb`. Inserting `c` at 1 (extends `'c'+`) and inserting `a`
at 1 (starts `"aabb"`) both fail at position 2 inside the same `R0@0` call; the second was
merged into the first, and f1 returned cost 3 (delete everything) where e8 returns 2.

Fix: during each parse, record the terminals whose failed read reached farthest, as (clause,
distance from where the terminal started), and add that set to the key (`_fail`, `_fails`,
`_gmax` in `_f10.dart`). Measured on dl seeds 1-8 in the same run as e8: f1 worse 33 -> 2,
invalid 2 -> 0 (f1k). This is an exact refinement of the key; it adds no heuristic.
