<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The machine, second look — what the c14 round measured

24. **Every fold hands its children the budget its prefix has not
    spent, and a fold that forgets is a bug the battery cannot see.**
    `_readSlots` has always handed each slot `whole − r.spent`. The
    repetition sweep did not: it asked every step at the round's whole
    budget, so a step whose prefix had already spent an edit was
    explored one rung deeper than any reading through it could afford.
    The battery was bit-identical either way — the extra readings are
    all pruned at the parent — so nothing in the judgment measured it.
    What measured it was recursion depth: `_grow` nested 107, 464 and
    1,159 frames deep on json documents of 1.4k, 6k and 24k characters
    with one error (1,568 at 6k/4), because each over-deep step
    re-entered the sweep at the next member. With the four-line
    handoff (save the budget, hand `whole − r.spent`, restore) depth is
    27–47 frames at every length: the nesting of the grammar, not of
    the document. Work at 24k/1 fell from about 990 ms to 420 ms; at
    6k/4 from 18.6 s to 0.7 s; at 24k/4 c13 could not be timed at all
    (a cold, unoptimized first call overflowed the Dart stack at
    6k chars / 2 errors). The rule: wherever a reading continues
    through a child, the child is asked at the reading's remaining
    budget, never the round's.

25. **Recursion depth is a measurement, not an implementation
    detail.** A depth that grows with the input says a bound is
    missing — the grammar's nesting is the only legitimate source of
    depth in a memoized engine, and it is constant per grammar. The
    instrument is a wrapper around `_grow` that records the deepest
    chain (`_depth.dart` over an instrumented copy). Two consequences
    for the harness: any timing run that includes a pre-c14 engine must
    warm on a small document first (the JIT-compiled frames are smaller
    than the interpreter's, so the same call overflows cold and
    succeeds warm — an "intermittent" crash that is not intermittent),
    and a scaling table must be read alongside the depth, since a
    superlinear time curve and a linear depth curve have the same cause.

26. **Whether a best-per-end list should be scanned or indexed depends
    on the construct's width, so the container decides at runtime.**
    A repair cell keeps one best reading per end position. Under the
    battery (documents of tens of characters) a construct holds a
    handful of ends and a linear scan is the cheapest thing there is —
    the c9 round's lesson stands. But a repetition over a
    3,000-member json object holds a reading per member boundary, and
    the scan is then quadratic in the document. `_Front` scans while it
    holds at most 32 entries and builds an end→slot map the moment it
    grows past that; it is the only `Map` in the engine (every slot
    structure is a `List`). On top of the budget handoff, indexing
    alone is worth 2.2x at 100k/1 (5.03 → 2.27 s), 1.8x at 24k/2 and
    3.7x at 24k/4 (92.7 → 25.1 s); on the battery it is neither
    measurable nor charged (the threshold is never crossed). A scan
    limit of 8 lost to 32 at 6k chars, where the map's construction
    cost is paid for constructs that would have finished scanning; both
    read the same at 24k.

27. **The cost of a recovery scales with the position of the error,
    not the length of the document.** Instrumented fills on json with
    one error: 304 fills for an error at character 79, 59,000 for an
    error at 15,317, about 3.9 fills per character BEFORE the failure
    point and none after it. The reason is exactness, not waste: the
    failure point is not the error point (a deleted comma is noticed
    at the next key), so the budget-b pass must explore the b-edit
    variants of every construct before the failure, which is where the
    error might be. After the failure everything is read at budget
    zero, from the plain memo, once. This is the shape of the engine's
    cost and it is the right shape — an engine that explored only near
    the failure would be locality, and locality was refuted a third
    time this round (ledger: per-region rungs score exactly c11's
    number, because the frontier is one number and the lower-rung
    reading that died one character short of a wrong family's reach can
    hold the next rung's winner anywhere).
