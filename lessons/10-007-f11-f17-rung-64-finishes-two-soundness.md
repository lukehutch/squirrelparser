<!-- Part of LESSONS_LEARNED.md, section: 10. The f-series: e8 made to scale while keeping its trees valid (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### 10.7 f11-f17: rung 64 finishes, two soundness bugs, and the tree read from the engine's parse

Engine copied to `dart/experiments/recovery/_f17.dart`; f11-f16 stay in the kit.

| Engine | Change on its parent | Result | Verdict |
|---|---|---|---|
| f11 | the failed-terminal key (10.2) encoded as `distance * clauses + clause` instead of `clause * (n + 2) + distance` | the old code used the length `n` of the repaired string, which differs between states with different edits, so equal states got unequal keys; states grown at cost 8 on rung 8: 66 -> 50 | kept |
| f12 | `_span` counts only the open calls that start at or after the last edit; among merged states the one with the fewest open calls is grown | battery 0.9899 (f10 0.9900: 10 trees differ, f10 cheaper by one edit on 4 cases) | kept |
| f13 | `_clear` (no edit inside the window a base-table result examined) by binary search over the sorted edits instead of a scan | trees identical to f12; rung 16 11.1 -> 5.9 s, rung 32 70 -> 28.5 s | kept |
| f14 | pass 2 skips a held state whose key pass 1 already grew | rung 64 finishes for the first time (39.1 s, cost 57); lf seed 2 `babbaccacccc` cost 3 -> 8 | rejected |
| f15 | f13 + the f14 skip only when the held state has no fewer open calls than the grown one | dl and lf identical to f13; rung 64 39.4 s | kept |
| f16 | f15 + each memo entry keeps its own taint (10.7.1) | fixes an lf crash present since f10; dl, lf otherwise identical to f15 | kept |
| f17 | f16 + the tree replayed from rule results recorded during the engine's parse (D1, 10.7.2) + base-table hits refused inside a running left-recursive cycle (10.7.3) | see 10.7.4 | current f-line best |

#### 10.7.1 A stored result must carry the taint of the result it grew from

lf seed 12, `R0 <- (((R1 / R1) / !R1) "bab" &(!'c')); R1 <- ('a'* 'a'?* (R1 / R0*))` on
`abaab`. In R0@0's second left-recursion round, R1@0 is evaluated again. It reads its own
earlier value through its first alternative and never reads R0@0, so its taint (the lowest
depth of a running entry it read) equals its own depth, and it went into the base table as
clean. But the earlier value it read was computed while R0@0 was running. A later state then
accepted `aabab`, which the library rejects, and `_tree` crashed on the library's
SyntaxError. Fix: each entry keeps the taint it ended with (`_mTnt`); a hit passes it on, and
a re-evaluation starts from it. The case now returns cost 2.

The crash had been there since f10 and was never counted: the fuzzer skips a case in which
any engine crashes (`if (crashed) continue`) and prints only the first crashing engine. A
crash is a case the totals do not show.

#### 10.7.2 D1: the tree is replayed from the parse, not parsed again

Up to f16, `_tree` handed the repaired string to the library parser and walked its tree. f17
records, for every successful rule evaluation, its length and what each rule call in its body
returned, in call order (`_T`). Calls go on one shared stack; a success copies its slice, a
failure truncates it. The record goes into the memo entry (`_mNode`) and with it into the base
table (`_bNode`). `_build` then walks the clauses from the top rule: terminals are matched
against the repaired string, and each `Ref` takes the next recorded call, so no rule is
evaluated again. Left recursion needs nothing extra: a round of a growing rule reads the
previous round's record through the memo hit, so the rounds nest in the record.

`_tree` must run on the parse of its own node. That held for every call site, and a guard
(`node.gen != _gen`) now throws if it does not.

#### 10.7.3 The base table was unsound under mutual left recursion

With the library parse gone, 5 of 12,800 dl/lf cases gave a different tree from f16, all on
grammars with rules that are left-recursive through each other. Traced on
`R0 <- ((R0* "ca"? R1) / "aac"); R1 <- (((R0 / R1) / 'c') / 'a')` with the string `cac`:
R1@2 runs and calls R0@2, which the library evaluates with R1@2 running, so R0@2 fails in its
first round and R1@2 takes `'c'`. The engine took R0@2 from the base table, where it had been
computed with nothing running, and recorded R1@2 as R0@2 -> R1 -> `'c'`. The match ends
agreed, so the old library re-parse hid the difference.

The taint check (10.7.1) covers one direction: a result that read a running entry is not
stored. This is the other: a clean stored result is reused where a rule it calls is running.
A call can meet a running entry only at its own position, and only if the two rules are on a
cycle of the left-call graph (the rules a rule can call before consuming input). f17 computes
nullable clauses and that graph once per grammar (`_cyc`) and refuses a base hit for X@p
while any rule on a cycle with X is running at p (`_idle`). It changes nothing on grammars
without left-recursive cycles.

After the guard, every case's replayed tree equals the library's tree of the same repaired
string (checked by a debug copy that builds both and stops at the first difference, on all
cases where f17 and f16 differ; 2026-10-24: false in general, see 10.8.1). On dl seed 5, `R0 <- ((R1+ / R0?) 'b' R0**); R1 <- (R0+
"cc"??)` on `bbcb`, f17 finds cost 1 where f16 returns 2: f16 rejected a valid string through
a stale base-table result.

#### 10.7.4 f17 measured

| Check | f10 | f16 | f17 |
|---|---|---|---|
| battery score / perfect %, time | 0.9900 / 84.5 | 0.9899 / 84.5, 2.23 s | 0.9899 / 84.5, 2.43 s; trees identical to f16 |
| gates | b2 fails | b2 fails | b2 fails; cx2, b1, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 2 |
| rung 16 / 32 / 64 errors | 107 s / - / - | 6.1 / 27.3 / 43.0 s | 7.3 / 35.1 / 54.5 s (costs 14 / 29 / 57 for both) |
| dl seeds 1-16: invalid, worse than the other, timeouts | 0 / 44 (vs e8) | 0, 1, 0 | 0, 1, 1 |
| lf seeds 1-16: invalid, worse, timeouts | 0 / 38 (vs e8) | 0, 0, 0 | 0, 0, 0 |
| depth `[`*n, one `]` missing | overflow at 1600 | n=800 7.2 s, overflow at 1600 | n=800 7.4 s, overflow at 1600 |
| `x (ax)*n b`, `x (ab)*n` | - | n=800 0.8 s / 6.1 s, overflow at 1600 | n=800 1.0 s / 7.0 s, overflow at 1600 |
| library parses per `recover` | one per tree built | one per tree built | none |
| LOC raw / normalized | 493 / 777 | 516 / 817 | 601 / 957 (+85 raw, +16.5% on f16) |

The dl timeout is `S <- R0; R0 <- ('b' (R2+ 'c' ("cc" R2)) 'a'); ...` on the 15-character
`bcbbaccccbbcbba`: f16 takes 19.8 s and f17 21.1 s when run alone, both cost 1, and the
fuzzer's limit falls between them. Timing split on rung 16 (one run each, noise about 7%):
f16 5.9 s, f17 without the base-table guard 6.8 s, f17 7.3 s; so the record costs about 15%
and the guard about 7%. Sharing one record object per length for rules that call no rule
changed nothing measurable.

**Still open:** the 400k evaluation cap (D2); b2; stack overflow at nesting 1600 (both the
evaluator and `_build` recurse); time quadratic in nesting depth for one missing bracket and
in n for `x (ab)*n`; 20 s on a 15-character fuzzer input and the fallback's 9 s case; the
window's and frontier prune's fuzzer losses against e8 (not re-measured since f10).
