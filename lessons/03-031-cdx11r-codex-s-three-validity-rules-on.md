<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cdx11r — Codex's three validity rules on cdx11o: invalid trees 12/11/11/19 → 6/7/6/17 at the same speed (2026-09-23)

**Codex round 3 (`total_stage`, re-measured here as `cx3ts`)** adds three rules to cdx11l:

1. **Outside a finished left-recursive cell, a clean reading is the plain one
   or is demoted** (`_outer`). A clean way whose end differs from the PEG
   answer's end is kept but demoted, and the plain answer is always offered.
   Deleting such ways instead (cdx11m) raised 173 costs, because later repairs
   build on them.
2. **A Ref admits a reading that matched input**, `end - pos > deleted`,
   instead of one with literal evidence.
3. **First: `reach` includes the arm's plain end, and the choice stops after an
   arm that cannot fail** (`_total`: an Optional, a `*`, or a Seq of such; a
   left-recursive Ref is exempt, since it fails as a seed).

Measured (orchestrator's kit, confirmed): cx3ts battery 0.9900/84.3, treeDiff 1,
costDiff 0 against cdx11o; all checks pass; fuzzer invalid 6/7/6/17 against
cdx11o's 12/11/11/19; cdx11o pays more than cx3ts in 8/6/7/2 cases, cx3ts pays
more in 0/0/0/1. 875 LOC (it was built on cdx11l).

**cdx11r (untracked `_cdx11r.dart`) is cdx11o plus these three rules.** One
detail matters: the read of an ACTIVE cell (the recursive read during growth)
must stay `_view`, not `_outer`; growth needs every stage. With `_outer` there
too (cdx11p, cdx11q) the battery falls to 0.9881/83.3, 14 costs rise. With
the absorption charge (J) or `_oneShape` (H) put back, nothing changes, so
neither was the cause.

Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, treeDiff 0 and
costDiff 0 against cdx11o, treeDiff 1 against cx3ts; accept t/t/t, freespan
3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props
2728/0, window P at every n, pred 0; fuzzer identical to cx3ts on seeds 1–4
(invalid 6/7/6/17, worse 0). Rungs (ms): 1000/1/1 325; 8/1 667; 16/1 1,750–1,776;
32/1 3,543–3,551; 64/1 4,239; 128/1 10,529; 4000/4/2 1,213; 8000/4/7 2,494;
8000/32/7 13,065. The 16/1 and 32/1 rungs were re-run alternating with cdx11o
and cx3ts: all three within 5% (a first reading of 5.0 s was noise).
LOC 803 → 837 normalized (+34, +4.2%).

**Not a counterexample to sealed sharing:** `S <- ('a' ',')* 'b' 'a'` on `a`
costs 3 edits in every engine since c14, where inserting `b` at 0 costs 1.
Missing characters at end of input are one completion (`owed`), so both
readings have charge 1, and `_compare` prefers the later first edit. The same
holds for every EOF case tried.
