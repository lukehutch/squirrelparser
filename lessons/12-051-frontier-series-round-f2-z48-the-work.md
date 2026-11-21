<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.51 Frontier series, round F2: z48, the work counter and the dependency sign gone, fuzzer gap halved again, fresh inputs worse

**Result.** z48 = vmf2a: Gemini's vgf2 (no `_work`; staging by the budget cap; a fixed recheck at `2 < cost <= 9`), Codex's
class substitutions and shorter `_total`/`_acyclic`, and the sign of `dep` removed. Beside z47: fields 15 -> 13 (way 3, cell 4,
engine 6, counting packed parts and map key kinds), bookkeeping lines 37 -> 35, 497 -> 460 formatted LOC (-37, -7.4%),
priceWorse 21/13 -> 11/10, exhaustive 0, battery 0.9896/85.1 -> 0.9898/86.0, every hard check. Time beside vm13b: semi3 0.94,
long sets 0.54, Dyck 0.66, battery 0.78, dense k=32 730 against 788 ms.

| Engine | priceWorse | Battery | Fresh g1/g3/g5 above z37a (of 480) | Other | Verdict |
|---|---|---|---|---|---|
| z47 (vmf1d) | 21/13 | 0.9896/85.1 | 0/0/92 | | base |
| vgf2 | 13/10 | 0.9896/85.1 | | 463 floc | in bands |
| vxf2core | 11/10 | 0.9898/86.0 | | 484 floc | in bands |
| vcf2 | 17/11 | 0.9898/86.0 | 3/50/108 | semi3 1.34x | outside the band |
| vgf2b | 15/7 | 0.9898/85.3 | | big fails 4/10 | rejected |
| vmf2b | | | 0/0/0 | dense k=8 59 s, big fails 7/10 | refuted |
| vmf2e | 11/8 | 0.9898/85.9 | 3/50/108 | la 1 above vm13b | not chosen |
| vmf2f | 14/7 | 0.9900/86.3 | 2/50/113 | big fails 4/10 | rejected |
| **vmf2a = z48** | **11/10** | **0.9898/86.0** | 3/50/108 | every band | **chosen** |

**What taught something.**
1. The kit does not see the cost of removing the work-limited recheck. On fresh inputs (seed 20261102, 480 per grammar) z48 is
   above z37a on 3/50/108 against z47's 0/0/92; the losses lie at costs 10 to 42, outside the fixed recheck range, so no small
   constant fixes them. A bound that rises with the ladder (vmf2b) restores 0/0/0 but is 4-6x slower on fresh inputs and blows
   up on dense input. The open trade-off: one engine field (a work limit, as in z47) against fresh accuracy.
2. The library's `memoVersion` is not a substitute for the engine's position stamp: vcf2 does 2.6x the plain evaluations of
   vgf2 (50,872 against 19,302), the cause of its semi3 1.34x.
3. Keeping `_Cell.ends` in discovery order (a linear scan in `add`) gains fuzzer accuracy but makes `T 1+)` at k=16384 take
   10 s against 0.67 s (vgf2b, vmf2f).
4. Kit defect: `big.sh` wrote its log through an unquoted path, so runs in parallel overwrote each other and reported false
   "no answer" failures. Fixed by quoting.
