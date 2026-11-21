<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Cross-review round 2 — the bound remembers the return site, not the depth (2026-09-23)

**Codex's round-2 engine (`cdx10`, untracked `_cdx10.dart`)** replaces the
depth-counting bound with one that remembers the most recent recursive return
site. Each recursive call site of the grammar gets its own symbol. A call
overwrites the remembered symbol, a return must match it, and after a return
any older symbol is allowed, so the rest of the stack is forgotten. Every real
call path maps to a path of this finite automaton, so the bound stays a
relaxation and stays admissible. It needs no depth cap and no deeper rebuilds.
The retained table is still one byte per (position, state), the minimum over
symbols. Floor at 1000/32/1: 21 (regular), 22 (depth 7), **27 (return site)**;
the answer costs 29. The stronger bound is bought once, when the search time
reaches (call sites + 1) x the regular bound's build time. The backward pass
is now a FIFO worklist over a precompiled product graph, and states with a
single free successor are contracted. The seventh judgment key (the mixed
deletion/insertion tiebreak) changed no battery answer and was deleted;
deleting the last-doubt key as well costs 34 trees (0.9895/83.9).

Checked in the orchestrator's kit: battery 0.9899/84.3 with treeDiff 0 and
costDiff 0 against cdx9m; gates, props (2728/0), pred and window identical;
fuzzer seeds 1 and 2 at N=400 worse 0/0, invalid 26/21 (same as cdx9m).
Rungs, alternated with cdx9m (ms): 1000/1/1 302 vs 277; 8/1 593 vs 556;
16/1 1,695 vs 1,860; **32/1 3,156 vs 39,786**; **64/1 3,029 vs over 300 s**;
4000/4/2 1,252 vs 1,015; 8000/4/7 2,435 vs 1,949 (+20–25% on sparse errors).
LOC 858 → 845 normalized (−13, −1.5%). Forcing the upgrade at once or never
changes no battery tree or cost, so on the battery the answer does not depend
on when the clock buys the stronger bound (confirmed for those two extremes).

Codex's refuted directions: the prefix + suffix cell prune at the same depth
(32 errors 36 → 58 s, 1.8 GB); forbidding open-class substitution in the bound
(no gain); ordering repetitions by increasing end (11–17 changed trees); a
budget-1 search before any bound (1 higher cost); a guard that rejects a later
First arm when an earlier arm's literal success lies before the first edit
(invalid 26/21 → 25/20, but it creates a new invalid case). Its counterexample
for Q1: `S <- A 'b'; A <- "ab" / 'a'` on `ac`. Both engines return cost 1
with A's second arm, but on the repaired `ab` A's first arm consumes both
characters. An arm's endpoint does not show that the arm stays selected after
a later edit, because an earlier failed arm may have looked past that
endpoint.

**Gemini's round-2 engine: a set of rejected characters at the frontier is
not the PEG obligation.** Gemini added `expectedMask` to the library's
`MatchResult` (the characters rejected at a match's frontier, one bit per
code unit mod 64, OR-ed through zero-width children) and refused an edit whose
character is in the mask of the piece before it, deleting the stop guard, the
stop exposure and the deletion offer rule. Its report says the fuzzer confirms
validity but gives no counts. Measured in its kit: battery 0.9899/84.3 →
0.9821/80.9 (149 trees and 78 costs differ from cdx9m, 51 lower), fuzzer
invalid 26/21 → **32/30**, worse 7 and 9 against cdx9m's 2 and 2, LOC 860.
The mask sees one character, so a failed arm that needs two or more
characters is either missed or refused too broadly, and mod-64 bits alias
unrelated characters. Its Q2 section (a prefix bound "makes the product a
sum") was not implemented; Codex's implementation of that prune was slower.
