<!-- Part of LESSONS_LEARNED.md, section: 2. The standing table (era-3 battery, 2026-08-21) and the c-series comparison (2026-09-06) -->
[Back to the index](../LESSONS_LEARNED.md)

### Full c-series comparison (2026-09-06; measured by Codex, audited the same day)

**Confirmed measurements:** c1–c19 and the c18 envelope variant, current
worktree at HEAD `1059d8e`, Dart 3.12.2 stable (linux_x64), AMD Ryzen 9 3950X.
The same current `weighted(buildBattery())` supplies **2,101 damaged cases**
across JSON, statements and left-recursive expressions; scoring uses the
frozen parser and the existing `expectedFor` truncation adjustment. These
measurements do not change the yardstick or promote a replacement engine.
The c18 row was measured on Codex's `_c18.dart`; the rebuilt `_c18.dart`
(lesson 55) returns the same tree and cost on all 13,241 raw cases, and the
audit's own same-day timings for c14, c17 and c18 are in lesson 55.
**c20 is deliberately absent from these tables.** It was measured a day
later with the session's own drivers (`_research18.dart battery ... compare`
and `_time20.dart`), not with this comparison's worker harness, so its
numbers are not comparable row-for-row; they are in lesson 58 and the c20
paragraph that follows it.

#### Timings and memory — measured, not estimates

Timings are separated from accuracy so they remain visible without scrolling
a wide table. Damaged battery time is the **total for 2,101 cases**, median of
three warmed passes with scoring outside the stopwatch. Clean time is **per
document**, derived from the median of three rounds of 4,600 parses (the 23
corpus documents repeated 200 times). There is a full damaged warmup and a
clean warmup. Engines run serially in fresh workers; timed workers are never
concurrent. Grammar/engine construction and VM startup are excluded from
stopwatch timings; construction performed inside `recover()` is included.
Small timing differences are not claims of statistical significance.

The two rightmost columns use a separate, identical workload:
`makeDoc(256, 4, Random(7))`, **5,959 characters with four deletions**.
They measure one recovery in a fresh process, not a warmed median.

| Engine | Damaged battery (ms) | Clean (µs/document) | 5,959-char recovery (ms) | Peak RSS (MiB) |
| --- | ---: | ---: | ---: | ---: |
| c1 | 1765 | 21.46 | timeout | — |
| c2 | 2472 | 45.51 | 7177 | 1058.1 |
| c3 | 1764 | 22.59 | timeout | — |
| c4 | 1724 | 21.97 | timeout | — |
| c5 | 1688 | 22.61 | timeout | — |
| c6 | 1054 | 9.06 | timeout | — |
| c7 | 1016 | 8.18 | timeout | — |
| c8 | 1017 | 9.03 | timeout | — |
| c9 | 582 | 7.82 | timeout | — |
| c10 | 645 | 19.70 | timeout | — |
| c11 | timeout† | 40.50 | timeout | — |
| c12 | 543 | 8.62 | timeout | — |
| c13 | 552 | 8.40 | timeout | — |
| c14 | 370 | 7.57 | 792 | 430.2 |
| c15 | 1744 | 8.34 | 1480 | 741.1 |
| c16 | 642 | 29.11 | 716 | 441.5 |
| c17 | 1011 | 17.13 | 575 | 333.3 |
| c18 | 806 | 14.47 | 430 | 296.5 |
| c19 | 1539 | 21.57 | 2361 | 599.7 |
| c18-envelope | 1383 | 14.02 | 861 | 342.3 |

† c11's scored battery exceeded the **60-second worker wall limit**. Its
historical battery time is approximately **1,926,000 ms (32 minutes)**,
recorded in `dart/experiments/recovery/c11_study.md`; it was **not reproduced**
in this comparison. Its clean timing and all gates were measured afresh.
The standalone clean run uses the same clean warmup/repeats but could not
follow a completed damaged warmup.

Every timeout in the 5,959-character column is a **15-second worker wall
limit**, including startup, not a proof of nontermination or an exact
recovery-only time bound. Every completed large-input run covered the whole
input and reported four edits; its tree was not AST-scored. This single
common rung establishes neither a scaling exponent nor a general bound.

Peak RSS is **whole-process resident memory**, including runtime/harness,
not retained recovery heap or incremental overhead. All workers load the
same imports; before-recovery current RSS for completed probes is roughly
230–237 MiB. Exact before/peak bytes are in the raw results.

#### Accuracy, category means and normalized size

| Engine | LOC | Score | Perfect % | Truncation | Deletion | Insertion | Substitution | Misc |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| c1 | 493 | 0.981778 | 78.63 | 0.9817 | 0.9792 | 0.9938 | 0.9851 | 0.9624 |
| c2 | 454 | 0.981188 | 78.53 | 0.9806 | 0.9786 | 0.9939 | 0.9850 | 0.9614 |
| c3 | 515 | 0.982942 | 81.15 | 0.9846 | 0.9794 | 0.9937 | 0.9867 | 0.9638 |
| c4 | 566 | 0.987815 | 83.86 | 0.9972 | 0.9843 | 0.9935 | 0.9873 | 0.9675 |
| c5 | 535 | 0.987815 | 83.86 | 0.9972 | 0.9843 | 0.9935 | 0.9873 | 0.9675 |
| c6 | 707 | 0.987902 | 84.01 | 0.9972 | 0.9843 | 0.9935 | 0.9877 | 0.9676 |
| c7 | 692 | 0.987902 | 84.01 | 0.9972 | 0.9843 | 0.9935 | 0.9877 | 0.9676 |
| c8 | 738 | 0.987902 | 84.01 | 0.9972 | 0.9843 | 0.9935 | 0.9877 | 0.9676 |
| c9 | 890 | 0.987902 | 84.01 | 0.9972 | 0.9843 | 0.9935 | 0.9877 | 0.9676 |
| c10 | 785 | 0.987902 | 84.01 | 0.9972 | 0.9843 | 0.9935 | 0.9877 | 0.9676 |
| c11 | 815 | 0.9874† | 84.7† | 0.995† | 0.981† | 0.993† | 0.998† | 0.962† |
| c12 | 784 | 0.989627 | 85.77 | 0.9972 | 0.9843 | 0.9934 | 0.9972 | 0.9689 |
| c13 | 786 | 0.989869 | 85.82 | 0.9972 | 0.9853 | 0.9931 | 0.9972 | 0.9691 |
| c14 | 807 | 0.989869 | 85.82 | 0.9972 | 0.9853 | 0.9931 | 0.9972 | 0.9691 |
| c15 | 1021 | 0.989864 | 85.82 | 0.9974 | 0.9854 | 0.9932 | 0.9973 | 0.9683 |
| c16 | 1016 | 0.989869 | 85.82 | 0.9972 | 0.9853 | 0.9931 | 0.9972 | 0.9691 |
| c17 | 1330 | 0.989965 | 86.01 | 0.9972 | 0.9853 | 0.9933 | 0.9972 | 0.9697 |
| c18 | 1194 | 0.989965 | 86.01 | 0.9972 | 0.9853 | 0.9933 | 0.9972 | 0.9697 |
| c19 | 470 | 0.990033 | 86.15 | 0.9974 | 0.9853 | 0.9931 | 0.9978 | 0.9692 |
| c18-envelope | 1219 | 0.990169 | 86.24 | 0.9974 | 0.9853 | 0.9933 | 0.9974 | 0.9707 |

† c11's accuracy/category cells retain their **historical** values and
precision from `c11_study.md`, not results imputed from its unfinished run.
All **19 completed batteries** have **0 crashes, 0 uncovered cases, 0
reported-bill discrepancies and 0 zero-cost damaged cases**. The bill audit
compares the reported piece count with emitted SyntaxError marks/spans; it
does not prove minimum repair cost. Equal scores do not establish equal trees.

LOC is freshly normalized with `dart format --output=show --summary=none
--language-version=3.0`, excluding blank and whole-line `//` comment lines;
no formatting is written to the engines. It counts each engine file, **not
uniformly added LOC over the native parser**: c6–c10 contain their folded-in
parser, while c8–c10 exclude the external `_convert.dart` adapters.

Configurations: c15 is **W=8, K=0**, not its effectively unlimited source
default; c16/c17 use **W=8, REFILL=false**. c17, c18 and c18-envelope retain
**back=2 windows**; c18/envelope have no origin beam. c19 uses neither beam
nor window. Instrumented and ablation-only variants are not additional
entries in this comparison.

#### Ordinary gates and additional counterexamples

**Confirmed:** every engine, including c11, passes `_accept` **3/3**,
`_freespan` **5/5**, `_recommit` **16/16**, and `_conf1` **6/6** (costs
`0 1 1 0 2 3`). The four historical groups do not include every audit:

| Engines | Four ordinary gate groups | Separate committed-prefix check | Extra greedy-predicate probe |
|---|---|---|---|
| c1, c3–c10, c12–c14, c16–c17 | PASS | PASS | FAIL |
| c2 | PASS | FAIL | FAIL |
| c11 | PASS | FAIL | PASS |
| c15, c18, c19, c18-envelope | PASS | PASS | PASS |

The committed-prefix probe is `Top <- Chunk 'z'; Chunk <- 'a'* 'b';` on
`abab`. c2/c11 return errors **[1..2, 4..4]**, deleting within the already
matched Chunk at 0..2. c1/c3–c10 return **[2..2, 2..4]**; c12–c19 and
c18-envelope return **[2..3, 3..4]**, without that overlap.

The extra predicate probe is `S <- &('a'* 'a') 'b';` on `a`: greedy PEG
makes the assertion fail. Each FAIL engine returns **one false assertion**.
c2 rewrites its predicate to reference synthetic rule `#0`; auditing that
rewritten clause against the original rules throws a rule-lookup error.
That is **not an engine crash**. Auditing the original assertion at the
returned position demonstrates the actual bug: `_compare_c2_pred.dart`
prints `returned positive assertion at 0 len=0` and
`original assertion mismatch=true`. The common audit checks the original
assertion's meaning for every engine.

The comparison's library run prints **+284: All tests passed!**, not the
historical +308. Underscore-prefixed recovery probes are not discovered by
that suite. The three comparison Dart drivers analyze with **No issues
found!** These are finite checks, not universal conformance proofs.

#### Conclusions and reproduction

**Confirmed in this comparison:** c19 is **470 versus c18's 1,194 lines**
(724 fewer), with **1,810 versus 1,807 perfect cases** out of 2,101. It loses
on insertion/misc category means while gaining on substitution/truncation.
c19/c18 is **1.91×** on the warmed battery, **5.49×** on the 5,959-character
recovery and **2.02×** on that probe's peak RSS. It is the smallest entry
passing the four ordinary groups and both extra audits, but remains above
400 lines and is **not an all-criteria winner**. c14 has the lowest measured
battery time but fails the extra predicate probe; c18-envelope has the
highest measured score, not the smallest implementation.

Do not combine these serial fresh-worker medians with older interleaved
paired samples as if they were one experiment. The larger c19 timeout and
deep-LR measurements remain in lessons 50/52; this common rung does not
supersede them.

Reproduce from the repository root (the parent enforces the limits above):

```sh
pushd dart
recovery_dart=/opt/flutter/bin/cache/dart-sdk/bin/dart
$recovery_dart --packages=.dart_tool/package_config.json experiments/recovery/_compare_c_all.dart battery
$recovery_dart --packages=.dart_tool/package_config.json experiments/recovery/_compare_c_all.dart clean c11
$recovery_dart --packages=.dart_tool/package_config.json experiments/recovery/_compare_c_all.dart gates
$recovery_dart --packages=.dart_tool/package_config.json experiments/recovery/_compare_c_all.dart scale
$recovery_dart --packages=.dart_tool/package_config.json experiments/recovery/_compare_c2_pred.dart
$recovery_dart test --reporter expanded
popd
```

The full report is `dart/experiments/recovery/_C_SERIES_COMPARISON.md`;
`_compare_c_results.json` holds all timing samples, full-precision scores,
exact RSS, gates, source paths and SHA-256s. These underscore files are
untracked scratch artifacts; the tables and findings above are recorded
here so the durable record does not depend solely on their survival.
