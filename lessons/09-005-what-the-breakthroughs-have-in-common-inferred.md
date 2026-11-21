<!-- Part of LESSONS_LEARNED.md, section: 9. The breakthroughs, distilled (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 9.5 What the breakthroughs have in common (inferred)

1. **The large speedups were all exact prunes.** The stop prune, the floor inside each rung,
   the return-site bound, exact skip bounds and credit settlement each remove only work that
   provably cannot change the answer. Every heuristic prune (windows, caps, w1, wide) was later
   shown to lose answers on some input.
2. **The large size reductions all came from making one mechanism do two jobs.** Budget 0 is
   the parser; the grow loop is the recovery loop; one fix kind is every repair; the memo table
   is the search state; the window edge is a count the repetition already makes.
3. **Validity came only from construction.** Every guard-based validity fix (cdx11r, cl24,
   x472, z5-z8) reduced invalid trees but never to zero, and held-out seeds showed part of the
   gain was fitted. Only searches whose state is a parse of the repaired string (pd23, e7s, e8)
   reached 0.
4. **Quality is mostly judgment among equal costs.** 0.48 of the score separates a scalar DP
   from the c-line, and 83% of x464a's gap is tie choice. The keys that matter: a later rival
   wins ties, fewer avoidable edits, and PEG's own reading of the input.
5. **Scaling to many errors needs the search cost to be a sum over errors.** Credit settlement
   (z) and windows (c17/c18, e14) do this; a global front with whole-document totals (c19, c20)
   does not.
