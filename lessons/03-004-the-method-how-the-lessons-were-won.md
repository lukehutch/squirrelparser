<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The method — how the lessons were won

15. **The yardstick is a design object** (I107). A battery that scores
    coin flips or post-cut structure measures tie-luck. Curate mutations
    to what a human could arguably answer, and make every
    expectation-change in the open.

16. **Keep gates the metric cannot see.** The battery is blind by
    construction to free-span deletion and prefix re-reading — it once
    rewarded +0.0020 for exactly the behavior `_freespan` exists to
    forbid. And a gate must be checked to be checking: the era-3
    curation accidentally emptied freespan's probe list, and every
    "pass" until the restoration was vacuous. Verify the gate fails for
    a known-bad engine.

17. **Domination is arithmetic; ablation is measurement.** Compute the
    frontier (`pareto.py`), never eyeball it — the hand-kept list was
    wrong twice the same way. Every kept mechanism carries the number
    that keeps it (the size floor is a measurement, I104); every removed
    one carries the number that killed it (the ledger below).
