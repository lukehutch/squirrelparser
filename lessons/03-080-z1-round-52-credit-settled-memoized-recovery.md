<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z1 - round 52: credit-settled memoized recovery on the native parser
(2026-10-22)

Round 52 builds `z1.dart` (copied to `_z1.dart`), a single-pass memoized
recovery relation attached directly to the native `peg.Parser` via
`Map.identity()` without windows, beams, or re-parsing:

1. **Zero duplicate pure-memo work**: clean parses always consult
   `parser.match(c, pos)`, and repaired readings at `(c, pos)` are memoized in
   `_relations[entry]` by budget watermark (`cell.budget >= _budget`) and
   left-recursion seed version.
2. **Evidence-based credit settlement (`credit` and
   `used = max(0, spent - credit)`)**: independent errors that are followed by
   clean evidence settle their spent edits into `credit` at `_budget = 1`, so a
   document with `k` separated errors recovers at `_budget = 1` without
   cross-error combinatorial products:
   - In `_seq`: `rSync` settles an edited prefix before a `Repetition` slot;
     `rSub` settles a pure substitution prefix (`r.subs == r.deleted`,
     `r.missing == 0`, `r.absorbed(pos) == 0`) before a `Repetition` slot and
     prunes the zero-length repetition stop (`subSettled && o.end == r.end`)
     when a settled continuation exists, making right-recursive `x (ab)*n`
     linear (`O(n)`: `11 ms` at `n = 400`, `61 ms` at `n = 800`, `97 ms` at
     `n = 1,600`); `syncSkip` settles a synchronized prefix before a final
     closing delimiter (`i == slots.length - 1`), solving `_chkscale` case 3
     (`[ `*n + `n` + `]]x`*(n/2)) at `_budget = 1`.
   - In `_seq`: settling onto an option `o` that already carries settled credit
     (`o.credit > 0`) requires `o.first > r.last + 1` (at least 2 clean
     characters between `r`'s edit and `o`'s first edit), preventing phantom
     wrapper proliferation on `T <- 'x' / '(' E ')'` in `_tilde.dart`
     (`maxWays` drops from `>1,000` to a constant `7` at length `9,000`).
   - In `recover()`: `owedCredit` walks past trailing EOF `owed` edits
     (`while (p != null && p.owed > 0) p = p.prev`) to check
     `_len > (p?.last ?? -1) + 1`, allowing deep nested inputs with an interior
     repair and a missing closing delimiter at EOF to settle at `_budget = 1`
     without affecting 2-edit battery cases (`w.credit == 0`).
3. **Cut obligations (`cut`) and cycle-safe `_startsClean`**: ordered choice
   (`First`), `Optional`, and `Repetition` record the plain parser's farther
   reach as `cut`, rejecting extensions that cross `cut` without a prior edit.
   Adding a cycle guard `(seen ??= {}).add(c)` to `_startsClean` eliminates all
   left-recursive `Ref -> First -> Ref` stack overflows in the random-grammar
   fuzzers (`0` crashes and `0` timeouts across all 6,400 `dl` + `lf` cases).
4. **Bottom-up overflow recovery (`_warmMatch`)**: on deep inputs that exceed
   the call stack (`n >= 800`), catching `StackOverflowError` warms the memo
   tables bottom-up from `p = _len` down to `0`.

Measured results on `z1`:

- **Size**: `529` raw non-comment/non-blank lines (`762` normalized under
  `dart format --language-version=3.0`), `0` analyzer issues.
- **Gates (`_research18.dart gates z1`)**: `accept cx2=true b1=true b2=true`,
  `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1 0 2 3`,
  `cleanTreeDiff=0`.
- **Battery (`_research18.dart battery z1`)**: `score=0.9898, perfect=86.1%,
  crashed=0, uncovered=0, auditBad=0, ms=2845`.
- **Property, predicate, and window checks**: `_properties18.dart z1`
  `2728/2728` (`0` violations); `_pred18.dart z1` `cost=1 falseAssertions=0`;
  `_windowcx.dart z1` `n=1..4096` all `cost=1 P=true edits=1`.
- **Multi-error JSON scaling (`_research18.dart scale z1 1000/k/1`, JIT)**:
  `k=1`: `105 ms` (cost 1); `k=8`: `253 ms` (cost 8); `k=16`: `218 ms`
  (cost 14); `k=32`: `323 ms` (cost 29); `k=64`: `373 ms / 397 MB` (`167 ms`
  warm, cost 59 vs `x511n` cost 65).
- **`_tilde.dart z1`**: `cases=909 crashes=0 cost=14891` (~7 s JIT for all 909
  cases run twice = 1,818 runs up to length `12,000`).
- **`deep.sh z1` (AOT)**: `depth` up to `3,200` (`45 ms` clean, `417 ms`
  missing `]`); `x (ax)*1600 b` `cost=1` in `129 ms`; `x (ab)*1600` `cost=1600`
  in `97 ms` (vs `x513j`'s `1,969 ms` -- 20x faster).
- **`_chkscale.dart z1` (AOT, `n = 100 / 200 / 400`)**: case 0:
  `3 / 6 / 14 ms` (cost 2); case 1: `3 / 6 / 13 ms` (cost 2); case 2:
  `1 / 3 / 7 ms` (cost `102 / 202 / 402`); case 3: `113 / 349 / 1336 ms`
  (cost `50 / 100 / 200`); case 4: `80 / 158 / 469 ms` (cost `35 / 68 / 135`).
- **Fuzzers (`dl.sh` and `lf.sh`, 3,200 cases each, `z1 / c14 / x511n`)**:
  `0` timeouts and `0` crashes; `dl` invalid `107 / 371 / 24`, worse
  `351 / 807 / 104`; `lf` invalid `81 / 233 / 28`, worse `354 / 708 / 79`
  (3.5x fewer invalid and >2x fewer worse than `c14`).
