<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.48 Cross-review series 2, round 14 (vr14): the read frontier traced from the parser, z46, and the end of the series

**The round.** Base z45 = kit `vm13b`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr14/BRIEF14.md` (an alignment test for `lastCost` that compares like with
like, undo or justify the three expression-packing cuts of R13-5, derive or delete `_far`'s `i == k` exception,
ablate `_seq`'s conditions, test the single coverage scan's assumption). New hard checks: Codex's long-literal control
and Gemini's `wxaa`/`wxya` inputs, valid at the optimum (`lz.sh`, now 20 inputs). New controls
(`vr14/controls14.sh`, not gates, `tail90` valid and price):

| Control | Source | Optimum |
|---|---|---:|
| `S <- &"abcde" [a-z] [a-z] [a-z] [a-z] [a-z] '0'+;` on `axcdx0000000000` | Gemini | 2 |
| `S <- &(("abaaaaaaaab" / "a") "c") !"ac" [abc]+;` on 12 a's | Codex | 3 |
| `S <- &("ab" [a-z] "cd") [a-z]+ !"q";` on `xbxxd` and on `xbzcx` | Claude | 2 |
| `S <- &(("abcd")? ("efgh")? "xyzwvm") [a-z]+;` on `abcxefgxxyzwvn` | Claude | 3 |
| `S <- &(("abcd")* "xyzwvm") [a-z]+;` on `abcxabcxxyzwvn` | Claude | 3 |
| `S <- &'b' [ab] / &"cd" [a-z]+;` on 10 a's | Claude (B.5) | 2 |

plus Claude's lookahead family `pfam.py` (152 generated predicate grammars per seed, seeds 14 and 15). Engines:
- Claude `vc14p` (457): about 20 deletions (`_startsClean`, rung -2, seed tracking in `First`, `sure`, `deep`,
  `costS`, ...), the three packing cuts undone, and `_far` re-reading the subclause of a failed `&`/`!` (with a set
  against cycles) instead of the `i == k` exception. Uses the allowed accuracy loss. Alternatives: `vc14w` (449),
  `vc14n` (456), `vc14` (460), `vc14s` (460, battery 0.9899, `lastCost` = plain edit distance, dense 1.11-1.14x),
  `vc14a` (484, read frontier from wrapped terminals), `vc14r` (fails pdls4 at 44).
- Codex `vx14aa` (536): the fallback's window is the furthest position any terminal read during the failed parse,
  traced by a copy of the grammar whose terminals are wrapped in a recording clause (`_Read`, `_trial`); the `i == k`
  exception is gone; `lastCost` fixed as in R13-3.
- Gemini `vg14` (495): the three packing cuts undone, `i == k` folded into the window as `max(k, _far)`, the rung
  variable `reach` replaced by `4 * sure + 1`, two `_local` conditions dropped from `_repeat`'s settle test,
  `lastCost` fixed by comparing the realigned string with the string's own marks (R13-3's fix in 0 lines).
- Orchestrator merges: `vm14a` (477) = vc14p with vx14aa's traced frontier in place of `_far`; `vm14b` (477) =
  vm14a with vg14's 0-line `lastCost` fix.

Logs: `squirrel-xr/vr14/kit/out/r14/ENGINE/*.txt` (script `vr14/check14.sh ENGINE`), `out/r14/controls.txt`,
`controls_vm14b.txt`, `pfam.txt`; reports and engines in `vr14/archive/r14`.

**Results** (orchestrator runs, one engine at a time, nothing else running). Every engine below passes the suite time
limits (no input over 2x + 250 ms), all gates (cx2, b1, b2; freespan 3 3 4 4 1; recommit 16/16; conformance
0 1 1 0 2 3; cleanTreeDiff 0), battery 0.9896 perfect 85.1, `big.sh`, `bat.sh`, lz 0 of 20 failed, la 165 cases with
0 invalid and 0 above z45, cpfix 0 invalid, long sets and Dyck 0 more expensive than z37a, wxyz 5 of 5 at price 4,
semi/semi3/group/group3/group4/wild 0, T family 5 above with excess 39, class fixtures 0 invalid.

| Engine | floc | battery vs z45 | pdls4/plfs4 priceWorse | g4 | group5 | controls valid (of 7) | pfam invalid s14/s15 | bat ratio |
|---|---:|---|---|---:|---|---:|---|---:|
| vm13b (z45) | 499 | - | 36/20 | 40 | 0/0 | 1 | 11/15 | 1.00 |
| vc14p (Claude) | 457 | same | 42/24 | 52 | 3/1 | 5 (one crashed) | 0/0 | 0.95 |
| vc14w (Claude) | 449 | not run | - | - | - | 1 | not run | - |
| vg14 (Gemini) | 495 | 30 `lastCost` lower | 36/20 | 40 | 0/0 | 1 | 11/15 | 1.00 |
| vx14aa (Codex) | 536 | 30 `lastCost` lower | 37/20 | 40 | 0/0 | **7** | 0/0 | 1.03 |
| vm14a | 477 | same | 42/24 | 52 | 3/1 | **7** | 0/0 | 0.97 |
| **vm14b (z46)** | **477** | 30 `lastCost` lower | 42/24 | 52 | 3/1 | **7** | 0/0 | 0.97 |

(group5 = optional-slot grouping-dependent / named sub-sequence naming-dependent; the limits are 42 for pdls4 and 3
for group5.) Prices on the controls: vx14aa, vm14a and vm14b are at the optimum on all 7; vc14p prices
`&(("abcd")* "xyzwvm")` at 6 against 3, is invalid on Codex's `abaaaaaaaab` control, and crashed (no output line) on
the `("abcd")? ("efgh")?` control.

**R14-1: the window must be the furthest position the parser read, and only a trace gives it (confirmed).** z45's
`_far` takes the furthest `pos + len` in the mismatch tree. A failed `&e` reports length 0 and drops what `e` read, so on
every control with a lookahead that reads past the point of failure, z45, vg14 and vc14w return the whole input as an
error (cost = input length, invalid). Gemini's `max(k, _far)` only renames z45's `i == k` exception: vg14 is invalid on
Gemini's own control. Claude's re-read of the predicate's subclause fixes 5 of 7 but not a predicate inside a
`First` alternative that backtracks (Codex's `abaaaaaaaab`), and its price on `("abcd")*` is twice the optimum.
Codex's trace records the end of every terminal read during the failed parse, which is by definition the furthest
position the parse depended on, and is the only form valid on all 7 controls and on all 304 pfam grammars. Its cost
is a second, wrapped copy of the grammar built per fallback parse (+27 lines in vm14a over vc14p's `_far`). A library
parser that exposed the furthest read position would make it about 3 lines; the series' constraint 8 forbade library
edits. Still invalid in every engine: `S <- &(("abcd")* "abcdefghijklmnopqrstuvwxyz") [a-z]+;` on
`abcxabcxabcdefghijklmnopqrstuvwxyy` (the fallback's 4,096-string limit runs out before depth 3).

**R14-2: vc14p's deletions cost accuracy within the allowed loss (confirmed), and its semi3 time is 1.9x z45
(confirmed).** pdls4 priceWorse rises to the limit, 42; plfs4 24; g4 52; group5 3 and 1 (Claude names the cause of each
loss: `seedFirst3` for pdls4/plfs4, `syncLast1` for group5, `costS` for g4). In an uncontended rerun vm14a takes
1,282 ms on semi3 against z45's 656 ms and vm14b 1,174 against 629; no single input is over 2x + 250 ms, so the
time limits pass. Dense 1.07x, long sets 1.05x, Dyck 0.96x, tfam/rg1/rg2 0.78-0.82x.

**R14-3: Gemini's `lastCost` fix holds in vm14b (confirmed).** Comparing the realigned string's marks with the string's
own marks (instead of the main search's cost) lowers `lastCost` on the same 30 battery inputs as vg14 and vx14aa, at
0 lines; vm14b's battery trees otherwise equal vm14a's.

**R14-4: findings checked.**
- Codex's single coverage scan (R13-5's untested assumption): Claude's B.4 counts 183.6 million `_Cell.add` calls with
  0 coverage-mode changes, with negative controls that do change mode; Gemini reports 0 mode flips over 18,658 inputs.
  The assumption holds on everything measured (computed, not proved).
- Claude B.1: `lastCost` and the price differ by the end-of-input discount, so they cannot be equal under R3-7 on
  every input; the remaining lz whole-literal inputs (cost 6 or 10 against price 2-4) are this case.
- Claude B.2: no derivation of `_floor = 4096` at a useful size was found.
- Kit flaws found by Claude and Codex: `suite.sh` passes the dense row vacuously when 0 dense inputs run; `lasum.py`
  accepts an engine that does not compile; lz lacked the two-edit input `S <- &'b' [ab] / &"cd" [a-z]+;` (added to
  the controls); `tail90` is slow on the hidden-read family; `dense.sh` reports `lastCost` without checking the tree;
  `cpfix.sh` skips two NUL inputs.

**R14-5: vm14b becomes z46** (`_z46.dart`, byte-identical to `vr14/kit/.../vm14b.dart`). 499 -> 477 formatted LOC
(-22, -4.4%), three way fields, 4 cell fields, engine fields 9 (unchanged), plus a one-field helper class `_Read`.
Gains over z45: valid at the optimum on all 7 controls (z45: 1), 0 invalid of 304 pfam grammars (z45: 26), `lastCost`
lower on 30 battery inputs, three packing cuts undone, the `i == k` exception gone. Losses: the allowed accuracy loss
(R14-2) and semi3 1.9x. vg14 (495) is the alternative with no accuracy loss, but it is invalid on 6 of the 7 controls.

**R14-6: elegance review of z46.**
- In its favor: the window is now a defined quantity (the furthest position read), not a heuristic with an exception;
  about 20 rules deleted; no expression-packed statements left from R13-5.
- Against it: the trace builds a wrapped copy of the grammar on every fallback parse, which duplicates work the
  library parser already does (the "never duplicate parsing work" ruling applies in spirit; the memo is not shared);
  the fallback's limit is still the empirical `_floor = 4096`; the main search still carries the conditions Claude
  names as the causes of the accuracy loss; `lastCost` still differs from the price on the whole-literal inputs.

**R14-7: verdicts.** Claude: not converged (size, accuracy, elegance; "vc14n and vc14w are one decision away").
Codex: not converged ("the next useful reduction is to expose native terminal read information from the library
parser"). Gemini: converged on size and on z45's fixes, not converged on the window's completeness, which vx14aa's
trace answers. No agent says further improvement is impossible.

**The series ends here.** After round 14 the user changed the objective (12.49): stop full-repair search and try
minimal coarse recovery inside the library. Round 15 was not run. z46 is the last engine of the vr series.
