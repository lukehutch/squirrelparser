<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The machine, fourth look — what the c16 round measured (2026-09-04)

The round's question was the user's: take c14 and stop its worst
cases from degrading past quadratic, given that the pika parser shows
recovery is possible in O(|G|·n). c16
(`dart/experiments/recovery/_c16.dart`, scratch, 1,015 lines vs c14's
807, +208, +25.8%) is c14 with c15's beam moved INTO c14's cells, plus
the plain-match memos c14 never had. Battery bit-identical to c14 at
every step (0.9899 / 85.8, 298 imperfect, 0 diff lines against the
c14 dump), all four gates (`_accept` ok cx2=1 b1=1 b2=1, `_freespan`
PASS, `_recommit` 16/16, `_conf1` `0 1 1 0 2 3`).

33. **The beam belongs in the cells, not in a new machine.** c15 paid
    3.75x on short inputs for a frontier machine whose only new idea
    was the beam of W origins per (position, shape). c16 keeps c14's
    recursive descent, memo cells and sweep, and adds one admission
    test at the two places a reading is offered to a best-per-end
    list: the repetition sweep (state = the repetition, end = the
    reading's end) and the sequence fold (state = the sequence and
    slot, end = the reading's end). A row per (state, end) holds at
    most W=8 origins, judged on the bill of the WHOLE document prefix
    (`ctx.plus(r)`, the context handed down the stack); a newcomer
    replaces the worst only when strictly better, and an origin
    already in the row updates its bill in place. This was claimed to give
    the same bound as c15, O(|G|·W·n) per rung; the c18 audit refutes the
    retained-origin premise (lesson 46). The measured result was 1.38x
    on the battery instead of 3.75x
    (c14 500 ms, c16 683–701 ms, three same-session pairs), and the
    battery is bit-identical at W=8, W=16 and W=∞; W=4 changes it
    (0.9890 / 85.3, 333 diff lines), as in c15.

34. **Both offer sites need the beam; the walker's alone leaves the
    fold as the growth site.** With the beam only on the repetition
    sweep, the 100k rung was still spending its time in `_readSlots`
    (22M fold offers at 100k, seed 2) because a sequence slot re-walks
    every continuation of every reading the fold still holds. The
    fold beam keyed by (sequence, slot, end) with the sequence's own
    position as origin closes it. Admission is judged from seven
    scalars (`_Beam`: charge, first doubt, evidence, last doubt,
    missing at end, deleted, missing) computed from the context and
    the reading; no `_Reading` is allocated per offer, and a row
    caches the index of its worst member until the row changes.

35. **The plain match was the quadratic tail, and it was hiding
    behind the repair.** c14 rebuilds a repetition's plain match from
    every start it is asked at, re-walking the suffix each time, and
    the evidence count walks the whole rebuilt tree: 48M characters of
    evidence walk at 100k/4 before the fix. c16 memoizes the plain
    match per position in the repair cell (stamped with the position's
    parse version, the same staleness rule as `Rule.parseCell`) as a
    suffix-shared chain (`_RepMatch`: head match, next, evidence), so
    the match from position p is the head at p plus the memoized match
    from the next position, O(1) after the first walk, with the
    evidence carried on the chain. Composite plain matches are cached
    the same way (the cell's `plainList`). The evidence walk no longer
    appears in the profile.

36. **The sweep's "changed" list must be a set, and a pass stamp per
    index is the cheap set.** `List.contains` on the changed list was
    12.8% of the 100k seed-2 run; a per-index stamp of the pass that
    last changed it makes the dedup O(1).

37. **Exact refills are correct and not worth it.** c14 serves a cell
    computed under one context to every later asker. Refilling when a
    strictly better prefix asks is exact per context and battery-
    identical, but its sign varies by instance (24k seed 7: 6.8 s with
    refills vs 8.8 s without; 24k seed 1: 13.3 vs 8.0; 100k seed 2:
    106 vs 32 s). Off by default, `-DREFILL=true` restores it.

38. **c16's rungs grow about linearly with n at fixed budget, but the
    bound argued for it is refuted.** The O(|G|·W·n) argument rested on
    at most W retained origins per (state, end); lesson 46 measures 13
    with W=8, so the linear growth in the table is an observation over
    these instances, not a proven bound, and its constant varies strongly
    with the error configuration. json
    `makeDoc` documents, four errors, one process per rung, peak RSS
    from `/usr/bin/time`, same session:

    | chars (seed) | c16 | c16 RSS | c14 | c15 W=8 |
    |---|---|---|---|---|
    | 1,442 (7) | 0.36 s | 276 MB | 0.18–0.27 s | 0.40–0.48 s |
    | 5,959 (7) | 0.75 s | 428 MB | 0.73–0.78 s | 1.34 s |
    | 24,190 (7) | 8.8 s | 1.68 GB | 26.2 s, 4.9 GB | 10.3 s, 3.3 GB |
    | 24,162 (1) | 8.0 s | 1.76 GB | 53.2 s | — |
    | 100,072 (7) | 12.9 s | 3.33 GB | 70.0 s, 13.4 GB | 32.3 s |
    | 100,060 (2) | 32.1 s | 7.45 GB | killed at 550 s, 31.4 GB | — |
    | 150,663 (7) | 15.5 s | 4.21 GB | — | 37–38 s, 11.1 GB |

    Per character 0.13–0.36 ms; the 100k instances of seeds 1/2/3
    take 28 / 32 / 26 s and the 24k instances of seeds 1–5 take
    4.4–13.3 s, so a factor of three between instances of one length
    is normal (clustered errors and unterminated strings cost the
    most). Where the time goes at 100k seed 2 (CPU profile,
    `_prof16.dart`): `_admit` 18%, `_Reading.then` and allocation,
    `_Reading.plus` once per sweep step (9.2M steps), 3.5M cell fills
    (35 per character). Memory is the open problem: at 24k seed 1 the
    live heap is 1.49 GB — 5.8M `_Reading` (555 MB), 3.1M `_Beam`
    (247 MB), lists 350 MB, 544k `_RepairCell` (78 MB) — and 100k seed
    2 needs more than 3 GB live (a 3 GB old-generation cap dies
    silently there). Roughly 30–70 KB per character, against c15's 74
    and c14's 130 at 100k. The readings are still the memory, as in
    c15; the next reduction is sharing or dropping the `_Reading`
    chains of evicted beam members, not the time. Stats mode
    (`-DSTATS=true`, on `_c16inst.dart`) is 3–4x slower and its times
    must never be compared with plain runs; several rungs in one
    process inflate the heap to 7 GB and slow the later rungs, so
    every number above is one process per rung.
