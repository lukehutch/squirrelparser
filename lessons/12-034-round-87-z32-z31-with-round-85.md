<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.34 Round 87 (z32): z31 with round 85's final demote restored, and a correction of 12.33

**The regression.** Round 85 (z30) deleted the final demote in `_repeat` (yk6). The round-85 suite
did not contain the family that needs it. On `S <- R0; R0 <- ((R0 / R1)* ('c'? "bcc"+ 'a'*) 'b'*);
R1 <- (R1 / 'b');` with input `cbcaccbccab` repeated k times, z30 and z31 price k = 3, 4, 6, 7 at
28, 39, 61, 72, where z27 and the restored engine give 8, 11, 17, 20. z31 needs 31.9 s at k = 7;
the restored engine 0.42 s. Where xrefmz finishes (k = 1, 2) all agree.

z32 (yo3, repo `dart/experiments/recovery/_z32.dart`) is z31 with the demote put back:

```dart
return [for (final r in ways) if (_rung != -1 || !_startsClean(sub, r.end)) switch (_plain(sub, r.end)?.end ?? r.end) {
  final sc when sc > r.end && !(r.end == p && _seedDepth < _never) => r.demote(sc),
  _ => r,
}];
```

**Checks, z32 beside z31.**
- Battery: 0.9911, perfect 87.3, treeDiff 2, costDiff 0. Gates the same.
- Fuzzers: pdl worse 1 (levWorse 1, priceWorse 0), plf worse 0; invalid 0, timeouts 0.
- Exhaustive: 0 worse of 61,204. Long sets: 0 dearer, 0 cheaper. Dyck: 0 dearer, 7.1 s against 6.9 s.
- Dense: the same prices and times on all four `(1+` / `1+)` configs to k = 128; on `cbcaccbccab`
  k = 2..16 the prices 5, 8, 11, 14, 17, 20, 23, 47 (z31: 5, 28, 39, 14, 61, 72, 23, 47).

The family is now in the dense script. LOC 590 → 593 (+3, +0.5%). Fields unchanged (`_Way` 10,
`_Cell` 4).

**Refuted: a cross-end prune in `_Cell.add`** (yo1, yo2: a way is dropped when one at an earlier end
with the same owed count spends at most its own spent plus the gap). No time change on LR `(1+`
(k = 1024 about 10.2 s). This fits the diagnosis of 12.33: the kept ways are real ties.

**Correction of 12.33: the yn10 verdict was wrong, and so was the lower bound.** 12.33 used
`_err87.dart`, which prints every one-character error as a deletion. The fuzzers' witness rule
(`_pdl.dart` `_witnesses`) reads a one-character error in a literal slot of a sequence as a
substitution. For example, z31's k = 4 tree puts the last `+` in the `')'` slot of the innermost
`'(' E ')'`, which spells `)`. `_val88.dart` (new, in the kit like the other drivers) applies the fuzzers' witness rule to dense
inputs and reports, per engine, whether some witness parses, and its price and distance.
Measured with it:

| Grammar, input | k | z31 / z32 | yn10 | xrefmz |
|---|---|---|---|---|
| non-LR or LR, `(1+` x k | 2, 3 | cost 3, 4, **invalid** | same as z31 | 2, 3, valid |
| non-LR or LR, `(1+` x k | 4, 5, 6, 8 | k, k, k, k - 1, valid | same | k (k <= 6) |
| LR, `(1+` x k | 11, 16, 32, 128 | 12, 17, 33, 129, **invalid** | 10, 13, 25, 97, valid | - |

The invalid trees insert a digit into `[0-9]`, an open class, which D7 forbids and the witness rule
rejects. So yn10's 97 at k = 128 was a valid and cheaper repair, and z31's 129 was not a valid
repair at all. The claim "k + 1 is the minimum" was also wrong: substituting the trailing `+` by
`)` closes one `(` and removes the `+` in one edit, so at small k the minimum is k, and at k >= 8
the engines go below k. The fuzzers do not generate this family (their invalid count is 0), and the
dense harness checks no trees. Dense prices must be checked with `_val88.dart` before they are
believed. Its witness enumeration runs out of memory on non-LR `(1+` at k >= 11.

**Open, in order.** (1) z32 returns trees that insert into an open class on the dense `(1+` family
(k = 2, 3 on both grammars; k >= 11 on LR). (2) yn10's valid repairs are cheaper than any z32 answer
on LR `(1+` at k >= 11; the minimum there is unknown. (3) LR `(1+` time grows as k^2 (12.33).
