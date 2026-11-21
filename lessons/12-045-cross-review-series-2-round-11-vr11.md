<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.45 Cross-review series 2, round 11 (vr11): the join as a library Match, a fallback that keeps the cheapest candidate, and z43

**The round.** Base z42 = kit `vg10`. Agents: Claude claude-opus-5-5 medium, Codex gpt-6.1-sol medium, Gemini
gemini-4-argon high. Brief: `squirrel-xr/vr11/BRIEF11.md` (find and fix R10-2 without adding way fields, fix the
long-zero predicate inputs R10-4 inside the fallback's budget). New hard checks: `kit/big.sh` (dense `(1+` at
k = 4,096 and 16,384, `1+)` at 4,096 and 8,192, each within 1.5x of the faster of vg9 and vg10) and `kit/lz.sh`
(long-zero predicate inputs valid). Engines:
- Codex `vx11c` (540): a dirty join is a library `peg.Match(null, 0, 0, subClauseMatches: [left, right])`; the
  library's constructor takes the position from the first child and the length from the last, so `first` and `last`
  are O(1). `prev` is one `_Way?` that holds only the edits owed at end of input. A map `_subs` from composite Match to
  bool caches `_allSub` (identity keys: `MatchResult` has no `==`). Iterative `_edits`, a private `_Stop`, sweep step
  `(_len + 1).bitLength`. The fallback accepts the first candidate string whose prefix parses and deletes the rest.
- Claude `vc11e` (530): vg10 with `_allSub` read from two leaves (the newest edit on each side of the newest join)
  and a fallback that keeps the cheapest candidate and stops when breadth-first order can no longer beat it.
  `vc11f` (533) adds an iterative `_edits`.
- Gemini `vg11` (522): vg10 with `_allSub` read from two leaves, boolean tests reordered so the cheap ones run first
  (331x fewer `_allSub` steps), iterative `_edits`, `_Stop`, the sweep step `p -= rules.length`, and the
  first-prefix fallback.
- Orchestrator merges: `vm11a` (527) = vg11 with vc11f's fallback; `vm11b` (542) = vx11c with vc11f's fallback.

Logs: `squirrel-xr/vr11/kit/logs_r11/{suite_o11,big,la,lasum,cpfix,lz,longset,dyck}_E.txt`. Reports:
`vr11/{claude,codex,gemini}/R11_*.md`.

**Results** (orchestrator runs, one engine at a time). Every engine below passes every hard check: battery 0.9896
with treeDiff and costDiff 0 against vg10, all gates, semi/semi3/group3/group4/group5/wild 0, T family 5 above the
optimum with excess 39, exhaustive g4 40, class fixtures 0 of 900 invalid, lookahead set 0 invalid, cpfix 0 invalid,
lz 0 of 10 failed, long sets and Dyck 0 more expensive than z37a, `big.sh` and `slow.py` within their limits.

| Engine | floc | pdl / plf priceWorse | battery ms | big T `(1+` 16,384 | big L `(1+` 16,384 | big T / L `1+)` 8,192 | dense ms | Dyck ms | `&'b' [ab] / &'c' [a-z]+` on 10, 40 a's |
|---|---:|---|---:|---:|---:|---:|---:|---:|---|
| vg10 (z42) | 522 | 36 / 21 | 12,400-12,800 | 30,000-45,000 (R10-2; 44,736 in this round's `big.sh`) | 9,500 | — | ~3,000 | — | 1, 1 |
| vx11c (Codex) | 540 | 36 / 21 | 6,765 | 8,258 | 4,737 | 394 / 248 | 3,218 | 4,121 | **10, 40** |
| vc11e (Claude) | 530 | 36 / 21 | 12,393 | 7,787 | 4,961 | 479 / 900 | 3,212 | 3,736 | 1, 1 |
| vc11f (Claude) | 533 | 36 / 21 | 12,327 | 7,170 | 3,891 | 316 / 755 | 2,903 | 3,847 | 1, 1 |
| vg11 (Gemini) | **522** | 36 / 22 | 12,861 | 11,090 | 5,679 | 315 / 779 | 3,259 | 3,721 | **10, 40** |
| vm11a (merge) | 527 | 36 / 21 | 12,800-13,000 | 11,015 | 5,720 | 308 / 780 | 3,106 | 3,840 | 1, 1 |
| **vm11b (merge)** | 542 | 36 / **20** | **6,715** | 7,720 | 4,422 | 344 / **262** | 3,120 | 4,003 | 1, 1 |

(T = `E <- T ('+' T)*`, L = `E <- E '+' T / T`. Battery times standalone, run twice for vx11c 6.7 / 6.4 s, vg11
12.8 / 12.8 s, vm11a 12.8 / 13.0 s, vg10 12.4 / 12.8 s. Dyck times are the engine's half of `dyck.sh`.)

**R11-1: the cause of R10-2 was the recursive tree reads, and every finalist fixes it.** All six engines answer dense
`(1+` at k = 16,384 in 7-11 s where vg10 took 30-45 s. Two different fixes work: reading `_allSub` from two leaves
and testing it last (vc11e, vg11), or caching it per join (vx11c). Claude measured that the two-leaf read is not
exact: it disagrees with the full walk 2,308 times on dense, but changed no price on any suite input (computed by
Claude, `vr11/claude/logs`; not re-run here). It is a heuristic read, not a rewrite of the same predicate.

**R11-2: the 1.9x battery speedup comes from representing the join as a library Match with an end-of-input-only
`prev`, not from the cache.** Codex's vx11nc (vx11c without `_subs`) runs the battery in 7.0 s (orchestrator,
confirmed), against 6.4-6.7 s with the cache and 12.4-13.0 s for every engine that keeps vg10's pair. The cache is
what keeps the large inputs fast: Codex reports 45 s at k = 16,384 without it (Codex's run, not re-run here). So the
pair `(_Way, _Way)?` of R10-1 cost the battery half its speed, and Match nodes the library already has carry the
same structure at no extra field.

**R11-3: the first-prefix fallback is a regression in recovery quality (Codex's own counterexample, confirmed).**
On `S <- &'b' [ab] / &'c' [a-z]+;` with 10 and 40 a's, the optimum is 1 (substitute the first a with c). vx11c and
vg11, which accept the first candidate whose prefix parses, delete the rest of the input and price it at 10 and 40;
vc11e, vc11f, vm11a and vm11b price it at 1. The excess grows with the input. Codex reported this against its own
engine; Gemini did not test it. Claude's fallback keeps the cheapest candidate `(price, way, tree)` with price =
`_len` minus the kept original characters plus insertions, and loops while
`fb == null || q[qi].$2 + 1 < fb.$1 && seen.length < _floor`: breadth-first order means no later string can be
cheaper once the next level's depth plus one reaches the best price. It still fixes R10-4 (lz 0 of 10 failed in every
engine; `S <- &[a-z] [^a] . '0';` on 40 zeros: vm11b cost 38, valid, 27 ms). This becomes a hard check in round 12.

**R11-4: vm11b becomes z43** (`_z43.dart`, byte-identical to `vr11/kit/.../vm11b.dart`). 522 -> 542 formatted LOC
(+20, +3.8%), three way fields, engine fields 8 -> 9 (`_subs`). It is the fastest engine of the round on the
battery (6.7 s against 12.4-12.8 s for z42, 1.9x), at k = 16,384 (T 7.7 s against 30-45 s), and on L `1+)` at
8,192 (262 ms, the best), and has the lowest plf priceWorse (20). It also answers `1+)` at k = 16,384 on both T and L
with the optimal checked repair (cost 16,384, 0.6-0.8 s), which every engine in R10-3, vg10 included, failed. The 20
lines buy speed only; vm11a (527, +5) is the size alternative with every accuracy number of vm11b but z42's battery
time. The rule that size ranks first is overridden here because the battery time halves and every accuracy number
stays equal or improves; recorded so a later round can revisit it.

**R11-5: other findings, checked.**
- The sweep step does not explain the battery speed. vm11a and vg11 with vx11c's step `(_len + 1).bitLength`
  (kit `vm11ab`, `vg11b`) run the battery in about 13.0 s (orchestrator, confirmed).
- Gemini states that vg11 gives "zero price differences from vg10" on every listed family. Narrower than stated:
  plf priceWorse 22 against vg10's 21 (confirmed), and R11-3 is a price difference on an input the suite lacks.
  Recorded in Gemini's error list.
- Claude: on `S <- !'0' . '0';` and `S <- !('0' '0') . . '0';` every engine returns a valid tree whose checked price
  is the optimum (9, 39 and 8, 38) while the reported cost is 3 higher (12, 42 and 11, 41) (`lz_vm11b.txt`,
  confirmed). The cost number and the tree disagree; the tree is right. Not fixed.

**R11-6: elegance review of z43.**
- In its favor: the join is the library's own Match node, so `first`, `last` and `owed` are O(1) reads and no tuple
  or summary node exists; `prev` has one meaning (edits owed at end of input); `_Stop` replaces the `StateError`
  catch of R10-6.
- Against it: `_subs` is a ninth engine field, an identity map from Match to bool, and its cold walk is recursive;
  `peg.Match(null, 0, 0, ...)` passes a position and length that the constructor ignores; the fallback (Claude's)
  adds a tuple `fb` and a second stop condition; the cost/tree disagreement on `!` grammars (R11-5) remains;
  `_Way.maxOwed` and `_Way.len` are still static and mutable (R9-4).

**R11-7: verdicts.** Gemini conjectures that vg11 has converged on every metric, the first such claim in the
series, but marks it conjectured, and vg11 fails R11-3. Codex: improvable in every metric; no lower bound is proved.
Claude: improvable; the fallback is still the largest part and the two-leaf read is inexact. Not all three agree, so
the rounds continue.

**Direction for round 12.** Start from z43. Hard check added: `S <- &'b' [ab] / &'c' [a-z]+;` on 10 and 40 a's at
price 1. Questions: can the Match representation drop `_subs` (exact `_allSub` without a cache or a recursive walk)?
Can the size come back toward vm11a's 527 while keeping the 6.7 s battery? Can the reported cost agree with the
tree's price on `!` grammars?
