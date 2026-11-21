<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.33 Round 86 (z31): z30 minus six conditions

z31 (yn40, repo `dart/experiments/recovery/_z31.dart`) is z30 with six clauses deleted. Each one
was first tested alone as a single deletion from z30 (yn1 to yn27), and the merge was then tested
again as a whole.

| Deleted | Where |
|---|---|
| yn5 | the non-clean filter `pe != r.end \|\| r.first == pos \|\| r.owed > 0` becomes `true` |
| yn11 | settle drops `(o.used == o.spent \|\| o.first > r.last + 1)` |
| yn14 | the step filter drops `sub is! peg.Repetition && s.clean && s.cut < _pred` |
| yn15 | the `_repeat` settle drops `(!s.incomplete \|\| s.first == s.end)` |
| yn25 | adv drops `rSub && options.any(settle)` |
| yn26 | canS drops `dEv > 1`, and the `dEv` local with it |

**Checks, z31 beside z30.**
- Battery: 0.9911, perfect 87.3, treeDiff 0, costDiff 0.
- Gates: freespan, recommit 16/16, conformance and cleanTreeDiff the same as z30.
- Fuzzers: pdl and plf worse 0 and 0, invalid 0, timeouts 0.
- Exhaustive: 0 worse of 61,204.
- Long sets: 0 dearer and 0 cheaper.
- Dyck: 0 dearer of 1,932, 6.8 s against 6.9 s.
- Dense k = 1024: the same prices on all four configs. Times are within noise: non-LR `(1+` 3.5 s, non-LR `1+)` 3.2 s, LR `(1+` 10.4 to 11.4 s, LR `1+)` 0.12 s.

LOC is 590 → 590 (0, 0%), because each deletion shortens a condition without removing a line.
Fields are unchanged: `_Way` 10, `_Cell` 4. Every field is still read.

**Refuted single deletions.**

| Candidate | Result |
|---|---|
| yn1: `_ev` CharSet-repetition exemption | battery 0.9905, treeDiff 16 |
| yn3: Ref read keeps all ways | treeDiff 28 |
| yn6: choice cut drops the absorbed clause | treeDiff 1 |
| yn7: sd update drops `(r.end > pos \|\| r.cut == _never - 1)` | pdl worse 1 |
| yn8: `if (f > pos) cut` without `_seedDepth == _never` | pdl worse 1, plf worse 2 |
| yn9: canS drops the clean-start clause | treeDiff 7 |
| yn10: `sync = false` | LR `(1+` k = 128 runs 43.8 s (z30 0.1 s) and LR `1+)` times out; but see below |
| yn13: `_repeat` skip drops `sub is! peg.CharSet` | battery 0.9897 |
| yn18: lookahead `probe(true)` demote | plf worse 1 |
| yn19: `_read` always returns `r.label` | battery 0.9908 |
| yn21: `r.end > r.last + 1` without the `_rung < 0` case | dense non-LR `1+)` and LR `(1+` missing (timeouts) |
| yn24: adv keeps only the rSub clause | costDiff 9 |
| yn27: the `_next` test is always 1 | plf worse 4 |
| yn30: local `_covers` lets a way with less owed cover one with equal spent | no speed gain on LR `(1+` |

**Correction: z30 is exact on LR `(1+` x k; yn10's cheaper price came from an invalid tree.** yn10
(no sync) reported cost 97 on LR `(1+` x 128 where z30 and z31 report 129, and is cheaper from k =
11 (10 against 12). Its k = 11 tree deletes `+(1+` around position 30 and inserts six `)`, which
gives `(1+(1+(1+(1+(1+(1+(1+(1+(1+(1))))))`: ten `(` and six `)`. The plain parser rejects this
string, so the tree is invalid. The dense harness prints the engine's own `path` label
(`checked`) and does not check the tree, so it cannot catch this. k + 1 is the minimum: each of
the k `(` needs its own edit (delete it or insert its `)`), and the trailing `+` needs one more
(delete it or insert a digit). No single edit serves two of these. This makes yn10 worse than
the table above records.

**LR `(1+` is quadratic because of tied repairs.** This was confirmed with an instrumented copy of
z30 (`_ym2i.dart`). Each E cell keeps about k ways, at distinct ends: the deletion and substitution
family, whose `used` stays at 1 after each settle. Growth runs about k/2 passes per cell, at about
5.5 proposals per pass. yn30, which lets owed break the tie, did not cut this.
