<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.5 Round 64: the check answers yes or no, and deep inputs are checked

Two changes.

1. When the edited string parses, z10 returns z9's tree. `_f25k.check`, which built f25's tree
   of the edited string, is replaced by `_f25k.accepts`, which only lays out the edits and
   parses. f25's tree is now built only on the fallback path (f25's search).
2. When `accepts` overflows the stack, it parses again after a sweep: for each position from
   the end of the string back to 0, it calls every rule in `_roots` there, so that the final
   top-down parse finds every deeper result in the memo. `_roots` is the set of rules that are
   not on a left-recursive cycle and cannot reach one by left calls.

Why `_roots` excludes the left-recursive rules: with mutual left recursion the library's
result at a position depends on which rule of the cycle is entered first, and the sweep enters
them in a different order. Measured with the sweep forced on every parse (dl seeds 1-4,
1,600 cases):

| Sweep roots | effect |
|---|---|
| every rule | 1 invalid tree (seed 1, mutual left recursion) |
| rules not on a cycle | the same invalid tree |
| `_roots` | no invalid tree, but 1 cost change (seed 3) |

The seed-3 change is in f25's search, not in the check: the forced sweep was in `_parse`,
which the search also uses, and the search reads `_touched` and `_ext`, which the sweep fills
(`bbba` on a grammar with no left recursion: cost 5 -> 6). The sweep was then moved into
`accepts` only, and a test copy ran both the sweep and the plain parse on every check and
compared the two answers: 0 differences on dl and lf seeds 1-16 (12,800 cases, about 400
checks per seed; a control print showed both accepts and rejects being compared).

The trees change. z9's tree and f25's tree carry the same edits but differ in two ways:
in the one case read (`[,[2,[3,[4]]],5]`), z9 puts the deleted `,` inside the inner array,
where f25 (the library's tree of the edited string) puts it one level out; and z9 labels an
empty match at the end of the input with no clause. The battery scores both trees the same.
Removing only the label difference drops the score to 0.9671 / 75.4% with 483 trees still
different, so the two differences cannot be separated (inferred: the scorer reads the
unlabeled node; not traced).

| Measure | z10 round 63 | z10 round 64 |
|---|---|---|
| battery | 0.9904 / 86.6% | 0.9904 / 86.6%, costDiff 0, treeDiff 1,887 of 2,101 |
| gates | pass | pass (same freespan, recommit, conformance) |
| dl / lf seeds 1-16 | 0 invalid | 0 invalid, every cost equal |
| rungs 8/16/32/64, AOT, ms (one build) | 243 / 225 / 303 / 345 | 193 / 192 / 267 / 285 |
| rung 64 peak RSS | 160 MB | 139 MB |
| battery, AOT | 2,593 / 2,582 ms | 2,539 / 2,529 ms |
| nesting 3,200, one `]` missing | 241 ms, unchecked | 245 ms, checked |
| nesting 25,600, one `]` missing | unchecked | 2,051 ms, checked |
| mutual left recursion (below), depth 25,600, one `)` missing | | 1,424 ms, checked |
| x(ax)*1600 b / x(ab)*1600 | 99 / 77 ms | 102 / 77 ms, both checked |
| LOC z10 + `_f25k` | 392 + 727 = 1,119 | 392 + 729 = 1,121 (+2, +0.2%) |

The mutual left recursion grammar is `S <- E; E <- F '+' T / T; F <- E; T <- '(' E ')' / 'n';`.
The fuzzers count `worse` against the best engine in the run; both rounds give the same costs,
so neither is worse than the other.
