<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.60 Neon round N3: z57, a simpler dominance test in the cell

**Result.** z57 = vgn3, Gemini's round-N3 engine (model gemini-4-neon-xhigh), taken unchanged. Beside z56: `_Cell.add`
decides between two ways with the same `owed` and the same boundary position by `cmp` alone, without the `edits <=` and
`used <=` coverage test; the cycle depth of a `First` counts the arms before a cut; `_repeat` makes one `_read` instead of
two; and the form is shorter (no `peg.` prefix, a result typedef, a `_rule` helper). Fields 8 -> 8, bookkeeping lines
(bkl.sh) 18 -> 17, 508 -> 490 formatted LOC (-18, -3.5%); battery 0.9902/86.4 equal, group4 semi4 #3 10 -> 8,
priceWorse 0/0 -> 0/1 (one plfs4 case, 5 against the optimum 2), pdls4 worse 121 -> 122, every other accuracy row equal;
fresh f3a and held-out equal; LR fuzzer 0 worse of 2,300; long-token k=64 1.09x z56; Dyck 0.82x z56 on three
interleaved repeats.

| Engine | Change from z56 | Fields | bkl | floc | Answers vs z56 | Verdict |
|---|---|---|---|---|---|---|
| **vgn3 = z57** | **dominance by `cmp`, First cut depth, one `_read` in `_repeat`, shorter form** | **8** | **17** | **490** | **priceWorse 0/1, group4 #3 10 -> 8** | **chosen** |
| vgn3b | vgn3 keeping the coverage test | 8 | 18 | 491 | priceWorse 0/0, group4 #3 10 -> 8 | runner-up |
| vgn3a1 | no `mark` | 7 | 14 | 517 | equal or better | rejected: budget refills, 6-40x on dense inputs |
| vgn3i / vgn3j2 | no `_mins` | 7 | 18 | 524 | group4 cbc grouping-dependent / Theta(k^2) | rejected |
| vgn3n12 | `_cells.remove` for `mark = -1` | 8 | 16 | | priceWorse 0/1 | rejected: cbc k=8 17-116x slower |

**What taught something.**
1. A coverage test over two way fields (`edits <= && used <=`) was kept to protect one fuzzer case in 6,400; the
   ranking puts one bookkeeping line above that record row, and the price of dropping it was measured, not assumed.
2. Each of the four remaining engine and cell fields (`mark`, `_mins`, the `(c, p)` key kind) now has a measured
   input family on which removing it is slower by a factor that grows with the input: `mark` on dense LR, `_mins` on
   `"1x"*k+"1"`, the key kind on long tokens. A field removal must name and pass the family that made it necessary.
3. On xhigh effort Gemini submitted an engine inside every band for the first time in the series, and reported its
   7-field engines as trade-off points rather than as the result.
