<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### x445zzo, x451y - rounds 44 and 45: a 297-line engine scores as sk10p does, and with x44ma's quality changes ported (x451y, 330 lines) it beats sk10p on battery, fuzzer and rung costs (2026-10-10)

Round 44 gave nine agents one axis each, all starting from sk10p, and an
independent checker re-measured each agent's best engine. Seven of the
nine agents were stopped once or more by the usage limit and resumed from
their notes; a2 (a cheaper comparison than `_wins`), a4 (every input
finishes) and a9 (ideas from other fields) never finished, and the checks
of a5 and a8 did not run. Round 45 gave six agents one axis each on
x445zzo; only q1 (quality) finished before the weekly limit, and its
checker confirmed every number.

Round 44 results (confirmed by the checker unless marked):

| Engine | Axis | Lines | Battery | Worse/better vs sk10p | Fuzzer worse, invalid (8 seeds; sk10p in brackets) | 64/1 cost | Verdict |
|---|---|---|---|---|---|---|---|
| x441aj (a1) | unify candidates | 480 | 0.9794 | 14/17 | 22 (16), 96 (89) | 68 | not adopted |
| x443xp (a3) | speed | 531 | 0.9801 | 0/0, treeDiff 0 | 0 (0), 89 (89) | 68 | speed only |
| x445zzo (a5) | rewrite small | 297 | 0.9800 | 14/11 | 35 (47), 88 (89) | 68 | adopted as base |
| x446zk (a6) | invalid trees | 565 | 0.9811 | | | 65 | quality only |
| x447aa (a7) | best-first search | 540 | 0.9793 | 57/36 | 26 (120), 54 (89) | 64 | ideas to mine |
| x448bp (a8) | | 1165 | 0.9786 | 149/71 | 457 (213), 81 (89) | 65 | not adopted |

x445zzo's numbers are the agent's; I re-ran its size, gates and
battery (against sk10p: 14 worse, 11 better, treeDiff 1147), and the
round-45 checker re-ran its gates. The a5 checker did not run.

- **x443xp** is sk10p with flat memo and reach arrays, a fix mark per
  position, forgetting by blocks of about sqrt(n) positions, and an exact
  cache of repetition iterations stamped by change counters. Trees equal
  sk10p's on the battery and on all 8 fuzzer seeds. Battery 2.1x faster
  (median 1637 against 3489 ms) and 37.4G -> 14.8G instructions; 64/1
  rung 539 ms against 3775 ms; x(ab)*1600 5.2x faster but still close to
  quadratic. One AOT cost worth knowing: a record kept in a generic list
  is type-checked on every read, 18% of battery instructions in x443xh;
  a class removes it.
- **x445zzo** is a rewrite in one fix kind. A fix at element i of a
  sequence at position q deletes s characters, skips elements i .. j-1
  (each inserted as its shortest input) and then matches element j, or
  closes the sequence. A literal of several characters is a sequence of
  its characters; a repetition or an option is a sequence of its one
  element. Price max(s, inserted length), at least 1. Its own curve of
  mechanisms (battery score, a5 agent):

  | Engine | Mechanisms | Lines | Score |
  |---|---|---|---|
  | zzz1 | close-at-end fallback F | 257 | 0.9515 |
  | zzz2 | F + last-token frontier T | 259 | 0.9560 |
  | zzz3 | + openers O | 261 | 0.9665 |
  | zzz4 | + token-iteration candidates and repetition stop I | 276 | 0.9745 |
  | zzz5 | + cap C | 276 | 0.9749 |
  | zzo | + comparison of following fixes W | 297 | 0.9800 |

  Without F the score is 0.79. The two halves of I work only together.
  W buys 0.005 for 21 lines and takes the 64/1 rung from 1.3 to 4.1 s.
- **x44ma** (mine, 563 lines): x443t with x446q's six changes. Battery
  0.9810, 64/1 cost 65. An ablation of each change on fuzzer seeds 1-4
  (worse cases without the change / with it): fallback 1/0, forced fix
  3/3, read-then-fail offers 14/9, tie step 31/3, line-end deletion
  10/0, readTo 22/7. Deleting `_nests` with the read-then-fail offers in
  place costs 140 battery cases (0.9716). Superseded by x451y.
- **x447aa** is a best-first search over fix sets. It is the only
  engine of the round with markedly fewer invalid trees (54 against 89)
  and it repairs `[1,,2` at cost 2 (sk10p 3), but scores 0.9793. Its
  exact variant x447ac did not finish the 32/1 rung.
- **x448bp** was built up in 60 steps from a 453-line engine and never
  reached sk10p's quality.

Round 45, q1 (quality on x445zzo): each change measured alone on the
battery and on fuzzer seeds 1-4 against x445zzo (fuzzer: worse cases of
the new engine / of zzo; zzo has 50 invalid trees on seeds 1-4):

| Engine | Change | Lines | Battery | Fuzzer worse | Invalid |
|---|---|---|---|---|---|
| x451a | whole-input fallback, unguarded | 298 | 0.9738 | 3/30 | 38 |
| x451b | forced fix, always | 299 | 0.9706 | 2/4 | 46 |
| x451c | read-then-fail offers | 297 | 0.9806 | 12/9 | 50 |
| x451d | tie step in `_wins` | 303 | 0.9802 | 1/24 | 44 |
| x451e | line end deletes the rest | 301 | 0.9800 | 0/1 | 50 |
| x451f | reads = max(reach, match length) | 297 | 0.9800 | 9/18 | 50 |
| x451g | fallback guarded by the price of the fixes | 306 | 0.9800 | 0/9 | 44 |
| x451k | layout characters are not tokens | 306 | 0.9801 | 0/0 | 50 |
| x451v | forced fix only over a non-empty match | ~300 | 0.9800 | 2/2 | 48 |
| x451w | no offer deletes the whole unread input | ~300 | 0.9800 | 1/0 | 51 |
| x451y | g d e f c k w v | 330 | 0.9811 | | 39 |

x451y, confirmed by its checker:

- 297 -> 330 lines (+33, +11.1%); sk10p 531 -> 330 (-201, -37.9%).
- Battery 0.9811: against x445zzo 22 better, 10 worse, all 16 cost
  differences lower; against sk10p 26 better, 14 worse, 19 of 23 cost
  differences lower.
- Fuzzer, 8 seeds: against x445zzo worse 23 vs 119, invalid 67 vs 88;
  against sk10p worse 47 vs 151, invalid 67 vs 89. No timeouts.
- Rung costs 6/8/13/16/31/65 (sk10p and zzo 6/8/16/19/34/68). The tree's
  edit count equals lastCost on the rungs (zzo: 35 for 34, 69 for 68).
- Gates identical to zzo's and sk10p's.
- Slower than zzo: 64/1 rung 9.5 against 5.7 s and 32/1 3.8 against
  2.4 s under load average 22-39. Instructions (callgrind, mine):
  battery 41.1G -> 51.8G (1.26x; sk10p 37.4G, x443xp 14.8G); 64/1
  rung 45.9G -> 67.6G (1.47x); x(ab)*1600 32.4G both.
- Depth 800 and x(ax)*1600 b still overflow the stack.

Refuted or not adopted:

- x451a, the unguarded whole-input fallback: short truncated inputs go
  from 1.0 to 0.0 on the battery.
- x451b, the forced fix on every element: forcing a nullable element
  drops its node, 139 battery cases worse. x451v forces only where the
  element would read something.
- x451j/l, later choice arms as candidates: +4 battery cases, but 21
  lines, 2 more invalid trees and about 50% more time.
- x45m1 (mine): x451y with the fallback taken whenever the tree costs
  more than deleting the whole input, dropping the `spent` guard. 13
  battery costs fall but the score drops 0.9811 -> 0.9749, while on the
  fuzzer it is never worse than x451y (x451y worse in 25) with 60
  invalid trees against 67. The fuzzer counts cost and the battery
  scores the tree; the guard is the choice between them, and x451y
  keeps it.

Open: "bcbab" with `R0 <- ((('b' R0 'b') / 'c'*) / R0)` costs 2 with an
invalid tree after the tie step (sk10p 4, valid); the stack depth; the
speed of `_wins`; x447aa's validity; the elegance review of x451y and
the round-45 axes q2-q6 (speed, robustness, invalid trees, radical
simplification, elegance), stopped by the weekly limit.

LOC: sk10p 531 -> x445zzo 297 (-234, -44.1%) -> x451y 330 (+33, +11.1%).
