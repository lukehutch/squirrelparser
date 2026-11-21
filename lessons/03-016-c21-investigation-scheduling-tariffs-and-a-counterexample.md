<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
