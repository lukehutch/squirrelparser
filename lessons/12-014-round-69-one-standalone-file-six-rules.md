<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.14 Round 69: one standalone file, six rules fewer (adopted)

z12 (kit) is z11 with z9's search and the exact search copied into one file, so an engine no
longer imports another. z13 (repo `dart/experiments/recovery/_z13.dart`) is z12 with these
changes:

1. Six rules deleted: the Optional trim, two `_repeat` step filters, the skip that stops a
   First after an arm that consumed, the incomplete-ways fallback, and the First break on a
   total arm (with its `_total` map). One comparison key (`paired`) deleted.
2. The checked path returns the library's tree of the repaired string, mapped onto the input
   (the same map the exact search uses), not z9's own tree. z9's tree builder `_tree` is gone.
3. The edits are read from the search records directly, in input order. z12 read them off
   z9's tree and sorted them with `List.sort`, which is not stable above 32 elements.
4. The tree map walks with an explicit stack.

Measured (kit, AOT):

| | z12 | z13 |
|---|---|---|
| LOC | 572 | 537 (-35, -6.1%) |
| Fields: way / cell / engine | 13 / 7 / 18 | 13 / 7 / 17 |
| Battery score / perfect | 0.9904 / 86.6 | 0.9904 / 86.6 (treeDiff 0 against z12 with the mapped tree) |
| Gates | all pass | all pass |
| dl seeds 1-16: worse than the other | 16 | 5 |
| lf seeds 1-16: worse than the other | 16 | 1 |
| Invalid trees, timeouts | 0, 0 | 0, 0 |
| Rungs 8/16/32/64 errors (ms) | 189/157/279/298 | 214/204/274/306 |
| Dense `bc `*256, `bb `*256, third probe *256 (s) | 9.7, 3.6, 37.8 | 4.7, 2.3, 33.2 |
| Nesting 25,600 with one error | 2.2 s | 2.3 s |

The rules were found by switching each one off in a scratch copy (z12x). Eleven of them left
every battery tree unchanged, but the fuzzers showed five of the eleven still matter:

| Switched off | dl / lf worse than z12 (seeds 1-16, or 1-2 where marked) | Kept |
|---|---|---|
| `look` (lookahead probe in `_plain`) | lf 81 vs 9 | yes |
| `rsubst` (substitution in a repetition) | 6 vs 0 (1-2) | yes |
| `kso` (spent + owed key) | 2 vs 0 (1-2) | yes |
| `fsub`, `ex`, `rfilt2` | 1-2 each (1-2) | yes |
| `rdemote` | battery same, `x (ax)*200 b` 6 ms -> 455 ms | yes |
| `total` | lf 1 vs 14: better without it | deleted |
| opttrim, rfilt, actskip, inc, kpaired | 0-1 | deleted |

Lesson: the battery does not decide a deletion. A rule with treeDiff 0 on the battery changed
the cost of 72 lookahead fuzzer cases.
