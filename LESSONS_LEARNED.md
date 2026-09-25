# PEG Error Recovery — the living record

> **Where the working record of the c14–c17 sessions lives (for other agents).**
> Chat history of the session that built c15, c16 and c17 (Claude Code, 2026-09-02
> to 2026-09-04):
> `~/.claude/projects/-home-luke-Work-squirrelparser/1a737cdf-c369-45bf-956c-1b5bf00d5723.jsonl`
> (one JSON object per line; earlier sessions are the sibling `*.jsonl` files
> in the same directory). Memory files (one fact per file, index in
> `MEMORY.md`, engine notes named `squirrel-*.md`):
> `~/.claude/projects/-home-luke-Work-squirrelparser/memory/`.
> Untracked scratch engines and drivers are `dart/experiments/recovery/_c*.dart`
> and `dart/test/recovery/_*.dart`; battery dumps and comparison scripts of a
> session are in that session's scratchpad under
> `/tmp/claude-1001/-home-luke-Work-squirrelparser/<session-id>/scratchpad/`
> (not persistent across reboots).

Seventy-odd engines across six architectural lines were built, measured, and
archived to reach the c-series: one algebra refined engine by engine, ending
at c14 — c13's judgment (c12's substitution breakthrough, the first to beat
the long c6–c10 judgment plateau, plus c13's one rule) on a machine whose
recursion depth and per-end scans are bounded by the grammar rather than by
the document, so a 100,000-character input is read in about two seconds
where c13 overflowed the stack. This file
records the yardstick, the standing results, the critical
lessons, and the refutations that must not be retried. (A refutation is a
measurement under a stated protocol, and one of them was itself wrong:
lesson 46 refutes the retained-width bound of lesson 33. A retry under a
different premise or protocol is a new experiment, not a repeat.) The
c1–c19 comparison of 2026-09-06 is in §2 beside the standing table; the
c18/c19 round and its audit are lessons 44–55. Everything else — the
era-1/era-2 history (insights I1–I107 in long form), the last full
twelve-engine table, and the archived lines' detailed accounts — is preserved
in `dart/experiments/recovery/attic/OLD_LESSONS_LEARNED.md`.

## 1. The problem and the yardstick

An engine receives a grammar and a damaged document and must return the best
complete reading: a tree over the real input, with `SyntaxError` nodes
marking exactly what was denied (real text judged noise) or owed (text
judged missing). Directives: no second parse over a repaired string (D1); no
arbitrary constants (D2); never invent characters of an open class,
structural completion is fine (D7); the two acceptance readings of D8
(`,3true` → `,3,true`; `[,2,` → `[2,`).

**The battery** (`astdiff.dart`): every single-character mutation of every
corpus document that breaks the parse, plus truncations and two-site damage,
across three grammars — json, a statement language (blocks/if/assign), and
left-recursive arithmetic. Expectations come from the frozen parser reading
the undamaged original, so no engine can be tuned toward them. Scoring is
Levenshtein distance over named-node skeletons. Five categories, named by
the operation a person performed: truncation, deletion, insertion,
substitution, misc. Curation (I107): operator coin-flips and 1–2-character
truncation stubs are not generated, and truncation expectations drop
left-recursion wrappers whose evidence lies beyond the cut — the battery
asks only questions a human could answer.

**The gates** (all must pass; the battery cannot see them by construction):

- `_accept` — D8's readings: cx2, b1, b2.
- `_freespan` — may a repair delete real input that already matched?
- `_recommit` — does the engine keep a committed construct rather than
  re-reading the healthy prefix as something else?
- `_conf1` — exact repair-cost conformance, no free passes for predicates.

## 2. The standing table (era-3 battery, 2026-08-21) and the c-series comparison (2026-09-06)

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

### The standing table (era-3 battery, 2026-08-21)

This is the standing table: the scored engines under the protocol of §1,
and c14 remains the standing engine. “All gates” below means the four gate
groups of §1, not the extra checks above; its timings are from the sessions
named in the notes that follow it.

| Engine | Score | Perfect% | ms | LOC | Gates | truncation | deletion | insertion | substitution | misc |
|---|---|---|---|---|---|---|---|---|---|---|
| **c14** | **0.9899** | **85.8** | 572 | 807 | all | 0.997 | 0.985 | 0.993 | 0.997 | 0.969 |
| c13 | 0.9899 | 85.8 | 637 | **786** | all | 0.997 | 0.985 | 0.993 | 0.997 | 0.969 |
| c12 | 0.9896 | 85.8 | 624 | 784 | all | 0.997 | 0.984 | 0.993 | **0.997** | **0.969** |
| c9 | 0.9879 | 84.0 | 633 | 890 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c10 | 0.9879 | 84.0 | 737 | 785 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c11 | 0.9874 | 84.7 | ~1,926,000 | 815 | all | — | — | — | — | — |
| c8 | 0.9879 | 84.0 | 955 | 738 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c7 | 0.9879 | 84.0 | 1181 | 692 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c6 | 0.9879 | 84.0 | 1180 | 707 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |

**c14 is the standing engine** (2026-09-02): c13's judgment, bit-identical
(the per-case dump diff against c13 is empty; every gate result below is
reproduced exactly), on a machine with two changes — the repetition sweep
hands each step only the budget its prefix has not yet spent, and the
best-per-end list is indexed once it grows past a scan's worth (§3,
lessons 24–27; §4). The c14/c13 ms above are a same-session pair
(2026-09-02, single battery runs each; c13's earlier 626 was 2026-08-22);
the durable figures are the paired ones below and the scaling table in
§4. c14 is 21 lines larger than c13 (786 → 807, +2.7%): +28 for the
`_Front` container with its comment, −10 for the `_indexOfEnd` helper it
replaces, +7 for the budget handoff and its comment.

**c13 was the standing engine from 2026-08-22 to 2026-09-02** and remains
the judgment reference: c12's substitution breakthrough plus one
rule of its own (the last-slot jurisdiction exemption, §4). It beats the
long c6–c10 plateau on judgment (+0.0020 score, +1.8 perfect) while being
the smallest and, on the paired clock, at-or-below c9 on both input kinds.
Its four gate results are exact: `_accept` ok cx2=1 b1=1 b2=1, `_freespan`
PASS (probe costs identical to c12), `_conf1` costs `0 1 1 0 2 3`,
`_recommit` 16/16 — re-run for c13 on 2026-08-22, with c9/c10/c11/c12
all green from 2026-08-21.

The c9/c10/c12 ms in the table are same-session single battery runs
(2026-08-21); the durable numbers are the paired ones below. Every score
and category mean above (bar c11's) was re-run from scratch on
2026-08-22 and reproduced to four decimals, as did both re-runnable
gates — `_freespan` PASS for all five, `_conf1` `0 1 1 0 2 3` for all
five; the c12→c13 per-case dump diff gives exactly the recorded 14 cases
changed, 10 improved, 4 worsened, net +0.511. c11's
figure is not a typo and was not re-measured here: its battery takes
about 1,926 SECONDS, three orders of magnitude off the others, so the
run was cut short deliberately (see the c11 entry in §4 — the cost is
a ~30-case cap-out tail, and it is why c11 is a study, not a candidate).
c11's category columns are left blank for the same reason; its recorded
score and coverage come from its own session.

**Paired latency, split by input kind** (`_c12lat.dart 21`, all three
engines interleaved on one warmed VM, two consecutive samples, medians;
clean = every corpus document parsed 20x, damaged = one pass over the
battery):

| Engine | clean vs c9 | damaged vs c9 |
|---|---|---|
| c9 | 1.000 | 1.000 |
| c10 | 2.43x, 2.55x | 1.130x, 1.129x |
| **c12** | **0.949x, 0.982x** | **0.977x, 0.978x** |
| **c13** | bit-identical to c12 (0.993 head-to-head) | 1.010 vs c12 ≈ **0.98x c9** |
| **c14** | **0.880x, 0.822x vs c13** | **0.725x, 0.728x vs c13** ≈ **0.71x c9** |

c14's row is a two-arm pairing against c13 (`_latsplit14.dart 21`, two
consecutive runs of 21 interleaved reps on one warmed VM, medians). The
damaged figure is the budget handoff: the battery's worst cases are the
ones whose repetition steps were being explored a rung deeper than any
reading through them could afford. The clean figure sits inside this
machine's noise band (0.82–0.88 across the two runs); the clean path never
proposes a costed reading, so the honest claim is "at or below c13".

c13's row is measured differently on purpose: a four-engine interleaved
rotation gave unstable per-engine ratios (JIT/code-cache interference,
lesson 21 again), so c13 was paired two-arm against c12 alone — the code
is identical on clean input except for one boolean in a penalty rule, and
the head-to-head confirmed it (clean c13/c12 = 0.993). The damaged
head-to-head read 1.010; combined with c12's 0.977–0.978 that puts c13 at
roughly 0.98x c9 on damaged input — still under on both paths, which is
the bar.

This split corrects a figure this file carried since 2026-08-19. c10's
cost against c9 was recorded as a single blended 1.073 from full-battery
reps; measured by input kind it is not one tax but two very different
ones — 1.13x on damaged input, but **2.4–2.6x on clean input**, where
c10's one-machine design pays dispatch on every consult that c9's
dedicated plain parser answered directly. The blended median hid it
because the damaged battery dominates the wall clock. c12 is at or
below c9 on both kinds, which is the first time any engine in the
series has been smaller AND faster than c9 rather than trading one for
the other. (Measured two-arm, without c10 interleaved, c12's clean
ratio reads lower still — 0.81–0.93x across samples; this machine's
noise band is wide, so the safe claim is "at or below c9 on both", not
a precise speedup.)

The c9/c8 ms are the SAME-SESSION paired medians (12 interleaved
full-battery reps on one warmed VM, 2026-08-19): ratio 0.587, so c9 is
1.7x faster on bit-identical judgment — every battery tree equal,
verified by a zero-diff dump, and every gate exact. c8 therefore joins
the attic. (c8's former table figure of 1,126 ms was the 2026-08-06
quiet-machine run; the c7/c6 rows keep their own last measurements, so
ms is only comparable WITHIN a measuring session — the c9:c8 ratio is
the durable number.) c9's higher line count is the price of its caches;
c8's LOC is restated at today's normalized count (738; the 759 recorded
earlier predates the strict-zero-fiber trim). c10 was paired against
c9 in its own session (10 interleaved full-battery reps, 2026-08-19):
medians 574/616, ratio 1.073 — its judgment is bit-identical to c9's,
so its row differs only in ms and LOC. (Its first cut measured 1.30x
at 714 lines; the fiber split described under I119 bought the ratio
down to ~1.07-1.09 — the band this machine's noise spans — for 76
lines, and the state-space pass under I120 gave back 5 of them.) The
c9/c10 pair was for two days a deliberate frontier — c9 the fast point,
c10 the small point — and c12 has since collapsed it: it is left of
both on every axis, so the frontier is one engine again.

The c6–c10 rows are the FUSED engine — the full squirrel parser folded
in, so each is self-contained and its LOC includes the whole parser
(~246 lines); the pre-fold, library-dependent c6 measured 461 lines and
~1,500 ms. c11 and c12 return to the published library untouched plus a
separate recovery module, so their LOC is NOT the same quantity as
c6–c10's. Two corrections in opposite directions, both worth knowing
before the LOC column is read as a ranking:

- c11/c12 do not carry the ~246 folded-in parser lines, which flatters
  them against c6–c10;
- c9 and c10 cannot be run at all without `_convert.dart`, a 120-line
  adapter that translates library clauses into each engine's own node
  classes and lives in the harness rather than the engine. c11 and c12
  consume the library's clause objects natively and need no adapter, so
  the honest totals are c9 ≈ 890+, c10 ≈ 785+, against c12's 784 flat.

The two effects do not cancel exactly and no attempt is made here to
net them; the durable claim is the narrower one, that **c12 is smaller
than c11 (815) and than c10 (785) counted the same way, by the same
script, in the same session**, which is the comparison the c12 brief
asked for. The c1–c8 ancestors and every other line are archived with
their last numbers in the attic (`attic/OLD_LESSONS_LEARNED.md`).

## 3. The critical lessons

### The architecture — three discoveries that define the design

1. **The LR grow-loop IS the recovery loop** (I100, the pivotal insight).
   A mismatch and a left-recursion seed are the same object: a suspended
   reading addressed by (clause, position). The memo entry's grow-loop
   serves left recursion and repair with no second mechanism — left
   recursion is recovery at cost zero. Everything else in the design is
   this loop plus a way to price what it grows.

2. **Parsing mode IS budget zero** (I101), **and the budget is the
   horizon** (A3). With no edits left, the costed descent is
   definitionally the pure parser, so the frozen memo answers
   unconditionally — every spent-out continuation is O(1) to the end of
   the input. The budget ladder is not an optimization: deleting it was
   ~100x latency, twice. The budget marks where repair can no longer
   reach, and the mode split disappears into it.

3. **Judgment must be whole-document and simultaneous.** The b-line's
   greedy commit-then-resume architecture has a proven ceiling (0.88):
   the correct choice between a cheap fill and a dear denial depends on
   repairs not yet made. Every reading must be priced against every
   rival over the whole document before anything commits. (The archived
   chart line achieved simultaneity by re-deriving what the parse knew;
   the c-line achieves it inside the one descent.)

### The judgment — what a reading is worth

4. **The rank is one quantity at two resolutions, split at the boundary**
   (I105 + I111). Five keys, each placed by a named failing case: fewest
   claims (edits + fees + the derived swallow) → PEG's own reading →
   most explained (net) → latest doubt → fewest obligations stranded at
   the cut. Tier 1 prices all wrongness with the boundary claim
   collapsed to one (I94); the last tier restores exactly the
   cardinality tier 1 forgot and nothing else — mid-document owes are
   fully priced up front, and recounting them below was
   double-representation (measured inert; removed). Ablations: drop
   latest-doubt −3.4 perfect, drop the stranded count −2.6, collapse the
   stranded count to a bit −2.6 (identical to dropping the tier: the
   count IS the tier). The root's admission is the rank's own price.

5. **The swallow is derived, never stored** (I108). A reading that
   absorbed more of its span than it pinned pays one — computed at every
   comparison from scalars the way carries (`absorbed > net`, relative
   to the comparing front's position), accumulated never. Idempotent, so
   double-charging is unrepresentable; the stored-toll design needed
   three fields, a judge, symmetry rules, and a root exception, and cost
   a two-session bug class. The span conservation law underneath:
   `span = net + absorbed + del`.

6. **The boundary claim is one, and it is idempotent** (I94 + I110).
   "The document stopped" charges once however many slots it strands.
   Structurally: the budget is an ADDITIVE ledger — the fold splits it
   by `full − spend`, so only quantities that add along `then` may enter
   spend. Pricing the eof bit into spend re-charges it at every nesting
   level that touches EOI, and deep truncation spines die at nesting
   boundaries (−0.0019, truncation 0.997→0.990). Additive: del, gap,
   net, fees, oweN. Idempotent, derived at use: the eof bit (a theorem:
   `oweN > 0 ⟺ owing ∧ end == n`), the swallow.

7. **The five counters are the floor** (I111). del and gap are split by
   the witness antisymmetry — a denial is witnessed by the input, an
   obligation only by the grammar; they trade 1:1 in the price, but
   `absorbed` needs denied-chars alone and the fee condition needs the
   owe count alone. oweN is the boundary cardinality (measured, −2.6 to
   collapse). net is evidence, orthogonal by the span law. fees is the
   exchange-rate correction where the two witness-kinds meet at par — an
   unspellable fill loses to an available denial at equal price
   (I72∩I36), it must outrank net (gate-pinned), a slot that is a
   back-edge into a growing cell is an LR seed and exempt (I106), and it
   can never be an owe: folding it into gap was battery-identical with
   every gate green and is rejected anyway, because a fee'd way that
   legitimately wins would report an edit the tree cannot show. A
   judgment charge must not forge an evidence mark.

8. **The tie law**: the latest same-price rival holds the bucket —
   deterministic, because expansion order is; measured four ways
   (first-keeps −2.6 to −3.1 perfect). A tie never signals improvement,
   or rank-equal rivals spin forever.

9. **Names are evidence** (I81/I96). A zero-width completion at the end
   of the input loses its name — the construct was never reached;
   mid-document it keeps it. The audit identity follows: the winner's
   reported cost equals the errors its tree actually shows.

### The representation — how the search stays cheap and honest

10. **The way is a cons cell that knows its sums** (I109). One payload (a
    denied/owed mark, a finished subtree, or a name over an inner chain),
    one tail; every scalar is either an additive cache of that list
    (del, gap, net, fees, oweN) or derived at the point of use (edits,
    marks, the eof bit, the swallow). The tree is a fold over the chain;
    the tree's cost is the way's own sums by construction; a frozen read
    is one constructor; the unread tail at the root is one more skip,
    not a protocol. c5's fifteen fields were one reading described three
    times — the giveaway was the root walking the finished tree to
    recompute a number the way already carried. Corollary, the method
    that found it: **derive, don't account** — when a stored quantity
    needs machinery to prevent double-counting, derive it at use.

11. **The way-front is the memo cell** (I103). One champion per ending,
    decided at insertion — insertion IS the improvement test, so the
    grow-loop stops when no add improves; no sort, no unstable-tie
    livelock. Warth's involved-set is the staleness rule: only rules
    that read a growing seed, at that position, during that growth, are
    ever recomputed. The seed is read RAW (a budget filter there hides
    the repair-carrying ways growth must build on), and any in-path hit
    is left recursion.

12. **Laziness is load-bearing** (I88, confirmed three times): building
    trees eagerly costs 20–31% at the tie-refresh volume the tie law
    requires; only winners are materialized. Same family: cache on
    stable identities (caching net on a freshly allocated wrapper never
    hits and cost 12%), and a literal is a char-sequence run through the
    ordinary fold (I95) — its replace edit stays literal-scoped, and
    routing literals through the memo cell was judgment-identical but
    +25% latency.

13. **Fold the parser in; put behavior on the nodes and state on the
    behavior** (the c6 fusion). The engine converts the grammar once into
    its own node hierarchy — each clause kind carries match (pure), go
    (priced), freeze, det, fill and pin as methods, and its own memo rows
    as generation-stamped arrays, so no type dispatch and no hash map sit
    on the hot path and a new input resets everything by bumping one
    counter. Judgment-identical, −20% latency; the one remaining type
    inspection is the conversion adapter, and the one tree walk
    (`_netOf`) sits at the package-tree boundary. The pure fiber's seven
    small match methods are the price of budget-zero answers being O(1) —
    routing budget-zero through the way machinery is the measured-slower
    direction.

14. **One left-recursion law for both fibers** (I112, the c7 collapse).
    Squirrel's rule — re-entry seeds the cell, growth bumps the
    position's version, a cell is valid only at its stamped version — now
    governs the priced fiber too. The refinement that made it affordable:
    a cell whose compute never read a growing seed cannot go stale, and
    THE INVOLVED SET IS ONE BOOLEAN recorded by the unwind (every
    enclosing grow when a seed is read is by definition an ancestor on
    the path), so Warth's recursion stack, heads map, tick counter and
    per-cell sets delete. Validity: `at ≥ budget && (!dep || ver ==
    rver[pos])`. Judgment-identical and faster than the machinery it
    replaced; the version rule WITHOUT the dep bit is sound but −13%
    (it cold-starts every same-position cell per growth step). The
    version-bump-refuted-for-recovery result was an artifact of c2's
    normalize-everything architecture, where every position grew;
    with repetitions as closures, growth is sparse again.

### The method — how the lessons were won

15. **The yardstick is a design object** (I107). A battery that scores
    coin flips or post-cut structure measures tie-luck. Curate mutations
    to what a human could arguably answer, and make every
    expectation-change in the open.

16. **Keep gates the metric cannot see.** The battery is blind by
    construction to free-span deletion and prefix re-reading — it once
    rewarded +0.0020 for exactly the behavior `_freespan` exists to
    forbid. And a gate must be checked to be checking: the era-3
    curation accidentally emptied freespan's probe list, and every
    "pass" until the restoration was vacuous. Verify the gate fails for
    a known-bad engine.

17. **Domination is arithmetic; ablation is measurement.** Compute the
    frontier (`pareto.py`), never eyeball it — the hand-kept list was
    wrong twice the same way. Every kept mechanism carries the number
    that keeps it (the size floor is a measurement, I104); every removed
    one carries the number that killed it (the ledger below).

### The machine — what the c9 round measured

18. **Measure the shape before choosing the container** (I115). The
    histograms came first, the design second: 71% of cell consults see
    at most one reading (90% at most three), 80% of fold steps hold one
    partial, and the champion map's key always equaled the stored
    reading's own `end`. Those three numbers make the map a list, the
    hash a linear scan, and the rebuilt-per-consult view a cached one —
    together 1.7x — while every change made WITHOUT a shape measurement
    behind it (the per-op campaign) was ±5% noise.

19. **The GC owns the allocation ledger** (I116). Under Dart's
    generational collector, a young object that dies young is nearly
    free, and a store into an old-space object pays a write barrier the
    fresh array never does. Both directions were measured: judging a
    candidate from its component sums BEFORE allocating it lost
    1.02–1.04x (the guard duplicates the arithmetic on every keep, the
    allocation it avoids was free), and reusing cell arrays ACROSS runs
    with epoch stamps and in-place resets lost 1.10x (every store aged).
    "Avoid allocation" is not an optimization goal; it is a hypothesis
    the collector usually falsifies.

20. **A ratio is only comparable within its session.** Even the paired
    in-process interleaved instrument drifts with machine load: a
    candidate measured 0.938 re-measured 1.033 when the machine
    lightened (the baseline sped up more than the candidate). Draw
    conclusions only from same-session pairs, and re-confirm any
    surprising ratio before acting on it — the c9 round's one false
    lead was a load artifact, not an engine effect.

21. **A blended ratio can hide two opposite taxes** (the c10 correction,
    2026-08-21). c10's cost against c9 was carried for two days as a
    single 1.073 from full-battery reps. Split by input kind it is 1.13x
    on damaged input and 2.4–2.6x on CLEAN input: the damaged battery
    dominates the wall clock, so the blended median all but erased a
    2.5x regression on the path most real documents take. Whenever an
    engine has two paths with different volumes, time them separately
    or the cheap-but-frequent one goes unmeasured.

### The repair — what a substitution must prove (the c12 round)

22. **A swap the rest of the sequence cannot read from is a guess, not a
    substitution** (I121). The replace repair consumes one wrong
    character in place of an exact-text slot. Offered unconditionally it
    is also the entire damaged-latency cost of the c12 design: compiled
    out, c12 was already cheaper than c9 on every hot damaged case. It
    is expensive for a structural reason, not a constant-factor one —
    each swap resumes at `end + 1`, a position the search would
    otherwise never visit, so the memo misses cascade downstream (2.8x
    the propose calls on the worst case), and because per-end pruning
    picks its survivor with a LOCAL comparator, a swap-derived reading
    can evict the chain that would have finished more cheaply and buy a
    whole extra budget round. The gate is the price of belief:
    `_resumes` requires the remaining slots to read cleanly from just
    after the swap and prove something, or the sequence to end there.
    −27% `then` calls, battery bit-identical, damaged 1.06x → 0.98x.
    The general form: a repair that opens a position no clean reading
    reaches must justify that position, or it pays for the whole
    subtree the search then has to explore.

23. **Where a repair is OFFERED is a design axis, not a detail.** The
    same substitution rule, unchanged in what it costs or what it
    accepts, measured 1.198x, 1.110x, 1.06x and 0.98x purely by moving
    and gating its offer site: from `Terminal.findReadings` (fired at
    every failing picky terminal) into `_readSlots`; then restricted to
    a clean prefix; then to a PREFERRED prefix with budget room; then
    to slots the sequence can resume past. Every one of those four
    tightenings held the battery bit-identical. A repair's expense lives
    in how often it is proposed, not in what it does when it wins.

### The machine, second look — what the c14 round measured

24. **Every fold hands its children the budget its prefix has not
    spent, and a fold that forgets is a bug the battery cannot see.**
    `_readSlots` has always handed each slot `whole − r.spent`. The
    repetition sweep did not: it asked every step at the round's whole
    budget, so a step whose prefix had already spent an edit was
    explored one rung deeper than any reading through it could afford.
    The battery was bit-identical either way — the extra readings are
    all pruned at the parent — so nothing in the judgment measured it.
    What measured it was recursion depth: `_grow` nested 107, 464 and
    1,159 frames deep on json documents of 1.4k, 6k and 24k characters
    with one error (1,568 at 6k/4), because each over-deep step
    re-entered the sweep at the next member. With the four-line
    handoff (save the budget, hand `whole − r.spent`, restore) depth is
    27–47 frames at every length: the nesting of the grammar, not of
    the document. Work at 24k/1 fell from about 990 ms to 420 ms; at
    6k/4 from 18.6 s to 0.7 s; at 24k/4 c13 could not be timed at all
    (a cold, unoptimized first call overflowed the Dart stack at
    6k chars / 2 errors). The rule: wherever a reading continues
    through a child, the child is asked at the reading's remaining
    budget, never the round's.

25. **Recursion depth is a measurement, not an implementation
    detail.** A depth that grows with the input says a bound is
    missing — the grammar's nesting is the only legitimate source of
    depth in a memoized engine, and it is constant per grammar. The
    instrument is a wrapper around `_grow` that records the deepest
    chain (`_depth.dart` over an instrumented copy). Two consequences
    for the harness: any timing run that includes a pre-c14 engine must
    warm on a small document first (the JIT-compiled frames are smaller
    than the interpreter's, so the same call overflows cold and
    succeeds warm — an "intermittent" crash that is not intermittent),
    and a scaling table must be read alongside the depth, since a
    superlinear time curve and a linear depth curve have the same cause.

26. **Whether a best-per-end list should be scanned or indexed depends
    on the construct's width, so the container decides at runtime.**
    A repair cell keeps one best reading per end position. Under the
    battery (documents of tens of characters) a construct holds a
    handful of ends and a linear scan is the cheapest thing there is —
    the c9 round's lesson stands. But a repetition over a
    3,000-member json object holds a reading per member boundary, and
    the scan is then quadratic in the document. `_Front` scans while it
    holds at most 32 entries and builds an end→slot map the moment it
    grows past that; it is the only `Map` in the engine (every slot
    structure is a `List`). On top of the budget handoff, indexing
    alone is worth 2.2x at 100k/1 (5.03 → 2.27 s), 1.8x at 24k/2 and
    3.7x at 24k/4 (92.7 → 25.1 s); on the battery it is neither
    measurable nor charged (the threshold is never crossed). A scan
    limit of 8 lost to 32 at 6k chars, where the map's construction
    cost is paid for constructs that would have finished scanning; both
    read the same at 24k.

27. **The cost of a recovery scales with the position of the error,
    not the length of the document.** Instrumented fills on json with
    one error: 304 fills for an error at character 79, 59,000 for an
    error at 15,317, about 3.9 fills per character BEFORE the failure
    point and none after it. The reason is exactness, not waste: the
    failure point is not the error point (a deleted comma is noticed
    at the next key), so the budget-b pass must explore the b-edit
    variants of every construct before the failure, which is where the
    error might be. After the failure everything is read at budget
    zero, from the plain memo, once. This is the shape of the engine's
    cost and it is the right shape — an engine that explored only near
    the failure would be locality, and locality was refuted a third
    time this round (ledger: per-region rungs score exactly c11's
    number, because the frontier is one number and the lower-rung
    reading that died one character short of a wrong family's reach can
    hold the next rung's winner anywhere).

### The machine, third look — what the c15 round measured (2026-09-03)

The round's question was the user's: a recovery whose cost cannot grow
faster than O(n^3) in the input, ideally the pika-style bound O(|G|·n)
memo entries per budget. c14's cost at four errors grows as about
n^2.6 (26–28 s at 24k characters) because its per-(clause, origin)
cells keep one reading per END: a list walker entered at ~1,900
origins holds thousands of ends each, so the memo is Θ(n²) readings.
c15 (`dart/experiments/recovery/_c15.dart`, scratch, 1,018 lines vs
c14's 807) is the same judgment on a different machine.

28. **The exact optimum under this cost model needs Θ(n²) walker
    summaries; the beam over origins is the approximation, and W=8
    of it loses nothing the battery can see.** c15 runs one level per
    budget (Dijkstra by characters spent), over hypotheses (frame
    shape, start, reading so far, running totals, origin). Frames are
    a graph-structured stack: a push entry per (position, rule or
    sequence shape) holds its parents and its best completed reading
    per end; a new parent is linked and replayed; a completion is
    recorded once and stepped into every parent. A node per (position,
    shape) keeps one entry per ORIGIN (the push entry the frame walks
    for), at most W of them; the worst is evicted only by a strictly
    better newcomer. With W=∞ this is c14's cells in stack form (exact,
    same score, out of memory at 24k/4 like the full-context build).
    Battery, all at 0 diff lines from the previous run:

    | W | battery | imperfect | 24k/4 |
    |---|---|---|---|
    | ∞ (exact) | 0.9899 / 85.8 | 298 | OOM (15 GB at 73 s) |
    | 8 | **0.9899 / 85.8** | 298 | **10.3 s, 3.3 GB** |
    | 4 | 0.9887 / 85.3 | 308 | — |
    | 2 | 0.9788 / 81.3 | 392 | — |
    | 1 | 0.9290 / 67.3 | 688 | — |

    W=8 and W=∞ produce the same imperfect-case dump (diff empty apart
    from the timing line); all four gates pass at W=8 (`_accept` ok
    cx2=1 b1=1 b2=1, `_freespan` PASS, `_recommit` 16/16, `_conf1`
    `0 1 1 0 2 3`). Case-wise against c14: 57 cases lower (weight
    0.966), 51 higher (0.949) — every one checked is an equal-cost tie
    resolved by arrival order (both engines keep the first reading
    among equal keys), e.g. `a+b*2(3+)*4` and `3z3` in a json array.

29. **Keying a frame by its whole stack is exponential in the number
    of open repaired frames; keying it by nothing is unsound; the
    origin is the key that is both.** With K frames of context in the
    key and no origin (measured before the replay fix of lesson 31, so
    all understated): K=0 0.9113, K=1 0.9153, K=2 0.9332, K=3 0.9642,
    K=4 0.9618, full stack (K=40) 0.9842 — but the full stack held
    18,516 distinct shapes at one position of a 1.4k document (2.99M
    entries, 8.4 s, 2.7 GB) and could not finish 24k. Merging frames
    that differ only in what encloses them is wrong because the
    enclosing frames price the continuation differently (a member
    walker inside a swallowed string is not the member walker of the
    honest object). The origin — the push entry the frame walks for —
    is exactly the enclosing context the price depends on, and there
    are at most W of them per (position, shape).

30. **A rule re-entered at the position where it is already open must
    link to the open frame, not push a new one — for left recursion
    AND for the end of input.** Two infinite zero-cost chains stalled
    the first build: `Term` re-entering itself at one position of
    `(a*b+(c*d)-(e+f)` (227 frames deep, level 0), and
    Value→Object→Member→Value→Array→… at the end of `{"t":[1}` (each
    frame costing only missingAtEnd, which `spent` does not count).
    Both are the same fact: an open frame of the same rule at the same
    position already represents every reading the re-entry could
    produce. The re-entry links to it (a cyclic stack) and is exempt
    from the delete-ahead penalty until the seed completes.

31. **In a stack whose entries carry a mutable best hypothesis,
    "already linked" says nothing about what the CURRENT hypothesis
    has seen: replay on every link.** The 0.9834 → 0.9899 gap of the
    first working build was one early return. A frame re-expanded at a
    later level with a better hypothesis re-linked to the push entry it
    had linked at the previous level, found itself already among the
    parents, and skipped the replay of that entry's completed
    readings — so `{"t":[flase]}` (Boolean via one delete + one
    insert, cost 2) completed up to the top Value and never reached
    the root, and the level-3 string swallow won. Replay is idempotent
    through keep-best, so the fix is to replay unconditionally. Found
    by tracing every step and offer that spans the whole document:
    the reading arrived at the seq frame and the WS step after it
    never printed.

32. **At fixed budget c15 is linear in the input and c14 is not; below
    ~10k characters c14 is 1.5–4x faster.** json `makeDoc` documents
    with four errors, one process per rung, same session (c14 via
    `_rung14.dart` over `_c14prof.dart`):

    | chars | c15 W=8 | c14 | c15 peak RSS |
    |---|---|---|---|
    | 1,442 | 0.40–0.48 s | 0.27 s | 344 MB |
    | 5,959 | 1.34 s | 0.78 s | — |
    | 24,190 | 9.9–10.3 s | 26.2 s | 3.3 GB (c14 4.9 GB) |
    | 100,072 | 32.3 s | not run (n^2.6 extrapolates to ~1,100 s) | — |
    | 150,663 | 37–38 s | — | 11.1 GB |
    | ~600k | killed at 35 GB | — | — |

    0.25–0.41 ms and ~74 KB per character at budget 4. Battery
    (short inputs): c15 1.8–1.9 s vs c14 0.49 s. Recursion depth of
    the step cascade is 5 at every rung (`maxDepth`), and no entry is
    ever queued behind the level's position sweep (`backward` = 0 on
    every run; a backward enqueue would be lost silently, because the
    sweep visits each position once per level). Census at 24k/4:
    3.05M entries (126 per character), 8.0M offers, 14.4M readings
    constructed, 1.82M nodes, 5.3M deliveries, 101k evictions. The
    readings are the memory; the next reduction is there (drop the
    `prev` chain from evicted entries, or share totals), not in the
    table. The ~1 KB per live entry and 600k-character ceiling on a
    64 GB machine are the open problem, not the time.

### The machine, fourth look — what the c16 round measured (2026-09-04)

The round's question was the user's: take c14 and stop its worst
cases from degrading past quadratic, given that the pika parser shows
recovery is possible in O(|G|·n). c16
(`dart/experiments/recovery/_c16.dart`, scratch, 1,015 lines vs c14's
807, +208, +25.8%) is c14 with c15's beam moved INTO c14's cells, plus
the plain-match memos c14 never had. Battery bit-identical to c14 at
every step (0.9899 / 85.8, 298 imperfect, 0 diff lines against the
c14 dump), all four gates (`_accept` ok cx2=1 b1=1 b2=1, `_freespan`
PASS, `_recommit` 16/16, `_conf1` `0 1 1 0 2 3`).

33. **The beam belongs in the cells, not in a new machine.** c15 paid
    3.75x on short inputs for a frontier machine whose only new idea
    was the beam of W origins per (position, shape). c16 keeps c14's
    recursive descent, memo cells and sweep, and adds one admission
    test at the two places a reading is offered to a best-per-end
    list: the repetition sweep (state = the repetition, end = the
    reading's end) and the sequence fold (state = the sequence and
    slot, end = the reading's end). A row per (state, end) holds at
    most W=8 origins, judged on the bill of the WHOLE document prefix
    (`ctx.plus(r)`, the context handed down the stack); a newcomer
    replaces the worst only when strictly better, and an origin
    already in the row updates its bill in place. This was claimed to give
    the same bound as c15, O(|G|·W·n) per rung; the c18 audit refutes the
    retained-origin premise (lesson 46). The measured result was 1.38x
    on the battery instead of 3.75x
    (c14 500 ms, c16 683–701 ms, three same-session pairs), and the
    battery is bit-identical at W=8, W=16 and W=∞; W=4 changes it
    (0.9890 / 85.3, 333 diff lines), as in c15.

34. **Both offer sites need the beam; the walker's alone leaves the
    fold as the growth site.** With the beam only on the repetition
    sweep, the 100k rung was still spending its time in `_readSlots`
    (22M fold offers at 100k, seed 2) because a sequence slot re-walks
    every continuation of every reading the fold still holds. The
    fold beam keyed by (sequence, slot, end) with the sequence's own
    position as origin closes it. Admission is judged from seven
    scalars (`_Beam`: charge, first doubt, evidence, last doubt,
    missing at end, deleted, missing) computed from the context and
    the reading; no `_Reading` is allocated per offer, and a row
    caches the index of its worst member until the row changes.

35. **The plain match was the quadratic tail, and it was hiding
    behind the repair.** c14 rebuilds a repetition's plain match from
    every start it is asked at, re-walking the suffix each time, and
    the evidence count walks the whole rebuilt tree: 48M characters of
    evidence walk at 100k/4 before the fix. c16 memoizes the plain
    match per position in the repair cell (stamped with the position's
    parse version, the same staleness rule as `Rule.parseCell`) as a
    suffix-shared chain (`_RepMatch`: head match, next, evidence), so
    the match from position p is the head at p plus the memoized match
    from the next position, O(1) after the first walk, with the
    evidence carried on the chain. Composite plain matches are cached
    the same way (the cell's `plainList`). The evidence walk no longer
    appears in the profile.

36. **The sweep's "changed" list must be a set, and a pass stamp per
    index is the cheap set.** `List.contains` on the changed list was
    12.8% of the 100k seed-2 run; a per-index stamp of the pass that
    last changed it makes the dedup O(1).

37. **Exact refills are correct and not worth it.** c14 serves a cell
    computed under one context to every later asker. Refilling when a
    strictly better prefix asks is exact per context and battery-
    identical, but its sign varies by instance (24k seed 7: 6.8 s with
    refills vs 8.8 s without; 24k seed 1: 13.3 vs 8.0; 100k seed 2:
    106 vs 32 s). Off by default, `-DREFILL=true` restores it.

38. **c16's rungs grow about linearly with n at fixed budget, but the
    bound argued for it is refuted.** The O(|G|·W·n) argument rested on
    at most W retained origins per (state, end); lesson 46 measures 13
    with W=8, so the linear growth in the table is an observation over
    these instances, not a proven bound, and its constant varies strongly
    with the error configuration. json
    `makeDoc` documents, four errors, one process per rung, peak RSS
    from `/usr/bin/time`, same session:

    | chars (seed) | c16 | c16 RSS | c14 | c15 W=8 |
    |---|---|---|---|---|
    | 1,442 (7) | 0.36 s | 276 MB | 0.18–0.27 s | 0.40–0.48 s |
    | 5,959 (7) | 0.75 s | 428 MB | 0.73–0.78 s | 1.34 s |
    | 24,190 (7) | 8.8 s | 1.68 GB | 26.2 s, 4.9 GB | 10.3 s, 3.3 GB |
    | 24,162 (1) | 8.0 s | 1.76 GB | 53.2 s | — |
    | 100,072 (7) | 12.9 s | 3.33 GB | 70.0 s, 13.4 GB | 32.3 s |
    | 100,060 (2) | 32.1 s | 7.45 GB | killed at 550 s, 31.4 GB | — |
    | 150,663 (7) | 15.5 s | 4.21 GB | — | 37–38 s, 11.1 GB |

    Per character 0.13–0.36 ms; the 100k instances of seeds 1/2/3
    take 28 / 32 / 26 s and the 24k instances of seeds 1–5 take
    4.4–13.3 s, so a factor of three between instances of one length
    is normal (clustered errors and unterminated strings cost the
    most). Where the time goes at 100k seed 2 (CPU profile,
    `_prof16.dart`): `_admit` 18%, `_Reading.then` and allocation,
    `_Reading.plus` once per sweep step (9.2M steps), 3.5M cell fills
    (35 per character). Memory is the open problem: at 24k seed 1 the
    live heap is 1.49 GB — 5.8M `_Reading` (555 MB), 3.1M `_Beam`
    (247 MB), lists 350 MB, 544k `_RepairCell` (78 MB) — and 100k seed
    2 needs more than 3 GB live (a 3 GB old-generation cap dies
    silently there). Roughly 30–70 KB per character, against c15's 74
    and c14's 130 at 100k. The readings are still the memory, as in
    c15; the next reduction is sharing or dropping the `_Reading`
    chains of evicted beam members, not the time. Stats mode
    (`-DSTATS=true`, on `_c16inst.dart`) is 3–4x slower and its times
    must never be compared with plain runs; several rungs in one
    process inflate the heap to 7 GB and slow the later rungs, so
    every number above is one process per rung.

### The machine, fifth look — what the c17 round measured (2026-09-04)

The round's question was the user's again: c16's 15.5 s and 4.21 GB
on a 150k input are unacceptable. c17
(`dart/experiments/recovery/_c17.dart`, scratch, 1,330 lines vs c16's
1,016 and c14's 807) is c16 with repairs confined to WINDOWS: spans of
the input around the positions where readings died. Battery 0.9900 /
86.0 against c14's 0.9899 / 85.8, with 11 deviations from the c14
dump, every one an equal-cost tie-break (4 worse: expr 656, 673, 669,
670; 7 better: expr 690, 694, 671, 999, 689 and json 572); all four
gates (`_accept17` ok cx2=1 b1=1 b2=1, `_freespan17` all clear,
`_recommit17` 0 of 1 discard, `_conf117` the six probes right).

39. **Repair only where the parse died, and let the ladder discover
    the deaths one at a time.** A repair action (delete ahead, mark
    missing, substitute) is tried only at an open position. A reading
    with no clean continuation notes a death at its end, a root
    reading that stops short notes one at its end, and the round
    keeps the farthest. When that death lies outside every window the
    ladder opens its windows and re-runs the SAME budget before
    accepting a winner — a winner found so far may only have got past
    that point on the free end-of-input reading. Windows persist
    across budgets, so each distinct death costs one re-run. Outside
    the windows every cell is the plain parse, computed once
    (`atBudget` unlimited), and a cell is refilled only when a window
    opened after its fill meets its span (`_stale`). At fixed budget
    that makes the work proportional to the windows, not the input.

40. **The window is walked per frame, two evidenced units back, and
    the unit that ends at the death is entered fresh.** The left edge
    walks `back` = 2 evidenced units from the death through the frames
    on the stack (a walker's occurrences count one each, a sequence's
    slots are expanded through their pieces). A non-atomic unit that
    ENDS at the death holds the failure's own context, so it is
    entered with a fresh count of two and closed as a span of its own;
    the enclosing frame then counts the units BESIDE it. The first,
    contiguous walk made the window run from the death back to two
    units before an enclosing frame's last unit — when that unit was
    an unclosed object that had swallowed the rest of the document,
    the window was (26775, 150663) at 150k. A frame extends the edge
    to its own origin only if it counted at least one unit: the fold
    of the top rule, whose chain before the slot the death is inside
    is only whitespace, was extending every window to position 0
    ((0, 13979) at 24k, 29 s and 2.08 GB).

41. **A plain parse that fails at budget zero is a death, and only a
    fill can say where.** The budget-zero shortcut served the plain
    parse's readings without noting a death, so the walker's failing
    occurrence attempt (the item fold that consumed `,` and then found
    `k` where a member's `"` had been deleted, position 23937) was
    never a death; the enclosing fold noticed the failure one position
    earlier (23936) and the window stopped there. c17 paid 5 on 24k
    seed 1 where c14 pays 3. A cell whose plain parse has no reading
    is now filled once at budget zero (no repair is possible at zero,
    so the content equals a fill at any budget outside a window) and
    still answers with the plain readings alone.

42. **Windows cost re-runs, and on short inputs the re-runs are the
    latency.** Battery 1.15 s vs c14's 0.50 s (2.3x; c16 1.38x). An
    instrumented run puts 0.20 s in first rounds and 0.91 s in
    re-runs: 6,223 rounds for 2,463 budget rungs over 2,101 cases. A
    typical one-error case runs budget 1 (dies, no window), re-runs
    with the window (wins, and the winner's readings die at the end),
    opens the end-of-input death's window and re-runs once more. That
    last re-run is required: without it 0.9840 / 83.7 (74 cases worse
    — the walk from the end death is what finds the repair inside a
    string that swallowed the rest of the input), and skipping it
    only when the winner has missingAtEnd 0 still moves 157 dump
    lines (0.9897). On long inputs a re-run is cheap (only stale
    cells refill), which is why the same mechanism wins there.
    Clearing the beam rows touched instead of reallocating the beam
    per window saved 50 ms of the battery.

43. **c17 substantially improves the measured long-input rungs.**
    Neither a worst-case linear bound nor equality with plain-parser peak
    memory follows from these measurements. The plain parser alone (the
    frozen library, `_plainrss.dart`, 2026-09-06) peaks at 230 MB of RSS
    at 24k, 100k and 200k alike, the VM's floor, in 31–43 ms, so c17's
    0.4–1.5 GB is recovery memory; the retained-origin audit is lesson
    46. json
    `makeDoc` documents, four errors, one process per rung, peak RSS
    from `/usr/bin/time`, same session:

    | chars (seed) | c17 | c17 RSS | c16 | c14 |
    |---|---|---|---|---|
    | 1,442 (7) | 0.15 s | 234 MB | 0.36 s, 276 MB | 0.18–0.27 s |
    | 5,959 (7) | 0.57 s | 324 MB | 0.75 s, 428 MB | 0.73–0.78 s |
    | 24,190 (7) | 1.09 s | 364 MB | 8.8 s, 1.68 GB | 26.2 s, 4.9 GB |
    | 24,162 (1) | 0.62 s | 397 MB | 8.0 s, 1.76 GB | 54.6 s |
    | 100,072 (7) | 2.49 s | 864 MB | 12.9 s, 3.33 GB | 70.0 s, 13.4 GB |
    | 100,060 (2) | 3.10 s | 912 MB | 32–35 s, 7.45 GB | killed at 550 s |
    | 100,041 (3) | 2.26 s | 849 MB | 26 s | — |
    | 150,663 (7) | 3.86 s | 1.09 GB | 15.5–16 s, 4.21 GB | — |
    | 150,606 (1) | 2.99 s | 933 MB | 17.7 s | — |
    | 201,260 (7) | 5.36 s | 1.53 GB | 146.9 s | — |

    25–45 µs and about 7.5 KB per character. Costs equal c16's (= c14's)
    on every rung, and the edits are identical on 24k seed 1 (c14's
    three insertions, where the first c17 paid 5), 100k seeds 2 and
    3, and both 150k instances. At 200k one insertion differs: a `}`
    deleted at 42565 is put back at 42565 by c17, while c14 and c16
    put it at 165527, the latest point that still parses (the
    later-doubt preference, both cost 4) — a window cannot reach the
    position c14 prefers, and the generator's own position is c17's.

### The machine, sixth look — c18's falsification round (2026-09-05)

The experiment and reproduction commands are in
`dart/experiments/recovery/_C18_FINDINGS.md`. Starting HEAD: `1059d8e`.
The frozen library and existing engines were not edited. c18 is a useful
candidate, not the requested minimal addition: it still has its own plain
parser and c17's approximate two-unit windows.

44. **A local winner needs a replacement law, not just a comparator.**
    The earlier warning in §6d remains live in c14/c17. With
    `Top <- A 'd' 'e' 'Y'; A <- P / Q; P <- 'a' . .;`
    `Q <- 'u' 'v' . . 'b' 'c';`, input `xabcdY` costs 3 via Q,
    although P gives a two-edit reading. P's temporary absorption charge
    loses locally and disappears after the shared suffix supplies evidence.
    `_dominance18.dart` prints the original and forced-P trees. c18 applies
    absorption only to complete comparisons and returns cost 2. This fixes
    that eviction, not every possible continuation-dependent comparison.

45. **A free recovery reading is not proof of a PEG predicate.**
    `S <- &('a'* 'a') 'b';` on `a` produces `falseAssertions=1` in
    c14/c17: non-greedy recovery can satisfy the assertion's body, but greedy
    PEG cannot. `_pred18.dart` checks each returned assertion with the real
    library matcher. c18 asks the ordinary PEG verdict and returns an
    error-only tree (`falseAssertions=0`). Empty-input fallback must also
    cost one zero-width error mark, not zero. These are correctness fixes,
    not oracle preferences.

46. **Admission width is not retained width.** `_beam18.dart 64 7` finds
    13 retained c16 origins for repetition 39, end 374, budget 3, with W=8:
    `[29,62,98,116,149,203,237,294,328,354,364,365,366]`. All precede
    the end. Replacing an admission-row member does not remove old readings
    from other memo cells. This refutes the retained-width premise of
    lesson 33, not by itself every possible linear bound. A separate
    no-beam c18 control is full-tree-and-cost identical to c17 on all
    13,241 raw battery cases; that is not equivalence on all inputs.

47. **Retaining incomparable bills buys accuracy, not yet compactness.**
    The indexed `_envelope18.dart` admits conservative numeric alternatives
    per end. Its absorption inequality uses `deleted + 2*evidence` because
    `absorbed > evidence` iff `span > deleted + 2*evidence`; 2 is algebra,
    not a tuning coefficient. Final-memo census: 669,957 readings in
    438,949 end buckets, maximum width 50. This is not a peak-heap count or
    a minimal Pareto set, and windows still constrain candidate discovery.

    | Engine | Weighted score / perfect | Normalized code lines | Paired damaged latency / c17 |
    |---|---|---:|---:|
    | c17 | 0.9900 / 86.0% | 1330 | 1.000 |
    | c18 | 0.9900 / 86.0% | 1194 | 0.785 |
    | envelope | 0.9902 / 86.2% | 1219 | 1.362 |

    Five interleaved rounds after warmup; full methodology in the findings.
    Raw scores: c18 0.9914 / 87.7%, envelope 0.9915 / 87.7%. Both have
    zero crashes, uncovered cases, or error-cost audit failures. Both pass
    acceptance, freespan `3 3 4 4 1`, recommit 16/16, conformance
    `0 1 1 0 2 3`, clean-tree equality and 2,728 additional grammar/input
    property checks. The current library suite has 284 passing tests.
    At 201,260 chars / four errors / seed 7, fresh-process c17/c18 are
    4854/3640 ms and 1,646,927,872/1,308,446,720 bytes peak process RSS.
    Envelope's 100,060-char seed-2 rung regresses to 14,949 ms; no general
    speed or worst-case complexity win is claimed for it.

48. **Laziness needs a demand rule; deleting mechanisms is not enough.**
    Freezing every successful plain subtree outside windows loses score
    (0.9880 / 85.0%). Replacing the ambiguous-missing penalty by rejection
    passes the old gates but loses `xb` under
    `S <- A 'x' 'b'; A <- 'a' / 'b';` (cost 3 instead of 1).
    Removing windows from the envelope fails freespan (`4 4 5 5 1`).
    Each is retained as a rejected control. The architectural next step
    is to keep the ordinary PEG verdict and attach a lazy recovery relation
    to existing memo machinery, sharing clean trees and repair backpointers.
    Predicate truth and other hard coherence conditions must be distinct
    from final preference; pruning needs continuation-compatible dominance.
    At the close of c18 this was a hypothesis; c19's implementation and
    measurements follow below.

### c19 — attach the relation, keep the ordinary verdict (2026-09-05)

49. **The architecture can be a small addition to the actual library.**
    `_c19.dart` implements `Recovery(existingParser).recover()` with repair
    relations in side maps keyed by real MemoEntry identity. Ordinary answers, assertions and terminal
    matching use that same Parser and unchanged input. A repair relation has
    its own growth/version clock: the frozen scalar MemoEntry loop cannot
    hold a set of ends/bills in its `result`. Clean input returns the original
    root object with zero recovery relations. Unchanged subtrees are shared;
    no engine-owned plain interpreter or converted clause hierarchy remains.
    Size: **470 normalized code lines**, versus c18's 1194; not yet under 400.

50. **Lazy attachment is not selective demand within a relation.** c19
    delays expansion until a `(clause, position, budget)` asks, then still
    enumerates that budget's alternatives. No window or beam is used.
    Weighted 0.9900 / 86.1%; raw 0.9916 / 87.8%, all crash/coverage/bill audits
    zero. Acceptance, freespan, recommit 16/16 and conformance pass, as do
    the three c18 counterexamples and 2728 property checks, now including
    preservation of the ordinary memo verdict. The archived charge check
    gives `0 0 0`; committed gives `[2..3, 3..4] OK` (substitution plus tail
    deletion, not the old r-series error list). Native same-end successes
    exclude repaired rivals as a freespan **policy**, not a dominance theorem.

    Five-round paired damaged latency is **1.892x c18 / 1.487x c17**.
    Clean c19/native is 0.999 in a separate paired control: attachment itself
    adds no resolved cost in that sample, although c19 is ~1.54x c18/c17 on
    their different plain interpreters. At 5959 chars / four errors / seed 7,
    c18/c19 take 447/2443 ms and 316538880/629432320 bytes peak process RSS.
    Final c19 times out at **45 seconds on 24190 characters**; the audit let
    it run, over 150 s and 7.7 GB peak RSS (lesson 55). This establishes
    a code-size reduction, not the sought scalable recovery algorithm.

51. **An ordinary match is safe proof, not automatically a safe repair seed.**
    `_c19seed.dart` starts the repair fixed point with the complete native
    match. Gates pass, but weighted score falls to 0.9898 / 85.9%. The selected
    c19 keeps proof and repair seed separate. The inferred issue is that
    choice admission observes the preferred readings already present; the
    full operator is not made monotone by a numeric Pareto front. The next
    unresolved mechanism is end/continuation-specific demand with a justified
    exclusion law, not merely another container for all affordable readings.
    `_C19_FINDINGS.md` records implementation anchors, controls, limitations
    and reproduction commands. No existing engine was replaced.

52. **Inspecting a native LR tree must not restore input-depth recursion.**
    c19 initially overflowed at 8193 characters in `_ev`, the evidence walk,
    not in the frozen parser. An explicit postorder stack fixes that probe:
    cost 1, full coverage, 17716 ms / 1640722432 B peak process RSS. It adds
    12 normalized lines (458 to 470). The high time/memory still indicts
    enumeration; fixing a tree visitor does not establish scalable recovery.

### Cross-series audit — distinct objectives and explicit test sets (2026-09-06)

53. **A smaller engine is not necessarily a faster or lighter engine.**
    The common c1–c19 comparison in §2 confirms c19's 724-line reduction
    against c18 and three extra perfect cases, but also 1.91× battery time,
    5.49× time and 2.02× peak process RSS on the common 5,959-character probe.
    c14 is the short-battery speed point; c18-envelope is the measured
    accuracy point; neither fact establishes the requested all-criteria
    optimum. Keep accuracy, clean/damaged latency, size, memory and
    conformance separate. A single memory rung is not a complexity bound.

54. **“All gates pass” must name the test set and the grammar being checked.**
    All twenty entries pass the four ordinary groups, yet c2/c11 fail the
    separate committed-prefix check, and only c11/c15/c18/c19/envelope pass
    the extra greedy-predicate example. c2's normalized `#0` references
    also expose an audit trap: a frozen-parser lookup error on a foreign
    clause is not evidence that recovery crashed. The original predicate
    is demonstrably false where c2's returned tree claims it. Check
    original-grammar meaning, distinguish harness errors from engine
    failures, and retain counterexamples beyond the scored battery.

### Audit of the Codex round (2026-09-06)

55. **A scored dump that agrees is not a tree that agrees, and a driver
    that prints UNKNOWN has not run.** Codex's c18 was rebuilt from
    `_c17.dart` by seventeen asserted text replacements (`mk18.py` in the
    session scratchpad) so that c17's documentation survives and the
    class names stay public (`Squirrel`, `Clause`, `rules`); Codex's file
    is kept as `_c18codex.dart`. `_treecmp18.dart` walks both engines'
    trees (clause, position, length, children) plus `lastCost` over all
    13,241 raw cases: rebuilt c18 against Codex's, 0 tree and 0 cost
    differences; c18 against c17, 146 trees and 5 costs differ (41 of the
    2,101 weighted cases, every one at equal score), and all five costs
    are c18 = 1 against c17 = 2: the single deletion in
    `["epsilon"},"zeta"]` and its kin, which c17 lost while the absorb
    penalty was still charged inside the sequence (inferred from the
    change list; not traced case by case). The earlier record that
    "c18's dump equals c17's" compared only the scored dump, which prints
    cases scoring below 1.0. `_recommit17.dart` and `_recommit18.dart`
    imported `_score16.dart`'s resolver, so they printed UNKNOWN for c17
    and c18: the "0 of 1" recorded for c17 was never a run. With the
    import fixed, c17 and c18 each pass 16/16. Gates on the rebuilt c18:
    accept ok cx2=1 b1=1 b2=1, freespan pass, recommit 16/16, conf1
    `0 1 1 0 2 3`, 2,728 property checks with 0 violations, `_pred18`
    falseAssertions=0 at cost 1, `xabcdY` cost 2 (c14 and c17: 3).
    Same-day timings, one process per rung, peak RSS from
    `/usr/bin/time` (this machine ran about 10% slower than in the c17
    session): battery c18 1,059–1,099 ms, c17 1,350, c14 601; 24k seed 1
    0.57 s / 330 MB, cost 3; 100k seed 2 2.75 s / 713 MB, cost 4; 200k
    seed 7 4.71 s / 1.22 GB, cost 4 (c17 in its own session: 0.62 s /
    397 MB, 3.28 s / 922 MB, 5.37 s / 1.53 GB). Lines: c17 1,330 → c18
    1,194 (−136, −10.2%); c14 807 → 1,194 (+387, +48.0%).
    `loc.normalised` returns (raw, normalized) pairs, as its docstring
    says; reading them the other way round produced a false "c19 is 388
    lines" during the audit. c19 is 470 normalized (388 raw: `dart
    format` unwraps its long lines). Envelope at 100k seed 2: 15.4 s /
    1.08 GB, and on a 2.5M-character document 62.6 s / 13.3 GB; c19 at
    24k seed 7: over 150 s and 7.7 GB. Standing: c14 stays the standing
    engine; c18 replaces c17 as the scratch candidate for long inputs
    (0.76x c17's time, 0.8x its memory, one better cost) at 1.8x c14 on
    the battery's short inputs, so promotion remains the workload call.

### c20 — the relation on the real parser, and the stops the input dictates (2026-09-07)

56. **The cost of a Pareto front is the number of insertions, not the
    price of one comparison.** The 100k profile put `_Front.add` at 23.5%
    inclusive, and two attempts to make the scan itself cheaper both
    failed: splitting the buckets by the front's two equality-class heads
    (`incomplete`, `missing == 0`) gave identical trees and no speedup,
    because the map traffic cost what the skipped comparisons saved, and
    reordering `cover` to test those two heads first changed nothing.
    Attribution by site then found a single sequence slot iterating over
    **118,911** alternative readings on one 100k input, which is where the
    time actually was.

57. **After one repair inside a repetition, every later item end is a
    distinct reading the front cannot compare away.** `_repeat` returns
    one prefix per iteration end, and the sequence around it reads its
    next slot at every one of them. The front separates readings by where
    they end and never compares two that end apart, so a bill that has
    paid once is carried unchanged to every subsequent stop and none of
    them dominates another. Of 848,478 readings reaching the prune,
    **91% were kept only because they had already paid for a repair.**
    This is the mechanism behind the c19 line's memory and latency, not
    the enumeration of repairs itself.

58. **Keep the stops the input dictated, and the prune is exact.** Record
    the positions where the walk *ran out* — the body could not be read
    again from there, so the walker stopped because the input told it to —
    and keep exactly those, plus every position under doubt, plus the
    farthest the walk got. A block's statements stop where the closing
    brace is because no further statement can be read there, and that is
    the stop the enclosing sequence needs. Front insertions fall from
    7.89M to 2.79M, 79% of repetition readings are dropped, the worst
    slot's alternatives fall from 118,911 to 28,233, and 100k goes from
    5,208 ms / 1,042 MB to 2,778 ms / 899 MB — with the battery trees
    bit-identical to the unpruned engine (both `treeDiff` 1882,
    `costDiff` 1 against the c17 reference). Four cheaper criteria were
    measured first and each cost accuracy: all short stops on closed
    ground (0.9895 / 85.7, fastest at 1,862 ms), the farthest stop per
    bill (0.9898 / 86.0), both ends of each bill's stop range (0.9900 /
    86.1). The four cases that separated them were all `stmt`, all a stray
    character inside a nested block, and each needed an *interior* stop on
    closed ground — the repetition has to be allowed to end where the
    enclosing block's closing brace sits.

59. **`treeDiff` and `costDiff` print 0/0 unless the literal word
    `compare` is on the command line.** Without it the battery driver
    never loads the reference dump and reports no differences at all,
    which reads exactly like a tree-identical result. Every "identical
    trees" claim in this round was re-taken with the argument present;
    against the c17 reference, c18 is 41/1, c19 is 1888/1 and c20 is
    1882/1, so a large `treeDiff` here means "differs from c17", not
    "differs from its own unpruned form".

**c20 as measured.** c19's repair relation (a Pareto front of numerically
incomparable bills per end position) attached to the real `peg.Parser`,
plus c18's locality windows, so a repair is tried only at open positions
inside a window over the round's farthest death, plus lesson 58's prune.
Battery **0.9901 / 86.3** in 1,471–1,496 ms, the highest accuracy of any
engine measured (c18 0.9900 / 86.0 in 986–989 ms; c19 0.9900 / 86.1 in
1,628 ms). All four gates: accept `cx2=1 b1=1 b2=1`, freespan `3 3 4 4 1`,
recommit 16/16, conformance `0 1 1 0 2 3`, `cleanTreeDiff=0`; 2,728
property checks with 0 violations; `_pred18` cost 1, falseAssertions 0
(matching c18, where c14 and c17 each have 1); `_dominance18` equal to c18
on all three arms including the `xabcdY` eviction that c14 and c17 fail.
Rungs, same machine, one process per rung, peak RSS from `/usr/bin/time`,
c18 first and c20 second: 24k seed 1 509 ms / 325 MB / cost 3 against
650 ms / 354 MB / cost 5; 24k seed 7 847 / 320 / 4 against 615 / 339 / 4;
100k seed 2 2,225 / 711 / 4 against 2,702 / 898 / 4; 150k seed 7 2,755 /
813 / 4 against 2,142 / 797 / 4; 200k seed 7 3,812 / 1,210 / 4 against
3,466 / 1,257 / 4. The cost-5 result at 24k seed 1 is the same before the
prune and is a property of the c19 lineage, not a regression from it.
Lines: c19 470 → c20 **886** normalized (+416, +88.5%), which is 0.74x
c18's 1,194 and 0.67x c17's 1,330, and 1.10x c14's 806. An alternative
that quantizes doubt to the left edge of its open run (`qf` inside
`cover`) reaches 2,073 ms / 760 MB at 100k but costs the tie-breaks:
0.9901 / 86.0 with `treeDiff` 1916. It is not the installed engine.

**c20 after the size round (2026-09-07).** The stack walk is gone; the
window's left edge counts back `back` = 4 marks in `_bound` (where the
repair search finished an evidenced, non-lexical repetition occurrence)
and may not reach past `wide` = 64 marks in `_plainBound` (where the
ordinary parse finished one). A death is an `int`. Lines **886 → 742**
normalized (−144, −16.3%; 677 raw code lines, 232 comment lines), which
is 1.58x c19's 470. Battery **0.9899 / 86.1** in 1,364–1,395 ms against
the walk's 0.9901 / 86.3 in 1,500 ms, `costDiff` 1 for both against the
c17 reference; case by case, 7 worse and 4 better, all 11 at equal cost.
All four gates: accept `cx2=1 b1=1 b2=1`, freespan `3 3 4 4 1`, recommit
16/16, conformance `0 1 1 0 2 3`, `cleanTreeDiff=0`; 2,728 property
checks, 0 violations; `_pred18` cost 1, falseAssertions 0. Rungs, written
as the driver argument `nodes/errors/seed`, one process each, peak RSS
from `/usr/bin/time`, boundary walk first and stack walk second:
`1000/4/1` (23,568 chars) 440 ms / 311 MB / cost 4 against 503 / 329 / 4;
`4000/4/2` (97,688) 1,359 / 624 / 4 against 1,534 / 647 / 4; `6000/4/1`
(147,054) 2,642 / 957 / 4 against no answer in 400 s at 14.9 GB;
`6000/4/3` (147,078) 5,646 / 1,467 / 6 against 2,913 / 1,003 / 4;
`6000/4/7` (147,105) 2,647 / 925 / 4 against no answer in 400 s at
11.2 GB; `8000/4/1` (196,441) 3,253 / 1,117 / 4 against 3,599 / 1,230 / 4;
`8000/4/7` (196,515) 3,724 / 1,263 / 6 against 4,111 / 1,303 / 6.

**60. The window's left edge is a count of finished occurrences, so it
    does not need the stack that produced them.** c20's window walked
    back through the live frames when a reading died: `_claim` unwound
    `back` evidenced units, `_units` descended into finished pieces,
    `_fresh` re-entered a piece that ended at the death with its own
    count, and `_atomic`/`_atomicPiece` decided per piece representation
    what counted as a unit — 227 raw lines and two copies of the same
    logic, one per piece representation. The only thing that walk
    computes is a position: where the last few proven occurrences began.
    A repetition already knows when it has finished an occurrence, so
    marking `_bound[end]` there and counting back over the marks gives
    the same edge without the stack. That deletes `_claim`, `_units`,
    `_fresh`, `_atomic`, `_atomicPiece`, `_startOf` and the `_Death`
    class (a death is now an `int`), and costs nothing on price: against
    the walk, 7 battery cases score lower and 4 score higher, every one
    of the 11 at identical repair cost — a tie-break in tree shape, not
    a worse repair.

**61. Marks made only by the repair search are marks only where doubt
    has already been.** The first boundary build marked `_bound` solely
    in `_repeat`, so the marks lay wherever the search had iterated. Text
    the ordinary parse read cleanly is answered from a memoized cell and
    never iterated, so it carries no marks at all. When the death then
    moves to a region the search has not walked, the four nearest marks
    can be a whole document behind it: measured, a window of 47,618
    characters at budget 2 on a 147k input, which does not terminate in
    400 s. Clearing the marks each round does not help — the gap is
    inside one round, not across rounds. The fix is a second array,
    `_plainBound`, marked from the ordinary parse's own occurrences,
    which is complete everywhere; the walk may not reach back past
    `wide` of them. `wide` is the smallest value that leaves the
    battery's repair cost unchanged: 32 gives `costDiff` 3, 64 and 128
    give 1, and the scale cost rises with it (147k seed 3: 4.3 s at 32,
    5.6 s at 64, 64 s / 4 GB at 256), so it is a bound on the search,
    not a tuning knob.

**62. The cost grows with the number of repairs, not the length of the
    input, and that is an unsolved problem, not a property to accept.**
    Measured on the installed engine with `_time20.dart`: at four errors
    the document length is nearly free — `1000/4/1` (23,568 characters)
    0.44 s, `8000/4/7` (196,515) 3.7 s — while at fixed length the error
    count is not: `1000/4/1` 0.44 s, `1000/8/1` 10.2 s, `1000/12/1` no
    answer in 120 s. Per rung of the ladder on `1000/12/1` the round
    times are 70, 57, 73, 155, 180, 477, 1250, 3148, 20157, 25094 ms,
    about a factor of 2.5 to 3 per rung, so the whole run is roughly the
    fourth to fifth power of the number of repairs. Instrumented, the
    fills per round stay near 30,000 and the open positions grow
    linearly (144 to 988), but the readings proposed per fill go 0.7,
    1.3, 3, 2, 9, 23, 35, 125, 240, 370: the growth is entirely in how
    many readings a cell hands back, not in how often it is asked.
    Inside the widest bucket at rung 10 (377 bills reaching one
    position) there are 59 distinct cost tuples, 113 distinct pairs of
    doubt positions and 10 distinct evidence values.

    Five attacks on that growth, all measured, none sufficient:
    (a) a hard ceiling on how many bills one end position keeps (8, by
    the acceptance order) leaves the battery bit-identical and cuts the
    work 30 % — the buckets are rarely that wide, so it is not the
    exponent; evicting a bill AFTER inserting it also stops `_read`'s
    fixed point from ever settling, because the evicted bill is proposed
    again on the next pass and reports progress forever, and every scale
    rung then spins at flat memory. (b) Dropping the doubt positions
    from the covering relation cuts the widest bucket from 377 to 115
    and makes `1000/12/1` finish in 103 s, but 16 errors still do not,
    and it costs two points of perfect. (c) Quantizing the doubt
    positions to the window they fall in gives 0.9894 / 85.4 and no
    scale gain. (d) Giving each window its own spending allowance,
    clamped inside the sequence fold, prices 54 cases wrong, because a
    cell filled under a clamp is cached as if it were complete; making
    the allowance a second ladder inside the budget instead keeps every
    price (`costDiff` 1, as it must: no complete reading exists one rung
    down, so every winner of the accepting rung is charged exactly the
    budget and the inner ladder can only choose among equals) but pays
    for the extra rounds — 8 errors 22 s against 10 s. (e) Confining the
    `_stops` prune's open-position exemption to the window the reading's
    own doubt lies in is bit-identical on the battery and gains nothing
    at scale.

    What the measurements say the fix must be: the front carries the
    running totals for the WHOLE document, so the number of ways to
    divide those totals grows with the number of errors, wherever they
    sit. No local prune changes that. Bounding it means not carrying
    global totals — pricing a window and committing it before moving on
    — which is a different engine and revives the greedy-commit family
    refuted at c1/b2 (0.8826), now with windows and deaths available
    that generation did not have.

**63. A rung recorded as "150k seed 7" is not a rung anyone can re-run.**
    The c20 figures below were written with the document size as a
    character count and the generator arguments left out. `_time20.dart`
    takes `nodes/errors/seed` and `makeDoc(6000, 4, 7)` produces 147,105
    characters, but the engine that produced the battery figures
    recorded here (verified: it still scores 0.9901 / 86.3) cannot
    finish that rung in 400 s, and at `1000/4/1` it answers cost 4 where
    the record says cost 5. So the recorded specification does not
    identify the input. Every rung in this section from here on is
    written as the literal argument passed to the driver.

**64. Three of the eight heads in the covering relation were doing no
    work.** Folding `owed` and `fee` into one head, and then `missing`
    with them, leaves the battery BIT-IDENTICAL (0.9899 / 86.1,
    `treeDiff` 1888, `costDiff` 1) — the four currencies were never four.
    Separately, `first` is two things at once: at or above `_clean` it is
    the reading's rank, below it the position where doubt began. Keeping
    only the rank, and letting the position decide between bills that
    cover one another both ways (the relation's existing "equal
    summaries replace the tree" rule, unchanged), scores 0.9901 / 86.0
    against 0.9899 / 86.1 — a better score for a smaller relation, all
    four gates, 2,728 property cases 0 violations, and the same rung
    times. Which rule breaks the tie is worth 2.4 points of perfect on
    its own: keeping the incumbent gives 83.6, choosing by the
    acceptance order 84.1, choosing by the position rule directly 84.1,
    and replacing gives 86.0.

### c21 investigation — scheduling, tariffs, and a counterexample (2026-09-08)

**65. A bounded window is a heuristic, not a completeness argument.**
CONFIRMED by `dart/experiments/recovery/_window21.dart`, against the current
c19, c20 and the new c21 scheduling experiment:

```
S <- P / A;
P <- '(' Item* ')';
A <- Item*;
Item <- 'a';
```

For input consisting of n `a` characters followed by `)`, c19 keeps the
parenthesized reading, marking the absent opener, at n=1,4,8,16,64,256.
C20 agrees at n=1 and 4. At n=8 it instead selects A and deletes the real
closer: the window is [(4,8)], excluding the opener at zero. At n=256 its
window is [(252,256)] and the same divergence occurs. All these readings
cost one; this is loss of an available same-priced structural explanation,
not a claim that the damaged text uniquely determines its author's intent.
C21 inherits the failure.

Source: c20 `_window` at 859 and `back=4 / wide=64` at 301/303.
This refutes the universal proximity justification for those boundaries.
The wording in lesson 61 that a battery-selected bound is “not a tuning
knob” must not be read as satisfying a no-arbitrary-heuristics requirement.
It also does not separately refute every aspect of lesson 58's stop prune.

**66. Repetition has an acyclic scheduling problem; ordinary left recursion
does not disappear with it.** CONFIRMED: the repeat step explicitly requires
`step.end > r.end`. The new `_c21.dart:704` processes input positions in
order, combining incoming prefixes before expanding each position. It is a
small alternative to c20's queue of individual histories, not a new Parser,
not Dijkstra by repair charge, and not a minimum-repair certificate.

Measured against current c20, using the same current oracle:

| Engine | Weighted score | Perfect / 2,101 | Raw score | Perfect / 13,241 |
|---|---:|---:|---:|---:|
| c20 | .990135 | 1806 | .991224 | 11464 |
| c21 scheduling | .990198 | 1808 | .991424 | 11502 |

There are 14 weighted / 156 raw full-tree differences and **zero** cost
differences. This is an aggregate improvement, not casewise dominance.
CONFIRMED commands: `_research21.dart battery c21 compare`,
`_research21.dart battery c21 compare raw`, and
`_research21.dart battery c20 raw`.

Scheduling is observably part of the policy: `_Front.cover` ignores actual
first-doubt positions below the clean sentinel, and mutual coverage replaces
the tree with the newest arrival (c21:86,127). The final comparator still
reads first doubt (c21:870). Hence a scheduling or packed-representation
rewrite cannot be called tree-neutral by numeric-summary reasoning alone.

**67. The best accuracy experiment was not a dramatic performance or size
win; the much faster prune regressed accuracy.** CONFIRMED, with timing
methodology and all exploratory controls in
[`_C21_FINDINGS.md`](dart/experiments/recovery/_C21_FINDINGS.md):

- Three warmed, interleaved battery rounds: c20 median 1177.785 ms;
  c21 1220.141 ms (3.6% slower). Clean timings were noisy and did not establish
  a clean-path improvement.
- Fresh serial `1000/8/1` workers: c20 8452 ms / 891.5 MiB peak RSS;
  c21 7665 ms / 871.3 MiB; tariff control 4272 ms / 632.8 MiB.
  These are single cold samples, not medians or recovery-only heap sizes.
- The tariff control scored .990080, 1805 perfect, with 11 different trees
  and no changed costs. It is not score-neutral and is not promoted.
- At `1000/12/1`, tariff finished in 40113 ms / 1701.0 MiB, cost 11;
  current c20 and c21 each exceeded a 50-second worker cap (exit 124).
  These timeouts establish neither nontermination nor a completed-run ratio.
- Normalized LOC: c20 743, c21 745, tariff 771. The sub-400 goal is unmet.

More than twenty executable controls were tried: price-profile and scalar
dominance, EOF specializations, evidence/position ordering, incurred-penalty
budgets, shared deterministic corridors, stale-work skipping, native closed
span shortcuts, view caches, budget-exhaustion certificates, and a smaller
window-free natural-stop engine. None delivered the requested combination.
Some passed every ordinary gate while losing substantial battery accuracy.

CONFIRMED c21 validation: acceptance 3/3 (including the exact b1 fixture),
freespan 5/5, recommit 16/16, conformance 6/6, false predicates 0; committed
errors [2..3,3..4], identical to current c20 and disjoint from the accepted
0..2 chunk; 2,728 property cases with zero violations; 34 existing-parser
attachment/memo checks passed. Weighted crashes, uncovered, mischarges and
invalid zero-cost results were all zero. `dart test` is currently **+284**,
all passing, not the historical +308. The original engines and dart/lib
were not edited.

**68. Sharing choices does not require committing choices.** INFERRED
architectural direction, **not an implemented breakthrough**: attach a
packed recovery forest to the existing parser, retaining AND nodes for
concatenation and OR nodes for alternatives, then request completions under
the actual continuation's budget and coherence conditions. Native memo
verdicts remain the ordinary PEG verdicts. Only recursive grammar dependencies
need a recovery fixed point; repetition can use position order.

For k independent reconverging binary repairs, an AND of k OR nodes has
O(k) representation without enumerating 2^k combinations. That factorable
example does not establish a universal complexity bound or describe c20's
measured exponent. It does show why lesson 62's measurements do not establish
that greedy window commitment is the only alternative to whole-history bills.

An admissible search can initially relax nonnegative penalties and use
deleted+missing as a lower bound, strengthening it with known clean fragments.
Coherence filters, evidence bounds for tied costs, EOF obligations,
zero-progress cycles and stable preference order must still be implemented.
C20's incomplete-root override and evidence-erasing lexical scans prevent
calling a simple scalar Viterbi substitution equivalent. This proposed packed,
continuation-demanded engine was **not built in this round**; the executable
c21 contains only the scheduling change and retains the heuristic windows.
Neither experiment is promoted as satisfying the original full brief.


### c22, round 1 — packed histories, eager recognition (2026-09-08)

**69. A packed forest is implemented; packing alone is not a performance
solution.** `_c22eager.dart` preserves this round's executable. It attaches
AND/OR recovery relations to actual native memo entries, with budget-indexed
cells and no windows or beams. It does not create a second Parser, alter the
input, or replace ordinary PEG verdicts. Discrete relation keys contain end,
spent edits, fee, EOF-owed flag, clean rank, and incomplete flag. Evidence,
deletion/missing split, first/last error positions and concrete histories are
not recognition keys.

The implemented selection factors non-additive pricing into queries. Fixing
the deletion count makes support filters monotone in evidence. First-error
and last-error bounds constrain every error leaf; three passes maximize
evidence/first, constrain first and minimize last, then constrain both and
apply a stable owed/count/canonical-tree preference. The final mixed-edit
tie-break is applied at the root. Optional direct-terminal repetition is
the evidence-erasing case; here evidence before erasure is fixed by consumed
span minus deletion count. This is an algebraic argument for this engine's
specific filters, not a proof for arbitrary recovery policies.

CONFIRMED initial checks (run from `dart/` with
`/opt/flutter/bin/cache/dart-sdk/bin/dart run experiments/recovery/…`):

- `_compare22.dart gates c22`: A=3, F=5, R=16, C=6, committed=true,
  committedErrors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
- `_properties22.dart c22`: 2,728 cases, 60 clean, zero violations.
- `_memo22.dart`: 34 checks passed, including unchanged Parser/MemoEntry
  identities, ordinary verdicts, input and clock, and shared clean subtrees.
- `_research22.dart battery c22 compare`: 2,101 cases, score .989836,
  1,800 perfect (85.7%), zero crashes/uncovered/mischarges/invalid-zero;
  2,020 raw-tree differences and zero cost differences from c20. The large
  raw-tree count includes label differences on clean EOF subtrees, not 2,020
  changed AST skeletons. This is below c20's .990135 / 1,806 perfect.
  Timed recovery total was 3,862 ms (single JIT run, not a warmed median).
- `_packed22.dart scale 1000 4 1`: length 23,568, cost=edits=4,
  covered=true; **43,890 ms / 11,774.3 MiB process peak RSS**, 31,663,803
  nodes, 13,593,328 groups, 332,412 budget cells. Only 25,155 query states
  were needed. This timing overlapped short audit workers; it is not a
  controlled speed ratio. The allocation count itself establishes failure.

This round is rejected as a performance candidate. Histories are shared,
but eager enumeration of repetition endpoints still builds an enormous
relation that its actual continuation scarcely uses. The next experiment
must share continuation/suffix work, not merely the prefixes that lead to it.
`dart/lib` and the pre-existing engines were not edited.

### c22, round 2 — a completion lower bound (2026-09-08)

**70. Regular relaxation prunes some recognition, not enough.**
`_c22bound.dart` preserves the variant. It compiles grammar entry/exit
states into a regular over-approximation: calls may return through any
caller, assertions are ignored, and terminal substitutions are permitted
more broadly than the real engine. A backward edit-distance table on
state × input-position provides a necessary completion-cost bound. EOF
holes are free in this bound; real fees and coherence are still checked
by packed selection. It never constructs a repaired input or Match tree.
INFERRED admissibility: every real repair has a path in this relaxation;
the converse is deliberately false. It is a lower-bound analysis, not a
second ordinary Parser or a distance/proximity heuristic.

CONFIRMED `_packed22.dart schedule` on round 1: 2,101 cases, **zero tree
or cost changes when OR traversal is reversed**, 8,142 ms total for both
orders. This tests selection-order independence, not all possible fixed-point
schedulers.

CONFIRMED intermediate bound-at-cell-exit battery: .989836 / 1,800 perfect,
zero crashes/uncovered/mischarges/invalid-zero, zero cost differences from
c20, 4,044 ms single-run timed recovery (`_research22.dart battery c22 compare`).
With the bound also used at entry and sequence prefixes,
`_packed22.dart scale 1000 4 1` printed cost=edits=4, covered=true,
**29,951 ms / 8,571.4 MiB**, 23,510,004 nodes, 10,044,280 groups,
268,166 budget cells and 25,155 query states. This was a fresh serial worker.
The bound removed roughly one quarter of the eager forest nodes; that is
still far worse than the c20/c21 controls. It is not promoted as a speed win.

The next round shares a relation across budget rounds rather than rebuilding
its zero/low-cost structure in separate budget cells. This change must be
tested, not assumed tree-neutral: guards and seed invalidation also observe
the available budget.

### c22, round 3 — incremental budget sharing (2026-09-08)

**71. Sharing across budgets saves storage, but not this workload's time.**
`_c22shared.dart` preserves this round. One relation per native MemoEntry
grows to the largest requested budget; lower-budget views filter paid cost.
Packed OR edges propagate newly found same-summary choices without replacing
old witnesses. The ordinary PEG memo clock is separate and untouched.

CONFIRMED `_research22.dart battery c22 compare`: .989836 / 1,800 perfect,
zero crashes/uncovered/mischarges/invalid-zero and zero cost differences
from c20, 3,619 ms single-run recovery total. `_properties22.dart c22`:
2,728 cases, 60 clean, zero violations. The final round-2 entry/prefix-bound
variant had the same score and counts (3,737 ms) and passed all current
gates (A3/F5/R16/C6, committed=true, falsePredicates=0).

CONFIRMED fresh serial `_packed22.dart scale 1000 4 1`: length 23,568,
cost=edits=4, covered=true; **33,671 ms / 7,182.4 MiB**, 20,094,898 nodes,
8,449,773 groups, 165,361 cells, 285,516 expansions, 2,070,148 bound prunes.
Fewer stored nodes did not make this sample faster than round 2.
`scale 200 4 1 census`: 315 ms / 345.9 MiB, 77,539 nodes. Changing document
size changes the seeded damage sites, so these two samples are **not** a
scaling-exponent measurement.

**72. Sharing without commitment is now directly executable.**
`_packed22.dart independent 4 tree` uses
`S <- Item*; Item <- ('a' 'x' / 'y' 'a') ';';` on `a;a;a;a;`.
Each site can mark the missing `x` after `a` or the missing `y` before it.
It constructs one forest, then restricts permitted error positions in the
selection query to request every combination. CONFIRMED: **16 combinations,
16 distinct full trees, zero extra forest nodes and zero extra recognition
expansions**. Initial recovery: cost=edits=4, 232 nodes, 92 groups, 21 cells,
31 ms / 282.9 MiB (single cold worker). Every selected tree covers the input
and has exactly the requested four diagnostic positions. This is stronger
than observing fewer frontier entries: earlier choices have not been lost.
It does not yet establish linear total query cost or arbitrary-grammar
complexity. A deletion-count query currently tries impossible splits even
when all repairs in a subtree are known to be holes; the next round derives
that query domain from the forest itself.

### c22, round 4 — demand only queries that can still win (2026-09-08)

**73. Non-additive selection can be bounded without collapsing its choices.**
`_c22query.dart` preserves this round. A scalar fixed point derives each
packed node's possible deletion-count interval. Selection asks candidate
roots incrementally, using paid+EOF as a cost lower bound and input length
minus deletions as an evidence upper bound. After cost/evidence and first
error have been fixed, later passes request only roots/counts still able
to attain those optima. The special incomplete-root override is retained.
No error-location combinations are replaced by one locally chosen history.

CONFIRMED `_packed22.dart independent 8` on the preceding shared variant:
**256 distinct combinations** recovered from the same 444-node forest,
zero extra forest nodes/expansions. With deletion domains alone,
`independent 64` used 3,412 nodes, 27,603 query states, 260 ms / 329.0 MiB.
After incremental root bounds and pass-to-pass restriction, the same probe
used **3,412 nodes, 6,147 query states, 134 ms / 296.8 MiB**. It selected four
different 64-site combinations, all correctly diagnosed and covered, without
new recognition. Times are fresh single JIT workers, not warmed medians.
The grammar factors into independent binary choices; exhaustive selection
has been checked through eight sites, not through all 2^64 combinations.

CONFIRMED weighted battery after the final query changes: .989836 / 1,800
perfect, zero crashes/uncovered/mischarges/invalid-zero, zero cost changes
from c20, 3,811 ms single-run total (`_research22.dart battery c22 compare`).
Before that last query optimization, reversing both relation-view order and
OR traversal gave **zero tree/cost changes in 2,101 cases**, 8,261 ms total.
`window 1024` returned cost=edits=1, covered=true, 4,125 nodes, 64 ms /
287.8 MiB. The driver is being strengthened to assert the actual `P` arm,
not merely cost, before claiming the distant-opener counterexample resolved.

The general recognition bottleneck is still present. These results establish
choice retention and cheaper selection, not the requested tiny, universally
fast recovery engine. The next round removes choice wrappers only from
preferred unrepaired prefixes, whose trajectory is fixed by ordinary PEG;
nonpreferred clean alternatives must still retain their OR nodes.

### c22, round 5 — ordinary prefixes need no choice wrapper (2026-09-08)

**74. Most of the bad allocation is not clean PEG bookkeeping.**
`_c22atom.dart` preserves this variant. Preferred unrepaired prefixes are
stored directly; repaired and nonpreferred clean groups retain their OR
nodes. On `_packed22.dart scale 1000 4 1 census` this removed only 187,897
nodes from round 3's 20,094,898. CONFIRMED: **33,737 ms / 7,117.2 MiB**,
19,907,001 nodes, 8,261,876 groups, cost=edits=4, covered=true. Query work
is now only 9,237 states/relaxations. Object sequences account for 1,820,416
stored groups; member-list repetition 1,455,813; its enclosing sequence
1,427,856. Another singleton-storage tweak will not fix this.

This is evidence for the next distinction: a query can be lazy about
**which history** wins while recognition is still eager about **where the
construct ends**. A continuation supplies endpoint restrictions as well as
score restrictions. The next experiment propagates conservative endpoint
ranges backward through following slots; these ranges must be derived from
the grammar and remaining edit budget, not an input-distance constant.

### c22, round 6 — continuation-derived endpoint ranges (2026-09-08)

**75. Narrowing the root is not the same as demanding nested completions.**
`_c22demand.dart` preserves the rejected variant. It propagates a conservative
endpoint range backward through each sequence's remaining slots. Finite
terminals contribute length plus available edit budget; direct-terminal
repetitions use indexed positions of nonmatching characters; unbounded or
recursive shapes relax to the start of input. Memo relations are indexed by
the demanded range. Native left-recursive entries relax the range at their
seed boundary, avoiding a new input-depth recursion through shrinking ranges.
These are grammar/budget-derived bounds, not a new fixed-size window.

CONFIRMED initial weighted run: .989836 / 1,800 perfect, zero crashes,
uncovered, mischarges, invalid-zero and changed costs vs c20, 4,164 ms
(`_research22.dart battery c22 compare`). After correcting the one-or-more
fallback to test whether any advancing prefix exists, rather than whether
an advancing prefix remains inside the demanded range,
`_packed22.dart scale 1000 4 1 census` gave **33,758 ms / 7,092.1 MiB**,
19,712,844 nodes, cost=edits=4 and complete coverage. JSON-root groups
fell from 13,331 to 7, but Object still had 1,790,253, member-list repetition
1,470,922 and its enclosing sequence 1,406,532. The constrained root barely
affected the unbounded intermediate relations. This variant was rejected
for extra code/cache complexity without a substantial performance gain;
it has not received the final broad validation of `_c22.dart`.

The active `_c22.dart` is restored to the smaller round-5 packed/query
prototype, not promoted over c20/c21. Round 5's weighted run was .989836 /
1,800 perfect, 3,689 ms, zero crashes/uncovered/mischarges/invalid-zero and
changed costs. Its full current gates passed (A3/F5/R16/C6, committed=true,
falsePredicates=0). Final comparative timing and audits follow below.

### c22, final audit and a separate clean-path control (2026-09-08)

**76. Stable preference includes grammar identity, not allocation order.**
Before the final audit, synthetic character clauses inside multi-character
literals were moved into the grammar-indexing pass. Allocating their
canonical IDs at the first recovery failure was an avoidable dependence
on exploration order, even though the raw-order test had not exposed it.
The final policy is charge, evidence, latest first error, earliest last
error, EOF mark count, mixed-edit tie, node count, canonical preorder with
depth. The incomplete-root exception is resolved explicitly before the
position/tie passes. Node count makes unproductive recursive wrapping lose.

CONFIRMED before that ID fix: `_packed22.dart schedule raw` compared
13,241 cases with both relation-view and OR traversal reversed: **zero
different trees or costs**, 47,005 ms for both orders combined. Final
post-fix validation is recorded below; this earlier run is not substituted
for it.

Final-source timing (`_timing22.dart 3`): one warm-up, three measured rounds,
rotating c20/c21/c22 order in one process, no other benchmark worker running.
Clean columns time 200 repetitions of the entire undamaged corpus; damaged
columns time one complete weighted 2,101-case battery. These are medians,
in milliseconds, not per-document latency:

| Engine | Clean corpus × 200 | Damaged battery |
|---|---:|---:|
| c20 | 192.896 | 1154.875 |
| c21 | 188.153 | 1182.747 |
| c22 packed/query | 103.731 | 3337.049 |

The damaged path is **2.89× slower than c20** here. The clean path avoids
recovery grammar setup altogether. A separate `_c20defer.dart` control moves
only `_site(top)` below c20's already-successful ordinary-parse return; its
validation and timing follow below. This is not a solution to damaged-input
search, and the original c20 is unchanged.

Physical nonblank, non-`//` lines (`awk` count; **not** the normalized LOC
used in older tables): c20 **677**, c21 **679**, c22 **804** (including the
one-line lower-bound API shared by the ablation controls). C22 is larger,
and does not meet the sub-400 target. No formatter or code golfing was used.

CONFIRMED fresh serial `_family22.dart ENGINE SITES` on the independently
ambiguous `a;` family (each result cost=edits=sites, Item count=sites,
covered=true):

| Sites | c20 ms / peak MiB | c22 ms / peak MiB |
|---|---:|---:|
| 8 | 20 / 280.3 | 38 / 285.6 |
| 32 | 94 / 289.6 | 72 / 285.2 |
| 64 | 242 / 286.6 | 125 / 290.2 |
| 256 | 21435 / 444.6 | 282 / 313.5 |
| 1024 | 30-second cap, exit 124 | 823 / 354.1 |

These are cold single workers, not medians or isolated recovery heap.
The family isolates independent ambiguity; it does not stand in for the
JSON battery or contradict c22's poor 23.6 KB JSON result.

At 256 sites the completed-run ratio is 76×. The 1,024-site timeout is
not a completed-run ratio or evidence of nontermination. A follow-up
ablation puts the same regular lower bound into the **old** c20: eagerly
(`_c20floor.dart`) or only after budget 1 has genuinely failed
(`_c20guided.dart`). This is needed before attributing the family speedup
to packing: avoiding futile budget rounds is a separate effect.

CONFIRMED at 256 sites: eager c20+floor **10,638 ms / 446.1 MiB**;
lazy-after-budget-1 c20+floor **10,812 ms / 329.4 MiB**. Both returned
cost=edits=Item count=256 with full coverage. The lower bound roughly halved
c20's time, but did **not** explain the whole 21,435→282 ms difference.
A further all-positions-open control checks the cost of the window-opening
ladder itself before assigning the remaining difference to representation.

That control **refutes a packing-only speedup claim**: `_family22.dart
openfloor 256` returned the same cost, Item count and coverage in **256 ms /
295.5 MiB**, versus packed c22's 282 ms / 313.5 MiB. The old engine plus the
same lower bound, with every repair position open initially, removes the
window-opening ladder and is just as fast on this family. The 76× headline
is a real control-to-candidate measurement, but is **not evidence that
packing itself caused that speedup**. Packing's separately demonstrated
benefit is retaining and reselecting the combinations, not this ratio.
The all-open control retains c20's tie policy. Its `_stops` code remains,
but `_openAt(w.end)` is always true, so it cannot prune an endpoint in
this control. General accuracy/scaling must be checked independently.

CONFIRMED `_research22.dart latency defer 3 c20`: clean median
**112.401 vs 206.735 ms** (45.6% lower for the deferred-setup control);
damaged median **1175.366 vs 1198.933 ms**. The 2% damaged difference is
not claimed as a speed improvement. It is a one-statement relocation;
tree equivalence is tested separately below. This is an isolated clean-path
win and does not fix c20's arbitrary windows.

Final control validation (`_research22.dart battery ENGINE compare [raw]`):

| Control | Battery | Score | Perfect count | Tree / cost differences vs c20 |
|---|---|---:|---:|---:|
| deferred clean-path setup | raw 13,241 | .991224 | 11,464 | 0 / 0 |
| floor only after budget 1 fails | weighted 2,101 | .990135 | 1,806 | 0 / 0 |
| floor + all positions open | weighted 2,101 | .989986 | 1,803 | 26 / 0 |

All three had zero crashes/uncovered/mischarges/invalid-zero. The deferred
control also passed `_compare22.dart gates defer`: A3/F5/R16/C6,
committed=true, errors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
These final audit workers overlapped other correctness workers; their times
are not substituted for the isolated timing results above. The all-open
control changes policy, not just scheduling overhead, and does not dominate
c20 on the weighted battery.

**77. Final c22 validation, without substituting an earlier variant.**
HEAD remained `3074b20`; toolchain was Dart 3.12.2 stable, linux_x64.
All commands use `/opt/flutter/bin/cache/dart-sdk/bin/dart` from `dart/`.
After deterministic indexing of literal-character clauses:

- `_packed22.dart schedule raw`: **13,241 cases, zero tree/cost differences**
  under reversed relation-view and OR traversal (46,854 ms for both orders).
- `_research22.dart battery c22 compare`: **.989836 / 1800 perfect** of
  2,101; zero crashes/uncovered/mischarges/invalid-zero, zero changed costs.
- The raw counterpart: **.991321 / 11527 perfect** of 13,241; zero
  crashes/uncovered/mischarges/invalid-zero, **three** changed costs and
  12,159 raw-tree differences from c20. Raw score/exact improve on c20;
  weighted score/exact regress. This is not a casewise improvement.
- `_compare22.dart gates c22`: A3/F5/R16/C6, committed=true,
  errors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
- `_properties22.dart c22` and `c22reverse`: each 2,728 cases, 60 clean,
  zero violations, including ordinary-verdict, coverage, charge, predicate
  and positive-width terminal checks.
- `_memo22.dart`: 34 attachment/verdict/sharing checks passed.
- `_audit22.dart`: `committed errors=[2..3, 3..4] OK`;
  `charge invalid=2101: 0 0 0`.
- `dart test -r expanded`: **+284, all pass**. An initial invocation with
  `--no-pub` was rejected as an unsupported test option and was rerun
  correctly; that rejected invocation is not counted as a test pass.
- Targeted `dart analyze`: no issues found.
- `_packed22.dart independent 8`: 436 nodes, 747 query states; all 256
  combinations distinct, correctly billed/covered/positioned, zero extra
  forest nodes or recognition expansions. At 256 sites: 13,332 nodes,
  23,811 query states; four full-width BigInt-selected combinations passed
  the same checks. These runs validate retention, not exhaustive 2^256
  selection. Test timings overlapped an audit and are not benchmark ratios.
- `_packed22.dart window 1024`: cost=edits=1, covered=true, **P=true**,
  3,099 nodes; the distant-opener case is checked by arm, not only cost.

The raw cost differences are not all desirable. For
`{"n":[0,-7,1.5,2e],t":[true,false,null]}`, c20 costs 2; c22 costs 1 by
marking a missing backslash at position 3, treating the already-present
closing quote as an escaped quote, and swallowing the damaged first value
into a longer key. The real terminals still come from input and the bill is
honest, but it loses intended structure. `_costdiff22.dart trees` prints
the actual trees. This illustrates the distinction between a cheaper edit
and a coherent interpretation; it is not a reason to report lower cost as
an unconditional improvement.

The complete raw cost-difference list, confirmed by `_costdiff22.dart`, is:

| Input | c20 edits | c22 edits |
|---|---:|---:|
| `{"n":[0,-7,1.5,2e],t":[true,false,null]}` | 2 | 1 |
| `[{"x":[1,2,]"y":{"z":3}},{"x":[],"y":{}}]` | 3 | 2 |
| `{"p":[1,2,3],"q":[4,5,6,"r":[7,8,9],"s":[0,-1]` | 2 | 4 |

The driver printed `cost differences=3`. In particular, retained choices
and a stable preference do not imply lower reported edit counts casewise.

### c23 trial — clause-local prefix conservation (2026-09-08)

The next trial, `_c23.dart`, propagates an error-position floor equal to
the ordinary successful clause's end. New repairs **inside that clause**
may extend its accepted prefix but may not alter it. Clean shorter
alternatives remain possible (needed for splitting a greedy lexical match),
and the floor does not leak back to the caller after a child returns.
Relations include this inherited floor in their memo identity. This is a
new coherence policy, **not** a semantics-neutral packing optimization or
a claim that the policy is universally right: e.g. an unescaped quote may
require editing a quote the ordinary parser already accepted. It is being
tested against both the gates and the battery before any recommendation.

CONFIRMED c23 trial: gates A3/F5/R16/C6, committed=true, falsePredicates=0,
but weighted score **.978147 / 1715 perfect**, 124 changed costs versus c20,
zero crashes/uncovered/mischarges/invalid-zero (`_research22.dart battery
c23 compare`, 3,046 ms). Removing the initial `{` from the first JSON
document changes c20's cost 1 into c23's **44**: the ordinary parser's
speculative String prefix is protected against the correct Object repair.
On `1000/4/1`, c23 took 3,388 ms / 811.7 MiB, but cost **6** instead of 4.
Its physical nonblank/non-`//` count is **807** lines. This is a rejected
accuracy tradeoff, not an improvement.

**78. Feasibility is not preference either.** Code inspection of c22 found
that the Ref, ordered-choice and repetition support filters remain opaque
during recognition. Consequently, a doomed zero-evidence branch can acquire
large enclosing relations before selection finally rejects it. The next
trial hoists conservative support bounds into monotone node annotations,
while retaining OR alternatives and leaving the final preference in the
query. This is distinct from c23's premature commitment: rejecting an
infeasible relation is not choosing among feasible histories. Its cyclic
updates must participate in the recovery fixed point; a one-time cached
"no evidence" answer would be unsound when a seed later gains evidence.

CONFIRMED `_c24.dart` trial, with assertions enabled: gates
A3/F5/R16/C6, committed=true, falsePredicates=0; weighted **.989836 / 1800
perfect**, zero crashes/uncovered/mischarges/invalid-zero or changed costs
vs c20 (4,724 ms single run). Each forest node propagates upper bounds on
E and D+2E and a lower bound on D. Impossible support filters prevent a
node from entering a frontier; later OR growth can wake the same-position
recovery clock. Budget-indexed cells are restored so a larger-budget
relation cannot retroactively change a smaller-budget support result.

This did **not** deliver the anticipated performance win:
`_compare22.dart scale c24 1000/4/1` returned cost=edits=4, covered=true,
**48,326 ms / 10,003.1 MiB peak RSS**. The annotation/dependency machinery
and duplicated budget cells cost more than the pruning saved on this
sample. Because both changed, this is not an isolated estimate of the cost
of early support checks. The monotonicity assertions and weighted/gate runs
passed; this is not yet a proof of every cyclic grammar or a promoted engine.

Final `_properties22.dart c24` and `c24reverse`, both run with
`dart run --enable-asserts`, each printed `cases=2728 clean=60 violations=0`.
Targeted analysis of the current c22/c23/c24 engines, four c20 controls and
their drivers printed `No issues found!`. This broadens the c24 correctness
audit, not its performance claim or its validation to the whole raw battery.
The c24 physical nonblank/non-`//` count is **848** lines. A final rerun of
`dart test -r expanded` again completed with **+284, all tests passed**.

For comparison, the all-open legacy control on the same JSON shape,
`_research22.dart scale openfloor 1000/4/1`, returned cost=edits=4,
covered=true in **13,409 ms / 2,961.9 MiB**. Removing the window ladder helps
the independent family but loses the advantage of bounded search on JSON.
Neither control satisfies the combined size/latency/memory/accuracy brief.

**79. The two previously proposed mechanisms are now executable, but they
are not the missing performance solution by themselves.** In `_c22.dart`,
AND/OR relations retain alternatives behind existing ordinary memo entries;
selection does not replace those alternatives with its winner. Non-additive
ranking is handled by fixing deletion count D in the query, maximizing
evidence E, and recomputing under error-position constraints. For a dirty
root the ranked charge is
`D + missing + fee + hasEOFOwed + (inputLength - D > 2*E ? 1 : 0)`;
`missing` here counts the paid, non-EOF holes. The reported edit count instead
includes every EOF mark and excludes fees.
The incomplete-root exception is explicit, not silently dropped to make
the charge additive. Support filters are applied inside query composition.

CONFIRMED implementation/experiments: 256 independently selected combinations
from one forest without new recognition; zero changed trees/costs across
13,241 inputs under reversed relation-view and OR order. INFERRED limitation:
this is not a confluence proof for every grammar-generation scheduler. In
particular, recognition still contains guards based on the presence of clean
options while seeds grow. Such a proof would also have to establish that
generation produces the same admissible graph, not merely that selection
on a fixed graph is stable.

The measured failures distinguish three tasks: storing histories compactly,
rejecting impossible histories, and avoiding construction of irrelevant
endpoints. C22 does the first and delays the final choice; its large JSON
forest shows that this does not automatically do the third. C23 commits to
ordinary prefixes too early; c24's attempted early impossibility checks cost
more than they save. The all-open legacy ablation explains the dramatic
independent-family speedup without packing. None of these measurements proves
a lower bound on the size of a better algorithm or that the ideal is
impossible. They do rule out promoting these particular implementations as
the tiny, fast, low-memory answer.

The accepted isolated optimization is the clean-path setup deferral, preserved
in `_c20defer.dart`; the original engine remains available as its control.
The packed prototype, rejected variants, probe programs and per-round results
are retained for reproducibility. No frozen-library or original-engine source
was changed. A final repository-wide `git diff --check` found only the existing
trailing whitespace in the user's `dart/test/recovery/_one.dart`; that unrelated
edit was left alone.

### c25 — the admissible floor prunes the rung, and the call site is what makes a bracket cost (2026-09-08)

c25 is c20 (the c19 relation on the real parser, `back=4` windows,
`_stops`) plus three changes. It is installed as
`dart/experiments/recovery/_c20.dart`, so every harness name is still
`c20`.

**1. Deferred clean-path setup.** `_site(top)` moves below the early
return taken when the ordinary parse already covers the input. This is
Codex's `_c20defer` finding, confirmed: on a clean document the recovery
grammar is never built.

**2. A regular lower bound, used inside the rung, not only to choose it.**
`_Bound` is an NFA over-approximation of the grammar with a backward
edit-distance table `distance[at][state]`, giving `after(c, at)` (from a
clause's exit) and `before(c, at)` (from its entry): an admissible lower
bound on what completing the document costs from there. Two prunes:

```dart
if (r.spent + _floor(c, r.end) > _budget) { pruned = true; continue; }
```

on every proposed bill, and

```dart
if (_bnd != null && _bnd!.before(c, pos) > _budget) return const [];
```

on the whole cell before it is filled. Cells that read no open position
are cached at `_unlimited` and reused at every higher budget, so a cell in
which anything was pruned must be recorded at the current budget instead:
that is what the `pruned` flag is for. Without it the prune silently drops
bills that are valid one rung up. The bound is built once the ladder
reaches budget `_guide = 3`; below that the rungs are cheap and the ~500 ms
build does not pay for itself.

Codex's `_c20guided` used the same bound only to pick the ladder's
starting rung. That is the weaker half: the floor is small relative to the
rungs that dominate, and a separate control (`_c20.start.dart`) that jumps
the ladder start measured 4,640 ms against 4,591 ms for no jump — no gain.
The win is entirely in pruning **within** a rung.

**3. The call site is what makes an unclosed bracket cost anything.**
Codex's relaxation lets a call return through ANY caller
(`eps(end_R, b)` for every caller of `R`). On a 23,560-character json
document with 12 real errors that relaxation's floor is **2**: merging
callers destroys exactly the bracket structure that makes json damage
expensive, so an unclosed brace is nearly free. Unfolding each call per
call site, and tying the knot only where the grammar is genuinely
recursive (`onPath`), raises the floor to **7** for 1.75x the states
(220 → 384, 19 → 34 MiB, ~300 → ~500 ms). The engine's cells carry no
call site, so a clause's bound is the least over its copies — still below
every real completion, whichever context the cell is in.

**Unfolding deeper is refuted.** With an unfold depth `k` (a recursive
clause gets `k` fresh copies before the knot is tied), on the same
`1000/12/1` document:

| k | states | build ms | table MiB | floor |
|---:|---:|---:|---:|---:|
| 1 | 384 | 584 | 34 | 7 |
| 2 | 1,856 | 2,404 | 166 | 7 |
| 3 | 7,744 | 16,026 | 696 | 7 |

The floor does not move while cost grows 20x. The remaining slack in the
bound is not call depth; it is the other two relaxations — assertions are
ignored and a substitution is allowed at every terminal. Driver:
`_boundstat3.dart`.

**Measured.** Battery bit-identical to the c20 base: `0.9901 / 86.0`,
treeDiff 1919, costDiff 1 against the c20 dump, for every bound variant
tried. All four gates pass; `_properties18 c20` 2,728 cases / 0
violations; `_pred18` falseAssertions 0; the repository suite is 284/284.
Rungs are single fresh workers, `_time20.dart`, json `makeDoc`:

| Rung (nodes/errors/seed) | chars | c20 base | c25 |
|---|---:|---|---|
| 1000/4/1 | 23,560 | 452 ms / 305 MB | 891 ms / 286 MB |
| 1000/8/1 | 23,560 | 8,938 ms / 871 MB | **1,045 ms / 362 MB** |
| 1000/12/1 | 23,560 | **never finished** (>500 s, 2.6 GB) | **1,691 ms / 439 MB** |
| 1000/16/1 | 23,560 | never finished | 4,146 ms / 483 MB |
| 1000/24/1 | 23,560 | never finished | 54,348 ms / 1,133 MB |
| 1000/32/1 | 23,560 | never finished | **still never finishes** (>400 s) |
| 4000/4/2 | 97,700 | 1,392 ms | 3,190 ms |
| 8000/4/7 | 196,500 | 3,668 ms / 1,204 MB, cost 6 | 6,682 ms / 987 MB, **cost 4** |

The bound is **not** output-neutral. An earlier claim in this session that
it was a pure speed knob is wrong: at `8000/4/7` the base engine and
`_guide = 5` both return cost 6 while `_guide = 3` returns cost 4. Pruning
changes which readings die, hence which deaths are recorded, hence which
windows open. Here it strictly improves the answer, but it is a search
change, not only a speed change, and `_guide` is a parameter that must be
scored, not assumed.

**Cost.** Normalized LOC c20 743 → c25 **901** (+158, **+21.3%**), almost
all of it `_Bound`. That is the wrong direction for the size goal and is
the main argument against this build.

**All positions open is refuted a third way.** Deleting the windows and
relying on the bound alone fixes Codex's window counterexample (`P` is
kept at every n) and removes both `back=4` and `wide=64`, with battery
0.9900 / 85.8 and all gates passing — but `1000/8/1` takes 64,014 ms /
2.5 GB and `1000/12/1` never finishes. The windows do work the bound
cannot replace. Variant: `_c20.allopen.dart`.

**Still open.** `1000/32/1` does not finish, so the hard requirement that
every input terminate is **not met**. Codex's window counterexample
(`_window21.dart`: c20 loses the `P` reading for n >= 8 because the
`back=4` window excludes the opener at position 0) is **still unfixed** in
c25, since the only fix found so far is all-open, which does not scale.


### The synthesis round — what each engine is best at, and why one engine cannot hold all of it (2026-09-11)

The question was whether the per-metric winners can be combined. Measured
bests, and the mechanism each one's advantage comes from:

| Metric | Best engine | Value | The mechanism responsible |
|---|---|---|---|
| Accuracy | c18-envelope | 0.9902 / 86.24 | c13's seven keys + the envelope |
| Size | c19 | 470 LOC | bills in side maps on the real library parser |
| Battery latency | c14 | 370 ms | no windows: one pass per case |
| Clean path | c14 | 7.57 µs/doc | no recovery grammar built |
| Large-input time and memory | c18 | 430 ms / 296 MiB | windows, no beam, memoized plain |
| Many errors on one document | c25 | 12 errors in 1.7 s | the admissible bound pruning inside the rung |
| Structural soundness | c19 | keeps the reading at every n | no window to exclude the repair site |

c20/c25 already hold five of these: c19's relation, c18's windows, the
stop prune and the bound. The two it does not hold are battery latency and
size, and this round established that the first of those is **structural**,
not an oversight.

**The pass census.** Instrumenting the ladder over the 2,101-case battery
(`_pass20.dart`): **6,179 top-level passes, of which 3,720 are window
re-runs and only 358 are budget increments.** So 60% of all work on short
inputs is re-running a pass because a window opened, and almost none of it
is climbing the ladder. Same-process battery times, one process per engine,
for reference: c14 468 ms, c18 946, c19 1590, c20 1371.

**Why the re-runs cannot be merged.** The 1.77 re-runs per case are two
distinct windows: one over the error, then one over the end of input, which
only becomes visible after the first repair lets the parse reach the end.
Opening the end window eagerly alongside the death window does exactly what
the census predicts on short inputs — re-runs fall to one per case (3,720 →
2,101), passes fall 26%, battery 1,371 → 1,241 ms, every tree unchanged —
and is **catastrophic on long inputs**: `1000/8/1` goes 976 ms / 321 MiB to
**57,313 ms / 2,198 MiB**, and `1000/12/1` does not finish. An end window
open from budget 1 makes the whole ladder explore end-of-input insertions.
Rejected and reverted.

**Why the diagnostic pass cannot be skipped either.** The first pass at
budget 1 has no open positions, so it is just the plain parse; its only
products are the death position and the window marks. The death is
available for free — `parser.syntaxErrorPosition()` already exists in the
library — but the marks are not: `_plainBound` is written from the
repetition sub-matches of `parser.match(c, pos)` at recovery cells, and the
library memoizes at rule boundaries only, so a repetition's occurrence ends
are not in the memo table. Reproducing them costs what the pass costs.

So the window design has a floor of about 2.2 passes per case where c14
needs one, and that is the whole 2.9x. **c14's battery latency and c18/c25's
large-input behavior cannot be held by one engine as long as locality comes
from windows**, because the mechanism that supplies the scaling is paid for
once per case on every input, including the ones too short to need it.

#### The bound is regular, and bracket balance is not

The round also settled where the admissible bound's slack lives, which is
the other half of why a combined engine is hard. Floor against the cost the
engine actually returns, json `makeDoc`, 23.5k characters:

| errors | cost returned | floor | free |
|---:|---:|---:|---:|
| 4 | 4 | 3 | 1 |
| 8 | 8 | 5 | 3 |
| 12 | 11 | 7 | 4 |
| 16 | 14 | 9 | 5 |

A controlled single-deletion experiment (`_boundstat8.dart`: delete exactly
one structural character from a clean 897-character document, at every
position, and read the floor) says precisely which deletions are free:

```
  "@d1  n=100 free=  0      ,@d1 n= 39 free=  0      :@d1 n= 40 free=  0
  "@d3  n= 60 free=  1      ,@d2 n= 20 free= 10      [@d1 n= 10 free= 10
  {@d1  n= 10 free=  0      ,@d4 n= 10 free=  8      ]@d1 n= 10 free= 10
  {@d2  n= 20 free= 10                               }@d1 n= 10 free= 10
                                                     }@d2 n= 20 free= 20
```

**Every deleted bracket is free at every depth; quotes and colons are
charged correctly.** That is not an implementation defect: bracket balance
is not a regular property, so any finite-state relaxation must lose it.
This is the reason deeper call-string unfolding did nothing — re-measured
here per deletion, k=3 charges 1 of 10 `[` deletions where k=1 charges 0.

**The counting bound that can see it does not compose.** A right-to-left
scan gives the exact Dyck cost (unmatched openers, unmatched closers at the
document start, type mismatches): 2, 5, 3, 5, 7, 10 for 4, 8, 12, 16, 24 and
32 errors. Rebuilding the regular bound with every bracket terminal made
epsilon and every bracket character free to skip (`_boundstat9.dart`) leaves
the regular floor **unchanged** — confirming brackets contribute nothing to
it — which suggests the two price disjoint edits and could be added. They
cannot: the sums are 5, 10, 10, 14 against costs of 4, 8, 11, 14, so the sum
**exceeds the true cost** at 4 and 8 errors and is not a lower bound. One
inserted bracket repairs the balance *and* the local structure the missing
bracket broke, so the same edit is counted twice. `max` is sound and adds
nothing, because the Dyck figure never exceeds the regular floor. Getting
both without double counting needs the counter inside the distance DP — the
product of 384 NFA states with a depth counter — which is a per-document
table of hundreds of megabytes. Not attempted.


### Cross-review round 1 — the cdx line, and a bound that counts recursion depth (2026-09-22/23)

**Setup.** Codex, Gemini and a separate Claude session each got BRIEF1 and a
copy of the kit. Gemini ran out of quota (HTTP 429) before producing a
candidate. Codex's candidate is `_cdx1.dart`: c19's relation attached to the
ordinary parser's memo entries, one champion per end, a regular suffix bound,
and repetitions that share an ordinary occurrence when the next occurrence
also succeeds. It finished every rung, including 32 errors, but Codex also
proved that its repetition rule is not minimal: a six-character input where it
returns cost 3 and cost 2 exists. The cdx line below is that engine plus the
fixes found by the witness-oracle fuzzer (`_fuzz.dart SEED N engines...`,
which checks every answer against an exhaustive minimum on small grammars).

| Engine | Change | Battery | LOC (raw/norm) |
|---|---|---|---|
| cdx1 | Codex round-1 candidate | 0.9899/85.9, 1565 ms | 491/616 |
| cdx4 | the bound decides which stops a repetition exposes | 0.9899/85.9, 1418 ms | 497/627 |
| cdx5 | an edit may not be placed after a repetition departs | 0.9900/86.0, 2450 ms | 499/631 |
| cdx7 | ordered choice breaks ties in First | 0.9897/84.0 | 501/633 |
| cdx8 | stop guard | 0.9897/84.0 | 574/744 |
| cdx8p | `+` over a zero-width body | 0.9897/84.0 | 576/751 |
| cdx8x | flat-array bucket-queue bound; states whose only exit is free are merged | 0.9897/84.0, 1375 ms | 625/809 |
| cdx8y | the ladder starts at the bound's floor | 0.9897/84.0, 1372 ms, trees = cdx8x | 625/809 |
| cdx9r | the bound counts recursion depth; depth rows are bought as rungs fail | 0.9897/84.0, 1290–1334 ms, trees = cdx8y | 668/858 |
| cdx10 | the bound remembers the return site | 0.9899/84.3, trees = cdx9m | 845/845 |
| cdx11l | a later First arm must be one an edit could have forced | 0.9900/84.3 | 839/839 |
| cdx11o | four parts of cdx11l deleted; sealed repetition sharing kept | 0.9900/84.3, trees = cdx11l | 804/803 |
| cdx11r | Codex's three validity rules; fuzzer invalid 12/11/11/19 → 6/7/6/17 | 0.9900/84.3 | 835/837 |
| cdx11s | Codex round 3 minus the cdx11o deletions | 0.9900/84.3, 1,575–1,594 ms | 803/802 |
| cl8 | eleven rules deleted; the ordering penalty is a tie-break; fuzzer invalid 6/6/6/12 | 0.9900/84.3, 1,580–1,644 ms | 712/712 |
| cl10 | reference cycles and whole-literal substitution fixed; budget a parameter; corrected fuzzer invalid 11/9/11/9 (cl8 14/10/13/9) | 0.9900/84.3, 1,510–1,561 ms | 700/700 |
| cl11 | exact bound distances (512+ errors finish), iterative tree (LR 8,192 terms finish, quadratic), `_minChars` deleted; trees = cl10 | 0.9900/84.3, 1,461–1,523 ms | 696/696 |
| cl12 | semi-naive growth (LR with an error linear: 32,768 terms 868 ms), `first >= reach` in First, a substitution tie-break; corrected fuzzer invalid 8/8/9/6 (cl11 11/9/11/9) | 0.9899/84.3, 1,515–1,599 ms | 702/702 |
| cl13 | a diverse retry per budget and after the ladder (no-repair 10 → 0), same-stop guard conjunction, literal revival, resumption check, sealing (unclosed parenthesis linear); corrected fuzzer invalid 8/6/8/4 | 0.9899/84.3, 1,629 ms | 710/727 |
| cl14 | shared gap scan, position-ordered repetition worklist, covered repetitions, semi-naive seed fix, monotone success, gallop-and-bisect ladder, bound bought by counted front offers (no Stopwatch); all 46 families finish; corrected fuzzer invalid 8/6/8/4/7/7/8/10 | 0.9900/84.4, 2,164 ms | 800/803 |
| cl15 | ring-queue bound build (8000/4/7 9,354 -> 6,078 ms), `_versions` deleted, a new last ranking key (not transitive; removes the `aabb` bound dependence); battery treeDiff 1 vs cl14 at equal cost | 0.9900/84.4, 1,861 ms | 804/804 |
| cl16 | the last ranking key deleted (the ranking is transitive again; `aabb` bound-dependent again), `subs` and two filters that changed no result deleted; battery treeDiff 1 vs cl15 at equal cost | 0.9900/84.4, 1,850 ms | 796/796 |
| cl17 | an edit-count key above cost 1 (`acaca` bound-independent, 5 fewer invalid fuzzer trees, 4 fewer cases where cdx1 is cheaper), three redundant parts removed; battery treeDiff 0 vs cl16 | 0.9900/84.4, 1,820 ms | 792/792 |
| cl18 | the opener guard tests the whole inserted literal, and a covered repetition's stop is left to the repetition that encloses it (2 fewer invalid fuzzer trees, `cba` fixed); battery treeDiff 0 vs cl17 | 0.9900/84.4, 1,821 ms | 798/796 |
| cl19 | 27 lines of rewrites that change no answer (`_Relation` extends `_Front`, one exit array in the bound, no growth-counter reset); `_tail` exempts a growing stop only if it used a seed (`cbaa` now valid); invalid 51 -> 50, worse 18 -> 17; battery treeDiff 0 vs cl18 | 0.9900/84.4, 1,848 ms | 771/769 |

The table shows only battery score, time and size. It does not show the checks that separate the engines: measured in one kit on 2026-09-24, cdx1 has 389 invalid fuzzer trees on seeds 1-8 against cl15's 58, does not finish 4,096 errors, 8,192-term left recursion or 26 of the 46 families, and crashes on an unclosed parenthesis at 1,024 terms (see the cl16 section).

The perfect-case drop 85.9 → 84.0 at cdx7 is the price of making First obey
ordered choice when two readings tie; it removed wrong answers that the
fuzzer found and the battery does not score.

**Fuzzer (confirmed).** Worse-than-minimum answers, seeds 2/1: cdx7 14/10,
cdx8x 8/3, cdx8y 8/3; at N=400, cdx8y and cdx9r both 0/0. The remaining
invalid answers (27 and 22 at N=400, 49 in all, the same counts for cdx8y) are
of two kinds. In 18, no reading is found and the whole input is deleted, although
a cheaper repair exists (`R0 <- (R1 (R1 / 'a')) 'b'; R1 <- 'a' / 'b'*` on `ca`:
`aab` costs 2). In 31, the tree's repaired string is not accepted by PEG, for
example an insertion inside a later First arm whose earlier arm would match
the inserted character (`R0 <- 'b' R1; R1 <- 'a' / ('b' / R0)+` on `bab`). 30 of
the 49 grammars contain a directly nested repetition of a body that can match
nothing (`'a'*+`), so that shape is involved often but is not the only cause.
Both kinds are open.

**Where the 32-error time goes (confirmed, `cdx8yp`).** The ladder runs rungs
21 → 29 and the last rung is 2/3 of the 60 s. Each extra unit of budget above
the floor multiplies a rung's time by about 2.7. The gap between floor and cost
is almost all bracket deletions. Deleting one structural character at 209
random positions of a 40-member document, the regular bound charged `]`, `[`
and `}` zero (0 of 13, 0 of 10, 0 of 14), while the true cost is one each. The
regular relaxation lets a recursive call return to any caller, so a missing
closer is never owed. A dominance prune (drop a way whose cost exceeds another
way's at the same cell by more than their difference in position) removed only
8% of the work and was dropped.

**The depth-counting bound (cdx9, confirmed).** Inside the one backward
distance computation, each state is paired with a count of open recursive
calls. A recursive reference becomes a push edge into the cycle and a pop edge
out of it, never merged with anything; the count saturates at a cap, and at
the cap push and pop are free, so the bound is admissible for every cap. End
of input is accepted only at depth 0. Only the minimum over depth is stored,
one byte per (position, state), so the table is the same size as before; the
depth rows exist only in two working rows. This corrects the synthesis round
above, which said this product needs a table of hundreds of megabytes: that
was true only if every depth were stored. The root value (depth 0 at position
0) is exact for every deleted-character type in the sweep, `[` included
(10 of 10). The stored minimum over depth still charges closers but not
openers (`[` 0 of 10), because a prefix may start at any depth.

**The cap (confirmed).** At 1000/32/1: cap 1, 2, 4 → 59–60 s (no gain);
cap 6 → 22.4 s; 8 → 22.7 s; 12 → 25.9 s; 16 → 27.0 s. Build time grows
linearly with the cap (0.2 s at 1, 1.8 s at 8, 5.2 s at 16 for 23.5k
characters), so a fixed cap of 8 made one-error recovery 8x slower
(1954 ms against 255). Doubling the cap after each failed rung fixed small
inputs but not medium ones (4000/4/2: 2320 ms against 909). The rule kept is
rent-then-buy: build the depth-0 bound first, and build the next one (cap
2c+1) only once the search since the last build has taken twice as long as that
build did, i.e. as long as the next build is expected to take. Its total is
within twice the better of never building and building at once, and it
has no tuned constant. The clock only decides when to prune harder; the
answers do not depend on it (battery treeDiff=0 and costDiff=0 for caps 8,
doubling and rent-then-buy against cdx8y).

Rungs, ms (all costs correct, all covered):

| Rung | cdx1 | c20y | cdx8x | cdx8y | cdx9 (cap 8) | cdx9r |
|---|---:|---:|---:|---:|---:|---:|
| 1000/1/1 | 98 | 210 | 242 | 255 | 1954 | 282 |
| 1000/8/1 | 905 | 1091 | 484 | 475 | 2171 | 498 |
| 1000/16/1 | 1561 | 2167 | 1367 | 1341 | 2472 | 1557 |
| 1000/32/1 | 49681 | 31464 | 61037 | 60088 | 23093 | 28276 |
| 4000/4/2 | 2840 | 3382 | 893 | 909 | 8044 | 990 |
| 8000/4/7 | 5521 | 7354 | 1914 | — | 15862 | 1914 |

cdx9r passes every check: battery 0.9897/84.0, accept t/t/t, freespan
3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0 (all
identical to cdx8y), props 2728/0 violations, pred falseAssertions=0, window
counterexample P kept at n = 64, 256, 4096. LOC 809 → 858 normalized (+49,
+6.1%).

**A clean empty reading hid the deletion (cdx9m, confirmed).** `_seq`
offered a deletion before a slot only when the slot had no clean reading. A
slot that can match nothing always has one, so "delete this character, then
read the slot" was never tried, and the need surfaced later where only a
substitution or a long skip remained. With `R0 <- (R1 (R1 / 'a')) 'b';
R1 <- 'a' / 'b'*` on `ca`, every engine from cdx8 on found no reading and deleted
the whole input. Changing the condition to "no clean reading that advances"
(one line) gives: battery 0.9897/84.0 → 0.9899/84.3, costs changed in 51 cases,
all 51 lower (none higher); fuzzer worse-than-cheapest (against cdx9r) 10 → 1
and 18 → 0 at N=400, invalid 27 → 26 and 22 → 21; every gate, props, pred and
window unchanged; LOC unchanged (858). Price: 32 errors 32.1–32.5 s → 37.3–38.3 s
(alternated, same load), other rungs +5–16%. A second experiment, keying the
front by (end, has guard) so a guarded way cannot displace an unguarded one,
changed nothing on the fuzzer and was dropped. The `ca` case itself is still
invalid under cdx9m: the deletion lands after `R1`'s empty reading, and on the
repaired string PEG's first arm would then take the `a`. An edit placed right
after an empty match changes what that match sees; the stop guard covers this
only for repetitions and insertions, not for ordered choice or deletions.

**Still open.** (1) The two-sided cell prune: min over depth of (prefix
bound + suffix bound) would charge missing openers too, but it needs one
direction stored with its depth. (2) The zero-width repetition bodies above.
(3) 32 errors still take 28 s; the gap between floor (22) and cost (29) is
the remaining work, and the first rungs above the floor cost almost nothing
(confirmed), so the remaining work is in the bound, not the search
(inferred: a tighter bound would raise the floor and prune the last rungs;
not yet measured).


**The Claude seat's round-1 engines.** The seat hit its 3-hour limit without
a report. It built on c19 and added pruning contexts per cell (`_x5` is its
`cand.dart`, `_x7`/`_x7j` add a frame stack). Measured in the orchestrator's kit
(2026-09-23): battery 0.9900/86.1 for all three (c19's tie-breaking, which
returns trees PEG would not produce), 2066/2114/2508 ms; against cdx9m, costs
differ in 51 cases and none is lower. LOC 635 (x5) and 712 (x7) normalized.
Rungs: 1000/1/1 696 and 701 ms; 1000/8/1 42,368 and 14,739 ms (cdx9m 574);
1000/16/1 does not finish in 300 s for either; 4000/4/2 4,028 ms (x5). Smaller
than cdx9m, but dominated on cost and on every many-error input, so it was not
carried into round 2.

### Cross-review round 2 — the bound remembers the return site, not the depth (2026-09-23)

**Codex's round-2 engine (`cdx10`, untracked `_cdx10.dart`)** replaces the
depth-counting bound with one that remembers the most recent recursive return
site. Each recursive call site of the grammar gets its own symbol. A call
overwrites the remembered symbol, a return must match it, and after a return
any older symbol is allowed, so the rest of the stack is forgotten. Every real
call path maps to a path of this finite automaton, so the bound stays a
relaxation and stays admissible. It needs no depth cap and no deeper rebuilds.
The retained table is still one byte per (position, state), the minimum over
symbols. Floor at 1000/32/1: 21 (regular), 22 (depth 7), **27 (return site)**;
the answer costs 29. The stronger bound is bought once, when the search time
reaches (call sites + 1) x the regular bound's build time. The backward pass
is now a FIFO worklist over a precompiled product graph, and states with a
single free successor are contracted. The seventh judgment key (the mixed
deletion/insertion tiebreak) changed no battery answer and was deleted;
deleting the last-doubt key as well costs 34 trees (0.9895/83.9).

Checked in the orchestrator's kit: battery 0.9899/84.3 with treeDiff 0 and
costDiff 0 against cdx9m; gates, props (2728/0), pred and window identical;
fuzzer seeds 1 and 2 at N=400 worse 0/0, invalid 26/21 (same as cdx9m).
Rungs, alternated with cdx9m (ms): 1000/1/1 302 vs 277; 8/1 593 vs 556;
16/1 1,695 vs 1,860; **32/1 3,156 vs 39,786**; **64/1 3,029 vs over 300 s**;
4000/4/2 1,252 vs 1,015; 8000/4/7 2,435 vs 1,949 (+20–25% on sparse errors).
LOC 858 → 845 normalized (−13, −1.5%). Forcing the upgrade at once or never
changes no battery tree or cost, so on the battery the answer does not depend
on when the clock buys the stronger bound (confirmed for those two extremes).

Codex's refuted directions: the prefix + suffix cell prune at the same depth
(32 errors 36 → 58 s, 1.8 GB); forbidding open-class substitution in the bound
(no gain); ordering repetitions by increasing end (11–17 changed trees); a
budget-1 search before any bound (1 higher cost); a guard that rejects a later
First arm when an earlier arm's literal success lies before the first edit
(invalid 26/21 → 25/20, but it creates a new invalid case). Its counterexample
for Q1: `S <- A 'b'; A <- "ab" / 'a'` on `ac`. Both engines return cost 1
with A's second arm, but on the repaired `ab` A's first arm consumes both
characters. An arm's endpoint does not show that the arm stays selected after
a later edit, because an earlier failed arm may have looked past that
endpoint.

**Gemini's round-2 engine: a set of rejected characters at the frontier is
not the PEG obligation.** Gemini added `expectedMask` to the library's
`MatchResult` (the characters rejected at a match's frontier, one bit per
code unit mod 64, OR-ed through zero-width children) and refused an edit whose
character is in the mask of the piece before it, deleting the stop guard, the
stop exposure and the deletion offer rule. Its report says the fuzzer confirms
validity but gives no counts. Measured in its kit: battery 0.9899/84.3 →
0.9821/80.9 (149 trees and 78 costs differ from cdx9m, 51 lower), fuzzer
invalid 26/21 → **32/30**, worse 7 and 9 against cdx9m's 2 and 2, LOC 860.
The mask sees one character, so a failed arm that needs two or more
characters is either missed or refused too broadly, and mod-64 bits alias
unrelated characters. Its Q2 section (a prefix bound "makes the product a
sum") was not implemented; Codex's implementation of that prune was slower.

### cdx11 — a later First arm must be one an edit could have forced (2026-09-23)

**The engine (`cdx11l`, untracked `_cdx11l.dart`) is cdx10 with four changes.**
Each one removes a class of invalid tree, where an invalid tree is one whose
failures (an earlier First arm, a repetition stop, an absent optional) do not
hold on the repaired string R. All four come from reading the fuzzer's
INVALID lines (`_q1diag.dart`), not from the battery.

1. **The lexical-repetition shortcut in `_read` was wrong and is deleted.**
   Its comment claimed that a one-character terminal cannot repair and advance,
   so every alternative of a successful lexical repetition is a prefix of its
   PEG tree. That claim is false. `S <- 'b'+` on `bcbb` costs 3 in every
   engine since c14 (it deletes the `cbb` tail), while one deletion of `c`
   suffices. Deleting the shortcut and the `_lexicalWays` field fixes it.
2. **A repetition can delete forward.** Deletions used to be offered only
   before a `Seq` slot. `_repeat` now offers, when no occurrence reads past
   the run's end, the nearest position within the budget where the body
   parses cleanly again, with a skip in between. The same loop in `_seq` and
   `_repeat` is one helper, `_resume`. The first attempt,
   calling `_seq([c.subClause], ...)` from `_repeat`, made 94–95 uncovered
   trees: `_Way.then` keeps only the last piece of a multi-piece way, so the
   skip was lost. The way is now built as `r.then(skip).then(clean)`.
3. **The insertion fallback is decided by a flag, not by an empty result.**
   The fallback (insert one occurrence) ran only when `best.ends` was empty.
   Once the deletion offer filled `best`, the fallback stopped running and
   equal-cost ties changed (for example Num became Name on `+2*3...`). A
   `read` flag, set when any occurrence read input, restores them.
4. **Two rules for a later First arm.** (a) A later arm stands only if an
   edit could have failed the earlier one: it must not be clean, and its first
   edit must lie at or before `reach`, the farthest end any earlier arm's
   reading attained. (b) Its first edit must not insert the character that
   starts an earlier arm (`_starts(e, lead)`), since on R that earlier arm
   would then succeed. Rule (b) exempts an earlier arm that is left-recursive
   (`_cyclic`), because a left-recursive arm fails on its first visit by
   construction: without the exemption the valid seed case
   `R0 <- 'a'?? (R0 / 'c'+)` on `b` is rejected. The old test
   `r.absorbed(pos) >= r.evidence` on later arms is implied by these rules
   and is deleted (same trees on the battery, same fuzzer counts).

**Measured (orchestrator's kit, confirmed):** battery 0.9899/84.3 → 0.9900/84.3,
190 trees differ from cdx10 and one cost is lower (i=1023, 2 → 1, now
perfect). Scores are better in 8 cases and worse in 3 (564 `1.,52e3`
1.0 → 0.917, 680 1.0 → 0.993, 756 0.958 → 0.938). Checks unchanged:
accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P at every n, pred 0 false assertions.
Fuzzer at N=400: invalid 26/21 → **12/11** (seeds 1/2), worse 4/4 against
cdx10's 78/87 (worse counts against the best listed engine). LOC 845 → 839
normalized (−6, −0.7%). Rungs (ms), cdx10 vs cdx11l: 1000/1/1 337 vs 330;
8/1 687 vs 698; 16/1 1,661 vs 1,872; 32/1 3,254 vs 3,636; 64/1 3,148 vs
3,804; 4000/4/2 1,157 vs 1,258; 8000/4/7 2,507 vs 2,505. Every rung finishes;
16–64 errors are 7–21% slower.

**Refuted or neutral in this round:** setting a deletion's `lead` to the next
input character (25 costs rise, all substitutions: a substitution inserts the
slot's character, not the next one); using the slot's character for a
substitution's lead (neutral: invalid 15/11 against 14/12, worse 7/9).

**Known limits, not changed:**
- Substitution exists only inside a `Seq` slot, so `R0 <- 'b'` on `a` costs 2.
- The Ref filter (`evidence > 0 || clean || end == pos || _oneShape`) counts a
  voluntary lexical scan as zero evidence, so `R0 <- 'c'* 'b'` on `ccca`
  costs 4 where one substitution suffices. This is the filter's deliberate
  policy against invented readings.
- Mutual left recursion still gives cost-0 invalid trees (for example
  `aaaac`): the engine's relation fixed point is not PEG's seed growth.
- `_q1diag` counts a tree as invalid only when the plain parser rejects every
  witness spelling of it (membership). It does not compare spans or First
  arms with the plain parse of the repaired string; its `_diag` line only
  prints a diagnosis. The invalid counts above are lower bounds. A strict
  count (`_q1strict`, any node span or arm that differs from the plain parse
  of R) gives 122–151 per seed for cdx10 and 127–179 for cdx11r; about half
  of those trees differ only within one character of an edit, mostly a
  repetition or First arm that would continue across the edit point. The
  strict count does not separate the engines (trees with a difference more
  than one character from every edit, seeds 1–4: cdx10 199, cdx11r 224).

### cdx11o — five deletions from cdx11l keep every tree class; two others are the speed (2026-09-23)

**Each part of cdx11l was removed alone and measured** (battery against
cdx11l, all checks, fuzzer seeds 1–4, then the rungs 8000/4/7 and 1000/32/1):

| Removed | treeDiff/costDiff | Score/perfect | Checks | 8000/4/7, 1000/32/1 ms |
|---|---|---|---|---|
| (A) hand-copied `_Way` in the scan-evidence reset → `change(ev: 0)` | 0/0 | 0.9900/84.3 | pass | — |
| (F) `incomplete` flag, its fallback and price loop at the root | 1/0 | 0.9900/84.3 | pass | 2,433 / 3,564 |
| (H) `_oneShape` term in the Ref filter | 0/0 | 0.9900/84.3 | pass | 2,483 / 3,646 |
| (J) the absorption term in `charge` (`charge = cost + fee`) | 0/0 | 0.9900/84.3 | pass | 2,301 / 3,553 |
| (B) the ordering penalty | 58/0 | 0.9902/84.7 | **fails accept b2 (D8)** | — |
| (D) stop exposure (`exposed`, `kept`, `floor`) | 4/0 | 0.9900/84.3 | pass, invalid 11/11/10/18 | 2,551 / **10,495** |
| (I) sealed occurrence sharing | 4/0 | 0.9900/84.3 | pass, invalid 11/11/10/18 | **46,341 / 15,743** |
| (E) the Str split | 131/88 | 0.9800/80.1 | — | — |
| (G1) the `last` key | 32/0 | 0.9896/83.9 | — | — |
| (G2) the `owed` key | 220/220 | 0.9870/81.6 | — | — |

cdx11l itself: 2,380 / 3,519 ms. A, F, H and J are removable at no measured
cost. B, E, G1 and G2 change judgments (B breaks D8's `,3true` case). D and I
remove one invalid tree per seed but are what keeps long inputs fast: without
sealed sharing 8000/4/7 takes 19x longer and 4.4 GB. cdx11n (all of A, D, F,
H, I, J removed, 780 LOC) confirmed this: 8000/4/7 32.6 s, 1000/128/1 40.9 s,
8000/32/7 47.3 s against 2.3/8.6/13.7 s.

**The engine (`cdx11o`, untracked `_cdx11o.dart`) is cdx11l minus A, F, H, J.**
Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, 1,685 ms,
treeDiff 1, costDiff 0 against cdx11l; accept t/t/t, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0,
window P at every n, pred 0 false assertions; fuzzer invalid 12/11/11/19,
worse 0 on every seed (same as cdx11l). LOC 839 → 804 raw, 803 normalized
(−35, −4.2%). Rungs (ms): 1000/1/1 309; 8/1 574; 16/1 1,640; 32/1 3,531;
64/1 3,655; 128/1 8,471; 4000/4/2 1,169; 8000/4/7 2,339; 8000/32/7 11,807.
Every rung finishes, at cdx11l's times.

**Refuted: cdx11m, "an unconditional clean reading is the plain one".**
Dropping every clean way whose end differs from the plain parse's end raises
173 costs. Clean left-recursive growth stages are prefixes that later repairs
build on, and they carry no cut guard. Gemini's round-3 `_view` patch is the
same rule (it reports seed-1 invalid 12 → 6 but did not measure costs).
Codex's round-3 variant demotes such readings instead of deleting them and
leaves the battery unchanged; it is under test.

### cdx11r — Codex's three validity rules on cdx11o: invalid trees 12/11/11/19 → 6/7/6/17 at the same speed (2026-09-23)

**Codex round 3 (`total_stage`, re-measured here as `cx3ts`)** adds three rules to cdx11l:

1. **Outside a finished left-recursive cell, a clean reading is the plain one
   or is demoted** (`_outer`). A clean way whose end differs from the PEG
   answer's end is kept but demoted, and the plain answer is always offered.
   Deleting such ways instead (cdx11m) raised 173 costs, because later repairs
   build on them.
2. **A Ref admits a reading that matched input**, `end - pos > deleted`,
   instead of one with literal evidence.
3. **First: `reach` includes the arm's plain end, and the choice stops after an
   arm that cannot fail** (`_total`: an Optional, a `*`, or a Seq of such; a
   left-recursive Ref is exempt, since it fails as a seed).

Measured (orchestrator's kit, confirmed): cx3ts battery 0.9900/84.3, treeDiff 1,
costDiff 0 against cdx11o; all checks pass; fuzzer invalid 6/7/6/17 against
cdx11o's 12/11/11/19; cdx11o pays more than cx3ts in 8/6/7/2 cases, cx3ts pays
more in 0/0/0/1. 875 LOC (it was built on cdx11l).

**cdx11r (untracked `_cdx11r.dart`) is cdx11o plus these three rules.** One
detail matters: the read of an ACTIVE cell (the recursive read during growth)
must stay `_view`, not `_outer`; growth needs every stage. With `_outer` there
too (cdx11p, cdx11q) the battery falls to 0.9881/83.3, 14 costs rise. With
the absorption charge (J) or `_oneShape` (H) put back, nothing changes, so
neither was the cause.

Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, treeDiff 0 and
costDiff 0 against cdx11o, treeDiff 1 against cx3ts; accept t/t/t, freespan
3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props
2728/0, window P at every n, pred 0; fuzzer identical to cx3ts on seeds 1–4
(invalid 6/7/6/17, worse 0). Rungs (ms): 1000/1/1 325; 8/1 667; 16/1 1,750–1,776;
32/1 3,543–3,551; 64/1 4,239; 128/1 10,529; 4000/4/2 1,213; 8000/4/7 2,494;
8000/32/7 13,065. The 16/1 and 32/1 rungs were re-run alternating with cdx11o
and cx3ts: all three within 5% (a first reading of 5.0 s was noise).
LOC 803 → 837 normalized (+34, +4.2%).

**Not a counterexample to sealed sharing:** `S <- ('a' ',')* 'b' 'a'` on `a`
costs 3 edits in every engine since c14, where inserting `b` at 0 costs 1.
Missing characters at end of input are one completion (`owed`), so both
readings have charge 1, and `_compare` prefers the later first edit. The same
holds for every EOF case tried.

### cdx11s — Codex's round-3 engine minus the four no-op parts: 837 → 802 LOC, 10% faster battery, one more valid repair (2026-09-23)

**Codex round 3 finished** (`cx3f`, 829 LOC, built on cdx11l). Beyond
`total_stage` it adds: First also consults the plain earlier-arm result (a
bound-pruned repair frontier does not show that an earlier PEG arm failed);
`_usedSeed` reads the relation cells' `recursive`/`usedSeed` flags instead of
a separate left-corner walk; a substitution carries its literal in `lead`, and
`_tail` checks whether the next edit completes a direct earlier Char/Str arm
of a frozen First; `_Way.change` replaces the copy constructors; the explicit
preferred-bit key in `_compare` is deleted (inert on battery and fuzzer).
Codex also refuted, by measurement: `Mismatch.len` as the examined span
(`'a' ('b' 'c')` on `abd`: len 1, the reviving edit is at 2; `&"ab"` on `ac`:
len 0, edit at 1); unordered choice (seed-1 invalid 6 → 18); one longest LR
extent per budget (0.9802, 213 trees differ); the regular bound alone
(1000/32/1 3.7 → 101 s); a productive-nullable rule (a new invalid on `aca`).

**cdx11s (untracked `_cdx11s.dart`) is cx3f minus the cdx11o deletions:** no
`incomplete` flag or fallback (F), no `_oneShape` in the Ref filter (H; the
function stays, a Seq slot still uses it), no absorption term in `charge`
and no `complete` flag in `_compare` (J).

Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, treeDiff 0 and
costDiff 0 against cdx11r; alternating runs 1,594/1,575 ms against cdx11r's
1,757/1,777 (−10%). Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16,
conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P at every n,
pred 0. Fuzzer seeds 1–4 invalid 6/7/6/17, the same as cdx11r; worse 0/0/1/0
against cdx11r's 0/0/0/1, and in both such cases both answers are invalid.
Rungs, paired and alternating (ms, cdx11s / cdx11r): 1000/1/1 327–329/321;
8/1 615–637/646; 16/1 1,798–1,864/1,859; 32/1 3,318–3,353/3,404; 64/1
3,708–3,721/3,844; 128/1 8,023–8,531/8,271; 4000/4/2 1,194–1,275/1,224;
8000/4/7 2,341–2,346/2,388; 8000/32/7 13,520–13,853/13,786. Codex's probes:
`S <- A 'b'; A <- "ab" / 'a'` on `ac` costs 2 (valid, `abb`, the only word;
cdx11r gives an invalid cost-1 tree); `R <- 'c'*+ 'b'` on `ccca` costs 1
(cdx11l 4); `S <- 'b'` on `a` still costs 2 (substitution exists only inside
a Seq slot). LOC 837 → 802 normalized (−35, −4.2%).

**Substitution at every Char/Str terminal is a trade-off, not a win
(scratch `subT`, `subT2`, 2026-09-23).** `subT` lets a failed Char/Str
terminal replace the next input character (`_Way.skip(pos, pos + 1, text)`)
beside its insertion; `subT2` also deletes the Seq-slot substitution block and
`_resumes`, which the terminal rule subsumes. Measured for `subT2` against
cdx11s: LOC 802 → 793 normalized (−9, −1.1%); all checks pass (accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0,
window P, pred 0); `S <- 'b'` on `a` costs 1 instead of 2; fuzzer seeds 1–4
worse 0/0/0/0 against cdx11s's 7/5/9/6 (cdx11s pays a higher cost on 27
cases), invalid 6/7/4/17 against 6/7/6/17. Against that: battery 0.9900/84.2
(two equal-cost cases lost, 618 `{"z":}3}` and 636 `[4,5,]6`: subT2 opens an
empty nested array and replaces the digit instead of moving the bracket), and
many-error rungs 16–21% slower, two paired runs each (1000/32/1 3,953–3,993
vs 3,360–3,431 ms; 1000/128/1 9,522–9,927 vs 8,071–8,224; 8000/32/7
14,742–15,086 vs 12,243–12,529); battery time is the same. Three tie-breaks
meant to recover 618 and 636 were refuted: forbidding substitution of a
character that a non-inverted CharSet reads (0.9897/84.0, 20 costs worse; the
battery contains a mistyped bracket that is a digit, `{"k":5{"a":1}...`);
counting only CharSet characters as evidence (0.9853/80.7, also 0.9855 on
cdx11s itself); a substitution as evidence −1 (0.9898/84.0, loses `[1\2]` →
`[1,2]` to deleting the `\`, and twice as slow). cdx11s stays the engine.

### cl8 — cdx11s with eleven rules deleted and the ordering penalty turned into a tie-break: 802 → 712 LOC, the same speed, fewer invalid trees (2026-09-23)

**What was deleted (each confirmed by battery, gates and fuzzer; untracked
`_cl8.dart`).** Every change below keeps the battery at 0.9900/84.3 and all
gates passing; together they change 6 battery trees at equal score.
- `_view`: the per-budget view cache, and the rule that dropped an edited
  reading ending where PEG's plain reading ends. The view is now: level the
  cell's readings, keep those within budget, and read a preferred reading
  that ends where PEG ends as PEG's own reading.
- Ref: the support filter (`r.end - pos > r.deleted || r.clean || ...`).
- Seq: the per-slot leveling of the incoming front; the `r.spent > _budget`
  skip; the condition that resumption and substitution are tried only when no
  clean option advances; `_resumes` (a substitution no longer has to be
  followed by a clean read of the next slots).
- First: demoting a later arm's readings.
- Repetition: the filter on a step that is a pure deletion with no evidence;
  the rule that kept an earlier stop when the bound proved the rest of the
  document cheaper from there.
- `_Bound`: the transition that skips a whole Str for one deletion.

**The ordering penalty is a tie-break, not a cost.** cdx11s added one to a
reading's `charge` (cost + fee) for an insertion a deletion could have
avoided, and used `charge` both to rank readings and against the budget.
Ranking by cost first and by that count second (`avoidable`), and checking
only cost against the budget, changes no tree, cost, gate or fuzzer answer
(h1 against the fee version). `charge` is gone; `_compare` is cost,
avoidable, evidence, first, last, owed. Of the penalty's conditions, `!o.clean`
is implied by `ahead <= o.missing` with `ahead > 0` (deleted, no change);
every other condition changes results when dropped: the last-slot exemption
0.9898/84.1, the one-shape exemption 0.9899/83.9, the one-shape and seed
exemptions together 0.9882/83.7, `ahead <= o.missing` 0.9896/84.1,
`o.end == r.end` 0.9732/80.5 with 35 costs changed.

**The penalty cannot be deleted, and D7 alone cannot replace it.** Without it
(cl6, 679 LOC) the battery rises to 0.9902/84.8 but gate b2 fails:
`[,2,33,true]` gets an invented digit instead of losing the comma. The battery
contains the same shape both ways (`[,33,true]` from a deleted `2` scores
insertion; `[2,,33,true]` from an added comma scores deletion), so no local
rule can win both; cl6 wins more of them, and b2 is D7. Three D7 rules on
cl6, all refuted: never insert a CharSet/AnyChar (0.9704/76.8, fails cx2;
the same ban away from end of input 0.9733/78.2, fails cx2); an invented
open-class character as evidence −1 (0.9900/84.1, still fails b2, because
the comma it keeps is evidence +1); a count of invented open-class
characters ranked after cost, before evidence (passes b2, 0.9803/81.1: the
expression corpus wants `a+*2` → `a+b*2`, which is also an invention) or
after evidence (0.9901/84.1, fails b2).

**A guard that changes no tree can still be the speed.** Always resuming in
`_repeat` (deleting the `steps.any(clean && advances)` guard) keeps every tree
and costs 4x on 1000/128/1 (7.7 → 32.6 s) and 2x on 8000/32/7 (10.9 → 23.6 s).
It stays.

**Measured (confirmed).** LOC 802 → 712 normalized (−90, −11.2%). Battery
0.9900/84.3, 1,580–1,644 ms (cdx11s 1,485–1,541 in the same runs, 3–7%
slower); treeDiff 6, costDiff 0. Accept t/t/t, freespan 3 3 4 4 1, recommit
16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P,
pred 0. Fuzzer seeds 1–4 against cdx11s: invalid 6/6/6/12 against 6/7/6/17;
worse 1/0/1/0 against 6/4/5/9. Rungs, alternating (ms, cdx11s / cl8):
1000/1/1 309/299; 1000/32/1 3,356/3,304; 1000/128/1 8,299/7,920; 8000/4/7
2,548/2,304; 8000/32/7 11,934/11,454; every cost equal.

The rest is restructuring: `_first`, `_optional`, `_after` (read after a
reading with its unspent budget), `_level`, `_body`, `_text`, a `_Guard`
typedef, `departed` for `first == _clean`, and switches in `_propose` and
the bound's automaton builder.

### cl10 — cross-review round 5 on cl8: two crashes and a cost-model flaw fixed, the fuzzer repaired, 712 → 700 LOC (2026-09-23)

*Superseded 2026-09-23 by cl11 below: cl10 does not finish 512+ errors on `('a' 'b')+` and overflows the stack on a left-recursive list of 8,192 terms.*

**Setup.** Codex (gpt-6-astra, max effort) and Gemini (gemini-3.1-pro-high)
each got BRIEF5: an elegance assessment of cl8 in the same format as mine
(scores by part, inelegances with line numbers, a ranked fix table), and then
a cleaner engine built and measured with the kit. My own assessment was
written first and given to both as the peer report. All three assessments
agree on the main points: the cells and their fixed-point growth are the
elegant part (9/10 from all three); `_Bound`, `_repeat`, `_seq` and the guards
score 3-4; `_budget` and `_seedRead` are mutable fields saved and restored
around calls; `piece` is typed `Object?`; the ranked cost and the reported
cost differ; several comments are stale. The engine below is untracked
`_cl10.dart`.

**Two crashes found by Codex (both reproduced in my kit).**
- A cycle of references (`S <- R0; R0 <- A / 'a'; A <- B; B <- A;` on `b`)
  overflows the stack: `_read` follows a Ref to its body without a cell, and
  `A <- B; B <- A` never reaches a cell. Fix: a Ref whose body is itself a Ref
  goes through a cell like any other clause (`c is peg.Ref && _body(c) is!
  peg.Ref && ...` in `_read`, and `peg.Ref() => _read(_body(c), ...)` in
  `_propose`). Battery and gates exact.
- The bound was not admissible: `_seq` let one input character be replaced
  by a whole multi-letter literal at cost 1, which the bound (one per letter)
  did not allow. See the cost-model flaw below; the fix is in the cost model,
  not in the bound. Codex's own fix weakened the bound instead (r5safe).
- The bound's automaton had no case for `peg.Nothing` (`()`); it now joins
  FollowedBy and NotFollowedBy as a free edge.

**The fuzzer never tested a literal longer than one letter.** `_same.dart`
writes two-letter literals as `'ab'`, which the metagrammar rejects (single
quotes are one character; `"ab"` is the multi-letter form), and the harness
skips any grammar that fails to parse (`catch (_) { continue; }`). That is why
each seed completed only 312-370 of its 400 cases. `_samedq.dart` writes them
as `"ab"` and completes all 400. It also adds a measure that does not depend
on the engine's cost model: for each valid tree, the Levenshtein distance from
the input to the repaired string (`levSum`, valid trees only), and the number
of cases where an engine's repaired string is farther from the input than the
best engine's (`levWorse`).

**The cost model charged one edit for a whole literal.** In a sequence slot,
cl8 could replace one input character by a whole literal at cost 1, while an
insertion of the same literal costs one per letter. With `S <- "abc" "def"`:
`def` costs 2 (the correct `d` is replaced by `abc`, then `d` is inserted
again), `xdef` costs 1, `xydef` costs 2. Substitution is now allowed only for
a one-letter literal (`text?.length == 1`; a first attempt tested `slot is
peg.Char`, which wrongly excludes a one-letter Str). On the battery this
changes 12 trees at equal cost and score, all the `i (x)` / `if` shape: cl8
replaced the space after `i` by `f`, cl10 inserts `f` and keeps the space as
whitespace. On the corrected fuzzer (seeds 1-4, 400 cases each, against cl8):
invalid 11/9/11/9 against 14/10/13/9;
levWorse 0/1/0/0 against 3/1/2/0; levSum 528/547/531/502 against
521/543/523/502 (higher because more trees are valid and counted).

**Refactors (each exact on battery, gates and fuzzer).**
- The budget is a parameter of `_read`, `_propose` and the construct methods
  (Codex e1, Gemini e1, my fix 3); `_after` and the save/restore are gone.
- `_seedRead` (a flag saved and restored) is a counter `_seedReads`; a cell
  used a seed if the counter moved while it grew.
- `_resume` checks `spent` against the budget, like every other test (Gemini
  e4); before it used `cost`, which differs only when characters are owed at
  the end of input.
- Deleted: the leveling of `_seq`'s result, and the growth filter that dropped
  an edited reading ending where the plain reading ends (both exact; the
  ending-where-PEG-ends rule in `_view` already covers the second).
- `_spell` splits a Str into Chars once, for both the bound and `_read`.
- The bound's edges are `(from, characters, call site)` records, not integers
  encoding push and pop as -2k and -2k-1.
- `_scan` names the "a starred terminal earns no evidence" rule used in both
  `_ev` and `_repeat`.
- `_versions` is a list, not a map.
- `piece` is a `_Piece` closure that builds its node only when the path is
  selected (from Codex); `_tree` is gone and `_branch` builds a labeled node.
- `first`'s sentinels are documented (`_clean == _never`, `_preferred` ranks
  above it) and the stale comments (fibers, "bill", the one-edit-at-a-time
  ladder that in fact jumps to the bound's floor, the missing tie-breaks in
  the header) are fixed.

**Negative results.**
- One budget quantity everywhere (`cost` instead of `spent`; Codex r5unify,
  Gemini e3, my xcost): 0.9834/81.6, 76 costs change, all lower. The two
  quantities are needed: `cost` counts owed end-of-input characters as one
  completion, and using it inside the search prunes readings that finish
  later.
- A deterministic schedule for strengthening the bound instead of the
  Stopwatch (Codex r5early, Gemini e2): trees exact, 8000/4/7 at 8.4-8.9 s
  against 2.2 s. The Stopwatch affects speed only (xrem, xnor: exact).
- Every reference through a cell (x7b, −3 LOC): 1,879 battery trees change,
  because an empty `WS` is labeled `WS` instead of the parser's convention of
  no label.
- Deleting the `_tail` First branch (y11): exact on battery, gates and old
  fuzzer, but on `S <- R0; R0 <- ("ab" / "a") "b"` it returns invalid trees
  that are too cheap (`ac` cost 1 where the valid answer is 2). Kept.
- Dropping the root special case in `recover`: treeDiff 2,099.
- `_usedSeed` from the cell alone (x1): fuzzer worse.
- Deletion sweep y1-y16 over cl8's remaining rules: only two were exact, and
  one of those (y11) is refuted above.
- Gemini's sealed-class `piece` (e1, 722 LOC): exact but larger than the
  closure; Codex's nullable `first` with a `chosen` flag: exact, but adds `!`
  operators, a helper and a compare line. Not taken.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| Reference cycle overflows the stack | Codex | `_tree.dart` on the grammar above: stack overflow in cl8, cost 2 in cl10 | confirmed, fixed |
| Bound inadmissible for whole-literal substitution | Codex | `"abc" "def"`: cl8 `def` 2, `xdef` 1; cl10 3, 3 | confirmed; fixed in the cost model |
| `Nothing` missing from the bound | Codex | source | confirmed, fixed |
| Budget as a parameter is exact | Codex, Gemini | check8: treeDiff 0 | confirmed |
| `spent` in `_resume` is exact | Gemini | check8: treeDiff 0 | confirmed |
| One budget quantity loses score | Codex, Gemini, Claude | 0.9834/81.6 | confirmed |
| Deterministic bound schedule is slow | Codex, Gemini | rungs 8000/4/7 | confirmed |
| Stopwatch makes results nondeterministic | Gemini | xrem, xnor: trees exact under two other schedules | not observed; speed only |
| Policy layer exists because D1 forbids the exact check | Claude | | Codex: overstated, D1 bans only a second parse; agreed |
| Fuzzer never tests multi-letter literals | Claude | `_samedq.dart`: 400/400 cases | confirmed |
| Whole-literal substitution for one character | Claude | probe | confirmed, fixed |

**Measured (confirmed).** LOC 712 → 700 normalized (−12, −1.7%). Battery
0.9900/84.3, 1,561 ms; treeDiff 12, costDiff 0, auditBad 0. Accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0,
props 2728/0, window P, pred 0. Old fuzzer invalid 6/6/6/11 (cl8 6/6/6/12).
Rungs, alternating (ms, cl8 / cl10): 1000/1/1 295/294;
1000/32/1 3,152/3,209; 1000/128/1 7,683/7,848; 8000/4/7 2,208/2,230; 8000/32/7
10,544/11,002 (+4%); every cost equal. Battery in the same run 1,515/1,510 ms.

**Open.**
- On `S <- R0; R0 <- ("ab" / "a") "b"` (language {abb}), cl8 and cl10 return
  an invalid cost-1 tree for `a`; the true cost is 2.
- `R0 <- (('c' 'c' R0)? (('a' / R2) / 'b'+) "ab"); R1 <- (R2 / 'a'+); R2 <-
  (R0 / R1);` on `ccbbbabcab`: cl10 returns cost 4 where cl8 returned cost 2
  (3 character edits) and the Levenshtein distance is 1. A search limit, not a
  cost-model one.
- Substitution is tried only in a sequence slot after a preferred reading;
  substitution at every terminal was refuted in 7f012d3.

### cl11 — Codex's final round-5 report on cl8: two inputs cl10 could not finish, 700 → 696 LOC (2026-09-23)

Codex's round-5 run ended (rc=1) after cl10 was committed; its report
(R5_CODEX.md, 229 lines, still marked "in progress" at the top, the run cut
off by a content filter) contains two failures that cl10 still had. Both were
reproduced in my kit with Codex's `_r5_stress.dart` (copied as `_stress.dart`,
60 s limit per input). The engine below is untracked `_cl11.dart`.

**cl10 did not finish two inputs (superseded claim: the cl10 section above
called the round complete).**
- `S <- ('a' 'b')+` on n copies of `ac`: cl8 and cl10 finish 256 errors in
  46 ms but pass 60 s at 512, 1,024 and 4,096. The bound's distances were a
  `Uint8List` saturating at 255, and a saturated value is read as 0
  (unknown), so past 255 errors the bound prunes nothing. cl11 stores exact
  distances in an `Int32List`: 512 errors in 67 ms, 4,096 in 1.2 s.
- `S <- E; E <- E '+' N / N; N <- [0-9]+;` with 8,192 terms and one `?`:
  cl8, cl10 and the exact-distance intermediate all overflow the stack in the
  recursive tree builder (`_branch` closures calling each other, one frame
  per left-recursive level). cl11 builds the selected tree in postorder with
  an explicit stack: each `_Node` is a ready match or a label over a path, and
  keeps its built match, so a node shared by two paths is built once. 8,192
  terms finish, cost 1.

**Deletions.**
- `_minChars` (a fifth grammar walk) is gone. The ladder's ceiling is
  `_len + terms.length`, the terminal count of the bound's automaton (Codex
  r5count). Sound because the automaton shares a clause only when it repeats
  on the current call path (`onPath`), and a shortest derivation repeats no
  clause on a branch, so its characters map one-to-one onto terminals. Probe:
  `S <- E E E E; E <- '(' E ')' / "abcdefgh"` on `x` (four uses of a shared
  recursive rule) returns cost 32, and `S <- A; A <- A 'x'` (no finite
  derivation) still returns the whole-input error.
- The loop that added 2 to each terminal's out-degree in `_Bound` (Codex
  finding 17). The terminal's insertion edge is already in `back` with one
  character, so its state never has a single free exit; the loop changed no
  decision.
- `Squirrel.lastCost` forwards to the last `Recovery` instead of copying it.

**Measured (confirmed).** LOC 700 → 696 normalized (−4, −0.6%); the iterative
tree costs +21 and the three deletions save 25. Battery 0.9900/84.3, 1,461-1,523 ms (cl8 1,488 ms in the same run);
treeDiff 12 against cl8, treeDiff 0 against cl10; costDiff 0, auditBad 0. Accept
t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred 0. Corrected fuzzer against cl8:
invalid 11/9/11/9 (cl8 14/10/13/9), levWorse 0/1/0/0, the same as cl10. Rungs, alternating (ms, cl8 / cl11): 1000/1/1 290/294; 1000/32/1 3,166/3,270; 1000/128/1 7,584/7,836; 8000/4/7 2,216/2,252; 8000/32/7 10,687/10,674; every cost equal. Stress (ms,
cl8 / cl11): errors 256 44/40; 512, 1,024, 4,096 timeout/63, 140, 1,074; LR 2,048 terms 2,096/2,183; LR 8,192 stack overflow/44,373.

**Negative results and open items.**
- **Left recursion with an error is quadratic** (closed by cl12 on
  2026-09-24: semi-naive growth, see the cl12 section). `E <- E '+' N / N` with one
  error: 1,024 / 2,048 / 4,096 terms take 0.6 / 2.4 / 10.6 s (error in the
  middle); 1.1 / 4.7 s for 1,024 / 2,048 with the error near the start. The
  clean parse takes 7-15 ms. Instrumented at 512 terms: the cell of E at 0
  grows 512 times and its growth re-proposes the whole relation each time
  (131,073 readings, about n^2/2). A semi-naive growth (re-derive only from
  readings added in the last iteration) is not exact as the engine stands:
  `_level` demotes the previous farthest preferred reading in every
  iteration, and `_first`'s `reach` is taken from the whole first-arm
  relation, so old seeds do not produce the same proposals twice. 8,192 terms
  take 44 s; 32k terms would take minutes. Open.
- **Optional-ab (Codex finding 26, confirmed).** `S <- A "ab"; A <- "ab"?` on
  `x`: cl8 returns an empty `A` then a whole-literal substitution (cost 1);
  cl10 and cl11 return an empty `A` then `a` substituted and `b` inserted
  (cost 2). No PEG reading has that shape: the only word is `abab`, cost 4.
  `_starts` tests whether the body matches exactly the one lead character,
  and `"ab"` cannot match `a`. Codex's r5guard (`m.len > 0`) does not fix it.
  A correct test needs the repaired text after the stop; open.
- **The comparator is not monotone under prefix composition (Codex finding
  10, confirmed from the source).** `_compare` prefers a later first edit and
  then an earlier last edit. If a prefers over b on `first` but has a later
  `last`, a prefix with an earlier edit makes `first` equal and reverses the
  order. One champion per end is therefore a policy, not a theorem. Open.
- Codex's final candidate (cdx5c, 711 LOC) keeps cl8's whole-literal
  substitution and makes the bound admissible for it with a substitution
  edge; cl10 removed the substitution instead (see the cl10 section). Not
  taken.
- Codex's nullable `first` with a `chosen` flag and its `_EdgeKind` enum:
  larger than cl10's forms, not taken (as in round 5).

**Claims table (Codex's final report).**

| Claim | My check | Verdict |
|---|---|---|
| Byte saturation: 512+ errors do not finish | `_stress.dart errors 512/1024/4096`: cl8, cl10 time out at 60 s | confirmed, fixed |
| Deep LR tree overflows the stack | `_stress.dart lr 8192`: StackOverflow in cl8, cl10, x11 | confirmed, fixed |
| Terminal count is a sound ceiling | argument from `onPath`; shared-recursion probe cost 32 | confirmed, adopted |
| Out-degree counts 2 per terminal, no decision changes | source; trees identical | confirmed, loop deleted |
| `lastCost` duplicated state | source | confirmed, getter |
| Optional-ab invalid tree | `_tree.dart`: cl8 cost 1, cl11 cost 2, both invalid | confirmed, open |
| Comparator not monotone under a prefix | source (keys `first` then `last`) | confirmed, open |
| Peer's `_Way` has 14 fields (it has 13) | source | Codex correct |
| "D1 forbids the exact check" is wrong | D1 bans a second parse only | agreed (as in cl10) |
| LR 8192 "completes" in cdx5c (50 s) | 44 s in cl11; quadratic, see above | confirmed, but not linear |

### cl12 — cross-review round 6 on cl11: left recursion with an error becomes linear, fewer invalid trees, 696 → 702 LOC (2026-09-24)

Round 6 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and
a Claude subagent (Opus 5.5) on BRIEF6 (Q1 linear left recursion, Q2 invalid
trees, Q3 comparator monotonicity, Q4 size, Q5 peer review). Codex finished
(rc=0, 651-line report). Gemini wrote its report and then hung waiting on a
background task; I stopped it. The Claude seat finished. The engine below is
untracked `_cl12.dart` (my kit's x47).

**What cl12 changes (confirmed from the diff against cl11).**
- **Semi-naive growth** (the Claude seat's engine, then adapted). Each strict
  improvement of a cell is logged as `(tick, end)`; `cell.start` is the tick
  at which the current growth pass began. A seed read of a cell that is being
  grown returns only the ends improved since that tick, plus the farthest
  preferred end and the start position, taken from a fresh set and sorted by
  end. Every clause grows this way; the Repetition exception the seat kept is
  not needed (x39: 7 equal-cost fuzzer trees change, invalid counts equal).
- **`r.first >= reach` in `_first`** (Gemini; cl11 had `>`): a later arm
  whose first edit is at or after the earlier arm's reach is skipped, since
  that edit could revive the earlier arm.
- **A last tie-break on substitutions**: between ways with equal `missing`,
  the way with more substitutions ranks higher. It restores the `1?1+1`
  battery tree that the semi-naive growth changed.
- Codex's two `_Bound` compactions (the slot map via `columns.putIfAbsent`;
  the push/pop edge loop in one statement).
- Comment fixes from the elegance review: the header now names every ranking
  key and the semi-naive growth; `start` is documented; the whole-input
  fallback says when it happens.

**Measured (confirmed), my kit, cl11 = x15.** LOC 696 → 702 normalized (+6,
+0.9%). Battery, alternated twice: cl11 0.9900/84.3 at 1,391 and 1,398 ms;
cl12 0.9899/84.3 at 1,515 and 1,525 ms (9% slower), treeDiff 8, costDiff 0,
auditBad 0.
Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P (n=4096 cost 1), pred falseAssertions 0.
Corrected fuzzer (`_samedq.dart`, seeds 1-4, 400 cases each): invalid 8/8/9/6
(cl11 11/9/11/9), worse 0/0/0/0 (cl11 3/1/2/3), levWorse 0/0/0/0 (cl11
3/1/2/3), levSum 534/549/535/507 (cl11 528/547/531/502). Old fuzzer
(`_same.dart`): invalid 4/5/4/9 (cl11 6/6/6/11), worse 0 on every seed.
Left recursion with one error (`_lrprof.dart`, error at 50%): 8,192 terms
316 ms (cl11 44,373 ms), 32,768 terms 868 ms. Stress (ms): errors 256 45,
512 72, 1,024 130, 4,096 1,126; LR 2,048 167; LR 8,192 338 (cl11: 63, 140,
1,074; 2,183; 44,373).
Rungs, alternating (ms, cl11 / cl12, every cost equal): 1000/1/1 294/300;
1000/32/1 3,290/3,271; 1000/128/1 7,883/8,095; 8000/4/7 2,243/2,271; 8000/32/7
10,772-10,916/10,927-11,290 (four runs each on an idle machine; a first run at
12,310 ms overlapped another job). Across three battery runs today cl12 is 3-9%
slower than cl11 (1,503-1,591 ms against 1,551-1,599 ms in the later two).

The levSum rise (+2 to +6 per seed) comes with fewer invalid trees: the
repairs cl11 returned in those cases were cheaper because they were invalid.

**Why the growth is linear (inferred from the profile, confirmed by timing).**
At 512 terms cl11 re-proposes 131,073 readings (about n^2/2) because each
growth iteration of `E` at 0 rereads the whole relation. cl12 rereads only the
ends improved in the last pass. The fresh view must be sorted by end: the
unsorted set was quadratic again (x34), and sorting restored 857 ms at 32,768
terms (x35).

**Candidates (all measured against cl11 in my kit unless noted).**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| x47 = cl12 | x39 + comment fixes | as above | 9 | linear LR, fewer invalid trees, one equal-cost battery tie lost |
| x39 | x35 with no Repetition exception in growth | = x47 in behavior, 702 LOC | 9 | simpler; 7 equal-cost fuzzer trees change |
| x35 | x34 + fresh view sorted by end | 32,768 terms 857 ms | 8 | superseded by x39 |
| x34 | x33 without the whole-literal lead | quadratic again (unsorted view) | 5 | Codex's prefix counterexample forced the revert |
| x33 | x32 + Codex's `_Bound` compactions + `(tick,end)` log | intermediate step, no separate result recorded | - | carried the refuted whole-literal lead |
| x32 | subs tie-break only when `missing` is equal | fixes `1?1+1`; optional-ab cost 1 with one error node | 6 | the cost-1 tree cannot be valid; traced to the whole-literal lead |
| x31 | `subs` as the last key always | fixes `1?1+1`, 85 tree changes | 3 | too many witness changes |
| x30 | lead-null tie key | 15 battery diffs, 0.9898 | 2 | loses score |
| x29 | x28 + a substitution counts as evidence | loses battery ties | 2 | rejected |
| x28 | the seat's linear engine + `>=` reach | 727 LOC, 0.9899, treeDiff 3; LR 8,192 344 ms, 32,768 918 ms; dq invalid 7/8/9/5 | 7 | best validity, but 25 LOC larger and 3 ties lost |
| x27 | x23a + the seat's Q2 changes | 701 LOC, treeDiff 0, dq 7/8/9/5 | 7 | whole-literal lead later refuted |
| x26 | tie forwarding on the linear engine | restores `1?1+1`; 1,024 terms 529 ms, 4,096 7,335 ms | 2 | quadratic |
| x24, x25 | Gemini's changes on the seat's engines | x24 732 LOC, treeDiff 3, dq 7/8/9/5 | 5 | larger, same validity as x28 |
| x23a | cl11 + `r.first >= reach` only | 696 LOC, treeDiff 0, dq 8/8/9/6, worse 1/0/0/1 | 7 | the useful half of Gemini's work |
| x23b | cl11 + `_text` of a Seq only | no change (11/9/11/9) | 1 | inert |
| x23 | both Gemini changes | 701 LOC, treeDiff 0, dq 8/8/9/6 | 6 | x23b adds lines for nothing |
| x22 | my delta growth (only the previous step's ends) | treeDiff 2, still quadratic (2-3x faster) | 3 | cells between the seed and the growing cell still reread everything |
| x21 | lead = the literal's remaining text | treeDiff 0, dq 10/9/12/8 | 3 | mixed; optional-ab falls to the whole-input error |
| x20 | `_least` returns the unreachable distance | no change | 1 | inert |
| x45 | front split: zero-width insertions keep their own champion | battery treeDiff 0 vs x39; no-repair cases 10 → 5 | 3 | invalid cost-5 tree on `cab` (below) |
| x41, x42 | front split keyed on zero-width insertion (x42 also on the lead) | x42: invalid counts rise to 9/9/10/6 | 2 | worse validity |

**Negative results and open items.**
- **Exact tie witnesses cost quadratic time.** At 512 terms, 66,048 of 67,582
  proposals are equal-rank replacements (67,328 logged). Forwarding them (x26)
  restores cl11's `1?1+1` tree but takes 7.3 s at 4,096 terms. cl12 keeps
  semi-naive growth and loses 3 equal-cost ties that the `subs` key does not
  recover; the battery score drops 0.9900 → 0.9899.
- **A whole-literal lead is refuted** (Codex): `S <- A "ab" 'c'; A <- (("abc" /
  'a') 'b')?;` on `xbc` costs 5 with it (the seat's vq6, x32) and 1 without.
- **Inputs with no repair (pre-existing, confirmed on cl11 and cl12).** On 10 of
  6,400 fuzzer cases (both fuzzers, seeds 1-8) the coherence rules reject every
  reading within the ceiling and `recover` returns one error over the whole
  input. In every case `_nearest.dart GRAMMAR INPUT 8` finds an accepted word at
  edit distance 1 or 2. Nine of the ten have a nullable repetition body or a
  repetition of a repetition, for example `R0 <- ("ba"? "cb" 'c'?+)` on `cb`.
  Causes (confirmed by tracing): (1) `_Front` keeps one champion per end, and a
  clean zero-width skip beats a zero-width insertion at the same end; (2)
  `_first` keeps one output per end, so a later arm's insertion that a guard
  would accept is dropped in favor of an earlier arm's insertion that the guard
  rejects; (3) "later first edit ranks higher" conflicts with `_tail`'s cut,
  which needs the first edit before the cut. The cl12 comment above
  `if (best == null)` now states the fallback. Open (BRIEF7 Q1).
- **The front split (x45) is rejected.** On `S <- R0; R0 <- ('c'** (R2 R0 'a')?
  'b'?+); R1 <- ('c'?? / (R0 / R0)+); R2 <- (R0 / (("cb" / 'a') R2* "cc"));`
  with input `cab` (dq seed 2), x39 returns the valid cost-1 tree
  `R0([c [<err1:a> b]])`, x45 an invalid cost-5 tree. The nearest word is `cb`.
- **Monotone comparators lose accuracy** (Codex, measured by Codex, not re-run):
  `(spent, owed, avoidable, -evidence)` 0.9685/81.1; dropping `last`
  0.9896/83.9; two later variants 0.9726. Codex's instrumented engine found 375
  local rank reversals in 71 battery cases, so one champion per end does lose
  rivals locally; no monotone order kept accuracy.
- Optional-ab (`S <- A "ab"; A <- "ab"?` on `x`): still cost 2, invalid in
  cl12. Codex's final engine (y6f) returns the valid cost-4 tree (`abab`,
  confirmed with `_tree.dart`) through a rule specific to an optional literal
  followed by a literal with the same text; y6f is 705 LOC with a
  pattern-restricted fast path. Open.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| Semi-naive growth makes LR with an error linear | Claude seat | `_lrprof.dart`: 8,192 316 ms, 32,768 868 ms (cl12) | confirmed, adopted |
| The linear engine loses only equal-cost ties | Claude seat | battery costDiff 0; treeDiff 3 on x28 | confirmed |
| Whole-literal lead fixes optional-ab safely | Claude seat | Codex's `xbc` counterexample: cost 5 vs 1 | wrong, reverted |
| Tie forwarding keeps exact trees but is quadratic | Claude seat (vs5) | x26: 529 ms at 1,024, 7,335 ms at 4,096 | confirmed |
| `r.first >= reach` removes invalid trees, treeDiff 0 | Gemini | x23a: dq 8/8/9/6, battery treeDiff 0 | confirmed, adopted |
| `_text` of a Seq closes `_tail` gaps | Gemini | x23b: no change on any count | wrong (inert) |
| Gemini's LR is O(n) (8,192 in 287 ms) | Gemini | its engine: 1,024 216 ms, 4,096 2,344 ms | wrong, quadratic |
| The `_wantsDelta` flag selects the delta path | Gemini | source: initialized `false`, never assigned, so the delta branch never runs | wrong (dead code) |
| Linear LR only for `E <- E sep N / N` | Codex | source: the fast path tests that shape | confirmed; not general, not adopted |
| Prefix counterexample to a whole-literal lead | Codex | `_tree.dart` on `xbc` | confirmed |
| Monotone orders lose accuracy | Codex | not re-run | Codex's measurement |
| 375 local rank reversals on the battery | Codex | not re-run | Codex's measurement |
| Final engine 705 LOC, invalid 11/9/11/8 | Codex | `check.sh` in my kit | confirmed; worse than cl12 |

**Process lessons.**
- `pkill -f PATTERN` and `pgrep -f PATTERN` match their own shell when the
  pattern appears in the calling command line: `pkill` kills its own shell
  (exit 144), and an `until ! pgrep -f ...` wait loop never ends. Kill by PID.
- Registering an engine edits the shared drivers `_research18.dart` and
  `_pred18.dart`. A registration that does not compile (x26) broke every run in
  progress. Register only when no run is going.
- A diagnostic engine that throws (x46, which throws "no repair" to count those
  cases) must be unregistered from `_pred18.dart`, or `bench.sh pred` crashes
  after the engines listed before it.

### cl13 — cross-review round 7 on cl12: every fuzzer input gets a repair, fewer invalid trees, 702 → 727 LOC (2026-09-24)

Round 7 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and
a Claude subagent (Opus 5.5, high effort) on BRIEF7 (Q1 inputs with no repair,
Q2 invalid trees, Q3 size and elegance, Q4 peer review). Codex finished (rc=0;
its report says "Final measurements Pending" but the body holds the measured
results). The Claude seat finished. Gemini stopped on its quota before writing
a report. The engine below is untracked `_cl13.dart` (my kit's k3k).

**What cl13 changes (confirmed from the diff against cl12).**
- **A diverse search, used only when the ordinary one fails** (Codex's r7retry,
  reorganized). `_Front` in diverse mode keys its readings by `distinction =
  (end, first, lead, guard stop, guard cut)` in place of `end`, and diverse
  cells live in their own map (`_cells[1]`). The ladder retries a budget in
  diverse mode when it found no reading and some reading was rejected (by the
  guards, `bad`, or by departing); `_Front.add` reports a rejection through
  `Recovery._rejected`. If the whole ladder still fails, `_ladder(top, true)`
  climbs it again with the diverse search at every budget. Semi-naive reads,
  the deletion-resumption check and the wrapper-following `_active` apply in one
  mode only (below).
- **Same-stop guard conjunction** (`_meet`, Codex's proof): when a guard is
  carried across a clean zero-width successor that has its own guard at the same
  stop, both must hold: the earlier cut and either opening test. cl12 dropped
  the successor's guard (`g = guard`). Codex's version kept the first cut only;
  cl13 takes the earlier cut, as the proof says.
- **Literal revival in `_first`** (Codex's `_finishes`, the same idea as the
  Claude seat's q7): a later arm is not skipped when an insertion finishes an
  earlier arm's literal.
- **Deletion-resumption check** (Codex's `_resume` guard, ordinary mode only): a
  clean resumption after a deletion may not start with a character that opens
  the stopped body.
- **A null terminal guard in `_plain`** (Codex).
- **Sealing** (cl12s): in `_seq`, when slot 0 is a Ref whose body is active at
  `pos` and a later plain run of the tail follows, the tail's plain run is taken
  as is. This makes the unclosed-parenthesis family linear (below).
- Removed after ablation: Codex's `_starts` literal fast path (ke), the
  multi-letter `broken` test in `then` (kf), and the optional single-character
  substitution (quadratic, below). The fallback became a function with a `wide`
  parameter in place of a `_wide` field and a recursive `recover()` call.

**Measured (confirmed), my kit, against cl12.** LOC 702 → 727 normalized (+25,
+3.6%). Battery 0.9899/84.3, treeDiff 0, costDiff 0, 1,629 ms (k3j 1,626,
k3i 1,699; cl12 about 1,520-1,556 ms in this kit).
Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0.
Corrected fuzzer (`_samedq.dart`, 400 cases): invalid seeds 1-4 8/6/8/4 (cl12
8/8/9/6), seeds 5-8 7/8/7/11 (cl12 9/10/9/13); worse 0 and levWorse 0 on all
eight seeds against cl12; levSum 533/553/536/512 (cl12 534/549/535/507). Old
fuzzer (`_same.dart`): invalid 3/2/4/6 (cl12 4/5/4/9), worse 0.
**No-repair cases (`norepair.sh`, both fuzzers, seeds 1-8): 0 (cl12 10).**
Left recursion with one error: 32,768 terms 809 ms. Unclosed parenthesis
(`E <- E '+' T / T; T <- '(' E ')' / [0-9]`, body `(1+1)+`, error `((1`):
1,024 198 ms, 4,096 306 ms (cl12 256 491-559 ms, 1,024 5.3-6.4 s, 2,048
21-26 s). Stress (ms, cl12 / cl13): errors 256 51/41, 512 76/76, 1,024
133/132, 4,096 1,246/1,036; LR 2,048 177/190, 8,192 333/365. Rungs (ms, cl12 /
cl13, every cost equal): 1000/1/1 328/345; 1000/32/1 3,450/3,928; 1000/128/1
8,681/9,388; 8000/4/7 2,337/2,288; 8000/32/7 11,176/11,755. k3f showed the
same gap on 1000/128/1 (8,736/9,659). The cause of the 5-14% gap on the
many-error rungs is not measured.

**Candidates (all in my kit, against cl12).**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| k3k = cl13 | k3j + `_meet` takes the earlier cut | as above | 9 | best validity, no-repair 0, linear families |
| k3j | k3i with the ladder a function and ka reverted | = k3h on every count, 722 LOC | 8 | seed-7 `acba` invalid |
| k3i | k3h + ka, ke, kf | 724 LOC; seed 7 `ccbcca` cost 3 (k3h 2) | 6 | ka is not harmless |
| k3h | k3f without the optional substitution | 731 LOC, invalid 8/6/8/4, 7/8/8/11; seed 6 one worse than k3f (levWorse 0) | 7 | linear |
| k3f | k3q + post-ladder diverse fallback | 739 LOC, same invalid counts as k3h, no-repair 0 | 4 | `S <- 'x' 'a'?+` on `b`×n quadratic: 265 ms at 512, 2,710 ms at 2,048 |
| k3q | per-rung diverse retry on any front rejection | no-repair 4 | 5 | front dominance still drops readings |
| k3r | per-rung retry only on a root rejection | no-repair 17 | 2 | rejections inside cells never reach the root |
| k3s | Codex's k1 + sealing + per-rung retry | 0.9900/84.5, treeDiff 3, no-repair 0; 1000/128/1 18.1 s, 8000/32/7 23.4 s (cl12 9.5 s, 13.2 s) | 3 | twice as slow on the rungs |
| k1 | Codex's r7finishsmall (post-ladder fallback only) | 706 LOC, 0.9899/84.3, treeDiff 0, no-repair 0 | 4 | the `a`×n family climbs the whole ladder first: quadratic |
| cl12s | cl12 + sealing | 721 LOC, trees = cl12, no-repair 10 | 5 | fixes only the parenthesis family |
| Claude q7 | early-first-edit slot in a second search | reported 717 LOC, no-repair 2 (not rerun) | 5 | superseded by the diverse retry |

**Ablations of k3h** (k3h: old fuzzer invalid 3/3/4/6, corrected 8/6/8/4, worse
0, no-repair 0).

| Ablation | Change | Result | Verdict |
|---|---|---|---|
| ka | `_active` follows wrappers in both modes | identical on seeds 1-4; seed 7 `R0 <- (R0?? ('c'+ / ("ac" R0)))` on `ccbcca` costs 3 (k3h 2) | kept diverse-only |
| kb | resume guard in both modes | worse cases, corrected 7/7/8/4 with levWorse 1, no-repair 2 | rejected |
| kc | no resume guard | old 3/3/4/8, corrected 8/6/9/5 | guard kept |
| kd | no `keepFirst` in `_first` | battery 0.9902/86.3 (perfect +2.0), treeDiff 299; worse 1 on several seeds, corrected 9/7/8/4 | open lead |
| ke | no `_starts` literal fast path | same counts, 2 fuzzer trees differ | deleted |
| kf | no `broken` text test in `then` | identical | deleted |
| kg | no terminal-null guard in `_plain` | corrected seed 2 invalid 7 | kept |
| kh | `g = guard` in place of `_meet` | old seed 4 invalid 7, corrected seed 2 7, worse 1 | `_meet` kept |

**Negative results and open items.**
- **The optional substitution is quadratic.** Codex's proposal in `_optional`
  (`if (text?.length == 1 && pos < _len && rs.single.end == pos)` substitute the
  option's literal for the next character, marked avoidable) repairs three
  seed-6 costs, but on `S <- 'x' 'a'?+` with input `b`×n it takes 265 ms at 512
  and 2,710 ms at 2,048 (cl12 about 45 and 65 ms), and on `R0 <- ("ab" "aa"*?
  'a'?+)` 9.7-10.7 s at 2,048 (cl12 363 ms). The per-rung retry is not the
  cause: an instrumented copy (k3fd) runs one ordinary rung. Removed; the cost is
  one worse seed-6 case.
- **`R0 <- ("ab" "aa"*? 'a'?+)` on `b`×n is quadratic in cl12 and cl13 alike**
  (cost n-1): cl12 188/420/1,500/5,821 ms and cl13 177/392/1,342/5,295 ms at
  1,024/2,048/4,096/8,192. The bound's floor stays far below the cost here, so
  the ladder climbs one rung per error. Open.
- **The plain parser overflows its stack** on deep right recursion or nesting at
  n ≈ 1,500-2,048, before recovery starts, in cl12 as well. Pre-existing.
- Seed 6 `S <- R0; R0 <- (("bc" / R0)* R2); R2 <- ("bb"+* 'b'?);` on
  `bbbbcbbbcb`: every engine returns an invalid tree (Codex traced cl12's cost-1
  change to the conjunction). Open.
- `keepFirst` (kd) is worth +2.0 perfect on the battery but costs fuzzer
  validity. Open.
- The diverse search keeps the front's full distinction, so front dominance is
  not solved in the ordinary search; it is avoided by the retry.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| A retry with a front keyed by the distinction repairs the no-repair cases | Codex | k1 `norepair.sh`: 0 | confirmed, adopted in reorganized form |
| The unrestricted wide front breaks `cab` (cost 1 valid → cost 5 invalid) | Codex, Claude | both reproduced it; it matches round 6's x45 | confirmed; diverse mode stays a retry |
| Same-stop guards must both hold: OR of openings, minimum of cuts | Codex | kh ablation; k3k (minimum cut) fixes seed-7 `acba` and old seed 2 | confirmed; the cut half was not in Codex's engine |
| The resume guard cuts invalid trees | Codex | kc +4 invalid; kb (both modes) no-repair 2 | confirmed, ordinary mode only |
| The optional substitution restores three seed-6 costs | Codex | k3f vs k3h: one fewer worse case | confirmed, but quadratic; rejected |
| The unmarked optional substitution breaks D8 on `[,2,]` (46 battery trees) | Codex | not rerun; the marked version has treeDiff 0 | Codex's measurement |
| cost = spent + bool(owed) is not additive | Codex | counterexample checked by hand | proved |
| Exact tie witnesses cannot be kept in linear time (round 6) | round-6 seats | Codex: only the tried forwarding is shown quadratic | the impossibility is unsupported; the measurement stands |
| `_active` must follow wrappers only in diverse mode | Codex | ka: identical on seeds 1-4, one worse case on seed 7 | confirmed (my first reading, "harmless", was wrong) |
| The `_starts` fast path and the `broken` text test are needed | Codex | ke, kf | unsupported; deleted |
| An early-first-edit slot gives no-repair 2 | Claude | not rerun | superseded |

**Process lessons.**
- `norepair.sh` pipes through `tee /dev/stderr`. With stderr redirected to the
  same log file, that truncates the log. Send its stderr to /dev/null.
- `norepair.sh` registers a copy that throws on no repair. Remove the `nr`
  entries from `_pred18.dart` afterward, or `bench.sh pred` crashes and the
  pred line is lost.
- An ablation that is identical on four fuzzer seeds can still differ on the
  next four (ka). Check seeds 5-8 before adopting a deletion.

### cl14 - cross-review round 8 on cl13: shared gap scans, a gallop-and-bisect ladder, a bound bought by counted work, 727 -> 803 LOC (2026-09-24)

Round 8 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and a
Claude subagent (Opus 5.5, high effort) on BRIEF8 (Q1 the `"ab" "aa"*? 'a'?+`
quadratic, Q2 invalid trees, Q3 size and elegance, Q4 peer review). Codex hit its
usage limit (rc=1, no Codex seat until Sep 29) and left a partial report whose
logs were still usable. Gemini and the Claude seat finished. Most of cl14 came
from the orchestrator's own candidates (r8gen through r8hJ), built on the seats'
diagnoses. The engine is untracked `_cl14.dart` (kit name r8hJ).

**What cl14 changes (confirmed from the diff against cl13).**
- **A shared gap scan** (`_next`, `_gaps`). `_resume` finds the next position
  where the input reads a clause through a per-clause skip array, so repeated
  scans over one unreadable run are shared. The scan stays bounded by the budget
  window (`r.end + budget - r.spent`). Codex and the Claude seat found that the
  `"ab" "aa"*? 'a'?+` quadratic was this scan (2n^2 steps in one rung), not the
  ladder, as BRIEF8 had guessed. Codex's r8next fixed terminals only; a First
  as the repetition body stayed quadratic until the scan was shared for every
  clause (r8gen).
- **`_plain` does one map lookup** with a failure sentinel, and no memo-version
  check (r8fin, r8e6). This pays for the next item.
- **`_sealed`**, one helper for the sealing rule of `_seq` and `_repeat`.
- **A position-ordered `_repeat` worklist** (a SplayTreeMap by end): each end is
  extended once (r8e7). The `"ab"*`, `('a' 'b')*`, `('a'? 'b')*`, `('a'* 'b')*`
  and `('a' / 'b')*` families become linear.
- **Covered repetitions** (`_covered`, r8h2): a clause each of whose occurrences
  starts an enclosing repetition's body, with only total slots after it, reads
  its later occurrences plainly; the enclosing repetition explores their repairs.
- **A semi-naive fix** (r8h4): a settled cell with `usedSeed` was viewed through
  `_since`, which gives Delta(A) x Delta(B) in place of Delta(A) x B + A x
  Delta(B), and `usedSeed` was set by any active read, including the cell's own
  left recursion. A cell now uses a seed only if it read a cell growing below it
  (`depth`, `_low`).
- **Success is monotone in the budget** (r8h5): the one-occurrence insertion for
  `+` was offered only if no occurrence was read anywhere, so a larger budget
  could lose it. It is now offered whenever the body can be inserted
  (`if (c.requireOne)`). `_mono.dart`: 0 of 13,241 generated cases non-monotone
  (r8h2 396, r8h4 13).
- **A gallop-and-bisect ladder over fresh cells** (`_ladder`, `_rung`; r8h6, r8h7):
  gallop up from the bound's floor until a budget succeeds, probe the found
  reading's cost next, then bisect. Each probe starts from empty cells. This
  relies on monotone success.
- **The diverse search runs only below the ordinary least budget**, and only if
  the ordinary search rejected a reading at its greatest failing budget (r8h9).
- **The bound is bought by counted work, not by a Stopwatch** (r8hG, r8hH). cl13's
  rule made the answer depend on machine speed (below). The ladder starts with
  the regular bound. It buys the return-site bound after `width * calls * (n+1)`
  front offers, the number of entries the purchase adds, or at the first offer
  after a failed probe. A purchase throws `_Spent` and restarts the gallop from
  the new floor.
- **Elegance review of r8hH (r8hJ)**: one identity map `_relations` in place of
  two maps and a getter; the per-rung reset moved into `_rung`; `recover()` and
  the `_Spent` handler shortened; a comment that sat above `_Spent` moved to
  `class Recovery`; the header comment rewritten to describe the ladder and the
  semi-naive regrowth. Buying the bound at once on failure was tried and
  reverted: it builds the bound even when the ladder then exits.

**Measured (confirmed), kit v3, against cl13.** LOC 727 -> 803 normalized (+76,
+10.5%; raw 800). Battery 0.9900/84.4 (cl13 0.9899/84.3), treeDiff 30, costDiff
0, 2,164 ms (cl13 about 1,550-1,630 ms in this kit). Accept t/t/t, freespan 3 3
4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0,
window P, pred falseAssertions 0. Corrected fuzzer (`_samedq.dart`, 400 cases),
invalid seeds 1-8: 8/6/8/4/7/7/8/10 (cl13 8/6/8/4/7/8/7/11); cl13 has one worse
case on seeds 5, 6 and 8 each, cl14 one on seed 7 (`acaca`, the bound-dependent
case below). levSum 533/553/536/512/538/529/533/527 (cl13 533/553/536/512/538/
527/535/524). Old fuzzer (`_same.dart`): invalid 3/2/4/6, as cl13. **No-repair
(`norepair.sh`, both fuzzers, seeds 1-8): 0.** Rungs (ms, cl13 / cl14, every cost
equal): 1000/1/1 345/335; 1000/32/1 3,928/1,867; 1000/128/1 9,388/5,006; 8000/4/7
2,288/8,969; 8000/32/7 11,755/9,164. Stress (ms, cl13 / cl14): errors 256 41/33,
512 76/52, 1,024 132/90, 4,096 1,036/161; LR 2,048 190/164, 8,192 365/339.
Families (`sweep3.py`, 46 grammars, n = 1,024/4,096/16,384, 120 s each):
all 46 finish at every size, no timeouts
(`$SP/r8/sweep_r8hJ.txt`; r8e7 timed out on 26, 28-31, 35, 42 and 43). The
slowest: family 43 2,519/9,793/40,552 ms, family 42 409/831/3,243 ms, family 30
267/512/2,330 ms, family 26 238/466/2,275 ms. Family 43 grows about 4x per 4x
of n, so near n log n, but at 16,384 it takes 40 s.

**Candidates.** Each row is measured against the row it builds on unless it says
otherwise.

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r8hJ = cl14 | r8hH after the elegance review | trees = r8hH everywhere, 803 LOC | 9 | same results, 7 lines fewer |
| r8hH | r8hG with the allowance equal to the entries the purchase adds (`width * calls * (n+1)`), lazy purchase after a failure | as cl14, 810 LOC; rungs 1,879/5,060/9,076/9,328 | 8 | the last engine before cleanup |
| r8hG | charge per front offer; a failure under the regular bound buys the bound; a new floor restarts the gallop at step 1 | trees = r8hH; rungs 1,866/5,010/9,288/9,573 | 7 | first rule that wins 1000/32/1 and 1000/128/1 without the Stopwatch |
| r8hK | allowance equal to the regular bound's size, no purchase on failure | rungs 4,284/8,235/2,334/22,267 | 4 | wins 8000/4/7, loses the rest |
| r8hA | always buy the return-site bound | rungs 1,726/5,444/7,737/9,634; battery 3.2-3.3 s | 5 | the build costs 1.9 s of battery time |
| r8hN | never buy | 1000/32/1 and 1000/128/1 over 300 s; 8000/32/7 22.3 s | 0 | does not finish |
| r8hF | buy after a failure at the floor | 12.0 s, 180 s, 9.6 s, 10.2 s | 2 | the first probe under the regular bound is the slow part |
| r8hW | a per-probe read cap equal to the bound's row cells | battery treeDiff 0 vs r8h9, 2,548 ms; 1000/32/1 243.8 s | 1 | every probe is under the cap, and every probe pays |
| r8hX | one read cap over the whole ladder | 1000/32/1 240.3 s | 1 | reads do not measure work; offers do |
| r8h9 | r8h8 with the diverse search asked only after a rejection at the greatest failing budget | battery treeDiff 0 vs r8h6; family 43 1,024 2.7 s, 4,096 11.3 s; rungs (Stopwatch) 174 s, over 300 s, -, 23.2 s | 6 | right ladder, wrong purchase rule |
| r8h8 | ordinary ladder first, then the diverse search below its least budget | family 43 16,384 in 44.7 s; 2 cheaper INVALID fuzzer trees | 4 | not adopted as is |
| r8h7 | probe the found reading's cost next | family 43 1,024 5.4 -> 3.4 s, 4,096 25.8 -> 14.3 s, trees = r8h6 | 7 | adopted |
| r8h6 | gallop-and-bisect ladder over fresh cells | battery treeDiff 5 vs r8h5, costDiff 0; families 26, 28-31 at 16,384 in 2.0-2.9 s | 7 | adopted |
| r8h5 | one-occurrence insertion whenever the body can be inserted | `_mono` 0 of 13,241; battery treeDiff 4 vs r8h4 | 8 | monotone success |
| r8h4 | seeds only from cells growing below | battery treeDiff 2 vs r8h2; LR 16,384 1,017 ms | 8 | fixes lost readings |
| r8h3 | view every settled cell in full | fixes the lost readings; family 36 2.6 s at 4,096 (r8h2 0.2 s) | 3 | too slow |
| r8h2 | covered repetitions read later occurrences plainly | battery treeDiff 0; fuzzer 1-4 treeDiff 7/4/5/4, worse 0, invalid unchanged; families 35 and 42 finish at 4,096 | 7 | adopted |
| r8h1 | covered repetitions suppress `_resume` only | families 35, 42, 43 unchanged | 2 | the literal's own leading deletion carries the run |
| r8e7 | position-ordered `_repeat` worklist | families 4-23 finish at 16,384 | 8 | adopted |
| r8e6 | `_plain` with one lookup and a failure sentinel | 8000/32/7 10.9-11.4 s vs r8fin 11.7-12.1 s, trees = r8fin | 7 | adopted, 739 lines |
| r8el | one `_sealed` helper, as written | 8000/32/7 13.5-14.0 s vs 11.6-11.9 s | 3 | call cost on `_repeat`'s hot path; kept only with r8e6 |
| r8fin | r8gen without `_plain`'s memo-version check | trees = r8gen on battery and fuzzer 1-8 | 7 | -1 line |
| r8gen | the gap scan shared for every clause, bounded by the budget window | battery treeDiff 0 vs cl13, all checks, no-repair 0; errors 4,096 1,129 -> 152 ms | 8 | adopted |
| r8nl | the scan unbounded | 3 fuzzer trees differ at equal cost | 3 | the window matters |
| r8next | eager next-match index for terminals (Codex) | linear on the terminal family; First family 2,048/8,192/16,384 510/4,936/20,947 ms | 5 | terminals only |
| r8hO | front keyed by (end, owes) | battery 0.9665/76.7, treeDiff 305 | 1 | bound-independent on `acaca`, but the battery rejects it |
| r8hO2 | owed characters ranked right after cost | battery 0.9598/74.5 | 0 | |
| r8hC | additive cost, every owed character counted | battery 0.9699/75.8, costLower 220; fuzzer worse 0/0/1 on seeds 1/5/7 (r8hF 10/9/14) | 2 | the battery wants a truncated tail to cost one |
| r8hD | additive cost inside fronts, one-completion cost for the final choice | fuzzer worse 0 on every seed, invalid 7/5/6/3/6/4/6/9; battery 0.9816/80.7, treeDiff 117 | 3 | edits the user's text in place of completing a prefix |
| r8hP | prune only edited readings | still bound-dependent | 1 | |
| r8g1 (Gemini) | multi-letter Str in the memoized switch | family 42 at 512 14.8 s (still quadratic); 43 at 32 30.6 s vs 13.5 s | 1 | not a fix |
| r8g2 (Gemini) | `_relations` as a late field | battery 1,704 ms vs 1,609 | 1 | not faster |

**The Stopwatch made the answer depend on the machine (confirmed).** cl13 bought
return-site memory after a wall-clock delay. The Claude seat noticed that its
comment ("the answer does not depend on when it is bought") is false. On
corrected fuzzer seed 7, `S <- R0; R0 <- ((R1 R1 'a')* ((R0 R1) / 'c'+) 'a');
R1 <- ...` on `acaca`, always buying (r8hA) and never buying (r8hN) give
different cost-2 readings: an insertion plus an owed tail (deleted 0, missing 1,
owed 4) against two deletions. Both bounds are admissible (root 1 and 2, true
cost 2). So a faster or slower machine can return a different tree. cl14's
purchase rule counts offers, so it is deterministic, but the tree still depends
on which bound is in force.

**Owed cost is not additive, so the one-per-end front is not a sound dynamic
program (confirmed).** `cost = spent + (owed == 0 ? 0 : 1)`. Under the regular
bound, `(R1 R1 'a')@0` at end 5 keeps d=0 m=2 o=1, which the cell exit prunes
(2+1 > 2), where the remembering bound keeps d=0 m=1 o=2: a reading that owes
nothing displaced an equal-cost reading that owes characters, then was pruned.
Every sound variant (r8hO, r8hO2, r8hC, r8hD, r8hP above) loses on the battery,
which expects that at equal one-completion cost a truncated prefix is completed
rather than the user's text edited: `{"a":1,` should owe a member, not
substitute `}` for `,`, and `[1,[2,[3,` should not become one string. The
one-per-end front is itself a bias toward owed tails that the battery depends
on. Open (round 9, Q1).

**The price of the bound (confirmed).** One front offer costs about 16 times
the wall time of one entry of the bound's build (7.8 s for 13.5M offers against
0.9 s for about 18.9M entries). On 8000/4/7 and 8000/32/7 the first failed probe
is equally cheap (about 1k and 7k offers); only later probes differ, so no rule
that decides at the first failure wins both rungs. On 8000/4/7 the regular floor
is 3, the cost 4, and the purchase is a 6.9 s build (n = 196k, width 161, calls
4): cl14 loses that rung to cl13 (8,969 against 2,288 ms). The regular bound
merges callers, so an unclosed bracket is free under it and it barely prunes on
bracket-heavy input; work grows steeply with the slack above the true cost
(300/32/1: budget 28 0.68 s, budget 30 6.2 s). Open (round 9, Q2).

**Plain-parser verdicts for left-recursive clauses depend on evaluation order
(confirmed, pre-existing, flagged for the user).** The Claude seat found it;
`_orderfz.dart` finds 20 of 3,000 random grammars that differ in a verdict
(length, or match against mismatch) and 29 more that differ only in tree shape.
Minimal case (`_entry.dart`): `S <- R0; R0 <- ('a'* R1*); R1 <- (R0 / 'c'??);`
on `cac`: R0 at 0 matches 2 characters when R0 is entered first and 0 when R1 is
entered first. This bears on the paper's statements about purity and the
omniscient parser (`squirrel_parser.tex` lines 413 and 433). It is a property of
the core parser, not of recovery; whether to fix the parser or the text is the
user's call.

**Claims table.** The full table is `$SP/r8/CLAIMS8.md`; the rows that decided
cl14:

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| The `"ab" "aa"*? 'a'?+` quadratic is the `_resume` scan, not the ladder | Codex, Claude | counters: n=2,048 6,305,801 resume steps, 2 rungs | confirmed; BRIEF8's guess was wrong |
| r8next and r8skip are linear on that family, battery treeDiff 0 | Codex | fam.sh; Codex's logs | confirmed, superseded by r8gen |
| An unbounded scan changes 3 fuzzer trees at equal cost | Claude | r8nl vs r8fin, 3 runs | confirmed |
| Plain-parser verdicts for LR clauses depend on evaluation order | Claude | `_order.dart`, `_orderfz.dart`, `_entry.dart` | confirmed, stronger than stated |
| The Stopwatch comment is false | Claude | r8hA vs r8hN on `acaca` | confirmed (the two differ in the tree, not in the cost) |
| r8head fixes 3 invalid trees but regresses seed-1 `bbcc` from 1 to 2 | Codex | not rerun | Codex's measurement; not adopted |
| No `keepFirst` gives 0.9902/86.3, treeDiff 299, more invalid trees | Codex | battery from Codex's log | confirmed from log; `keepFirst` stays |
| cl13 invalid on seeds 1-8 is 8/6/8/4/7/8/7/11 | Codex | orchestrator's runs | confirmed |
| A multi-letter Str in the memoized switch fixes the quadratic families | Gemini | r8g1 on families 35, 42, 43 | wrong |
| `_relations` as a late field is faster | Gemini | r8g2 battery time | unsupported |

**Open items.**
- A cost model and front that do not depend on the bound and keep the battery
  (Q1 of round 9).
- The bound's price: battery 2,164 ms against cl13's 1,550-1,630, and 8000/4/7
  8,969 against 2,288 ms.
- Family 43 `S <- ("bc" / R0)*; R0 <- ("bb"+* 'b'?)` on `bbbbcb` x n is n log n
  but slow; 2.5 s at 1,024, 9.8 s at 4,096, 40.6 s at 16,384.
- r8h8 found 3 cheaper valid repairs that r8h9's rejection test misses.
- Size: cl14 is 76 lines larger than cl13.

**Process lessons.**
- `norepair.sh`'s cleanup sed matched only lowercase engine names, so an engine
  named with capitals (r8hJ) left its `nr` entry in `_pred18.dart`. The pattern
  is now `[a-zA-Z0-9]*nr`.
- A wait loop written as `pgrep -f PATTERN` matches its own shell when PATTERN is
  in its command line, and never exits. Wait on a known PID with `kill -0`, or on
  the harness's own completion notice.
- A work cap must count the unit that costs time: reads (r8hW, r8hX) did not;
  front offers did.
- Two admissible bounds may give different trees when the ranking is not a sound
  dynamic program. Test determinism by building one copy per bound and diffing
  them, not by timing.

### cl15 - cross-review round 9 on cl14: a faster bound build, one bound-dependent case removed, and a last key that is not transitive, 803 -> 804 LOC (2026-09-24)

Round 9 ran Gemini (gemini-3.1-pro-high) and a Claude subagent (Opus 5.5, high
effort) on BRIEF9 (Q1 a cost model and front that do not depend on the bound,
Q2 the bound's price, Q3 invalid trees, Q4 size and elegance, Q5 peer review).
Codex has no quota until Sep 29. Gemini's first launch failed on quota; the
relaunch was still running when cl15 was committed; its report is verified in the
next section. The engine is untracked `_cl15.dart` (kit name r9c15):
the Claude seat's b3 plus the orchestrator's elegance review.

**What cl15 changes (confirmed from the diff against cl14).**
- **A faster bound build** (the seat's a24/b3). `_Bound` keeps its graph in one
  interleaved `List<int>` edge list and runs its breadth-first search over an
  `Int32List` ring queue with head and tail indices. `queued` admits each state
  once, so the queue never holds more than `wide` states and the ring never
  overruns (proof by reading). The seat's bucketed Dijkstra (a16) was quadratic,
  because a bucket queue costs O(spread) per position.
- **`_versions` and `version` deleted**: nothing read them after cl14's `_plain`
  lost its memo-version check.
- **The cell-reuse test is `cell.budget >= budget && !cell.usedSeed`.**
- **A new last ranking key** (the seat's a11): between readings that insert
  equally, the most substitutions; otherwise the fewest substitutions, then the
  fewest insertions. In cl14 the order of offers decided these ties. The key
  removes one of cl14's two bound-dependent cases (seed 3, `aabb`).
- **Elegance review of b3 (r9c15)**: a dead branch deleted (`cell.usedSeed ?
  _since : -1` sat under a test that had just required `!cell.usedSeed`);
  `most = _len + _bnd.terms.length` hoisted out of `_ladder`'s loop, since
  neither term changes inside it; the header comment rewritten to state the last
  key and that it is not transitive (below).

**Measured (confirmed), kit r9/verify, against cl14.** LOC 803 -> 804 normalized
(+1, +0.1%). Battery 0.9900/84.4, treeDiff 1 against cl14 at equal cost, costDiff
0, 1,861 ms (cl14 2,164 in round 8's kit). Accept t/t/t, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0, window P, pred
falseAssertions 0. Corrected fuzzer (`_samedq.dart`, 400 cases), invalid seeds
1-8: 8/6/8/4/7/7/8/10 (= cl14), worse 0 on every seed, levSum equal to cl14's on
every seed; trees differ from cl14 on 4/4/4/4/5/5/2/5 cases, all at equal cost.
Old fuzzer invalid 3/2/4/6 (= cl14). No-repair 0. Rungs (ms, cl14 / cl15, every
cost equal): 1000/1/1 342/282; 1000/32/1 1,921/1,485; 1000/128/1 5,312/4,972;
8000/4/7 9,354/6,078; 8000/32/7 9,609/6,226. Stress (ms, cl14 / cl15): errors 256
40/44, 512 70/58, 1,024 81/81, 4,096 198/180; LR 2,048 182/178, 8,192 362/352.
Families (`fam.sh`): LR with one error at 32,768 terms 726 ms; unclosed
parenthesis 1,024/4,096 159/166 ms; every other listed family linear. Families
(`sweep3.py`, 46 grammars, n = 1,024/4,096/16,384): all 46 finish at every size
with the same costs as cl14; the slowest is still family 43 (cl14 / cl15 at
16,384: 45,397 / 44,625 ms), then 42 (3,493 / 3,626), 30 (2,599 / 2,673) and 26
(2,429 / 2,588).

**Determinism (confirmed).** Each engine was built twice, once with only the
regular bound (`g`: `_allowance = 0`) and once with the return-site bound from
the start (`m`), and the two copies were diffed.

| engine | battery treeDiff g/m | fuzzer treeDiff g/m, seeds 1-8 |
|---|---|---|
| cl14 | 0 | 0/0/1/0/0/0/1/0 (`aabb`, `acaca`) |
| cl15 (= b3) | 0 | 0/0/0/0/0/0/1/0 (`acaca`) |
| a27 | 0 | 0 on every seed |
| k6 | - | 0/0/0/0/0/0/1/0 |

On seed 7 the `m` copy gives the invalid, worse tree. So cl15 still answers
differently depending on which bound is in force, on one fuzzer input in 3,200.

**Owed cost has a dominance rule (confirmed, proof).** The Claude seat proved:
with `cost = spent + (owed == 0 ? 0 : 1)`, and owed insertions only ever
following at `_len`, an owing reading O of spent t dominates a non-owing reading
N of spent s iff t + 1 <= s, and N dominates O iff s <= t. At t = s neither
dominates, which is exactly the case the one-per-end front resolves by rank. a27
keeps two slots per end (one owing, one not) and drops a slot only when the other
dominates it. It is bound-independent on every seed, but costs seed 5 one
invalid tree and seeds 2 and 5 one worse case each (levSum seed 2 557 against
553), so it was not adopted.

**The last key is not transitive (confirmed).** The key is

    if (a.missing == b.missing) return b.subs - a.subs;
    return a.subs != b.subs ? a.subs - b.subs : a.missing - b.missing;

It puts a substitution before a deletion (equal missing), an insertion before a
substitution (fewer substitutions), and a deletion before an insertion (fewer
missing at equal subs). Among single edits the (missing, subs) pairs (0,0),
(0,1), (1,0) form a cycle, so in a cyclic triple the order of offers still
decides. An instrumented copy (r9b3x) that records, per (front, key, cost,
avoidable, evidence, first, last, owed), the set of (missing, subs) pairs seen,
finds 0 cycles on the battery and 2/0/0/0/0/2/1/3 on fuzzer seeds 1-8 (for
example `babaa`, `cab`, `cabacabbabacaa`, `cbccbcba`). The seat's claim that the
key "orders readings by their edits in place of offer order" is therefore wrong
as stated.

The battery uses all three pairs of the cycle, and each choice there matches
what a person would do:
- JSON `{a":1`: insert `"` before `a`, not substitute `"` for `a` (insertion over
  substitution).
- `stmt` with a stray `}`: delete the `}`, not insert `{` before it to make an
  empty block (deletion over insertion).
- JSON `3z3`: substitute `,` for `z`, not delete `z` and join `33` (substitution
  over deletion).

So no order on edit types alone matches the battery. The preference depends on
where the edit falls relative to the input's own brackets and tokens. Every
transitive key tried loses:

| Candidate | Last key | Result | Score | Reasoning |
|---|---|---|---|---|
| b3 = cl15 | a11's key (cyclic) | 0.9900/84.4; fuzzer = cl14 | 8 | best measured; the cycle is documented |
| k1 = k4 | fewer missing, then more subs (k4: more subs, then fewer missing) | 0.9900/84.4, 86 trees differ from b3, all JSON missing-open-quote cases, which now substitute `"` for the key's first letter; seed 7 levSum 532 against 533 | 3 | against human expectation on 86 inputs |
| k6 | more missing, then more subs | 0.9899/84.3 (7 `stmt` cases lost); invalid equal, worse 0; still bound-dependent on seed 7 | 4 | loses the stray `}` case |
| k2 | fewer subs, then fewer missing | 0.9897/84.1 (9 lost); seed 6 worse 1 | 2 | |
| k5 | fewer missing, then fewer subs | 0.9897/84.1; seed 6 worse 1 | 2 | |

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r9c15 = cl15 | b3 after the elegance review | trees = b3 on the battery and fuzzer seeds 1-8; 804 LOC | 9 | same results, a dead branch gone |
| b3 (Claude) | cl14 + the last key + the fast bound build + `_versions` deleted | as cl15 | 8 | removes `aabb`'s bound dependence; 8000/4/7 about 35% faster |
| b2 (Claude) | b3 without the last key | battery = cl14, 803 LOC | 7 | keeps both bound-dependent cases |
| a27 (Claude) | two-slot front + last key + fast bound build | 816 LOC; 0.9900/84.5, treeDiff 4; invalid 8/6/8/4/8/7/8/10; worse on seeds 2 and 5 | 6 | the only bound-independent engine, one invalid and two worse trees |
| a17 (Claude) | flat `Int32List` graph + ring queue | 8000/4/7 5,030 ms, 834 LOC | 4 | fastest build, 30 more lines |
| a23 (Claude) | ring queue only | 8000/4/7 6,230 ms | 4 | |
| a2, a5, a6, a7, a9 (Claude) | front keyed by (end, owes), dominance, other last keys | 0.9899-0.9900; invalid up to 8/7/8/4/8/8/9/11 | 3-5 | superseded by a11/a27 |
| nokf (Claude) | b3 without `keepFirst` | 0.9902/86.4, 303 changes, +1 invalid on seeds 1, 2, 5, 8, worse 1 | 2 | more invalid trees |
| a12 (Claude) | ladder `hi = r.cost` | 8000/4/7 8,894 ms | 2 | the tree would no longer be the least budget's |
| a14, a26 (Claude) | a check after dominance; `_rejected` dropped in `_rung` | worse 1 on seed 1 / seed 6 | 1 | |
| a1, a3, a4, a8, a10 (Claude) | ranking-order changes | 0.9727-0.9847 | 0 | battery loss |
| a19 (Claude) | `_covered` deleted | families 35, 42, 43 time out | 0 | does not finish |
| a21 (Claude) | reuse seeded cells | 0.9670 | 0 | |
| a16 (Claude) | bucketed Dijkstra bound | 8000/4/7 290 s | 0 | quadratic queue |

**Claims table.** The full table is `$SP/r9/CLAIMS9.md`.

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| b3 battery 0.9900/84.4, treeDiff 1 vs cl14 at equal cost; all checks equal | Claude | check.sh r9b3 | confirmed |
| b3 corrected fuzzer invalid 8/6/8/4/7/7/8/10, worse 0, no-repair 0 | Claude | `_samedq` seeds 1-8; norepair.sh | confirmed |
| a27 is bound-independent | Claude | g/m copies, battery and 8 seeds | confirmed (the seat had measured a11 only) |
| a27 costs one invalid and two worse trees | Claude | check.sh r9a27, seeds 1-8 | confirmed |
| owing/non-owing dominance rule | Claude | read the proof | confirmed |
| the last key orders readings by edits, not by offer order | Claude | r9b3x cycle count: 8 cycles on seeds 1-8 | wrong as stated |
| the ring queue never overruns | Claude | read: `queued` admits each state once | confirmed |
| `_versions` deletion changes nothing | Claude | part of b3's checks | confirmed |
| the fast build: 8000/4/7 9,707 -> 6,184 ms | Claude | rungs.sh cl14 r9c15: 9,354 -> 6,078 ms | confirmed |
| family 43 spends 45% of its time in the diverse rung | Claude | not rerun | unsupported by my check; round 10 |
| the 58 invalid trees split 29/18/11 (repetition/option, ordered choice, literal/sequence) | Claude | not rerun | unsupported by my check; round 10 |
| dead `cell.usedSeed ? _since : -1` branch; loop-invariant `most` | orchestrator | read r9b3 | confirmed, fixed in cl15 |
**Open items.**
- A transitive last key that keeps the battery's three human choices. It must
  look at where an edit falls relative to the input's brackets and tokens, not
  only at the edit type.
- Bound independence on `acaca` (seed 7) without a27's losses.
- Family 43's diverse rung.
- The invalid-tree classes, once confirmed.
- Size: 804 lines.

**Process lessons.**
- Gemini again handed its work to background tasks (its log: "root agent idle;
  waiting up to 5h0m0s for 25 background task(s)"), against the preamble. It
  stayed in its own directory, so it was left to run.
- A cycle in a comparator does not show as a crash or a failing check; it shows
  only as order dependence. Count it directly: record, per group of otherwise
  equal keys, the set of values the last key compares, and look for a cyclic
  triple.

### cl16 - cross-review round 10 on cl15: the last ranking key deleted, and cdx1 measured against it, 804 -> 796 LOC (2026-09-24)

Round 10 ran a Claude subagent (Opus 5.5, high effort) on BRIEF10 (Q1 a
transitive last key, Q2 bound independence on `acaca`, Q3 invalid trees, Q4
family 43, Q5 size, Q6 review of the round-9 verdicts). Codex has no quota until
Sep 29; Gemini's round-9 run was still waiting on its background tasks. The
engine is untracked `_cl16.dart` (kit name r10c16e): the seat's `cand` plus the
orchestrator's elegance review.

**What cl16 changes (confirmed from the diff against cl15).**
- **The last ranking key is deleted.** `_compare` ends at `a.owed - b.owed`.
  Every key is now an integer field of one reading, compared in a fixed order,
  so the ranking is a strict weak order (a lexicographic order on integer
  vectors). Readings equal in every key are resolved by `_Front.add` as before.
- **The `subs` field is deleted**: only the old key read it.
- **Two filters deleted that changed no result**: the diverse search's look
  through wrappers in `_active`, and the departed filter in `_repeat`.
- **Elegance review of cand**: `_Front.far` moved to the other fields;
  `_farthest` takes an `Iterable`, so `_Front.add` no longer copies the front
  into a list to find the farthest end; `lastCost = best.spent + best.owed`.
  Battery and fuzzer seeds 1-8 treeDiff 0 against cand.

**Measured (confirmed), kit r9/verify.** LOC 804 -> 796 normalized (-8, -1.0%).
Battery 0.9900/84.4, treeDiff 1 against cl15 at equal cost (json `...,"z"ta"]}`:
cl16 deletes the stray `"`, cl15 inserted `\`), 1,850 ms. Accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0, window
P, pred falseAssertions 0. Corrected fuzzer against cl15, seeds 1-8: invalid
8/6/8/4/7/7/8/10 (equal), worse 0, levWorse 0, levSum equal on every seed; trees
differ on 10/7/11/12/14/17/10/6 cases. Old fuzzer invalid 3/2/4/6. No-repair 0.
Stress and rungs equal to cl15 within noise (8000/4/7 5,931 / 5,924 ms). Families:
all 46 finish with cl15's costs; family 43 at 16,384 45,397 -> 41,162 ms.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0. Fuzzer seeds 1-8:
0/0/1/0/0/0/1/0, on `aabb` (both trees valid, equal cost and edit distance) and
`acaca` (the m copy gives the invalid tree). So cl16 gives back cl15's one gain
here: `aabb` depends on the bound again, as in cl14.

**Round 9 was wrong about the last key (confirmed).** Round 9 said "every
transitive key tried loses" and "the battery uses all three pairs of the cycle".
Having no last key at all is transitive and changes one battery tree, at equal
cost and score. Round 9's own row b2 ("b3 without the last key, battery = cl14")
already showed this. The three human choices (`{a":1` inserts `"`, a stray `}`
is deleted, `3z3` edits `z` at position 4) come out the same without the key,
measured with `_ed.dart`. The seat found that the stray-`}` choice rests on
`_resume` keeping a resumed scan's evidence (q1e, which drops that evidence,
loses the 7 stray-`}` cases). The cyclic key was only deciding offer-order ties.

**Why `acaca` depends on the bound (confirmed by the seat's analysis, read).**
With `cost = spent + (owed == 0 ? 0 : 1)`, an owing reading pays one unit for
any number of owed characters and can read more input, so on equal cost it wins
on evidence. On `acaca` the ranking itself prefers the invalid owing reading;
the regular bound only reaches the valid tree because it prunes differently.
Every cost model that charges owed characters fully loses the battery (q2a
0.9699, q2b 0.9817, q2c/q2d 0.9726), because JSON and stmt truncations need the
one-unit completion. a27's two-slot front loses for the same reason.

**cdx1 against cl15 (confirmed, same kit).** The c-table's cdx1 row (0.9899/85.9,
1,565 ms, 616 LOC) looks better than cl15 on the columns it has. On every other
check it is far behind:

| Check | cdx1 | cl15 |
|---|---|---|
| normalized LOC | 616 | 804 |
| battery score/perfect | 0.9899/85.9 | 0.9900/84.4 |
| battery time | 1,517 ms | 1,861 ms |
| battery cost vs the other engine | higher on 52, lower on 0 | |
| gates | all pass | all pass |
| fuzzer invalid, seeds 1-8 (3,200 cases) | 389 | 58 |
| fuzzer worse (cost above the other engine) | 747 | 23 |
| fuzzer levSum | 4,523 | 4,261 |
| errors 512 / 1,024 / 4,096 | 2,956 ms / 31,678 ms / did not finish in 60 s | 61 / 81 / 174 ms |
| left recursion 2,048 / 8,192 | 3,087 ms / did not finish in 60 s | 184 / 347 ms |
| rungs 1000/1/1, 1000/32/1, 1000/128/1 | 110 ms, 45,016 ms, did not finish in 300 s | 284, 1,672, 5,456 ms |
| rungs 8000/4/7, 8000/32/7 | 5,110, 10,230 ms | 6,086, 6,165 ms |
| 46 families | 26 do not finish in 120 s | all finish |
| unclosed parenthesis, 1,024 | Dart VM "evacuation failed" | 159 ms |

The higher perfect score comes from not breaking equal-cost ties by PEG's
ordered choice (cdx7 made that change; round 9's nokf measured the trade). On
`stmt x=1; } y=2;` cdx1 inserts `{` to make an empty block, where cl15 and cl16
delete the stray `}` (`_ed.dart`).

**cl15 and cl16 are not minimal against cdx1 (confirmed).** On 23 of the 3,200
fuzzer cases cdx1 finds a cheaper valid answer or a valid one where the cl line
gives an invalid tree: 8 invalid in cl16 but valid in cdx1 (for example
`R0 <- ('a' R0? 'a') / "ab"` on `aaaaa`, 1003 against 1), 12 both valid but
cl16 costlier (for example `R0 <- ('b'? 'a'? R0) / "aa"` on `acba`, 3 against
2), 3 both invalid. cl16 gives the same 23. The round-9 and round-10 fuzzer runs
compared only with cl14 and cl15, which share the guards, so `worse 0` there
did not mean minimal. Inferred, not traced: one of the coherence guards added
after cdx1 (`_stop`, `_starts`, `_tail`, `bad`, the departed filters) discards
the cheaper reading. The list is `$SP/cdx1_side/c15worse.txt`.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r10c16e = cl16 | cand + elegance review | trees = cand; 796 LOC | 9 | same results, no list copy in `_Front.add` |
| cand (Claude) | cl15 minus the last key, `subs`, x4, x9 | every check = cl15 except `aabb` bound-dependent | 8 | transitive ranking, 8 lines fewer |
| fnk2 (Claude) | a "hollow" key in place of the last key | 806 LOC; `aabb` bound-independent; 12 keyword repairs substitute `f` for a space in `i (x)` | 5 | against human expectation |
| q1n (Claude) | k6 + a hollow field | battery treeDiff 0, 825 LOC | 5 | +29 LOC for no measured gain |
| q1l, q1o (Claude) | hollow as avoidable / after evidence | 0.9904/84.6, fuzzer invalid +1 on seeds 6 and 8 | 3 | fuzzer loss |
| dx11 (Claude) | the avoidable demotion in `_seq` deleted | 0.9904/84.9, levWorse 1 (`bab`) | 4 | fails levWorse 0 |
| q2a-q2d (Claude) | owed characters charged fully | 0.9699-0.9817 | 0 | battery loss |
| x1, x3, x5-x8, x10, dx12, dx16 (Claude) | single guard deletions | invalid or worse up on the fuzzer, or battery loss | 0-1 | each guard still decides a fuzzer case |
| cdx1 as the engine | | see the table above | 0 | 26 families do not finish |
| start again from cdx1 | add fixes only where a check fails | not built | 4 | nearly every row of the table above forces a fix back in |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery 0.9900/84.4, treeDiff 1 vs cl15 at equal cost | Claude | `bench.sh battery` BASE=r9c15 | confirmed |
| cand: all gates, props, window, pred equal to cl15 | Claude | check.sh r10c16 | confirmed |
| cand: fuzzer invalid = cl15, worse 0, levWorse 0, seeds 1-8 | Claude | `_samedq` r9c15 r10c16 | confirmed |
| cand: no-repair 0 | Claude | norepair.sh r10c16 | confirmed |
| cand: 46 families finish with cl15's costs | Claude | sweep3.py, costs compared per family | confirmed |
| cand: stress and rungs equal to cl15 | Claude | stress.sh, rungs.sh | confirmed |
| cand: `aabb` and `acaca` bound-dependent | Claude | g/m copies, battery and seeds 1-8 | confirmed |
| round 9's "every transitive key loses" is wrong | Claude | the empty key: treeDiff 1 at equal cost | confirmed |
| the three human choices do not need the key | Claude | `_ed.dart` rerun on cl15, cl16, cdx1: same edits in cl15 and cl16 | confirmed |
| the stray-`}` choice rests on `_resume` evidence | Claude | not rerun (q1e) | unsupported by my check |
| `acaca`: the ranking prefers the invalid tree | Claude | read the argument; consistent with m giving the invalid tree | confirmed by reading |
| family 43 is n log n, 42-48% in the diverse rung | Claude | ratios 4.03x/4.17x in my sweep | consistent |
| 58 invalid trees split 26/18/10 + 4 mixed by kind set | Claude | not rerun | unsupported by my check |

Round 11 (2026-09-24) confirmed the q1e and 26/18/10 + 4 rows and refuted the `acaca` cost-model conclusion; see the cl17 section.

**Open items.**
- The 23 fuzzer cases where cdx1 beats the cl line: find which guard discards
  the cheaper reading. cdx1 now belongs in every fuzzer comparison.
- `acaca` and `aabb` bound independence; the owed-cost model that causes
  `acaca`.
- The invalid-tree classes; family 43's diverse rung.
- Size: 796 lines, against cdx1's 616.

**Process lessons.**
- A table's columns decide what a reader concludes. The c-table showed only
  battery score, time and size, so cdx1 looked better than cl15; the checks
  that separate them (fuzzer, stress, families) were not in it. The c-table now
  has a note under it saying so.
- A fuzzer that compares an engine only with its own ancestors cannot find a
  fault they share. Keep an independent engine (here cdx1) in the comparison.

### cl17 - cross-review round 11 on cl16: an edit-count key above cost 1, 796 -> 792 LOC (2026-09-24)

Round 11 ran a Claude subagent (Opus 5.5, high effort) on BRIEF11 (Q1 the 23
fuzzer cases where cdx1 is cheaper, Q2 bound independence on `acaca` and `aabb`,
Q3 invalid trees, Q4 family 43, Q5 what each part of cl16 buys against cdx1, Q6
review of round 10). Codex and Gemini had no quota (Gemini: "Individual quota
reached", Pro and Flash, until about Sep 29). The engine is untracked
`_cl17.dart` (kit name r11c17e): the seat's `cand` plus the orchestrator's
elegance review.

**What cl17 changes (confirmed from the diff against cl16).**
- **A new ranking key after the avoidable key**, applied only above cost 1:
  `if (a.cost > 1 && a.edits != b.edits) return a.edits - b.edits;` with
  `edits = spent + owed`. It compares within one cost class, so the ranking is
  still a lexicographic order and transitive. At cost 1 it does nothing, so a
  lone completion still pays one unit for everything it owes, which the battery
  needs (JSON and `stmt` truncations).
- **Three changes that change no result**: the `r.clean ||` part of the reach
  skip in `_first` was redundant (a clean reading never starts before `reach`
  once decided); the early `_evidence[m]` lookup in `_ev` duplicated the loop's
  `continue`; `_oneShape` is one memoized expression whose entry is `false`
  while the body is examined, so a clause that reaches itself has more than one
  shape.
- `lastCost = best.edits`; the header comment now lists the keys as the code
  has them (round 10's comment said "fewest completions", but the key counts
  owed characters).

**Measured (confirmed), kit r9/verify.** LOC 796 -> 792 normalized (-4,
-0.5%). Battery 0.9900/84.4, treeDiff 0 and costDiff 0 against cl16, 1,820-1,925
ms. Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0. Old fuzzer
invalid 2/2/4/6 (cl16 3/2/4/6), worse 0. No-repair 0. All 46 families finish
with cl16's costs (family 43 at 16,384: 40,842 ms, cl16 40,308). Stress and
rungs equal to cl16 within noise (errors 4,096 150 / 152 ms, left recursion
8,192 319 / 344 ms, 8000/4/7 5,817 / 5,946 ms, 1000/128/1 4,559 / 4,657 ms).

**Corrected fuzzer with cdx1 (confirmed).** "Worse" counts cases above the least
cost of the engines in the run, so each engine is compared in its own run:

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl16 (run with cdx1) | 8/6/8/4/7/7/8/10 = 58 | 2/1/6/2/0/6/4/2 = 23 | 2/1/4/2/0/1/3/2 = 15 |
| cl17 (run with cl16 and cdx1) | 8/5/7/4/7/7/6/9 = 53 | 1/1/5/2/0/5/3/2 = 19 | 1/1/3/2/0/1/2/2 = 12 |

cl17 is never costlier than cl16 on these 3,200 cases; all 19 remaining worse
cases are against cdx1. levSum is lower or equal on seeds 1-7 and one higher on
seed 8 (528 against 527). The five invalid trees fixed (s2 `acbcabca`, s3
`cabcca`, s7 `acaca`, s7 `bbacccab`, s8 `cacbbca`) are all an owing reading that
read farther and outranked a plain repair. cl17 has no invalid tree that cl16
lacks.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0; fuzzer seeds 1-8
differ only on seed 3 `aabb`. `acaca` is bound-independent: its owing reading
has edits 5 and the deleting reading edits 2, both at cost 2. `aabb` is an
exact tie on every key between two valid cost-1 trees (substitute `a -> b`, or
insert `b`), so `_Front.add` keeps whichever arrives first, and the bound
decides the order. Three tie-breaks were measured and each changes battery
trees: prefer deletion (treeDiff 8, the stray-`}` cases), prefer insertion
(treeDiff 85, JSON `{a":1`), first edit kind (treeDiff 611).
(2026-09-25: the deletion and insertion labels here are swapped, and
`_Front.add` does not keep the first of two equal readings; see the cl18
section.)

**The 23 cdx1-cheaper cases, traced by the seat (not all rechecked).**
- Fixed by the new key: 2 `bccab`, 5 `ccac`, 15 `cabaab`, 19 `acba` (confirmed:
  fuzzer counts above).
- Cost-1 lone completion against one deletion: 10, 11. Charging it (WR) loses
  the battery (0.9893).
- The reach skip in `_first` (8, 17); the opener guard, the avoidable demotion
  or the bound (3); the bound suppressing the diverse retry (14); an
  unexplained search gap (18). Each guard's knockout fixes its case and loses
  on other seeds.
- Case 6 is not a defect: cl16's rank cost is 3 against cdx1's 4; the fuzzer
  compares `lastCost`, which holds edits (7), not rank cost.
- Cases 1, 4, 7, 9, 12, 13, 16, 20-23: cl16's tree is invalid (the invalid-tree
  problem, not a ranking one).

**What each part of cl16 buys against cdx1 (the seat's knockouts, measured
there).** Every guard and policy that cdx1 lacks decides at least one seed of the
three-way fuzzer, or the battery, or speed: the cut guard, the opener guard, the
reach skip, the earlier-arm lead, keepFirst in ordered choice (without it the
battery rises to 0.9902/86.4 but 303 trees change and seeds 1, 2, 5, 8 lose),
the `_total` break, native plain reach, the departed filter in `_seq`, the
avoidable demotion (the `bab` case), the guard skip in `_resume`, `_stop`,
`_tail`, `later`, the sealed body in `_repeat`, resuming past unreadable
characters (worse 35-54 per seed without it), the requireOne block (0.9694
without it), the bound floor (40% slower battery), sealed-atom sharing (family
38 718 -> 1,927 ms without it), and each ranking key. The only knockouts inside
every target are the clean skip in `_view` (V1, 4 lines) and the exposed
filter (P3, changes 4 battery trees).

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r11c17e = cl17 | cand + comment fixes | trees = cand; 792 LOC | 9 | every target met; comments now describe the code |
| cand (Claude) | cl16 + edit key above cost 1 + three redundant parts removed | as above | 9 | 4 of the 23 cases and 5 invalid trees fixed, `acaca` bound-independent |
| cand + V1 (Claude) | the `_view` clean skip deleted | about 788 LOC; invalid 54, worse 1/1/5/2/0/4/4/2; battery treeDiff 0 | 8 | within every target, 4 lines fewer, but one more invalid tree than cand on s7; the case it gains (12) stays invalid |
| cand + P3 (Claude) | exposed filter deleted | 4 battery trees change; s3 and s7 gains lost | 6 | no line saving worth the loss |
| cand + S3 (Claude) | avoidable demotion deleted | 0.9904/84.9, treeDiff 51, fixes case 3; s4 levWorse 3 | 6 | fails levWorse (`bab`) |
| Y=M (Claude) | return-site bound from the start | trees and family costs equal; battery 4,080 against 2,288 ms, 1000/1/1 2.4x slower | 4 | bound-independent by construction, too slow on small inputs |
| DS2 (Claude) | `_Front.add` keeps no equal diverse readings | family 43 -18%; `bcba` becomes invalid | 3 | changes trees |
| OE, OE2, OE4, OE5, OE7 (Claude) | other edit-count keys, including at cost 1 | 0.9726-0.9899 | 0-3 | battery loss; the key must skip cost 1 |
| KD, KI, TK (Claude) | tie-breaks for `aabb` | treeDiff 8 / 85 / 611 | 1-2 | battery trees change |
| WR (Claude) | truncation against deletion | fixes 10, 11; 0.9893 | 1 | battery loss |
| EV = round 10's q1e | no evidence from resumed scans | 0.9899/84.3, treeDiff 15 | 2 | 8 battery cases lose |
| SB, SF, ST (Claude) | bound tests in `_seq` and `_first` | family 43 unchanged | 2 | no gain |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery 0.9900/84.4, treeDiff 0 vs cl16 | Claude | `bench.sh battery` BASE=r10c16e | confirmed |
| cand: every check equal to cl16, no-repair 0 | Claude | check.sh, norepair.sh | confirmed |
| cand: invalid 53, worse 19, levWorse 12 (three-way) | Claude | `_samedq` r10c16e cdx1 r11c17, seeds 1-8 | confirmed |
| cl16 baseline worse 2/1/6/2/0/6/4/2, levWorse 2/1/4/2/0/1/3/2 | Claude | `_samedq` r10c16e cdx1, seeds 1-8 | confirmed |
| cand: never costlier than cl16 | Claude | the same runs | confirmed |
| cand: `acaca` bound-independent, `aabb` not | Claude | det.sh | confirmed |
| cand: families, rungs, stress equal to cl16 | Claude | sweep3.py, rungs.sh, stress.sh | confirmed |
| `aabb` ties on every key | Claude | read the two readings in the report | consistent, not rerun |
| round 10: `acaca` needs a cost model the battery rejects | Claude (r10) | the new key fixes it at treeDiff 0 | wrong |
| round 10: q1e loses the stray-`}` cases | Claude (r10) | seat reran it: treeDiff 15, also i=734, 756 | confirmed (was unsupported) |
| round 10: 58 invalid split 26/18/10 + 4 | Claude (r10) | seat reran it: 26/18/10/3/1 | confirmed (was unsupported) |
| cl16 section: a guard discards the cheaper reading | orchestrator | seat's trace | partly wrong: 4 cases come from the ranking, 1 is not a defect |
| the knockout table in Q5 | Claude | not rerun, except that cand's numbers match | unsupported by my check |

**Open items.**
- 19 fuzzer cases where cdx1 is still cheaper; 11 of them are invalid trees in
  cl17.
- `aabb`: an exact tie decided by arrival order. A tie-break that keeps the
  battery has not been found.
- Family 43 (41 s at 16,384). `_rejected` is one global flag: any bad or
  departed reading in any rung sends `recover()` into the whole diverse ladder.
  A flag that records whether the rejected reading could have beaten the found
  one is the likeliest tree-preserving speedup (inferred, not built).
- `lastCost` holds edits, not the rank cost; the name misleads (case 6).
- Size: 792 lines against cdx1's 616; V1 is the only measured deletion inside
  every target.

**Process lessons.**
- A cost model that failed when applied everywhere can pass when applied in
  one cost class. Round 10 rejected "charge owed characters" because it was
  tested at cost 1 too, where the battery's truncations live.
- An agent's orphaned process skews later timings: Gemini's round-9 run left a
  Dart VM running family 43 on cl14 for 4 h 55 min after the agent exited. Check
  `ps` after every agent exits.

### cl18 - cross-review round 12 on cl17: the opener guard sees the whole inserted literal, 792 -> 796 LOC (2026-09-24)

Round 12 ran a Claude subagent (Opus 5.5, high effort) on BRIEF12 (Q1 invalid
trees, starting with the 8 cases where cdx1 is valid; Q2 one validity rule in
place of several guards; Q3 family 43 and the `_rejected` flag; Q4 size and
elegance; Q5 review of round 11). Codex and Gemini had no quota (until about
Sep 29). The engine is untracked `_cl18.dart` (kit name r12c18e): the seat's
`cand` plus the orchestrator's elegance review.

**What cl18 changes (confirmed from the diff against cl17).**
- **The opener guard tests the whole inserted text.** `_read` gives each
  reading of a multi-character literal with no deletion a `lead`: the rest of
  the literal from its first edit, `c.text.substring(r.first - pos)`. `change`
  takes an optional `lead`. `_starts` no longer requires a one-character text,
  so the guard asks whether the inserted text revives the body, not only its
  first character. A lead is never empty: it runs from an edit inside the
  literal to the literal's end.
- **A covered repetition's stop is left to the repetition that encloses it**:
  `_tail` skips a `Repetition` in `_covered`.
- **Two changes that change no result**: `.demoted` in the requireOne block
  (trees equal on the battery and fuzzer seeds 1-8); the `_rung` test
  `w.bad || w.departed` is evaluated once (`dropped`, +1 line, kept for
  clarity).
- Comments now say "literal" and "text" where the guard used to take one
  character. Elegance review: the guard functions' parameter `ch` is now `s`
  (it holds a text), which lets the formatter join two lines (798 -> 796
  normalized); renaming it `lead` instead wrapped lines (804).

**Measured (confirmed), kit r9/verify.** LOC 792 -> 796 normalized (+4,
+0.5%; raw 792 -> 798); the size target is missed. Battery 0.9900/84.4, treeDiff 0 and costDiff
0 against cl17, 1,821-1,857 ms. Accept t/t/t, freespan 3 3 4 4 1, recommit
16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P, pred
falseAssertions 0. Old fuzzer invalid 2/2/4/6 (= cl17), worse 0, treeDiff
22/29/23/31 at equal cost. No-repair 0. All 46 families finish with cl17's costs (family 43 at
16,384: 39,448 ms, cl17 40,101). Stress and rungs equal to
cl17 within noise (errors 4,096 160 / 161 ms, left recursion 8,192 312 / 357
ms, 1000/128/1 4,594 / 4,564 ms, 8000/4/7 6,116 / 5,858 ms).

**Corrected fuzzer, three-way with cl17 and cdx1 (confirmed, one run).**

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl17 | 8/5/7/4/7/7/6/9 = 53 | 1/1/5/2/0/6/3/2 = 20 | 1/1/3/2/0/2/2/2 = 13 |
| cl18 | 7/5/7/4/7/6/6/9 = 51 | 0/1/5/2/0/5/3/2 = 18 | 0/1/3/2/0/1/2/2 = 11 |

Every seed is at or below cl17. levSum is equal on seeds 2-5, 7 and 8, one
higher on seeds 1 and 6 (532 against 531, 524 against 523). The two fixed
invalid trees are s1 `cba` (cl17 1002, cl18 1; cdx1 5) and s6
`R0 <- (R1 / R1?); R1 <- ('b' (('a' R0) "ab"+))` on `babab` (1007 -> 1). The
seat's two-way run finds 108 differing trees, all others at equal cost and
validity (not rerun). 18 of the 19 cases where cdx1 was cheaper remain.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0; fuzzer seeds 1-8
differ only on seed 3 `aabb`, as in cl17.

**The 8 cases where cl17 is invalid and cdx1 valid, traced by the seat.** Six
causes:
- A, the opener test saw one character (`cba`): fixed by cl18.
- B, the guard cuts at the match end where the body's examined extent is
  needed (`ccacccababb`, `aaaaa`): a look rule fixes them (w2) but adds 56
  lines and raises worse on seeds 3, 5 and 7.
- C, a left-recursive seed read empty under the `_usedSeed` exemption
  (`cbccbcb`, `cbaa`): conjectured from the diagnostics, not built.
- D, a later First arm whose first edit deletes where an earlier arm still
  matches (`ccaab`): not built.
- E, the diverse ladder resumes past a deletion the guard forbids (`ccbbbc`):
  fixed by `_free` (below), not kept.
- F, an exact tie decided by the last key (`aaacbbb`).
Of cl18's 51 invalid trees, most are a repetition or option PEG would read
longer on the repaired string (groups B and C), then ordered choice (D).

**Negative results (the seat's measurements).**
- **No single rule replaces several guards.** The look rule (w1, both cuts):
  invalid 61, worse 30. The lead rule implies no other guard: deleting
  `_finishes` on top of it gives +1 invalid on s4, the `_stop` seed line worse
  56, the requireOne block 0.9694. A resume lead in place of `_resume`'s guard
  skip (w3, w4): 12 battery trees change, worse 41 or 26 against 24.
- **Family 43.** The diverse ladder is about half its time (confirmed: a copy
  that runs it only when nothing was found takes 1,465-1,530 / 5,325-5,389 ms
  at 1,024 / 4,096 against cl18's 2,641-2,649 / 10,314-10,343 ms, same costs).
  In family 43 the flag is always set by `_Front.add`
  seeing a bad reading, never by `_rung`. The diverse ladder never runs on the
  battery; on the fuzzer it runs on 35 of 3,200 inputs and changes 12 answers
  (7 replaced, 5 found from nothing). Every narrower condition changes trees
  or leaves family 43 unchanged: the flag from `_rung` only for dropped
  readings at or below the found cost (no gain), no flag from `_Front.add`
  (worse above cl17 on s2 and s8), the flag only from the answer's rung
  (battery treeDiff 1).
- **V1 (the clean skip in `_view`) stays**: -4 lines, but `(('a' 'a')* (R0
  'a')*)` on `aaaaa` (s7) becomes invalid.
- **cand_free** (cl18 + `_free`: the diverse ladder skips `_resume`'s guard
  only when the ordinary ladder found nothing), 799 LOC: invalid 49, worse 17,
  17 of 19; but the old fuzzer loses two cases, s3 `('a'? 'a' 'a')` on `caab`
  (2 -> 3; cl17's repaired string is rejected by plain PEG) and s4
  `((R0 / R0)? 'b' 'b'?+)` on `bbbbbaab` (2 -> 3; a real loss: `_resume`
  stops at an empty match of the nullable `'b'?`). Two fixes for s4 failed
  (battery treeDiff 39; worse above cl17 on s6, s7). Not rerun here.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r12c18e = cl18 | cand + `ch` -> `s` | trees = cand; 798/796 LOC | 8 | every target but size |
| cand (Claude) | lead rule + covered `_tail` + `.demoted` removed + `_rung` merge | 798/798 LOC; invalid 51, worse 18; treeDiff 0 | 8 | two invalid trees fixed, nothing lost |
| cand_free (Claude) | cand + `_free` | 799 LOC; invalid 49, worse 17; old fuzzer s3, s4 lose | 7 | better fuzzer, one real old-fuzzer loss |
| w6 (Claude) | V1 deleted | 796 LOC; invalid 50 on the `_free` line, +1 on s7 | 5 | -4 lines for a real loss |
| w2 (Claude) | look rule where the cut is null | 848 LOC; invalid 49; worse up on s3, s5, s7 | 3 | fixes group B, +56 lines |
| w1 (Claude) | look rule for reach and cut | 843 LOC; invalid 61, worse 30 | 1 | worse on every column |
| w3, w4 (Claude) | resume lead | 794 LOC; treeDiff 12; worse 41 / 26 | 1-2 | battery trees change |
| w10, w8, w12 (Claude) | narrower `_rejected` | trees change or family 43 unchanged | 1-3 | no tree-preserving speedup |
| lead + a guard deleted (Claude) | `_finishes` / `_stop` seed line / requireOne | +1 invalid s4 / worse 56 / 0.9694 | 0-1 | each guard still decides a case |
| `lead` rename (orchestrator) | `ch` -> `lead` | 804 LOC | 2 | lines wrap |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery treeDiff 0, every check = cl17 | Claude | check18.sh r12c18 | confirmed |
| cand: invalid 51, worse 18, levWorse 11; cl17 53, 20, 13 | Claude | the same run, three-way | confirmed |
| cand: no-repair 0 | Claude | norepair.sh r12c18 | confirmed |
| cand: det only `aabb` | Claude | det11.sh r12c18 | confirmed |
| cand: stress and rungs = cl17 | Claude | stress.sh, rungs.sh | confirmed |
| cand: 46 families, costs = cl17 | Claude | sweep3.py r11c17e r12c18 | confirmed |
| r12c18e: trees = cand | orchestrator | battery BASE=r12c18, treeDiff 0 | confirmed |
| diverse ladder ~49% of family 43 | Claude | a copy with `if (found == null)`: 5,325-5,389 against 10,314-10,343 ms at 4,096, same costs | confirmed (about 48%) |
| cl17 section: KD/KI labels swapped | Claude | final key `a.missing - b.missing`: treeDiff 85; `b.missing - a.missing`: 0.9899/84.3, treeDiff 8 | confirmed; corrected below |
| cl17 section: `_Front.add` keeps whichever arrives first | Claude | read `_Front.add`: only `_first` passes keepFirst; elsewhere a later equal reading replaces the stored one | confirmed; the order of production decides, not a first-wins rule |
| round 11 knockouts G1, F1b, V1, T, S3 reproduce | Claude | not rerun | unsupported by my check |
| group C cause (`_usedSeed`) | Claude | the seat marks it conjectured | conjectured |
| cand_free old-fuzzer losses | Claude | not rerun | unsupported by my check |

**Corrections to the cl17 section.** Its determinism paragraph has the two
tie-break labels swapped: preferring insertion changes 8 battery trees (the
stray-`}` cases get an inserted `{`), and preferring fewer insertions changes
85. The same paragraph says `_Front.add` keeps whichever reading arrives first;
only ordered choice keeps the first, and elsewhere the later equal reading
replaces it, so the tie is decided by the order the rungs produce the readings.

**Open items.**
- Size: 796 normalized lines against cdx1's 616. No deletion inside every target was found
  this round.
- Invalid groups B, C and D; the examined-extent cut is the right cut for B but
  costs 56 lines as built.
- Family 43: a flag that fires only when a bad reading could outrank the found
  answer under `_compare` (not built).
- `aabb`, an exact tie.
- `lastCost` holds edits, not the rank cost (above it exactly when owed > 1).

**Process lessons.**
- A rename can move LOC either way under the formatter: `ch` -> `lead` added 6
  normalized lines, `ch` -> `s` saved 2. `bench.sh loc` formats with
  `--language-version=3.0` (the short style); the installed `dart format` without
  it uses the tall style and restyles the whole file, so only `bench.sh loc`
  measures size.
- `pgrep -f` with a pattern from the loop's own command line matches the loop
  itself, so a wait loop built on it never ends. Wait on output files or the
  job's own completion.

### cl19 - cross-review round 13 on cl18: 27 lines shorter, and the growth exemption in `_tail` narrowed, 796 -> 769 LOC (2026-09-25)

Round 13 ran a Claude subagent (Opus 5.5, high effort) on BRIEF13, which put
size first (Q1 the same trees with fewer lines; Q2 fewer lines with better
answers; Q3 invalid-tree groups C and D; Q4 family 43 without changing a tree;
Q5 review of round 12). Codex and Gemini had no quota. The engine is untracked
`_cl19.dart` (kit name r13c19), the seat's final `cand` unchanged.

**What cl19 changes (confirmed from the diff against cl18).**
- **Rewrites that change no answer**, 796 -> 768 normalized lines:
  `_Relation` extends `_Front` (the `front` field and `_Front.diverse` go;
  `key` reads the search's mode, which is safe because no front outlives a
  rung); one `exit` array in the bound build (-2 before a state's first exit,
  -1 once it has a priced exit or a second one) in place of `out` and `exit`;
  `lastCost = 0` removed (a new `Recovery` starts at 0); the ladder's loop
  condition as one expression; `_first` indexes its arms instead of keeping an
  `earlier` list, and computes `reach` with `_farthest` over the arm's readings
  and its plain reading (a plain reading is always preferred); `_resume`'s
  loop, `_next`, `_tail`, `_ev` and `_covered` shortened; `_Front.ways`
  removed.
- **The growth-counter reset in `_rung` is removed.** When `_Spent` is thrown
  mid-growth, `_depth`, `_low` and `_since` keep stale values into the next
  rung. This is safe (argued, and the 46-family sweep exercises the throw):
  every growth sets `_low` to `_never` on entry and decides `usedSeed` from
  its own reads; depths are compared only with each other, so an offset in
  `_depth` changes nothing; and the top cell is the shallowest, so the stale
  `_low` and `_since` it restores are never read.
- **`_tail` exempts a stop only if its body's cell is growing and used a seed**
  (`_active && _usedSeed`, +1 line). cl18 exempted every stop whose body's cell
  was growing when the lazy guard ran. One corrected-fuzzer tree changes, s8
  `R0 <- ((R0* 'a') / (("cb" R0) / R0?))` on `cbaa`: cl18 inserts `a` at 4
  (cost 1, invalid: plain PEG reads `cbaaa` differently), cl19 deletes `a` at
  3 (cost 1, valid).

**Measured (confirmed), kit r9/verify.** LOC 796 -> 769 normalized (-27,
-3.4%; raw 798 -> 771). Battery 0.9900/84.4, treeDiff 0 and costDiff 0
against cl18, 1,848 ms. Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16,
conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P, pred
falseAssertions 0. Old fuzzer treeDiff 0 against cl18 on seeds 1-8. Corrected
fuzzer two-way against cl18, seeds 1-8: one differing tree (`cbaa`). No-repair
0. `det11.sh`: only `aabb`. All 46 families finish with cl18's costs (family
43 at 16,384: 41,517 ms, cl18 40,813). Stress and rungs within about 10% either
way; left recursion at 2,048 terms is 18 ms slower in three reruns (195-199
against 176-182 ms) and equal at 8,192 (348-361 against 343-358 ms), so the gap
is a fixed cost, not a growing one (cause not found).

**Corrected fuzzer, three-way with cl18 and cdx1 (confirmed, one run).**

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl18 | 7/5/7/4/7/6/6/9 = 51 | 0/1/5/2/0/5/3/2 = 18 | 0/1/3/2/0/1/2/2 = 11 |
| cl19 | 7/5/7/4/7/6/6/8 = 50 | 0/1/5/2/0/5/3/1 = 17 | 0/1/3/2/0/1/2/1 = 10 |

levSum is one higher on s8 (529 against 528).

**Group C, traced by the seat (its measurements, not rerun here).**
- Round 12's conjecture for `cbaa` is wrong: deleting the `_usedSeed` line in
  `_stop` does not fix it and raises worse to 57. The cause is the `_active`
  exemption in `_tail`, fixed above. Removing that exemption outright (w11)
  also fixes `cbaa` but leaves old-fuzzer s7 `aaaaa` with no repair (cost 5
  against 3). `same.sh` screens only old seeds 1-4, so it missed this: guard
  changes need all eight old seeds.
- `cbccbcb` has a different cause: `('c' 'b')` is a `Seq` of two `Char`s, so
  its reading carries the lead `c`, not `cb`. Joining adjacent leads (w12)
  fixes it but never finishes on s1 and s6, because owed insertions at the end
  cost 1 however many there are and the lead grows without limit.

**Negative results (the seat's measurements).**
- Group D (w5, 774 LOC): a later First arm whose first edit deletes at `pos`
  stands only if no earlier arm matches the repaired text. Fixes `ccaab` and
  three more (invalid 48, worse 17), but s1 `bbcc` goes 1 -> 2, where cl18's
  cost-1 answer is valid only through the substitution fill.
- Q4: "a dropped bad reading could outrank the found answer" (cost at most the
  found cost) is always true where the flag is read, so it filters nothing
  (argued: the flag comes from the last failing rung, at budget found - 1, and
  every reading there passed `spent + bound <= budget`). A bound filter loses
  old s3 `caab` (2 -> 3). No sound condition cheaper than the diverse retry
  itself was found.
- No merge of `_starts`/`_finishes`, `_stop`/`_tail` or the two bound forms.
- On top of w11: V1 deleted (+1 invalid on s7), `_usedSeed` dropped from the
  `_first` lead check (worse 21), reach from `_plain` only (worse 122), the
  requireOne block deleted (0.9694), `_scan` zeroing deleted (0.9878).

**Elegance review.** In cl19's `_tail`, `_usedSeed` of a growing cell reads
`usedSeed` from its previous growth: on a cell's first growth in a rung the
test is `active && recursive`, on a regrowth (which happens only because
`usedSeed` was set) it is `active`. The variant that tests only `active &&
recursive` (r13c19e, a `regrowing` getter and a shared `_cell` lookup) keeps
every tree on the battery and both fuzzers, seeds 1-8, but is 771 lines. Not
adopted; the size goal decides a tie in trees.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cand = cl19 | w1 + `_tail` exemption `_active && _usedSeed` | 769 LOC; invalid 50, worse 17; one tree better | 9 | every target met; left recursion 2,048 +18 ms fixed |
| w1 | rewrites only | 768 LOC; trees = cl18 | 8 | same trees, `cbaa` still invalid |
| r13c19e (orchestrator) | exemption `active && recursive` | 771 LOC; trees = cl19 | 7 | states the rule exactly, 2 lines more |
| w5 | group D rule | 774 LOC; invalid 48; s1 `bbcc` 1 -> 2 | 5 | fails the per-seed target |
| w11 | `_active` exemption removed | 767 LOC; no-repair 1 (old s7) | 2 | fails target 1 |
| w9 | diverse retry only when nothing found | family 43 halved; 7 + 5 trees change | 2 | changes trees |
| w2, w3 | narrower `_rejected` | vacuous / old s3 loss | 1-3 | no gain |
| w12 | joined leads | hangs on s1, s6 | 0 | does not finish |
| w4 | `_usedSeed` in place of `_active` | invalid 53, worse 20 | 1 | fails target 3 |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: 769 normalized LOC | Claude | `bench.sh loc`: raw 771, normalized 769 | confirmed |
| cand: battery treeDiff 0, costDiff 0, all checks = cl18 | Claude | check19.sh r13c19 | confirmed |
| cand: one corrected-fuzzer tree differs (`cbaa`, cost 1 both, now valid) | Claude | two-way `_samedq` seeds 1-8 against cl18: one TREEDIFF | confirmed |
| cand: invalid 50, worse 17, levWorse 10 | Claude | three-way run | confirmed |
| cand: old fuzzer treeDiff 0 on seeds 1-8 | Claude | check19.sh (seeds 1-8) | confirmed |
| cand: no-repair 0; det only `aabb` | Claude | norepair.sh, det11.sh | confirmed |
| cand: 46 families, costs = cl18 | Claude | sweep3.py r12c18e r13c19 | confirmed |
| growth-counter reset not needed | Claude | code reading (above) and the sweep | confirmed by argument |
| cold left-recursion rows 5-20% slower, JIT | Claude | three reruns: +18 ms at 2,048, none at 8,192 | gap confirmed; cause unconfirmed |
| Q4 condition vacuous | Claude | read `_ladder`: `rejected` is taken from the last failing rung | confirmed by argument |
| group C `cbaa` cause, `cbccbcb` cause, w5, w12, w11 results | Claude | the `cbaa` fix confirmed through cand; the others not rerun | partly confirmed |
| round-12 claims rerun (cand_free s3/s4, family 43 timing, V1) | Claude | not rerun by me; the seat's reruns agree with round 12 | unsupported by my check |

**Open items.**
- Size: 769 against cdx1's 616.
- Invalid groups B, C (`cbccbcb`: a lead joined across a `Seq` of literals,
  bounded by the grammar, not built) and D (w5 without the `bbcc` loss).
- Family 43: about half its time in the diverse retry.
- `aabb`, an exact tie; `lastCost` holds edits, not the rank cost.
- The guard's `_active` test depends on when the lazy guard runs (pre-existing).

**Process lessons.**
- A guard change must be screened on all eight old-fuzzer seeds: w11 passed
  seeds 1-4 and lost a repair on seed 7.
- A constant timing gap that vanishes at larger n is a fixed cost; rerun at two
  sizes before calling it a slowdown.

## 4. The c-series arc — what each engine taught

- **c1** (I101): the budget-zero collapse. The two-mode split (parse vs
  repair) is not a feature of the problem, only of earlier designs — the
  pure parser is the zero fiber of the costed descent. 0.9818, 493 lines.
- **c2** (I102): the four-form normalization (X* is left recursion, X? is
  choice, a literal is a char-sequence, EOI is a slot) — the smallest
  engine ever above 0.98 (454 lines) and the proof that grammar rewriting
  as a FOUNDATION costs accuracy and produces trees foreign to the
  author's grammar. The behavioral laws survive; the rewriting does not.
- **c3** (I103): the way-front as the memo cell; Warth's involved-set;
  the sort and its livelock class deleted. Porting truths: the seed is
  read raw; gating foundLR on a null container silently turns growth off.
- **c4** (I104–I107): the completed rank — every key traced to a family;
  the fee's seed exemption; the literal replace edit; eof-is-not-spend.
  The residual then classified: mostly yardstick, not engine (→ era-3
  curation). Proved the size floor is a measurement: nine collapses below
  ~511 lines each broke a recorded bar.
- **c5** (I108): the swallow derived, never stored — toll, vouch, judge,
  and the vouch-symmetry bug class deleted; judgment bit-identical.
- **c6** (I109–I111, then the fusion): the way as a cons cell that knows
  its sums (fifteen fields → ten); the root protocol and audit walk
  deleted; the pentad audit — admission is the rank's own price, tier 5
  is the stranded count alone, and the five counters are proven the
  floor (0.9879 / 84.0 / ~1490 ms / 461 lines). Then the whole squirrel
  parser folded in: an engine-owned node hierarchy with behavior as
  methods and memo state as stamped arrays on the nodes —
  judgment-identical and −20% latency, 707 lines all told.
- **c7** (I112): one left-recursion law for both fibers — re-entry
  seeds, growth bumps the position's version, and the involved set is a
  single boolean recorded by the unwind; Warth's stack, heads map, tick
  and sets delete. Judgment-identical, 0.9879 / 84.0 / ~1112 ms / 692
  lines, every gate exact — the first engine to hold the accuracy AND
  latency records at once.
- **c8** (I113): the adversarial audit, and one frozen-answer protocol.
  Every assumption re-questioned; most held with sharper reasons (the
  clean-cell rivals are load-bearing — b1's winner SPLITS a purely
  matching "33"; the pure fiber stays dual code; the ladder stays).
  What changed: freeze(pos) is the single frozen-answer protocol at
  every node kind (go = freeze-or-repair; grow's budget zero calls it;
  a terminal's pin bit is the leaf case of the net walk), and the rule
  cell owns its frozen way, built once. Judgment-identical, every gate
  exact — the standing engine. The audit's two new refutations are in
  the ledger; the design is visibly at a fixed point (c5→c6 cut 73
  lines, c6→c7 one law, c7→c8 one protocol). c8 was then renamed and
  re-documented end to end for readers without this file's history —
  every invented term replaced (section 8), every mechanism explained in
  plain language in the source, judgment re-verified identical — and
  finished with the strict zero fiber: budget-zero queries always get
  exactly the plain parser's cached answer, making the zero fiber
  order-independent and ~5% faster. 0.9879 / 84.0 / ~1126 ms / 759
  lines, every gate exact, analyzer-clean.
- **c9** (I115–I116): the same algorithm on the data its measured shape
  asks for — 1.7x faster (paired ratio 0.587), judgment bit-identical
  (zero-diff dump), every gate exact. The round began by measuring the
  SHAPE of the hot structures over the whole battery: 71% of cell
  consults see at most one reading (90% at most three, max 52); 80% of
  fold steps hold one partial; and every champion-map insert used the
  stored reading's own `end` as its key. Three changes follow from
  those numbers and account for the whole win: the champion map becomes
  a plain list scanned by `end` (the key was the value's own field);
  a cell's filtered view is cached between changes, and its object
  identity — which now changes exactly when content may — lets a rule
  reference cache its labeled wrapping and revalidate by `identical`;
  and naming moves from per-fill to per-change, applied as the view is
  built (with the packaged plain answers — zero-budget reading, its
  list, a reference's tree wrapper — each built at most once). Two
  "obvious" moves measured backwards and were reverted: judging a
  candidate before allocating it (1.02–1.04x) and reusing cell arrays
  across runs via epoch stamps (1.10x) — Dart's generational GC makes
  young allocation nearly free and charges a write barrier for
  old-space stores, so the fresh-arrays-per-run design c6 chose is not
  a shortcut but the optimum. The per-op campaign around these
  (indexed loops, fold micro-shapes, terminal tweaks) measured ±5%
  with unstable sign: on this engine the representation, not the
  operations, was the lever.
- **c10** (I117–I118): one machine at every budget. The dedicated
  plain parser c9 still carried for the zero fiber is deleted; a
  budget-zero consult runs the SAME costed descent with nothing to
  spend. Three laws make the collapse exact to the tree and the label:
  WITH NO BUDGET LEFT, REPAIR IS PARSING (the zero fiber's one
  PREFERRED reading — greedy demotion strips "the parser's own choice"
  from every reading the greedy parser would not produce — IS the
  plain answer); EACH FIBER OWNS ITS STORE AND ITS CLOCK (budget-zero
  fills the cell's twin, each fiber grows left recursion on its own
  version clock, and ties follow the fiber: the costed search keeps
  the newcomer, the zero fiber keeps the incumbent, because a fixed
  point discards an equal re-derivation); SHARING FOLLOWS THE VIEW
  (every packaged answer is cached by the identity of the view it was
  built over, so the first asker builds it and every later asker
  shares the same object — label sharing is observable, so this is
  correctness, not tuning). Bit-identical trees (zero-diff dump plus a
  node-by-node oracle over all 2101 cases), every gate exact,
  890 → 790 lines (−11%) at a measured ~1.09x paired latency — c9
  keeps the latency point. I118 is the boundary of I116's ledger,
  found by compressing past the knee and bisecting back: routing the
  two per-candidate hot paths (the slot walk, the store's view build)
  through the shared judge — an intermediate list per store, a judging
  cell with its cache bookkeeping per offer — measured 1.18x slower
  end to end (paired ratio 1.30 → 1.57), so those two sites inline
  the rules the helpers state. Young allocation is nearly free; a
  per-offer allocation plus invalidation writes in the innermost loop
  is not just allocation.
- **c10, second pass** (I119): the plain parse is a FACE of each
  construct, not a mode of the search. c10's first cut ran the zero
  fiber through the costed machinery's full shape — a memo cell per
  composite, a list of candidates per consult, a tree translation per
  serve — and measured 1.30x against c9. Instrumented attribution
  (stopwatch around every zero-fiber entry) put essentially the WHOLE
  gap in that fiber: the costed rounds were already at parity. The fix
  is a fiber split inside each construct: `proposePlain` is the
  classic PEG parse — one preferred reading, its finished tree built
  as it returns (`_node`), children consulted through the
  single-reading `plainReading`, no lists between stores — and
  `proposeReadings` is the costed candidate generation; `_grow` fills
  the same cells with whichever face the fiber calls for, and inside a
  twin fill inline composites skip cells entirely, so the zero fiber
  memoizes only at rule boundaries, exactly the plain parser's own
  shape. Readings-with-trees stay sound because in the zero fiber
  every consult is served at most one preferred reading, so every
  chain is deterministic and demotion has already discarded whatever
  the greedy parser would not produce. Bit-identical at every step
  (four gate-verified stages: lean proposals 1.30 → 1.20, cell bypass
  → ~1.17, eager trees → ~1.13, single-reading consults → ~1.09);
  the residual ~9% is the dispatch tax of one machine choosing its
  fiber per consult, below this VM's run-to-run noise. 714 → 790
  lines: the second face costs 76 lines and buys back most of the
  deleted parser's speed.
- **c10, third pass** (I120): the state a variable holds is only real
  if some read distinguishes it. A reachability audit of the engine's
  state cross-product found two collapses and confirmed the rest is
  load-bearing. Landed: `_round` deleted (written everywhere, read
  only to copy into `_budget` — the ladder now loops on `_budget`
  itself), and the per-fiber version clocks merged into ONE
  (bit-identical, gates, ratio 1.073: a cross-fiber bump can only
  force a refill that re-derives the same content, because the plain
  parse is deterministic and a zero cell keeps its incumbent on ties —
  so the stores must be disjoint but the clock need not be). Refuted
  by the oracle: one-sided zeroWraps (769/2101 differ — `_r10`
  compares tree labels by POINTER, so which RuleRef built a shared
  wrap is observable; the dump text stayed identical, meaning the
  two-sidedness exists solely to reproduce c9's first-asker choices).
  That same mechanism analytically refutes deleting the wrap caches,
  un-sharing refView, and merging `_probing` into `_zeroFill` (both
  would shift wrap sides/pointers). 790 → 785 lines.
- **c11** (the code-space study, `c11_study.md`): the pure parser re-run
  under directive sets — uniform-cost search over restarts, no chart,
  the library untouched. It scores 0.9874 / 84.7 with all four gates:
  −0.0005 on score, **+0.7 on coverage** against the c9/c10 plateau,
  which is why it is in the record at all. One structural zero remains
  (i=168, same-cell left recursion — the repair consults (Value,0) while
  that cell is in progress; only a chart serves it). Its veto
  (challenge) directive is free in charge but pays one unit of QUEUE
  ORDER — free in both is a random walk, priced in both loses ties the
  evidence key should decide — with sites read off the returned tree and
  `run.discarded` only where an enclosing match ends at the failure
  frontier, cuts of one repetition never composing, no two consecutive
  vetoes (which bounds vetoes at edits+1 and keeps the charge bands
  finite), and rings admitted in bulk because per-level draining starves
  the far family. Its search needs TWO clocks over one frontier, found
  only after three full batteries: queue-cost bands with the furthest
  parent frontier first before a candidate exists (greedy, so capped
  multi-error searches complete something), charge bands FIFO within
  after one does (the only starvation-free rival hunt — both frontier
  extremes livelocked, 18 regressions near-end and 22 far-end). The
  verdict is the closing sentence of the study: **a restart engine
  re-derives what a chart holds.** Its battery takes ~1,926 seconds
  against c9's 0.6, all of it in a ~30-case cap-out tail. c11 is kept
  as a study and as the source of c12's architecture, not as a
  candidate.
- **c12** (I121, the standing engine): the best of c9, c10 and c11 in
  one file. From c11 it takes the architecture — the published library
  untouched, a separate recovery module consuming library clauses
  natively, so no `_convert.dart` adapter exists for it. From c10 it
  takes the one-machine design and the state-space discipline. From c9
  it takes the measured containers of I115 and the caches that make the
  clean path fast. It is the first engine to break the c6–c10 judgment
  plateau: **0.9896 / 85.8**, substitution 0.988 → 0.997 and misc
  0.968 → 0.969, all four gates exact, 784 lines, and on the paired
  clock at or below c9 on both clean and damaged input. The judgment
  gain is the substitution repair (a wrong character consumed as an
  error span for an exact-text slot); the latency was won back by
  gating where that repair is offered (lessons 22 and 23 above), which
  cost ten lines for the `_resumes` helper against five recovered by
  condensation. Note what the score does NOT say: c12's trees are no
  longer bit-identical to c9's — that invariant ended here, deliberately,
  because c9's substitution reading was the thing being improved on.
- **c13** (the standing engine): c12 plus one rule — the noise-vs-absence
  penalty (a demonstrated deletion nearby prices the "something was
  missing" reading) is EXEMPT at a sequence's LAST slot. The reason is
  jurisdiction: at the last slot, the question of what stood there belongs
  to the enclosing context — the parent's next slot may want exactly the
  character the deletion would consume — and the fold cannot see that far,
  so pricing the absence locally is a guess charged as knowledge. Net
  +0.511 pts over 14 battery cases (10 fixed, 4 broken): 0.9899 / 85.8,
  all four gates, clean path bit-identical, damaged 1.010 vs c12, 786
  lines (+2). The same window attacked the OTHER half of the residual —
  the json string-swallow family (mechanism A) — seven ways and refuted
  the whole line (see the ledger): the swallow signal is not reliably
  computable from reading totals at proposal time, and every detection
  policy fired on the engine's own legitimate accounts.
- **c14** (the standing engine, 2026-09-02): c13's judgment on a bounded
  machine. The round set out to find a revolutionary engine and
  scored its candidates first (per-region rungs, key reorderings, an
  evidence memo on rule wrappers, the library's own memo as the plain
  fiber, and the two changes kept; the ledger records each result). Every
  candidate that touched the judgment scored below c13 — the seven-key
  comparison and the single global frontier are, by the ledger's count,
  at a strict local optimum of this yardstick (§6c's perfect-oracle
  bound of +0.0012 is the headroom that remains and none of it is
  reachable by an ordering change). What the round found instead was a
  bound the battery could not see: the repetition sweep was asking
  each step at the round's whole budget (lesson 24). c14 =
  c13 + that four-line handoff + `_Front` (lesson 26). Battery
  `0.9899 / 85.8`, dump diff against c13 empty, `_accept` ok cx2=1 b1=1
  b2=1, `_freespan` PASS, `_recommit` 16/16, `_conf1` `0 1 1 0 2 3`;
  807 lines (+21); damaged 0.73x c13 paired. Scaling on generated json
  (`_scale14.dart`, `members/errors`, min of two warm runs, ms):

  | chars / errors | c13 | c14 |
  |---|---|---|
  | 354 / 1 (the edit landed harmlessly: cost 0, a clean parse) | 0.47 ms | 0.48 ms |
  | 717 / 1 | 111 ms | 4.9 ms |
  | 1,445 / 1 (two runs) | 1,142 ms; 1,388 ms | 6.9 ms; 7.7 ms |
  | 2,927 / 1 | 16,238 ms | 10.6 ms |
  | 5,962 / 1 | > 300 s (timed out) | 3.6 ms |
  | 24,193 / 1 | > 300 s | 415 ms |
  | 100,075 / 1 | not attempted | 2,497 ms |
  | 1,444 / 2 | 6,306 ms | 21 ms |
  | 5,961 / 2 | > 300 s | 53 ms |
  | 24,192 / 2 | not attempted | 3,326 ms |
  | 100,074 / 2 | not attempted | 2,905 ms |
  | 1,442 / 4 | 112,763 ms | 176 ms |
  | 5,959 / 4 | > 300 s | 728 ms |
  | 24,190 / 4 | not attempted | 28,497 ms |
  | 1,438 / 8 | > 300 s | 3,890 ms |

  Each row is one process per engine pair (`timeout 300`), one warm-up
  call and then the mean over up to 20 calls or one second; "> 300 s"
  means the process was killed before the warm-up call and one timed
  call finished. c13's curve between 717 and 2,927 characters is a
  factor of 10–12 per doubling of length (about n^3.5); the committed
  c13 had no bound on the sweep at all, so the `_c13b` variant timed
  during the round (a step cap, 990 ms at 24k/1) was already far ahead
  of it and is not what the c13 column shows. c14's time tracks the
  error position rather than the length (lesson 27): 5,962/1 is
  cheaper than 1,445/1 because its edit fell earlier in the document.

  and the ablation on top of the budget handoff (four variants
  interleaved, `_scale3.dart`, min of 2):

  | doc | handoff only | + index | + evidence memo | + both |
  |---|---|---|---|---|
  | 100,075 chars / 1 error | 5,031 | 2,269 | 5,129 | 2,012 |
  | 24,192 / 2 | 5,894 | 3,279 | 5,342 | 2,545 |
  | 24,190 / 4 | 92,700 | 25,100 | 87,200 | 26,900 |
  | 5,959 / 4 | 1,032 | 823 | 879 | 951 |

  The evidence memo (a lazy per-wrapper `evidence` field on a `_Node`
  subclass of the library's `Match`) reads within noise of the handoff
  alone in every row and was dropped; its clean-path cost was 1.0–1.09x
  in the wrapper-only form and 1.1–1.3x when every node carried it.
  What c14 does NOT change: no key, no price, no offer site, no gate.

- **c15** (scratch `_c15.dart`, 2026-09-03; not the standing engine):
  c14's judgment on a level-by-level frontier machine — a
  graph-structured stack of frames with a beam of W origins per
  (position, frame shape). Battery equal to c14 to four digits
  (0.9899 / 85.8, 298 imperfect, all gates), 1,018 lines (+211, +26%),
  3.75x slower on the battery's short inputs, linear in the input at
  fixed budget where c14 is ~n^2.6 (24k chars / 4 errors: 10.3 s vs
  26.2 s; 150k: 38 s where c14 would take tens of minutes), ~74 KB per
  character of memory. Lessons 28–32. Why it is not promoted: the
  latency goal is the battery's (short inputs, where it loses 3.75x)
  and its memory ceiling is ~600k characters at four errors; promotion
  is a call on which workload matters, recorded here for the user.
- **c16** (scratch `_c16.dart`, 2026-09-04; not the standing engine):
  c14 with c15's beam of W=8 origins moved into c14's own cells (an
  admission test at the repetition sweep and at every sequence slot,
  keyed by (state, end), judged on the whole-document bill from seven
  scalars) plus memoized plain matches (a suffix-shared chain per
  repetition position, a cached composite match per cell) and an O(1)
  sweep dedup. Battery bit-identical to c14 at every step (0.9899 /
  85.8, 298 imperfect, 0 diff lines, all gates), 1,015 lines (+208,
  +25.8%), 1.38x c14 on the battery's short inputs (683–701 vs 500
  ms), bounded linear at fixed budget: 24k/4 8.8 s vs c14 26.2 s,
  100k/4 12.9 s vs 70.0 s, 150k/4 15.5 s; peak RSS 1.7 GB at 24k and
  3.3–7.5 GB at 100k where c14 takes 4.9 and 13.4 GB. Lessons 33–38.
  Why it is not promoted: the same workload call as c15 (short inputs
  pay 1.38x) and the memory per character is still tens of KB; the
  user decides.
- **c17** (scratch `_c17.dart`, 2026-09-04; not the standing engine):
  c16 with repairs allowed only inside windows opened over the round's
  farthest death, each window walked two evidenced units back per frame,
  and the same budget re-run after every window. 0.9900 / 86.0 (11
  equal-cost tie-break deviations from c14), all gates (recommit 16/16
  once its driver resolved c17, lesson 55), 1,330 lines (+315, +31%
  over c16), 2.3x c14 on the battery; 24k 0.6–1.1 s / 0.4 GB, 100k
  2.3–3.1 s / 0.9 GB, 200k 5.4 s / 1.5 GB. Lessons 39–43. Superseded
  as the scratch candidate by c18.
- **c18** (scratch `_c18.dart`, Codex 2026-09-05, rebuilt with c17's
  documentation 2026-09-06; the scratch candidate, not the standing
  engine): c17 minus the origin beam, with the absorb penalty charged
  only at the root comparison, the plain PEG verdict for predicates, a
  memoized repetition's evidence read off its chain, and a zero-width
  error mark for empty input. Same score (0.9900 / 86.0); 41 weighted
  trees differ from c17 at equal score and five raw cases cost one less;
  all gates and the extra checks; 1,194 lines (−136, −10.2% vs c17;
  +387, +48.0% vs c14); 0.76x c17 on the battery and 1.8x c14; 24k
  0.57 s / 330 MB, 100k 2.75 s / 713 MB, 200k 4.71 s / 1.22 GB, where
  the plain parser alone is 230 MB. Lessons 44–48 and 55. Why it is not
  promoted: the same workload call as c15–c17 (short inputs pay 1.8x
  c14); the user decides.

- **c19** (scratch `_c19.dart`, Codex 2026-09-05; not the standing
  engine): the repair relation as a small addition to the real library
  parser — `Recovery(parser).recover()`, repair bills in side maps keyed
  by MemoEntry identity, no engine-owned plain interpreter. 0.9900 /
  86.1, all gates, **470 lines**, the smallest engine ever at that score.
  But enumeration without locality: 1.9x c18 on the battery and it does
  not finish 24k in 150 s / 7.7 GB. Lessons 49–52.
- **c20** (scratch `_c20.dart`, 2026-09-07; not the standing engine):
  c19's relation on the real parser, c18's windows, and the repetition
  stop prune of lesson 58. 0.9901 / 86.3 — the highest accuracy measured
  — all gates and extra checks, 886 lines (+88.5% over c19, 0.74x c18),
  1.5x c18 on the battery, and 0.9x c18's time at 150k and 200k where c19
  does not run at all. Lessons 56–59. Why it is not promoted: the same
  workload call as c15–c18, short inputs pay about 1.5x c18 and 2.9x c14;
  the user decides.

## 5. What the archived lines taught (details in the attic)

- **dot/m-line** (budgeted deepening over the memo): the budget-horizon
  law; per-round judgment without whole-document rivalry is a ceiling —
  truncation 0.91–0.93, and one unfixable recommit case.
- **r-line** (the chart): simultaneity of judgment — its lasting gift to
  the rank — but the chart re-derives what the parse already knew.
- **b-line** (two-mode commit): D8 is decidable by classes with no
  pricing at all, and greedy commit has a proven 0.88 wall.
- **t-line** (mismatch-tree walking): the latency record (1,170 ms) and
  the proof that the tree's sideways signal is sound — but the tree
  holds each reading's FIRST failure, while recovery's information is
  every REJECTED reading (I98).
- **s-line** (the way-algebra, explicit form): the direct ancestor — the
  c-series is this algebra rebuilt on the grow-loop substrate; on the
  fair battery it holds nothing the c-line lacks.

## 6. The refutation ledger (do not retry without new evidence)

| Claim | Verdict |
|---|---|
| A point window at the death, no walk at all | 0.9665 / 77.5 at 733 lines: the walk is worth 0.0236 and 8.8 perfect |
| Widen the window by doubling on a failed round | 0.9867 / 0.9874 at 742 / 758 lines — better than a point, still short of the walk |
| Walk the frame chain without descending into finished pieces | keeps 0.9900 / 86.1 but the first window is (0, 4077) not (4037, 4077): 24k does not finish |
| Drop `_fresh` (re-enter the piece that ends at the death) | battery IMPROVES to 0.9903 / 86.5, and 150k goes 2.1 s / 797 MB → 29.0 s / 6.3 GB; the battery is short inputs and cannot see it |
| Mark a boundary at every repetition occurrence, lexical included | 0.9805: a per-character scan marks every position, so the window is four characters wide |
| Mark a boundary at each sequence slot end | 0.9893; at each whole-sequence end, `costDiff` 3; at each repetition START, `costDiff` 2 |
| Widen the boundary count instead of capping it | score plateaus at 0.9900 / 86.1 from `back` = 6 and costs 28% more time; the residual gap to the walk is not window width |
| Boundaries from the ordinary parse ALONE, counting back `back` of them | 0.9797 at `back` = 4, 0.9884 at 16, 0.9900 at 64 — and 64 costs 3.7x the time at 24k and 4.5x at 200k |
| Clear the boundary marks each round to keep them local | battery unchanged, and the 47,618-character window survives: the gap is inside one round |
| Enter a death at the granularity of the scan that ends there | battery unchanged, blowup unchanged: the death was not at a scan's end |
| Delete the budget; compute cells once | ~100x latency; the budget is the horizon (A3, twice) |
| Grammar rewriting as the engine's foundation | −0.0008, foreign trees, and the library's LR does the same work (c2) |
| Repetition through its own memo cell | 2,440 vs 1,535 ms, no accuracy change (twice) |
| Greedy commit-one-then-reparse as judgment | the b-line's 0.88 ceiling: the correct choice depends on repairs not yet made |
| Eager trees / ways as materialized trees | +20–31% latency at the tie-refresh volume (I88 ×3) |
| Ties keep incumbents / PEG-first ties | −2.6 to −3.1 perfect; latest-wins stands (×4) |
| The fee ranked below net | breaks the acceptance gate: the b2 fill out-nets its denial and must still lose |
| Universal replace edit (all slots) | zero residual cases fixed, two regressions, 2x latency |
| Per-position version bump with ubiquitous growth | battery timeout; Warth's involved-set is the rule |
| Root simplification (drop owed-admission) | recommit fails: the incoherent honest reading must displace the coherent swallow |
| Prefix-freeze with conditions (non-LR, window, clean) | its consult cost its savings; budget-zero alone is faster |
| Merging `_determined` and `_minFill` | memoizing under a cycle-cut poisons minFill inside LR paths |
| Net crediting bare `Match(null)` spans | re-weights every completion's matched prefix; −3 recommit cases |
| A literal through the memo cell (an anonymous rule) | judgment-identical, +25% latency: front ceremony on every MATCHING literal outweighs caching the failing folds |
| Rank without latest-doubt / without the stranded count | −3.4 / −2.6 perfect (re-measured on c6, post-vouch): both keys stand |
| The stranded count collapsed to a bit | −2.6 perfect, identical to dropping the tier: the count IS the tier (I105, re-confirmed era-3) |
| `spend := edits` (eof claim in the budget) | −0.0019, truncation 0.997→0.990: the additive-ledger law |
| The fee counted as an owe (`fees` into `gap`) | battery-identical, ALL gates green — rejected on the audit identity: a winning fee'd way would report an edit the tree cannot show |
| Literals through the FUSED memo, and the naked version rule | both judgment-identical, both slower: literal fronts +25%; the version rule without the dep bit −13% (cold-starts every same-position cell per growth step) |
| Stateless predicates (delete _Look's front) | judgment-identical, badly slower: the predicate's front was the ONLY cache over its Ref-to-literal sub chain — memo state acts at a distance, and "dead" state can be load-bearing for a different node's latency |
| Composite freeze cached by allocating a front per probed position | a cache whose MISS allocates a front+map at every deny-scan probe costs more than the structural matches it saves |
| The front read-view cache | judgment-identical; unresolved under machine load (paired ratios 1.00±0.10) and dropped — a front stays read-only on reads; retry on a quiet machine |
| The budget watermark folded into the version array | blocked by analysis: atBudget is a >=-ordered clock serving every smaller query; the version is an =-checked clock scoped by usedSeed. One counter cannot express both, and unscoping the version is the −13% naked-version design. The absorbable piece — "never computed" as memoVersion == −1 — was absorbed (judgment-identical) |
| Canonical cell fills (every fill at the round's full budget) | +0.0001 score, 1.6x latency — declined: most cells are only reached by mostly-spent readings, and never exploring deeper than asked is where the time goes. The lazy watermark is the design, now documented with its price |
| The strict zero fiber (budget-zero always answers with the cached plain parse, never the champion map's zero-cost view) | ADOPTED: battery-inert, ~5% faster, and the zero fiber becomes order-independent — the last query-order dependence at budget zero is gone |
| Semi-naive evaluation / avoid re-derivation (the fix BOTH outside analyses converged on) | only 29% of fills re-derive an unchanged value; the other 71% are first derivations no delta scheme can skip |
| Saturation — run each budget's fixed point to completion so rungs start warm | ~7% fewer fills, zero time won: the rung tax is the ladder's shape, not repeated work |
| Compare-before-allocate (judge a candidate from component sums, allocate only on keep) | 1.02–1.04x SLOWER, measured twice (with and without `@pragma('vm:prefer-inline')`): the avoided young allocation was nearly free, and the guard duplicates the sum arithmetic on every keep |
| Cross-run cell reuse (grow-only arrays, epoch stamps, in-place reset instead of fresh allocation) | 1.10x SLOWER: stores into old-space objects pay the GC write barrier fresh young arrays never do; c6's fresh-arrays-per-run is the optimum, not a shortcut |
| The per-op campaign (indexed loops, fold micro-shapes, terminal tweaks) | ±5% with unstable sign under load; representation was the lever (R6–R8, 1.7x), operations were noise |
| Drop the substitution repair entirely (c12) | 0.9885 / 84.4 — fails the perfect bar. The repair is required; only its offer site was negotiable |
| A non-evicting substitution (keep the swap reading beside the incumbent instead of pruning against it) | 0.9895 / 85.6 and no operation count won: eviction was not the cost, the newly opened position was |
| The substitution offered `.penalized()` | 0.9886 / 84.6 — a penalty is not a ranking-only hint; it counts into charge, so it changes what the budget can afford |
| A ranking-only `guess` bit marking swap-derived readings (tried as an early key, a late key, and cleared at construct boundaries) | 0.9891–0.9895 / 85.4–85.6: a large operation cut, but it loses six mid-array-delimiter substitutions that are EXACT ties, which is precisely where a tiebreak bit does damage |
| `(end, guess)` as the per-end pruning key | battery timed out past 600 s (from 0.6 s): two survivors per end is not a refinement, it is a second search |
| Gate the substitution on `slot.text?.length == 1` | holds the record score, but a reproducible ~15% slowdown on the CLEAN path in an A/B/A test, for no damaged gain — the check runs where nothing is damaged |
| Gate the substitution on `deletedAhead < 0` | 85.7 perfect: cheaper than `_resumes` to evaluate and strictly worse at telling a swap from a guess |
| Detect the json string-swallow from reading totals (construct-boundary tax) | 0.9893 / 85.2 + 45 uncovered: the detector fires on intermediate search chains — a chain that later resolves is not evidence |
| The same tax priced only on grammar-literal failures | 0.9859 / 83.4 and ~26x battery time: literal decomposition makes the tax fire per character of every multi-char literal failure |
| Rank-suspect flags, three refinements (`litEvidence` accounting v1–v3) | 0.9843 / 0.9845 / 0.9847 — all WORSE than baseline: the flag condemns c12's own legitimate delete-quote-and-reassociate account; collateral ≥ the ≤+0.005 gain |
| Whole-document scope to judge swallows post-hoc | structurally blind: the swallow's absorbed span (16 chars) never exceeds the honest reading's evidence (23), so the comparison cannot separate them |
| The swallow family itself (charge-1 escape substitution opens a fake string whose `[^"\\]` swallows a member) | RE-DIAGNOSED 2026-08-22 (see §6c): the winning accounts are usually TRUE minimum-cost readings the yardstick penalizes — e.g. deleting one letter makes `""` a legal key at cost 1 where the human's repair costs 2. Not engine failure |
| Hold the ladder one extra rung past first admission, so costlier rivals reach the root | On all four worst json cases the extra rung's root frontier held only same-key duplicates of the winner — no honest rival exists AT THE ROOT at any single extra rung's depth |
| Retain exact-seven-key ties beside cell holders (cap 3/end), letting composition see both | As an engine change: WORSE (imperfect 298→330, mean 0.9896). As measurement: even a PERFECT offline oracle judging every collected candidate reaches only 0.9908 (+0.0012); 12 expr-deletion cases hold a perfect reading the comparator cannot see |
| Price deleted input above inserted text (destruction worse than invention), weights 2 and 3 | 0.9824 / 0.9656 vs 0.9899 — asymmetric pricing collapses insertion AND substitution categories too. Symmetric per-character pricing is strongly optimal under this yardstick |
| Local rungs / per-region budgets (c14 round: each failing region climbs its own ladder, the rest stays at zero) | 0.9875 / 84.7 — to four digits c11's restart number (0.9874 / 84.7), from a different design; a lower-rung reading that died one character short of a wrong family's reach holds the next rung's winner anywhere, so the frontier must be one number. Third refutation of locality; do not retry |
| Swap the order of the seven comparison keys (evidence before cost, and cost before evidence with charge first) | −0.0033 either way |
| An evidence memo on rule wrappers (`_Node extends lib.Match` with a lazy `evidence` field) | ≤11% and inconsistent in sign after the budget handoff; clean 1.00–1.09x (noise); every-node form 1.10–1.32x SLOWER on the clean path. Dropped from c14 |
| The library's parser memo as the plain fiber (consult `lib` for budget-zero answers instead of the engine's own plain memo) | 2.71x slower: the library's memo is keyed for its own left-recursion protocol and answers through a wrapper per consult |
| A per-budget view cache | no effect (the c12 round; re-confirmed as unnecessary once the sweep handoff removed the over-deep fills it would have cached) |
| `_Front` scan limit 8 instead of 32 | slower at 6k chars (map built for constructs that finish scanning), equal at 24k; 32 kept |
| Frontier frames keyed by their whole stack (c15 round, K=∞) | exponential in the open repaired frames: 18,516 shapes at one position of a 1.4k document, 2.99M entries / 8.4 s / 2.7 GB at 64/4, OOM at 24k; 0.9842 |
| Frontier frames keyed by K frames of context and no origin (c15, K=0..4) | 0.9113 / 0.9153 / 0.9332 / 0.9642 / 0.9618 — merging frames that differ in their enclosing context is unsound; the origin (lesson 29) is the key |
| Beam narrower than 8 origins per (position, shape) (c15, W=4/2/1) | 0.9887 / 0.9788 / 0.9290; W=8 equals the exact search on the whole battery |
| Exact origin-keyed frontier (c15, W=∞) | same score as W=8 but Θ(n²) walker readings: 15 GB and unfinished at 24k/4 |
| Beam of 4 origins per (state, end) in c14's cells (c16, W=4) | 0.9890 / 85.3 (333 diff lines); W=8, 16 and ∞ bit-identical to c14, so 8 is the width |
| Drop a repetition's non-greedy ends from the sweep (c16 round) | wrong: a nested construct that closes early needs the shorter end (the early-close case); refuted before measurement |
| Exact per-context refills of served cells as the default (c16) | battery-identical but sign varies by instance: 6.8 vs 8.8 s (24k seed 7), 13.3 vs 8.0 (24k seed 1), 106 vs 32 s (100k seed 2). Kept behind `-DREFILL=true` |
| Evidence memo on library-typed trees alone (an `Expando` on composite matches, c16 round) | never hit: c14 builds a fresh plain tree per call, so there is nothing to remember until the plain match itself is memoized (lesson 35) |
| Beam rows in hash maps keyed by (state, end) (c16 round) | replaced by arrays indexed by state then end; the map lookup was in the admission hot path |
| Timing several rungs in one process (c16 round, method) | invalid: the heap grows to 7 GB and later rungs slow down; one process per rung |
| Contiguous walk of K units across frames for the window (c17, first walk) | window from the death back past an enclosing frame's swallowing last unit: (26775, 150663) at 150k; the per-frame walk with fresh entry (lesson 40) replaces it |
| Leaf-granularity walk, and death-only entry with a shared count (c17) | both lose json 118 (the `[` inside the previous sibling); 0.9900 needs the per-frame spans |
| A 256-character cap on a window (c17) | same battery, a magic number; rejected for the per-frame walk |
| The frame's origin as the edge for a frame that counted no unit (c17) | windows from position 0 ((0, 13979) at 24k, (0, 26813) at 150k); 29 s / 2.08 GB at 24k, 200k did not finish |
| The budget-zero shortcut without noting a death (c17) | the real failure point (23937 on 24k seed 1) never windowed: cost 5 vs c14's 3 (lesson 41) |
| Skip the end-of-input death's window (c17) | 0.9840 / 83.7, 74 cases worse: that walk finds the repair inside a string that swallowed the rest of the input |
| Skip the end death's re-run when the winner has missingAtEnd 0 (c17) | 0.9897, 157 diff lines; the re-run stays |
| Also refuted in the c17 session before the per-frame walk: K other than 2, innermost-walker ownership of the walk, death = no offers, accepting a winner before opening the window, min over frame proposals, a slot as one unit, re-runs without the beam reset, a full reset per window | each lost battery cases or was O(E·n); details in the session transcript named at the top of this file |

| Bucket the repair front by its two equality-class heads (c20) | identical trees, no speedup: battery 1,481 → 1,517 ms, 100k 5,208 → 5,266 ms; the map traffic costs what the skipped comparisons save |
| Reorder `cover` to test the equality-class heads first (c20) | no change (1,495 ms battery, 5,229 at 100k); the cost is the number of insertions, not the price of one (lesson 56) |
| Prune a repetition to its clean stops only (c20) | no effect at all: every reading the prune would have dropped was already clean |
| Prune all short stops on closed ground (c20) | fastest of the criteria (1,862 ms at 100k) but 0.9895 / 85.7 with `costDiff` 8 |
| Keep only the farthest stop per bill (c20) | 0.9898 / 86.0, `costDiff` 8; both ends of the range gives 0.9900 / 86.1 and still loses four `stmt` cases that need an interior stop (lesson 58) |
| Collapse a sequence's equal-end readings and re-run the same budget (c20) | 0.9891–0.9892 and slower on every rung, with or without doubt quantization |
| A separate rule for an absent optional (c20) | no measurable gain on any rung; excluded as unused code |

## 6b. The mechanism-A autopsy (json string-swallow, 2026-08-22)

The residual class: a single substitution inside a json string opens a
fake string literal whose repetition `[^"\\]` then swallows the rest of
the member — including the comma and next key — at charge 1. The honest
reading needs two edits (close the fake string, re-open the swallowed
one), so it costs more and loses the round race; the ladder stops at
budget 1 and never sees it. Root dumps confirmed this exact shape.

Four attack classes, all measured, all rejected:

1. **Tax where the swallow is proposed** (construct-boundary or
   grammar-literal-scoped): fires on intermediate search chains that a
   later budget rung legitimately resolves, or per-character via literal
   decomposition; both cost more than they fix.
2. **Rank suspects below clean readings** (three `litEvidence`
   refinements): cannot distinguish "this reading was reached through a
   swap" from "this reading was reached through an honest deletion" —
   c12's own best account for one damaged case carries the same mark.
3. **Judge whole-document after search** (absorbed-vs-evidence): the
   quantities do not separate — absorbed 16 < evidence 23 on the very
   case that motivates the fix.
4. **Let the ladder climb further**: the general latency problem, already
   measured (c11); not a targeted fix.

The durable lesson is about SIGNALS, not swallows: whether a reading is
a swallow is a property of what its subtree COULD have been under other
edits — counterfactual information that does not exist in the reading's
own totals. Any detector built from totals prices honest repairs too.
A correct signal would need to enumerate the alternative edits, which is
the search itself.

### §6c. The ceiling measurements (2026-08-22)

Three probes bounded what ANY engine under this objective can score:

1. **Extra-rung enumeration**: holding the ladder past first admission
   on the four worst json cases surfaced no rival — the winner's keys
   were duplicated, not challenged. The horizon is not hiding better
   readings one rung up.
2. **Tie-retention + oracle judgment**: keeping every exact-tie reading
   alive through composition and judging all collected complete
   admissions offline: 71 of 330 imperfect cases have a better candidate
   in hand, 12 hold a perfect one; a perfect oracle over the sets scores
   0.9908 vs 0.9896 chosen. That +0.0012 is the ENTIRE headroom of
   arrival-order tie resolution — and it is reachable only with
   knowledge outside the readings (an oracle), so no engine rule can
   take it without pricing something in.
3. **Asymmetric pricing** (deletion costs more than insertion): refuted
   hard (−0.0075 at weight 2). The yardstick rewards structure, but
   symmetric per-character pricing is still the right objective.

And the re-diagnosis that closes the family: inspecting the worst json
cases directly shows the engine returning TRUE minimum-cost accounts.
`{...,"bc":[2,33,tru],d":{...}}` → deleting `d` makes `""` a legal key:
one deletion where the human repair needs two insertions. The battery's
expectation is frequently unreachable at the engine's cost — the residual
there is the yardstick asking for structure the edit metric does not
price, not an engine defect. Under this objective and this yardstick,
c13 sits within about +0.001 of the measurable optimum; further gains
require changing what is priced, not how the search runs.

### §6d. What c13 actually is — and the scalar-DP probe that settled it (2026-08-22)

The design synthesis that closed §6c ended with a sentence worth
correcting in the record, because the mis-naming had a cost:

> the perfect algorithm is the one c13 already is — budget-laddered
> Dijkstra over the grammar×input product graph

**That identification is wrong on both halves**, and believing it is what
made a ground-up rebuild look "score-neutral by construction". It is not
neutral: rebuilt honestly, that description scores **0.5110**.

Why it is not Dijkstra:

1. **No cost-ordered exploration and no certificate.** Dijkstra IS the
   pairing of a global priority queue with the proof that the first goal
   pop is optimal. c13 explores in GRAMMAR order (memoized recursive
   descent) and re-enters from the top with a rising bound; the family is
   cost-bounded iterative deepening. Cost-ordering is recovered only at
   ROUND granularity, which supports the weaker claim "the winner's
   charge does not exceed the first budget at which a coherent account
   survived" — not "no cheaper account exists". The gap is measured, not
   theoretical: best-per-end eviction uses a LOCAL comparator, and before
   I121 it evicted the global minimum (cases 877/1297 returned 2 where a
   1 existed). `_resumes` fixed the observed cases and restored no proof.
   A Dijkstra implementation cannot have that bug class; c13 did.
2. **The weights are not edge weights.** Dijkstra needs fixed,
   non-negative, additive costs. c13's charge is context-dependent three
   ways: `absorbPenalty` is recomputed at every comparison from the
   COMPARING CELL's position; the noise-vs-absence penalty depends on how
   the reading arrived (`deletedAhead`); and c13's own last-slot
   exemption makes it depend on the slot's index in its parent. The same
   reading carries different charge in different places.
3. **The objective is not a path length.** Keys 2–5 (preferred identity,
   evidence, firstDoubt, lastDoubt) are bits and positions, not
   accumulable quantities, and the fold is NON-MONOTONE in its inputs.
   Non-monotonicity rules out the whole Dijkstra/Knuth lightest-derivation
   family, not one implementation of it.

"Grammar×input product graph" is equally off: readings are chains inside
folds with fixed-point growth for left recursion, not nodes of a product
graph. The engines in this project that genuinely were shortest-path over
that graph are the retired agenda engine (Knuth lightest-derivation,
first-goal-pop certified — the one place "Dijkstra-for-grammars" was
accurate) and the c13b probe below.

**The probe (c13b, built and deleted 2026-08-22).** A faithful rebuild of
exactly that description: 2D integer chart `V[clause][start][end]` = min
charge, relaxed to fixpoint (Bellman–Ford flavoured, since the fold is
not monotone enough for Dijkstra's pop order), then a traceback that
rebuilds the tree along the chart's own recorded layers. No reading
objects, no comparator in the search. Measured, all same-session:

| | battery | perfect% | crashed | uncovered | ms | LOC |
|---|---|---|---|---|---|---|
| c13 | 0.9899 | 85.8 | 0 | 0 | 614 | 786 |
| c13b | 0.5110 | 16.9 | 0 | 0 | 54,705 | 807 |

Gates: `_freespan` PASS 5/5, `_conf1` 0 free passes but costs
`0 1 1 0 1 1` against the field's `0 1 1 0 2 3` — the ungated
substitution move ("consume one wrong character as this slot's error")
buys a zero-width `&Kw` predicate for a flat 1 however many edits the
guard really needs. The deficit is UNIFORM across all five damage
categories (0.48–0.56), which is the signature of a missing judgment
rather than a missing repair operator.

So the part of c13 expressible as minimum-cost search over the
grammar×input product graph scores 0.51; **the other 0.48 of the battery
is the judgment** — the seven keys, the evidence filters, the
preferred/plain-parse identity, the jurisdiction exemptions. A traceback
applying all seven keys faithfully would need key-carrying DP states,
which rebuilds c13's cells and comparator inside the chart and dissolves
the "it's just Dijkstra" claim from the other direction.

The accurate one-liner: **c13's cost skeleton is minimum-distance repair
search (the Aho–Peterson kinship is fair THERE); c13's score is its
judgment, and the judgment is not a shortest-path computation.** Say
"budget-laddered cost-bounded search over the grammar, with best-per-end
dominance under a seven-key preference" and the sentence is true.

Two findings from building it that outlive the file:

- **Pad-by-write landmine.** Padding parallel clause arrays by calling a
  set-and-pad helper with `kind.length - 1` OVERWRITES the last-created
  clause's payload. When conversion happens to create a texted terminal
  last (`Top <- V ';'` makes `';'` last), its text becomes `''` — and an
  empty literal matches anything for charge 0, a silent free pass.
  `_freespan` caught it as a uniform want−1 miss. Any constructor that
  pads clause-parallel arrays through a write helper has this bug class;
  check before trusting its costs.
- **Traceback must walk the construction's own tables.** Phase 2 has to
  read exactly the layers phase 1 wrote; every divergence produced a
  silent fallback error span. Seven fixes, all found that way.

Method note: the lesson also applies to this file. An algorithm name is a
claim about a mechanism, and it sets priors — this one predicted a
score-neutral rebuild and was off by 0.48. Name the mechanism, not the
nearest famous algorithm.

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

## 8. The c7→c8 rename map

c8 is c7 with every invented identifier renamed for a reader without this
file's history, and every mechanism documented in the source in plain
language. Original squirrel-parser names (Clause, Match, Seq, First, Ref,
`match`, `inRecPath`, `foundLeftRec`, `memoVersion`, …) were kept or
mirrored. The logic is expression-for-expression identical.

c9 keeps c8's names unchanged, so this map reads onto it directly; the
c9-only additions (`_best`, `_view`, `_maxSpent`, `plain`, `asList`,
`wrapped`, `owner`, `refSrc`/`refView`, `finish`) are documented where
they live in `c9.dart`. c10 keeps the same names again (its additions —
`zeroTwin`, `_zeroFiber`, `_greedyOnly`, the fiber-split version
clocks — are documented where they live in `c10.dart`). c12 keeps them
once more, and adds `Terminal.picky`, `_readSlots`, `_resumes`,
`preferred` and `spent`, each documented at its definition; c13 keeps
c12's names unchanged (its one addition is a local boolean).

**Classes**

| c7 | c8 | meaning |
|---|---|---|
| `_Way` | `_Reading` | one candidate way of reading a span, with its repair bill |
| `_Cap` | `_Labeled` | a construct's name wrapped around its children |
| `_Front` | `_RepairCell` | best reading per end position at one (node, position) |
| `_PCell` | `_ParseCell` | plain-parse memo entry (tree + left-recursion state) |
| `_N` | `_Node` | grammar node base class |
| `_Comp` | `_MemoNode` | a node whose repair results are memoized |
| `_Seq` | `_Sequence` | sequence |
| `_First` | `_Choice` | ordered choice (`/`) |
| `_Rep` | `_Repeat` | repetition (`*`/`+`) |
| `_Opt` | `_Maybe` | optional (`?`) |
| `_Look` | `_Lookahead` | `&X` / `!X` |
| `_Ref` | `_RuleRef` | reference to a named rule |
| `_Term` | `_Leaf` | terminal base class |
| `_StrN` | `_Literal` | multi-character literal |
| `_CharN` | `_OneChar` | single exact character |
| `_SetN` | `_CharClass` | character class, possibly negated |
| `_AnyN` | `_Wildcard` | `.` |
| `_NothingN` | `_Empty` | matches the empty string |

**`_Way`/`_Reading` fields and methods**

| c7 | c8 | meaning |
|---|---|---|
| `del` | `deleted` | input characters skipped as noise |
| `gap` | `missing` | required pieces absent before end of input |
| `oweN` | `missingAtEnd` | required pieces absent at the cut-off |
| `net` | `evidence` | characters matched by picky matchers |
| `key` | `firstDoubt` | position of the first repair, or a clean sentinel |
| `fees` | `penalties` | tie-losing charges that are not edits |
| `owing` | `endsIncomplete` | something required is missing exactly at `end` |
| `what` | `piece` | what this step contributes to the tree |
| `tail` | `prev` | the reading up to the previous step |
| `edits` | `cost` | total bill (end-of-input charged once) |
| `spend` | `spent` | the budget-counted part of the bill |
| `peg` | `preferred` | the plain parser's own choice |
| `free` | `clean` | no repairs at all |
| `ate()` | `absorbPenalty()` | +1 for absorbing more than it proved |
| `_Way.unit` | `_Reading.empty` | a reading of nothing |
| `_Way.skip` | `_Reading.deleting` | delete a span as noise |
| `over()` | `withTree()` | carry a finished tree as the piece |
| `capped()` | `labeled()` | wrap under a construct's name |
| `fee()` | `penalized()` | one more penalty point |

**Cells, node methods, engine**

| c7 | c8 | meaning |
|---|---|---|
| `_by` | `_bestByEnd` | the champion map |
| `at` | `atBudget` | budget the cell was computed at |
| `ver` | `memoVersion` | position-version stamp (mirrors the library) |
| `dep` | `usedSeed` | computation read a growing seed |
| `inPath`/`foundLR` | `inRecPath`/`foundLeftRec` | mirrors the library's MemoEntry |
| `res`/`way`/`has` | `tree`/`reading`/`computed` | parse cell contents |
| `ways()` | `readings()` | a cell's/node's candidate readings |
| `go` | `findReadings` | per-kind implementation behind `readings` |
| `freeze` | `cleanReading` | the plain parse as one reading |
| `peek` | `cellAt` | the repair cell if it exists (never allocates) |
| `det`/`detGo` | `hasOneShape`/`computeOneShape` | only one tree shape possible |
| `fill`/`fillGo` | `minChars`/`computeMinChars` | fewest characters a match consumes |
| `pin` | `picky` | terminal accepts only specific characters |
| `owe` | `recordMissing` | the "it was missing" reading |
| `expand` | `proposeReadings` | one candidate-generation pass |
| `seedAt` | `isGrowingAt` | back-edge into a growing cell |
| `row` | `cells` | the per-position cell array |
| `pure` | `parseCell` | the rule's plain-parse memo entry |
| `grow` | `_grow` | the repair fixed-point loop |
| `fold` | `_readSlots` | the slot-by-slot sequencing engine |
| `_rank` | `_compare` | the five-key reading comparison |
| `_prune` | `_bestPerEnd` | keep the best reading per end |
| `_netOf` | `_evidenceIn` | evidence in a finished tree |
| `_node`/`_build` | `_treeOf`/`_buildTree` | winner-only tree construction |
| `_conv` | `_convert` | library clauses → engine nodes |
| `_in`/`_n` | `_input`/`_len` | the input and its length |
| `_run` | `_runId` | per-input generation stamp |
| `_pver`/`_rver` | `_parseVersions`/`_repairVersions` | the two version arrays |
| `_sawSeed` | `_seedWasRead` | the upward involved-set signal |
| `_fill` | `_minDocLen` | shortest accepted document (search bound) |
| `_far`/`_peg` | `_clean`/`_chosen` | the two firstDoubt sentinels |
| `_never` | `_impossible` | minChars for "cannot match" |
| `lit:` | `insideLiteral:` | `_readSlots` flag for the replace repair |
