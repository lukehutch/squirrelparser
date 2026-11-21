<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c25 — the admissible floor prunes the rung, and the call site is what makes a bracket cost (2026-09-08)

c25 is c20 (the c19 relation on the real parser, `back=4` windows,
`_stops`) plus three changes. It is installed as
`dart/experiments/recovery/_c20.dart`, so every harness name is still
`c20`.

**1. Deferred clean-path setup.** `_site(top)` moves below the early
return taken when the ordinary parse already covers the input. This is
Codex's `_c20defer` finding, confirmed: on a clean document the recovery
grammar is never built.

**2. A regular lower bound, used inside the rung, not only to choose it.**
`_Bound` is an NFA over-approximation of the grammar with a backward
edit-distance table `distance[at][state]`, giving `after(c, at)` (from a
clause's exit) and `before(c, at)` (from its entry): an admissible lower
bound on what completing the document costs from there. Two prunes:

```dart
if (r.spent + _floor(c, r.end) > _budget) { pruned = true; continue; }
```

on every proposed bill, and

```dart
if (_bnd != null && _bnd!.before(c, pos) > _budget) return const [];
```

on the whole cell before it is filled. Cells that read no open position
are cached at `_unlimited` and reused at every higher budget, so a cell in
which anything was pruned must be recorded at the current budget instead:
that is what the `pruned` flag is for. Without it the prune silently drops
bills that are valid one rung up. The bound is built once the ladder
reaches budget `_guide = 3`; below that the rungs are cheap and the ~500 ms
build does not pay for itself.

Codex's `_c20guided` used the same bound only to pick the ladder's
starting rung. That is the weaker half: the floor is small relative to the
rungs that dominate, and a separate control (`_c20.start.dart`) that jumps
the ladder start measured 4,640 ms against 4,591 ms for no jump — no gain.
The win is entirely in pruning **within** a rung.

**3. The call site is what makes an unclosed bracket cost anything.**
Codex's relaxation lets a call return through ANY caller
(`eps(end_R, b)` for every caller of `R`). On a 23,560-character json
document with 12 real errors that relaxation's floor is **2**: merging
callers destroys exactly the bracket structure that makes json damage
expensive, so an unclosed brace is nearly free. Unfolding each call per
call site, and tying the knot only where the grammar is genuinely
recursive (`onPath`), raises the floor to **7** for 1.75x the states
(220 → 384, 19 → 34 MiB, ~300 → ~500 ms). The engine's cells carry no
call site, so a clause's bound is the least over its copies — still below
every real completion, whichever context the cell is in.

**Unfolding deeper is refuted.** With an unfold depth `k` (a recursive
clause gets `k` fresh copies before the knot is tied), on the same
`1000/12/1` document:

| k | states | build ms | table MiB | floor |
|---:|---:|---:|---:|---:|
| 1 | 384 | 584 | 34 | 7 |
| 2 | 1,856 | 2,404 | 166 | 7 |
| 3 | 7,744 | 16,026 | 696 | 7 |

The floor does not move while cost grows 20x. The remaining slack in the
bound is not call depth; it is the other two relaxations — assertions are
ignored and a substitution is allowed at every terminal. Driver:
`_boundstat3.dart`.

**Measured.** Battery bit-identical to the c20 base: `0.9901 / 86.0`,
treeDiff 1919, costDiff 1 against the c20 dump, for every bound variant
tried. All four gates pass; `_properties18 c20` 2,728 cases / 0
violations; `_pred18` falseAssertions 0; the repository suite is 284/284.
Rungs are single fresh workers, `_time20.dart`, json `makeDoc`:

| Rung (nodes/errors/seed) | chars | c20 base | c25 |
|---|---:|---|---|
| 1000/4/1 | 23,560 | 452 ms / 305 MB | 891 ms / 286 MB |
| 1000/8/1 | 23,560 | 8,938 ms / 871 MB | **1,045 ms / 362 MB** |
| 1000/12/1 | 23,560 | **never finished** (>500 s, 2.6 GB) | **1,691 ms / 439 MB** |
| 1000/16/1 | 23,560 | never finished | 4,146 ms / 483 MB |
| 1000/24/1 | 23,560 | never finished | 54,348 ms / 1,133 MB |
| 1000/32/1 | 23,560 | never finished | **still never finishes** (>400 s) |
| 4000/4/2 | 97,700 | 1,392 ms | 3,190 ms |
| 8000/4/7 | 196,500 | 3,668 ms / 1,204 MB, cost 6 | 6,682 ms / 987 MB, **cost 4** |

The bound is **not** output-neutral. An earlier claim in this session that
it was a pure speed knob is wrong: at `8000/4/7` the base engine and
`_guide = 5` both return cost 6 while `_guide = 3` returns cost 4. Pruning
changes which readings die, hence which deaths are recorded, hence which
windows open. Here it strictly improves the answer, but it is a search
change, not only a speed change, and `_guide` is a parameter that must be
scored, not assumed.

**Cost.** Normalized LOC c20 743 → c25 **901** (+158, **+21.3%**), almost
all of it `_Bound`. That is the wrong direction for the size goal and is
the main argument against this build.

**All positions open is refuted a third way.** Deleting the windows and
relying on the bound alone fixes Codex's window counterexample (`P` is
kept at every n) and removes both `back=4` and `wide=64`, with battery
0.9900 / 85.8 and all gates passing — but `1000/8/1` takes 64,014 ms /
2.5 GB and `1000/12/1` never finishes. The windows do work the bound
cannot replace. Variant: `_c20.allopen.dart`.

**Still open.** `1000/32/1` does not finish, so the hard requirement that
every input terminate is **not met**. Codex's window counterexample
(`_window21.dart`: c20 loses the `P` reading for n >= 8 because the
`back=4` window excludes the opener at position 0) is **still unfixed** in
c25, since the only fix found so far is all-open, which does not scale.
