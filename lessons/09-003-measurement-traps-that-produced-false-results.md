<!-- Part of LESSONS_LEARNED.md, section: 9. The breakthroughs, distilled (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 9.3 Measurement traps that produced false results

- Two batteries (era-3 and the 13,241 raw cases) and two LOC conventions (raw and normalized;
  `loc.normalised` returns (raw, normalized)) were mixed more than once.
- `battery` prints `treeDiff=0` unless the word `compare` is passed.
- `_recommit17/18` imported the wrong resolver, so a recorded "0 of 1" never ran.
- The scored dump omits perfect cases, so equal dumps can hide different trees.
- The x-line worse/better counter printed 0/0 because the CAT=1 output had no `^SCORE` lines.
- The old fuzzer never tested multi-letter literals, and `_samedq` was too loose.
- Blended ratios and JIT warm-up hid real differences; use AOT and per-family numbers.
