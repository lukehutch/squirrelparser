<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z7 - round 58: balanced bitfield packing, active-LR skip guards, and
ordered-choice totality and dominance laws (2026-10-24)

`_z7.dart` (kit `z7.dart`, 451 raw / 806 normalized lines) evolves
`_z6.dart` (413 raw / 716 normalized) to resolve both defects from the
z6 review (`_bits.dart` and `_bits2.dart`) and cut invalid trees across
all 12,800 fuzzer cases (`dl.sh` and `lf.sh`, seeds 1-8 and held-out
seeds 9-16) from 160 (`z6`) and 116 (`x513j`) down to 96, while keeping
bit-identical battery trees and costs (`0.9904 / 86.6`, `treeDiff=0`,
`costDiff=0` against `zd` in `x3.exe`).

**1. Balanced 63-bit `edits` packing and 15-bit active `First` arm index
(`_bits.dart` resolution).**

In `_Way`, the 63 positive bits of `edits` are partitioned into five
12/13-bit fields instead of `12/8/18/10/15`:
- `missing`: bits 0..12 (`edits & 0x1FFF`, up to 8,191; `+1` at `1`).
- `owed`: bits 13..25 (`(edits >> 13) & 0x1FFF`, up to 8,191; `+1` at
  `1 << 13`).
- `subs`: bits 26..37 (`(edits >> 26) & 0xFFF`, up to 4,095; `s << 26`
  in `_Way.skip`).
- `fee`: bits 38..49 (`(edits >> 38) & 0xFFF`, up to 4,095; `1 << 38`
  in `_seq`).
- `credit`: bits 50..62 (`edits >> 50`, up to 8,191; `r.used << 50` in
  `_seq` and `_repeat`).

In `_read` and `_propose`, an active `_Cell.mark` packs
`~(d << 16 | arm << 1 | seeded)`, expanding the active `First` arm
index `arm` from 7 bits (`& 0x7F`, mask `0xFE`) to 15 bits (`& 0x7FFF`,
mask `0xFFFE`, up to 32,767 arms). On `_bits.dart`, `z7` returns exact
costs at all tested sizes (`owed` n = 250..300 -> cost 250..300; `arms`
n = 100..200 -> cost 7). This also exposed a silent overflow in `z6` on
`_chkscale.dart` case 4 (`n = 2000`, `r('[n,', 2000) + r(']', 1333)`):
2,000 openers and 1,333 closers require 667 missing `]` insertions at
EOF plus 1 edit for the trailing comma (true cost 668), which `z6`'s
8-bit `owed` field wrapped mod 256 to `668 - 512 = 156`; `z7` reports
the true cost `668`.

**2. Coordinate-identification law of deletion for active left-recursion
(`_bits2.dart` resolution).**

Under deletion of `k` characters at `pos..pos+k`, position `pos` in the
repaired string is identified with `pos + k` in the input. If a
left-recursive rule `E` is currently active at `pos` (`_active(slot,
r.end)`), skipping `pos..pos+k` and calling `_plain(E, pos + k)` inside
`_seq` or `_repeat` bypasses the active fixed-point cell at `pos` and
evaluates `E` fresh at `pos + k` without the left-recursion seed,
preventing outer left-recursive growth across `pos..pos+k`. Guarding the
skip-ahead deletion/substitution blocks in `_seq` and `_repeat` with
`!_active(slot, r.end)` / `!_active(c.subClause, r.end)` and guarding
`_repeat`'s fast-forward loop against active taken `First` arms
(`!_active((m1.piece as peg.MatchResult).subClauseMatches.firstOrNull
?.clause ?? c.subClause, r.end)`) resolves `_bits2.dart` (`cost=7` and
`cost=8`, matching `e7s` and `x513j`).

**3. Per-slot `_seedDepth` isolation, zero-width repairs under nullable
clauses, and trailing EOF repetitions.**

- In `_seq`, `_seedDepth` is isolated per slot (`prevSeed = _seedDepth;
  _seedDepth = _never; ... _seedDepth = _min(prevSeed, _seedDepth);`)
  and `lrNullRep` is checked at any non-final slot (`i < slots.length -
  1 && r.end == pos`), so a left-recursive prefix at slot 0 (such as
  `R0*` in `R0 <- ((R0* 'c'* !'b') 'a')`) does not leak its `_seedDepth`
  into subsequent non-recursive repetitions at `r.end == pos`.
- In `_read`, repaired zero-width ways (`!r.clean && r.end == pos`) are
  admitted even when `plain?.end == pos`, allowing a zero-width
  insertion inside `OneOrMore(Optional(...))` (`'b'?+`) to feed outer
  left-recursive rules that require non-empty progress.
- In `_seq`, `mustAdvance` requires `r.end < _len ||
  slots.skip(i + 1).any((s) => _min0(s) > 0)`, so a trailing repetition
  at EOF with no required closing delimiter after it is not forbidden
  from matching 0 times after an `owed` insertion, while constructs with
  a closing delimiter (`Block`, `String`) keep `z6`'s exact EOF behavior.

**4. Exact memoized 1-char derivability (`_matchesOne`) and productive
`FollowedBy` in `_minChars`.**

- `_matchesOne(peg.Clause c, String ch)` is replaced by a 1-line
  memoized query in `_one` running a fresh `peg.Parser` on the
  1-character string `ch` (`!m.isMismatch && m.len > 0`). Unlike the old
  structural approximation, this is exact for arbitrary nested `Seq`,
  lookahead predicates (`&`/`!`), and nullable prefixes without running
  a second parse on the document (obeying D1).
- In `_minChars`, `peg.FollowedBy` checks `!req &&
  _minChars(c.subClause, {...p, c}) < _never ? 0 : _never`, so
  unproductive left-recursive lookahead arms (`&R0+` where `R0 <- &R0+`)
  return `_never` instead of `0`.

**5. Algebraic laws of `First` ordered choice (`_total`, `_key`,
`_head`, `_covers`, `nul`, and `_steals`).**

- **Totality (`_total` and `nul`):** In PEG, `Optional` and `ZeroOrMore`
  (and `Seq`/`First`/`Ref` built from them without active left
  recursion) are total functions that never return `Mismatch`. Once a
  non-active total arm is evaluated in `First`, no subsequent arm can
  ever be reached (`break`). Conversely, when a non-total arm matches
  `pos..pos` (`0` length) only via a lookahead predicate (`!_total(sub,
  pos)`), `nul = true` allows later arms only if their first edit is at
  `pos` (`r.first == pos`) to break the lookahead.
- **Dominance (`_key`, `_head`, `_covers`, `seen`):** If a later arm
  `sub` of `First` or its required initial clause (`_head(sub)`, Cached
  in `_heads` alongside `_key` in `_str`) is already covered in `seen`
  by an earlier non-active arm (`_covers`), `sub` can never be reached
  in PEG and is skipped (`continue`).
- **Unified left-spine and first-edit stealing (`_steals`, `_eq`,
  `_tails`):** `_firstEdit` is generalized into `_steals(us, o, at)` and
  applied to non-clean ways (`!o.clean`) in `First` (against `priors`),
  `_seq` (against `getTails()`), and `_repeat` (against `getTails()`).
  `_tails` now also collects `Optional` subclauses and prior arms of
  0-length `First` matches at `end`. `_steals` rejects `o` if either (a)
  `o` is non-empty in the repaired string and any clause along its left
  spine at `at` equals a clause in `us` (`_eq`), or (b) `o.first == at`
  and its initial edit at `at` triggers any clause in `us` (`_matchesOne`
  for 1-char insertion/substitution, `_plain` for deletion).

**Measurements** (kit, 2026-10-24):

| Check | z6 (`zd`) | z7 |
|---|---|---|
| LOC (normalized / raw) | 716 / 413 | 806 / 451 |
| Battery (2,101 cases) | 0.9904 / 86.6 | 0.9904 / 86.6, treeDiff 0, costDiff 0 |
| Battery JIT (`bench.sh battery`) | 2,812-2,899 ms | 3,407 ms |
| Battery AOT (`x3.exe bench 3 zd z7`) | 2,802 ms median (2,794 min) | 3,101 ms median (3,101 min), treeDiff 0, costDiff 0 |
| Gates (`accept`, `freespan`, `recommit`, `conf1`, `cleanTreeDiff`) | all pass | all pass (`true/true/true`, `3 3 4 4 1`, `16/16`, `0 1 1 0 2 3`, `0`) |
| `props` / `pred` / `window` | 0 / 0 / P at every n | 0 violations (2,728 cases) / falseAssertions=0 / P=true at n=1..4096 |
| `_bits.dart` (`owed` n=250..300, `arms` n=100..200) | FAILS (`owed` cost 1 at 257, 44 at 300) | PASSES (cost 250..300; arms cost 7) |
| `_bits2.dart` (2 LR + error cases) | FAILS (cost 4, cost 8) | PASSES (cost 7, cost 8; matches e7s and x513j) |
| Many errors (`scale 1000/16/1`, `32/1`, `64/1` JIT) | rung 64: 584 ms (cost 59) | 362 ms (cost 14), 581 ms (cost 29), 535 ms (cost 59) |
| Many errors (`x3.exe rung 1000/64/1 3` AOT) | 251 ms (cost 59) | 235-282 ms (cost 59) |
| `deep.sh` (depth 100..3200; `x(ax)*nb`, `x(ab)*n` 50..1600) | depth 3,200 missing 1: 280 ms | all finish; depth 3,200 missing 0/1: 44/316 ms; `x(ax)*1600b`: 695 ms; `x(ab)*1600`: 81 ms |
| `_tilde.dart` (909 transparent-rule cases) | 0 crashes, cost 14,686 | 0 crashes, cost 14,686 |
| `_chkscale.dart` (`n=2000` cases 0, 1, 4; `n=500` case 2; `n=200` case 3) | case 4 cost 156 (overflowed from 668) | all finish; case 0/1: 362 ms (cost 2); case 2 (`n=500`): 91 ms (cost 501); case 3 (`n=200`): 2,276 ms (cost 100); case 4 (`n=2000`): 2,684 ms (true cost 668) |

**Fuzzer comparison** (`dl.sh` and `lf.sh`, 8 seeds x 400 = 3,200 cases
per row, 3-way head-to-head `z7 / zd / x513j`; `zd` is `z6`):

| Suite & seeds | `worse` (`z7 / zd / x513j`) | `levWorse` (`z7 / zd / x513j`) | `invalid` (`z7 / zd / x513j`) | `timeouts` |
|---|---|---|---|---|
| `dl.sh` seeds 1-8 (3,200) | 77 / 68 / 156 | 63 / 57 / 134 | **19** / 35 / 22 | 0 / 0 / 0 |
| `dl.sh` seeds 9-16 (3,200, held-out) | **77** / 82 / 146 | **69** / 70 / 122 | 27 / 46 / **25** | 0 / 0 / 0 |
| `lf.sh` seeds 1-8 (3,200) | **75** / 84 / 118 | **55** / 70 / 95 | **25** / 35 / 26 | 0 / 0 / 0 |
| `lf.sh` seeds 9-16 (3,200, held-out) | **73** / 90 / 148 | **53** / 72 / 126 | **25** / 44 / 43 | 0 / 0 / 0 |
| **Total (12,800 cases)** | **302** / 324 / 568 | **240** / 269 / 477 | **96** / 160 / 116 | **0 / 0 / 0** |

Across all 12,800 fuzzer cases (including the 6,400 held-out cases on
seeds 9-16), `z7` cuts `z6`'s invalid trees by 40% (`160 -> 96`) and
beats `x513j` on total invalid trees (`96` vs `116`), on `dl` seeds 1-8
invalid trees (`19` vs `22`), on `lf` seeds 1-8 invalid trees (`25` vs
`26`), and on `lf` seeds 9-16 invalid trees (`25` vs `43`), while also
beating both `z6` and `x513j` on total `worse` (`302` vs `324` and
`568`) and `levWorse` (`240` vs `269` and `477`).
