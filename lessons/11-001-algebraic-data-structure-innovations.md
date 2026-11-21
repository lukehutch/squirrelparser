<!-- Part of LESSONS_LEARNED.md, section: 11. Round 60: z9 — Zero Bit-Packing Anywhere, Exact z6/z7 Battery Trees, Fastest Battery & Rungs, and Best D1 Fuzzer Validity/Costs (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 11.1 Algebraic & Data-Structure Innovations

1. **100% Zero Bit-Packing Anywhere via Algebraic Field Covariance:**
   - **In `_Way`:** All 12 fields are plain typed values (`int end, deleted, spent, owed, used, subs, evidence, first, last, cut`, `bool incomplete`, `Object? piece`, `_Way? prev`). No bitfields, masks, or shifts exist anywhere.
   - **`clean`, `preferred`, and `paired` Derived by Covariance (Zero Sentinels in `first`):**
     - `first` stores only actual edit positions (initialized to `_never` when no edit has occurred).
     - `clean` is algebraically equivalent to `cost == 0`: `bool get clean => cost == 0;`.
     - `preferred` is algebraically equivalent to a clean reading with no active cut obligation: `bool get preferred => clean && cut == _never;`.
     - `missing` is derived covariantly from `spent - deleted`: `int get paired => _min(deleted, spent - deleted + owed);`.
   - **In `_Cell`:** `cell.mark` no longer packs budget, version, depth, seeded flag, and `First` arm index into a single `int`. Instead, `_Cell` stores plain typed fields (`int mark = -1, ver = -1, dep = 0, arm = 0; bool seeded = false;`), eliminating all bitwidth limits (`_bits.dart` passes for arbitrary `owed` and `First` arm counts).
   - **Unboxed `List<_Way>` Frontier in `_Cell.ends`:** Because each cell frontier holds at most a few pareto-undominated `(end, used, incomplete)` points, storing `ends` as a flat `List<_Way>` and matching `e.end == r.end && e.used == r.used && e.incomplete == r.incomplete` directly in `_Cell.add` eliminates both integer key bit-packing (`(r.end << 15) | ...` in `z6`/`z7`) and `LinkedHashMap`/Record boxing overhead, while allowing `_seq` to hand off `cur = next.ends` with zero list copying.

2. **Monotonicity Theorem for `_total` and Static-Totality Memoization (`_tot`):**
   - In `_total(c, at)`, the active-LR check `!_active(c, at)` is purely restrictive (negative), and all structural combinators (`FollowedBy`, `Seq.every`, `First.any`, `Ref`) are monotone. Therefore $\text{\_total}(c, \text{at}) \implies \text{\_total}(c, -1)$ for all $\text{at} \ge 0$.
   - Caching static totality (`at = -1`) in `_tot[c]` turns `_total(sub, pos)` into a single $O(1)$ map lookup returning `false` for >99% of grammar clauses, cutting ~350 ms off battery execution.

3. **Empty-Language Clause Pruning (`_min0(c) == _never`) and `OneOrMore` Semantics:**
   - In `squirrel_parser` (`Repetition.match` line 122), `if (result.len == 0) break;` runs *before* `children.add(result)`. Consequently, `OneOrMore(sub)` (`sub+`) always fails if `sub` can only match 0 characters (such as `(!R0)+` or `(&'c')+`), and `FollowedBy(sub)` (`&sub`) can succeed with 0 characters only when `!req && _minChars(sub, p) < _never`.
   - Computing `_min0(c)` with `(c, req)` cycle detection (`p.remove((c, req))` on return so shared DAG subclauses are not poisoned across branches) and guarding `_read` with `_min0(c) == _never` and `_m1` with `_min0(c) < _never` prevents repairing dead clauses whose language is $\emptyset$.

4. **Syntactic vs. Semantic Dominance in `_covers` and D1-Compliant `_m1`:**
   - Recording `s.add(_key(c))` *before* `if (_active(c, at)) return;` in `_covers(c, s, p, at)` ensures that an active `Ref` syntactically shadows identical later `First` arms (`(R0 / R0)`) via `seen` without adding the active `Ref` to `priors` `p` (where its own later arms would steal from themselves).
   - Extracting `OneOrMore` subclauses in `_tails.add` (`if (c is peg.Optional || c is peg.Repetition && c.requireOne)`) and replacing `z7`'s D1-violating `new peg.Parser(..., input: ch).match(c, 0)` in `_matchesOne` with a structural, cached 1-character consuming matcher `_m1` (`_one[(c, ch)]`) + early-exit guard `if (us.isEmpty || !ne && o.first != at) return false;` in `_steals` cut both runtime and fuzzer `worse`/`invalid` counts.
