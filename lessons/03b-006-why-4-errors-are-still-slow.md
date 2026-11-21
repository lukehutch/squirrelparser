<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### Why 4 errors are still slow

Trace of e14 on rung 4: at the third error (position 12,433) the only
failed call enclosing the failure is the whole document, at position
0, so the window falls back to the start of the input. The cost-3 level
then holds 75k states and cost 4 holds 375k (577k parses, 58 s).
Open: a window for the case where fewer than K failed calls enclose
the failure. Successful calls as a fallback did not help. The z line
handles the same rung (64 errors) in 0.58 s JIT because it settles each
isolated repair once clean input follows it; the e search has no
equivalent and its work grows with the product of the choices at each
error.
