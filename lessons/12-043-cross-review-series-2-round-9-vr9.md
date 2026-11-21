<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.43 Cross-review series 2, round 9 (vr9): a summary node per dirty join, an ordered fallback, and z41

**The round.** Base z40 = kit `vc8zh`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr9/BRIEF9.md` (goal: smaller than 625 formatted lines, three way fields, z40's
speed, the lookahead set and the class and predicate fixtures as hard checks). Engines:
- Gemini `vg9` (542): vc8zh with a summary node on every dirty join, a one-line arithmetic `cmp`, `_repeat` calling
  `synced`, the fallback's edits generated left to right, `_delta` removed.
- Claude `vc9r5` (547): Gemini's round-8 vg8 with z40's fallback put back, vg8's way-keyed `opt` set replaced, `_per`,
  `_exactPer`, `done`, the First-choice `cut` and the second queue slot in `_repeat` deleted.
- Codex `vx9q` (566): vc8zh shortened, with a first-in-first-out retry in the fallback.

Logs: `squirrel-xr/vr9/kit/out/suite_o9_{vg9,vc9r5,vx9q}.txt`, `vr9/orch/la_*.txt`. Reports:
`vr9/{claude,codex,gemini}/R9_*.md`. Gemini finished in 48 minutes, Codex and Claude in about 3 hours.

**Results beside vc8zh** (orchestrator runs, one engine at a time; every engine: no FAIL line in `suite.sh`, gates
cx2/b1/b2, freespan, recommit, conformance, cleanTreeDiff pass; invalid 0 on pdl, plf and dense; class fixtures 0 of
900; wild 0; exhaustive g1, g2, g3, g5 0; long sets 0 more expensive):

| Check | vc8zh (z40) | vg9 (Gemini) | vc9r5 (Claude) | vx9q (Codex) |
|---|---|---|---|---|
| formatted LOC | 625 | **542** | 547 | 566 |
| counted `_Way` fields | 3 | 3 | 3 | 3 |
| battery score, treeDiff, costDiff | 0.9896 | 0.9896, 118, 0 | 0.9896, 146, 0 | 0.9859, 155, 22 |
| pdl / plf priceWorse | 27 / 15 | 27 / 15 | 37 / 21 | 27 / 16 |
| exhaustive g4 worse | 40 | 40 | 40 | 40 |
| Dyck more expensive | 0 | 0 | 3 | 1 |
| semi / semi3 / group3 above the optimum | 0 / 0 / 0 | 0 / 0 / 0 | 1 / 3 / 3 | 0 / 0 / 0 |
| group5 grouping- / naming-dependent | 0 / 0 | 0 / 0 | 2 / 2 | 0 / 0 |
| T family above, excess | 5, 39 | 7, 42 | 5, 39 | 5, 39 |
| lookahead set invalid (of 165) | 1 | **0** | 1 | **0** |
| class and predicate fixtures invalid, ms | 0, 46 | 0, 42 | 0, 79 | 0, 44 |
| dense ms (engine / z40, same run) | — | 6,228 / 9,571 | **2,826** / 9,635 | 5,609 / 9,548 |
| dense `(1+` non-LR, time k=1024 / k=256 | 4.1 | 4.5 | **8.1** | 3.9 |
| long sets ms | — | 5,576 / 6,898 | — | — |
| Dyck ms | — | 4,058 / 5,247 | 3,459 / 5,596 | 4,277 / 5,848 |

**R9-1: vg9 becomes z41** (`_z41.dart`, byte-identical to `vr9/gemini/kit/.../vg9.dart`). 625 -> 542 formatted LOC
(-83, -13.3%), three way fields (edits, used, evidence), cell fields as z40, engine fields 9 -> 8 (`_delta` removed).
Beside z40 every accuracy check is equal except the T family (7 inputs above the optimum, excess 42 against 39; the
limit is 80), and it fixes z40's one invalid tree on the lookahead set (`S <- 'x' &('y' 'z') [a-z]+;` on `abc;`).
Against z37a: long sets 0 more expensive of 1,800, Dyck 0 of 1,932 (orchestrator runs). Time: dense 0.65x, long sets
0.81x, Dyck 0.77x z40; the T family is 1.78x z40 (1,547 against 869 ms), inside the per-input limit (2x + 250 ms).
Where the 83 lines come from (Gemini's count, not re-derived line by line):
- **A summary node on every dirty join** (-53). When both sides of `then` have edits, the new way's `prev` is a
  `_Way` that records the left side's `first`, whether both sides are pure substitutions, and the combined owed
  count. `first`, `owed` and `_allSub` become reads of that node, so `piece` takes 4 shapes instead of 6 and
  `label` and `tail` go.
- **`cmp` in one line** (0 lines, no allocation): `cost != b.cost ? cost - b.cost : (b.evidence - evidence) * _never
  + edits - b.edits`. It has the same sign as z40's list because |edits - b.edits| < 2^30 (Gemini's argument,
  checked by reading).
- **`_repeat` calls `synced`** instead of repeating its formula (-4).
- **The fallback generates its edits left to right**: a state is (string, depth, first index allowed), so each set
  of edits is produced in one order instead of all of its orders. This removes duplicate strings, so the 4,096-string
  budget reaches depth 3, which is why the lookahead case z40 fails is now valid. It is the same lesson as R8-2 from
  the other side: the budget is spent on distinct strings or it is wasted. Gemini's argument that the left-to-right
  order reaches every string within each edit distance was read and not refuted; it is supported by 0 invalid on
  the lookahead set and the fixtures, not proved by a test that could fail.

**R9-2: vc9r5 fails the linearity requirement.** On the dense `(1+` family the time ratio k=1024 / k=256 is 8.1 in
the orchestrator's run (Claude measured 8.3 and said so in its report); the limit is about 5. It also has more
accuracy losses than vg9 (priceWorse 37/21, semi3 3, group3 3, group5 2/2, Dyck 3), all inside the bounds. It is by
far the fastest engine on dense (0.29x z40) and Dyck (0.62x), and it removes `_per` and `_exactPer`; both deserve a
look from vg9's side. Claude's alternative vc9n0 (552, ratio 3.6) was not run by the orchestrator.

**R9-3: vx9q passes but is larger.** 566 lines; battery 0.9859 with costDiff 22 against z40 (limit 0.985); otherwise
equal to z40 except Dyck 1 and plf 16, lookahead set 0 invalid. Codex's first-in-first-out retry in the fallback is a
second way to fix z40's lookahead case.

**R9-4: elegance review of z41.**
- **The summary node gives `_Way`'s fields a second meaning.** In the node built in `then` (vg9.dart:33), `end` holds
  the left side's `first`, `edits` holds 1 or 2 as a flag for "both sides are substitutions", `used` holds an owed
  count, and `piece` holds a `_Way`. The getters read them by position (`prev?.end`, `prev!.edits == 1`,
  `prev?.used`). The way-field count stays 3, but a reader cannot tell from a field which meaning it has; this is
  the bit-packing that section 3 of the brief counts as extra fields, done with a record instead of an integer. Open
  for round 10: either a separate small node class (costs lines) or a derivation that does not need the node.
- `_Way.maxOwed` and `_Way.len` are static and mutable, so two `Squirrel` objects that recover at the same time
  would share them. This is in z40 too (vc8zh.dart:9); it is a pre-existing flaw, not new.
- The four constants `_cap 2`, `_per 4`, `_floor 4096`, `_exactPer 16` remain; vc9r5 shows `_per` and `_exactPer` can
  go at some accuracy cost on vg8's base.
- `_seq` still computes `sub`, `sync`, `rSub` and `canS` in 17 lines; Gemini's vg9sr (526) replaced them with
  `_repeat`'s two-line formula and failed group4 `cbc`.

**R9-5: verdicts.** None says no further improvement is possible. Claude and Codex both name the same next step: let
a lookahead share its pending edits with the clause that follows, so the fallback (37-39 lines) can go. Gemini: the
three way fields cannot be reduced (as R6-4); vg9 is within 5-10 lines of the smallest size it can see.

**Direction for round 10.** Start from z41. Settle the summary node's second meanings (R9-4); try vc9r5's deletions
(`_per`, `_exactPer`, `done`, the `cut`) on vg9 and find what makes vc9r5 fast on dense without losing linearity;
attempt shared lookahead edits to delete the fallback, keeping 0 invalid on both new hard checks.
