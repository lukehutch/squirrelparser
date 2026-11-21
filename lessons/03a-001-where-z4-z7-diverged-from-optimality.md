<!-- Part of LESSONS_LEARNED.md, section: z8 (round 59, 2026-10-24): genuine field elimination and returning to z3's simplicity -->
[Back to the index](../LESSONS_LEARNED.md)

### Where z4–z7 diverged from optimality

`z3` (round 55, `560` normalized / `338` raw LOC) was small, fast (`2.71 s`
AOT), and already scored `0.9901 / 86.4%`. Instead of algebraically
eliminating redundant fields on `_Way`, `z4`–`z7` took two wrong turns:

1. **Bit-packing disguised as field reduction:** `z4`–`z7` packed six
   independent counters (`owed`, `deleted`, `missing`, `fee`, `subs`,
   `arms`) into bit-slices of a single 64-bit `int edits` (`z6` used 8-bit
   fields that silently overflowed at `256` on `_bits.dart` and
   `_chkscale.dart`; `z7` widened them to 15-bit fields with 9shift/mask
   getters). That did not reduce the number of conceptual bookkeeping
   quantities being managed—it merely hid them inside bit-shifts while
   adding code and CPU overhead.
2. **Heavy AST-walking filter passes during candidate generation:**
   `z4`–`z7` added `_tails`, `_matchesOne`, `_firstEdit`, `_steals`,
   `_covers`, `_head`, `_total`, and `_eq`, bloating the engine from
   `560` normalized / `338` raw lines (`z3`) to `806` normalized / `451`
   raw lines (`z7`, +44% normalized LOC) and slowing battery AOT from
   `2,711 ms` (`z3`) to `3,087–3,101 ms` (`z7`).
