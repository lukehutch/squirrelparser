<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.8 Round 66: f25's search without its ranking walk (adopted)

`_f25k.dart` changes three ways; `_z10.dart` is unchanged.

1. The ranking walk `_keys`/`_score` is deleted, with its fields (`_Node.ev`, `_Node.encl`,
   `_T.ev`) and the prune `bound(x) > bestEv` that used it. Finished repairs of one cost are
   ordered by `_cmp`: fewer edits, then edits as late as possible, then insert before
   substitute before delete. "Fewer edits" is needed because characters appended at the end
   count as one edit in the search's cost: without it the search took two appended
   characters over one substitution (dl worse 6, lf worse 2 against z10).
2. The cap `evals < 400000` is deleted (an arbitrary constant). No run below reaches it.
3. `_parse` itself sweeps the memo from the end back when the stack overflows (round 64 put
   this in `accepts` only). A parse that does not overflow is unchanged, so no answer on
   the battery or the fuzzers changes.

| Measure | z10 (round 64) | z10 (round 66) |
|---|---|---|
| `_f25k.dart` LOC | 729 | 666 (-63, -8.6%) |
| battery | 0.9904 / 86.6%, 2,526 ms | same trees (treeDiff 0), 2,646 ms |
| gates | pass | pass, same numbers |
| dl seeds 1-16: worse / levWorse / invalid, each against the other | 4 / 4 / 0 | 0 / 0 / 0 |
| lf seeds 1-16: worse / levWorse / invalid, each against the other | 2 / 2 / 0 | 0 / 0 / 0 |
| rungs 8/16/32/64, ms | 207 / 197 / 268 / 279 | 230 / 200 / 290 / 321 (one run each) |
| deep.sh | all finish | same costs, same times |
| `E <- '(' E ')' / 'c'? 'c' 'a'?` on `(`*n `bc` `)`*n | search overflows from n = 1,600, z9's invalid tree returned | search finishes at n = 1,600; overflows at 3,200 in `_build` |

The ranking walk was the deepest recursion in the fallback. The walks still recursive are
`_build` and `_tree`'s `walk`, both as deep as the tree.
