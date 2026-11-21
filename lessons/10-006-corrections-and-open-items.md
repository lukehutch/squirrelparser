<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.6 Corrections and open items

- **Correction (this session, before this section was written):** f6's 148 "lower costs" on
  the battery are not repairs e8 misses. Characters appended at the end cost 1 in total in the
  search (`costOf`), so appending `"":0}` to `{"a":1,` and substituting `,` -> `}` tie at
  cost 1; `lastCost` reports `best.edits.length`, which is 5 for the append. Cost comparisons
  on truncated inputs compare edit counts, not search costs.
- **Still open:** rung 64 (equal-cost repairs that leave different constructs open multiply
  across errors; f6's open-call rule bounds this but raises 73 battery costs); D1 (`_tree`
  re-parses with the library parser); D2 (the 400k cap, now applied twice); b2; stack depth;
  the frontier prune is not admissible (it changed no battery result but is part of the 44/38
  fuzzer losses, with the window); the fallback's 9 s worst case.
