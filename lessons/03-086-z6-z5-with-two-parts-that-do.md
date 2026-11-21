<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z6 - z5 with two parts that do nothing deleted (2026-10-23)

`_z6.dart` is `_z5.dart` with three changes. Every tree, cost and gate
is the same as z5's. Size goes from 418 raw / 732 normalized lines to
413 / 716 (-16 normalized, -2.2%).

1. `_wraps` (the zero-growth left-recursion cycle check) is deleted.
2. `_resumes` (the look-ahead condition on the one-letter skip in
   `_seq`) is deleted.
3. `_minChars` is cached per clause (`_mins`, `_min0`) at the two call
   sites that pass no path set. It used to rebuild its path sets on
   every call.

**Measurements** (kit, 2026-10-23):

| Check | z5 | z6 |
|---|---|---|
| Battery | 0.9904 / 86.6 | 0.9904 / 86.6, treeDiff 0 |
| Battery JIT, same session, 3 runs | 3,106-3,201 ms | 2,812-2,899 ms |
| Battery AOT (`x3.exe bench 3`) median | 2,844 ms | 2,796 ms |
| Gates | all pass | all pass (`0 1 1 0 2 3`, recommit 16/16) |
| props / pred / window | 0 / 0 / P at every n | 0 / 0 / P at every n |
| dl, lf invalid | 35, 35 | 35, 35; worse 0 against z5 in both |
| Depth 3,200, one missing | 294 ms | 280 ms |

The dl and lf `treeDiff` column reads 100 and 50 even between z5 and an
exact copy of z5, so that column does not compare engines.

**What each z5 part is worth.** Twelve copies of z5, each with one part
removed, run on the battery, gates, dl and lf in one run (worse counts
are against the cheapest of the 13 engines in that run):

| Part removed | Battery | dl worse / invalid | lf worse / invalid |
|---|---|---|---|
| none (z5) | 0.9904 / 86.6 | 19 / 35 | 22 / 35 |
| `_wraps` | same | 19 / 35 | 22 / 35 |
| `_resumes` | same | 19 / 35 | 22 / 35 |
| `penalize` fee | 0.9908 / 87.1, gate b2 fails | 19 / 35 | 22 / 35 |
| `mustAdvance` | 0.9900 / 86.3 | 17 / 34 | 21 / 35 |
| look-ahead probe in `_plain` | same | 19 / 35 | 73 / 44 |
| `_firstEdit` filter | same | 28 / 50 | 27 / 45 |
| one-letter skip in First | same | 28 / 35 | 37 / 36 |
| `lrNullRep` | same | 20 / 39 | 19 / 35 |
| tails check on one-letter skip | same | 20 / 37 | 20 / 39 |
| tails check on skip-ahead | same | 16 / 39 | 24 / 41 |
| active-arm skip in First | same | 25 / 40 | 24 / 36 |
| owed term in the `_seq` budget test | same | 25 / 35 | 28 / 36 |

Only `mustAdvance` and the `penalize` fee change the battery. The
`penalize` fee exists for gate b2 and costs 0.0004 on the battery. The
other parts earn their place on the fuzzers only.

**Where z6's time goes.** On the battery, z5 runs 1.13 rungs per case,
and 87% of cases cost 1, so reusing work across rungs would save almost
nothing. Per case, it makes about 1,486 `_read` calls, 2,188 `_plain`
calls, 975 evidence walks and 1,300 grammar walks (`_tails`,
`_startsClean`, `_matchesOne`). A finished cell holds 2.1 ways on
average. The cost is rung 1 looking for repairs at every position of
the input. z6 runs 28.0G Ir on the battery under callgrind; x513j's
recorded 12.72G is from another build.

**Open, in order.**

1. Limit rung-1 repairs to a window around the failure (as in c18),
   keeping the window counterexample passing.
2. Replace the five grammar walks (`_minChars`, `_oneShape`, `_tails`,
   `_startsClean`, `_matchesOne`) with one table per clause, built once.
3. Decide whether gate b2 is worth 0.0004 on the battery.
