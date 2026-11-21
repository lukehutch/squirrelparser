<!-- Part of LESSONS_LEARNED.md, section: 6b. The mechanism-A autopsy (json string-swallow, 2026-08-22) -->
[Back to the index](../LESSONS_LEARNED.md)

### §6c. The ceiling measurements (2026-08-22)

Three probes bounded what ANY engine under this objective can score:

1. **Extra-rung enumeration**: holding the ladder past first admission
   on the four worst json cases surfaced no rival — the winner's keys
   were duplicated, not challenged. The horizon is not hiding better
   readings one rung up.
2. **Tie-retention + oracle judgment**: keeping every exact-tie reading
   alive through composition and judging all collected complete
   admissions offline: 71 of 330 imperfect cases have a better candidate
   in hand, 12 hold a perfect one; a perfect oracle over the sets scores
   0.9908 vs 0.9896 chosen. That +0.0012 is the ENTIRE headroom of
   arrival-order tie resolution — and it is reachable only with
   knowledge outside the readings (an oracle), so no engine rule can
   take it without pricing something in.
3. **Asymmetric pricing** (deletion costs more than insertion): refuted
   hard (−0.0075 at weight 2). The yardstick rewards structure, but
   symmetric per-character pricing is still the right objective.

And the re-diagnosis that closes the family: inspecting the worst json
cases directly shows the engine returning TRUE minimum-cost accounts.
`{...,"bc":[2,33,tru],d":{...}}` → deleting `d` makes `""` a legal key:
one deletion where the human repair needs two insertions. The battery's
expectation is frequently unreachable at the engine's cost — the residual
there is the yardstick asking for structure the edit metric does not
price, not an engine defect. Under this objective and this yardstick,
c13 sits within about +0.001 of the measurable optimum; further gains
require changing what is priced, not how the search runs.
