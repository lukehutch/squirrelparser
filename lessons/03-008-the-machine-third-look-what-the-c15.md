<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The machine, third look — what the c15 round measured (2026-09-03)

The round's question was the user's: a recovery whose cost cannot grow
faster than O(n^3) in the input, ideally the pika-style bound O(|G|·n)
memo entries per budget. c14's cost at four errors grows as about
n^2.6 (26–28 s at 24k characters) because its per-(clause, origin)
cells keep one reading per END: a list walker entered at ~1,900
origins holds thousands of ends each, so the memo is Θ(n²) readings.
c15 (`dart/experiments/recovery/_c15.dart`, scratch, 1,018 lines vs
c14's 807) is the same judgment on a different machine.

28. **The exact optimum under this cost model needs Θ(n²) walker
    summaries; the beam over origins is the approximation, and W=8
    of it loses nothing the battery can see.** c15 runs one level per
    budget (Dijkstra by characters spent), over hypotheses (frame
    shape, start, reading so far, running totals, origin). Frames are
    a graph-structured stack: a push entry per (position, rule or
    sequence shape) holds its parents and its best completed reading
    per end; a new parent is linked and replayed; a completion is
    recorded once and stepped into every parent. A node per (position,
    shape) keeps one entry per ORIGIN (the push entry the frame walks
    for), at most W of them; the worst is evicted only by a strictly
    better newcomer. With W=∞ this is c14's cells in stack form (exact,
    same score, out of memory at 24k/4 like the full-context build).
    Battery, all at 0 diff lines from the previous run:

    | W | battery | imperfect | 24k/4 |
    |---|---|---|---|
    | ∞ (exact) | 0.9899 / 85.8 | 298 | OOM (15 GB at 73 s) |
    | 8 | **0.9899 / 85.8** | 298 | **10.3 s, 3.3 GB** |
    | 4 | 0.9887 / 85.3 | 308 | — |
    | 2 | 0.9788 / 81.3 | 392 | — |
    | 1 | 0.9290 / 67.3 | 688 | — |

    W=8 and W=∞ produce the same imperfect-case dump (diff empty apart
    from the timing line); all four gates pass at W=8 (`_accept` ok
    cx2=1 b1=1 b2=1, `_freespan` PASS, `_recommit` 16/16, `_conf1`
    `0 1 1 0 2 3`). Case-wise against c14: 57 cases lower (weight
    0.966), 51 higher (0.949) — every one checked is an equal-cost tie
    resolved by arrival order (both engines keep the first reading
    among equal keys), e.g. `a+b*2(3+)*4` and `3z3` in a json array.

29. **Keying a frame by its whole stack is exponential in the number
    of open repaired frames; keying it by nothing is unsound; the
    origin is the key that is both.** With K frames of context in the
    key and no origin (measured before the replay fix of lesson 31, so
    all understated): K=0 0.9113, K=1 0.9153, K=2 0.9332, K=3 0.9642,
    K=4 0.9618, full stack (K=40) 0.9842 — but the full stack held
    18,516 distinct shapes at one position of a 1.4k document (2.99M
    entries, 8.4 s, 2.7 GB) and could not finish 24k. Merging frames
    that differ only in what encloses them is wrong because the
    enclosing frames price the continuation differently (a member
    walker inside a swallowed string is not the member walker of the
    honest object). The origin — the push entry the frame walks for —
    is exactly the enclosing context the price depends on, and there
    are at most W of them per (position, shape).

30. **A rule re-entered at the position where it is already open must
    link to the open frame, not push a new one — for left recursion
    AND for the end of input.** Two infinite zero-cost chains stalled
    the first build: `Term` re-entering itself at one position of
    `(a*b+(c*d)-(e+f)` (227 frames deep, level 0), and
    Value→Object→Member→Value→Array→… at the end of `{"t":[1}` (each
    frame costing only missingAtEnd, which `spent` does not count).
    Both are the same fact: an open frame of the same rule at the same
    position already represents every reading the re-entry could
    produce. The re-entry links to it (a cyclic stack) and is exempt
    from the delete-ahead penalty until the seed completes.

31. **In a stack whose entries carry a mutable best hypothesis,
    "already linked" says nothing about what the CURRENT hypothesis
    has seen: replay on every link.** The 0.9834 → 0.9899 gap of the
    first working build was one early return. A frame re-expanded at a
    later level with a better hypothesis re-linked to the push entry it
    had linked at the previous level, found itself already among the
    parents, and skipped the replay of that entry's completed
    readings — so `{"t":[flase]}` (Boolean via one delete + one
    insert, cost 2) completed up to the top Value and never reached
    the root, and the level-3 string swallow won. Replay is idempotent
    through keep-best, so the fix is to replay unconditionally. Found
    by tracing every step and offer that spans the whole document:
    the reading arrived at the seq frame and the WS step after it
    never printed.

32. **At fixed budget c15 is linear in the input and c14 is not; below
    ~10k characters c14 is 1.5–4x faster.** json `makeDoc` documents
    with four errors, one process per rung, same session (c14 via
    `_rung14.dart` over `_c14prof.dart`):

    | chars | c15 W=8 | c14 | c15 peak RSS |
    |---|---|---|---|
    | 1,442 | 0.40–0.48 s | 0.27 s | 344 MB |
    | 5,959 | 1.34 s | 0.78 s | — |
    | 24,190 | 9.9–10.3 s | 26.2 s | 3.3 GB (c14 4.9 GB) |
    | 100,072 | 32.3 s | not run (n^2.6 extrapolates to ~1,100 s) | — |
    | 150,663 | 37–38 s | — | 11.1 GB |
    | ~600k | killed at 35 GB | — | — |

    0.25–0.41 ms and ~74 KB per character at budget 4. Battery
    (short inputs): c15 1.8–1.9 s vs c14 0.49 s. Recursion depth of
    the step cascade is 5 at every rung (`maxDepth`), and no entry is
    ever queued behind the level's position sweep (`backward` = 0 on
    every run; a backward enqueue would be lost silently, because the
    sweep visits each position once per level). Census at 24k/4:
    3.05M entries (126 per character), 8.0M offers, 14.4M readings
    constructed, 1.82M nodes, 5.3M deliveries, 101k evictions. The
    readings are the memory; the next reduction is there (drop the
    `prev` chain from evicted entries, or share totals), not in the
    table. The ~1 KB per live entry and 600k-character ceiling on a
    64 GB machine are the open problem, not the time.
