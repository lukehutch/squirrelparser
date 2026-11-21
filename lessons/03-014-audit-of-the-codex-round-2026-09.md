<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Audit of the Codex round (2026-09-06)

55. **A scored dump that agrees is not a tree that agrees, and a driver
    that prints UNKNOWN has not run.** Codex's c18 was rebuilt from
    `_c17.dart` by seventeen asserted text replacements (`mk18.py` in the
    session scratchpad) so that c17's documentation survives and the
    class names stay public (`Squirrel`, `Clause`, `rules`); Codex's file
    is kept as `_c18codex.dart`. `_treecmp18.dart` walks both engines'
    trees (clause, position, length, children) plus `lastCost` over all
    13,241 raw cases: rebuilt c18 against Codex's, 0 tree and 0 cost
    differences; c18 against c17, 146 trees and 5 costs differ (41 of the
    2,101 weighted cases, every one at equal score), and all five costs
    are c18 = 1 against c17 = 2: the single deletion in
    `["epsilon"},"zeta"]` and its kin, which c17 lost while the absorb
    penalty was still charged inside the sequence (inferred from the
    change list; not traced case by case). The earlier record that
    "c18's dump equals c17's" compared only the scored dump, which prints
    cases scoring below 1.0. `_recommit17.dart` and `_recommit18.dart`
    imported `_score16.dart`'s resolver, so they printed UNKNOWN for c17
    and c18: the "0 of 1" recorded for c17 was never a run. With the
    import fixed, c17 and c18 each pass 16/16. Gates on the rebuilt c18:
    accept ok cx2=1 b1=1 b2=1, freespan pass, recommit 16/16, conf1
    `0 1 1 0 2 3`, 2,728 property checks with 0 violations, `_pred18`
    falseAssertions=0 at cost 1, `xabcdY` cost 2 (c14 and c17: 3).
    Same-day timings, one process per rung, peak RSS from
    `/usr/bin/time` (this machine ran about 10% slower than in the c17
    session): battery c18 1,059–1,099 ms, c17 1,350, c14 601; 24k seed 1
    0.57 s / 330 MB, cost 3; 100k seed 2 2.75 s / 713 MB, cost 4; 200k
    seed 7 4.71 s / 1.22 GB, cost 4 (c17 in its own session: 0.62 s /
    397 MB, 3.28 s / 922 MB, 5.37 s / 1.53 GB). Lines: c17 1,330 → c18
    1,194 (−136, −10.2%); c14 807 → 1,194 (+387, +48.0%).
    `loc.normalised` returns (raw, normalized) pairs, as its docstring
    says; reading them the other way round produced a false "c19 is 388
    lines" during the audit. c19 is 470 normalized (388 raw: `dart
    format` unwraps its long lines). Envelope at 100k seed 2: 15.4 s /
    1.08 GB, and on a 2.5M-character document 62.6 s / 13.3 GB; c19 at
    24k seed 7: over 150 s and 7.7 GB. Standing: c14 stays the standing
    engine; c18 replaces c17 as the scratch candidate for long inputs
    (0.76x c17's time, 0.8x its memory, one better cost) at 1.8x c14 on
    the battery's short inputs, so promotion remains the workload call.
