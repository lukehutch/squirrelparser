<!-- Part of LESSONS_LEARNED.md, section: 6b. The mechanism-A autopsy (json string-swallow, 2026-08-22) -->
[Back to the index](../LESSONS_LEARNED.md)

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
