<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c22, final audit and a separate clean-path control (2026-09-08)

**76. Stable preference includes grammar identity, not allocation order.**
Before the final audit, synthetic character clauses inside multi-character
literals were moved into the grammar-indexing pass. Allocating their
canonical IDs at the first recovery failure was an avoidable dependence
on exploration order, even though the raw-order test had not exposed it.
The final policy is charge, evidence, latest first error, earliest last
error, EOF mark count, mixed-edit tie, node count, canonical preorder with
depth. The incomplete-root exception is resolved explicitly before the
position/tie passes. Node count makes unproductive recursive wrapping lose.

CONFIRMED before that ID fix: `_packed22.dart schedule raw` compared
13,241 cases with both relation-view and OR traversal reversed: **zero
different trees or costs**, 47,005 ms for both orders combined. Final
post-fix validation is recorded below; this earlier run is not substituted
for it.

Final-source timing (`_timing22.dart 3`): one warm-up, three measured rounds,
rotating c20/c21/c22 order in one process, no other benchmark worker running.
Clean columns time 200 repetitions of the entire undamaged corpus; damaged
columns time one complete weighted 2,101-case battery. These are medians,
in milliseconds, not per-document latency:

| Engine | Clean corpus × 200 | Damaged battery |
|---|---:|---:|
| c20 | 192.896 | 1154.875 |
| c21 | 188.153 | 1182.747 |
| c22 packed/query | 103.731 | 3337.049 |

The damaged path is **2.89× slower than c20** here. The clean path avoids
recovery grammar setup altogether. A separate `_c20defer.dart` control moves
only `_site(top)` below c20's already-successful ordinary-parse return; its
validation and timing follow below. This is not a solution to damaged-input
search, and the original c20 is unchanged.

Physical nonblank, non-`//` lines (`awk` count; **not** the normalized LOC
used in older tables): c20 **677**, c21 **679**, c22 **804** (including the
one-line lower-bound API shared by the ablation controls). C22 is larger,
and does not meet the sub-400 target. No formatter or code golfing was used.

CONFIRMED fresh serial `_family22.dart ENGINE SITES` on the independently
ambiguous `a;` family (each result cost=edits=sites, Item count=sites,
covered=true):

| Sites | c20 ms / peak MiB | c22 ms / peak MiB |
|---|---:|---:|
| 8 | 20 / 280.3 | 38 / 285.6 |
| 32 | 94 / 289.6 | 72 / 285.2 |
| 64 | 242 / 286.6 | 125 / 290.2 |
| 256 | 21435 / 444.6 | 282 / 313.5 |
| 1024 | 30-second cap, exit 124 | 823 / 354.1 |

These are cold single workers, not medians or isolated recovery heap.
The family isolates independent ambiguity; it does not stand in for the
JSON battery or contradict c22's poor 23.6 KB JSON result.

At 256 sites the completed-run ratio is 76×. The 1,024-site timeout is
not a completed-run ratio or evidence of nontermination. A follow-up
ablation puts the same regular lower bound into the **old** c20: eagerly
(`_c20floor.dart`) or only after budget 1 has genuinely failed
(`_c20guided.dart`). This is needed before attributing the family speedup
to packing: avoiding futile budget rounds is a separate effect.

CONFIRMED at 256 sites: eager c20+floor **10,638 ms / 446.1 MiB**;
lazy-after-budget-1 c20+floor **10,812 ms / 329.4 MiB**. Both returned
cost=edits=Item count=256 with full coverage. The lower bound roughly halved
c20's time, but did **not** explain the whole 21,435→282 ms difference.
A further all-positions-open control checks the cost of the window-opening
ladder itself before assigning the remaining difference to representation.

That control **refutes a packing-only speedup claim**: `_family22.dart
openfloor 256` returned the same cost, Item count and coverage in **256 ms /
295.5 MiB**, versus packed c22's 282 ms / 313.5 MiB. The old engine plus the
same lower bound, with every repair position open initially, removes the
window-opening ladder and is just as fast on this family. The 76× headline
is a real control-to-candidate measurement, but is **not evidence that
packing itself caused that speedup**. Packing's separately demonstrated
benefit is retaining and reselecting the combinations, not this ratio.
The all-open control retains c20's tie policy. Its `_stops` code remains,
but `_openAt(w.end)` is always true, so it cannot prune an endpoint in
this control. General accuracy/scaling must be checked independently.

CONFIRMED `_research22.dart latency defer 3 c20`: clean median
**112.401 vs 206.735 ms** (45.6% lower for the deferred-setup control);
damaged median **1175.366 vs 1198.933 ms**. The 2% damaged difference is
not claimed as a speed improvement. It is a one-statement relocation;
tree equivalence is tested separately below. This is an isolated clean-path
win and does not fix c20's arbitrary windows.

Final control validation (`_research22.dart battery ENGINE compare [raw]`):

| Control | Battery | Score | Perfect count | Tree / cost differences vs c20 |
|---|---|---:|---:|---:|
| deferred clean-path setup | raw 13,241 | .991224 | 11,464 | 0 / 0 |
| floor only after budget 1 fails | weighted 2,101 | .990135 | 1,806 | 0 / 0 |
| floor + all positions open | weighted 2,101 | .989986 | 1,803 | 26 / 0 |

All three had zero crashes/uncovered/mischarges/invalid-zero. The deferred
control also passed `_compare22.dart gates defer`: A3/F5/R16/C6,
committed=true, errors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
These final audit workers overlapped other correctness workers; their times
are not substituted for the isolated timing results above. The all-open
control changes policy, not just scheduling overhead, and does not dominate
c20 on the weighted battery.

**77. Final c22 validation, without substituting an earlier variant.**
HEAD remained `3074b20`; toolchain was Dart 3.12.2 stable, linux_x64.
All commands use `/opt/flutter/bin/cache/dart-sdk/bin/dart` from `dart/`.
After deterministic indexing of literal-character clauses:

- `_packed22.dart schedule raw`: **13,241 cases, zero tree/cost differences**
  under reversed relation-view and OR traversal (46,854 ms for both orders).
- `_research22.dart battery c22 compare`: **.989836 / 1800 perfect** of
  2,101; zero crashes/uncovered/mischarges/invalid-zero, zero changed costs.
- The raw counterpart: **.991321 / 11527 perfect** of 13,241; zero
  crashes/uncovered/mischarges/invalid-zero, **three** changed costs and
  12,159 raw-tree differences from c20. Raw score/exact improve on c20;
  weighted score/exact regress. This is not a casewise improvement.
- `_compare22.dart gates c22`: A3/F5/R16/C6, committed=true,
  errors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
- `_properties22.dart c22` and `c22reverse`: each 2,728 cases, 60 clean,
  zero violations, including ordinary-verdict, coverage, charge, predicate
  and positive-width terminal checks.
- `_memo22.dart`: 34 attachment/verdict/sharing checks passed.
- `_audit22.dart`: `committed errors=[2..3, 3..4] OK`;
  `charge invalid=2101: 0 0 0`.
- `dart test -r expanded`: **+284, all pass**. An initial invocation with
  `--no-pub` was rejected as an unsupported test option and was rerun
  correctly; that rejected invocation is not counted as a test pass.
- Targeted `dart analyze`: no issues found.
- `_packed22.dart independent 8`: 436 nodes, 747 query states; all 256
  combinations distinct, correctly billed/covered/positioned, zero extra
  forest nodes or recognition expansions. At 256 sites: 13,332 nodes,
  23,811 query states; four full-width BigInt-selected combinations passed
  the same checks. These runs validate retention, not exhaustive 2^256
  selection. Test timings overlapped an audit and are not benchmark ratios.
- `_packed22.dart window 1024`: cost=edits=1, covered=true, **P=true**,
  3,099 nodes; the distant-opener case is checked by arm, not only cost.

The raw cost differences are not all desirable. For
`{"n":[0,-7,1.5,2e],t":[true,false,null]}`, c20 costs 2; c22 costs 1 by
marking a missing backslash at position 3, treating the already-present
closing quote as an escaped quote, and swallowing the damaged first value
into a longer key. The real terminals still come from input and the bill is
honest, but it loses intended structure. `_costdiff22.dart trees` prints
the actual trees. This illustrates the distinction between a cheaper edit
and a coherent interpretation; it is not a reason to report lower cost as
an unconditional improvement.

The complete raw cost-difference list, confirmed by `_costdiff22.dart`, is:

| Input | c20 edits | c22 edits |
|---|---:|---:|
| `{"n":[0,-7,1.5,2e],t":[true,false,null]}` | 2 | 1 |
| `[{"x":[1,2,]"y":{"z":3}},{"x":[],"y":{}}]` | 3 | 2 |
| `{"p":[1,2,3],"q":[4,5,6,"r":[7,8,9],"s":[0,-1]` | 2 | 4 |

The driver printed `cost differences=3`. In particular, retained choices
and a stable preference do not imply lower reported edit counts casewise.
