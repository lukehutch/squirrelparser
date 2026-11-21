<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.46 Cross-review series 2, round 12 (vr12): the substitution test reads an existing count, and z44

**The round.** Base z43 = kit `vm11b`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr12/BRIEF12.md` (drop `_subs` exactly, bring the size back toward 527
without losing z43's battery time, make the reported cost agree with the tree's price on `!` grammars). New hard
checks: `kit/bat.sh` (battery at most 1.25x z43 in the same command), `kit/lz.sh` with 12 inputs (the R11-3 prefix
counterexample), `kit/big.sh` with 10 inputs (`1+)` at k = 16,384, reference z43). Engines:
- Codex `vx12s` (541): `_pureSub` tests `_ev(piece) == edits`. On a dirty piece `_ev` counts substitutions only,
  because an insertion leaf has length 0 and a deletion leaf has no terminal clause, so the test is exact and reuses
  the `_mins` memo; `_subs` and `_allSub` are deleted. `_map` also tries a suffix alignment of the repaired string
  against the input and keeps it when it has fewer edits; `lastCost` is computed from the final alignment.
- Claude `vc12k` (521): z43 with the fallback's substitution candidates deleted, a shorter `then` tail
  (`prev?.then(r.prev ?? r) ?? r.prev ?? r`), `_edits` as a switch with patterns, and `fb` seeded from the main
  search's answer. `vc12d` (523) keeps the substitution candidates.
- Gemini `vg12` (521): a depth-2 read `_s` in place of `_allSub` (inexact: it disagrees with the full walk on 4.9% of
  dense calls, Gemini's count), `fb` merged into the answer tuple, and a new acceptance rule
  `(_len < 1 || w.evidence > 0 || w.edits <= _len)` on main-search answers.
- Orchestrator merge `vm12a` (516) = vc12k with vx12s's `_ev` test (`_subs`, `_allSub` deleted).

Logs: `squirrel-xr/vr12/kit/out/r12/ENGINE/{suite,big,lz,bat,la,lasum,cpfix,longset,dyck,wxyz}.txt` (script
`vr12/check12.sh ENGINE`). Reports: `vr12/{claude,codex,gemini}/R12_*.md`; engines and reports in `vr12/archive/r12`.

**Results** (orchestrator runs, one engine at a time). Every engine below passes the suite time limits, all gates,
`big.sh`, `bat.sh`, lz (0 of 12 failed), the lookahead set (0 invalid), cpfix (0 invalid), long sets and Dyck (0 more
expensive than z37a), and has battery 0.9896 perfect 85.1, pdl/plf priceWorse 36/20, exhaustive g4 40,
semi/semi3/group/group3/group4/group5/wild 0, T family 5 above the optimum with excess 39, class fixtures 0 invalid.

| Engine | floc | engine fields vs z43 | battery cost vs z43 | bat ratio | lookahead set: above z43 | `&"wxyz" [a-z]+` valid at | `"abcdef"` on `x` |
|---|---:|---|---|---:|---:|---|---|
| vm11b (z43) | 542 | 9 | - | 1.00 | - | 10 | 6, optimal |
| vx12s (Codex) | 541 | -1 | 30 lower (cost = price) | 0.97 | 0 | 10 | 6, optimal |
| vc12k (Claude) | 521 | 0 | equal | 1.08 | 9 | 10, 12 | 6, optimal |
| vc12d (Claude) | 523 | 0 | equal | 1.05 | 0 | 10 | 6, optimal |
| vg12 (Gemini) | 521 | -1 | equal | 1.01 | 0 | 10 | **invalid** |
| **vm12a (merge)** | **516** | **-1** | equal | 1.03 | 9 | 10, 12 | 6, optimal |

(`&"wxyz" [a-z]+` was tried on 10, 12, 15 and 20 a's and on 20 b's; the optimum is 4 on each. Dyck: vm12a 4.27 s
against z37a's 5.56 s.)

**R12-1: the exact pure-substitution test needs no cache of its own (Codex, confirmed).** A dirty piece is a Match
tree of edit leaves: a substitution is a one-character terminal match (contributes 1 to `_ev`), an insertion has
length 0 and a deletion is a `SyntaxError` (both contribute 0), while each of the three adds to `edits`. So
`_ev(piece) == edits` holds exactly when every edit is a substitution, which is what `_allSub` computed. vm12a and
vx12s use it: same trees and costs as z43 on the battery, every hard check passed, `big.sh` within the limits (the cold
`_ev` walk is still recursive but shares the existing memo). One engine field and one helper are gone.

**R12-2: Gemini's acceptance rule turns optimal answers into invalid ones (confirmed).** The rule sends a main-search
answer with no evidence and more edits than input characters to the fallback search. On `S <- "abcdef";` with input
`x`, `xy`, `xyz` or `q`, and on `S <- "abcdefghij" / "z" "abcdefghij";` with `x` or `xy`, vg12 returns an invalid tree
in 36-95 ms; z43, vx12s, vc12k and vm12a return the optimum (6 and 10 insertions, price 2-4). The fallback's
breadth-first search cannot build a whole literal of 6 characters inside its 4,096-string limit. The brief required
every rule that changes which repair is chosen to be tested where the first and the cheapest answer differ (R11-3);
Gemini tested only the lz inputs the rule was aimed at. vg12 is rejected.

**R12-3: the fallback's substitution candidates trade 9 lookahead cases for one more valid input (confirmed).**
vc12k and vm12a, which do not generate substitutions in the fallback, price 9 of the 165 lookahead cases 1 above z43
and the optimum (for example `S <- 'x' &('y' 'z') [a-z]+;` on `a`: 3 against 2; `S <- Item+; Item <- &Kw Word WS; ...`
on `a;`). Claude reported this. With the candidates gone, the 4,096-string limit reaches one level deeper, and
`S <- &"wxyz" [a-z]+;` on 12 a's becomes valid at the optimum 4, where z43, vx12s, vc12d and vg12 return an invalid
tree (Claude's new defect D.2, confirmed). At 15 and 20 characters every engine is still invalid. On Claude's D.3
grammars (`S <- &"wxyz" [a-z] [a-z] [a-z] [a-z];` on four inputs, `S <- &"ab" [a-z] [a-z] / "q";` on three) every
engine returns the optimal price, so the deletion costs nothing there.

**R12-4: vx12s fixes R11-5 at 20 lines (confirmed).** With the suffix alignment, `lastCost` equals the checked price
on all 12 lz inputs (z43: 3 higher on 4 of them, the two `!` grammars) and on the 30 battery inputs where z43's cost exceeds its price; no
checked price changes. Codex also found that replacing `_oneShape` by a direct terminal test (vx12l, 527) changes the
price on 158 of 600 inputs when a terminal `'x'` is renamed `X <- 'x'` (Codex's `logs/namecheck_prices.txt`, not re-run
here), and that deleting `_takes` (vx12b) gives 3,150 worse exhaustive g3 cases; both rejected by Codex.

**R12-5: vm12a becomes z44** (`_z44.dart`, byte-identical to `vr12/kit/.../vm12a.dart`). 542 -> 516 formatted LOC
(-26, -4.8%), three way fields, engine fields 9 -> 8 (`_subs` gone). Battery 0.9896 with treeDiff and costDiff 0
against z43, battery time 1.03x z43 (7.2 against 7.0 s in the same command), every hard check and allowed loss passed.
It is the smallest passing engine, so it ranks first under the brief's rule (size first). What it gives up against z43:
9 lookahead cases 1 above the optimum (R12-3), outside the allowed-loss table; and `lastCost` exceeds the
checked price on 8 of the 12 lz inputs against z43's 4 (1 higher on `&[a-z] [^a] . '0'` and `&('a' / 'b') [^a] '0'`,
probably from vc12k's seeding of `fb` with the main answer, not tested; the trees are valid at the optimum). What it gains: valid at the optimum on
`&"wxyz" [a-z]+` with 12 a's. vc12d (523) is the alternative with no measured loss against z43.

**R12-6: elegance review of z44.**
- In its favor: the pure-substitution test is one comparison of two numbers the engine already keeps (R12-1); no
  identity map from Match to bool; the fallback has one kind of candidate fewer; the `then` tail is one expression.
- Against it: R11-5 is wider than in z43 (8 lz inputs, not 4); `peg.Match(null, 0, 0, ...)` still passes a position and length the constructor ignores; `lastCost`
  still disagrees with the tree's price on `!` grammars (R11-5; vx12s's fix not taken because of its 20 lines);
  `_Way.maxOwed` and `_Way.len` are still static and mutable (R9-4); the fallback is still bounded by a string count,
  which is what fails D.2 at 15+ characters and R12-2.

**R12-7: verdicts.** Codex: not converged (vx12s passes, smaller variants failed new controls). Claude: not
converged in size, accuracy or elegance. Gemini: further improvement possible in size (3-8 lines) and in the
lookahead fallback, not in way fields (3 is the minimum under the current dominance design). Not all three agree that
no improvement is possible, so the rounds continue.

**Direction for round 13.** Start from z44. Hard checks added: `S <- "abcdef";` on `x`, `xy`, `xyz` and
`S <- "abcdefghij" / "z" "abcdefghij";` on `x`, `xy` (valid at the optimum; negative control vg12), and the lookahead
set's witness price against z44 (no case above z44). Questions: can the fallback be bounded by price rather than by a
string count, so that `&"wxyz" [a-z]+` is valid on 15 and 20 characters and the 9 lookahead cases come back? Can
vx12s's alignment be made small enough to fix R11-5 inside the size ranking?
