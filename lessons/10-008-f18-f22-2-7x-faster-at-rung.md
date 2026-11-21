<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.8 f18-f22: 2.7x faster at rung 64, and every tree equal to the library's

Engine copied to `dart/experiments/recovery/_f22.dart`; f18-f21 stay in the kit.

| Engine | Change on its parent | Result | Verdict |
|---|---|---|---|
| f18 | pass 2 runs only when pass 1 found an answer; before, a failed pass 1 ran pass 2 over every held state with no cost cap, then the fallback | the 20 s dl case: 4.6 s, cost 1; dl/lf never worse than f17, 7 cases cheaper, timeouts 1 -> 0; rungs 7.2 / 33.8 / 55.0 s | kept |
| f19a | the window's left edge is computed once per state, at evaluation, and a grown state is not evaluated a second time | step towards f19b | kept |
| f19b | `open` and `span` are also computed at evaluation; a state is evaluated once, and again only when it is taken as an answer | rung 16 5.8 -> 1.95 s (iterations executed 14.7M -> 0.87M); rungs 32 / 64: 25.5 / 41.8 s | kept |
| f20a | f18 + trails: a repetition records the iterations it ran, and a later parse with no edit inside them jumps over them, appending their call records | rung 16 5.77 -> 5.69 s | no gain on f18; the trails return in f20b |
| f20b | f19b + the f20a trails, with an iteration appended only if it starts where the trail's last one ended | rungs 2.0 / 12.6 / 21.8 s; battery trees identical to f18 | kept |
| f21 | the ranking keys (`ev`, `encl`) read from the call records of the parse instead of a tree built for every finished state; the tree is built once, for the answer | trees identical to f20b; peak memory at rung 64 1.07 GB -> 0.58 GB | kept |
| f22 | f21 + context-dependent memo entries are never stored in, or read past by, the base table (10.8.2); `_mTnt` deleted | see 10.8.3 | current f-line best |

Without the contiguity condition, f20b crashed in `_build` ("Null check") and gave costlier
answers: a trail took an iteration that started after a gap, so the jump skipped input no
iteration had matched. A checking copy (`_f20bc`) that runs every skipped iteration and throws
on a different result found it, and passes on dl and lf seeds 1-16 after the fix.

On the 12,800 dl and lf cases, f20b's trees differ from f18's on 2 cases in each fuzzer. Three
are equal-cost ties. On the fourth, dl `acbc`, f20b costs 2 where f18 costs 3. The
differences come from f19b, which reads the window and merge keys at a different time.

#### 10.8.1 The fuzzers did not check that a tree is the library's tree

The fuzzers (`_chk48f.dart`) count a tree as valid when its repaired string parses in the
library. They do not compare the tree with the library's tree of that string. The strict
check (`_f22s.dart` and the other `_*s.dart` copies) does: it parses the repaired string with
the library and throws if the two pretty-printed trees differ. On dl and lf seeds 1-16, it
failed for f20b on 3 cases, all on grammars with mutual left recursion; f17, f18 and f19b,
checked on those cases only, fail the same 3:
- dl seed 5, `abbcbb`;
- dl seed 5, `bcbb`;
- dl seed 16, `cccaca`.

f21 passed those 3 and failed a fourth (lf seed 11, `ba`), which f17-f20b pass. So the claim in 10.7.3, that every
replayed tree equals the library's, was checked only on the cases where f17 and f16 differ,
and it is false in general. Every engine since f17 replays its tree from its own parse, so a
replayed tree differs from the library's whenever the engine's parse differs from the
library's.

#### 10.8.2 Context-dependent memo entries

With base-table hits switched off, f20b and f21 give the library's tree on all four cases at
the same cost, so the base table causes all four.

The library keeps memo entries computed inside a left-recursive cycle, and reuses them later in
the same parse. Consider an entry for R2 at position p, computed while R1 at p is running and
reading R1's seed. That entry holds only for the moment it was computed, but a later call to
R2 at p still gets it from the memo. The base table broke this in two ways:

- A stored R1 at p, from a parse where the cycle ran, is hit, so the cycle does not run and the
  context-dependent R2 entry is never made. A later call to R2 at p computes it fresh and gets a
  different result.
- A clean stored result is hit while such an entry is already in the memo inside its extent,
  where the library would have read it.

On `ba` (lf seed 11) the library fails `!R1+` at position 1 and takes R2 as `""`; f21 took R1 at
position 1 from the base table and later built R2 as `R1 ""`. The idle check of 10.7.3 does not
cover either case: in the first, nothing on the cycle is running when R1 is hit; in the second,
the running rule has already returned.

The fix:
- An entry is dirty if it read a running seed above it (`_taint < _mDep`), or if it read or
  created a dirty entry. Dirtiness passes to the caller like the taint.
- A dirty entry is never stored in the base table.
- A base-table hit is refused when the current parse has a dirty entry at any position inside
  the stored extent (`_dirtyIn`).

This makes the taint stored per entry (`_mTnt`, 10.7.1) unnecessary: a hit on a dirty entry
marks the reader dirty, and a re-evaluation starts from the entry's own dirty bit. Direct left
recursion makes no dirty entry: the head reads its own seed at its own depth. Only rules that
are left-recursive through each other lose base-table reuse. Making stores symmetric with hits
(storing only an entry's first computation in a parse) changed none of the four cases; that
hypothesis was wrong.

#### 10.8.3 f22 measured

| Check | f18 | f20b | f22 |
|---|---|---|---|
| battery score / perfect %, time | 0.9899 / 84.5 | 0.9899 / 84.5; trees identical to f18 | 0.9899 / 84.5, 2.7 s; trees identical to f20b |
| gates | b2 fails | b2 fails; cx2, b1, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 2 | identical to f20b |
| rung 16 / 32 / 64 errors (costs 14 / 29 / 57) | 7.2 / 33.8 / 55.0 s | 2.0 / 12.6 / 21.8 s | 1.8 / 8.3 / 20.1 s |
| peak memory at rung 32 / 64 | - | 1.23 / 1.05 GB | 0.53 / 0.56 GB |
| dl and lf seeds 1-16: worse, invalid, timeouts | dl worse 1 (vs f20b) | 0, 0, 0 | 0, 0, 0 |
| strict check (tree = library's tree), dl and lf seeds 1-16 | fails the same 3 (run on those cases only) | 3 failures | 0 failures |
| LOC raw | - | 651 | 700 (+49, +7.5% on f20b; +99, +16.5% on f17) |

f22 runs at f21's speed (within 5% on all three rungs, about the noise between runs). The
three rungs were timed with nothing else running.

Time split on f20b at rung 64 (Stopwatch timers, one run):
- parsing 11.9 s of 22 s;
- child generation 3.0 s, nearly all of it alphabet probes, each a full parse;
- tree building 2.4 s (removed by f21);
- ranking keys 1.1 s.

A parse costs 46 / 68 / 92 us at rungs 16 / 32 / 64. The cost grows with the number of edits,
because each parse still executes about 123 iterations, most of them at earlier edits. There
are 1,600 to 2,700 parses per error.

**Still open:**
- the 400k evaluation cap (D2);
- b2;
- stack overflow at nesting 1600;
- the time per parse at earlier edits: a memo that persists across parses, keyed by the edits
  inside each entry's extent, would remove it;
- `_dirtyIn` scans a list, which is linear in the number of dirty entries;
- the fuzzers should run the strict check by default.
