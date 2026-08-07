# Error-recovery experiments

**Not part of the published library.** This directory holds the standing
error-recovery engine, the measurement harness behind
`../../../LESSONS_LEARNED.md`, and an attic of every superseded attempt.

Run from the `dart/` directory:

```sh
dart --packages=$PWD/.dart_tool/package_config.json experiments/recovery/<file>.dart
```

## What is live

- **`c6.dart` — the engine.** Score 0.9879, 84.0% perfect, ~1.5 s battery,
  all gates. See `LESSONS_LEARNED.md` at the repository root for the
  yardstick, the critical lessons, and the refutation ledger.
- `astdiff.dart` — the battery (mutation corpus, expectations, scoring).
- `_score1.dart <engine> [dump]` — battery runner.
- `_accept.dart <engine>`, `_conf1.dart`, `_freespan.dart`,
  `_recommit.dart` — the four gates.
- `pareto.py`, `loc.py` — frontier arithmetic and normalized line counts.

## The attic

`attic/` holds ~300 superseded engines and probes (the m/r/s/t/b/c1–c5
lines), the era-1/era-2 record (`attic/OLD_LESSONS_LEARNED.md`), and
`attic/libsrc_recovery/` — the recovery experiments that once lived in
`lib/src/recovery/` (the published parser performs no recovery; it only
marks syntax errors).

Files named `_*.dart` outside the harness are untracked scratch probes;
many reference archived engines and no longer compile.
