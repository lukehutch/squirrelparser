<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### Round 15 on cl20: no smaller engine, and two failures no family covered (2026-09-25)

Round 15 ran a Claude subagent (Opus 5.5, high effort) on BRIEF15 (Q1 noavoid
without the `bab` loss; Q2 the speed of seed sealing with less code; Q3 a proof or
restructure for the three budget conditions; Q4 per-function LOC; Q5 review of round
14). It built 21 engines (n1-n16 and reruns) and found none smaller that meets every
target, so cl20 stands (757 LOC). Its report is `R15_CLAUDE.md` in the round kit.

**Findings from the seat (its measurements unless marked).**
- **The avoidable key has one job**: among repairs of equal cost it prefers deleting
  input so that later input fills the slot over inserting the slot's text (on `bab`:
  delete `b` at 0 and insert `a` at 2, which the fuzzer counts as one substitution,
  against two insertions). Without it (n1, 736 LOC) only s4 levWorse is worse (3
  against 2), and n1 finds three cheaper answers (s2 `bbbbbbbb` 2 -> 1, s2
  `ccbbbabcab` 4 -> 2, s6 `bc` 3 -> 2). All three exemptions of the demotion are
  needed (n5-n7). A `max(deleted, missing)` key fixes `bab` but makes s2 `cacac`
  invalid (n8).
- **Seed sealing** reads each `'+' N` tail of a left-recursive sum with the plain
  parser: lr 8192 reads 53,266 cells against 90,112 without it. Deleting it (n10,
  742 LOC, same battery trees) costs AOT lr 2048 43 against 33 ms and lr 8192 156
  against 130 ms. k13's errors 4096 slowdown came from its k10 parts, not from the
  sealing.
- **The three refused conditions are not implied.** `_view`'s `r.spent > budget`
  drops 2,512 readings in 130 battery cases (a cell is read at a smaller budget than
  it was grown at by reuse, by an active read, or after regrowth). `stop == r.end`
  in `_resume` is not a budget condition: without it `opens` tests a character that
  does not follow the stop. Moving the budget check to one place saves no lines
  (argued).
- **`_ev`** can be written with no memo (n14, 749 LOC, same trees by proof) but is
  then quadratic on right recursion, or memoized in two passes (n4, 753 LOC) but
  then AOT errors 4096 is 56 against 46 ms (cause unknown).
- Round 14's claims reproduce: k10's slowdown has the two named causes, and either
  alone gives all of it; k13's lr numbers; noavoid's `bab`; the first_total knockout
  exactly and stop_seed within 1.

**Two failures that predate the round (confirmed, my runs, AOT via
`_nrscale.dart` and a new `_depth.dart` compiled with `dart compile exe`).**
- **Recovery overflows the stack far below the parser's own depth.** Grammar
  `S <- V; V <- '[' (V (',' V)*)? ']' / 'n';` on `[`*n `n` `]`*n: the plain parse
  succeeds up to n = 1,600 and overflows at 3,200; with the last `]` missing, cl20
  overflows at n = 400 (300 takes 11 ms), cdx1 at 800. The recursion is
  `_read -> _seq -> _repeat -> _read`, one round per nesting level. A JSON document
  nested 400 deep with one missing bracket crashes recovery.
- **One error at the end of a right recursion through a repetition is cubic.**
  `S <- A; A <- 'x' ('a' A)*;` on `x` (`ax`)*n `b`, cost 1: cl20 13 / 64 / 331 /
  2,280 ms at n = 50 / 100 / 200 / 400, cl19 the same, cdx1 6 / 31 / 172 / 1,131;
  all overflow by n = 700. With n errors (`x` (`ab`)*n) cl20 takes 588 / 2,059 /
  6,478 ms (JIT) at 100 / 200 / 400. The same nesting through an optional
  (`('a' A)?`), through `'x' 'a' A / 'x'`, or inside brackets is linear. The
  inferred cause (not measured): an inner `A` can stop at any unit boundary with the
  outer repetitions reading the rest at no cost, so each of the n cells has O(n)
  ends, and the bound cannot prune them. None of the 46 families has this shape.

**Candidates.**

| Candidate | LOC | Result | Score | Reasoning |
|---|---|---|---|---|
| cl20 unchanged | 757 | every target but size | 7 | nothing smaller passed |
| n10 sealing deleted | 742 | same battery trees; AOT lr +20-30% | 4 | fails speed |
| n4 `_ev` two passes | 753 | same trees; AOT errors 4096 +21% | 4 | fails speed, cause unknown |
| n1 noavoid | 736 | s4 levWorse 3 > 2; three cheaper answers | 3 | fails target 3 on one seed |
| n14 `_ev` no memo | 749 | quadratic on right recursion | 3 | fails target 4 |
| n8 `max` key | 738 | `bab` fixed, s2 `cacac` invalid | 2 | new invalid tree |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| no smaller engine meets the targets; cand = cl20 byte-identical | Claude | `same.sh cand` before the round; the seat's final outputs | confirmed for cand; the negative results not rerun |
| right recursion overflows at about 1,400 levels | Claude | `_depth.dart`, `_nrscale.dart` in AOT: overflow at 400 (brackets) and by 700 (`('a' A)*`) | confirmed, and worse than stated |
| `'x' ('a' A)*` superlinear, 551 / 7,324 ms at 100 / 500 | Claude | AOT 64 / 2,280 ms at 100 / 400 with one error; JIT 588 / 6,478 at 100 / 400 with n errors | confirmed (the seat's input not recorded) |
| n1, n4, n8, n10, n14 numbers; Q5 reruns | Claude | not rerun | unsupported by my check |

**Open items.** The stack depth (recovery must reach at least the parser's depth);
the cubic `('a' A)*` family; both added as families before any further size work.

**Process lesson.** A family list only proves what it contains: 46 families, all
linear, and none nested a rule through a repetition or went deeper than the stack.
Add the shape of every new failure as a family.
