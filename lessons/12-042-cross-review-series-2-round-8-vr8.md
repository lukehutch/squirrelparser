<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.42 Cross-review series 2, round 8 (vr8): gaps in the fallback's alphabet, a lookahead check, and z40

**The round.** Base z39 = kit `vc7zi`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr8/BRIEF8.md`. Ranking and hard limits as in round 7, with the new check
`kit/wild.sh` (the `('a' .)*` family, R7-2) in `kit/suite.sh`. Engines:
- Claude `vc8za`: z39 with `_ev` cached in `_mins`, a recursive `preferred`, the ladder ceiling written
  `shortest == _never ? -1 : _len + 1`, the breadth-first fallback kept.
- Gemini `vg8`: the fallback and the lookahead probe deleted.
- Codex `vx8`: the fallback kept, its alphabet changed to every code unit some terminal accepts.

Logs: `squirrel-xr/vr8/kit/logs_r8/` (suites `suite_o8_*` and `suite_n8_*`, lookahead set `la_r8*`). Reports:
`vr8/{claude,codex,gemini}/R8_*.md`. This round also replaced the kit's single build with one runner per engine
(R8-9 below).

**Results beside vc7zi** (orchestrator runs; every engine: gates cx2/b1/b2, freespan, recommit, conformance,
cleanTreeDiff all pass; invalid 0 on pdl, plf and dense; class fixtures 0 of 900 invalid; long sets and Dyck 0 more
expensive; semi, semi3, group, group3, group4, group5 and wild 0):

| Check | vc7zi (z39) | vc8za (Claude) | vg8 (Gemini) | vx8 (Codex) | vc8zh (z40) |
|---|---|---|---|---|---|
| formatted LOC | 628 | 620 | **516** | 627 | 625 |
| counted `_Way` fields | 3 | 3 | 3 | 3 | 3 |
| battery score, treeDiff | 0.9896 | 0.9896, 0 | 0.9896, 118 | 0.9896, 138 | 0.9896, 0 |
| pdl / plf priceWorse | 28 / 15 | 27 / 15 | 27 / 16 | 33 / 24 | 27 / 15 |
| exhaustive g4 worse | 40 | 40 | 40 | 46 | 40 |
| T family above, excess | 5, 39 | 5, 39 | 7, 42 | 5, 39 | 5, 39 |
| lookahead set invalid (of 165) | 1 | 1 | **61** | **29** | 1 |
| Codex's class and predicate fixtures invalid or crash (of 20) | 4 | 4 | 13 | 0 | 0 |
| dense ms (engine / base, same run) | — | 10,714 / 10,835 | 7,128 / 10,279 | 7,521 / 10,349 | 9,821 / 10,181 (vc8zd) |

**R8-1: vc8zh becomes z40** (`_z40.dart`, byte-identical to `vr8/kit/.../vc8zh.dart`, sha256 0f8f4837...). It is vc8za
with the fallback's alphabet rebuilt: one code unit for each distinct set of terminal ranges that contain it (every
terminal accepts or rejects all units of such a set alike), where `.` and an inverted class add the range of every
unit, and a unit in no range is not included (only `.` or an inverted class can read it, and then it is in their
range). The inverted-class search starts at 32 and wraps to 0-31. 628 -> 625 formatted LOC (-3, -0.5%), 3 way fields.
Every suite check equals vc8za's; the lookahead set gives 1 invalid (the case z39 also fails); Codex's fixtures and
three `S <- &[a-z] [^a] . '0';` inputs (`kit/cpfix.sh`, 23 cases run, 2 with NUL skipped) give 0 invalid in 52 ms.

**R8-2: an alphabet with more members finds fewer repairs.** The first fix, vc8zd (620 LOC: one code unit per interval
between the bounds of class ranges and literal characters, plus 0), passed every suite check but gave 3 invalid on
the lookahead set, against vc8za's 1. Two cases that need three edits (`S <- Item+; Item <- &Kw Word WS; Kw <- "if";
Word <- [a-z]+; ~WS <- [ ]*;` on `abc;`; `S <- 'x' &('y' 'z') [a-z]+;` on `abcab`) were no longer found: the
breadth-first search stops at 4,096 strings, and redundant alphabet members (two units no terminal tells apart)
spend that budget before depth 3. Lesson: the fallback's completeness depends on the alphabet being both complete
(every distinguishable unit) and minimal (no two indistinguishable units); dropping the all-reject unit from grammars
without `.` or inverted classes is part of minimality.

**R8-3: the lookahead set is now a hard check** (`kit/la.sh`, 5 lookahead grammars x 33 short inputs; summary by
`kit/lasum.py`). No earlier suite grammar had a lookahead that a repair must satisfy, so the suite passed vg8, which
deletes the fallback and gives 61 invalid trees here, including `S <- (!('a'?) 'b') / "ccccccc";` on `a` (cost 1,
invalid; the others give cost 7, valid). Deleting the fallback is still not possible. This answers R7-3 for vg8 (inferred for vg7, not run on
this set): it passed the suite without the fallback because the suite had no such grammar.

**R8-4: the old alphabet had gaps** (Codex). One code unit per terminal gave no valid repair for `S <- &[a-z] [^a]
'0';` on `0` and `a0`, and an inverted class covering 32..0xffff threw `Bad state: No element`. Codex's fix (every
accepted code unit) is correct but has 65,536 members when the grammar has `.`: vx8 takes 3.8 s on 10 characters and
17.3 s on 40 of `S <- &[a-z] [^a] . '0';`, against 2-22 ms for vc8zh.

**R8-5: `_floor` in the ladder budget is needed** (Gemini proposed deleting it). vc8nf = vc8za without it improves
pdl/plf priceWorse 27/15 -> 20/11 and exhaustive g4 40 -> 0, but fails: dense 1.24x (cbc k=32 3.8 -> 7.3 s, SLOW FAIL),
29 Dyck inputs more expensive, semi 1, semi3 2, group3 2 and group5 1 above the optimum or grouping-dependent, named
`P*` at k=11 priced 8 against 6. The 40 g4 inputs are the cost of the floor.

**R8-6: the comparison chain** (elegance finding R7-6). vc8ze = vc8zd with `cmp` as a chain of conditional
expressions instead of a three-element list: every suite check identical, dense 9,731 -> 9,151 ms (-6%), long sets
7,016 -> 6,573 (-6%), Dyck 5,239 -> 4,765 (-9%), +4 formatted LOC. Not taken into z40 because size ranks first; left
to round 9.

**R8-7: false and wrong claims.** Gemini quoted vc7zi's `_allSub` as `piece is peg.MatchResult && ...` and said it
rejects every substitution; no engine file has that text, and vc7zi.dart:42 accepts `(peg.Clause _, int _)`. Its
exhaustive count 71,044 is wrong (61,204, Codex). Claude started a background task in print mode, which the preamble
forbids. Codex showed that dominance between two ways is not contextual equivalence (`S <- &'b' A; A <- 'a' / 'b';`)
and that six of the fallback's uses without lookahead could move into the main search, but class and predicate cases
still need a search over repaired strings.

**R8-8: elegance review of z40.** Still open: `cmp` allocates (R8-6); `piece` has six shapes; `_seq` and `_repeat`
each compute `rSub` and `canS` with different formulas; the constants `_cap 2`, `_per 4`, `_floor 4096`, `_exactPer 16`
and the fallback's 4,096 cap are empirical; the fallback now builds its alphabet with a quadratic loop over terminal
ranges (cheap for the grammars measured, inferred to stay so since the number of ranges is small).

**R8-9: verdicts.** None says no further improvement is possible. Claude: deleting the fallback would save 24-31 lines
but needs lookahead edits shared between siblings. Codex: no convergence, no minimum is proved. Gemini: no further
reduction of way fields (conjectured), 6-16 more lines.

**Build system.** Every engine now has its own runner (`kit/run.sh ENGINE DRIVER ARGS`, built by `kit/mkrun.py` into
`out/run/ENGINE/DRIVER.exe`, holding that engine and the pricing reference xrefmz only). All 666 registered engines
compile in 2 min 9 s; rebuilding one engine's 8 drivers takes 2.4 s; suite output is identical to the old monolithic
build apart from timings.

**Direction for round 9.** Start from z40. The fallback stays until a replacement passes the lookahead set and
`kit/cpfix.sh`; decide the `cmp` chain; reduce the empirical constants or derive them; keep three way fields.
