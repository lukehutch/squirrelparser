# My own position, written before Codex's reply arrived

Recorded so the comparison required by the standing directive is genuine and
not retrofitted after reading Codex. Committed before its output was available.

## (a) Is there a two-mode formulation that avoids the chart's fill cost?

**My answer: no, and the reason is that the property the chart buys is one the
top-down search already has.**

The chart's promise is that no cell is ever recomputed. That is only worth
paying for if cells *are* being recomputed. Measured, they are not:
`calls/cell` is **1.00 at p50** and 1.28x aggregate, and the 1.28 is the LR
fixpoint, not redundancy — `_fix` already memoizes per (clause, pos, budget).
The measured worklist floor is **1.97 relaxations per cell** (m51), so a chart
re-relaxes *more* than the search it replaces. There is no waste to recover.

The chart's price, meanwhile, is unconditional: m132 touches **13.9 chart
columns at p50** of |G| = 105, at **3.2%** repair-cell density. A chart fills
100%. The trade is roughly 31 to 1 against before any constant factors.

The two ways to bound the fill are both refuted by measurement rather than
taste. A DP wavefront forward from the failure point searches the wrong
direction — repair sites are **100% at-or-before the frontier, 0% after**,
median 13 characters to its left, p90 37. And a healthy-suffix anchor to close
the window against exists in only **167 of 598** cases, bracketing every site
in 49.1% of those.

A seeded Pika sweep — the fixpoint restricted to the cells the top-down search
actually demanded — is the strongest surviving version, and it still loses, for
the first reason: those cells are already computed once each, so the sweep adds
the 1.97 relaxation floor and buys nothing.

**What the sweep genuinely knew that top-down did not was one thing: what lies
to the right.** And the only place that knowledge changed an answer was the
place where the answer is *nothing lies to the right* — end of input. Top-down
gets that for free with a length comparison, which is I81. I claim the
right-to-left advantage on this workload is fully harvested by I81, and the
remaining 266 mid-input zero-width nodes are not defects but correct namings of
slots whose evidence the damage destroyed (m142 measured what deleting them
costs: perfect% 69.2 -> 67.5).

**Falsifiable form:** if a seeded right-to-left sweep over only the demanded
cells beats m143 on latency at equal score, I am wrong. m141 is the unseeded
version of that experiment and lost 17.8x.

## (b) Where do 200+ lines come from to reach the <400 goal?

**My answer: they cannot, under the fold the brief asks for, and this is
arithmetic rather than engineering.**

The instruction was to carry a copy of the parser and memo table into every
engine and then count the whole file. **That fold was never done for this
engine line** — m143, m132, m121 and m78 all
`import 'package:squirrel_parser/squirrel_parser.dart'`; only m69 and m70 ever
contained a `class Parser`. So m143's **628** is a recovery-only figure being
compared against a whole-file target.

The tracked copy `_core.dart` is **490 lines**. Folding it in puts m143 at
roughly **1118** whole-file, and makes under-400 arithmetically impossible
(floor = 490 + recovery). The honest options are therefore:

1. Keep the current convention (engines import the library) and treat <400 as a
   target for the recovery code alone — m143 is at 628 against it, so 228 lines
   must go.
2. Complete the fold as instructed and retire the <400 target as unreachable,
   replacing it with a recovery-only budget.

This is a call for the user, not for me. It is flagged rather than silently
resolved, and the current numbers are stated for what they are.

Within option 1, where I would actually look for the 228 lines, in order of
expected yield: the witness machinery (`_solveWitnesses`, `_visitWitness`,
`_witness`, `_need`, lines 464-596 — roughly 130 lines serving one purpose);
the seven-level `_better` key, where earlier occasions already showed some
levels are dominated by others; and the `_Way` list algebra (`_at`, `_put`,
`_admit`, `_extend`, `_possessive`), which is a hand-rolled Pareto frontier
that may collapse now that I78 refuses `net == 0`. I have not measured any of
these, so they are candidates, not claims.

## (c) When is I81 the wrong call?

**My answer: I could not construct a case, and I tried by building the
grammars rather than reasoning about them (`_i81probe.dart`).**

The guard has four conjuncts: the node covers zero characters; it asserts no
character anywhere beneath it (`_asserts` recurses, so a `Filled` descendant
protects it); its position is at or past `input.length`; and the cost-0 memo
admits no zero-length reading of that clause there.

The last conjunct is the escape hatch, and its soundness rests on `_pure`
computing the cell on demand rather than reporting empty for one the cost-0
pass never visited. It does: `_pure` forces `_budget = 0` and goes through
`_fix(_pc, ...)`, which computes and memoizes. So an unvisited cell cannot
produce a false "hollow".

Four adversarial grammars, three built so a named rule legitimately matches
empty at end of input:

    KEEP  Tail <- (',' Item)*   empty by construction   kept
    KEEP  Opt  <- 'x'?          optional                kept
    KEEP  Rest <- [0-9]*        star                    kept
    DROP  Num  <- [0-9]+        cannot read empty       m132 emits it, m143 drops

All four behave as intended.

**The attack I would make if I were arguing against myself:** the rule is
decided at *emit*, not during the search, so a hollow node cannot influence
which repair wins — only how the winner is rendered. If two candidate repairs
tie on the key vector and differ only in a hollow node, the tie is still broken
by the old key, and I81 then deletes the node from whichever won. That is
harmless for score but means I81 is a rendering rule wearing the clothes of a
semantic one. Moving it into `_beats` would make it semantic; I have not
measured whether that changes anything, and I expect it is worth ~0.

**The known cost, stated plainly:** 5 of 1792 cases get worse, all `expr`, and
on every one m143's tree is the *more* faithful — the flat skeleton edit
distance pays for m132's invented node because its label coincides with an
outer wrapper both engines fail to emit. That is an evaluator artifact worth
0.0002 against I81's +0.0045.
