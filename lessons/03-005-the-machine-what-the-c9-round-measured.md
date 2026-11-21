<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

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
