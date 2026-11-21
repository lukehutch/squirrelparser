<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### Traps met

- `_research18.dart compare` compares against `BASE` (default c17), so
  e-series runs must set `BASE=e7s`; without it e8 showed treeDiff 2,079
  against itself.
- `_tree` and `_children` read the memo of the most recent parse, so
  they must run before any other state is parsed (an e10 bug).
- Each `dart run` recompiles from the file: editing an engine while a
  background run of it is compiling mixes versions. One rung result
  (1000/4/7, 213 s, 1.05 GB) is discarded for this reason.
