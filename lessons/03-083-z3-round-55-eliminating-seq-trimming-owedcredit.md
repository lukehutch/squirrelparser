<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z3 - round 55: eliminating `_seq` trimming, `owedCredit`, and `Terminal*`
blind spot (2026-10-22)

Starting from `z2` (`347` raw / `569` normalized LOC), a systematic audit of
every remaining state update, trim pass, and special case uncovered three
further simplifications that simultaneously reduce code size by another **9 raw
/ 9 normalized lines** (`338` raw / `560` normalized LOC) while improving
battery score (`0.9900 -> 0.9901`), battery perfect rate (`86.3% -> 86.4%`,
`1,815/2,101`), `1000/64/1` multi-error scale speed (`519 ms`), `_tilde.dart`
total cost (`14,951 -> 14,901`), and fuzzer performance (`185 vs 2` on `dl.sh`,
`183 vs 2` on `lf.sh`, with `-30` and `-20` fewer `invalid` trees across seeds
`1..8`):

1. **Eliminated Redundant Per-Slot and Exit Trimming in `_seq`, Preserving
   Active LR Seeds in `_read`**:
   - In `z2`, `_seq` computed `farthest = _farthest(cur)` and ran
     `v.trim(farthest)` at the start of every slot *and* again on exit from
     `_seq`, even though `_read` already computes `farthest = _farthest(raw)`
     and trims every returned reading on exit.
   - The only reason `_seq` had needed its own trim was that when `_read`
     returned from an *active* left-recursive cell (`cell.mark < 0`),
     `_read`'s exit `r.trim(farthest)` prematurely demoted shorter clean LR
     seeds (`E -> 'a'`) against longer clean seeds before outer LR
     expansions (`E '+' T`) had finished extending them.
   - Guarding `_read`'s exit trim with `cell.mark < 0 ? r : r.trim(farthest)`
     preserves active LR seeds until the fixed point closes, allowing all
     per-slot and exit `_farthest`/`trim` passes in `_seq` to be deleted
     completely (saving 4 lines and 2 passes per sequence slot).
   - Combined the two empty-repetition skip guards in `_seq` (`subSettled` and
     `r.incomplete && !_oneShape(slot.subClause)`) into a single `mustAdvance`
     boolean.

2. **Eliminated `owedCredit` and the `while (p.prev != null && p.owed > 0)`
   Walk in `recover()`**:
   - In `z2`, `recover()` walked `p = p.prev` to compute `owedCredit`, granting
     an extra `-1` discount at root whenever `w.credit > 0 && w.owed > 0`.
   - However, `w.cost = deleted + missing + (owed == 0 ? 0 : 1)` already
     charges `+1` for EOF truncation (`owed > 0`), and `w.credit` already
     refunds settled in-document edits. When all in-document edits are
     genuinely settled (`w.used == 0`), `w.cost - w.credit` is already
     `1 <= _budget (1)`. Granting an additional `owedCredit = 1` when
     `w.used > 0` actually allowed an *unsettled* second in-document edit plus
     an EOF truncation to masquerade as a single-budget recovery at
     `_budget = 1`, preferring a premature truncation over a complete 2-edit
     parse in battery cases `i=560`, `i=630`, and `i=654`.
   - Deleting the 4-line `p.prev` walk and `owedCredit` fixes `i=560`
     (`0.750 -> 1.000`), `i=630` (`0.833 -> 1.000`), and `i=654`
     (`0.833 -> 1.000`), raising the battery to **`0.9901 / 86.4%`**
     (`1,815/2,101` perfect) and lowering `_tilde.dart` total cost from
     `14,951` to **`14,901`**.

3. **Fixed the Empty Multi-Char `Terminal*` Blind Spot & Unified Multi-Char
   Literal Evidence**:
   - In `z2`, `_read` fast-pathed 1-character terminal repetitions via:
     `if (c is peg.Repetition && c.subClause is peg.Terminal && plain != null)
     { ... if (plain.end - pos == k.length) ... }`
     Because `0 == 0` is always true when `k.isEmpty` (`plain.end == pos`), any
     zero-or-more repetition of a *multi-character* string literal (e.g.
     `"caba"*`) whose first iteration failed at `pos` (`k.length == 0`)
     accidentally satisfied `plain.end - pos == k.length` and returned only the
     0-length `[plain]` match without ever calling `_repeat`!
   - Replacing `plain.end - pos == k.length` with `_minChars(c.subClause) == 1`
     in `_read` and `_ev`, deleting `if (!c.requireOne && c.subClause is
     peg.Terminal) step = step.copy(ev: 0);` (along with the `ev` parameter on
     `_Way.copy`), and guarding `_repeat` against spurious EOF-truncated
     terminal repetitions (`best.ends.isNotEmpty && c.subClause is peg.Terminal
     && step.owed >= step.evidence`) allows multi-character `Str*` clauses to
     recover mutated occurrences just like `Str+`.
   - Across all 8 seeds (`3,200` cases each) of `dl.sh` and `lf.sh`, `z3` beats
     `z2` by **`185` to `2`** on `dl.sh` (reducing `invalid` from `146` to
     **`116`**) and **`183` to `2`** on `lf.sh` (reducing `invalid` from `121`
     to **`101`**), with `0` timeouts.

**Measured results on `z3.dart` (Round 55)**:

- **Size**: **`338` raw** non-comment/non-blank lines (**`560` normalized**
  under `dart format --language-version=3.0` -- down from `347 / 569` in
  Round 54 `z2` and `379 / 613` in Round 53 `z1`), `0` `dart analyze` issues.
- **Battery (`_research18.dart battery z3`)**: **`score=0.9901, perfect=86.4%
  (1,815/2,101), crashed=0, uncovered=0, auditBad=0, ms=2829`** (`2,868 ms` in
  review).
- **All 4 Honesty Gates (`_research18.dart gates z3`)**: `accept cx2=true
  b1=true b2=true`, `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1
  0 2 3`, `cleanTreeDiff=0`.
- **Properties, predicate, and window checks**: `props z3` `2728/2728`
  (`0` violations); `pred z3` `cost=1 falseAssertions=0`; `window z3`
  `n=1..4096` all `cost=1 P=true edits=1`.
- **Multi-error JSON scaling (`_research18.dart scale z3 1000/k/1`)**:
  - `1000/16/1`: `cost=14, ms=251, covered=true, edits=14`
  - `1000/32/1`: `cost=29, ms=359, covered=true, edits=29`
  - `1000/64/1`: `cost=59, ms=519, covered=true, edits=59`
- **`_tilde.dart z3`**: `cases=909 crashes=0 cost=14901` (`50` lower total cost
  than `z2`).
- **`deep.sh z3`**:
  - `depth` `n=100..3200`: `missing=0` in `0..47 ms`; `missing=1` in
    `19..3,050 ms` (`cost=1`).
  - `x (ax)*n b` `n=50..1600`: `3 / 10 / 36 / 116 / 381 / 810 ms` (`cost=1`).
  - `x (ab)*n` `n=50..1600`: `1 / 2 / 6 / 12 / 141 / 209 ms` (`cost=n` for
    `n <= 400`, `cost=n+1` at `n >= 800` when run standalone cold).
- **`_chkscale.dart z3` (`n=1000`, JIT)**:
  - case 0: `cost=2, ms=212`
  - case 1: `cost=2, ms=208`
  - case 2: `cost=1002, ms=77`
  - case 3: `cost=500, ms=7903`
  - case 4: `cost=335, ms=870`
- **Fuzzers (`SEEDS="1..8" dl.sh` and `lf.sh`, 3,200 cases each, `z2` vs
  `z3`)**:
  - `dl.sh`: `worse: {'z2': 185, 'z3': 2}, invalid: {'z2': 146,
    'z3': 116}, timeouts: 0, levWorse: {'z2': 179, 'z3': 2}`.
  - `lf.sh`: `worse: {'z2': 183, 'z3': 2}, invalid: {'z2': 121,
    'z3': 101}, timeouts: 0, levWorse: {'z2': 181, 'z3': 1}`.
