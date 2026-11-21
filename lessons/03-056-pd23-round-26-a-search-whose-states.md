<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### pd23 - round 26: a search whose states are PEG derivatives makes every tree valid, 909 -> 856 LOC (2026-10-03)

Round 26 was run by the orchestrator alone (Codex and Gemini had no quota).
It takes round 25's open item: invalid trees come from guards that look only
near the edit, so the exact fix is a search whose states are PEG states. The
pd line is a new engine, not an edit of cl28. Engines pd1-pd23 are in the
scratch kit r26x; pd23 is the best.

**The design (confirmed from pd23's code).**
- A state is the derivative of the top rule after the characters read so
  far: a hash-consed term that says what PEG does for every way the rest of
  the input could go. Each place a clause may end is kept as an age
  (characters read since), so equal terms reached by different paths are one
  node, and the search merges states on the term with trees erased (`sid`).
- An edit is a step: read the next input character, delete it, or insert a
  character a literal of the grammar names (D7: no open-class character is
  ever invented). Best-first search over (input position, term) orders
  states by a lower bound on the total cost; text owed at the end of input
  costs one in total, as in the c line.
- Left recursion: a call to R at q while R is in progress at q is a leaf
  LC; iteration k+1 is R's body with LC replaced by iteration k, built when
  iteration k may first end longer than iteration k-1. This is the seed-
  growing rule of the parser itself, applied to derivatives.
- Trees are carried in the terms, so the answer is read off the final state
  and no repaired string is parsed again (D1).
- A term whose one pending kid has no end yet only waits on that kid, so it
  is kept as a frame on a stack and only the innermost term is stepped.
- Because every state is an exact PEG state, the tree is PEG's parse of the
  witness by construction. No guard is needed for validity.

**Measured (confirmed), kit r26x.**
- Battery (2,101 cases), pd23 vs pd14: 0.9900/84.4, treeDiff 0, costDiff 0.
  r26f (= cl28) scores 0.9900/84.5 on the same battery.
- Long-literal fuzzer `_samedl`, seeds 1-8, 3,200 cases, against r26f:
  r26f worse 180, invalid 46, levWorse 84; pd14 worse 0, invalid 0,
  timeouts 0, levWorse 0. pd20, pd22 and pd23 each equal pd14 on every
  count, treeDiff 0.
- Gates, pd23: accept cx2=true b1=true b2=false, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 2 2, cleanTreeDiff 0. Identical to
  pd14 and pd22. r26f has b2=true and conformance 0 1 1 0 2 3.
- Scaling, AOT executables (pd23 unless named):
  - nesting `(`*n on expr: n=512/1024/4096 in 192/423/1832 ms (pd18:
    n=512 in 2,993 ms; pd22 and earlier overflow the stack at 1024);
  - `x (ax)*n b`: n=1600/3200/6400 in 160/347/757 ms (r26f n=1600 3,978 ms);
  - `x (ab)*n`, n errors: linear (pd22 n=400..3200 in 46/100/207/420 ms;
    r26f n=1600 4,272 ms);
  - depth 800/1600/3200, valid 27/53/124 ms, one missing 39/62/124 ms
    (r26f overflows the stack at 3200);
  - LR expression with 2,048 errors: 115 ms (pd8; pd6 did not finish 1,024
    errors in 60 s).
- Battery time, back to back in the same kit: r26f 2,000 ms, pd23 18,553
  ms. pd23 is 9.3x slower on short inputs. It is faster than r26f only on
  long inputs.

**How the line got there (results confirmed from the transcript and the runs; the change column is from the transcript notes).**

| Engine | Change | Result |
|---|---|---|
| pd1 | derivative search, deletions placed as in x1y | truncated JSON cases time out |
| pd2 | owed text bounded by a strictly shrinking shortest completion; lazy successor terms (nodes 240,175 -> 28,225 on one case) | every truncated case finishes; battery 0.9807 |
| pd4 | evidence key: deletions, substitutions and reads no literal accepts all count in `bare` | battery 0.9898; matches r26f on pd2's seven worst cases |
| pd5 | fixes to the end-of-input measure (details not recorded) | battery 0.9900/84.4; fuzzer worse 0, invalid 0 vs r26f's 181/46 |
| pd6 | shortest-completion cap from the CFG relaxation | 7 worse, 7 invalid; states grow as about 4n^2 per error |
| pd7, pd7k | SDK `SplayTreeSet`, string keys (pd7) or record keys (pd7k) | 674 LOC; string keys 30% slower |
| pd8 | fewer distinct terms per position | errors linear: 2,048 in 115 ms; battery 71.0 s vs pd6's 97.6 s |
| pd9-pd11 | per-state cost work (details not recorded) | `x (ab)*n`: pd9 and pd10 time out at n=400, pd11 quadratic; pd9 overflows the stack at depth 800 |
| pd12 | frames on an explicit stack | battery 2.5x faster than pd9 (30.2 s), treeDiff 0 |
| pd13, pd14 | literals in depth-first order | battery 17.0 s, treeDiff 0 vs pd12 |
| pd15-pd17 | shared-hole frames; LR nesting | linear nesting but 871-888 LOC |
| pd18 | pd14 + the nesting fix in fewer lines | 861 LOC |
| pd20 | an insertion that leaves term and frames unchanged (same `sid`, same frame) only ages them, so it is dropped | nesting quadratic -> linear: n=512 2,993 -> 206 ms |
| pd22 | `_below` deleted; `_lits` and `_proves` computed per node and memoized on `sid` | `x ab` and `x ax b` quadratic -> linear; 862 -> 858 LOC |
| pd23 | the plain-parse fast path deleted | no stack overflow at any measured depth; 858 -> 856 LOC |

**Why pd22 was needed (confirmed with a state dump).** The focus term is a
chain of pending wrap, cat and seq nodes as deep as the nesting (1,411 nodes
at position 401 on `x (ax)*n b`), and `_below` walked all of it at every
state to list the literals and test which character the term proves. A
union per node, memoized on `sid`, costs one lookup per new node. Taking
each kid's literals in order, first occurrence wins, gives the same order as
`_below`'s preorder walk, so no tie-break changes.

**Why pd23 was needed (confirmed).** Every pd engine first ran the library
parser (`parser.match`) and returned its tree if it consumed the whole
input. That parser is recursive and overflows the stack at nesting 1024 on
expr, at `x (ax)*n b` with n=3200 and at depth 3200. This was a flaw in
every pd engine, not in the search. Deleting the fast path fixes all three
and gives the same trees (cleanTreeDiff 0), but valid input now goes
through the search: 27 ms vs 1 ms at depth 800.

**Negative results (confirmed).**

| Probe | Change | Result | Score |
|---|---|---|---|
| pd16 | free end-of-input completion counted as one edit in the ranking | changes trees | 2 |
| pd19 | pd16's ranking key deleted with `_whole` | battery equal, but `_samedl` worse 11 (cost 1 -> 2, 3, 4), e.g. `R0 <- ((("cacab" / "bca") / R0?) / R0)` on `ca` | 2 |
| pd21 | pd20 generalized to an ancestor walk over insertion runs | times equal pd20's on all four families, more code | 3 |
| pd20 first version | compared the term (`t == p.t`) | never fires: the inserted character is in the tree, so ids differ; `sid` is the right key | 0 |
| pd7 | string memo keys | 30% slower than record keys | 3 |

**Candidates.**

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| pd23 | 856 LOC; invalid 0, worse 0 vs r26f's 46/180; linear on every measured family; every measured input finishes | 8 | first engine valid by construction; smallest of pd14-pd23; 9.3x slower than r26f on the battery |
| pd22 | 858 LOC; same trees | 7 | overflows the stack at depth 1024 |
| pd20 | 862 LOC | 6 | quadratic on `x (ax)*n b` |
| pd18 | 861 LOC | 5 | quadratic on nesting |
| r26f = cl28 | 909 LOC; invalid 46 per 3,200 | 4 | guards cannot see revived repetitions far from the edit |

LOC: cl28 909 -> pd23 856 normalized (-53, -5.8%); pd18 861 -> pd23 856 (-5,
-0.6%).

**Notes.**
- Ties among equal-cost repairs are broken by the order of `_lits`, which is
  the grammar's textual order. This is PEG's ordered-choice priority, so it is
  defensible, but it is a choice the ranking makes, not a consequence of it.
- Ford 2004 (the undecidability of PEG language emptiness, cited for the
  search cap) was already in `paper/verification/bib.md`; the claim check was
  added to `cites_history.md` this round.

**Open items.**
- Battery latency: 9.3x r26f on short inputs.
- Gate b2=false in every pd engine (r26f: true).
- `_app(a, b)` folds b's list into a on each call, which may be quadratic in
  some grammar (inferred, not measured).
- Size: pd10's stale LC case and pd11's sequence `_sure` may be deletable.
- The header comment of pd23 still says pd14.
