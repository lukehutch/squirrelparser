<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z2 - round 54: covariant state collapse and structural predicates
(2026-10-22)

Stepping back to view `z1` from both the low-level memo/cell state
representation and the high-level grammar recovery invariants yielded `z2`
(`dart/experiments/recovery/_z2.dart`), incorporating five structural
unifications and improvements:

1. **5-to-1 Covariant State Collapse in `_Cell` (`mark`)**:
   In Round 53, `_Cell` carried five separate state fields (`int budget = -1,
   version = -1; bool active = false, recursive = false, usedSeed = false;`)
   with an 8-line entry/exit protocol in `_read`. Because `active` and
   `recursive` are only meaningful while a cell is on the active call stack,
   and `(budget, usedSeed, version)` are monotonic in
   `(_budget << 20) + version` once finished (a cell that did not read a
   left-recursive seed is valid at all versions `0xFFFFF` for its `_budget`),
   all five fields collapse into a single `int mark = -1`:
   - `-1`: uninitialized
   - `-2`: active on the call stack (non-recursive)
   - `-3`: active on the call stack and re-entered by a left-recursive cycle
   - `(_budget << 20) + (_seedRead ? _versions[pos] ?? 0 : 0xFFFFF)`: finished.
   The recomputation check in `_read` collapses to `cell.mark < mark` where
   `mark = (_budget << 20) + (_versions[pos] ?? 0)`.

2. **Unified Structural Predicates on `_Way` (`pureSub`, `synced`, `trim`)**:
   - `bool pureSub(int from) => subs > 0 && cost == subs && absorbed(from) ==
     0;`
     Because `cost = deleted + missing + (owed > 0 ? 1 : 0)` and
     `subs <= deleted`, `subs > 0 && cost == subs` implies `!clean`,
     `spent > 0`, `missing == 0`, `owed == 0`, and `!incomplete` (since
     `incomplete` only arises from `missing > 0` or `owed > 0`). This single
     predicate replaces four 5-clause conjunctions across `_seq` and `_repeat`.
   - `bool synced(int from, [int gap = 1]) => spent > 0 && end > last + gap &&
     evidence > absorbed(from) + 1;`
     Because every edit sets `last >= end_at_edit`, `end > last + gap` with
     `gap >= 0` implies that the final character(s) of the reading were matched
     cleanly (`!incomplete`), unifying prefix synchronization (`r.synced(pos)`,
     `gap = 1`) and suffix settlement (`o.synced(r.end, 0)`, `gap = 0`).
   - `_Way trim(int f) => preferred && f >= 0 && end != f ? demote(f) : this;`
     Unifies non-farthest clean demotion across `_read`, `_propose`
     (`Optional`), and `_seq`.
   - Redundant post-filter removal in `_read`: since `plain = _plain(c, pos)`
     is invariant for `(c, pos)` and every entry added to `cell` is already
     filtered by `r.clean && r.cut >= (plain?.end ?? _never) || plain?.end !=
     r.end`, re-testing that condition when reading from `cell.ends.values` was
     redundant.

3. **Fixed 1-Char Substitution Precedence & Removed Unconditional
   `!r.preferred` Substitution**:
   In Round 53, line 234 of `_seq` read:
   `slot is peg.Char || slot is peg.Str && slot.text.length == 1 &&
   (!r.preferred || _resumes(slots, i, r.end + 1))`
   Due to `||` vs `&&` precedence, `slot is peg.Char` bypassed `_resumes(...)`
   completely, and `!r.preferred` proposed a 1-character substitution on
   *every* dirty prefix at *every* 1-char terminal slot even when the next slot
   could not resume at `r.end + 1`. Changing this to:
   `(slot is peg.Char || slot is peg.Str && slot.text.length == 1) &&
   _resumes(slots, i, r.end + 1)`
   cut `1000/64/1` runtime by **~49%** (`695 ms -> 355 ms` AOT / `555 ms` JIT)
   and battery runtime from `2,800 ms` to **`2,388 ms`** with zero loss on any
   battery case or property test.

4. **Non-Empty Witness Requirement for Interior Structural Repetitions After a
   Missing Opening Delimiter**:
   In `stmt` battery cases with a missing opening `'{'` (`if (a) b = 1; }
   else { ... }`, `while (a) x = 1; }`), the grammar
   `Block <- '{' WS Stmt* WS '}' WS` previously hallucinated a missing
   `'{'` right before the stray closing `'}'`, matching `Stmt*` 0 times
   (`o.end == r.end`) to wrap the stray `'}'` in an empty `Block({})` while
   deleting the actual statements before `'}'`.
   Principle: if a sequence prefix `r` has `r.evidence == 0 && r.incomplete`
   (a hallucinated opening delimiter with zero terminal evidence), a
   non-lexical interior repetition (`slot is peg.Repetition &&
   !_oneShape(slot.subClause)`) cannot match 0 times (`o.end == r.end`).
   One line in `_seq`:
   `if (r.evidence == 0 && r.incomplete && slot is peg.Repetition &&
   !_oneShape(slot.subClause) && o.end == r.end) continue;`
   fixed 6 of the 8 `stmt` missing-`'{'` battery cases (`i=349, 417, 428,
   474, 486, 765`: `0.727..0.903 -> 1.000`) plus `json` `i=46, 546`, lifting
   the 2,101-case battery from `0.9896 / 86.1%` to **`0.9900 / 86.3%`**
   (`1,814 / 2,101` perfect).

5. **Dynamic `First` Nullability, Active Bare-`Ref` Cycle Skip, and `OneOrMore`
   Non-Empty Fallback**:
   To reduce fuzzer `invalid` trees (`dl.sh` and `lf.sh`, where a repaired tree
   must re-parse under strict PEG semantics):
   - In `_propose` (`peg.First`), eliminated `bool settled` (covariant with
     `cut < _never` once `cut = _min(cut, f)` is updated unconditionally for
     `f >= 0`), added `if (rs.any((r) => r.clean && r.end == pos)) break;` (any
     arm of `First` that matches 0 chars cleanly at `pos` is dynamically
     nullable at `pos`, so later arms are unreachable in PEG), and skipped bare
     `Ref` arms already active at `pos` when an earlier arm produced results
     (`if (out.isNotEmpty && _active(sub, pos)) continue;`).
   - In `_repeat`, tightened the `best.ends.isEmpty` fallback
     (`c.requireOne == true`) from `if (r.end == pos)` to
     `if (r.end == pos && !r.clean)` because `OneOrMore` in PEG never accepts a
     0-length clean match.
   Together, these reduced `dl.sh` (5 seeds, 2,000 cases) `invalid` from `151`
   to **`96`** (`-36%`) and `lf.sh` (5 seeds, 2,000 cases) `invalid` from `107`
   to **`76`** (`-29%`), with `0` timeouts and `0` worse cases.

**Measured results on `z2.dart` (Round 54)**:

- **Size**: **`347` raw** non-comment/non-blank lines (**`569` normalized**
  under `dart format --language-version=3.0` -- down from `379 / 613` in
  Round 53 `z1` and `529 / 762` in Round 52), `0` `dart analyze` issues.
- **Battery (`bench.sh battery z2`)**: **`score=0.9900, perfect=86.3%
  (1,814/2,101), crashed=0, uncovered=0, auditBad=0, ms=2388`**.
- **All 4 Honesty Gates (`bench.sh gates z2`)**: `accept cx2=true b1=true
  b2=true`, `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1 0 2 3`,
  `cleanTreeDiff=0`.
- **Properties, predicate, and window checks**: `bench.sh props z2` `2728/2728`
  (`0` violations); `bench.sh pred` `cost=1 falseAssertions=0`;
  `bench.sh window z2` `n=1..4096` all `cost=1 P=true edits=1`.
- **Multi-error JSON scaling (`bench.sh scale z2 1000/k/1`)**:
  - `1000/16/1`: `cost=14, ms=218`
  - `1000/32/1`: `cost=29, ms=327`
  - `1000/64/1`: `cost=59, ms=555` (JIT) / `355 ms` (warm)
- **`_tilde.dart z2`**: `cases=909 crashes=0 cost=14951`.
- **`deep.sh z2`**:
  - `depth` `n=100..3200`: `missing=0` in `0..50 ms`; `missing=1` in
    `19..3,058 ms` (`cost=1`).
  - `x (ax)*n b` `n=50..1600`: `3 / 11 / 34 / 116 / 376 / 842 ms` (`cost=1`).
  - `x (ab)*n` `n=50..1600`: `1 / 2 / 6 / 11 / 47 / 81 ms` (`cost=n`).
- **`_chkscale.dart z2` (`n=100 / 200 / 400`, JIT)**:
  - case 0: `30 / 70 / 69 ms` (`cost=2`)
  - case 1: `36 / 64 / 70 ms` (`cost=2`)
  - case 2: `19 / 28 / 39 ms` (`cost=102 / 202 / 402`)
  - case 3: `285 / 641 / 2,376 ms` (`cost=50 / 100 / 200`)
  - case 4: `192 / 245 / 472 ms` (`cost=35 / 68 / 135`)
- **Fuzzers (`SEEDS="1 2 3 4 5" dl.sh` and `lf.sh`, 2,000 cases each)**:
  - `dl.sh`: `worse: 0, invalid: 96, timeouts: 0, levWorse: 0` (down from
    `151` invalid in `z1`).
  - `lf.sh`: `worse: 0, invalid: 76, timeouts: 0, levWorse: 0` (down from
    `107` invalid in `z1`).
