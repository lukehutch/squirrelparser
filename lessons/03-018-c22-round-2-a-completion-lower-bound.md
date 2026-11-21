<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c22, round 2 — a completion lower bound (2026-09-08)

**70. Regular relaxation prunes some recognition, not enough.**
`_c22bound.dart` preserves the variant. It compiles grammar entry/exit
states into a regular over-approximation: calls may return through any
caller, assertions are ignored, and terminal substitutions are permitted
more broadly than the real engine. A backward edit-distance table on
state × input-position provides a necessary completion-cost bound. EOF
holes are free in this bound; real fees and coherence are still checked
by packed selection. It never constructs a repaired input or Match tree.
INFERRED admissibility: every real repair has a path in this relaxation;
the converse is deliberately false. It is a lower-bound analysis, not a
second ordinary Parser or a distance/proximity heuristic.

CONFIRMED `_packed22.dart schedule` on round 1: 2,101 cases, **zero tree
or cost changes when OR traversal is reversed**, 8,142 ms total for both
orders. This tests selection-order independence, not all possible fixed-point
schedulers.

CONFIRMED intermediate bound-at-cell-exit battery: .989836 / 1,800 perfect,
zero crashes/uncovered/mischarges/invalid-zero, zero cost differences from
c20, 4,044 ms single-run timed recovery (`_research22.dart battery c22 compare`).
With the bound also used at entry and sequence prefixes,
`_packed22.dart scale 1000 4 1` printed cost=edits=4, covered=true,
**29,951 ms / 8,571.4 MiB**, 23,510,004 nodes, 10,044,280 groups,
268,166 budget cells and 25,155 query states. This was a fresh serial worker.
The bound removed roughly one quarter of the eager forest nodes; that is
still far worse than the c20/c21 controls. It is not promoted as a speed win.

The next round shares a relation across budget rounds rather than rebuilding
its zero/low-cost structure in separate budget cells. This change must be
tested, not assumed tree-neutral: guards and seed invalidation also observe
the available budget.
