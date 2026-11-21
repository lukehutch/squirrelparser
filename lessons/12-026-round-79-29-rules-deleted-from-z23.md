<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.26 Round 79: 29 rules deleted from z23, screened on long inputs (z24)

**Method.** Each candidate deletes one condition, test or tie-break from z23 (kit `z22v`).
Each was run alone on the battery, then on the long sets (ex2/in5g1, in5g3, in5g5: 600 inputs
each), the dl and lf fuzzers and the exhaustive check (41,524 inputs). The survivors were merged
and the merge went through the whole suite again, plus the dense probes.

**The long sets catch what the short checks miss.** Three deletions that passed the battery, the
fuzzers and the exhaustive check made long inputs dearer:
- a8, the greedy-slot check (`_greedy`, `_takes`, `_head`): long g3 inputs dearer by up to 33
  against 8, 9 and 6. zc1, zc3 and zc4, merges that included it, were dearer on 112 g3 and 5 g1
  long inputs.
- a10, a settle condition: 5 long g1 inputs dearer.
- a24 (drop `slots.length > 2` in the sync test) with b21 (drop the clean-step test in `_repeat`):
  one g5 long input dearer (7 against 6). a24 alone is fine and b21 was dropped.
Every candidate deletion must now be screened on the long sets.

**A merge must rerun every check, and single-candidate checks miss pairs.** zf1 (zc8 + 16 of
batch 3) failed three checks: the batch-3 exhaustive run had aborted on g2 to g5 (an `xargs`
bug in the run script, fixed), so two harmful deletions got through.
- e21 (drop `o.first > r.end` in `settle`): alone, 69 g5 exhaustive misses (`aqx` 3 against 2).
- e30 (drop z23's eager settling in stage -1): alone, non-LR `1+)` 39.7 s at k = 64 against
  0.32 s, though `(1+` prices are lower (121 against 128 at k = 128).
- e44 (drop `incomplete` from the cell key) with e45 (drop the `first > end` normalization of the
  same key): lf seed 13, `R0 <- ('b'?+ 'c')` on `c`, cost 2 against 1. Each alone gives 1; found
  by bisecting the 14 remaining deletions. Keeping either fixes it: zf3 keeps e45's part, zf4
  keeps e44's. Both pass every check; zf3 is cheaper on 3 long inputs and was chosen.

**z24 = z23 minus 29 rules.** Repo `dart/experiments/recovery/_z24.dart`, kit `zf3`.
- From zc8: a2 (Str filter `r.evidence > 0 || r.cost <= _budget`), a6 (`pen` and `del`), a11
  (the Terminal/First early add in `_repeat`), a17 (`r.cut >= pe || pe != r.end`), a23
  (`w.owed <= 1` in the doubt test), a24, a26 (sync test simplified), a29 (the `_versions++` for a
  seeded First), b6 (`sync ||` in `_next`), b8 (final repeat mapping is `_ => r`), b9a and b9b
  (evidence and owed tie-breaks), b16 (Seq `0 when req` in `_minChars`), b17 (Optional demote),
  b22 (`_oneShape` in the Ref filter), b23 (`r.evidence != 1` in rSub).
- From batch 3: e3 (`r.clean` in the label filter), e4 (`_depth == 0`), e7 (`r.end == pos` in the
  cell add test), e15 (`out.isNotEmpty` before restoring `_seedDepth`), e16 (the plain-match test
  for a Ref in `_startsClean`), e18 and e27 (two `_active` tests; `_arm` is then unused and
  deleted), e22 (the end-of-input test on `adv`), e28 (`dEv > 1` in rSub), e37 (`f != pos` in
  Optional), e39 (the `preferred` tie-break), e44 (`incomplete` in the cell key), e46
  (`incomplete` in the queue key).
606 -> 594 LOC (-12, -2.0%). Fields unchanged (`_Way` 10, `_Cell` 4); the local `pen` is gone.
Many deletions shorten a line rather than remove one, so the LOC change understates the change.

| | z23 | z24 |
|---|---|---|
| LOC | 606 | 594 (-12, -2.0%) |
| Battery | 0.9904 / 86.5, 4,983 ms | 0.9908 / 87.1, 4,830 ms; 52 trees differ, all from a6 |
| Gates | all pass | all pass |
| dl / lf worse, invalid, timeouts, levWorse, priceWorse | 0 | 0 |
| Exhaustive misses (41,524) | 0 | 0 |
| Long sets g1 / g3 / g5 against z23 | | 0 dearer; cheaper on 0 / 2 / 1 |
| Long sets ms against z21m (same run) | | 2,350 / 1,873 / 668 against 2,756 / 3,226 / 859 |
| `(1+` / `1+)`, k = 128 | cost 128 / 128, 416 / 603 ms | same costs, 381 / 345 ms |
| LR `(1+` / LR `1+)`, k = 128 | cost 129 / 130, 211 / 21 ms | same costs, 207 / 22 ms |
| depth, `x (ax)*n b`, `x (ab)*n` at n = 1600 | linear, 108 / 159 ms | linear, 109 / 152 ms |

**Refuted this round.** a8, a10, b24 (one long input dearer and one cheaper), b21 with a24, e21,
e30, and e44 with e45 (above). On the battery against zc8, 12 batch-3 deletions changed trees
or costs (ze1, ze10, ze20, ze23, ze24, ze26, ze32, ze38 and others); ze17, ze31, ze33 and ze48
made long inputs dearer; on the fuzzers ze8, ze14, ze19, ze29, ze36, ze40, ze42, ze43 and ze47
were dearer. ze47 deletes the doubt test (dl 49 and lf 19 dearer), which confirms 12.25's case.
In the earlier batch on zc4, d2, d6, d9, d34 and d41 lowered the battery score (d34 to 0.8615 at
167 s).

**Open.** Unchanged from 12.25: LR `(1+` and non-LR `1+)` quadratic in the local stage, local
prices on dense LR `(1+`, and `cbcaccbccab` x k.
