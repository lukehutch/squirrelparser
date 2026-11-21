<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl28 - round 25 on cl27: the diverse key holds what a lead is tested for, not its text, so every input finishes, 898 -> 909 LOC (2026-10-03)

Round 25 was run by the orchestrator alone (Codex and Gemini had no quota).
It takes the first fix named in round 24's open items: key a lead on the
outcomes of the tests it can face, not on a prefix of its text.

**What cl28 changes (confirmed from the diff against cl27).**
- `_Front.key` held `r.lead?.substring(0, min(r.lead!.length, _wide))`, a
  prefix cut at the grammar's longest literal. It now holds
  `search._class(r.lead!)`: a record of (1) one bit per tested clause, set
  when `_starts(clause, lead)` holds, where the tested clauses are the bodies
  of every repetition and optional and every arm of a `First` but the last,
  and (2) the lead itself when it is a suffix of some literal, else null.
  These are the only questions the guards ask of a lead: whether it opens a
  greedy body or an earlier arm, and which literal it can still finish.
- Termination: the tested clauses and the literal suffixes are finite sets
  fixed by the grammar, so the key takes finitely many values whatever the
  length of the owed text. Unlike a width cut, the number of values does not
  grow with the leads' length.
- `_wide` and `_longest` (7 lines) are deleted. The parent map that
  `_covered` built locally is lifted into `_uses` and also gives the clause
  list for `_tested` and `_suffixes`; a separate `_all` clause list in the
  first version (r26a, 923 LOC) was deleted in the elegance pass (r26f).

**Measured (confirmed), kit r9/verify, baseline cl27 (kit name r24p1).**
- `hang.sh`: G1 and the `R9 <- "cccc"` variant G2 on `acacac` cost 2, valid,
  in under a second (cl27: G2 does not finish in 120 s). G3, the
  `("ab" "cd")*` case on `abcd`: `abcdabcee`, five owed characters ranked at
  cost 1, valid (cl27 invalid at 2 edits). New case G4, `S <- R0; R0 <- (R1 /
  "baba"+?); R1 <- ((("cb" / 'c') / R2+) / (R0* (R0 R1))); R2 <- ('a'*?
  ("ababa"? 'b'* R0*));` on `caba`: cost 1, valid (cl27 does not finish).
- `check28.sh`: battery 0.9900/84.5, treeDiff 0, costDiff 0; accept t/t/t,
  freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff
  0, props 2728/0, window P, pred 0, no-repair total 0. Old fuzzer and strict
  witness seeds 1-8: equal to cl27 except one tree on seed 4 (worse by one
  edit under `lastCost`, equal under the ranking cost; see below).
  `_samedw` seeds 1-8: equal to cl27 in every count.
- Long-literal fuzzer `_samedl` (`samedl.sh`, 10 s limit), seeds 1-32,
  12,800 cases: cl27 worse 3, invalid 164, timeouts 1, levWorse 3; cl28 worse
  1, invalid 163, timeouts 0, levWorse 0; treeDiff 5. r26a and r26f give
  identical trees on all 12,800.
- `deep.sh` and `multi.sh`: every cost equal to cl27 and times within 8%
  (for example `x (ab)*n` at n=1600 4,322 against 4,245 ms); both overflow
  the stack at depth 3,200 in the nesting test, as cl27 does.
- Families 0-45 (`famaot.py`, 3 runs, AOT, on r26a): every cost equal to
  cl27; the medians differ by -7% to +10%, and only families 1, 6, 18 and 24
  by more than 6% (family 24 is 71 against 78 ms). Not rerun on r26f, whose
  diff from r26a only moves the clause list.

**The `bbbbbbabbb` case is a tie, not a key bug.** cl28's one seed-4 tree
that is worse under `lastCost` is an owed completion where cl27 inserts one
character. A key on the full lead (probe r26z) gives cl28's answer, so cl27
reached its one-edit tree only because the prefix cut merged two leads. Both
answers cost 1 under the ranking (an owed-only completion costs 1).

**Negative results (confirmed).**

| Probe | Change | Result | Score |
|---|---|---|---|
| H1 (r26e) | edits as a tie-break after cost, to prefer the one-edit tree | battery 0.9847 | 1 |
| r26m | always remember (`_Bound(parser, true)`, `_allowance = 0`) | same trees, 1.7x slower | 3 |
| r26d | the diverse key in every rung | LR 2048 40x slower, battery 0.9897 | 1 |
| H6 (h6a) | a stop guard also tests the input after a deletion at the stop | `_samedl` seeds 1-8: invalid -6, worse +16 | 3 |

**Where the invalid trees are (confirmed, `_why.dart` on cl28's 46 invalid
`_samedl` trees, seeds 1-8).** The innermost clause whose match differs
between the tree and PEG's parse of the witness is an empty `*` or `?` that
the witness revives (27), a `First` that takes another arm (10), a nonempty
repetition that grows (5), and a literal or sequence that fails (4). In 15 of
the 27 revived repetitions and optionals, the next edit comes at least two
characters after the empty clause (up to 10), so a guard that looks only at
the characters next to the stop cannot catch them.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r26f = cl28 | the class key, `_all` folded into `_uses` | 909 LOC; every input in 12,800 finishes; all checks equal or better than cl27 | 8 | first key with a finite range fixed by the grammar |
| r26a | the class key, separate `_all` | 923 LOC; same trees | 6 | larger |
| cl27 | prefix key | 898 LOC; G2, G4 and one fuzzer case do not finish | 2 | fails termination |

LOC 898 -> 909 normalized (+11, +1.2%).

**Open items.**
- Invalid trees: 163 per 12,800 `_samedl` cases. Most are empty
  repetitions revived by text far from the edit, which local guards cannot
  see; the exact fix is a search whose states are PEG states (round 26).
- Kind D, the five families, the quadratic term with two or more errors, and
  size (909 against cl20's 757), as in round 24.
