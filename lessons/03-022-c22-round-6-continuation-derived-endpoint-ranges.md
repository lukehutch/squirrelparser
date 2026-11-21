<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
