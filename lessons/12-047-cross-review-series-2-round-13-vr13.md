<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.47 Cross-review series 2, round 13 (vr13): a fallback window at the parse frontier, and z45

**The round.** Base z44 = kit `vm12a`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr13/BRIEF13.md` (bound the fallback by something better than a string
count, make `lastCost` equal the price in fewer lines than vx12s, size, elegance). New hard checks: `lz.sh` with 17
inputs (the R12-2 whole-literal inputs, negative control vg12) and no lookahead case above z44; target `wxyz.sh`
(`S <- &"wxyz" [a-z]+;` on 10, 12, 15, 20 a's and 20 b's, optimum 4). Engines:
- Codex `vx13h` (510): `_Cell.add`'s two coverage scans merged into one loop (equivalent if no cell changes coverage
  mode without a reset; Codex's own most-doubted claim). Codex rejected its windowed fallback vx13a with a new
  negative control (below) and its whole-literal completion vx13c with `&('w' 'x' 'y' 'z')`.
- Claude `vc13k` (512): two rewrites, same repairs as z44. `vc13n` (518) adds a fallback window ending at the
  furthest position read anywhere in the failed parse (`_far`, an edit at the current position always allowed),
  substitution candidates back, and a suffix alignment compared with the string's own marks.
- Gemini `vg13` (504): the same three ideas in a different form (window = top-level match length, alignment compared
  with the main search's cost) plus size cuts: `_read` hoisting, `computed` replaced by `cell.fresh == all`, `_reset`
  as one record expression, `_apply`'s delete and substitute merged, `gap` with an assignment inside an expression.
- Orchestrator merges: `vm13a` (498) = vg13 + vx13h's single scan; `vm13b` (499) = vm13a with vc13n's window;
  `vm13c` (502) = vm13b with vc13n's alignment test; `vm13d` (500) = vm13c's test written in vg13's two-line form.

Logs: `squirrel-xr/vr13/kit/out/r13/ENGINE/*.txt` (script `vr13/check13.sh ENGINE`); reports and engines in
`vr13/archive/r13`.

**Results** (orchestrator runs, one engine at a time). Every engine below passes the suite time limits, all gates,
`big.sh`, `bat.sh` (ratio 0.85-1.03), lz (0 of 17 failed), cpfix (0 invalid), long sets and Dyck (0 more expensive
than z37a; Dyck 4.0-4.3 s against z37a's 5.5-5.8 s), and has battery 0.9896 perfect 85.1, priceWorse 36/20, g4 40,
semi/semi3/group 0, T family 5 above with excess 39, class fixtures 0 invalid.

| Engine | floc | battery vs z44 | la below z44 | wxyz | `wxaa0000000000` (opt 2) | `wxya0000000000` (opt 1) | Codex long-literal (opt 1) |
|---|---:|---|---:|---|---:|---:|---|
| vm12a (z44) | 516 | - | - | 2/5 | 11 | 1 | 1 |
| vx13h (Codex) | 510 | same | 0 | 2/5 | not run | not run | 1 |
| vc13k (Claude) | 512 | same | 0 | 2/5 | not run | not run | not run |
| vc13n (Claude) | 518 | 30 `lastCost` lower | 9 | 5/5 | 2 | 1 | 1 |
| vg13 (Gemini) | 504 | same | 9 | 5/5 | 3 | **2** | **invalid** |
| vm13a | 498 | same | 9 | 5/5 | 3 | **2** | **invalid** |
| **vm13b (z45)** | **499** | same | 9 | 5/5 | 2 | 1 | 1 |
| vm13c | 502 | 30 `lastCost` lower | 9 | 5/5 | not run | not run | not run |

**R13-1: the fallback's window must be read from the whole failed parse, not its top level (confirmed).** Both
vg13 and vc13n limit the fallback's edits to positions up to where the failed parse stopped. Gemini takes the top-level
mismatch length; a failed `&e` reports length 0, so on `S <- &"wxyz" [a-z] [a-z] [a-z] [a-z] '0'+;` with `wxya...` it
can only edit position 0 and prices 2 against z44's optimal 1 (Gemini's own counterexample, confirmed). Worse, on
Codex's control `S <- &P !"Pa" [a-z]+;` with P the alphabet 8 times and input `Pa` (optimum 1, deleting the last a,
which z44 finds), vg13 and vm13a return an **invalid** tree after 2.0-2.3 s. vc13n's `_far` (the furthest `pos + len`
in the mismatch tree) plus one edit always allowed at the current position keeps both inputs optimal. vg13 is rejected.

**R13-2: the window is what pays for the substitution candidates (confirmed).** With the window, the fallback's 4,096
strings are spent near the frontier, so the substitution candidates removed in R12-3 come back without losing depth:
the 9 lookahead cases return to the optimum (9 below z44, 0 above) and `&"wxyz" [a-z]+` is valid at the optimum on all
5 inputs, including 15 and 20 characters (z44: 2 of 5). This answers round 13's first question in part: the bound is
still a string count, but its allocation, not its size, was the problem (Codex's B.1 states the same).

**R13-3: `lastCost` against the price (confirmed).** vg13's two-line alignment makes `lastCost` equal the price on the
12 original lz inputs (z44: 5 higher), but it keeps the realigned string only when it has fewer marks than the main
search's answer and never when the main search found none, so on the 30 battery inputs z44 already overstates it still
does. vc13n's test (fewer marks than the string's own alignment) fixes those 30 too (costLower 30, prices unchanged);
in vm13c it costs 3 lines over vm13b, in vm13d's packed form 1. Both forms leave the whole-literal lz inputs at cost 6
against price 2-4 (an inserted run is priced below its length). Codex traced z44's extra cost on `&[a-z] [^a] . '0'`
to the removed substitution candidates, not to `fb` seeding, which corrects my R12-5 guess.

**R13-4: vm13b becomes z45** (`_z45.dart`, byte-identical to `vr13/kit/.../vm13b.dart`). 516 -> 499 formatted LOC
(-17, -3.3%), three way fields, engine fields 8 (unchanged). Same battery trees and costs as z44, every hard check,
battery 1.01x. Gains over z44: 9 lookahead cases at the optimum again, `&"wxyz" [a-z]+` 5 of 5, `wxaa...` 11 -> 2,
`lastCost` equals the price on the 12 original lz inputs. Losses: none measured. vm13d (500, not run; same function as
vm13c, which passed everything) is the alternative that also fixes `lastCost` on the battery.

**R13-5: elegance review of z45.**
- In its favor: the fallback now reads where the parser stopped from the mismatch tree it already built (`_far`),
  which is the kind of reuse of the parser's own information the series aims at; one coverage scan in `_Cell.add`
  instead of two; the substitution test and the window together replace R12-3's trade.
- Against it: three of vg13's cuts save lines by packing statements into expressions (`_reset` as a record of side
  effects, `len: -next + (next = o)` in `gap`, `(ch = ..., k = ...)` in `_apply`), the dense-packing pattern R6-2
  warned about; the alignment compares a fallback string with the main search's cost, two different quantities, and
  does nothing when the main search found no answer (R13-3); the window's `i == k ||` exception is needed but not
  derived; the fallback's limit is still the empirical `_floor = 4096`; `_Cell.add`'s merged loop rests on an
  untested assumption about coverage modes (Codex).

**R13-6: verdicts.** Codex: not converged (size, speed, accuracy, elegance; fewer fields possible in another
representation, not shown). Claude: not converged (size in `_seq`'s condition chain, an ablation of `sync`/`rSub`/`st`
untried). Gemini: not converged, "1-2 rounds from convergence". The rounds continue.

**Direction for round 14.** Start from z45. New hard checks: Codex's long-literal control and Gemini's `wxaa`/`wxya`
inputs (valid at the optimum). Questions: the alignment test that compares like with like at no more lines than z45
(vm13d is 1 line more); undo or justify the three expression-packing cuts; derive or delete the `i == k` exception;
Claude's ablation of `_seq`'s conditions; test the merged scan's coverage-mode assumption.
