<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c19 — attach the relation, keep the ordinary verdict (2026-09-05)

49. **The architecture can be a small addition to the actual library.**
    `_c19.dart` implements `Recovery(existingParser).recover()` with repair
    relations in side maps keyed by real MemoEntry identity. Ordinary answers, assertions and terminal
    matching use that same Parser and unchanged input. A repair relation has
    its own growth/version clock: the frozen scalar MemoEntry loop cannot
    hold a set of ends/bills in its `result`. Clean input returns the original
    root object with zero recovery relations. Unchanged subtrees are shared;
    no engine-owned plain interpreter or converted clause hierarchy remains.
    Size: **470 normalized code lines**, versus c18's 1194; not yet under 400.

50. **Lazy attachment is not selective demand within a relation.** c19
    delays expansion until a `(clause, position, budget)` asks, then still
    enumerates that budget's alternatives. No window or beam is used.
    Weighted 0.9900 / 86.1%; raw 0.9916 / 87.8%, all crash/coverage/bill audits
    zero. Acceptance, freespan, recommit 16/16 and conformance pass, as do
    the three c18 counterexamples and 2728 property checks, now including
    preservation of the ordinary memo verdict. The archived charge check
    gives `0 0 0`; committed gives `[2..3, 3..4] OK` (substitution plus tail
    deletion, not the old r-series error list). Native same-end successes
    exclude repaired rivals as a freespan **policy**, not a dominance theorem.

    Five-round paired damaged latency is **1.892x c18 / 1.487x c17**.
    Clean c19/native is 0.999 in a separate paired control: attachment itself
    adds no resolved cost in that sample, although c19 is ~1.54x c18/c17 on
    their different plain interpreters. At 5959 chars / four errors / seed 7,
    c18/c19 take 447/2443 ms and 316538880/629432320 bytes peak process RSS.
    Final c19 times out at **45 seconds on 24190 characters**; the audit let
    it run, over 150 s and 7.7 GB peak RSS (lesson 55). This establishes
    a code-size reduction, not the sought scalable recovery algorithm.

51. **An ordinary match is safe proof, not automatically a safe repair seed.**
    `_c19seed.dart` starts the repair fixed point with the complete native
    match. Gates pass, but weighted score falls to 0.9898 / 85.9%. The selected
    c19 keeps proof and repair seed separate. The inferred issue is that
    choice admission observes the preferred readings already present; the
    full operator is not made monotone by a numeric Pareto front. The next
    unresolved mechanism is end/continuation-specific demand with a justified
    exclusion law, not merely another container for all affordable readings.
    `_C19_FINDINGS.md` records implementation anchors, controls, limitations
    and reproduction commands. No existing engine was replaced.

52. **Inspecting a native LR tree must not restore input-depth recursion.**
    c19 initially overflowed at 8193 characters in `_ev`, the evidence walk,
    not in the frozen parser. An explicit postorder stack fixes that probe:
    cost 1, full coverage, 17716 ms / 1640722432 B peak process RSS. It adds
    12 normalized lines (458 to 470). The high time/memory still indicts
    enumeration; fixing a tree visitor does not establish scalable recovery.
