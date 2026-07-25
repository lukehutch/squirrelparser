# Error-recovery experiments

**Not part of the published library.** These are the measurement harnesses and
candidate implementations behind `../../../LESSONS_LEARNED.md`. Nothing here is
imported by `lib/`; the recovery engines under test treat the parser as an oracle
only (`Parser.match`, `Parser.parse`).

Run from the `dart/` directory:

```sh
dart --packages=$PWD/.dart_tool/package_config.json experiments/recovery/<file>.dart
```

`dart analyze` cannot resolve these (they use `package:squirrel_parser/src/...`
paths); running them is the only check.

## Candidate implementations

| file | LOC | shape | note |
|---|---|---|---|
| `m16.dart` | 352 | 517/519 | smallest correct variant; absolute regret pricing |
| `m15.dart` | 406 | 517/519 | speed-safe variant; deviation regret pricing |
| `m12.dart` | 396 | 516/519 | predecessor-walk reconstruction (caps at 516) |
| `sd6.dart` | 526 | 512/519 | the "v6" baseline all speed ratios are relative to |
| `sd5.dart`, `sd3.dart` | 513, 499 | 512/519 | earlier steps in the same line |

## Gates

- `m15_misses.dart`, `m16_misses.dart`, `sd6_misses.dart` — the 519-mutant battery:
  shape / cover / cost histogram. Each prints a `dot` reference row **before** the
  row under test; grep `^superdot` for the variant.
- `m15_valid.dart`, `m16_valid.dart` — the 7 valid documents must be untouched.
- `edge_check.dart` — degenerate inputs (empty string, lone brackets). This is the
  gate that found the empty-input `RangeError`; the mutation battery structurally
  cannot.
- `identity_check.dart` — proves m15's and m16's regret formulations are the same
  objective (0 cost and 0 regret disagreements over all 519 inputs).
- `table_cmp.dart` — per-case latency, `dot` vs v6 vs m15 vs m16, alternating in one
  process. `win_cmp.dart` is the same without `dot`.
- `d_allengines.dart <engine>` — the older `lib/src/recovery/` engines
  (`skip`, `semiring`, `agenda`, `frontier`, `dot`, `search`) on the same battery.
  **Requires the untracked `lib/src/recovery/*.dart` files**, which are not
  committed; it will not compile without them.
