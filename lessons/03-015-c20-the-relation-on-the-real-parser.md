<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c20 — the relation on the real parser, and the stops the input dictates (2026-09-07)

56. **The cost of a Pareto front is the number of insertions, not the
    price of one comparison.** The 100k profile put `_Front.add` at 23.5%
    inclusive, and two attempts to make the scan itself cheaper both
    failed: splitting the buckets by the front's two equality-class heads
    (`incomplete`, `missing == 0`) gave identical trees and no speedup,
    because the map traffic cost what the skipped comparisons saved, and
    reordering `cover` to test those two heads first changed nothing.
    Attribution by site then found a single sequence slot iterating over
    **118,911** alternative readings on one 100k input, which is where the
    time actually was.

57. **After one repair inside a repetition, every later item end is a
    distinct reading the front cannot compare away.** `_repeat` returns
    one prefix per iteration end, and the sequence around it reads its
    next slot at every one of them. The front separates readings by where
    they end and never compares two that end apart, so a bill that has
    paid once is carried unchanged to every subsequent stop and none of
    them dominates another. Of 848,478 readings reaching the prune,
    **91% were kept only because they had already paid for a repair.**
    This is the mechanism behind the c19 line's memory and latency, not
    the enumeration of repairs itself.

58. **Keep the stops the input dictated, and the prune is exact.** Record
    the positions where the walk *ran out* — the body could not be read
    again from there, so the walker stopped because the input told it to —
    and keep exactly those, plus every position under doubt, plus the
    farthest the walk got. A block's statements stop where the closing
    brace is because no further statement can be read there, and that is
    the stop the enclosing sequence needs. Front insertions fall from
    7.89M to 2.79M, 79% of repetition readings are dropped, the worst
    slot's alternatives fall from 118,911 to 28,233, and 100k goes from
    5,208 ms / 1,042 MB to 2,778 ms / 899 MB — with the battery trees
    bit-identical to the unpruned engine (both `treeDiff` 1882,
    `costDiff` 1 against the c17 reference). Four cheaper criteria were
    measured first and each cost accuracy: all short stops on closed
    ground (0.9895 / 85.7, fastest at 1,862 ms), the farthest stop per
    bill (0.9898 / 86.0), both ends of each bill's stop range (0.9900 /
    86.1). The four cases that separated them were all `stmt`, all a stray
    character inside a nested block, and each needed an *interior* stop on
    closed ground — the repetition has to be allowed to end where the
    enclosing block's closing brace sits.

59. **`treeDiff` and `costDiff` print 0/0 unless the literal word
    `compare` is on the command line.** Without it the battery driver
    never loads the reference dump and reports no differences at all,
    which reads exactly like a tree-identical result. Every "identical
    trees" claim in this round was re-taken with the argument present;
    against the c17 reference, c18 is 41/1, c19 is 1888/1 and c20 is
    1882/1, so a large `treeDiff` here means "differs from c17", not
    "differs from its own unpruned form".

**c20 as measured.** c19's repair relation (a Pareto front of numerically
incomparable bills per end position) attached to the real `peg.Parser`,
plus c18's locality windows, so a repair is tried only at open positions
inside a window over the round's farthest death, plus lesson 58's prune.
Battery **0.9901 / 86.3** in 1,471–1,496 ms, the highest accuracy of any
engine measured (c18 0.9900 / 86.0 in 986–989 ms; c19 0.9900 / 86.1 in
1,628 ms). All four gates: accept `cx2=1 b1=1 b2=1`, freespan `3 3 4 4 1`,
recommit 16/16, conformance `0 1 1 0 2 3`, `cleanTreeDiff=0`; 2,728
property checks with 0 violations; `_pred18` cost 1, falseAssertions 0
(matching c18, where c14 and c17 each have 1); `_dominance18` equal to c18
on all three arms including the `xabcdY` eviction that c14 and c17 fail.
Rungs, same machine, one process per rung, peak RSS from `/usr/bin/time`,
c18 first and c20 second: 24k seed 1 509 ms / 325 MB / cost 3 against
650 ms / 354 MB / cost 5; 24k seed 7 847 / 320 / 4 against 615 / 339 / 4;
100k seed 2 2,225 / 711 / 4 against 2,702 / 898 / 4; 150k seed 7 2,755 /
813 / 4 against 2,142 / 797 / 4; 200k seed 7 3,812 / 1,210 / 4 against
3,466 / 1,257 / 4. The cost-5 result at 24k seed 1 is the same before the
prune and is a property of the c19 lineage, not a regression from it.
Lines: c19 470 → c20 **886** normalized (+416, +88.5%), which is 0.74x
c18's 1,194 and 0.67x c17's 1,330, and 1.10x c14's 806. An alternative
that quantizes doubt to the left edge of its open run (`qf` inside
`cover`) reaches 2,073 ms / 760 MB at 100k but costs the tie-breaks:
0.9901 / 86.0 with `treeDiff` 1916. It is not the installed engine.

**c20 after the size round (2026-09-07).** The stack walk is gone; the
window's left edge counts back `back` = 4 marks in `_bound` (where the
repair search finished an evidenced, non-lexical repetition occurrence)
and may not reach past `wide` = 64 marks in `_plainBound` (where the
ordinary parse finished one). A death is an `int`. Lines **886 → 742**
normalized (−144, −16.3%; 677 raw code lines, 232 comment lines), which
is 1.58x c19's 470. Battery **0.9899 / 86.1** in 1,364–1,395 ms against
the walk's 0.9901 / 86.3 in 1,500 ms, `costDiff` 1 for both against the
c17 reference; case by case, 7 worse and 4 better, all 11 at equal cost.
All four gates: accept `cx2=1 b1=1 b2=1`, freespan `3 3 4 4 1`, recommit
16/16, conformance `0 1 1 0 2 3`, `cleanTreeDiff=0`; 2,728 property
checks, 0 violations; `_pred18` cost 1, falseAssertions 0. Rungs, written
as the driver argument `nodes/errors/seed`, one process each, peak RSS
from `/usr/bin/time`, boundary walk first and stack walk second:
`1000/4/1` (23,568 chars) 440 ms / 311 MB / cost 4 against 503 / 329 / 4;
`4000/4/2` (97,688) 1,359 / 624 / 4 against 1,534 / 647 / 4; `6000/4/1`
(147,054) 2,642 / 957 / 4 against no answer in 400 s at 14.9 GB;
`6000/4/3` (147,078) 5,646 / 1,467 / 6 against 2,913 / 1,003 / 4;
`6000/4/7` (147,105) 2,647 / 925 / 4 against no answer in 400 s at
11.2 GB; `8000/4/1` (196,441) 3,253 / 1,117 / 4 against 3,599 / 1,230 / 4;
`8000/4/7` (196,515) 3,724 / 1,263 / 6 against 4,111 / 1,303 / 6.

**60. The window's left edge is a count of finished occurrences, so it
    does not need the stack that produced them.** c20's window walked
    back through the live frames when a reading died: `_claim` unwound
    `back` evidenced units, `_units` descended into finished pieces,
    `_fresh` re-entered a piece that ended at the death with its own
    count, and `_atomic`/`_atomicPiece` decided per piece representation
    what counted as a unit — 227 raw lines and two copies of the same
    logic, one per piece representation. The only thing that walk
    computes is a position: where the last few proven occurrences began.
    A repetition already knows when it has finished an occurrence, so
    marking `_bound[end]` there and counting back over the marks gives
    the same edge without the stack. That deletes `_claim`, `_units`,
    `_fresh`, `_atomic`, `_atomicPiece`, `_startOf` and the `_Death`
    class (a death is now an `int`), and costs nothing on price: against
    the walk, 7 battery cases score lower and 4 score higher, every one
    of the 11 at identical repair cost — a tie-break in tree shape, not
    a worse repair.

**61. Marks made only by the repair search are marks only where doubt
    has already been.** The first boundary build marked `_bound` solely
    in `_repeat`, so the marks lay wherever the search had iterated. Text
    the ordinary parse read cleanly is answered from a memoized cell and
    never iterated, so it carries no marks at all. When the death then
    moves to a region the search has not walked, the four nearest marks
    can be a whole document behind it: measured, a window of 47,618
    characters at budget 2 on a 147k input, which does not terminate in
    400 s. Clearing the marks each round does not help — the gap is
    inside one round, not across rounds. The fix is a second array,
    `_plainBound`, marked from the ordinary parse's own occurrences,
    which is complete everywhere; the walk may not reach back past
    `wide` of them. `wide` is the smallest value that leaves the
    battery's repair cost unchanged: 32 gives `costDiff` 3, 64 and 128
    give 1, and the scale cost rises with it (147k seed 3: 4.3 s at 32,
    5.6 s at 64, 64 s / 4 GB at 256), so it is a bound on the search,
    not a tuning knob.

**62. The cost grows with the number of repairs, not the length of the
    input, and that is an unsolved problem, not a property to accept.**
    Measured on the installed engine with `_time20.dart`: at four errors
    the document length is nearly free — `1000/4/1` (23,568 characters)
    0.44 s, `8000/4/7` (196,515) 3.7 s — while at fixed length the error
    count is not: `1000/4/1` 0.44 s, `1000/8/1` 10.2 s, `1000/12/1` no
    answer in 120 s. Per rung of the ladder on `1000/12/1` the round
    times are 70, 57, 73, 155, 180, 477, 1250, 3148, 20157, 25094 ms,
    about a factor of 2.5 to 3 per rung, so the whole run is roughly the
    fourth to fifth power of the number of repairs. Instrumented, the
    fills per round stay near 30,000 and the open positions grow
    linearly (144 to 988), but the readings proposed per fill go 0.7,
    1.3, 3, 2, 9, 23, 35, 125, 240, 370: the growth is entirely in how
    many readings a cell hands back, not in how often it is asked.
    Inside the widest bucket at rung 10 (377 bills reaching one
    position) there are 59 distinct cost tuples, 113 distinct pairs of
    doubt positions and 10 distinct evidence values.

    Five attacks on that growth, all measured, none sufficient:
    (a) a hard ceiling on how many bills one end position keeps (8, by
    the acceptance order) leaves the battery bit-identical and cuts the
    work 30 % — the buckets are rarely that wide, so it is not the
    exponent; evicting a bill AFTER inserting it also stops `_read`'s
    fixed point from ever settling, because the evicted bill is proposed
    again on the next pass and reports progress forever, and every scale
    rung then spins at flat memory. (b) Dropping the doubt positions
    from the covering relation cuts the widest bucket from 377 to 115
    and makes `1000/12/1` finish in 103 s, but 16 errors still do not,
    and it costs two points of perfect. (c) Quantizing the doubt
    positions to the window they fall in gives 0.9894 / 85.4 and no
    scale gain. (d) Giving each window its own spending allowance,
    clamped inside the sequence fold, prices 54 cases wrong, because a
    cell filled under a clamp is cached as if it were complete; making
    the allowance a second ladder inside the budget instead keeps every
    price (`costDiff` 1, as it must: no complete reading exists one rung
    down, so every winner of the accepting rung is charged exactly the
    budget and the inner ladder can only choose among equals) but pays
    for the extra rounds — 8 errors 22 s against 10 s. (e) Confining the
    `_stops` prune's open-position exemption to the window the reading's
    own doubt lies in is bit-identical on the battery and gains nothing
    at scale.

    What the measurements say the fix must be: the front carries the
    running totals for the WHOLE document, so the number of ways to
    divide those totals grows with the number of errors, wherever they
    sit. No local prune changes that. Bounding it means not carrying
    global totals — pricing a window and committing it before moving on
    — which is a different engine and revives the greedy-commit family
    refuted at c1/b2 (0.8826), now with windows and deaths available
    that generation did not have.

**63. A rung recorded as "150k seed 7" is not a rung anyone can re-run.**
    The c20 figures below were written with the document size as a
    character count and the generator arguments left out. `_time20.dart`
    takes `nodes/errors/seed` and `makeDoc(6000, 4, 7)` produces 147,105
    characters, but the engine that produced the battery figures
    recorded here (verified: it still scores 0.9901 / 86.3) cannot
    finish that rung in 400 s, and at `1000/4/1` it answers cost 4 where
    the record says cost 5. So the recorded specification does not
    identify the input. Every rung in this section from here on is
    written as the literal argument passed to the driver.

**64. Three of the eight heads in the covering relation were doing no
    work.** Folding `owed` and `fee` into one head, and then `missing`
    with them, leaves the battery BIT-IDENTICAL (0.9899 / 86.1,
    `treeDiff` 1888, `costDiff` 1) — the four currencies were never four.
    Separately, `first` is two things at once: at or above `_clean` it is
    the reading's rank, below it the position where doubt began. Keeping
    only the rank, and letting the position decide between bills that
    cover one another both ways (the relation's existing "equal
    summaries replace the tree" rule, unchanged), scores 0.9901 / 86.0
    against 0.9899 / 86.1 — a better score for a smaller relation, all
    four gates, 2,728 property cases 0 violations, and the same rung
    times. Which rule breaks the tie is worth 2.4 points of perfect on
    its own: keeping the incumbent gives 83.6, choosing by the
    acceptance order 84.1, choosing by the position rule directly 84.1,
    and replacing gives 86.0.
