<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
