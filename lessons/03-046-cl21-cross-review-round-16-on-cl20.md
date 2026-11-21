<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl21 - cross-review round 16 on cl20: recovery on an explicit stack reaches the parser's depth, and the cubic family becomes quadratic, 757 -> 799 LOC (2026-09-25)

Round 16 ran a Claude subagent (Opus 5.5, high effort) on BRIEF16 (Q1 depth; Q2 the
cubic family; Q3 other shapes; Q4 review of round 15). It built p1-p11. The engine
is untracked `_cl21.dart` (kit names `p9`, `r16p9`), the seat's `cand` unchanged.
Its report is `R16_CLAUDE.md` in the round kit.

**What cl21 changes (confirmed from the diff against cl20).**
- **Growth runs on an explicit stack.** `_grow` and the four construct functions
  (`_seq`, `_repeat`, `_first`, `_optional`) are `sync*` generators. When a
  construct needs a cell that is not grown yet, `_read` returns null and leaves the
  growth in `_want`; the construct yields it; `_drive` runs it on a list of
  iterators; the result comes back in `_got`. `_asks` wraps the call. cl20 recursed
  `_read -> _seq -> _repeat -> _read` once per nesting level (about 8.6 Dart frames
  per level, the seat's estimate from a cut trace); cl21 uses no Dart frame per
  level and 4.00 heap iterators per level (the seat's counter).
- **Rule 1.** In `_repeat`, a reading that ends exactly at a stop its own body made
  (`r.guard?.$1 == r.end` and the guard's `opens` is the body's) is not extended by
  another body match, and `_rejected` is set. The guard states that the body fails
  there on the repaired string, so a further match contradicts it. To make the test
  possible, `_stop` takes `opens` from an `Expando` keyed by the body, so each body
  has one closure. Setting `_rejected` is needed: without it (p4) old fuzzer s7
  `ababa` goes from cost 1 to 4, because the diverse retry no longer runs.

**Measured (confirmed), kit r9/verify, cl20 = r14c20p, cl21 = r16p9.** LOC 757 ->
799 normalized (+42, +5.5%; raw 760 -> 805); the stack alone is +35 (p2, the seat's
count). Battery 0.9900/84.4, treeDiff 0 and costDiff 0 against cl20, 1,995 ms.
Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0. No-repair 0.
`det11.sh`: only seed 3 `aabb`, as in cl20. Old fuzzer: invalid equal on seeds 1-8,
worse 0, treeDiff 1 on seeds 2, 3, 5 and 8. Rungs (JIT, one run): 1000/1/1 274 /
274 ms, 1000/32/1 1,484 / 1,563, 1000/128/1 5,058 / 5,235, 8000/4/7 5,845 / 5,824,
8000/32/7 6,126 / 6,146, same costs. All 46 families finish
with cl20's costs (`sweep3.py`, JIT, one run); summed time at the largest n 74,504 /
81,257 ms (1.09x), family 43 at 16,384 40,458 / 43,623 ms.

**Corrected fuzzer, three-way (cl20, cdx1, cl21), confirmed.**

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl20 | 7/5/7/4/7/6/6/8 = 50 | 0/1/5/2/0/5/3/2 = 18 | 0/1/3/2/0/1/2/2 = 11 |
| cl21 | 7/5/7/4/7/6/6/8 = 50 | 0/1/5/2/0/5/3/1 = 17 | 0/1/3/2/0/1/2/1 = 10 |

cl20's s8 worse is 2 in this run, against 1 in its own baseline, because cl21 is
cheaper on `babbbaaabb` (1 against 3; "worse" counts cost above the least in the
run). levSum is equal on every seed but s8 (527 against 529). The seat lists 15
changed trees (11 corrected, 4 old fuzzer), all valid, 14 at equal cost; my runs
agree on the counts (treeDiff per seed not itemized here).

**Depth and the cubic family, AOT (`deep.sh`, one run each, ms), confirmed.**

| input | n=50 | 100 | 200 | 400 | 800 | 1,600 |
|---|---|---|---|---|---|---|
| cl20 x(ax)^n b | 15 | 66 | 322 | 2,306 | overflow | overflow |
| cl21 x(ax)^n b | 6 | 21 | 68 | 250 | 1,041 | 4,350 |
| cdx1 x(ax)^n b | 6 | 32 | 172 | 1,106 | overflow | overflow |
| cl20 x(ab)^n | 13 | 59 | 289 | 2,111 | overflow | overflow |
| cl21 x(ab)^n | 6 | 20 | 67 | 254 | 1,013 | 4,593 |
| cdx1 x(ab)^n | 451 | 6,071 | timeout | | | |

Bracket grammar with the last `]` missing: cl20 overflows at 400, cdx1 at 800, cl21
recovers at 800 (33 ms) and 1,600 (98 ms); every engine overflows at 3,200, where
the plain parse overflows too. The seat found the plain parser's limit at 1,697 and
the overflow there inside `Parser.match`, so recovery cannot go deeper without an
iterative plain parser. cl21's time grows about 4x per doubling: quadratic, not n
log n. The valid bracket input at 1,600 took 16 ms in cl21 against 1 ms in cl20
(one run, not explained).

**The cost: AOT stress, `aot.sh r14c20p r16p9`, 11 interleaved runs, medians
(confirmed).** errors 256 3 / 3 ms, 1024 11 / 14, 4096 52 / 64; lr 2048 35 / 38, lr
8192 132 / 144. cl21 is 9% to 27% slower. The seat measured the same slowdown for
p2, the stack without rule 1, so it comes from the generators.

**Findings from the seat (its measurements unless marked).**
- **The cubic cause, with counters** at n = 400 on `x` (`ax`)*n `b`: 3n + 2 cells,
  about n/2 ends per cell (242,603 ends in 1,202 cells); cl20 made 81,268 `_view`
  calls and 10,996,272 `then` calls, cl21 1,296 and 249,014. In cl20 each
  repetition step viewed the inner cell again. What remains is the n/2 ends per cell.
- **Four more shapes stay quadratic** under cl21 (cubic and overflowing by 400-800
  under cl20): two-arm-star `A <- 'x' ('a' A / 'b' A)*`, mutual-star
  `A <- 'x' B*; B <- 'a' A`, opt-in-star `A <- 'x' ('a' A?)*` and list-rr
  `L <- 'n' (',' L)*`, the comma list written right-recursively. Eight other shapes
  (brackets with `*`, `+` or choice, `('a' A)?`, left recursion inside right
  recursion and the reverse, a `*` before a terminator, `+` with a fallback arm) are
  linear, and cl21 reaches the plain parser's depth on all 12. `deep2.sh` holds
  them.
- **The floor prune is not admissible** (p6: `r.spent + 1 + floor[cut] > budget` on
  a guarded reading): it makes `x(ax)*n b` linear but loses s1 `bbcc` (1 -> 2) and
  changes 3 battery trees; the guard may never be charged, and a deletion across
  `cut` is counted twice. p10 and p11 (with `_rejected` on the prune) lose s1
  `cccbbb` or are cubic again.
- **Two pre-existing flaws.** `_stop` replaces a reading's guard instead of meeting
  it, so an inner stop's requirement is dropped when an outer stop is made (and rule
  1 sees only the latest stop). The diverse retry depends on one global flag, so
  removing a doomed reading anywhere can switch it off (p4).
- Round 15's reruns: n1's s4 `bab` loss and n10's and n4's AOT numbers reproduce;
  "overflows at about 1,400 levels" is unsupported (cl20 overflows at 400-800 on
  every AOT shape).

**Elegance review (orchestrator).**
- The stack protocol returns results through two mutable fields, `_got` and
  `_want`, and six call sites repeat `if (_asks(...)) yield _want!; for (... in
  _got)`. It is correct because `_got` is read right after the growth that sets it,
  but a reader has to know that. A shorter protocol is a round-17 question.
- A multi-character literal calls `_drive(_seq(_spell(c), ...))`: a generator and a
  stack for every such read with budget > 0, though a spelled literal never grows a
  cell. A candidate cause of the slowdown (not measured).
- The `_opener` Expando exists so that `identical` can name the body behind a guard.
  Storing the body in the guard in place of the closure would read better, but
  `_meet` builds a new closure from two guards, so a met guard would need a set of
  bodies; not changed.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cl21 = p9 | stack + rule 1 with `_rejected` | 799 LOC; depth = parser; cubic -> quadratic; trees valid, one cheaper; AOT +9-27% | 7 | fixes two inputs that do not finish; fails speed |
| p5 | as p9 with a `_bodyOf` Expando | 800 LOC; trees = p9 | 6 | one line more |
| p2 | stack only | 792 LOC; trees = cl20; still cubic | 5 | fixes depth only |
| cl20 | none | overflows at 400; cubic | 5 | inputs that do not finish |
| p1, p3 | stack variants | no faster than p2 | 4-5 | nothing gained |
| p6, p8, p10 | floor prune | loses s1 `bbcc` or `cccbbb` | 2-3 | not admissible |
| p4 | rule 1 without `_rejected` | s7 `ababa` 1 -> 4 | 2 | retry switched off |
| p7, p11 | prune without rule 1; prune with `_rejected` | cubic | 1 | no gain |

cl21 is adopted although it fails the speed target: the directive that every input
must finish outranks speed, and cl20 crashes on a JSON document nested 400 deep with
one missing bracket.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| p9: battery treeDiff 0, every check = cl20, no-repair 0, det only `aabb` | Claude | check21.sh, norepair.sh, det11.sh r16p9 | confirmed |
| p9: invalid = cl20 per seed; worse and levWorse <= cl20; `babbbaaabb` 3 -> 1 | Claude | the same check21 run | confirmed |
| p9 recovers the bracket grammar at 1,600; cl20 overflows at 400 | Claude | deep.sh, AOT | confirmed |
| cubic -> quadratic, about 4 s at 1,600 | Claude | deep.sh: 4,350 / 4,593 ms | confirmed |
| AOT 12-21% slower | Claude | aot.sh: 9-27% | confirmed |
| rungs within noise, same costs | Claude | rungs.sh | confirmed |
| all 46 families finish with cl20's costs | Claude | sweep3.py | confirmed (1.09x the summed time) |
| counters: `_view` 81,268 -> 1,296, `then` 10,996,272 -> 249,014 | Claude | not rerun (round 17 Q5) | unsupported by my check |
| four quadratic shapes, eight linear | Claude | not rerun | unsupported by my check |
| p2 keeps every tree; p4, p6, p10, p11 losses | Claude | not rerun | unsupported by my check |
| plain parser limit 1,697, overflow inside `Parser.match` | Claude | deep.sh: plain ok at 1,600, overflow at 3,200 | consistent, the exact limit not rerun |

**Disclosures by the seat.** It read the session transcript, outside its directory,
after a context compaction (nothing from it is used as a result); a stale AOT binary
first gave false overflows, and all Q1 numbers are from a recompiled one; one run
started in the background by accident; `check.sh` ran in two parts; the `del` error
kind of its driver gives a valid input.

**Open items.** The AOT slowdown of the generators; the four quadratic shapes and
the family (n/2 ends per cell); `_stop` replacing guards; the retry trigger; size
(799).

**Process lesson.** Check a performance fix at the depth and length of real inputs,
not only on the families: every family finished in cl20 while a JSON document nested
400 deep crashed it.
