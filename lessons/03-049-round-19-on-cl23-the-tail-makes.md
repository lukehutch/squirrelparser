<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### round 19 on cl23: the tail makes one error linear but not two, and the fuzzer's witness was too loose (2026-09-26)

Round 19 ran a Claude subagent (Opus 5.5, high effort) on BRIEF19 (Q1 the tail;
Q2 size; Q3 the diverse retry and the fuzzer's witness; Q4 review of round 18).
Codex and Gemini had no quota. **No engine is promoted; cl23 stays.**

**The corrected witness (confirmed).** `_samedq.dart` accepted a tree if some
string parses when every one-character error is read as a deletion or as any
letter, anywhere in the tree. It never checked that the tree is PEG's tree of
that string. The engine charges a one-character skip as one edit; a skip is a
substitution only where it takes the place of a literal slot the tree leaves
unfilled. The corrected witness (`_samedw.dart`, `_samew.dart`) allows, in a Seq
or a multi-letter Str, as many substitutions as there are slots minus plain
children, and reads every other error as a deletion (or, elsewhere, as a
one-letter literal alternative of its parent).
- `caab` under `R0 <- ('a'? 'a' 'a')`: every slot holds a plain child, so both
  errors are deletions, the witness is `aa`, and PEG rejects it. The reading
  `aaa` contradicts the tree's empty Optional. The old witness accepted it.
- Recount, corrected fuzzer seeds 1-8 (`_samedw`, run in r9/verify): cl23
  invalid 7/5/7/4/7/6/6/8 = 50 -> 9/6/9/6/8/11/9/10 = 68; worse
  0/1/5/2/0/5/3/1 -> 0/1/4/2/0/5/3/1; cdx1 invalid 52/52/45/48/54/64/57/58.
  Every earlier invalid count in this file used the old witness.
- Four of the 18 newly invalid cl23 trees checked by hand; all four are engine
  errors, not witness errors:
  - `('b'*)+ "ac"` on `ac`: tree `OneOrMore[Err(a), ZeroOrMore ""]`, cost 2. The
    plain parser's `Repetition.match` (`combinators.dart`, `if (result.len == 0)
    break;`) never keeps an empty iteration, and inserting `b` costs 1.
  - `('c'?)+ 'b' (R0/'b')` on `ba`: cost 4 with empty Optional iterations after
    error iterations; inserting `c` and substituting a -> b costs 2.
  - `bcb`: an extra error in the Str "cb" whose slots are all filled, and the
    greedy `'c'?` left empty where PEG takes the `c`.
  - `ccbc`: an error child in a Seq whose slots are all filled; after the
    deletion PEG's R0 takes its first alternative `'c'`.
- Kind B (11 of 18, the seat's heuristic count): an iteration made of a skip and
  then the body's empty match adds no character to the repaired string, so PEG's
  tree cannot contain it. `_repeat` tests only input width (`_cl23.dart:844`,
  `if (step.end <= r.end) continue;`). Proposed rule for round 20: an iteration
  that adds no character to the repaired string is not an iteration (the
  repetition's counterpart of I68). The other 7 are substitutions with no free
  literal slot, or ordered-choice cases.

**t20: the tail (confirmed).** cl23 plus a lazy linked list of the readings rule
1 closes (`_Tail`), kept apart from a cell's exported ends and passed through
`_seq`'s last slot and `_first`; a `pref` field so the ranking sees the farthest
preferred closed end without building the tail; a fold to one reading per end
when a tail holds more readings than there are ends (pigeonhole); a build cache
that keeps one reading per key.
- LOC 841 -> 951 normalized (+110, +13.1%).
- Battery 0.9900/84.4, treeDiff 0, costDiff 0, 1,952 ms; every check. Old fuzzer
  = cl22 on seeds 1-8; corrected fuzzer = cl23 on every seed under both
  witnesses. One tree changes at equal cost (`acabb`, both valid).
- One error, AOT, n = 100 ... 1,600 (deep2): list-rr cl23 19/59/228/916/3,679,
  t20 5/10/19/43/93 ms; opt-in-star cl23 20/85/248/1,065/4,346, t20
  8/15/31/64/125 ms. Linear.
- Two errors, AOT, n = 200 ... 1,600 (multi.sh): list-rr cl23 67/261/988/4,388,
  t20 82/292/1,130/4,885; opt-in-star cl23 82/271/1,188/4,800, t20
  79/326/1,273/4,927 ms. Both quadratic; t20 3-24% slower.
- AOT stress, 11 interleaved runs, medians cl20 / cl23 / t20: errors 1,024
  11/11/11; errors 4,096 47/48/57; lr 2,048 33/33/36; lr 8,192 128/129/130.
- Not promoted: +110 lines, 19% slower on errors 4,096, and the quadratic term
  returns with a second error. The seat's own verdict agrees.

**Negative results (the seat's, not rerun unless stated).**
- t15, an earlier tail form that passed every scripted check, is far worse than
  quadratic with several errors (list-rr k = 2: 55 s at n = 800; cl23 1.0 s):
  each level rebuilt the whole chain below it. The kit had no multi-error test;
  `multi.sh` (`_multi19.dart`) is now in r9/verify.
- Each of the three tail sites is needed (ablations f1, f2, f4); a fold per run
  of the repetition is quadratic on one error (t10); bound filters in the build
  (t14, t18, t19) are slower or quadratic again; t12 gives `n,n,n,n,m,m` cost 2.
- Speed probes on t20 (t21-t28) recover at most 2-4 ms at +2-12 lines.
- Q2: a per-construct `_Pass` is +10 lines (t8). No engine shorter than cl23.
- Q3: q4b and q4c are not admissible under either witness, so the family 43
  timing of a rung-only retry trigger is not needed.

**Elegance review (orchestrator).** The engine did not change, so round 18's
review stands. One finding: `_repeat`'s progress test compares input ends, while
the answer is judged by the repaired string, so a repetition can hold an
iteration no PEG tree has. The fix is the kind-B rule above.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| cl23 unchanged | none | 841 LOC; every check | 8 | best on size and speed; kind-B trees open |
| t20 (Claude) | tail + pref + fold + build cache | 951 LOC; one error linear; two errors quadratic and 3-24% slower; errors 4,096 +19% | 5 | wins only on single-error inputs |
| t17 (Claude) | t15 + build cache | 947 LOC; plus-rr k = 8 2,350 vs 254 ms | 3 | slower |
| t21-t28 (Claude) | speed probes on t20 | 953-963 LOC | 3 | +2-12 lines for 2-4 ms |
| t9 (Claude) | cl23 with `exposed` -> `open()` | 841 LOC; errors 4,096 53-54 vs 47 | 2 | no lines saved |
| t15 (Claude) | tail + pref + fold | 929 LOC; list-rr k = 2 55 s at 800 | 2 | super-quadratic |
| t8 (Claude) | per-construct `_Pass` | 926 LOC (+10 over t7) | 1 | longer |
| t10, t14, t18, t19 (Claude) | tail variants | quadratic or slower | 0-1 | fail speed |
| t12 (Claude) | tail variant | `n,n,n,n,m,m` cost 2 | 0 | not admissible |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| old witness wrong; `caab` invalid | Claude | read `_samedq`, the tree and PEG on `aa`, `aaa` | confirmed (proved) |
| cl23 invalid 50 -> 68, cdx1 recounts | Claude | `_samedw` seeds 1-8 in r9/verify | confirmed |
| newly invalid trees are engine errors | Claude | 4 of 18 by hand | confirmed for 4 |
| t20: every check, trees = cl23 | Claude | check23.sh r19t20 | confirmed |
| t20: one error linear | Claude | deep2 list-rr, opt-in-star | confirmed (two shapes) |
| two errors quadratic in both, t20 slower | Claude | multi.sh list-rr, opt-in-star k = 2 | confirmed |
| errors 4,096: t20 56 vs cl23 48 | Claude | aot.sh: 57 vs 48 | confirmed |
| t15 super-quadratic | Claude | not rerun | unsupported by my check |
| replay counts are a model, not a timing | Claude | agrees with round 18's own wording | confirmed |
| t20's per-key build keeps every answer | Claude | measured only (battery, 16 fuzzer seeds) | not proved |

**Open items.**
- Kind-B trees (11 of 18): the zero-width iteration rule.
- The 7 other newly invalid trees: substitutions with no free slot, ordered choice.
- The quadratic term with two or more errors in the four shapes; the tail
  removes it only for one error.
- Size: 841 against cl20's 757 and cdx1's 616.
