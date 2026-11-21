<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The architecture — three discoveries that define the design

1. **The LR grow-loop IS the recovery loop** (I100, the pivotal insight).
   A mismatch and a left-recursion seed are the same object: a suspended
   reading addressed by (clause, position). The memo entry's grow-loop
   serves left recursion and repair with no second mechanism — left
   recursion is recovery at cost zero. Everything else in the design is
   this loop plus a way to price what it grows.

2. **Parsing mode IS budget zero** (I101), **and the budget is the
   horizon** (A3). With no edits left, the costed descent is
   definitionally the pure parser, so the frozen memo answers
   unconditionally — every spent-out continuation is O(1) to the end of
   the input. The budget ladder is not an optimization: deleting it was
   ~100x latency, twice. The budget marks where repair can no longer
   reach, and the mode split disappears into it.

3. **Judgment must be whole-document and simultaneous.** The b-line's
   greedy commit-then-resume architecture has a proven ceiling (0.88):
   the correct choice between a cheap fill and a dear denial depends on
   repairs not yet made. Every reading must be priced against every
   rival over the whole document before anything commits. (The archived
   chart line achieved simultaneity by re-deriving what the parse knew;
   the c-line achieves it inside the one descent.)
