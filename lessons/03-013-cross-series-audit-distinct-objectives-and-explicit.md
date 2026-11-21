<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Cross-series audit — distinct objectives and explicit test sets (2026-09-06)

53. **A smaller engine is not necessarily a faster or lighter engine.**
    The common c1–c19 comparison in §2 confirms c19's 724-line reduction
    against c18 and three extra perfect cases, but also 1.91× battery time,
    5.49× time and 2.02× peak process RSS on the common 5,959-character probe.
    c14 is the short-battery speed point; c18-envelope is the measured
    accuracy point; neither fact establishes the requested all-criteria
    optimum. Keep accuracy, clean/damaged latency, size, memory and
    conformance separate. A single memory rung is not a complexity bound.

54. **“All gates pass” must name the test set and the grammar being checked.**
    All twenty entries pass the four ordinary groups, yet c2/c11 fail the
    separate committed-prefix check, and only c11/c15/c18/c19/envelope pass
    the extra greedy-predicate example. c2's normalized `#0` references
    also expose an audit trap: a frozen-parser lookup error on a foreign
    clause is not evidence that recovery crashed. The original predicate
    is demonstrably false where c2's returned tree claims it. Check
    original-grammar meaning, distinguish harness errors from engine
    failures, and retain counterexamples beyond the scored battery.
