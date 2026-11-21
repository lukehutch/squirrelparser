<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.39 Cross-review series 2, round 5 (vr5): grouping invariance by flattening sequences, a new grouping test, and z37

**The round.** Base z36 = kit `z36a`. Agents and models as in round 4 (Claude claude-opus-5-5 medium, Codex gpt-6.1-sol
medium, Gemini gemini-4-argon high). Brief: `squirrel-xr/vr5/BRIEF5.md`, open items 1-8 of 12.38. Engines:
- Codex `vx5`: no change in behavior. A memo hit uses a constant empty worklist, and `_oneLit(c)` is replaced by
  `c is peg.Char || c is peg.Str` at the one place it is read (only one-character `Str` reach it). 580 -> 579 LOC.
  Its rejected `vx5s` (a cell per sequence suffix) removes the grouping dependence but raises prices: semi 0 -> 3,
  semi3 0 -> 2, T family 5 -> 14, flat cbc 16/16 against 5 (Codex's numbers, not rerun).
- Gemini `vg5`: `_flat` flattens nested sequences in `_propose` and `_startsClean`, except sequences holding a
  repetition, option or lookahead slot; `s is peg.Repetition` in `_seq`'s `rSub` and `canS` only outside local
  mode; the bound `r.subs <= _Way.maxOwed` becomes `r.subs <= i + _min0(start rule)`; three conditions removed (the
  `arm` filter's `pos == _len` exemption, the last-slot `r.subs == 1 && _startsClean(...)` sync, and the nested
  `peg.Seq` settle branch). 580 LOC.
- Claude: no engine passed its own checks (vc5b-vc5x, vc5e/f: search on a nested copy of the grammar removes the
  grouping dependence and raises prices). Its report is critique and ablation.
- The orchestrator built three merges: `z37b` = vg5 + vx5's two cuts; `z37a` = z37b with vg5's three removed
  conditions restored; `z37c` = z37b with `_flat` flattening every nested sequence.

Logs: `squirrel-xr/vr5/orch/out/suite_o5_{vx5,vg5,z37a,z37c}.txt`, `group5_r5.txt`.

**New check `group5.sh`** (in the suite from this round on). Part 1: four groupings of `S <- E ';' E ';' E ';'?`
(a trailing optional slot). Part 2: `S <- E ';' E ';' E` against `S <- A ';' E` and `S <- E ';' B`, all three
grammars defining `A` and `B`, so M is the same. 35 semi3 inputs each. A missing engine reports 35 incomplete
(negative control run). Also fixed this round, after Codex's report: `group4.sh` passed with no output rows and
ignored invalid trees; both now count as incomplete.

**Results beside z36a.** Common to every engine below: battery 0.9907, treeDiff 0, costDiff 0, all gates, fuzzer
priceWorse 0/0, invalid 0, exhaustive 0 of 61,204, long sets 0 of 1,800, Dyck 0, dense prices identical, semi 0/27,
semi3 0/35, group 0/9, T named 5/39, group3 0/0, class fixtures 0 of 900 invalid, slow.py pass.

| Check | z36a = z36 | vx5 | vg5 | z37c | z37a = z37 |
|---|---|---|---|---|---|
| pdl / plf worse | 62 / 39 | 62 / 39 | 62 / 39 | 63 / 40 | 62 / 39 |
| group4 semi4 / cbc grouping-dependent | 2 of 12 / 3 of 4 | same | **0 / 0** | **0 / 0** | **0 / 0** |
| flat cbc k = 2..4 (grouped 5 8 11) | 16 27 38 | same | 5 8 11 | 5 8 11 | 5 8 11 |
| group5 optional-slot / named sub-sequence | 0 / 0 | 0 / 0 | **3** / 0 | 0 / 0 | 0 / 0 |
| pair 2 named k = 11/16/32 (opt 6 10 22) | 6 11 22 | 6 11 22 | **6 10 22** | 6 10 22 | 6 10 22 |
| dense ms (engine / z36a) | — | 10,983 / 10,436 | 10,130 / 10,465 | 13,076 / 10,412 | 10,917 / 10,584 |
| validity ms | — | 2,072 / 2,132 | 1,925 / 2,004 | 2,900 / 2,013 | 2,084 / 2,031 |
| T family ms | — | 2,303 / 2,574 | 876 / 2,434 | 986 / 2,489 | 867 / 2,512 |
| Dyck ms | — | 6,430 / 6,530 | 5,813 / 6,494 | 6,055 / 6,880 | 5,989 / 6,597 |
| LOC | 580 | 579 | 580 | 579 | 579 |

z37b (vg5 + vx5 cuts) gives group4 0/0 and group5 3/0, like vg5; its full suite was not run.

**R5-1: z37a becomes z37** (`_z37.dart`, byte-identical to `vr5/orch/.../z37a.dart`).
- **Gains over z36:**
  - every grouping test is now 0: group4 semi4 2 -> 0 of 12 and cbc 3 -> 0 of 4. The flat cbc grammar costs
    5/8/11, the same as grouped, against 16/27/38. So the cbc price no longer depends on how the grammar is grouped
    (R4-4 closed for the tests in the suite);
  - pair 2 named reaches the exact optimum at k = 16 (10 against 11), so the one loss of round 4 is gone;
  - the T family and rule-naming sets run 2.5-2.9x faster, and Dyck 9% faster.
- **Losses:** dense +3.1% and validity +2.6% in time, inside the limits.
- **Size and bookkeeping:** 580 -> 579 LOC (-1, -0.17%). `_Way` stays at 10 integers + 2 references, `_Cell` at 3
  integers + 3 references; no table added.

**R5-2: vg5's three deletions are what make an optional slot change the price.** With the three conditions
restored (z37a) group5 is 0; without them (vg5, z37b) the middle grouping of `E ';' E ';' E ';'?` costs more on 3
inputs (11 vs 12, 15 vs 16, 10 vs 12). Flattening every nested sequence (z37c) also gives 0, with a simpler
`_flat`, but costs one fuzzer input on each set and is 26% slower on dense and 44% slower on validity; the
exception for sequences holding a unary slot is what keeps the memo cell of such a subsequence. Gemini labeled
vg5's grouping invariance "[proved]" and said no further improvement was possible on grouping; the proof covers
only sequences without unary slots, which its own `_flat` leaves nested.

**R5-3: M is unchanged, R3-4 open.** Gemini's bound `i + _min0(start rule)` in `_seq` is not M itself; M still
prices trailing runs. Gemini's "Theorem 1" (no computable non-constant M is invariant under language equivalence)
was not checked. Codex recommends taking M as stated metadata of the grammar or benchmark (conjectured).

**R5-4: the unit threshold.** Codex's control (`S <- ('a' 'b')*`-style, input `xy`, two substitutions repair one
two-character iteration, `vr5/codex/logs/controls.log`) refutes Claude's argument that the `1` in `unit` is
necessary; nothing derives it either. Open.

**R5-5: ablation.** Claude and Codex each suppressed all 13 bookkeeping fields one at a time; every suppression loses
something on some check (their reports, not rerun). With a strict "lose nothing" rule no field can go.

**Agents' report errors** (recorded in `vr6/ERRORS_*.md`):
- **Gemini**: "[proved]" grouping invariance and "no further improvement on grouping" (R5-2); refuted by group5.
- **Claude**: none of fact; its most-likely-wrong claim (the unit necessity argument) was refuted by Codex, as it
  anticipated.
- **Codex**: none found. Its dense "2.4% slower" measured 5.2% in the orchestrator's run (timing noise range).
- **Orchestrator**: `group4.sh` from round 4 could not fail on a missing engine or an invalid tree (found by Codex).

**Quantitative summary.** Exact families: 5 of 101 inputs above the optimum (unchanged). Grouping and naming
tests: grouping-dependent inputs 5 -> 0 (group4 5, group5 0, group3 0); pair 2 named one loss -> 0. Fuzzers,
exhaustive, Dyck, long sets: no input more expensive than the optimum, as before. Speed: T/rule-naming 2.5-2.9x
faster, dense +3%. Size -1 line, fields unchanged.

**Qualitative assessment.**
- **Gemini's engine carried the round for the third time**, with a rule stated over the grammar's structure
  rather than its names. Its deletions, which looked like simplifications, were what broke the new optional-slot
  test; they had to be restored.
- **Codex was again the most reliable**, with a zero-change size cut and two checker defects found.
- **Claude found no engine** but its critique of Gemini's round-4 numbers and its ablations were correct.
- **The search for perfection has stopped paying.** Five rounds of series 2 moved the size from 593 to 579 lines
  (-2.4%) and left the bookkeeping at 10 + 3 integer fields. Every gain in accuracy has been bought with another
  condition. Conditions like `last ? r.evidence > 0 || r.subs == 1 && _startsClean(s, r.end) : r.first > pos &&
  r.evidence > r.subs` cannot be explained from a principle, and every ablation "loses something" because the
  checks measure exactness on hand-made families.
- **Verdicts:** none of the three agents says no improvement is possible (Claude: possible on every metric; Gemini:
  none on grouping and naming, which group5 refutes, more on size; Codex: open defects remain).

**Direction for round 6 (the user's ruling, 2026-10-31).** One goal for all agents: the minimal logic and
bookkeeping that keeps most, not all, of z37's recovery quality without losing speed. At most three bookkeeping
fields per way (four if one is shown necessary), found by working out which fields are functions, exactly or
approximately, of others or of combinations of others. A small loss of accuracy is accepted for a large gain in
size and elegance. Conditions like the one quoted above are to be removed or replaced by a principle.
