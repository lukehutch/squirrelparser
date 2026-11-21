<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Round 24 on cl27: a wider diverse key fixes a lead that spans two literals, but the diverse rung is 75x slower at width 3 than at width 2, so no candidate is promoted, and cl27's own cut has the same flaw (2026-09-27)

Round 24 ran a Claude subagent (Opus 5.5, high effort) on BRIEF24 (Q1 the key
cut at `_wide`; Q2 cancelling edit pairs and kind D; Q3 speed; Q4 size; Q5
review of round 23). Codex and Gemini had no quota. The seat's `cand` (l9,
kit name r25a) grows `_wide` inside `_starts` during the ordinary search. The
orchestrator moved that into one statement between the two ladders (r25b),
then dropped the longest-literal starting value (r25c). r25c passed every
check below, then did not finish fuzzer seed 31 (see "The width blow-up").
Nothing is promoted; cl27 stays the engine.

**What r25c changes (confirmed from the diff against cl27).**
- `_wide`, the length to which the diverse key holds a lead, was the
  grammar's longest literal. It is now `0`, raised after the ordinary ladder
  to the longest text that `_starts` found to open a body:
  `_wide = _startsCache.entries.fold(_wide, (n, e) => e.value ? max(n,
  e.key.$2.length) : n);`. `_longest` (7 lines) is deleted.
- The ordinary search is cl27's: `_wide` is read only in `_Front.key` under
  `_diverse`. The diverse search terminates: `recover()` runs every ordinary
  rung before any diverse rung (`_ladder(top, false)` then `_ladder(top,
  true, ...)`), so `_wide` is a fixed finite number during the diverse
  search, and the round-23 argument for a fixed cut applies (the seat's
  proof, read and accepted).
- Neither cut is exact, and neither is bounded in practice (below). Two
  leads that first differ beyond every text the ordinary search tested are
  still merged. The longest-literal cut was never
  argued for any case; round 23 chose it only as a finite cut. The new one is
  the width the guards used.

**Measured (confirmed), kit r9/verify.**
- `S <- ("ab" "cd")* A; A <- 'a' 'b' 'c' B; B <- 'd' / 'e' 'e';` on `abcd`:
  cl27 invalid at 2 edits; r25a, r25b and r25c `abcdabcee`, owed only (cost
  1), valid. The three BRIEF23 cases stay valid at cost 1.
- `check28.sh` (baseline cl27), identical for r25a and r25c apart from wall
  time: battery 0.9900/84.5, treeDiff 0 and costDiff 0; accept t/t/t,
  freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props
  2728/0, window and pred as cl27. `_samedw` (three-way with cdx1) invalid
  7/5/5/4/7/6/4/10 = 48, worse 9, levWorse 6, all equal to cl27 per seed;
  `_samew` invalid 38 and `_same` invalid 24, equal per seed, worse 0. The
  only tree change is one seed-2 case (`bcba`) on `_same` and `_samew`, an
  equal-cost tie between valid answers (7 edits each).
- r25b against r25a and r25c against r25b: treeDiff 0 on the battery and on
  every seed of `_samedw`, `_samew` and `_same`; r25c against r25b also on
  `_samedw` seeds 9-30. Seed 31 did not finish (next paragraph).
- no-repair 0; `det11.sh`: only `aabb`; `deep2.sh` and `multi.sh`: every cost
  equal to cl27 on all 22 shape blocks.
- Timing, r25b against cl27 (r24p1): families under default flags, medians
  of 7, within 2% either way (4 380/386, 6 1,075/1,078, 10 1,289/1,312, 11
  543/537, 16 1,992/2,000, 18 2,488/2,471); AOT stress equal (errors 4096
  49/49, lr 8192 132/133); rungs one run each within 4% either way, costs
  equal. r25c was not timed on the families: its run was queued after seed
  31.

**The width blow-up (confirmed).** On seed 31, case 11,
`S <- R0; R0 <- (("ac" 'c')+ / ((R1 R0 'b') / 'a')); R1 <- ((R2 R0)? (R0 R2
'c')? (R2 'a' 'b')*); R2 <- (('c' R1) ("bc"* R1 R1*));` on `acacac`, cl27
answers `accacc` (cost 2, valid) in 0.6 s of engine time; r25a, r25b and
r25c do not finish in 120 s. The ordinary ladder is the same in all of them
(budgets 1 and 2, 50 ms). The ordinary search found `ca`, `abcc` and `abbcc`
to open a body, so r25c's width is 5 where cl27's is 2 (`"ac"`), and the
diverse rung at budget 1 does not end within 120 s. With cl27's width forced by an
environment variable (debug copy `r24d`): width 2, 0.5 s; width 3, 38.7 s;
widths 4 and 5, more than 240 s. The diverse key keeps a lead as far as
`_wide`, and a lone owed completion costs 1 however long it is, so at
budget 1 the diverse search keeps one reading per distinct lead prefix of
length up to `_wide` in every cell (inferred from the key; the rung
counts were not printed); in this recursive grammar the time grows 75x
from width 2 to width 3.

cl27 has the same flaw. Its width is the longest literal anywhere in the
grammar, so adding the unused rule `R9 <- "cccc";` to the same grammar makes
cl27 run past 240 s on the same 6-character input. Round 23's argument that
the longest-literal cut keeps the diverse search finite is correct, but
finite is not enough: the search is exponential in the width, and the width
is a property of the grammar's spelling, not of the input. This is a breach
of "every input must finish" in any practical sense, and it was in cl27 when
it was promoted. `_samedw`'s grammars use literals of at most 2 characters,
which is why no earlier seed showed it.

The 12 s and 820 MB that `_wone.dart` reports for cl27 on this case are the
kit's compile time: `_wone` imports every registered engine. The engine's
own timer stops at 601 ms.

**The cost of cl27 over cl26 (Q3).** The seat found equal Dart work in the
two (callgrind per function) and a bimodal collection count under the VM's
default old-generation growth, and proposed timing with
`--old_gen_growth_time_ratio=100`. Rerun (confirmed, medians of 7, cl26 /
cl27): family 10 1,402/1,411 ms (the 6% default-flag gap is gone), but
family 4 408/425 and family 6 1,222/1,250, with 34 against 36 collections on
family 4 in every run. So part of the gap is the collection schedule and part
is extra allocation (the lead strings) that shows up as collections. Timing
comparisons of a few percent should report collection counts.

**Elegance review of r25c (not promoted).**
- The seat's form changed `_wide` from inside `_starts`, a cached test, with
  a `!_diverse` condition to keep it safe. One statement between the ladders
  gives the same value (the cache holds only the ordinary search's entries
  at that point), with no side effect and no condition, at the same length.
- With the width taken from the tests, the literal floor had no remaining
  purpose, and `_longest` went with it (-6 lines).
- Side findings (confirmed with `_wone.dart`): `S <- 'b'* 'a'* 'b'` on `bb`
  answers `bbab` (two owed characters, cost 1) where `bab` (one insertion,
  cost 1) is valid and one edit shorter; the owed price of 1 ties them and a
  later key picks `bbab`. `S <- 'b'* 'a'? 'b'` on `bc` is invalid at 2 edits
  (kind D) where `ab` is valid at 2.

**Negative results (the seat's figures, not rerun unless marked).**
- A cut at the longest one-pass body span (l1): battery 10x slower (19.8 s)
  and `_samedw` seed 7 does not finish.
- A cancelling pair (a deletion and an insertion that share a character with
  no read between) is never the best valid answer (the seat's proof
  generalizes the orchestrator's from one character each to runs, read and
  accepted; the shifted form holds only when the text between is the same
  character repeated). None of cl27's 48 `_samedw`, 38 `_samew` or 18
  NEWINV_R19 invalid trees is cancelling, and `cbbb` is kind D. The rule on
  cl27 alone (l4) turns the `("ab" "cd")*` case into no repair at all; with
  the key fix it has nothing to remove. Not adopted.
- The five families' 13-19% over cl24 is the `~pos` entries themselves (+17%
  joins and +18% adds on family 16). Seeding growth without `~pos` (l7) gains
  nothing; the ordinary key without the split (l8) runs the diverse retry and
  is 30% slower on family 16.
- Lazy leads (l5) are never forced on families 10, 11 and 16 but recover no
  time.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cl27 unchanged | none | 898 LOC; `("ab" "cd")*` case invalid; unused 4-letter literal makes a 6-letter input not finish | 5 | stays only because every candidate is worse |
| r25c | `_wide` from 0, raised between the ladders to the longest opening text; `_longest` deleted | 893 LOC; trees = cl27 on seeds 1-30; seed 31 case 11 does not finish | 1 | fails termination where cl27 finishes |
| r25b | r25a with the widening between the ladders | 899 LOC; same hang | 1 | same |
| l9 = r25a (Claude) | `_wide` grown inside `_starts` | 899 LOC; same hang | 1 | same |
| l3, l4 (Claude) | cancelling rule | 913, 910 LOC; no invalid tree fixed; l4 loses the case | 2-4 | proved safe, no benefit |
| l5-l8 (Claude) | speed variants | no gain or slower | 1-3 | |
| l1 (Claude) | cut at the longest body span | seed 7 does not finish | 0 | fails termination |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| l9 fixes the `("ab" "cd")*` case at cost 1 | Claude | `_wone.dart` | confirmed |
| l9 = cl27 on battery, gates, all fuzzer counts; one equal-cost tie | Claude | check28.sh r25a | confirmed |
| the ordinary search is cl27's; the diverse search terminates | Claude | read the code; seed 31 case 11 | the ordinary search is equal (confirmed); the diverse search is finite but exponential in the width and does not finish in 120 s: wrong in practice |
| no invalid tree of cl27 is cancelling | Claude | not rerun | plausible (script read in the report) |
| cl27's gap over cl26 is the GC schedule, Dart work equal | Claude | famflag.py, families 10, 4, 6 | partly: family 10 yes; families 4 and 6 still 2-4% with more collections |
| o11 does not finish; o39 costs 2 on `ccbbbc`, not 1 | Claude | not rerun | plausible |
| side findings `bbab` and `bc` | Claude | `_wone.dart` | confirmed |

**Open items.**
- The diverse key's lead cut. Any fixed width looks exponential in that width
  (inferred from widths 2-5 on one case);
  the fix must stop leads from multiplying at a cost that does not grow with
  their length, for example a key on the outcomes of the guard tests a lead
  can still reach rather than on its text, or a price on owed characters in
  the diverse search only. Check: seed 31 case 11 and the `R9 <- "cccc"`
  variant finish under 1 s, and the `("ab" "cd")*` case is valid.
- The fuzzer should draw longer literals, so that `_samedw` can see this
  class of case.
- Kind D (`cbbb`, `'b'* 'a'? 'b'` on `bc`).
- Equal-cost ties between an owed completion and a shorter insertion
  (`bbab` against `bab`).
- The five families (cl24's times) and cl27's extra allocation.
- The quadratic term with two or more errors in the four shapes.
- Size: 898 against cl20's 757.
