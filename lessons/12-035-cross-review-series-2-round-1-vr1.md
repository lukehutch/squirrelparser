<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.35 Cross-review series 2, round 1 (vr1): three engines beside z32, a ruling on class holes, and a gate lost since round 79

**The round.** After round 87 the author asked for rounds of cross-review: Claude (claude-opus-5-5,
medium), Codex (gpt-6.1-sol, medium) and Gemini (gemini-4-argon, high) each analyze all progress,
propose the one optimal engine, build and test it; later rounds critique each other's engines and
improve on them. Brief: `squirrel-xr/vr1/BRIEF1.md`. Engines: Claude `vc1b`, `vc1s`; Codex `vx1`,
`vx1a`; Gemini `vg1`. All numbers below were re-measured by the orchestrator in
`squirrel-xr/vr1/orch/` unless marked "agent's figure".

**Ruling (the author, 2026-10-30): a class hole is a valid repair.** When a repair needs a character
that only an open class (`[0-9]`, `[ab]`, `.`) can supply, the tree marks a zero-width error under
the class. It is owed one member of the class, priced as one insertion, and the tree is valid if
some member makes it parse. This is D7's "structural completion". It settles a conflict Claude and
Codex both proved: under the old witness rule (a hole has no witness), gate cx2 (`xa` on
`S <- A 'x' 'a'; A <- [ab];` with zero deleted characters) cannot pass with a valid tree.

**New check: `_wit89.dart`.** The fuzzers' witness rule (`_pdl.dart`) with one change: a lone
zero-width error under a CharSet or AnyChar is filled with one member from each region of the code
space on which every class and literal of the grammar is constant. `_val89.dart` (dense validity)
and `_vxcl89.dart` (Codex's six class grammars, seeds and their one-character edits, 900 inputs)
use it. Negative controls (`_wit89test.dart`): a hole under `[a-z]` after `&'q'` with the real
class is valid, the same tree under `[0-9]` is not; `!'a' [ab] 'x'` valid, `!'a' !'b' [ab] 'x'`
not. All four print as expected. Limitation: a one-character substitution into a class slot is
still not accepted, only a zero-width hole.

**Correction of 12.34 (open item 1 withdrawn).** Under the ruling, every z32 tree on the dense
families is valid (`val89_r1.log`: 96 of 96 trees valid across yo3, vc1b, vc1s, vx1), and the class
fixtures give 0 invalid of 900 for every engine (`vxcl89_r1.log`). What 12.34 called invalid
trees were class holes.

**The exact optimum of `(1+` x k, both grammars** (Claude's `exprdp.py`, a CYK-style dynamic program
over the CNF of the expression language; `brute.py`, an independent enumeration, agrees for
k <= 6; both re-run by the orchestrator):

| k | 1 | 2 | 3 | 4 | 5 | 6 | 8 | 11 | 16 | 32 |
|---|---|---|---|---|---|---|---|---|---|---|
| with class holes | 1 | 1 | 2 | 2 | 3 | 4 | 5 | 8 | 11 | 23 |
| literals only | 1 | 2 | 2 | 2 | 3 | 4 | 5 | 8 | 11 | - |

12.33's "k + 1 is the minimum" and 12.34's "the minimum at k = 2..6 is k" are both wrong. Above
k = 6 only the dynamic program checks these values.

**z32 has failed gate b2 since round 79.** D8's second reading (`[,2,` reads as `[2,`) is the
acceptance line's `b2`. `suite.sh` printed `gates | tail -4`, which drops that line, the fifth from
the end. z24 deleted z23's deletion-preference rule `pen`, although the round-79 ablation table
(line 11308) records "`pen` 0.9908 ... b2 fails ... keep (D8)". Every engine since, z24 to z32,
fails b2, and no suite showed it. Found by Claude (log `s1_accept_history.log`, agent's figure),
confirmed here: `r18s4.exe gates yo3` prints `accept cx2=true b1=true b2=false`. `suite.sh` now
prints `tail -5`.

**Results** (each engine beside yo3 = z32 in one command; logs `suite_vc1b.log`, `suite_vx1.log`, `suite_vg1.log`):

| Check | z32 (yo3) | vc1b (Claude) | vc1s (Claude) | vx1 (Codex) | vg1 (Gemini) |
|---|---|---|---|---|---|
| Idea | — | z32 + z23's deletion preference | z32, no class insertion (strict D7) | z32, no class insertion + a work allowance | z32 + deletion preference + left-recursive continuation table + looser local settle |
| Battery score / treeDiff / costDiff | 0.9911 | 0.9907 / 50 / 0 | 0.9547 (agent's figure) | 0.9568 / 539 / 337 | 0.9907 / 50 / 0 (treeDiff 0 against vc1b) |
| Gates cx2, b1, b2 | yes, yes, **no** | yes, yes, yes | no, yes, yes | no, yes, yes | yes, yes, yes |
| Other gates | — | same | same (agent's figure) | same | same |
| pdl / plf worse (6,400 each) | 0 / 0 | 0 / 0 | — | 13 / 5 | 0 / 0 |
| Exhaustive dearer (61,204) | 0 | 0 | — | g1 40, g4 11 | 0 |
| Long sets dearer (1,800) | 0 | 0 | — | g1 22 | 0 |
| Dyck dearer / time | 0 / 7.0-7.2 s | 0 / 7.3 s | — | 197 / 8.1 s vs 6.7 | 0 / 6.2 s vs 7.0 |
| Dense LR `(1+` k = 1024 | 10.9 s | 12.4 s | does not finish | does not finish | **0.45 s** |
| Dense non-LR `(1+` / `1+)` k = 1024 | 3.3 / 3.1 s | — | — | — | 0.64 / 1.6 s |
| Dense `cbcaccbccab` k = 32 | 12.1 s | — | — | — | 4.4 s, same price 95 |
| Valid, `_wit89` (dense, classes) | all, 0 of 900 invalid | same | same | same | same |
| LR `(1+` price at k = 11 / 16 / 32 / 128 (optimum 8 / 11 / 23 / 95) | 10 / 15 / 31 / 127 | 10 / 15 / 31 / 127 | 8 / 14 / 30 / 126 | 9 / 14 / 30 / 126 | **8 / 11 / 23 / 95** |
| LR `1+)` price at k = 32 (optimum 32) | 33 | 33 | 32 | 32 | 32 |
| LOC | 593 | 598 (+5, +0.8%) | 594 (+1) | 616 (+23, +3.9%) | 593 (0) |
| Fields `_Way` / `_Cell` | 10 / 4 | 10 / 4 | 10 / 4 | 10 / 4, +1 engine field | 9 / 4, +1 engine table `_tails` |

The 50 battery trees vc1b changes are all one shape: a value missing before a comma or a digit
missing in a number (`[,33,`, `.5`, `e3`); z32 fills a hole, vc1b deletes the comma, both at cost 1.
That is b2's reading. The battery's expected trees and D8 disagree on these inputs; the 0.0004 is
the known price of D8 (round 79 measured 0.9904 with `pen` against 0.9908 without).

**What vg1 changes** (diff against yo3, comments and blank lines removed, 90 lines). Three parts:
(1) z23's deletion preference `pen`, the same fix as vc1b, which restores b2; (2) `_tails`, a table
keyed by (left-recursive clause, clean end of its base match) holding the continuations an inner cell
already found; an outer cell that reaches that end with a settled way composes them instead of
growing the loop again step by step; (3) wider `rSub`/`sync`/`canS` conditions in `_seq` in local
mode, so the last slot of `E <- E '+' T` can settle a pure-substitution prefix. The field `incomplete`
is replaced by a test on fields the way already has (`deleted == 0 && end == pos && !clean`). The LOC
is unchanged partly because vg1 joins onto one line several statements z32 splits over two; about 15
lines of new logic were added.

**Gemini's named refutation test, run.** Gemini's report (D.4) names as most likely wrong the
conjecture that `_tails` never loses an intermediate stop, and proposes `(1+`^k`;1+1` on
`S <- E ';' E`. Run here with `_tail90.dart` (whole inputs, `_wit89` validity) on 27 inputs
(`(1+`^k`;1+1`, `1+1;(1+`^k, `(1+`^k`;(1+`^k, k = 1..6, 8, 11, 16), against the exact optimum
from Claude's dynamic program extended with `S -> E ';' E` and the engines' cap M = 5
(`orch/exprdp_semi.py`, logs `exprdp_semi.log`, `tail90_semi.log`). z32 is dearer than the optimum
on 7 of 27, by up to 8 (31 against 23). vg1 is dearer on 3 of 27, by 1 each (16/15, 12/11, 24/23;
all with k >= 11 groups before `;`). The control Gemini named (vg1 with `fresh.add(r)` always run,
`vg1f`) is not cheaper (12 against vg1's 11 on one input, equal on the rest), so the excess is not
caused by the `_tails` skip; it comes from the limits of the local search. The conjecture as stated
is refuted (vg1 is not exact on left-recursive PEGs), but its proposed cause is not the cause.

**Quantitative summary.** vg1 is the round's best engine: everything vc1b passes, the exact optimum
on every dense family measured (the first engine to reach it on LR `(1+` from k = 11), LR `(1+` at
k = 1024 24x faster than z32 and apparently linear (12, 21, 76, 446 ms at k = 16, 64, 256, 1024),
Dyck 10% faster, the same size, one field fewer. The battery score 0.9907 against z32's 0.9911 is
the price of D8 (the same 50 comma trees as vc1b). It becomes **z33** (`_z33.dart`).

**Qualitative assessment.**
- The largest gain of the round came from measurement, not design: the class-hole ruling turned
  12.34's "invalid trees" into valid ones, a check (`_wit89`) now sees class holes, the exact
  optimum is now known for one family, and a gate (b2) that had failed silently for eight rounds is
  visible again. Two of the three agents found the suite defect or the class conflict
  independently.
- The two strict-D7 engines (vc1s, vx1) show that forbidding class holes costs battery quality
  (0.955-0.957) and makes LR inputs not finish; the ruling removes the reason to build them.
- vg1's speed gain is the kind the guiding principle asks for: an entry keyed by a memo position
  (`(clause, end)`) carries to a distant frame what that frame would otherwise recompute, as the
  squirrel parser's left-recursion entry does. Its price gain is less clean: the new `_seq`
  conditions compare a count of substitutions with a slot index (`r.subs <= i`) and the evidence
  with that count (`r.evidence > r.subs`); no argument from PEG semantics or the edit model is
  given, and it may be fitted to the `(1+` family (brief rule 3). The fuzzers, exhaustive sets and
  long sets do not detect a problem with it, but they never reached the case it fixes either.
- vg1 is still not exact (3 of 27 inputs above, by 1), its size did not shrink, and `_tails` adds
  an engine table. All three agents say further improvement is possible on every metric (Claude
  R1 D, Codex R1 D, Gemini R1 D.3); the series continues.

**Open for round 2.** (1) Explain or derive the `r.subs <= i && r.evidence > r.subs` conditions
from the edit model, or replace them. (2) The 3 inputs above where vg1 is dearer by 1. (3) Whether
`_tails` can replace part of the existing semi-naive growth rather than sit beside it (size).
(4) Re-time on a quiet machine. (5) Proposals still unbuilt: Codex's single fixed-point evaluator in
which the memo entry owns the unresolved obligations; Claude's per-cost bound on ways in an LR cell.
