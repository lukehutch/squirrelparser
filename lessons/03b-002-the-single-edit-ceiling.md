<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### The single-edit ceiling

Before e1, a script tried every single-character edit of every battery
input and kept the best by the battery's own scoring. That oracle
scores 0.9847, below z6's 0.9904, so a search that ranks single-edit
repairs well is not enough on its own; the ranking among multi-edit
repairs and the way edits are written into the tree decide the rest.
