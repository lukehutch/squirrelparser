<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.3 The window drops repairs; a fallback recovers the worst cases

The window is a restriction, not a search order: edits before `left` are never generated.
Example: `R0 <- "caaab" / 'c' / R2; R2 <- 'a' R0 R2++` on `aaab`; the repair is inserting `c`
at 0, before the innermost failed call, and f3 deletes the whole input (cost 4 against 1).
f3 with the key fix (f3k), dl seeds 1-8: worse 36, invalid 5; 4 of the 5 invalid trees are
whole-input deletions. Deferring the out-of-window edits (f8, f9) is sound but each deferred
state costs a full parse of the input, and the rungs slow by 20-30x.

f10 keeps the window and adds one fallback: when the windowed search finds no repair at all,
search again with no window, no frontier prune, a fresh `front`, and a fresh evaluation
count. The fresh count matters: on `babbbcbbcccb` (lf seed set 9-16) the windowed search used
all 400k evaluations, and without the reset the fallback had none left. That case now
returns cost 3 but takes 9 s on a 12-character input.
