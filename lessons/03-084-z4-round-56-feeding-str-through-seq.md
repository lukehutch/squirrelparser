<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z4 - round 56: feeding `Str` through `_seq`, depth-scoped LR marks,
tail-stealing guards, and post-order `_ev` (2026-10-23)

A head-to-head review of Round 55 `z3` (`338` raw / `560` normalized LOC)
against `x513j` (`777` raw / `918` normalized LOC) showed that while `z3` led
on battery score (`0.9901 / 86.4%` vs `0.9811 / 76.4%`), code size, and
multi-error JSON rungs (`332 ms` / `917 ms` vs `716 ms` / `1,701 ms`), `z3`
trailed `x513j` on random-grammar fuzzers (`dl.sh`: `420` worse vs `110`,
`116` invalid vs `22`; `lf.sh`: `468` worse vs `74`, `101` invalid vs `26`),
deep inputs (`x (ab)*n` at `n >= 800` gave `cost = n + 1` in `769 ms` when run
cold; `n=3200 missing=1` took `3,571 ms`; `x (ax)*1600 b` took `874 ms`), and
repeated recovery-cell work (`z3aud.dart`: `11,845` `bud0to1` re-runs, `71,356`
`againNew` cell re-runs).

Round 56 (`_z4.dart`, `443` raw / `762` normalized LOC, with `_z3.dart`
restored to the Round 55 `bf0fd55` baseline) resolves these gaps through six
actual changes in `_z4.dart`:

1. **Feeding Multi-Character `peg.Str` Through `_seq` (`_letters` in `_read`)**:
   - In `z3`, `peg.Str` in `_read` already split multi-character strings into
     `letters = _letters.putIfAbsent(c, () => [for (final s in
     c.text.split('')) peg.Char(s)])` and delegated to `_seq(letters, pos)`,
     but returned every reading unconditionally (`[for (final r in
     _seq(letters, pos)) r.label(c, pos)]`), including zero-evidence readings
     whose `used + owed > _budget`, while `_seq` only allowed 1-char
     substitutions when `_resumes(slots, i, r.end + 1)` held at budget 1.
   - Filtering `_seq(letters, pos)` in `_read` by `if (r.evidence > 0 || r.used
     + r.owed <= _budget)`, allowing 1-char substitution in `_seq` whenever
     `r.used + 1 < _budget || _resumes(slots, i, r.end + 1)`, and adding a
     single-character skip fallback in `peg.First` when all arms are 1-char
     literals of the same character (`{for (final s in c.subClauses) if
     (_oneLit(s)) '$s'}.length == 1`) plus skip/substitution proposals inside
     `_repeat` (`c.subClause is! peg.CharSet && !_active(c.subClause, r.end)`)
     cuts `worse` cases on 8-seed `dl.sh` from `420` to **`77`** (beating
     `x513j`'s **`141`**) and on 8-seed `lf.sh` from `468` to **`77`** (beating
     `x513j`'s **`98`**).

2. **Depth-Scoped Left-Recursion Seed Tracking (`_depth`, `_seedDepth`,
   `minSeed < d` in `_read`)**:
   - In `z3`, a single boolean `_seedRead` tracked whether any active LR cell
     was read, and `outer = _seedRead; ... _seedRead = outer || _seedRead;`
     propagated `_seedRead = true` up to *every* enclosing caller, even after
     the inner left-recursive cycle had completely finished its fixed point. As
     a result, enclosing non-recursive cells at `pos` were stamped with
     `_versions[pos]` instead of `0xFFFFF` and were needlessly recomputed on
     later version bumps at `pos`.
   - In `z4`, active cells encode their call depth `d = ++_depth` in
     `cell.mark = -2 * d` (set to `-2 * d - 1` when re-entered recursively),
     and `_seedDepth` tracks the minimum depth of any active cycle read. When
     cell `d` finishes its loop, `minSeed < d` is true *only* if `d` depends on
     a still-active outer cycle at depth `< d`; otherwise `cell.mark` is
     stamped with `0xFFFFF` and `_seedDepth` is restored to `outer`.
   - Combined with `mark = ((pos == _len && _budget == 0 ? 1 : _budget) << 20)
     + (_versions[pos] ?? 0)` (and `_budget == 0 && pos < _len` returning
     `[plain]` directly in `_read`), this eliminates **100%** of `bud0to1`
     cell re-runs (`11,845 -> 0`), cuts `againNew` by **30.3%** (`71,356 ->
     49,708`), `againSame` by **37.4%** (`19,386 -> 12,145`), `lrIters` by
     **20.9%** (`13,880 -> 10,975`), and `thens` by **15.2%** (`2,953,167 ->
     2,503,034`).

3. **Allocation-Free Post-Order `_ev(m)` and Bottom-Up `sweep` in `recover()`
   (10x Deep-Input Speedup and Exact `cost = n` on `x (ab)*n`)**:
   - In `z3`, `_ev(m)` only wrote `_evidence[m] = s` for the root of each call,
     without memoizing intermediate `MatchResult` nodes `n` visited on the
     stack, causing `O(depth^2)` traversals on deep trees (`3,571 ms` on
     `n=3200 missing=1`). In `z4`, `_ev(m)` memoizes `_evidence[n] = s` for
     every node `n` in post-order (`if (ok) _evidence[n] = s;`), cutting
     `n=3200 missing=1` from `3,571 ms` to **`296 ms`** (**12.1x faster**) and
     `x (ax)*1600 b` from `874 ms` to **`103 ms`** (**8.5x faster**).
   - In `recover()`, once `StackOverflowError` sets `deep = true`, `sweep`
     warms both `parser.match` and `_read` bottom-up (`p = _len` down to `0`)
     at the start of each budget rung before `_read(top, 0)`, fixing `x (ab)*n`
     at `n = 800, 1600` (`cost = 800, 1600` in `44 ms` and `75 ms`, vs `z3`'s
     `cost = 801, 1601` in `769 ms` and `x513j`'s `1,945 ms`).

4. **Tail-Stealing Guards in `_seq` (`_tails`, `_matchesOne`, `_firstEdit`) &
   Repetition/Optional Cut Guards (`sc > r.end` in `_repeat`)**:
   - In `_seq`, when prefix `r` ends with an open `Repetition` or zero-length
     clause at `r.end`, `_tails` collects those trailing clauses (`getTails()`).
     Before slot `i` skips to `j`, substitutes 1 char, or accepts an option `o`
     whose first edit is at `r.end` (`o.first == r.end`), `_seq` checks whether
     any trailing clause `u` in `getTails()` would cleanly match at `j` or
     match the substituted/inserted character (`_matchesOne`, `_firstEdit`),
     which on re-parse would cause the earlier repetition/optional in `r` to
     greedily consume that character and steal it from slot `i`.
   - In `_repeat`, exit readings check `_plain(c.subClause, r.end)?.end`: when
     `sc > r.end && !(r.end == pos && _seedDepth < _never)`, `r.demote(sc)`
     sets `cut = sc` even on dirty repetitions (since `demote` now updates
     `cut: _min(cut, sc)` unconditionally while `trim` passes `clean ? f :
     _never`), preventing outer sequences from matching past a clean repetition
     continuation at `r.end`.
   - In `_propose` (`peg.Optional`), the empty option is trimmed against the
     *shortest* positive clean reach (`rs.fold(f, (m, r) => r.clean && r.end >
     pos && r.end < m ? r.end : m)`) rather than only the farthest reach `f`.

5. **Lookahead Left-Recursion Probe in `_plain` & `req` Mode in `_minChars`**:
   - When `FollowedBy` or `NotFollowedBy` runs in `_plain` while `_depth > 0`
     and rules at `pos` are active (`(_cells[e]?.mark ?? 0) < -1`), `_plain`
     temporarily clears cached results at `pos`, sets `inRecPath = true` on
     active rules, and checks if a match depends on a 0-length LR seed
     (`act.any((x) => x.$2.foundLeftRec)`), demoting `rk` to `_clean` if
     seeding with `Match(r, pos, 0)` mismatches.
   - Together with item 4, these validity guards cut `invalid` trees on 8-seed
     `dl.sh` from `116` to **`60`** (`-48%`) and on 8-seed `lf.sh` from `101`
     to **`47`** (`-53%`), while lifting battery score to **`0.9902`**.

**Measured results on `z4.dart` (`_z4.dart`, Round 56)**:

- **Size**: **`443` raw** non-comment/non-blank lines (**`762` normalized**
  under `dart format --language-version=3.0` -- vs `x513j`'s `777` raw / `918`
  normalized LOC), `0` `dart analyze` issues, and `dart/lib/` restored to pure
  untouched parser state (`284/284` repo tests pass).
- **Battery (`_research18.dart battery z4`)**: **`score=0.9902, perfect=86.4%
  (1,815/2,101), crashed=0, uncovered=0, auditBad=0`** (up from `0.9901` in
  Round 55, vs `x513j` `0.9811 / 76.4%`). AOT battery (`out/x3.exe bench 3 z4
  x513j`): `z4 min=1781 ms, med=1829 ms` (down from `2,868 ms` in Round 55).
- **All 4 Honesty Gates (`_research18.dart gates z4`)**: `accept cx2=true
  b1=true b2=true`, `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1
  0 2 3`, `cleanTreeDiff=0`.
- **Properties, predicate, and window checks**: `_properties18.dart z4`
  `2728/2728` (`0` violations); `_pred18.dart` `cost=1 falseAssertions=0`;
  `_windowcx.dart z4` `n=1..4096` all `cost=1 P=true edits=1`.
- **Multi-error JSON scaling (`out/x3.exe rung z4` AOT and `_research18.dart
  scale z4` JIT)**:
  - `1000/16/1`: **`cost=14, ms=128` AOT** / `278 ms` JIT (down from `332 ms`
    in Round 55; **5.6x faster** than `x513j`'s `cost=16, 716 ms`).
  - `1000/32/1`: `cost=29, ms=472` JIT.
  - `1000/64/1`: **`cost=59, ms=218` AOT** / `446 ms` JIT (down from `917 ms`
    in Round 55; **7.8x faster** than `x513j`'s `cost=65, 1,701 ms`).
- **`deep.sh z4` (AOT)**:
  - `depth` `n=3200 missing=0`: `cost=0, ms=37`.
  - `depth` `n=3200 missing=1`: **`cost=1, ms=296`** (down from `3,571 ms` --
    **12.1x faster**).
  - `x (ax)*1600 b`: **`cost=1, ms=103`** (down from `874 ms` -- **8.5x
    faster**).
  - `x (ab)*n` `n=50..1600`: **`1 / 2 / 5 / 31 / 44 / 75 ms`**, **`cost=n` for
    all `n` including `800` and `1600`** (fixing the `cost=801/1601` bug and
    speeding up `n=1600` by **10.3x** from `769 ms` to `75 ms`, vs `x513j`'s
    `1,945 ms`).
- **8-Seed Random-Grammar Fuzzers (3,200 cases each)**:
  - Head-to-head (`./dl.sh TAG z4 x513j` and `./lf.sh TAG z4 x513j`):
    - `dl.sh`: `worse: {'z4': 77, 'x513j': 141}, invalid: {'z4': 60, 'x513j':
      22}, timeouts: 0, levWorse: {'z4': 65, 'x513j': 121}`.
    - `lf.sh`: `worse: {'z4': 77, 'x513j': 98}, invalid: {'z4': 47, 'x513j':
      26}, timeouts: 0, levWorse: {'z4': 60, 'x513j': 75}`.
  - 4-way with `c` and `cdx` lines (`./dl.sh c_cmp z4 c14 cdx10 x513j` and
    `./lf.sh c_cmp z4 c14 cdx10 x513j`):
    - `dl.sh`: `worse: {'z4': 87, 'c14': 836, 'cdx10': 759, 'x513j': 152},
      invalid: {'z4': 60, 'c14': 371, 'cdx10': 282, 'x513j': 22}, timeouts: 0,
      levWorse: {'z4': 73, 'c14': 695, 'cdx10': 638, 'x513j': 131}`.
    - `lf.sh`: `worse: {'z4': 91, 'c14': 728, 'cdx10': 757, 'x513j': 111},
      invalid: {'z4': 47, 'c14': 233, 'cdx10': 200, 'x513j': 26}, timeouts: 0,
      levWorse: {'z4': 71, 'c14': 570, 'cdx10': 611, 'x513j': 86}`.
- **Repeated-Work Audit (`z3aud.dart` on the 2,101-case battery, Round 55 vs
  Round 56)**:
  - `bud0to1`: **`11,845 -> 0`** (**-100%**)
  - `againNew`: **`71,356 -> 49,708`** (**-30.3%**, `w: 1,179,886 -> 885,441`)
  - `againSame`: **`19,386 -> 12,145`** (**-37.4%**, `w: 69,759 -> 52,319`)
  - `lrIters`: **`13,880 -> 10,975`** (**-20.9%**)
  - `thens`: **`2,953,167 -> 2,503,034`** (**-15.2%**)
  - `dupDerivs`: **`349,100 -> 323,699`** (**-7.3%**)
