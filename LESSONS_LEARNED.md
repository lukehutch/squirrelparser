# PEG Error Recovery — the living record

Seventy-odd engines across six architectural lines were built, measured, and
archived to reach the six that remain: the c-series, one algebra refined six
times. This file records the yardstick, the standing results, the critical
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

## 2. The standing table (era-3 battery, 2026-08-06)

| Engine | Score | Perfect% | ms | LOC | Gates | truncation | deletion | insertion | substitution | misc |
|---|---|---|---|---|---|---|---|---|---|---|
| **c8** | **0.9879** | **84.0** | ~c7 | 755 | all | **0.997** | **0.984** | 0.993 | **0.988** | **0.968** |
| c7 | 0.9879 | 84.0 | 1112 | 692 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |
| c6 | 0.9879 | 84.0 | 1180 | 707 | all | 0.997 | 0.984 | 0.993 | 0.988 | 0.968 |

c8's latency could not be resolved against c7: the measurement session ran
under external machine load ~33, where paired interleaved ratios read
1.00 +/- 0.10. Its changes are allocation-neutral-or-better by
construction; re-time on a quiet machine before quoting a number. c8's
higher line count is the readability rename (section 8): longer names
wrap more lines; the logic is expression-for-expression identical to the
pre-rename c8 (verified by a zero-diff battery dump).

Both rows are the FUSED engine — the full squirrel parser folded in, so
each is self-contained and its LOC includes the whole parser (~246 lines);
the pre-fold, library-dependent c6 measured 461 lines and ~1,500 ms. c7
dominates c6 (identical judgment, one left-recursion law, 5% faster,
15 lines smaller), so c6 is archived as its measured twin. c7 also now
holds the all-time latency point: t1's 1,170 ms record falls, at +0.06
score. The c1–c6 ancestors and every other line are archived with their
last numbers in the attic (`attic/OLD_LESSONS_LEARNED.md`).

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
  plain language in the source, judgment re-verified identical.

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

## 7. Where things live

- The engine: `dart/experiments/recovery/c8.dart` — self-contained (the
  full parser folded in; the published library contributes only the
  interchange types, and `lib/src` performs no recovery). `c7.dart` is
  the pre-audit twin, kept until c8's latency parity is confirmed on a
  quiet machine.
- The harness: `dart/test/recovery/` — battery + scoring
  (`astdiff.dart`), runner (`_score1.dart <engine> [dump]`), the four
  gates (`_accept.dart <engine>`, `_freespan.dart`, `_recommit.dart`,
  `_conf1.dart`), and size (`loc.py`).
- Archive: `dart/experiments/recovery/attic/` (~320 files: c1–c6, the
  s/r/m/t/b lines, ~900 scratch probes, `pareto.py` — retired when one
  engine remained — `libsrc_recovery/`, and the old lib-recovery tests);
  the era-1/era-2 record and the era-3 archive in
  `attic/OLD_LESSONS_LEARNED.md`.

## 8. The c7→c8 rename map

c8 is c7 with every invented identifier renamed for a reader without this
file's history, and every mechanism documented in the source in plain
language. Original squirrel-parser names (Clause, Match, Seq, First, Ref,
`match`, `inRecPath`, `foundLeftRec`, `memoVersion`, …) were kept or
mirrored. The logic is expression-for-expression identical.

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
