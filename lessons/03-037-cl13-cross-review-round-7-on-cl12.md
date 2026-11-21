<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl13 — cross-review round 7 on cl12: every fuzzer input gets a repair, fewer invalid trees, 702 → 727 LOC (2026-09-24)

Round 7 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and
a Claude subagent (Opus 5.5, high effort) on BRIEF7 (Q1 inputs with no repair,
Q2 invalid trees, Q3 size and elegance, Q4 peer review). Codex finished (rc=0;
its report says "Final measurements Pending" but the body holds the measured
results). The Claude seat finished. Gemini stopped on its quota before writing
a report. The engine below is untracked `_cl13.dart` (my kit's k3k).

**What cl13 changes (confirmed from the diff against cl12).**
- **A diverse search, used only when the ordinary one fails** (Codex's r7retry,
  reorganized). `_Front` in diverse mode keys its readings by `distinction =
  (end, first, lead, guard stop, guard cut)` in place of `end`, and diverse
  cells live in their own map (`_cells[1]`). The ladder retries a budget in
  diverse mode when it found no reading and some reading was rejected (by the
  guards, `bad`, or by departing); `_Front.add` reports a rejection through
  `Recovery._rejected`. If the whole ladder still fails, `_ladder(top, true)`
  climbs it again with the diverse search at every budget. Semi-naive reads,
  the deletion-resumption check and the wrapper-following `_active` apply in one
  mode only (below).
- **Same-stop guard conjunction** (`_meet`, Codex's proof): when a guard is
  carried across a clean zero-width successor that has its own guard at the same
  stop, both must hold: the earlier cut and either opening test. cl12 dropped
  the successor's guard (`g = guard`). Codex's version kept the first cut only;
  cl13 takes the earlier cut, as the proof says.
- **Literal revival in `_first`** (Codex's `_finishes`, the same idea as the
  Claude seat's q7): a later arm is not skipped when an insertion finishes an
  earlier arm's literal.
- **Deletion-resumption check** (Codex's `_resume` guard, ordinary mode only): a
  clean resumption after a deletion may not start with a character that opens
  the stopped body.
- **A null terminal guard in `_plain`** (Codex).
- **Sealing** (cl12s): in `_seq`, when slot 0 is a Ref whose body is active at
  `pos` and a later plain run of the tail follows, the tail's plain run is taken
  as is. This makes the unclosed-parenthesis family linear (below).
- Removed after ablation: Codex's `_starts` literal fast path (ke), the
  multi-letter `broken` test in `then` (kf), and the optional single-character
  substitution (quadratic, below). The fallback became a function with a `wide`
  parameter in place of a `_wide` field and a recursive `recover()` call.

**Measured (confirmed), my kit, against cl12.** LOC 702 → 727 normalized (+25,
+3.6%). Battery 0.9899/84.3, treeDiff 0, costDiff 0, 1,629 ms (k3j 1,626,
k3i 1,699; cl12 about 1,520-1,556 ms in this kit).
Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P, pred falseAssertions 0.
Corrected fuzzer (`_samedq.dart`, 400 cases): invalid seeds 1-4 8/6/8/4 (cl12
8/8/9/6), seeds 5-8 7/8/7/11 (cl12 9/10/9/13); worse 0 and levWorse 0 on all
eight seeds against cl12; levSum 533/553/536/512 (cl12 534/549/535/507). Old
fuzzer (`_same.dart`): invalid 3/2/4/6 (cl12 4/5/4/9), worse 0.
**No-repair cases (`norepair.sh`, both fuzzers, seeds 1-8): 0 (cl12 10).**
Left recursion with one error: 32,768 terms 809 ms. Unclosed parenthesis
(`E <- E '+' T / T; T <- '(' E ')' / [0-9]`, body `(1+1)+`, error `((1`):
1,024 198 ms, 4,096 306 ms (cl12 256 491-559 ms, 1,024 5.3-6.4 s, 2,048
21-26 s). Stress (ms, cl12 / cl13): errors 256 51/41, 512 76/76, 1,024
133/132, 4,096 1,246/1,036; LR 2,048 177/190, 8,192 333/365. Rungs (ms, cl12 /
cl13, every cost equal): 1000/1/1 328/345; 1000/32/1 3,450/3,928; 1000/128/1
8,681/9,388; 8000/4/7 2,337/2,288; 8000/32/7 11,176/11,755. k3f showed the
same gap on 1000/128/1 (8,736/9,659). The cause of the 5-14% gap on the
many-error rungs is not measured.

**Candidates (all in my kit, against cl12).**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| k3k = cl13 | k3j + `_meet` takes the earlier cut | as above | 9 | best validity, no-repair 0, linear families |
| k3j | k3i with the ladder a function and ka reverted | = k3h on every count, 722 LOC | 8 | seed-7 `acba` invalid |
| k3i | k3h + ka, ke, kf | 724 LOC; seed 7 `ccbcca` cost 3 (k3h 2) | 6 | ka is not harmless |
| k3h | k3f without the optional substitution | 731 LOC, invalid 8/6/8/4, 7/8/8/11; seed 6 one worse than k3f (levWorse 0) | 7 | linear |
| k3f | k3q + post-ladder diverse fallback | 739 LOC, same invalid counts as k3h, no-repair 0 | 4 | `S <- 'x' 'a'?+` on `b`×n quadratic: 265 ms at 512, 2,710 ms at 2,048 |
| k3q | per-rung diverse retry on any front rejection | no-repair 4 | 5 | front dominance still drops readings |
| k3r | per-rung retry only on a root rejection | no-repair 17 | 2 | rejections inside cells never reach the root |
| k3s | Codex's k1 + sealing + per-rung retry | 0.9900/84.5, treeDiff 3, no-repair 0; 1000/128/1 18.1 s, 8000/32/7 23.4 s (cl12 9.5 s, 13.2 s) | 3 | twice as slow on the rungs |
| k1 | Codex's r7finishsmall (post-ladder fallback only) | 706 LOC, 0.9899/84.3, treeDiff 0, no-repair 0 | 4 | the `a`×n family climbs the whole ladder first: quadratic |
| cl12s | cl12 + sealing | 721 LOC, trees = cl12, no-repair 10 | 5 | fixes only the parenthesis family |
| Claude q7 | early-first-edit slot in a second search | reported 717 LOC, no-repair 2 (not rerun) | 5 | superseded by the diverse retry |

**Ablations of k3h** (k3h: old fuzzer invalid 3/3/4/6, corrected 8/6/8/4, worse
0, no-repair 0).

| Ablation | Change | Result | Verdict |
|---|---|---|---|
| ka | `_active` follows wrappers in both modes | identical on seeds 1-4; seed 7 `R0 <- (R0?? ('c'+ / ("ac" R0)))` on `ccbcca` costs 3 (k3h 2) | kept diverse-only |
| kb | resume guard in both modes | worse cases, corrected 7/7/8/4 with levWorse 1, no-repair 2 | rejected |
| kc | no resume guard | old 3/3/4/8, corrected 8/6/9/5 | guard kept |
| kd | no `keepFirst` in `_first` | battery 0.9902/86.3 (perfect +2.0), treeDiff 299; worse 1 on several seeds, corrected 9/7/8/4 | open lead |
| ke | no `_starts` literal fast path | same counts, 2 fuzzer trees differ | deleted |
| kf | no `broken` text test in `then` | identical | deleted |
| kg | no terminal-null guard in `_plain` | corrected seed 2 invalid 7 | kept |
| kh | `g = guard` in place of `_meet` | old seed 4 invalid 7, corrected seed 2 7, worse 1 | `_meet` kept |

**Negative results and open items.**
- **The optional substitution is quadratic.** Codex's proposal in `_optional`
  (`if (text?.length == 1 && pos < _len && rs.single.end == pos)` substitute the
  option's literal for the next character, marked avoidable) repairs three
  seed-6 costs, but on `S <- 'x' 'a'?+` with input `b`×n it takes 265 ms at 512
  and 2,710 ms at 2,048 (cl12 about 45 and 65 ms), and on `R0 <- ("ab" "aa"*?
  'a'?+)` 9.7-10.7 s at 2,048 (cl12 363 ms). The per-rung retry is not the
  cause: an instrumented copy (k3fd) runs one ordinary rung. Removed; the cost is
  one worse seed-6 case.
- **`R0 <- ("ab" "aa"*? 'a'?+)` on `b`×n is quadratic in cl12 and cl13 alike**
  (cost n-1): cl12 188/420/1,500/5,821 ms and cl13 177/392/1,342/5,295 ms at
  1,024/2,048/4,096/8,192. The bound's floor stays far below the cost here, so
  the ladder climbs one rung per error. Open.
- **The plain parser overflows its stack** on deep right recursion or nesting at
  n ≈ 1,500-2,048, before recovery starts, in cl12 as well. Pre-existing.
- Seed 6 `S <- R0; R0 <- (("bc" / R0)* R2); R2 <- ("bb"+* 'b'?);` on
  `bbbbcbbbcb`: every engine returns an invalid tree (Codex traced cl12's cost-1
  change to the conjunction). Open.
- `keepFirst` (kd) is worth +2.0 perfect on the battery but costs fuzzer
  validity. Open.
- The diverse search keeps the front's full distinction, so front dominance is
  not solved in the ordinary search; it is avoided by the retry.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| A retry with a front keyed by the distinction repairs the no-repair cases | Codex | k1 `norepair.sh`: 0 | confirmed, adopted in reorganized form |
| The unrestricted wide front breaks `cab` (cost 1 valid → cost 5 invalid) | Codex, Claude | both reproduced it; it matches round 6's x45 | confirmed; diverse mode stays a retry |
| Same-stop guards must both hold: OR of openings, minimum of cuts | Codex | kh ablation; k3k (minimum cut) fixes seed-7 `acba` and old seed 2 | confirmed; the cut half was not in Codex's engine |
| The resume guard cuts invalid trees | Codex | kc +4 invalid; kb (both modes) no-repair 2 | confirmed, ordinary mode only |
| The optional substitution restores three seed-6 costs | Codex | k3f vs k3h: one fewer worse case | confirmed, but quadratic; rejected |
| The unmarked optional substitution breaks D8 on `[,2,]` (46 battery trees) | Codex | not rerun; the marked version has treeDiff 0 | Codex's measurement |
| cost = spent + bool(owed) is not additive | Codex | counterexample checked by hand | proved |
| Exact tie witnesses cannot be kept in linear time (round 6) | round-6 seats | Codex: only the tried forwarding is shown quadratic | the impossibility is unsupported; the measurement stands |
| `_active` must follow wrappers only in diverse mode | Codex | ka: identical on seeds 1-4, one worse case on seed 7 | confirmed (my first reading, "harmless", was wrong) |
| The `_starts` fast path and the `broken` text test are needed | Codex | ke, kf | unsupported; deleted |
| An early-first-edit slot gives no-repair 2 | Claude | not rerun | superseded |

**Process lessons.**
- `norepair.sh` pipes through `tee /dev/stderr`. With stderr redirected to the
  same log file, that truncates the log. Send its stderr to /dev/null.
- `norepair.sh` registers a copy that throws on no repair. Remove the `nr`
  entries from `_pred18.dart` afterward, or `bench.sh pred` crashes and the
  pred line is lost.
- An ablation that is identical on four fuzzer seeds can still differ on the
  next four (ka). Check seeds 5-8 before adopting a deletion.
