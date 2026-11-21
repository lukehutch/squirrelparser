<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.40 Cross-review series 2, round 6 (vr6): three way fields, field covariance, and z38

**The round.** Base z37 = kit `z37a`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr6/BRIEF6.md`, with the round-6 direction of 12.39: the least logic and
bookkeeping that keeps most of z37's quality at no loss of speed, at most three counted `_Way` fields (`end`,
`piece`, `prev` free), found by working out the exact and approximate covariance of the fields. Hard limits:
dense, long-set and Dyck time each at most 1.10x z37a. Allowed losses: battery >= 0.985, fuzzer priceWorse <= 1% of
the k = 1 inputs (42), exhaustive <= 1%, long sets and Dyck <= 2%, dense price <= 1.05x, exact families <= 10% of
inputs above the optimum, T family excess <= 80, grouping and naming dependence <= 10%. Engines:
- Gemini `vg6`: 3 way fields (`edits`, `used`, `evidence`), 4 cell fields (`arm` removed), 15 engine fields,
  `Exact` and `_Probe` deleted and replaced by an 11-line breadth-first search over string edits (at most 4,096
  strings) that runs only when every search rung finds nothing.
- Claude `vc6p`: 8 way fields (`deleted` removed), z37a minus `Exact`, the lookahead probe, `_doubt`, the
  evidence - 1 adjustment and first/last tie-break in `cmp`, `pos == _len` in `ok`, and the `Ref` filter.
- Codex `vx6c`: 3 way fields (`edits`, `used`, `evidence`, the same three as vg6), every other fact recomputed by
  walking the edit tree. Its `vx6f` (213 LOC) scores 0.8072 and fails gates b1 and b2; `vx6g`-`vx6j` were rejected
  by Codex on speed.

Logs: `squirrel-xr/vr6/kit/out/suite_{o6p,o6c,o6g}.txt` (orchestrator runs). Reports:
`vr6/{claude,codex,gemini}/R6_*.md`.

**Results beside z37a** (orchestrator runs; every engine: gates cx2/b1/b2, freespan, recommit, conformance,
cleanTreeDiff all pass; invalid 0; class fixtures 0 of 900 invalid; semi, semi3, group, group3, group4 semi4,
group5 all 0; T family 5 above, excess 39, as z37a):

| Check (limit) | z37a | vc6p (Claude) | vx6c (Codex) | vg6 (Gemini) |
|---|---|---|---|---|
| counted `_Way` / `_Cell` fields | 9 / 5 | 8 / 5 | 3 / 5 | **3 / 4** |
| battery score (>= 0.985), treeDiff, costDiff | 0.9907 | 0.9904, 334, 1 | 0.9907, 2, 0 | 0.9904, 25, 16 |
| pdl / plf priceWorse (<= 42) | 0 / 0 | 27 / 8 | 0 / 5 | 36 / 11 |
| pdl / plf k1Worse | 0 / 0 | 10 / 5 | — | 16 / 6 |
| exhaustive worse (<= 1%) | 0 | 40 of 9,840 (g4) | 0 | 26 of 9,840 (g4) |
| long sets more expensive (<= 36) | 0 | 0 | **104 (g3)** | 0 |
| Dyck more expensive | 0 | 0 | 0 | 0 |
| dense prices / cbc k = 1 | same / 2 | same / 3 | same / — | same / 3 |
| dense ms (engine / z37a) | — | 11,629 / 12,167 | **33,115 / 11,481** | 10,242 / 11,075 |
| long sets ms | — | 6,706 / 7,426 | **17,729 / 7,376** | 6,383 / 7,249 |
| Dyck ms (<= 1.10x) | — | 5,906 / 6,578 | **11,321 / 5,786** | 6,349 / 5,797 (1.095x) |
| LOC (`loc.sh`) | 579 | 480 | 617 | 208 |
| formatted LOC (`kit/floc.sh`) | 961 | **804** | 1,022 | 934 |
| non-blank characters | 29,796 | 25,029 | 30,573 | 24,406 |

vx6c fails the long-set loss limit and every time limit (SLOW FAIL on dense, long sets, Dyck, validity, semi,
semi3). vc6p and vg6 pass every hard limit and stay inside every allowed loss. The vc6p times were measured while
the Gemini agent was still running on the same machine.

**R6-1: vg6 becomes z38** (`_z38.dart`, byte-identical to `vr6/kit/.../vg6.dart`, sha256 af55a271...2483).
Chosen by the brief's ranking, which puts way fields first: 9 -> 3 counted `_Way` fields, 5 -> 4 `_Cell` fields,
21 -> 15 engine fields, two classes deleted.
- **Gains:** the bookkeeping target is met for the first time in series 2; dense 7.5% and long sets 12% faster.
- **Losses:** 36 + 11 fuzzer inputs more expensive than z37 (0.84% and 0.26% of the k = 1 inputs), 26 of 9,840
  exhaustive g4 inputs, cbc k = 1 costs 3 against 2, Dyck 9.5% slower (just inside the limit).
- **Size:** 579 -> 208 LOC by `loc.sh` (-371, -64%), but **961 -> 934 (-27, -2.8%) once both files are formatted
  the same way** (`kit/floc.sh`: `dart format --line-length 120` in the kit's package), and 29,796 -> 24,406 non-blank characters (-18%). vg6 packs statements onto long lines (103 lines
  over 140 characters, the longest 567). The LOC rule in the brief counted lines, not code; from round 7 on, size is
  measured by `kit/floc.sh`.

**R6-2: the six removed fields became logic in the way's tree.** Formatted, vg6's `_Way` class is 180 lines against
z37a's 60. `owed` is read off a structural invariant (an end-of-input insertion always has a clean way at `len` as
its `prev`); `first` and `last` are found by walking `(piece, prev)`, kept short by rotating a third dirty step into
a nested piece in `then` and by merging clean steps; `subs` is a walk (`_allSub`) behind an O(1) span test;
`deleted` is `max(0, end - a - evidence - spent)`. So vg6 meets the field limit by moving the facts from fields into
the shape of the tree, and the logic that keeps that shape (eight cases in `then`, three in `label`) is the kind of
condition the round-6 direction wanted removed. Almost all of vg6's net reduction is the deleted `Exact` class (272
formatted lines in z37a, formatted outside the package).

**R6-3: two agents chose the same three fields.** Codex and Gemini both kept `edits` (all edits), `used` (the
local budget since the last settle) and `evidence` (positive terminal characters matched). Codex recomputes the rest
by a walk over the whole edit tree and is 2.9x slower on dense and 104 inputs more expensive on long sets; Gemini
keeps the walks short with rotations and is as fast as z37. The three fields are what cannot be read from the tree:
`used` is reset by a settle, so it is not a function of the edits; `evidence` excludes whitespace and wildcards, so
it is not `span - deleted`; `edits` is the total that `used` forgets.

**R6-4: covariance findings** (the agents' instrumented runs, not rerun by the orchestrator).
- **Exact identities, proved by induction over the constructors by all three agents:**
  - `0 <= subs <= deleted <= spent`;
  - `end - pos = deleted + evidence + absorbed`, with `absorbed >= 0`;
  - `0 <= used <= spent + ex(owed) <= cost`, with equality when no prefix was ever settled;
  - `pos <= first <= last <= end` for a way with edits;
  - clean iff `spent + owed = 0`;
  - `owed > 0` implies `end = len`.
  
  No field is a function of at most three others over the corpus: Codex measured nonzero H(X | S) for every field
  and every subset S of up to three others (22.4 M way events, 1,170 rows).
- **Approximate relations:**
  - `deleted = min(cost, max(0, span - evidence))` on 92% of ways, and on 100% of dense and fuzzer ways, whose
    grammars have no wildcard terminals;
  - `spent = used` on 99.5% of battery ways but 59% of dense ways, where 40% of ways have a settled prefix;
  - `first = last` on 72% of ways;
  - `(cost, used, evidence)` plus the span hold 80% of the joint entropy of all nine fields (Gemini: 12.1 bits,
    2.4 bits left).
- **Prediction rate is not decision safety.** A field that is predicted on 97% of ways can still flip decisions
  where it matters. Codex: `owed` and `spent` are each 96.8% predictable, yet replacing them loses 18 and 21 inputs
  on semi. Gemini, replacing each field live:
  - `deleted` and `cut` cost nothing;
  - `subs` costs two dense time-outs;
  - `first` or `last` set to a constant times out on 21-25 of 25 dense inputs (the cell key and the `synced` test
    read them);
  - `used = cost` times out on all dense inputs;
  - `evidence = span - deleted` drops the battery to 0.9461.
  
  So the fields that cannot be predicted are the ones the cell key and the settle test read, and those must stay
  exact, whether as fields or by walking the tree.

**R6-5: Claude's vc6p is the smallest formatted engine** (804 lines, -16.3%) and the most conservative, but keeps 8
fields. Claude's ablations, removing one field at a time from vc6p:
- `subs` read from the tree: dense 1.26x;
- `cut` removed: long-set g3 +108;
- `first` or `last` removed: dense 1,024 vs 769;
- `evidence` removed: battery 0.9810;
- `spent` and `used` merged: freespan fails.

So vc6p is a local minimum in fields. vg6 escapes it by restructuring the tree, which vc6p does not do.

**Agents' report errors** (recorded in `vr6/ERRORS_*.md`):
- **Gemini**: "208 LOC, 64.1% reduction" counts long packed lines; formatted it is 2.8%. Its "3 fields is the natural
  structural floor" is supported by its three live ablations, not proved.
- **Claude**: "removing `deleted` costs nothing" rested on the battery only; Gemini's live test on dense and the
  fuzzer confirms it (no error, but the claim was under-tested).
- **Codex**: none of fact. Its engine failed the speed limits, which it reported itself.

**Quantitative summary.** Way fields 9 -> 3, cell fields 5 -> 4, engine fields 21 -> 15. Formatted size 961 -> 934
(-2.8%). Accuracy losses, all inside the allowed limits: fuzzer priceWorse 0 -> 36/11, exhaustive 0 -> 26, battery
0.9907 -> 0.9904. Exact families, grouping and naming tests, long sets and Dyck unchanged. Speed: dense -7.5%,
long sets -12%, Dyck +9.5%.

**Qualitative assessment.**
- **The field limit is met; the logic limit is not.** Every field vg6 removed returned as a case in `then`, `label`,
  `first`, `last` or `_allSub`. The real size reduction this round is the deleted `Exact` class, and Claude's vc6p
  shows that the deletion is safe without the field rewrite.
- **Gemini carried the round for the fourth time**, and for the first time overstated the size: the LOC count was met
  by packing lines.
- **Codex's covariance analysis was the most rigorous**, with an exact conditional-entropy table and a decision-flip
  table. Its engine showed that a three-field way with a naive tree walk is too slow.
- **Claude's ablations located the floor of the field-per-fact design** (8 fields).
- **Verdicts:** none of the three says that no further improvement is possible (Codex "I do not believe the frontier
  is closed"; Claude "possible, not shown"; Gemini names a T-family improvement).

**Direction for round 7.** The same goal, with size measured after formatting, starting from z38 and vc6p:
- keep the three fields of z38;
- reach vc6p's formatted size or smaller, by finding a tree shape whose invariants make `first`, `last`, `owed` and
  `subs` one-line reads instead of eight cases in `then`.
