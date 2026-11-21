<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Cross-review round 1 — the cdx line, and a bound that counts recursion depth (2026-09-22/23)

**Setup.** Codex, Gemini and a separate Claude session each got BRIEF1 and a
copy of the kit. Gemini ran out of quota (HTTP 429) before producing a
candidate. Codex's candidate is `_cdx1.dart`: c19's relation attached to the
ordinary parser's memo entries, one champion per end, a regular suffix bound,
and repetitions that share an ordinary occurrence when the next occurrence
also succeeds. It finished every rung, including 32 errors, but Codex also
proved that its repetition rule is not minimal: a six-character input where it
returns cost 3 and cost 2 exists. The cdx line below is that engine plus the
fixes found by the witness-oracle fuzzer (`_fuzz.dart SEED N engines...`,
which checks every answer against an exhaustive minimum on small grammars).

| Engine | Change | Battery | LOC (raw/norm) |
|---|---|---|---|
| cdx1 | Codex round-1 candidate | 0.9899/85.9, 1565 ms | 491/616 |
| cdx4 | the bound decides which stops a repetition exposes | 0.9899/85.9, 1418 ms | 497/627 |
| cdx5 | an edit may not be placed after a repetition departs | 0.9900/86.0, 2450 ms | 499/631 |
| cdx7 | ordered choice breaks ties in First | 0.9897/84.0 | 501/633 |
| cdx8 | stop guard | 0.9897/84.0 | 574/744 |
| cdx8p | `+` over a zero-width body | 0.9897/84.0 | 576/751 |
| cdx8x | flat-array bucket-queue bound; states whose only exit is free are merged | 0.9897/84.0, 1375 ms | 625/809 |
| cdx8y | the ladder starts at the bound's floor | 0.9897/84.0, 1372 ms, trees = cdx8x | 625/809 |
| cdx9r | the bound counts recursion depth; depth rows are bought as rungs fail | 0.9897/84.0, 1290–1334 ms, trees = cdx8y | 668/858 |
| cdx10 | the bound remembers the return site | 0.9899/84.3, trees = cdx9m | 845/845 |
| cdx11l | a later First arm must be one an edit could have forced | 0.9900/84.3 | 839/839 |
| cdx11o | four parts of cdx11l deleted; sealed repetition sharing kept | 0.9900/84.3, trees = cdx11l | 804/803 |
| cdx11r | Codex's three validity rules; fuzzer invalid 12/11/11/19 → 6/7/6/17 | 0.9900/84.3 | 835/837 |
| cdx11s | Codex round 3 minus the cdx11o deletions | 0.9900/84.3, 1,575–1,594 ms | 803/802 |
| cl8 | eleven rules deleted; the ordering penalty is a tie-break; fuzzer invalid 6/6/6/12 | 0.9900/84.3, 1,580–1,644 ms | 712/712 |
| cl10 | reference cycles and whole-literal substitution fixed; budget a parameter; corrected fuzzer invalid 11/9/11/9 (cl8 14/10/13/9) | 0.9900/84.3, 1,510–1,561 ms | 700/700 |
| cl11 | exact bound distances (512+ errors finish), iterative tree (LR 8,192 terms finish, quadratic), `_minChars` deleted; trees = cl10 | 0.9900/84.3, 1,461–1,523 ms | 696/696 |
| cl12 | semi-naive growth (LR with an error linear: 32,768 terms 868 ms), `first >= reach` in First, a substitution tie-break; corrected fuzzer invalid 8/8/9/6 (cl11 11/9/11/9) | 0.9899/84.3, 1,515–1,599 ms | 702/702 |
| cl13 | a diverse retry per budget and after the ladder (no-repair 10 → 0), same-stop guard conjunction, literal revival, resumption check, sealing (unclosed parenthesis linear); corrected fuzzer invalid 8/6/8/4 | 0.9899/84.3, 1,629 ms | 710/727 |
| cl14 | shared gap scan, position-ordered repetition worklist, covered repetitions, semi-naive seed fix, monotone success, gallop-and-bisect ladder, bound bought by counted front offers (no Stopwatch); all 46 families finish; corrected fuzzer invalid 8/6/8/4/7/7/8/10 | 0.9900/84.4, 2,164 ms | 800/803 |
| cl15 | ring-queue bound build (8000/4/7 9,354 -> 6,078 ms), `_versions` deleted, a new last ranking key (not transitive; removes the `aabb` bound dependence); battery treeDiff 1 vs cl14 at equal cost | 0.9900/84.4, 1,861 ms | 804/804 |
| cl16 | the last ranking key deleted (the ranking is transitive again; `aabb` bound-dependent again), `subs` and two filters that changed no result deleted; battery treeDiff 1 vs cl15 at equal cost | 0.9900/84.4, 1,850 ms | 796/796 |
| cl17 | an edit-count key above cost 1 (`acaca` bound-independent, 5 fewer invalid fuzzer trees, 4 fewer cases where cdx1 is cheaper), three redundant parts removed; battery treeDiff 0 vs cl16 | 0.9900/84.4, 1,820 ms | 792/792 |
| cl18 | the opener guard tests the whole inserted literal, and a covered repetition's stop is left to the repetition that encloses it (2 fewer invalid fuzzer trees, `cba` fixed); battery treeDiff 0 vs cl17 | 0.9900/84.4, 1,821 ms | 798/796 |
| cl19 | 27 lines of rewrites that change no answer (`_Relation` extends `_Front`, one exit array in the bound, no growth-counter reset); `_tail` exempts a growing stop only if it used a seed (`cbaa` now valid); invalid 51 -> 50, worse 18 -> 17; battery treeDiff 0 vs cl18 | 0.9900/84.4, 1,848 ms | 771/769 |
| cl20 | 12 lines of rewrites that change no battery answer (`_Relation` merged into `_Front` with a lazy log, `default: throw` dropped, seed sealing without `r.end > pos`); one fuzzer tree changes at equal cost; three shorter conditions refused as unproved | 0.9900/84.4, 1,866 ms | 760/757 |
| cl21 | growth on an explicit stack of `sync*` generators, so recovery reaches the plain parser's depth (brackets: cl20 overflows at 400, cl21 recovers at 1,600); a repetition does not extend a reading past its own body's stop, so `'x' ('a' A)*` with one error goes from cubic to quadratic; battery treeDiff 0 vs cl20, one fuzzer tree cheaper; AOT stress 9-27% slower | 0.9900/84.4, 1,995 ms | 805/799 |
| cl22 | cl21's growth as hand-written frames (`_Grow`, `_Pass`) instead of `sync*` generators, so AOT stress is back at cl20's speed at cl21's depth; a stop meets the guard it replaces, and rule 1 tests the guard's body tag, so 3 battery trees and 2 old-fuzzer trees become valid at equal cost (`caabb`: cl21's cost-1 answer was invalid); `x (ab)*n` 12% slower | 0.9900/84.4, 2,032 ms | 845/845 |
| cl23 | a stop this body already guards returns the reading unchanged (no new guard or closure per meet), so `x (ab)*n` is back below cl21 (1,600: 5,121 -> 4,236 ms); `_got` read directly; rule 1 and the new return share `_stopped`; trees = cl22 everywhere | 0.9900/84.4, 1,897 ms | 841/841 |
| cl24 | a repetition step that adds no character to the repaired string is not an iteration (PEG stops at an empty match), a `+` holds no reading before its first occurrence, a First rejects a later arm when an earlier arm reads the input after its leading deletion; strict-witness invalid 68 -> 50, worse 31 -> 12; battery treeDiff 0 vs cl23; seven families +1 (cl23 invalid there), eight slower by a constant factor | 0.9900/84.4, 1,897 ms | 861/861 |
| cl25 | a front keys an insertion that reads no input (`end == pos`, `missing > 0`) apart from the empty reading, and a collision of the two under one key triggers the diverse retry; eight nullable-body families 1.5-7x faster, five 13-29% slower, all costs equal; strict-witness invalid 50 = cl24, worse 15 -> 12; one old-fuzzer case (`aba`) now an invalid owed completion | 0.9900/84.5, 1,915 ms | 871/871 |
| cl26 | a lone completion costs 1, but after another edit each owed character costs 1; the stop guard tests the whole owed text, and a stop at the end of input gets no seed exemption; one comparator line proved dead and deleted; strict-witness invalid 50 -> 49, worse 19 -> 9 (three-way run); `aba` valid, `cbbb` (kind D) newly invalid; battery treeDiff 0 | 0.9900/84.5, 1,935 ms | 889/889 |
| cl27 | an insertion's lead runs on through every literal inserted after it, up to the first character read, deleted or of a class; the stop guard is carried across joins and tests all that text, so `owing` is deleted; the diverse key holds the lead up to the grammar's longest literal; three owed-completion cases valid at cost 1, strict-witness invalid 49 -> 48, old-fuzzer worse 2 -> 0; battery treeDiff 0; families 0-6% slower | 0.9900/84.5, 2,022 ms | 897/898 |

The table shows only battery score, time and size. It does not show the checks that separate the engines: measured in one kit on 2026-09-24, cdx1 has 389 invalid fuzzer trees on seeds 1-8 against cl15's 58, does not finish 4,096 errors, 8,192-term left recursion or 26 of the 46 families, and crashes on an unclosed parenthesis at 1,024 terms (see the cl16 section).

Round 19 (2026-09-26) found that the corrected fuzzer's witness (`_samedq`) accepted trees that are not PEG's tree of any string; under the stricter witness (`_samedw`) cl23 has 68 invalid trees on seeds 1-8, not 50. Earlier invalid counts in this file use the old witness. No engine replaced cl23 in round 19.

Round 20 (2026-09-26) promoted cl24: under the strict witness it has 50 invalid trees on seeds 1-8 against cl23's 68.

Round 21 (2026-09-26) promoted cl25: a front keys an insertion that reads no input apart from the empty reading, which makes eight nullable-body families 1.5-7x faster at equal cost; the strict-witness invalid count stays 50 and worse falls 15 -> 12.

Round 22 (2026-09-26) promoted cl26: owed characters after another edit cost 1 each, and the stop guard sees the whole owed text, so `aba` and two other trees become valid; strict-witness invalid 50 -> 49, worse 19 -> 9, battery trees unchanged.

Round 23 (2026-09-26) promoted cl27: the text inserted after a stop is tested as one string however the slots split it, so an owed completion can no longer revive the stop one slot at a time; strict-witness invalid 49 -> 48, battery trees unchanged, 889 -> 898 lines.

Round 24 (2026-09-27) promoted nothing: a diverse key wide enough to tell apart a lead that spans two literals makes a 6-character fuzzer input run past 120 s, and cl27 itself runs past 240 s on that input once the grammar holds an unused 4-letter literal, because the diverse search is exponential in the key's width. cl27 stays the engine with that flaw named.

The perfect-case drop 85.9 → 84.0 at cdx7 is the price of making First obey
ordered choice when two readings tie; it removed wrong answers that the
fuzzer found and the battery does not score.

**Fuzzer (confirmed).** Worse-than-minimum answers, seeds 2/1: cdx7 14/10,
cdx8x 8/3, cdx8y 8/3; at N=400, cdx8y and cdx9r both 0/0. The remaining
invalid answers (27 and 22 at N=400, 49 in all, the same counts for cdx8y) are
of two kinds. In 18, no reading is found and the whole input is deleted, although
a cheaper repair exists (`R0 <- (R1 (R1 / 'a')) 'b'; R1 <- 'a' / 'b'*` on `ca`:
`aab` costs 2). In 31, the tree's repaired string is not accepted by PEG, for
example an insertion inside a later First arm whose earlier arm would match
the inserted character (`R0 <- 'b' R1; R1 <- 'a' / ('b' / R0)+` on `bab`). 30 of
the 49 grammars contain a directly nested repetition of a body that can match
nothing (`'a'*+`), so that shape is involved often but is not the only cause.
Both kinds are open.

**Where the 32-error time goes (confirmed, `cdx8yp`).** The ladder runs rungs
21 → 29 and the last rung is 2/3 of the 60 s. Each extra unit of budget above
the floor multiplies a rung's time by about 2.7. The gap between floor and cost
is almost all bracket deletions. Deleting one structural character at 209
random positions of a 40-member document, the regular bound charged `]`, `[`
and `}` zero (0 of 13, 0 of 10, 0 of 14), while the true cost is one each. The
regular relaxation lets a recursive call return to any caller, so a missing
closer is never owed. A dominance prune (drop a way whose cost exceeds another
way's at the same cell by more than their difference in position) removed only
8% of the work and was dropped.

**The depth-counting bound (cdx9, confirmed).** Inside the one backward
distance computation, each state is paired with a count of open recursive
calls. A recursive reference becomes a push edge into the cycle and a pop edge
out of it, never merged with anything; the count saturates at a cap, and at
the cap push and pop are free, so the bound is admissible for every cap. End
of input is accepted only at depth 0. Only the minimum over depth is stored,
one byte per (position, state), so the table is the same size as before; the
depth rows exist only in two working rows. This corrects the synthesis round
above, which said this product needs a table of hundreds of megabytes: that
was true only if every depth were stored. The root value (depth 0 at position
0) is exact for every deleted-character type in the sweep, `[` included
(10 of 10). The stored minimum over depth still charges closers but not
openers (`[` 0 of 10), because a prefix may start at any depth.

**The cap (confirmed).** At 1000/32/1: cap 1, 2, 4 → 59–60 s (no gain);
cap 6 → 22.4 s; 8 → 22.7 s; 12 → 25.9 s; 16 → 27.0 s. Build time grows
linearly with the cap (0.2 s at 1, 1.8 s at 8, 5.2 s at 16 for 23.5k
characters), so a fixed cap of 8 made one-error recovery 8x slower
(1954 ms against 255). Doubling the cap after each failed rung fixed small
inputs but not medium ones (4000/4/2: 2320 ms against 909). The rule kept is
rent-then-buy: build the depth-0 bound first, and build the next one (cap
2c+1) only once the search since the last build has taken twice as long as that
build did, i.e. as long as the next build is expected to take. Its total is
within twice the better of never building and building at once, and it
has no tuned constant. The clock only decides when to prune harder; the
answers do not depend on it (battery treeDiff=0 and costDiff=0 for caps 8,
doubling and rent-then-buy against cdx8y).

Rungs, ms (all costs correct, all covered):

| Rung | cdx1 | c20y | cdx8x | cdx8y | cdx9 (cap 8) | cdx9r |
|---|---:|---:|---:|---:|---:|---:|
| 1000/1/1 | 98 | 210 | 242 | 255 | 1954 | 282 |
| 1000/8/1 | 905 | 1091 | 484 | 475 | 2171 | 498 |
| 1000/16/1 | 1561 | 2167 | 1367 | 1341 | 2472 | 1557 |
| 1000/32/1 | 49681 | 31464 | 61037 | 60088 | 23093 | 28276 |
| 4000/4/2 | 2840 | 3382 | 893 | 909 | 8044 | 990 |
| 8000/4/7 | 5521 | 7354 | 1914 | — | 15862 | 1914 |

cdx9r passes every check: battery 0.9897/84.0, accept t/t/t, freespan
3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0 (all
identical to cdx8y), props 2728/0 violations, pred falseAssertions=0, window
counterexample P kept at n = 64, 256, 4096. LOC 809 → 858 normalized (+49,
+6.1%).

**A clean empty reading hid the deletion (cdx9m, confirmed).** `_seq`
offered a deletion before a slot only when the slot had no clean reading. A
slot that can match nothing always has one, so "delete this character, then
read the slot" was never tried, and the need surfaced later where only a
substitution or a long skip remained. With `R0 <- (R1 (R1 / 'a')) 'b';
R1 <- 'a' / 'b'*` on `ca`, every engine from cdx8 on found no reading and deleted
the whole input. Changing the condition to "no clean reading that advances"
(one line) gives: battery 0.9897/84.0 → 0.9899/84.3, costs changed in 51 cases,
all 51 lower (none higher); fuzzer worse-than-cheapest (against cdx9r) 10 → 1
and 18 → 0 at N=400, invalid 27 → 26 and 22 → 21; every gate, props, pred and
window unchanged; LOC unchanged (858). Price: 32 errors 32.1–32.5 s → 37.3–38.3 s
(alternated, same load), other rungs +5–16%. A second experiment, keying the
front by (end, has guard) so a guarded way cannot displace an unguarded one,
changed nothing on the fuzzer and was dropped. The `ca` case itself is still
invalid under cdx9m: the deletion lands after `R1`'s empty reading, and on the
repaired string PEG's first arm would then take the `a`. An edit placed right
after an empty match changes what that match sees; the stop guard covers this
only for repetitions and insertions, not for ordered choice or deletions.

**Still open.** (1) The two-sided cell prune: min over depth of (prefix
bound + suffix bound) would charge missing openers too, but it needs one
direction stored with its depth. (2) The zero-width repetition bodies above.
(3) 32 errors still take 28 s; the gap between floor (22) and cost (29) is
the remaining work, and the first rungs above the floor cost almost nothing
(confirmed), so the remaining work is in the bound, not the search
(inferred: a tighter bound would raise the floor and prune the last rungs;
not yet measured).


**The Claude seat's round-1 engines.** The seat hit its 3-hour limit without
a report. It built on c19 and added pruning contexts per cell (`_x5` is its
`cand.dart`, `_x7`/`_x7j` add a frame stack). Measured in the orchestrator's kit
(2026-09-23): battery 0.9900/86.1 for all three (c19's tie-breaking, which
returns trees PEG would not produce), 2066/2114/2508 ms; against cdx9m, costs
differ in 51 cases and none is lower. LOC 635 (x5) and 712 (x7) normalized.
Rungs: 1000/1/1 696 and 701 ms; 1000/8/1 42,368 and 14,739 ms (cdx9m 574);
1000/16/1 does not finish in 300 s for either; 4000/4/2 4,028 ms (x5). Smaller
than cdx9m, but dominated on cost and on every many-error input, so it was not
carried into round 2.
