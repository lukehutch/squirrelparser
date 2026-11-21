<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.66 Neon round N6 (gemini-4-neon-high): z62, the sweep only on overflow and the recheck by grammar shape

**Result.** z62 = vgn6: z61 with four small changes. Fields 8 -> 8, bookkeeping lines (bkl.sh) 13 -> 12, 480 -> 479
formatted LOC (-1, -0.2%). Every check.sh row equals z61's except pdls4/plfs4 worse 120/79 -> 149/90 (priceWorse
0/0). big.sh passes all 10 rows for the first time since z59: `L (1+` k = 16384 falls from 82.4e9 to 48.6e9
instructions (vm13b 41.4e9). Fresh f3a and held-out equal z61; LR fuzzer 3,800 lines identical.

| Engine | Change from z61 | Fields | bkl | floc | Result | Verdict |
|---|---|---|---|---|---|---|
| **vgn6 = z62** | **all four changes** | **8** | **12** | **479** | **big.sh 10/10; worse 149/90** | **chosen** |
| vgn6k | vgn6 without the `cmp` change | 8 | 13 | 479 | big.sh gain kept; worse 120/79 | trade-off point |
| vgn6b6f | no `evidence`; split computed at top level | 7 | 12 | 559 | battery 0.9902/86.6; fails longset g3, tfam time | rejected |
| vgn6g1 / g2 | one mode + greedy-repetition filter | 7 | 11 | 413 / 416 | cbc 2/16/27/38; `L (1+` k = 64 times out | rejected |

**What taught something.**
1. **The `L (1+` excess was redundant work, not a harder search.** Neon instrumented vm13b and z61 and found the same
   number of proposals in both; the difference was in parsing the candidates. When the damaged input overflows the
   stack, `deep` is set, and z61 then ran the iterative sweep on every repaired candidate in advance. A repaired
   string has the errors removed, so it rarely nests as deeply, and the ordinary parse succeeds. Parsing plainly and
   sweeping only on an overflow removes the extra work. The lesson: before treating a slow row as a search problem,
   count the search steps against a reference. If they are equal, the cost is in work done around the search.
2. **A recheck fallback that exists to bound cost is needed only where the cost can grow.** The local fallback at
   cost above 8 was added because a global recheck is expensive on cyclic grammars such as cbc and tfam, where
   repetitions inside recursion multiply the ways. On an acyclic grammar the recursion depth is fixed by the grammar,
   so the global recheck stays cheap, and it is exact. Restricting the fallback to cyclic grammars restored both g3
   optimal answers and made g3 faster. The condition is computed from the grammar, so it is not a fitted constant;
   but it is a cost rule, and the fitted 8 behind it remains.
3. **A tie-break field that looks dead can still choose among equal-price answers.** Neon removed the `edits` test
   from `cmp` as dead in `_Cell.add`, but `cmp` is also used in `_repeat` and at the top level, where the test chose
   between repairs of equal price. Prices did not change (priceWorse 0/0), but the trees chosen differ from the
   reference more often (worse 120/79 -> 149/90). The control vgn6k proved the whole change came from this one
   line. Every caller of a comparison must be checked before a test in it is called dead; the fuzzer's worse count,
   not the price checks, is what sees it.
4. **The 8-field barrier is now one cache doing two jobs.** Neon removed `evidence` and computed the
   literal/wildcard split at the top level, which reached z37a's battery record (86.6%). What still fails is `_mins`:
   `cmp` needs it to cache D + S, and `_pureSub` needs it to cache the concrete substitution count. Caching one
   breaks the other's results or makes `_pureSub` quadratic. A 7-field engine needs either a second cache (a field)
   or a way for `_pureSub` to get its count without one.
5. **The one-mode engine is not fixed by filtering stopped repetitions.** X2 proposed refusing ways whose stopped
   repetition could take the next character. Built two ways, it still misprices cbc and is slow on `L (1+`. The
   displaced valid ways are not only those of greedy repetitions, so the second search mode remains necessary.
