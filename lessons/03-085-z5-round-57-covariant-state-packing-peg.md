<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z5 - round 57: covariant state packing, PEG monotonicity laws, and
single-lookup cell frontiers (2026-10-23)

Round 57 (`_z5.dart`, `418` raw / `732` normalized LOC, down from `443` raw /
`762` normalized in `z4`) refines and compacts `z4` by exploiting five state
covariances across `_Way`, `_Cell`, `_read`, and `_tree`, together with six
PEG monotonicity and structural symmetry laws:

1. **Covariant `incomplete` via Parity-Tagged `last` in `_Way`**:
   - In `z4`, `_Way` stored `final bool incomplete;` alongside `last`, and
     `then(_Way r)` recomputed `r.incomplete || (r.end == end && incomplete)`
     while retaining `last > r.last ? last : r.last`.
   - In `z5`, `last` encodes both the position of the latest edit (`last >> 1`)
     and whether that edit was a zero-width terminal insertion (`odd`:
     `(first << 1) | 1`) or a span deletion/substitution (`even`: `b << 1` in
     `_Way.skip`, `-1` when clean). Because `then` takes `max(last, r.last)`,
     a reading ends with an unclosed zero-width insertion at `end` if and only
     if `last == (end << 1) | 1 > end << 1`. Thus
     `bool get incomplete => last > end << 1;` is 100% covariant with
     `(last, end)`, eliminating the `incomplete` field and its propagation in
     `then`.

2. **Homomorphic Bit-Sliced Edit Counters (`edits` in `_Way`)**:
   - In `z4`, `_Way` carried 14 fields (`end, deleted, missing, owed, subs,
     evidence, first, fee, credit, cut, last, incomplete, piece, prev`), and
     `_seq` / `_repeat` allocated intermediate `_Way.copy` objects to attach
     `fee` or `credit` before or after `then`.
   - In `z5`, the five non-span edit counters `(missing, owed, subs, fee,
     credit)` are packed into a single 63-bit integer `final int edits`
     (`missing`: bits `0..14` `& 0x7FFF`, `owed`: bits `15..22` `& 0xFF`,
     `subs`: bits `23..37` `& 0x7FFF`, `fee`: bits `38..47` `& 0x3FF`,
     `credit`: bits `48..62` `>> 48`), while `deleted` remains a full 63-bit
     `int` so documents of arbitrary length never overflow `deleted` and deep
     repetitions (`n = 3,000` in `_tilde.dart`) never overflow `missing`,
     `subs`, or `credit`.
   - Because all five counters in `edits` are additive under `then(_Way r,
     [int d = 0])`, `edits + r.edits + d` sums all five counters plus any
     credit settlement (`r.used << 48`) or penalty fee (`1 << 38`) in a single
     integer addition, eliminating `_Way.copy` entirely and shrinking `_Way`
     from 14 fields to 9 (`end, deleted, edits, evidence, first, cut, last,
     piece, prev`).

3. **Single-`int` `_Cell` Key and Single-Compare Frontier Admission**:
   - In `z4`, `_Cell.ends` was a `Map<(int, bool, bool, int), _Way>` keyed by
     the 4-tuple `(r.end, r.incomplete, r.missing == 0, r.used)`, and `add`
     called both `b.cmp(r)` and `r.cmp(b)`.
   - Ablation on the 2,101-case battery and 8-seed fuzzers showed that the
     `r.missing == 0` bit in `_Cell`'s key was redundant (dropping it improves
     the battery by `+1` perfect case and cuts `dl.sh` `worse` by `2`), and
     that `_zeroWays` on `Squirrel` was redundant because `_evidence` already
     caches `_ev(m)` in `O(1)`.
   - In `z5`, `ends` is a `Map<int, _Way>` keyed by the single packed integer
     `k = (r.end << 15) | (r.used << 1) | (r.incomplete ? 1 : 0)`, and `add`
     evaluates `cmp` once (`final c = r == null ? -1 : ends[k]?.cmp(r) ?? 1;`).

4. **Active `First` Arm Packed into `cell.mark` and Producing Arm Read from
   `r.piece`**:
   - While a cell is active at depth `d` (`cell.mark < -1`), `~cell.mark`
     packs `(d << 8) | (arm << 1) | seededBit`. In `_propose` (`peg.First`),
     before evaluating arm `i`, `cell.mark` updates the active arm index `i`.
   - When a recursive call in `_read` reads an active `First` cell
     (`cell.mark < 0 && c is peg.First`), it reads the producing subClause `s`
     of each seed `r` directly from `r.piece` (`(final peg.Clause s, _, _) ||
     peg.MatchResult(clause: final s?)`) and requires
     `c.subClauses.indexOf(s) >= (~cell.mark >> 1) & 0x7F`. Because PEG
     `First.match` tries arms in strict index order `0, 1, ...`, arm `j` at
     `pos` can never observe a left-recursive seed at `pos` produced by an
     earlier arm `i < j` (had arm `i` succeeded at `pos`, `First` would have
     returned arm `i` without ever reaching arm `j`).

5. **Post-Order `_tree` Without `ready` Flag and Boxed-Record Identity**:
   - Symmetric with `_ev(m)`, `_tree(Object root, int rootEnd)` keeps only
     unbuilt composite nodes on `todo = [(root, rootEnd)]`, collects unbuilt
     composite children into `miss`, and builds `peg.Match` once `miss` is
     empty, eliminating the 3-tuple `(Object, int, bool ready)` state flag.
   - Keeping `piece` and `p` statically typed as `Object` (rather than the
     record type `(peg.Clause?, int, _Way)`) prevents Dart's AOT compiler from
     unboxing and re-boxing records across `todo` and `built`
     (`Map.identity()`).

6. **Five Additional PEG Monotonicity & Structural Symmetry Guards**:
   - **Zero-Growth Left-Recursion Cycle Guard (`_wraps` in `_read`)**: A
     recursive expression `_wraps(_Way? r, peg.Clause c, int pos, int end)`
     rejects any candidate `r` for `(c, pos)` ending at `end` that wraps a
     descendant labeled `(c, pos)` with the identical span `pos..end`, since
     `MemoEntry.match` stops left-recursion expansion when length does not
     strictly increase.
   - **Nullable-Arm Ordered-Choice Shadowing in `First` (`_propose`)**:
     Unwrapping `sub` for `act` checks `sub is peg.Repetition && sub.requireOne`
     (`OneOrMore`) rather than `HasOneSubClause`. Because `Optional` and
     `ZeroOrMore` always succeed with at least `len = 0` on Pass 1 of
     `MemoEntry.match` (`r.preferred && r.end == pos`), they shadow all later
     arms of `First` at `pos` even when their operand is active.
   - **Clean Root Rejection (`w.clean` in `recover`)**: Once the initial
     `verdict = parser.match(top, 0)` fails to span `0.._len`, no zero-edit
     reading (`w.clean`, whether `_preferred` or `_clean`) can be a valid full
     parse of the damaged input.
   - **Greedy Left-Recursive Prefix Absorption (`lrNullRep` in `_seq`)**: When
     slot `0` (`i == 0`) in `_seq` is a nullable repetition (`Repetition` or
     `Optional` of `Repetition` with a clean empty match at `pos`) whose
     evaluation read an active left-recursive rule (`_seedDepth < _never`), and
     the remaining slots require at least one character (`_minChars(s) > 0`),
     slot `0` cannot stop at `o.end > pos` because in PEG its greedy repetition
     at `o.end` would consume the remaining slots as another iteration of the
     left-recursive rule.
   - **Symmetric `_matchesOne` on `peg.Seq` and Leaf Substitution Check in
     `_firstEdit`**: In `_matchesOne`, a `peg.Seq` matches a single character
     `ch` whenever its sole positive-`_minChars` slot matches `ch` (handling
     leading as well as trailing nullable slots) or, if all slots are nullable,
     any slot matches `ch`. In `_firstEdit`, leaf `SyntaxError` steps that are
     substitutions (`x.subs > (x.prev?.subs ?? 0)`) return `null` at the leaf
     rather than suppressing the tail-stealing check across the entire subtree
     whenever a later slot had `o.subs > 0`.

**Approaches tried and reverted in Round 57**:
- Applying a prefix-stealing check across earlier arms of `peg.First` and
  unwrapping `HasOneSubClause` in `_repeat`'s tail-cut check: reverted because
  calling `_plain(u, pos + len)` at `pos + len > pos` evaluates left-recursive
  rules in `u` fresh at `pos + len` where they are not in left-recursion,
  increasing `dl.sh` `worse` from `56` to `66`.
- Packing `deleted` and `subs` into 12-bit and 11-bit slices of `edits`: caught
  by `_tilde.dart` at `n = 3,000` (`len = 6,000..12,000`), where `deleted >=
  4,096` and `subs = 2,999 >= 2,048` overflowed into adjacent bit-slices.
  Keeping `deleted` as a full `int` and widening `missing`, `subs`, and
  `credit` to 15 bits each (`0..32,767`) in `edits` eliminated the overflow and
  saved one getter line.

**Measured results on `z5.dart` (`_z5.dart`, Round 57)**:

- **Size**: **`418` raw** non-comment/non-blank lines (**`732` normalized**
  under `dart format` -- down `25` raw / `30` normalized lines from `z4`'s
  `443` raw / `762` normalized, and vs `x513j`'s `777` raw / `918` normalized),
  `0` `dart analyze` issues, `284/284` repository tests passing.
- **Battery (`_research18.dart battery z5`)**: **`score=0.9904, perfect=86.6%
  (1,819/2,101), crashed=0, uncovered=0, auditBad=0, ms=2778-2859`** (up `+4`
  perfect cases and `+0.0002` score from `z4`'s `0.9902 / 86.4%`, and `14%`
  faster in JIT than `z4`'s `3,227-3,264 ms`). On `out/x3.exe bench 3 z5 z4
  x513j`: `z5 min=2857 ms, med=2863 ms` vs `z4 min=3108 ms, med=3133 ms`.
- **All 4 Honesty Gates (`_research18.dart gates z5`)**: `accept cx2=true
  b1=true b2=true`, `freespan 3 3 4 4 1`, `recommit 16/16`, `conformance 0 1 1
  0 2 3`, `cleanTreeDiff=0`.
- **Properties, predicate, window, and transparent-rule checks**:
  `_properties18.dart z5` `2728/2728` (`0` violations); `_pred18.dart` `cost=1
  falseAssertions=0`; `_windowcx.dart z5` `n=1..4096` all `cost=1 P=true
  edits=1`; `_tilde.dart z5` `cases=909 crashes=0 cost=14633`.
- **Multi-error JSON scaling (`out/x3.exe rung z5` AOT and `_research18.dart
  scale z5` JIT)**:
  - `1000/16/1`: **`cost=14, ms=139` AOT** / `283 ms` JIT.
  - `1000/32/1`: **`cost=29, ms=201` AOT** / `377 ms` JIT.
  - `1000/64/1`: **`cost=59, ms=251` AOT** / `584 ms` JIT.
- **`deep.sh z5` (AOT)**:
  - `depth` `n=3200 missing=0`: `cost=0, ms=38`.
  - `depth` `n=3200 missing=1`: **`cost=1, ms=282`** (vs `z4` `296 ms`).
  - `x (ax)*1600 b`: **`cost=1, ms=81`** (vs `z4` `103 ms`).
  - `x (ab)*n` `n=50..1600`: **`1 / 2 / 5 / 31 / 44 / 71 ms`**, **`cost=n` for
    all `n` including `800` and `1600`** (vs `z4` `75 ms` and `x513j` `1,945
    ms`).
- **8-Seed Random-Grammar Fuzzers (3,200 cases each)**:
  - Head-to-head (`./dl.sh z5_h2h z5 x513j` and `./lf.sh z5_h2h z5 x513j`):
    - `dl.sh`: `worse: {'z5': 56, 'x513j': 144}, invalid: {'z5': 35, 'x513j':
      22}, timeouts: 0, levWorse: {'z5': 44, 'x513j': 122}` (`worse` cut by
      **27%** from `z4`'s `77`, and `invalid` cut by **42%** from `z4`'s `60`
      and **70%** from `z3`'s `116`).
    - `lf.sh`: `worse: {'z5': 66, 'x513j': 98}, invalid: {'z5': 35, 'x513j':
      26}, timeouts: 0, levWorse: {'z5': 51, 'x513j': 75}` (`worse` cut by
      **14%** from `z4`'s `77`, and `invalid` cut by **26%** from `z4`'s `47`
      and **65%** from `z3`'s `101`).
  - 5-way with `z4`, `c14`, `cdx10`, and `x513j` (`./dl.sh z5_all z5 z4 c14
    cdx10 x513j` and `./lf.sh z5_all z5 z4 c14 cdx10 x513j`):
    - `dl.sh`: `worse: {'z5': 65, 'z4': 87, 'c14': 837, 'cdx10': 759, 'x513j':
      154}, invalid: {'z5': 35, 'z4': 60, 'c14': 371, 'cdx10': 282, 'x513j':
      22}, timeouts: 0, levWorse: {'z5': 52, 'z4': 73, 'c14': 695, 'cdx10':
      638, 'x513j': 131}`.
    - `lf.sh`: `worse: {'z5': 83, 'z4': 92, 'c14': 729, 'cdx10': 758, 'x513j':
      113}, invalid: {'z5': 35, 'z4': 47, 'c14': 233, 'cdx10': 200, 'x513j':
      26}, timeouts: 0, levWorse: {'z5': 65, 'z4': 72, 'c14': 571, 'cdx10':
      612, 'x513j': 88}`.
