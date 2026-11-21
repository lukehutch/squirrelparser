<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### pd57 - round 29: nine deletions, class sets refuted, cubic bound from the literature, 944 -> 898 LOC (2026-10-03)

**pd57 = pd46 minus nine parts (confirmed).** A review agent tried 16
candidates on pd46, each tested alone (battery against pd46, gates, fuzzer
8 seeds x 400 cases), with a counter on every condition suspected dead; I
re-ran the combined engine in my own kit. Kept:
- `_firstN`: `|| out.first.k == _match` is implied by `out.length == 1`
  (the loop stops after any sure kid, and a match is sure).
- `_seqN`: the dead-fail check after `_dead` cannot fire; counter 0.
- tree building: the single-SyntaxError exclusion in `owed` cannot fire;
  counter 0.
- seen key: `min(at.a, 1)`, which states the comment's "any d > 0 acts
  alike" directly; a nonzero `a` at the top never occurs (counter 0).
- `_spelled` inlined into `_rep` (its only reader, memoized).
- the sid is the canon's id: `_bySid`, `_canon`, `_sid` deleted.
- `_lead` includes lookahead kids, and `_lits` and `_proves` read from it:
  `_lits1`, `_proves1` and the `proves` field deleted. The bound is weaker
  inside lookaheads but still a lower bound; no tree changed. That a weaker
  bound can never change a tie-break is not proved.
- record keys in place of the `_K` class (18 lines with a hand-written `==`).
- `_meet` inlined into `_wait` (its only caller).
pd57 then adds comments only: the header lists all seven tie-breaks (est,
bare, edits, a later first edit, an earlier last edit, inserted characters
only a class spells, state order), `_N.i` says what it holds, `fin` is
renamed `accepts`, and `_inert` says why composites count.

Checks, all equal to pd46 (confirmed): battery 0.9898/84.4, treeDiff 0,
costDiff 0; gates accept cx2/b1 true, b2 false, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 2, cleanTreeDiff 0; fuzzer worse 0,
invalid 0, timeouts 0, treeDiff 0 (pd56; pd57 differs only in comments and
one field name, by diff). Every scaling input finishes at pd46's cost.
Speed: battery 2,074 ms vs 1,927; families 3 to 10% slower (two runs
each), e.g. ab repetition n=16384 836-893 vs 803-819 ms, paren n=16384
18.1 vs 17.6 s, extra brackets n=32 8.9 vs 8.7 s.

**Refuted or not adopted.**
- Narrowing `_inert` to left calls only: 21 battery trees and 8 fuzzer
  trees change. Composite inert terms decide which kid a frame waits on.
- `_St.order` as a list of keys: same trees, battery 37% slower.
- List keys in an equality-aware hash map (pd58), to win back pd57's few
  percent: 911 LOC (+13), timings within noise of pd46 and pd57. Not worth
  13 lines.
- Classes as interned sets of frame classes (pd54): never finishes from
  n=3 on the extra-bracket family (n=1 1 ms, n=2 8 ms, n=3 over 60 s). A
  node can be a frame of itself through repeated owed brackets, so its set
  holds its own class and grows every pass. A fixed member for a frame from
  the node itself (pd54b) also never finishes from n=3, so the cycles are
  longer than one node. A correct version is a bisimulation fixed point over
  a growing cyclic graph (online partition refinement); not built.

**Why extra brackets cost about n^3: class exits cascade (confirmed by
instrumentation).** At n=4: 551 classes but only 118 distinct stacks of
frame sids; 265 nodes left their class, and 189 of them hold frames from one
(parent class, frame sid) pair only. A parent leaves its class, its states
are searched again, and the frames they push give the child a continuation
that differs only in the parent's identity. That is correct (the parent did
gain a continuation), so a cheaper test cannot skip it.

**A cubic worst case is expected for any exact engine (literature).**
Exact least-cost repair under a grammar includes Dyck edit distance. Chang
(arXiv 1511.04731, CPM 2016), after Abboud, Backurs and Vassilevska Williams
(FOCS 2015): an O(n^(3-e)) combinatorial algorithm for Dyck edit distance
with alphabet size 10 would give one for RNA folding, and with it a
breakthrough for combinatorial k-clique. So no exact combinatorial engine is
truly subcubic on all grammars with many bracket errors unless that
conjecture fails. The json family has one bracket type, which the bound does
not cover, so pd57's n^3 there is its own cost.

**Candidates.**

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| pd57 | 898 LOC; same trees as pd46; 3-10% slower | 9 | 46 lines gone, every check equal, clearer comments |
| pd56 | 898 LOC; same as pd57 | 8 | pd57 without the comment fixes |
| pd46 | 944 LOC | 7 | previous best |
| pd58 | 911 LOC; speed within noise | 4 | 13 lines for no measured gain |
| `_St.order` list | 4 lines fewer; 37% slower | 2 | slower |
| pd54b | n=3 over 60 s | 0 | never finishes |
| pd54 | n=3 over 60 s | 0 | never finishes |
| `_inert` narrowed | 21 trees change | 0 | wrong trees |

LOC: pd46 944 -> pd56 898 (-46, -4.9%); pd46 944 -> pd57 898 (-46, -4.9%);
pd57 898 -> pd58 911 (+13, +1.4%).

**Open items.**
- Size: pd57 898 against c20's 742.
- Extra brackets (one bracket type): about n^3; the hardness result does not
  cover one type, so a better order is possible in principle.
- Gate b2=false in every pd engine.
