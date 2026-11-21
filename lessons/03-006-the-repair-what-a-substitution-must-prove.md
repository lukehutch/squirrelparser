<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The repair — what a substitution must prove (the c12 round)

22. **A swap the rest of the sequence cannot read from is a guess, not a
    substitution** (I121). The replace repair consumes one wrong
    character in place of an exact-text slot. Offered unconditionally it
    is also the entire damaged-latency cost of the c12 design: compiled
    out, c12 was already cheaper than c9 on every hot damaged case. It
    is expensive for a structural reason, not a constant-factor one —
    each swap resumes at `end + 1`, a position the search would
    otherwise never visit, so the memo misses cascade downstream (2.8x
    the propose calls on the worst case), and because per-end pruning
    picks its survivor with a LOCAL comparator, a swap-derived reading
    can evict the chain that would have finished more cheaply and buy a
    whole extra budget round. The gate is the price of belief:
    `_resumes` requires the remaining slots to read cleanly from just
    after the swap and prove something, or the sequence to end there.
    −27% `then` calls, battery bit-identical, damaged 1.06x → 0.98x.
    The general form: a repair that opens a position no clean reading
    reaches must justify that position, or it pays for the whole
    subtree the search then has to explore.

23. **Where a repair is OFFERED is a design axis, not a detail.** The
    same substitution rule, unchanged in what it costs or what it
    accepts, measured 1.198x, 1.110x, 1.06x and 0.98x purely by moving
    and gating its offer site: from `Terminal.findReadings` (fired at
    every failing picky terminal) into `_readSlots`; then restricted to
    a clean prefix; then to a PREFERRED prefix with budget room; then
    to slots the sequence can resume past. Every one of those four
    tightenings held the battery bit-identical. A repair's expense lives
    in how often it is proposed, not in what it does when it wins.
