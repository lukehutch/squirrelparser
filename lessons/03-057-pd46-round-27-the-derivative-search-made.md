<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### pd46 - round 27: the derivative search made fast, and continuation classes, 856 -> 944 LOC (2026-10-03)

Round 27 was run by the orchestrator alone (Codex and Gemini had no quota).
It takes pd23's open item: the derivative search was 9.3x slower than cl28
on the battery. Engines pd24-pd44 are in the scratch kit r26x; pd45-pd48b
are in r27k.

**The design added this round (confirmed from the code).**
- Per-node memo fields replace the global memo map (pd24, pd25). What depends
  only on a term's `sid` is stored on the first node with that `sid`.
- A lower bound on the edits still owed, from the grammar read as a CFG whose
  rules return anywhere they are called: a position is a terminal's
  character, the follow sets come from one fixed point, and the least edits
  from each position at each input offset are computed per input (pd27-pd29).
  The search is best-first on edits plus this bound. Ties go to fewer input
  characters no terminal could read.
- A bucket queue over the integer key (pd30).
- Frame ages: a frame's ages, d characters on, can only meet younger ages or
  ages its hole already held, so only age 0 can tie and any d > 0 acts alike
  (pd31). This makes the paren family linear.
- One derivative automaton per grammar, grown as inputs need it and reused
  across inputs, since no term holds an input position (pd33).
- Characters that no terminal tells apart step alike, so one stands for all
  (pd34).
- GSS nodes (pd39): a pending term's frames are shared per (term, position,
  flags), and an end joins every frame of its node. This replaces pd36's
  hash-consed frame stacks, which enumerate distinct stacks.
- Continuation classes (pd43, pd44): each node gets a class keyed by its
  term's `sid`, the hole's `sid`, the outer node's class and the flags. The
  search merges kid states on the class, not on the node, so nodes with the
  same continuation share their states. A node that gains a frame of another
  class leaves its class and its kid is searched again.

**Measured (confirmed), kit r26x.**
- Battery (2,101 cases): pd44 vs pd43 0.9898/84.4, 2,008 ms, treeDiff 0,
  costDiff 0. pd43 vs pd36: 2,067 ms, treeDiff 61, costDiff 0. All 61 diffs
  are equal-cost trees; the choice among them follows the push order `seq`.
- Gates, pd43 and pd44: cx2=true b1=true b2=false, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 2 2, cleanTreeDiff 0.
- Long-literal fuzzer `_samedl`, pd43 and pd44: worse 0, invalid 0,
  timeouts 0, levWorse 0.
- Battery time down the line: pd23 18,553 ms, pd26 10.2 s, pd28 5,514, pd29
  5,401, pd31 5,234, pd32 4,591, pd33 1,929-2,204, pd34 1,808-1,837, pd35a
  1,755, pd38 1,558. r26f (cl28) back to back with pd34: 1,959-2,016 vs
  1,783-1,835 ms. The derivative search is now as fast as cl28 on short
  inputs.
- Scaling, AOT executables (ms):

| Family | n | pd44 | pd43 | pd37 | pd39 |
|---|---|---|---|---|---|
| paren | 1024 / 4096 / 16384 | 1,068 / 4,635 / - | 905 / 3,818 / 16,916 | 549 / 2,238 / 9,898 | 40,716 at 1024 |
| optional x a | 512 / 2048 / 8192 | - / 65 / - | 16 / 64 / 219 | 5 / 17 / 76 | 1,226 / 33,414 at 512 / 2048 |
| ab aa a | 1024 / 2048 / 4096 | - / 101 / - | 57 / 104 / 216 | 16 / 31 / 57 | |
| ab repetition | 1024 / 4096 / 16384 | | 60 / 204 / 836 | 35 / 140 / 592 | |
| optional-a b repetition | 1024 / 4096 / 16384 | | 68 / 277 / 1,179 | 61 / 241 / 968 | |
| json valid long | 1024 / 4096 / 16384 | | 81 / 398 / 1,658 | 67 / 278 / 1,110 | |

- Brackets, `S <- V; V <- '[' (V (',' V)*)? ']' / [0-9]+;`:
  - n extra brackets (`[` + `[1,2]],`*n + `1]`), n=8/16/32: pd43 123/919/
    7,518, pd44 -/1,217/9,571, pd39 144/1,640/20,299. About n^3. pd36 and
    pd37 time out at n=64 (and pd36 at every size).
    cl28 (r26f): n=8/12/16 in 65/667/1,185 ms, n=32 not done in about
    300 s. The least cost is below n (n=16 costs 11).
  - n missing brackets (`[1,2,`*n), n=64/256/1024: pd43 29/121/572, pd44
    639 at 1024, pd37 12/46/173, pd36 280/5,015/timeout.
  - one extra bracket in a long valid input: linear at cost 1 in pd37, pd39
    and pd43 (n=4096: 515, 716, 672 ms).
  - depth 3200, valid / one missing: pd43 189/185 ms.

**How the line got there.**

| Engine | Change | Result |
|---|---|---|
| pd24 | per-node `steps` map replaces the global memo for steps | |
| pd25 | per-node memo fields; `sid`-only facts on the first node with that `sid` | |
| pd26 | the bare-character bound added to `bare` at push | 10.2 s |
| pd27 | CFG lower bound on owed edits per position and offset | |
| pd28 | child bounds computed at push | 5,514 ms |
| pd29 | follow sets from one fixed point; owed text reaches any position | 5,401 ms; 856 -> 995 LOC |
| pd30 | bucket queue; LR iterations that end no later dropped | 4% faster |
| pd31 | frame ages with d > 0 treated alike | paren linear (16,384 in 11.1 s); 5,234 ms; 1,017 LOC |
| pd32 | trimmed | 4,591 ms |
| pd33 | one automaton per grammar, reused across inputs | 1,929-2,204 ms; 941 LOC |
| pd34 | characters no terminal tells apart step alike | 1,808-1,837 ms; 949 LOC |
| pd35, pd35a | elegance review | 904 / 905 LOC; 1,755 ms |
| pd36 | `_settle` memoized | 908 LOC; extra brackets exponential |
| pd37 | second bound from bracket weights | 1,041 LOC; missing brackets linear; extra brackets still time out |
| pd38 | pd37's bound counts the edits, not 0/1 | 1,046 LOC; 1,558 ms |
| pd39 | GSS nodes replace frame stacks | 951 LOC; extra brackets about n^3; paren, optional x a and ab aa a quadratic |
| pd42 | classes keyed by the term's id | optional x a fixed; paren still 54 s at 1024 |
| pd43 | classes keyed by the term's `sid` | every pd39 regression linear again; 993 LOC |
| pd44 | the `lent` flag deleted: a class change always searches again | 967 LOC; same trees as pd43 |
| pd45 | elegance review of pd44 | 954 LOC; same trees, costs, gates and fuzzer as pd44 |
| pd46 | `_zero` deleted | 944 LOC; same trees, costs, gates and fuzzer as pd45; 2,098 ms |

**Why the tie key holds (confirmed by ablation).** Removing parts of the
tie-break after cost: pd34a 0.9779/79.2 (treeDiff 364, costDiff 69); without
`s` 0.9866/82.0 (treeDiff 407); without `span` 0.9897 (treeDiff 35); without
both 270 treeDiff. Every part is used.

**Theory (confirmed from the source, arXiv 2111.02336, recorded in
`paper/verification/cites_recovery.md` section 13).** Language edit distance
to a CFG takes O(|G|^2 n^3) (Aho and Peterson 1972), O(|G| n^3) (Myers), and
about n^2.82 with fast matrix multiplication (Bringmann et al.); by Lee's
result no algorithm beats Boolean matrix multiplication. Dyck edit distance
is no easier (Abboud et al., via k-Clique). With at most k edits, Dyck edit
distance takes O(n + k^4.544) (Fried et al.). So about n^3 on n extra
brackets is the general cost of the problem, not a defect of this design
(inferred: the bracket grammar is not exactly Dyck). Linear time holds while
the number of edits is bounded.

**Negative results (confirmed).**

| Probe | Change | Result | Score |
|---|---|---|---|
| pd41 | node key on the term's `sid` | a wrap and its kid share a `sid`, so a node waited on itself and every input fell back to whole-input error; with the parent in the key, optional x a unchanged and extra brackets crash in the tree code | 1 |
| pd42 with outer id | class keyed by the outer node's id | no gain | 2 |
| pd44q1 | invented open-class count `inv` ranked right after the estimate | b2 passes; battery 0.9833/81.2, treeDiff 165 (32 with fewer edits, all equal rank cost) | 3 |
| pd44q2 | `inv` ranked after `bare`, before edits | 0.9898/84.4, treeDiff 2; b2 still fails | 4 |
| pd40 | | 1,094 LOC | 2 |
| pd36 | hash-consed frame stacks | extra brackets time out at every n | 3 |
| pd37 | weight bound on pd36 | missing brackets linear, extra brackets time out | 4 |

**Elegance review (pd44 -> pd45, confirmed).** A review agent applied 11
changes. The main ones: `_G.id` deleted, a class is an object and a node
that leaves its class becomes its own class (`v.cls = v`); the class key
drops the `z` flag and tests `at.a` directly; `_no` renamed `_noBetter` with
its arguments in reading order; the `_tree` path walk uses a stack of runs;
the re-push reuses the state. pd45 vs pd44: battery 0.9898/84.4, treeDiff 0,
costDiff 0, 2,119 ms (pd44 2,008 in another run); gates and fuzzer the same.
Not applied: `join` sums `inv` but `_noBetter` does not compare it.

**pd46: `_zero` deleted (confirmed empirically, argued, not proved).**
`_zero` asked whether a pending part had age 0. A counting probe found it
false on every battery input and on probes with optionals, lookaheads and
left recursion. The argument: an age-0 part arises only inside a `seq` whose
ages hold 0, which `_wait` never delegates through, or inside a term that is
`now`, which returns done first. pd46 drops it and keys a node on
`(term id, pos, sens, look, free, cost == 0)`. pd46 vs pd45: battery
0.9898/84.4, treeDiff 0, costDiff 0, 2,098 ms; gates the same; fuzzer worse
0, invalid 0, timeouts 0. LOC 954 -> 944 (-10, -1.0%).

**pd47, pd47b: nodes only at clause calls (confirmed).** pd46 makes a GSS
node for the term a node waits on. pd47 walks the wait chain to the first
`wrap` or LR `grow` term (as Earley predicts only nonterminals) and steps the
terms between in place; pd47b stops only at rule calls (`wrap` of a `Ref`).
Both 950 LOC. Battery vs pd46: pd47 0.9899/84.4, 1,708 ms, treeDiff 5;
pd47b 0.9898/84.4, 1,590 ms, treeDiff 13; costDiff 0 in both, all diffs
equal-cost expr trees. Gates and fuzzer the same as pd46.

| Family (AOT, ms) | n | pd46 | pd47 | pd47b |
|---|---|---|---|---|
| paren | 1024 / 4096 / 16384 | 1,025 at 1024 | 886 / 3,819 / 15,757 | 679 / 3,086 / 12,987 |
| optional x a | 512 / 2048 / 8192 | 88 at 4096 | 7 / 28 / 107 | 4 / 15 / 65 |
| ab aa a | 1024 / 2048 / 4096 | 165 | 27 / 59 / 91 | 26 / 52 / 70 |
| ab repetition | 1024 / 4096 / 16384 | 163 | 39 / 161 / 696 | 31 / 133 / 505 |
| optional-a b repetition | 1024 / 4096 / 16384 | | 66 / 258 / 1,153 | 66 / 238 / 1,038 |
| json valid long | 1024 / 4096 / 16384 | | 78 / 304 / 1,398 | 80 / 296 / 1,539 |
| extra brackets | 8 / 16 / 32 | 165 / 1,297 / 9,218 | 230 / 2,511 / 30,841 | 361 / 4,727 / 57,110 |
| missing brackets | 64 / 256 / 1024 | 10 / 42 / 183 | 8 / 33 / 158 | 7 / 25 / 133 |

(pd46's single figures are from a separate driver, best of 3.) Depth 3200
and the x(ax)*n / x(ab)*n families stay linear in both. So pd47b is the
fastest engine on every linear family (optional x a 65 ms at 8192, pd37 76)
but about 6x slower than pd46 on extra brackets (n^3.6 between 16 and 32).
The cause, from counters on extra brackets n=16: pd47b makes 516k terms to
pd46's 96k over the same 32 sids, while pops are about equal (389k vs 367k).
Terms carry their tree fragments, so stepping inline terms in place makes
many distinct terms of one shape; a node per inline term shared those
steps. Probes that stop at `wrap`/`grow`/`seq` (1,481 ms on extra brackets
n=16) or also at `cat` (1,156 ms) sit between pd46 and pd47b on both
families.

**pd48: a state already seen is not stepped (confirmed).** A step's `sid`
depends only on the parent's `sid`, the character and how it is read
(checked: pd48chk compares the step of the parent's canonical term with the
real step on every state of the battery and fuzzer, and never differs). So
the seen check can run before the step is built. pd48 (from pd46) and pd48b
(from pd47b) give the same trees as their bases, the same gates, fuzzer 0.
Gain at most about 10% (extra brackets n=16: pd46 1,133 -> pd48 1,059 ms;
pd47b 5,220 -> pd48b 4,704 ms), for +1 LOC. The rejected pops do not cost
mainly the step. Not adopted.

**Candidates.**

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| pd46 | 944 LOC; same trees as pd45; 2,098 ms | 8 | the smallest pd engine since pd36 with every input finishing; extra brackets about n^3 |
| pd47b | 950 LOC; 1,590 ms; equal-cost trees | 7 | fastest on short and linear inputs; extra brackets 6x pd46 |
| pd48 | 945 LOC; same trees as pd46 | 6 | at most 10% faster for one line |
| pd47 | 950 LOC; 1,708 ms | 6 | between pd46 and pd47b on every family |
| pd45 | 954 LOC; same trees as pd44 | 7 | `_zero` not needed |
| pd44 | 967 LOC; 2,008 ms; every measured input finishes; invalid 0 | 7 | longer than pd45 |
| pd43 | 993 LOC; same trees | 7 | `lent` not needed |
| pd37 | 1,041 LOC; fastest on linear families | 4 | extra brackets never finish |
| pd36 | 908 LOC | 3 | extra brackets never finish |

LOC: pd23 856 -> pd46 944 normalized (+88, +10.3%); pd36 908 -> pd46 944
(+36, +4.0%); pd44 967 -> pd45 954 (-13, -1.3%); pd45 954 -> pd46 944 (-10,
-1.0%).

**A correction to pd23's section (confirmed from the code).** It says no
open-class character is ever inserted. That is wrong for every pd engine:
`_rep` inserts an open class's least printable member that no literal
spells, ranked after cost by the count `inv`. The tree marks it as a
zero-width error, so no character is invented in the tree, but gate b2
(`[,2,33,true]`: delete the comma rather than owe a value) is exactly the
D7 case and fails. Both readings have rank cost 1; `bare` (the deleted comma
is a character no repair reads) decides for the insertion. The battery holds
both shapes (`[,33,true]` from a deleted `2` wants the insertion), so a
global reordering trades b2 for 165 trees (pd44q1 above), as cl6's three D7
rules did.

**`lastCost` is the edit count, not the rank (confirmed).** `lastCost =
found.ed`, while the search ranks by `cost`, in which all text owed at the
end of input costs 1. On `a*(` pd44 reports 2 (owe a value and `)`, rank 1)
and pd44q1 reports 1 (substitute the `(`, rank 1). `costLower` in the
battery compare counts edits, so it can differ between engines of equal
rank.

**Open items.**
- Size: pd46 is 36 lines above pd36.
- Prove that pd46's deletion of `_zero` is sound (empirical so far).
- Get pd47b's linear-family speed without its term growth on extra
  brackets: for example keep tree fragments out of terms stepped in place.
- Decide whether `_noBetter` should compare `inv`.
- Constant factor: 1.2-3.8x pd37 on paren, optional x a and ab aa a.
- Extra brackets are about n^3 in n errors; the k-Dyck bound suggests
  O(n + poly(k)) is possible.
- Gate b2=false in every pd engine.
