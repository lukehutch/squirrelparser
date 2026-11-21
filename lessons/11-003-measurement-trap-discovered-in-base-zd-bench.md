<!-- Part of LESSONS_LEARNED.md, section: 11. Round 60: z9 — Zero Bit-Packing Anywhere, Exact z6/z7 Battery Trees, Fastest Battery & Rungs, and Best D1 Fuzzer Validity/Costs (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 11.3 Measurement Trap Discovered in `BASE=zd ./bench.sh battery ... compare`

In `_research18.dart`, running `BASE=zd ./bench.sh battery X compare` executes *both* `e.recover(k.mutant)` (timed) and `b.recover(k.mutant)` (where `b` is `BASE=zd`, untimed) inside the same 2,101-case loop. When `X` is `zd` (`BASE=zd ./bench.sh battery zd compare`), both `e` and `b` are instances of `zd.Squirrel`, so the Dart JIT compiler warms `zd.Squirrel` at 2x call frequency with monomorphic inline caches inside the timed loop (`2,565–2,674 ms`), whereas when `X` is any other engine (`z9`, `z8`, `z7`), `zd` runs interleaved with `X` on every case (`2,795–2,862 ms` for `z9`). When timed standalone (`./bench.sh battery X`, one engine per process) or in interleaved AOT (`x3.exe bench 5 zd z7 z8 z9`), **z9 is the fastest engine in both modes**.
