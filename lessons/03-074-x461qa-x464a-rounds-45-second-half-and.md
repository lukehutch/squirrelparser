<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### x461qa, x464a - rounds 45 (second half) and 46: x451y's trees in 306 lines at 2.16x fewer battery instructions; with the elegance review's two tree changes and an empty-fix mark (x464a, 306 lines) fuzzer worse 45 against sk10p's 153, invalid 66 against 89 (2026-10-10)

Round 45's other five axes (q2-q6) ran on x451y, and their checks were
stopped by the usage limit; round 46 re-ran the checks, merged the
results into one engine, shrank q4's validity ban, restarted the
robustness axis and reviewed the merged engine. Every agent ran on
Opus 5.5 at medium effort, and an independent checker re-measured each
builder's best engine. Speed is compared by callgrind instruction
counts (Ir), since the machine load was 20-130.

Round 45, second half (each checked in round 46):

| Engine | Axis | Lines | Trees vs x451y | Battery Ir | Verdict |
|---|---|---|---|---|---|
| x452al (q2) | speed | 338 | same | 24.6G (51.8G) | confirmed, merged |
| x452aq (q2) | iteration cache | 390 | same | 27.8G | merged in short form |
| x454r (q4) | invalid trees | 431 | invalid 67 -> 46 | 1.016x | confirmed, shrunk |
| x455be (q5) | golf | 297 | same | 52.7G | confirmed, merge base |
| x456ai (q6) | elegance | 327 | same | same | confirmed, merged |

- x452al's two largest gains: candidates as one flat record (a pattern
  match on a record that holds a record calls a runtime type test,
  15.8G of 51.9G), and memo entries in arrays per rule body (7.5G).
- x454r's report said it was 2.3-3.7x slower; those were single wall
  times under load. By Ir it costs the same as x451y on the 32 and 64
  rungs and on x(ab)*1600, and 1.016x on the battery.
- x456ai's `_tok = max(_tok, pos)` changes what `_tok` means (the token
  that starts last, not the one that ends last). It changed no tree on
  the battery or the fuzzer, so it is pure as measured, not by
  construction.
- The checker found that the worse/better count we use reads `^SCORE`
  lines that the CAT=1 battery output does not print, so it always
  gives 0/0. treeDiff and costDiff on the n=2101 line are the measure.

Round 46, merge (x461, on x455be; every row has x451y's trees on the
battery and all 8 fuzzer seeds; Ir in G):

| Engine | Change | Lines | Battery | 64/1 | x(ab)*1600 |
|---|---|---|---|---|---|
| x451y | reference | 330 | 51.8 | 67.6 | 32.4 |
| x455be | start | 297 | 52.7 | 73.0 | 56.6 |
| x461a | + q6 cleanups | 296 | 52.8 | 73.2 | 56.7 |
| x461b | + flat candidate record | 298 | 37.0 | 70.6 | 56.3 |
| x461d | + memo arrays per body | 301 | 45.1 | 60.5 | 53.0 |
| x461h | + `_gaps` cache, flat key | 299 | 52.0 | 72.9 | 32.9 |
| x461k | a+b+d+e+h + `_nfix` guard | 315 | 24.0 | 46.2 | 24.8 |
| x461qa | k shortened | 306 | 24.0 | 46.2 | 24.8 |
| x461zs | qa + iteration cache | 349 | 29.1 | 8.6 | 11.1 |

x461qa, confirmed by its checker:

- 330 -> 306 lines (-24, -7.3%) against x451y; 297 -> 306 (+9, +3.0%)
  against x455be.
- Same trees as x451y: battery 0.9811 treeDiff 0, fuzzer 8 seeds
  treeDiff 0 (invalid 67), gates and rung costs 6/8/13/16/31/65.
- Ir against x451y: battery 2.16x fewer, 64/1 rung 1.46x, x(ab)*1600
  1.33x.
- Depth unchanged: brackets 700 finish and 800 overflow; x(ax)*n b
  finishes up to n = 846.

The `_gaps` cache conflict is settled: q5 deleted it and measured only
the battery; without it x(ab)*1600 doubles (24.8G -> 48.7G), for 3
lines. The cache variant x461zs (+43 lines, not checked) takes the 64/1
rung 46.2G -> 8.6G but the battery 24.0G -> 29.1G; it needed a class,
not a record, for a run (a record costs 16G on the battery), forgetting
by blocks, and its state kept out of `_m`'s stack frame, or x(ax)*800 b
overflows. q2's claim that x452aq finishes x(ax)*800 b was wrong: it
overflows at about 746.

Elegance review of x461qa (x463, on x461qa). Changes with the same
trees on the battery and fuzzer: `_wins` grows the kept fix set in
place; a dead `_far` reset deleted; `m.len` is 0 on a terminal mismatch;
one candidate record per opener; the repetition marker holds the fix.
Two changes that alter trees:

- q, a fresh memo entry on forget: MemoEntry keeps foundLeftRec after
  its result is cleared, so a forgotten entry redid left-recursion
  growth with stale state. 1 fuzzer tree differs at equal cost, both
  valid; battery Ir -5%. The merge agent had rejected the same change
  (x461n) for that one tree difference.
- m, `!one` dropped from the opener condition: fuzzer worse 0 against
  6, invalid 66 against 67, battery unchanged.

Refuted in the review: dropping `at >= min(_tok, _best)` (7 battery
trees worse), the skip at the end of the input (13 worse), `kids.length
== real` (12 worse); `_wins` forgetting only from `_diff(_fix, x.fix)`
(fuzzer 5 worse: the next parse reads entries of the line computed
just before).

x463ym is x461qa with the five same-tree changes plus q and m. Its
checker did not run; I re-measured it:

- 306 -> 305 lines (-1, -0.3%).
- Battery 0.9811, treeDiff 0 against x461qa; gates unchanged; rung
  costs 6/8/13/16/31/65.
- Fuzzer 8 seeds against x461qa: worse 0 against 6, invalid 66 against
  67, treeDiff 14. Against sk10p: worse 45 against 153, invalid 66
  against 89.
- Battery Ir 24.04G -> 23.09G (-3.9%); 64/1 and x(ab)*1600 +0.5%.

x464a (mine) is x463ym with x453q's empty-fix mark (below): 306 lines,
battery treeDiff 0, gates unchanged, fuzzer treeDiff 2 against x463ym
(the two cases the mark changes; worse 0/0, invalid 66), 32 and 64
rungs cost 31 and 65 with as many edits, battery Ir 23.15G (+0.25%).
It is the current best.

Validity (x462, on x455be). x462x is x454r's ban rebuilt in 345 lines:
one left-edge walker serves both the insertion check and the
left-recursion exclusion, and the open elements include the arms of a
choice before the arm taken (the First:shorter class, which fixes
`R0 <- ('c' / ("abac" / R0+))` on "bcc"). Confirmed by its checker:

- 297 -> 345 lines (+48, +16.2%).
- Battery 0.9811, treeDiff 0 against x455be; gates unchanged.
- Fuzzer 8 seeds: invalid 37 against 67; worse 14 against 34.
- Ir: battery 1.22x, 64/1 1.02x, but x(ab)*400 4.6x (15.7G against
  3.4G), which the report gave as 2.2-3.5x from wall times.
- Restarting from position 0 or from the banned fix gives the same
  trees. Without the deletion check: 343 lines, invalid 44, worse 5.
  Without the choice arms: 342 lines, invalid 47.
- bcbab stays open: every rule that lets an element read past the
  inserted text (seven forms) bans too much, and q6's FIRST-set guard
  alone did not fix it.

Not adopted: x462x costs 39 lines and 4.6x on x(ab)*400 for 30 fewer
invalid trees; the open fix is to memoize the walker per (element,
inserted terminals) and to walk only the fixes added since the last
walk.

Robustness (x453, on x455be). x453s catches StackOverflowError at each
rule entry, records the entries it unwound, resets them, bumps
memoVersion and rematches the deepest first; `_edits` is iterative.
It finishes the depth family to 3200 and x(ax)*1600 b, and its
battery, fuzzer, gates and rungs equal x455be's at +1.7% Ir. The
checker refuted the report's other claims:

- On deep random inputs x453s sometimes returns the whole-input answer
  (cost n): 8 of 150 cases in the checker's run, 23 in the agent's own
  files, and once on rightrec-mid in 10 runs. Rerun alone, the same
  inputs cost 1 or 2. The inferred cause is a second overflow inside
  the handler, which leaves one entry with inRecPath set.
- x455be crashes on 41/29/34 of the random cases (the report said 7),
  and x453s times out on 9-13 per seed (the report said one input).

Not adopted. One part is: x453q, a zero-length syntax error where a fix
deletes and inserts nothing (1 line). Without it lastCost counts 1 and
the tree holds no error node, as in `S <- 'a' ('x'? !'b') [a-z];` on
"ab"; with it the tree's edit count equals lastCost on all 8 seeds.

Open: the stack depth (an explicit stack, or an overflow handler that
cannot overflow itself); bcbab; the walker's cost; the iteration
cache's battery cost; MemoEntry is imported from the parser's src/.

LOC: x451y 330 -> x461qa 306 (-24, -7.3%) -> x463ym 305 (-1, -0.3%)
-> x464a 306 (+1, +0.3%).
