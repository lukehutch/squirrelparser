<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### Standing of the line

e7s and e8 lead every engine on valid trees together with fuzzer repair
cost: 0 invalid trees in 12,800 cases and the fewest worse costs, at
0.9899 on the battery, in fewer lines than z6. They lose on battery
time (4.6-6.0 s against z6's 2.8 s and c14's 0.4-0.6 s), on many errors
(4 errors: 61 s or more against 64 errors in 0.58 s for z6), on gate b2,
and on D1. Whether the parse-per-state cost can be brought under the
memo sharing the D1 rule asks for, without losing the validity, is the
open question this line leaves.
