<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl10 — cross-review round 5 on cl8: two crashes and a cost-model flaw fixed, the fuzzer repaired, 712 → 700 LOC (2026-09-23)

*Superseded 2026-09-23 by cl11 below: cl10 does not finish 512+ errors on `('a' 'b')+` and overflows the stack on a left-recursive list of 8,192 terms.*

**Setup.** Codex (gpt-6-astra, max effort) and Gemini (gemini-3.1-pro-high)
each got BRIEF5: an elegance assessment of cl8 in the same format as mine
(scores by part, inelegances with line numbers, a ranked fix table), and then
a cleaner engine built and measured with the kit. My own assessment was
written first and given to both as the peer report. All three assessments
agree on the main points: the cells and their fixed-point growth are the
elegant part (9/10 from all three); `_Bound`, `_repeat`, `_seq` and the guards
score 3-4; `_budget` and `_seedRead` are mutable fields saved and restored
around calls; `piece` is typed `Object?`; the ranked cost and the reported
cost differ; several comments are stale. The engine below is untracked
`_cl10.dart`.

**Two crashes found by Codex (both reproduced in my kit).**
- A cycle of references (`S <- R0; R0 <- A / 'a'; A <- B; B <- A;` on `b`)
  overflows the stack: `_read` follows a Ref to its body without a cell, and
  `A <- B; B <- A` never reaches a cell. Fix: a Ref whose body is itself a Ref
  goes through a cell like any other clause (`c is peg.Ref && _body(c) is!
  peg.Ref && ...` in `_read`, and `peg.Ref() => _read(_body(c), ...)` in
  `_propose`). Battery and gates exact.
- The bound was not admissible: `_seq` let one input character be replaced
  by a whole multi-letter literal at cost 1, which the bound (one per letter)
  did not allow. See the cost-model flaw below; the fix is in the cost model,
  not in the bound. Codex's own fix weakened the bound instead (r5safe).
- The bound's automaton had no case for `peg.Nothing` (`()`); it now joins
  FollowedBy and NotFollowedBy as a free edge.

**The fuzzer never tested a literal longer than one letter.** `_same.dart`
writes two-letter literals as `'ab'`, which the metagrammar rejects (single
quotes are one character; `"ab"` is the multi-letter form), and the harness
skips any grammar that fails to parse (`catch (_) { continue; }`). That is why
each seed completed only 312-370 of its 400 cases. `_samedq.dart` writes them
as `"ab"` and completes all 400. It also adds a measure that does not depend
on the engine's cost model: for each valid tree, the Levenshtein distance from
the input to the repaired string (`levSum`, valid trees only), and the number
of cases where an engine's repaired string is farther from the input than the
best engine's (`levWorse`).

**The cost model charged one edit for a whole literal.** In a sequence slot,
cl8 could replace one input character by a whole literal at cost 1, while an
insertion of the same literal costs one per letter. With `S <- "abc" "def"`:
`def` costs 2 (the correct `d` is replaced by `abc`, then `d` is inserted
again), `xdef` costs 1, `xydef` costs 2. Substitution is now allowed only for
a one-letter literal (`text?.length == 1`; a first attempt tested `slot is
peg.Char`, which wrongly excludes a one-letter Str). On the battery this
changes 12 trees at equal cost and score, all the `i (x)` / `if` shape: cl8
replaced the space after `i` by `f`, cl10 inserts `f` and keeps the space as
whitespace. On the corrected fuzzer (seeds 1-4, 400 cases each, against cl8):
invalid 11/9/11/9 against 14/10/13/9;
levWorse 0/1/0/0 against 3/1/2/0; levSum 528/547/531/502 against
521/543/523/502 (higher because more trees are valid and counted).

**Refactors (each exact on battery, gates and fuzzer).**
- The budget is a parameter of `_read`, `_propose` and the construct methods
  (Codex e1, Gemini e1, my fix 3); `_after` and the save/restore are gone.
- `_seedRead` (a flag saved and restored) is a counter `_seedReads`; a cell
  used a seed if the counter moved while it grew.
- `_resume` checks `spent` against the budget, like every other test (Gemini
  e4); before it used `cost`, which differs only when characters are owed at
  the end of input.
- Deleted: the leveling of `_seq`'s result, and the growth filter that dropped
  an edited reading ending where the plain reading ends (both exact; the
  ending-where-PEG-ends rule in `_view` already covers the second).
- `_spell` splits a Str into Chars once, for both the bound and `_read`.
- The bound's edges are `(from, characters, call site)` records, not integers
  encoding push and pop as -2k and -2k-1.
- `_scan` names the "a starred terminal earns no evidence" rule used in both
  `_ev` and `_repeat`.
- `_versions` is a list, not a map.
- `piece` is a `_Piece` closure that builds its node only when the path is
  selected (from Codex); `_tree` is gone and `_branch` builds a labeled node.
- `first`'s sentinels are documented (`_clean == _never`, `_preferred` ranks
  above it) and the stale comments (fibers, "bill", the one-edit-at-a-time
  ladder that in fact jumps to the bound's floor, the missing tie-breaks in
  the header) are fixed.

**Negative results.**
- One budget quantity everywhere (`cost` instead of `spent`; Codex r5unify,
  Gemini e3, my xcost): 0.9834/81.6, 76 costs change, all lower. The two
  quantities are needed: `cost` counts owed end-of-input characters as one
  completion, and using it inside the search prunes readings that finish
  later.
- A deterministic schedule for strengthening the bound instead of the
  Stopwatch (Codex r5early, Gemini e2): trees exact, 8000/4/7 at 8.4-8.9 s
  against 2.2 s. The Stopwatch affects speed only (xrem, xnor: exact).
- Every reference through a cell (x7b, −3 LOC): 1,879 battery trees change,
  because an empty `WS` is labeled `WS` instead of the parser's convention of
  no label.
- Deleting the `_tail` First branch (y11): exact on battery, gates and old
  fuzzer, but on `S <- R0; R0 <- ("ab" / "a") "b"` it returns invalid trees
  that are too cheap (`ac` cost 1 where the valid answer is 2). Kept.
- Dropping the root special case in `recover`: treeDiff 2,099.
- `_usedSeed` from the cell alone (x1): fuzzer worse.
- Deletion sweep y1-y16 over cl8's remaining rules: only two were exact, and
  one of those (y11) is refuted above.
- Gemini's sealed-class `piece` (e1, 722 LOC): exact but larger than the
  closure; Codex's nullable `first` with a `chosen` flag: exact, but adds `!`
  operators, a helper and a compare line. Not taken.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| Reference cycle overflows the stack | Codex | `_tree.dart` on the grammar above: stack overflow in cl8, cost 2 in cl10 | confirmed, fixed |
| Bound inadmissible for whole-literal substitution | Codex | `"abc" "def"`: cl8 `def` 2, `xdef` 1; cl10 3, 3 | confirmed; fixed in the cost model |
| `Nothing` missing from the bound | Codex | source | confirmed, fixed |
| Budget as a parameter is exact | Codex, Gemini | check8: treeDiff 0 | confirmed |
| `spent` in `_resume` is exact | Gemini | check8: treeDiff 0 | confirmed |
| One budget quantity loses score | Codex, Gemini, Claude | 0.9834/81.6 | confirmed |
| Deterministic bound schedule is slow | Codex, Gemini | rungs 8000/4/7 | confirmed |
| Stopwatch makes results nondeterministic | Gemini | xrem, xnor: trees exact under two other schedules | not observed; speed only |
| Policy layer exists because D1 forbids the exact check | Claude | | Codex: overstated, D1 bans only a second parse; agreed |
| Fuzzer never tests multi-letter literals | Claude | `_samedq.dart`: 400/400 cases | confirmed |
| Whole-literal substitution for one character | Claude | probe | confirmed, fixed |

**Measured (confirmed).** LOC 712 → 700 normalized (−12, −1.7%). Battery
0.9900/84.3, 1,561 ms; treeDiff 12, costDiff 0, auditBad 0. Accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0,
props 2728/0, window P, pred 0. Old fuzzer invalid 6/6/6/11 (cl8 6/6/6/12).
Rungs, alternating (ms, cl8 / cl10): 1000/1/1 295/294;
1000/32/1 3,152/3,209; 1000/128/1 7,683/7,848; 8000/4/7 2,208/2,230; 8000/32/7
10,544/11,002 (+4%); every cost equal. Battery in the same run 1,515/1,510 ms.

**Open.**
- On `S <- R0; R0 <- ("ab" / "a") "b"` (language {abb}), cl8 and cl10 return
  an invalid cost-1 tree for `a`; the true cost is 2.
- `R0 <- (('c' 'c' R0)? (('a' / R2) / 'b'+) "ab"); R1 <- (R2 / 'a'+); R2 <-
  (R0 / R1);` on `ccbbbabcab`: cl10 returns cost 4 where cl8 returned cost 2
  (3 character edits) and the Levenshtein distance is 1. A search limit, not a
  cost-model one.
- Substitution is tried only in a sequence slot after a preferred reading;
  substitution at every terminal was refuted in 7f012d3.
