<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z1 - round 53: historical audit and compaction to 379 raw / 613 normalized
lines (2026-10-22)

A full audit of all historical lines (`libsrc_recovery/`, `a`, `b`, `c`, `cdx`,
`cl`, `m`, `pd`, `r`, `s`, `sk`, `t`, `u`, `x`, and `z` across `attic/`,
`OLD_LESSONS_LEARNED.md`, and `LESSONS_LEARNED.md`) identified why each
paradigm succeeded or failed:

1. **Two-phase probe / lookahead / grammar-derived heuristics
   (`libsrc_recovery`, `a`/`b`/`m`/`r`)**: `m23` (`0.9866`, `897` LOC) and
   `m41` (`0.9873`, `794` LOC) showed that local structural recovery works well
   on single-error sites, but coupling recovery into `Parser`/`Clause` with
   lookahead probes and cascading heuristics (`r1`-`r14`, `1,259` LOC) creates
   state leaks, magic constants, and exponential cascades on multi-error files.
2. **Chart / Dijkstra / Earley / NFA / Token-Lattice / Pushdown (`t1`-`t3`,
   `pd1`-`pd6`, `sk1`-`sk3`, `u1`-`u6`)**: global minimum-edit decoders violate
   PEG ordered-choice discipline (`First`) and negation (`NotFollowedBy`),
   creating anchorless deletion deserts and failing `recommit` and
   `conformance`.
3. **Single-winner memoized recursion (`s1`-`s12`)**: `s4` (`480` LOC,
   `0.9786`) was compact and fast, but storing a single `MatchResult` per
   `(Clause, pos)` suffers from the **Same-Start Prefix Trap** (a greedy clean
   match of an early subclause hides the shorter prefix needed for an inner
   repair).
4. **Trial-and-invalidate over a single memo (`x1`-`x513k`)**: `x464a` (`281`
   raw / `306` normalized LOC, `0.9811 / 76.4%`) was the smallest engine in
   line count, but mutating `_fix` and calling `_forget(q)` to re-run
   `_parse()` causes `42.5-67%` of all memo work to repeat (`x513j` grew to
   `777` raw / `918` normalized lines and still had `42.5%` duplicate work),
   violating the Round 48 zero-duplicate-work ruling.
5. **Multi-end Pareto front attached to the native parser (`c1`-`c25`, `z1`)**:
   `c19` (`388` raw / `470` normalized LOC, `0.9900 / 86.15%`) proved that
   attaching a recovery cell to `parser.getMemoEntry(c, pos)` via
   `Map.identity()` achieves **0% duplicate pure-memo work** while solving the
   Same-Start Prefix Trap cleanly. However, `c19` blew up on multi-error
   scaling (`25 s` on 16 errors) because its Pareto bucket retained every
   incomparable `(first, last)` error-span pair across long repetitions, and
   `c20`-`c25` (`666`-`1,089` LOC) grew large trying to tame that growth with
   windows or 13-condition dominance predicates.

**Key simplifications and ablation lessons in Round 53 (`z1.dart`, `379` raw /
`613` normalized LOC)**:

- **4-tuple-keyed `_Cell` (`Map<(int, bool, bool, int), _Way>`)**: replaces
  `_Front` (`Map<int, List<_Way>>` + 23-line pairwise dominance loop) and
  `_Relation` (`view`/`viewBudget` cache) with a single `_Cell` class keyed by
  `(r.end, r.incomplete, r.missing == 0, r.used)` and ordered by `r.cmp(b)`.
  Why `r.used` must be in the key: under credit settlement,
  `used = max(0, spent - credit)` is the *remaining future budget cost*,
  whereas `charge` in `cmp` is the *total edit price*. Because `(used, charge)`
  is a 2D Pareto frontier (`used <= _budget`), a 3-tuple key
  `(r.end, r.incomplete, r.missing == 0)` lets a settled high-charge reading
  (`used = 1, charge = 4`) overwrite an unsettled lower-charge reading
  (`used = 2, charge = 2`). Adding `r.used` to the tuple key preserves all
  Pareto-incomparable `(used, charge)` pairs in 6 lines of map lookup and
  restores the full **`86.1%` perfect** rate.
- **Ablation of the 311-line prototype against adversarial stress suites**:
  An initial `311` raw / `462` normalized LOC compaction passed `battery`
  (`0.9895 / 85.7%`), `gates`, `props`, `window`, and `scale`, but
  stress-testing against `deep.sh`, `_tilde.dart`, and `_chkscale.dart` proved
  that four mechanisms cannot be deleted:
  1. **Cut obligations (`cut`)**: without `cut` on
     `First`/`Optional`/`Repetition`, `x (ax)*n b` in `deep.sh` degrades from
     linear to `O(n^3)`.
  2. **Pure-substitution credit settlement (`subs` / `rSub` in `_seq` and
     `r.subs == r.cost` in `Ref`)**: without `subs`, right-recursive
     `x (ab)*n` with `n` substitutions cannot settle at `_budget = 1` and times
     out at `n = 400`. Importantly, `subs` must *not* be added to `cmp()` as a
     global tie-breaker (where it causes delimiter substitutions like `[4,5,6]`
     to beat intra-token deletions like `[45,6]` when `charge` and `evidence`
     tie).
  3. **Top-level `StackOverflowError` recovery (`_warmMatch`) and iterative
     `_tree`**: catching `StackOverflowError` inside `_plain` instead of at the
     top level of `recover()` prevents `_read` from unwinding to `_warmMatch`
     at depth `n >= 800`.
  4. **Repetition last-repaired-step evidence (`dEv > 1`) and `_seq`
     `settles(o)` (`o.end > o.last`)**: in `_repeat`, checking `dEv > 1` on the
     last *repaired* step `d` prevents a 1-character hallucinated block `"{ "`
     from borrowing a subsequent clean statement's evidence to settle credit.
     In `_seq`, `settles(o)` must check `o.end > o.last` (at least 1 clean
     character after `o`'s last edit, e.g. closing `']'` in
     `V <- '[' WS (V ...)? ']'`) rather than `o.synced(r.end)`
     (`o.end > o.last + 1`), which otherwise causes `_tilde.dart` grammar 1 to
     blow up 70x (`2,238 ms -> 32 ms` at `n = 200`).
- **Single-pass iterative `_ev` and inline 1-character terminal repetition
  projection**: replaces the 26-line two-pass postorder stack with a 10-line
  single-pass loop and replaces `_lexicalWays` with an inline prefix loop gated
  by `plain.end - pos == k.length`.

**Measured results on `z1.dart`**:

- **Size**: **`379` raw** non-comment/non-blank lines (**`613` normalized**
  under `dart format --language-version=3.0` -- down from `529 / 762` in
  Round 52 and `666 / 986` in `c25`), `0` `dart analyze` issues.
- **Battery (`bench.sh battery z1`)**: **`score=0.9896, perfect=86.1%,
  crashed=0, uncovered=0, auditBad=0, ms=2800`**.
- **All 4 Honesty Gates (`bench.sh gates z1`)**: `accept cx2=true b1=true
  b2=true`, `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1 0 2 3`,
  `cleanTreeDiff=0`.
- **Properties, predicate, and window checks**: `bench.sh props z1` `2728/2728`
  (`0` violations); `bench.sh pred` `cost=1 falseAssertions=0`;
  `bench.sh window z1` `n=1..4096` all `cost=1 P=true edits=1`.
- **Multi-error JSON scaling (`bench.sh scale z1 1000/k/1`)**:
  - `1000/16/1`: `cost=14, ms=218`
  - `1000/32/1`: `cost=29, ms=352`
  - `1000/64/1`: `cost=59, ms=695`
  with **0% duplicate pure-memo work**.
- **`_tilde.dart z1`**: `cases=909 crashes=0 cost=14933` in ~7 s (all 909 cases
  up to `n=3,000` run twice = 1,818 runs).
- **`deep.sh z1`**:
  - `depth` `n=100..3200`: `missing=0` in `0..44 ms`; `missing=1` in
    `19..2,988 ms` (`cost=1`).
  - `x (ax)*n b` `n=50..1600`: `3 / 10 / 34 / 116 / 390 / 840 ms` (`cost=1`).
  - `x (ab)*n` `n=50..1600`: `1 / 3 / 6 / 12 / 49 / 82 ms` (`cost=n`).
- **`_chkscale.dart z1` (`n=100 / 200 / 400`, JIT)**:
  - case 0: `28 / 45 / 61 ms` (`cost=2`)
  - case 1: `31 / 42 / 64 ms` (`cost=2`)
  - case 2: `18 / 23 / 36 ms` (`cost=102 / 202 / 402`)
  - case 3: `247 / 510 / 1,689 ms` (`cost=50 / 100 / 200`)
  - case 4: `178 / 265 / 472 ms` (`cost=35 / 68 / 135`)
