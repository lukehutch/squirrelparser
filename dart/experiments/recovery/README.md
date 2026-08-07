# The recovery engine

**Not part of the published library.** This directory holds the standing
error-recovery engine and the attic of every superseded attempt.

- **`c7.dart` — the engine.** Self-contained: the full squirrel parser is
  folded in, and the published library contributes only the interchange
  types (the grammar AST in, `MatchResult` trees out). Score 0.9879,
  84.0% perfect, ~1.1 s battery, all gates. See `LESSONS_LEARNED.md` at
  the repository root for the yardstick, the critical lessons, and the
  refutation ledger.
- **`attic/`** — ~320 superseded engines and probes (the m/r/s/t/b lines
  and c1–c6), the ~900 untracked scratch probes of the campaign, the
  era-1/era-2 record (`attic/OLD_LESSONS_LEARNED.md`), the retired
  frontier tool (`pareto.py`), the library's former recovery experiments
  (`libsrc_recovery/` — the published parser performs no recovery), and
  the old `test/recovery` tests that targeted them.

The measurement harness — battery, gates, runner, line counter — lives in
`../../test/recovery/`.
