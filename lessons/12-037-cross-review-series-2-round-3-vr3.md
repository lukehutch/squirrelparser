<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.37 Cross-review series 2, round 3 (vr3): three engines beside z34, rule naming, time limits, and z35

**The round.** Base z34 = kit `z34b`. Same agents and models (Claude claude-opus-5-5 medium, Codex gpt-6.1-sol
medium, Gemini gemini-4-argon high). Brief: `squirrel-xr/vr3/BRIEF3.md`, open items 1-8 of 12.36. Engines: Claude
`vc3` (`r.subs <= i` replaced by a leaf count of the slots before i, `_pre`; a split key for R2-8; a simpler
settle); Codex `vx3` (R2-8 fixed by checking full equality inside a key's bucket; fewer temporary ways; no change in
behavior); Gemini `vg3` (30-bit key; `_Cell.ver` and the `_versions` table removed by packing the version into
`mark`; `r.subs <= _Way.maxOwed` in place of `r.subs <= i`; new `_seq` sync and settle conditions; `_startsClean`
also accepts a terminal; in `_repeat`, a 2-character separator across an iteration boundary when the repeated body
is a named rule, `sub is peg.Ref`). The orchestrator built `vg3m` (vg3 without its two `sub is peg.Ref` conditions)
and `vg3n` (without the one in `canS`). Logs in `squirrel-xr/vr3/orch/`: `suite_vg3.log`, `suite_vg3m.log`,
`r3_vc3.log`, `rulegroup.log`; Codex's and Claude's full suites are their own (`R3_CODEX.md` C, `R3_CLAUDE.md` C.9)
and agree with the orchestrator's runs where both exist.

**Results beside z34b** (orchestrator's runs, except vx3: Codex's suite). Every engine: battery 0.9907, costDiff 0,
all gates (cx2, b1, b2; freespan 3 3 4 4 1; recommit 16/16; conformance 0 1 1 0 2 3); pdl priceWorse 0; plf
priceWorse 1 (the `cabb` input below); exhaustive 0 of 61,204 more expensive; class fixtures 0 of 900 invalid; every
dense tree valid.

| Check | z34b = z34 | vx3 | vc3 | vg3 = z35 | vg3m |
|---|---|---|---|---|---|
| battery treeDiff | — | 0 | 0 | 4 | 4 |
| plf levWorse | 37 | 37 | 37 | 38 | 38 |
| long sets (1,800): more expensive | — | 0 | 0 | 0 | **1** |
| Dyck (1,932): more expensive than the optimum | 0 | 0 | 0 | 0 | **3** (5 -> 13, 7 -> 12, 5 -> 13) |
| dense non-LR `(1+` k = 256 / 1024: price | 193 / 769 | same | same | same | **257 / 1025** |
| dense `cbcaccbccab` k = 2: price | 5 | 5 | 5 | 5 | **17** |
| semi (27): above the optimum | 3 | 3 | 3 | **0** | 0 |
| semi3 (35): above / excess | 3 / 4 | 3 / 4 | 3 / 4 | **0 / 0** | 0 / 0 |
| group (9): above | 4 | 4 | 2 | **0** | 0 |
| group3 (35, four groupings): grouping-dependent / above under any | 1 / 4 | — | 1 / 4 | 3 / 3 | — |
| T family (30): above / excess | 15 / 88 | 15 / 88 | 15 / 88 | **5 / 39** | — |
| T family, `T` body inlined into `S`: above / excess | 19 / 69 | 19 / 69 | 19 / 69 | 12 / 81 | — |
| LR `(1+` with `P <- '+' T` named: exact | yes | yes | yes | yes | yes |
| Dyck time (engine / z34b, s) | — | — | 5.9 / 5.9 | 7.1 / 6.3 | 7.0 / 6.3 |
| dense non-LR `(1+` k = 1024 (ms) | 633 | — | 588 | 1,056 | 3,550 |
| dense `cbcaccbccab` k = 16 / 32 (ms) | 1,148 / 4,700 | — | — / 4,376 | 774 / 1,970 | — |
| LOC (`loc.sh`) | 586 | 586 | 591 | 582 | 582 |
| `_Cell` integers / engine tables | 4 / 7 | 4 / 7 | 4 / 7 | 3 / 6 | 3 / 6 |

**R3-1: vg3 becomes z35** (`_z35.dart`). It is the only engine of the round better than z34 on a price line and
worse on none of the price checks: semi 3 -> 0, semi3 3 -> 0, group 4 -> 0, T family 15 -> 5 above the optimum
(excess 88 -> 39), with Dyck, long sets, exhaustive and the dense prices unchanged. It is also 4 lines and one cell
field and one engine table smaller (586 -> 582 LOC, -4, -0.7%; `_Way` unchanged at 10 integers + 2 references;
`_Cell` 4 -> 3 integers + 3 references; engine tables 7 -> 6), and 2.4x faster on `cbcaccbccab` x 32 (4,700 ->
1,970 ms), because `_startsClean` now applies to terminal repetitions. It costs: 4 battery tree differences at equal
cost, one more plf levWorse (38 against 37, at equal price), Dyck 12% slower, and dense non-LR `(1+` x 1024 1.7x
slower (633 -> 1,056 ms; inside the new time limit of 2x + 250 ms).

**R3-2: vg3's `sub is peg.Ref` conditions make the price depend on rule naming, and they cannot simply be deleted.**
On the T family, naming the body as rule `T` (`S <- T+`) gives 5 of 30 above the optimum; inlining the same body
into `S` gives 12 of 30 (`rulegroup.log`). z34 also depends on naming (15 against 19), so this is not new, but it
breaks constraint 3. Deleting both conditions (vg3m) removes this dependence and makes these inputs more expensive:
three Dyck inputs (5 -> 13, 7 -> 12, 5 -> 13), `cbcaccbccab` x 2 (5 -> 17), dense non-LR `(1+` x 256 / x 1024
(193 / 769 -> 257 / 1025, and 5-7x slower), and one long-set input. So the conditions do real work, and the work
they do is tied to the grammar's naming, not its language. A test that shows the price is independent of naming
must cover more than one grammar: on the two grammars of `rulegroup.sh`, vg3m looked like the best engine.

**R3-3: vg3's price still depends on how a sequence is grouped** (Claude's `group3.sh`, run by the orchestrator).
Under `S <- E (';' E) ';' E` vg3 is above the optimum on 3 of 35 inputs that it prices exactly under the flat, left
and right groupings. The three-grouping test `group.sh` does not include that grouping. Gemini's report says vg3
"fully resolves R2-3"; it does not.

**R3-4 (new defect, open): M depends on how many rules the grammar has.** M = `_Way.maxOwed` is the sum of every
rule's shortest match. Naming `P <- '+' T` in the LR expression grammar changes the optimum of `(1+` x 11 / 16 / 32
from 8 / 11 / 23 to 6 / 10 / 22, with the same language. The price definition itself breaks constraint 3.
Candidate fixes for round 4: (a) M = the maximum, not the sum, over all subexpressions of their shortest match
(naming a subexpression adds no new subexpression, so this is independent of naming); (b) M = the length of the
shortest string of the start rule; (c) price every trailing insertion run at 1. Each changes some exact optima, which
must be recomputed by the DP tools.

**R3-5: R2-8 is fixed three ways.** vg3 widens the key to 30 bits (latent only at 2^30 characters, where `_never`
already limits the engine); vx3 checks full equality in the key's bucket (exact at any length); vc3 splits the key
by input length. z35 has vg3's version.

**R3-6: a 4-character input where every engine is above the optimum** (Codex, plf seed 14, input `cabb`, grammar
in `R3_CODEX.md`). Every engine returns price 2; `xrefmz` returns 1 (a run of five inserted characters at the end).
Disabling the active-choice `arm` filter gives price 1, but changes 6 battery trees (score 0.9906), so it is not a
fix. Codex's explanation (conjectured): an inserted prefix moves the repaired string forward while the input
position stays, and the `arm` filter then mistakes a needed earlier arm for one at the active call's start.

**R3-7: `lastCost` is decided.** Claude's breakdown on `(xyzd)` x 8: `lastCost` 40 = spent + owed, the way's cost
39 (the tail capped), the best alignment of the same repaired string 36, the cheapest witness the tree admits 33,
the optimum 32. `lastCost` is the mark count of the returned tree, which the battery's `auditBad` checks
(`_research18.dart:1371`); the price is measured by the witness (`priceWorse`), as the kit already does. The gaps
39 -> 36 -> 33 -> 32 are in the search and the alignment, not the formula.

**R3-8: `cbcaccbccab` is quadratic in the last stage** (Claude's profile on vc3 = z34's behavior). The answer comes
from local mode at budget 2 with no work limit; one cell holds about n distinct ends, so stored ways grow about 3.6x
per doubling of k (20,490 / 69,082 / 248,634 at k = 8 / 16 / 32). In local mode the budget bounds the cost since the
last settle, not the total, and the local key (end, last edit, owed) does not merge different ends. vg3 cuts the
constant (2.4x at k = 32) but not the growth (774 -> 1,970 ms from k = 16 to 32).

**R3-9: exactness on every fixed grammar in linear time is ruled out, conditionally** (Claude, Abboud, Backurs and
Vassilevska Williams 2015, arXiv 1504.01431, Theorem 3). A linear-time exact Dyck edit distance (18 bracket kinds)
would solve 3k-Clique in O(n^{k+c}), against the k-Clique conjecture. The bridge to this engine's price (M caps the
end-of-input run; Dyck edit distance does not) is not proved. With R2-7 this settles that exactness is claimed
per family, never in general.

**New in the kit: time limits and price checks** (at the user's request; `vr3/kit/suite.sh`, `vr3/kit/slow.py`).
Each suite part runs under a hard limit of about 3x the time of a known-good engine (battery 90 s, fuzzers 180,
exhaustive 300, long sets 60, Dyck 90, dense 120, validity 60, semi / semi3 / group 60, T family 120, rule naming
240, class fixtures 60). A part over its limit prints `TIMEOUT FAIL` and stops the suite. At the end `slow.py`
prints `SLOW FAIL` when the engine is more than 2x + 250 ms slower than the base on one input, more than 1.5x on a
part total of at least 2 s, or has more fuzzer timeouts, and `PRICE FAIL` when a dense price is above the base's
(the suite printed those prices but compared none of them). Negative controls: vg3m fails both (3 dense prices; 2
dense inputs 5-7x slower); a copy of vg3's log with dense times tripled, 2 fuzzer timeouts added and the Dyck total
raised fails on each; vg3 passes. The whole suite took about 4 minutes per engine.

**Agents' report errors** (recorded in `vr4/ERRORS_*.md`). Gemini: "vg3 fully resolves R2-3" (refuted by
`group3.sh`, R3-3); "every one of the 10 ints on `_Way` is read on the inner loop ... [proved]" is labeled proved
with no proof. Codex and Claude: no error of fact found. Orchestrator: `rulegroup.sh` lost its counter inside a
subshell, so its T-family half printed nothing until fixed; and the first conclusion from the two-grammar naming
test favored vg3m, which the full suite refuted.

**Quantitative summary.** z35 is the first promotion of this series that improves prices: inputs above the exact
optimum on the four families with a computed optimum fall from 25 of 101 (semi 3, semi3 3, group 4, T 15) to 5 of
101, total excess on the T family 88 -> 39, at 4 fewer lines, one fewer cell field and one fewer engine table. vx3
and vc3 change nothing measurable except the key (and group 4 -> 2 for vc3). No engine fixed the rule-naming or the
grouping dependence completely, the `cabb` input, the quadratic last stage, or the `a(xy)` T inputs (5 of 5 still
above the optimum).

**Qualitative assessment.**
- Gemini's engine carried the round; Claude and Codex were most useful as measurers: Claude's group3 test and
  `cbcaccbccab` profile, Codex's `cabb` counterexample and its field ablation (zeroing `subs`, `first`, `cut`, `arm`
  or dropping `fresh` passes a small screen but changes battery trees, so no field of z34 is dead).
- vg3's gains come from conditions keyed to grammar form (`sub is peg.Ref`, a terminal in `_startsClean`). They
  are measured gains, but they are the opposite of what the guiding principle asks: the parser core's memo entry
  means the same thing whatever the grammar's naming, and these conditions do not.
- Constraint 3 now fails in three measured ways: grouping (R3-3), rule naming (R3-2) and the price definition itself
  (R3-4). R3-4 must be fixed first, since the optima the other two are measured against depend on it.
- All three agents say every metric can still improve; the series continues.

**Open for round 4.** (1) R3-4, a price whose M does not depend on naming (decide, recompute the optima). (2) A
replacement for vg3's `sub is peg.Ref` conditions with the same prices on Dyck, dense and `cbcaccbccab` and no
dependence on naming. (3) The middle grouping (R3-3). (4) The `cabb` input. (5) The quadratic last stage on
`cbcaccbccab`. (6) The `a(xy)` T inputs. (7) vg3's 1.7x on dense non-LR `(1+` x 1024 and 12% on Dyck.
