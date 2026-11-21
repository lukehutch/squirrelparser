<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The machine, fifth look — what the c17 round measured (2026-09-04)

The round's question was the user's again: c16's 15.5 s and 4.21 GB
on a 150k input are unacceptable. c17
(`dart/experiments/recovery/_c17.dart`, scratch, 1,330 lines vs c16's
1,016 and c14's 807) is c16 with repairs confined to WINDOWS: spans of
the input around the positions where readings died. Battery 0.9900 /
86.0 against c14's 0.9899 / 85.8, with 11 deviations from the c14
dump, every one an equal-cost tie-break (4 worse: expr 656, 673, 669,
670; 7 better: expr 690, 694, 671, 999, 689 and json 572); all four
gates (`_accept17` ok cx2=1 b1=1 b2=1, `_freespan17` all clear,
`_recommit17` 0 of 1 discard, `_conf117` the six probes right).

39. **Repair only where the parse died, and let the ladder discover
    the deaths one at a time.** A repair action (delete ahead, mark
    missing, substitute) is tried only at an open position. A reading
    with no clean continuation notes a death at its end, a root
    reading that stops short notes one at its end, and the round
    keeps the farthest. When that death lies outside every window the
    ladder opens its windows and re-runs the SAME budget before
    accepting a winner — a winner found so far may only have got past
    that point on the free end-of-input reading. Windows persist
    across budgets, so each distinct death costs one re-run. Outside
    the windows every cell is the plain parse, computed once
    (`atBudget` unlimited), and a cell is refilled only when a window
    opened after its fill meets its span (`_stale`). At fixed budget
    that makes the work proportional to the windows, not the input.

40. **The window is walked per frame, two evidenced units back, and
    the unit that ends at the death is entered fresh.** The left edge
    walks `back` = 2 evidenced units from the death through the frames
    on the stack (a walker's occurrences count one each, a sequence's
    slots are expanded through their pieces). A non-atomic unit that
    ENDS at the death holds the failure's own context, so it is
    entered with a fresh count of two and closed as a span of its own;
    the enclosing frame then counts the units BESIDE it. The first,
    contiguous walk made the window run from the death back to two
    units before an enclosing frame's last unit — when that unit was
    an unclosed object that had swallowed the rest of the document,
    the window was (26775, 150663) at 150k. A frame extends the edge
    to its own origin only if it counted at least one unit: the fold
    of the top rule, whose chain before the slot the death is inside
    is only whitespace, was extending every window to position 0
    ((0, 13979) at 24k, 29 s and 2.08 GB).

41. **A plain parse that fails at budget zero is a death, and only a
    fill can say where.** The budget-zero shortcut served the plain
    parse's readings without noting a death, so the walker's failing
    occurrence attempt (the item fold that consumed `,` and then found
    `k` where a member's `"` had been deleted, position 23937) was
    never a death; the enclosing fold noticed the failure one position
    earlier (23936) and the window stopped there. c17 paid 5 on 24k
    seed 1 where c14 pays 3. A cell whose plain parse has no reading
    is now filled once at budget zero (no repair is possible at zero,
    so the content equals a fill at any budget outside a window) and
    still answers with the plain readings alone.

42. **Windows cost re-runs, and on short inputs the re-runs are the
    latency.** Battery 1.15 s vs c14's 0.50 s (2.3x; c16 1.38x). An
    instrumented run puts 0.20 s in first rounds and 0.91 s in
    re-runs: 6,223 rounds for 2,463 budget rungs over 2,101 cases. A
    typical one-error case runs budget 1 (dies, no window), re-runs
    with the window (wins, and the winner's readings die at the end),
    opens the end-of-input death's window and re-runs once more. That
    last re-run is required: without it 0.9840 / 83.7 (74 cases worse
    — the walk from the end death is what finds the repair inside a
    string that swallowed the rest of the input), and skipping it
    only when the winner has missingAtEnd 0 still moves 157 dump
    lines (0.9897). On long inputs a re-run is cheap (only stale
    cells refill), which is why the same mechanism wins there.
    Clearing the beam rows touched instead of reallocating the beam
    per window saved 50 ms of the battery.

43. **c17 substantially improves the measured long-input rungs.**
    Neither a worst-case linear bound nor equality with plain-parser peak
    memory follows from these measurements. The plain parser alone (the
    frozen library, `_plainrss.dart`, 2026-09-06) peaks at 230 MB of RSS
    at 24k, 100k and 200k alike, the VM's floor, in 31–43 ms, so c17's
    0.4–1.5 GB is recovery memory; the retained-origin audit is lesson
    46. json
    `makeDoc` documents, four errors, one process per rung, peak RSS
    from `/usr/bin/time`, same session:

    | chars (seed) | c17 | c17 RSS | c16 | c14 |
    |---|---|---|---|---|
    | 1,442 (7) | 0.15 s | 234 MB | 0.36 s, 276 MB | 0.18–0.27 s |
    | 5,959 (7) | 0.57 s | 324 MB | 0.75 s, 428 MB | 0.73–0.78 s |
    | 24,190 (7) | 1.09 s | 364 MB | 8.8 s, 1.68 GB | 26.2 s, 4.9 GB |
    | 24,162 (1) | 0.62 s | 397 MB | 8.0 s, 1.76 GB | 54.6 s |
    | 100,072 (7) | 2.49 s | 864 MB | 12.9 s, 3.33 GB | 70.0 s, 13.4 GB |
    | 100,060 (2) | 3.10 s | 912 MB | 32–35 s, 7.45 GB | killed at 550 s |
    | 100,041 (3) | 2.26 s | 849 MB | 26 s | — |
    | 150,663 (7) | 3.86 s | 1.09 GB | 15.5–16 s, 4.21 GB | — |
    | 150,606 (1) | 2.99 s | 933 MB | 17.7 s | — |
    | 201,260 (7) | 5.36 s | 1.53 GB | 146.9 s | — |

    25–45 µs and about 7.5 KB per character. Costs equal c16's (= c14's)
    on every rung, and the edits are identical on 24k seed 1 (c14's
    three insertions, where the first c17 paid 5), 100k seeds 2 and
    3, and both 150k instances. At 200k one insertion differs: a `}`
    deleted at 42565 is put back at 42565 by c17, while c14 and c16
    put it at 165527, the latest point that still parses (the
    later-doubt preference, both cost 4) — a window cannot reach the
    position c14 prefers, and the generator's own position is c17's.
