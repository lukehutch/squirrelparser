<!-- Part of LESSONS_LEARNED.md, section: 2. The standing table (era-3 battery, 2026-08-21) and the c-series comparison (2026-09-06) -->
[Back to the index](../LESSONS_LEARNED.md)

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
