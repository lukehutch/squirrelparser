<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.63 The Neon series (N1 to N5): what can be derived and what must be stored

**Result.** Five rounds by Gemini 4 Neon (high effort, except xhigh in N3) took z54 to z59: fields 9 -> 8, bookkeeping
lines (bkl.sh) 30 -> 13, formatted LOC 454 -> 492, with accuracy held (battery 0.9902/86.5, priceWorse 0/0, fresh f3a
0/0/0, LR fuzzer 0 above the exact reference) and Dyck about 0.5x z37a. Per round: N1 z55 (bkl 29), N2 z56 (`_Cell.dep`
gone, bkl 18), N3 z57 (bkl 17), N4 z58 (bkl 14), N5 z59 (bkl 13); details in 12.58 to 12.62.

**What taught something.**
1. **A field can be removed when it is a function of the way's tree; it cannot when it records the search's history.**
   Every removal in the series replaced a stored value by one computed from the tree or passed back by a call: the
   cycle depth became a return value (N2), `absorbed` became an inequality over `evidence` (N4), "clean" became "the
   piece is not a `Match`" (N4), and `synced` stopped reading `evidence` by counting the insertions in the piece (N5).
   The fields that survived all hold something the tree does not contain. `mark` records the budget at which a cell
   was last filled, so the cell is refilled only for a larger budget; without it a cell is refilled at every read (N3). `_mins` caches a lower bound that costs Theta(k)
   to recompute, so dropping it makes the work quadratic (N3). The `(clause, position)` key kind holds repairs at
   positions where the parser never made a memo entry; rebuilding them by a scan costs the width of the window, which
   on long tokens is the whole input (N2). `used` in local modes depends on the order in which the way was built: N5
   found one pure-substitution fragment that needs two different values of `used` on `L (1+` and on `T (1+` (N5-4).
   So the test before attempting a field removal is: do two runs that build the same tree ever need different values
   of the field? If yes, the field holds history, and only a change to the search, not a rewrite of the engine, can
   remove it.
2. **Bookkeeping lines fell much faster than fields because most of those lines kept two copies of one fact
   consistent.** `absorbed` and `evidence`, `dep` and the call stack, `rSub` and `used` each held related information.
   Each line that wrote both copies went once one copy was derived. The 13 lines left mostly write the four fields of
   item 1, which hold different facts. Further large cuts in bookkeeping lines therefore need a field removal, not
   more rewriting.
3. **Deriving a value moves its cost from bookkeeping lines to code, so size grew.** A stored field costs a line at
   every place it is written. A derived one costs a function or a wider return type, written once: the return tuples
   that carry the cycle depth cost 58 lines in N2. The ranking puts bookkeeping lines above size, so 454 -> 492 was the
   expected price, not an accident. A derivation should be written once, as a function, so that its cost does not
   repeat at each call site.
4. **When an answer depends on visit order, some way in the set is invalid.** A cell keeps one way per key. When two
   ways tie, the order of insertion decides which survives, and that order matters only if the two differ in
   something the key does not see. Three rounds met the same plfs4 case. N3 dropped a coverage test that had been
   keeping both ways, and the case was lost. N4 fixed the visit order on the two global rungs; that order failed fresh
   inputs on the other rungs. N5 found the cause: the skip-ahead step built a way that a previous optional slot would
   take, and that way was not a valid repair. Once that way was never built, the order stopped mattering and its
   condition went. A fix that tunes an order, or keeps both ways, hides an invalid candidate; the fix is to stop
   generating it.
5. **Restricting a mechanism to some modes can create an invariant in the others.** N4 restricted the settling of
   `used` to the local modes, to remove `rSub`. That change made `used == spent + _ex(owed)` hold throughout global cost
   mode, which N5 then proved. The same restriction is why `used` is still a field: the local modes break the identity.
   A field that is derivable in one mode and not in another must still be stored, unless the modes are merged.
6. **The agent was reliable on measurements and unreliable on what to submit, and the brief changed that.** In N1 and
   N2 Gemini reported the counterexample to its own engine (a depth-2 check that was inexact; a scan that was
   quadratic on long tokens) and submitted the engine anyway. From N3 on, after the brief named the input family that
   had made each field necessary and asked for trade-off points in a table, its submitted engine was inside every band
   and its 7-field engines were reported as trade-offs. In N4 it labeled a claim "proved" with no proof. In N5, after
   the brief asked for the proof, it gave one. A brief that names the checks a change must pass, and asks for the
   proof and for the claim most likely to be wrong, gets that work done. A brief that only states the goal does not.
7. **One xhigh round is not a comparison.** N3, on xhigh, gave a smaller simplification than N4 and N5 on high, and the
   series' one priceWorse loss. With one round on each setting and different starting engines, this shows no benefit
   from xhigh; it does not show xhigh is worse.
8. **Under shared load, a time failure is evidence only against a reference run beside it.** Load averages of 35 to 70
   moved single-run times by up to +-50%. Every SLOW FAIL and `big.sh` failure in the series was load: each time, the
   reference engine failed the same way when run interleaved (N1-6, N5).
