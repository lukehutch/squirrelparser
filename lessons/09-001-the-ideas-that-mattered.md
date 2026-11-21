<!-- Part of LESSONS_LEARNED.md, section: 9. The breakthroughs, distilled (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 9.1 The ideas that mattered

**Search: what made many errors and long inputs finish**

| Idea | Engine, era | What it bought | How it was found | Why it worked (inferred unless marked) |
|---|---|---|---|---|
| Budget 0 is the parser; the budget ladder is the search horizon (I101) | c-line, A | deleting the ladder cost ~100x latency, twice | two failed attempts to delete it | most documents need few edits; a rung only explores readings costing at most its budget |
| Each child gets only the budget that is left | c14, A | growth n^3.5 to about linear at fixed budget | profiling: the sweep asked every step at the whole budget | a reading that has spent its budget cannot afford more alternatives, so they are never built |
| The left-recursion grow loop is the recovery loop (I100) | c-line, A | one fixed-point loop serves both | unifying two loops that did the same thing | both iterate until the memo stops changing |
| Stop prune: keep only the stops the input dictated | c20, B | front insertions 7.89M to 2.79M, 100k input 5.2 to 2.8 s, trees bit-identical | counting where front insertions came from, not making each one cheaper | PEG repetition is greedy, so a continuation never starts at an interior item end on clean text |
| Cost scales with the number of repairs, not length (diagnosis) | c20/c21, B | redirected all scaling work to lower bounds | 1000/4 0.44 s, 1000/8 10.2 s, 1000/12 unfinished; five local prunes refuted | the front carries whole-document totals, so ways to split them multiply per error |
| An admissible floor prunes inside each rung | c25, B | 12 errors: unfinished to 1.7 s; 16 errors 4.1 s | floor used only to pick the starting rung gained nothing (recorded) | it kills exactly the bills that cannot finish within budget, before they enter the front |
| Bound remembers the last return site | cdx10, B | 32 errors 39.8 to 3.2 s; 64 errors finish in 3 s; -1.5% lines; same trees | `_boundstat8` showed every deleted bracket is free to a regular bound | bracket balance is not regular; one remembered call site captures nearly all of it, and the automaton stays finite |
| Semi-naive growth sorted by end | cl12, C | left recursion 8,192 terms 44 s to 316 ms; with an error, linear | re-derivation count in the grow loop | each round extends only the readings that changed |
| Diverse retry | cl13, C | no-repair failures 10 to 0 | fuzzer cases with no answer | a retry keyed apart finds the reading the first pass evicted |
| Shared gap scan, position worklist, gallop/bisect over budget, bound bought after counted work | cl14, C | all 46 families finish | the family table | answers are monotone in budget, so a ladder can bisect; buying the bound late keeps one-error inputs cheap |
| Explicit stack, then frames | cl21/cl22, D | depth 400 to 1,600 at cl20's speed | stack overflow on nested input | Dart has no stack-size flag |
| Sharing: one derivative automaton, GSS continuations, classes | pd46, D | 18.5 to 2.0 s battery | profiling pd23 | the same continuation was rebuilt per reading |
| Two-part bound with return-site rows | u21, D | 6-12 error rungs over 300 s to 1.5 s | cdx10's bound moved into the derivative search | same reason as cdx10 |
| Gain-measured offers with a partial re-parse | sk4/sk6, E | 64/1 rung 14,781 to 415 | taking the first matching skip was too greedy | "reads farthest for least" stands in for the rest of the document's cost; re-parsing only what read to the offer makes measuring cheap |
| First-gain bound w1 | sk8f..x504i, E | many-error rungs finish | deleting it: 64/1 unfinished in 18 minutes (D50-2) | it caps the deletion length; it is not admissible (`'b'+` costs 4 vs 2) |
| Exact skip bounds | x482o, E | battery Ir -49%, same trees | reading which offers could never win | the test `n+1-p <= b.r-b.c` is a proof, not a guess |
| Credit settlement: the budget limits unconfirmed edits only | z-line, F | k errors cost a sum, not a product; 64 errors in 470 ms | z2's design | once a later stretch of input confirms an edit, the edit no longer limits the search |
| Cut obligations | z-line, F | O(n^3) to linear on its family | profiling | a cut means nothing before it can change |
| Bottom-up sweep on stack overflow; depth-scoped left-recursion marks | x471j, z-line, E/F | nesting 705 to 3,200, same trees | Dart has no stack-size flag | filling the deepest entries first makes the retry shallow |
| Window over the latest failure | c17/c18, e14, A/F | 200k characters in 5 s (c18) | memory profiles | most errors are local; c21's counterexample shows this is a heuristic |
| Deferred clean-path setup | c25, B | clean latency -45.6%, zero tree changes | reading the clean path | a clean document never needs recovery state |

**Validity and robustness: trees that parse their own repaired string**

| Idea | Engine, era | What it bought | How it was found | Why it worked |
|---|---|---|---|---|
| Every failure a tree relies on must still hold on the repaired string | cdx11l/r, C | invalid 26/21 to 6/7/6/17 | fuzzer witnesses | a PEG choice or lookahead decided on the original text can decide differently on the repaired text |
| Write insertions into the tree; match literals one character at a time | sk7q, E | fuzzer invalid 1,543 to 159 | the invalid count was meaningless until the tree held the inserted text | the tree becomes a parse of a repaired string, so it can be checked |
| One-letter substitution only | cl-line, C | keeps the bound admissible | a whole-literal substitution undercut the bound | a substitution of a literal is several letter edits |
| An iteration that adds no character is not an iteration | cl24, D | strict invalid 68 to 50 | `_samedw` witnesses | an empty iteration lets a repetition read text PEG would not |
| Offer a deletion unless a clean reading advances | cdx9m, B | 51 costs lower, none higher; fuzzer worse 10 to 1 | one-line reading of `_seq` | an empty match is not evidence that the slot read the input |
| mustAdvance; ordered-choice nullability | z-line, F | closes the empty-literal loop class | fuzzer | same as above, at the repetition |
| Derivative search: accept only what PEG accepts | pd23, D | 0 invalid, 0 worse | design | the search state is a PEG derivative, so every accepted string is in the language by construction |
| Search over repaired strings, tree read from the search | e7s/e8, F | 0 invalid in 12,800 cases; worse 55/47/51/35 vs z7's 90/98/96/95 | design, after z-line validity guards kept leaking | the same construction as pd23, in the memo parser |
| Exhaustive fuzzer with a minimum-cost witness | cdx1 round, B | made invalid and costlier-than-minimum answers visible | the battery could not see them | a finite exhaustive check on small grammars is a proof for those grammars |
| Fuzzer witness tightened (`_samedq`, `_samedw`) | rounds 5 and 19, C/D | 312-370 of 400 cases had been skipped; true invalid 68, not 50 | auditing the checker | a check that skips cases reports success |

**Judgment: which of several equal repairs to keep**

| Idea | Engine, era | What it bought | How it was found | Why it worked |
|---|---|---|---|---|
| Judge whole documents simultaneously | c1, A | greedy commit's ceiling is 0.8826 (b2); c-line reaches 0.990 | the b-line plateau | the right choice depends on repairs not yet made |
| Five-key rank, latest rival wins ties | c-line, A | the tie rule alone is worth 2.4 points of perfect (c20) | ablation | a later reading has seen more of the input |
| About 0.48 of the score is judgment, not search | c13b, A | scalar minimum-cost DP scores 0.5110 | probe | many readings have the same cost |
| 83% of x464a's gap to z8 is equal-cost tie choice | x464a audit, E | named where the x-line loses | per-case score diff | x464a has no ranking keys, only first found |
| Penalty becomes the `avoidable` tie-break after cost | cl8, C | eleven rules deleted, 802 to 712 LOC, same score | deleting rules one at a time | a penalty that only breaks ties does not need its own price |
| `_wins`: compare offers by the fixes that follow them | sk9y6, E | 0.9647 to 0.9802; without it 0.9728 | measuring greedy failures | a bounded lookahead prices the repairs a fix forces later |
| Delete the cyclic key | cl16, C | the ranking became transitive | inconsistent orders in the fuzzer | a non-transitive order makes results depend on arrival order |
| Order-independent tie-breaking by grammar identity | c22, B | zero differences with traversal reversed | reversing traversal | ties no longer depend on exploration order |

**Size and elegance**

| Idea | Engine, era | What it bought | How it was found | Why it worked |
|---|---|---|---|---|
| One fix kind (s, j): the Aho-Peterson covering grammar | sk3 to x445zzo, E | 0.45 to 0.91; 531 to 297 lines | sk7's terminology correction | skipping an element is inserting its shortest text; one loop serves deletion, insertion, substitution, closing |
| Repair is the ordinary memo parser with fixes in force | x464a, E | 306 lines at 0.9811; left recursion and memo from the library | sk2's skeleton kept through every sk round | the memo table is the search state; there is no recovery data structure |
| The recovery cell lives on the library MemoEntry (D1) | z-line, F | no duplicate parse; checks read the memo | the user's ruling | one table, one parse |
| Derive, don't account | c5/c6, A | -104 LOC | counters that duplicated what a walk could read | a value read from the tree cannot disagree with it |
| Window edge is a count of marks | c20, B | 886 to 742 LOC (-16.3%); two rungs that never finished now finish | noticing the stack walk computed one position | the repetition already knows when it finishes an occurrence |
| Fold heads that always move together | c20 lesson 64, B | three of eight heads deleted; score up | ablation | a false incomparability blocks real domination |
| True field elimination, no bit-packing | z8, F | 716 to 500 LOC | packing caused overflow defects | fewer fields, not denser fields |
| Data layout: flat records, arrays per rule body | x464a, E | battery Ir 2.16x lower, same trees | a nested record match cost 15.8G of 51.9G Ir | Dart's pattern match on nested records calls a runtime type test |

**Method**

| Idea | Era | What it bought |
|---|---|---|
| Gates for what the battery cannot see: `_conf1`, `_freespan`, `_recommit`, b2 | A | 31 engines were found to lie about cost (`_conf1`) |
| Measure the shape first (I93, I115) | A | re-derivation was only 29%, which refuted the planned semi-naive chart for c-line latency |
| Ablate every part; check held-out seeds | C, F | sealed sharing worth 19x (cdx11o); z6's validity gain was partly fitted (invalid +31% on unseen seeds) |
| Compare whole trees with `compare`, not the scored dump | B | c18 "same as c17" was 146 different trees |
| Time with AOT; name the rung as generator arguments | B, C | JIT hid gaps; "150k seed 7" could not be reproduced |
| Keep an independent comparator (cdx1) | C | caught answers the cl-line's own checks could not |
