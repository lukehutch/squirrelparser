<!-- Part of LESSONS_LEARNED.md, section: 8. The c7→c8 rename map -->
[Back to the index](../LESSONS_LEARNED.md)

## 8. The c7→c8 rename map

c8 is c7 with every invented identifier renamed for a reader without this
file's history, and every mechanism documented in the source in plain
language. Original squirrel-parser names (Clause, Match, Seq, First, Ref,
`match`, `inRecPath`, `foundLeftRec`, `memoVersion`, …) were kept or
mirrored. The logic is expression-for-expression identical.

c9 keeps c8's names unchanged, so this map reads onto it directly; the
c9-only additions (`_best`, `_view`, `_maxSpent`, `plain`, `asList`,
`wrapped`, `owner`, `refSrc`/`refView`, `finish`) are documented where
they live in `c9.dart`. c10 keeps the same names again (its additions —
`zeroTwin`, `_zeroFiber`, `_greedyOnly`, the fiber-split version
clocks — are documented where they live in `c10.dart`). c12 keeps them
once more, and adds `Terminal.picky`, `_readSlots`, `_resumes`,
`preferred` and `spent`, each documented at its definition; c13 keeps
c12's names unchanged (its one addition is a local boolean).

**Classes**

| c7 | c8 | meaning |
|---|---|---|
| `_Way` | `_Reading` | one candidate way of reading a span, with its repair bill |
| `_Cap` | `_Labeled` | a construct's name wrapped around its children |
| `_Front` | `_RepairCell` | best reading per end position at one (node, position) |
| `_PCell` | `_ParseCell` | plain-parse memo entry (tree + left-recursion state) |
| `_N` | `_Node` | grammar node base class |
| `_Comp` | `_MemoNode` | a node whose repair results are memoized |
| `_Seq` | `_Sequence` | sequence |
| `_First` | `_Choice` | ordered choice (`/`) |
| `_Rep` | `_Repeat` | repetition (`*`/`+`) |
| `_Opt` | `_Maybe` | optional (`?`) |
| `_Look` | `_Lookahead` | `&X` / `!X` |
| `_Ref` | `_RuleRef` | reference to a named rule |
| `_Term` | `_Leaf` | terminal base class |
| `_StrN` | `_Literal` | multi-character literal |
| `_CharN` | `_OneChar` | single exact character |
| `_SetN` | `_CharClass` | character class, possibly negated |
| `_AnyN` | `_Wildcard` | `.` |
| `_NothingN` | `_Empty` | matches the empty string |

**`_Way`/`_Reading` fields and methods**

| c7 | c8 | meaning |
|---|---|---|
| `del` | `deleted` | input characters skipped as noise |
| `gap` | `missing` | required pieces absent before end of input |
| `oweN` | `missingAtEnd` | required pieces absent at the cut-off |
| `net` | `evidence` | characters matched by picky matchers |
| `key` | `firstDoubt` | position of the first repair, or a clean sentinel |
| `fees` | `penalties` | tie-losing charges that are not edits |
| `owing` | `endsIncomplete` | something required is missing exactly at `end` |
| `what` | `piece` | what this step contributes to the tree |
| `tail` | `prev` | the reading up to the previous step |
| `edits` | `cost` | total bill (end-of-input charged once) |
| `spend` | `spent` | the budget-counted part of the bill |
| `peg` | `preferred` | the plain parser's own choice |
| `free` | `clean` | no repairs at all |
| `ate()` | `absorbPenalty()` | +1 for absorbing more than it proved |
| `_Way.unit` | `_Reading.empty` | a reading of nothing |
| `_Way.skip` | `_Reading.deleting` | delete a span as noise |
| `over()` | `withTree()` | carry a finished tree as the piece |
| `capped()` | `labeled()` | wrap under a construct's name |
| `fee()` | `penalized()` | one more penalty point |

**Cells, node methods, engine**

| c7 | c8 | meaning |
|---|---|---|
| `_by` | `_bestByEnd` | the champion map |
| `at` | `atBudget` | budget the cell was computed at |
| `ver` | `memoVersion` | position-version stamp (mirrors the library) |
| `dep` | `usedSeed` | computation read a growing seed |
| `inPath`/`foundLR` | `inRecPath`/`foundLeftRec` | mirrors the library's MemoEntry |
| `res`/`way`/`has` | `tree`/`reading`/`computed` | parse cell contents |
| `ways()` | `readings()` | a cell's/node's candidate readings |
| `go` | `findReadings` | per-kind implementation behind `readings` |
| `freeze` | `cleanReading` | the plain parse as one reading |
| `peek` | `cellAt` | the repair cell if it exists (never allocates) |
| `det`/`detGo` | `hasOneShape`/`computeOneShape` | only one tree shape possible |
| `fill`/`fillGo` | `minChars`/`computeMinChars` | fewest characters a match consumes |
| `pin` | `picky` | terminal accepts only specific characters |
| `owe` | `recordMissing` | the "it was missing" reading |
| `expand` | `proposeReadings` | one candidate-generation pass |
| `seedAt` | `isGrowingAt` | back-edge into a growing cell |
| `row` | `cells` | the per-position cell array |
| `pure` | `parseCell` | the rule's plain-parse memo entry |
| `grow` | `_grow` | the repair fixed-point loop |
| `fold` | `_readSlots` | the slot-by-slot sequencing engine |
| `_rank` | `_compare` | the five-key reading comparison |
| `_prune` | `_bestPerEnd` | keep the best reading per end |
| `_netOf` | `_evidenceIn` | evidence in a finished tree |
| `_node`/`_build` | `_treeOf`/`_buildTree` | winner-only tree construction |
| `_conv` | `_convert` | library clauses → engine nodes |
| `_in`/`_n` | `_input`/`_len` | the input and its length |
| `_run` | `_runId` | per-input generation stamp |
| `_pver`/`_rver` | `_parseVersions`/`_repairVersions` | the two version arrays |
| `_sawSeed` | `_seedWasRead` | the upward involved-set signal |
| `_fill` | `_minDocLen` | shortest accepted document (search bound) |
| `_far`/`_peg` | `_clean`/`_chosen` | the two firstDoubt sentinels |
| `_never` | `_impossible` | minChars for "cannot match" |
| `lit:` | `insideLiteral:` | `_readSlots` flag for the replace repair |
