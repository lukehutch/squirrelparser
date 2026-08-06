# Brief: m81 is correct and small but 3.9x too slow

## The one question

`dart/experiments/recovery/m81.dart` is a standalone PEG parser + error-recovery
engine, 471 LOC. It must get **4x faster without losing answers**. Everything
else about it is already where it needs to be.

| engine | LOC | battery latency | notes |
|---|---|---|---|
| m78 (the engine to beat) | 1296 | **229.3 ms** | previous best |
| m80 | 440 | 1964 ms | m81's immediate parent |
| **m81 (current)** | **471** | **~890 ms** | 2.75x smaller than m78, 3.9x slower |

The target is **<= 229.3 ms** on the same battery under the same protocol, with
the cost sum still 975, the six acceptance cases still exact, and LOC still far
below 1296. LOC may grow somewhat if that is what buys the speed; it must not
approach m78's.

## How to reproduce every number here

```
cd dart/experiments/recovery
dart run _ab81.dart      # m80 vs m81: shape, coverage, cost sum, ms; 2 passes each
dart run _abl81.dart     # ablations: baseline / -tree nodes / -FILL / -deepening
dart run _idist.dart     # instrumented counters: cells, ways, memo hits, by clause type
dart run _lr81.dart      # left recursion must not hang
dart run _a81.dart       # the AST-diff quality evaluator (705 weighted cases)
```

The **official protocol** is one engine built once and reused across all 519
mutants in a cold isolate with a single Stopwatch and no warmup — that is what
`_ab81.dart` and `final_table.dart` do, and the 229.3 ms for m78 was measured
that way. `_abl81.dart` builds a fresh engine per mutant, which reads ~20%
higher; compare ablations only against that harness's own baseline. Run-to-run
noise is about +/-5%, so anything under ~8% needs repeat runs to call.

## What the algorithm is

A repair is a claim about the **tree**, never an edit to the input. The input
string is never modified. Two repair moves:

- `SKIP(pos, k)` -> a `SyntaxError` span node covering k characters
- `FILL(clause, pos)` -> a zero-width `Filled` node, legal only when the clause
  has a **unique minimal witness** (choice-free), so nothing is invented that
  could have been something else

Cost = characters skipped + characters filled. The engine finds a minimum-cost
whole-input reading by iterative deepening on that cost.

The central data structure (I38): every clause at every position answers with
**all end positions it can reach**, each with the cheapest way of reaching it.
As of m81 (I47) that answer is a **cons list threaded through the ways
themselves**, not a `Map<int,int>` — measured, a cell holds 1.08 endings, 47.1%
hold none and 41.0% hold exactly one.

```dart
class _Way {
  final int end;        // the position this way reaches
  final int cost;       // SKIP chars + FILL chars; 0 means pure PEG
  final int got;        // characters matched
  final int net;        // characters matched by a terminal THAT CONSTRAINS
  final bool synth;     // does this way OPEN with a repair?
  final _N? nodes;      // promised tree, built only for the winner
  final _Way? next;     // the next ENDING in the same answer
}
typedef _Ways = _Way?;
```

Three memo tables, all `Map<Clause, List<_Cell?>>`:
- `_pc` — the budget-0 answer (exactly the frozen parser's). Budget-independent,
  so solved once per input and shared by every deepening round.
- `_mc` — this round's answer, no leading repair allowed.
- `_me` — this round's answer WITH a leading repair allowed (`_repair`).

`_mc`/`_me` are cleared when the budget changes; `_pc` is not.

PEG conformance is maintained by making round 0 (`_budget == 0`) *exactly* the
frozen parser: `_first` takes the first alternative with a pure reading, `_opt`
prefers a pure body, repetitions collapse possessively, and `_repair` commits to
a pure match when one exists.

## Where the time goes — measured, not guessed

Per mutant, from `_idist.dart`:

```
rounds 2.62/mutant
_fix calls    18,810/mutant   (49.5% are memo hits)
cell bodies    9,454/mutant   -> ~185 ns each
ways returned   1.09 per cell body
_wrap allocs   5,837/mutant
_seq extends   5,285/mutant
SKIP ways      1,516/mutant
FILL ways        605/mutant

cell bodies by clause type:
  Ref 35.6%   Char 20.4%   Seq 14.7%   CharSet 8.2%   First 6.6%
  Optional 5.3%   ZeroOrMore 5.2%   Str 3.4%   OneOrMore 0.7%

cell bodies at a (clause,pos) the FROZEN parse never asked about: 0.0%
```

That last line matters: the repair search is **not** wandering into positions
the ordinary parse never visits. It is re-asking the same cells with a budget.

Ablations (against `_abl81.dart`'s own 1096 ms baseline):

| mechanism removed | ms | share | cost sum |
|---|---|---|---|
| baseline | 1096 | — | 975 |
| tree node construction | 926 | 15% | 975 |
| **FILL** | **413** | **62%** | 1404 (quality collapses) |
| deepening (start at the oracle budget) | 780 | 29% | 975 |

So FILL is the dominant cost and is also load-bearing for quality.

## Already tried — do NOT retry these

Each was measured, and each is recorded because the reasoning behind it was
plausible and wrong.

| change | result | verdict |
|---|---|---|
| `Map<int,_Way>` -> cons list | 1964 -> 928 ms | **KEPT** (this is m81) |
| judge an extension from 3 ints before allocating its node list | 5% | **KEPT** |
| stop memoizing terminals (32% of all cell bodies) | 2%, not 32% | KEPT, but tiny |
| collapse `Ref` into its body (35.6% of cell bodies, looks like a pure alias) | 907 -> 1351 ms, **1.49x WORSE** | REVERTED |
| drop the `_me` element memo table | 955 -> 1033 ms | REJECTED — it is a pure cache and earns its keep |
| keep one way per cell instead of all endings | **3x slower** (2764 ms), cost sum 16044 vs 975 | REJECTED — all-endings is what makes the search converge |
| deepening step-by-one instead of doubling | 1049 vs 895 ms | REJECTED |
| deepening step to 4 then double | 880 vs 895 ms | within noise, not worth the line |
| recursive single-SKIP instead of a k-loop (tried on m80) | 3139 -> 4010 ms | REJECTED |
| forbid a wholly-invented rule node (tried on m80) | 2534 -> 2695 ms, shape unchanged | REJECTED |
| allow SKIP where the pure parse SUCCEEDS | shape 345->360 but 3166 -> 5718 ms | off while latency binds |

## Hard constraints — a proposal that breaks one of these is not usable

1. **Never start a second parse or a second parser instance.** Repair updates
   the current memo table in place.
2. **The input is never modified.** No repaired string is ever constructed.
   Repairs appear in the tree as `SyntaxError` spans and zero-width `Filled`
   nodes.
3. **No arbitrary heuristics, no tuning constants.** Every decision must follow
   from a stated principle. A magic threshold is not acceptable even if fast.
4. **Never invent a terminal that could have been something else.** FILL is
   legal only where the witness is unique. Structural tokens (a brace, a
   bracket, a delimiter) may be filled; a value may not.
5. **`dart/lib` is frozen.** Each engine file is standalone: it carries its own
   copy of the parser and memo table. No `Clause` subclass can gain a field.
   `Clause` has no `==`/`hashCode` override, so `Map<Clause,...>` is identity-
   hashed.
6. **Round 0 must remain exactly the frozen parser**, so undamaged input pays
   nothing for a search it does not need, and PEG semantics are preserved
   (ordered choice commits, repetition is possessive).
7. **Left recursion must work.** `Expr <- Expr WS AddOp WS Term / Term` must not
   hang. The rule: the frozen parser keeps a re-derived left-recursive result
   only while it is strictly longer, so the seed is monotone; lifted to a map of
   endings, monotone means MERGE, not replace. Replacing lets a cell shrink and
   the growth test then fires forever.

## The six acceptance cases — all must stay byte-identical

```
"[2,33,true]"  cost 0  [2,33,true]
"[2,33true]"   cost 1  [2,33<,>true]      -- FILL a comma, not "delete 33"
"[,2,]"        cost 2  [<,>2<,>]
"[,2,3]"       cost 1  [<,>2,3]
"[2,,3]"       cost 1  [2,<,>3]
"[,2,"         cost 3  [<,>2<]><,>        -- FILL the bracket; never invent a 0
```

`< >` is a FILL, `« »` a SKIP. The design rule behind cases 2 and 6: inventing a
character that *could have been anything* (a `0` to complete a list) is
forbidden; inventing a structural closer that is forced by the grammar is
allowed, and deleting a stray leading comma beats inventing a value.

## Quality must not regress

`_a81.dart` scores 705 weighted cases across three grammars and ten damage
categories weighted by how much a human would care. m81 currently scores
**AGGREGATE 0.7608, perfect 52.1%, crashed 0, uncovered 0**. Any speedup that
moves this materially is not a speedup.

## What would actually help

Ideas that attack **cell count** or **per-cell cost**, given that:
- the memo is already near-perfect (hit rate 49.5%, and nearly every miss is a
  genuinely distinct cell),
- the search does not visit off-path positions at all,
- FILL is 62% of the time but is required for quality,
- carrying all endings per cell is what makes the search converge, and
- deepening overhead is only 29%, so even a perfect budget oracle leaves 3x.

Read `m81.dart` end to end before proposing. Concrete, measurable proposals with
a predicted mechanism are worth far more than general advice; every prediction
in the table above that was made without measuring turned out wrong.
