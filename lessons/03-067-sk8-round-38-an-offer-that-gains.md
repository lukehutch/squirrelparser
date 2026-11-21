<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk8 - round 38: an offer that gains nothing may not bound the search or block the close at the end; 0.962 -> 0.963, fuzzer worse cases 105 -> 25 against sk7y (2026-10-08)

sk8f is sk7y with five changes to how `_repair` treats an offer that reads
no farther than the frontier (one that gains nothing). Round 37 made such
offers common: every failed opener at a choice's position is now a
candidate, and inserting one usually reads exactly to the frontier.

1. **A fallback must read to the frontier** (sk8a). The offer kept when
   none gains (`idle`) must have r >= far. On
   `R0 <- ("cbab" / R1)` with input `abaab`, sk7y kept the opener of
   "cbab" at 0, which reads less than the plain parse, and paid 5; sk8a
   pays 1, as sk7q did. Battery trees unchanged; fuzzer worse 51 -> 47
   against sk7q.
2. **The close at the end of input refuses an infinite price** (sk8b).
   sk7y closed a sequence whose skipped elements have no finite input and
   reported cost 2,147,483,655 on `bbcc` (a fuzzer grammar). sk7q
   happened never to reach that fallback. Battery trees unchanged.
3. **Only an offer that gains sets the window** (sk8c). The window bounds
   how many characters later offers may delete. An insertion that gains
   nothing set it to its price, so on `aabc` deleting `bc` (cost 2) was
   never looked at after the opener `c` at 0 (cost 1, then 3 more).
   0.9628.
4. **The close at the end runs when no offer was kept** (sk8d), even if
   a fallback offer exists. 0.9631.
5. **A sequence close is offered at the end of input like anywhere
   else** (sk8e), so it competes on reach less price. 0.9632.
6. **Review fixes** (Opus agent, sk8f): the test `q + s <= n` that change
   5 left is always true and is deleted; `offer` returns early when it
   gains nothing; two header sentences corrected (the window bounds
   deletion, and the end close needs no kept offer, not no gaining one).
   Battery and fuzzer trees identical to sk8e.

**Results (confirmed; costs).**

| Engine | Battery | 6/1 | 8/1 | 12/1 | 32/1 | 64/1 | 256/4/7 | Invalid | LOC |
|---|---|---|---|---|---|---|---|---|---|
| sk7q | 0.9528/65.8 | 9 | 17 | 26 | 50 | 104 | 4 | 159 | 428 |
| sk7y | 0.9621/67.6 | 6 | 8 | 16 | 38 | 151 | 4 | 165 | 453 |
| sk8b | as sk7y, treeDiff 0 | | | | | | | | |
| sk8c | 0.9628/67.7 | | | | | | | | |
| sk8d | 0.9631/67.9 | | | | | | | | |
| sk8e | 0.9632/68.1 | 6 | 8 | 16 | 38 | 151 | 4 | 137 | 455 |
| sk8f | as sk8e, treeDiff 0 | same | same | same | same | same | same | 137 | 454 |

- Battery sk8e against sk7y: 21 better, 1 worse
  (`{"k":[{"a":1}{"b":2]}`, 2 -> 4).
- Fuzzer (8 seeds x 400), counting cases where each engine is the worse
  of the two: sk8e 25 vs sk7y 105, invalid 137 vs 165; sk8e 56 vs sk7q
  107, invalid 137 vs 159. Timeouts 0. Round 37's fuzzer regression
  against sk7q is reversed.
- Gates, sk8e: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit
  16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0. Deep checks as sk7y:
  overflow at depth 800, `x (ax)*n b` costs 2, x(ab)*1600 2.7 s.
- Battery time 883-924 ms (sk7y 886-909), on a loaded machine.

**Open items, with proposed fixes.**
- `aabc` on `R0 <- ('c' R0 R0)+ / (R1+ / 'a'+)` still costs 4 (sk7q
  2). The only candidate at the error is the repetition `'a'+`, which is
  never offered a close, and the fallback opener at 0 is kept. Proposed:
  offer a repetition a close after deleting s characters, as a sequence
  is; not tried.
- The 64-error rung (151 vs sk7q 104), quote swallowing, recursive
  openers and nullable `+` remain as in round 37.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| sk8f | 0.9632, fuzzer worse 25 vs sk7y 105, invalid 137, 454 LOC | 8 | best of the line on battery and fuzzer |
| sk8e | same trees, 455 LOC | 7 | superseded by sk8f |
| sk8d | 0.9631 | 6 | end close still not an ordinary offer |
| sk8c | 0.9628 | 6 | |
| sk8b | as sk7y | 5 | fixes the infinite price only |
| sk7y | 0.9621, invalid 165 | 5 | superseded |

LOC: sk7y 453 -> sk8f 454 (+1, +0.2%).
