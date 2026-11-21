<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
