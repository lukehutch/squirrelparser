<!-- Part of LESSONS_LEARNED.md, section: 7. Where things live -->
[Back to the index](../LESSONS_LEARNED.md)

## 7. Where things live

- Full c-series comparison (2026-09-06): the durable tables and caveats are
  in §2. Scratch `dart/experiments/recovery/_C_SERIES_COMPARISON.md` adds the
  per-engine gate matrix and detailed methodology; `_compare_c_results.json`
  preserves raw timing samples and source hashes. `_compare_c.dart` runs
  one engine; `_compare_c_all.dart` runs fresh workers serially with explicit
  wall limits; `_compare_c2_pred.dart` isolates the normalization/audit trap.

- c18/c19 investigation: `dart/experiments/recovery/_C18_FINDINGS.md` and
  `_C19_FINDINGS.md`; selected experiments `_c18.dart`, `_envelope18.dart`,
  `_c19.dart`. `_c18.dart` is the rebuilt file (lesson 55) and Codex's
  original is `_c18codex.dart`; in `dart/test/recovery/`,
  `_treecmp18.dart <a> <b> [raw]` compares two engines' trees and costs
  over the battery, `_show18.dart` prints both trees for raw indices,
  `_score18`/`_rung18`/`_accept18`/`_freespan18`/`_recommit18`/`_conf118`
  are the c18 drivers, and `_plainrss.dart` is the plain-parser RSS
  control. `_research18.dart` runs shared gates, score, paired latency and
  generated scaling rungs; `_properties18.dart` runs the extra grammar/input
  properties. `_memo19.dart` tests attaching to an existing Parser;
  `_audit19.dart` runs charge/committed; `_native_latency19.dart` isolates clean
  attachment cost. The underscore engines and controls are experiments, not
  replacements for the standing engine or imports for tracked production code.

- The c15 frontier engine (scratch, untracked): `dart/experiments/recovery/_c15.dart`;
  drivers in `dart/test/recovery/`: `_score15.dart` (battery, `c15 dump`,
  `-DW=<beam>` and `-DK=<context>`), `_rung15.dart` (json `makeDoc`
  rungs `members/errors`, prints entries/offers/deliveries/evictions/
  maxDepth/backward), `_one15.dart` (one input, trace on),
  `_one1415.dart` (c14 vs c15 cost + skeleton on one input),
  `_accept15`/`_freespan15`/`_recommit15`/`_conf115.dart` (the gates
  with c15 added; pass `-DW=8` for the beam build, default is exact).

- The c17 windowed engine (scratch, untracked): `dart/experiments/recovery/_c17.dart`
  (`-DW=<beam>`, default 8); drivers in `dart/test/recovery/`:
  `_score17.dart` (battery, `c17 dump`), `_rung17.dart` (json `makeDoc`
  rungs `members/errors[/seed]`, prints the windows opened),
  `_edits1417.dart` (`c14|c16|c17 members/errors[/seed]`, then positions
  for the ancestor chain of a node and `a-b` for a slice of the
  document; prints every edit with context), `_errpos16.dart` (error
  positions of a `makeDoc` instance; the first position is in the
  generator's coordinates and can be a benign deletion), `_one1417.dart`
  (c14 vs c17 on one input), `_accept17`/`_freespan17`/`_recommit17`/
  `_conf117.dart` (the gates). With the root filesystem full, run Dart as
  `/opt/flutter/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json`
  from `dart/`, and put that SDK `bin` first on `PATH` for `loc.py`.

- The c16 beam-in-cells engine (scratch, untracked): `dart/experiments/recovery/_c16.dart`
  (`-DW=<beam>`, default 8; `-DREFILL=true` for exact refills), and
  `_c16inst.dart`, the same engine with counters (`-DSTATS=true`, 3–4x
  slower); drivers in `dart/test/recovery/`: `_score16.dart` (battery,
  `c16 dump`), `_rung16.dart` (json `makeDoc` rungs `members/errors[/seed]`,
  on the instrumented copy), `_rung14s.dart` (the same rungs on c14),
  `_prof16.dart` (CPU profile through the VM service: `dart
  --enable-vm-service=0 --disable-service-auth-codes --profiler
  --profile-period=200 …`), `_heap16.dart` (live heap by class),
  `_errpos16.dart` (error positions of a `makeDoc` instance),
  `_one1416.dart` (c14 vs c16 on one input), `_accept16`/`_freespan16`/
  `_recommit16`/`_conf116.dart` (the gates with c16 added).

- The engine: `dart/experiments/recovery/c14.dart` — the published
  library untouched (`lib/src` performs no recovery) plus this one
  recovery module, which consumes the library's clause objects
  natively. `c13.dart` is kept as the judgment reference (bit-identical
  trees, unbounded sweep) and `c12.dart` as the pre-exemption reference.
- Kept for comparison: `c9.dart` (fast) and `c10.dart` (small), each
  self-contained with the full parser folded in and each reachable only
  through `_convert.dart`'s adapters; `c11.dart` with its design
  account in `c11_study.md`.
- The harness: `dart/test/recovery/` — battery + scoring
  (`astdiff.dart`), runner (`_score1.dart <engine> [dump]`), the four
  gates (`_accept.dart <engine>`, `_freespan.dart`, `_recommit.dart`,
  `_conf1.dart`), the c9/c10 adapters (`_convert.dart`), size
  (`loc.py`), and the paired-timing instrument (`_race.dart`).
- The paper's frontier statistics are reproduced with a two-step
  recipe rather than a tracked instrumented engine (which would be a
  duplicate of `c14.dart` and would rot). Make the instrumented copy
  (c14's best-per-end list lives behind `_Front`, hence `.list`):

      sed -e 's|^  int _budget = 0;|  int _budget = 0;\n  static int instCells = 0;\n  static int instReadings = 0;\n  static int instMax = 0;|' \
          -e 's|^    cell.atBudget = _budget;|    instCells++;\n    instReadings += cell._best.list.length;\n    if (cell._best.list.length > instMax) instMax = cell._best.list.length;\n    cell.atBudget = _budget;|' \
          c14.dart > _c14inst.dart

  then run `test/recovery/_frontier14.dart`, which sweeps the battery
  through it and prints the score alongside the counts. The score MUST
  come back 0.9899/85.8, which is what makes the counts trustworthy.
  Measured 2026-09-02 for c14: **421,550** repair-cell computations,
  mean **1.68** readings at completion, max **46**, with the score
  reproduced. c13 read 622,025 / 1.71 / 52 on 2026-08-22 (recipe over
  `c13.dart` with `cell._best.length` and no `.list`, runner
  `_frontier13.dart`) and c12 622,697 / 1.71 / 52: the exemption changes
  which readings survive in 14 cases, so the cell count moves slightly
  and the shape statistics do not. The c13→c14 drop of 32% in
  computations is the budget handoff — every cell the over-deep sweep
  used to fill at a rung its reading could not afford is a computation
  the sweep no longer asks for — and the same trees come out.
- The battery's *composition* is likewise reproduced rather than
  tracked: a throwaway that calls `buildBattery()` and `weighted()` and
  tallies both by category prints it. Measured 2026-08-22: generation
  yields **13,241** breaking mutants (deletion 527, truncation 620,
  insertion 5,662, substitution 5,224, misc 1,208; json 5,631, stmt
  5,703, expr 1,907), and `weighted()` samples that down to the scored
  **2,101** (525/525/438/350/263; json 944, stmt 856, expr 301). The
  sampling unit is 175 cases per weight point and is set by the
  SCARCEST supply — deletion, 527/3.0 = 175.7 — not by `misc`. Worth
  knowing because the raw pool is ~10x richer in insertions and
  substitutions than in deletions (9 insert characters per position vs
  1 deletion), so scoring the raw pool would hand the aggregate to the
  two classes that are merely cheapest to generate.
- Archive: `dart/experiments/recovery/attic/` (~320 files: c1–c8, the
  s/r/m/t/b lines, ~900 scratch probes, `pareto.py` — retired when one
  engine remained — `libsrc_recovery/`, and the old lib-recovery tests);
  the era-1/era-2 record and the era-3 archive in
  `attic/OLD_LESSONS_LEARNED.md`. `attic/c8.dart` stays importable
  (`_convert.dart`'s `convertC8`) as the paired-timing and dump
  baseline.
