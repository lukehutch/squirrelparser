<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl12 — cross-review round 6 on cl11: left recursion with an error becomes linear, fewer invalid trees, 696 → 702 LOC (2026-09-24)

Round 6 ran Codex (gpt-6-astra, max effort), Gemini (gemini-3.1-pro-high) and
a Claude subagent (Opus 5.5) on BRIEF6 (Q1 linear left recursion, Q2 invalid
trees, Q3 comparator monotonicity, Q4 size, Q5 peer review). Codex finished
(rc=0, 651-line report). Gemini wrote its report and then hung waiting on a
background task; I stopped it. The Claude seat finished. The engine below is
untracked `_cl12.dart` (my kit's x47).

**What cl12 changes (confirmed from the diff against cl11).**
- **Semi-naive growth** (the Claude seat's engine, then adapted). Each strict
  improvement of a cell is logged as `(tick, end)`; `cell.start` is the tick
  at which the current growth pass began. A seed read of a cell that is being
  grown returns only the ends improved since that tick, plus the farthest
  preferred end and the start position, taken from a fresh set and sorted by
  end. Every clause grows this way; the Repetition exception the seat kept is
  not needed (x39: 7 equal-cost fuzzer trees change, invalid counts equal).
- **`r.first >= reach` in `_first`** (Gemini; cl11 had `>`): a later arm
  whose first edit is at or after the earlier arm's reach is skipped, since
  that edit could revive the earlier arm.
- **A last tie-break on substitutions**: between ways with equal `missing`,
  the way with more substitutions ranks higher. It restores the `1?1+1`
  battery tree that the semi-naive growth changed.
- Codex's two `_Bound` compactions (the slot map via `columns.putIfAbsent`;
  the push/pop edge loop in one statement).
- Comment fixes from the elegance review: the header now names every ranking
  key and the semi-naive growth; `start` is documented; the whole-input
  fallback says when it happens.

**Measured (confirmed), my kit, cl11 = x15.** LOC 696 → 702 normalized (+6,
+0.9%). Battery, alternated twice: cl11 0.9900/84.3 at 1,391 and 1,398 ms;
cl12 0.9899/84.3 at 1,515 and 1,525 ms (9% slower), treeDiff 8, costDiff 0,
auditBad 0.
Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P (n=4096 cost 1), pred falseAssertions 0.
Corrected fuzzer (`_samedq.dart`, seeds 1-4, 400 cases each): invalid 8/8/9/6
(cl11 11/9/11/9), worse 0/0/0/0 (cl11 3/1/2/3), levWorse 0/0/0/0 (cl11
3/1/2/3), levSum 534/549/535/507 (cl11 528/547/531/502). Old fuzzer
(`_same.dart`): invalid 4/5/4/9 (cl11 6/6/6/11), worse 0 on every seed.
Left recursion with one error (`_lrprof.dart`, error at 50%): 8,192 terms
316 ms (cl11 44,373 ms), 32,768 terms 868 ms. Stress (ms): errors 256 45,
512 72, 1,024 130, 4,096 1,126; LR 2,048 167; LR 8,192 338 (cl11: 63, 140,
1,074; 2,183; 44,373).
Rungs, alternating (ms, cl11 / cl12, every cost equal): 1000/1/1 294/300;
1000/32/1 3,290/3,271; 1000/128/1 7,883/8,095; 8000/4/7 2,243/2,271; 8000/32/7
10,772-10,916/10,927-11,290 (four runs each on an idle machine; a first run at
12,310 ms overlapped another job). Across three battery runs today cl12 is 3-9%
slower than cl11 (1,503-1,591 ms against 1,551-1,599 ms in the later two).

The levSum rise (+2 to +6 per seed) comes with fewer invalid trees: the
repairs cl11 returned in those cases were cheaper because they were invalid.

**Why the growth is linear (inferred from the profile, confirmed by timing).**
At 512 terms cl11 re-proposes 131,073 readings (about n^2/2) because each
growth iteration of `E` at 0 rereads the whole relation. cl12 rereads only the
ends improved in the last pass. The fresh view must be sorted by end: the
unsorted set was quadratic again (x34), and sorting restored 857 ms at 32,768
terms (x35).

**Candidates (all measured against cl11 in my kit unless noted).**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| x47 = cl12 | x39 + comment fixes | as above | 9 | linear LR, fewer invalid trees, one equal-cost battery tie lost |
| x39 | x35 with no Repetition exception in growth | = x47 in behavior, 702 LOC | 9 | simpler; 7 equal-cost fuzzer trees change |
| x35 | x34 + fresh view sorted by end | 32,768 terms 857 ms | 8 | superseded by x39 |
| x34 | x33 without the whole-literal lead | quadratic again (unsorted view) | 5 | Codex's prefix counterexample forced the revert |
| x33 | x32 + Codex's `_Bound` compactions + `(tick,end)` log | intermediate step, no separate result recorded | - | carried the refuted whole-literal lead |
| x32 | subs tie-break only when `missing` is equal | fixes `1?1+1`; optional-ab cost 1 with one error node | 6 | the cost-1 tree cannot be valid; traced to the whole-literal lead |
| x31 | `subs` as the last key always | fixes `1?1+1`, 85 tree changes | 3 | too many witness changes |
| x30 | lead-null tie key | 15 battery diffs, 0.9898 | 2 | loses score |
| x29 | x28 + a substitution counts as evidence | loses battery ties | 2 | rejected |
| x28 | the seat's linear engine + `>=` reach | 727 LOC, 0.9899, treeDiff 3; LR 8,192 344 ms, 32,768 918 ms; dq invalid 7/8/9/5 | 7 | best validity, but 25 LOC larger and 3 ties lost |
| x27 | x23a + the seat's Q2 changes | 701 LOC, treeDiff 0, dq 7/8/9/5 | 7 | whole-literal lead later refuted |
| x26 | tie forwarding on the linear engine | restores `1?1+1`; 1,024 terms 529 ms, 4,096 7,335 ms | 2 | quadratic |
| x24, x25 | Gemini's changes on the seat's engines | x24 732 LOC, treeDiff 3, dq 7/8/9/5 | 5 | larger, same validity as x28 |
| x23a | cl11 + `r.first >= reach` only | 696 LOC, treeDiff 0, dq 8/8/9/6, worse 1/0/0/1 | 7 | the useful half of Gemini's work |
| x23b | cl11 + `_text` of a Seq only | no change (11/9/11/9) | 1 | inert |
| x23 | both Gemini changes | 701 LOC, treeDiff 0, dq 8/8/9/6 | 6 | x23b adds lines for nothing |
| x22 | my delta growth (only the previous step's ends) | treeDiff 2, still quadratic (2-3x faster) | 3 | cells between the seed and the growing cell still reread everything |
| x21 | lead = the literal's remaining text | treeDiff 0, dq 10/9/12/8 | 3 | mixed; optional-ab falls to the whole-input error |
| x20 | `_least` returns the unreachable distance | no change | 1 | inert |
| x45 | front split: zero-width insertions keep their own champion | battery treeDiff 0 vs x39; no-repair cases 10 → 5 | 3 | invalid cost-5 tree on `cab` (below) |
| x41, x42 | front split keyed on zero-width insertion (x42 also on the lead) | x42: invalid counts rise to 9/9/10/6 | 2 | worse validity |

**Negative results and open items.**
- **Exact tie witnesses cost quadratic time.** At 512 terms, 66,048 of 67,582
  proposals are equal-rank replacements (67,328 logged). Forwarding them (x26)
  restores cl11's `1?1+1` tree but takes 7.3 s at 4,096 terms. cl12 keeps
  semi-naive growth and loses 3 equal-cost ties that the `subs` key does not
  recover; the battery score drops 0.9900 → 0.9899.
- **A whole-literal lead is refuted** (Codex): `S <- A "ab" 'c'; A <- (("abc" /
  'a') 'b')?;` on `xbc` costs 5 with it (the seat's vq6, x32) and 1 without.
- **Inputs with no repair (pre-existing, confirmed on cl11 and cl12).** On 10 of
  6,400 fuzzer cases (both fuzzers, seeds 1-8) the coherence rules reject every
  reading within the ceiling and `recover` returns one error over the whole
  input. In every case `_nearest.dart GRAMMAR INPUT 8` finds an accepted word at
  edit distance 1 or 2. Nine of the ten have a nullable repetition body or a
  repetition of a repetition, for example `R0 <- ("ba"? "cb" 'c'?+)` on `cb`.
  Causes (confirmed by tracing): (1) `_Front` keeps one champion per end, and a
  clean zero-width skip beats a zero-width insertion at the same end; (2)
  `_first` keeps one output per end, so a later arm's insertion that a guard
  would accept is dropped in favor of an earlier arm's insertion that the guard
  rejects; (3) "later first edit ranks higher" conflicts with `_tail`'s cut,
  which needs the first edit before the cut. The cl12 comment above
  `if (best == null)` now states the fallback. Open (BRIEF7 Q1).
- **The front split (x45) is rejected.** On `S <- R0; R0 <- ('c'** (R2 R0 'a')?
  'b'?+); R1 <- ('c'?? / (R0 / R0)+); R2 <- (R0 / (("cb" / 'a') R2* "cc"));`
  with input `cab` (dq seed 2), x39 returns the valid cost-1 tree
  `R0([c [<err1:a> b]])`, x45 an invalid cost-5 tree. The nearest word is `cb`.
- **Monotone comparators lose accuracy** (Codex, measured by Codex, not re-run):
  `(spent, owed, avoidable, -evidence)` 0.9685/81.1; dropping `last`
  0.9896/83.9; two later variants 0.9726. Codex's instrumented engine found 375
  local rank reversals in 71 battery cases, so one champion per end does lose
  rivals locally; no monotone order kept accuracy.
- Optional-ab (`S <- A "ab"; A <- "ab"?` on `x`): still cost 2, invalid in
  cl12. Codex's final engine (y6f) returns the valid cost-4 tree (`abab`,
  confirmed with `_tree.dart`) through a rule specific to an optional literal
  followed by a literal with the same text; y6f is 705 LOC with a
  pattern-restricted fast path. Open.

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| Semi-naive growth makes LR with an error linear | Claude seat | `_lrprof.dart`: 8,192 316 ms, 32,768 868 ms (cl12) | confirmed, adopted |
| The linear engine loses only equal-cost ties | Claude seat | battery costDiff 0; treeDiff 3 on x28 | confirmed |
| Whole-literal lead fixes optional-ab safely | Claude seat | Codex's `xbc` counterexample: cost 5 vs 1 | wrong, reverted |
| Tie forwarding keeps exact trees but is quadratic | Claude seat (vs5) | x26: 529 ms at 1,024, 7,335 ms at 4,096 | confirmed |
| `r.first >= reach` removes invalid trees, treeDiff 0 | Gemini | x23a: dq 8/8/9/6, battery treeDiff 0 | confirmed, adopted |
| `_text` of a Seq closes `_tail` gaps | Gemini | x23b: no change on any count | wrong (inert) |
| Gemini's LR is O(n) (8,192 in 287 ms) | Gemini | its engine: 1,024 216 ms, 4,096 2,344 ms | wrong, quadratic |
| The `_wantsDelta` flag selects the delta path | Gemini | source: initialized `false`, never assigned, so the delta branch never runs | wrong (dead code) |
| Linear LR only for `E <- E sep N / N` | Codex | source: the fast path tests that shape | confirmed; not general, not adopted |
| Prefix counterexample to a whole-literal lead | Codex | `_tree.dart` on `xbc` | confirmed |
| Monotone orders lose accuracy | Codex | not re-run | Codex's measurement |
| 375 local rank reversals on the battery | Codex | not re-run | Codex's measurement |
| Final engine 705 LOC, invalid 11/9/11/8 | Codex | `check.sh` in my kit | confirmed; worse than cl12 |

**Process lessons.**
- `pkill -f PATTERN` and `pgrep -f PATTERN` match their own shell when the
  pattern appears in the calling command line: `pkill` kills its own shell
  (exit 144), and an `until ! pgrep -f ...` wait loop never ends. Kill by PID.
- Registering an engine edits the shared drivers `_research18.dart` and
  `_pred18.dart`. A registration that does not compile (x26) broke every run in
  progress. Register only when no run is going.
- A diagnostic engine that throws (x46, which throws "no repair" to count those
  cases) must be unregistered from `_pred18.dart`, or `bench.sh pred` crashes
  after the engines listed before it.
