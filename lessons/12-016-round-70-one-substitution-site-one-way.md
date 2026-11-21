<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.16 Round 70: one substitution site, one way per end in the queue, memoized skip scans (adopted)

z15 (repo `dart/experiments/recovery/_z15.dart`) is a standalone copy of z13 with three changes,
built in steps (z13u, z14, z15 in the kit):

1. A substitution is offered where a one-letter terminal fails to read, instead of at three
   places (a `_seq` slot, a `_repeat` body, and a First whose one-letter arms are all the same
   letter). The First rule and its `_key`/`_str` map are deleted.
2. `_repeat`'s queue of ways waiting to be extended holds one way per (end, incomplete), the
   best by `cmp`. A way with more budget used at the same end is still kept in `best`, so its
   callers see it, but it is not extended: its extensions cannot be cheaper.
3. Both skip loops (`_seq` and `_repeat`) call `_next(clause, from, to, test)`, the first
   position where the clause reads cleanly. Each scanned position records its answer or a jump
   past a span with no answer, in one integer list per (clause, test), so the scans cost one
   read per position overall. The scan stops at the budget limit, as the old loops did.

Measured (kit, AOT):

| | z13 | z15 |
|---|---|---|
| LOC | 537 | 542 (+5, +0.9%) |
| Fields: way / cell / engine | 13 / 7 / 17 | 13 / 7 / 17 (`_str` out, `_nexts` in) |
| Battery score / perfect | 0.9904 / 86.6 | 0.9899 / 86.2 (62 trees differ, 4 costs lower) |
| Battery time | 2.9 s | 3.0 s |
| Gates | all pass | all pass |
| dl seeds 1-16: worse than the other | 11 | 3 |
| lf seeds 1-16: worse than the other | 6 | 2 |
| Invalid trees, timeouts | 0, 0 | 0, 0 |
| Rungs 8/64 errors (ms) | 212/332 | 230/288 |
| Dense `bc `*256 / *1024 (ms) | 4,420 / - | 89 / 465 |
| Dense `bb `*256 / *512 / *1024 (ms) | 2,190 / 9,747 / - | 95 / 212 / 578 |
| Third probe *256 / *1024 | 33 s, exact path | 7 / 25 ms, checked path |
| Nesting 25,600 with one error | 2.3 s | 2.4 s |

How the dense cost was found: counters in a scratch copy. On `bb `*k, `_repeat`'s best cell held
about k^2 ways (1,088, 4,224, 16,640 for k = 32, 64, 128), one per (end, used) pair, and every
one was extended. Keying every cell by end alone made the ways linear but cost fuzzer quality
(dl 6 vs 2, lf 5 vs 1 against z13). Switching the key place by place showed that only the
queue matters: the queue alone keyed by end gave the same battery trees and 0/0 fuzzer
difference against z13u, at 33x the speed on `bb `*256. After that, reads grew about 2.2x per
doubling and the skip scans 4.5x; memoizing the scans made them linear. The first memo scanned
to the end of the input and keyed a map by records (battery +21%, rungs 2.2x, memory 2x); the
bounded scan with a jump list removed both.

Substitution at the terminal alone (z13u) was 8.5x slower than z13 on `bb `*512 (82 s vs
9.7 s), because the substitution inside `'c'?` added ways at every unit. Filtering it out of an
Optional body (z13v) restored that speed but sent the third probe back to the exact path; the
queue change made the filter unnecessary.
