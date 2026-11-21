<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.4 The replay produced an edit order the tree builder cannot render

`finish` re-tries a shadow `s` with the descendant's later edits when the first of them is at
a later position, or at the same position after an insertion. It allowed a substitution after
an insertion at the same position, which `_children` never generates; the string was right
(`cabc` -> insert `c` at 1, substitute `a` -> `b` at 1 = `ccbbc`), but `_tree` drew two
one-character errors at position 1. Fix: at an equal position the later edit must also be an
insertion, the same rule `_children` uses.
