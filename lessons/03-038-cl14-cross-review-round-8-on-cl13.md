<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl14 - cross-review round 8 on cl13: shared gap scans, a gallop-and-bisect ladder, a bound bought by counted work, 727 -> 803 LOC (2026-09-24)

Round 8 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and a
Claude subagent (Opus 5.5, high effort) on BRIEF8 (Q1 the `"ab" "aa"*? 'a'?+`
quadratic, Q2 invalid trees, Q3 size and elegance, Q4 peer review). Codex hit its
usage limit (rc=1, no Codex seat until Sep 29) and left a partial report whose
logs were still usable. Gemini and the Claude seat finished. Most of cl14 came
from the orchestrator's own candidates (r8gen through r8hJ), built on the seats'
diagnoses. The engine is untracked `_cl14.dart` (kit name r8hJ).

**What cl14 changes (confirmed from the diff against cl13).**
- **A shared gap scan** (`_next`, `_gaps`). `_resume` finds the next position
  where the input reads a clause through a per-clause skip array, so repeated
  scans over one unreadable run are shared. The scan stays bounded by the budget
  window (`r.end + budget - r.spent`). Codex and the Claude seat found that the
  `"ab" "aa"*? 'a'?+` quadratic was this scan (2n^2 steps in one rung), not the
  ladder, as BRIEF8 had guessed. Codex's r8next fixed terminals only; a First
  as the repetition body stayed quadratic until the scan was shared for every
  clause (r8gen).
- **`_plain` does one map lookup** with a failure sentinel, and no memo-version
  check (r8fin, r8e6). This pays for the next item.
- **`_sealed`**, one helper for the sealing rule of `_seq` and `_repeat`.
- **A position-ordered `_repeat` worklist** (a SplayTreeMap by end): each end is
  extended once (r8e7). The `"ab"*`, `('a' 'b')*`, `('a'? 'b')*`, `('a'* 'b')*`
  and `('a' / 'b')*` families become linear.
- **Covered repetitions** (`_covered`, r8h2): a clause each of whose occurrences
  starts an enclosing repetition's body, with only total slots after it, reads
  its later occurrences plainly; the enclosing repetition explores their repairs.
- **A semi-naive fix** (r8h4): a settled cell with `usedSeed` was viewed through
  `_since`, which gives Delta(A) x Delta(B) in place of Delta(A) x B + A x
  Delta(B), and `usedSeed` was set by any active read, including the cell's own
  left recursion. A cell now uses a seed only if it read a cell growing below it
  (`depth`, `_low`).
- **Success is monotone in the budget** (r8h5): the one-occurrence insertion for
  `+` was offered only if no occurrence was read anywhere, so a larger budget
  could lose it. It is now offered whenever the body can be inserted
  (`if (c.requireOne)`). `_mono.dart`: 0 of 13,241 generated cases non-monotone
  (r8h2 396, r8h4 13).
- **A gallop-and-bisect ladder over fresh cells** (`_ladder`, `_rung`; r8h6, r8h7):
  gallop up from the bound's floor until a budget succeeds, probe the found
  reading's cost next, then bisect. Each probe starts from empty cells. This
  relies on monotone success.
- **The diverse search runs only below the ordinary least budget**, and only if
  the ordinary search rejected a reading at its greatest failing budget (r8h9).
- **The bound is bought by counted work, not by a Stopwatch** (r8hG, r8hH). cl13's
  rule made the answer depend on machine speed (below). The ladder starts with
  the regular bound. It buys the return-site bound after `width * calls * (n+1)`
  front offers, the number of entries the purchase adds, or at the first offer
  after a failed probe. A purchase throws `_Spent` and restarts the gallop from
  the new floor.
- **Elegance review of r8hH (r8hJ)**: one identity map `_relations` in place of
  two maps and a getter; the per-rung reset moved into `_rung`; `recover()` and
  the `_Spent` handler shortened; a comment that sat above `_Spent` moved to
  `class Recovery`; the header comment rewritten to describe the ladder and the
  semi-naive regrowth. Buying the bound at once on failure was tried and
  reverted: it builds the bound even when the ladder then exits.

**Measured (confirmed), kit v3, against cl13.** LOC 727 -> 803 normalized (+76,
+10.5%; raw 800). Battery 0.9900/84.4 (cl13 0.9899/84.3), treeDiff 30, costDiff
0, 2,164 ms (cl13 about 1,550-1,630 ms in this kit). Accept t/t/t, freespan 3 3
4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0,
window P, pred falseAssertions 0. Corrected fuzzer (`_samedq.dart`, 400 cases),
invalid seeds 1-8: 8/6/8/4/7/7/8/10 (cl13 8/6/8/4/7/8/7/11); cl13 has one worse
case on seeds 5, 6 and 8 each, cl14 one on seed 7 (`acaca`, the bound-dependent
case below). levSum 533/553/536/512/538/529/533/527 (cl13 533/553/536/512/538/
527/535/524). Old fuzzer (`_same.dart`): invalid 3/2/4/6, as cl13. **No-repair
(`norepair.sh`, both fuzzers, seeds 1-8): 0.** Rungs (ms, cl13 / cl14, every cost
equal): 1000/1/1 345/335; 1000/32/1 3,928/1,867; 1000/128/1 9,388/5,006; 8000/4/7
2,288/8,969; 8000/32/7 11,755/9,164. Stress (ms, cl13 / cl14): errors 256 41/33,
512 76/52, 1,024 132/90, 4,096 1,036/161; LR 2,048 190/164, 8,192 365/339.
Families (`sweep3.py`, 46 grammars, n = 1,024/4,096/16,384, 120 s each):
all 46 finish at every size, no timeouts
(`$SP/r8/sweep_r8hJ.txt`; r8e7 timed out on 26, 28-31, 35, 42 and 43). The
slowest: family 43 2,519/9,793/40,552 ms, family 42 409/831/3,243 ms, family 30
267/512/2,330 ms, family 26 238/466/2,275 ms. Family 43 grows about 4x per 4x
of n, so near n log n, but at 16,384 it takes 40 s.

**Candidates.** Each row is measured against the row it builds on unless it says
otherwise.

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r8hJ = cl14 | r8hH after the elegance review | trees = r8hH everywhere, 803 LOC | 9 | same results, 7 lines fewer |
| r8hH | r8hG with the allowance equal to the entries the purchase adds (`width * calls * (n+1)`), lazy purchase after a failure | as cl14, 810 LOC; rungs 1,879/5,060/9,076/9,328 | 8 | the last engine before cleanup |
| r8hG | charge per front offer; a failure under the regular bound buys the bound; a new floor restarts the gallop at step 1 | trees = r8hH; rungs 1,866/5,010/9,288/9,573 | 7 | first rule that wins 1000/32/1 and 1000/128/1 without the Stopwatch |
| r8hK | allowance equal to the regular bound's size, no purchase on failure | rungs 4,284/8,235/2,334/22,267 | 4 | wins 8000/4/7, loses the rest |
| r8hA | always buy the return-site bound | rungs 1,726/5,444/7,737/9,634; battery 3.2-3.3 s | 5 | the build costs 1.9 s of battery time |
| r8hN | never buy | 1000/32/1 and 1000/128/1 over 300 s; 8000/32/7 22.3 s | 0 | does not finish |
| r8hF | buy after a failure at the floor | 12.0 s, 180 s, 9.6 s, 10.2 s | 2 | the first probe under the regular bound is the slow part |
| r8hW | a per-probe read cap equal to the bound's row cells | battery treeDiff 0 vs r8h9, 2,548 ms; 1000/32/1 243.8 s | 1 | every probe is under the cap, and every probe pays |
| r8hX | one read cap over the whole ladder | 1000/32/1 240.3 s | 1 | reads do not measure work; offers do |
| r8h9 | r8h8 with the diverse search asked only after a rejection at the greatest failing budget | battery treeDiff 0 vs r8h6; family 43 1,024 2.7 s, 4,096 11.3 s; rungs (Stopwatch) 174 s, over 300 s, -, 23.2 s | 6 | right ladder, wrong purchase rule |
| r8h8 | ordinary ladder first, then the diverse search below its least budget | family 43 16,384 in 44.7 s; 2 cheaper INVALID fuzzer trees | 4 | not adopted as is |
| r8h7 | probe the found reading's cost next | family 43 1,024 5.4 -> 3.4 s, 4,096 25.8 -> 14.3 s, trees = r8h6 | 7 | adopted |
| r8h6 | gallop-and-bisect ladder over fresh cells | battery treeDiff 5 vs r8h5, costDiff 0; families 26, 28-31 at 16,384 in 2.0-2.9 s | 7 | adopted |
| r8h5 | one-occurrence insertion whenever the body can be inserted | `_mono` 0 of 13,241; battery treeDiff 4 vs r8h4 | 8 | monotone success |
| r8h4 | seeds only from cells growing below | battery treeDiff 2 vs r8h2; LR 16,384 1,017 ms | 8 | fixes lost readings |
| r8h3 | view every settled cell in full | fixes the lost readings; family 36 2.6 s at 4,096 (r8h2 0.2 s) | 3 | too slow |
| r8h2 | covered repetitions read later occurrences plainly | battery treeDiff 0; fuzzer 1-4 treeDiff 7/4/5/4, worse 0, invalid unchanged; families 35 and 42 finish at 4,096 | 7 | adopted |
| r8h1 | covered repetitions suppress `_resume` only | families 35, 42, 43 unchanged | 2 | the literal's own leading deletion carries the run |
| r8e7 | position-ordered `_repeat` worklist | families 4-23 finish at 16,384 | 8 | adopted |
| r8e6 | `_plain` with one lookup and a failure sentinel | 8000/32/7 10.9-11.4 s vs r8fin 11.7-12.1 s, trees = r8fin | 7 | adopted, 739 lines |
| r8el | one `_sealed` helper, as written | 8000/32/7 13.5-14.0 s vs 11.6-11.9 s | 3 | call cost on `_repeat`'s hot path; kept only with r8e6 |
| r8fin | r8gen without `_plain`'s memo-version check | trees = r8gen on battery and fuzzer 1-8 | 7 | -1 line |
| r8gen | the gap scan shared for every clause, bounded by the budget window | battery treeDiff 0 vs cl13, all checks, no-repair 0; errors 4,096 1,129 -> 152 ms | 8 | adopted |
| r8nl | the scan unbounded | 3 fuzzer trees differ at equal cost | 3 | the window matters |
| r8next | eager next-match index for terminals (Codex) | linear on the terminal family; First family 2,048/8,192/16,384 510/4,936/20,947 ms | 5 | terminals only |
| r8hO | front keyed by (end, owes) | battery 0.9665/76.7, treeDiff 305 | 1 | bound-independent on `acaca`, but the battery rejects it |
| r8hO2 | owed characters ranked right after cost | battery 0.9598/74.5 | 0 | |
| r8hC | additive cost, every owed character counted | battery 0.9699/75.8, costLower 220; fuzzer worse 0/0/1 on seeds 1/5/7 (r8hF 10/9/14) | 2 | the battery wants a truncated tail to cost one |
| r8hD | additive cost inside fronts, one-completion cost for the final choice | fuzzer worse 0 on every seed, invalid 7/5/6/3/6/4/6/9; battery 0.9816/80.7, treeDiff 117 | 3 | edits the user's text in place of completing a prefix |
| r8hP | prune only edited readings | still bound-dependent | 1 | |
| r8g1 (Gemini) | multi-letter Str in the memoized switch | family 42 at 512 14.8 s (still quadratic); 43 at 32 30.6 s vs 13.5 s | 1 | not a fix |
| r8g2 (Gemini) | `_relations` as a late field | battery 1,704 ms vs 1,609 | 1 | not faster |

**The Stopwatch made the answer depend on the machine (confirmed).** cl13 bought
return-site memory after a wall-clock delay. The Claude seat noticed that its
comment ("the answer does not depend on when it is bought") is false. On
corrected fuzzer seed 7, `S <- R0; R0 <- ((R1 R1 'a')* ((R0 R1) / 'c'+) 'a');
R1 <- ...` on `acaca`, always buying (r8hA) and never buying (r8hN) give
different cost-2 readings: an insertion plus an owed tail (deleted 0, missing 1,
owed 4) against two deletions. Both bounds are admissible (root 1 and 2, true
cost 2). So a faster or slower machine can return a different tree. cl14's
purchase rule counts offers, so it is deterministic, but the tree still depends
on which bound is in force.

**Owed cost is not additive, so the one-per-end front is not a sound dynamic
program (confirmed).** `cost = spent + (owed == 0 ? 0 : 1)`. Under the regular
bound, `(R1 R1 'a')@0` at end 5 keeps d=0 m=2 o=1, which the cell exit prunes
(2+1 > 2), where the remembering bound keeps d=0 m=1 o=2: a reading that owes
nothing displaced an equal-cost reading that owes characters, then was pruned.
Every sound variant (r8hO, r8hO2, r8hC, r8hD, r8hP above) loses on the battery,
which expects that at equal one-completion cost a truncated prefix is completed
rather than the user's text edited: `{"a":1,` should owe a member, not
substitute `}` for `,`, and `[1,[2,[3,` should not become one string. The
one-per-end front is itself a bias toward owed tails that the battery depends
on. Open (round 9, Q1).

**The price of the bound (confirmed).** One front offer costs about 16 times
the wall time of one entry of the bound's build (7.8 s for 13.5M offers against
0.9 s for about 18.9M entries). On 8000/4/7 and 8000/32/7 the first failed probe
is equally cheap (about 1k and 7k offers); only later probes differ, so no rule
that decides at the first failure wins both rungs. On 8000/4/7 the regular floor
is 3, the cost 4, and the purchase is a 6.9 s build (n = 196k, width 161, calls
4): cl14 loses that rung to cl13 (8,969 against 2,288 ms). The regular bound
merges callers, so an unclosed bracket is free under it and it barely prunes on
bracket-heavy input; work grows steeply with the slack above the true cost
(300/32/1: budget 28 0.68 s, budget 30 6.2 s). Open (round 9, Q2).

**Plain-parser verdicts for left-recursive clauses depend on evaluation order
(confirmed, pre-existing, flagged for the user).** The Claude seat found it;
`_orderfz.dart` finds 20 of 3,000 random grammars that differ in a verdict
(length, or match against mismatch) and 29 more that differ only in tree shape.
Minimal case (`_entry.dart`): `S <- R0; R0 <- ('a'* R1*); R1 <- (R0 / 'c'??);`
on `cac`: R0 at 0 matches 2 characters when R0 is entered first and 0 when R1 is
entered first. This bears on the paper's statements about purity and the
omniscient parser (`squirrel_parser.tex` lines 413 and 433). It is a property of
the core parser, not of recovery; whether to fix the parser or the text is the
user's call.

**Claims table.** The full table is `$SP/r8/CLAIMS8.md`; the rows that decided
cl14:

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| The `"ab" "aa"*? 'a'?+` quadratic is the `_resume` scan, not the ladder | Codex, Claude | counters: n=2,048 6,305,801 resume steps, 2 rungs | confirmed; BRIEF8's guess was wrong |
| r8next and r8skip are linear on that family, battery treeDiff 0 | Codex | fam.sh; Codex's logs | confirmed, superseded by r8gen |
| An unbounded scan changes 3 fuzzer trees at equal cost | Claude | r8nl vs r8fin, 3 runs | confirmed |
| Plain-parser verdicts for LR clauses depend on evaluation order | Claude | `_order.dart`, `_orderfz.dart`, `_entry.dart` | confirmed, stronger than stated |
| The Stopwatch comment is false | Claude | r8hA vs r8hN on `acaca` | confirmed (the two differ in the tree, not in the cost) |
| r8head fixes 3 invalid trees but regresses seed-1 `bbcc` from 1 to 2 | Codex | not rerun | Codex's measurement; not adopted |
| No `keepFirst` gives 0.9902/86.3, treeDiff 299, more invalid trees | Codex | battery from Codex's log | confirmed from log; `keepFirst` stays |
| cl13 invalid on seeds 1-8 is 8/6/8/4/7/8/7/11 | Codex | orchestrator's runs | confirmed |
| A multi-letter Str in the memoized switch fixes the quadratic families | Gemini | r8g1 on families 35, 42, 43 | wrong |
| `_relations` as a late field is faster | Gemini | r8g2 battery time | unsupported |

**Open items.**
- A cost model and front that do not depend on the bound and keep the battery
  (Q1 of round 9).
- The bound's price: battery 2,164 ms against cl13's 1,550-1,630, and 8000/4/7
  8,969 against 2,288 ms.
- Family 43 `S <- ("bc" / R0)*; R0 <- ("bb"+* 'b'?)` on `bbbbcb` x n is n log n
  but slow; 2.5 s at 1,024, 9.8 s at 4,096, 40.6 s at 16,384.
- r8h8 found 3 cheaper valid repairs that r8h9's rejection test misses.
- Size: cl14 is 76 lines larger than cl13.

**Process lessons.**
- `norepair.sh`'s cleanup sed matched only lowercase engine names, so an engine
  named with capitals (r8hJ) left its `nr` entry in `_pred18.dart`. The pattern
  is now `[a-zA-Z0-9]*nr`.
- A wait loop written as `pgrep -f PATTERN` matches its own shell when PATTERN is
  in its command line, and never exits. Wait on a known PID with `kill -0`, or on
  the harness's own completion notice.
- A work cap must count the unit that costs time: reads (r8hW, r8hX) did not;
  front offers did.
- Two admissible bounds may give different trees when the ranking is not a sound
  dynamic program. Test determinism by building one copy per bound and diffing
  them, not by timing.
