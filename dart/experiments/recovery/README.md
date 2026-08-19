# The recovery engine

**Not part of the published library.** This directory holds the standing
error-recovery engine and the attic of every superseded attempt.

- **`c9.dart` — the engine.** Self-contained: the full squirrel parser is
  folded in, and the published library contributes only the interchange
  types (the grammar AST in, `MatchResult` trees out). Score 0.9879,
  84.0% perfect, ~0.6 s battery, all gates, analyzer-clean, documented
  end to end in plain language. c9 is c8's algorithm bit-for-bit (the
  battery trees are identical) on faster data: flat cells, views cached
  between changes, naming applied per change — 1.7x faster, measured
  paired and interleaved. See `LESSONS_LEARNED.md` at the repository
  root for the yardstick, the critical lessons, and the refutation
  ledger.
- **`attic/`** — ~320 superseded engines and probes (the m/r/s/t/b lines
  and c1–c8), the ~900 untracked scratch probes of the campaign, the
  era-1/era-2 record (`attic/OLD_LESSONS_LEARNED.md`), the retired
  frontier tool (`pareto.py`), the library's former recovery experiments
  (`libsrc_recovery/` — the published parser performs no recovery), and
  the old `test/recovery` tests that targeted them. `attic/c8.dart`
  stays importable as the paired-timing and dump baseline.

The measurement harness — battery, gates, runner, line counter — lives in
`../../test/recovery/`.
