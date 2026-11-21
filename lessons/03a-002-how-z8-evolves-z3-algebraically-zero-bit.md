<!-- Part of LESSONS_LEARNED.md, section: z8 (round 59, 2026-10-24): genuine field elimination and returning to z3's simplicity -->
[Back to the index](../LESSONS_LEARNED.md)

### How z8 evolves z3 algebraically (zero bit-packing, 500 normalized / 315 raw LOC)

`z8` (`squirrel-kit/dart/experiments/recovery/z8.dart`, copied to
`dart/experiments/recovery/_z8.dart`) starts directly from `z3` and
applies genuine algebraic field elimination alongside the clean lessons
learned from rounds 56–58:

1. **Four `_Way` fields and four `_Way` methods/getters genuinely
   eliminated (zero bit-packing):**
   Every remaining field on `_Way` is a plain Dart field (`end`, `cost`,
   `deleted`, `owed`, `spent`, `used`, `first`, `last`, `arms`, `cut`,
   `clause`, `children`):
   - **`fee` eliminated:** In `z3`, `fee` was only ever `0` or `1`,
     allocated via `o.withFee(1)` when a second-or-later sequence element
     deleted input (`penalize && o.end == r.end && !o.clean && del <= o.spent`).
     In `_seq`, that penalized candidate is always strictly dominated by
     the already-accumulated skip-ahead candidate `best` at `o.end`, so
     `if (penalize && o.end == r.end && !o.clean && del <= o.spent) continue;`
     eliminates the `fee` field and `withFee` method outright (`costDiff = 0`
     across all 2,101 battery cases).
   - **`subs` eliminated:** In `z3`, `subs` was tracked on every `_Way`
     solely to test `step.subs == 0` in `_repeat` when distinguishing a
     pure deletion from a 1-char substitution. Algebraically, a single
     repetition step `s` from `r.end` is a pure substitution if and only if
     `s.deleted > 0 && s.cost == s.deleted && s.absorbed(r.end) == 0`
     (`s.pureSub(r.end)`), eliminating the `subs` field.
   - **`credit` and `int get used` eliminated:** `z3` stored `credit` and
     recomputed `int get used => cost - credit` on every comparison, while
     only ever reading `credit` inside `then` to check whether a prefix
     had unsettled cost before settling it on a clean `>= 2`-char
     continuation. Storing `used` directly as a plain `int` field and
     passing `[bool s = false]` to `then(_Way r, [bool s = false])`
     eliminates `credit` and the `used` getter (`s` settles `used` to `0`
     when `r.clean && r.end - end >= 2`, and `r.owed == 0 && !s` settles
     `owed` to `0`).
   - **`missing` and `int get spent` eliminated:** `z3` stored `missing`
     only to compute `int get spent => deleted + missing + owed` and a
     secondary tie-breaker `_min(deleted, missing + owed)` in `cmp`.
     Dropping that redundant tie-breaker (`costDiff = 0`, `score = 0.9904 /
     86.6%`) allows `spent` to be stored directly as a plain `int` field
     (`spent + r.spent - (r.owed == 0 && !s ? owed : 0)`), eliminating both
     `missing` and the `spent` getter.
   - **`_Way.copy` and `_Way.empty` unified into `_Way.clean`**, and the
     `_letters` cache map on `Squirrel` removed.
2. **Cut-Deletion Monotonicity Law in `_Way.then` (replaces `_tails` /
   `_firstEdit` / `_steals`):**
   When an earlier element voluntarily stopped before a clean continuation
   `[end, cut)` (`cut < _never`), the following element `r` cannot
   immediately delete input at `end` (`cut < _never && r.first == end &&
   r.deleted > 0`). Combined with the existing cut overlap check
   (`r.end > end && cut <= r.end && (r.clean || r.first >= cut)`), this
   2-token condition in `_Way.then` prevents greedy prefixes in `_seq` and
   `_repeat` from stopping early just so the next element can delete the
   characters the prefix could have consumed cleanly—without `z4`–`z7`'s
   AST-walking `_tails`/`_firstEdit`/`_steals` machinery.
3. **Non-Nullable Substitution Law in `_repeat` (`sub0`):**
   In `_repeat`, a 1-char substitution step `s` (`s.end - r.end ==
   s.deleted`) is allowed to propagate when the repeated subclause is
   non-nullable (`_minChars(sub) > 0`, i.e. `!sub0`), while pure deletions
   remain blocked across iterations (`final pDel = s.end - r.end ==
   s.deleted && (sub0 || !s.pureSub(r.end));`). This repairs damaged
   characters inside nested `OneOrMore` loops (such as `'c'++` in `cx2`)
   and lifts battery accuracy to `0.9904 / 86.6%` (`costDiff = 0` vs
   `z6`/`z7`).
4. **Active-LR Skip-Ahead Guards and Iterative Post-Order `_ev`/`_tree`:**
   - Guarding `_seq` and `_repeat` skip-ahead (`!_active(step, r.end)`) and
     `_repeat` fast-forward (`!_active(sub, at)`) prevents unexpanded
     left-recursive seed failures from pruning skip-ahead deletions around
     an active LR spine (fixing `_bits2.dart` and contributing to `0.9904 /
     86.6%`).
   - `_ev` and `_tree` run as single-pass iterative post-order traversals
     with zero intermediate `miss` list allocations, keeping deep inputs
     (`deep.sh` depth 3,200 in `293 ms`, `_chkscale.dart` at `n = 6400` in
     `439–459 ms`) fast and stack-safe.
