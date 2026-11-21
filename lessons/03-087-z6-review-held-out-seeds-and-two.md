<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### z6 review: held-out seeds and two defects (2026-10-23)

**Held-out fuzzer seeds.** The z-line guards were tuned on seeds 1-8.
Seeds 9-16 (8 x 400 cases each, one run of six engines; worse is
against the cheapest of the six):

| Engine | dl worse 1-8 / 9-16 | dl invalid 1-8 / 9-16 | lf worse 9-16 | lf invalid 9-16 |
|---|---|---|---|---|
| z6 | 78 / 101 | 35 / 46 | 106 | 44 |
| z4 | 100 / 110 | 60 / 60 | 111 | 48 |
| x513j | 166 / 160 | 22 / 25 | 160 | 43 |
| cl28 | 185 / 186 | 46 / 40 | 240 | 44 |
| cdx10 | 768 / 739 | 282 / 237 | 745 | 205 |
| c14 | 846 / 830 | 371 / 339 | 703 | 221 |

z6 keeps the fewest worse costs on unseen seeds. Its invalid trees rise
from 35 to 46 (+31%), against 22 to 25 for x513j, so part of z5's
validity gain was fitted to seeds 1-8.

**Defect 1: `owed` overflows (z5, z6).** `owed` has 8 bits in the packed
`edits` int. With `S <- 'x' A; A <-` n letters `'b'` on input `x`, z6
returns cost 1 at n = 257 and 44 at n = 300 (true cost 257 and 300; z4,
x513j and c14 return them). `fee` (10 bits), `credit` (15 bits) and the
First arm index (7 bits) have the same kind of limit; a 129-arm left
recursive First did not trigger the arm limit. Fix: separate fields, or
check the limits.

**Defect 2: left recursion followed by an error (z5, z6).** Grammar
`S <- E ';'; E <- "k0" / "k1" / E '+' "k1"`, input `k1+k1+k1+;`. The
cost-1 repair deletes the last `+` (c14 finds it). z6 returns cost 4: it
deletes `k1+` at the start and grows E only once. With `E <- "k0" / E
'+' "k1"` the best is cost 2 (c14, z4, cdx10); z6 and x513j return 8.
Removing any one of the twelve guards in the z5 ablation does not change
this, so the cause is in z5's core changes to left-recursion growth; z4
gets the one-arm case right. Neither fuzzer generates this case.
Probes: kit `_bits.dart`, `_bits2.dart`.
