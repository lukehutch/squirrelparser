<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### u28 - round 32: a lookahead position is bounded by what follows the lookahead, battery 4.7 -> 2.3 s, 958 -> 998 LOC (2026-10-07)

**The cause of u21's slow battery (confirmed by probes).** u21 gave a
position with no copy in the unfolded grammar the bound 0. Those are the
positions inside a lookahead, since the table treats a predicate as a move
that reads nothing. On the stmt grammar (`N <- !K [a-z]+`) every name
starts with a lookahead, so the bound at the start was 1 where the true cost was 2
or 3, and the search took every state whose cost was at most the bound.
Probe on battery case 727 (true cost 2): u22 16,558 states, pd57 355.

**u28 = u21 with three changes (confirmed).**
- The closure over `_back` reads flat arrays (an offset array and one list
  of targets) in place of a list of lists (u22: battery 4.7 -> 3.9 s, same
  trees).
- The table records, for each predicate, the node where it ends. For each
  position in a predicate's body, `_via` holds the positions (or the end of
  the top rule) a read may reach from there by moves that read nothing. A
  lookahead reads nothing, so what the term must still read is what follows
  the lookahead. A position with a copy keeps itself in `_via`, so a rule
  used both inside and outside a lookahead gets the least of both, which
  closes the case where u21 to u27 could overestimate (inferred possible,
  never observed).
- `_lb` takes the least over `_via[x]` for each lead position x.
- Probe, START is the bound at offset 0 in edits, STATES the states taken:

| Input | u26 START | u26 STATES | u28 START | u28 STATES | true cost |
|---|---|---|---|---|---|
| case 727 | 1 | 293 | 2 | 247 | 2 |
| `f5=;` | 1 | 43 | 2 | 31 | 2 |
| `f5=;g5=;` | 1 | 199 | 3 | 55 | 3 |

**Checks (confirmed).**
- Battery: 0.9896/84.2, 2.29-2.31 s (two runs; u21 4.7 s, pd57 2.0 s).
  treeDiff 0 against u27; u27 against u26 treeDiff 23, costDiff 0; u26
  against u22 treeDiff 72, costDiff 0. So every cost equals u22's.
- Gates equal to u21: accept cx2/b1 true, b2 false, freespan 3 3 4 4 1,
  recommit 16/16, conformance 0 1 1 0 2 2, cleanTreeDiff 0.
- Fuzzer 8 seeds x 400 against pd57: worse 0, invalid 0, timeouts 0.
- Grammar `S <- (B 'y' / &B 'a' 'z')+; B <- 'a' 'a'?;` (B both inside and
  outside a lookahead), inputs azq, qaz, aaz, bz, a: same costs as pd57.
- Rungs, all finishing (u26 in brackets): 1000/6/1 1.0 s (1.1); 8/1 1.0 s;
  12/1 1.3 s (1.4); 32/1 17.4 s, 4.1 GB (18.5); 64/1 6.5 s (7.1); 256/4/7
  0.42 s; 1024/4/7 1.06 s (1.10); paren n=16384 3.5 s; ab repetition
  n=16384 0.91 s; optional-a b 0.35 s; extra brackets n=32 9.8 s (10.4);
  missing n=1024 0.19 s; depth 3200 0.27 s; x(ab)*n n=1600 0.17 s.

**Refuted or not adopted.**
- u24: a lookahead position bounded by the other lead positions, 0 if every
  lead position is in a lookahead. Unsound in principle (a term whose whole
  lead is a lookahead still owes what follows it); 2.35 s.
- u25/u26: a floor per offset (the least over every state) for lookahead
  positions. Sound, 2.55 s, 968 LOC, but weak on stmt: the least is taken
  over states inside a string literal that can swallow the rest of the
  input, so START stays 1.
- The table built twice (u27t, a timing control): 3.2 s against 2.45 s, so
  the table is about 0.75 s of the battery and the search about 1.55 s
  (pd57, with no table, 2.0 s).
- A closure over the condensed key graph: of the 620 closure entries on
  stmt, 491 are direct edges between keys (json 1,765 of 2,255, expr 1,381
  of 1,941), so it cannot save more than about a fifth.

| Candidate | Result | Score | Reasoning |
|---|---|---|---|
| u28 | 2.3 s; 0.9896; 998 LOC; sound on shared rules | 8 | fastest u engine, every rung finishes |
| u27 | as u28; 1004 LOC | 7 | same trees, set built per lookup |
| u26 | 2.55 s; 968 LOC | 7 | 30 lines smaller, 10% slower, weak bound on stmt |
| u24 | 2.35 s; unsound in principle | 3 | a lookahead-only lead would be bounded by 0 |
| u22 | 3.9 s; 965 LOC | 5 | flat closure only |
| u21 | 4.7 s; 958 LOC | 4 | superseded |

LOC: u21 958 -> u22 965 -> u26 968 -> u27 1004 -> u28 998; u21 -> u28
+40, +4.2%.

**Open items.**
- The table, about 0.75 s of the battery; pd57's search alone is 2.0 s.
- Extra brackets about n^3 (n=32 9.8 s).
- 1000/32/1 at 4 GB.
- Gate b2=false in every pd engine.
