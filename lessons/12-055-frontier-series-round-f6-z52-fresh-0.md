<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.55 Frontier series, round F6: z52, fresh 0/0/0 from one settle condition

**Result.** z52 = vmf6e: z51 with Gemini's new settle term in `_repeat` and recheck bound 1660, Codex's inlined skip scan,
and size cuts. Beside z51: fields 12 -> 12, bookkeeping lines 35 -> 33, 456 -> 447 formatted LOC (-9, -2.0%); priceWorse
10/6, battery 0.9900/86.3, exhaustive 0 and tfam 3/30 equal; fresh inputs above z37a (g1/g3/g5 of 480) 0/0/16 -> 0/0/0 with
50 g5 inputs below z37a, held-out seed 0/2/25 -> 0/2/2; fresh time beside z51 0.95/0.99/0.77x and 0.96/1.00/0.76x.

The change in `_repeat` (z51's settle condition had only the last two terms):
```
final settle = canS && !s.clean &&
    (g < 0 && unit && r.synced(p, 0) ||
        !any && rSub && s.end > r.end + s.spent && _pureSub(s, r.end) ||
        s.evidence > 1 && (syncs(s) || !any && s.evidence > s.absorbed(r.end)));
```

| Engine | Change from z51 | Fresh f3a | Held-out f3b | Time checks | Verdict |
|---|---|---|---|---|---|
| vmf5n = z51 | | 0/0/16 | 0/2/25 | pass | base |
| vcf6g (Claude) | bound 1800, no memo clear before a mode-0 recheck | 0/0/9 | 0/2/16 | pass | superseded |
| vxf6ab (Codex) | `saved` comparison, `_next` inlined | 0/0/16 | 0/2/25 | pass | scan kept |
| vgf6 (Gemini) | settle term, bound 1660, size cuts | 0/0/0 | 0/2/2 | pass | kept |
| vmf6a | vgf6 with bound 1600 | 0/0/2 | 0/2/2 | | rejected |
| vmf6d | vmf6e without the memo clear before a mode-0 recheck | 0/0/0 | 0/2/2 | big 4/10 once, noise on rerun | open |
| **vmf6e = z52** | **vgf6 + inlined scan, `cmp` and `dep` written out** | **0/0/0** | **0/2/2** | **pass** | **chosen** |

**What taught something.**
1. The 16 losses had one cause in the code, not in the recheck's numbers. In a repetition of a one-character clause, a
   one-character substitution can never satisfy the settle condition (`s.evidence > 1` or `s.end > r.end + s.spent`), so
   the local edit count `used` grows over the whole repetition and the ladder prunes the arm that holds the cheaper
   answer. Raising the recheck bound (Claude, 1800: 0/0/9 at 1.06x) only reran the search more often. Finding the code path
   that drops the cheaper answer gave all 16 and a faster g5.
2. Fixing the first search made the recheck cheaper: g5 time fell to 0.77x z51 because the ladder now finds the answer at a
   lower budget.
3. A lower line count from joining statements, or from a derived quantity in place of a stored field's comparison, is not
   less bookkeeping; both were written out or rejected (rule 15).
4. A time failure on the `big` input `(1+` is not evidence against a change unless it survives interleaved repeats: vmf6d
   failed 4 of 10 once and matched vmf6e on three repeats.
