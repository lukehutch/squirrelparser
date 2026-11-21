<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk10p - round 43: give-backs deleted, the comparison of following fixes parses incrementally; 608 -> 531 lines at the same rung costs, fuzzer worse cases 116 -> 23 and invalid trees 102 -> 89 against sk9y6 (2026-10-09)

Changes from sk9y6 to sk10p, in the order they were measured:

- sk10d: the give-back is deleted (a repetition no longer closes before
  the iteration that read to the frontier). Battery 0.9802 -> 0.9798,
  15 cases worse and 20 better; rung costs unchanged; 608 -> 533 lines.
  64/1 rung 14.2 -> 11.3 s.
- sk10h: `_wins` (compare an offer with the kept one by the fixes that
  follow each) no longer parses the whole input once per fix. It parses
  again from the lowest position where the two fix sets differ, and
  forgets memo entries from there on when it is done. Battery trees
  identical to sk10d (treeDiff 0).
- sk10m: sk10h plus the four bugs the elegance review found, each first
  measured alone (sk10i-l):
  - (B) a fix inside a repetition is priced and written from 0, not
    from the element's index;
  - (A) the window test is `r - p <= gain`, and holds only once an offer
    gains;
  - (C) the left edge of a token-iteration candidate is the token
    start, when there is one;
  - (D) the forced-arm set is cleared in each parse, and the repair
    works on a snapshot of it.
  Two fields, `bp` and `known`, became dead and were deleted. Against
  sk10h: 143 trees differ, 1 cost; battery 0.9797. Rungs
  6/8/12/16/32/64 take 0.64/0.87/1.16/1.47/1.90/3.48 s against sk10d's
  1.56/1.88/3.19/4.18/6.33/11.27 s, at the same costs.
- sk10n: `_jump`, the rule that a deletion starting at or past the
  frontier may not end inside a nested construct, is deleted. Battery
  0.9797 -> 0.9801; on the fuzzer never worse than sk10m, invalid 92 ->
  90.
- sk10o: the `_kept` field is deleted. `_repair` returns its price and
  the position it read to. Battery trees identical to sk10n.
- sk10p: the `idle` fallback (keep the first element offer that reads to
  the frontier when nothing gains) is deleted. Battery trees identical
  to sk10n.

Ablations (battery against the engine named; worse/better cases):

| Removed | On | Battery | Worse/better | Kept? |
|---|---|---|---|---|
| `_wins` | sk10m | 0.9728 | 70/21 | yes; it costs 2.0 -> 3.3 s |
| token-iteration candidates | sk10m | 0.9720 | 69/5 | yes |
| `_opens` | sk10m | 0.9729 | 49/8 | yes |
| forced choice arms | sk10m | 0.9794 | 7/1 | yes; fuzzer worse 11 vs 3 without |
| `_jump` | sk10m | | | deleted (sk10n) |
| close at end of input | sk10n | 0.8128 | | yes |
| top-level cap | sk10n | 0.9793 | 30/5 | yes |
| `idle` | sk10o | 0.9801 | | deleted (sk10p) |

Refuted this round:

- sk10e: cap the nested repairs inside `_wins`. 0.9735, 44 cases worse;
  the uncapped comparison is part of the quality.
- sk10f: reuse the memo entries parsed while an offer was measured. Those
  entries collected no candidates, and the 64/1 rung cost 1,534 instead
  of 68.
- auditBad (cases where the tree's edit count differs from `lastCost`)
  is not a bug check here: the audit counts a deletion of s characters
  plus k insertions as s + k, while the engine prices it max(s, k), a
  replacement.

Codex (gpt-6.1-sol, round 43) built cx43a and cx43b (611 and 694
lines), a global search on an explicit frame stack. Measured by Codex,
not rerun here:

- no invalid trees on the 3,200 fuzzer cases (sk9y6 102), but those
  grammars have no character classes, and `S <- ![a-z] [a-m] / "XX"`
  on empty input gives both an invalid tree;
- worse than sk9y6 in about 780 fuzzer cases, battery 0.976, battery
  25-35 s, and every 23,500-character rung timed out at 120 s;
- depth 3200 passes; the explicit frame stack is the measured way past
  the overflow at 800;
- a counterexample to u28's exactness: `S <- 'a'* 'a' / "aaaaab"` on
  `b` costs 5 (insert five `a`), and u28 returns a cost-1 whole-input
  error. Not adopted.

**Results (confirmed).** Rungs are costs (1000/k/1).

| Engine | Battery | ms | 6/1 | 8/1 | 12/1 | 16/1 | 32/1 | 64/1 | 64/1 ms | Invalid | Worse vs sk9y6 | LOC |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sk9y6 | 0.9802 | 4196 | 6 | 8 | 16 | 19 | 34 | 68 | 14168 | 102 | - | 608 |
| sk10d | 0.9798 | 3245 | 6 | 8 | 16 | 19 | 34 | 68 | 11269 | | | 533 |
| sk10m | 0.9797 | 3274 | 6 | 8 | 16 | 19 | 34 | 68 | 3480 | 92 | 24 vs 88 | 548 |
| sk10n | 0.9801 | | 6 | 8 | 16 | 19 | 34 | 68 | | 90 | 23 vs 115 | 535 |
| sk10p | 0.9801 | | 6 | 8 | 16 | 19 | 34 | 68 | 8555 (load) | 89 | 23 vs 116 | 531 |

- sk10p and sk10n were timed only while nine agents shared the machine:
  sk10p's battery 4.2 s, rungs 0.84/0.76/1.31/1.71/5.93/8.56 s, and
  x(ab)*1600 26.4 s, against 4.6 s for sk10m on a quiet machine. Their
  quiet times are not measured.
- Fuzzer (8 seeds x 400) against sk9y6: worse 23 vs 116, levWorse 18 vs
  87, invalid 89 vs 102, timeouts 0.
- Gates: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit 16/16,
  conformance 0 1 1 0 1 1, cleanTreeDiff 0.
- `deep.sh`: `x (ax)*n b` costs 1; depth 800 still overflows the stack.
- Open: `[1,,2` costs 3 (wrapped as a string) where 2 suffices; a
  missing `[` far from the failure; greedy-repetition invalid trees;
  left recursion; stack depth.

LOC: sk9y6 608 -> sk10p 531 (-77, -12.7%).
