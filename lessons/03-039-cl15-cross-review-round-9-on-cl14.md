<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl15 - cross-review round 9 on cl14: a faster bound build, one bound-dependent case removed, and a last key that is not transitive, 803 -> 804 LOC (2026-09-24)

Round 9 ran Gemini (gemini-3.1-pro-high) and a Claude subagent (Opus 5.5, high
effort) on BRIEF9 (Q1 a cost model and front that do not depend on the bound,
Q2 the bound's price, Q3 invalid trees, Q4 size and elegance, Q5 peer review).
Codex has no quota until Sep 29. Gemini's first launch failed on quota; the
relaunch was still running when cl15 was committed; its report is verified in the
next section. The engine is untracked `_cl15.dart` (kit name r9c15):
the Claude seat's b3 plus the orchestrator's elegance review.

**What cl15 changes (confirmed from the diff against cl14).**
- **A faster bound build** (the seat's a24/b3). `_Bound` keeps its graph in one
  interleaved `List<int>` edge list and runs its breadth-first search over an
  `Int32List` ring queue with head and tail indices. `queued` admits each state
  once, so the queue never holds more than `wide` states and the ring never
  overruns (proof by reading). The seat's bucketed Dijkstra (a16) was quadratic,
  because a bucket queue costs O(spread) per position.
- **`_versions` and `version` deleted**: nothing read them after cl14's `_plain`
  lost its memo-version check.
- **The cell-reuse test is `cell.budget >= budget && !cell.usedSeed`.**
- **A new last ranking key** (the seat's a11): between readings that insert
  equally, the most substitutions; otherwise the fewest substitutions, then the
  fewest insertions. In cl14 the order of offers decided these ties. The key
  removes one of cl14's two bound-dependent cases (seed 3, `aabb`).
- **Elegance review of b3 (r9c15)**: a dead branch deleted (`cell.usedSeed ?
  _since : -1` sat under a test that had just required `!cell.usedSeed`);
  `most = _len + _bnd.terms.length` hoisted out of `_ladder`'s loop, since
  neither term changes inside it; the header comment rewritten to state the last
  key and that it is not transitive (below).

**Measured (confirmed), kit r9/verify, against cl14.** LOC 803 -> 804 normalized
(+1, +0.1%). Battery 0.9900/84.4, treeDiff 1 against cl14 at equal cost, costDiff
0, 1,861 ms (cl14 2,164 in round 8's kit). Accept t/t/t, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0, window P, pred
falseAssertions 0. Corrected fuzzer (`_samedq.dart`, 400 cases), invalid seeds
1-8: 8/6/8/4/7/7/8/10 (= cl14), worse 0 on every seed, levSum equal to cl14's on
every seed; trees differ from cl14 on 4/4/4/4/5/5/2/5 cases, all at equal cost.
Old fuzzer invalid 3/2/4/6 (= cl14). No-repair 0. Rungs (ms, cl14 / cl15, every
cost equal): 1000/1/1 342/282; 1000/32/1 1,921/1,485; 1000/128/1 5,312/4,972;
8000/4/7 9,354/6,078; 8000/32/7 9,609/6,226. Stress (ms, cl14 / cl15): errors 256
40/44, 512 70/58, 1,024 81/81, 4,096 198/180; LR 2,048 182/178, 8,192 362/352.
Families (`fam.sh`): LR with one error at 32,768 terms 726 ms; unclosed
parenthesis 1,024/4,096 159/166 ms; every other listed family linear. Families
(`sweep3.py`, 46 grammars, n = 1,024/4,096/16,384): all 46 finish at every size
with the same costs as cl14; the slowest is still family 43 (cl14 / cl15 at
16,384: 45,397 / 44,625 ms), then 42 (3,493 / 3,626), 30 (2,599 / 2,673) and 26
(2,429 / 2,588).

**Determinism (confirmed).** Each engine was built twice, once with only the
regular bound (`g`: `_allowance = 0`) and once with the return-site bound from
the start (`m`), and the two copies were diffed.

| engine | battery treeDiff g/m | fuzzer treeDiff g/m, seeds 1-8 |
|---|---|---|
| cl14 | 0 | 0/0/1/0/0/0/1/0 (`aabb`, `acaca`) |
| cl15 (= b3) | 0 | 0/0/0/0/0/0/1/0 (`acaca`) |
| a27 | 0 | 0 on every seed |
| k6 | - | 0/0/0/0/0/0/1/0 |

On seed 7 the `m` copy gives the invalid, worse tree. So cl15 still answers
differently depending on which bound is in force, on one fuzzer input in 3,200.

**Owed cost has a dominance rule (confirmed, proof).** The Claude seat proved:
with `cost = spent + (owed == 0 ? 0 : 1)`, and owed insertions only ever
following at `_len`, an owing reading O of spent t dominates a non-owing reading
N of spent s iff t + 1 <= s, and N dominates O iff s <= t. At t = s neither
dominates, which is exactly the case the one-per-end front resolves by rank. a27
keeps two slots per end (one owing, one not) and drops a slot only when the other
dominates it. It is bound-independent on every seed, but costs seed 5 one
invalid tree and seeds 2 and 5 one worse case each (levSum seed 2 557 against
553), so it was not adopted.

**The last key is not transitive (confirmed).** The key is

    if (a.missing == b.missing) return b.subs - a.subs;
    return a.subs != b.subs ? a.subs - b.subs : a.missing - b.missing;

It puts a substitution before a deletion (equal missing), an insertion before a
substitution (fewer substitutions), and a deletion before an insertion (fewer
missing at equal subs). Among single edits the (missing, subs) pairs (0,0),
(0,1), (1,0) form a cycle, so in a cyclic triple the order of offers still
decides. An instrumented copy (r9b3x) that records, per (front, key, cost,
avoidable, evidence, first, last, owed), the set of (missing, subs) pairs seen,
finds 0 cycles on the battery and 2/0/0/0/0/2/1/3 on fuzzer seeds 1-8 (for
example `babaa`, `cab`, `cabacabbabacaa`, `cbccbcba`). The seat's claim that the
key "orders readings by their edits in place of offer order" is therefore wrong
as stated.

The battery uses all three pairs of the cycle, and each choice there matches
what a person would do:
- JSON `{a":1`: insert `"` before `a`, not substitute `"` for `a` (insertion over
  substitution).
- `stmt` with a stray `}`: delete the `}`, not insert `{` before it to make an
  empty block (deletion over insertion).
- JSON `3z3`: substitute `,` for `z`, not delete `z` and join `33` (substitution
  over deletion).

So no order on edit types alone matches the battery. The preference depends on
where the edit falls relative to the input's own brackets and tokens. Every
transitive key tried loses:

| Candidate | Last key | Result | Score | Reasoning |
|---|---|---|---|---|
| b3 = cl15 | a11's key (cyclic) | 0.9900/84.4; fuzzer = cl14 | 8 | best measured; the cycle is documented |
| k1 = k4 | fewer missing, then more subs (k4: more subs, then fewer missing) | 0.9900/84.4, 86 trees differ from b3, all JSON missing-open-quote cases, which now substitute `"` for the key's first letter; seed 7 levSum 532 against 533 | 3 | against human expectation on 86 inputs |
| k6 | more missing, then more subs | 0.9899/84.3 (7 `stmt` cases lost); invalid equal, worse 0; still bound-dependent on seed 7 | 4 | loses the stray `}` case |
| k2 | fewer subs, then fewer missing | 0.9897/84.1 (9 lost); seed 6 worse 1 | 2 | |
| k5 | fewer missing, then fewer subs | 0.9897/84.1; seed 6 worse 1 | 2 | |

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r9c15 = cl15 | b3 after the elegance review | trees = b3 on the battery and fuzzer seeds 1-8; 804 LOC | 9 | same results, a dead branch gone |
| b3 (Claude) | cl14 + the last key + the fast bound build + `_versions` deleted | as cl15 | 8 | removes `aabb`'s bound dependence; 8000/4/7 about 35% faster |
| b2 (Claude) | b3 without the last key | battery = cl14, 803 LOC | 7 | keeps both bound-dependent cases |
| a27 (Claude) | two-slot front + last key + fast bound build | 816 LOC; 0.9900/84.5, treeDiff 4; invalid 8/6/8/4/8/7/8/10; worse on seeds 2 and 5 | 6 | the only bound-independent engine, one invalid and two worse trees |
| a17 (Claude) | flat `Int32List` graph + ring queue | 8000/4/7 5,030 ms, 834 LOC | 4 | fastest build, 30 more lines |
| a23 (Claude) | ring queue only | 8000/4/7 6,230 ms | 4 | |
| a2, a5, a6, a7, a9 (Claude) | front keyed by (end, owes), dominance, other last keys | 0.9899-0.9900; invalid up to 8/7/8/4/8/8/9/11 | 3-5 | superseded by a11/a27 |
| nokf (Claude) | b3 without `keepFirst` | 0.9902/86.4, 303 changes, +1 invalid on seeds 1, 2, 5, 8, worse 1 | 2 | more invalid trees |
| a12 (Claude) | ladder `hi = r.cost` | 8000/4/7 8,894 ms | 2 | the tree would no longer be the least budget's |
| a14, a26 (Claude) | a check after dominance; `_rejected` dropped in `_rung` | worse 1 on seed 1 / seed 6 | 1 | |
| a1, a3, a4, a8, a10 (Claude) | ranking-order changes | 0.9727-0.9847 | 0 | battery loss |
| a19 (Claude) | `_covered` deleted | families 35, 42, 43 time out | 0 | does not finish |
| a21 (Claude) | reuse seeded cells | 0.9670 | 0 | |
| a16 (Claude) | bucketed Dijkstra bound | 8000/4/7 290 s | 0 | quadratic queue |

**Claims table.** The full table is `$SP/r9/CLAIMS9.md`.

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| b3 battery 0.9900/84.4, treeDiff 1 vs cl14 at equal cost; all checks equal | Claude | check.sh r9b3 | confirmed |
| b3 corrected fuzzer invalid 8/6/8/4/7/7/8/10, worse 0, no-repair 0 | Claude | `_samedq` seeds 1-8; norepair.sh | confirmed |
| a27 is bound-independent | Claude | g/m copies, battery and 8 seeds | confirmed (the seat had measured a11 only) |
| a27 costs one invalid and two worse trees | Claude | check.sh r9a27, seeds 1-8 | confirmed |
| owing/non-owing dominance rule | Claude | read the proof | confirmed |
| the last key orders readings by edits, not by offer order | Claude | r9b3x cycle count: 8 cycles on seeds 1-8 | wrong as stated |
| the ring queue never overruns | Claude | read: `queued` admits each state once | confirmed |
| `_versions` deletion changes nothing | Claude | part of b3's checks | confirmed |
| the fast build: 8000/4/7 9,707 -> 6,184 ms | Claude | rungs.sh cl14 r9c15: 9,354 -> 6,078 ms | confirmed |
| family 43 spends 45% of its time in the diverse rung | Claude | not rerun | unsupported by my check; round 10 |
| the 58 invalid trees split 29/18/11 (repetition/option, ordered choice, literal/sequence) | Claude | not rerun | unsupported by my check; round 10 |
| dead `cell.usedSeed ? _since : -1` branch; loop-invariant `most` | orchestrator | read r9b3 | confirmed, fixed in cl15 |
**Open items.**
- A transitive last key that keeps the battery's three human choices. It must
  look at where an edit falls relative to the input's brackets and tokens, not
  only at the edit type.
- Bound independence on `acaca` (seed 7) without a27's losses.
- Family 43's diverse rung.
- The invalid-tree classes, once confirmed.
- Size: 804 lines.

**Process lessons.**
- Gemini again handed its work to background tasks (its log: "root agent idle;
  waiting up to 5h0m0s for 25 background task(s)"), against the preamble. It
  stayed in its own directory, so it was left to run.
- A cycle in a comparator does not show as a crash or a failing check; it shows
  only as order dependence. Count it directly: record, per group of otherwise
  equal keys, the set of values the last key compares, and look for a cyclic
  triple.
