<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
