<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.67 Neon round N7 (gemini-4-neon-xhigh): z63, one weighted score in place of `evidence`, and linear long tokens

**Result.** z63 = vgn7: z62 without `_Way.evidence`, with a weighted edit score in `_mins`, a marks tie-break inside
`_cmp`, a bound on refilling non-final terminals, an in-place memo reset on stack overflow, and several speed changes.
Fields 8 -> 7, bookkeeping lines (bkl.sh) 12 -> 11, 479 -> 584 formatted LOC (+105, +21.9%). Every check.sh row
passes; battery 0.9902/86.5 -> 0.9901/86.6; pdls4/plfs4 worse 149/90 -> 120/79 (priceWorse 0/0); fresh f3a 0 above;
held-out g5 0 above (z62: 1). Instructions against z62: long token k = 512 1096e9 -> 53.9e9 (growth per doubling
x3.02/3.47/7.34 -> x2.10/2.16/2.21), Dyck 37.7e9 -> 33.6e9, `L (1+` k = 4096 11.7e9 -> 9.4e9, `T (1+` 18.2e9 ->
14.1e9, tfam 9.11e9 -> 8.32e9, cbc8 1.31e9 -> 1.14e9. Of z37a, vm13b, z62 and z63, z63 has the lowest count on 7 of 9
rows (z37a leads long token k = 64, vm13b leads cbc8).

| Engine | Change from z62 | Fields | bkl | floc | Result | Verdict |
|---|---|---|---|---|---|---|
| **vgn7 = z63** | **all changes** | **7** | **11** | **584** | **every check; worse 120/79; long tokens linear** | **chosen** |
| vgn7_cmp | only the marks tie-break in `_cmp` | 8 | 12 | - | worse 120/79 | control |
| vgn7_6f | vgn7 without `_mins` | 6 | 11 | - | semi3 7/35, fresh g5 1 above | rejected |
| vgn7_trim1 | vgn7 without the speed changes | 7 | 11 | 520 | accuracy kept; Dyck, L, T, tfam speed lost | trade-off point |
| vgn7a | recheck bound 8192, global only | 7 | 11 | 583 | tfam 0/0, rule naming 0/0; tfam time, semi3 1/35 | rejected |
| vgn7b | score 2 S_c + D | 7 | 11 | 584 | `L (1+` k = 16384 32.8e9, worse 119/79; tfam witness time | rejected |
| vgn7c | no b = 4 local recheck | 7 | 11 | 583 | cbc8 0.18e9; semi3 1/35 | rejected |

**What taught something.**
1. **Two readers of one cache need two numbers only if both need exact values.** N6 concluded that `_mins` could not
   serve both `_pureSub` (concrete substitution count) and `cmp` (D + S). But `_pureSub` asks only whether a subtree
   is pure substitution, which is an equality test, and `cmp` only breaks ties. With the score 4 S_c + 3 D, the
   difference 4 spent - score = 4 S_w + D + 4 I is a sum of non-negative terms, so it is 0 exactly when the subtree is
   pure concrete substitution; the equality test stays exact. The same number, divided by 4 and rounded, gives S_c + D
   exactly for D <= 3, and only an approximation beyond. The barrier came from asking for exact counts where one
   reader needed a yes/no answer and the other a usually-right order. Before adding a field because two uses of a
   cache conflict, ask what each use actually needs.
2. **A non-injective score fails where its collisions decide something, and the price checks do not see it.**
   4 S_c + 3 D gives 12 for S_c = 3 and for D = 4, so two ways of equal cost and end can swap in a cell. Neon built
   the case: a lookahead `&"abm"` that needs the alternative the swap discarded. vgn7 then reports cost 25 against
   z62's 4, yet the tree it returns has witness price 4, the same as z62's. The swap changes which ways survive at the
   low rungs; a later rung still finds an answer as cheap (inferred from the two outputs, not traced). A generator
   for this class found no other input among 800 where vgn7 differs from z62. Every check compares tree prices, so a
   defect in the reported cost is invisible to them. A side lesson from the same test: the reference engine's
   internal cost is not comparable either (cost 11 at price 8), so comparisons across engines must use the price.
3. **The precedence of a tie-break, not its presence, set the worse count.** z62 lost 120/79 because the marks test
   ran after `first`/`last` instead of before. Passing the marks difference into `_cmp` and testing it before
   `first`/`last` gives the old order with no `edits` test in `_Way.cmp`, so the count returned at one bookkeeping
   line less. When a tie-break moves to another place, its position in the order must move with it.
4. **The superlinear long-token growth was one rule shared by every engine, not a property of the problem.** All
   engines grew x3 to x7 per doubling, which made it look intrinsic. The cause: on `E <- E '+' T`, a non-final
   terminal `'+'` could be refilled with edits on each left-recursion iteration, so each of O(k) iterations could
   buy edits again across the token. Bounding the refill by `i + _min0(_top)` makes the growth linear, and no answer
   on any check changed. A row where every engine is slow in the same way is
   evidence of a shared rule, and the cure is to find which step repeats per iteration.
5. **Reusing parse state after an overflow saves work but couples the engine to library internals.** Resetting the
   unfinished MemoEntry frames in place keeps 1,113 finished entries on `L (1+` k = 16384 and removes one parser,
   which removes duplicate work (D1). But the engine now writes library fields, and a reset of a partly grown
   left-recursion seed could leave a partial result; no check overflows inside a growing seed, and the retry has no
   bound. The saving is real; its safety rests on an untested invariant.
6. **A brief that names every criterion moves many rows, and the size row pays.** Listing each criterion with its
   record gave Neon a target per row; it took the field, bkl, worse, long-token, Dyck, L, T and D1 rows in one round,
   rows no earlier round attempted together. Formatted LOC is ranked last, so the speed changes spent 64 lines
   (vgn7_trim1 is 520) and the rest went to the new score and the overflow path. A size target has to be stated as a
   limit, not only as a rank, if it is to hold while other rows move.
