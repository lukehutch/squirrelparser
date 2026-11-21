<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.5 f10 measured

| Check | e8 | f5 | f10 |
|---|---|---|---|
| battery score / perfect % | 0.9900 / 84.5 | 0.9900 / 84.5 | 0.9900 / 84.5 (9 trees differ from e8, i=541 cost 1 -> 2) |
| gates | b2 fails | b2 fails | b2 fails; cx2, b1, freespan, recommit 16/16, conformance as e8 |
| rung 1 / 4 / 8 / 16 errors | 0.2 s / over 300 s / - / - | 0.2 / 0.9 / 4.7 / 91 s | 0.2 / 0.56 / 5.3 / 107 s (16 measured before 10.3-10.4) |
| rung 64 | - | 400k cap, deletes the document | not re-run; expected as f5 |
| dl seeds 1-16, invalid / worse than the other | 0 / 4 | 12 invalid on seeds 1-8 alone | 0 / 44 |
| lf seeds 1-16, invalid / worse than the other | 0 / 4 | - | 0 / 38 |
| held-out 9-16 against z8 (dl, lf invalid) | 0, 0 | - | 0, 0 (z8 64, 62) |
| depth `[`*n | stack overflow at 1600 | - | same |
| `x (ab)*n` (n errors) | deletes all at every n | - | optimal to n=200 (22 s), deletes all from 400 |
| LOC raw / normalized | 429 / 671 | 478 / 742 | 493 / 777 (+64 raw, +14.9% on e8) |
