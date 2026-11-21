<!-- Part of LESSONS_LEARNED.md, section: z8 (round 59, 2026-10-24): genuine field elimination and returning to z3's simplicity -->
[Back to the index](../LESSONS_LEARNED.md)

### Independent check of z8 (2026-10-24)

Re-run in the kit in one session, JIT unless marked; `_z8.dart` is
byte-identical to the kit's `z8.dart`.

| Check | z8 | z7 | z6 (`zd`) |
|---|---|---|---|
| LOC (`loc.py`, normalized / raw) | 500 / 315 | 806 / 451 | 716 / 413 |
| Battery (`battery X compare`, BASE=zd) | 0.9904 / 86.6, treeDiff 18, costDiff 0 | 0.9904 / 86.6, treeDiff 0 | 0.9904 / 86.6 |
| Battery time, one run each | 3,059 ms | 3,501 ms | 2,895 ms |
| Gates | all pass | all pass | all pass |
| Rungs 1 / 16 / 64 (costs 1 / 14 / 59) | 116 / 330 / 470 ms | 151 / 367 / 533 ms | 150 / 289 / 672 ms |
| `deep.sh` depth 3,200, one missing (AOT) | 192 ms | - | 272 ms |
| `_bits2.dart` costs (c14: 1 and 2) | 6 and 2 | 7 and 8 | 4 and 8 |

Fuzzer, one 5-way run (`z8 / z7 / zd / x513j / e8`), 8 seeds x 400
per row; worse is against the cheapest of the five, so it is higher
than in the 4-way table above, where e8 was absent:

| Row | worse | invalid |
|---|---|---|
| dl 1-8 | 116 / 90 / 81 / 170 / 55 | 69 / 19 / 35 / 22 / 0 |
| lf 1-8 | 188 / 98 / 108 / 137 / 47 | 64 / 25 / 35 / 26 / 0 |
| dl 9-16 | 129 / 96 / 101 / 161 / 51 | 64 / 27 / 46 / 25 / 0 |
| lf 9-16 | 192 / 95 / 111 / 170 / 35 | 63 / 25 / 44 / 43 / 0 |
| Total (12,800) | 625 / 379 / 401 / 638 / 188 | 260 / 96 / 160 / 116 / 0 |

No timeouts. Corrections to the round 59 text above:

- **Trees are not identical to z6.** Costs are (costDiff 0), but 18
  battery trees differ.
- **The battery is not faster than z6.** 3,059 ms against 2,895 ms in
  one session; the round's 2,560-2,755 ms and z6's 2,812-2,899 ms
  were taken in different sessions. z8 is faster on many errors (rung
  64: 470 ms against 672 ms) and on deep inputs (192 ms against 272 ms).
- **"Zero bit-packing" is true of `_Way` only.** `cell.mark` still
  packs the budget and a version counter into one int (`b << 20`,
  `0xFFFFF`, inherited from z3), and `first` still holds the clean and
  preferred flags as values at or above `1 << 30`. A position whose
  version count reaches 2^20 would alias; no test reaches it.
- **`_bits2.dart` has no pass criterion; it prints costs.** z8's 6 on
  the first grammar is 5 above c14's cost 1 (`k1+k1+k1` then delete
  the last `+`), and higher than z6's 4. No z engine finds cost 1.
- **The `_Way` field list above names fields z8 does not have**
  (`cost`, `arms`, `clause`, `children`). The twelve fields are `end`,
  `deleted`, `spent`, `evidence`, `first`, `piece`, `owed`, `used`,
  `incomplete`, `cut`, `prev`, `last`.

Elegance review of z8 (read, not ablated):

- The size cut is real: normalized LOC falls 716 -> 500 (-216, -30.2%)
  against z6, and the bitfield getters on `_Way` are gone. Raw LOC is
  far below normalized (315 against 500) because many lines hold
  several statements; `dart format` would make the file read as its
  normalized size.
- Several conditions name grammar shapes rather than a rule: `i == 1
  && r.owed > 1` (second slot only) and `slots.length > 2` in `_seq`,
  `evidence > absorbed + 1` in `synced`, the `g = 1` default. Each is
  a candidate for an ablation run; if one changes no result it should
  go, and if it does, the reason belongs in a comment.
- `cmp` has seven keys; `charge` adds a hidden eighth.
- `_minChars` is not cached (z6 cached it) and copies a set on every
  recursive call; it runs on every `_repeat` call.
- Good: `then` is the one place prefixes combine; `_ev` and `_tree`
  are iterative; the overflow fallback reuses `sweep`.
