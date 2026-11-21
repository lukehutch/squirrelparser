<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The synthesis round — what each engine is best at, and why one engine cannot hold all of it (2026-09-11)

The question was whether the per-metric winners can be combined. Measured
bests, and the mechanism each one's advantage comes from:

| Metric | Best engine | Value | The mechanism responsible |
|---|---|---|---|
| Accuracy | c18-envelope | 0.9902 / 86.24 | c13's seven keys + the envelope |
| Size | c19 | 470 LOC | bills in side maps on the real library parser |
| Battery latency | c14 | 370 ms | no windows: one pass per case |
| Clean path | c14 | 7.57 µs/doc | no recovery grammar built |
| Large-input time and memory | c18 | 430 ms / 296 MiB | windows, no beam, memoized plain |
| Many errors on one document | c25 | 12 errors in 1.7 s | the admissible bound pruning inside the rung |
| Structural soundness | c19 | keeps the reading at every n | no window to exclude the repair site |

c20/c25 already hold five of these: c19's relation, c18's windows, the
stop prune and the bound. The two it does not hold are battery latency and
size, and this round established that the first of those is **structural**,
not an oversight.

**The pass census.** Instrumenting the ladder over the 2,101-case battery
(`_pass20.dart`): **6,179 top-level passes, of which 3,720 are window
re-runs and only 358 are budget increments.** So 60% of all work on short
inputs is re-running a pass because a window opened, and almost none of it
is climbing the ladder. Same-process battery times, one process per engine,
for reference: c14 468 ms, c18 946, c19 1590, c20 1371.

**Why the re-runs cannot be merged.** The 1.77 re-runs per case are two
distinct windows: one over the error, then one over the end of input, which
only becomes visible after the first repair lets the parse reach the end.
Opening the end window eagerly alongside the death window does exactly what
the census predicts on short inputs — re-runs fall to one per case (3,720 →
2,101), passes fall 26%, battery 1,371 → 1,241 ms, every tree unchanged —
and is **catastrophic on long inputs**: `1000/8/1` goes 976 ms / 321 MiB to
**57,313 ms / 2,198 MiB**, and `1000/12/1` does not finish. An end window
open from budget 1 makes the whole ladder explore end-of-input insertions.
Rejected and reverted.

**Why the diagnostic pass cannot be skipped either.** The first pass at
budget 1 has no open positions, so it is just the plain parse; its only
products are the death position and the window marks. The death is
available for free — `parser.syntaxErrorPosition()` already exists in the
library — but the marks are not: `_plainBound` is written from the
repetition sub-matches of `parser.match(c, pos)` at recovery cells, and the
library memoizes at rule boundaries only, so a repetition's occurrence ends
are not in the memo table. Reproducing them costs what the pass costs.

So the window design has a floor of about 2.2 passes per case where c14
needs one, and that is the whole 2.9x. **c14's battery latency and c18/c25's
large-input behavior cannot be held by one engine as long as locality comes
from windows**, because the mechanism that supplies the scaling is paid for
once per case on every input, including the ones too short to need it.

#### The bound is regular, and bracket balance is not

The round also settled where the admissible bound's slack lives, which is
the other half of why a combined engine is hard. Floor against the cost the
engine actually returns, json `makeDoc`, 23.5k characters:

| errors | cost returned | floor | free |
|---:|---:|---:|---:|
| 4 | 4 | 3 | 1 |
| 8 | 8 | 5 | 3 |
| 12 | 11 | 7 | 4 |
| 16 | 14 | 9 | 5 |

A controlled single-deletion experiment (`_boundstat8.dart`: delete exactly
one structural character from a clean 897-character document, at every
position, and read the floor) says precisely which deletions are free:

```
  "@d1  n=100 free=  0      ,@d1 n= 39 free=  0      :@d1 n= 40 free=  0
  "@d3  n= 60 free=  1      ,@d2 n= 20 free= 10      [@d1 n= 10 free= 10
  {@d1  n= 10 free=  0      ,@d4 n= 10 free=  8      ]@d1 n= 10 free= 10
  {@d2  n= 20 free= 10                               }@d1 n= 10 free= 10
                                                     }@d2 n= 20 free= 20
```

**Every deleted bracket is free at every depth; quotes and colons are
charged correctly.** That is not an implementation defect: bracket balance
is not a regular property, so any finite-state relaxation must lose it.
This is the reason deeper call-string unfolding did nothing — re-measured
here per deletion, k=3 charges 1 of 10 `[` deletions where k=1 charges 0.

**The counting bound that can see it does not compose.** A right-to-left
scan gives the exact Dyck cost (unmatched openers, unmatched closers at the
document start, type mismatches): 2, 5, 3, 5, 7, 10 for 4, 8, 12, 16, 24 and
32 errors. Rebuilding the regular bound with every bracket terminal made
epsilon and every bracket character free to skip (`_boundstat9.dart`) leaves
the regular floor **unchanged** — confirming brackets contribute nothing to
it — which suggests the two price disjoint edits and could be added. They
cannot: the sums are 5, 10, 10, 14 against costs of 4, 8, 11, 14, so the sum
**exceeds the true cost** at 4 and 8 errors and is not a lower bound. One
inserted bracket repairs the balance *and* the local structure the missing
bracket broke, so the same edit is counted twice. `max` is sound and adds
nothing, because the Dyck figure never exceeds the regular floor. Getting
both without double counting needs the counter inside the distance DP — the
product of 384 NFA states with a depth counter — which is a per-document
table of hundreds of megabytes. Not attempted.
