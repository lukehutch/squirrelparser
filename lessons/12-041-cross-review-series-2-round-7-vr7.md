<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.41 Cross-review series 2, round 7 (vr7): the smallest three-field engine, and z39

**The round.** Base z38 = kit `vg6`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr7/BRIEF7.md`. Size is now formatted LOC (`kit/floc.sh`) and ranks first,
then counted `_Way` fields (at most 3, hard), then cell and engine fields, then accuracy, then speed. Hard limits:
invalid 0, no crash, no time-out or SLOW FAIL in `suite.sh ENGINE vg6`, dense, long-set and Dyck totals each at most
1.10x vg6. Allowed losses as in round 6. Engines:
- Claude `vc7zi`: z38's three fields, `first`/`last`/`owed` rewritten as short reads, the match evidence cached in
  an `Expando` keyed by match (an engine field, not a way field), the breadth-first fallback kept.
- Gemini `vg7`: z38's three fields, the `prev` link used as a summary-node binary tree, the lookahead probe and the
  breadth-first fallback deleted, `_evidence` and `_nexts` merged into `_mins`.
- Codex `vx7ao`: z38's three fields, a restricted normalization of the child tree with bounded exact boundary
  queries, the fallback kept.

Logs: `squirrel-xr/vr7/kit/out/suite_o7_{vc7zi,vg7,vx7ao}.txt` (orchestrator runs, one after another on an idle
machine). Reports: `vr7/{claude,codex,gemini}/R7_*.md`.

**Results beside vg6** (orchestrator runs; every engine: gates cx2/b1/b2, freespan, recommit, conformance,
cleanTreeDiff all pass; invalid 0 on pdl, plf and dense; class fixtures 0 of 900 invalid; long sets and Dyck 0
more expensive than z37a; semi, semi3, group3, group4, group5 0 dependent; T family 5 above, excess 39, as vg6):

| Check (limit) | vg6 (z38) | vc7zi (Claude) | vg7 (Gemini) | vx7ao (Codex) |
|---|---|---|---|---|
| formatted LOC (`kit/floc.sh`) | 934 | **628** | 642 | 797 |
| counted `_Way` fields | 3 | 3 | 3 | 3 |
| engine fields (besides rules, topRuleName, parser) | 12 | 11 | 10 | 12 |
| battery score (>= 0.985), treeDiff, costDiff | 0.9904 | 0.9896, 330, 7 | 0.9906, 8, 7 | 0.9904, 460, 7 |
| pdl / plf priceWorse (<= 42) | 36 / 11 | 28 / 15 | 33 / 17 | 36 / 16 |
| exhaustive worse (<= 1%) | 26 (g4) | 40 (g4) | 31 (g4) | 40 (g4) |
| dense ms (engine / vg6) | — | 10,200 / 10,016 (1.02x) | 7,498 / 9,774 (0.77x) | 8,114 / 9,656 (0.84x) |
| long sets ms | — | 6,394 / 6,670 (0.96x) | 6,514 / 6,672 (0.98x) | 5,719 / 6,678 (0.86x) |
| Dyck ms | — | 5,363 / 6,387 (0.84x) | 5,931 / 6,499 (0.91x) | 5,211 / 6,356 (0.82x) |
| `S <- ('a' .)*` on b^2, b^4, b^6 (optimum 1, 2, 3) | 1, 2, 3 | 1, 2, 3 | **2, 4, 6** | 1, 2, 3 |
| breadth-first fallback | yes | yes | no | yes |

All three pass every hard limit and stay inside every allowed loss. vc7zi finds a cheaper repair than vg6 on one
group4 semi4 input (8 against 10, the same under every grouping).

**R7-1: vc7zi becomes z39** (`_z39.dart`, byte-identical to `vr7/kit/.../vc7zi.dart`, sha256 758d6d52124c...).
Chosen by the ranking: smallest formatted engine with three way fields.
- **Size:** 934 -> 628 formatted LOC (-306, -32.8%); 3 way fields, as z38.
- **Losses beside z38:** battery 0.9904 -> 0.9896, 14 more exhaustive g4 inputs above the optimum (40 of 9,840,
  0.41%), plf priceWorse 11 -> 15; pdl priceWorse improves 36 -> 28.
- **Speed:** long sets 4% and Dyck 16% faster, dense 2% slower.

**R7-2: vg7 is 14 lines larger and has an unbounded price defect.** Gemini's own section D found it, and the
orchestrator confirmed it: on `S <- ('a' .)*` vg7 prices `bb`, `bbbb`, `bbbbbb` at 2, 4, 6 against the optimum 1, 2,
3. The guard it added to `_repeat` (`!c.requireOne && !s.clean && r.evidence + s.evidence == 0` skips the step) treats
an iteration with zero terminal evidence as deletable, but `_ev` gives zero evidence to `.`, inverted classes and
`CharSet*`, so a repetition whose body ends in a wildcard is deleted whole and the excess grows with the input. No
suite input has that shape, which is why every suite check passed. Gemini kept the guard because deleting it made
input 30 of the T family produce 2^19 witnesses and time out. vg7 is still the fastest on dense (0.77x) and is the
only engine without the fallback.

**R7-3: the fallback is not always needed.** Claude (vc7c) and Codex both measured 2 invalid plf trees when the
fallback is deleted from their engines; vg7 has no fallback and gives 0 invalid trees on pdl, plf, dense and the
class fixtures. Which part of vg7 makes the fallback unnecessary is not known (inferred candidates: its `_repeat`
guard, or the summary-node tree).

**R7-4: Gemini invented brief constraints.** Its report cites a "Standing Constraint 5 ('Remove any fallback search
instead of shrinking it')", a battery floor of 0.9904 and a 1.15x speed limit. None is in BRIEF7 or in its prompt
(`grep` on both). The limits it applied were stricter than the brief's in two cases and looser in one (1.15x against
1.10x). Recorded in `ERRORS_gemini.md`.

**R7-5: Codex's findings.** The fallback runs 0 times on the battery and once in the conformance gate (refuting
Gemini's round-6 description of it as a regular path). Merging `mark` and `dep` into one cell field saves nothing
formatted. Deleting the `_at` index saves 8 lines but is too slow (also measured by Gemini: Dyck 1.18x).

**R7-6: elegance review of z39** (orchestrator, by reading the file):
- `cmp` builds a three-element list on every call (`[...].firstWhere`), on the hot path of `_Cell.add` and
  `_repeat.push`; a chain of conditional expressions is equivalent and allocates nothing.
- `first` tests `clean` twice (`clean || spent == 0 ? (clean ? _never : len) : _first`); equivalent:
  `clean ? _never : spent == 0 ? len : _first`.
- `piece` is an `Object?` with six shapes (null, `MatchResult`, `SyntaxError`, `Clause`, `(int, _Way)`,
  `(Clause, int)`); every reader is a type switch.
- `_seq` still computes four predicates per slot (`sync`, `rSub`, `canS`, `st`), one of which reads the top rule's
  shortest match; this is the kind of condition the round-6 direction asked to remove.
- The constants `_cap`, `_per`, `_floor`, `_exactPer` and the fallback's 4,096 are empirical.
These go into BRIEF8 as required first checks rather than being applied unmeasured to z39.

**R7-7: verdicts.** None of the three says further improvement is impossible. Claude estimates 20 to 40 more lines
from merging conditions into single rules and proposes replacing the fallback by a larger budget on the existing
ladder; Codex says no minimum is proved and the sync/settle thresholds are policies, not consequences of PEG
semantics; Gemini estimates 5 to 15 lines. Direction for round 8: start from z39; take vg7's deletions (no fallback,
no lookahead probe, merged caches) where they hold without its `_repeat` guard; fix the R7-6 findings; add the
`('a' .)*` family as a test.
