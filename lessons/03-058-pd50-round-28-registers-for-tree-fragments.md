<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### pd50 - round 28: registers for tree fragments refuted, extra brackets diagnosed, 944 -> 957 LOC (2026-10-03)

Round 28 was run by the orchestrator alone. It takes pd46's open items on
term growth and on extra brackets. Engines pd49-pd53i are in the scratch kit
r27k. Nothing is promoted: pd46 stays the standing pd engine.

**pd49: the join fill is made when the state is taken (confirmed).** A pop
that joins a frame now stores the frame's term in `_St.x` and builds the
fill only if the state is taken from the queue, as a step already was. Same
trees, gates and fuzzer as pd46; 944 -> 947 LOC; battery 2,059 ms against
pd46's 2,043 in the same session; extra brackets n=32 9,567 -> 8,340 ms.

**pd50: a state already seen is not built, for fills too (confirmed).** The
fill's `sid` depends only on the frame's `sid`, the child's `sid` and `a`, so
it is memoized on those and looked up on canonical terms before the real
fill is built; a step's `sid` is found the same way (pd48's observation).
pd50chk throws if the predicted `sid` ever differs from the built one; it
never does on the battery or the fuzzer. Same trees, gates b1, cx2,
freespan, recommit 16/16, conformance and cleanTreeDiff 0 as pd46; fuzzer
worse/invalid/timeouts 0. Battery 2,098 ms; extra brackets n=32 6,446 ms
(about 33% less than pd46). 944 -> 957 LOC (+13, +1.4%). Not adopted: the
battery does not move, and the extra-bracket family is still about n^3.

**pd51 and pd52: tree fragments in registers, refuted (confirmed).** pd47b
was fastest on linear families but its terms carry their trees, so equal
derivatives with different trees are different terms, and extra brackets
were 6x pd46. The idea tried here is the variable of a streaming string
transducer (Alur and Cerny, FSTTCS 2010: "It uses a finite set of variables
that range over strings from the output alphabet. At every step, the
transducer processes an input symbol, and updates all the variables in
parallel"): a term holds a placeholder tree `_var` whose value is in a
per-state list `regs`, so terms that differ only in their trees are one
term, and the GSS node key includes the register ids.
- First version: treeDiff 12, all in expr at equal cost. Cause: `_cut` and
  `_meet` compare subterms by identity, and in pd46 a hash-consed term
  includes its forest, so identity means equal shape and equal forest.
  Positional registers made two different forests look equal. Fixed by one
  register per distinct evaluated forest (`_regs` dedupes after
  evaluation). After the fix treeDiff 0.
- pd51: 1,019 LOC (+75, +7.9% on pd46); battery 2,499 ms; extra brackets
  n=32 11,816 ms. pd52 (seen check before `_regs`): 1,014 LOC (+70, +7.4%);
  2,447 ms; 9,087 ms.
- The profile puts about 15% in `_regs` before the cache fix. Inferred: a
  per-state register evaluation costs as much as building the tree into the
  term did, so moving trees out of terms saves nothing. Lesson: in pd46 the
  forest in the term is part of what makes identity comparisons in `_cut`
  and `_meet` correct; any scheme that takes it out must give those
  comparisons the forest some other way.

**Extra brackets are about n^3, and why (confirmed by instrumentation).**
pd46i counts states per position and per cost. On `"[" + "[1,2]],"*n +
"1]"`: n = 4, 8, 16, 32 give 3,790, 27,018, 165,200, 888,239 states and 18,
138, 1,214, 9,652 ms. At most 13 `sid`s occur at any position, but the
classes per position reach 253, 951 and 2,577 (n = 4, 8, 16). Nodes that
left their class are 2,122 of 14,181 at n=16 but hold 97k of the 165k
states. States per cost level grow with the cost (n=16: cost 3 has 3,331,
cost 10 has 33,115). pd53i reduces the class key's age to 0/1 and changes
nothing.
- Diagnosis: the regular bound `_lb` merges follow sets per rule, so it
  cannot see an unmatched `]` and prices it 0. The search then explores
  every cost from each position's least cost up to the answer's, with O(n)
  open origins per position: about n^3. A global least-distance repair is
  cubic in general (Aho and Peterson 1972), so this is the expected cost of
  exactness without a better bound, not a bug.
- A Dyck bound was worked out and rejected. For a suffix with total closer
  excess E, greatest prefix excess of closers M and open depth k, the
  bracket edits still owed are at least ceil((U+R)/2) with U = max(0, M-k)
  and R = k - E + U. On this family it gives about u/2 against a true cost
  of about 0.69u for u unmatched closers, so the search stays superlinear.
  It is also unsound when an open class such as json's `[^"]` matches `]`
  inside a string. Not built.

**Candidates.**

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| pd46 | 944 LOC; 2,043 ms; extra n=32 9,567 ms | 8 | standing; smallest |
| pd50 | 957 LOC; 2,098 ms; extra n=32 6,446 ms | 7 | a third faster on extra brackets, same order, +13 lines |
| pd49 | 947 LOC; 2,059 ms; 8,340 ms | 6 | half of pd50's gain |
| pd52 | 1,014 LOC; 2,447 ms; 9,087 ms | 2 | larger and slower |
| pd51 | 1,019 LOC; 2,499 ms; 11,816 ms | 1 | larger and slower |
| Dyck bound | not built | 2 | too weak by a constant; unsound with open classes |
| class age 0/1 | no change | 1 | the classes are not the cause |

LOC: pd46 944 -> pd49 947 (+3, +0.3%); pd46 944 -> pd50 957 (+13, +1.4%);
pd46 944 -> pd51 1,019 (+75, +7.9%); pd46 944 -> pd52 1,014 (+70, +7.4%).

**Open items.**
- Size: pd46 is 944 against c20's 742. `_tree` (64 lines) and `join` (48)
  are the largest parts; no deletion found that keeps conformance.
- Extra brackets: about n^3. Needs either a bound that sees bracket balance
  and stays sound with open classes, or a rule that limits how far back an
  error may be repaired (not exact, must be justified).
- Keeping tree fragments out of terms: refuted as done here (pd51, pd52).
- Gate b2=false in every pd engine.
