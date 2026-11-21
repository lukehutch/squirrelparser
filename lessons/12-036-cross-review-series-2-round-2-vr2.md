<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.36 Cross-review series 2, round 2 (vr2): critique of round 1, three engines beside vg1, a checker gap, and z34

**The round.** Base z33 = kit `vg1`. Same agents and models as round 1 (Claude claude-opus-5-5 medium, Codex
gpt-6.1-sol medium, Gemini gemini-4-argon high). Brief: `squirrel-xr/vr2/BRIEF2.md`; each agent first reviewed the
other two round-1 reports, then built an improved engine. Engines: Claude `vc2` (vg1 minus `r.evidence > r.subs`) and
`vc2s` (vg1 plus a rerun of the exact rungs below the first answer's cost); Codex `vx2` (substitution provenance moved
into the fragment, `_subOf` removed, a dead `used > _budget` check removed, a mapper change for substitutions in class
slots); Gemini `vg2` (`_tails` stored in `_cells`, `seeded` folded into the sign of `dep`, a merged prefix scan, new
`_seq` settle conditions). The orchestrator built two merges: `z34a` (vg2's size cuts with vg1's `_seq` lines, vx2's
changes 1 and 2, vc2s's rerun) and `z34b` (z34a without the rerun). All numbers were re-measured in
`squirrel-xr/vr2/orch/` (logs named below) unless marked "agent's figure". The issues decided are R2-1 to R2-9 in
`squirrel-xr/vr3/HISTORY.md`.

**Ruling (the orchestrator, R2-1): a one-character substitution into a class slot is a valid repair, and `_wit89`
was wrong.** vg1 renders `ax -> bx` on `S <- &'b' [ab] 'x';` as one one-character error in the `[ab]` slot (one
edit, cost 1). `_wit89` filled a one-character error only from a one-letter literal slot, so it read the class slot
as a deletion and called the tree invalid; Codex reported six such "class-rendering validity failures". The checker
is now `_wit91.dart` (`_wit89` plus: a one-character error in a class slot may be filled by any member of the
class). Controls `_wit91test.dart`: 9 of 9 as expected, 5 negative (`wit91_o2.log`). Under `_wit91` every round-2
engine is valid on the six fixtures with marks = cost. vx2's mapper change renders the same repair as a deletion plus
a hole, marks = 2 x cost for a one-edit repair: it fits the tree to the checker's gap, and is rejected.

**New families with computed optima (R2-9).** Each has an exact dynamic program in `tools/` and a script in the kit.
`semi3` (`S <- E ';' E ';' E`, LR `E`, M = 7, five shapes x k = 1..6, 8: 35 inputs, `exprdp_semi3.py`); the T family
(`S <- T+; T <- '(' T* 'a' 'b' 'c' ')' / 'z';`, M = 2, six units x k = 5, 6, 8, 10, 20: 30 inputs, `exprdp_t.py`;
LL(1), so PEG and CFG agree); the grouped grammar of R2-3 (`group.sh`). Optima of the T family:

| Unit | k = 5 | 6 | 8 | 10 | 20 |
|---|---|---|---|---|---|
| `(axyz)` | 15 | 18 | 24 | 30 | 60 |
| `(axy` | 15 | 18 | 24 | 30 | 60 |
| `(xyzd)` | 20 | 24 | 32 | 40 | 80 |
| `(axyzw` | 20 | 24 | 32 | 40 | 80 |
| `a(xy)` | 16 | 19 | 26 | 32 | 64 |
| `(ax)(` | 15 | 18 | 24 | 30 | 60 |

**R2-3: vg1's `r.subs <= i` depends on how a sequence is grouped** (Codex, confirmed in `group_r2.log`).
`T <- '(' E ')' / [0-9]` and `T <- ('(' E) ')' / [0-9]` accept the same strings, but on LR `(1+` x 16 / x 32 vg1 and
z34b price 11 / 23 on the first grammar and 14 / 30 on the second. vg2 and z34a give 11 / 23 on both. A condition
whose effect on the price changes when a sequence is regrouped is not derived from PEG semantics (constraint 3). This
answers 12.35's open item 1: the condition is a fit, not a derivation.

**R2-2: `r.evidence > r.subs` is not a no-op** (Claude). vc2 (vg1 without it) equals vg1 on every suite line, but on
`(axyz)` x 40 the price rises 139 -> 160 (agent's figure, Claude R2). vc2 is rejected. The suite had no family that
reached this condition; the T family now does.

**R2-7: the price is NP-hard on general PEGs** (Codex and Gemini: Cheon and Han, DLT 2020; edit distance to a PEG
language is NP-complete with a unary bound). Exactness can only be measured on families with a computed optimum, and
an engine exact on every grammar in polynomial time is not to be expected.

**R2-8 (open): `_Cell._key` masks `first` to 20 bits** (Claude); ways whose `first` differ by a multiple of 2^20 share
a key. Latent below 2^20 characters.

**Results** (each engine beside vg1 in one command; logs `suite_vx2.log`, `suite_vc2s.log`, `suite_vg2.log`,
`suite_z34a.log`, `suite_z34b.log`, `semi3_r2.log`, `semi3_z34a.log`, `group_all.log`, `tfam_small.log`). Every engine
gives, beside vg1: battery 0.9907, treeDiff 0, costDiff 0; all gates (cx2, b1, b2; freespan 3 3 4 4 1; recommit
16/16; conformance 0 1 1 0 2 3); pdl / plf worse 0 / 0, invalid 0; exhaustive 0 of 61,204 more expensive; long sets
0 of 1,800; Dyck 0 of 1,932; class fixtures 0 of 900 invalid; every dense tree valid. They differ here:

| Check | vg1 = z33 | vx2 | vc2s | vg2 | z34a | z34b = z34 |
|---|---|---|---|---|---|---|
| semi (27): above the optimum | 3 | 3 | 0 | 0 | 0 | 3 |
| semi3 (35): above / total excess | 3 / 4 | 3 / 4 | 0 / 0 | 4 / 9 | 0 / 0 | 3 / 4 |
| group (9): above | 4 | — | — | 0 | 0 | 4 |
| T family (30): above / total excess | 15 / 88 | 15 / 88 | 13 / 69 | 11 / 52 | 13 / 69 | 15 / 88 |
| Dense k = 1024 non-LR `(1+` (ms) | 516-651 | 638 | 1,923 | 773 (vg1 855) | 1,688 | 561-652 |
| non-LR `1+)` | 1,577-1,699 | 1,760 | 1,557 | 2,782 (vg1 3,900) | 1,598 | 1,533 |
| LR `(1+` | 435-535 | 445 | 1,748 | 843 (vg1 968) | 1,699 | 435-522 |
| LR `1+)` | 83-87 | 97 | 1,453 | 195 (vg1 120) | 1,382 | 82 |
| `cbcaccbccab` x 32 (ms, price 95 in all) | 4,380-4,913 | 4,921 | 4,522 | 7,896 (vg1 6,187) | 4,732 | 4,948 (vg1 5,029) |
| Dyck time (engine / vg1, s) | — | 6.2 / 6.3 | 6.7 / 5.9 | 10.1 / 10.0 | 7.0 / 6.5 | 6.6 / 6.5 |
| LOC (`loc.sh`) | 593 | 593 | 595 | 588 | 588 | 586 |

vg1's times are a range over the runs of this round; times in parentheses are vg1 in the same run (vg2's suite ran
on a loaded machine).

**The `lastCost` defect (new, open).** On `(xyzd)` x 8 every engine's `lastCost` is 40 while the witness price of its
own tree is 33 (optimum 32; `tfam_small.log`). On every other T-family input the two agree. `lastCost` is meant to be
the cost of the tree returned.

**z34.** z34b's full suite beside vg1 (`suite_z34b.log`) equals vg1 on every line, including the trees (treeDiff 0) and
the dense prices; its times are within the spread of vg1's across runs (the range in the table covers a run made while
another build was compiling). z34b becomes **z34** (`_z34.dart`): vg1's trees, prices and times in 586 LOC (593 -> 586, -7, -1.2%);
`_Way` unchanged (10 integers + `piece`, `prev`); `_Cell` 5 -> 4 scalar fields (`seeded` folded into the sign of
`dep`); engine tables `_subOf` and `_tails` removed (the tails live in `_cells` under a `(clause, end)` key, whose
map changed from `Map.identity()` to `{}`). The rerun (z34a) is not adopted: it buys semi, semi3 and group exactness
and 2 of 15 T-family misses at 3-17x on dense inputs.

**Agents' report errors** (recorded in `vr3/ERRORS_*.md`). Gemini (R2_GEMINI line 257) gave the semi3 k = 8 optimum
as 16 (it is 15) and vg2's price there as 17 (it returns 18), from a test of k = 1, 2, 4, 8 only; on all 35 inputs
vg2 is above the optimum on 4 (excess 9), against vg1's 3 (excess 4). Codex's six "validity failures" were the
checker's gap, and its mapper change fit the tree to that gap. Claude: no error of fact found.

**Quantitative summary.** No round-2 engine dominates vg1. Each gain is paid for elsewhere: the rerun (vc2s, z34a)
makes semi, semi3 and group exact at 3-17x the dense time; vg2's `_seq` conditions fix semi, group and 4 T-family
inputs and lose semi3 (1 more input above, excess 4 -> 9). The only change with no cost is size: z34 is 7 lines
smaller with one cell field and two engine tables fewer, at vg1's behavior. The T family is where every engine is
furthest from the optimum (15 of 30 above, total excess 88 for vg1/z34).

**Qualitative assessment.**
- The round's main result is again measurement: a checker gap (R2-1) that made correct one-edit repairs look invalid,
  three new families with exact optima, the grouping test that exposes `r.subs <= i` as fitted, and a `lastCost`
  that disagrees with the tree. Without the new families, vc2, vg2 and z34a would all have looked equal to vg1.
- The agents were most useful as critics. Codex found the grouping dependence; Claude found that `r.evidence > r.subs`
  matters and that the fuzzers never computed `priceWorse` (`_pdl.dart:322`; it needs the reference `xrefmz`, now
  always run in the vr3 kit); Gemini's size cuts were adopted. As designers, all three made local changes to vg1;
  none built the unified evaluator or the per-cost bound proposed in round 1.
- Exactness and speed now pull against each other in a measured way: a rerun below the first answer's cost finds the
  cheaper repairs, so the first pass's local search is what misses them. The open question is what memo-table fact
  would let the first pass find them, which is the kind of answer the guiding principle asks for.
- The engine is still 586 lines against the parser core's idea of one memo entry. Size fell for the first time in
  this series, but by deleting bookkeeping, not by a simpler mechanism.
- All three agents say further improvement is possible on every metric; the series continues.

**Open for round 3.** (1) Exactness without the rerun's cost. (2) Conditions in `_seq` whose effect does not change
when a sequence is regrouped (R2-3). (3) The T family. (4) The `lastCost` defect. (5) `cbcaccbccab` scaling, about 4x
per doubling of k from k = 16. (6) R2-8, the 20-bit key. (7) Size and bookkeeping ablation. (8) The unbuilt
proposals of round 1.
