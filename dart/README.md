# Dart implementations

Three separate packages, each a complete `squirrel_parser` with its own `lib`, tests and `pubspec.yaml`:

- `noRecovery/`: the parser as given in the paper, without error recovery. A failed match is the
  single `MISMATCH` value.
- `coarseRecovery/`: the published package. The parser with detailed mismatches and coarse error
  recovery, `Parser.parse(recover: true)`.
- `recovery/`: the error recovery work in progress. The parser core with detailed mismatches and no
  coarse recovery, plus the current recovery engine `Squirrel` in `lib/src/recovery.dart`.

This directory itself is the package `squirrel_experiments`: the recovery experiments
(`experiments/`) and scratch drivers (`test/recovery/`), which depend on `coarseRecovery`.

`../run_all_tests.sh` analyzes and tests all three packages.
