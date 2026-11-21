<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.19 Round 72: cross-review round 2, and an exact engine under a tree definition (fx1-fx10)

**Round 2** (brief `squirrel-xr/ur2/BRIEF2.md`; checks in `ur2/NOTES_R2.md`). Codex and
Claude finished. Gemini's run hit the 5-hour timeout (rc=124) and wrote no report; its kit
held two engines, arg3 and arg4, which I copied into the master kit and measured myself.

| Engine | Agent | LOC | Price at the end of the input (run of m insertions) | Battery | Gates | dl / lf levWorse |
|---|---|---|---|---|---|---|
| z15 | - | 542 | 1 | 0.9899 / 86.2 | all pass | 118 / 101 |
| sol3 | Codex | - | I + ceil(L/B), B = n + size(G) | 0.9899 / 86.2, treeDiff 0 | all pass | 118 / 101 (Codex's run) |
| opu4 | Claude | - | ceil(m/(n+1)) | 0.9899 / 86.2, treeDiff 0 | all pass | 118 / 103 |
| opu7 | Claude | - | m | - | recommit 14/16 | 0 / 0 |
| opu8 | Claude | - | m | - | conformance fails | 110 / 86 |
| arg3 | Gemini | 607 | m | 0.9692 / 75.6 | all pass | not run |
| arg4 | Gemini | 610 (+68, +12.5%) | 1 up to M, then 1 per further character; M = sum of the rules' shortest matches | 0.9902 / 86.4, 4.0 s | all pass | 99 / 76 |

sol3 and opu4 make exact repair decidable (a cost bound now bounds the length of the end
run) and change no battery tree; Claude's and Codex's decidability proofs were read and are
sound. arg4's M is computed from the grammar, so it is not a fixed constant (D2). Invalid trees
and timeouts are 0 for every engine in the table.

**Hardness.** Two results, both for the string definition S (the repaired string must parse
under the library parser, and the cost is the edit distance to it):
- under the collapsed price, exact repair is undecidable already at cost 1 (12.18, sketches);
- under the per-character price, exact repair is NP-hard: Codex with the grammar growing with
  the formula, Claude with a fixed grammar (`r2np 200 5`: the parser agrees with the formula
  on 200 of 200 instances; 4 variables timed out).
These say nothing about weaker definitions. The user objected (2026-10-26) that a bottom-up
parse into fragments, as in the pika parser, followed by a splice of the fragments, should be
near linear. That is right for a definition where each parse judgment is made on the input
as written (definition F below): the cost of a (clause, start, end) cell is then a sum of its
parts' costs, and a dynamic program over cells is exact and polynomial. What F gives up is
measured below: its trees are not always parses of the repaired string.

**Two more round-2 facts.**
- `ab if` (posGrammar): cost 2 is optimal (the parser accepts `ifb if`), so the gate's 3 is
  z15's suboptimal cost. But the exact engines' trees for it fail the witness check: the tree
  maps a class repair wrongly. The fuzzers do not see this, since their grammars have no
  classes.
- Per-character exactness contradicts the recommit gate: xrefp completes `[1,[2,[3,[4` as a
  String at cost 2, where the gate wants an Array (z15 4, z16a 3).

**The fx line: an exact engine under definition F.** One file, a dynamic program over
(clause, start, end) cells with doubling cost budgets, 223 to 238 LOC (z15 542).
- fx1, definition F: every judgment (choice arm, repetition stop, absent option, predicate) is
  made on the input as written, at the clause's start.
- fx2, definition F+: a judgment at a position where an edit is made is free. Two key bits:
  `s` (the derivation starts with an edit) and `o` (what follows must start with an edit).
- fx3 to fx9 add tie-break keys after cost. Each key adds or takes a minimum part by part,
  so the program stays exact: d (input characters destroyed), the characters a rule reads
  after its own edit, the position of the first edit (later wins), and one destroyed
  character per rule made only of inserted text.

Battery deltas against z15 (`split.sh`, total over 2,101 cases; z15 scores 0.9899):

| Engine | Change | Score | Total delta | Gates |
|---|---|---|---|---|
| fx2 | F+, collapsed price | 0.9499 | - | b1 and freespan fail |
| fx3 | + destroyed count, end-of-input scaffolding unlabeled | 0.9741 | -33.2 | b2 fails |
| fx4 | characters read by a leaf rule containing an edit count as destroyed | = fx3 | 0 | Str calls Chr, so Str is not a leaf |
| fx5 | + characters read after a rule's own edit | 0.9832 | -14.0 | |
| fx6 | a deletion is an own edit too | | -13.9 | |
| fx7 | + first edit position, ranked after d | | -12.1 | |
| fx7f | first edit position ranked before d | 0.9849 | -10.5 | b2 fails |
| fx8 | + "reads no input" bit | | -18.3 / -13.6 | refuted |
| fx9 | + invented rule counts as destroyed | | -26.7 | b1 fails |
| fx9f | fx9, first edit before d | | -15.3 | all pass |
| fx10 | fx9f reporting z15's tree shapes and edit count | 0.9826 / 81.3 | -15.3 | all pass |

b2 (delete the stray comma in `[,2,33,true]`) and the expr cases with a missing operand
(insert one) pull against each other, and no local rule found here wins both; z15 itself
inserts in expr i=242 and 250 and deletes in json i=38.

**F is not sound for PEG.** The fuzzers (16 seeds x 400, `LIMIT=30`):

| Engine | dl invalid | dl levWorse | lf invalid | lf levWorse |
|---|---|---|---|---|
| z15 | 0 | 118 | 0 | 101 |
| fx9f | 2,567 | 2,599 | 2,546 | 2,601 |
| fx10 (before the shape fix) | 1,848 | 2,022 | 1,873 | 2,017 |
| fx10 | 297 | 428 | 189 | 301 |

Most of fx9f's invalid trees were shape: it left end-of-input insertions out of the tree, and it
wrapped a substitution in a `Char` node, where the witness check reads a fill only from a bare
`SyntaxError` in the parent's slot. The rest are real: a judgment made on the input does not
hold on the repaired string. Example: `S <- R0; R0 <- ((R0 'b' 'a') 'c' (R0 R0 R0)) / 'a'++;`
on `aab`. fx10 completes it as `aabacaaa` (cost 5); a PEG parse of that string fails, because
the first `R0` of the three takes all of `aaa`. z15 deletes the `b` (cost 1). The `o` bit sees
only input, never inserted text, so a greedy repetition followed by inserted text is unchecked.
Making each cell carry what follows it would make the judgments sound, but a cell's cost then
depends on its continuation, which is the same continuation dependence that made the pd line
(pd23, pd46) cubic.

**Speed.** fx10 takes 11.8 s on the battery against z15's 3.7 s; json cases with two errors take
up to 168 ms each, because each doubling of the budget recomputes every cell.

**Conclusion.** No fx engine is adopted. The fx line shows where the polynomial exactness the
user asked about comes from (judgments fixed by the input) and what it costs (repairs that do
not parse).

**z16: arg4, reduced.** arg4 is z15 with five changes: the price above (`int get cost` at
`arg4.dart:19`, M recomputed in `_recover` on every call), wider `_Cell._key` and repetition-queue
keys, a loop over start offsets in `run()`, an edit-distance pass after the check that can lower
the reported cost, and a retry one cost lower. On the dense probes (`dens5.exe`, k=256) arg4 ran
over 120 s on the first two. Bisected:

| Step | Dense k=256 (three probes, ms) | Battery | Note |
|---|---|---|---|
| arg4 | >120,000 / >120,000 / 6 | 0.9902 / 86.4 | |
| queue key reverted to z15's (`end`, incomplete, clean-with-cut) | 7,300 on probe 1 | same trees | the `used` field in the key made the queue grow with the error count |
| start-offset loop limited to 0 (z16p) | 91 / 102 / 6 | treeDiff 0 vs arg4 | |
| no edit-distance pass (z16x) | | treeDiff 0 vs z16p | dl / lf `worse` 104 -> 107 / 80 -> 87, levWorse unchanged 100 / 76: the pass lowers only the bill |
| no retry (z16y) | | treeDiff 0 vs z16p | levWorse 100 / 76, `worse` unchanged |
| neither, loop deleted (z16) | 84 / 102 / 6 | treeDiff 0 vs z16p | |

**A stack-overflow defect, found by the deletion.** Without the edit-distance pass, the nesting
test (`depth.exe`, `[`*n `n` `]`*(n-1)) was 6 to 9 times slower at n = 400 to 1600 (451 / 582 / 852
ms against z16p's 53 / 79 / 140). The pass never runs on that input (cost 1). Counting `_read`
calls in the deep sweep after the first `StackOverflowError` (`_sodrv.dart`, instrumented copies):
z16 made 150,456, z16p 17,598, with the same cell and evidence counts at the catch. The catch in
`run()` cleared the engine's cells but kept the library parser, and the overflow can stop that
parser in the middle of a match and leave its memo half written. Whether it does depends on
where the stack runs out, which depends on frame sizes, so deleting unrelated code in `recover`
moved the overflow and exposed it. Fix: the catch makes a fresh parser, as the catch around the
first parse already did (`z16.dart:398-402`). Then 63 / 89 / 171 / 423 ms at n = 400 / 800 /
1600 / 3200 (z15 50 / 66 / 141 / 364, same run), and the battery trees do not change. z15 and
earlier engines carry the same catch; they are fast on this test only because their overflow
happens elsewhere.

**z16 against z15** (16 seeds x 400, `LIMIT=30`, xrefp in the same run; battery `BASE=z15`):

| | z15 | z16 |
|---|---|---|
| LOC | 542 | 562 (+20, +3.7%) |
| Fields per reading / cell / engine | 13 / 7 / 17 | 13 + one static (M) / 7 / 17 |
| Battery | 0.9899 / 86.2, 3.7 s | 0.9902 / 86.4, 3.9 s; 73 trees differ, 44 costs lower, 4 higher |
| Gates | all pass | all pass (freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3) |
| dl worse / levWorse / invalid | 132 / 118 / 0 | 113 / 100 / 0 |
| lf worse / levWorse / invalid | 140 / 101 / 0 | 92 / 76 / 0 |
| Dense k=1024 (three probes) | 446 / 556 / 22 ms | 495 / 620 / 31 ms |
| Nesting, one missing `]`, n = 3200 | 364 ms | 423 ms |

The four higher battery costs (json i=1683 `{"alpha":"b` 2 -> 3; expr i=1830 `a+b*2-(3+`, i=1834
`1*(2+`, i=1883 `a*(b+` 1 -> 2; xrefp 2, 1, 1, 1) are one effect. On `1*(2+` z15 substitutes `)`
for the `+`; z16 keeps the `+` and inserts an operand and `)` at the end. Under z16's price both
cost 1 (an end run no longer than M costs 1), the tie-break takes the insertion, and the
per-character bill is 2. This is the price working as designed: it ranks a short completion as
cheap as one interior edit.

**Conclusion.** z16 replaces z15 as the reference engine: same gates, a slightly better battery,
18 / 25 fewer cases farther from the optimum than xrefp, and speed within about 20% of z15 on
every probe. It is still not exact under any price: 100 dl and 76 lf cases remain. The price is
decidable (cost c bounds an end run by M + c - 1 characters). The fx line shows that an
exact polynomial engine needs judgments that do not depend on what follows, and PEG judgments do.
