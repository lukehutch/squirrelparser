<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c22, round 3 — incremental budget sharing (2026-09-08)

**71. Sharing across budgets saves storage, but not this workload's time.**
`_c22shared.dart` preserves this round. One relation per native MemoEntry
grows to the largest requested budget; lower-budget views filter paid cost.
Packed OR edges propagate newly found same-summary choices without replacing
old witnesses. The ordinary PEG memo clock is separate and untouched.

CONFIRMED `_research22.dart battery c22 compare`: .989836 / 1,800 perfect,
zero crashes/uncovered/mischarges/invalid-zero and zero cost differences
from c20, 3,619 ms single-run recovery total. `_properties22.dart c22`:
2,728 cases, 60 clean, zero violations. The final round-2 entry/prefix-bound
variant had the same score and counts (3,737 ms) and passed all current
gates (A3/F5/R16/C6, committed=true, falsePredicates=0).

CONFIRMED fresh serial `_packed22.dart scale 1000 4 1`: length 23,568,
cost=edits=4, covered=true; **33,671 ms / 7,182.4 MiB**, 20,094,898 nodes,
8,449,773 groups, 165,361 cells, 285,516 expansions, 2,070,148 bound prunes.
Fewer stored nodes did not make this sample faster than round 2.
`scale 200 4 1 census`: 315 ms / 345.9 MiB, 77,539 nodes. Changing document
size changes the seeded damage sites, so these two samples are **not** a
scaling-exponent measurement.

**72. Sharing without commitment is now directly executable.**
`_packed22.dart independent 4 tree` uses
`S <- Item*; Item <- ('a' 'x' / 'y' 'a') ';';` on `a;a;a;a;`.
Each site can mark the missing `x` after `a` or the missing `y` before it.
It constructs one forest, then restricts permitted error positions in the
selection query to request every combination. CONFIRMED: **16 combinations,
16 distinct full trees, zero extra forest nodes and zero extra recognition
expansions**. Initial recovery: cost=edits=4, 232 nodes, 92 groups, 21 cells,
31 ms / 282.9 MiB (single cold worker). Every selected tree covers the input
and has exactly the requested four diagnostic positions. This is stronger
than observing fewer frontier entries: earlier choices have not been lost.
It does not yet establish linear total query cost or arbitrary-grammar
complexity. A deletion-count query currently tries impossible splits even
when all repairs in a subtree are known to be holes; the next round derives
that query domain from the forest itself.
