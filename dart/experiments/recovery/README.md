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
| **`m26.dart`** | **382** | **517/519** | **current winner**: A1-A5, left recursion correct, fastest |
| `m25.dart` | 394 | 517/519 | m24 + one entry object per item instead of four parallel tables |
| `m24.dart` | 393 | 517/519 | m23 + total (never-throwing) reconstruction with a Ref cycle guard |
| `m23.dart` | 371 | 517/519 | m22 + A5, the parser's left-recursion memo rule |
| `m22.dart` | 337 | 517/519 | goal wrapper `Seq([top, Nothing])`; **wrong on left-recursive grammars** |
| `m19.dart` | 362 | 517/519 | m18 + First/Optional unified |
| `m18.dart` | 373 | 517/519 | the axiomatic engine (A1-A4); recursion is the dot |
| `m17.dart` | 357 | 517/519 | m16 with only the span loop replaced by a unit skip edge |
| `m20.dart`, `m21.dart` | 350, 361 | 517/519 | rejected memo representations (2.4x, 2.0x slower) |
| `m16.dart` | 352 | 517/519 | smallest pre-A5 variant; absolute regret pricing |
| `m15.dart` | 406 | 517/519 | speed-safe variant; deviation regret pricing |
| `m12.dart` | 396 | 516/519 | predecessor-walk reconstruction (caps at 516) |
| `sd6.dart` | 526 | 512/519 | the "v6" baseline all speed ratios are relative to |
| `sd5.dart`, `sd3.dart` | 513, 499 | 512/519 | earlier steps in the same line |

## Gates

- **`bf_check.dart` — brute-force ground truth.** Computes the true minimum edit
  distance by BFS over single-character edits against the pure parser, over five
  grammars chosen to vary left recursion. This is the only gate that can catch an
  error every engine shares; it is what found the left-recursion defect. m26: 44/44.
- `lr_check.dart` — left-recursive grammars, coverage only (weaker than `bf_check`).
- `<engine>_misses.dart` — the 519-mutant battery:
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
