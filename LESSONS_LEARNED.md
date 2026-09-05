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
lessons, and the refutations that must not be retried. Everything else — the
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

## 2. The standing table (era-3 battery, 2026-08-21)

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
    already in the row updates its bill in place. Same bound as c15
    (at most W live readings per (state, end) per budget, so
    O(|G|·W·n) per rung), 1.38x on the battery instead of 3.75x
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

38. **At fixed budget c16 is bounded linear in the input, and the
    constant is set by the error configuration, not by n.** json
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

43. **At fixed budget c17 is linear in the input with a small
    constant, and the peak memory is the plain parse's.** json
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
