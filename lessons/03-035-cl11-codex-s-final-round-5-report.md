<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl11 — Codex's final round-5 report on cl8: two inputs cl10 could not finish, 700 → 696 LOC (2026-09-23)

Codex's round-5 run ended (rc=1) after cl10 was committed; its report
(R5_CODEX.md, 229 lines, still marked "in progress" at the top, the run cut
off by a content filter) contains two failures that cl10 still had. Both were
reproduced in my kit with Codex's `_r5_stress.dart` (copied as `_stress.dart`,
60 s limit per input). The engine below is untracked `_cl11.dart`.

**cl10 did not finish two inputs (superseded claim: the cl10 section above
called the round complete).**
- `S <- ('a' 'b')+` on n copies of `ac`: cl8 and cl10 finish 256 errors in
  46 ms but pass 60 s at 512, 1,024 and 4,096. The bound's distances were a
  `Uint8List` saturating at 255, and a saturated value is read as 0
  (unknown), so past 255 errors the bound prunes nothing. cl11 stores exact
  distances in an `Int32List`: 512 errors in 67 ms, 4,096 in 1.2 s.
- `S <- E; E <- E '+' N / N; N <- [0-9]+;` with 8,192 terms and one `?`:
  cl8, cl10 and the exact-distance intermediate all overflow the stack in the
  recursive tree builder (`_branch` closures calling each other, one frame
  per left-recursive level). cl11 builds the selected tree in postorder with
  an explicit stack: each `_Node` is a ready match or a label over a path, and
  keeps its built match, so a node shared by two paths is built once. 8,192
  terms finish, cost 1.

**Deletions.**
- `_minChars` (a fifth grammar walk) is gone. The ladder's ceiling is
  `_len + terms.length`, the terminal count of the bound's automaton (Codex
  r5count). Sound because the automaton shares a clause only when it repeats
  on the current call path (`onPath`), and a shortest derivation repeats no
  clause on a branch, so its characters map one-to-one onto terminals. Probe:
  `S <- E E E E; E <- '(' E ')' / "abcdefgh"` on `x` (four uses of a shared
  recursive rule) returns cost 32, and `S <- A; A <- A 'x'` (no finite
  derivation) still returns the whole-input error.
- The loop that added 2 to each terminal's out-degree in `_Bound` (Codex
  finding 17). The terminal's insertion edge is already in `back` with one
  character, so its state never has a single free exit; the loop changed no
  decision.
- `Squirrel.lastCost` forwards to the last `Recovery` instead of copying it.

**Measured (confirmed).** LOC 700 → 696 normalized (−4, −0.6%); the iterative
tree costs +21 and the three deletions save 25. Battery 0.9900/84.3, 1,461-1,523 ms (cl8 1,488 ms in the same run);
treeDiff 12 against cl8, treeDiff 0 against cl10; costDiff 0, auditBad 0. Accept
t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred 0. Corrected fuzzer against cl8:
invalid 11/9/11/9 (cl8 14/10/13/9), levWorse 0/1/0/0, the same as cl10. Rungs, alternating (ms, cl8 / cl11): 1000/1/1 290/294; 1000/32/1 3,166/3,270; 1000/128/1 7,584/7,836; 8000/4/7 2,216/2,252; 8000/32/7 10,687/10,674; every cost equal. Stress (ms,
cl8 / cl11): errors 256 44/40; 512, 1,024, 4,096 timeout/63, 140, 1,074; LR 2,048 terms 2,096/2,183; LR 8,192 stack overflow/44,373.

**Negative results and open items.**
- **Left recursion with an error is quadratic** (closed by cl12 on
  2026-09-24: semi-naive growth, see the cl12 section). `E <- E '+' N / N` with one
  error: 1,024 / 2,048 / 4,096 terms take 0.6 / 2.4 / 10.6 s (error in the
  middle); 1.1 / 4.7 s for 1,024 / 2,048 with the error near the start. The
  clean parse takes 7-15 ms. Instrumented at 512 terms: the cell of E at 0
  grows 512 times and its growth re-proposes the whole relation each time
  (131,073 readings, about n^2/2). A semi-naive growth (re-derive only from
  readings added in the last iteration) is not exact as the engine stands:
  `_level` demotes the previous farthest preferred reading in every
  iteration, and `_first`'s `reach` is taken from the whole first-arm
  relation, so old seeds do not produce the same proposals twice. 8,192 terms
  take 44 s; 32k terms would take minutes. Open.
- **Optional-ab (Codex finding 26, confirmed).** `S <- A "ab"; A <- "ab"?` on
  `x`: cl8 returns an empty `A` then a whole-literal substitution (cost 1);
  cl10 and cl11 return an empty `A` then `a` substituted and `b` inserted
  (cost 2). No PEG reading has that shape: the only word is `abab`, cost 4.
  `_starts` tests whether the body matches exactly the one lead character,
  and `"ab"` cannot match `a`. Codex's r5guard (`m.len > 0`) does not fix it.
  A correct test needs the repaired text after the stop; open.
- **The comparator is not monotone under prefix composition (Codex finding
  10, confirmed from the source).** `_compare` prefers a later first edit and
  then an earlier last edit. If a prefers over b on `first` but has a later
  `last`, a prefix with an earlier edit makes `first` equal and reverses the
  order. One champion per end is therefore a policy, not a theorem. Open.
- Codex's final candidate (cdx5c, 711 LOC) keeps cl8's whole-literal
  substitution and makes the bound admissible for it with a substitution
  edge; cl10 removed the substitution instead (see the cl10 section). Not
  taken.
- Codex's nullable `first` with a `chosen` flag and its `_EdgeKind` enum:
  larger than cl10's forms, not taken (as in round 5).

**Claims table (Codex's final report).**

| Claim | My check | Verdict |
|---|---|---|
| Byte saturation: 512+ errors do not finish | `_stress.dart errors 512/1024/4096`: cl8, cl10 time out at 60 s | confirmed, fixed |
| Deep LR tree overflows the stack | `_stress.dart lr 8192`: StackOverflow in cl8, cl10, x11 | confirmed, fixed |
| Terminal count is a sound ceiling | argument from `onPath`; shared-recursion probe cost 32 | confirmed, adopted |
| Out-degree counts 2 per terminal, no decision changes | source; trees identical | confirmed, loop deleted |
| `lastCost` duplicated state | source | confirmed, getter |
| Optional-ab invalid tree | `_tree.dart`: cl8 cost 1, cl11 cost 2, both invalid | confirmed, open |
| Comparator not monotone under a prefix | source (keys `first` then `last`) | confirmed, open |
| Peer's `_Way` has 14 fields (it has 13) | source | Codex correct |
| "D1 forbids the exact check" is wrong | D1 bans a second parse only | agreed (as in cl10) |
| LR 8192 "completes" in cdx5c (50 s) | 44 s in cl11; quadratic, see above | confirmed, but not linear |
